---
title: "개발계 배포 방식 — Gaming5 베어메탈 AIO"
type: "decision"
date: 2026-07-05
tags: ["#decision", "#devpc", "#openstack"]
status: "stable"
related_nodes: ["[[04_Meetings/2026-07-12-meeting-weekly]]", "[[03_Guides/DevPC-Kolla-Ansible-Setup-Guide]]", "[[01_Concepts/SU-Cloud-Campus-Network]]"]
deciders: ["[[05_People/차지만]]"]
author: "AI Assistant"
---

# 개발계 배포 방식 — Gaming5 베어메탈 AIO

## 한 줄 요약

Gaming5(개발계)는 Proxmox 없이 **베어메탈 Ubuntu에 Kolla-Ansible AIO**로 배포한다.

## 배경 및 문제 상황

개발계용 서버(Gaming5)에 OpenStack을 구축해야 했다. 운영계(P520)와 같은 방식(Proxmox → 멀티노드 VM)으로 할지, 더 단순한 방식으로 갈지 선택이 필요했다. Gaming5는 물리 NIC가 1개뿐이라는 제약도 있었다.

## 고려한 대안

| 대안 | 장점 | 단점 |
|------|------|------|
| **베어메탈 Ubuntu + AIO** ✅ | 가상화 오버헤드 없음, 빠른 배포, 단순한 구조 | NIC 1개 제약 → veth 트릭 필요 |
| Proxmox + 멀티노드 VM | 운영계와 동일한 구조, 스냅샷 용이 | 중첩 가상화 오버헤드, NIC 부족 |
| DevStack | 초고속 설치 | 프로덕션 비적합, HA 불가 |

## 결정 및 근거

**베어메탈 + AIO 채택.**

- 개발계는 "빨리 올려서 테스트하는" 환경 → 오버헤드 최소화 우선
- AIO는 단일 노드에 controller+compute가 모두 올라가 구조가 단순
- NIC 1개 제약은 `brbond0 + veth 트릭`으로 해결 (관리망 브리지 + veth1을 neutron external interface로)
- MAC 차단 문제는 netplan MAC 스푸핑으로 임시 해결 (정식 해결은 캠퍼스팀 등록 요청 병행)

## 트레이드오프

- **얻은 것:** 단순한 구조, 가상화 오버헤드 없음, 빠른 이터레이션
- **포기한 것:** Proxmox 스냅샷, VM 단위 격리
- **위험 요소:**
  - NIC 1개라 관리망/외부망 완전 분리 불가 → veth 트릭 의존
  - MAC 스푸핑 중 팀원 노트북 동시 접속 금지 조건 (충돌 위험)

## 재검토 조건

- 네트워크 장비를 추가해 NIC 2개 환경이 되면 운영계와 동일한 구조로 전환 검토
- MAC 정식 등록 완료 후 스푸핑 제거

## 관련 문서

- [[03_Guides/DevPC-Kolla-Ansible-Setup-Guide]]
- [[02_QnA_Archive/2026-07-05-devpc-180-network-failure-resolved]]
- [[01_Concepts/SU-Cloud-Campus-Network]]
