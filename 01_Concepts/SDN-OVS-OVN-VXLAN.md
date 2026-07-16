---
title: "SDN · LinuxBridge · OVS · OVN · VXLAN/Geneve — 개념 정리"
type: "concept"
date: 2026-06-21
tags: ["#networking", "#ovn", "#ovs", "#sdn", "#vxlan"]
status: "review"
related_nodes: ["[[01_Concepts/VXLAN]]", "[[01_Concepts/OVN-OVS-Architecture]]", "[[01_Concepts/OVN-Network-Flow]]", "[[01_Concepts/Provider-vs-SelfService-Network]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-06-21-sdn-ovs-ovn-vxlan-raw]]"
---

# SDN · LinuxBridge · OVS · OVN · VXLAN/Geneve — 개념 정리

## 한 줄 정의

OpenStack 네트워킹을 구성하는 소프트웨어 정의 네트워킹(SDN) 스택의 각 레이어 개념 정리.

## 상세 설명

### SDN (Software Defined Networking)

- 네트워크 장비의 **제어 플레인(Control Plane)** 과 **데이터 플레인(Data Plane)** 을 분리
- 소프트웨어로 네트워크 경로·정책을 프로그래밍 방식으로 제어
- OpenStack Neutron이 SDN 컨트롤러 역할

---

### LinuxBridge

- Linux 커널 내장 L2 스위치 기능
- 단순하고 안정적이나 기능이 제한적
- OpenStack에서 VXLAN 기반 오버레이 구현 시 사용 (구형)

```
brq-<net-id>  ← 네트워크마다 별도 브리지
  ├─ tap<port-id>  ← VM NIC
  └─ vxlan-<vni>   ← 터널 인터페이스 (노드별 직접 연결)
```

**단점**: 노드 수가 늘면 `vxlan-N` 인터페이스가 선형으로 증가, 관리 복잡.

---

### OVS (Open vSwitch)

- 고기능 소프트웨어 스위치 엔진 (커널 모듈 + `ovs-vswitchd` 데몬)
- OpenFlow flow table로 패킷 처리 규칙 프로그래밍 가능
- VXLAN, Geneve, GRE 등 다양한 터널 지원
- LinuxBridge보다 훨씬 강력하나 단독으로 쓰면 flow 관리가 복잡

---

### OVN (Open Virtual Network)

- OVS 위에 얹는 **논리 네트워크 오케스트레이션 레이어**
- NB DB(Northbound)에 논리 스위치/라우터를 정의 → SB DB(Southbound)로 변환 → 각 노드 OVS에 flow 자동 프로그래밍
- OVN = 두뇌(control plane), OVS = 손발(data plane)

**OpenStack에서의 OVN 역할**:
- Neutron이 OVN NB DB에 논리 네트워크 정의 작성
- ovn-northd가 논리 → 물리 변환
- 각 노드의 ovn-controller가 자기 담당 flow를 OVS에 주입

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
- [[01_Concepts/OVN-OVS-Architecture]]
- [[01_Concepts/OVN-Network-Flow]]
- [[01_Concepts/Kolla-Ansible]]
- [[01_Concepts/Provider-vs-SelfService-Network]]
