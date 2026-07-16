---
title: "DevStack 이후 — OpenStack VM 위 앱 배포 과제 가이드"
type: "guide"
date: 2026-05-24
tags: ["#guide", "#prestudy", "#devstack", "#docker", "#openstack"]
related_nodes: ["[[03_Guides/DevStack-Installation-Guide]]", "[[01_Concepts/OpenStack-Overview]]", "[[01_Concepts/Floating-IP]]", "[[03_Guides/Prestudy-Shopping-Pipeline-Week3]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-05-24-devstack-deploy-task-raw]]"
---

# DevStack 이후 — OpenStack VM 위 앱 배포 과제 가이드

## 개요

DevStack 설치 후 다음 단계: OpenStack VM 위에 Docker Compose 3-tier 앱을 배포해서 "OpenStack이 실제 앱 실행 환경을 제공하는 계층"이라는 감각을 연결하는 과제.

**핵심 흐름:**
```
OpenStack VM 생성 → VM 접속 → Docker Compose 앱 배포 → 외부 접속 확인
```

---

## 선행 조건

- DevStack 설치 완료 (Horizon 접속 가능)
- VM 생성, Floating IP 연결, SSH 접속 흐름 완료
- → [[03_Guides/DevStack-Installation-Guide]]

---

## 커리큘럼 위치

```
DevStack 설치 + Horizon/CLI 확인
  ↓
OpenStack 네트워크, Security Group, Floating IP 이해
  ↓
OpenStack VM 위 Docker Compose 3-tier 앱 배포   ← 👈 이 가이드
  ↓
같은 앱을 Kubernetes로 이전
  ↓
작은 MSA 형태로 서비스 분리
  ↓
OpenStack Infrastructure MVP 설계
```

---

## 과제 범위

### ✅ 필수 범위
- [ ] DevStack에서 Ubuntu 계열 VM 인스턴스 생성
- [ ] Security Group에서 SSH(22)와 HTTP(80) 접근 허용
- [ ] Floating IP 연결 또는 실습 환경에 맞는 경로로 VM SSH 접속
- [ ] VM 안에 Docker와 Docker Compose 설치
- [ ] Web/WAS/DB 3-tier 예제 앱을 Docker Compose로 실행
- [ ] 브라우저에서 앱 접속 확인
- [ ] `브라우저 → OpenStack 네트워크 → VM → 컨테이너 → DB` 흐름 설명

### ❌ 비범위 (다음 단계로 미룸)
- Kubernetes 클러스터 구성
- 여러 VM에 Web/WAS/DB 분산 배치
- 상용 수준 HA, 모니터링, CI/CD
- 복잡한 인증, 도메인, TLS 설정

---

## 단계별 절차

### Step 1. Ubuntu VM 생성 (Horizon)

1. **Horizon** → Compute → Instances → Launch Instance
2. 설정:
   - Instance Name: `app-vm`
   - Source: Ubuntu 22.04 이미지
   - Flavor: `m1.small` (1 vCPU, 2GB RAM)
   - Networks: self-service network

### Step 2. Security Group 규칙 추가

Horizon → Network → Security Groups → default → Add Rule:

| 방향 | 프로토콜 | 포트 | CIDR |
|------|---------|------|------|
| Ingress | TCP | 22 | 0.0.0.0/0 |
| Ingress | TCP | 80 | 0.0.0.0/0 |

### Step 3. Floating IP 연결

```bash
# CLI로 Floating IP 생성 및 연결
openstack floating ip create provider
openstack server add floating ip app-vm <FIP>

# SSH 접속 확인
ssh ubuntu@<FIP>
```

### Step 4. VM 안에 Docker 설치

```bash
# VM에서 실행
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu
newgrp docker

# Docker Compose 설치
sudo apt install -y docker-compose-plugin
docker compose version
```

### Step 5. 3-tier 앱 배포

**권장 기술 스택:**

| 계층 | 권장 | 이유 |
|------|------|------|
| Web | Nginx | HTTP 요청 진입점 명확히 볼 수 있음 |
| WAS | FastAPI / Flask / Express | 익숙한 언어 선택 가능 |
| DB | PostgreSQL / MySQL | Docker 경험과 연결 |

**최소 docker-compose.yaml:**
```yaml
version: "3.8"
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: password
    healthcheck:
      test: ["CMD", "pg_isready"]

  app:
    build: ./app
    depends_on:
      db:
        condition: service_healthy
    environment:
      DB_HOST: db

  nginx:
    image: nginx:alpine
    ports: ["80:80"]
    volumes: ["./nginx.conf:/etc/nginx/conf.d/default.conf"]
    depends_on: [app]
```

### Step 6. 외부 접속 확인

```bash
# Floating IP로 접속
curl http://<FIP>/
```

---

## 제출 기준

완전 성공 여부와 무관하게 **마지막 에러/진행 단계를 기록하면 제출 인정**.

제출물:
1. 접속 확인 스크린샷 (브라우저 또는 curl 출력)
2. 흐름 설명 (`브라우저 → FIP → VM → nginx → app → db`)
3. 막힌 경우: 에러 메시지 + 시도한 것

---

## 관련 문서

- [[03_Guides/DevStack-Installation-Guide]]
- [[01_Concepts/Floating-IP]]
- [[01_Concepts/Provider-vs-SelfService-Network]]
- [[03_Guides/Prestudy-Shopping-Pipeline-Week3]] — 유사한 3-tier Docker Compose 구성 참고
