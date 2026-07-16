---
title: "사전학습 2차 피드백 — 버전 의존성 관리·Ceph·CSP 커스터마이제이션"
type: "qa"
date: 2026-05-24
tags: ["#openstack", "#devstack", "#prestudy", "#feedback"]
related_nodes: ["[[02_QnA_Archive/2026-05-17-prestudy-feedback-1]]", "[[01_Concepts/OpenStack-Overview]]", "[[03_Guides/DevStack-Installation-Guide]]"]
author: "AI Assistant"
status: "resolved"
raw_source: "[[00_Inbox/2026-05-24-feedback-0524-raw]]"
---

# 사전학습 2차 피드백 — 버전 의존성 관리·Ceph·CSP 커스터마이제이션

## 1. ❓ 질의 및 배경 (Context)

- **상황:** DevStack 2주차 실습 완료 후 교수님 피드백 세션. OS·Python·패키지 버전 충돌로 2023.1 버전으로 낮춰 설치 성공
- **핵심 질문:** OpenStack처럼 수많은 컴포넌트가 맞물리는 시스템에서 버전과 의존성을 안정적으로 관리하는 전략은?

## 2. 🧠 분석 및 추론 (Analysis)

### OpenStack 버전 관리 현실
- OpenStack 업데이트 주기: **6개월**
- 릴리즈마다 컴포넌트 간 의존성이 바뀌어 최신 버전 바로 사용 시 충돌 빈번

### CSP(클라우드 서비스 제공자)의 접근 방식
- CSP는 OpenStack 릴리즈 버전을 **즉시 따르지 않음**
- 자체 인프라 환경에 맞게 컴포넌트를 **커스텀·수정**해서 사용
- 예: Kubernetes 프로비저닝 컴포넌트도 자체적으로 커스터마이징
- **컴포넌트별로 독립적으로 커스텀해서 사용하는 것이 일반적**

### VirtualBox NAT 이해
- VirtualBox NAT가 NAT 개념을 가장 직관적으로 이해하기 좋은 환경

## 3. 💡 해결책 및 결과 (Solution)

- **Stable 브랜치 고정**: 특정 릴리즈(예: 2023.1 Antelope) 브랜치를 명시적으로 고정해 설치
- **컨테이너화(Kolla)**: 컨테이너 단위로 컴포넌트를 격리해 의존성 충돌 최소화
- **릴리즈 노트 추적**: 각 릴리즈의 EOL 일정 사전 파악 필수
- **실습 사진 + AI 학습**: 실습 캡처본을 AI에 질의하며 개념 보강 권장

## 4. 🔗 추가 통찰 (Insights & Next Steps)

- Ceph: 분산 스토리지 시스템, OpenStack의 백엔드 스토리지로 자주 활용 (Cinder/Glance 연동)
- 학습 방향: 실습 사진을 AI에 넣고 Q&A 형태로 심화 학습 진행
- 다음 단계: Kolla-Ansible 기반 배포로 의존성 충돌 회피 전략 실습
