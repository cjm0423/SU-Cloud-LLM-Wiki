---
title: "사전학습 제출 템플릿"
type: "raw"
date: 2026-05-11
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/Prestudy-Submit-Template]]"
---
# 제출 템플릿

매주 리뷰 회의 전, 팀원들이 참고할 수 있도록 리드로서 먼저 템플릿에 맞춰 진행 상황을 공유해 주는 것을 추천해.

**[정상 진행 시 예시 - 1주차]**

> **[OpenStack 사전학습 1주차]1. 이번 주 학습 주제:** OpenStack 핵심 컴포넌트 역할 및 IaaS 개념 정리
**2. 직접 해본 것 / 캡처 / 링크 1개:** `openstack_이론 교안.pdf` 요약본 노션 링크 (링크)
**3. 핵심 정리 3줄:**
> 
> - Nova는 컴퓨트, Neutron은 네트워크, Cinder는 블록 스토리지를 담당함.
> - Keystone이 전체 인증을 통제하는 중앙 허브 역할을 수행함.
> - IaaS로서의 OpenStack은 가상화를 넘어 자원을 프로비저닝하고 관리하는 포털 역할을 함.
> **4. 막힌 점 또는 질문 1~2개:** Glance와 Cinder의 이미지/볼륨 관리 차이가 실무에서 어떻게 구분되어 쓰이는지 궁금함.
> **5. 상태:** 완료

**[막혔을 때 예시 - 3주차]**

> **[OpenStack 사전학습 3주차]1. 이번 주 학습 주제:** DevStack 설치 및 기본 조회
**2. 상태:** 막힘
> 
> 
> **[막힌 경우]1. 어느 단계에서 막혔는지:** `./stack.sh` 실행 중 RabbitMQ 연동 단계
> **2. 마지막으로 실행한 명령 또는 확인한 화면:** `./stack.sh`**3. 에러 메시지 핵심 10줄:**`Error: Service rabbitmq-server is not runningJob for rabbitmq-server.service failed...` (캡처본 첨부)
> **4. 이미 시도해본 것:** VM 메모리를 4GB에서 8GB로 늘리고 재부팅 후 재실행해봄.
> **5. 현재 상태:** 구글링 통해 포트 충돌 여부 확인 중
> 

**[1주차]**

> **[OpenStack 사전학습 1주차]**
> 

**1. 이번 주 학습 주제:** OpenStack 핵심 컴포넌트 역할 및 IaaS 개념 정리
**2. 직접 해본 것 / 캡처 / 링크 1개:** [노션 정리 링크](1%EC%A3%BC%EC%B0%A8(05%2011%20~%2005%2017)%2035dd8e51100c808f8b94cc5ce2a1010f.md)
**3. 핵심 정리 3줄:**

- IaaS(Infrastructure as a Service) - 인프라를 제공해준다. 우리는 OS, Middleware, Runtime, Data, App만 관리
- OpenStack이란? IaaS 클라우드 시스템을 구축하는 가장 대표적인 오픈소스 소프트웨어
- 오픈스택 핵심 컴포넌트 및 역할 - Keystone: Identity, Nova: Compute, Neutron: Networking, Glance: Image, Cinder: Block Storage, Swift: Storage, Horizon: Dashboard.

**4. 막힌 점 또는 질문 1~2개:** 

현재 실습 구성을 보면 PC OS → hypervisor (virtual box) → ubuntu(guest os) → hypervisor(KVM) → 오픈스택 인스턴스(VM)이던데 이중 가상화를 하는 이유는?
**5. 상태:** 완료

**[2주차]**

[OpenStack 사전학습 2주차]

1. 이번 주 학습 주제: DevStack 환경 준비 및 버전/의존성 트러블슈팅
2. 직접 해본 것 / 캡처 / 링크 1개:
openstack-devstack-lab 리포지토리 실습 흐름에 따라 VirtualBox 환경 구축 및 DevStack(2023.1 안정화 버전) 설치 완료, Horizon 대시보드 접속 및 실습 과정 버전 오류 트러블슈팅
3. 핵심 정리 3줄:
    - 실습 환경 구축: VirtualBox를 활용해 Ubuntu 22.04 VM을 생성하고, DevStack 구동에 필요한 컴퓨팅 자원과 NAT 네트워크 환경을 구성
    - DevStack 설치: 전용 `stack` 계정 생성 후 `local.conf`를 통해 비밀번호와 호스트 IP 등 최소 필수 환경을 정의하고 `./stack.sh`로 설치를 진행
    - 대시보드 및 통신 확인: 설치 중 발생한 버전 의존성(Python, 컴포넌트 브랜치) 충돌을 검증된 버전(2023.1)으로 해결하였고, Horizon 대시보드에서 수동으로 Private 네트워크와 라우터를 연결해 통신 구조를 확인
4. 막힌 점 또는 질문 1~2개:
실습 중 OS, Python, 그리고 내부 패키지 간의 버전이 꼬이는 의존성 충돌을 겪고 결국 2023.1 버전으로 낮춰서 설치에 성공했습니다. 오픈스택은 수많은 컴포넌트가 맞물려 돌아가고 깃허브를 통해 끊임없이 최신화되는데, 실제 운영 환경이나 프로젝트에서 이런 수많은 컴포넌트의 버전과 의존성을 안정적으로 관리하려면 어떤 전략(예: 릴리스 노트 추적, 특정 Stable 브랜치 고정, 컨테이너화 등)을 가져가야 할까요?
5. 상태: 완료 (트러블슈팅 포함)

**[3주차]**

**[OpenStack 사전학습 3주차]**

**1. 이번 주 학습 주제:**
OpenStack 기본 컴포넌트 설치 및 카카오 클라우드 3-tier 실시간 데이터 파이프라인의 Docker Compose 재구성 (관리형 서비스 없이 동일 파이프라인 구축)

**2. 직접 해본 것 / 캡처 / 링크 1개:**
OpenStack 기본 컴포넌트 설치를 완료했고, 카카오 클라우드 VM에서 7개 컨테이너(MySQL, Flask+Gunicorn, Nginx, Filebeat, Logstash, Kafka, Traffic Generator)로 구성한 쇼핑몰 3-tier 파이프라인을  기동. `kafka-console-consumer`로 nginx-topic에 실시간 행동 로그가 흘러가는 것까지 검증.
링크: [3주차(쇼핑 파이프라인 - 데이터 분석 course)](3%EC%A3%BC%EC%B0%A8(%EC%87%BC%ED%95%91%20%ED%8C%8C%EC%9D%B4%ED%94%84%EB%9D%BC%EC%9D%B8%20-%20%EB%8D%B0%EC%9D%B4%ED%84%B0%20%EB%B6%84%EC%84%9D%20course)%2036ed8e51100c80ff97bac16055c4a9d7.md), [오픈스택(OpenStack) 클라우드 구축 학습](../%EC%A0%84%EB%B6%81%EB%8C%80%20opestack%20%EC%A0%95%EB%A6%AC/%EC%98%A4%ED%94%88%EC%8A%A4%ED%83%9D(OpenStack)%20%ED%81%B4%EB%9D%BC%EC%9A%B0%EB%93%9C%20%EA%B5%AC%EC%B6%95%20%ED%95%99%EC%8A%B5%2036ed8e51100c80009905f152f7da6f87.md) 

**3. 핵심 정리 3줄:**

- **서비스명 = DNS** - docker-compose.yaml의 서비스명(`mysql`, `flask-app`, `kafka` 등)이 Docker 내장 DNS로 동작해 컨테이너끼리 IP 없이 이름으로 통신
- **공유 볼륨 패턴** - `nginx_logs` 라는 이름의 volume을 nginx(쓰기)와 filebeat(읽기 전용)에 동시 마운트해 로그 파일을 공유. Sidecar 패턴의 가장 단순한 형태이며 K8s의 emptyDir과 동일한 개념
- **준비 동기화** - `healthcheck` + `depends_on: service_healthy` + entrypoint의 대기 루프로, 단순 "컨테이너 시작"이 아닌 "실제 요청 받을 준비 완료"를 보장

**4. 막힌 점 또는 질문 1~2개:**

- 카카오클라우드에서 PaaS로 쓰던 서비스들을 VM의 Docker 컨테이너로 직접 내려보니 기능은 같지만 redundancy, 복구, 격리가 다 빠졌다. 실무에서 “PaaS에게 맡길 것 vs 직접 운영할 것"을 가르는 기준은?

**5. 상태: 완료**