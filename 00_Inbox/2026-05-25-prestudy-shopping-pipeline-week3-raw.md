---
title: "사전학습 3주차 (쇼핑 파이프라인 - 데이터 분석 course)"
type: "raw"
date: 2026-05-25
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/Prestudy-Shopping-Pipeline-Week3]]"
---
# 3주차(쇼핑 파이프라인 - 데이터 분석 course)

---

## 📋 목차

1. 아키텍처 비교 (원본 vs Docker)
2. 컨테이너 구성
3. 데이터 흐름
4. 실행 & 검증
5. 학습 포인트
6. 트러블슈팅

---

## 1. 아키텍처 비교

### 원본 (카카오 클라우드)

```
TG-VM × 2 → ALB → API-VM × 2 → Managed MySQL
                       │
                       └ access log → Filebeat → Logstash
                                                    │
                                                    ↓ Avro + Schema Registry
                                              Managed Kafka (2 브로커)
```

**인프라**: VPC, Object Storage × 2, ALB, Managed MySQL, Managed Kafka, Data Stream VM, TG-VM × 2, API-VM × 2

### Docker 버전 (옵션 A)

```
TG 컨테이너 → Nginx → Flask → MySQL
                │
                └ access log (공유 볼륨) → Filebeat → Logstash → Kafka (KRaft 단일 브로커)
```

**인프라**: VM 1대 (8GB) + Docker Compose

### 단순화한 부분

| 원본 | Docker 버전 | 이유 |
| --- | --- | --- |
| Managed Kafka 2 브로커 | Kafka 1 브로커 (KRaft) | 학습용 충분, replication factor=1 |
| API 서버 2대 + LB | Nginx 1대 → Flask 1대 | LB 학습은 별도 트랙 |
| Avro + Schema Registry | JSON 그대로 Kafka로 | Schema Registry 컨테이너 1개 절약 |
| Pub/Sub + Object Storage | 제거 | 카카오 클라우드 전용 (Day1 Lab02 기능) |

---

## 2. 컨테이너 구성

| # | 컨테이너 | 이미지 | 포트 | 역할 |
| --- | --- | --- | --- | --- |
| 1 | `mysql` | `mysql:8.0.34` | (내부 3306) | 쇼핑몰 DB. 24개 상품, 4명 샘플 유저 |
| 2 | `flask-app` | 직접 빌드 (python:3.11-slim) | (내부 8080) | 원본 Flask 앱 1200줄, Gunicorn workers=2 threads=4 |
| 3 | `nginx` | `nginx:1.25-alpine` | **80 (외부 노출)** | API 진입점. JSON 포맷 access log 생성 |
| 4 | `filebeat` | `elastic/filebeat:8.13.4` | (내부) | Nginx access log → Logstash로 전송 |
| 5 | `logstash` | `elastic/logstash:8.13.4` | (내부 5044) | JSON 파싱, 타입 변환, Kafka로 발행 |
| 6 | `kafka` | `apache/kafka:3.7.1` | 9092 | KRaft 모드 단일 브로커. 토픽 `nginx-topic` |
| 7 | `traffic-generator` | 직접 빌드 (python:3.11-slim) | — | 가상 쇼핑몰 유저 행동 시뮬레이션 (state machine) |

---

## 3. 데이터 흐름

```
1. Traffic Generator가 가상 쇼핑몰 유저 행동(Anon → 회원가입 → Login →
   Browse → Cart → Checkout → Review)을 상태 기계 기반으로 시뮬레이션.
   각 행동에 해당하는 HTTP 요청을 nginx:80으로 발사 (예: POST /login).

2. Nginx는 path 매칭(/products, /cart/add, /checkout 등)으로 허용된 endpoint만
   Flask(flask-app:8080)로 reverse proxy. 동시에 응답 정보(status, request_time,
   session_id, user_id, product_id 등 14개 필드)를 JSON 포맷으로
   /var/log/nginx/flask_app_access.log에 기록.

3. Flask + Gunicorn이 비즈니스 로직 처리. MySQL(mysql:3306)에서
   사용자/상품/세션/장바구니/주문/리뷰 데이터를 조회·수정.

4. Filebeat이 공유 볼륨(nginx_logs)을 read-only로 마운트하여
   access log를 tail. 새 줄이 들어오면 Beats 프로토콜로 logstash:5044로 전송.

5. Logstash가 JSON 파싱, 타임스탬프 정규화, 타입 변환(status→int,
   request_time→float 등)을 수행. Filebeat의 메타 필드 제거.

6. Logstash의 output → Kafka(kafka:9092)의 nginx-topic 토픽에
   JSON으로 발행.

7. Kafka 컨슈머(kafka-console-consumer 또는 별도 분석 앱)가 토픽을 구독하여
   실시간 행동 로그를 분석 가능.
```

---

## 4. 실행 & 검증

```bash
# docker 설치
curl -fsSL https://get.docker.com | sudo sh

# sudo 없이 docker 쓰기 (재로그인 필요)
sudo usermod -aG docker $USER

# 적용하려면 로그아웃 후 재접속
exit

# 설치 확인
docker --version
docker compose version    # 띄어쓰기 — 이게 나와야 정상

# 잘 되면
docker run hello-world
```

### 4-1. VM에 올리기

[shopping-pipeline.tar.gz](3%EC%A3%BC%EC%B0%A8(%EC%87%BC%ED%95%91%20%ED%8C%8C%EC%9D%B4%ED%94%84%EB%9D%BC%EC%9D%B8%20-%20%EB%8D%B0%EC%9D%B4%ED%84%B0%20%EB%B6%84%EC%84%9D%20course)/shopping-pipeline.tar.gz)

```bash
# 로컬에서
scp -i C:\Users\user\Downloads\keypairswclub.pem C:\Users\user\Downloads\shopping-pipeline.tar.gz ubuntu@61.109.238.249:~

# VM 안에서
tar -xzf shopping-pipeline.tar.gz
cd shopping-pipeline
docker compose up -d --build
```

### 4-2. 컨테이너 상태 확인

```bash
docker compose ps
```

기대 결과 (모두 `Up`, mysql/kafka는 `healthy`):

```
NAME                STATUS
flask-app           Up
filebeat            Up
kafka               Up (healthy)
logstash            Up
mysql               Up (healthy)
nginx               Up
traffic-generator   Up
```

### 4-3. Kafka로 로그가 흘러가는지 확인

```bash
docker compose exec kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic nginx-topic \
  --from-beginning
```

기대 출력 (5초 안에 메시지가 흘러나와야 함):

```json
{"timestamp":"2026-05-28 12:34:56","remote_addr":"172.18.0.8","request":"GET /products HTTP/1.1","status":200,"body_bytes_sent":1234,"http_referer":"-","session_id":"abc...","user_id":"u1","request_time":0.012,"endpoint":"/products","method":"GET","query_params":"","product_id":"","host":"nginx"}
{"timestamp":"...","request":"POST /cart/add HTTP/1.1","status":200,"product_id":"103",...}
```

각 메시지가 가상 유저의 행동 하나. 점점 다양한 endpoint가 나타나는지 보면 됨.

### 4-4. MySQL 데이터 확인 (실제로 비즈니스 로직이 동작했는지)

```bash
docker compose exec mysql mysql -uadmin -padmin1234 shopdb -e \
  "SELECT COUNT(*) AS sessions FROM sessions;
   SELECT COUNT(*) AS orders FROM orders;
   SELECT COUNT(*) AS cart_logs FROM cart_logs;
   SELECT event_type, COUNT(*) FROM cart_logs GROUP BY event_type;"
```

Traffic Generator가 동작하기 시작하면 숫자가 시간에 따라 증가해야 함.

```bash
docker compose exec mysql mysql -uadmin -padmin1234 shopdb -e \
"SELECT * FROM sessions LIMIT 20; SELECT * FROM orders LIMIT 20; SELECT * FROM cart_logs LIMIT 20; SELECT event_type, COUNT(*) FROM cart_logs GROUP BY event_type;"
```

### 4-5. 로그 보기

```bash
docker compose logs -f traffic-generator   # TG가 어떤 요청을 보내는지
docker compose logs -f nginx                # 어떤 응답을 보내는지
docker compose logs -f logstash | head -50  # Logstash 파싱 결과 (stdout codec)
```

---

## 5. 학습 포인트

### 5-1. 원본 클라우드 흐름과 1:1 대응

- 카카오 클라우드 콘솔에서 클릭으로 만드는 인프라(LB, Managed Kafka, MySQL, VM × 4) ↔ 이 docker-compose의 7개 서비스
- "PaaS 없이도 같은 파이프라인 구축 가능" ↔ "PaaS가 운영 부담을 얼마나 줄여주는가" 이해

### 5-2. 컨테이너 간 통신

- Nginx → Flask: `proxy_pass http://flask-app:8080` ← 서비스명이 DNS
- Flask → MySQL: `MYSQL_HOST=mysql` 환경변수 ← 같은 패턴
- Filebeat → Logstash: `hosts: ["logstash:5044"]` ← Beats 프로토콜
- Logstash → Kafka: `bootstrap_servers => "kafka:9092"` ← Kafka 클라이언트

### 5-3. 볼륨 공유 패턴 (가장 중요)

- Nginx는 `/var/log/nginx/`에 access log를 **쓰고**
- Filebeat은 같은 경로를 **읽음**
- 둘이 어떻게 같은 파일을 보는가? → `nginx_logs` named volume을 두 컨테이너에 다 마운트

```yaml
volumes:
  nginx_logs:           # Docker 관리 named volume

nginx:
  volumes:
    - nginx_logs:/var/log/nginx          # rw

filebeat:
  volumes:
    - nginx_logs:/var/log/nginx:ro       # read-only
```

이 패턴은 Sidecar 패턴의 가장 단순한 형태. K8s로 가면 같은 Pod에 두 컨테이너 + emptyDir volume으로 똑같이 풀림.

### 5-4. Kafka KRaft 모드

- 원본은 Managed Kafka라 ZooKeeper가 뒤에 숨어있음
- Docker 버전은 KRaft 모드 = ZooKeeper 없이 Kafka 자체가 메타데이터 관리
- 환경변수 `KAFKA_PROCESS_ROLES: "broker,controller"` 한 노드가 두 역할 동시 수행

### 5-5. JSON vs Avro 트레이드오프 (원본이 왜 Avro를 썼는가)

- **JSON (이 버전)**: 사람이 읽기 쉬움, 스키마 강제 없음, 메시지 크기 큼
- **Avro (원본)**: 스키마 강제 (Schema Registry로 진화 관리), 바이너리라 작음, 디버깅 불편
- 운영 규모 커지면 Avro/Protobuf로 가는 게 표준

---

### 6. Kafka UI 추가 (브라우저로 토픽/메시지 보기)

```yaml
kafka-ui:
  image: provectuslabs/kafka-ui:latest
  ports:
    - "8080:8080"
  environment:
    KAFKA_CLUSTERS_0_NAME: local
    KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
```

```bash
http://{vm public ip}:8080
```

---

## 정리

```bash
docker compose down -v       # 모든 볼륨/데이터 삭제
docker system prune -a       # 안 쓰는 이미지/캐시 정리
docker volume prune -a       # 볼륨 정리 
```

---

# 코드 분석

### 1. `docker-compose.yml`

전체 오케스트레이션 파일. 가장 중요

```bash
# docker-compose.yml
# "services" 아래 정의된 각 항목이 컨테이너 1개가 됨.
# docker compose up 하면 여기 정의된 순서/의존성에 따라 전부 띄움.
services:

  # ============= MySQL =============
  mysql:
    image: mysql:8.0.34              # Docker Hub에서 받아올 이미지 (직접 빌드 안 함)
    container_name: mysql            # 컨테이너 이름 고정. 안 적으면 shopping-pipeline-mysql-1 식으로 자동 생성
    environment:                     # 컨테이너 안에 들어갈 환경변수. MySQL 공식 이미지의 약속된 변수들
      MYSQL_ROOT_PASSWORD: rootpass  # root 계정 비번
      MYSQL_DATABASE: shopdb         # 첫 부팅 시 자동 생성할 DB 이름
      MYSQL_USER: admin              # 첫 부팅 시 자동 생성할 일반 계정
      MYSQL_PASSWORD: admin1234      # 그 계정 비번
    volumes:
      # [named volume] DB 데이터를 컨테이너 밖에 영속화. 컨테이너 지워도 데이터 살아남음
      - mysql_data:/var/lib/mysql
      # [bind mount] 우리 init.sql을 컨테이너 안 특정 경로로 넣음.
      # /docker-entrypoint-initdb.d/ 안의 .sql은 MySQL이 "최초 1회" 자동 실행 (테이블/샘플데이터 생성)
      # :ro = read-only (컨테이너가 이 파일 수정 못 함)
      - ./mysql/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro
    networks:
      - pipeline-net                 # 이 컨테이너가 속할 가상 네트워크
    healthcheck:                     # "DB가 진짜 요청 받을 준비 됐는지" 주기적 검사
      # mysqladmin ping으로 살아있는지 확인. 통과하면 상태가 healthy로 바뀜
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uadmin", "-padmin1234"]
      interval: 5s                   # 5초마다 검사
      timeout: 5s                    # 검사 1회당 최대 대기
      retries: 20                    # 20번 연속 실패하면 unhealthy
    command:                         # 컨테이너 기본 실행 명령에 인자 추가
      # MySQL8 기본 인증(caching_sha2)이 일부 클라이언트와 호환 안 돼서 옛 방식으로
      - --default-authentication-plugin=mysql_native_password
      # MySQL이 기본으로 메모리 많이 잡음. 8GB VM 고려해 버퍼풀을 256MB로 제한
      - --innodb-buffer-pool-size=256M

  # ============= Flask + Gunicorn =============
  flask-app:
    build: ./flask-app               # 이미지를 받는 게 아니라 ./flask-app/Dockerfile로 직접 빌드 (우리 코드가 들어가야 하니까)
    container_name: flask-app
    environment:                     # app.py가 os.environ.get()으로 읽는 값들
      MYSQL_HOST: mysql              # ★핵심: "mysql"은 위 서비스명 = Docker 내장 DNS 이름. 이걸로 DB 컨테이너에 접속
      MYSQL_USER: admin
      MYSQL_PASSWORD: admin1234
      MYSQL_DATABASE: shopdb
    depends_on:
      mysql:
        condition: service_healthy   # ★ mysql이 healthy 될 때까지 기다렸다 시작. (그냥 depends_on은 "컨테이너 시작"만 보장하지 DB 준비완료는 보장 안 함)
    networks:
      - pipeline-net
    # ports 없음 → 외부로 포트 노출 안 함. 오직 내부에서 nginx만 접근 가능

  # ============= Nginx (API Gateway + access log 생성) =============
  nginx:
    image: nginx:1.25-alpine         # 가벼운 alpine 기반 nginx
    container_name: nginx
    ports:
      - "80:80"                      # "호스트포트:컨테이너포트". ★유일하게 외부 노출되는 컨테이너. VM의 80 → nginx 80
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro   # 우리 설정 파일로 덮어쓰기 (read-only)
      # ★핵심 공유 볼륨: nginx가 여기에 access log를 "쓰고", 아래 filebeat이 같은 볼륨을 "읽음"
      - nginx_logs:/var/log/nginx
    depends_on:
      - flask-app                    # flask-app 다음에 시작 (시작 순서만, healthy 조건 없음)
    networks:
      - pipeline-net

  # ============= Filebeat =============
  filebeat:
    image: docker.elastic.co/beats/filebeat:8.13.4
    container_name: filebeat
    user: root                       # /var/log/nginx 파일을 읽으려면 권한 필요 → root로 실행
    # -e: 로그를 stdout으로 / --strict.perms=false: 마운트된 설정파일 권한검증 끔(안 끄면 실행 거부함)
    command: ["filebeat", "-e", "--strict.perms=false"]
    volumes:
      - ./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      # ★ nginx와 동일한 nginx_logs 볼륨을 read-only로 공유받음 → nginx가 쓴 로그를 읽음
      - nginx_logs:/var/log/nginx:ro
      # Filebeat이 "어디까지 읽었는지" 기록(레지스트리) 저장. 재시작해도 중복 안 읽음
      - filebeat_data:/usr/share/filebeat/data
    depends_on:
      - nginx                        # 로그를 만드는 nginx
      - logstash                     # 로그를 보낼 logstash
    networks:
      - pipeline-net

  # ============= Logstash =============
  logstash:
    image: docker.elastic.co/logstash/logstash:8.13.4
    container_name: logstash
    environment:
      LS_JAVA_OPTS: "-Xms512m -Xmx512m"   # JVM heap 고정 512MB. 8GB VM 고려. (Xms=최소, Xmx=최대를 같게 두는 게 JVM 권장)
    volumes:
      # 파이프라인 설정 폴더 마운트. 이 안의 .conf를 logstash가 자동 로드
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
    depends_on:
      kafka:
        condition: service_healthy   # kafka가 준비돼야 메시지를 보낼 수 있으니 대기
    networks:
      - pipeline-net

  # ============= Kafka (KRaft 모드, 단일 브로커) =============
  kafka:
    image: apache/kafka:3.7.1
    container_name: kafka
    ports:
      - "9092:9092"                  # 외부에서 kcat 등으로 확인용 (선택). 보안그룹에선 닫아두는 게 안전
    environment:
      KAFKA_NODE_ID: 1                                  # 이 노드의 ID
      KAFKA_PROCESS_ROLES: "broker,controller"          # ★KRaft: ZooKeeper 없이 한 노드가 broker(메시지)+controller(메타데이터) 둘 다
      KAFKA_LISTENERS: "PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093"  # 내가 "귀를 여는" 주소들
      KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://kafka:9092"  # ★클라이언트에게 "나한테 오려면 kafka:9092로 와"라고 알려주는 주소. logstash가 이걸로 붙음
      KAFKA_CONTROLLER_LISTENER_NAMES: "CONTROLLER"
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT"  # 둘 다 평문(암호화X)
      KAFKA_CONTROLLER_QUORUM_VOTERS: "1@kafka:9093"    # 컨트롤러 투표자 = 노드1 자신뿐 (단일 노드)
      KAFKA_INTER_BROKER_LISTENER_NAME: "PLAINTEXT"
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1         # ★복제본 1개. 기본값 3인데 브로커 1대뿐이라 3이면 에러남
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1 # 〃
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1            # 〃
      KAFKA_DEFAULT_REPLICATION_FACTOR: 1               # 〃
      KAFKA_MIN_INSYNC_REPLICAS: 1                      # 〃
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"           # logstash가 nginx-topic에 처음 보낼 때 토픽 자동 생성
      KAFKA_NUM_PARTITIONS: 1                           # 새 토픽 기본 파티션 수
      KAFKA_LOG_DIRS: "/tmp/kraft-combined-logs"        # Kafka 데이터 저장 경로 (컨테이너 내부)
      CLUSTER_ID: "4L6g3nShT-eMCtK--X86sw"              # KRaft 클러스터 고유 ID (원래 랜덤 생성하는데 학습용 고정값)
      KAFKA_HEAP_OPTS: "-Xmx512M -Xms512M"              # JVM heap 512MB 제한
    # ★ 여기 원래 volumes로 kafka_data 마운트가 있었는데, named volume이 root 소유라
    #   appuser가 못 써서 컨테이너가 죽었음 → 마운트 제거. 이제 컨테이너 내부 경로 그대로 사용
    networks:
      - pipeline-net
    healthcheck:
      # 실제로 broker API를 호출해 응답 오는지 확인
      test: ["CMD-SHELL", "/opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 > /dev/null 2>&1 || exit 1"]
      interval: 10s
      timeout: 10s
      retries: 30
      start_period: 30s              # ★첫 부팅 시 KRaft 메타데이터 포맷에 시간 걸려서, 처음 30초는 실패해도 안 따짐

  # ============= Kafka UI (웹 콘솔) =============
  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    ports:
      - "8080:8080"                  # 브라우저 접속용. http://공인IP:8080
    environment:
      KAFKA_CLUSTERS_0_NAME: local                   # UI에 표시될 클러스터 이름 (0_ 번호는 여러 클러스터 등록 가능해서)
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092   # 연결할 Kafka (서비스명 DNS)
      DYNAMIC_CONFIG_ENABLED: "true"                  # UI에서 토픽 생성/설정 변경 가능
      JAVA_OPTS: "-Xms256m -Xmx256m"                  # heap 256MB로 제한 (메모리 절약)
    depends_on:
      kafka:
        condition: service_healthy
    networks:
      - pipeline-net

  # ============= Traffic Generator =============
  traffic-generator:
    build: ./traffic-generator       # 직접 빌드
    container_name: traffic-generator
    depends_on:
      - nginx                        # 시작 순서만 (실제 준비 확인은 entrypoint.sh가 함)
      - kafka
    networks:
      - pipeline-net
    restart: unless-stopped          # 죽으면 자동 재시작 (수동으로 멈추기 전까지). 트래픽 끊기지 않게

# 위에서 사용한 named volume들을 선언. 빈 값이면 Docker가 기본설정으로 생성
# (kafka_data는 권한문제로 제거했으므로 여기 없음)
volumes:
  mysql_data:
  nginx_logs:
  filebeat_data:

# 가상 네트워크 선언. 모든 서비스가 pipeline-net 하나에 속해 서로 통신
# (이 파이프라인은 단방향 흐름이라 MSA 데모처럼 네트워크를 쪼개지 않음)
networks:
  pipeline-net:
```

---

### 2. `flask-app/requirements.txt`

Dockerfile의 `RUN pip install -r requirements.txt`가 설치하는 대상.

```bash
# flask-app/requirements.txt
# flask-app/Dockerfile이 이 목록을 pip install로 설치함

flask==2.1.3
# ★ 버전 고정이 핵심. 원본 app.py가 "from flask.json import JSONEncoder"와
#   "app.json_encoder = ..."를 쓰는데, 이건 Flask 2.2 이하 방식.
#   Flask 2.3부터 JSONEncoder가 제거돼서 ImportError로 컨테이너가 죽었음 → 2.1.3로 내림

werkzeug==2.1.2
# ★ Flask의 핵심 의존 라이브러리(요청/응답 처리 엔진). Flask와 버전 짝이 맞아야 함.
#   flask==2.1.3만 적으면 pip가 werkzeug는 최신(3.x)을 깔아버려서
#   "cannot import name 'url_quote' from werkzeug.urls" 에러 발생 → 2.1.2로 같이 고정해야 해결

gunicorn==21.2.0
# WSGI 서버. Flask 내장 서버는 개발용이라, 실전용으로 Gunicorn이 Flask 앱을 구동.
#   Dockerfile의 CMD에서 "gunicorn ... app:app"으로 실행됨

mysql-connector-python==8.2.0
# app.py가 MySQL에 붙을 때 쓰는 드라이버 (import mysql.connector).
#   pure-python 구현이라 컨테이너에 별도 시스템 라이브러리(libmysqlclient 등) 설치 불필요
```

---

### 3. `flask-app/Dockerfile`

Flask 앱 이미지를 빌드하는 설계도.

```bash
# flask-app/Dockerfile

# 베이스 이미지: 가벼운 Python 3.11 (slim = 불필요한 것 제거된 경량판)
FROM python:3.11-slim

# 이후 명령들이 실행될 작업 디렉토리. 없으면 자동 생성
WORKDIR /app

# ★ COPY requirements → install → COPY app.py 순서가 의도적임 (Docker 레이어 캐시 활용)
#   requirements가 안 바뀌면 무거운 pip install 레이어를 재사용.
#   app.py만 고치면 pip install 건너뛰고 마지막 COPY만 다시 → 빌드 빨라짐
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt   # --no-cache-dir: pip 캐시 안 남겨 이미지 용량 절약

# 앱 코드 복사
COPY app.py .

# "이 컨테이너는 8080을 쓴다"는 문서화 (실제 포트 여는 건 compose의 ports)
EXPOSE 8080

# 컨테이너 시작 시 실행할 명령
#   gunicorn: Flask 내장서버는 개발용이라 실전 WSGI 서버 Gunicorn으로 실행 (원본도 동일)
#   --workers 2 --threads 4: 프로세스2 × 스레드4 (원본은 CPU*2+1 공식, 컨테이너라 보수적 고정)
#   --bind 0.0.0.0:8080: 8080에서 listen
#   --access-logfile -: 접근로그를 stdout으로 (docker logs로 보이게)
#   app:app: app.py 파일의 app 객체(Flask 인스턴스)
CMD ["gunicorn", "--workers", "2", "--threads", "4", "--bind", "0.0.0.0:8080", "--access-logfile", "-", "app:app"]
```

---

### 4. `traffic-generator/Dockerfile`

```bash
# traffic-generator/Dockerfile

FROM python:3.11-slim

WORKDIR /app

# entrypoint.sh에서 nginx 준비 확인용으로 curl이 필요한데 slim엔 없어서 설치
#   --no-install-recommends: 추천 패키지 안 깔아 용량 절약
#   rm -rf .../lists/*: apt 캐시 삭제 (이미지 용량 절약)
#   && 로 한 RUN에 묶은 것도 레이어 수 최소화 목적
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# traffic_generator가 쓰는 라이브러리 (HTTP 요청 / YAML 파싱)
RUN pip install --no-cache-dir requests pyyaml

# 코드 파일들 복사
COPY config.py .
COPY config.yml .
COPY traffic_generator.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh          # 스크립트에 실행 권한 부여

# 시작하면 entrypoint.sh 실행 (바로 python을 안 부르고 한 단계 거침 - 아래 entrypoint 설명 참고)
CMD ["./entrypoint.sh"]
```

---

### 5. `traffic-generator/entrypoint.sh`

```bash
#!/bin/sh
# traffic-generator/entrypoint.sh
# 역할: traffic_generator.py를 바로 실행하지 않고, "파이프라인이 준비될 때까지 기다린 뒤" 실행

set -e   # 명령 하나라도 실패하면 스크립트 즉시 종료

echo "[traffic-generator] Waiting for nginx → flask → mysql chain to be ready..."

# ★ 왜 필요한가: compose의 depends_on은 "컨테이너 시작" 순서만 보장하지,
#   nginx→flask→mysql 체인이 "진짜 요청 받을 준비"가 됐는지는 모름. 그래서 직접 확인.
# 최대 60번 반복 (×3초 = 최대 3분 대기)
for i in $(seq 1 60); do
  # /products가 200을 주면 = nginx도, flask도, mysql도 다 살아있다는 신호 (이 endpoint가 DB를 조회하니까)
  #   -s 조용히 / -f 실패 시 에러코드 / -o /dev/null 응답본문 버림
  if curl -sf -o /dev/null "http://nginx/products"; then
    echo "[traffic-generator] Pipeline is ready. Starting traffic..."
    break                            # 준비됐으면 루프 탈출
  fi
  echo "[traffic-generator] not ready yet... ($i/60)"
  sleep 3                            # 아직이면 3초 자고 재시도
done

# ★ exec: 현재 셸 프로세스를 python으로 "교체" (자식으로 띄우는 게 아니라).
#   이래야 컨테이너의 메인 프로세스(PID 1)가 python이 돼서, docker stop 시 신호가 python에 바로 전달됨
# --mode continuous: 원본 코드의 무한 트래픽 생성 모드
exec python3 traffic_generator.py --mode continuous
```

---

### 정리

```bash
traffic-generator (entrypoint.sh가 nginx 준비 대기 후 무한 요청)
   │  http://nginx/...
   ▼
nginx (80, custom_json 로그를 nginx_logs 볼륨에 기록)
   │  proxy_pass http://flask-app:8080
   ▼
flask-app (gunicorn 8080) ──> mysql (3306)   ← 비즈니스 로직
   
nginx_logs 볼륨 (공유)
   │
   ▼
filebeat ──Beats(5044)──> logstash ──kafka:9092──> kafka ──> kafka-ui(8080)
```

세 가지 핵심 메커니즘:

1. **서비스명 = DNS**: `mysql`, `flask-app`, `kafka`, `logstash` 등 서비스 이름으로 서로를 찾음
2. **공유 볼륨**: `nginx_logs`를 nginx(쓰기)와 filebeat(읽기)이 함께 마운트 → 파일 공유
3. **준비 동기화**: `healthcheck` + `depends_on: service_healthy` + entrypoint의 대기 루프