---
title: "개발계 PC (Gaming5) Kolla-Ansible AIO 배포 가이드"
type: "guide"
date: 2026-07-05
tags: ["#guide", "#kolla-ansible", "#devpc", "#openstack"]
related_nodes: ["[[01_Concepts/Kolla-Ansible]]", "[[03_Guides/Kolla-Ansible-Install-Guide]]", "[[02_QnA_Archive/2026-07-05-devpc-180-network-failure-resolved]]", "[[03_Guides/Tailscale-Setup-Guide]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-07-05-devpc-kolla-setup-raw]]"
---

# 개발계 PC (Gaming5) Kolla-Ansible AIO 배포 가이드

## 개요

개발계 서버(Gaming5, 베어메탈 Ubuntu)에 물리 NIC가 1개뿐인 환경에서 Kolla-Ansible All-in-One(AIO)으로 OpenStack을 배포하는 가이드. 핵심은 **브리지+veth 트릭**으로 관리망과 외부망 NIC를 논리적으로 분리하는 것.

## 환경

- 서버: Lenovo IdeaCentre Gaming5 (개발계)
- OS: Ubuntu 24.04 Server (베어메탈)
- Public IP: `210.94.240.180`
- 물리 NIC: 1개 (`enp7s0f0`)
- 배포 방식: Kolla-Ansible AIO

---

## 단계별 절차

### Step 1. 기본 시스템 준비

```bash
hostnamectl set-hostname su-cloud-dev
sudo apt update && sudo apt upgrade -y
timedatectl set-timezone Asia/Seoul

# NTP 동기화 (필수)
apt install -y chrony
systemctl enable --now chrony
```

### Step 2. 네트워크 준비 — 브리지 + veth 트릭

**핵심 개념**: 물리 NIC가 하나뿐이라 관리망과 외부망을 논리적으로 분리해야 함.

```
brbond0 (브리지) ← enp7s0f0 (물리 NIC)
brbond0          ← veth0 (veth pair 한쪽)
veth1            → Neutron이 가져가서 br-ex로 편입 (IP 없음)
```

- 관리 IP(`.180`)는 `brbond0`에 부여 → `network_interface`
- `veth1`은 IP 없이 up 상태만 유지 → `neutron_external_interface`

```bash
# 브리지 생성
sudo ip link add name brbond0 type bridge
sudo ip link set brbond0 up

# 물리 NIC를 브리지에 편입
sudo ip link set enp7s0f0 down
sudo ip link set enp7s0f0 master brbond0
sudo ip link set enp7s0f0 up

# veth pair 생성
sudo ip link add veth0 type veth peer name veth1
sudo ip link set veth0 master brbond0
sudo ip link set veth0 up
sudo ip link set veth1 up
```

### Step 3. netplan 설정 (MAC 스푸핑 포함)

> ⚠️ 개발계 서버의 원래 MAC이 캠퍼스 스위치에서 차단되어 있으므로 팀원 노트북 MAC으로 스푸핑 필요. 자세한 사유: [[02_QnA_Archive/2026-07-05-devpc-180-network-failure-resolved]]

```yaml
# /etc/netplan/01-network.yaml
network:
  version: 2
  ethernets:
    enp7s0f0:
      match:
        macaddress: "88:ae:dd:5d:00:28"    # 원래 MAC
      set-name: enp7s0f0
      macaddress: "b0:38:6c:e1:a9:7f"      # 스푸핑할 MAC (노트북 등록 MAC)
  bridges:
    brbond0:
      interfaces: [enp7s0f0]
      addresses:
        - "210.94.240.180/24"
      nameservers:
        addresses: [210.94.224.10]
      routes:
        - to: "default"
          via: "210.94.240.254"
```

```bash
sudo netplan apply
```

### Step 4. Kolla-Ansible 설치

```bash
apt install -y python3-pip python3-venv
python3 -m venv /opt/kolla-venv
source /opt/kolla-venv/bin/activate

pip install kolla-ansible==22.0.0 ansible-core

# kolla-ansible 설정 파일 생성
mkdir -p /etc/kolla
cp /opt/kolla-venv/share/kolla-ansible/etc_examples/kolla/globals.yml /etc/kolla/
cp /opt/kolla-venv/share/kolla-ansible/etc_examples/kolla/passwords.yml /etc/kolla/
cp /opt/kolla-venv/share/kolla-ansible/ansible/inventory/all-in-one /etc/kolla/
```

### Step 5. globals.yml 핵심 설정

```yaml
# /etc/kolla/globals.yml
kolla_base_distro: "ubuntu"
openstack_release: "2026.1"
network_interface: "brbond0"              # 관리망
neutron_external_interface: "veth1"       # 외부망 (IP 없음)
kolla_internal_vip_address: "210.94.240.180"
enable_neutron_provider_networks: "yes"
neutron_plugin_agent: "ovn"
enable_octavia: "no"                       # AIO에서는 선택적
```

### Step 6. 비밀번호 생성 및 배포

```bash
kolla-genpwd   # /etc/kolla/passwords.yml 자동 생성

# SSH 키 준비 (로컬 → 자신에게)
ssh-keygen -t rsa -b 4096
ssh-copy-id root@localhost

# 사전 검사
kolla-ansible -i /etc/kolla/all-in-one bootstrap-servers
kolla-ansible -i /etc/kolla/all-in-one prechecks

# 배포
kolla-ansible -i /etc/kolla/all-in-one deploy
```

### Step 7. 배포 후 검증

```bash
# OpenStack 클라이언트 설치
kolla-ansible -i /etc/kolla/all-in-one post-deploy
source /etc/kolla/admin-openrc.sh

# 기본 네트워크 자원 생성
openstack network create --external --provider-physical-network physnet1 \
  --provider-network-type flat external-net
openstack subnet create --network external-net \
  --allocation-pool start=210.94.240.210,end=210.94.240.250 \
  --no-dhcp --gateway 210.94.240.254 \
  --subnet-range 210.94.240.0/24 external-subnet

# Horizon 접속 확인
curl http://210.94.240.180/
```

---

## 주의사항

- ⚠️ MAC 스푸핑 중 팀원 노트북과 **동시 연결 절대 금지** (IP/MAC 충돌)
- veth1은 IP가 없어야 함. 있으면 Neutron이 br-ex로 편입 시 충돌
- AIO는 단일 노드에 모든 서비스(controller+compute)가 올라감 → 부하 고려

## 관련 문서

- [[01_Concepts/Kolla-Ansible]]
- [[02_QnA_Archive/2026-07-05-devpc-180-network-failure-resolved]]
- [[03_Guides/Tailscale-Setup-Guide]]
