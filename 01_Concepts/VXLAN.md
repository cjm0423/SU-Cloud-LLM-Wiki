---
title: "VXLAN"
type: "concept"
date: 2026-06-18
tags: ["#networking", "#vxlan", "#openstack", "#overlay-network"]
status: "stable"
related_nodes: ["[[Provider-vs-SelfService-Network]]", "[[Neutron]]", "[[Linux-Bridge]]"]
author: "SU-Cloud Team"
---

# VXLAN

## 한 줄 정의

VXLAN(Virtual Extensible LAN)은 L3 네트워크 위에 L2 네트워크를 터널로 확장하는 오버레이 기술로, OpenStack Self-Service Network에서 Compute Node 간 VM 트래픽을 격리·전달할 때 사용한다.

## 왜 VXLAN이 필요한가

물리적으로 다른 서버(Compute Node)에 있는 VM들이 **같은 가상 네트워크**에 있는 것처럼 통신해야 한다.
기존 VLAN은 최대 4096개 제한이 있지만, VXLAN은 최대 1600만 개의 논리 네트워크를 지원한다.

```
Compute Node A                    Compute Node B
┌─────────────┐                  ┌─────────────┐
│   VM-1      │                  │   VM-2      │
│ 192.168.1.2 │                  │ 192.168.1.3 │
└──────┬──────┘                  └──────┬──────┘
       │ br-int                         │ br-int
       │                                │
  VXLAN 터널 ──────────────────── VXLAN 터널
  (UDP 4789)    물리 네트워크      (UDP 4789)
```

## 핵심 개념

- **VNI (VXLAN Network Identifier):** 논리 네트워크 ID (24bit, ~1600만 개)
- **VTEP (VXLAN Tunnel Endpoint):** 터널의 양 끝점. br-int에 바인딩된 각 Compute Node의 물리 NIC
- **UDP 4789:** VXLAN 기본 포트. 원본 L2 프레임을 UDP로 캡슐화해서 전송

## 패킷 구조

```
[ 외부 IP 헤더 ] [ UDP 헤더 ] [ VXLAN 헤더 (VNI) ] [ 원본 L2 이더넷 프레임 ]
```

## OpenStack에서의 흐름

1. VM-1이 VM-2로 패킷 전송
2. Compute Node A의 br-int가 수신
3. VXLAN 에이전트(Neutron)가 VM-2가 어느 VTEP에 있는지 확인
4. UDP/VXLAN으로 캡슐화하여 Compute Node B로 전송
5. Compute Node B의 br-int가 디캡슐화 후 VM-2에 전달

## SU Cloud에서의 의미

서버가 2대 이상으로 확장될 때 학생들이 각기 다른 서버에 배포된 VM끼리 같은 네트워크로 묶이려면 VXLAN 이해가 필수다.

## 관련 개념

- [[Provider-vs-SelfService-Network]] — VXLAN이 사용되는 Self-Service Network
- [[Linux-Bridge]] — br-int, br-ex 구현체
- [[Neutron]] — VXLAN 터널 관리 주체
