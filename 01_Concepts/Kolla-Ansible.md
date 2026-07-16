---
title: "Kolla-Ansible"
type: "concept"
date: 2026-06-21
tags: ["#openstack", "#kolla-ansible", "#iac", "#docker"]
related_nodes: ["[[01_Concepts/OpenStack-Overview]]", "[[03_Guides/Kolla-Ansible-Install-Guide]]", "[[02_QnA_Archive/2026-06-28-kolla-ansible-deploy-troubleshooting]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-06-21-kolla-ansible-intro-raw]]"
---

# Kolla-Ansible

## 한 줄 정의

OpenStack의 모든 서비스를 Docker 컨테이너로 패키징하고, Ansible로 다수 노드에 자동 배포해주는 OpenStack 공식 배포 도구.

## 상세 설명

### 왜 만들어졌나

OpenStack은 서비스가 매우 많다 (Keystone, Nova, Neutron, Glance, Cinder, Swift, Octavia, RabbitMQ, MariaDB, Memcached...).

수동 설치 시 노드마다 이 과정을 반복해야 한다:
1. 패키지 설치
2. 설정 파일 수정 (`/etc/nova/nova.conf`, `/etc/neutron/neutron.conf` ...)
3. DB 초기화
4. 서비스 시작 (`systemctl start nova-api ...`)
5. 의존성 문제 해결
6. 노드마다 반복 (ct01, ct02, ct03, cp01, cp02, st01 ...)

Kolla-Ansible은 이 전 과정을 자동화한다:

```
globals.yml에 NIC 이름 두 개 적고
kolla-ansible deploy 실행
→ 30~60분 후 OpenStack 완성
```

### Kolla vs Ansible — 역할 분리

**Kolla — 이미지 담당**
- OpenStack 각 서비스를 Docker 이미지로 패키징해두는 프로젝트
- 컨테이너 단위로 버전 관리, 의존성 충돌 격리

```
quay.io/openstack.kolla/keystone
quay.io/openstack.kolla/nova-api
quay.io/openstack.kolla/neutron-server
...
```

**Ansible — 배포 담당**
- 각 노드에 SSH로 접속해서 이미지들을 실행하는 자동화 도구

```
deploy host (cjm-lb)
  │ SSH
  ├── ct01, ct02, ct03 → keystone, nova-api, neutron-server 컨테이너 실행
  ├── cp01, cp02       → nova-compute, ovs-agent 컨테이너 실행
  └── st01             → cinder-volume, swift 컨테이너 실행
```

### Ansible 핵심 개념

- **Inventory**: 어느 호스트에 무엇을 배포할지 정의하는 목록 파일 (`multinode`)
- **Playbook**: 실행할 작업 목록 (YAML). "어느 호스트에서 어떤 모듈을 어떤 순서로"
- **Role**: Playbook을 기능별로 모아둔 묶음 (예: `nova`, `neutron`, `keystone`)
- **globals.yml**: Kolla-Ansible의 핵심 설정 파일 — 어떤 서비스를 활성화할지, NIC는 무엇인지, VIP는 무엇인지 정의

### IaC (Infrastructure as Code)

Kolla-Ansible은 IaC 도구의 일종:
- **Terraform**: 인프라 자원 자체를 만드는 도구 (VM, 네트워크, 스토리지 생성)
- **Ansible**: 이미 존재하는 서버 안에 들어가서 설정·자동화 (Kolla가 이 방식)

## SU Cloud에서의 활용

- 운영계(P520): Proxmox VM 위에 Kolla-Ansible 멀티노드 배포 (ct01~ct03 + cp01~cp02 + st01)
- 개발계(Gaming5): 베어메탈에 Kolla-Ansible AIO(All-in-One) 배포
- OpenStack 릴리즈: **2026.1 (Gazpacho)**, Kolla-Ansible 22.0.0, Ubuntu 24.04
- SDN: OVN + Geneve, Cinder LVM, Swift, Octavia 구성

## 관련 개념

- [[01_Concepts/OpenStack-Overview]]
- [[01_Concepts/OVN-OVS-Architecture]]
- [[01_Concepts/HA-Concepts]]

## 참고 자료

- 배포 트러블슈팅: [[02_QnA_Archive/2026-06-28-kolla-ansible-deploy-troubleshooting]]
- 설치 가이드: [[03_Guides/Kolla-Ansible-Install-Guide]]
