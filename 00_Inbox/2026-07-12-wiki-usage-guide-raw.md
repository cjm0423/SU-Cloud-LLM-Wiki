---
title: "SU-Cloud-LLM-Wiki 사용가이드"
type: "raw"
date: 2026-07-12
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# SU-Cloud-LLM-Wiki 사용가이드

이 문서는 "구조 설명"이 아니라 **실제로 매일 어떻게 쓰는지**에 대한
가이드입니다. 처음 한 번만 하는 세팅과, 회의/트러블슈팅이 있을 때마다
반복하는 루틴 두 부분으로 나뉩니다.

---

## Part 1. 처음 한 번만 — 팀원별 세팅

### 1) 저장소 받기

```bash
git clone https://github.com/cjm0423/SU-Cloud-LLM-Wiki.git
```

### 2) Obsidian 설치 및 Vault 열기

1. [obsidian.md](https://obsidian.md/)에서 설치
2. 실행 → `Open folder as vault` → 방금 clone한 `SU-Cloud-LLM-Wiki` 폴더 선택

### 3) 플러그인 설치 (Settings → Community plugins → Browse)

| 플러그인 | 용도 |
| --- | --- |
| **Dataview** | 각 INDEX.md의 동적 테이블(회의 목록, 미승격 원본 목록 등)을 표시 |
| **Templater** | 새 문서 만들 때 `99_Templates`의 템플릿을 자동으로 삽입 |
| **Git** | Obsidian 안에서 commit/push 버튼으로 바로 처리 |

설치 후 각각 활성화(Enable)까지 해야 작동합니다.

### 4) Templater 폴더 연결 (선택이지만 강력 추천)

Settings → Templater → Template folder location → `99_Templates` 지정.
이후 새 노트에서 `Ctrl+Alt+T` (또는 단축키 설정) → 어떤 템플릿 쓸지 고르면
frontmatter까지 자동으로 채워집니다.

> 플러그인 설치가 번거롭다면 최소한으로는 **Git만 있어도 사용 가능**합니다.
Dataview/Templater 없이도 그냥 폴더에 마크다운 파일을 만들고 커밋하면
시스템 자체는 작동합니다 — 다만 자동 목록, 자동 템플릿 삽입이 빠질 뿐입니다.
> 

---

## Part 2. 실전 루틴 — 회의/트러블슈팅이 생길 때마다

### Step 0. 원본 저장 (끝나자마자 바로)

회의나 AI와의 트러블슈팅 대화가 끝나면, **다듬지 말고** 원본을
`00_Inbox`에 저장합니다.

1. `00_Inbox`에서 새 노트 생성, 템플릿은 `OKF-Raw-Template`
2. 파일명: `YYYY-MM-DD-keyword-raw.md` (예: `2026-07-16-vxlan-mtu-error-raw.md`)
3. STT 전사, 채팅 로그, 회의 노트를 그대로 붙여넣기 — 오탈자·잡담 신경 안 씀
4. `status: raw`로 둔 채 저장

**이 단계가 가장 중요합니다.** 나머지 단계는 나중에 몰아서 해도 되지만,
이 단계를 놓치면 원본 자체가 영영 사라집니다.

### Step 1. AI에게 추출 요청

AI(Claude 등)와 대화창을 열고, 대화 시작 전에 README에 있는
**"LLM Wiki 에이전트 시스템 프롬프트"**를 붙여둡니다. (한 번 붙여두면
그 대화 안에서는 계속 유효)

문제가 해결되면:

```
이 내용을 위키로 추출해 줘
```

라고만 입력하면 AI가 OKF 포맷(YAML frontmatter + 구조화된 마크다운)으로
정리해서 코드 블록으로 출력해줍니다.

### Step 2. 알맞은 폴더에 저장

AI 출력 결과를 어디에 넣을지는 아래 기준으로 판단합니다.

| 이 대화의 성격이... | 저장 위치 |
| --- | --- |
| 특정 에러/문제 하나를 해결한 것 | `02_QnA_Archive` |
| 회의 내용 요약 | `04_Meetings` |
| 앞으로도 계속 유효할 개념 설명 | `01_Concepts` |
| 처음부터 끝까지 따라할 수 있는 설치/절차 | `03_Guides` |

Obsidian에서 해당 폴더에 새 노트 생성 → AI가 준 마크다운 내용 붙여넣기
→ 파일명은 AI가 제안한 `YYYY-MM-DD-keyword-english.md` 형식 그대로 사용.

### Step 3. 원본과 연결하기

새로 만든 문서의 frontmatter에 원본 링크를 채웁니다.

```yaml
raw_source: "[[00_Inbox/2026-07-16-vxlan-mtu-error-raw]]"
```

그리고 `00_Inbox`에 있던 원본 파일로 돌아가서 `status: raw` →
`status: promoted`로 바꿔줍니다. (이제 이 원본은 "처리 완료" 표시가 됨)

### Step 4. GitHub에 반영

Obsidian 왼쪽 사이드바 Git 아이콘 클릭 → Commit → Push.
또는 터미널에서:

```bash
git add .
git commit -m "docs: VXLAN MTU 오류 QnA 추가"
git push
```

### Step 5. (선택) INDEX.md 수동 목록 갱신

Dataview를 쓰고 있다면 각 폴더의 INDEX.md 표가 자동으로 갱신되므로 이
단계는 건너뛰어도 됩니다. Dataview 없이 쓰는 팀원이 있다면 수동 표에도
한 줄 추가해주면 좋습니다.

---

## Part 3. 한 사이클 예시

```
1. 화요일 회의 종료
   → 00_Inbox/2026-07-14-network-review-raw.md 에 회의 노트 그대로 저장

2. 목요일, 시간 날 때
   → Claude에게 시스템 프롬프트 + 위 원본 붙여넣고 "위키로 추출해 줘"
   → AI가 04_Meetings용 마크다운 출력

3. 04_Meetings/2026-07-14-network-review.md 생성
   → raw_source: "[[00_Inbox/2026-07-14-network-review-raw]]" 추가

4. 00_Inbox/2026-07-14-network-review-raw.md 의 status를 promoted로 변경

5. git commit & push
```

---

## Part 4. 습관으로 만들기 — 자주 실패하는 지점과 대응

| 실패 지점 | 대응 |
| --- | --- |
| "위키로 추출해줘"를 매번 까먹음 | 회의록 Action Item 맨 마지막 줄에 항상 "Inbox 저장 담당자: OOO"를 고정 항목으로 넣기 |
| Inbox만 쌓이고 승격이 안 됨 | 주 1회, 담당자 한 명이 `00_Inbox/INDEX.md`의 "미승격 원본" Dataview 쿼리로 밀린 것 확인 |
| 신규 팀원이 플러그인 설치를 안 함 | 이 가이드의 Part 1을 온보딩 첫날 그대로 시켜보기 |
| 파일명 규칙이 흐트러짐 | 템플릿 첫 줄 주석에 파일명 제안이 나오도록 이미 시스템 프롬프트에 규칙이 있음 — AI가 준 제안 그대로 쓰기 |
| 어느 폴더에 넣을지 헷갈림 | Part 2 Step 2의 표 기준으로 판단: "문제 하나"면 QnA, "계속 유효한 개념"이면 Concept |

---

## 빠른 체크리스트

- [ ]  회의/트러블슈팅 종료 즉시 → `00_Inbox`에 원본 저장
- [ ]  시간 날 때 → AI에게 "위키로 추출해 줘"
- [ ]  알맞은 폴더에 저장 (QnA / Meeting / Concept / Guide)
- [ ]  `raw_source` 채우고 원본 `status`를 `promoted`로 변경
- [ ]  git commit & push