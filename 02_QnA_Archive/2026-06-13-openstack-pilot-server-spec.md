---
title: "OpenStack 파일럿 서버 사양 및 환경 확인"
type: "qa"
date: 2026-06-13
tags: ["#openstack", "#infra", "#pilot"]
related_nodes: ["[[04_Meetings/2026-06-13-kickoff]]", "[[01_Concepts/SU-Cloud-Project-Overview]]", "[[01_Concepts/Proxmox]]"]
author: "AI Assistant"
status: "resolved"
raw_source: "[[00_Inbox/2026-06-13-openstack-pilot-raw]]"
---

# OpenStack 파일럿 서버 사양 및 환경 확인

## 1. ❓ 질의 및 배경 (Context)

- **상황:** 킥오프 이후 실제 운영 가능한 서버 사양, 위치, 네트워크 환경 파악 필요
- **핵심 질문:** 서버가 몇 대인지, 사양은 어떤지, 어디에 두고, 네트워크는 어떻게 구성할 수 있는지

## 2. 🧠 분석 및 추론 (Analysis)

### 서버 현황 확인 결과

| 서버 | 모델 | 역할 |
|------|------|------|
| 운영계 | **Lenovo ThinkStation P520** 1대 | 운영계 OpenStack |
| 개발계 | **Lenovo IdeaCentre Gaming5 17ACN7** 1대 | 개발계 / 보조 인프라 |

### 환경 질문 및 답변

| 항목 | 내용 |
|------|------|
| 서버 위치 | 조교실 405호 뒤쪽 (김재현이 파악) |
| 네트워크 구성 파악 | 전산실에 문의 남겨둠 |
| VLAN / 10GbE 가능 여부 | 필요 시 별도 스위치 구매해서 구성 가능 |
| Public IP / Floating IP | 1~2개 가능 확인 |

## 3. 💡 해결책 및 결과 (Solution)

- P520을 운영계 OpenStack, Gaming5를 개발계로 역할 분리
- 서버는 405호 조교실에 위치
- Public IP 1~2개 확보 가능 (전산실 협의)
- 추가 스위치 구매로 VLAN / 10GbE 구성 검토

## 4. 🔗 추가 통찰 (Insights & Next Steps)

- Tailscale 기반 원격 접근으로 초기 외부 접속 문제 해소
- Phase 0 완료 후 학교 네트워크 파악(VLAN 가능 여부, Public IP 할당 방식) 전산실 협의 필요
- 관련: [[04_Meetings/2026-06-13-kickoff]]
