---
title: "문서 자동화 - 하네스 엔지니어링"
type: "raw"
date: 2026-07-12
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# 문서 자동화 - 하네스 엔지니어링

[SU-Cloud-LLM-Wiki.zip](%EB%AC%B8%EC%84%9C%20%EC%9E%90%EB%8F%99%ED%99%94%20-%20%ED%95%98%EB%84%A4%EC%8A%A4%20%EC%97%94%EC%A7%80%EB%8B%88%EC%96%B4%EB%A7%81/SU-Cloud-LLM-Wiki.zip)

# SU Cloud LLM Wiki — 지식 관리 시스템

> 채팅창에서 흩어지는 질문, 회의 결정, 트러블슈팅 과정을 마크다운 위키로
영구 축적하는 시스템. Andrej Karpathy의 LLM Wiki 철학 + Google OKF(Open
Knowledge Format) + Obsidian 그래프뷰 기반.
> 

---

## 1. 왜 만들었나

- 팀원이 AI와 나눈 문제 해결 대화, 회의에서 나온 결정, 트러블슈팅 과정은
**한 번 쓰고 사라지기엔 아까운 지식**입니다.
- 핵심 원칙: **질문도 자산이다.** 좋은 답변은 채팅에 흩어지게 두지 말고,
위키에 새 페이지로 저장해 축적합니다.
- 결과물은 git으로 관리되는 마크다운 파일 묶음이고, Obsidian으로 열면
그래프뷰에서 지식 간 연결이 시각화됩니다.

---

## 2. 전체 파이프라인 (5단계)

```
0단계 — 원본 보존 (Inbox)
회의/대화가 끝나면 가공 없이 STT 전사나 채팅 로그를 그대로 저장
    ↓
1단계 — 질의응답 (Chat)
팀원이 AI(Claude, ChatGPT, Gemini 등)와 대화하며 문제 해결
    ↓
2단계 — AI의 지식화 (Format)
"이 내용을 위키로 추출해 줘" 명령 → AI가 OKF 표준(YAML + 구조화 마크다운)으로 변환
원본이 있으면 raw_source 필드로 역참조 남김
    ↓
3단계 — 저장 및 연동 (GitHub)
변환된 마크다운을 저장소에 commit
원본 inbox 파일은 삭제하지 않고 상태만 raw → promoted로 변경
    ↓
4단계 — 시각화 및 연결 (Obsidian)
팀원 각자 로컬에서 Vault로 열고 그래프뷰(Ctrl+G)로 지식망 확인
```

**핵심 설계 포인트:** 요약본만 남기지 않고, **원본(0단계)과 가공본(2단계)을
양방향 링크로 연결**해서 나중에 검증 가능하게 만든 것이 이 시스템의 핵심
개선점입니다.

---

## 3. 폴더 구조

| 폴더 | 역할 |
| --- | --- |
| `00_Inbox` | 원본 저장소 — STT 전사, 채팅 로그 등 가공 전 raw 데이터 |
| `01_Concepts` | 정적 개념 문서 (OpenStack, Neutron, VXLAN, Floating IP 등) |
| `02_QnA_Archive` | AI 질의응답 추출 문서 — 가장 많이 쌓이는 곳 |
| `03_Guides` | 확정된 튜토리얼 / 설치 가이드 |
| `04_Meetings` | 회의 아카이브 (inbox에서 승격된 요약본) |
| `05_People` | 참여자 허브 노드 (그래프뷰에서 사람 중심으로 연결 확인) |
| `99_Templates` | 새 문서 작성 시 쓰는 Obsidian 템플릿 |

---

## 4. 폴더별 상세 설명

### `00_Inbox` — 원본 보존 계층 (신규 도입)

**문제:** 기존 구조는 AI가 요약·가공한 결과물만 쌓였습니다. 요약 과정에서
뉘앙스가 빠지거나 잘못 정리돼도 검증할 원본이 없었습니다.

**해결:** 원본을 가공 없이 먼저 저장하는 계층을 추가했습니다.

- 규칙은 단 하나 — **"일단 저장, 정리는 나중에."** 오탈자, 잡담, 반복 다 그대로 둡니다.
- 파일명: `YYYY-MM-DD-keyword-raw.md`
- 정식 문서로 승격돼도 원본은 삭제하지 않고 `status: raw → promoted`로만 변경
- 정식 문서 쪽에는 `raw_source: "[[00_Inbox/원본파일명]]"`로 역참조

이렇게 하면 "저장"과 "정리"가 분리돼서, 바빠서 정리를 못해도 최소한 원본은
잃어버리지 않습니다.

---

### **`01_Concepts` — 변하지 않는 개념 정의**

"이게 뭔지"를 설명하는 정적 지식. 프로젝트 진행 상황과 무관하게 계속
유효한 개념들입니다. 예: `OpenStack-Overview`(Nova/Neutron/Glance 등
컴포넌트 역할), `VXLAN`(오버레이 네트워크 원리), `Floating-IP`(DNAT 매핑
동작). 구조는 "한 줄 정의 → 상세 설명 → SU Cloud에서의 활용 → 관련
개념"이며, 한번 작성하면 잘 바뀌지 않는다는 게 특징입니다.

---

### **`02_QnA_Archive` — 트러블슈팅/질의응답 기록**

"이 문제를 어떻게 풀었는지"를 담는 곳. 01_Concepts와 달리 특정 시점,
특정 상황에 묶여 있는 지식입니다. 예: `2026-05-15-devstack-flamingo- python-error` — 특정 날짜에 특정 팀원이 겪은 Python 버전 충돌 문제,
원인 분석, 해결 코드, 다른 팀원이 겪은 유사 이슈까지 기록. 구조는
상황(Context) → 분석(Analysis) → 해결책(Solution) → 추가 통찰(Insights).
가장 많이 쌓일 폴더입니다 — AI와 대화하다 막힌 부분이 생길 때마다
여기로 추출됩니다.

---

### **`03_Guides` — 검증된 재현 가능한 절차**

QnA와 구분 기준: QnA는 "특정 문제 하나"를 푼 기록이고, Guide는
"처음부터 끝까지 따라 하면 되는 완성된 절차"입니다. 예:
`DevStack-Installation-Guide`, `Proxmox-Installation-Guide` — 둘 다
"버전/브랜치 선택 주의" 표가 맨 위에 있고, 실제 검증된 버전(예: Proxmox
8.4는 성공, 9.2는 하드웨어 충돌)을 명시합니다. QnA에서 반복적으로 나온
문제가 해결되면, 그 과정을 정리해서 Guide로 승격시키는 흐름도
가능합니다 (QnA → Guide).

---

### **`04_Meetings` — 회의 아카이브**

날짜별 회의록. `00_Inbox`의 원본(STT 등)이 요약·구조화돼 승격된
결과물입니다. 구조는 Session Snapshot(날짜/참여자) → Summary → 주요
논의 내용 → Action Items(체크박스, 담당자/기한) → Related Notes. 실제
킥오프 회의록에는 "왜 이 결정을 했는지"(핵심 판단)까지 남겨서, 나중에
"그때 왜 이렇게 정했지?"에 답할 수 있게 되어 있습니다.

---

### **`05_People` — 참여자 허브 노드**

사람 한 명당 파일 하나. 문서 내용 자체는 거의 없고, Dataview 쿼리로
"이 사람이 참여한 회의 목록"을 자동으로 끌어옵니다. 콘텐츠 저장용이
아니라, Obsidian 그래프뷰에서 사람을 중심으로 어떤 회의/문서와
연결되는지 한눈에 보여주는 연결 전용 폴더입니다.

---

### **`99_Templates` — 새 문서 작성 틀**

`OKF-Concept-Template`, `OKF-QnA-Template`, `OKF-Meeting-Template`,
`OKF-Raw-Template` 4종. 새 문서 만들 때 이 폴더 파일을 복사(또는
Templater 플러그인으로 자동 삽입)해서 씁니다. `99`로 시작하는 건 폴더
정렬 시 맨 뒤로 보내기 위한 관례입니다.

---

### 전체 흐름 요약

```
00_Inbox (원본)
    → 02_QnA_Archive / 04_Meetings (가공된 개별 기록)
        → 01_Concepts / 03_Guides (검증되어 안정화된 지식)
            → 05_People (연결 허브)
```

이 전체를 찍어내는 틀이 `99_Templates`입니다.

---

## 5. 문서 포맷 (OKF 템플릿)

모든 문서는 YAML frontmatter + 구조화된 마크다운을 따릅니다.

| 템플릿 | 용도 | 주요 항목 |
| --- | --- | --- |
| OKF-Concept-Template | 개념 정리 | 한 줄 정의, 상세 설명, 활용, 관련 개념 |
| OKF-QnA-Template | 트러블슈팅/질의응답 | 상황·질문 → 분석 → 해결책 → 후속 통찰 |
| OKF-Meeting-Template | 회의록 | 요약, 논의 내용, Action Items, 관련 노트 |
| OKF-Raw-Template | 원본 캡처 (신규) | 원본 내용 그대로 + 선택적 메모 |

공통 규칙: 연관 개념은 반드시 `[[문서명]]` 양방향 링크로 표기 → Obsidian
그래프뷰에서 지식망으로 시각화됨.

---

## 6. 운영 방식

1. GitHub 저장소를 Git으로 관리 (AI가 커밋 진행 가능)
2. 팀원 각자 로컬 PC에 clone → Obsidian Vault로 오픈
3. 권장 플러그인: **Dataview**(YAML 기반 동적 테이블), **Templater**(템플릿
자동 삽입), **Git**(Obsidian 안에서 commit/push)
4. 회의/트러블슈팅 종료 시 담당자가 원본을 Inbox에 저장 → AI에게 추출 요청
→ GitHub commit까지 진행

---

## 7. 기대 효과

- 질문과 분석 결과가 채팅창에서 사라지지 않고 누적 자산이 됨
- 신규 팀원 온보딩 시 그래프뷰로 프로젝트 지식 구조를 한눈에 파악 가능
- 트러블슈팅 재발 시 과거 QnA 검색으로 즉시 해결책 확인
- 원본(raw)과 가공본(promoted)이 분리돼 있어 정보 신뢰도 유지

[SU-Cloud-LLM-Wiki 사용가이드](%EB%AC%B8%EC%84%9C%20%EC%9E%90%EB%8F%99%ED%99%94%20-%20%ED%95%98%EB%84%A4%EC%8A%A4%20%EC%97%94%EC%A7%80%EB%8B%88%EC%96%B4%EB%A7%81/SU-Cloud-LLM-Wiki%20%EC%82%AC%EC%9A%A9%EA%B0%80%EC%9D%B4%EB%93%9C%2039fd8e51100c80679154d5a9b024660c.md)