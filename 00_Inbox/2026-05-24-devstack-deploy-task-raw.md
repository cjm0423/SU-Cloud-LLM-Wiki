---
title: "DevStack 이후 앱 배포 과제 계획 및 공지"
type: "raw"
date: 2026-05-24
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/DevStack-App-Deploy-Task]]"
---
# 🚀 DevStack 이후 앱 배포 과제 계획 및 공지

> 📅 **작성일**: 2026-05-24
> 
> 
> 🏷️ **상태**: 예고 → 진행 예정
> 
> 🎯 **관련 세션**: 2026-05-24 DevStack 점검 세션
> 
> 👥 **대상**: 멘티 / 학생
> 
> 🔗 **선행 과제**: DevStack 설치, Horizon 접속, VM 생성, Floating IP 연결
> 

---

## 📌 목차

1. [목적](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%EB%AA%A9%EC%A0%81)
2. [배경](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%EB%B0%B0%EA%B2%BD)
3. [운영 판단](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%EC%9A%B4%EC%98%81-%ED%8C%90%EB%8B%A8)
4. [권장 투입 시점](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%EA%B6%8C%EC%9E%A5-%ED%88%AC%EC%9E%85-%EC%8B%9C%EC%A0%90)
5. [커리큘럼 연결](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%EC%BB%A4%EB%A6%AC%ED%81%98%EB%9F%BC-%EC%97%B0%EA%B2%B0)
6. [이번 후속 과제의 범위](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%EC%9D%B4%EB%B2%88-%ED%9B%84%EC%86%8D-%EA%B3%BC%EC%A0%9C%EC%9D%98-%EB%B2%94%EC%9C%84)
7. [권장 실습 구성](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%EA%B6%8C%EC%9E%A5-%EC%8B%A4%EC%8A%B5-%EA%B5%AC%EC%84%B1)
8. [운영자 준비사항](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%EC%9A%B4%EC%98%81%EC%9E%90-%EC%A4%80%EB%B9%84%EC%82%AC%ED%95%AD)
9. [과제 완료 기준 및 제출 산출물](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%EA%B3%BC%EC%A0%9C-%EC%99%84%EB%A3%8C-%EA%B8%B0%EC%A4%80-%EB%B0%8F-%EC%A0%9C%EC%B6%9C-%EC%82%B0%EC%B6%9C%EB%AC%BC)
10. [학생 과제 안내문 (KakaoTalk 공유용)](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%ED%95%99%EC%83%9D-%EA%B3%BC%EC%A0%9C-%EC%95%88%EB%82%B4%EB%AC%B8-kakaotalk-%EA%B3%B5%EC%9C%A0%EC%9A%A9)
11. [학생 제출 템플릿](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%ED%95%99%EC%83%9D-%EC%A0%9C%EC%B6%9C-%ED%85%9C%ED%94%8C%EB%A6%BF)
12. [리뷰 회의 질문](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%EB%A6%AC%EB%B7%B0-%ED%9A%8C%EC%9D%98-%EC%A7%88%EB%AC%B8)
13. [후속 확장안](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%ED%9B%84%EC%86%8D-%ED%99%95%EC%9E%A5%EC%95%88)
14. [운영자 체크리스트](https://claude.ai/chat/23235e42-eadf-42ed-92dd-ad4c5fe218d0#-%EC%9A%B4%EC%98%81%EC%9E%90-%EC%B2%B4%ED%81%AC%EB%A6%AC%EC%8A%A4%ED%8A%B8)

---

## 🎯 목적

- DevStack 실습을 단순 설치 확인에서 끝내지 않고, OpenStack이 실제 애플리케이션 실행 환경을 제공하는 계층이라는 감각까지 연결한다.
- Docker, 3-tier Web/WAS/DB, MSA, Kubernetes 경험이 부족한 상태에서 바로 큰 과제를 내지 않고, **OpenStack VM 위에 작은 앱을 올리는 단계부터** 시작한다.
- 학생들이 **Floating IP, Security Group, VM, SSH, Docker 네트워크, 컨테이너 내부 통신을 하나의 요청 흐름**으로 설명할 수 있게 한다.

---

## 🧭 배경

- 2026-05-17 사전학습 미팅에서 학생들의 Docker, Kubernetes, Kubeflow, 3-tier 배포 경험을 확인했다.
- 일부 Kubeflow 실습과 Docker/PostgreSQL 경험은 있으나, **실제 애플리케이션을 배포하고 네트워크 흐름을 설명해 본 경험은 제한적**인 것으로 확인했다.
- 따라서 OpenStack 자체를 더 깊게 파기 전에, 다음 흐름을 한 번 경험하게 하는 것이 적절하다.

> 💡 **핵심 흐름**
> 
> 
> `OpenStack VM 생성` → `VM 접속` → `Docker Compose 앱 배포` → `외부 접속 확인`
> 

---

## ⚙️ 운영 판단

> ⚠️ **중요**: 이 과제는 DevStack 설치 과제와 **동시에 시작하지 않는다**.
> 
1. 먼저 DevStack 설치, Horizon 접속, 기본 네트워크 확인, VM 생성, Floating IP 연결, SSH 접속 흐름을 마무리한다.
2. 그 다음 단계로 "OpenStack VM 위에 실제 앱 배포하기" 과제를 낸다.
3. **Kubernetes와 MSA는 이 과제의 필수 범위에 넣지 않고**, 3-tier Docker Compose 배포가 확인된 뒤 후속 과제로 둔다.

---

## 📅 권장 투입 시점

| 시점 | 운영 판단 | 설명 |
| --- | --- | --- |
| 2026-05-24 세션 | 과제 예고 | DevStack 점검 후, 다음 단계가 앱 배포라는 방향만 공유 |
| DevStack 기본 실습 완료 직후 | 과제 시작 | 최소 기준: Horizon 접속, VM 생성, Floating IP/SSH 접속 시도까지 |
| 완료도가 낮은 경우 | 1주 연기 | DevStack 설치 자체가 다수 막혀 있으면 트러블슈팅 우선 |
| 완료도가 충분한 경우 | 다음 주 과제로 진행 | 완전 성공 여부와 무관하게 마지막 에러/진행 단계 남기면 제출 인정 |

---

## 🗺️ 커리큘럼 연결

```
OpenStack/DevStack 개념 확인
  ↓
DevStack 설치와 Horizon/CLI 확인
  ↓
OpenStack 네트워크, Security Group, Floating IP 이해
  ↓
OpenStack VM 위 Docker Compose 3-tier 앱 배포   ← 👈 이번 과제
  ↓
같은 앱을 Kubernetes로 이전
  ↓
작은 MSA 형태로 서비스 분리
  ↓
OpenStack Infrastructure MVP 설계로 연결
```

---

## 📦 이번 후속 과제의 범위

### ✅ 필수 범위

- [ ]  DevStack에서 Ubuntu 계열 VM 인스턴스 생성
- [ ]  Security Group에서 SSH와 HTTP 접근 허용
- [ ]  Floating IP 연결 또는 실습 환경에 맞는 경로로 VM SSH 접속
- [ ]  VM 안에 Docker와 Docker Compose 설치
- [ ]  Web/WAS/DB 3-tier 예제 앱을 Docker Compose로 실행
- [ ]  브라우저에서 앱 접속 확인
- [ ]  브라우저 요청 → OpenStack 네트워크 → VM → 컨테이너 → DB 흐름 설명

### ❌ 비범위

- Kubernetes 클러스터 구성
- Kubeflow 배포
- 여러 VM에 Web/WAS/DB 분산 배치
- 상용 수준 HA, 모니터링, CI/CD
- 앱 기능 개발 자체
- 복잡한 인증, 도메인, TLS 설정

---

## 🧪 권장 실습 구성

| 계층 | 권장 기술 | 이유 |
| --- | --- | --- |
| **Web** | Nginx 또는 간단한 React 정적 페이지 | 외부 HTTP 요청을 받는 지점을 명확히 볼 수 있음 |
| **WAS** | FastAPI, Express, Spring Boot 중 택1 | 학생들이 익숙한 언어 선택 가능 |
| **DB** | PostgreSQL | 기존 Docker/PostgreSQL 경험과 연결 쉬움 |
| **실행 방식** | Docker Compose | K8s로 넘어가기 전 컨테이너/네트워크 이해 적절 |
| **배포 위치** | OpenStack VM 1대 | 과제 난이도를 낮추고 실패 원인 감소 |

---

## 🛠️ 운영자 준비사항

> ⚠️ **이미지 주의**: 기본 CirrOS 이미지는 Docker 실습에 부적합. Ubuntu 계열 이미지를 Glance에 등록할 것.
> 
- DevStack에서 Ubuntu 22.04 cloud image 사용 가능 여부 확인
- 기본 CirrOS 이미지 대신 Ubuntu 계열 이미지를 Glance에 등록하는 절차 준비
- 학생 PC 자원 부족 가능성 고려 → VM flavor 작게 시작
- 권장 최소 flavor: `1 vCPU / 2GB RAM / 10GB Disk` (로컬 사양 부족 시 실패 로그 제출 인정)
- 3-tier 예제 앱은 운영자가 제공한 예제 repo / 아주 작은 샘플 사용
- 제출 기준은 **"완벽한 성공"보다 "어디까지 연결했고 어디서 막혔는지 설명 가능"** 에 둔다

---

## 📑 과제 완료 기준 및 제출 산출물

### 완료 기준

| 구분 | 완료 기준 |
| --- | --- |
| OpenStack | VM 생성, Security Group 설정, Floating IP/SSH 접근 경로 확인 |
| VM | SSH 접속 후 Docker/Docker Compose 설치 확인 |
| App | Web/WAS/DB 컨테이너 실행, 브라우저에서 Web 화면 확인 |
| Network | 외부 요청이 Web → WAS → DB까지 이동하는 흐름을 5~7줄로 설명 |
| Trouble Log | 실패한 경우 마지막 명령, 에러 메시지, 현재 상태 제출 |

### 제출 산출물

- [ ]  OpenStack 인스턴스 목록 또는 Horizon 화면 캡처
- [ ]  Security Group 설정 캡처
- [ ]  Floating IP 또는 SSH 접속 결과
- [ ]  `docker compose ps` 또는 컨테이너 실행 상태
- [ ]  브라우저 접속 결과 화면
- [ ]  `docker-compose.yml`
- [ ]  요청 흐름 설명 5~7줄
- [ ]  (막힌 경우) 마지막 명령과 에러 메시지 핵심 10줄

---

## 💬 학생 과제 안내문 (KakaoTalk 공유용)

📋 안내문 펼치기 (복사용)

```
[OpenStack 후속 실습 안내]

이번 과제는 DevStack 설치를 마무리한 뒤 진행할 후속 실습입니다.
목표는 OpenStack에서 만든 VM 위에 실제 3-tier 앱을 올려보는 것입니다.

중요한 점은 앱을 멋지게 만드는 것이 아니라,
"OpenStack이 VM과 네트워크를 제공하고, 그 위에 애플리케이션이 배포된다"는 흐름을 직접 확인하는 것입니다.

진행 시점:
- 2026-05-24 세션에서는 DevStack 실습 상태를 먼저 점검합니다.
- Horizon 접속, VM 생성, Floating IP 또는 SSH 접속 흐름을 확인한 뒤 다음 과제로 진행합니다.
- DevStack 설치가 막힌 경우에는 앱 배포보다 마지막 에러와 진행 단계를 정리하는 것을 우선합니다.

과제명:
- OpenStack VM 위에 Docker Compose 3-tier 앱 배포하기

목표:
1. DevStack에서 Ubuntu VM 생성
2. Security Group에서 SSH/HTTP 접근 허용
3. Floating IP 또는 실습 환경에 맞는 방식으로 VM 접속
4. VM 안에 Docker/Docker Compose 설치
5. Web/WAS/DB 3-tier 앱 실행
6. 브라우저에서 앱 접속 확인
7. 요청이 Web -> WAS -> DB로 이동하는 흐름 정리

필수 산출물:
1. OpenStack VM 생성 화면 또는 인스턴스 목록 캡처
2. Security Group 설정 캡처
3. SSH 접속 성공 화면 또는 막힌 지점
4. docker compose ps 결과
5. 브라우저 접속 결과
6. docker-compose.yml
7. 네트워크 흐름 설명 5~7줄

이번 과제에서 Kubernetes는 필수가 아닙니다.
Kubernetes와 MSA는 Docker Compose 기반 3-tier 앱 배포를 먼저 확인한 뒤 다음 단계로 진행합니다.

실패해도 제출 인정됩니다.
대신 아래 내용을 남겨주세요.

[막힘 공유]
1. 어느 단계에서 막혔는지:
2. 마지막으로 실행한 명령:
3. 에러 메시지 핵심 10줄:
4. 이미 시도해본 것:
5. 현재 상태:

캡처를 공유할 때 비밀번호, 토큰, 민감한 IP는 가리고 올려주세요.
```

---

## 📝 학생 제출 템플릿

📋 제출 템플릿 펼치기 (복사용)

```
[OpenStack VM 앱 배포 과제]

1. 현재 상태:
- 미시작 / 진행중 / 완료 / 막힘

2. OpenStack에서 확인한 것:
- VM 생성:
- Security Group:
- Floating IP 또는 SSH 접속:

3. Docker Compose 앱 실행:
- Web:
- WAS:
- DB:
- docker compose ps 결과:

4. 브라우저 접속 결과:
- 접속 URL:
- 성공/실패:
- 캡처 또는 설명:

5. 요청 흐름 설명:
- 브라우저 요청은 먼저 (작성)
- OpenStack에서는 (작성)
- VM 내부에서는 (작성)
- 컨테이너 간 통신은 (작성)
- DB 접근은 (작성)

6. 막힌 점 또는 질문:
- (작성)
- (작성)
```

---

## 🔍 리뷰 회의 질문

| 질문 | 확인하려는 것 |
| --- | --- |
| 브라우저에서 접속한 IP는 어디에서 온 주소인가? | Floating IP와 VM 접근 경로 이해 |
| Security Group에서 어떤 포트를 열었는가? | SSH/HTTP 접근 제어 이해 |
| Web 컨테이너와 WAS 컨테이너는 어떻게 통신하는가? | Docker Compose 내부 DNS와 네트워크 이해 |
| WAS는 DB 주소를 어떻게 알고 있는가? | 환경변수, 서비스명, 내부 네트워크 이해 |
| OpenStack 네트워크와 Docker 네트워크는 어디에서 경계가 나뉘는가? | VM 바깥 네트워크와 VM 안쪽 네트워크 구분 |
| 이 앱을 Kubernetes로 옮기면 어떤 리소스가 필요할까? | 다음 과제 연결 |

---

## 🔭 후속 확장안

### 🪜 다음 단계 1: 같은 앱을 Kubernetes로 이전

- Docker Compose의 service를 Kubernetes Deployment와 Service로 변환
- DB는 StatefulSet 또는 단순 Deployment + PVC로 구성
- ConfigMap, Secret, Service, Ingress 또는 NodePort 사용
- **목표**: YAML 작성량이 아니라 Compose와 Kubernetes의 **배포 단위 차이** 이해

### 🪜 다음 단계 2: 작은 MSA 형태로 분리

- WAS를 `user-service`, `order-service` 같은 두 개의 작은 서비스로 분리
- Web에서 각 서비스를 호출하게 구성
- 서비스 하나를 중지했을 때 어떤 장애가 생기는지 기록
- **목표**: MSA가 서비스 개수 증가가 아니라 **네트워크, 배포, 장애 지점 증가**를 동반한다는 점 이해

---

## ✅ 운영자 체크리스트

- [ ]  2026-05-24 세션에서 DevStack 설치 상태를 먼저 확인
- [ ]  DevStack 완료자가 충분하면 후속 앱 배포 과제 공개
- [ ]  완료자가 적으면 과제 공개는 하되 제출 시점을 1주 뒤로 미룸
- [ ]  Ubuntu cloud image 등록 방법 준비
- [ ]  예제 3-tier 앱 repo 또는 최소 샘플 준비
- [ ]  Security Group, Floating IP, SSH 접속 흐름 1회 시연
- [ ]  학생들에게 Kubernetes는 이번 과제의 필수가 아니라고 명확히 안내
- [ ]  제출 산출물에서 성공 여부보다 **네트워크 흐름 설명**을 중심으로 리뷰

---

> 📚 **관련 문서**
> 
> - DevStack 설치 가이드 (링크 추가)
> - OpenStack 네트워크 개념 정리 (링크 추가)
> - 예제 3-tier 앱 repo (링크 추가)