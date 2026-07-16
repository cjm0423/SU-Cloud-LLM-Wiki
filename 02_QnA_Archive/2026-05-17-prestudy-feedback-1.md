---
title: "사전학습 1차 피드백 — 네트워크 기초·이중 가상화·쿼럼"
type: "qa"
date: 2026-05-17
tags: ["#openstack", "#networking", "#prestudy", "#feedback"]
related_nodes: ["[[02_QnA_Archive/2026-05-24-prestudy-feedback-2]]", "[[01_Concepts/OpenStack-Overview]]", "[[01_Concepts/Provider-vs-SelfService-Network]]"]
author: "AI Assistant"
status: "resolved"
raw_source: "[[00_Inbox/2026-05-17-feedback-0517-raw]]"
---

# 사전학습 1차 피드백 — 네트워크 기초·이중 가상화·쿼럼

## 1. ❓ 질의 및 배경 (Context)

- **상황:** 멘티들이 DevStack 기반으로 OpenStack 사전학습 1주차를 완료한 후 조충희 교수님의 피드백 세션
- **핵심 질문:**
  1. NAT 네트워크와 Host-only 네트워크의 차이는?
  2. VirtualBox에서 이중 가상화(PC OS → VirtualBox → Ubuntu → KVM → OpenStack 인스턴스)가 왜 필요한가?
  3. OpenStack Controller를 2대가 아닌 3대로 구성하는 이유는?

## 2. 🧠 분석 및 추론 (Analysis)

### VirtualBox 네트워크 모드
- **NAT**: 게스트가 호스트 IP를 공유해 외부 인터넷 접근, 외부에서 게스트로 직접 접근 불가
- **Host-only**: 호스트-게스트 간 격리된 전용 네트워크, 외부 인터넷 접근 없음
- **Bridge**: 게스트가 물리 네트워크에 직접 연결, 별도 IP 할당

### 이중 가상화의 이유
- OpenStack은 Linux 전용 → Windows 환경에서는 VirtualBox로 VM 생성 불가피
- 실습에서는 `PC OS → VirtualBox(Ubuntu) → KVM → OpenStack VM` 구조 사용
- **가상화는 안 거칠수록 좋다** (오버헤드 증가) → 실제 운영은 baremetal에 Ubuntu 직접 설치
- 이중 가상화는 "학습 목적의 어쩔 수 없는 구조"

### Controller 3대 구성 (쿼럼)
- Controller가 죽으면 Nova scheduler 등 모든 API가 멈춰 compute 노드들이 동작 불가
- **쿼럼**: 분산 시스템에서 의사 결정에 필요한 최소 과반수 노드 수
- 2대 → 한 대 장애 시 과반수(1/2) 불성립, split-brain 발생
- **3대 → 한 대 장애 시 2/3 과반수 성립**, 정상 운영 가능
- 홀수 구성이 쿼럼 유지에 유리 → 3대 이상 홀수

### OpenStack 네트워크 계층
- 사용자 전용 네트워크 / 관리자 네트워크 / 노드 간 네트워크 / 스토리지 네트워크 분리
- Provider network (물리 할당) vs Self-service network (논리 할당, tenant가 직접 구성)

## 3. 💡 해결책 및 결과 (Solution)

- VirtualBox로 실습 환경 구성 시 NAT + Host-only 혼합 사용 → 인터넷 접근 + 노드 간 통신
- 실습은 이중 가상화 수용, 실제 운영은 baremetal Ubuntu에 OpenStack 직접 설치
- Controller 노드 3대 홀수 구성으로 쿼럼 보장 (Kolla-Ansible 기본값)
- VirtualBox 안에서 IP로 노드 간 연결 → 네트워크 실습 가능

## 4. 🔗 추가 통찰 (Insights & Next Steps)

- 가상화 스택이 깊을수록 성능 오버헤드 증가 → 실제 프로덕션에서는 baremetal 권장
- Kafo24(카페24) 사례: OpenStack 기반 클라우드 서비스 운영 중
- 공식 문서 참고: https://docs.openstack.org/ko_KR/install-guide/get-started-conceptual-architecture.html
- 다음 단계: DevStack 환경 구성 후 Static NAT, VLAN, Bridge 개념 직접 실습
