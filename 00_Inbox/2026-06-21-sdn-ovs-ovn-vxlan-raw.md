---
title: "SDN · LinuxBridge · OVS · OVN · VXLAN/Geneve"
type: "raw"
date: 2026-06-21
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[01_Concepts/SDN-OVS-OVN-VXLAN]]"
---
# SDN · LinuxBridge · OVS · OVN · VXLAN/Geneve

> OpenStack 네트워킹 스택 개념 정리
> 

---

## SDN (Software Defined Networking)

### 기존 네트워크의 문제

기존 네트워크 장비(스위치, 라우터)는 **제어(Control Plane)와 전달(Data Plane)이 하나의 하드웨어 안에** 묶여있다.

```
[기존 스위치]
  ┌─────────────────┐
  │ Control Plane   │  ← "패킷을 어디로 보낼지 결정" (라우팅 테이블)
  ├─────────────────┤
  │ Data Plane      │  ← "실제로 패킷을 전달" (패킷 포워딩)
  └─────────────────┘
  → 설정 변경하려면 장비를 직접 건드려야 함
  → 자동화, 프로그래밍 불가
```

### SDN의 해결 방식

Control Plane과 Data Plane을 **분리**한다.

```
[SDN]
  Control Plane → 소프트웨어 (중앙에서 API로 제어)
  Data Plane    → 하드웨어/가상 스위치 (빠른 전달만 담당)
```

네트워크를 **코드로 제어**할 수 있게 된다. OpenStack Neutron이 바로 SDN 컨트롤러 역할이다.

### Overlay SDN vs Underlay SDN

**Overlay SDN** — 물리 네트워크 위에 가상 네트워크를 얹는 방식

```
[물리 네트워크]  192.168.100.x  ← 실제 존재하는 네트워크 (underlay)
      위에
[가상 네트워크]  172.22.0.x     ← OVN이 만든 논리 네트워크 (overlay)
```

VM들은 `172.22.0.x`로 통신하지만, 실제 패킷은 `192.168.100.x` 관리망을 Geneve 터널로 타고 이동한다. 물리 네트워크 장비는 그냥 UDP 패킷으로만 인식한다.

**Underlay SDN** — 물리 스위치 자체를 소프트웨어로 제어하는 방식. 물리 장비가 SDN을 지원해야 한다 (OpenFlow 지원 스위치 등).

> 이 실습 환경은 Overlay SDN이다. 물리망(Proxmox vmnet)은 그대로 두고, OVN이 그 위에 가상 네트워크를 만든다.
> 

---

## LinuxBridge

### 한 줄 설명

**Linux 커널에 내장된 소프트웨어 브리지**. 별도 소프트웨어 없이 커널만으로 VM들을 L2 연결한다.

### 동작 방식

```
VM-A (tap) ──┐
VM-B (tap) ──┤── brq<net-id> ──── vxlan-<id> ──── 물리망 (ens18)
VM-C (tap) ──┘        │
                  DHCP tap
```

- `brq<net-id>` : Neutron이 생성한 Linux 브리지. 같은 네트워크의 VM들이 여기에 연결됨
- `vxlan-<id>` : 브리지에 꽂힌 VXLAN 터널 인터페이스. 다른 노드와의 오버레이 연결
- `tap` : VM의 가상 NIC와 브리지를 연결하는 인터페이스

### 라우터 구성

라우터는 특정 network 노드의 **네임스페이스(netns)** 안에 고정된다.

```bash
# 수동 설치 때 라우터 내부를 이렇게 확인했다
ip netns exec qrouter-<uuid> iptables -t nat -L
ip netns exec qrouter-<uuid> ip addr
ip netns exec qdhcp-<uuid> ip addr    # DHCP 네임스페이스
```

- 모든 라우팅 트래픽이 이 노드를 물리적으로 통과해야 함
- 이 노드가 죽으면 라우팅 전체가 끊김 → **SPOF(Single Point of Failure)**

### 특징

| 장점 | 단점 |
| --- | --- |
| 커널 내장, 별도 설치 불필요 | 성능이 OVS보다 낮음 |
| 구조가 단순해서 디버깅 쉬움 | 분산 라우팅 불가 |
| OpenStack 입문 학습에 적합 | 대규모 환경에서 확장성 한계 |
| `ip netns`, `iptables`으로 직관적 확인 | 노드가 늘어날수록 관리 복잡도 증가 |

---

## OVS (Open vSwitch)

### 한 줄 설명

**소프트웨어로 만든 가상 스위치**. LinuxBridge보다 기능이 많고 성능이 좋다. 커널 모듈과 사용자 공간 데몬(`ovs-vswitchd`)으로 구성된다.

### LinuxBridge와 차이

|  | LinuxBridge | OVS |
| --- | --- | --- |
| 구현 | Linux 커널 내장 | 별도 데몬 (`ovs-vswitchd`) |
| 터널링 | VXLAN만 | VXLAN, Geneve, STT, GRE |
| 플로우 제어 | 불가 | OpenFlow로 정밀 제어 가능 |
| 성능 | 보통 | 높음 (DPDK 하드웨어 가속 지원) |
| 멀티노드 관리 | 개별 설정 | OVN으로 통합 관리 가능 |

### 브리지 구조

OVS는 브리지 단위로 포트를 묶는다. Kolla OVN 환경에서는 두 개의 브리지가 핵심이다.

```bash
sudo docker exec openvswitch_vswitchd ovs-vsctl show

# compute 노드 (cp02)
Bridge br-int
    Port tap1f430626-97    ← VM 연결 tap 포트
    Port tap4be8df35-70    ← DHCP 포트
    Port ovn-openst-0      ← cp01로 Geneve 터널
    Port ovn-openst-3      ← ct03(gateway chassis)으로 Geneve 터널

# gateway chassis 노드 (ct03)
Bridge br-int
    Port ovn-openst-...    ← 각 compute로 Geneve 터널
    Port patch-br-ex       ← br-ex와 내부 연결

Bridge br-ex
    Port ens19             ← 물리 NIC (IP 없음, 외부망 출구)
    Port patch-br-int      ← br-int와 내부 연결
```

### br-int vs br-ex

|  | br-int | br-ex |
| --- | --- | --- |
| 존재 위치 | **모든 노드** (compute, gateway 포함) | **gateway chassis에만** |
| 역할 | VM tap, Geneve 포트를 묶는 내부 논리 스위치 | 외부망 출구. ens19(IP 없음)를 포트로 붙여서 사용 |
| ens19 관계 | 무관 (ens19 미사용) | ens19가 이 브리지의 포트로 꽂힘 |

> **patch port** — br-int ↔ br-ex를 연결하는 OVS 내부 가상 포트. 물리 NIC가 아니라 OVS 안에서만 존재하는 가상 케이블이다. `patch-br-int`, `patch-br-ex`라는 이름으로 보인다.
> 

### 패킷 흐름 (OVS only, OVN 없이)

```
VM tap
  → br-int
    → vxlan 포트 (ens18 경유)   ← 다른 노드로 오버레이
    → patch-br-ex
      → br-ex
        → ens19                  ← 외부망 출구
```

OVN 없이 OVS만 쓸 때는 각 노드의 OVS를 Neutron OVS agent가 직접 일일이 설정해야 했다.

---

## OVN (Open Virtual Network)

### OVS와의 관계

OVN은 OVS를 **대체하는 게 아니라** OVS 위에서 OVS를 제어하는 레이어다.

```
OVN        ← 제어 플레인 (논리 네트워크 정의 + OVS 제어)
 └── OVS   ← 데이터 플레인 (실제 패킷 처리)
      └── Linux kernel
```

OVN이 있으면 OVS도 반드시 같이 있다. OVN은 "여러 노드의 OVS를 중앙에서 통합 관리"하는 상위 레이어다.

```
[OVN 없이 OVS만]
  Neutron OVS agent가 각 노드에서 OVS를 직접 설정
  → 노드 수가 늘수록 agent 간 동기화가 복잡해짐
  → RabbitMQ 메시지 큐로 통신 → 느림

[OVN 있을 때]
  논리 네트워크를 Northbound DB에 한 번만 정의
  → 각 노드의 ovn-controller가 DB를 읽고 로컬 OVS를 자동 설정
  → OVSDB 직접 통신 → 빠름
```

### OVN 내부 구조

```
[Neutron (CMS)]
    │ "라우터 만들어, 포트 붙여, NAT 설정해"
    ▼
[Northbound DB]          ← 논리 설정 저장 (사람이 원하는 상태)
  논리 스위치, 라우터
  논리 포트, NAT 규칙
    │
[ovn-northd]             ← 논리 설정 → 런타임 플로우로 변환
    │
[Southbound DB]          ← 런타임 상태 저장 (실제로 어디서 동작 중인지)
  물리 바인딩 (어느 노드에 어느 포트가 있는지)
  터널 정보, chassis 정보
    │
[ovn-controller]         ← 각 노드에서 실행
  Southbound DB 읽고 → 로컬 OVS에 OpenFlow 플로우 설치
```

### Northbound DB vs Southbound DB

**Northbound DB** — 원하는 상태 (논리 설정)

```bash
ovn-nbctl show

# 출력 예시
switch internal-net        ← 논리 스위치
  port 172.22.0.154        ← VM 포트
  port 172.22.0.2 (DHCP)

router main-router         ← 논리 라우터
  lrp external  192.168.100.221/24
  lrp internal  172.22.0.1/24
  nat: 172.22.0.154 → 192.168.100.243  ← floating IP
  nat: 172.22.0.0/24 → 192.168.100.221 ← SNAT
```

**Southbound DB** — 실제 상태 (물리 바인딩)

```bash
ovn-sbctl show

# 출력 예시
Chassis openstack-cp02     ← 물리 노드
  Port_Binding 172.22.0.154  ← 이 VM은 cp02에 있음

Chassis openstack-ct03     ← gateway chassis
  Port_Binding cr-lrp-...    ← 라우터는 ct03이 담당
```

```bash
# "이렇게 동작해야 한다" 설계도
ssh ubuntu@192.168.100.202 "sudo docker exec ovn_northd ovn-nbctl show"

# "실제로 이렇게 동작 중이다" 현황판
ssh ubuntu@192.168.100.202 "sudo docker exec ovn_northd ovn-sbctl show"
```

### Gateway Chassis

OVN의 라우터는 논리 객체라서 어느 특정 노드에 고정되지 않는다. 그런데 실제 패킷이 인터넷으로 나가려면 결국 어딘가 물리 노드의 `ens19`를 통과해야 한다. 그 **출구 담당 노드**를 OVN이 자동으로 지정한 것이 gateway chassis다.

```
ct01, ct02, ct03 모두 [network] 그룹
        ↓
OVN이 셋 중 하나를 active gateway chassis로 자동 선출
        ↓
선출된 노드에서만 br-ex + ens19 활성화
floating IP NAT, SNAT 여기서 처리
나머지 둘은 standby → active 죽으면 자동 인계
```

```bash
# 현재 어느 ct가 gateway chassis인지 확인
ovn-sbctl find port_binding type=chassisredirect | grep chassis

# UUID → 호스트명 변환
ovn-sbctl list chassis | grep -E '_uuid|hostname'
```

### OVS only vs OVN 비교

```
OVS only (ML2/OVS)           OVN
──────────────────────        ──────────────────────────
network 노드 (고정)            ct01 ← active (자동 선출)
  qrouter netns               ct02 ← standby
  ↑ 모든 트래픽 여기로          ct03 ← standby
  ↑ 죽으면 SPOF
                              active 죽으면 → standby 자동 인계
```

| 항목 | ML2/OVS | OVN |
| --- | --- | --- |
| 제어 방식 | RabbitMQ 메시지 큐 | OVSDB 직접 통신 |
| 구현 언어 | Python | C |
| 라우터 위치 | network 노드 고정 | 논리 객체, gateway chassis 자동 선출 |
| 라우터 HA | SPOF | 자동 failover |
| 분산 라우팅 | 불가 | 지원 |
| 확장성 | 낮음 | 높음 |
| 상태 확인 | `ip netns exec` + `iptables` | `ovn-nbctl` / `ovn-sbctl` |

---

## 캡슐화 프로토콜: VXLAN vs Geneve

### 캡슐화가 필요한 이유

VM들은 서로 다른 물리 노드에 있어도 "같은 L2 네트워크에 있는 것처럼" 통신해야 한다. 그런데 물리 네트워크는 IP 라우팅만 한다. 그래서 **VM의 이더넷 프레임을 통째로 UDP 패킷 안에 넣어서** 물리 노드 간에 전달하는 것이 캡슐화다.

```
[원본: VM이 보내는 패킷]
  src MAC: fa:16:3e:e0:44:66 (VM eth0)
  src IP:  172.22.0.154
  dst IP:  8.8.8.8

[캡슐화 후: 물리망에서 이동하는 패킷]
  Outer src IP : 192.168.100.206 (cp02 ens18)
  Outer dst IP : 192.168.100.204 (ct03 ens18)
  Protocol     : UDP
  Port         : 6081 (Geneve) 또는 4789 (VXLAN)
    └── [터널 헤더 (VNI + 메타데이터)]
          └── [Inner: 원본 이더넷 프레임 전체]
```

물리 네트워크 입장에서는 그냥 UDP 패킷이다. 터널 양쪽 노드만 안에 VM 패킷이 들어있다는 걸 안다.

### VXLAN

```
[VXLAN 헤더 구조]
  Flags (8bit) | Reserved (24bit) | VNI (24bit) | Reserved (8bit)
  → 고정 크기, VNI(네트워크 식별자) 24bit만 전달 가능
```

- UDP 포트: **4789**
- LinuxBridge, ML2/OVS 환경에서 사용
- 헤더가 고정이라 추가 메타데이터를 실을 수 없음

### Geneve

```
[Geneve 헤더 구조]
  Ver | OptLen | Flags | Protocol Type | VNI (24bit) | Reserved
  └── [Variable Length Options (TLV 형식)]
        Type | Length | Value  ← 추가 메타데이터를 자유롭게 실을 수 있음
```

- UDP 포트: **6081**
- OVN 환경에서 사용
- 가변 길이 옵션 필드 덕분에 OVN이 논리 포트 ID, 정책 메타데이터를 터널 헤더에 실어 노드 간 전달 가능

### OVN이 Geneve를 선택한 이유

OVN은 패킷이 어느 논리 포트에서 왔는지, 어떤 보안 정책을 적용해야 하는지 같은 메타데이터를 노드 간에 전달해야 한다. VXLAN은 헤더가 고정이라 VNI 이외의 정보를 실을 공간이 없다. Geneve는 옵션 필드가 가변이라 이 정보를 담을 수 있다.

```bash
# Geneve 패킷 직접 확인 (cp02에서)
sudo tcpdump -ni ens18 udp port 6081 -e -vv -c 3

# 출력 예시
192.168.100.206.6469 > 192.168.100.204.6081: Geneve, vni 0x0, proto TEB
    fa:16:3e:e0:44:66 > ...     ← Inner: VM MAC
    172.22.0.154 > 8.8.8.8     ← Inner: VM → 인터넷
```

|  | VXLAN | Geneve |
| --- | --- | --- |
| UDP 포트 | 4789 | 6081 |
| 헤더 크기 | 고정 (8byte) | 가변 (최소 8byte) |
| 메타데이터 | VNI(24bit)만 | VNI + 추가 옵션 필드 |
| 사용 환경 | LinuxBridge, ML2/OVS | OVN |
| OVN 지원 | 미사용 | 기본값 |

---

## 세 가지 환경 전체 비교

LinuxBridge, OVS, OVN은 각각 다른 조합이다. OVS와 OVN은 이름이 비슷하지만 OVN은 OVS를 대체하는 게 아니라 OVS 위에 올라타는 제어 레이어다.

|  | LinuxBridge + VXLAN | OVS + VXLAN | OVN (OVS + Geneve) |
| --- | --- | --- | --- |
| 데이터 플레인 | Linux 커널 브리지 | Open vSwitch | Open vSwitch |
| 제어 플레인 | Neutron L2 agent | Neutron OVS agent | OVN (northd + ovn-controller) |
| 오버레이 | VXLAN (UDP/4789) | VXLAN (UDP/4789) | Geneve (UDP/6081) |
| 라우터 위치 | `ip netns qrouter` 고정 | `ip netns qrouter` 고정 | OVN logical router (분산) |
| 라우터 HA | SPOF | SPOF | gateway chassis 자동 선출 |
| 분산 라우팅 | 불가 | 부분 지원 | 완전 지원 |
| 디버깅 | `ip netns` + `iptables` | `ovs-vsctl` + `ip netns` | `ovn-nbctl` + `ovn-sbctl` |

---

## 전체 계층 관계

```
SDN                           ← 개념 (제어와 전달 분리)
 └── Overlay SDN              ← 물리 위에 가상 네트워크
      ├── LinuxBridge         ← 커널 내장 브리지 (단순, 레거시)
      │    └── VXLAN          ← 오버레이 캡슐화 프로토콜
      └── OVS                 ← 고성능 가상 스위치 (단일 노드)
           ├── VXLAN          ← OVS only 환경
           └── OVN            ← OVS 여러 대 통합 관리 (제어 레이어)
                └── Geneve    ← OVN이 사용하는 캡슐화 프로토콜
```

OpenStack Neutron이 OVN을 제어하고, OVN이 각 노드의 OVS를 제어하고, OVS가 실제 패킷을 Geneve로 캡슐화해서 전달하는 계층 구조다.

[OVS/OVN과 SDN의 이해](https://hillagoon.github.io/sdn/SDN/)