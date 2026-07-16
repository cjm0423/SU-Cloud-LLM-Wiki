---
title: "SU Cloud 프로젝트 개요"
type: "concept"
date: 2026-06-18
tags: ["#su-cloud", "#project", "#vision", "#architecture"]
status: "review"
related_nodes: ["[[OpenStack-Overview]]", "[[차지만]]", "[[박준우]]", "[[2026-06-13-kickoff]]", "[[04_Meetings/INDEX]]"]
author: "SU-Cloud Team"
---

# SU Cloud 프로젝트 개요

## 한 줄 정의

삼육대학교 학생들이 실제 학교 자원 위에서 OpenStack 기반 클라우드를 기획·구축·운영해보는 준프로덕션 플랫폼 프로젝트.

## 비전

> "단순 OpenStack 실습이나 졸업작품이 아니라, 학교 내부 사용자(학생, 연구실, 수업)에게 VM과 컴퓨팅 파워를 제공하는 준프로덕션 클라우드 플랫폼을 만든다."

AI로 코드 작성 비용이 낮아지는 시대에 더 중요한 역량인 **아키텍팅, 인프라 이해, Platform Engineering** 경험을 실전으로 쌓는 것이 핵심 목표다.

## 로드맵

```
Phase 1 — Infrastructure MVP (현재)
  └─ 학교 서버 2대 확보 (ThinkStation)
  └─ Proxmox 설치 (v8.4, 2026-06-15 완료)
  └─ OpenStack 수동 설치 (controller + compute)
  └─ VM 생성/접속 + packet flow 이해
  └─ Provider/Self-Service Network + Floating IP

Phase 2 — Self-Service Portal
  └─ OpenStack SDK/API 기반 VM 신청/승인 흐름
  └─ 사용자 포털 (Horizon 커스텀 또는 별도 개발)
  └─ 이메일 알림, 인증, 관리자 승인 워크플로우

Phase 3 — Production-like 운영
  └─ 실제 사용자 트래픽 수용 (수업, 연구실, AI 실험)
  └─ 모니터링, 장애 대응, 운영 문서화
  └─ Kolla Ansible 자동화 검토
```

## 팀 구성

| 역할 | 이름 |
|------|------|
| 멘토 (비전/아키텍처) | [[박준우]] |
| 멘토 (기술/인프라) | [[안현]] |
| 학생 PL | [[차지만]] |
| Core Team | [[이민기]], [[백지원]], [[김재현]] |
| 지도교수 | [[조충희 교수님]] |

## 기술 스택

| 레이어 | 기술 |
|--------|------|
| 하이퍼바이저 | Proxmox VE 8.4 |
| 클라우드 플랫폼 | OpenStack Antelope (2023.1) |
| 네트워킹 | Neutron + Linux Bridge + VXLAN |
| 원격 접속 | Tailscale |
| 개발 실습 | DevStack |
| 문서화 | LLM Wiki (이 저장소) |

## 제약 사항 (현실적 한계)

- 서버 1~2대 중심 구조 → HA/DR 목표로 잡기 어려움
- 초기 목표: backup, 개발계/운영계 분리, VM 생성/접속 검증
- 학생 프로젝트 일정 관리 리스크

## 관련 문서

- [[04_Meetings/INDEX]] — 전체 회의 아카이브
- [[01_Concepts/OpenStack-Overview]] — 핵심 기술
- [[03_Guides/DevStack-Installation-Guide]] — 실습 시작점
