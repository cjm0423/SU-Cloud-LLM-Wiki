---
title: "HA 고가용성 핵심 개념 — VPN·Galera·Quorum·VIP·HAProxy"
type: "concept"
date: 2026-06-21
tags: ["#openstack", "#ha", "#networking", "#mariadb", "#haproxy"]
status: "stable"
related_nodes: ["[[01_Concepts/OpenStack-Overview]]", "[[01_Concepts/Kolla-Ansible]]", "[[04_Meetings/2026-06-28-meeting-weekly]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-06-21-feedback-concepts-raw]]"
---

# HA 고가용성 핵심 개념 — VPN·Galera·Quorum·VIP·HAProxy

## 한 줄 정의

OpenStack 클러스터에서 서버 1대가 죽어도 서비스가 계속되도록 보장하는 기술의 모음 (VIP, Keepalived, MariaDB Galera, HAProxy, RabbitMQ).

## 상세 설명

### VPN & Tailscale

| 개념 | 설명 |
|------|------|
| VPN | 물리적으로 멀리 있어도 같은 네트워크 안에 있는 것처럼 만드는 기술 (암호화 가상 전용선) |
| Tailscale | WireGuard 기반 P2P VPN. 설정 쉽고, 중앙 서버 거치지 않고 기기 간 직접 연결 |

```
[학교 밖 사용자 PC]              [학교 Proxmox]
  192.168.1.x (집 공유기)        192.168.100.x (vmnet)
       └─────────── Tailscale WireGuard 터널 ──────────┘
```

Tailscale로 Proxmox(`100.98.185.101`)에 연결하면 vmnet(`192.168.100.x`) 전체에 접근 가능.

일반 VPN과 달리 P2P 연결이라 훨씬 빠르고 설정이 단순.

---

### Proxmox 단 네트워크 구조

```
[인터넷]
    │
  eno1 (물리 NIC)
    │
  vmbr0 (공인 IP: 210.94.240.179)  ← 학교 인터넷과 연결
    │
  natzone/vmnet (192.168.100.1/24)  ← VM들의 사설 네트워크 (SNAT)
    ├── VM 200 (cjm-lb,  .201)
    ├── VM 201 (cjm-ct01, .202)
    └── ...
  tailscale0 (100.98.185.101)       ← 외부 접속용 VPN
```

VM들이 `vmnet` 내부 브리지에 있어 공인 IP 추가 없이도 SNAT으로 인터넷 접근 가능.

---

### MariaDB Galera — DB 고가용성

**문제**: DB 1대 = 단일 장애점

**Galera 해결책**: MariaDB 여러 대를 동기 복제로 묶어 하나처럼 동작

```
[Nova, Keystone...]
          │
          ▼
      HAProxy (VIP .200)
     /        |        \
 MariaDB1  MariaDB2  MariaDB3
  (ct01)    (ct02)    (ct03)
    ↕          ↕         ↕
    └──── Galera 동기 복제 ────┘
         (항상 동일한 데이터)
```

- **동기 복제**: MariaDB1에 데이터 쓰이면 2, 3에도 **동시** 반영
- HAProxy는 1대를 active, 나머지를 backup으로 → 쓰기 충돌 방지

---

### HA와 쿼럼 — 왜 Controller 3대인가

**2대의 문제**: 네트워크 분리 시 둘 다 자기가 master라고 주장 → **Split-Brain**

**3대의 해결**: 과반수(2/3)로 투표 가능

```
ct01 ↔ ct02 ↔ ct03
  └─ ct01이 죽으면 ─┘
        ct02, ct03이 2:0으로 투표
        → 나머지 2대가 계속 서비스
```

**쿼럼(Quorum)**: 분산 시스템에서 의사 결정에 필요한 최소 과반수 노드 수. 홀수 구성이 필수.

---

### VIP (Virtual IP)

특정 서버에 고정된 IP가 아닌, **살아있는 서버가 들고 있는 IP**.

```
VIP → 192.168.100.200 (지금은 ct01이 들고 있음)

ct01이 죽으면?
→ ct02가 자동으로 .200을 가져감
→ 사용자는 .200으로 계속 접속
```

**VIP 구현 방법**
| 방법 | 설명 |
|------|------|
| **Keepalived (VRRP)** | 서버들끼리 "나 살아있어" 교환, master 죽으면 backup이 VIP 인수. SU Cloud 사용 방식 |
| Pacemaker + Corosync | 더 강력한 클러스터 소프트웨어, 설정 복잡 |
| 클라우드 LB | AWS ELB 등, 인프라가 알아서 관리 |

---

### HAProxy — 로드밸런서

들어오는 요청을 여러 서버에 분배:

```
사용자 → VIP(.200) → HAProxy → ct01 / ct02 / ct03
```

- **부하 분산**: 여러 controller에 요청 분산
- **헬스체크**: 죽은 서버를 자동으로 제외
- **포트별 분리**: `:5000`(Keystone), `:8774`(Nova), `:9696`(Neutron), `:3306`(MariaDB)

**Keepalived와의 관계**:
- Keepalived = "VIP가 어디 붙을지" 담당
- HAProxy = "VIP로 들어온 요청을 어디로 보낼지" 담당

---

### RabbitMQ — 메시지 큐

서비스들 사이에서 비동기 메시지 전달:

```
사용자: "VM 만들어줘"
    │
Nova-API → RabbitMQ("VM 스케줄링 해줘")
    │
Nova-Scheduler → RabbitMQ("cp01에 VM 만들어줘")
    │
Nova-Compute(cp01) → 실제 VM 생성
    │
Neutron → 네트워크 연결
```

RabbitMQ도 클러스터 구성 필요 (3대 controller 각각에 설치).

## SU Cloud에서의 활용

- Kolla-Ansible 배포 시 Controller 3대(ct01~ct03) 구성
- VIP: `192.168.100.200`, HAProxy + Keepalived(VRRP) 조합
- MariaDB Galera 멀티마스터 클러스터 (ct01 active, ct02/ct03 backup)
- RabbitMQ 3대 클러스터 (각 controller에 컨테이너로)

## 관련 개념

- [[01_Concepts/Kolla-Ansible]]
- [[01_Concepts/OpenStack-Overview]]
- [[01_Concepts/VXLAN]]
