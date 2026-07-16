---
title: "Neutron 네트워킹 백엔드 — OVN + Geneve 채택"
type: "decision"
date: 2026-06-21
tags: ["#decision", "#ovn", "#networking"]
status: "stable"
related_nodes: ["[[04_Meetings/2026-06-28-meeting-weekly]]", "[[01_Concepts/OVN-OVS-Architecture]]", "[[01_Concepts/SDN-OVS-OVN-VXLAN]]"]
deciders: ["[[05_People/차지만]]", "[[05_People/백지원]]"]
author: "AI Assistant"
---

# Neutron 네트워킹 백엔드 — OVN + Geneve 채택

## 한 줄 요약

Neutron 백엔드로 **OVN + Geneve** 를 사용한다. LinuxBridge+VXLAN은 수동 설치 학습에만 사용한다.

## 배경 및 문제 상황

Kolla-Ansible 배포 시 Neutron 플러그인을 선택해야 했다. 이민기 멘토의 수동 설치 환경은 LinuxBridge+VXLAN 방식을 썼고, 차지만 멘토는 Kolla 기본값인 OVN을 선택해야 할지 판단이 필요했다.

## 고려한 대안

| 대안 | 장점 | 단점 |
|------|------|------|
| **OVN + Geneve** ✅ | Kolla-Ansible 기본값, br-int 하나로 터널 통합, Geneve 메타데이터 유연성, Gateway Chassis HA | 학습 곡선 높음, 진단 도구(ovn-nbctl/sbctl)가 컨테이너 내부에만 있음 |
| LinuxBridge + VXLAN | 구조 단순, 이민기 환경과 동일 | 노드 증가 시 vxlan-N 인터페이스 선형 증가, qrouter namespace 디버깅 복잡 |
| OVS ML2 (VXLAN, no OVN) | OVS 기반으로 이해 쉬움 | OVN 없이 OVS만 쓰면 flow 관리를 직접 해야 해서 더 복잡 |

## 결정 및 근거

**OVN + Geneve 채택.**

- Kolla-Ansible 22.x의 기본값이 OVN → 검증된 조합
- OVN은 `br-int` 하나에 모든 터널을 논리적으로 통합 → 노드 증가에도 인터페이스 수 일정
- Geneve는 헤더에 OVN 포트/정책 메타데이터를 실을 수 있어 유연성 높음
- Gateway Chassis 구조로 N-S 트래픽 HA 지원
- 260628 회의에서 교수님이 OVN/OVS 시각화 자료 제작 요청 → 학습 방향과도 일치

## 트레이드오프

- **얻은 것:** 확장성, Kolla 공식 지원, Geneve 유연성, Gateway Chassis HA
- **포기한 것:** LinuxBridge 방식의 단순한 구조 (이해하기 쉬운 1:1 대응)
- **위험 요소:** `ovn-nbctl`/`ovn-sbctl`이 컨테이너 내부에서만 실행 가능 → 진단 시 `docker exec ovn_northd` 필수

## 재검토 조건

- OVN 관련 미해결 버그가 운영에 영향을 줄 경우
- 팀원 전원이 OVN 구조를 이해하기 어렵다는 판단이 나올 경우 (LinuxBridge로 복귀 검토)

## 관련 문서

- [[01_Concepts/OVN-OVS-Architecture]]
- [[01_Concepts/OVN-Network-Flow]]
- [[01_Concepts/SDN-OVS-OVN-VXLAN]]
- [[04_Meetings/2026-06-28-meeting-weekly]]
