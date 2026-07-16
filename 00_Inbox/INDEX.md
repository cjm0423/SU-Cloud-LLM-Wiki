---
title: "Inbox 인덱스"
type: "index"
date: 2026-07-16
tags: ["#index", "#inbox"]
---

# 00_Inbox

**원본을 가공 없이 던져놓는 곳.** 여기서는 절대 정리하려고 하지 마세요 —
"일단 저장, 정리는 나중에"가 이 폴더의 유일한 규칙입니다.

## 왜 필요한가

`02_QnA_Archive`, `04_Meetings`에 쌓이는 문서는 전부 **AI가 요약/가공한 결과물**입니다.
가공 과정에서 뉘앙스가 빠지거나 잘못 요약될 수 있는데, 원본이 없으면 나중에
"그때 정확히 뭐라고 했지?"를 검증할 방법이 없습니다. Inbox는 그 원본을 보존하는 계층입니다.

```
회의/채팅 종료
    → 원본을 가공 없이 00_Inbox에 저장 (raw)
        → 시간 날 때 AI에게 "이 inbox 파일을 위키로 추출해줘"
            → 02_QnA_Archive 또는 04_Meetings로 승격 (promoted)
                → 승격된 문서에 raw_source로 원본 역참조
```

## 저장 규칙

- **파일명:** `YYYY-MM-DD-keyword-raw.md`
- **내용:** STT 전사, 채팅 로그 캡처, 회의 노트 스크린샷 텍스트 등 원본 그대로.
  다듬지 않아도 됩니다. 오탈자, 반복, 잡담 다 괜찮습니다.
- **템플릿:** [[99_Templates/OKF-Raw-Template]] (매우 가벼운 포맷 — 형식 갖추느라 시간 쓰지 말 것)

## 승격(Promote) 규칙

- 원본을 정식 위키 문서로 변환했으면, **원본을 지우지 마세요.** frontmatter의
  `status`를 `raw` → `promoted`로 바꾸기만 하면 됩니다.
- 승격된 정식 문서 쪽에는 아래처럼 원본 역참조를 남겨주세요:
  ```yaml
  raw_source: "[[00_Inbox/2026-06-13-kickoff-raw]]"
  ```
- 이렇게 하면 정식 문서에서 원본으로, 원본에서도 어떤 문서로 승격됐는지 양방향 추적이 가능합니다.

## 미승격 원본 확인 (Dataview)

아직 정식 위키로 추출되지 않은 원본만 골라 보여줍니다. 방치되고 있는 원본을 찾을 때 씁니다.

~~~
```dataview
TABLE date, tags
FROM "00_Inbox"
WHERE status = "raw"
SORT date ASC
```
~~~

## 전체 Inbox 목록

~~~
```dataview
TABLE date, status, tags
FROM "00_Inbox"
SORT date DESC
```
~~~

| 날짜 | 원본 | 상태 | 승격된 문서 |
|------|------|------|------|
| 2026-05-11 | [[00_Inbox/2026-05-11-openstack-components-week1-raw\|OpenStack & Components - 1 week]] | raw | |
| 2026-05-11 | [[00_Inbox/2026-05-11-openstack-study-index-raw\|오픈스택 모음 인덱스]] | raw | |
| 2026-05-11 | [[00_Inbox/2026-05-11-prestudy-4week-roadmap-raw\|OpenStack 4주 사전학습 로드맵]] | raw | |
| 2026-05-11 | [[00_Inbox/2026-05-11-prestudy-content-index-raw\|사전학습 인덱스]] | raw | |
| 2026-05-11 | [[00_Inbox/2026-05-11-prestudy-index-raw\|사전학습 정리 인덱스]] | raw | |
| 2026-05-11 | [[00_Inbox/2026-05-11-prestudy-submit-template-raw\|사전학습 제출 템플릿]] | raw | |
| 2026-05-11 | [[00_Inbox/2026-05-11-prestudy-week1-raw\|사전학습 1주차 (05/11~05/17)]] | raw | |
| 2026-05-17 | [[00_Inbox/2026-05-17-feedback-0517-raw\|0517 피드백]] | raw | |
| 2026-05-17 | [[00_Inbox/2026-05-17-feedback-index-raw\|피드백 인덱스]] | raw | |
| 2026-05-18 | [[00_Inbox/2026-05-18-devstack-openstack-week2-raw\|Devstack 실습 & Openstack 공부 - 2 week]] | raw | |
| 2026-05-18 | [[00_Inbox/2026-05-18-prestudy-devstack-week2-raw\|사전학습 2주차 (DevStack 환경 구성)]] | raw | |
| 2026-05-24 | [[00_Inbox/2026-05-24-devstack-deploy-task-raw\|DevStack 이후 앱 배포 과제 계획]] | raw | |
| 2026-05-24 | [[00_Inbox/2026-05-24-feedback-0524-raw\|0524 피드백]] | raw | |
| 2026-05-25 | [[00_Inbox/2026-05-25-openstack-study-week3-raw\|Openstack 공부2 - 3 week]] | raw | |
| 2026-05-25 | [[00_Inbox/2026-05-25-prestudy-shopping-pipeline-week3-raw\|사전학습 3주차 (쇼핑 파이프라인)]] | raw | |
| 2026-06-01 | [[00_Inbox/2026-06-01-june-schedule-index-raw\|6월 일정 인덱스]] | raw | |
| 2026-06-01 | [[00_Inbox/2026-06-01-openstack-project-description-raw\|오픈스택 프로젝트 설명]] | raw | |
| 2026-06-01 | [[00_Inbox/2026-06-01-project-roadmap-detail-raw\|SU-Cloud 2026 로드맵 상세]] | raw | |
| 2026-06-01 | [[00_Inbox/2026-06-01-project-roadmap-raw\|SU Cloud 프로젝트 로드맵 (6월~12월)]] | raw | |
| 2026-06-01 | [[00_Inbox/2026-06-01-su-cloud-project-index-raw\|SU-Cloud 프로젝트 인덱스]] | raw | |
| 2026-06-01 | [[00_Inbox/2026-06-01-weekly-schedule-index-raw\|주간 세부 일정 계획 인덱스]] | raw | |
| 2026-06-13 | [[00_Inbox/2026-06-13-meeting-kickoff-raw\|260613 킥오프 회의]] | raw | [[04_Meetings/2026-06-13-kickoff]] |
| 2026-06-13 | [[00_Inbox/2026-06-13-meeting-notes-index-raw\|회의록 인덱스]] | raw | |
| 2026-06-13 | [[00_Inbox/2026-06-13-openstack-pilot-raw\|OpenStack 파일럿]] | raw | |
| 2026-06-14 | [[00_Inbox/2026-06-14-doc-automation-raw\|문서 자동화 정리]] | raw | |
| 2026-06-14 | [[00_Inbox/2026-06-14-june-progress-index-raw\|6월 진행사항 인덱스]] | raw | |
| 2026-06-14 | [[00_Inbox/2026-06-14-openstack-manual-install-raw\|오픈스택 수동설치 구성]] | raw | |
| 2026-06-14 | [[00_Inbox/2026-06-14-openstack-network-flow-raw\|openstack 네트워크 흐름 분석]] | raw | |
| 2026-06-14 | [[00_Inbox/2026-06-14-ops-pc-network-setup-raw\|운영pc 실습 환경 네트워크 구성 정리]] | raw | |
| 2026-06-14 | [[00_Inbox/2026-06-14-progress-june-week3-index-raw\|6월 3주차 진행사항 인덱스]] | raw | |
| 2026-06-14 | [[00_Inbox/2026-06-14-proxmox-install-raw\|proxmox 설치방법]] | raw | |
| 2026-06-14 | [[00_Inbox/2026-06-14-tailscale-remote-raw\|tailscale 원격 접속 방법]] | raw | |
| 2026-06-14 | [[00_Inbox/2026-06-14-tailscale-setup-raw\|tailscale 구성 및 설정]] | raw | |
| 2026-06-15 | [[00_Inbox/2026-06-15-weekly-schedule-w3-raw\|[3주차] 6월 15일~21일 일정]] | raw | |
| 2026-06-21 | [[00_Inbox/2026-06-21-campus-network-runbook-raw\|SU Cloud 학내망 경로 추적 Runbook]] | raw | |
| 2026-06-21 | [[00_Inbox/2026-06-21-feedback-concepts-raw\|피드백 개념 정리]] | raw | |
| 2026-06-21 | [[00_Inbox/2026-06-21-kolla-ansible-intro-raw\|Kolla-Ansible이란]] | raw | |
| 2026-06-21 | [[00_Inbox/2026-06-21-kolla-install-roadmap-raw\|Kolla Ansible 설치 로드맵]] | raw | |
| 2026-06-21 | [[00_Inbox/2026-06-21-kolla-practice-guide-raw\|Kolla-Ansible 실습 해설]] | raw | |
| 2026-06-21 | [[00_Inbox/2026-06-21-meeting-weekly-raw\|260621 주간 회의]] | raw | |
| 2026-06-21 | [[00_Inbox/2026-06-21-network-path-diagnosis-raw\|네트워크 경로 진단 — 명령어 & 개념 정리]] | raw | |
| 2026-06-21 | [[00_Inbox/2026-06-21-ovn-flow-details-raw\|OVN 네트워크 흐름 확인 세부 내용]] | raw | |
| 2026-06-21 | [[00_Inbox/2026-06-21-ovn-network-flow-raw\|OVN 네트워크 흐름 확인 (Kolla Ansible)]] | raw | |
| 2026-06-21 | [[00_Inbox/2026-06-21-progress-june-week4-index-raw\|6월 4주차 진행사항 인덱스]] | raw | |
| 2026-06-21 | [[00_Inbox/2026-06-21-sdn-ovs-ovn-vxlan-raw\|SDN · LinuxBridge · OVS · OVN · VXLAN/Geneve]] | raw | |
| 2026-06-22 | [[00_Inbox/2026-06-22-weekly-schedule-w4-raw\|[4주차] 6월 22일~28일 일정]] | raw | |
| 2026-06-28 | [[00_Inbox/2026-06-28-campus-network-draft-raw\|SU Cloud 캠퍼스 네트워크 구조 초안]] | raw | |
| 2026-06-28 | [[00_Inbox/2026-06-28-kolla-deploy-troubleshoot-raw\|Kolla-Ansible 배포 트러블슈팅 로그]] | raw | |
| 2026-06-28 | [[00_Inbox/2026-06-28-meeting-weekly-raw\|260628 주간 회의]] | raw | [[04_Meetings/2026-06-13-kickoff]] |
| 2026-06-28 | [[00_Inbox/2026-06-28-ovn-diagram-raw\|OVN 다이어그램]] | raw | |
| 2026-06-28 | [[00_Inbox/2026-06-28-ovn-ovs-final-raw\|OVN OVS 최종정리]] | raw | |
| 2026-06-28 | [[00_Inbox/2026-06-28-p520-gpu-vllm-passthrough-raw\|P520 GPU VLLM 패스스루 가이드]] | raw | |
| 2026-06-28 | [[00_Inbox/2026-06-28-progress-july-week1-index-raw\|7월 1주차 진행사항 인덱스]] | raw | |
| 2026-07-01 | [[00_Inbox/2026-07-01-july-progress-index-raw\|7월 진행사항 인덱스]] | raw | |
| 2026-07-01 | [[00_Inbox/2026-07-01-july-schedule-raw\|7월 일정]] | raw | |
| 2026-07-04 | [[00_Inbox/2026-07-04-campus-network-analysis-raw\|0704 학교망 네트워크 구조 파악]] | raw | |
| 2026-07-05 | [[00_Inbox/2026-07-05-devpc-internet-outage-raw\|개발계(180) 인터넷 불가 — 런북]] | raw | |
| 2026-07-05 | [[00_Inbox/2026-07-05-devpc-kolla-setup-raw\|개발계 pc(gaming 5) Kolla-Ansible 구성]] | raw | |
| 2026-07-05 | [[00_Inbox/2026-07-05-devpc-network-failure-raw\|개발계(180) 네트워크 장애 — 조치 기록]] | raw | |
| 2026-07-05 | [[00_Inbox/2026-07-05-devpc-nginx-raw\|개발계 외부 접속 확인 (NGINX)]] | raw | |
| 2026-07-05 | [[00_Inbox/2026-07-05-devpc-tailscale-raw\|개발계(baremetal ubuntu) tailscale 구성]] | raw | |
| 2026-07-05 | [[00_Inbox/2026-07-05-progress-july-week2-index-raw\|7월 2주차 진행사항 인덱스]] | raw | |
| 2026-07-12 | [[00_Inbox/2026-07-12-doc-automation-existing-raw\|문서 자동화 정리 기존]] | raw | |
| 2026-07-12 | [[00_Inbox/2026-07-12-doc-automation-harness-raw\|문서 자동화 - 하네스 엔지니어링]] | raw | |
| 2026-07-12 | [[00_Inbox/2026-07-12-meeting-weekly-raw\|260712 주간 회의]] | raw | |
| 2026-07-12 | [[00_Inbox/2026-07-12-progress-july-week3-index-raw\|7월 3주차 진행사항 인덱스]] | raw | |
| 2026-07-12 | [[00_Inbox/2026-07-12-wiki-index-raw\|위키 인덱스]] | raw | |
| 2026-07-12 | [[00_Inbox/2026-07-12-wiki-usage-guide-raw\|SU-Cloud-LLM-Wiki 사용가이드]] | raw | |
| 2026-07-15 | [[00_Inbox/2026-07-15-meeting-wiki-raw\|260715 위키 회의]] | raw | |
| 2026-07-16 | [[00_Inbox/2026-07-16-jeonbuk-openstack-index-raw\|전북대 openstack 정리 인덱스]] | raw | |
| 2026-07-16 | [[00_Inbox/2026-07-16-jeonbuk-openstack-study-raw\|오픈스택 클라우드 구축 학습]] | raw | |
