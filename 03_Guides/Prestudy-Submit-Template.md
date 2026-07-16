---
title: "사전학습 제출 템플릿 및 1~3주차 제출 기록"
type: "guide"
date: 2026-05-11
tags: ["#guide", "#prestudy", "#template"]
related_nodes: ["[[03_Guides/Prestudy-4Week-Roadmap]]", "[[01_Concepts/OpenStack-Overview]]", "[[03_Guides/DevStack-Installation-Guide]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-05-11-prestudy-submit-template-raw]]"
---

# 사전학습 제출 템플릿 및 1~3주차 제출 기록

## 제출 템플릿

매주 리뷰 회의 전 리드가 먼저 작성하고 팀원들이 참고.

```markdown
[OpenStack 사전학습 N주차]

1. 이번 주 학습 주제: (무엇을 공부했는지)
2. 직접 해본 것 / 캡처 / 링크 1개: (증거 첨부)
3. 핵심 정리 3줄:
   - 
   - 
   - 
4. 막힌 점 또는 질문 1~2개: (모르는 것, 궁금한 것)
5. 상태: 완료 / 막힘 / 진행중
```

### 막혔을 때 추가 양식

```markdown
[막힌 경우]
1. 어느 단계에서 막혔는지:
2. 마지막으로 실행한 명령:
3. 에러 메시지 핵심 10줄:
4. 이미 시도해본 것:
5. 현재 상태:
```

---

## 1주차 제출 기록 (차지만)

**학습 주제:** OpenStack 핵심 컴포넌트 역할 및 IaaS 개념 정리

**핵심 정리 3줄:**
- IaaS(Infrastructure as a Service) — 인프라를 제공해준다. OS, Middleware, Runtime, Data, App만 관리
- OpenStack이란? IaaS 클라우드 시스템을 구축하는 대표적인 오픈소스 소프트웨어
- 핵심 컴포넌트: Keystone(인증), Nova(컴퓨트), Neutron(네트워킹), Glance(이미지), Cinder(블록 스토리지), Swift(스토리지), Horizon(대시보드)

**막힌 점:** PC OS → VirtualBox → Ubuntu → KVM → OpenStack 인스턴스 이중 가상화를 하는 이유는?
→ 해답: [[02_QnA_Archive/2026-05-17-prestudy-feedback-1]]

**상태:** ✅ 완료

---

## 2주차 제출 기록 (차지만)

**학습 주제:** DevStack 환경 준비 및 버전/의존성 트러블슈팅

**핵심 정리 3줄:**
- 실습 환경: VirtualBox로 Ubuntu 22.04 VM 생성, DevStack 구동에 필요한 자원과 NAT 네트워크 구성
- DevStack 설치: stack 계정 생성 후 `local.conf`로 최소 필수 환경 정의 → `./stack.sh` 설치
- 트러블슈팅: Python/컴포넌트 버전 충돌 → 검증된 2023.1 버전으로 해결, Horizon 대시보드 접속 확인

**막힌 점:** 수많은 컴포넌트의 버전과 의존성을 안정적으로 관리하는 전략?
→ 해답: [[02_QnA_Archive/2026-05-24-prestudy-feedback-2]]

**상태:** ✅ 완료 (트러블슈팅 포함)

---

## 3주차 제출 기록 (차지만)

**학습 주제:** OpenStack 기본 컴포넌트 설치 및 카카오 클라우드 3-tier 파이프라인 Docker Compose 재구성

**핵심 정리 3줄:**
- **서비스명 = DNS** — docker-compose.yaml의 서비스명이 Docker 내장 DNS로 동작해 컨테이너끼리 IP 없이 통신
- **공유 볼륨 패턴** — nginx_logs 볼륨을 nginx(쓰기)와 filebeat(읽기 전용)에 동시 마운트. Sidecar 패턴의 가장 단순한 형태
- **준비 동기화** — `healthcheck` + `depends_on: service_healthy`로 "실제 요청 받을 준비 완료" 보장

**막힌 점:** PaaS에게 맡길 것 vs 직접 운영할 것을 가르는 기준?

**상태:** ✅ 완료

---

## 관련 문서

- [[03_Guides/Prestudy-4Week-Roadmap]]
- [[03_Guides/DevStack-Installation-Guide]]
- [[03_Guides/Prestudy-Shopping-Pipeline-Week3]]
- [[02_QnA_Archive/2026-05-17-prestudy-feedback-1]]
- [[02_QnA_Archive/2026-05-24-prestudy-feedback-2]]
