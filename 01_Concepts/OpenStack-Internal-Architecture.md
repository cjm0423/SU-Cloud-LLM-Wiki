---
title: "OpenStack 내부 아키텍처 — Nova·RabbitMQ·Neutron OVN·Ceph"
type: "concept"
date: 2026-05-25
tags: ["#openstack", "#nova", "#rabbitmq", "#neutron", "#ceph"]
related_nodes: ["[[01_Concepts/OpenStack-Overview]]", "[[01_Concepts/OVN-OVS-Architecture]]", "[[01_Concepts/VXLAN]]", "[[01_Concepts/HA-Concepts]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-05-25-openstack-study-week3-raw]]"
---

# OpenStack 내부 아키텍처 — Nova·RabbitMQ·Neutron OVN·Ceph

## 한 줄 정의

OpenStack 핵심 서비스들의 내부 동작 원리: Nova VM 생성 흐름, RabbitMQ 비동기 메시지 큐, Neutron 네트워킹 레이어, Ceph 분산 스토리지.

## 상세 설명

### Nova VM 생성 흐름

**동기 호출 (실선 화살표):**
```
nova-api (요청 수신·토큰 검증)
    ↓
nova-conductor (DB 접근 중계)
    ↓
nova-scheduler (Filter/Weigh 알고리즘으로 배치 노드 선택)
    ↓
nova-compute (실제 VM 생성 및 실행)
```

**외부 서비스 연동 (RabbitMQ 비동기):**
- **Glance**: VM 부팅용 이미지 다운로드
- **Neutron**: 네트워크 포트 생성
- **Cinder**: 루트 볼륨(스토리지) 요청

**하이퍼바이저 계층:**
```
nova-compute
    ↓
libvirt (virsh define / virsh start → VM XML 정의)
    ↓
QEMU/KVM (qemu-system-x86_64 -enable-kvm)
  QEMU: VM 프로세스 실행·에뮬레이션
  KVM: CPU 하드웨어 가상화 위임
```

---

### RabbitMQ — 메시지 큐

**정의:** AMQP(Advanced Message Queuing Protocol) 기반 오픈소스 메시지 브로커. Nova, Neutron, Cinder 등 OpenStack 서비스 간 비동기 통신에 사용.

**핵심 구성 요소:**
| 구성 요소 | 역할 |
|----------|------|
| **Producer** | 메시지를 발행하는 생산자 (예: nova-api) |
| **Exchange** | 메시지를 받아 적절한 큐에 라우팅 |
| **Queue** | 메시지를 보관, 소비자에게 전달 |
| **Consumer** | 메시지를 구독하고 처리 (예: nova-compute) |
| **Binding** | Exchange가 큐로 라우팅할 때의 규칙 |

**VM 생성 시 흐름 예시:**
```
사용자 "VM 만들어줘"
    ↓ nova-api
RabbitMQ ["VM 스케줄링 해줘"]
    ↓ nova-scheduler
RabbitMQ ["cp01에 VM 만들어줘"]
    ↓ nova-compute(cp01)
실제 VM 생성
    ↓ Neutron
네트워크 연결
```

**HA 구성:** 3대 controller 각각에 컨테이너로 실행, 클러스터링 → [[01_Concepts/HA-Concepts]]

---

### libvirt — 하이퍼바이저 추상화

**정의:** KVM, QEMU, Xen, VMware 등 다양한 하이퍼바이저를 통합 관리하는 API/도구

**주요 명령어:**
```bash
virsh list --all          # 모든 VM 목록
virsh define vm.xml       # XML로 VM 정의
virsh start vm-name       # VM 시작
virsh snapshot-create-as  # 스냅샷 생성
```

---

### Neutron 네트워킹 레이어

**OVN 방식 (현재 SU Cloud):**
```
VM eth0 → tap → br-int (OVS)
    → Geneve 캡슐화 → Gateway Chassis (ct03)
        → br-ex → 외부망
```
→ 상세: [[01_Concepts/OVN-Network-Flow]], [[01_Concepts/OVN-OVS-Architecture]]

**LinuxBridge+VXLAN 방식 (수동 설치, 구형):**
```
VM → tap → brq-<net-id> → vxlan-N 터널
```

**VXLAN 개념:**
- Self-service network를 물리 네트워크 위에 오버레이하는 터널링 기술
- VNI(VXLAN Network Identifier)로 테넌트 네트워크 구분
- 상세: [[01_Concepts/VXLAN]]

---

### Ceph — 분산 스토리지

**정의:** 여러 서버에 데이터를 분산 저장하는 오픈소스 스토리지 시스템

**OpenStack 연동:**
| OpenStack 서비스 | Ceph 활용 |
|----------------|----------|
| Cinder | Block 스토리지 백엔드 (RBD) |
| Glance | 이미지 저장소 |
| Nova | Live migration 시 ephemeral 디스크 공유 |

**특징:**
- CRUSH 알고리즘으로 데이터 배치 결정 (중앙 디렉토리 없음)
- OSD(Object Storage Daemon), MON(Monitor), MDS(Metadata Server) 구성
- 3-way replication으로 고가용성 보장

**SU Cloud에서의 활용:**
- 현재 배포에는 Cinder LVM + Swift 사용 (Ceph 미사용)
- 대규모 확장 시 Ceph 도입 검토 예정

## SU Cloud에서의 활용

- Nova 배포: nova-api/conductor/scheduler → ct01~03 (controller), nova-compute → cp01~02
- RabbitMQ: 각 controller에 컨테이너로 클러스터 구성
- 네트워킹: OVN + Geneve (LinuxBridge 방식은 수동 설치 실습에서 사용)
- 스토리지: Cinder LVM (st01), Swift 오브젝트 스토리지 (st01)

## 관련 개념

- [[01_Concepts/OpenStack-Overview]]
- [[01_Concepts/OVN-OVS-Architecture]]
- [[01_Concepts/OVN-Network-Flow]]
- [[01_Concepts/VXLAN]]
- [[01_Concepts/HA-Concepts]]
- [[01_Concepts/Kolla-Ansible]]
