# SU-Cloud LLM Wiki

> **삼육대학교 SU Cloud 프로젝트의 살아있는 지식 저장소**
> Andrej Karpathy의 LLM Wiki 철학 + Google OKF(Open Knowledge Format) 기반

---

## 이 저장소의 목적

채팅창에서 AI와 나눈 대화, 회의에서 나온 결정, 트러블슈팅 과정 —
이 모든 것은 한 번 쓰고 사라지기엔 너무 아까운 지식입니다.

**핵심 원칙:** 질문도 자산이다.
좋은 답변은 채팅에 흩어지게 두지 말고, 위키에 새 페이지로 저장해 축적하라.

```
팀원이 AI와 문제 해결
    → "위키로 추출해 줘" 명령
        → OKF 마크다운으로 변환
            → GitHub commit
                → Obsidian 그래프 뷰에서 지식망 시각화
```

소스만 축적되는 것이 아니라 **질문과 분석 결과까지 누적**됩니다.
git으로 관리(AI가 진행)되는 마크다운 파일 묶음 → Obsidian으로 시각화.

---

## 폴더 구조

```
SU-Cloud-LLM-Wiki/
├── 00_Inbox/            # 원본 저장소 (STT 전사, 채팅 로그 등 가공 전 raw 데이터)
├── 01_Concepts/        # 정적 개념 문서 (OpenStack, Neutron, VXLAN, Floating IP 등)
├── 02_QnA_Archive/     # AI 질의응답 추출 문서 (가장 많이 쌓이는 곳)
├── 03_Guides/          # 확정된 튜토리얼 / 설치 가이드
├── 04_Meetings/        # 회의 아카이브 (inbox에서 승격된 요약본)
├── 05_People/          # 참여자 허브 노드
├── 06_Decisions/       # 기술 결정 기록 (왜 이 방향으로 결정했는가)
├── 99_Templates/       # Obsidian 템플릿 (Concept / QnA / Meeting / Guide / Person / Raw / Decision)
└── README.md           # 이 파일
```

---

## LLM Wiki 파이프라인

### 0단계 — 원본 보존 (Inbox)
회의/대화가 끝나면 **가공 없이** STT 전사나 채팅 로그를 그대로 `00_Inbox`에 저장합니다.
정리는 나중에, 지금은 저장만. 자세한 규칙은 [[00_Inbox/INDEX]] 참고.

### 1단계 — 질의응답 (Chat)
팀원이 해결책을 찾기 위해 AI(Claude, ChatGPT, Gemini 등)와 대화합니다.

### 2단계 — AI의 지식화 (Format)
문제가 해결되면 `"이 내용을 위키로 추출해 줘"` 라고 명령합니다.
AI는 이를 Google OKF 표준(YAML 메타데이터 + 구조화된 마크다운)에 맞춰 변환하고,
원본이 `00_Inbox`에 있다면 `raw_source` 필드로 역참조를 남깁니다.

### 3단계 — 저장 및 연동 (GitHub)
변환된 마크다운 파일을 이 저장소에 commit합니다. 이때 원본 inbox 파일은 지우지 않고
frontmatter의 `status`를 `raw` → `promoted`로만 바꿔둡니다.
향후 이 과정도 AI 에이전트가 자동화할 수 있습니다.

### 4단계 — 시각화 및 연결 (Obsidian)
팀원들이 각자 로컬 PC에서 이 저장소를 Obsidian Vault로 엽니다.
`Ctrl+G` → 그래프 뷰 → 어떤 질문이 어떤 개념과 연결되는지 한눈에 파악.

---

## Claude Code 하네스 (권장)

이 저장소는 [Claude Code](https://claude.com/product/claude-code)로 열면
`CLAUDE.md`를 자동으로 읽고, 아래 3가지 요청을 알아서 처리합니다. 별도
프롬프트를 붙여넣을 필요 없이 자연어로 요청하면 됩니다:

| 이렇게 말하면 | 무슨 일이 일어나나 |
|---|---|
| "inbox 처리해줘" / "위키로 추출해줘" | `00_Inbox`의 raw 원본을 찾아 정식 위키 문서로 추출·분류·연결하고, 원본 status를 `promoted`로 갱신, 커밋까지 |
| "status 검토해줘" / "draft 승인해줘" | draft/review 상태 문서의 **전체 본문**을 보여주고 stable 승격 여부를 확인받음 |
| "위키 점검해줘" / "정합성 체크해줘" | 깨진 wikilink, INDEX.md 불일치, status 값 오류, 누락된 메타데이터를 스캔해서 보고 |

상세 절차는 각각 `.claude/skills/promote-inbox/`, `.claude/skills/review-status/`,
`.claude/skills/wiki-lint/`의 `SKILL.md`에 있습니다. commit은 자동으로
하되 **push는 항상 사람이 확인하고 명시적으로 요청했을 때만** 합니다.

---

## (Claude Code 없이) 범용 AI 챗 시스템 프롬프트

Claude Code 대신 ChatGPT/Gemini 같은 일반 챗 UI를 쓴다면, 대화 시작 전 이
프롬프트를 붙여두면 대화가 끝난 뒤 OKF 위키 문서로 변환해 줍니다. (단,
`CLAUDE.md`의 세부 규칙이나 위 스킬들의 자동화는 적용되지 않으니 결과물을
직접 검토해서 커밋해야 합니다.)

```
[Role]
당신은 SU-Cloud 프로젝트의 'LLM Wiki 지식 엔지니어(Knowledge Engineer)'입니다.
당신의 목표는 채팅창에 흩어지는 유용한 질문, 분석 결과, 트러블슈팅 과정을
구글의 Open Knowledge Format(OKF) 철학을 따른 마크다운 파일로 영구 축적하는 것입니다.

[Task]
내가 "이 내용을 위키로 추출해 줘" 또는 "문서화해 줘"라고 요청하면,
앞선 대화의 핵심 맥락(문제 상황, 원인 분석, 해결책)을 추출하여
아래의 OKF Markdown 템플릿 형식에 맞춰 마크다운 코드 블록으로만 출력하세요.

[Rule]
1. YAML Frontmatter를 반드시 포함합니다.
2. 연관 개념은 반드시 [[문서명]] 형태의 양방향 링크(Wikilink)로 표기합니다.
3. 파일명은 YYYY-MM-DD-keyword-english.md 형태로 첫 줄에 주석으로 제안하세요.
```

템플릿은 [[99_Templates/OKF-QnA-Template]] 참고.

---

## Obsidian 세팅 및 운영 가이드

### 초기 세팅
1. 이 저장소를 로컬에 Clone: `git clone <repo-url>`
2. Obsidian 실행 → `Open folder as vault` → 클론한 폴더 선택
3. `Ctrl+G`로 그래프 뷰 열기

> ⚠️ `[[문서명]]` 형태의 위키링크는 **Obsidian에서만** 클릭 가능한 링크로
> 렌더링됩니다. GitHub 웹페이지에서 그냥 열어보면 대괄호가 텍스트 그대로
> 보입니다. 문서 내용을 확인하는 용도로는 문제없지만, 링크를 타고 이동하려면
> Obsidian으로 열어야 합니다.

### 추천 플러그인
- **Dataview** — YAML 메타데이터 기반 동적 쿼리 테이블 생성
- **Templater** — 새 문서 작성 시 OKF 템플릿 자동 삽입
- **Git** — 저장소 commit/push를 Obsidian 안에서 바로 처리

### Dataview 활용 예시

Dataview는 YAML frontmatter를 SQL처럼 쿼리하는 Obsidian 플러그인이다.
마크다운 코드블록 언어를 `dataview`로 지정하면 자동으로 동적 테이블로 렌더링된다.

**기본 문법:**
- `FROM "폴더명"` — 특정 폴더의 파일들
- `WHERE 조건` — frontmatter 필드 필터링
- `TABLE 필드들` — 표시할 컬럼 지정
- `SORT 필드 ASC/DESC` — 정렬

**예시 1: 검토 필요한 문서 목록**
~~~
```dataview
TABLE date, title, file.link AS "문서"
FROM "01_Concepts" OR "03_Guides" OR "06_Decisions"
WHERE status = "review"
SORT date ASC
```
~~~

**예시 2: 미해결 QnA 목록**
~~~
```dataview
TABLE date, title
FROM "02_QnA_Archive"
WHERE status = "open"
SORT date DESC
```
~~~

**예시 3: 이번 달 회의 목록**
~~~
```dataview
TABLE date, participants
FROM "04_Meetings"
WHERE type = "meeting" AND date >= date(2026-07-01)
SORT date ASC
```
~~~

**예시 4: 특정 사람이 관련된 모든 문서**
~~~
```dataview
TABLE file.folder, date
FROM ""
WHERE contains(related_nodes, "[[05_People/차지만]]")
SORT date DESC
```
~~~

---

## 현재 프로젝트 컨텍스트

| 항목 | 내용 |
|------|------|
| 프로젝트명 | SU Cloud (삼육대학교 교내 클라우드 플랫폼) |
| 목표 | OpenStack 기반 준프로덕션 셀프서비스 클라우드 구축 |
| 학생 PL | [[차지만]] |
| 멘토 | [[박준우]], [[안현]] |
| 팀원 | [[이민기]], [[백지원]], [[김재현]] |
| 핵심 스택 | OpenStack (Antelope), Proxmox, Tailscale, DevStack |

---

## 관련 문서

- [[00_Inbox/INDEX]] — 원본 저장 규칙
- [[01_Concepts/OpenStack-Overview]] — OpenStack 전체 구조 개요
- [[01_Concepts/Provider-vs-SelfService-Network]] — 네트워크 핵심 개념
- [[03_Guides/DevStack-Installation-Guide]] — DevStack 설치 가이드
- [[04_Meetings/INDEX]] — 전체 회의 목록
- [[05_People/INDEX]] — 참여자 목록
