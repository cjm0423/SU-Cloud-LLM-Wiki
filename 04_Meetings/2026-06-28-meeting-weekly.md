---
title: "260628 주간 회의 — Production 네트워크·HA·메시지 큐 피드백"
type: "meeting"
date: 2026-06-28
tags: ["#meeting", "#su-cloud"]
related_nodes: ["[[04_Meetings/2026-06-21-meeting-weekly]]", "[[04_Meetings/2026-07-12-meeting-weekly]]", "[[01_Concepts/VXLAN]]", "[[01_Concepts/Floating-IP]]", "[[01_Concepts/Provider-vs-SelfService-Network]]"]
participants: ["[[05_People/차지만]]", "[[05_People/이민기]]", "[[05_People/박준우]]", "[[05_People/안현]]", "[[05_People/백지원]]", "[[05_People/김재현]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-06-28-meeting-weekly-raw]]"
---

# 260628 주간 회의 — Production 네트워크·HA·메시지 큐 피드백

## 📋 Session Snapshot

- 날짜: 2026-06-28
- 참여자: [[05_People/차지만]], [[05_People/이민기]], [[05_People/박준우]], [[05_People/안현]], [[05_People/백지원]], [[05_People/김재현]] (조충희 교수님 불참)
- 이전 회의: [[04_Meetings/2026-06-21-meeting-weekly]]
- 다음 회의: [[04_Meetings/2026-07-12-meeting-weekly]]

## 📝 Summary

Kolla-Ansible 배포가 완료된 상태에서 Production 수준 요구사항 피드백이 집중됐다. 핵심은 **네트워크 대역 분리**, **HAProxy/Keepalived를 통한 VIP 구성**, **MariaDB Galera 쿼럼**, **RabbitMQ 메시지 큐** 이해도 향상. OVN 시각화 자료 제작과 Tailscale ACL 태그 기반 권한 분리도 과제로 부여됐다.

## 💬 주요 논의 내용

### 네트워크 설계 (Production 관점)
- **대역 분리 필수**: tunnel / mgmt / provider가 현재 같은 대역 → Production은 반드시 분리
- tunnel network는 별도 분리 필수
- **VXLAN 사용 조건**: compute 노드가 서로 다른 대역(다른 데이터센터)에 있을 때 L2 통합 목적으로 사용
- **Geneve**: VXLAN의 MTU 증가로 인한 패킷 드랍 문제를 가변 길이 옵션 필드로 보완

### OVN / OVS
- **OVN이 OVS를 제어**하는 구조 → OVN 통신 구조 시각화 자료 제작 필요

### 로드밸런싱 · VIP (HAProxy / Keepalived / VRRP)
- HAProxy가 controller 3대에 모두 설치되어 있는지 확인 필요
- keepalived(VRRP)를 통해 VIP가 어떻게 할당되는지 동작 원리 정리
- 현재 LB 노드 = **bootstrap node** (관리용 노드) 형태

### 고가용성(HA) · 쿼럼
- OpenStack HA에서 가장 중요한 영역은 **DB** → MariaDB Galera quorum 실험 권장
- 구성 방식: Galera / active-standby / active-active
- 동시 쓰기 발생 시 데이터 처리 방식이 핵심 포인트

### 메시지 큐 (RabbitMQ / Kafka)
- 실시간 요청을 **Kafka에 적재**하는 필요성 인식
- **RabbitMQ · Kafka 등 비동기 처리 개념** 학습 권장 (대용량 트래픽 운영 고려)

### OpenStack CLI
- CLI는 **REST API를 분석해 Python으로 구현한 래퍼**

### 접근 제어 (Tailscale ACL)
- Tailscale ACL은 **태그(tag) 기반 권한 부여** 가능
- 현재 동일 계정이면 개인 end device까지 서버 접근 가능 → 이메일·태그 기반 분리 검토

### 향후 과제
- Kubernetes 환경 위 구축 시 Registry 별도 구성 + Helm 도입 검토
- Notion 정리 내용을 GitHub에 통합

## ✅ Action Items

- [ ] **[[05_People/백지원]]** — VXLAN/VNI, br-int, br-tun, Linux bridge, tcpdump 확인 흐름을 draw.io로 확장·공유
- [x] **[[05_People/백지원]] · [[05_People/차지만]]** — OVN/Geneve packet flow와 gateway chassis 구조 시각화
- [ ] **[[05_People/이민기]]** — Tailscale ACL, tag, email 분리 방식 정리
- [ ] **[[05_People/이민기]]** — Galera quorum, VIP failover, OpenStack 운영 데이터 시나리오 추가 실험
- [x] **[[05_People/차지만]]** — Kolla Ansible 배포 트러블슈팅 로그 정리
- [x] **[[05_People/차지만]]** — 학교 네트워크 진단 명령어 스크립트 공유
- [ ] **[[05_People/박준우]] · [[05_People/안현]]** — 학교 네트워크 현장 확인 일정 조율
- [ ] **전원** — campus network architecture 초안 각자 작성
- [ ] **[[05_People/박준우]]** — Notion 개인 정리 자료 GitHub wiki로 통합 방향 공유

## 🔗 Related Notes

- People: [[05_People/차지만]], [[05_People/이민기]], [[05_People/박준우]], [[05_People/안현]], [[05_People/백지원]], [[05_People/김재현]]
- Topics: [[01_Concepts/VXLAN]], [[01_Concepts/Floating-IP]], [[01_Concepts/Provider-vs-SelfService-Network]]
- Next Meeting: [[04_Meetings/2026-07-12-meeting-weekly]]
