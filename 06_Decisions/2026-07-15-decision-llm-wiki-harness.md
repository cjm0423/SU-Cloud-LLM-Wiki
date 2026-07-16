---
title: "지식 관리 방식 — LLM Wiki + 하네스 엔지니어링 채택"
type: "decision"
date: 2026-07-15
tags: ["#decision", "#wiki", "#knowledge-management"]
status: "stable"
related_nodes: ["[[04_Meetings/2026-07-15-meeting-wiki-setup]]", "[[04_Meetings/2026-07-12-meeting-weekly]]", "[[01_Concepts/LLM-Wiki-Concept]]"]
deciders: ["[[05_People/조충희 교수님]]", "[[05_People/차지만]]", "[[05_People/백지원]]"]
author: "AI Assistant"
---

# 지식 관리 방식 — LLM Wiki + 하네스 엔지니어링 채택

## 한 줄 요약

팀의 지식을 Notion이 아닌 **GitHub 마크다운 위키**로 관리하고, AI가 자동으로 추출·정리·커밋하는 **하네스 엔지니어링** 방식을 채택한다.

## 배경 및 문제 상황

260712 회의에서 교수님이 "흩어져있는 정보를 GitHub wiki 형태로 하나로 통합하면 좋을 것 같다"고 제안. 기존 Notion 정보는 검색이 어렵고 AI와 통합이 불편했다. 어떻게 지식을 관리할지 방향 결정 필요.

## 고려한 대안

| 대안 | 장점 | 단점 |
|------|------|------|
| **GitHub Markdown + AI 하네스** ✅ | git 버전 관리, AI 통합 용이, Obsidian 그래프뷰, 오프라인 사용 가능 | 설정 복잡, 팀원 git 학습 필요 |
| Notion 계속 사용 | 이미 익숙함, 풍부한 UI | AI 통합 어려움, 검색 제한, 오프라인 불편 |
| GitHub Wiki (기본) | 기본 제공 | 마크다운만, 그래프뷰 없음, Dataview 없음 |
| Confluence | 전문적 기업 위키 | 유료, 오버스펙 |

## 결정 및 근거

**GitHub Markdown + Obsidian + CLAUDE.md 하네스 엔지니어링 채택.**

260715 회의에서 확정된 방향:
1. **버전 1로 시작** → 나중에 개선 (Helm mkdocs 같은 레퍼런스 참고)
2. **하네스 엔지니어링**: CLAUDE.md에 미리 설계된 대로 AI가 자동으로 처리. 사람이 다 설명하지 않아도 됨
3. **Inbox = raw 원본 계층**: 원본과 가공본을 양방향 링크로 연결 → 나중에 검증 가능
4. **Frontmatter `status` 큐**: AI 초안 → 사람 검토 → 승인 흐름

## 트레이드오프

- **얻은 것:** AI 통합, git 버전 관리, Obsidian 그래프뷰, 검증 가능한 원본 보존
- **포기한 것:** Notion의 편한 UI, 팀원들의 기존 Notion 익숙함
- **위험 요소:** 팀원이 git commit/push 를 안 하면 지식이 sync 안 됨 → obsidian-git 플러그인으로 완화

## 재검토 조건

- 팀원 절반 이상이 git 워크플로우에 거부감을 가질 경우 → Obsidian Git 플러그인 강화 또는 다른 방식 검토
- 프로젝트 확장 시 CloudLab 등 다른 프로젝트에도 동일 구조 적용 여부 검토

## 관련 문서

- [[04_Meetings/2026-07-15-meeting-wiki-setup]]
- [[04_Meetings/2026-07-12-meeting-weekly]]
- [[01_Concepts/LLM-Wiki-Concept]]
- [[03_Guides/LLM-Wiki-Usage-Guide]]
