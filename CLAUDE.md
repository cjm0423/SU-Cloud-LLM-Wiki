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
99_Templates/        OKF-Concept / OKF-QnA / OKF-Meeting / OKF-Guide / OKF-Person / OKF-Raw / OKF-Decision 템플릿.
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

`stable`로 승격되는 Concept/Meeting/Guide 문서는 `reviewed_by`
(검토자 — `[[05_People/이름]]` 형식) / `reviewed_date`(승격된 날짜)를
같이 채운다. 생성 시점(`draft`)에는 빈 값으로 둔다.

## 표준 작업 (Skill로 위임)

아래 작업들은 상세 절차를 `.claude/skills/`의 Skill 파일로 분리해뒀다.
관련 요청이 오면 해당 Skill을 읽고 그대로 따른다.

- **"inbox 처리해줘" / "위키로 추출해줘"** →
  [`.claude/skills/promote-inbox/SKILL.md`](.claude/skills/promote-inbox/SKILL.md)
  (00_Inbox의 raw 원본을 정식 위키 문서로 추출·분류·연결·커밋. 참여자
  허브 노드(05_People) 자동 생성 포함)
- **"status 검토해줘" / "draft 승인해줘"** →
  [`.claude/skills/review-status/SKILL.md`](.claude/skills/review-status/SKILL.md)
  (draft/review 문서 원문 전체를 보여주고 stable 승격 여부 확인)
- **"위키 점검해줘" / "정합성 체크해줘"** →
  [`.claude/skills/wiki-lint/SKILL.md`](.claude/skills/wiki-lint/SKILL.md)
  (깨진 wikilink, INDEX.md 불일치, status 오류, 누락된 메타데이터 점검)
- **"public에 반영해줘" / "public wiki 업데이트해줘"** →
  [`.claude/skills/publish-to-public/SKILL.md`](.claude/skills/publish-to-public/SKILL.md)
  (이 리포의 stable 문서를 sibling 리포 `SU-Cloud-Wiki-Public`의 공개
  핸드북(mkdocs)으로 정규화·민감정보 제거해서 반영)

## Public 핸드북과의 관계

`00_Inbox`~`99_Templates`는 이 프로젝트의 **private 운영 리포**다.
학생들이 학습·실습한 내용 중 공개 가능한 것은 별도 git 저장소
`../SU-Cloud-Wiki-Public`(mkdocs 기반 공개 핸드북)으로 옮겨 배포한다.
두 리포는 완전히 분리되어 있으며, private → public 반영은 항상
`publish-to-public` Skill을 통해서만 한다(민감정보 제거 절차를 건너뛰지
않기 위함).

## 공통 원칙

- `00_Inbox` 원본의 내용을 다듬거나 요약해서 원본 자체를 덮어쓰지 않는다
  (원본은 검증용이므로 그대로 보존 — frontmatter만 바꾼다).
- 이미 `status: promoted`인 원본은 다시 처리하지 않는다.
- 확신 없는 정보를 임의로 지어내서 `related_nodes`나 본문에 채우지 않는다
  — 애매하면 추측하지 말고 사람에게 물어본다.
- push는 사람이 확인 후 명시적으로 요청했을 때만 한다.