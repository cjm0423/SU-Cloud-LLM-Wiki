---
title: "SU Cloud LLM Wiki — 지식 관리 시스템 개념"
type: "concept"
date: 2026-07-12
tags: ["#wiki", "#knowledge-management", "#obsidian", "#okf"]
status: "stable"
related_nodes: ["[[01_Concepts/SU-Cloud-Project-Overview]]"]
author: "AI Assistant"
raw_source: ["[[00_Inbox/2026-07-12-doc-automation-harness-raw]]", "[[00_Inbox/2026-06-14-doc-automation-raw]]", "[[00_Inbox/2026-07-12-doc-automation-existing-raw]]"]
---

# SU Cloud LLM Wiki — 지식 관리 시스템 개념

## 한 줄 정의

팀원이 AI와 나눈 문제 해결 대화, 회의 결정, 트러블슈팅 과정을 마크다운 위키로 영구 축적하는 시스템. Andrej Karpathy의 LLM Wiki 철학 + Google OKF(Open Knowledge Format) + Obsidian 그래프뷰 기반.

## 상세 설명

### 왜 만들었나

- 팀원이 AI와 나눈 문제 해결 대화, 회의 결정, 트러블슈팅 과정은 **한 번 쓰고 사라지기엔 아까운 지식**
- **핵심 원칙: 질문도 자산이다.** 좋은 답변은 채팅에 흩어지게 두지 말고 위키에 저장해 축적
- 결과물은 git으로 관리되는 마크다운 파일 묶음, Obsidian으로 열면 그래프뷰에서 지식 간 연결 시각화

---

### 전체 파이프라인 (5단계)

```
0단계 — 원본 보존 (Inbox)
회의/대화가 끝나면 가공 없이 STT 전사나 채팅 로그를 그대로 저장
    ↓
1단계 — 질의응답 (Chat)
팀원이 AI(Claude, ChatGPT, Gemini 등)와 대화하며 문제 해결
    ↓
2단계 — AI의 지식화 (Format)
"이 내용을 위키로 추출해 줘" 명령 → AI가 OKF 표준으로 변환
원본이 있으면 raw_source 필드로 역참조 남김
    ↓
3단계 — 저장 및 연동 (GitHub)
변환된 마크다운을 저장소에 commit
원본 inbox 파일은 삭제하지 않고 status: raw → promoted로만 변경
    ↓
4단계 — 시각화 및 연결 (Obsidian)
팀원 각자 로컬에서 Vault로 열고 그래프뷰(Ctrl+G)로 지식망 확인
```

**핵심 설계 포인트**: 요약본만 남기지 않고, **원본(0단계)과 가공본(2단계)을 양방향 링크로 연결**해서 나중에 검증 가능하게 만든 것이 이 시스템의 핵심.

---

### 폴더 구조 및 역할

| 폴더 | 역할 |
|------|------|
| `00_Inbox` | 원본 저장소 — STT 전사, 채팅 로그 등 가공 전 raw 데이터 |
| `01_Concepts` | 정적 개념 문서 (프로젝트 진행과 무관하게 계속 유효한 지식) |
| `02_QnA_Archive` | AI 질의응답 추출 문서 — 특정 문제 하나를 푼 기록 |
| `03_Guides` | 확정된 재현 가능한 절차 (처음부터 끝까지 따라할 수 있는 것) |
| `04_Meetings` | 회의 아카이브 (inbox에서 승격된 요약본) |
| `05_People` | 참여자 허브 노드 (그래프뷰 연결 전용, Dataview로 동적 목록) |
| `99_Templates` | 새 문서 작성 시 쓰는 Obsidian 템플릿 |

```
00_Inbox (원본)
    → 02_QnA_Archive / 04_Meetings (가공된 개별 기록)
        → 01_Concepts / 03_Guides (검증되어 안정화된 지식)
            → 05_People (연결 허브)
```

---

### 00_Inbox — 원본 보존 계층 (핵심 철학)

**왜 도입했나**: 기존 구조는 AI가 요약·가공한 결과물만 쌓였음. 요약 과정에서 뉘앙스가 빠지거나 잘못 정리돼도 검증할 원본이 없었음.

**규칙**: "일단 저장, 정리는 나중에." 오탈자, 잡담, 반복 다 그대로.
- 파일명: `YYYY-MM-DD-keyword-raw.md`
- 정식 문서로 승격돼도 원본 삭제 안 함 → `status: raw → promoted`로만 변경
- 정식 문서 쪽에 `raw_source: "[[00_Inbox/원본파일명]]"`로 역참조

---

### 문서 포맷 (OKF 템플릿)

| 템플릿 | 용도 | 주요 항목 |
|--------|------|-----------|
| OKF-Concept-Template | 개념 정리 | 한 줄 정의, 상세 설명, 활용, 관련 개념 |
| OKF-QnA-Template | 트러블슈팅/질의응답 | 상황→분석→해결책→후속 통찰 |
| OKF-Meeting-Template | 회의록 | 요약, 논의 내용, Action Items, 관련 노트 |
| OKF-Raw-Template | 원본 캡처 | 원본 내용 그대로 + 선택적 메모 |

공통 규칙: 연관 개념은 반드시 `[[문서명]]` 양방향 링크로 표기 → Obsidian 그래프뷰에서 시각화.

---

### 하네스 엔지니어링 (Harness Engineering)

- CLAUDE.md 파일에 에이전트 지시 사항을 미리 정의
- 팀원이 "inbox 처리해줘"라고만 해도 AI가 알아서 분류·추출·커밋
- 맥락을 다 부여하지 않아도 워크플로우를 타서 초안 자동 생성

---

### 운영 방식

1. GitHub 저장소를 Git으로 관리 (AI가 커밋 진행 가능)
2. 팀원 각자 로컬 PC에 clone → Obsidian Vault로 오픈
3. 권장 플러그인: **Dataview** (YAML 기반 동적 테이블), **Templater** (템플릿 자동 삽입), **Git** (Obsidian 안에서 commit/push)
4. 회의/트러블슈팅 종료 시 담당자가 원본을 Inbox에 저장 → AI에게 추출 요청 → GitHub commit

## SU Cloud에서의 활용

- 이 저장소 자체가 SU Cloud 프로젝트의 지식 관리 시스템
- CLAUDE.md가 에이전트 지시 파일 역할 (하네스 엔지니어링)
- Obsidian + Dataview + obsidian-git 플러그인 조합 사용

## 관련 개념

- [[01_Concepts/SU-Cloud-Project-Overview]]

## 참고 자료

- 사용 가이드: [[03_Guides/LLM-Wiki-Usage-Guide]]
