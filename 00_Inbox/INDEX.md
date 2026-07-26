---
title: "Inbox 인덱스"
type: "index"
tags: ["#index", "#inbox"]
---

# 00_Inbox

**원본을 가공 없이 던져놓는 곳.** 여기서는 절대 정리하려고 하지 마세요 —
"일단 저장, 정리는 나중에"가 이 폴더의 유일한 규칙입니다.

> 이 파일은 폴더를 유지하기 위한 **안내용 인덱스**입니다. clone/pull 하면
> 이 폴더가 생기니, 여기에 원본을 넣고 에이전트에게 "inbox 처리해줘"라고
> 요청하세요.

## 왜 필요한가

`01_Concepts`, `02_QnA_Archive`, `04_Meetings` 등에 쌓이는 문서는 전부
**AI가 추출·가공한 결과물**입니다. 가공 과정에서 뉘앙스가 빠지거나 잘못
요약될 수 있는데, 원본이 없으면 나중에 "그때 정확히 뭐라고 했지?"를 검증할
방법이 없습니다. Inbox는 그 원본을 보존하는 계층입니다.

```
회의/채팅 종료
    → 원본을 가공 없이 00_Inbox에 저장 (raw)
        → 시간 날 때 AI에게 "이 inbox 파일을 위키로 추출해줘"
            → 알맞은 유형 폴더로 승격 (promoted)
                → 승격된 문서에 raw_source로 원본 역참조
```

## 저장 규칙

- **파일명:** `YYYY-MM-DD-keyword-raw.md`
- **내용:** STT 전사, 채팅 로그 캡처, 회의 노트 등 원본 그대로.
  다듬지 않아도 됩니다. 오탈자, 반복, 잡담 다 괜찮습니다.
- **템플릿:** [[99_Templates/OKF-Raw-Template]] (매우 가벼운 포맷 — 형식
  갖추느라 시간 쓰지 말 것)

## 승격(Promote) 규칙

- 원본을 정식 위키 문서로 변환했으면, **원본을 지우지 마세요.** frontmatter의
  `status`를 `raw` → `promoted`로 바꾸기만 하면 됩니다.
- 승격된 정식 문서 쪽에는 아래처럼 원본 역참조를 남깁니다:
  ```yaml
  raw_source: "[[00_Inbox/2026-01-01-example-raw]]"
  ```
- 이렇게 하면 정식 문서 ↔ 원본 사이 양방향 추적이 가능합니다.

## 미승격 원본 확인 (Dataview)

아직 정식 위키로 추출되지 않은 원본만 골라 보여줍니다. 방치되고 있는 원본을
찾을 때 씁니다. *(Dataview는 Obsidian 전용 — mkdocs 뷰어에서는 실행되지 않습니다.)*

~~~
```dataview
TABLE date, tags
FROM "00_Inbox"
WHERE status = "raw"
SORT date ASC
```
~~~

## 전체 Inbox 목록

~~~
```dataview
TABLE date, status, tags
FROM "00_Inbox"
SORT date DESC
```
~~~

<!-- 원본을 추가하면 여기에 수동 목록 표를 채우거나(mkdocs 뷰어용),
     Obsidian에서는 위 Dataview 쿼리가 자동으로 목록을 만들어 줍니다. -->
