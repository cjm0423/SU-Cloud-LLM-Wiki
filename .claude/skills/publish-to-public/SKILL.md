---
name: publish-to-public
description: 이 private 위키(status:stable)의 학습·실습 문서를 SU-Cloud-Wiki-Public 리포(mkdocs 공개 핸드북)로 정규화·민감정보 제거해서 옮긴다. "public에 반영해줘", "public wiki 업데이트해줘", "이 문서 public으로 옮겨줘" 같은 요청에 사용.
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash(git *)
---

# /publish-to-public — private 문서 → public 핸드북 반영

이 리포(`SU-Cloud-LLM-Wiki`, private 운영 리포)의 `status: stable` 문서를
`../SU-Cloud-Wiki-Public`(public 핸드북, mkdocs)의 해당 챕터 문서로
정규화·민감정보 제거해서 옮긴다. **public 리포는 별도 git 저장소**이며
경로는 이 리포와 sibling(`E:\SU-Cloud-LLM-Wiki\SU-Cloud-Wiki-Public`)이다.

이 스킬은 처음부터 있던 게 아니라, 2026-07-18에 카카오톡으로 공유된 실제
설계 문서(노션 export: `0. SU-Cloud 문서 카테고리화`, `1. SU-Cloud Public
Handbook repo 폴더 체계 설계안`, `3. 문서 정규화 작업 방안`, `SU-Cloud Wiki
운영 체계 제안`)를 근거로 만들어졌다. 폴더 구조나 문서 유형 체계 자체를
바꾸고 싶으면 이 스킬이 아니라 그 설계 문서 쪽을 먼저 갱신해야 한다.

## 0. 전제 — 이미 확정된 구조

Public 리포의 폴더/파일 구조는 **이미 설계·스캐폴딩되어 있다**
(`00-start-here` ~ `11-contributing` + `99-templates`, 각 폴더 안 파일까지
확정). 이 스킬은 **새 파일을 만드는 게 아니라, 이미 있는 스캐폴딩 파일의
본문을 채우거나 갱신하는 것**이 기본 동작이다. 대상 파일이 안 보이면
먼저 `E:\SU-Cloud-LLM-Wiki\SU-Cloud-Wiki-Public\mkdocs.yml`의 `nav:`와
실제 `docs/` 트리를 확인해서 구조가 바뀌었는지 확인한다 — 없는 카테고리를
새로 만들어야 할 것 같으면 사람에게 먼저 확인한다(폴더 구조 변경은 멘토
리뷰 대상).

## 1. 대상 찾기

`01_Concepts`, `03_Guides`, `02_QnA_Archive`에서 `status: "stable"`인
문서를 Glob/Grep으로 찾는다. 여러 건이면 사람에게 목록을 보여주고 전부
할지 일부만 할지 확인한다.

**기본적으로 제외되는 것** (요청받아도 별도로 한 번 더 확인):
- `04_Meetings`, `06_Decisions`, `05_People` — 학습 콘텐츠가 아니라
  내부 운영 기록
- 내부 인프라 인벤토리/네트워크 구성 자체가 주제인 문서 (예:
  `SU-Cloud-Infrastructure.md`, `SU-Cloud-Campus-Network.md`,
  `Campus-Network-Runbook.md`, `Ops-PC-Network-Setup-Guide.md`,
  `Tailscale-Setup-Guide.md`, `P520-GPU-VLLM-Passthrough-Guide.md`,
  `LLM-Wiki-Usage-Guide.md`) — 이 위키 자체나 운영 인프라에 대한 문서라
  public 학습 커리큘럼 대상이 아님

## 2. 매핑표 — private 문서 → public 대상 파일

아래는 2026-07-18 기준으로 이미 반영을 마친 매핑이다. 새 private 문서가
생기면 이 표에 없는 것부터 확인하고, 아래 기준으로 매핑을 새로 정한다.

| Private 문서 | Public 대상 |
| --- | --- |
| `01_Concepts/OpenStack-Overview.md`, `Neutron.md`, `OpenStack-Internal-Architecture.md` | `02-openstack-basics/*.md` |
| `01_Concepts/VXLAN.md`, `SDN-OVS-OVN-VXLAN.md`, `OVN-OVS-Architecture.md`, `Linux-Bridge.md`, `Provider-vs-SelfService-Network.md`, `Floating-IP.md`, `Security-Group.md` | `03-network-basics/*.md` |
| `03_Guides/DevStack-Installation-Guide.md` + `02_QnA_Archive/*devstack-flamingo*` | `04-devstack-lab/*.md` |
| `03_Guides/DevStack-App-Deploy-Task.md` | `05-vm-3tier-assignment/*.md` |
| `03_Guides/OpenStack-Manual-Install-Guide.md`, `Proxmox-Installation-Guide.md`, `01_Concepts/Proxmox.md` | `06-manual-openstack-install/*.md` |
| `01_Concepts/Kolla-Ansible.md` + `03_Guides/Kolla-Ansible-Install-Guide.md` + `02_QnA_Archive/*kolla-ansible-deploy-troubleshooting*` | `07-kolla-ansible-lab/*.md` |
| `01_Concepts/HA-Concepts.md`, `Network-Path-Diagnosis.md`, `OVN-Network-Flow.md` | `08-network-ha-deep-dive/*.md` |
| `01_Concepts/SU-Cloud-Project-Overview.md`, `SU-Cloud-Project-Roadmap.md` | `01-project-overview/*.md` (반드시 일반화 — 아래 3번) |

새 주제가 매핑표에 없으면, public 리포의 `README.md`에 있는 전체 구조를
보고 가장 맞는 챕터를 고른다. 애매하면 사람에게 물어본다 — 카테고리
자체를 추가하지 않는다(설계상 대분류는 리뷰 없이 임의로 늘리지 않음).

## 3. 정규화 — 옮기면서 반드시 할 것

1. **문서 유형 결정**: `concept` / `lab-guide` / `troubleshooting` /
   `overview` / `process` 중 하나. 대상 public 파일이 이미 있으면 그
   frontmatter의 `type`을 그대로 따른다(임의로 바꾸지 않는다).
2. **해당 유형의 구조를 따른다** — `SU-Cloud-Wiki-Public/docs/99-templates/`의
   템플릿 5종이 각 유형의 정답 구조다.
3. **민감정보 제거/일반화** (가장 중요, 절대 생략하지 않는다):
   - 실명(팀원 이름, 교수님 이름) → 전부 제거하거나 역할로 순화
     (예: "차지만 방식" → "초기 실습 방식")
   - 실제 공인 IP, VPN(Tailscale 등) IP, 실제 내부 IP 할당표 →
     `<EXAMPLE_IP>` 같은 placeholder 또는 RFC 1918/RFC 5737 예시 대역으로
   - 내부 호스트명(예: `cjm-ct01`, `ct01~03`, `cp01~02`, `st01`) →
     `Controller Node 1/2/3`, `Compute Node 1/2` 같은 역할 기반 일반 명칭
   - 하드웨어 브랜드/장비 닉네임(예: 특정 서버 애칭, 스위치 모델명),
     건물/호실 번호 → 전부 삭제 (일반화 불가능하면 문장째 삭제)
   - 실제 UUID, MAC 주소 등 환경 고유 식별자 → 삭제하거나 형식만 보여주는
     placeholder로
   - 원격 접속 방법(VPN 설정, 어떻게 내부망에 들어가는지) 자체를 설명하는
     내용은 **일반화하지 말고 통째로 제외** — 이건 운영 보안 정보라 아무리
     순화해도 public에 적합하지 않음
   - 확실하지 않으면 (제거해도 학습 내용이 안 깨지면) 지운다. 애매하면
     사람에게 물어본다.
4. **`source_note`**: 어느 private 문서에서 가져왔는지 남긴다(파일 경로
   그대로 적어도 됨 — public 문서엔 어차피 private 리포 링크가 없으니
   `[[wikilink]]`가 아니라 평문으로).
5. **`status`**: `draft`로 둔다. `review`/`published`로의 승격은 사람이
   실제로 mkdocs serve로 읽어보고 판단할 몫이다 — 이 스킬이 임의로 올리지
   않는다.
6. **링크**: public 문서 안에서는 Obsidian wikilink(`[[...]]`)가 아니라
   표준 마크다운 상대 링크(`[텍스트](../다른챕터/파일.md)`)를 쓴다 (public
   리포는 roamlinks 플러그인을 쓰지 않기로 결정됨).

## 4. 작업 후 확인

1. 수정한 파일 목록을 사람에게 보여준다 (어떤 private 문서 → 어떤 public
   파일).
2. 민감정보로 판단해서 **뺀 내용**이 있으면 별도로 명시한다 — 사람이
   "그건 괜찮으니 넣어도 된다"고 판단할 수도 있으므로, 임의 판단이었다는
   걸 투명하게 드러낸다.
3. `E:\SU-Cloud-LLM-Wiki\SU-Cloud-Wiki-Public`에서
   `.venv\Scripts\python -m mkdocs build --strict`로 빌드 확인 (경고 있으면
   고치거나 사람에게 보고).
4. 민감정보 재확인용으로 아래와 같은 grep을 한 번 더 돌려서 흔한 패턴이
   남아있지 않은지 스스로 점검한다 (완전하지 않으니 최종 판단은 사람 몫):
   ```
   grep -rEn "192\.168\.[0-9]+\.[0-9]+|100\.[0-9]+\.[0-9]+\.[0-9]+" docs/
   ```

## 5. 커밋

Public 리포(`SU-Cloud-Wiki-Public`)에서 커밋한다 — private 리포와는 별개
커밋이다. 커밋 메시지 형식: `docs: <챕터> — <무엇을 반영했는지>`.

**push는 하지 않는다.** 사람이 실제로 내용을 읽어보고 확인한 뒤 명시적으로
요청했을 때만 push한다.

## 하지 말 것

- Public 리포의 폴더/파일 구조(`00-start-here` ~ `99-templates`)를 스스로
  바꾸지 않는다 — 구조 변경은 멘토 리뷰 대상.
- `status: draft`인 private 문서는 옮기지 않는다 — 아직 검증 안 된 내용을
  공개하지 않기 위함.
- 민감정보 제거를 "나중에 AI로 일괄 스캔하면 되니까"라며 생략하지 않는다
  — 일괄 스캔은 **추가 안전장치**이지, 옮기는 시점의 책임을 대체하지 않는다.
- private 리포의 원본 문서는 건드리지 않는다 (읽기만 한다).
