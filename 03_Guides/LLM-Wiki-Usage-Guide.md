---
title: "SU-Cloud-LLM-Wiki 사용가이드"
type: "guide"
date: 2026-07-12
tags: ["#guide", "#wiki", "#obsidian"]
related_nodes: ["[[01_Concepts/LLM-Wiki-Concept]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-07-12-wiki-usage-guide-raw]]"
---

# SU-Cloud-LLM-Wiki 사용가이드

## 개요

이 문서는 **실제로 매일 어떻게 쓰는지**에 대한 가이드. 처음 한 번만 하는 세팅과, 회의/트러블슈팅 때마다 반복하는 루틴으로 구성.

---

## Part 1. 처음 한 번만 — 팀원별 세팅

### 1) 저장소 받기

```bash
git clone https://github.com/cjm0423/SU-Cloud-LLM-Wiki-cjm.git
```

### 2) Obsidian 설치 및 Vault 열기

1. https://obsidian.md/ 에서 설치
2. 실행 → `Open folder as vault` → clone한 `SU-Cloud-LLM-Wiki` 폴더 선택

### 3) 플러그인 설치 (Settings → Community plugins → Browse)

| 플러그인 | 용도 |
|----------|------|
| **Dataview** | 각 INDEX.md의 동적 테이블(회의 목록, 미승격 원본 목록) 표시 |
| **Templater** | 새 문서 만들 때 `99_Templates` 템플릿 자동 삽입 |
| **Git** | Obsidian 안에서 commit/push 버튼으로 처리 |

> 최소: **Git만 있어도 사용 가능.** Dataview/Templater 없어도 마크다운 파일 직접 만들고 커밋하면 됨.

### 4) Templater 폴더 연결 (강력 추천)

Settings → Templater → Template folder location → `99_Templates` 지정
→ 이후 `Ctrl+Alt+T`로 템플릿 자동 삽입 가능

---

## Part 2. 실전 루틴 — 회의/트러블슈팅 때마다

### Step 0. 원본 저장 (끝나자마자 즉시) ⭐가장 중요

1. `00_Inbox`에서 새 노트 생성, 템플릿: `OKF-Raw-Template`
2. 파일명: `YYYY-MM-DD-keyword-raw.md` (예: `2026-07-16-vxlan-mtu-error-raw.md`)
3. STT 전사, 채팅 로그, 회의 노트 그대로 붙여넣기 — 오탈자·잡담 신경 안 씀
4. `status: raw`로 둔 채 저장

### Step 1. AI에게 추출 요청

Claude와 대화창을 열고:
```
이 내용을 위키로 추출해 줘
```
→ AI가 OKF 포맷(YAML frontmatter + 구조화된 마크다운)으로 출력

### Step 2. 알맞은 폴더에 저장

| 대화 성격 | 저장 위치 |
|-----------|-----------|
| 특정 에러/문제 하나를 해결 | `02_QnA_Archive` |
| 회의 내용 요약 | `04_Meetings` |
| 앞으로도 계속 유효한 개념 설명 | `01_Concepts` |
| 처음부터 끝까지 따라할 수 있는 절차 | `03_Guides` |

파일명: `YYYY-MM-DD-keyword-english.md`

### Step 3. 원본과 연결하기

새 문서 frontmatter에:
```yaml
raw_source: "[[00_Inbox/2026-07-16-vxlan-mtu-error-raw]]"
```

원본 파일(`00_Inbox/...`)로 돌아가서:
```yaml
status: "promoted"   # raw → promoted 변경
```

### Step 4. GitHub에 반영

```bash
git add .
git commit -m "docs: VXLAN MTU 오류 QnA 추가"
git push
```
또는 Obsidian Git 플러그인에서 Commit → Push 버튼 클릭.

### Step 5. (선택) INDEX.md 수동 목록 갱신

Dataview 쓰면 자동 갱신되므로 생략 가능.

---

## Part 3. 한 사이클 예시

```
1. 화요일 회의 종료
   → 00_Inbox/2026-07-14-network-review-raw.md 에 회의 노트 저장

2. 목요일 (시간 날 때)
   → Claude에게 "위키로 추출해 줘"
   → AI가 04_Meetings용 마크다운 출력

3. 04_Meetings/2026-07-14-network-review.md 생성
   → raw_source 링크 추가

4. 원본 status를 promoted로 변경

5. git commit & push
```

---

## Part 4. 자주 실패하는 지점

| 실패 지점 | 대응 |
|-----------|------|
| "위키로 추출해줘"를 매번 까먹음 | 회의록 Action Item 마지막에 "Inbox 저장 담당자: OOO" 고정 |
| Inbox만 쌓이고 승격 안 됨 | 주 1회 담당자가 `00_Inbox/INDEX.md` 미승격 Dataview 쿼리로 확인 |
| 어느 폴더에 넣을지 헷갈림 | Part 2 Step 2 표 기준 — "문제 하나"면 QnA, "계속 유효한 개념"이면 Concept |

## 관련 문서

- [[01_Concepts/LLM-Wiki-Concept]] — 시스템 철학 및 전체 파이프라인
