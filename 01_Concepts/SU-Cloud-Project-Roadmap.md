---
title: "SU Cloud 프로젝트 로드맵 (2026년 6월 ~ 12월)"
type: "concept"
date: 2026-06-01
tags: ["#su-cloud", "#roadmap", "#project"]
related_nodes: ["[[01_Concepts/SU-Cloud-Project-Overview]]", "[[01_Concepts/Kolla-Ansible]]", "[[04_Meetings/2026-06-13-kickoff]]"]
author: "AI Assistant"
raw_source: ["[[00_Inbox/2026-06-01-project-roadmap-raw]]", "[[00_Inbox/2026-06-01-project-roadmap-detail-raw]]"]
---

# SU Cloud 프로젝트 로드맵 (2026년 6월 ~ 12월)

## 한 줄 정의

멘토 2명 + 멘티 4명이 학교 서버(405호)에 OpenStack 기반 SU Cloud를 구축하고, 최종적으로 Self-service Portal을 통해 VM을 발급하는 클라우드 서비스까지 운영하는 6개월 로드맵.

## 상세 설명

### Phase 0 · 6월 — 학습 & 기반 세팅

> 목표: Proxmox 위 VM에서 OpenStack을 수동 설치해 Horizon에 로그인하는 것까지 완료 (학습 목적)

- [x] P520에 Proxmox VE 설치 — 공동계정으로 멘티 4명 접속 환경 구성
- [x] 외부 접근 세팅 — Tailscale 설치, 집·외부에서 Proxmox 콘솔 접근 확인
- [x] 멘티 4명 OpenStack 수동 설치 실습 (Kolla-Ansible)
- [x] 학교 네트워크 파악 — VLAN 가능 여부, Public IP 2개 할당 확정
- [x] 외부 진입 아키텍처 — Edge VM + nginx 구조 검토

---

### Phase 1 · 7월 — 개발계 구축 (Ubuntu native)

> 목표: 개발계 Horizon에서 VM 생성 → FIP 할당 → SSH 접속 전체 흐름 동작 확인

- [ ] Gaming5에 Ubuntu 설치 — Proxmox 제거 후 베어메탈 Ubuntu로 전환
- [ ] OpenStack 수동 설치 혹은 **Kolla-Ansible 멀티노드 배포** (globals.yml 기준)
- [ ] VLAN 구성 확정 (VLAN 110/120 개발계, VLAN 10/20 운영계)
- [ ] Edge-GW 구성 — P520에 nginx 2 listen, 개발계/운영계 분기
- [ ] 팀 원격 접근 환경 통일 (Tailscale, 멘티 4명 전원 접근 확인)

---

### Phase 2 · 8–9월 — 운영계 구축 & 흐름 검증

> 목표: 멘티가 운영계 OpenStack에서 VM을 발급받아 3-tier 앱을 배포, 외부에서 접근 가능한 상태까지

- [ ] P520 베어메탈 Kolla-Ansible 배포 (Cinder / Horizon 포함, 전체 서비스 기동)
- [ ] E2E 사용자 흐름 검증 (VM 생성 → FIP 할당 → Security Group → SSH 접속 → 앱 배포)
- [ ] VM 위 3-tier 앱 배포 (Ubuntu cloud image + Docker Compose, Nginx/Flask/MySQL)
- [ ] 모니터링 기초 세팅

---

### Phase 3 · 10월 — Self-service Portal MVP

> 목표: 사용자가 VM 신청 → 승인 → 자동 생성까지 이어지는 흐름 최소 수준 동작

- [ ] Horizon 갭 분석 (신청·승인·알림 흐름 중 Horizon이 커버 못 하는 부분 정의)
- [ ] 사용자 시나리오 정의 (교수님·연구실·학생 각각의 신청 흐름 문서화)
- [ ] OpenStack SDK 연동 PoC (VM 생성 자동화 API, 승인 플로우 프로토타입)
- [ ] 얇은 Portal 보완 (필요한 흐름만 최소 구현)

---

### Phase 4 · 11–12월 — 소수 서비스 오픈

> 목표: 실제 사용자가 SU Cloud를 통해 VM을 발급받고 최소 2주 이상 안정적으로 운용

- [ ] 베타 사용자 온보딩 (교수님 1–2명, 연구실 1–2곳)
- [ ] 운영 체계 수립 (장애 대응 Runbook, 이슈 트래킹, 자원 관리 프로세스)
- [ ] 트래픽 수집 & 모니터링
- [ ] 프로젝트 회고 & 2027 로드맵 문서화

## SU Cloud에서의 활용

이 로드맵은 팀 방향성의 기준 문서. 주간 회의에서 현황을 대조하고 Phase별 완료 여부를 추적.

## 관련 개념

- [[01_Concepts/SU-Cloud-Project-Overview]]
- [[01_Concepts/Kolla-Ansible]]
- [[01_Concepts/HA-Concepts]]
- [[04_Meetings/2026-06-13-kickoff]]
