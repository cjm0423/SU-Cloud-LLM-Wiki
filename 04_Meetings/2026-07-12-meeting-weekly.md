---
title: "260712 주간 회의 — Public IP 부족·Self-service 포탈·위키 통합"
type: "meeting"
date: 2026-07-12
tags: ["#meeting", "#su-cloud"]
related_nodes: ["[[04_Meetings/2026-06-28-meeting-weekly]]", "[[04_Meetings/2026-07-15-meeting-wiki-setup]]", "[[01_Concepts/SU-Cloud-Project-Overview]]", "[[01_Concepts/Floating-IP]]"]
participants: ["[[05_People/차지만]]", "[[05_People/이민기]]", "[[05_People/박준우]]", "[[05_People/안현]]", "[[05_People/백지원]]", "[[05_People/김재현]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-07-12-meeting-weekly-raw]]"
---

# 260712 주간 회의 — Public IP 부족·Self-service 포탈·위키 통합

## 📋 Session Snapshot

- 날짜: 2026-07-12
- 참여자: [[05_People/차지만]], [[05_People/이민기]], [[05_People/박준우]], [[05_People/안현]], [[05_People/백지원]], [[05_People/김재현]] (조충희 교수님 불참)
- 이전 회의: [[04_Meetings/2026-06-28-meeting-weekly]]
- 다음 회의: [[04_Meetings/2026-07-15-meeting-wiki-setup]]

## 📝 Summary

현재 진행 상황 공유 및 Public IP/도메인 부족 문제 논의. 흩어진 정보를 GitHub Wiki로 통합하고 이번 주 안에 위키 체계를 갖추기로 결정. Self-service 포탈 설계(요구사항 정의, DB 설계) 방향 수립.

## 💬 주요 논의 내용

### 각 멤버 현황

**[[05_People/백지원]]**
- 네트워크 충분히 학습한 것으로 평가
- 72번 포트는 트렁크 아닌 것으로 추정
- 415호 Juniper EX3300 스위치의 VLAN 사용 여부 파악 필요

**[[05_People/차지만]]**
- bind 0.0.0.0 확인 → Tailscale 없이 외부에서 Horizon 접속 가능 여부 테스트
- Kolla exforward bind 0.0.0.0으로 변경하면 해결될 것으로 예상

**[[05_People/이민기]]**
- WSREP: 동기화 API 파악

**[[05_People/김재현]]**
- Public IP 최소 2개 추가 필요 (총 4개)
- 도메인 필요 (개발계, 운영계에 매핑되는 IP + 도메인)
- 179, 180 포트 80/443 외부 접근 불가 문제 확인 중

### 현재 문제점
- **네트워크 (IP·도메인) 부족**: Public IP 적은 상황에서 서비스 제공 방법 논의
- 포트포워딩·서브도메인 형식으로 제공 가능성 검토

### 앞으로의 진행 방향
1. **Self-service 포탈 설계** → 요구사항 정리 (목적 대상, 서비스 방식, DB 설계)
   - 사용자가 VM 요청 시 어떻게 접속하게 할 것인지
   - 제안서의 추상적 내용을 구체적으로 정의
2. **위키 체계 통합** → 이번 주 안에 완성, [[05_People/백지원]] 리드
3. **IP 추가·도메인 신청** → Public IP 용도 논의 후 결정

## ✅ Action Items

- [ ] 전원 — Self-service 포탈 요구사항 정리 (사용자 시나리오, DB 스키마)
- [ ] [[05_People/백지원]] — 흩어진 정보를 GitHub wiki 형태로 통합 (이번 주 완료)
- [ ] [[05_People/김재현]] — Public IP 2개 추가 신청·도메인 신청 조율
- [ ] [[05_People/차지만]] — Horizon 외부 접속 bind 0.0.0.0 적용 확인
- [ ] [[05_People/백지원]] — 415호 Juniper EX3300 VLAN 사용 여부 파악

## 🔗 Related Notes

- People: [[05_People/차지만]], [[05_People/이민기]], [[05_People/박준우]], [[05_People/안현]], [[05_People/백지원]], [[05_People/김재현]]
- Topics: [[01_Concepts/SU-Cloud-Project-Overview]], [[01_Concepts/Floating-IP]]
- Next Meeting: [[04_Meetings/2026-07-15-meeting-wiki-setup]]
