---
name: promote-inbox
description: 00_Inbox의 미승격(status: raw) 원본을 정식 위키 문서(01_Concepts/02_QnA_Archive/03_Guides/04_Meetings/06_Decisions)로 추출·분류·연결·커밋한다. "inbox 처리해줘", "위키로 추출해줘", "원본 승격해줘" 같은 요청에 사용.
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash(git *)
---

# /promote-inbox — 미승격 원본 → 정식 위키 문서 추출

`00_Inbox`에 사람이 저장만 해둔 원본(STT 전사, 채팅 로그, Notion 내보내기
등)을 찾아 정식 위키 문서로 추출·분류·연결·커밋한다.

## 0. 대상 찾기

`00_Inbox/*.md`를 Glob/Grep으로 훑어 frontmatter `status: "raw"`인 파일을
전부 나열한다. 여러 건이면 사람에게 전체 목록(파일명 + 제목)을 보여주고
"전부 처리" 할지 "일부만 지정" 할지 확인한다. 한 건씩 별도 커밋으로 처리하는
것이 기본값 — 사람이 "한 번에 묶어서 커밋해줘"라고 명시하지 않는 한 문서별로
커밋을 나눈다.

## 1. 목적지 폴더 판단

원본을 읽고 아래 기준으로 분류한다. 판단이 애매하면 **추측하지 말고**
AskUserQuestion으로 사람에게 물어본다.

| 원본 내용이... | 목적지 | 템플릿 |
|---|---|---|
| 특정 에러/문제 하나를 해결한 것 | `02_QnA_Archive` | `99_Templates/OKF-QnA-Template.md` |
| 회의 내용 | `04_Meetings` | `99_Templates/OKF-Meeting-Template.md` |
| 앞으로도 계속 유효할 개념 설명 | `01_Concepts` | `99_Templates/OKF-Concept-Template.md` |
| 처음부터 끝까지 따라할 수 있는 설치/절차 | `03_Guides` | (Concept 템플릿 구조를 절차형으로 변형) |
| "왜 이 기술을 선택했는가" 결정 기록 | `06_Decisions` | `99_Templates/OKF-Decision-Template.md` |

## 2. 관련 문서 찾기

문서를 쓰기 전에 목적지 폴더(및 인접 폴더)를 Glob/Grep으로 살펴서 관련
있는 기존 문서를 찾는다. 확신 없는 관계를 `related_nodes`에 지어내지 않는다
— 실제로 내용이 겹치거나 참조 관계가 있는 문서만 링크한다.

## 3. 정식 문서 작성

- 목적지 템플릿의 frontmatter 구조를 그대로 따른다. 폴더별 필수 필드:
  - **QnA** (`type: "qa"`): `status`는 `open`(미해결) / `resolved`(해결됨) /
    `wontfix`(해결 안 함) 중 원본 내용에 맞는 값. `raw_source` 필수.
  - **Meeting** (`type: "meeting"`): `participants`는 `05_People/`의 사람
    문서를 `[[wikilink]]`로. `raw_source` 필수.
  - **Concept** (`type: "concept"`) / **Decision** (`type: "decision"`):
    `status`는 기본 `draft`.
  - 공통: `related_nodes`는 실제 관련 문서만 `[[문서명]]` wikilink로.
    `raw_source: "[[00_Inbox/원본파일명]]"` 반드시 채운다 (Decision 템플릿엔
    `raw_source` 필드가 없으니 추가하지 않는다).
- 파일명: `YYYY-MM-DD-keyword-english.md`. 날짜는 원본의 날짜(없으면 오늘
  날짜), 키워드는 영문 소문자+하이픈.
- 원본 내용을 요약·재구성해서 쓰되, 원본에 없는 사실을 지어내지 않는다.

## 4. 원본 상태 갱신

방금 처리한 `00_Inbox` 원본 파일의 frontmatter를 수정한다:
- `status: "raw"` → `status: "promoted"`
- `promoted_to: ""` → `promoted_to: "[[대상폴더/새문서명]]"`

**원본 본문 내용 자체는 절대 수정·삭제하지 않는다.** frontmatter만 바꾼다.

## 5. INDEX.md 갱신

목적지 폴더 `INDEX.md`의 "수동 목록" 표에 새 문서 한 줄을 추가한다.
Dataview 쿼리 블록은 건드리지 않는다 — 자동 갱신된다. 표 컬럼은 폴더마다
다르므로(예: `01_Concepts`는 파일/제목/태그, `02_QnA_Archive`는
날짜/제목/태그/상태) 기존 표의 컬럼 구성을 그대로 따라간다.

## 6. 커밋

한 세트(새 정식 문서 + 원본 status 변경 + INDEX.md 갱신)를 하나의 커밋으로
묶는다. 커밋 전에 어떤 파일이 새로 생기고 어떤 파일이 바뀌는지 요약해서
사람에게 보여준다.

커밋 메시지 형식: `docs: <새 문서 제목> 추가`

**push는 하지 않는다.** 사람이 확인 후 명시적으로 요청했을 때만 push한다.

## 하지 말 것

- `00_Inbox` 원본의 내용을 다듬거나 요약해서 원본 자체를 덮어쓰지 않는다
  (원본은 검증용이므로 그대로 보존 — frontmatter만 바꾼다).
- 이미 `status: promoted`인 원본은 다시 처리하지 않는다.
- 확신 없는 정보를 임의로 지어내서 `related_nodes`나 본문에 채우지 않는다
  — 애매하면 사람에게 물어본다.
- 여러 건을 한꺼번에 커밋으로 묶지 않는다 (사람이 명시적으로 요청한 경우 제외).
