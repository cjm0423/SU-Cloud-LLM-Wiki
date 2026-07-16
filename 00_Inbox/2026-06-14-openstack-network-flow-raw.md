---
title: "openstack 네트워크 흐름 분석"
type: "raw"
date: 2026-06-14
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# openstack 네트워크 흐름 분석

[openstack_네트워크_흐름_분석.pdf](openstack%20%EB%84%A4%ED%8A%B8%EC%9B%8C%ED%81%AC%20%ED%9D%90%EB%A6%84%20%EB%B6%84%EC%84%9D/openstack_%EB%84%A4%ED%8A%B8%EC%9B%8C%ED%81%AC_%ED%9D%90%EB%A6%84_%EB%B6%84%EC%84%9D.pdf)

## OpenStack 네트워크 구조

1. Provider Network
    - **누가 만드나**: 오픈스택을 운영하는 사람(관리자)이 직접 구축
    - **어디에 할당되나**: VM Instance에 직접 할당
    - **특징**: 인터넷에 직접 연결된 외부 네트워크 (192.168.22.0/24)
    
    ```bash
    Provider Network (192.168.22.0/24)
             ├── Controller Node
             └── Compute Node
                      └── Instance
    ```
    
    - Compute Node에 붙은 Instance가 Provider N/W에 직결 → 별도 NAT 없이 외부 통신 가능.

1. Self-Service Network(Tenant N/W)
    - **누가 만드나**: 오픈스택을 사용하는 일반 사용자(Tenant)가 직접 생성
    - **핵심**: Provider Network 위에 **GRE 또는 VXLAN 터널링**을 얹어서 구축
    - **장점**: 임의의 사설 IP 대역 자유롭게 설정 가능 (예: 172.16.1.0/24)
    
    | 색상 | 네트워크 | 대역 | 역할 |
    | --- | --- | --- | --- |
    | 파란색 | Provider N/W | 192.168.22.0/24 | 외부 인터넷 연결 |
    | 초록색 | Tunnel N/W | 192.168.23.0/24 | VXLAN 캡슐화 통신 |
    | 빨간색 | Tenant N/W | 172.16.1.0/24 | VM 내부 사설 네트워크 |
    - **핵심 포인트**: Tenant N/W는 물리적으로 독립된 게 아니라, Tunnel N/W 위에 VXLAN으로 오버레이된 논리 네트워크.

## OpenStack 컴포넌트 비교

Provider N/W 방식과 Self-Service N/W 방식 각각의 **서비스 레이아웃** 비교.

**Option 1: Provider Networks**

Controller Node에서 돌리는 핵심 서비스:

- SQL DB, NoSQL DB, Message Queue, NTP
- Identity(Keystone), Image(Glance), Placement, Compute Management
- Networking: Management, ML2 Plug-in, Linux Bridge Agent, DHCP Agent, Metadata Agent
- Block Storage Management, Orchestration (선택)

Compute Node: KVM Hypervisor, Compute(Nova), Linux Bridge Agent

**Option 2: Self-Service Networks**

Option 1에서 추가되는 것:

- Controller에 **L3 Agent** 추가 → 라우터(Router Namespace) 운영
- 나머지 구조는 동일하나 L3 라우팅 기능이 Controller에 올라옴

**핵심 차이**: Self-Service는 L3 Agent가 필요. L3 Agent가 가상 Router를 만들어서 Tenant N/W ↔ Provider N/W 간 라우팅을 담당.

## 물리 네트워크 구성도 (실습 환경)

**노드 구성**

| 노드 | 인터페이스 | IP |
| --- | --- | --- |
| Controller | ens192 (manual) | Provider N/W 연결 |
| Controller | ens160 | 192.168.23.236 |
| Compute1 | ens192 (manual) | Provider N/W 연결 |
| Compute1 | ens160 | 192.168.23.237 |

**네트워크 의미**

- `ens192` → **Provider N/W** (192.168.22.0/24): 인터넷 연결용. `manual` 설정 = IP 없이 브리지 포트로만 사용
- `ens160` → **Mgmt / Tunnel N/W** (192.168.23.0/24): 3가지 용도 겸용
    1. OpenStack API 통신
    2. SSH 접속 및 설치용 관리 네트워크
    3. **VXLAN 터널** 통신

## Self-Service 네트워크 구성

![image.png](openstack%20%EB%84%A4%ED%8A%B8%EC%9B%8C%ED%81%AC%20%ED%9D%90%EB%A6%84%20%EB%B6%84%EC%84%9D/image.png)

Controller Node 내부:

- **Linux Bridge Agent** 아래 2개의 브리지가 생성됨
    - `Provider Bridge (brq...)`: ens192(물리)와 연결 → 외부 인터넷 브리지
    - `Self-Service Bridge (brq...)`: VXLAN Interface(vxlan)와 연결 → 터널 브리지
- **L3 Agent**: Router Namespace(`qrouter`) 생성 → 두 브리지 사이 라우팅
- **DHCP Agent**: 각 네트워크마다 DHCP Namespace(`qdhcp`) 생성

Compute Node 내부:

- Security Groups (iptables 기반 방화벽)
- `Self-Service Bridge` + `VXLAN Interface` → Controller와 VXLAN 터널 연결
- `Provider Bridge` → 물리 Provider N/W 연결

![image.png](openstack%20%EB%84%A4%ED%8A%B8%EC%9B%8C%ED%81%AC%20%ED%9D%90%EB%A6%84%20%EB%B6%84%EC%84%9D/image%201.png)

- Tenant VM → Self-Service Bridge → VXLAN Tunnel → Controller Self-Service Bridge → Router Namespace → Provider Bridge → Internet
- Router Namespace 내부: `qr-` 포트(Tenant 방향), `qg-` 포트(Provider 방향) = NAT 처리 지점

# Self-Service 네트워크 구성 과정

## 1. Provider 네트워크 구성

첫 번째 구성 단계. **openstack network create** 명령으로 Provider N/W를 생성했을 때 Controller 내부에서 일어나는 일.

**생성된 구조**

```bash
Controller
├── DHCP Namespace (qdhcp-c199735)
│     └── ns-e9fb1 (DHCP 서버 포트)
└── Provider Bridge (brqc1997735-77)
      ├── tape9f  ← DHCP namespace 연결 tap 포트
      └── ens192  ← 물리 NIC (Provider N/W로 나가는 출구)
```

**핵심**: Provider N/W 생성 시 Neutron이 자동으로

1. Linux Bridge(`brq...`) 생성
2. 물리 NIC(`ens192`)를 해당 브리지에 바인딩
3. DHCP Namespace 생성 + tap 포트로 브리지에 연결

Compute Node는 아직 없음 → VM이 없으니 Compute 쪽 구성은 안 생긴 상태.

## 2. Self-Service 네트워크 구성

두 번째 단계. Tenant 네트워크(172.16.1.0/24) 추가 생성.

**추가된 구조 (Controller)**

```bash
Controller
├── DHCP Namespace (qdhcp-c199735) → Provider 용
├── DHCP Namespace (qdhcp-34078f0c) → Self-Service 용
│     └── ns-b5ab
├── Provider Bridge (brqc1997735-77)
│     ├── tape9f
│     └── ens192
└── Self-Service Bridge (brq34078f0c-3e)  ← 신규
      ├── vxlan70  ← VXLAN 인터페이스
      └── tapb5a   ← DHCP ns 연결
```

`ens160` (192.168.23.236) → **VXLAN Tunnels**로 연결

**핵심**: Self-Service N/W 생성 시:

1. 새 Linux Bridge(`brq34078f0c...`) 생성
2. VXLAN Interface(`vxlan70`) 생성 → `ens160`을 통해 터널 확장
3. Self-Service 전용 DHCP Namespace 추가 생성

아직 Router가 없으므로 Provider ↔ Self-Service 간 통신 불가.

## 3. Router 생성

세 번째 단계. L3 Router를 생성하고 Self-Service 서브넷을 연결.

**추가된 구조**

```bash
Controller
├── Router Namespace (qrouter-594a2a7a)  ← 신규
│     └── qr-19d1 (172.16.1.1)  ← Self-Service 쪽 인터페이스
├── Self-Service Bridge
│     ├── tap19d  ← Router namespace 연결 tap 포트  ← 신규
│     ├── vxlan70
│     └── tapb5a
└── Metadata Agent
```

**핵심**: `openstack router add subnet` 명령 실행 시:

- Router Namespace 내에 `qr-` 포트 생성 (172.16.1.1 = Tenant 게이트웨이 IP)
- Self-Service Bridge에 `tap19d` 포트 추가로 연결
- Metadata Agent 활성화
- 아직 `qg-` 포트(외부 게이트웨이) 없음 → 인터넷은 아직 안 됨

## 4. Router Gateway 설정

네 번째 단계. `openstack router set --external-gateway` 로 Provider N/W를 Router에 연결.

**추가된 구조**

```bash
Router Namespace (qrouter-594a2a7a)
├── qg-e019 (192.168.22.185)  ← Provider 방향 게이트웨이 포트  ← 신규
└── qr-19d1 (172.16.1.1)      ← Tenant 방향 포트

Provider Bridge (brqc1997735-77)
├── tape9f
├── ens192
└── tape019  ← Router의 qg 포트와 연결  ← 신규
```

**192.168.22.185** = Router가 Provider N/W에서 할당받은 Floating IP의 기반이 되는 IP (qg 포트 IP).

**핵심**: 이 시점부터 Tenant VM → Router(NAT) → Provider N/W → Internet 경로가 완성됨. SNAT 규칙이 Router Namespace의 iptables에 등록됨.

## 5.  VM Instance 생성

마지막 구성 단계. Self-Service N/W에 VM 기동.

**Compute Node에 생성된 구조**

```bash
Compute Node
├── ens160 (192.168.23.237)  ← VXLAN 터널 엔드포인트
└── Self-Service Bridge (brq34078f0c-3e)
      ├── tap66a  ← VM의 가상 NIC와 연결
      ├── iptables  ← Security Group 처리
      └── vxlan70   ← Controller 방향 VXLAN 터널

VM Instance
└── eth0 (172.16.1.218)  ← DHCP로 할당받은 IP
```

전체 패킷 경로 (VM → Internet)

```bash
VM(eth0, 172.16.1.218)
  → tap66a → iptables(SG 체크) → vxlan70
  → [VXLAN 캡슐화: src=192.168.23.237, dst=192.168.23.236]
  → ens160(Compute) → 물리 네트워크 → ens160(Controller)
  → vxlan70(Controller) → Self-Service Bridge
  → tap19d → Router Namespace(SNAT: 172.16.1.218 → 192.168.22.185)
  → qg-e019 → tape019 → Provider Bridge
  → ens192 → Provider Network → Internet
```

![image.png](openstack%20%EB%84%A4%ED%8A%B8%EC%9B%8C%ED%81%AC%20%ED%9D%90%EB%A6%84%20%EB%B6%84%EC%84%9D/image%202.png)

# CTRL-COMP1 노드간 통신 (VM → Internet)

실제 패킷 캡처로 위 흐름을 **검증**한 슬라이드.

**시나리오**: VM(172.16.1.218) → `ping 8.8.8.8`

**Compute Node ens160에서 캡처한 내용**

```bash
# 송신 (VXLAN 캡슐화)
192.168.23.237:45218 > 192.168.23.236:8472
  [OTV] Inner: 172.16.1.218 > 8.8.8.8 ICMP echo request

# 수신 (VXLAN 역캡슐화 후 응답)
192.168.23.236:41060 > 192.168.23.237:8472
  [OTV] Inner: 8.8.8.8 > 172.16.1.218 ICMP echo reply
```

Controller Provider Bridge(ens192) 캡처

```bash
192.168.22.185 > dns.google  ← SNAT 된 후 나가는 패킷
dns.google > 192.168.22.185  ← 응답 돌아옴
```

**확인 포인트**:

- VXLAN UDP 포트 **8472** 사용
- Compute → Controller 구간은 터널 IP(`192.168.23.x`)로 캡슐화
- Controller의 Router Namespace에서 SNAT: `172.16.1.218 → 192.168.22.185`

## COMP1-COMP2 VM간 통신

**시나리오**: Compute2의 VM(172.16.1.33) → Compute1의 VM(172.16.1.218) ping

이 환경에서 두 Compute는 **다른 물리 서버**에 있고 관리 IP 대역도 다름 (192.168.23.x vs 192.168.24.x).

**Compute1 ens160 캡처**

```bash
# ARP (먼저 MAC 주소 조회)
192.168.23.237 > 192.168.24.174 [OTV]
  ARP: who-has 172.16.1.218 tell 172.16.1.33
  ARP Reply: 172.16.1.218 is-at fa:16:3e:a7:f5:6a

# ICMP
192.168.24.174 > 192.168.23.237 [OTV]
  Inner: 172.16.1.33 > 172.16.1.218 ICMP echo request
192.168.23.237 > 192.168.24.174 [OTV]
  Inner: 172.16.1.218 > 172.16.1.33 ICMP echo reply
```

**핵심 포인트**: Compute 노드의 물리 IP 대역(192.168.23.x vs 192.168.24.x)이 달라도 VXLAN 오버레이 덕분에 같은 Tenant N/W(172.16.1.0/24)처럼 통신 가능. **이게 VXLAN의 핵심 가치** — 물리 네트워크 토폴로지에 무관하게 논리 L2 세그먼트 확장.

## 이후 방향성(COMP 확장)

현재 Compute 1대에서 **여러 대(Compute N)로 수평 확장**하는 방향성 제시.

VXLAN Tunnels가 중심 허브 역할을 하며, 새로운 Compute 노드를 추가할 때마다:

- ens160에 VXLAN 터널 엔드포인트 설정
- Self-Service Bridge + VXLAN Interface 생성
- Controller의 L2 Population 또는 Flood & Learn으로 MAC 테이블 자동 전파

→ 애플리케이션/VM 입장에서는 아무 변경 없이 그대로 통신 가능.

## 이후 방향성(Neutron 아키텍처 심화)

더 나아간 방향성: **ML2 Plug-in + Arista/OVS 기반 엔터프라이즈 아키텍처** 소개.

**Neutron 구조**

```bash
Client (CLI/SDK/Horizon)
  → Neutron REST API (net-create, net-delete...)
  → Neutron ML2 Plug-in
      ├── Arista Plug-in  → CVX(Cloud Vision eXtension)
      │                        → eAPI로 Spine-Leaf 스위치 자동 프로비저닝
      └── OVS Plug-in    → Compute Node의 OVS Agent
                               → Leaf 노드에서 VM간 스위칭
```

**Spine-Leaf 토폴로지 (Folded CLOS)**

- Spine 2대 + Leaf N대 + BLEAF(Border Leaf)
- CVX가 Control-Plane 역할: 모든 스위치 설정을 중앙 관리

**핵심 설명 두 가지**:

1. MAC 주소를 물리 스위치가 아닌 **vSwitch에서 소유**하도록 설계 → 물리 스위치의 MAC 테이블 폭발 방지
2. OVS가 Compute 내부에서 VM간 스위칭 처리 → 물리 스위치 부하 감소

현재 SU Cloud 수준(LinuxBridge + VXLAN)보다 훨씬 고도화된 상용 클라우드 아키텍처. **참고 방향성** 정도로 이해하면 됨.