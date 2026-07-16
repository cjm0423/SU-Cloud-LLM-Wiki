---
title: "OpenStack 7-Node HA 수동 설치 가이드 (개요)"
type: "guide"
date: 2026-06-14
tags: ["#guide", "#openstack", "#ha", "#manual-install"]
status: "stable"
related_nodes: ["[[01_Concepts/HA-Concepts]]", "[[01_Concepts/OpenStack-Overview]]", "[[03_Guides/Kolla-Ansible-Install-Guide]]", "[[03_Guides/Proxmox-Installation-Guide]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-06-14-openstack-manual-install-raw]]"
---

# OpenStack 7-Node HA 수동 설치 가이드 (개요)

## 개요

제한된 자원(8 Cores, 24GB RAM) 내에서 3-Controller HA + Load Balancer 분리 아키텍처를 구현하는 초경량 PoC 설계. Kolla-Ansible 도입 전 수동 설치 실습용.

> **전체 상세 설치 절차 (107KB):** [[00_Inbox/2026-06-14-openstack-manual-install-raw]]
> 실제 배포에는 **Kolla-Ansible** 사용 권장 → [[03_Guides/Kolla-Ansible-Install-Guide]]

---

## 노드 구성 (7대)

| VM | 수량 | CPU | RAM | 디스크 | 역할 |
|----|------|-----|-----|--------|------|
| openstack-lb | 1대 | 1 | 1GB | 10GB | HAProxy, Keepalived (VIP 관리) |
| openstack-ct01~03 | 3대 | 2 | 4GB | 40GB | Controller (Keystone, Glance, Nova-API, DB, MQ) |
| openstack-cp01~02 | 2대 | 2 | 3.5GB | 50GB | Compute (Nova-Compute, **CPU Type: host 필수**) |
| openstack-st01 | 1대 | 1 | 4GB | OS 20GB + Cinder 50GB + Swift 30GB | Storage |

**총 자원:** CPU 8 Cores (1.5배 오버커밋 허용), RAM 24GB, Storage 300GB

---

## 네트워크 구성 (2-NIC)

| NIC | 네트워크 | 역할 |
|-----|---------|------|
| ens18 (vmnet) | 192.168.100.x | 관리망 (API, DB, MQ, VXLAN) |
| ens19 (vmbr0) | 외부망 | Neutron external (br-ex) |

**IP 배정 계획:**
```
VIP: 192.168.100.200   (Keepalived)
lb:  192.168.100.201
ct01: 192.168.100.202
ct02: 192.168.100.203
ct03: 192.168.100.204
cp01: 192.168.100.205
cp02: 192.168.100.206
st01: 192.168.100.207
```

---

## 설치 순서 (개요)

### Phase 1. Proxmox VM 생성

1. 모든 VM을 Ubuntu 22.04 LTS로 설치
2. **Compute 노드**: CPU Type을 반드시 `host`로 (중첩 가상화)
3. **Storage 노드**: 빈 디스크(sdb) 추가 마운트 (Cinder LVM용)
4. **Memory Ballooning 해제** 필수 (DB 즉사 방지)
5. 모든 VM에 ens18(vmnet) + ens19(vmbr0) 2개 NIC 추가

### Phase 2. 기본 시스템 설정 (7대 공통)

```bash
# 1. 패키지 업데이트
apt update && apt upgrade -y
timedatectl set-timezone Asia/Seoul
apt install -y chrony
systemctl enable --now chrony

# 2. ens18 고정 IP 설정 (각 노드별)
# /etc/netplan/50-cloud-init.yaml 수정

# 3. ens19 IP 없이 UP
tee /etc/netplan/51-ens19.yaml << 'EOF'
network:
  version: 2
  ethernets:
    ens19:
      dhcp4: false
      dhcp6: false
EOF
netplan apply
```

### Phase 3. 핵심 서비스 설치 순서

```
1. MariaDB Galera (ct01~03) — Quorum 구성
2. RabbitMQ 클러스터 (ct01~03)
3. Memcached (ct01~03)
4. Keystone (ct01~03)
5. Glance (ct01~03)
6. Nova (ct01~03 + cp01~02)
7. Neutron (ct01~03 + cp01~02)
8. Cinder (ct01~03 + st01)
9. Horizon (ct01)
10. HAProxy + Keepalived (lb)
```

### Phase 4. 네트워크 자원 생성

```bash
source /etc/openstack/admin-openrc.sh

# Provider network (flat)
openstack network create \
  --share --external \
  --provider-physical-network provider \
  --provider-network-type flat provider

# Subnet
openstack subnet create \
  --network provider \
  --allocation-pool start=192.168.100.210,end=192.168.100.250 \
  --no-dhcp --gateway 192.168.100.1 \
  --subnet-range 192.168.100.0/24 provider-subnet

# Self-service network
openstack network create selfservice
openstack subnet create \
  --network selfservice \
  --gateway 172.16.1.1 \
  --subnet-range 172.16.1.0/24 selfservice-subnet

# Router
openstack router create router
openstack router add subnet router selfservice-subnet
openstack router set --external-gateway provider router
```

---

## 수동 설치 vs Kolla-Ansible 비교

| 항목 | 수동 설치 | Kolla-Ansible |
|------|---------|--------------|
| 학습 효과 | ✅ 높음 (내부 구조 파악) | △ 낮음 |
| 설치 시간 | ❌ 수 일~수 주 | ✅ 30~60분 |
| 안정성 | △ 실수 여지 많음 | ✅ 검증된 절차 |
| 버전 관리 | ❌ 수동 | ✅ 자동 |
| 권장 용도 | 학습/이해용 | 실제 배포용 |

## 관련 문서

- [[03_Guides/Kolla-Ansible-Install-Guide]] — 실제 배포에 권장
- [[01_Concepts/HA-Concepts]] — HAProxy, Keepalived, Galera 개념
- [[01_Concepts/OpenStack-Overview]]
- [[01_Concepts/OVN-Network-Flow]]
