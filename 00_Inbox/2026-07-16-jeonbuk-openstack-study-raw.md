---
title: "오픈스택(OpenStack) 클라우드 구축 학습"
type: "raw"
date: 2026-07-16
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[01_Concepts/OpenStack-Overview]]"
---
# 오픈스택(OpenStack) 클라우드 구축 학습

---

## 목차

1. 클라우드 컴퓨팅 개요
2. 오픈스택이란
3. 오픈스택 아키텍처와 핵심 컴포넌트
4. 노드 구성과 네트워크 설계
5. 설치 환경 준비
6. 설치 방법별 비교 (DevStack / Packstack / Kolla-Ansible / 수동)
7. 컴포넌트별 설치·설정
8. Horizon 대시보드 사용법
9. 인스턴스 운영 실습
10. CLI(openstack) 활용
11. 트러블슈팅 & 운영 팁

---

## 1. 클라우드 컴퓨팅 개요

### 핵심 개념

- **클라우드 컴퓨팅**: 컴퓨팅 자원(CPU, 메모리, 스토리지, 네트워크)을 인터넷을 통해 온디맨드로 제공받는 모델
- **NIST의 5가지 본질적 특성**: 온디맨드 셀프서비스, 광범위한 네트워크 접근, 자원 풀링, 빠른 탄력성, 측정 가능한 서비스

### 서비스 모델

| 모델 | 제공 범위 | 예시 |
| --- | --- | --- |
| **IaaS** | 인프라(VM, 네트워크, 스토리지) | AWS EC2, **OpenStack** |
| **PaaS** | 런타임/플랫폼 | Heroku, GAE |
| **SaaS** | 애플리케이션 | Gmail, Salesforce |

### 배포 모델

- **Public / Private / Hybrid / Community Cloud**
- 오픈스택은 주로 **Private Cloud** 구축에 사용 (Public도 가능)

### 가상화 vs 클라우드

- **가상화**: 하나의 물리 자원을 여러 논리 자원으로 분할 (하이퍼바이저)
- **클라우드**: 가상화 + 자동화 + 셀프서비스 + 과금/측정
- → 오픈스택은 가상화 위에 올라가는 **오케스트레이션 레이어**

---

## 2. 오픈스택이란

### 기본 정보

- **2010년** NASA + Rackspace 합작 프로젝트로 출발
- **Apache 2.0 라이선스** 오픈소스
- **OpenInfra Foundation**(구 OpenStack Foundation)이 운영
- 6개월 주기 릴리즈 (알파벳 순 코드네임): … Antelope → Bobcat → Caracal → Dalmatian → Epoxy → Flamingo …

### 특징

- 모듈형 아키텍처 (필요한 컴포넌트만 선택 설치)
- 다양한 하이퍼바이저 지원 (KVM 기본, Xen, ESXi, Hyper-V)
- REST API 기반 → 자동화/통합 용이
- 멀티 테넌시 지원

### 왜 쓰는가

- 벤더 락인 회피
- 사내 데이터센터를 클라우드화 (Private Cloud)
- 망분리 환경, 공공/금융 등 데이터 주권 요구 환경

---

## 3. 오픈스택 아키텍처와 핵심 컴포넌트

### 핵심 컴포넌트 (필수)

| 컴포넌트 | 코드네임 | 역할 |
| --- | --- | --- |
| Identity | **Keystone** | 인증/인가, 서비스 카탈로그 |
| Image | **Glance** | VM 이미지 저장/관리 |
| Compute | **Nova** | VM 인스턴스 생성/관리 |
| Networking | **Neutron** | 가상 네트워크/서브넷/라우터 |
| Dashboard | **Horizon** | 웹 GUI |
| Placement | **Placement** | 자원 인벤토리/할당 추적 (Nova에서 분리됨) |

### 선택 컴포넌트 (확장)

- **Heat**: 오케스트레이션 (CloudFormation 유사)
- **Ceilometer / Gnocchi / Aodh**: 모니터링/계측/알람
- **Ironic**: 베어메탈 프로비저닝
- **Magnum**: 컨테이너 오케스트레이션 (K8s 등)
- **Octavia**: LBaaS (로드밸런서)
- **Designate**: DNSaaS
- **Barbican**: 키/시크릿 관리
- **Trove**: DBaaS
- **Manila**: 공유 파일 시스템

### 컴포넌트 간 통신 흐름 (인스턴스 생성 예)

```
사용자 → Horizon/CLI
     → Keystone(인증 토큰 발급)
     → Nova-API(요청 수신)
     → Placement(자원 후보 조회)
     → Nova-Scheduler(노드 선택)
     → Glance(이미지 다운로드)
     → Neutron(네트워크/포트 할당)
     → Cinder(볼륨 연결, 선택)
     → Nova-Compute(KVM/libvirt로 VM 부팅)
```

---

## 4. 노드 구성과 네트워크 설계

### 노드 역할

| 노드 | 역할 | 주요 실행 서비스 |
| --- | --- | --- |
| **Controller Node** | 컨트롤 플레인 | Keystone, Glance, Nova-API, Neutron-Server, Horizon, MariaDB, RabbitMQ |
| **Compute Node** | VM 실행 | Nova-Compute, libvirt/KVM, Neutron L2 Agent |
| **Network Node** | 외부 통신/라우팅 | Neutron L3 Agent, DHCP Agent, Metadata Agent |
| **Storage Node** | 블록/오브젝트 스토리지 | Cinder-Volume, Swift |

> 소규모/테스트 환경에서는 Controller + Network를 하나로, Compute만 별도 노드로 가는 구성이 흔합니다 (최소 2노드).
> 

### 네트워크 종류

- **Management Network**: 노드 간 내부 통신 (API, DB, 메시지 큐)
- **Provider Network**: 외부와 직접 연결되는 네트워크 (운영자가 사전 정의)
- **Self-Service / Tenant Network**: 사용자가 직접 만드는 가상 네트워크 (VXLAN/GRE 터널)
- **Storage Network**: 스토리지 트래픽 분리용 (선택)
- **API Network / External Network**: API 노출, Floating IP용

### 권장 NIC 구성 (실습 환경)

- 최소 2개: `Management` + `Provider`
- 권장 3개: `Management` + `Provider/External` + `Tunnel(VXLAN)`

---

## 5. 설치 환경 준비

### 하드웨어 최소 요건 (실습 기준)

- **Controller**: 8GB+ RAM, 4 vCPU, 50GB+ 디스크
- **Compute**: 8GB+ RAM (VM 띄울 만큼), 4 vCPU, **CPU 가상화 지원(VT-x/AMD-V)**, 100GB+ 디스크
- VirtualBox/VMware 위에서 실습 시 → **Nested Virtualization** 활성화 필수

### OS 선택

- Ubuntu Server 22.04 LTS (가장 많은 가이드)
- Rocky Linux / AlmaLinux 9 (RHEL 계열)
- CentOS Stream

### 사전 작업 체크리스트

- [ ]  호스트명 설정 (`controller`, `compute1` 등)
- [ ]  `/etc/hosts`에 IP-호스트명 매핑 (DNS 대신)
- [ ]  모든 노드 시간 동기화 (Chrony/NTP)
- [ ]  root 또는 sudo 사용자 준비
- [ ]  SELinux/AppArmor, 방화벽 정책 확인 (실습 시 비활성화 고려)
- [ ]  공식 패키지 저장소 추가 (Ubuntu Cloud Archive 또는 RDO)

```bash
# Ubuntu에서 클라우드 아카이브 추가 예시
sudo add-apt-repository cloud-archive:caracal
sudo apt update && sudo apt upgrade -y
```

---

## 6. 설치 방법별 비교

| 방법 | 난이도 | 용도 | 비고 |
| --- | --- | --- | --- |
| **DevStack** | ⭐ | 개발/테스트 (싱글 노드) | 재부팅 시 사라짐, 운영 X |
| **Packstack (RDO)** | ⭐⭐ | RHEL/Rocky 계열 PoC | Puppet 기반 |
| **Kolla-Ansible** | ⭐⭐⭐ | 컨테이너 기반 운영 | Docker로 각 서비스 컨테이너화 |
| **OpenStack-Ansible** | ⭐⭐⭐⭐ | 대규모 운영 | LXC 컨테이너 |
| **수동 설치** | ⭐⭐⭐⭐⭐ | 학습용 (Install Guide) | 가장 깊이 이해 가능 |

### DevStack 빠른 시작

```bash
sudo useradd -s /bin/bash -d /opt/stack -m stack
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack
sudo su - stack
git clone https://opendev.org/openstack/devstack
cd devstack
cp samples/local.conf .
./stack.sh
```

> 강의에서 어떤 방법으로 설치하는지 확인 후, 해당 섹션 위주로 정리하세요.
> 

---

## 7. 컴포넌트별 설치·설정 (수동 설치 기준 흐름)

### 7-1. 사전 패키지

- **MariaDB**: 메타데이터 저장
- **RabbitMQ**: 서비스 간 메시지 큐
- **Memcached**: 토큰 캐싱
- **etcd**: 분산 락/설정

### 7-2. Keystone (Identity)

- DB 생성 → 패키지 설치 → `keystone.conf` 수정 → DB 동기화 → 부트스트랩
- 핵심 개념: **User / Project(Tenant) / Role / Domain / Service / Endpoint**
- 인증 후 발급되는 **토큰**으로 다른 서비스 호출

```bash
openstack endpoint list
openstack user create --domain default --password-prompt admin
```

### 7-3. Glance (Image)

- 이미지 저장 백엔드: 파일시스템(기본), Swift, Ceph
- 주요 포맷: `qcow2`, `raw`, `vmdk`, `iso`

```bash
openstack image create "cirros" \
  --file cirros.img --disk-format qcow2 --container-format bare --public
```

### 7-4. Placement

- Nova에서 분리된 자원 추적 서비스
- 어떤 노드에 얼마나 자원이 남았는지 관리

### 7-5. Nova (Compute)

- 구성요소: `nova-api`, `nova-scheduler`, `nova-conductor`, `nova-compute`
- Compute 노드에는 `nova-compute`만 설치
- 셀(Cell) 구조 이해

### 7-6. Neutron (Networking)

- ML2 플러그인 + 메커니즘 드라이버(`linuxbridge` 또는 `openvswitch`)
- 에이전트: L2, L3, DHCP, Metadata
- Provider Network vs Self-Service Network 선택

### 7-7. Horizon

- Django 기반 웹 대시보드
- 설치 후 `http://<controller-ip>/horizon` 접속

### 7-8. Cinder (선택)

- LVM 백엔드가 가장 흔함 (실습)
- 운영에서는 Ceph RBD, NetApp 등 사용

---

## 8. Horizon 대시보드 사용법

### 자주 쓰는 메뉴

- **Project → Compute → Instances**: VM 생성/관리
- **Project → Compute → Images**: 이미지 업로드
- **Project → Compute → Key Pairs**: SSH 키페어
- **Project → Network → Networks / Routers**: 가상 네트워크 구성
- **Project → Network → Security Groups**: 방화벽 룰
- **Project → Network → Floating IPs**: 외부 접근용 IP 할당
- **Admin → Compute → Flavors**: VM 사양 템플릿 (관리자 전용)

### 인스턴스 생성 시 입력 항목

1. Details (이름, 가용 영역)
2. Source (이미지/볼륨)
3. Flavor (사양)
4. Networks (붙일 네트워크)
5. Security Groups
6. Key Pair
7. Configuration (cloud-init 스크립트)

---

## 9. 인스턴스 운영 실습

### 일반적인 실습 순서

1. 이미지 업로드 (CirrOS, Ubuntu cloud image)
2. Flavor 생성 (관리자)
3. External(Provider) 네트워크 생성
4. Self-Service 네트워크 + 서브넷 생성
5. 라우터 생성 → External 게이트웨이 연결 → Self-Service 인터페이스 추가
6. 보안그룹에 SSH(22), ICMP 허용 규칙 추가
7. Key Pair 생성/등록
8. 인스턴스 생성
9. Floating IP 할당
10. SSH 접속 확인 (`ssh -i key.pem cirros@<floating-ip>`)
11. 볼륨 생성 → 인스턴스에 attach → 마운트
12. 스냅샷 생성, 인스턴스 마이그레이션 등 고급 기능

---

## 10. CLI(openstack) 활용

### 환경변수 (admin-openrc)

```bash
export OS_USERNAME=admin
export OS_PASSWORD=password
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
```

### 자주 쓰는 명령어

```bash
# 서비스/엔드포인트 확인
openstack service list
openstack endpoint list
openstack catalog list

# 사용자/프로젝트
openstack user list
openstack project list
openstack role assignment list --names

# 이미지/플레이버
openstack image list
openstack flavor list

# 네트워크
openstack network list
openstack subnet list
openstack router list
openstack security group list

# 인스턴스
openstack server list
openstack server create --image cirros --flavor m1.tiny \
  --network private --key-name mykey --security-group default test-vm
openstack server show test-vm
openstack console url show test-vm

# 볼륨
openstack volume create --size 10 vol1
openstack server add volume test-vm vol1
```

---

## 11. 트러블슈팅 & 운영 팁

### 자주 보는 로그 위치

```
/var/log/keystone/
/var/log/glance/
/var/log/nova/
/var/log/neutron/
/var/log/cinder/
/var/log/apache2/  # Horizon
```

### 디버깅 체크리스트

- [ ]  시간 동기화 어긋남 → 토큰 에러
- [ ]  `/etc/hosts` 누락 → 서비스 통신 실패
- [ ]  RabbitMQ 권한/계정 문제
- [ ]  DB 동기화(`-manage db sync`) 누락
- [ ]  방화벽이 API 포트 차단
- [ ]  Compute 노드의 가상화 활성화 여부 (`egrep -c '(vmx|svm)' /proc/cpuinfo`)
- [ ]  Neutron 에이전트 상태 (`openstack network agent list`)
- [ ]  Nova 서비스 상태 (`openstack compute service list`)

### 일반 운영 팁

- `journalctl -u <service>.service -f` 로 실시간 로그
- 인증 실패 → 토큰 만료/시간 어긋남 의심
- 인스턴스 ERROR 상태 → Nova-Scheduler/Compute 로그 → Placement 자원 확인
- 네트워크 안 됨 → Security Group → Router → Floating IP → Provider 네트워크 순으로 확인

---

## 🔗 참고 자료

- 오픈스택 공식 문서: https://docs.openstack.org/
- 설치 가이드: https://docs.openstack.org/install-guide/
- Kolla-Ansible: https://docs.openstack.org/kolla-ansible/
- DevStack: https://docs.openstack.org/devstack/