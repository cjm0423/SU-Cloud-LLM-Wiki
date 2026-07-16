---
title: "피드백 개념 정리"
type: "raw"
date: 2026-06-21
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# 피드백 개념 정리

| 개념 | 한 줄 설명 |
| --- | --- |
| VPN | 멀리 있어도 같은 네트워크 안에 있는 것처럼 만드는 기술 |
| Tailscale | WireGuard 기반 P2P VPN. 설정 쉽고 빠름 |
| Proxmox 네트워크 | vmnet(사설) + vmbr0(공인) 분리. SNAT으로 인터넷 연결 |
| Galera | MariaDB 여러 대를 동기 복제로 묶어 하나처럼 쓰는 클러스터 |
| HA | 서버가 죽어도 서비스가 계속되는 구조 |
| 3대인 이유 | Quorum(과반수 투표)으로 Split-Brain 방지 |
| VIP | Virtual IP. 누구든 살아있는 노드가 가져가는 IP |

---

### 1. VPN — 다른 네트워크에 어떻게 접속하나

OpenStack VM들은 `192.168.100.x` 대역. 이 대역은 Proxmox 안에서만 존재하는 **사설 네트워크**. 학교 밖에서는 이 IP로 접속할 수 없음.

**VPN이 하는 일**

VPN은 가상의 전용선을 생성. 물리적으로는 멀리 있어도, 마치 같은 네트워크 안에 있는 것처럼 만들어주는 기술.

```bash
[학교 밖 사용자 PC]              [학교 Proxmox]
  192.168.1.x (집 공유기)        192.168.100.x (vmnet)
       │                               │
       └─────── VPN 터널 ──────────────┘
                (암호화된 가상 전용선)
```

VPN 터널 안으로 들어오면 PC가 마치 `192.168.100.x` 네트워크 안에 있는 것처럼 동작.

**Tailscale이 VPN인 이유**

Tailscale은 WireGuard 기반 VPN. 사용자 PC와 pve(`100.98.185.101`)가 Tailscale 망(`100.x.x.x`)으로 연결되어 있고, pve가 vmnet의 게이트웨이(`192.168.100.1`)이기 때문에, Tailscale로 pve에 연결하면 `192.168.100.x` 대역 전체에 접근 가능.

**일반 VPN vs Tailscale 차이**

일반 VPN은 중앙 서버가 있어서 모든 트래픽이 거기를 거침. Tailscale은 기기끼리 직접 연결(P2P)하는 방식이라 훨씬 빠르고 설정이 간단.

---

### 2. Proxmox 단 네트워크 구조

Proxmox 안에는 네트워크가 여러 층이다.

```bash
[인터넷]
    │
  eno1 (물리 NIC)
    │
  vmbr0 (공인 IP: 210.94.240.179)  ← 학교 인터넷과 연결
    │
  natzone/vmnet (192.168.100.1/24)  ← VM들의 사설 네트워크
    │ SNAT (192.168.100.x → 공인 IP)
    ├── VM 200 (cjm-lb,  .201)
    ├── VM 201 (cjm-ct01, .202)
    ├── VM 202 (cjm-ct02, .203)
    └── ...

  tailscale0 (100.98.185.101)       ← 외부 접속용 VPN
```

핵심은 VM들이 `vmbr0`에 직접 붙으면 공인 IP를 써야 하고 학교 보안장비에 노출됨. 그래서 `vmnet`이라는 **내부 전용 브리지**를 만들고 SNAT으로 인터넷에 나가게 한 것. 이 구조 덕분에 VM이 늘어나도 공인 IP가 추가로 필요 없다.

---

### 3. MariaDB Galera — 왜 DB를 3대로?

**DB 1대만 있을 때의 문제**

```bash
[Nova, Keystone, Neutron...]
          │ DB 쿼리
          ▼
      MariaDB (1대)  ← 이게 죽으면?
                       OpenStack 전체 다운
```

DB가 단일 장애점(Single Point of Failure).

**Galera가 해결하는 방법 → 고가용성이 아닌 모든것이 active [고가용성 다중 마스터 클러스터링]**

Galera는 MariaDB 여러 대를 **하나처럼** 동작하게 묶어줌.

```bash
[Nova, Keystone...]
          │
          ▼
      HAProxy (VIP .200)
     /        |        \
 MariaDB1  MariaDB2  MariaDB3
  (ct01)    (ct02)    (ct03)
    ↕          ↕         ↕
    └──── Galera 동기화 ────┘
         (항상 동일한 데이터)
```

Galera는 **동기 복제**를 함. MariaDB1에 데이터가 쓰이면 2, 3에도 **동시에** 반영. 그래서 ct01이 죽어도 ct02나 ct03이 똑같은 데이터를 갖고 있어서 서비스가 계속됨.

HAProxy는 3대 중 1대(`ct01`)만 active로 쓰고 나머지는 backup으로 대기. 쓰기 요청이 분산되면 충돌이 날 수 있기 때문.

---

### 4. HA — 왜 컨트롤러를 3대로 하나

**HA(High Availability) 고가용성**

**컨트롤러 1대일 때**

```bash
[사용자]
    │
    ▼
Controller (1대)  ← 죽으면 모든 API 불통
  Keystone
  Nova-API
  Neutron
  ...
```

**컨트롤러 3대 + HAProxy**

```bash
[사용자]
    │
    ▼
VIP 192.168.100.200 (Keepalived가 관리)
    │
  HAProxy
 /   |   \
ct01 ct02 ct03    ← 어느 하나가 죽어도 나머지 2대가 받음
```

**왜 3대인가**

2대로는 HA가 불완전. 네트워크가 끊겨서 두 서버가 서로 상대방이 죽었다고 판단하면 둘 다 자기가 master라고 주장하는 **Split-Brain** 문제 발생.

3대면 항상 과반수(2대)로 투표해서 어느 쪽이 살아있는지 결정 가능. 이걸 **Quorum(쿼럼)** 이라고 함.

```bash
ct01 ↔ ct02 ↔ ct03
  └─ ct01이 죽으면 ─┘
        ct02, ct03이 2:0으로 투표
        → ct02 또는 ct03이 master
```

**Keepalived의 역할**

VIP(`192.168.100.200`)를 관리. 3대 중 1대가 VIP를 들고 있다가 죽으면 다른 노드로 VIP가 자동으로 이동. 사용자는 VIP만 바라보기 때문에 뒤에서 어느 노드가 처리하든 상관없음.

---

### 5 . VIP(Virtual IP, 가상 IP)는 특정 서버 한 대에 고정된 IP가 아니라, **여러 서버 중 살아있는 서버가 들고 있는 IP**.

일반 IP vs VIP

**일반 IP**

```bash
ct01 → 192.168.100.202 (고정)
ct02 → 192.168.100.203 (고정)
ct03 → 192.168.100.204 (고정)
```

ct01이 죽으면 `.202`로 접속 불가. 사용자가 ct02 IP로 다시 접속해야 함.

**VIP**

```bash
VIP → 192.168.100.200 (지금은 ct01이 들고 있음)

ct01이 죽으면?
→ ct02가 자동으로 .200을 가져감
→ 사용자는 .200으로 계속 접속
```

---

### 6. VIP 구현 방법들

**1. Keepalived (VRRP)**

내 환경에서 쓰는 방식. 서버들끼리 VRRP 프로토콜로 "나 살아있어"를 주고받다가, master가 죽으면 backup이 priority에 따라 VIP를 가져감.

```bash
ct01 (master, VIP 들고 있음)
ct02 (backup, 대기 중)
ct03 (backup, 대기 중)

ct01 죽으면 → ct02가 VIP 가져감
```

설정이 단순하고 가벼움. 온프레미스 환경에서 가장 많이 씀.

**2. Pacemaker + Corosync**

Keepalived보다 훨씬 강력한 클러스터링 소프트웨어. VIP뿐만 아니라 서비스 자체를 다른 노드로 이전시키는 것도 가능. 설정도 복잡.

**3. 클라우드 로드밸런서**

AWS의 ELB, GCP의 Load Balancer 같은 것. 클라우드에서는 VIP 개념 대신 로드밸런서 DNS 주소를 씀. 인프라가 알아서 관리해줘서 Keepalived 같은 걸 직접 설정할 필요가 없음.

**4. DNS 라운드로빈**

같은 도메인에 여러 IP를 등록해두는 방식. 엄밀히는 VIP가 아니지만 비슷한 효과를 냄. 다만 서버가 죽어도 DNS가 그 IP를 계속 반환할 수 있어서 완전한 HA는 아님.

---

### 7. RabbitMQ → 메세지큐 정의 & 역할[kafka / pubsub / +@]

서비스들 사이에서 메시지를 전달하는 역할

```bash
Nova → [RabbitMQ 큐에 메시지 넣음] → Neutron이 꺼내서 처리
Nova → [RabbitMQ 큐에 메시지 넣음] → Cinder가 꺼내서 처리
```

VM 생성 요청이 들어올 때 내부에서 이런 일이 발생.

```bash
사용자: "VM 만들어줘"
    │
Nova-API: "알겠어" → RabbitMQ에 "VM 스케줄링 해줘" 메시지 넣음
    │
Nova-Scheduler: 메시지 꺼냄 → "cp01에 올리면 되겠다" → RabbitMQ에 "cp01에 VM 만들어줘" 넣음
    │
Nova-Compute(cp01): 메시지 꺼냄 → 실제 VM 생성
    │
Neutron: "네트워크 붙여줘" 메시지 받아서 처리
```

RabbitMQ도 클러스터링 진행

---

### 8. HAProxy

들어오는 요청을 여러 서버에 **나눠주는 역할**

1. 부하분산

```bash
사용자 → VIP(.200) → HAProxy → ct01 (바쁨)
                              → ct02 (한가함) ← 여기로 보냄
                              → ct03 (대기)
```

1. 헬스체크

```bash
HAProxy: ct01아 살아있어? → 응답 없음 → ct01 제외
HAProxy: ct02아 살아있어? → OK → ct02로 요청 보냄
HAProxy: ct03아 살아있어? → OK → ct03으로 요청 보냄
```

1. 프로토콜 분리

```bash
:5000 (Keystone)  → ct01, ct02, ct03 Keystone 처리하는 서버들로
:8774 (Nova API)  → ct01, ct02, ct03 Nova API 처리하는 서버들로
:9696 (Neutron)   → ct01, ct02, ct03 Neutron 처리하는 서버들로
:3306 (MariaDB)   → ct01만 (active), ct02, ct03 (backup) MariaDB로
```

**Keepalived와의 관계**

HAProxy와 Keepalived는 항상 같이 씀.

```bash
Keepalived: VIP(.200)를 살아있는 노드로 이동시킴
HAProxy: VIP로 들어온 요청을 3대 컨트롤러로 분배
```

Keepalived는 "VIP가 어디 붙을지" 담당, HAProxy는 "요청을 어디로 보낼지" 담당

---