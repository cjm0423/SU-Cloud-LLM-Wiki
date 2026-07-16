---
title: "사전학습 3주차 — 쇼핑몰 3-tier 파이프라인 Docker Compose 구성"
type: "guide"
date: 2026-05-25
tags: ["#guide", "#prestudy", "#docker", "#kafka", "#pipeline"]
status: "stable"
related_nodes: ["[[01_Concepts/OpenStack-Overview]]", "[[03_Guides/DevStack-Installation-Guide]]", "[[03_Guides/Prestudy-4Week-Roadmap]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-05-25-prestudy-shopping-pipeline-week3-raw]]"
---

# 사전학습 3주차 — 쇼핑몰 3-tier 파이프라인 Docker Compose 구성

## 개요

카카오 클라우드의 관리형 서비스(Managed Kafka, Managed MySQL, ALB 등)를 **VM 1대의 Docker Compose**로 대체해 동일한 3-tier 데이터 파이프라인을 구현한 사전학습 3주차 과제.

---

## 아키텍처 비교

### 원본 (카카오 클라우드)
```
TG-VM × 2 → ALB → API-VM × 2 → Managed MySQL
                       │
                       └ access log → Filebeat → Logstash
                                                    ↓
                                              Managed Kafka (2 브로커)
```

### Docker Compose 버전
```
TG 컨테이너 → Nginx → Flask → MySQL
                │
                └ access log (공유 볼륨) → Filebeat → Logstash → Kafka (KRaft 단일 브로커)
```

**단순화한 부분:**

| 원본 | Docker 버전 | 이유 |
|------|------------|------|
| Managed Kafka 2 브로커 | Kafka 1 브로커 (KRaft) | 학습용 충분, replication factor=1 |
| API 서버 2대 + LB | Nginx 1대 → Flask 1대 | LB 학습은 별도 트랙 |
| Avro + Schema Registry | JSON → Kafka | Schema Registry 컨테이너 절약 |
| Pub/Sub + Object Storage | 제거 | 카카오 클라우드 전용 기능 |

---

## 컨테이너 구성 (7개)

| # | 컨테이너 | 이미지 | 포트 | 역할 |
|---|---------|--------|------|------|
| 1 | `mysql` | mysql:8.0.34 | (내부 3306) | 쇼핑몰 DB (24개 상품, 4명 유저) |
| 2 | `flask-app` | python:3.11-slim (빌드) | (내부 8080) | Flask 앱, Gunicorn workers=2 threads=4 |
| 3 | `nginx` | nginx:1.25-alpine | **80 (외부 노출)** | API 진입점, JSON access log 생성 |
| 4 | `filebeat` | elastic/filebeat:8.13.4 | (내부) | Nginx access log → Logstash 전송 |
| 5 | `logstash` | elastic/logstash:8.13.4 | (내부 5044) | JSON 파싱·타입 변환·Kafka 발행 |
| 6 | `kafka` | apache/kafka:3.7.1 | 9092 | KRaft 모드 단일 브로커, `nginx-topic` |
| 7 | `traffic-generator` | python:3.11-slim (빌드) | — | 가상 쇼핑몰 유저 행동 시뮬레이션 |

---

## 데이터 흐름

```
1. Traffic Generator: 가상 유저 행동(Anon→회원가입→Login→Browse→Cart→Checkout→Review)
   상태 기계 기반으로 HTTP 요청 발사 → nginx:80

2. Nginx: 요청을 flask-app:8080으로 역방향 프록시
   JSON 포맷 access log 생성 → 공유 볼륨(nginx_logs)

3. Filebeat: 공유 볼륨에서 access log 감시 → Logstash:5044 전송

4. Logstash: JSON 파싱, 타임스탬프 변환 → Kafka(nginx-topic)에 발행

5. Kafka(KRaft): 메시지 수신, 소비자가 kafka-console-consumer로 실시간 확인
```

---

## 핵심 학습 포인트

### 1. 서비스명 = DNS
`docker-compose.yaml`의 서비스명(`mysql`, `flask-app`, `kafka` 등)이 Docker 내장 DNS로 동작:
```yaml
# flask-app에서 mysql로 연결
MYSQL_HOST: mysql   # IP 없이 서비스명으로 통신
```

### 2. 공유 볼륨 패턴 (Sidecar)
```yaml
volumes:
  nginx_logs:   # nginx(쓰기) + filebeat(읽기 전용) 동시 마운트

services:
  nginx:
    volumes: [nginx_logs:/var/log/nginx]
  filebeat:
    volumes: [nginx_logs:/var/log/nginx:ro]
```
K8s의 `emptyDir`과 동일한 개념.

### 3. 준비 동기화 (healthcheck + depends_on)
```yaml
services:
  mysql:
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
  flask-app:
    depends_on:
      mysql:
        condition: service_healthy   # mysql healthy 후에만 시작
```
단순 "컨테이너 시작"이 아닌 "실제 요청 받을 준비 완료"를 보장.

---

## 실행 방법

```bash
# 클론 후 실행
git clone <repo>
cd shopping-pipeline
docker compose up -d

# 검증: nginx-topic 실시간 확인
docker compose exec kafka \
  kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic nginx-topic \
  --from-beginning
```

---

## PaaS vs Self-hosting 기준

| | PaaS (카카오 클라우드) | Self-hosting (이 실습) |
|-|---------------------|----------------------|
| 장점 | redundancy, 복구, 격리 자동 | 비용 절감, 학습 효과 |
| 단점 | 비용, 벤더 종속 | 운영 부담 |
| 기준 | 고가용성 필수 서비스 | 학습/개발/소규모 |

## 관련 문서

- [[03_Guides/Prestudy-4Week-Roadmap]]
- [[01_Concepts/OpenStack-Overview]]
- [[01_Concepts/HA-Concepts]] — Kafka 클러스터링 개념
