---
title: "Kolla-Ansible 멀티노드 배포 가이드 (Ubuntu 24.04 + OpenStack 2026.1)"
type: "guide"
date: 2026-06-21
tags: ["#guide", "#kolla-ansible", "#openstack", "#ubuntu"]
related_nodes: ["[[01_Concepts/Kolla-Ansible]]", "[[01_Concepts/OVN-OVS-Architecture]]", "[[02_QnA_Archive/2026-06-28-kolla-ansible-deploy-troubleshooting]]"]
author: "AI Assistant"
raw_source: ["[[00_Inbox/2026-06-21-kolla-install-roadmap-raw]]", "[[00_Inbox/2026-06-21-kolla-practice-guide-raw]]"]
---

# Kolla-Ansible 멀티노드 배포 가이드 (Ubuntu 24.04 + OpenStack 2026.1)

## 개요

Proxmox 위 VM들에 Kolla-Ansible 22.0.0으로 OpenStack 2026.1 (Gazpacho)를 멀티노드로 배포하는 가이드.

> ⚠️ **버전 주의**: kolla-ansible 22.x는 Ubuntu 24.04 (Noble)만 지원. 22.04로 시작하면 install-deps 단계에서 실패함.

---

## 노드 구성

| VM 이름 | IP (ens18) | Kolla 역할 |
|---------|-----------|-----------|
| cjm-lb (deploy host) | 192.168.100.201 | kolla-ansible 실행 전용 |
| VIP | 192.168.100.200 | Keepalived가 관리 (별도 VM 아님) |
| cjm-ct01~03 | .202~.204 | control + network + HAProxy |
| cjm-cp01~02 | .205~.206 | compute |
| cjm-st01 | .207 | storage (Cinder LVM + Swift) |

### NIC 역할

| NIC | 용도 |
|-----|------|
| `ens18` | 관리망 192.168.100.x (API, 오버레이, 스토리지) |
| `ens19` | 외부망 (IP 없음, UP 상태) → neutron_external_interface |

---

## Phase 0 — VM 초기화 및 OS 설치

### VM 스펙

| VM 유형 | CPU | RAM | 디스크 | CPU Type |
|---------|-----|-----|--------|---------|
| cjm-lb | 1 | 1GB | 10GB | x86-64-v2-AES |
| cjm-ct01~03 | 2 | 4GB | 40GB | x86-64-v2-AES |
| cjm-cp01~02 | 2 | 3.5GB | 50GB | **host** (중첩 가상화) |
| cjm-st01 | 1 | 4GB | OS 20GB + Cinder 50GB + Swift 30GB | x86-64-v2-AES |

> Proxmox 설치 시 `Set up this disk as an LVM group` **해제** (Kolla는 Docker라 불필요)

### 모든 VM 공통 체크리스트

```bash
# 업데이트
sudo apt update && sudo apt upgrade -y

# ens19 IP 없이 UP (ct/cp 노드만)
sudo tee /etc/netplan/51-ens19.yaml <<'EOF'
network:
  version: 2
  ethernets:
    ens19:
      dhcp4: false
      dhcp6: false
EOF
sudo chmod 600 /etc/netplan/51-ens19.yaml
sudo netplan apply

# passwordless sudo
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER

# NIC 이름 확인 (ens18/ens19 이어야 함)
ip -br a
```

---

## Phase 1 — Deploy Host (cjm-lb) 설정

### SSH 키 배포

```bash
# cjm-lb에서 실행
ssh-keygen -t rsa -b 4096 -N ""
for ip in 202 203 204 205 206 207; do
  ssh-copy-id -i ~/.ssh/id_rsa.pub ubuntu@192.168.100.$ip
done
```

### Kolla-Ansible 설치

```bash
# Python 가상환경
python3 -m venv /opt/kolla-venv
source /opt/kolla-venv/bin/activate

# kolla-ansible 22.0.0 설치
pip install kolla-ansible==22.0.0 'ansible-core>=2.16,<2.20'

# 설정 파일 복사
mkdir -p /etc/kolla
cp $(python3 -c "import kolla_ansible; print(kolla_ansible.__file__.replace('__init__.py',''))")etc/kolla/globals.yml /etc/kolla/
cp $(python3 -c "import kolla_ansible; print(kolla_ansible.__file__.replace('__init__.py',''))")etc/kolla/passwords.yml /etc/kolla/
```

---

## Phase 2 — globals.yml 설정

```yaml
# /etc/kolla/globals.yml 핵심 항목
kolla_base_distro: "ubuntu"
openstack_release: "2026.1"
kolla_internal_vip_address: "192.168.100.200"
network_interface: "ens18"
neutron_external_interface: "ens19"

# 네트워크 백엔드
neutron_plugin_agent: "ovn"
enable_neutron_provider_networks: "yes"

# 스토리지
enable_cinder: "yes"
cinder_volume_group: "cinder-volumes"   # st01의 /dev/sdb

# 고급 서비스
enable_swift: "yes"
enable_octavia: "yes"
enable_haproxy: "yes"

# MariaDB/RabbitMQ 클러스터 (자동)
```

---

## Phase 3 — multinode 인벤토리 설정

```ini
# /etc/kolla/multinode
[control]
cjm-ct01 ansible_host=192.168.100.202
cjm-ct02 ansible_host=192.168.100.203
cjm-ct03 ansible_host=192.168.100.204

[network]
cjm-ct01
cjm-ct02
cjm-ct03

[compute]
cjm-cp01 ansible_host=192.168.100.205
cjm-cp02 ansible_host=192.168.100.206

[storage]
cjm-st01 ansible_host=192.168.100.207

[monitoring]
cjm-ct01

[deployment]
localhost       ansible_connection=local
```

---

## Phase 4 — 배포 실행

```bash
source /opt/kolla-venv/bin/activate

# 비밀번호 생성
kolla-genpwd

# 의존성 설치
kolla-ansible -i /etc/kolla/multinode install-deps

# 서버 초기화
kolla-ansible -i /etc/kolla/multinode bootstrap-servers

# 사전 검사 (테스트 이미지 사용)
kolla-ansible -i /etc/kolla/multinode prechecks --use-test-images

# 이미지 선반입 (선택, 타임아웃 방지)
kolla-ansible -i /etc/kolla/multinode pull

# 배포
kolla-ansible -i /etc/kolla/multinode deploy
```

> ⚠️ ProxySQL keepalived 순환 의존 이슈 발생 시: [[02_QnA_Archive/2026-06-28-kolla-ansible-deploy-troubleshooting]] 참고

---

## Phase 5 — 배포 후 검증

```bash
# post-deploy (openrc 파일 생성)
kolla-ansible -i /etc/kolla/multinode post-deploy
source /etc/kolla/admin-openrc.sh

# 기본 자원 생성
# External network (provider flat)
openstack network create --external \
  --provider-physical-network physnet1 \
  --provider-network-type flat external-net
openstack subnet create --network external-net \
  --allocation-pool start=192.168.100.210,end=192.168.100.250 \
  --no-dhcp --gateway 192.168.100.1 \
  --subnet-range 192.168.100.0/24 external-subnet

# Test VM
openstack server create --image cirros \
  --flavor m1.tiny --network internal-net test-vm

# FIP 할당 및 SSH 확인
openstack floating ip create external-net
openstack server add floating ip test-vm <FIP>
```

---

## 주의사항 / 트러블슈팅

| 이슈 | 해결 |
|------|------|
| install-deps 실패 | kolla 버전 ↔ OS 버전 ↔ 브랜치 EOL 확인. Ubuntu 24.04 + kolla 22.0.0 사용 |
| prechecks 이미지 없음 | `--use-test-images` 플래그 (prechecks 전용) |
| VIP 미부착 | keepalived-proxysql 순환 의존 → deploy 중 `exit 0` 루프 우회 |
| rp_filter 차단 | `sysctl -w net.ipv4.conf.all.rp_filter=2` |
| Octavia dhclient 없음 | `apt install isc-dhcp-client` (Ubuntu 24.04) |

전체 트러블슈팅 로그: [[02_QnA_Archive/2026-06-28-kolla-ansible-deploy-troubleshooting]]

## 관련 문서

- [[01_Concepts/Kolla-Ansible]]
- [[01_Concepts/OVN-OVS-Architecture]]
- [[01_Concepts/HA-Concepts]]
