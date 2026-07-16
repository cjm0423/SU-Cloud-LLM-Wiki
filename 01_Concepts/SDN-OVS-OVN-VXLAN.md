---
title: "SDN · LinuxBridge · OVS · OVN · VXLAN/Geneve — 개념 정리"
type: "concept"
date: 2026-06-21
tags: ["#networking", "#ovn", "#ovs", "#sdn", "#vxlan"]
status: "stable"
related_nodes: ["[[01_Concepts/VXLAN]]", "[[01_Concepts/Linux-Bridge]]", "[[01_Concepts/OVN-OVS-Architecture]]", "[[01_Concepts/OVN-Network-Flow]]", "[[01_Concepts/Provider-vs-SelfService-Network]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-06-21-sdn-ovs-ovn-vxlan-raw]]"
---

# SDN · LinuxBridge · OVS · OVN · VXLAN/Geneve — 개념 정리

> ℹ️ OVN/OVS 컴포넌트 상세(NB/SB DB, ovn-northd, 브리지 구조)는 [[01_Concepts/OVN-OVS-Architecture]]에 정리되어 있다.
> 이 문서는 **SDN이라는 큰 틀에서 각 레이어가 왜 등장했는지**와 SU Cloud가 어떤 순서로 이 스택을 거쳐왔는지에 집중한다.

## 한 줄 정의

OpenStack 네트워킹을 구성하는 소프트웨어 정의 네트워킹(SDN) 스택이 LinuxBridge → OVS → OVN으로 진화해온 배경과 이유.

## 상세 설명

### SDN (Software Defined Networking)

- 네트워크 장비의 **제어 플레인(Control Plane)** 과 **데이터 플레인(Data Plane)** 을 분리
- 소프트웨어로 네트워크 경로·정책을 프로그래밍 방식으로 제어
- OpenStack Neutron이 SDN 컨트롤러 역할

---

### 왜 LinuxBridge → OVS → OVN 순으로 넘어갔나

| 단계 | 한계 | 다음 단계가 해결한 것 |
|------|------|----------------------|
| **LinuxBridge** (→ [[01_Concepts/Linux-Bridge]]) | 단순 L2 스위칭만 가능, 프로그래머블 제어 불가 | OVS가 OpenFlow 기반 flow 제어 도입 |
| **OVS** (Open vSwitch) | flow table을 노드마다 직접 관리해야 해서, 노드가 늘수록 운영 복잡도 급증 | OVN이 논리 정의 → 물리 flow 자동 변환을 대신 처리 |
| **OVN** (→ [[01_Concepts/OVN-OVS-Architecture]]) | (현재 SU Cloud가 사용하는 최종 단계) | — |

OVN은 OVS 위에 얹는 논리 네트워크 오케스트레이션 레이어로, "OVN = 두뇌, OVS = 손발" 관계다 — 구성요소별 상세는 [[01_Concepts/OVN-OVS-Architecture]] 참고.

---

### 캡슐화 프로토콜 비교

| 항목 | VXLAN | Geneve |
|------|-------|--------|
| 표준 | RFC 7348 | RFC 8926 |
| 헤더 크기 | 고정 8바이트 | **가변 길이** (옵션 필드) |
| 메타데이터 | VNI(24bit)만 | OVN 포트/정책 정보를 헤더에 담을 수 있음 |
| MTU 영향 | 증가, 패킷 드랍 빈번 | 동일하나 유연한 옵션 처리 |
| UDP 포트 | 4789 | 6081 |
| 사용 환경 | LinuxBridge, OVS ML2 (구형) | **OVN (현재 SU Cloud)** |

---

### SU Cloud에서의 진화

```
초기 (수동 설치, 이민기 방식)
  LinuxBridge + VXLAN
    brq-<id> + vxlan-N 직결
    qrouter namespace가 라우팅 처리

현재 (Kolla-Ansible, 차지만 방식)
  OVN + Geneve
    br-int 하나에 모든 터널 논리적 통합
    OVN Logical Router가 namespace 없이 flow로 라우팅
    Gateway Chassis(ct03)가 N-S 트래픽 처리
```

## SU Cloud에서의 활용

- Kolla-Ansible 배포 시 `neutron_plugin_agent: "ovn"` 설정
- OVN + Geneve(UDP/6081)로 VM 간 트래픽 캡슐화
- Gateway Chassis = ct03 (ens19 → br-ex 연결, 외부망 출구)

## 관련 개념

- [[01_Concepts/VXLAN]]
- [[01_Concepts/Linux-Bridge]]
- [[01_Concepts/OVN-OVS-Architecture]]
- [[01_Concepts/OVN-Network-Flow]]
- [[01_Concepts/Kolla-Ansible]]
- [[01_Concepts/Provider-vs-SelfService-Network]]
