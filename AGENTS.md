# SU-Cloud LLM Wiki — Agent Instructions

이 저장소는 SU Cloud 프로젝트의 지식 위키다. 사람은 `00_Inbox`에 원본을
저장하는 것까지만 담당한다. **원본을 정식 위키 문서로 추출·분류·연결·
커밋하는 전 과정은 이 파일을 읽는 에이전트(너)가 담당한다.**

## 저장소 구조

```
00_Inbox/            원본 (STT 전사, 채팅 로그, Notion 내보내기 등). 사람이 직접 저장.
01_Concepts/         정적 개념 문서. 프로젝트 상황과 무관하게 계속 유효한 지식.
02_QnA_Archive/      특정 문제 하나를 해결한 트러블슈팅/질의응답 기록.
03_Guides/           처음부터 끝까지 따라 하면 되는 검증된 절차.
04_Meetings/         회의 요약본.
05_People/           참여자 허브 노드 (거의 손댈 일 없음).
06_Decisions/        기술 결정 기록 (왜 이 방향으로 갔는가).
99_Templates/        OKF-Concept / OKF-QnA / OKF-Meeting / OKF-Raw / OKF-Decision 템플릿.
```

## status 필드 스키마

| 파일 위치 | status 값 | 의미 |
|---|---|---|
| `00_Inbox` | `raw` | 저장만 된 원본, 아직 위키로 추출 안 됨 |
| `00_Inbox` | `promoted` | 위키 문서로 추출 완료 |
| `01_Concepts`, `03_Guides`, `04_Meetings`, `06_Decisions` | `draft` | AI가 초안 생성, 사람 검토 전 |
| `01_Concepts`, `03_Guides`, `04_Meetings`, `06_Decisions` | `review` | 검토 필요 표시 (내용 수정 필요하면 이 값으로) |
| `01_Concepts`, `03_Guides`, `04_Meetings`, `06_Decisions` | `stable` | 사람이 검토 완료, 신뢰 가능 |
| `02_QnA_Archive` | `open` | 아직 해결 안 됨 |
| `02_QnA_Archive` | `resolved` | 문제 해결 완료 |
| `02_QnA_Archive` | `wontfix` | 해결하지 않기로 결정 |

**워크플로우:**
```
00_Inbox: raw → promoted
위키 문서: draft → review → stable
QnA: open → resolved
```

사람이 `status: "review"` 로 바꾸면 Dataview 쿼리가 "검토 필요 목록"에 자동으로 올라온다.
에이전트가 만든 문서는 기본값 `draft`로 두고, 사람이 확인 후 `stable`로 바꾼다.

## 표준 작업: 미승격 원본 처리

사람이 "inbox 처리해줘" 또는 "위키로 추출해줘"라고 하면 아래 절차를 그대로
수행한다.

### 1. 미승격 원본 찾기
`00_Inbox/*.md` 중 frontmatter `status: raw`인 파일을 전부 찾는다.

### 2. 내용 파악 후 목적지 폴더 결정
| 원본 내용이... | 목적지 |
|---|---|
| 특정 에러/문제 하나를 해결한 것 | `02_QnA_Archive` |
| 회의 내용 | `04_Meetings` |
| 앞으로도 계속 유효할 개념 설명 | `01_Concepts` |
| 처음부터 끝까지 따라할 수 있는 설치/절차 | `03_Guides` |
| "왜 이 기술을 선택했는가" 결정 기록 | `06_Decisions` |

판단이 애매하면 추측하지 말고 사람에게 물어본다.

### 3. 정식 문서 작성
- 목적지에 맞는 템플릿(`99_Templates/OKF-Concept-Template.md`,
  `OKF-QnA-Template.md`, `OKF-Meeting-Template.md`)의 형식을 그대로 따른다.
- YAML frontmatter 필수. `related_nodes`는 관련 있는 기존 문서를
  `[[문서명]]` wikilink로 채운다 (관련 문서를 찾기 위해 해당 폴더를
  먼저 살펴본다).
- `raw_source: "[[00_Inbox/원본파일명]]"`을 반드시 채운다.
- 파일명 형식: `YYYY-MM-DD-keyword-english.md`. 날짜는 원본의 날짜를
  쓰고(원본에 날짜가 없으면 오늘 날짜), 키워드는 영문 소문자+하이픈.

### 4. 원본 상태 갱신
방금 처리한 `00_Inbox` 원본 파일의 frontmatter `status`를 `raw`에서
`promoted`로 바꾼다. **원본 내용 자체는 절대 수정하거나 삭제하지 않는다.**

### 5. INDEX.md 갱신
목적지 폴더의 `INDEX.md`에 있는 "수동 목록" 표에 새 문서 한 줄을 추가한다.
(Dataview 쿼리 부분은 건드릴 필요 없음 — 자동으로 갱신됨)

### 6. 커밋
아래 두 가지를 하나의 커밋으로 묶는다:
- 새로 만든 정식 문서
- 원본 파일의 status 변경 + INDEX.md 갱신

커밋 메시지 형식: `docs: <새 문서 제목> 추가`

커밋하기 전에 어떤 파일이 새로 생기고 어떤 파일이 바뀌는지 요약해서
사람에게 보여준다. push는 사람이 확인 후 명시적으로 요청했을 때만 한다.

## 하지 말 것
- `00_Inbox` 원본의 내용을 다듬거나 요약해서 원본 자체를 덮어쓰지 않는다
  (원본은 검증용이므로 그대로 보존).
- 이미 `status: promoted`인 원본은 다시 처리하지 않는다.
- 확신 없는 정보를 임의로 지어내서 `related_nodes`나 본문에 채우지 않는다.
