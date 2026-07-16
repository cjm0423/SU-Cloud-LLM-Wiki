---
title: "Provider Network vs Self-Service Network"
type: "concept"
date: 2026-06-18
tags: ["#openstack", "#networking", "#neutron"]
status: "stable"
related_nodes: ["[[OpenStack-Overview]]", "[[Neutron]]", "[[VXLAN]]", "[[Floating-IP]]"]
author: "SU-Cloud Team"
---

# Provider Network vs Self-Service Network

> ⚠️ 이 문서의 다이어그램·패킷 흐름은 **LinuxBridge + VXLAN** 시절(구형 수동 설치) 구조 기준이다.
> 현재 SU Cloud(Kolla-Ansible)는 **OVN + Geneve**로 전환됐다 — 실제 흐름은 [[01_Concepts/OVN-Network-Flow]] 참고.
> 여기서는 Provider/Self-Service의 **개념적 차이**(누가 만드는가, 격리 방식, IP 할당)는 백엔드와 무관하게 여전히 유효하다.

## 한 줄 정의

OpenStack에는 두 가지 네트워크 모델이 있다. Provider는 물리 네트워크에 직접 연결, Self-Service는 가상 라우터를 통해 격리된 테넌트 네트워크를 구성한다.

## Provider Network

```
물리 네트워크 (스위치/라우터)
        │
  br-ex (외부 브리지)
        │
     VM NIC
```

- 물리 네트워크와 **직접** 연결된 flat/VLAN 네트워크
- 관리자만 생성 가능
- VM이 외부 IP를 직접 갖거나, 물리 네트워크 DHCP를 그대로 사용
- 구성이 단순하지만 테넌트 간 격리가 어려움

## Self-Service Network

```
VM
 │
br-int (내부 브리지) ── VXLAN 터널 ── 다른 Compute Node의 VM
 │
가상 라우터 (qrouter-xxx namespace)
 │
br-ex (외부 브리지)
 │
물리 네트워크
```

- 테넌트가 직접 생성하는 가상 네트워크 (Private IP: 192.168.x.x 등)
- 가상 라우터가 SNAT/DNAT 처리
- **Floating IP**로 외부에서 VM에 접근 가능
- VXLAN으로 Compute Node 간 트래픽 터널링 → 물리적으로 다른 서버에 있는 VM이 같은 네트워크처럼 동작

## 핵심 차이 비교

| 항목 | Provider | Self-Service |
|------|---------|-------------|
| 생성 권한 | 관리자 | 테넌트(일반 사용자) |
| 격리 | 물리 VLAN 의존 | VXLAN으로 논리 격리 |
| IP 할당 | 물리망 IP 직접 사용 | 사설 IP + Floating IP |
| 복잡도 | 낮음 | 높음 (라우터, namespace) |
| SU Cloud 활용 | 외부 연결 게이트웨이 | 학생별 VM 네트워크 |

## 패킷 흐름 추적 (Self-Service)

외부 → VM 방향:
```
인터넷 → 물리 NIC → br-ex → qrouter namespace (DNAT: Floating IP → Private IP) → VXLAN → br-int → VM
```

VM → 외부 방향:
```
VM → br-int → VXLAN → qrouter namespace (SNAT) → br-ex → 물리 NIC → 인터넷
```

## SU Cloud에서의 활용

- 학생들이 신청한 VM은 각자 **Self-Service Network** 안에 배치
- 외부 접근이 필요한 VM만 **Floating IP** 부여
- Provider Network는 물리 스위치와 연결되는 공용 게이트웨이 역할

## 관련 개념

- [[Neutron]] — 이 두 네트워크를 관리하는 OpenStack 컴포넌트
- [[VXLAN]] — Self-Service Network의 격리 기술
- [[Floating-IP]] — Self-Service VM의 외부 접근 수단
- [[Linux-Bridge]] — br-int, br-ex의 실제 구현체
