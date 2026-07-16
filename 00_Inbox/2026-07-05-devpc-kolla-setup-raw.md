---
title: "개발계 pc(gaming 5) Kolla-Ansible 구성"
type: "raw"
date: 2026-07-05
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# 개발계 pc(gaming 5) Kolla-Ansible 구성

> 대상 서버: 개발계 (Gaming5 추정, 단일 NIC)
Public IP: .180
방식: 베어메탈 + Kolla-Ansible All-in-One (VLAN 분리 없음)
> 

---

## 0. 사전 조건 체크리스트

- [x]  서버가 72번 벽포트 → HPE OfficeConnect 1820 스위치에 물리적으로 연결됨
- [x]  Ubuntu 24.04 Server 설치 완료
- [x]  Public IP `.180` 할당 확인, 게이트웨이 `.254` 확인
- [x]  물리 NIC 1개만 존재 (온보드) — 이후 브릿지+veth 트릭 필요

---

## 1. 기본 시스템 준비

```bash
hostnamectl set-hostname su-cloud-dev
sudo apt update && sudo apt upgrade -y
timedatectl set-timezone Asia/Seoul

# NTP 동기화 (필수)
apt install -y chrony
systemctl enable --now chrony
```

---

## 2. 네트워크 준비 — 브릿지 + veth 트릭

물리 NIC가 하나뿐이라, 관리망(`network_interface`)과 외부망(`neutron_external_interface`)을 논리적으로 분리해야 함.

### 2-1. 개념

```
brbond0 (브릿지) ← enp7s0f0 (물리 NIC 편입)
brbond0 ← veth0 (veth pair 한쪽, 같이 브릿지에 편입)
veth1  (veth pair 반대쪽) → Neutron이 통째로 가져가서 br-ex로 편입
```

- 관리 IP(.180)는 **brbond0**에 부여 → `network_interface`
- **veth1**은 IP 없이 up 상태만 유지 → `neutron_external_interface`

### 2-2. 브릿지 생성 및 물리 NIC 편입

```bash
# 물리 NIC 이름 확인
ip link show

# 브릿지 생성
sudo ip link add name brbond0 type bridge
sudo ip link set brbond0 up

# 물리 NIC를 브릿지에 편입 (인터페이스명은 실제 확인한 이름으로 교체)
sudo ip link set enp7s0f0 down
sudo ip link set enp7s0f0 master brbond0
sudo ip link set enp7s0f0 up
```

### 2-3. veth pair 생성

```bash
sudo ip link add veth0 type veth peer name veth1

# veth0은 브릿지에 편입
sudo ip link set veth0 master brbond0
sudo ip link set veth0 up
sudo ip link set veth1 up
```

### 2-4. netplan으로 영구 설정

`/etc/netplan/50-cloud-init.yaml` (예시, 실제 인터페이스명/IP로 교체):

```yaml
network:
  version: 2
  ethernets:
    enp7s0f0:
      dhcp4: false
      match:
        macaddress: "88:ae:dd:5d:00:28"
      set-name: enp7s0f0
  bridges:
    brbond0:
      interfaces: [enp7s0f0]
      macaddress: "b0:38:6c:e1:a9:7f"
      addresses:
        - "210.94.240.180/24"
      nameservers:
        addresses:
          - 210.94.224.10
        search: []
      routes:
        - to: "default"
          via: "210.94.240.254"
```

> veth pair는 netplan에서 직접 지원이 약해서, systemd-networkd link 파일이나 `/etc/systemd/system/veth-setup.service` 같은 부팅 시 재생성 스크립트로 관리하는 걸 권장. (아래 참고용 유닛 예시)
> 

`/etc/systemd/system/veth-setup.service`:

```
[Unit]
Description=Create veth pair for Neutron external interface
After=systemd-networkd.service network-online.target
Wants=network-online.target
Requires=systemd-networkd.service

[Service]
Type=oneshot
ExecStartPre=/bin/sh -c 'until ip link show brbond0 >/dev/null 2>&1; do sleep 1; done'
ExecStartPre=-/sbin/ip link del veth0
ExecStart=/sbin/ip link add veth0 type veth peer name veth1
ExecStart=/sbin/ip link set veth0 master brbond0
ExecStart=/sbin/ip link set veth0 up
ExecStart=/sbin/ip link set veth1 up
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

```bash
# 검증
sudo netplan try

sudo systemctl daemon-reload
sudo systemctl enable veth-setup.service
sudo netplan apply
reboot
```

### 2-5. 재부팅 후 확인

```bash
# veth 데몬 확인 [active(exit)으로 나오면 성공]
systemctl status veth-setup.service

ip a show brbond0    # .180 IP 붙어있는지 확인
ip a show veth1      # up 상태, IP 없음 확인
ping -c 3 8.8.8.8    # 인터넷 확인
```

---

## 3. Kolla-Ansible 설치 (venv)

운영계에서 검증된 조합 그대로 사용: **Ubuntu 24.04 + kolla-ansible 22.0.0 + ansible-core 2.19.11**

```bash
sudo apt update
sudo apt install -y python3-dev python3-venv libffi-dev gcc git libdbus-1-dev libglib2.0-dev pkg-config

# 1. venv 자리 준비
sudo mkdir -p /opt/kolla-venv
sudo chown $USER:$USER /opt/kolla-venv

# 2. venv 생성 및 활성화
python3 -m venv /opt/kolla-venv
source /opt/kolla-venv/bin/activate

# 3. venv 안에서 패키지 설치 (sudo 없이! --break-system-packages도 불필요)
pip install -U pip
pip install docker
pip install dbus-python
pip install "ansible-core==2.19.11"
pip install kolla-ansible==22.0.0

# 4. 설정 파일 자리 준비 (venv와 무관, 별개 작업)
sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla

# 5. 예시 설정 파일들을 /etc/kolla로 복사 (sudo 없이, 이미 내 소유니까)
cp -r /opt/kolla-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/
cp /opt/kolla-venv/share/kolla-ansible/ansible/inventory/all-in-one /etc/kolla/
```

---

## 4. passwords.yml 생성

```bash
pip install "python-openstackclient" --break-system-packages
kolla-genpwd -p /etc/kolla/passwords.yml
```

---

## 5. globals.yml 핵심 설정

`/etc/kolla/globals.yml`:

```yaml
kolla_base_distro: "ubuntu"
openstack_release: "2026.1"

kolla_internal_vip_address: "210.94.240.180"

network_interface: "brbond0"
neutron_external_interface: "veth1"

# 최소 구성으로 시작 — 필요한 것만 켬
enable_cinder: "no"
enable_octavia: "no"
enable_swift: "no"
enable_haproxy: "no"     # All In One이라 불필요
enable_keepalived: "no"  # All In One이라 불필요
```

> 운영계에서 겪었던 ProxySQL/Keepalived 순환 의존, rabbit_stream_fanout 이슈 등은 all-in-one 단일 노드라 발생하지 않음 (멀티 컨트롤러 환경 전용 이슈였음).
> 
- 설정하는 법
    
    vi에서 `/` 검색으로 각 항목을 찾아서 고치시면 됩니다.
    
    ```
    :set number     " 줄 번호 보이게 (선택사항, 편함)
    ```
    
    **1. `kolla_base_distro` 찾기**
    
    ```
    /kolla_base_distro
    ```
    
    주석(`#`) 해제하고 값 확인/수정:
    
    ```yaml
    kolla_base_distro:"ubuntu"
    ```
    
    **2. `openstack_release` 찾기**
    
    ```
    /openstack_release
    ```
    
    ```yaml
    openstack_release:"2026.1"
    ```
    
    **3. `kolla_internal_vip_address` 찾기**
    
    ```
    /kolla_internal_vip_address
    ```
    
    ```yaml
    kolla_internal_vip_address:"210.94.240.180"
    ```
    
    **4. `network_interface` 찾기**
    
    ```
    /network_interface
    ```
    
    ```yaml
    network_interface:"brbond0"
    ```
    
    **5. `neutron_external_interface` 찾기**
    
    ```
    /neutron_external_interface
    ```
    
    ```yaml
    neutron_external_interface:"veth1"
    ```
    
    **6. `enable_haproxy`, `enable_keepalived` 찾기**
    
    ```
    /enable_haproxy
    ```
    
    ```yaml
    enable_haproxy:"no"
    ```
    
    ```
    /enable_keepalived
    ```
    
    ```yaml
    enable_keepalived:"no"
    ```
    
    **7. Cinder/Octavia/Swift도 명시적으로 꺼두고 싶으시면**
    
    ```
    /enable_cinder/enable_octavia/enable_swift
    ```
    
    각각 `"no"`로.
    
    **8. `docker_namespace` 찾기**
    
    ```bash
    /docker_namespace
    ```
    
    ```bash
    docker_namespace: "openstack.kolla"
    ```
    
    1. **`enable_proxysql` 찾기**
    
    ```bash
    /enable_proxysql
    ```
    
    ```bash
    enable_proxysql: "no"
    ```
    

---

## 6. inventory 확인

`/etc/kolla/all-in-one` 파일을 기본값 그대로 사용 (localhost 대상). 필요 시 `ansible_user`, `ansible_become` 정도만 확인.

```bash
cd /etc/kolla

sudo vi all-in-one
```

```bash
# 최상단에 추가

[all:vars]
ansible_python_interpreter=/opt/kolla-venv/bin/python3
```

```bash
# ping : pong 확인
ansible -i all-in-one all -m ping
```

---

## 7. 배포

```bash
# root계정 nopasswd 적용
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ubuntu-nopasswd > /dev/null
sudo chmod 0440 /etc/sudoers.d/ubuntu-nopasswd
sudo visudo -c
```

```bash
cd /etc/kolla

kolla-ansible install-deps

kolla-ansible bootstrap-servers -i all-in-one
```

```bash
# IPv4 forwarding 확인[0이면 꺼진상태]
sysctl net.ipv4.ip_forward

# IPv4 forwarding 켜기
sudo sysctl -w net.ipv4.ip_forward=1

# 영구반영
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-kolla-ip-forward.conf
sudo sysctl --system

# 재확인[1]
sysctl net.ipv4.ip_forward
```

```bash
# 그룹에 docker 추가됐는지 확인
getent group docker

# ubuntu 사용자를 docker에 추가
sudo groupadd docker 2>/dev/null
sudo usermod -aG docker $USER

# 재시작으로 적용
reboot

# 그룹 확인
groups

# docker 확인
docker pull hello-world
docker run hello-world
```

```bash
source /opt/kolla-venv/bin/activate

cd /etc/kolla

kolla-ansible prechecks -i all-in-one --use-test-images

kolla-ansible pull -i all-in-one

kolla-ansible deploy -i all-in-one

kolla-ansible post-deploy -i all-in-one
```

---

## 8. 검증

```bash
# openstack CLI 설치
pip install python-openstackclient

source /etc/kolla/admin-openrc.sh
openstack service list
openstack network agent list

# admin 비밀번호 확인
grep keystone_admin_password /etc/kolla/passwords.yml
```

- Horizon 웹 접속: `http://210.94.240.180/`
- 관리자 계정/비밀번호는 `/etc/kolla/passwords.yml`의 `keystone_admin_password` 확인

```bash
admin

JfAkaXhgAgqpcU74CZABjQ1imqkFurZSjM8lDglw
```

---

## 9. 개발계 Kolla-Ansible AIO 설치 — 트러블슈팅 정리

대상: 개발계 서버 (su-cloud-dev, 210.94.240.180) / 구성: Kolla-Ansible 22.0.0 + Ubuntu 24.04 + OpenStack 2026.1 All-in-One
결과: 배포 완료, Horizon/openstack CLI/Neutron 에이전트 전부 정상 확인 (2026-07-07)

---

## 0. 최종 검증 결과

| 항목 | 결과 |
| --- | --- |
| Horizon 대시보드 | `http://210.94.240.180/` 정상 접속, Compute 개요 페이지 확인 |
| `openstack service list` | heat-cfn, neutron, nova, placement, heat, keystone, glance — 7개 서비스 정상 등록 |
| `openstack network agent list` | Metadata/DHCP/L3/Open vSwitch agent 전부 `Alive: :-)`, `State: UP` |

---

## 1. Docker 그룹 권한 미반영

**증상**: `bootstrap-servers` 성공 후 `docker pull hello-world` 시 `permission denied ... docker.sock`

**원인**: `bootstrap-servers`가 사용자를 docker 그룹에 추가했지만, 그룹 멤버십은 로그인 세션 갱신이 필요함. 게다가 최초엔 docker 그룹 자체가 없었음 (`groups` 명령에 docker 미포함)

**해결**:

```bash
sudo usermod -aG docker $USER
sudo reboot     # newgrp으로 임시 전환하는 것보다 재부팅이 확실
```

---

## 2. IPv4 Forwarding 비활성화

**증상**: `docker run hello-world` 시 `WARNING: IPv4 forwarding is disabled. Networking will not work.`

**원인**: OpenStack 인스턴스 네트워킹(Neutron 라우팅)에 필수적인 커널 설정이 꺼져 있었음

**해결**:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-kolla-ip-forward.conf
sudo sysctl --system
sudo systemctl restart docker    # 커널 값만 바꿔선 안 되고, docker 데몬도 재시작해야 반영됨
```

---

## 3. prechecks — [quay.io](http://quay.io/) 이미지 네임스페이스 검증 실패

**증상**:

```
Kolla images from quay.io/openstack.kolla namespace are meant only for testing purposes
```

**원인 분석 과정**:

1. 처음엔 `docker_registry`를 `"docker.io"`로 오버라이드해서 이 assertion을 우회 시도 → prechecks는 통과했으나, 실제 `deploy`에서 `docker.io/openstack.kolla/kolla-toolbox` 이미지가 **존재하지 않아** pull 실패
2. 확인 결과, kolla-ansible 2026.1(현재 버전) 정식 이미지는 [**quay.io/openstack.kolla**](http://quay.io/openstack.kolla)에만 존재. `docker_registry` 기본값 자체가 quay.io였음

**최종 해결**:

```yaml
# globals.yml — docker_registry는 손대지 않고 기본값(quay.io) 유지
#docker_registry:
docker_namespace: "openstack.kolla"
```

```bash
kolla-ansible prechecks -i all-in-one --use-test-images
kolla-ansible pull -i all-in-one
kolla-ansible deploy -i all-in-one --use-test-images
```

**교훈**: `--use-test-images`라는 이름 때문에 "가짜/저품질 이미지"로 오해하기 쉬우나, 실제로는 이 버전의 **유일한 정식 배포 이미지 경로([quay.io/openstack.kolla](http://quay.io/openstack.kolla))를 쓰겠다고 확인하는 플래그**일 뿐. `docker_registry`를 임의로 다른 값으로 바꾸는 게 오히려 문제를 만듦 — 기본값을 건드리지 말고 플래그로 허용하는 게 정답.
**pull에는 이 플래그 자체가 존재하지 않음** (`unrecognized arguments: --use-test-images`) — `pull`은 그냥 옵션 없이 실행.

---

## 4. deploy — MariaDB와 ProxySQL의 포트 충돌

**증상**: `deploy` 중 MariaDB 컨테이너가 계속 `Exited (1)`로 종료. 로그 확인 결과:

```
[ERROR] Can't start server: Bind on TCP/IP port: Address already in use
[ERROR] Do you already have another server running on port: 3306 ?
```

`sudo ss -tlnp | grep 3306` 확인 결과, **ProxySQL 프로세스가 이미 3306 포트를 점유** 중이었음

**원인**: AIO 구성이라 `enable_haproxy: "no"`, `enable_keepalived: "no"`로 꺼뒀지만, **`enable_proxysql`은 이 설정들과 무관하게 별도로 기본 활성화**되어 있었음. ProxySQL은 원래 멀티노드 환경에서 MariaDB/Galera 앞단 로드밸런서 역할인데, AIO(단일 노드)에는 불필요.

**해결**:

```yaml
# globals.yml에 명시적으로 추가
enable_proxysql: "no"
```

```bash
docker rm -f proxysql mariadb 2>/dev/null
sudo kill -9 <proxysql가 물고 있던 PID>   # ss -tlnp로 확인 후
sudo ss -tlnp | grep 3306    # 완전히 비어있는지 확인
kolla-ansible deploy -i all-in-one --use-test-images
```

**운영계(멀티노드)와의 차이 — 헷갈리지 말 것**:

- 운영계에서 썼던 `keepalived` ProxySQL 헬스체크 우회 루프(`check_alive_proxysql.sh`를 강제로 `exit 0` 처리)는 **"ProxySQL이 정상적으로 필요한 상황에서, keepalived 헬스체크 타이밍만 우회"**하는 것으로, 이번 케이스와는 다른 문제.
- 지금(AIO)은 ProxySQL 자체가 **필요 없는 상황**이므로, 헬스체크를 속이는 게 아니라 **`enable_proxysql: "no"`로 아예 끄는 것**이 정답.

---