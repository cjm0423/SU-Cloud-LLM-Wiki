---
title: "Kolla-Ansible 실습 해설"
type: "raw"
date: 2026-06-21
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# Kolla-Ansible 실습 해설

> **환경**: OpenStack 2026.1 Gazpacho · OVN + Cinder + Swift + Octavia
**버전**: Ubuntu 24.04 / Kolla-Ansible 22.0.0 / Proxmox 환경 기준
> 

---

## 배경: 수동 설치와 Kolla-Ansible의 차이

| 항목 | 수동 설치 | Kolla-Ansible |
| --- | --- | --- |
| 네트워크 드라이버 | LinuxBridge + VXLAN | OVS + Geneve (OVN) |
| 라우터 관리 | `ip netns exec qrouter-...` | `ovn-nbctl` / `ovn-sbctl` |
| HA 구성 | HAProxy 직접 설치 + keepalived 수동 | `globals.yml`에 `enable_haproxy: yes` 한 줄 |
| 서비스 재시작 | 각 노드에 `systemctl` 직접 실행 | `kolla-ansible reconfigure --tags <서비스>` |
| 설정 파일 위치 | `/etc/nova/nova.conf` 등 직접 편집 | `/etc/kolla/config/` 아래에만 오버라이드 |
| 멀티노드 구성 | 노드마다 개별 작업 | multinode 인벤토리에 IP만 적으면 자동 배포 |

> 💡 **핵심 변화**
Kolla는 모든 OpenStack 서비스를 **Docker 컨테이너**로 실행한다. "어떤 서비스가 어느 노드에서 어떻게 실행되는가"를 개발자가 직접 추적할 필요 없이, Ansible이 멱등하게 관리해준다.
> 

---

## Phase 0 — VM 초기화 및 OS 재설치

### 왜 Ubuntu 24.04인가?

Kolla-Ansible 20.x (OpenStack 2025.1 Caracal)부터 Ubuntu 22.04 (Jammy) 호스트 지원이 공식 제거됐다. Kolla 22.x를 쓰려면 반드시 **Ubuntu 24.04 (Noble)** 가 필요하다.

> ⚠️ **주의**
prechecks 단계에서 `release jammy not supported` 오류가 발생하면 OS를 24.04로 재설치하는 것 외에 해결 방법이 없다. 이것이 Phase 0에서 가장 먼저 OS 버전을 확정하는 이유다.
> 

### VM 역할 분리 구조

| VM | IP (ens18) | 역할 | 분리 이유 |
| --- | --- | --- | --- |
| cjm-lb | 192.168.100.201 | Deploy host 전용 | Ansible을 실행하는 노드는 배포 대상과 분리해야 패키지 의존성이 충돌하지 않는다 |
| VIP | 192.168.100.200 | keepalived Virtual IP | ct01~03 중 누가 살아있든 API 엔드포인트(.200)는 항상 같은 주소로 유지됨 |
| cjm-ct01~03 | 192.168.100.202~204 | Control + Network + HAProxy | 컨트롤플레인 3중화. 하나가 죽어도 keepalived가 VIP를 살아있는 노드로 이전 |
| cjm-cp01~02 | 192.168.100.205~206 | Compute | 실제 VM (Nova instance)이 여기서 실행됨. CPU Type을 `host`로 설정해야 중첩 가상화 가능 |
| cjm-st01 | 192.168.100.207 | Cinder LVM + Swift | 스토리지만 담당. 추후 디스크 확장이나 Swift 노드 추가 시 이 그룹만 건드리면 됨 |

### NIC 2개 구성의 이유

컨트롤/컴퓨트 노드에는 NIC가 두 개(`ens18`, `ens19`) 달려있다. 이것은 OpenStack 네트워킹의 핵심 설계다.

| NIC | 용도 | 왜 분리하는가 |
| --- | --- | --- |
| `ens18` | 관리망 192.168.100.x | API 호출, Geneve 오버레이 터널, 스토리지 트래픽이 모두 여기를 지난다. IP가 있어야 노드 간 통신이 가능하다 |
| `ens19` | 외부망 (IP 없음, UP만) | OVN의 `br-ex`가 이 인터페이스에 붙어서 floating IP 트래픽의 출구로 사용한다. IP가 없어야 OVN이 이 인터페이스를 완전히 통제할 수 있다 |

> ⚠️ **실수 포인트**`ens19`에 IP가 할당되어 있으면 prechecks에서 `external interface has IP` 오류가 발생한다. netplan 설정에서 `ens19`를 `dhcp4: false`, `dhcp6: false`로 명시적으로 막아야 한다.
> 

### Compute 노드 CPU Type을 `host`로 설정하는 이유

cp01, cp02의 CPU Type을 `host`로 설정하는 이유는 **중첩 가상화(nested virtualization)** 때문이다. Proxmox 위에서 VM이 실행되고, 그 VM 위에서 또 OpenStack Nova가 VM을 만들어야 한다. CPU가 가상화 명령어(VT-x, VT-d)를 guest에게 노출해야 nova-compute가 KVM을 활용할 수 있다. 다른 CPU Type은 이 명령어를 숨긴다.

### st01 Cinder LVM 디스크 준비

Cinder LVM 백엔드는 블록 디바이스를 직접 LVM VG로 관리한다. `globals.yml`에 `cinder_volume_group: "cinder-volumes"`라고 적으면, Kolla는 배포 시 이 이름의 VG가 st01에 존재한다고 가정한다. VG가 없으면 Cinder 서비스가 시작되지 않는다.

```bash
# st01에서 실행 — OS 설치 시 LVM 자동 구성을 해제했으므로 sdb가 비어있다
sudo pvcreate /dev/sdb                   # 물리 볼륨 초기화
sudo vgcreate cinder-volumes /dev/sdb   # VG 이름은 globals.yml과 반드시 일치
sudo vgs                                 # cinder-volumes VG 확인
```

> 💡 **LVM 자동 구성을 해제하는 이유**
Ubuntu 설치 시 "Set up this disk as an LVM group" 옵션을 활성화하면 OS가 전체 디스크를 자동으로 LVM으로 구성한다. 이렇게 되면 Cinder가 사용할 추가 디스크(`/dev/sdb`)를 별도로 지정하기 어렵다. OS는 단순 ext4로 설치하고, 추가 디스크를 Cinder 전용으로 남겨두는 것이 Kolla 환경에서의 표준 방식이다.
> 

---

## Phase 1 — Deploy Host 준비 (cjm-lb)

### 왜 venv를 만드는가?

kolla-ansible과 ansible-core는 특정 버전 조합에서만 동작한다. Ubuntu 24.04 시스템에는 이미 Python 패키지들이 설치되어 있고, `pip install`을 시스템 레벨에서 하면 버전 충돌이 발생할 수 있다. venv로 격리된 환경을 만들면 kolla-ansible이 필요한 정확한 버전 조합을 충돌 없이 설치할 수 있다.

```bash
python3 -m venv ~/kolla-venv
source ~/kolla-venv/bin/activate

pip install -U pip
pip install 'ansible-core==2.19.11'
pip install 'kolla-ansible==22.0.0'
```

> 💡 **Python 버전 호환성**
Kolla-Ansible 22.0.0은 Python 3.11+ 이상을 요구한다. Ubuntu 24.04의 기본 Python은 3.12이므로 별도 설치 없이 그대로 사용할 수 있다. (22.04에서는 Python 3.10이 기본이라 3.11을 따로 설치해야 했다.)
> 

### 설정 파일 구조 이해

kolla-ansible 설치 후 `/etc/kolla/` 디렉터리에 두 개의 핵심 파일이 생긴다.

| 파일 | 역할 | 비유 |
| --- | --- | --- |
| `globals.yml` | 어떤 서비스를 어떤 설정으로 올릴 것인가 | 주방의 레시피 — 재료(NIC, VIP, 활성화할 서비스)를 정의 |
| `passwords.yml` | 각 서비스의 DB 비밀번호, 토큰 등 | `kolla-genpwd`가 자동으로 채워주는 자격증명 모음 |
| `multinode` | 어느 IP가 어느 역할을 맡는가 | 배달 지시서 — Ansible이 이 파일을 보고 SSH로 접속 |

### ansible collection 설치가 필요한 이유

kolla-ansible은 표준 ansible 모듈 외에 추가 collection(`community.general`, `ansible.posix` 등)을 사용한다. `kolla-ansible install-deps`는 이 의존성 collection들을 `~/.ansible/collections/`에 설치해준다. 이 단계를 생략하면 deploy 중 "collection not found" 오류가 발생한다.

---

## Phase 2 — 설정 파일 작성

### globals.yml 핵심 설정 해설

`globals.yml`은 "이번 배포에서 어떤 것을 킬 것인가"를 결정하는 마스터 설정이다.

| 설정 항목 | 값 | 의미 |
| --- | --- | --- |
| `kolla_internal_vip_address` | `192.168.100.200` | HAProxy가 관리하는 Virtual IP. 모든 OpenStack API의 단일 진입점. ct01~03 중 하나가 다운되어도 이 IP는 살아있다 |
| `network_interface` | `ens18` | API, 내부 오버레이, 스토리지 트래픽을 모두 처리하는 관리망 NIC |
| `neutron_external_interface` | `ens19` | floating IP 출구. OVN이 `br-ex`를 여기에 붙인다. 이 NIC에 IP가 없어야 한다 |
| `neutron_plugin_agent` | `ovn` | LinuxBridge/Open vSwitch 대신 OVN(Open Virtual Network)을 사용. 논리 라우터, 논리 스위치를 중앙에서 관리 |
| `enable_haproxy` | `yes` | ct01~03에 HAProxy + keepalived 배포. VIP 이중화의 핵심 |
| `enable_cinder` | `yes` | 블록 스토리지 서비스 활성화. `enable_cinder_backend_lvm`과 함께 써야 LVM 백엔드가 붙는다 |
| `enable_swift` | `yes` | 오브젝트 스토리지. st01에 배포 |
| `enable_octavia` | `yes` | LBaaS(Load Balancer as a Service). Amphora VM을 올려서 haproxy를 띄우는 방식 |
| `enable_valkey` | `yes` | Redis의 오픈소스 포크. 캐시 및 세션 저장소로 사용. Kolla 22.x에서 Redis 대체 |

### OVN을 선택한 이유

수동 설치에서는 LinuxBridge + VXLAN 조합이 일반적이다. Kolla 22.x 환경에서 OVN을 선택하면 다음이 달라진다.

| 항목 | 수동/LinuxBridge 방식 | OVN 방식 |
| --- | --- | --- |
| 라우터 위치 | `qrouter` 네임스페이스 (특정 노드 고정) | Gateway Chassis (ct01~03 중 자동 선택, HA) |
| 캡슐화 프로토콜 | VXLAN (UDP/4789) | Geneve (UDP/6081) — 가변 옵션 필드로 메타데이터 전달 |
| 상태 확인 | `ip netns exec` + `iptables` | `ovn-nbctl show` / `ovn-sbctl show` |
| 분산 라우팅 | 불가 (단일 노드) | 지원 (각 compute에서 직접 처리 가능) |

### multinode 인벤토리가 하는 일

multinode 파일은 Ansible이 "어느 IP에 어떤 컨테이너를 올릴 것인가"를 결정하는 지도다. **그룹 이름이 역할을 정의한다.**

```
[control]      → ct01~03 : Keystone, Glance, Nova-API, Neutron, MariaDB, RabbitMQ
[network]      → ct01~03 : OVN 컨테이너, DHCP agent
[compute]      → cp01~02 : nova-compute, OVS agent
[storage]      → st01    : cinder-volume, Swift
[loadbalancer] → ct01~03 : HAProxy, keepalived (VIP 관리)
[monitoring]   → ct01    : Fluentd 로그 수집
```

> 💡 **ct 노드가 control + network + loadbalancer를 동시에 담당하는 이유**
이 실습 환경은 총 7개 VM으로 규모가 작다. 실제 프로덕션이라면 network 전용 노드를 분리하겠지만, 여기서는 ct 3대가 세 가지 역할을 모두 담당하도록 중복 선언했다. Kolla는 한 노드가 여러 그룹에 속하는 것을 허용한다.
> 

### kolla-genpwd가 자동으로 하는 일

`passwords.yml`에는 MariaDB root 비밀번호, RabbitMQ 자격증명, Keystone admin 토큰 등 수십 개의 비밀번호가 필요하다. `kolla-genpwd`를 실행하면 이 파일을 무작위 값으로 채워준다. 나중에 Horizon 접속 비밀번호가 필요할 때 아래 명령어로 확인한다.

```bash
grep keystone_admin_password /etc/kolla/passwords.yml
```

---

## Phase 3 — 배포

### 배포 단계 순서와 이유

kolla-ansible 배포는 여러 단계로 나뉘어 있고, 각 단계를 순서대로 실행해야 한다. 건너뛰면 다음 단계에서 오류가 발생한다.

| 단계 | 명령어 | 하는 일 |
| --- | --- | --- |
| 1 | `octavia-certificates` | Octavia가 Amphora VM과 HTTPS 통신할 때 쓰는 TLS 인증서 생성. deploy 전에 미리 만들어야 한다 |
| 2 | `bootstrap-servers` | 모든 대상 노드에 Docker 설치, 필요한 Python 패키지 설치, 커널 모듈 로드 등 OS 수준 준비 |
| 3 | `prechecks` | OS 버전, NIC 존재 여부, 그룹 정의 완전성 등을 사전 검증. 여기서 잡은 오류가 deploy 중 오류보다 훨씬 디버깅하기 쉽다 |
| 4 | `pull` | 모든 컨테이너 이미지를 미리 다운로드. 네트워크가 불안정한 환경에서 deploy 도중 timeout을 방지 |
| 5 | `deploy` | 실제 배포. 모든 서비스 컨테이너를 올리고, 설정 파일을 주입하고, 서비스 간 연결을 구성 |
| 6 | `post-deploy` | `admin-openrc.sh` 생성. OpenStack CLI를 쓰기 위한 환경 변수 파일 |

### rp_filter를 0으로 설정하는 이유

ct 노드에서 `net.ipv4.conf.all.rp_filter=0`을 설정하는 이유는 OVN의 트래픽 경로 때문이다.

**rp_filter(Reverse Path Filtering)** 는 커널이 들어오는 패킷의 소스 IP로 라우팅 테이블을 역으로 조회해서, 해당 인터페이스가 맞지 않으면 패킷을 버리는 기능이다. OVN에서 floating IP 트래픽은 OVS 내부를 거쳐 `ens18`로 들어왔다가 다시 `ens19`로 나가는 **비대칭 경로**를 따를 수 있다. rp_filter가 켜져 있으면 이 패킷들이 커널에서 조용히 드롭된다. OVN 환경에서는 비대칭 라우팅이 정상 동작이므로 rp_filter를 비활성화해야 한다.

```bash
for ip in 202 203 204; do
    ssh ubuntu@192.168.100.$ip \
        "echo 'net.ipv4.conf.all.rp_filter=0' | sudo tee /etc/sysctl.d/99-kolla.conf && \
         echo 'net.ipv4.conf.ens18.rp_filter=0' >> /etc/sysctl.d/99-kolla.conf"
done
```

### keepalived ProxySQL 우회 루프가 필요한 이유

deploy 도중에 keepalived 컨테이너가 재시작될 때마다 `/checks/check_alive_proxysql.sh` 스크립트가 원본으로 복원된다. 이 스크립트는 ProxySQL 소켓이 살아있는지 확인하는데, 배포 중에는 ProxySQL이 아직 완전히 올라오지 않아서 스크립트가 실패하고, **keepalived가 VIP를 떨어뜨린다**.

VIP가 떨어지면 kolla-ansible이 `192.168.100.200`으로 보내는 API 호출이 실패하고 배포 전체가 멈춘다. 이를 막기 위해 5초마다 해당 스크립트를 "항상 성공(`exit 0`)"으로 덮어쓰는 루프를 별도 터미널에서 유지한다.

ProxySQL을 사용하지 않은 이유는 Galera Cluster를 쓰기에 ProxySQL과 구조가 맞지 않아서 사용하지 않았다.

```bash
ProxySQL이 하는 일:
  클라이언트 → ProxySQL → MariaDB 단일 노드
                            또는
                          MariaDB Primary
                          MariaDB Replica  ← 읽기 분산
                          
                          
 Galera Cluster:
  ct01 MariaDB ←──┐
  ct02 MariaDB ←──┼── 모든 노드가 Primary, 어디서 써도 됨
  ct03 MariaDB ←──┘   (Multi-Master 동기 복제)
```

```bash
# 터미널 2에서 deploy 전에 실행 후 유지
set +H
while true; do
    for ip in 202 203 204; do
        ssh -o StrictHostKeyChecking=no ubuntu@192.168.100.$ip \
            "sudo docker exec keepalived sh -c \
            'printf \"#!/bin/sh\nexit 0\n\" > /checks/check_alive_proxysql.sh' 2>/dev/null"
    done
    sleep 5
done
set -H
```

> ⚠️ **주의**
이 루프는 deploy가 완전히 완료된 후 Ctrl+C로 종료한다. 이 환경에서는 ProxySQL을 활성화하지 않았기 때문에 발생하는 구성 불일치 문제다. 운영 환경에서는 ProxySQL이 정상 실행되므로 이런 우회가 필요 없다.
> 

### prechecks 주요 실패 원인 해설

| 오류 메시지 | 원인 | 해결 |
| --- | --- | --- |
| `release jammy not supported` | Ubuntu 22.04 사용 | Ubuntu 24.04로 재설치. 파일 복사나 업그레이드로는 해결 안 됨 |
| `loadbalancer group does not exist` | multinode에 `[loadbalancer]` 그룹 없음 | `[loadbalancer:children]` 아래 `control` 추가 |
| `has no attribute 'bifrost'` | bifrost 그룹 정의 누락 | 빈 `[bifrost]` 그룹 추가. 사용하지 않아도 정의는 필요 |
| `interface not found` | NIC 이름 오타 | `ip -br a`로 실제 이름 확인. `ens18`이 아니라 `enp1s0`일 수도 있음 |
| `external interface has IP` | `ens19`에 IP 주소 있음 | netplan에서 `ens19` IP 제거 후 `netplan apply` |
| `SSH connection failed` | SSH 키 배포 안 됨 | lb 노드에서 `ssh-copy-id` 재실행 |

---

## Phase 4 — 초기 리소스 생성

### 외부 네트워크 vs 테넌트 네트워크

OpenStack에서 네트워크는 두 계층으로 나뉜다.

| 종류 | 이름 | 대역 | 역할 |
| --- | --- | --- | --- |
| 외부 네트워크 | `external-net` | 192.168.100.0/24 (관리망과 동일 대역) | floating IP가 여기서 할당됨. `ens19 → br-ex`를 통해 Proxmox 관리망과 직접 연결 |
| 테넌트 네트워크 | `internal-net` | 172.22.0.0/24 | 실제 VM들이 연결되는 프라이빗 네트워크. 외부에서 직접 접근 불가 |
| 라우터 | `main-router` | — | `internal-net ↔ external-net` 연결. floating IP NAT와 SNAT을 처리 |

> 💡 **외부 네트워크 대역이 관리망과 같은 이유**
이 실습 환경에서 Proxmox의 natzone은 `192.168.100.0/24` 대역을 공인 IP로 SNAT해준다. floating IP도 같은 대역에서 할당되어야 Proxmox natzone을 통해 인터넷으로 나갈 수 있다. 실제 프로덕션에서는 외부 네트워크가 별도 공인 IP 대역을 가진다.
> 

### allocation-pool의 의미

외부 네트워크 서브넷 생성 시 `--allocation-pool start=192.168.100.210,end=192.168.100.250`을 지정한다. 이 범위의 IP가 floating IP로 사용된다. `.201~.207`은 VM들이 이미 사용 중이고, `.200`은 VIP이므로 겹치지 않는 범위를 지정해야 한다.

### 보안그룹을 따로 만드는 이유

OpenStack의 기본 보안그룹(`default`)은 모든 인바운드를 차단한다. ping과 SSH를 테스트하려면 ICMP와 TCP 22번을 허용하는 규칙이 있는 보안그룹을 만들고 VM 생성 시 지정해야 한다.

```bash
openstack security group create test-sg --description "test security group"
openstack security group rule create --proto icmp test-sg
openstack security group rule create --proto tcp --dst-port 22 test-sg
```

---

## Phase 5 — 네트워크 흐름 확인

### OVN 논리 구조 확인 방법

수동 설치에서는 `ip netns exec qrouter-<id> iptables -t nat -L` 같은 명령어로 라우터 내부를 직접 확인했다. OVN에서는 이 방식이 없다. 대신 두 가지 레벨에서 확인한다.

| 명령어 | 보여주는 것 | 비유 |
| --- | --- | --- |
| `ovn-nbctl show` | 논리 라우터, 논리 스위치, NAT 규칙 — 원하는 네트워크 상태 | "이렇게 동작해야 한다"는 설계도 |
| `ovn-sbctl show` | 실제 바인딩 — 어느 물리 노드가 어느 포트를 담당하는지 | "실제로 이렇게 동작 중이다"는 현황판 |

### Gateway Chassis가 자동으로 선택되는 과정

수동 설치에서는 네트워크 노드 1대에 `qrouter` 네임스페이스가 고정됐다. OVN에서는 `[network]` 그룹의 ct01~03 중 하나가 **active gateway chassis**로 자동 선택된다. 나머지 둘은 standby 상태다. active가 죽으면 자동으로 다른 노드가 인계받는다.

```bash
# 현재 어느 ct가 라우터를 담당하는지 확인
ssh ubuntu@192.168.100.202 \
  "sudo docker exec ovn_northd ovn-sbctl find port_binding type=chassisredirect \
   | grep -E 'chassis|logical_port'"

# chassis UUID → 호스트명으로 변환
ssh ubuntu@192.168.100.202 \
  "sudo docker exec ovn_northd ovn-sbctl list chassis \
   | grep -E '_uuid|hostname'"
```

### 패킷이 인터넷까지 가는 전체 경로

cirros VM에서 `ping 8.8.8.8`을 실행할 때 패킷이 거치는 경로다.

| 구간 | 변환/처리 | 확인 방법 |
| --- | --- | --- |
| cirros `eth0` → tap 인터페이스 | VM의 가상 NIC에서 tap으로. MTU 1442 (Geneve 오버헤드 제외) | `ip addr` (cirros 내부) |
| tap → br-int (OVS) | OVS의 논리 스위치로 수신 | `ovs-vsctl show` (cp02) |
| br-int → Geneve 터널 | `172.22.0.154 → 8.8.8.8` 패킷을 UDP/6081로 캡슐화. 외부: `192.168.100.206 → 192.168.100.204` | `tcpdump -ni ens18 udp port 6081` (cp02) |
| ct03 br-int → OVN 라우터 | Geneve 디캡슐화 → OVN 논리 라우터에서 NAT 처리 | `ovn-nbctl show` (nat 항목) |
| OVN 라우터 NAT | `172.22.0.154 → 192.168.100.243` (floating IP DNAT/SNAT) | `ovn-nbctl show` |
| br-ex → ens19 | OVN 라우터 external 포트에서 Proxmox natzone으로 송출 | `tcpdump -ni ens19 icmp` (ct03) |
| Proxmox natzone MASQUERADE | `192.168.100.243 → 공인 IP` (SNAT) | `iptables -t nat -L POSTROUTING` (pve) |

---

## Phase 6 — Octavia (Amphora LBaaS) 구성

### Octavia가 하는 일

Octavia는 OpenStack의 Load Balancer as a Service 컴포넌트다. 단순히 HAProxy 설정을 배포하는 것이 아니라, LB 요청이 들어올 때마다 **Nova로 Amphora VM을 새로 생성**하고 그 VM 안에 haproxy를 설정해서 트래픽을 처리한다. LB VM 자체가 격리되므로 하나의 LB 장애가 다른 LB에 영향을 주지 않는다.

```
[트래픽 흐름]

클라이언트
  └ VIP (172.22.0.21:80)
     └ Amphora VM (172.22.0.158) — haproxy 실행
        └ Member (172.22.0.154:80) 백엔드 VM

[Amphora 관리 통신 경로]

octavia-worker
  └ Nova API → Amphora VM 생성 (lb-mgmt-net: 10.1.0.x)
     └ octavia-health-manager
          └ o-hm0 (10.1.0.x) ↔ Amphora VM (10.1.0.x) UDP 5555 heartbeat
               └ HTTPS 9443으로 haproxy 설정 주입
```

| 컴포넌트 | 역할 |
| --- | --- |
| `octavia-api` | LB 생성/수정/삭제 API 처리 |
| `octavia-worker` | Nova에 Amphora VM 생성 요청, haproxy 설정 주입 (HTTPS/9443) |
| `octavia-health-manager` | Amphora VM 상태를 UDP 5555로 주기적으로 확인 |
| `octavia-housekeeping` | 오류 상태 Amphora 정리 |
| Amphora VM | haproxy가 실행되는 실제 LB 인스턴스. `lb-mgmt-net` (10.1.0.0/24)에 연결 |

### Amphora 이미지를 직접 빌드하는 이유

Octavia는 LB 생성마다 Amphora라는 전용 VM 이미지를 사용한다. 이 이미지는 Ubuntu 기반으로 haproxy, keepalived, amphora-agent가 사전 설치된 특수 이미지다. 공식 빌드 스크립트(`diskimage-create.sh`)로 직접 빌드해서 Glance에 올려야 한다.

> ⚠️ **주의**`debootstrap`이 설치되어 있지 않으면 빌드가 에러 없이 종료되지만 `.qcow2` 파일이 생성되지 않는다. "빌드가 완료됐는데 파일이 없다"면 `debootstrap` 설치 여부를 먼저 확인한다.
> 

### 이미지 visibility를 `community`로 설정하는 이유

Octavia worker는 Glance에서 `amphora` 태그가 붙은 이미지를 조회해서 Amphora VM을 생성한다. 이미지를 `private`으로 등록하면 octavia 서비스 계정의 프로젝트에서만 보인다. octavia worker가 실행되는 컨텍스트에 따라 이미지를 찾지 못하는 경우가 발생한다. `community`로 설정하면 프로젝트에 상관없이 모든 서비스 계정이 조회할 수 있다.

```bash
IMAGE_ID=$(openstack image list --tag amphora -f value -c ID)
openstack image set $IMAGE_ID --community
openstack image show $IMAGE_ID | grep visibility
# visibility | community
```

### `octavia_network_type: tenant` 설정의 의미

`globals.yml`의 `octavia_network_type` 기본값은 `provider`다. `provider` 모드에서는 Amphora 관리 네트워크를 물리 네트워크에 직접 연결하는 방식을 사용한다.

`tenant` 모드로 설정하면 OVN `br-int`에 `o-hm0` 인터페이스를 붙여서 `lb-mgmt-net`(10.1.0.0/24)을 오버레이로 구성한다. 이 실습 환경에서는 외부 물리 네트워크가 없으므로 `tenant` 모드가 맞다. `tenant`로 설정해야 `hm-interface.yml` Ansible 태스크가 실행되어 ct 노드에 `o-hm0` 인터페이스가 생성된다.

```yaml
# globals.yml에 추가
octavia_network_type: "tenant"

octavia_amp_network:
  name: "lb-mgmt-net"
  external: false
  subnet:
    name: "lb-mgmt-subnet"
    cidr: "10.1.0.0/24"
    no_gateway_ip: true
    enable_dhcp: true
    ip_version: 4
```

> ⚠️ **주의**`octavia_amp_network`는 반드시 딕셔너리 형태로 입력해야 한다. 문자열(`"lb-mgmt-net"`)로 입력하면 `object of type 'str' has no attribute 'name'` 에러가 발생한다.
> 

### Ubuntu 24.04에서 `dhclient`가 없는 이유

Ubuntu 22.04까지는 `isc-dhcp-client`가 기본 설치되어 있어서 `dhclient` 명령어를 바로 쓸 수 있었다. Ubuntu 24.04에서는 이 패키지가 기본에서 제거됐다. 대신 systemd-networkd가 DHCP를 처리한다.

Octavia의 `octavia-interface.service`는 `o-hm0` 인터페이스에 IP를 할당할 때 `dhclient` 명령어를 직접 호출한다. 24.04에서는 이 명령어가 없으므로 서비스 시작이 실패한다. `isc-dhcp-client`를 수동으로 설치해서 해결한다.

```bash
for ip in 202 203 204; do
    ssh ubuntu@192.168.100.$ip "sudo apt-get install -y isc-dhcp-client"
done

for ip in 202 203 204; do
    ssh ubuntu@192.168.100.$ip \
        "sudo systemctl restart octavia-interface && \
         sudo systemctl enable octavia-interface"
done
```

### health-manager `bind_ip`를 `0.0.0.0`으로 바꾸는 이유

Octavia health-manager는 Amphora VM으로부터 UDP 5555 포트로 heartbeat를 수신한다. Amphora VM은 `lb-mgmt-net`(10.1.0.0/24)에 연결되어 있고, ct 노드의 `o-hm0` 인터페이스가 이 네트워크 접점이다.

그런데 kolla-ansible deploy가 생성하는 기본 health-manager 설정에서 `bind_ip`가 관리망(`192.168.100.x`)으로 설정된다. health-manager가 관리망 IP로 바인딩하면 `o-hm0`(10.1.0.x)으로 들어오는 Amphora heartbeat를 수신할 수 없다.

`bind_ip = 0.0.0.0`(모든 인터페이스 수신)으로 설정하고 `controller_ip_port_list`에 o-hm0 IP들을 명시하면 Amphora가 어느 ct 노드로 heartbeat를 보내도 수신할 수 있다.

```bash
mkdir -p /etc/kolla/config/octavia

cat > /etc/kolla/config/octavia/octavia-health-manager.conf <<'EOF'
[health_manager]
bind_ip = 0.0.0.0
controller_ip_port_list = 10.1.0.74:5555,10.1.0.167:5555,10.1.0.21:5555
EOF

kolla-ansible reconfigure -i ~/multinode --tags octavia
```

> 💡 **오버라이드 설정 파일 경로**`/etc/kolla/config/` 아래에 서비스별 conf 파일을 두면 `kolla-ansible reconfigure` 시 해당 설정이 컨테이너 내부에 주입된다. 컨테이너를 직접 수정하면 reconfigure 시 덮어씌워지므로 반드시 이 방식으로 오버라이드한다.
> 

### 트러블슈팅 총정리

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 빌드 완료 후 `.qcow2` 없음 | `debootstrap` 미설치. 에러 없이 종료되는 스크립트 버그 | `apt install debootstrap qemu-utils git kpartx` |
| `ImageGetException: Failed to retrieve image with amphora tag` | Glance 이미지 visibility가 `private` | `openstack image set --community <image-id>` |
| `object of type 'str' has no attribute 'name'` | `globals.yml`에서 `octavia_amp_network`를 문자열로 입력 | `globals.yml`에 딕셔너리 형태로 정확히 입력 |
| `o-hm0` 인터페이스 생성 안 됨 | `octavia_network_type` 기본값이 `provider` | `globals.yml`에 `octavia_network_type: "tenant"` 추가 후 reconfigure |
| `octavia-interface.service` 시작 실패 | Ubuntu 24.04에 `dhclient` 없음 | ct01~03 전체에 `apt install isc-dhcp-client` |
| `ComputeWaitTimeoutException` + `No route to host 10.1.0.x:9443` | health-manager `bind_ip`가 관리망으로 설정됨 | `/etc/kolla/config/octavia/octavia-health-manager.conf`에 `bind_ip = 0.0.0.0` 설정 후 reconfigure |
| LB ACTIVE인데 `503 Service Unavailable` | 백엔드 VM 보안그룹에 80 포트 미허용 또는 웹서버 미실행 | `security group rule create --dst-port 80` + 웹서버 실행 확인 |