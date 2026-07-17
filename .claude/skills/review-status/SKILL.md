---
name: review-status
description: draft/review 상태인 위키 문서(01_Concepts, 03_Guides, 04_Meetings, 06_Decisions)를 사람이 검토하도록 원문 전체를 보여주고 draft/review/stable 여부를 확인받는다. "status 검토해줘", "review 문서들 확인해줘", "draft 승인해줘" 같은 요청에 사용.
user-invocable: true
allowed-tools:
  - Read
  - Edit
  - Glob
  - Grep
  - Bash(git *)
---

# /review-status — 위키 문서 status 검토

`01_Concepts`, `03_Guides`, `04_Meetings`, `06_Decisions`의 `draft` /
`review` 상태 문서를 사람이 검토해서 `stable`로 올릴지 판단하게 돕는다.

**`02_QnA_Archive`는 대상이 아니다** — QnA는 `open`/`resolved`/`wontfix`
라이프사이클을 쓰며 이 스킬의 범위가 아니다.

## 1. 대상 찾기

`01_Concepts`, `03_Guides`, `04_Meetings`, `06_Decisions` 아래 `*.md`를
Glob/Grep으로 훑어 frontmatter `status: "draft"` 또는 `status: "review"`인
문서를 전부 나열한다. 파일명 + 제목 + 현재 status로 목록을 사람에게 먼저
보여준다.

## 2. 원문 전체를 보여주고 검토받기 — 절대 요약하지 않는다

**이것이 이 스킬의 핵심 규칙이다.** 문서를 요약해서 보여주고 승인받으면,
실제로 뭐가 쓰여있는지 확인 없이 도장 찍는 것과 같아서 검토 자체가
무의미해진다. 반드시 문서의 **본문 전체를 그대로** 출력한 다음
stable/review/draft 중 어느 상태로 둘지 물어본다.

- 한 번에 여러 문서를 몰아서 처리하지 않는다. 배치 크기를 줄이더라도
  (예: 한 번에 1~2개씩) 전체 내용을 보여주는 쪽을 우선한다.
- AskUserQuestion으로 "stable로 승격 / review 유지 / draft로 되돌림" 중
  선택받는다. 문서 수정이 필요하다는 피드백이 오면 그 자리에서 Edit으로
  반영한 뒤 다시 물어본다(다듬은 버전을 또 요약하지 말고 바뀐 부분을 보여준다).

## 3. status 반영

사람의 응답에 따라 각 문서 frontmatter의 `status` 필드를 Edit으로
변경한다:
- 승인 → `status: "stable"`
- 수정 필요 표시 → `status: "review"`
- 아직 이르다는 판단 → `status: "draft"` 유지

## 4. 커밋

변경된 문서들을 요약해서 보여준 뒤, 사람이 원하면 하나의 커밋으로 묶는다.
커밋 메시지 예: `docs: <N>개 문서 status 검토 반영 (stable 승격 등)` —
실제로 무엇이 바뀌었는지 반영해 구체적으로 쓴다.

**push는 하지 않는다.** 사람이 확인 후 명시적으로 요청했을 때만 push한다.

## 하지 말 것

- 문서 요약만 보여주고 승인 여부를 묻지 않는다 — 반드시 원문 전체.
- 여러 문서를 한 번에 몰아서 검토 요청하지 않는다.
- 사람이 review로 표시해둔 이유(무엇을 고쳐야 하는지)를 짐작으로 채우지
  않는다 — 코멘트가 없으면 무엇이 문제인지 먼저 물어본다.
