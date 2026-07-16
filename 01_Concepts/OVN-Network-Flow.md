---
title: "OVN 네트워크 흐름 — VM에서 인터넷까지"
type: "concept"
date: 2026-06-21
tags: ["#openstack", "#ovn", "#networking", "#geneve"]
related_nodes: ["[[01_Concepts/OVN-OVS-Architecture]]", "[[01_Concepts/VXLAN]]", "[[01_Concepts/Floating-IP]]", "[[01_Concepts/Kolla-Ansible]]"]
author: "AI Assistant"
raw_source: ["[[00_Inbox/2026-06-21-ovn-network-flow-raw]]", "[[00_Inbox/2026-06-21-ovn-flow-details-raw]]"]
---

# OVN 네트워크 흐름 — VM에서 인터넷까지

## 한 줄 정의

OVN 환경에서 OpenStack VM의 패킷이 인터넷에 도달하기까지의 전체 경로: `VM → br-int(OVS) → Geneve 터널 → gateway chassis → br-ex → Proxmox SNAT → 인터넷`.

## 상세 설명

### 트래픽 유형 구분

```
[사람이 접속할 때]  사용자 PC
                     │ Tailscale 암호화 터널(100.x.x.x)
                     ▼
                   pve (100.98.185.101)
                     │ vmnet 브리지(192.168.100.1)
                     ▼
             OpenStack VM들 / Horizon / SSH
             → Tailscale이 관리 접속에만 등장

[VM이 인터넷 나갈 때]  cirros (172.22.0.154)
                         │ br-int → Geneve 터널
                         ▼
                       gateway chassis (ct03)
                         │ br-ex → ens19
                         ▼
                 Proxmox natzone → vmbr0 → 인터넷
                 → Tailscale 관여 안 함
```

---

### 전체 흐름 (VM → 인터넷)

```
[cp02] cirros VM (172.22.0.154)
  │ eth0 (MTU 1442)
  ▼ tap1f430626-97
[cp02] br-int (OVS)
  │ Geneve 캡슐화 (UDP/6081)
  │ 192.168.100.206 → 192.168.100.204
  ▼
[ct03] br-int (OVS) ← gateway chassis
  │ Geneve 디캡슐화
  ▼ OVN logical router (main-router)
  │ SNAT①: 172.22.0.154 → 192.168.100.243 (floating IP)
  │ SNAT②: 192.168.100.243 → 192.168.100.221 (라우터 외부 IP)
  ▼ br-ex → ens19
[Proxmox] natzone MASQUERADE
  │ 192.168.100.0/24 → 공인 IP (210.94.240.179)
  ▼ eno1 (물리 NIC)
인터넷 (8.8.8.8)
```

---

### 단계별 상세

**1단계 — VM 안 (cirros)**
```
출발: 172.22.0.154 → 목적: 8.8.8.8
```

**2단계 — cp02의 br-int (OVS)**
- VM eth0 → `tap1f430626-97` → `br-int`
- br-int가 목적지 8.8.8.8 → 게이트웨이(172.22.0.1) → gateway chassis(ct03)로 Geneve 전달 결정
- OVN에서 br-int는 하나가 모든 터널 처리 (수동설치의 `brq` + `vxlan` 분리 구조와 다름)

**3단계 — Geneve 캡슐화**
```
[Outer Header]
  src IP: 192.168.100.206 (cp02 관리망)
  dst IP: 192.168.100.204 (ct03 관리망, gateway chassis)
  proto: UDP / port 6081

[Geneve Header]
  vni: flow key (OVN 자동 관리)
  가변 길이 옵션: OVN 포트/정책 메타데이터

[Inner Payload]
  src IP: 172.22.0.154 (cirros)
  dst IP: 8.8.8.8
```

**4단계 — ct03 (gateway chassis)**
- Geneve 디캡슐화 → 원본 패킷 복원
- OVN logical router가 SNAT 두 번 수행:
  1. Floating IP SNAT: `172.22.0.154 → 192.168.100.243`
  2. 라우터 외부 IP SNAT: `192.168.100.243 → 192.168.100.221`
- `br-ex → ens19`로 외부 출력

**5단계 — Proxmox natzone**
- `192.168.100.221 → 공인 IP (210.94.240.179)` MASQUERADE
- `vmbr0 → eno1` 타고 인터넷으로

---

### tcpdump 실측 (ct03 ens19)

```bash
01:44:21.567238 fa:16:3e:2f:30:1e > 86:97:4e:2a:67:bc
    192.168.100.243 > 8.8.8.8: ICMP echo request
```
- `fa:16:3e:2f:30:1e` = OVN 라우터 external 포트 MAC
- `86:97:4e:2a:67:bc` = Proxmox natzone 게이트웨이 MAC

---

### Geneve vs VXLAN

| 항목 | VXLAN | Geneve |
|------|-------|--------|
| 헤더 | 고정 8바이트 | **가변 길이** 옵션 필드 |
| 메타데이터 | 없음 | OVN 포트/정책 정보를 헤더에 실음 |
| MTU 영향 | 증가 → 패킷 드랍 잦음 | 동일하나 유연한 옵션 |
| 포트 | UDP/4789 | UDP/6081 |

## SU Cloud에서의 활용

- OVN + Geneve 조합으로 Kolla-Ansible 배포
- Gateway Chassis: ct03 (UUID `60a45818-...`)
- Floating IP 동작: OVN Logical Router의 `dnat_and_snat` NAT 규칙
- 외부망 NIC: `ens19` (IP 없음, `br-ex`로 흡수)

## 관련 개념

- [[01_Concepts/OVN-OVS-Architecture]]
- [[01_Concepts/VXLAN]]
- [[01_Concepts/Floating-IP]]
- [[01_Concepts/Kolla-Ansible]]
