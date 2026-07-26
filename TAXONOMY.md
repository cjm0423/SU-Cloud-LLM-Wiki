---
title: "태그 분류 체계 (Controlled Vocabulary)"
type: "reference"
date: 2026-07-20
status: "stable"
---

# 태그 분류 체계

이 위키에서 사용할 수 있는 태그는 **아래 23개가 전부다.** 여기 없는 태그는
새로 만들지 않는다. 사람도, 에이전트도 마찬가지다.

## 왜 통제 어휘인가

2026-07-20 이전 위키에는 태그가 74개 있었고 그중 **52개(70%)가 1~2개
문서에만 붙어 있었다.** `#antelope`, `#kafka`, `#octavia` 같은 태그는
문서 하나만 걸리므로 "묶어서 보기"라는 태그 본연의 기능을 못 한다.

**태그는 문서 요약이 아니라 문서를 가로질러 묶는 도구다.**
문서 내용을 설명하고 싶으면 태그가 아니라 `title`과 본문에 쓴다.
특정 버전·제품명(`Antelope`, `Kafka`, `Octavia`)은 본문 검색으로 찾는다.

## 태깅 규칙

1. **문서당 2~5개, 대개 3~4개.** 6개 이상이면 태그로 요약을 하고 있는 것이다.
   단, `OpenStack-Overview`처럼 축 하나로 완전히 규정되는 문서는 1개도 괜찮다.
   억지로 채우지 않는다.
2. **아래 4개 축에서 골라 조합한다.** 축마다 최대 2개.
   해당 없는 축은 그냥 비운다.
3. **`type` 필드와 중복되는 태그는 금지.** `type: "guide"`인 문서에
   `#guide`를 붙이지 않는다. 폴더와 `type`이 이미 그 일을 한다.
4. **모든 문서에 붙는 태그는 만들지 않는다.** 폐기된 `#su-cloud`가
   그 예다 — SU Cloud 리포에서 su-cloud 태그는 정보량이 0이다.
5. **`00_Inbox` 원본은 예외.** 기존대로 `#raw`, `#inbox`만 유지한다.
   원본은 승격 전 임시 보관물이라 주제 분류 대상이 아니다.
6. **`05_People`과 각 `INDEX.md`는 태그를 비운다** (`tags: []`).
   `type: "person"` / `type: "index"`로 충분하다.

---

## 축 A — 기술 스택 (7개)

무엇을 다루는 소프트웨어/제품인가.

| 태그 | 범위 |
|---|---|
| `#openstack` | OpenStack 코어 전반 (Nova, Neutron, Keystone, Glance, Cinder …) |
| `#kolla-ansible` | Kolla-Ansible 배포 도구 |
| `#devstack` | DevStack 개발용 올인원 설치 |
| `#proxmox` | Proxmox VE 하이퍼바이저 |
| `#ovn-ovs` | OVN / OVS / SDN 데이터플레인 · 오버레이(VXLAN·Geneve) · Linux Bridge |
| `#docker` | 컨테이너 런타임 및 Compose 구성 |
| `#tailscale` | Tailscale·VPN 기반 원격 접속 |

## 축 B — 주제 영역 (6개)

기술 스택과 무관하게 어떤 문제 영역인가.

| 태그 | 범위 |
|---|---|
| `#networking` | L2/L3, 라우팅, 스위칭, IP 할당, 방화벽 경로, 네트워크 진단 |
| `#compute` | 하이퍼바이저, VM 스케줄링, GPU 패스스루, 인스턴스 관리 |
| `#storage` | Ceph, 볼륨, 이미지 저장소, 백업 |
| `#ha` | 고가용성 — 클러스터, 쿼럼, Galera, VIP, HAProxy, 페일오버 |
| `#security` | 인증·인가, Security Group, 방화벽 정책, 접근 제어 |
| `#deployment` | 설치·배포·IaC·자동화 절차 그 자체 |

## 축 C — 환경 (4개)

**이 위키에서 변별력이 가장 높은 축이다.** "개발계 얘기냐 학내망 얘기냐"가
실제로 문서를 찾을 때 쓰는 기준이므로 웬만하면 하나는 붙인다.

| 태그 | 범위 |
|---|---|
| `#campus-network` | 학내망 — 학교 네트워크 인프라, 대역, 방화벽 정책 |
| `#devpc` | 개발계 — Gaming5 베어메탈 AIO 환경 |
| `#production` | 운영계 — 7-node HA 클러스터 (목표 구성 포함) |
| `#prestudy` | 사전학습·개인 실습 환경 |

## 축 D — 문서 성격 (6개)

`type`으로 표현되지 않는 문서의 성격.

| 태그 | 범위 |
|---|---|
| `#troubleshooting` | 장애·오류의 원인 규명과 해결 |
| `#runbook` | 장애 발생 시 그대로 따라 하는 대응 절차 |
| `#feedback` | 교수님·멘토로부터 받은 피드백과 지적 사항 |
| `#wiki-ops` | 이 위키 시스템 자체의 설계·운영 |
| `#roadmap` | 계획, 일정, 목표, 진행 현황 |
| `#infra-inventory` | 보유 장비·서버·네트워크 자산 현황 |

---

## 폐기된 태그 매핑

기존 태그를 새 어휘로 옮긴 대응표. 위키에 옛 태그가 남아 있으면 이 표대로
고친다.

### 구조 중복 — `type`/폴더가 이미 표현하므로 전량 삭제

`#guide` `#meeting` `#decision` `#concept` `#qna` `#people` `#index`
`#template`

### 무변별 — 삭제

`#su-cloud` (전체 문서의 절반에 붙어 있어 필터 기능 없음)

### 흡수 통합

| 옛 태그 | → 새 태그 |
|---|---|
| `#ovn` `#ovs` `#sdn` `#vxlan` `#geneve` `#overlay-network` `#linux-bridge` | `#ovn-ovs` |
| `#neutron` `#floating-ip` `#vlan` `#traceroute` `#nginx` `#firewall` | `#networking` |
| `#nova` `#hypervisor` `#gpu` `#passthrough` `#vllm` | `#compute` |
| `#ceph` | `#storage` |
| `#security-group` | `#security` |
| `#haproxy` `#mariadb` `#rabbitmq` | `#ha` |
| `#installation` `#manual-install` `#iac` `#pipeline` | `#deployment` |
| `#infra` `#infrastructure` `#inventory` `#pilot` | `#infra-inventory` |
| `#campus` | `#campus-network` |
| `#project` `#vision` `#status` `#architecture` | `#roadmap` |
| `#wiki` `#obsidian` `#okf` `#knowledge-management` | `#wiki-ops` |
| `#vpn` | `#tailscale` |
| `#career` `#kickoff` `#cloud-engineering` | 삭제 (본문으로 충분) |

### 본문 검색으로 대체 — 삭제

버전명·제품명은 태그로 만들지 않는다.

`#antelope` `#flamingo` `#ubuntu` `#python` `#kafka` `#octavia` `#vllm`

---

## 어휘를 늘려야 할 때

새 태그가 필요하다고 느끼면 먼저 자문한다:

- **이 태그가 붙을 문서가 앞으로 3개 이상 생기는가?** 아니면 만들지 않는다.
- **기존 23개 중 어느 것으로도 안 잡히는가?** 대개는 잡힌다.
- **문서를 "묶는" 태그인가, 문서를 "설명하는" 태그인가?** 후자면 본문에 쓴다.

세 질문을 통과하면 이 파일에 추가하고 어느 축에 속하는지 명시한다.
어휘 변경은 이 파일이 유일한 기준점이므로, 여기에 적지 않은 태그를
문서에 쓰지 않는다.
