---
name: wiki-lint
description: 위키 전체를 스캔해서 깨진 wikilink, INDEX.md 수동 목록과 실제 파일 불일치, 잘못된 status 값, 누락된 raw_source, 허브 노드 없는 참여자 등 구조적 문제를 찾아 보고한다. "위키 점검해줘", "링크 깨진 거 있나 확인해줘", "정합성 체크해줘" 같은 요청에 사용.
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Bash(git *)
---

# /wiki-lint — 위키 구조 정합성 점검

이 저장소의 정합성은 에이전트가 매번 절차(`promote-inbox`, `review-status`)를
안 까먹고 지키는 데 의존한다. 이 스킬은 그 결과가 실제로 깨지지 않았는지
검증하는 점검용이다. **기본 동작은 보고만 한다 — 발견한 문제를 사람이
검토하고 고쳐달라고 명시했을 때만 Edit한다.**

## 점검 항목

### 1. 깨진 wikilink

전체 `*.md` (템플릿 폴더 `99_Templates` 제외)에서 `[[...]]` 패턴을 모두
추출한다. 각 링크에 대해:
- `[[00_Inbox/파일명]]`처럼 경로가 포함된 링크 → 해당 경로의 `.md` 파일이
  실제로 존재하는지 확인.
- `[[문서명]]`처럼 경로 없는 bare 링크 → 저장소 어딘가에 그 basename을 가진
  `.md` 파일이 있는지 확인 (Obsidian이 폴더 무관하게 basename으로 링크를
  푸는 방식과 동일).
- 파이프(`[[문서명|표시텍스트]]`)가 있으면 `|` 앞부분만 파일명으로 취급.

존재하지 않으면 🔴 **깨진 링크**로 보고 (어느 파일의 몇 번째 줄인지 포함).

**알려진 함정 (오탐 제거 필수):**
- 코드 펜스(```) 안의 bash `[[ -n "$VAR" ]]` 같은 조건문은 wikilink가
  아니다 — 코드 블록 내부는 건너뛴다.
- 백틱 인라인 코드(`` `[[wikilink]]` ``, `` `[[문서명]]` `` 등)로 문법을
  설명하는 예시 텍스트도 wikilink가 아니다 — 인라인 코드 스팬 안의 `[[...]]`도
  건너뛴다.
- DevStack `local.conf`처럼 `[[local|localrc]]` 같은 INI 섹션 헤더 문법이
  우연히 wikilink 파이프 문법과 겹치는 경우가 있다(`03_Guides/DevStack-Installation-Guide.md`
  실사례). 코드 블록 제외 규칙으로 자연히 걸러진다.

### 2. INDEX.md 수동 목록 ↔ 실제 파일 불일치

`01_Concepts`, `02_QnA_Archive`, `03_Guides`, `04_Meetings`, `06_Decisions`
각각에 대해:
- 폴더 안의 실제 `.md` 파일 목록(INDEX.md 자신은 제외)을 Glob으로 가져온다.
- 해당 폴더 `INDEX.md`의 "수동 목록" 표에 나온 wikilink들과 비교한다.
- 실제 파일은 있는데 표에 없으면 🔴 **INDEX 누락**.
- 표에는 있는데 실제 파일이 없으면 🔴 **INDEX 유령 항목** (파일이 삭제/이동됐는데
  표만 안 지워진 경우).

### 3. status 값 검증

`STATUS-OVERVIEW.md`에 정의된 허용값 기준으로 각 폴더 문서의 frontmatter
`status`를 확인한다:
- `00_Inbox`: `raw` | `promoted`
- `01_Concepts`, `03_Guides`, `04_Meetings`, `06_Decisions`: `draft` | `review` | `stable`
- `02_QnA_Archive`: `open` | `resolved` | `wontfix`

허용값 밖의 값(오타, 빈 값 등)이면 🔴 **잘못된 status**로 보고.

### 4. 필수 필드 누락

- `02_QnA_Archive`, `04_Meetings`, `03_Guides` 문서 중 `raw_source`가 빈
  문자열/빈 배열인 경우 → 🟡 **raw_source 누락** (검증 불가능한 문서라는 뜻).
- `04_Meetings`의 `participants`, `06_Decisions`의 `deciders`가 비어있는
  경우 → 🟡 **참여자 정보 누락**.

### 5. 허브 노드 없는 참여자

Meeting `participants` / Decision `deciders`에 등장하는 모든 사람에 대해
`05_People/<이름>.md`가 존재하는지 확인한다. 없으면 🟡 **허브 노드 없음**
(그래프뷰에서 끊긴 링크가 됨).

### 6. reviewed 필드 (참고용, 낮은 우선순위)

`status: "stable"`인 Concept/Meeting/Guide 문서 중 `reviewed_by` 또는
`reviewed_date`가 비어있는 경우 → ℹ️ **검토 이력 없음**으로 별도 섹션에
모아서만 보여준다 (이 필드는 나중에 추가됐으므로 기존 문서 대부분이
해당될 수 있다 — 급하게 고칠 문제는 아니라는 걸 사람에게 분명히 알린다).

## 보고 형식

```
## 🔴 구조적 문제 (N건)
- [파일:줄] 문제 설명

## 🟡 메타데이터 누락 (N건)
- [파일] 문제 설명

## ℹ️ 참고 (N건)
- [파일] 검토 이력 없음
```

건수가 0인 섹션은 생략한다. 전체가 0건이면 "구조적 문제 없음"으로 짧게 보고.

## 고칠 때

사람이 "고쳐줘"라고 명시하면:
- 🔴 항목은 기계적으로 고칠 수 있는 것들(INDEX 누락 줄 추가, 유령 항목 삭제,
  잘못된 status를 명백히 의도된 값으로 정정)부터 처리한다.
- 깨진 wikilink는 오타인지 실제로 문서가 아직 없는 것인지 애매하면 추측해서
  고치지 않고 사람에게 물어본다.
- 🟡/ℹ️ 항목은 내용을 지어내야 하는 경우가 많으므로(예: raw_source가 뭔지,
  참여자 역할이 뭔지) 기본적으로 자동 수정하지 않고 사람에게 값을 물어본다.
- 수정 후에는 어떤 파일이 바뀌었는지 요약해서 보여주고, 커밋은 사람이
  요청했을 때만 한다.
