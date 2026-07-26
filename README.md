# LLM Wiki Harness

> **AI 에이전트가 운영하는 지식 위키 하네스**
> Andrej Karpathy의 LLM Wiki 철학 + Google OKF(Open Knowledge Format) 기반

이 저장소는 특정 프로젝트의 지식 콘텐츠가 아니라, 그 위키를 **AI 에이전트가
자동으로 운영**하게 만드는 **하네스(harness) 엔지니어링 결과물**만 담는다.
사람은 원본을 `00_Inbox`에 저장하는 것까지만 하고, 추출·분류·연결·커밋의
전 과정은 `CLAUDE.md`를 읽는 에이전트가 담당한다.

> 실제 학습·실습 콘텐츠(개념·QnA·가이드·회의록·참여자 등)는 이 저장소에
> 포함하지 않는다. 여기 있는 것은 **재사용 가능한 뼈대**뿐이다.

---

## 무엇이 들어있나

```
.claude/skills/      에이전트 표준 작업 절차(Skill) — 이 하네스의 핵심
CLAUDE.md            에이전트 지침 (Claude Code가 자동 로드)
AGENTS.md            CLAUDE.md와 동일한 사본 (Cursor 등 AGENTS.md 관례 도구용)
TAXONOMY.md          태그 통제 어휘
99_Templates/        OKF 문서 템플릿 9종 (Concept/QnA/Meeting/Guide/Person/Raw/Decision/SU-Cloud/Reference)
scripts/             mkdocs 로컬 뷰어 실행·셋업 스크립트
mkdocs.yml           mkdocs(Material) 뷰어 설정
requirements.txt     뷰어용 파이썬 의존성
```

콘텐츠 폴더(`01_Concepts` ~ `08_Reference`, `00_Inbox`, `05_People` 등)는
에이전트가 운영 시 생성하는 대상이며, 이 하네스 저장소에는 비어 있다.

---

## 핵심 철학

**질문도 자산이다.** 채팅으로 해결한 문제, 회의에서 나온 결정, 트러블슈팅
과정은 한 번 쓰고 사라지기엔 아깝다. 좋은 답변을 위키에 새 페이지로 축적한다.

```
사람이 AI와 문제 해결
    → "위키로 추출해 줘" 명령
        → OKF 마크다운으로 변환 (YAML 메타데이터 + 구조화 본문 + 양방향 링크)
            → git commit
                → 그래프 뷰에서 지식망 시각화
```

---

## 에이전트 표준 작업 (Skill)

`CLAUDE.md`를 읽는 에이전트(Claude Code 권장)에게 자연어로 요청하면 아래를
알아서 처리한다. 상세 절차는 각각 `.claude/skills/<이름>/SKILL.md`에 있다.

| 이렇게 말하면 | 무슨 일이 일어나나 | Skill |
|---|---|---|
| "inbox 처리해줘" / "위키로 추출해줘" | `00_Inbox`의 raw 원본을 정식 위키 문서로 추출·분류·연결·커밋 (참여자 허브 노드 자동 생성) | `promote-inbox` |
| "status 검토해줘" / "draft 승인해줘" | draft/review 문서의 **전체 본문**을 보여주고 stable 승격 여부 확인 | `review-status` |
| "위키 점검해줘" / "정합성 체크해줘" | 깨진 wikilink, INDEX 불일치, status 오류, 누락 메타데이터 스캔·보고 | `wiki-lint` |
| "레퍼런스 만들어줘" / "치트시트로 정리해줘" | 흩어진 조회용 자료(명령어·설정값)를 `08_Reference` 레퍼런스로 수집 | `build-reference` |
| "N명 통합해줘" / "여러 명 자료 합쳐줘" | 여러 참여자가 각자 학습한 inbox 원본을 문서 유형별로 통합/분리, 출처 provenance 보존 | `merge-people` |
| "public에 반영해줘" | stable 문서를 별도 공개 핸드북 리포로 정규화·민감정보 제거 후 반영 | `publish-to-public` |

---

## status 워크플로우

```
00_Inbox:  raw → promoted
위키 문서:  draft → review → stable
QnA:       open → resolved
```

에이전트가 만든 문서는 기본값 `draft`로 두고, 사람이 확인 후 `stable`로 바꾼다.
자세한 스키마는 `CLAUDE.md`의 "status 필드 스키마" 참고.

---

## 로컬 뷰어 (mkdocs)

콘텐츠를 채운 뒤에는 mkdocs(Material) 뷰어로 열람할 수 있다.

```powershell
# 최초 1회
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
powershell -File scripts\setup-mkdocs.ps1   # docs/ 정션·하드링크 생성

# 매번
powershell -File scripts\serve-private.ps1  # http://127.0.0.1:8000
```

`docs/`는 저장소 루트 콘텐츠를 가리키는 NTFS 정션/하드링크라 git에 커밋하지
않는다. `[[문서명]]` 위키링크는 Obsidian 또는 mkdocs 뷰어에서 링크로
렌더링된다(GitHub 웹에서는 대괄호가 그대로 보인다).

---

## 새 프로젝트에 적용하려면

1. 이 저장소를 뼈대로 clone/복사한다.
2. `CLAUDE.md`의 저장소 구조·status 스키마·태그 어휘를 프로젝트에 맞게 조정한다.
3. `TAXONOMY.md`의 통제 어휘를 프로젝트 도메인에 맞게 갱신한다.
4. 사람이 `00_Inbox`에 원본을 넣고, 에이전트에게 "inbox 처리해줘"라고 요청한다.
