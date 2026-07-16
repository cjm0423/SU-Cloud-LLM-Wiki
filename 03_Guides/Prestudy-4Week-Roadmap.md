---
title: "OpenStack 4주 사전학습 로드맵 및 액션 플랜"
type: "guide"
date: 2026-05-11
tags: ["#guide", "#prestudy", "#openstack"]
related_nodes: ["[[01_Concepts/OpenStack-Overview]]", "[[03_Guides/DevStack-Installation-Guide]]", "[[02_QnA_Archive/2026-05-17-prestudy-feedback-1]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-05-11-prestudy-4week-roadmap-raw]]"
---

# OpenStack 4주 사전학습 로드맵 및 액션 플랜

## 개요

SU Cloud 프로젝트 킥오프 전 멘티들이 수행한 4주 사전학습 계획. 이론 → 실습 → 심화 → 네트워크 순서로 진행.

---

## 1주차 (05/11 ~ 05/17): OpenStack 기본기 및 큰 그림 그리기

**학습 목표:** IaaS 생태계 내에서 OpenStack의 포지셔닝 이해, 핵심 컴포넌트 역할 정의

**액션 아이템:**
- Google Drive의 `openstack_이론 교안.pdf` 정독
- Kubernetes(컨테이너 오케스트레이션)와 OpenStack(IaaS)의 차이 및 연결 방식 비교 학습
- 리드 역할: 단톡방에 금요일 저녁/일요일 오전 중 리뷰 회의 일정 확정

**핵심 키워드:** IaaS, Keystone, Nova, Neutron, Glance, Cinder, Swift, Horizon

---

## 2주차 (05/18 ~ 05/24): DevStack 실습 환경 구축

**학습 목표:** 로컬 환경에 VirtualBox + Ubuntu 22.04 LTS 세팅, `local.conf` 구조 파악

**액션 아이템:**
- GitHub DevStack Lab 리포지토리 확인 및 관련 영상 시청
- VM 자원 할당 및 네트워크 설정
- 설치 중 발생하는 모든 에러 메시지를 캡처하고 정리하는 습관 들이기

**참고:** 의존성 충돌 시 **2023.1 버전으로 고정** → [[03_Guides/DevStack-Installation-Guide]]

---

## 3주차 (05/25 ~ 05/31): DevStack 설치 및 CLI/UI 검증

**학습 목표:** `./stack.sh` 스크립트 실행, Horizon 대시보드 접속 및 CLI 쿼리 테스트

**액션 아이템:**
- 설치 스크립트 실행 후 로그 모니터링 (실패해도 막힌 지점과 마지막 로그 10줄 스크랩)
- OpenStack CLI 및 `virsh` 명령어로 인스턴스/리소스 조회
- **제출 꿀팁:** 완벽한 성공보다 "어디서 왜 막혔는지" 상세히 기록

---

## 4주차 (06/01 ~ 06/07): 네트워크 심화 및 킥오프 준비

**학습 목표:** OpenStack 내부 네트워크 흐름(Floating IP, Security Group) 이해 및 인프라 MVP 질문 도출

**액션 아이템:**
- L2/L3, 라우팅 테이블, DHCP 기본 네트워크 개념을 Neutron에 대입
- 오프라인 킥오프 때 멘토님과 논의할 **핵심 질문 3가지** 및 **인프라 MVP 확인사항** 최종 정리

---

## 관련 문서

- [[01_Concepts/OpenStack-Overview]]
- [[03_Guides/DevStack-Installation-Guide]]
- [[02_QnA_Archive/2026-05-17-prestudy-feedback-1]]
- [[02_QnA_Archive/2026-05-24-prestudy-feedback-2]]
