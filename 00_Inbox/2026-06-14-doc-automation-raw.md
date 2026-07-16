---
title: "문서 자동화 정리"
type: "raw"
date: 2026-06-14
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[01_Concepts/LLM-Wiki-Concept]]"
---
# 문서 자동화 정리

---

참고 자료:

# 안드레 카파시

[안드레이 카파시가 제안한 ‘LLM Wiki’](https://javaexpert.tistory.com/1709)

### **질문도 자산이 된다**

좋은 답변은 채팅에 흩어지게 두지 말고, **위키에 새 페이지로 저장해 축적하라**는 것입니다.

즉, 소스만 축적되는 것이 아니라 **질문과 분석 결과까지 누적**

git으로 관리(AI가 진행)되는 마크다운 파일 묶음 → Obsidian으로 시각화

# 구글 OKF(Open Knowledge Format)

[Google Cloud가 공개한 Open Knowledge Format, OKF 쉽게 이해하기](https://javaexpert.tistory.com/1777)

**사람과 AI 에이전트가 모두 읽고 이해할 수 있도록** 구글이 발표한 지식 정리용 개방형 포맷(표준)

---

[SU-Cloud-LLM-Wiki.zip](%EB%AC%B8%EC%84%9C%20%EC%9E%90%EB%8F%99%ED%99%94%20%EC%A0%95%EB%A6%AC/SU-Cloud-LLM-Wiki.zip)

### 📁 전체 구조 한눈에 보기

`SU-Cloud-LLM-Wiki/     (28개 파일 / 1,424줄)
├── README.md
├── 01_Concepts/       (6개)
├── 02_QnA_Archive/    (2개)
├── 03_Guides/         (2개)
├── 04_Meetings/       (6개)
├── 05_People/         (8개)
└── 99_Templates/      (3개)`

---

### 📄 README.md — 저장소 진입점

이 레포 전체의 **사용 설명서**

**① LLM Wiki 철학** — Karpathy의 "질문도 자산이다" 원칙과 Google OKF 개념을 SU Cloud에 어떻게 적용하는지 설명합니다.

**② 파이프라인 흐름** — `AI와 대화 → "위키로 추출해 줘" → OKF 마크다운 변환 → GitHub commit → Obsidian 그래프 시각화` 4단계를 정리했어요.

**③ LLM Wiki 에이전트 시스템 프롬프트** — 팀원이 AI에게 붙여서 쓸 수 있는 프롬프트 전문이 들어 있습니다. 이걸 Claude나 ChatGPT 대화 첫머리에 붙이면, 대화 끝에 "문서화해 줘"라고만 해도 OKF 형식으로 뽑아줍니다.

**④ Obsidian 세팅 방법** — Clone → Vault 열기 → `Ctrl+G` 그래프 뷰, Dataview 플러그인 설치 방법까지 담았습니다.

---

### 📁 01_Concepts/ — 개념 문서 6개

프로젝트를 하면서 반복적으로 참조하게 될 **정적 개념 레퍼런스**들입니다. 새 팀원이 합류했을 때 가장 먼저 읽어야 할 문서들이에요.

**`SU-Cloud-Project-Overview.md`** — 프로젝트 전체 개요. 비전, 3단계 로드맵(Infrastructure MVP → Self-Service Portal → Production 운영), 팀 구성, 기술 스택을 한 파일에 정리했습니다. 신규 팀원 온보딩용

**`OpenStack-Overview.md`** — Nova, Neutron, Glance, Keystone, Cinder, Horizon 등 핵심 컴포넌트 역할 정리, Controller/Compute Node 구성, 사용자 요청이 Keystone → Nova → Neutron을 거쳐 VM이 뜨는 전체 트래픽 흐름 다이어그램

**`Provider-vs-SelfService-Network.md`** — 킥오프에서 "이걸 먼저 이해해야 한다"고 강조된 핵심 개념. Provider/Self-Service의 구조 차이, 패킷이 VM → br-int → VXLAN → qrouter namespace → 물리망을 지나가는 흐름을 ASCII 다이어그램으로 그렸고, AWS VPC와 비교 테이블

**`VXLAN.md`** — Self-Service Network가 물리적으로 다른 서버의 VM끼리 같은 네트워크처럼 통신할 수 있는 원리. VNI, VTEP, UDP 4789 포트, 패킷 캡슐화 구조를 설명합니다. 서버가 2대 이상으로 늘어날 때 반드시 이해해야 하는 내용이에요.

**`Floating-IP.md`** — Self-Service Network의 VM에 공인 IP를 동적으로 매핑하는 방법. qrouter의 DNAT/SNAT 동작 원리, AWS Elastic IP와의 비교, 자주 하는 실수(Security Group 포트 안 열기) 포함.

**`Proxmox.md`** — SU Cloud에서 Proxmox가 왜 필요한지(물리 서버 위에서 여러 VM으로 반복 실습 가능), v9.2는 하드웨어 충돌로 v8.4를 써야 한다는 이슈, Tailscale과 연결해서 외부에서 접근하는 구조를 설명합니다.

---

### 📁 02_QnA_Archive/ — QnA 추출 문서 2개

AI와 나눈 대화 중 재사용 가치가 있는 것들을 OKF 포맷으로 뽑아낸 공간입니다. **앞으로 가장 많이 쌓여갈 폴더**예요.

**`INDEX.md`** — Obsidian Dataview 쿼리가 심어져 있어서, 플러그인을 설치하면 이 폴더의 모든 QnA가 날짜/태그/상태 기준으로 **동적 테이블**로 자동 생성됩니다. 수동 목록도 병기했어요.

**`2026-05-15-devstack-flamingo-python-error.md`** — 실제 팀 이슈에서 뽑은 첫 번째 QnA 문서. Flamingo(2025.2) 브랜치에서 Python/Sphinx 충돌이 나는 원인 분석, stable/2023.1로 다운그레이드하는 해결책, 이민기(OOM)·김재현(Apple Silicon) 이슈까지 함께 담았습니다. OKF 포맷(Context → Analysis → Solution → Insights) 구조의 실제 예시로도 활용됩니다.

---

### 📁 03_Guides/ — 설치 가이드 2개

실습에서 검증된 **재현 가능한 튜토리얼**입니다.

**`DevStack-Installation-Guide.md`** — Ubuntu 22.04 + stable/2023.1(Antelope) 기준. stack 사용자 생성 → git clone → local.conf 작성 → `./stack.sh` 실행 → 설치 후 체크리스트(Horizon 접속, Provider/Self-Service Network 생성, VM + Floating IP + SSH)까지 단계별로 정리했어요. 자주 발생하는 오류 3가지(Flamingo 충돌, OOM, Apple Silicon)도 표로 포함됩니다.

**`Proxmox-Installation-Guide.md`** — 2026-06-15 학교 ThinkStation 실습 기반. v8.4 ISO 선택 이유, USB 부팅 → 설치 마법사 → 웹 UI 접속, Tailscale 연결, 학생용 VM 생성, **중첩 가상화(Nested Virtualization) 활성화** 명령어(OpenStack KVM 실습에 필수)까지 담겼습니다.

---

### 📁 04_Meetings/ — 회의 아카이브 6개

zip 파일의 `00.inbox` 원본 STT 전사본을 **OKF Meeting 포맷으로 승격**시킨 문서들입니다. 원본의 긴 전사 내용을 Summary → 주요 논의 → Action Items → Related Notes 구조로 압축했어요.

**`INDEX.md`** — 전체 회의 목록 타임라인(2026-04 ~ 2026-06-16)과 Dataview 쿼리. 프로젝트 흐름을 한눈에 볼 수 있습니다.

**`2026-05-06-professor-meeting.md`** — 교수님·박준우·안현이 학교 서버/네트워크 자원 확인, Infrastructure MVP와 Self-Service Portal MVP 분리 결정한 첫 공식 회의.

**`2026-05-07-cha-jiman-1on1.md`** — 차지만과 1:1로 학생 팀 의지 확인, 정식 시작을 기말고사 이후(6월 중순)로 확정, 사전학습 계획 수립.

**`2026-05-17-prestudy-1.md`** — 학생들 첫 사전학습 점검. 기초 강의보다 DevStack 실습 + 네트워크 이해 중심으로 방향 전환 결정. 안현이 설명한 심화 개념(중첩 가상화, Kolla Ansible, Ceph 등) 포함.

**`2026-06-13-leader-prep.md`** — 킥오프 직전 박준우-차지만 사전 미팅. "AI 시대 엔지니어 역량" 메시지, 차지만의 PL 역할 범위(교수님 소통, 팀 관리, 회의록), Cloud Club 연계 전략이 핵심입니다.

**`2026-06-13-kickoff.md`** — 전체 팀 공식 킥오프. 서버 현황, 3단계 OpenStack 설치 전략, Proxmox+Tailscale 원격 접속 모델, SU Cloud 가치 제안, 10개 Action Items 포함.

---

### 📁 05_People/ — 참여자 허브 노드 8개

Obsidian 그래프 뷰에서 **사람 → 회의 → 개념**이 연결되게 만드는 허브 역할입니다. 각 사람 파일에는 Dataview 쿼리가 심어져 있어서, 해당 인물이 참여한 회의 목록이 자동으로 뜹니다.

차지만, 박준우, 안현, 이민기, 백지원, 김재현, 조충희 교수님 + `INDEX.md` 총 8개.

---

### 📁 99_Templates/ — OKF 템플릿 3개

새 문서를 작성할 때 복사해서 쓰는 **형식 표준**입니다.

**`OKF-QnA-Template.md`** — AI와 대화 후 추출용. Context → Analysis → Solution → Insights 4섹션 + YAML Frontmatter(type, date, tags, related_nodes, status).

**`OKF-Concept-Template.md`** — 새 개념 문서용. 한 줄 정의 → 상세 설명 → SU Cloud에서의 활용 → 관련 개념 구조.

**`OKF-Meeting-Template.md`** — 새 회의 요약용. Session Snapshot → Summary → 주요 논의 → Action Items → Related Notes 구조.

---

**한 줄 요약하면**, zip의 raw 회의록 데이터를 뼈대로 삼고, 거기서 나온 개념·이슈·결정을 모두 `[[wikilink]]`로 연결되는 OKF 포맷 문서로 변환한 구조입니다. Obsidian에서 열면 이 연결들이 그래프로 시각화되고, 앞으로 팀원들이 AI와 해결한 내용을 `02_QnA_Archive`에 추가할수록 지식망이 점점 두터워지는 방식이에요.

- 사용 시나리오
    
    ### 1단계 — 세팅 (딱 한 번만)
    
    **GitHub에 올리기**
    
    ```jsx
    cd SU-Cloud-LLM-Wiki
    git init
    git remote add origin <GitHub 레포 URL>
    git add .
    git commit -m "init: SU-Cloud LLM Wiki 초기 구성"
    git push -u origin main
    ```
    
    **팀원들 각자 세팅**
    
    ```jsx
    git clone <GitHub 레포 URL>
    ```
    
    그 다음 Obsidian 실행 → `Open folder as vault` → 클론한 폴더 선택. 끝입니다.
    
    ---
    
    ### 2단계 — 일상적인 사용 패턴 3가지
    
    ### 패턴 A. 트러블슈팅 후 문서화 (가장 흔한 케이스)
    
    예를 들어 Neutron 네트워크 설정하다가 막혔을 때:
    
    **① AI와 문제 해결**
    
    `나: OpenStack에서 VM에 Floating IP 붙였는데 ping이 안 돼요.
    AI: Security Group에서 ICMP를 허용했는지 확인해보세요...
        (대화 이어짐)
    나: 됐습니다! Security Group + router gateway 설정이 문제였네요.`
    
    **② 문서화 명령 한 마디**
    
    `나: 이 내용을 위키로 추출해 줘`
    
    **③ AI가 OKF 마크다운으로 출력**
    
    ```jsx
    <!-- 파일명: 2026-06-20-floating-ip-ping-fail.md -->
    ---
    title: "Floating IP 연결 후 ping 불가 문제"
    type: "troubleshooting"
    date: 2026-06-20
    tags: ["#floating-ip", "#security-group", "#networking"]
    related_nodes: ["[[Floating-IP]]", "[[Provider-vs-SelfService-Network]]"]
    ...
    ```
    
    **④ 파일 저장 후 push**
    
    ```jsx
    # 출력 내용을 복사해서 파일로 저장
    02_QnA_Archive/2026-06-20-floating-ip-ping-fail.md
    
    git add . && git commit -m "docs: Floating IP ping 불가 트러블슈팅" && git push
    ```
    
    **⑤ 팀원들이 pull하면 Obsidian 그래프에 자동 반영**
    
    ---
    
    ### 패턴 B. 회의 후 문서화
    
    회의가 끝난 뒤 STT 전사본이나 메모를 들고:
    
    `나: [회의 내용 붙여넣기]
        이걸 위키 회의록 포맷으로 정리해 줘`
    
    AI가 `99_Templates/OKF-Meeting-Template.md` 형식으로 정리해주면 `04_Meetings/`에 저장하고 push.
    
    ---
    
    ### 패턴 C. 새 개념 공부 후 정리
    
    VXLAN이나 Ceph 같은 새 개념을 공부했을 때:
    
    `나: VXLAN과 VLAN의 차이를 공부했는데 이걸 개념 문서로 만들어 줘
        SU Cloud 맥락도 포함해서`
    
    `01_Concepts/`에 저장하면 기존 문서들과 `[[wikilink]]`로 자동 연결됩니다.
    
    ---
    
    ### 3단계 — Obsidian에서 실제로 보이는 것들
    
    **그래프 뷰 (`Ctrl+G`)**
    
    지금 당장 열어도 이렇게 보입니다:
    
    `[차지만] ── [2026-06-13-kickoff] ── [OpenStack-Overview]
                        │                        │
                [2026-06-13-leader-prep]     [VXLAN]
                                                 │
                                  [Provider-vs-SelfService-Network]`
    
    문서가 쌓일수록 어떤 기술에 질문이 몰리는지, 누가 어떤 회의에 참여했는지 군집이 생깁니다.
    
    **Dataview 동적 테이블** (`02_QnA_Archive/INDEX.md` 열면)
    
    | date | title | tags | status |
    | --- | --- | --- | --- |
    | 2026-06-20 | Floating IP ping 불가 | #floating-ip | resolved |
    | 2026-05-15 | DevStack Flamingo 오류 | #devstack | resolved |
    
    새 파일 push할 때마다 이 테이블이 자동으로 업데이트됩니다.
    
    ---
    
    ### 실제 팀 운영 제안
    
    개인적으로 이렇게 운영하면 부담이 가장 적을 것 같아요.
    
    **차지만(PL)이 할 것:** 회의 후 AI로 회의록 정리 → `04_Meetings/`에 push. 매주 1회.
    
    **팀원 각자가 할 것:** 막혔다가 해결되면 AI에게 "위키로 추출해 줘" → `02_QnA_Archive/`에 push. 해결할 때마다.
    
    **아무도 안 해도 되는 것:** `01_Concepts/` 개념 문서는 이미 만들어져 있으니 추가로 공부한 개념이 생길 때만 선택적으로 추가.
    
    이렇게 하면 PL이 따로 문서 정리에 시간을 쓰지 않아도, 팀원들이 문제 해결하는 과정 자체가 자동으로 지식망이 되는 구조입니다.