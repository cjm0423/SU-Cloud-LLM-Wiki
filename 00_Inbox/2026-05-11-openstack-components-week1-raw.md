---
title: "OpenStack & Components - 1 week"
type: "raw"
date: 2026-05-11
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[01_Concepts/OpenStack-Overview]]"
---
# OpenStack & Components - 1 week

### 참고자료

https://www.openstack.org/software/

https://velog.io/@dlwpdlf147/OpenStack-%EC%98%A4%ED%94%88%EC%8A%A4%ED%83%9D%EC%9D%B4%EB%9E%80

https://wikidocs.net/230172

## 1. OpenStack이란

OpenStack은 데이터센터 전반에 걸쳐 있는 대규모의 컴퓨팅, 스토리지, 네트워킹 자원 풀(pool)을 제어하는 클라우드 운영체제이며, 이 모든 자원은 공통된 인증 메커니즘을 갖춘 API를 통해 관리되고 프로비저닝 된다. - openstack 공식 소개

→ 클라우드 컴퓨팅 환경을 구축하고 관리할 수 있는 **오픈소스 소프트웨어 플랫폼**
쉽게 말해 AWS나 Kakaocloud 같은 클라우드 서비스를 내 회사 서버에 직접 만들 수 있게 해주는 도구

---

## 2. IaaS & OpenStack

1. IaaS (Infrastructure as a Service) 란
    - 서버, 스토리지 및 네트워크 등과 같은 사용자가 필요한 컴퓨팅 자원(IT 인프라)을 가상화된 형태로 제공하는 서비스
2. IaaS 와 OpenStack의 관계
    - OpenStack을 활용해 내 컴퓨팅·스토리지·네트워킹 자원을 가상화하여 사용자에게 자원을 제공함으로써 **IaaS형 CSP의 역할을 수행**

---

## 3. Components

- **Compute**
    1. **Nova - Compute Service**
        - 가상 머신(VM)의 생명 주기 관리(생성, 스케줄링, 삭제)를 담당
    2. Zun - Containers Service
- **Storage**
    1. Swift - Object Storage
        - 객체 스토리지 서비스, 대규모 비정형 데이터 저장, HTTP로 접근 가능
    2. **Cinder - Block Storage**
        - 블록 스토리지 서비스 제공, 데이터베이스, 파일 시스템 등을 위한 스토리지 볼륨 관리
    3. Manila - Shared filesystems
- **Networking**
    1. **Neutron - Networking (VPC)**
        - 클라우드 내 네트워킹 기능을 관리하는 컴포넌트로, 가상 네트워크, 서브넷, 라우터 등을 설정하고 관리
    2. Octavia - Load Balancer
    3. Designate - DNS Service
- **Shared Services**
    1. **Keystone - Identity service**
        - OpenStack 내의 모든 인증 및 권한 부여 작업을 담당하는 서비스, 사용자와 서비스 간의 인증 관리
    2. Placement - Placement service
    3. **Glance - Image service**
        - 가상 머신 이미지 관리 서비스, VM 이미지 등록, 저장, 검색 및 검색 기능 제공
    4. Barbican - Key management
- **Orchestration**
    1. Heat - Orchestration
        - 오케스트레이션 서비스, 템플릿을 사용하여 애플리케이션 스택의 자원을 자동으로 생성하고 관리
    2. Mistral - Workflow service
    3. Zaqar - Messaging Service
    4. Blazer - Resource reservation service
    5. AODH - Alarming Service
- **Workload Provisioning**
    1. Magnum -  Container Orchestration Engine Provisioning
    2. Trove - Database as a Service
        - 데이터베이스 서비스, 관계형 및 비관계형 데이터베이스 인스턴스를 관리할 수 있게 함.
- **Application Lifecycle**
    1. Freezer - Backup and Restore
    2. Masakari - Instances High Availability Service
- **Web frontends**
    1. **Horizon - Dashboard** 
        - OpenStack의 대시보드, 웹 기반의 사용자 인터페이스를 제공하여 OpenStack 서비스를 관리
    2. Skyline - Next Generation Dashboard
- **Hardware Lifecycle**
    1. Ironic - Bare Metal Provisioning Service
    2. Cyborg - Lifecycle management of accelerators
- **Monitoring service**
    1. Ceilometer - Metering & Data Correction Service
        - 테레메트리 서비스, 클라우드 사용에 대한 메트릭 수집, 모니터링 및 빌링을 위한 데이터를 제공
- **Resource optimization**
    1. Watcher - Optimization Service
- **Billing / Business Logic**
    1. Adjutant - Operators processes automation
    2. Cloudkitty - Billing and chargebacks
- **Testing / Benchmark**
    1. Rally - Benchmarking tool
    2. Tempest - The Openstack Intergration Test Suite

![Openstack Architecture](OpenStack%20&%20Components%20-%201%20week/Openstack_Architecture.png)

Openstack Architecture