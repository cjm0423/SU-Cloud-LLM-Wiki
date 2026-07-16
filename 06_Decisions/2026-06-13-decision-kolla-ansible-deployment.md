---
title: "OpenStack 배포 방식 — Kolla-Ansible 채택"
type: "decision"
date: 2026-06-13
tags: ["#decision", "#kolla-ansible", "#openstack"]
status: "stable"
related_nodes: ["[[04_Meetings/2026-06-13-kickoff]]", "[[01_Concepts/Kolla-Ansible]]", "[[03_Guides/Kolla-Ansible-Install-Guide]]"]
deciders: ["[[05_People/차지만]]", "[[05_People/조충희 교수님]]"]
author: "AI Assistant"
---

# OpenStack 배포 방식 — Kolla-Ansible 채택

## 한 줄 요약

수동 설치 대신 **Kolla-Ansible**로 OpenStack을 배포한다. 수동 설치는 학습 목적에만 사용한다.

## 배경 및 문제 상황

Phase 0(6월)에서 멘티들이 수동 설치로 OpenStack을 직접 공부한 후, Phase 1(7월)부터 실제 개발계·운영계 구축을 시작해야 했다. 수동 설치를 프로덕션 배포에도 계속 쓸지, 자동화 도구를 도입할지 선택해야 했다.

## 고려한 대안

| 대안 | 장점 | 단점 |
|------|------|------|
| **Kolla-Ansible** ✅ | 30~60분 배포, Docker 컨테이너 격리, 검증된 절차, 버전 관리 자동 | 내부 구조 파악 어려움 (학습용 부적합) |
| 수동 설치 | 내부 구조 완전 파악, 세밀한 커스터마이징 | 멀티노드 시 수 일 소요, 실수 여지 많음, 반복 불가 |
| DevStack | 빠른 단일 노드 설치 | 프로덕션 비적합, HA 구성 불가 |

## 결정 및 근거

**Kolla-Ansible 채택.**

- 7-node HA 클러스터를 수동으로 설치하면 수 주가 소요되고 재현이 어렵다
- Kolla-Ansible은 `globals.yml`에 NIC 이름 두 개만 넣으면 30~60분에 완성 → 반복 가능한 배포
- 컨테이너화로 버전 의존성 충돌 격리
- 수동 설치는 학습(Phase 0) 에서 이미 달성됨 → 더 이상 프로덕션에서 반복할 이유 없음

## 트레이드오프

- **얻은 것:** 빠르고 반복 가능한 배포, 컨테이너 기반 격리, 공식 지원
- **포기한 것:** 패키지 단위 세밀한 커스터마이징 (필요 시 Kolla 이미지 커스터마이징으로 대체 가능)
- **위험 요소:** EOL 브랜치 사용 시 `install-deps` 단계 실패 (실제 발생 → [[02_QnA_Archive/2026-06-28-kolla-ansible-deploy-troubleshooting]])

## 재검토 조건

- OpenStack 릴리즈가 Kolla-Ansible 지원 범위를 벗어나는 경우
- Kolla가 지원하지 않는 특수한 설정이 필요한 경우

## 관련 문서

- [[04_Meetings/2026-06-13-kickoff]]
- [[01_Concepts/Kolla-Ansible]]
- [[03_Guides/Kolla-Ansible-Install-Guide]]
- [[02_QnA_Archive/2026-06-28-kolla-ansible-deploy-troubleshooting]]
