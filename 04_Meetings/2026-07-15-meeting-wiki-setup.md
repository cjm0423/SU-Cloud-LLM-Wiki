---
title: "260715 위키 시스템 설계 회의 — 하네스 엔지니어링·Frontmatter 스키마"
type: "meeting"
date: 2026-07-15
tags: ["#meeting", "#su-cloud", "#wiki"]
related_nodes: ["[[04_Meetings/2026-07-12-meeting-weekly]]", "[[01_Concepts/SU-Cloud-Project-Overview]]"]
participants: ["[[05_People/조충희 교수님]]", "[[05_People/차지만]]", "[[05_People/백지원]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-07-15-meeting-wiki-raw]]"
---

# 260715 위키 시스템 설계 회의 — 하네스 엔지니어링·Frontmatter 스키마

## 📋 Session Snapshot

- 날짜: 2026-07-15
- 참여자: [[05_People/조충희 교수님]], [[05_People/차지만]], [[05_People/백지원]]
- 이전 회의: [[04_Meetings/2026-07-12-meeting-weekly]]

## 📝 Summary

SU-Cloud LLM Wiki의 버전 1 설계 방향 확정. AI가 맥락 없이도 워크플로우를 따라 초안을 만들어주는 **하네스 엔지니어링** 방식 채택. Frontmatter `status` 필드를 큐(queue)로 활용해 검토→승인→발행 흐름 구성. Inbox = raw 원본 파일 계층으로 역할 확정.

## 💬 주요 논의 내용

### 전체 방향

- **버전 1부터 시작**, 이후 개선해 나가기
- 초반에는 Helm 등 이미 mkdocs로 만들어진 레퍼런스를 따라가는 것이 좋음
- 현재 구성 = 결과물이 나오는 것

### 하네스 엔지니어링
- 내가 다 설명하지 않아도 미리 설계된 대로 AI가 배움 → CLAUDE.md 방식
- 맥락을 다 부여하지 않아도 워크플로우를 타서 초안을 만들어주는 것이 목표
- "나는 수동으로 설명하지 않아도 AI가 알아서 처리"하는 구조

### Frontmatter 스키마 (논의 결과)

**2번 이슈 — `status` 필드 활용**
- 검토해야 하는 것들을 **큐(queue)에 올려두고**, 수정할 것만 확인 후 approve하면 반영되는 형식
- `raw` → `promoted` 플로우

**3-2번 이슈**
1. 제출 템플릿은 필요하면 추후 추가
2. 관련 문서에도 태깅 추가하면 좋음

**3-4번 이슈**
- Overview가 필요할까? → README로 하면 되지 않나 → **일단 살려서 가보기**

### 범위 확장
- Inbox가 raw file 계층
- 위키 → 일단 SU-Cloud에 맞춰서 진행, 이후 CloudLab이 두 번째 페이지, 추후 모든 wiki 서비스로 확장 계획

## ✅ Action Items

- [ ] [[05_People/백지원]] — 일요일 초안 완성
- [ ] 전원 — CLAUDE.md 기반 하네스 엔지니어링 구조 적용 확인

## 🔗 Related Notes

- People: [[05_People/조충희 교수님]], [[05_People/차지만]], [[05_People/백지원]]
- Topics: [[01_Concepts/SU-Cloud-Project-Overview]]
- Previous: [[04_Meetings/2026-07-12-meeting-weekly]]
