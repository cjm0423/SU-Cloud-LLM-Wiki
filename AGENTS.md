<!-- 이 파일은 CLAUDE.md와 내용이 같다. Claude Code는 CLAUDE.md를, 다른 AI 코딩
     도구(Cursor 등)는 관례상 AGENTS.md를 읽으므로 두 파일을 동일하게 유지한다.
     둘 중 하나만 수정했다면 다른 쪽도 같이 갱신할 것. -->

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
07_SU-Cloud/         이 프로젝트·환경 자체의 정보 (개요·로드맵·인프라 인벤토리·캠퍼스망 구조). 배우는 개념이 아니라 "SU-Cloud가 무엇인가"를 기록. 현실이 바뀌면 갱신 대상.
08_Reference/        조회 전용 문서. 명령어 치트시트·포트/설정 조회표 등 "읽는 게 아니라 값·문법만 찾는" 자료. 개념(01)에서 흩어진 조회 정보를 모은다.
99_Templates/        OKF-Concept / OKF-QnA / OKF-Meeting / OKF-Guide / OKF-Person / OKF-Raw / OKF-Decision / OKF-SU-Cloud / OKF-Reference 템플릿.
```

루트에는 폴더에 속하지 않는 **메타 문서**가 있다: `README.md`(홈),
`LEARNING-PATH.md`(학습 흐름 뷰 — 아래 섹션), `STATUS-OVERVIEW.md`(status 집계),
`TAXONOMY.md`(태그 통제 어휘). `docs/`·`site/`는 mkdocs 뷰어용 생성물이라
git 추적 밖이다(아래 "Private mkdocs 뷰어" 섹션).

## status 필드 스키마

| 파일 위치 | status 값 | 의미 |
|---|---|---|
| `00_Inbox` | `raw` | 저장만 된 원본, 아직 위키로 추출 안 됨 |
| `00_Inbox` | `promoted` | 위키 문서로 추출 완료 |
| `01_Concepts`, `03_Guides`, `04_Meetings`, `06_Decisions`, `07_SU-Cloud`, `08_Reference` | `draft` | AI가 초안 생성, 사람 검토 전 |
| `01_Concepts`, `03_Guides`, `04_Meetings`, `06_Decisions`, `07_SU-Cloud`, `08_Reference` | `review` | 검토 필요 표시 (내용 수정 필요하면 이 값으로) |
| `01_Concepts`, `03_Guides`, `04_Meetings`, `06_Decisions`, `07_SU-Cloud`, `08_Reference` | `stable` | 사람이 검토 완료, 신뢰 가능 |
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

`stable`로 승격되는 Concept/Meeting/Guide/Reference 문서는 `reviewed_by`
(검토자 — `[[05_People/이름]]` 형식) / `reviewed_date`(승격된 날짜)를
같이 채운다. 생성 시점(`draft`)에는 빈 값으로 둔다.

## 태그 (통제 어휘)

**태그는 [`TAXONOMY.md`](TAXONOMY.md)에 정의된 23개가 전부다.** 문서를
만들거나 고칠 때 `tags`를 채워야 하면 먼저 그 파일을 읽고, 거기 있는
어휘에서만 고른다. 새 태그를 만들지 않는다.

- 4개 축(기술 스택 / 주제 영역 / 환경 / 문서 성격)에서 조합해 문서당 2~5개.
- `type` 필드와 중복되는 태그(`#guide`, `#meeting`, `#concept`, `#decision`,
  `#qna`, `#people`) 금지 — 폴더와 `type`이 이미 그 일을 한다.
- 환경 축(`#campus-network`, `#devpc`, `#production`, `#prestudy`)이
  이 위키에서 변별력이 가장 높다. 판단 가능하면 하나는 붙인다.
- `00_Inbox` 원본과 `05_People`, 각 `INDEX.md`는 주제 태그를 붙이지 않는다.
- 어휘를 늘려야 한다고 판단되면 임의로 쓰지 말고 사람에게 제안한다.

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
- **"레퍼런스 만들어줘" / "치트시트로 정리해줘"** →
  [`.claude/skills/build-reference/SKILL.md`](.claude/skills/build-reference/SKILL.md)
  (개념 문서 등에 흩어진 조회용 자료(명령어·설정값)를 08_Reference의 정식
  레퍼런스 문서로 모음. 소스 3곳 이상일 때만 — 개념마다 남발 금지)
- **"public에 반영해줘" / "public wiki 업데이트해줘"** →
  [`.claude/skills/publish-to-public/SKILL.md`](.claude/skills/publish-to-public/SKILL.md)
  (이 리포의 stable 문서를 sibling 리포 `SU-Cloud-Wiki-Public`의 공개
  핸드북(mkdocs)으로 정규화·민감정보 제거해서 반영)
- **"N명 통합해줘" / "여러 명 자료 합쳐줘"** →
  [`.claude/skills/merge-people/SKILL.md`](.claude/skills/merge-people/SKILL.md)
  (여러 참여자가 같은 주제를 각자 학습한 inbox 원본을 문서 유형별
  기준으로 통합/분리하고 raw_source에 모든 출처를 남김. 참여자 수 무관.
  원본 전문을 읽고 고유 디테일을 살려 융합 — 헤딩 요약 금지)

## Public 핸드북과의 관계

`00_Inbox`~`99_Templates`는 이 프로젝트의 **private 운영 리포**다.
학생들이 학습·실습한 내용 중 공개 가능한 것은 별도 git 저장소
`../SU-Cloud-Wiki-Public`(mkdocs 기반 공개 핸드북)으로 옮겨 배포한다.
두 리포는 완전히 분리되어 있으며, private → public 반영은 항상
`publish-to-public` Skill을 통해서만 한다(민감정보 제거 절차를 건너뛰지
않기 위함).

## Private mkdocs 뷰어와 학습 경로 (LEARNING-PATH.md)

이 private 리포는 로컬 mkdocs 뷰어로도 열람한다:
`powershell -File scripts\serve-private.ps1` → `127.0.0.1:8000`.
`docs/`는 루트 콘텐츠를 가리키는 **NTFS 정션**이라(`scripts/setup-mkdocs.ps1`가
생성) 원본을 그대로 실시간 반영한다. 최상위 폴더나 루트 메타 문서를 새로
추가했을 때만 `setup-mkdocs.ps1`를 다시 돌린다(`$dirs`/`$files`/`.pages` 갱신).
- ⚠️ **루트 메타 문서(`README`·`LEARNING-PATH`·`STATUS-OVERVIEW`·`TAXONOMY`)는
  하드링크**라, 파일을 통째로 덮어쓰면(예: Write 툴) 새 inode가 생겨 링크가
  끊기고 뷰어에 반영되지 않는다. 이 경우 `setup-mkdocs.ps1`를 다시 돌려
  하드링크를 재생성한다. (폴더 안 문서는 정션이라 이 문제가 없다.)
- 상단 탭 라벨과 순서는 각 폴더의 `.pages`(`title:`)와 `docs/.pages`가 정한다.
  탭 번호(`01 · 개념` …)는 폴더 내부번호가 아니라 **읽는 순서**다.

- **유형 폴더(01_~08_)는 "찾기용" 레퍼런스/저작 구조**다. 처음 보는 사람이
  **배운 흐름대로 읽기엔** 개념·QnA·가이드가 유형별로 흩어져 있어 불편하다.
- **`LEARNING-PATH.md`(루트)가 그 흐름을 엮는 비파괴 오버레이**다. 파일을
  옮기지 않고, 실제 학습·구축 순서(5월 사전학습 → 로드맵 Phase 0~4)대로 기존
  문서를 **별칭 위키링크**(`[[01_Concepts/X|표시텍스트]]`)로 연결한다. 각 항목은
  "무엇을 · 왜" 한 줄을 단다. 단계 골격은
  [[07_SU-Cloud/SU-Cloud-Project-Roadmap]]의 Phase 언어를 따른다.
- **유지보수 규칙:** 위키 문서를 새로 만들거나 승격하면(`promote-inbox`·
  `merge-people` 등) **`LEARNING-PATH.md`의 알맞은 단계에 한 줄 끼워 넣는다.**
  로드맵 Phase가 진행되면 단계를 이어서 추가한다. 이 오버레이는 원본 문서를
  건드리지 않는다.
- **Dataview 블록은 mkdocs에서 실행되지 않는다**(Dataview는 Obsidian 전용).
  각 INDEX 페이지엔 쿼리 텍스트가 코드블록으로 노출되지만, 바로 아래 "수동
  목록" 표가 실제 내용을 담당하므로 그대로 둔다 — 억지로 훅·CSS로 숨기지
  않는다(불필요한 복잡도).

## 결정의 기록 (harness engineering)

작업 방식·구조·컨벤션을 새로 정하면 **그 세션에서 끝내지 말고 반드시
지속되는 곳(이 `CLAUDE.md` 또는 해당 `.claude/skills/`)에 적어** 다음 세션의
에이전트가 같은 규칙을 따르게 한다. 결정을 대화에만 남기지 않는다.

## 공통 원칙

- `00_Inbox` 원본의 내용을 다듬거나 요약해서 원본 자체를 덮어쓰지 않는다
  (원본은 검증용이므로 그대로 보존 — frontmatter만 바꾼다).
- 이미 `status: promoted`인 원본은 다시 처리하지 않는다.
- 확신 없는 정보를 임의로 지어내서 `related_nodes`나 본문에 채우지 않는다
  — 애매하면 추측하지 말고 사람에게 물어본다.
- push는 사람이 확인 후 명시적으로 요청했을 때만 한다.
