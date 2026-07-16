---
title: "Kolla Ansible 설치 로드맵 (Ubuntu 24.04)"
type: "raw"
date: 2026-06-21
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/Kolla-Ansible-Install-Guide]]"
---
# Kolla Ansible 설치 로드맵 (Ubuntu 24.04)

> **환경**: Proxmox `pve` / VMID 200~206 / OpenStack 2026.1 "Gazpacho"
**스택**: OVN + Cinder LVM + Swift + Octavia
**버전**: kolla-ansible 22.0.0 · ansible-core 2.19 · **Ubuntu 24.04 (Noble)**
> 

---

## 0. 노드 구성

| VMID | 이름 | IP (ens18) | Kolla 역할 |
| --- | --- | --- | --- |
| 200 | cjm-lb | 192.168.100.201 | **deploy host** (kolla-ansible 실행 전용) |
| — | VIP | 192.168.100.200 | keepalived가 관리 (별도 VM 아님) |
| 201 | cjm-ct01 | 192.168.100.202 | control + network + HAProxy |
| 202 | cjm-ct02 | 192.168.100.203 | control + network + HAProxy |
| 203 | cjm-ct03 | 192.168.100.204 | control + network + HAProxy |
| 204 | cjm-cp01 | 192.168.100.205 | compute |
| 205 | cjm-cp02 | 192.168.100.206 | compute |
| 206 | cjm-st01 | 192.168.100.207 | storage (Cinder LVM + Swift) |

### NIC 역할

| NIC | 용도 | 비고 |
| --- | --- | --- |
| `ens18` | 관리망 192.168.100.x | API · VXLAN 오버레이 · 스토리지 |
| `ens19` | 외부망 (IP 없음, UP) | neutron_external_interface → OVN br-ex |

> **수동 설치와 핵심 차이**
> 
> - 수동: brq / vxlan / netns / HAProxy 직접 구성 → 복잡
> - Kolla: `globals.yml`에 NIC 이름 두 개만 적으면 컨테이너가 전부 처리
> - `cjm-lb`는 OpenStack 서비스를 올리지 않고, deploy host 전용으로 전환

> **⚠️ Ubuntu 버전 주의**
kolla-ansible 20.x(2025.1)부터 Ubuntu 22.04 호스트 지원이 제거됨.
최신 22.x를 쓰려면 **반드시 Ubuntu 24.04 (Noble)** 사용.
ISO: `https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso`
> 

---

## Phase 0 — VM 초기화 · OS 재설치

Proxmox에서 VMID 200~206 전부 삭제 후 **Ubuntu 24.04** 클린 설치

### VM 스펙

| VM | CPU | RAM | 디스크 | CPU Type | NIC |
| --- | --- | --- | --- | --- | --- |
| cjm-lb | 1 | 1GB | 10GB | x86-64-v2-AES | ens18 |
| cjm-ct01~03 | 2 | 4GB | 40GB | x86-64-v2-AES | ens18 + ens19 |
| cjm-cp01~02 | 2 | 3.5GB | 50GB | **host** (중첩가상화) | ens18 + ens19 |
| cjm-st01 | 1 | 4GB | OS20 + Cinder50 + Swift30 | x86-64-v2-AES | ens18 |

설치 시 주의: `Set up this disk as an LVM group` **해제** (Kolla는 Docker라 불필요)

### 모든 VM 공통 체크리스트

```bash
# 0. 업데이트
sudo apt update && sudo apt upgrade -y

# 1. ens18 고정 IP 설정 (/etc/netplan/...)
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

# 3. passwordless sudo
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER

# 4. NIC 이름 확인 (ens18 / ens19 이어야 함)
ip -br a

# 5. Python3 확인 (Ubuntu 24.04 기본 = 3.12)
python3 --version
```

### cjm-lb → 나머지 노드 SSH 키 배포

```bash
# cjm-lb에서
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519

# 각 노드에 배포 (lb 자신 포함)
for ip in 201 202 203 204 205 206 207; do
    ssh-copy-id ubuntu@192.168.100.$ip
done

# 연결 확인
for ip in 201 202 203 204 205 206 207; do
    ssh ubuntu@192.168.100.$ip hostname
done
```

## ST01에 Cinder LVM 디스크 추가

```bash
# st01에서 실행
# 추가 디스크 확인 (sdb가 Cinder용 50GB 디스크)
lsblk

# LVM VG 생성
sudo pvcreate /dev/sdb
sudo vgcreate cinder-volumes /dev/sdb

# 확인
sudo vgs
```

---

## Phase 1 — Deploy host 준비 (`cjm-lb`에서만)

> Ubuntu 24.04 기본 Python이 3.12라 별도 3.11 설치 불필요.
kolla-ansible 22.0.0은 Python 3.11+ 요구 → 3.12로 충족.
> 

```bash
# 1. 패키지 설치
sudo apt update && sudo apt install -y python3-dev python3-venv libffi-dev gcc git

# 2. venv 생성 (기본 python3 = 3.12)
python3 -m venv ~/kolla-venv
source ~/kolla-venv/bin/activate

# 3. kolla-ansible 22.x 설치 (최신, Ubuntu 24.04)
pip install -U pip
pip install 'ansible-core==2.19.11'
pip install 'kolla-ansible==22.0.0'

# 4. 설정 파일 복사
sudo mkdir -p /etc/kolla && sudo chown $USER:$USER /etc/kolla
cp -r ~/kolla-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
cp ~/kolla-venv/share/kolla-ansible/ansible/inventory/multinode ~/multinode

# 5. ansible collection 설치
kolla-ansible install-deps

# 6. 확인
kolla-ansible --version
```

---

## Phase 2 — 설정 파일 작성

### `/etc/kolla/globals.yml`

```bash
sudo tee /etc/kolla/globals.yml <<'EOF'
kolla_base_distro: "ubuntu"
kolla_internal_vip_address: "192.168.100.200"

network_interface: "ens18"
neutron_external_interface: "ens19"
neutron_plugin_agent: "ovn"

enable_haproxy: "yes"
enable_cinder: "yes"
enable_cinder_backend_lvm: "yes"
enable_swift: "yes"
enable_octavia: "yes"
enable_valkey: "yes"

octavia_provider_drivers: "amphora:Amphora provider"
octavia_provider_agents: "amphora"

cinder_volume_group: "cinder-volumes"
cinder_cluster_name: "cinder-cluster"
cinder_enabled_backends:
  - name: lvm
    driver: lvm
EOF
```

> **OVN을 쓰면 달라지는 것**
> 
> - 수동 설치의 `qrouter` 네임스페이스, `brq`, `vxlan-*` 인터페이스 없음
> - 대신 논리 구조를 `ovn-nbctl show` / `ovn-sbctl show` 로 확인
> - 실제 패킷은 OVS가 처리하지만, 설정은 OVN이 추상화해서 관리

### `~/multinode` 인벤토리

```bash
# 기본 multinode 파일로 교체
cp ~/kolla-venv/share/kolla-ansible/ansible/inventory/multinode ~/multinode

# 상단 호스트 정의 부분만 수정
# control/network/loadbalancer 노드 설정
sed -i '/^\[control\]$/,/^\[/{/^\[control\]$/!{/^\[/!d}}' ~/multinode
sed -i '/^\[control\]$/a ct01 ansible_host=192.168.100.202 ansible_user=ubuntu\nct02 ansible_host=192.168.100.203 ansible_user=ubuntu\nct03 ansible_host=192.168.100.204 ansible_user=ubuntu' ~/multinode

sed -i '/^\[network\]$/,/^\[/{/^\[network\]$/!{/^\[/!d}}' ~/multinode
sed -i '/^\[network\]$/a ct01 ansible_host=192.168.100.202 ansible_user=ubuntu\nct02 ansible_host=192.168.100.203 ansible_user=ubuntu\nct03 ansible_host=192.168.100.204 ansible_user=ubuntu' ~/multinode

sed -i '/^\[compute\]$/,/^\[/{/^\[compute\]$/!{/^\[/!d}}' ~/multinode
sed -i '/^\[compute\]$/a cp01 ansible_host=192.168.100.205 ansible_user=ubuntu\ncp02 ansible_host=192.168.100.206 ansible_user=ubuntu' ~/multinode

sed -i '/^\[storage\]$/,/^\[/{/^\[storage\]$/!{/^\[/!d}}' ~/multinode
sed -i '/^\[storage\]$/a st01 ansible_host=192.168.100.207 ansible_user=ubuntu' ~/multinode

sed -i '/^\[monitoring\]$/,/^\[/{/^\[monitoring\]$/!{/^\[/!d}}' ~/multinode
sed -i '/^\[monitoring\]$/a ct01 ansible_host=192.168.100.202 ansible_user=ubuntu' ~/multinode

sed -i '/^\[loadbalancer:children\]$/a control' ~/multinode
```

### multinode 파일 역할

```
kolla-ansible deploy 실행
       ↓
multinode 파일 읽음
       ↓
"ct01~03은 [control] 그룹이니까 Keystone, Nova-API, Neutron 컨테이너 올려"
"cp01~02는 [compute] 그룹이니까 nova-compute 컨테이너 올려"
"st01은 [storage] 그룹이니까 Cinder, Swift 컨테이너 올려"
       ↓
각 노드에 SSH로 접속해서 해당 컨테이너 배포
```

| 그룹 | 역할 |
| --- | --- |
| `[control]` | Keystone, Glance, Nova-API, Neutron-server, MariaDB, RabbitMQ, Memcached |
| `[network]` | OVN, DHCP agent, L3 agent |
| `[compute]` | nova-compute, OVS agent |
| `[storage]` | Cinder-volume, Swift |
| `[loadbalancer]` | HAProxy, Keepalived (VIP 관리) |
| `[monitoring]` | Fluentd 로그 수집 |
| `[bifrost]` | 베어메탈 프로비저닝 (미사용, 빈 그룹만 필요) |
| `[deployment]` | kolla-ansible 실행 노드 (=lb, localhost) |

### 비밀번호 생성

```bash
kolla-genpwd    # /etc/kolla/passwords.yml 자동 채움
```

---

## Phase 3 — 배포

lb 노드에서 배포

```bash
source ~/kolla-venv/bin/activate

# 0. octavia 인증서 발급
kolla-ansible octavia-certificates -i ~/multinode

# 1. 호스트 준비 (Docker 설치 등)
kolla-ansible bootstrap-servers -i ~/multinode

# 1.5 ct 노드에 rp_filter 설정 추가
for ip in 202 203 204; do
    ssh ubuntu@192.168.100.$ip \
        "echo 'net.ipv4.conf.all.rp_filter=0' | sudo tee /etc/sysctl.d/99-kolla.conf && \
         echo 'net.ipv4.conf.ens18.rp_filter=0' >> /etc/sysctl.d/99-kolla.conf"
done

# 2. 사전 점검 — 여기서 오류 잡고 넘어가기
kolla-ansible prechecks -i ~/multinode --use-test-images

# 2.5 이미지 미리 다운로드 (네트워크 불안정 대비)
kolla-ansible pull -i ~/multinode

# 3. 실제 배포 전 — keepalived ProxySQL 체크 우회 루프 실행
# 터미널 2에서 실행 후 유지:
set +H
while true; do
    for ip in 202 203 204; do
        ssh -o StrictHostKeyChecking=no ubuntu@192.168.100.$ip \
            "sudo docker exec keepalived sh -c 'printf \"#!/bin/sh\nexit 0\n\" > /checks/check_alive_proxysql.sh' 2>/dev/null"
    done
    sleep 5
done
set -H

# 4. 실제 배포 (30~60분)
kolla-ansible deploy -i ~/multinode

# 5. admin 자격증명 생성
kolla-ansible post-deploy -i ~/multinode

# (참고)모든 컨테이너 정리
kolla-ansible destroy -i ~/multinode --yes-i-really-really-mean-it
```

### prechecks 주요 실패 원인

| 오류 | 원인 | 해결 |
| --- | --- | --- |
| `release jammy not supported` | Ubuntu 22.04 사용 | **24.04로 재설치** |
| `loadbalancer group does not exist` | 인벤토리에 그룹 누락 | `[loadbalancer]` 추가 |
| `has no attribute 'bifrost'` | bifrost 그룹 누락 | 빈 `[bifrost]` 추가 |
| interface not found | NIC 이름 오타 | `ip -br a` 로 확인 |
| external interface has IP | ens19에 IP 있음 | netplan에서 ens19 IP 제거 |
| SSH connection failed | 키 배포 안 됨 | ssh-copy-id 재실행 |
- keepalived ProxySQL 체크 우회 루프
    
    deploy 중에 keepalived 컨테이너가 재시작될 때마다 원본 스크립트가 복원되기 때문에, 5초마다 강제로 `exit 0` 스크립트로 덮어써서 VIP가 계속 살아있게 유지하는 겁니다.
    
    ```bash
    set +H          # bash 히스토리 확장 비활성화 (! 문자 오류 방지)
    while true; do  # 무한 반복
        for ip in 202 203 204; do   # ct01, ct02, ct03 순서로
            ssh ... ubuntu@192.168.100.$ip \
                "sudo docker exec keepalived sh -c \
                'printf \"#!/bin/sh\nexit 0\n\" > /checks/check_alive_proxysql.sh'"
            # keepalived 컨테이너 안의 proxysql 체크 스크립트를
            # "항상 성공(exit 0)" 으로 5초마다 덮어씀
        done
        sleep 5     # 5초 대기 후 반복
    done
    ```
    

### 배포 확인

```bash
# openstack CLI 설치 (deploy host에서)
pip install python-openstackclient

source /etc/kolla/admin-openrc.sh
openstack service list
openstack network agent list

# Horizon접속: http://192.168.100.200
# admin 비밀번호 확인
grep keystone_admin_password /etc/kolla/passwords.yml
```

ID: `admin`

PW: 위 명령어 출력값

---

## Phase 4 — 초기 리소스 생성

```bash
source /etc/kolla/admin-openrc.sh

# 외부 네트워크 (관리망과 같은 대역, floating IP 범위만 지정)
openstack network create --external --provider-network-type flat \
  --provider-physical-network physnet1 external-net

openstack subnet create --network external-net \
  --subnet-range 192.168.100.0/24 \
  --gateway 192.168.100.1 \
  --no-dhcp \
  --allocation-pool start=192.168.100.210,end=192.168.100.250 \
  external-subnet

# 테넌트 네트워크
openstack network create internal-net
openstack subnet create --network internal-net \
  --subnet-range 172.22.0.0/24 \
  --gateway 172.22.0.1 internal-subnet

# 라우터
openstack router create main-router
openstack router set main-router --external-gateway external-net
openstack router add subnet main-router internal-subnet

# cirros 이미지
wget https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
openstack image create cirros --disk-format qcow2 \
  --container-format bare --public \
  --file cirros-0.6.2-x86_64-disk.img

# flavor
openstack flavor create --ram 512 --disk 1 --vcpus 1 m1.tiny

# 보안그룹 (ping + SSH 허용)
openstack security group create test-sg --description "test security group"
openstack security group rule create --proto icmp test-sg
openstack security group rule create --proto tcp --dst-port 22 test-sg

# VM 생성할 때 이 보안그룹 지정
openstack server create --flavor m1.tiny --image cirros \
  --network internal-net \
  --security-group test-sg \
  test-vm

# floating IP
openstack floating ip create external-net
openstack server add floating ip test-vm <floating-ip>

# vm으로 핑 테스트 및 접속 테스트
ping -c 3 <floating-ip>
ping -c 3 192.168.100.243

ssh cirros@192.168.100.243 # PW: gocubsgo

# vm안에서 인터넷 연결 확인
ping -c 3 8.8.8.8
```

---

## Phase 5 — 네트워크 흐름 확인

### OVN 논리 구조 확인

```bash
# 논리 라우터/스위치 전체 보기
ssh ubuntu@192.168.100.202 "sudo docker exec ovn_northd ovn-nbctl show"

# 실제 바인딩 (어느 노드가 어느 포트 담당)
ssh ubuntu@192.168.100.202 "sudo docker exec ovn_northd ovn-sbctl show"

# 논리 플로우 (패킷이 어떤 규칙을 탐)
ssh ubuntu@192.168.100.202 "sudo docker exec ovn_northd ovn-sbctl lflow-list"
```

### VM → 인터넷 흐름 (OVN 기준)

```bash
switch (internal-net)          ← 수동 설치의 brq1cb278e6-00 역할
  port 172.22.0.154            ← cirros VM
  port 172.22.0.2 (localport) ← DHCP
  port (router)                ← 라우터 연결 포트

switch (external-net)          ← 수동 설치의 brq634db776-28 역할
  port (localnet)              ← ens19 물리 연결
  port (router)                ← 라우터 연결 포트

router (main-router)           ← 수동 설치의 qrouter 네임스페이스 역할
  lrp (external측) 192.168.100.221/24
    gateway chassis: [ct01, ct03, ct02]  ← 실제로 어느 ct가 라우터 담당할지
  lrp (internal측) 172.22.0.1/24
  nat 192.168.100.243 → 172.22.0.154   ← floating IP (DNAT)
  nat 192.168.100.221 → 172.22.0.0/24  ← SNAT (인터넷 출구)
```

```
VM (cirros)
 └ OVS port (cp01)
    └ OVN logical switch (internal-net)
       └ OVN logical router (main-router)
          └ SNAT → OVN gateway chassis (ct 중 1대)
             └ br-ex → ens19
                └ Proxmox natzone → 인터넷
```

> 수동 설치의 `ip netns exec qrouter-...` 대신,
OVN은 **논리 라우터**가 어느 물리 노드(gateway chassis)에서 실행될지를 자동으로 선택.
`ovn-sbctl show` 에서 `Gateway_Chassis` 항목으로 확인.
> 

### 실제 패킷 캡처

```bash
# cirros VM에서 ping 날리면서
ping 8.8.8.8

# gateway chassis 확인 (어느 ct가 라우터 트래픽 담당하는지)
ssh ubuntu@192.168.100.202 "sudo docker exec ovn_northd ovn-sbctl find port_binding type=chassisredirect | grep -E 'chassis|logical_port'"

# chassis UUID → 호스트명 매핑
ssh ubuntu@192.168.100.202 "sudo docker exec ovn_northd ovn-sbctl list chassis | grep -E '_uuid|hostname'"

# gateway chassis 역할을 맡은 ct 노드에서 캡처
ssh ubuntu@192.168.100.${gateway chassis ct ip} "sudo tcpdump -ni ens19 icmp -e"
```

```bash
fa:16:3e:2f:30:1e > 86:97:4e:2a:67:bc
192.168.100.243 > 8.8.8.8: ICMP echo request

fa:16:3e:2f:30:1e  ← OVN 라우터(main-router)의 external 포트 MAC
86:97:4e:2a:67:bc  ← Proxmox natzone 게이트웨이 MAC
192.168.100.243    ← floating IP (SNAT된 주소)
```

---

# Phase 6 — Octavia (Amphora LBaaS) 구성

> **환경**: Kolla-Ansible 22.0.0 / OpenStack 2026.1 Gazpacho / Ubuntu 24.04
**네트워킹**: OVN / lb-mgmt-net `10.1.0.0/24`**결과**: Amphora LB `ACTIVE` / `ONLINE` + 실제 HTTP 트래픽 전달 확인 완료
> 

---

## 전체 흐름 요약

```
amphora 이미지 빌드 (diskimage-create.sh)
  └ Glance 등록 (visibility: community)
     └ globals.yml 설정 추가 (octavia_network_type, octavia_amp_network)
        └ kolla-ansible deploy --tags octavia
           └ isc-dhcp-client 설치 (Ubuntu 24.04 누락 패키지)
              └ octavia-interface 서비스 시작 → o-hm0 IP 할당
                 └ health-manager bind_ip 수정 (0.0.0.0 + o-hm0 IP)
                    └ kolla-ansible reconfigure --tags octavia
                       └ LB 생성 → ACTIVE / HTTP 트래픽 전달 확인
```

---

### Amphora 이미지 빌드

### 의존성 설치

```bash
sudo apt-get install -y debootstrap qemu-utils git kpartx
```

> **주의**: `debootstrap` 없으면 빌드가 에러 없이 종료되지만 `.qcow2` 파일이 생성되지 않음.
> 

### 빌드 실행

```bash
cd /tmp/octavia/diskimage-create/
./diskimage-create.sh -a amd64 -o /tmp/amphora-x64-haproxy -t qcow2 2>&1 | tee /tmp/dib-build.log
```

빌드 시간: 약 10~20분. 완료 후 확인:

```bash
ls -lh /tmp/amphora-x64-haproxy.qcow2
# 정상: 약 360MB
```

> **참고**: `stat: cannot statx '/tmp/amphora-x64-haproxy'` 경고는 스크립트 버그로 무시해도 됨.
> 

---

### Glance 이미지 등록

반드시 **octavia 서비스 계정**으로 등록해야 함.

```bash
. /etc/kolla/octavia-openrc.sh

openstack image create amphora-x64-haproxy \
  --container-format bare \
  --disk-format qcow2 \
  --private \
  --tag amphora \
  --file /tmp/amphora-x64-haproxy.qcow2

openstack image list --tag amphora
```

### visibility를 community로 변경

`private`으로 등록하면 octavia worker가 이미지를 찾지 못함. 반드시 `community`로 변경:

```bash
IMAGE_ID=$(openstack image list --tag amphora -f value -c ID)
openstack image set $IMAGE_ID --community
openstack image show $IMAGE_ID | grep visibility
# visibility | community
```

> **트러블슈팅**: `ImageGetException: Failed to retrieve image with amphora tag`
octavia worker가 Glance에서 태그로 이미지를 조회할 때 `private` 이미지는
소유 프로젝트 외에서 보이지 않음. `community`로 변경하면 해결.
> 

---

### globals.yml 설정 추가

```bash
cat >> /etc/kolla/globals.yml <<'EOF'

# Octavia network type: tenant = OVN br-int에 o-hm0을 붙이는 방식
# 기본값이 "provider"라서 명시적으로 지정 필요
octavia_network_type: "tenant"

# Amphora 관리 네트워크 설정 (딕셔너리 형태로 입력 필수)
octavia_amp_network:
  name: "lb-mgmt-net"
  external: false
  subnet:
    name: "lb-mgmt-subnet"
    cidr: "10.1.0.0/24"
    no_gateway_ip: true
    enable_dhcp: true
    ip_version: 4
EOF
```

> **주의 1**: `octavia_network_type` 기본값은 `"provider"`.
`"tenant"`로 설정해야 `hm-interface.yml` 태스크가 실행되어 o-hm0 인터페이스가 생성됨.
> 

> **주의 2**: `octavia_amp_network`는 반드시 딕셔너리 형태로 입력.
문자열(`"lb-mgmt-net"`)로 입력하면 `object of type 'str' has no attribute 'name'` 에러 발생.
> 

---

### kolla-ansible deploy

```bash
source ~/kolla-venv/bin/activate
kolla-ansible deploy -i ~/multinode --tags octavia
```

이 단계에서 octavia-interface 서비스 파일이 생성되지만, Ubuntu 24.04에
`dhclient`가 없어서 서비스 시작 실패 → Step 5에서 해결.

---

### isc-dhcp-client 설치

Ubuntu 24.04는 기본적으로 `dhclient`가 없음.
`octavia-interface.service`가 `dhclient`로 o-hm0 IP를 할당하므로 반드시 설치:

```bash
for ip in 202 203 204; do
    ssh ubuntu@192.168.100.$ip "sudo apt-get install -y isc-dhcp-client"
done
```

설치 후 서비스 시작 및 부팅 자동 시작 등록:

```bash
for ip in 202 203 204; do
    ssh ubuntu@192.168.100.$ip \
        "sudo systemctl restart octavia-interface && \
         sudo systemctl enable octavia-interface"
done
```

o-hm0 IP 할당 확인:

```bash
for ip in 202 203 204; do
    echo "=== ct0$((ip-201)) ==="
    ssh ubuntu@192.168.100.$ip "ip addr show o-hm0"
done
```

정상 출력 예시:

```
10: o-hm0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1442 ...
    inet 10.1.0.74/24 brd 10.1.0.255 scope global dynamic o-hm0
```

본 환경 o-hm0 IP:

- ct01: `10.1.0.74`
- ct02: `10.1.0.167`
- ct03: `10.1.0.21`

---

### health-manager bind_ip 수정

deploy 후 health-manager의 `bind_ip`가 관리망(192.168.100.x)으로 설정됨.
o-hm0 IP로 수신해야 amphora VM과 통신 가능하므로 오버라이드 설정 추가:

```bash
mkdir -p /etc/kolla/config/octavia

cat > /etc/kolla/config/octavia/octavia-health-manager.conf <<'EOF'
[health_manager]
bind_ip = 0.0.0.0
controller_ip_port_list = 10.1.0.74:5555,10.1.0.167:5555,10.1.0.21:5555
EOF
```

설정 반영:

```bash
kolla-ansible reconfigure -i ~/multinode --tags octavia
```

반영 확인:

```bash
for ip in 202 203 204; do
    echo "=== ct0$((ip-201)) ==="
    ssh ubuntu@192.168.100.$ip \
        "sudo docker exec octavia_health_manager \
         cat /etc/octavia/octavia.conf | grep -E 'bind_ip|controller_ip'"
done
# bind_ip = 0.0.0.0
# controller_ip_port_list = 10.1.0.74:5555,10.1.0.167:5555,10.1.0.21:5555
```

---

### LB 생성 및 동작 검증

### LB 생성

```bash
source /etc/kolla/admin-openrc.sh

openstack loadbalancer create \
  --name test-lb \
  --vip-subnet-id internal-subnet

watch openstack loadbalancer show test-lb
# 약 1~2분 후: provisioning_status = ACTIVE, operating_status = ONLINE
```

Amphora VM 확인:

```bash
openstack server list --all-projects | grep amphora
# amphora-XXXX | ACTIVE | internal-net=172.22.0.x; lb-mgmt-net=10.1.0.x
```

### Listener / Pool / Member 구성

```bash
# Listener (80 포트 HTTP)
openstack loadbalancer listener create \
  --name test-listener \
  --protocol HTTP \
  --protocol-port 80 \
  test-lb

# Pool (ROUND_ROBIN)
openstack loadbalancer pool create \
  --name test-pool \
  --lb-algorithm ROUND_ROBIN \
  --listener test-listener \
  --protocol HTTP

# 백엔드 VM 보안그룹에 80 포트 허용
openstack security group rule create \
  --proto tcp \
  --dst-port 80 \
  test-sg

# Member 추가 (백엔드 VM의 internal-net IP)
openstack loadbalancer member create \
  --name test-member \
  --address 172.22.0.154 \
  --protocol-port 80 \
  test-pool
```

### 동작 검증

백엔드 VM에 웹서버 실행:

```bash
ssh cirros@192.168.100.243
$ sudo busybox httpd -f -p 80 &
$ sudo netstat -tlnp | grep 80
# tcp 0 0 :::80 :::* LISTEN
```

VIP로 HTTP 요청:

```bash
$ curl -s http://172.22.0.21
# HTTP 응답 확인 (404 또는 파일 목록 = amphora haproxy 정상 동작)
```

---

### 트러블슈팅 전체 정리

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 빌드 완료 후 `.qcow2` 없음 | `debootstrap` 미설치 | `apt install debootstrap qemu-utils git kpartx` |
| `ImageGetException: Failed to retrieve image with amphora tag` | 이미지 visibility가 `private` | `openstack image set --community` |
| `object of type 'str' has no attribute 'name'` | `octavia_amp_network`를 문자열로 입력 | globals.yml에 딕셔너리 형태로 입력 |
| o-hm0 인터페이스 생성 안 됨 | `octavia_network_type` 기본값이 `provider` | globals.yml에 `octavia_network_type: "tenant"` 추가 |
| `octavia-interface.service` 시작 실패 | Ubuntu 24.04에 `dhclient` 없음 | `apt install isc-dhcp-client` (ct01~03 전체) |
| `ComputeWaitTimeoutException` + `No route to host 10.1.0.x:9443` | health-manager `bind_ip`가 관리망으로 설정됨 | `/etc/kolla/config/octavia/octavia-health-manager.conf`에서 `bind_ip = 0.0.0.0`, `controller_ip_port_list`를 o-hm0 IP로 변경 후 reconfigure |
| LB ACTIVE인데 `503 Service Unavailable` | 백엔드 VM 보안그룹에 80 포트 미허용 또는 웹서버 미실행 | `security group rule create --dst-port 80` + 웹서버 실행 확인 |

---

### Octavia 구성 개념

```
[Octavia 구성 요소]

octavia-api            <- LB 생성/조회 API
octavia-worker         <- Nova에 Amphora VM 생성 요청, haproxy 설정 주입
octavia-health-manager <- Amphora VM 상태 모니터링 (UDP 5555)
octavia-housekeeping   <- 만료된 Amphora 정리
octavia-driver-agent   <- provider 드라이버 통신

[트래픽 흐름]

클라이언트
  └ VIP (172.22.0.21:80)
     └ Amphora VM (172.22.0.158) haproxy
        └ Member (172.22.0.154:80) 백엔드 VM

[Amphora 관리 통신 경로]

octavia-worker
  └ Nova API → Amphora VM 생성 (lb-mgmt-net: 10.1.0.x)
     └ octavia-health-manager
          └ o-hm0 (10.1.0.x) <-> Amphora VM (10.1.0.x) UDP 5555 heartbeat
               └ HTTPS 9443으로 haproxy 설정 주입

[o-hm0 인터페이스 구조]

OVN br-int
  └ o-hm0 (type=internal, iface-id=<neutron port id>)
       └ dhclient -> 10.1.0.x/24 IP 할당
            └ lb-mgmt-net DHCP 서버가 IP 제공
```

---

### 참고: octavia.conf 핵심 설정값

```bash
ssh ubuntu@192.168.100.202 \
  "sudo docker exec octavia_api \
   cat /etc/octavia/octavia.conf | \
   grep -E 'amp_image_tag|amp_image_owner|amp_flavor|rabbit_stream|bind_ip|controller_ip'"
```

| 항목 | 값 | 설명 |
| --- | --- | --- |
| `amp_image_tag` | `amphora` | Glance 이미지 조회 태그 |
| `amp_image_owner_id` | octavia 프로젝트 ID | 이미지 소유자 프로젝트 |
| `amp_flavor_id` | amphora flavor UUID | Amphora VM 스펙 (Kolla 자동 생성) |
| `rabbit_stream_fanout` | `false` | RabbitMQ stream queue 에러 방지 |
| `bind_ip` | `0.0.0.0` | health-manager 수신 IP |
| `controller_ip_port_list` | `10.1.0.x:5555,...` | Amphora heartbeat 수신 주소 |