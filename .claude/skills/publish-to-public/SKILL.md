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

`01_Concepts`, `03_Guides`, `02_QnA_Archive`, `07_SU-Cloud`, `08_Reference`에서
`status: "stable"`인 문서를 Glob/Grep으로 찾는다. 여러 건이면 사람에게
목록을 보여주고 전부 할지 일부만 할지 확인한다.

**기본적으로 제외되는 것** (요청받아도 별도로 한 번 더 확인):
- `04_Meetings`, `06_Decisions`, `05_People` — 학습 콘텐츠가 아니라
  내부 운영 기록
- `08_Reference` 문서 중 우리 환경 고유값(노드명 `ct01~03`·`cp01~02`,
  IP·MAC·`ens19` 등)이 든 조회표 — 내부 인프라 정보라 public 대상이 아님.
  범용 도구 문법만 담은 레퍼런스라면 공개 가능하나, 매핑은 사람이 확인.
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
| `07_SU-Cloud/SU-Cloud-Project-Overview.md`, `SU-Cloud-Project-Roadmap.md` | `01-project-overview/*.md` (반드시 일반화 — 아래 3번) |

새 주제가 매핑표에 없으면, public 리포의 `README.md`에 있는 전체 구조를
보고 가장 맞는 챕터를 고른다. 애매하면 사람에게 물어본다 — 카테고리
자체를 추가하지 않는다(설계상 대분류는 리뷰 없이 임의로 늘리지 않음).

## 3. 정규화 — 옮기면서 반드시 할 것

1. **문서 유형 결정**: `concept` / `lab-guide` / `troubleshooting` /
   `overview` / `process` 중 하나. 대상 public 파일이 이미 있으면 그
   frontmatter의 `type`을 그대로 따른다(임의로 바꾸지 않는다).
2. **해당 유형의 구조를 따른다** — `SU-Cloud-Wiki-Public/docs/99-templates/`의
   템플릿 5종이 각 유형의 정답 구조다.

### 2-1. frontmatter는 private 스키마를 그대로 옮기지 않는다

Private 템플릿(2026-07-20 개편)은 public보다 필드가 훨씬 많고, **늘어난
필드 상당수가 민감정보를 담는 자리다.** public frontmatter는 아래 7개가 전부다:

```yaml
type: / title: / category: / tags: [] / status: draft / source_note: "" / last_updated:
```

| Private 필드 | public 처리 |
|---|---|
| `hardware` | ❌ **삭제** — 장비 모델·애칭이 그대로 들어있다 (`Lenovo P520`, `IdeaCentre Gaming5`) |
| `environment` | ⚠️ **재작성** — 공인 IP·내부 호스트명·MAC이 섞여 있다. OS/버전만 남기고 나머지 삭제 |
| `symptoms` | ⚠️ **재작성** — 검색 키워드라 유용하니 살리되, IP·MAC·내부 호스트명은 제거 |
| `os`, `target_version`, `verified_on` | ✅ 본문 "검증된 환경" 표로 흡수 (버전 정보는 학습에 유용) |
| `raw_source` | ❌ 삭제 → `source_note`에 평문 경로로 |
| `reviewed_by`, `reviewed_date`, `author` | ❌ 삭제 (실명) |
| `related_nodes` | ❌ 삭제 → 본문 상대 링크로 |
| `decision_status`, `supersedes`, `superseded_by`, `meeting_type`, `participants`, `deciders`, `role`, `focus_areas` | ❌ 삭제 (애초에 public 대상 폴더가 아님) |
| `tags` | private 통제 어휘(`TAXONOMY.md`)를 그대로 쓰지 않는다. `#devpc`/`#production`/`#campus-network` 같은 **환경 축 태그는 전부 제거** — 내부 환경 구분이라 public에 의미 없고 힌트만 준다 |

### 2-2. 새로 생긴 본문 섹션 처리

2026-07-20 템플릿 개편으로 아래 섹션들이 생겼다. 학습 가치가 높지만
**민감정보가 가장 많이 모이는 자리**이기도 하다.

| 섹션 | 처리 |
|---|---|
| **검증된 환경** 표 | OS·버전·소요시간은 유지. **Public IP / 내부 IP / 장비 모델 / 호스트명 / 검증자 이름 행은 삭제** |
| **알려진 비호환 조합** | ✅ 그대로 유지 — 버전 조합 정보라 학습 가치가 가장 높다 |
| **에러 메시지 원문** | 로그 안에 IP·호스트명이 섞이므로 **한 줄씩 확인**. 마스킹하되 에러 문자열 자체는 살린다 |
| **시도했지만 실패한 방법** | ✅ 유지 — 순수 기술 판단 기록이면 그대로. 내부 장비 얘기(예: "USB 랜카드를 개발계 PC로")는 삭제 |
| **최종 검증 / 트러블슈팅** | 명령어는 유지, 출력 예시의 IP·호스트명은 placeholder로 |
| **롤백** | ✅ 유지 |
| **재발 방지 / 남은 과제** | ❌ **통째로 삭제** — 내부 운영 TODO(누가 무엇을 요청, 캠퍼스팀 협의 등)라 public 무관 |

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

### 3-1. 🔴 자격증명 — 발견 즉시 중단하고 사람에게 알린다

**`00_Inbox` 원본에 실제 비밀번호가 평문으로 저장되어 있다** (2026-07-20 확인).
private 리포라 그대로 두기로 했으나, **public으로는 어떤 형태로도 넘어가면 안 된다.**

확인된 위치 (2026-07-20 기준, 이후 늘어날 수 있음):

| 원본 | 내용 |
|---|---|
| `2026-06-14-tailscale-remote-raw.md` | Proxmox root 비밀번호 |
| `2026-07-05-devpc-kolla-setup-raw.md` | OpenStack admin 비밀번호 |
| `2026-06-28-p520-gpu-vllm-passthrough-raw.md` | GPU VM 계정/비번, 공용 Google 계정 |

**옮기기 전에 반드시 대상 문서에 아래를 돌린다:**

```bash
grep -rEni "password|passwd|비밀번호|비번|secret|token|api[_-]?key|credential|\
keystone_admin|ssh-rsa|BEGIN [A-Z ]*PRIVATE KEY|@gmail\.com|@[a-z0-9-]+\.(com|net|kr)" <대상파일>
```

**처리 규칙:**

- **값이 보이면 그 줄을 옮기지 않는다.** 마스킹(`****`)도 하지 않는다 —
  마스킹은 "여기 비밀번호가 있다"는 사실 자체를 알려주므로, 아예 문장을 지운다.
- 비밀번호를 **확인하는 방법**(예: `grep keystone_admin_password
  /etc/kolla/passwords.yml`)은 표준 절차라 유지해도 된다. 값만 없으면 된다.
- **계정 주소**(공용 Google 계정 등)는 값이 아니어도 삭제한다.
- `kolla-genpwd`처럼 비밀번호를 **생성**하는 명령은 유지한다.
- 자격증명을 발견하면 **작업을 멈추고 사람에게 어느 파일 몇 번째 줄인지
  보고한다.** 조용히 지우고 넘어가지 않는다 — 원본 쪽 로테이션이 필요한지
  사람이 판단해야 한다.
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
4. 민감정보 재확인용으로 아래 grep을 **전부** 돌려서 남은 게 없는지
   점검한다 (완전하지 않으니 최종 판단은 사람 몫):

   ```bash
   # ① 자격증명 — 하나라도 걸리면 즉시 중단하고 보고
   grep -rEni "password|passwd|비밀번호|비번|secret|token|api[_-]?key|credential|keystone_admin|ssh-rsa|BEGIN [A-Z ]*PRIVATE KEY|@gmail\.com" docs/

   # ② IP — 공인 IP(210.94.x)는 절대 남으면 안 됨. 사설도 예시 대역인지 확인
   grep -rEn "210\.94\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+|100\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+" docs/

   # ③ MAC 주소 — 2026-07-20 템플릿 개편으로 symptoms 필드에 들어가기 시작함
   grep -rEn "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" docs/

   # ④ 내부 호스트명·장비·위치
   grep -rEn "cjm-|su-cloud-dev|ct0[1-3]|cp0[1-2]|st01|brbond0|enp7s0f0|Gaming5|ThinkStation|P520|A5500|TL-SG108|OfficeConnect|EX3300|[0-9]{3}호|[0-9]+번 ?벽?포트" docs/

   # ⑤ 실명
   grep -rEn "차지만|박준우|백지원|이민기|김재현|안현|조충희" docs/
   ```

   > ⚠️ **자주 놓치는 자리** — 2026-07-20 템플릿 개편 이후 민감정보는 본문보다
   > **frontmatter의 `environment`/`symptoms`/`hardware` 필드**와 **"검증된 환경"
   > 표**에 더 많이 모인다. 본문만 훑고 넘어가지 말 것.

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
