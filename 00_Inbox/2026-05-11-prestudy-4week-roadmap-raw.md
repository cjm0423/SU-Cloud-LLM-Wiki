---
title: "OpenStack 4주 사전학습 로드맵 및 액션 플랜"
type: "raw"
date: 2026-05-11
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/Prestudy-4Week-Roadmap]]"
---
# 🗓️ OpenStack 4주 사전학습 로드맵 및 액션 플랜

### 1주차: OpenStack 기본기 및 큰 그림 그리기 (05/11 ~ 05/17)

- **학습 목표:** IaaS 생태계 내에서 OpenStack의 포지셔닝 이해, 핵심 컴포넌트(Keystone, Nova, Neutron 등) 역할 정의.
- **Action Item:**
    - Google Drive의 `openstack_이론 교안.pdf` 정독.
    - 평소 관심 있던 클라우드 네이티브 아키텍처나 쿠버네티스(Kubernetes) 환경과 OpenStack(IaaS)이 어떻게 다르고 또 어떻게 연결될 수 있는지 비교하며 읽어보기.
    - **리드 역할:** 단톡방에 금요일 저녁 또는 일요일 오전 중 첫 리뷰 회의 일정 픽스하기.

### 2주차: DevStack 실습 환경 구축 (05/18 ~ 05/24)

- **학습 목표:** 로컬 환경에 VirtualBox 및 Ubuntu 22.04 LTS 세팅, `local.conf` 구조 파악.
- **Action Item:**
    - GitHub DevStack Lab 리포지토리 확인 및 YouTube ① 시청.
    - VM 자원 할당 및 네트워크 설정 진행.
    - 본격적인 설치 전, 과정 중 발생하는 모든 에러 메시지를 캡처하고 정리하는 습관 들이기.

### 3주차: DevStack 설치 및 CLI/UI 검증 (05/25 ~ 05/31)

- **학습 목표:** `./stack.sh` 스크립트 실행, Horizon 대시보드 접속 및 CLI 쿼리 테스트.
- **Action Item:**
    - 설치 스크립트 실행 후 로그 모니터링. 실패하더라도 멈춘 지점과 마지막 로그 10줄 스크랩.
    - OpenStack CLI 및 `virsh` 명령어를 통한 인스턴스/리소스 조회 시도.
    - **제출 꿀팁:** 완벽한 성공보다 '어디서 왜 막혔는지' 상세히 기록하는 것에 집중하기.

### 4주차: 네트워크 심화 및 킥오프 준비 (06/01 ~ 06/07)

- **학습 목표:** OpenStack 내부 네트워크 흐름(Floating IP, Security Group 등) 이해 및 인프라 MVP 질문 도출.
- **Action Item:**
    - L2/L3, 라우팅 테이블, DHCP 등 기본 네트워크 개념을 OpenStack Neutron에 대입해보기.
    - 오프라인 킥오프 때 멘토님과 논의할 **핵심 질문 3가지** 및 **인프라 MVP 확인사항** 최종 정리.