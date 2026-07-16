---
title: "Openstack 공부2 - 3 week"
type: "raw"
date: 2026-05-25
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[01_Concepts/OpenStack-Internal-Architecture]]"
---
# Openstack 공부2 - 3 week

## Nova

![KakaoTalk_20260524_095122853_01.jpg](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/KakaoTalk_20260524_095122853_01.jpg)

### VM 생성 흐름

**1) Nova 내부 컴포넌트 (동기 호출, 실선 화살표)**

요청이 순차적으로 흐릅니다:

- **nova-api**: 요청 수신 및 토큰 검증
- **nova-conductor**: DB 접근 중계 역할
- **nova-scheduler**: Filter/Weigh 알고리즘으로 VM을 배치할 노드 선택
- **nova-compute**: 실제 VM 생성 및 실행 담당

**2) 외부 서비스 연동 (비동기/API 호출, 점선 화살표)**

RabbitMQ(AMQP) 메시지 큐를 통해 다른 OpenStack 서비스와 통신합니다:

- **Glance**: VM 부팅용 이미지 다운로드
- **Neutron**: 네트워크 포트 생성
- **Cinder**: 루트 볼륨(스토리지) 요청

**3) 하이퍼바이저 계층**

nova-compute가 VM 생성을 결정하면:

- **libvirt**: `virsh define`, `virsh start` 명령으로 VM XML을 정의하고 제어하는 하이퍼바이저 추상화 계층
- **QEMU/KVM**: `qemu-system-x86_64 -enable-kvm` 명령으로 실제 VM 실행
    - QEMU는 VM 프로세스 실행 및 에뮬레이션
    - KVM은 CPU 하드웨어 가상화 위임
- **RabbitMQ란?**
    - 참고자료
        
        https://velog.io/@sdb016/RabbitMQ-%EA%B8%B0%EC%B4%88-%EA%B0%9C%EB%85%90
        
        https://hoestory.tistory.com/85
        
    
    **메시지 큐**(Message Queue)를 통해 여러 애플리케이션에 데이터를 주고받을 수 있도록 해주기 위한 **AMQP**의 오픈소스 메시지 브로커
    
    **AMQP:** Advanced Message Queuing Protocol의 약자로 생산자(Producer)와 수신자(Consumer) 사이에서 메시지를 안전하게 교환하는 메시지 지향 미들웨어 개방형 프로토콜입니다.
    
    ![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image.png)
    
    - Producer : 메시지를 발행하는 생산자
    - Exchange : 생산자가 발행한 메시지를 보관하고 있다가 알맞은 큐에 전달하는 매개체
    - Queue : 생산자가 발행한 메시지를 보관하고 있다가 소비자가 소비할 때 소비자에게 전달
    - Consumer : 생산자가 발행한 메시지를 구독하고 사용하는 소비자
    - Binding : Exchange에게 알맞은 큐에 메시지를 라우팅 할 때 규칙을 지정하는 행위, Exchange의 종류에 따라 지정하는 방식이 달라집니다.
- **libvert란?**
    - 참고자료
        
        https://somaz.tistory.com/122
        
        https://computing-jhson.tistory.com/89#google_vignette
        
    
    ![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%201.png)
    
    **libvirt**는 virtualization platforms을 관리하기 위한 도구로,Qemu-KVM, Xen, VMware 등 다양한 hypervisor들 작동시키기 위한 통합 API이다.
    
    - 특징
        - KVM, QEMU, Xen, VMware, Hyper-V등 다양한 하이퍼바이저 지원
        - 가상 머신의 생성, 삭제, 스냅샷, 마이그레이션 등 다향한 기능 제공
        - virsh, virt-manager, libvirt API 등을 활용한 관리 가능
    
    ![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%202.png)
    
    **Qemu-KVM 이란?**
    
    https://somaz.tistory.com/121
    
    https://chanchan01.tistory.com/11
    

## Neutron

- Hardware 스위치 구성도

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%203.png)

### Neutron + OVS(Open vSwitch) - 전통적 방식

![KakaoTalk_20260524_095122853_02.jpg](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/KakaoTalk_20260524_095122853_02.jpg)

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%204.png)

**Control Plane (제어 흐름)**

요청은 위쪽 파이프라인을 따라 흐릅니다:

- **neutron-server**: REST API 수신, 논리 네트워크 DB 관리
- **ML2 plugin**: mechanism driver로 `openvswitch`를 사용
- **RabbitMQ**: RPC 메시지 큐로 명령을 각 노드에 전달

**Data Plane (compute/network 노드에서 실제 동작)**

- **neutron-ovs-agent**: 각 노드에 상주하면서 RabbitMQ로 RPC를 수신하고, OVS 흐름을 **직접** 설정
- **Open vSwitch 브릿지 3종**:
    - `br-int`: VM 포트 연결 (통합 브릿지)
    - `br-tun`: VXLAN 터널 (노드 간 오버레이 통신)
    - `br-ex`: 외부망 연결
- 각 브릿지에 `ovs-ofctl`, `ovs-vsctl` 명령으로 OpenFlow 룰을 직접 주입

**핵심 특징**: 모든 compute/network 노드마다 **agent가 상주**하면서 RPC를 받아 OVS를 명령줄 도구로 일일이 설정. Neutron-server가 모든 변경사항을 RabbitMQ로 broadcast하는 구조.

### Neutron + OVN(Open Virtual Network) - 현대적 방식

https://kwonkwonn.tistory.com/3

![KakaoTalk_20260524_095122853_03.jpg](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/KakaoTalk_20260524_095122853_03.jpg)

- **CMS:** 클라우드 상에서 가상 네트워크 서버에 대한 플러그인이라고 이해
- **OVN Northbound daemon/DB:** OVN에서는 가상 네트워크를 현대 물리네트워크의 구조와 유사한 형태로 받아들인다.
L3 스위치를 사용자가 요청하면, 이 논리적인 장비를 northbound DB에 저장하는 식.
- **OVN Southbound daemon/DB:** OVN Southbound DB는 언더레이 네트워크와 가상네트워크를 잇는 부분.
논리적인 구조를 동작하게 하려면, 어떤 포트에 논리적인 장비가 연결되어 있는지와 같은 정보를 가지고 있을 필요가 있다.
Northbound DB는 논리 장비가 업데이트 되면, 이를 southbound 에 알리고, 이 가상 디바이스의 기능을 분해하여 southbound 는 논리장비를 어떻게 해석하여 업데이트를 할지 결정하는데 참여한다.
- **OVN-Controller:** OVN controller 는 각 장비에서 어떻게 데이터를 처리 할지를 결정. 또한, 가상네트워크 특성상 어떤 장비에서 새로 만든 장비가 구동되어야 할 지 정해지지 않기 때문에, 새로운 인터페이스가 감지되었다거나, 연결 상태들의 변화를 southbound 에 보고하는 역할도 진행.
- **OVS-vswitchd/ovsdb-server:** OVN은 결국 OVS라는 블록을 사용해 추상화된 네트워크를 제공하는 프로젝트. 이 모듈들은 전달 되는 정보를 기반으로 노드 정보를 저장하거나, 실제 가상네트워크 동작에 참여하는 모듈임.

**Control Plane**

- **neutron-server**: 동일 (REST API 수신, 논리 네트워크 DB 관리)
- **ML2 plugin**: mechanism driver가 `ovn`으로 바뀜
- **OVN Northbound DB**: 논리 스위치/라우터/포트/ACL을 저장 (사용자가 정의한 "원하는 상태")
- **ovn-northd**: 논리 정의를 물리적 흐름으로 **변환**해서 Southbound DB에 갱신
- **OVN Southbound DB**: Logical Flow와 바인딩 정보 저장 (실제 적용될 상태)
- **OVN의 Northbound/Southbound DB 분리**
    
    분리 이유: "논리"와 "물리"를 분리하기 위해서
    
    ```jsx
    사용자 의도 (논리)
        ↓
    [Northbound DB] ← "이런 네트워크를 원해요"
        ↓
    [ovn-northd] ← 번역기
        ↓
    [Southbound DB] ← "그럼 각 호스트는 이렇게 동작해야 해요"
        ↓
    실제 호스트들 (물리)
    ```
    
    ### Northbound DB: "원하는 것"의 세계
    
    **저장하는 것** (논리적, 추상적):
    
    - **Logical Switch**: "프론트엔드 네트워크"
    - **Logical Router**: "프론트엔드와 백엔드를 연결하는 라우터"
    - **Logical Switch Port**: "VM1이 연결될 포트, IP는 10.0.0.5"
    - **ACL**: "포트 80은 허용, 22는 거부"
    - **Load Balancer**: "이 VIP는 이 백엔드들로 분산"
    
    **특징**:
    
    - **물리적 위치에 대한 정보가 전혀 없음**. VM이 어느 호스트에 있는지, 터널이 어떻게 뚫려야 하는지 모릅니다.
    - 사용자(Neutron)가 보는 추상화 수준
    - 그래서 **선언적(declarative)**: "이렇게 됐으면 좋겠어"만 기술
    
    ### ovn-northd: 번역기
    
    **역할**: Northbound DB의 논리 정의를 읽어서 **Logical Flow**라는 중간 표현으로 변환하고, Southbound DB에 씁니다.
    
    **핵심 작업**: "이 논리 스위치에 포트가 3개 있다 → 그럼 MAC 학습 테이블은 이렇고, 브로드캐스트는 이렇게 처리하고, ACL은 이런 흐름으로..."
    
    이건 매우 복잡한 작업입니다. 사용자가 만든 단순한 "스위치 + 포트 3개"가 실제로는 **수십 개의 OpenFlow 룰**로 펼쳐져야 하거든요. ovn-northd가 그걸 자동으로 풀어줍니다.
    
    **중요**: 이 시점까지도 **여전히 물리적 위치는 모릅니다**. Logical Flow는 "이런 논리적 흐름이 있어야 한다"는 추상 표현이에요.
    
    ### Southbound DB: "어떻게 할지"의 세계
    
    **저장하는 것**:
    
    1. **Logical Flow**: ovn-northd가 만든 추상 흐름 규칙
        - 예: "목적지 MAC이 X면 포트 Y로 보내라" (논리 포트 기준)
    2. **Chassis**: 물리 호스트 목록
        - 각 compute 노드가 자기 자신을 여기 등록 ("나 compute-3이야, 내 IP는 192.168.1.13")
    3. **Port Binding**: **논리 포트 ↔ 물리 호스트 매핑**
        - "VM1의 포트는 compute-3에 있어"
        - 이게 **연결고리**입니다 ⭐
    4. **MAC Binding**: ARP 학습 결과 캐싱
    
    **특징**:
    
    - 논리와 물리가 **만나는 지점**
    - 모든 ovn-controller가 이 DB를 구독함
    - "여기 모든 정보가 다 있어, 각자 필요한 거 가져가"

**Data Plane (각 compute 노드)**

- **ovn-controller**: Southbound DB를 구독(subscribe)하다가 변경이 감지되면 OVS flows를 자동 주입
- **Open vSwitch**: 흐름 테이블을 실행 — 별도 agent 없이 자동

**핵심 특징**: RabbitMQ도 없고, neutron-ovs-agent도 없다. 대신 **DB 기반 pub/sub 모델**로 동작. 각 노드의 ovn-controller가 SB DB를 구독하다가 변경을 감지해서 자기 노드의 OVS만 업데이트.

- **Geneve(Generic Network Virtualization Encapsulation)**
    
    OVN에서 호스트 간 통신에 사용하는 터널 프로토콜
    
    ```jsx
    [VM-A: 10.0.0.5]              [VM-B: 10.0.0.6]
        ↓                              ↓
    [compute-1: 192.168.1.11]    [compute-2: 192.168.1.12]
                  ↑                ↑
                  └── 물리 네트워크 ──┘
    ```
    
    VM-A와 VM-B는 같은 가상 네트워크(10.0.0.0/24)에 있다고 **믿고** 있어요. 하지만 실제로는 서로 다른 물리 서버에 있고, 그 사이에는 물리 네트워크(192.168.1.0/24)가 있죠.
    
    문제: VM-A가 10.0.0.6으로 패킷을 보내면, 물리 네트워크 라우터는 "10.0.0.0/24가 어디 있는지 모르는데?" 합니다. 물리 네트워크는 가상 네트워크의 존재조차 모르거든요.
    
    **해결책: 캡슐화(Encapsulation)**. VM의 패킷을 통째로 물리 네트워크용 패킷 안에 **포장**해서 보내는 거예요. 물리 네트워크 입장에서는 그냥 "서버끼리 주고받는 일반 패킷"으로 보이고, 받는 쪽에서 포장을 뜯어서 안의 VM 패킷을 꺼냅니다.
    
    이 포장 방식이 바로 **터널 프로토콜**입니다.
    
    ### 패킷이 실제로 어떻게 생겼나
    
    VM-A가 VM-B에게 보내는 패킷을 따라가봅시다:
    
    **1) VM이 만든 원본 패킷**
    
    ```jsx
    [Ether: src=VM-A_MAC, dst=VM-B_MAC]
    [IP: src=10.0.0.5, dst=10.0.0.6]
    [TCP/UDP/...: 페이로드]
    ```
    
    **2) compute-1의 OVS가 Geneve로 캡슐화**
    
    ```jsx
    [Ether: src=compute-1_MAC, dst=compute-2_MAC]   ← 물리 이더넷
    [IP: src=192.168.1.11, dst=192.168.1.12]        ← 물리 IP
    [UDP: dst_port=6081]                             ← Geneve 표준 포트
    [Geneve Header: VNI, options...]                 ← 가상 네트워크 식별자
    [원본 패킷 전체가 여기 통째로 들어감] ← payload
    ```
    
    물리 네트워크는 바깥쪽 헤더만 보고 "compute-1 → compute-2" 일반 UDP 패킷이라고 생각하고 전달합니다.
    
    **3) compute-2의 OVS가 받아서 포장을 벗김**
    
    - Geneve 헤더 확인 → "이건 VNI=5인 가상 네트워크 거구나"
    - 안의 원본 패킷을 꺼냄
    - VNI 5에 속한 로컬 VM(VM-B)에게 전달
    
    VM-B는 자기가 받은 게 캡슐화돼서 왔다는 걸 **전혀 모릅니다**. 그냥 "VM-A에서 직접 받은 것"처럼 보이죠.
    
    ### Geneve 헤더의 구조
    
    ```jsx
     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |Ver|  Opt Len  |O|C|    Rsvd.  |          Protocol Type        |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |        Virtual Network Identifier (VNI)       |    Reserved   |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    |                    Variable Length Options                    |
    +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    ```
    
    핵심 필드:
    
    - **VNI (24비트)**: 가상 네트워크 ID. 2^24 ≈ 1600만 개의 가상 네트워크 식별 가능
    - **Options**: 가변 길이 — 이게 Geneve의 핵심 차별점입니다 ⭐
    - **Protocol Type**: 안에 든 패킷 종류 (이더넷, IP 등)
    
    ### Geneve vs VXLAN: 왜 OVN은 Geneve를 쓰나?
    
    여기가 중요한 부분이에요. 사진 1의 OVS 방식에서는 `br-tun`이 보통 **VXLAN**을 썼는데, OVN은 **Geneve**를 기본으로 합니다. 왜일까요?
    
    **VXLAN의 한계**: 헤더가 **고정 크기**예요. VNI 24비트 + 약간의 예약 필드, 끝. 추가 정보를 실을 공간이 없습니다.
    
    **Geneve의 강점**: **Variable Length Options**. 헤더에 임의의 메타데이터를 붙일 수 있어요. OVN은 이걸 적극 활용합니다:
    
    - **논리 입력 포트 (Logical Ingress Port)**: "이 패킷은 VM-A의 포트에서 시작됐어"
    - **논리 출력 포트 (Logical Egress Port)**: "VM-B의 포트로 가야 해"
    - **기타 컨트롤 메타데이터**
    
    왜 이게 중요하냐? 받는 쪽 ovn-controller가 **이 패킷이 어떤 논리 흐름의 일부인지 즉시 알 수 있어요**. VXLAN이었다면 받은 후에 "이게 어느 논리 포트지?" 다시 계산해야 합니다.
    
    ### Geneve vs VXLAN vs GRE 비교표
    
    | 항목 | GRE | VXLAN | Geneve |
    | --- | --- | --- | --- |
    | **전송 프로토콜** | IP 위 직접 | UDP (4789) | UDP (6081) |
    | **VNI 크기** | 32비트 (Key) | 24비트 | 24비트 |
    | **헤더 크기** | 4~8바이트 | 8바이트 고정 | 8바이트 + 가변 옵션 |
    | **확장성** | 거의 없음 | 없음 | 우수 (옵션) |
    | **하드웨어 오프로드** | 광범위 | 광범위 | 점차 확대 중 |
    | **OVN 사용** | ❌ | 가능하지만 비권장 | ✅ 기본 |
    | **표준화** | RFC 2784 | RFC 7348 | RFC 8926 |

#### 비교

| 구분 | OVS 방식 (사진 1) | OVN 방식 (사진 2) |
| --- | --- | --- |
| **통신 방식** | RabbitMQ RPC (push) | DB 구독 (pull/watch) |
| **노드별 에이전트** | neutron-ovs-agent 필요 | ovn-controller만 (경량) |
| **L3 라우팅** | 별도 l3-agent 필요 | OVN 내장 (분산 라우팅) |
| **상태 모델** | 명령형 (각 노드에 명령 전달) | 선언형 (원하는 상태 정의 → 알아서 수렴) |
| **확장성** | RabbitMQ 병목 가능 | DB 기반이라 더 잘 확장됨 |

## VLAN 기반 Network 격리

![KakaoTalk_20260524_095122853_05.jpg](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/KakaoTalk_20260524_095122853_05.jpg)

**`Router (Mikrotik)`** : Mikrotik은 VLAN, 고급 라우팅, 방화벽을 제대로 지원하는 전문 네트워크 장비

색깔 별 6개 VLAN이 정의

| 색 | VLAN | 용도 |
| --- | --- | --- |
| ⚫ 검정 | **Node Mgmt VLAN** | 노드 자체 관리 (SSH, 모니터링 등 호스트 OS 접근) |
| 🟠 주황 | **Service Mgmt VLAN** | OpenStack 서비스 간 통신 (API 호출, RabbitMQ 등) |
| 🔴 빨강 | **Storage VLAN** | 스토리지 트래픽 (Cinder 볼륨, Ceph 등) |
| 🔵 파랑 | **Virtual Network VLAN** | 테넌트 VM 간 통신 (Geneve/VXLAN 오버레이가 여기 실림) |
| 🟢 초록 | **Provider VLAN** | 물리 네트워크와 직접 연결되는 프로바이더 네트워크 |
| 🟣 보라 | **External VLAN** | 외부 인터넷 연결 (Floating IP, 외부 게이트웨이) |

각 노드(compute/control/storage)로 가는 VLAN 역할

- **compute**: VM을 돌리니까 Virtual Network, Provider, External 등 대부분 필요
- **control**: API/서비스 관리가 핵심이니 Service Mgmt, Node Mgmt 위주
- **storage**: Storage VLAN이 핵심

## Ceph

https://computing-jhson.tistory.com/112#google_vignette

https://hdbstn3055.tistory.com/398

https://yeti.tistory.com/240

오픈소스 분산 스토리지 플랫폼으로 단일 분산 컴퓨터 클러스터에 오브젝트 스토리지를 구현하고 object, block 및 file level의 스토리지 기능을 제공

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%205.png)

- **MON (Ceph Monitor)**
    - 클러스터의 결정적 상태 정보를 관리하는 역할
    - Ceph 스토리지 클러스터의 현재 상태에 대한 Ceph 스토리지 클러스터 맵의 마스터 복사본을 유지
    - 모니터에는 높은 일관성이 필요하며, Ceph 스토리지 클러스터의 상태에 대한 합의를 보장하기 위해 `Paxos` 알고리즘 사용
    - 클러스터의 전체적인 상태 및 OSD 맵, CRUSH 맵, 인증 정보를 관리하는 핵심 컴포넌트
- **OSD (Object Storage Daemon)**
    - Ceph 클라이언트를 대신하여 데이터를 저장
    - Ceph 노드의 CPU, 메모리 및 네트워킹을 활용하여 data replication, erasure coding, rebalancing, recovery, monitoring 및 report 기능을 수행
    - 실제 데이터 object가 저장되는 노드(컴퓨터)
- **MDS (Metadata Server)**
    - Ceph File System(CephFS)에 저장된 파일과 관련된 메타데이터를 저장 및 관리
- **MNG (Ceph Manager)**
    - 실시간 운영 데이터를 수집하는 역할과 Monitor의 부하를 줄여주는 역할

#### Ceph Interface

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%206.png)

- **RADOS (Reliable Autonomic Distributed Object Store) - Ceph Object Gateway**
    - Ceph 스토리지 클러스터에 대한 RESTful 게이트웨이를 애플리케이션에 제공하기 위해 `librados` 라이브러리에 빌드된 **Object Storage Interface**
    - Ceph에서 object read/write 할 때 사용
- **RADOS Block Device (RBD)**
    - RADOS 상에 block device image를 만들 수 있도록 제공하는 서비스
    - **Block Device Storage Interface**로서, 특히 클라우드 상 가상머신의 image로 활용
- **CephFS (File System)**
    - RADOS 상에 File system을 사용할 수 있도록 제공하는 서비스
    - **File Storage Interface**로서, POSIX와 호환되는 API를 제공
    - CephFS에 저장된 파일과 관련된 메타데이터(directories, file ownership, access modes, etc)는 MDS에서 관리

#### 파일 저장 방식

![다운로드.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/%EB%8B%A4%EC%9A%B4%EB%A1%9C%EB%93%9C.png)

- Date Write

```jsx
사용자가 파일 하나를 Ceph 파일 시스템에 저장
												↓
Ceph가 자동으로 파일을 여러 object들로 나눈다 (각 object에 object ID 부여)
												↓
Ceph가 객체 저장을 위해 만든 논리적인 파티션인 Pool에 object들을 넣는다
												↓
object ID를 기반으로 각각의 object들은 PG에 할당 (CRUSH 알고리즘을 통해 해당 PG는 어떤 OSD들에 저장되는 지를 계산)
												↓
Ceph는 모든 object를 여러 OSD에 안전하게 중복 저장 후 사용자에게 파일 object들의 ID를 전달
```

- Date Read

```jsx
사용자가 파일을 읽고자 한다.
												↓
자신의 object들의 ID를 이용해 직접 <PG정보+CRUSH 알고리즘>를 통해 어떤 OSD에 저장되어 있는 지를 알 수 있다.
												↓
이 정보를 바탕으로 사용자는 해당 OSD에 데이터를 달라고 요청
```

---

## 3-tier architecture app 배포

### 1. network 만들기

- Public network

```bash
openstack network create public \
  --external \
  --provider-network-type flat \
  --provider-physical-network public

openstack subnet create public-subnet \
  --network public \
  --subnet-range 172.24.4.0/24 \
  --gateway 172.24.4.1 \
  --no-dhcp \
  --allocation-pool start=172.24.4.10,end=172.24.4.200
```

- private network

```bash
openstack network create public

openstack subnet create private-subnet \
  --network private \
  --subnet-range 10.0.0.0/26
```

- Router

```bash
openstack router create router1
openstack router set router1 --external-gateway public
openstack router add subnet router1 private-subnet
```

### 2. Image 만들기 (ubuntu)

```bash
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

openstack image create "ubuntu-22.04" \
  --file jammy-server-cloudimg-amd64.img \
  --disk-format qcow2 \
  --container-format bare \
  --public
```

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%207.png)

### 3. Flavor 만들기

```bash
openstack flavor create --id 3 --ram 2048 --disk 10 --vcpus 1 ubuntu.small
```

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%208.png)

### 4. keypair 만들기

```bash
cd ~
openstack keypair create mykey > keypair.pem
chmod 600 keypair.pem
```

### 5. Nova Instance 만들기

```bash
openstack server create ubuntu-vm \
  --image ubuntu-22.04 \
  --flavor ubuntu.small \
  --key-name mykey \
  --network private
```

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%209.png)

- Instance가 만들어 졌으나 status error가 남. (nova의 cell 매핑이 깨진 상태)

```bash
openstack server show ubuntu-vm -c fault

code : 400 / message : 'Host controller' is not mapped to any cell 
```

- 트러블슈팅 과정
    
    ```bash
    source ~/devstack/openrc admin admin
    
    # nova-compute up 상태 확인
    openstack compute service list 
    
    # cell에 호스트를 등록(discover)
    sudo nova-manage cell_v2 discover_hosts --verbose 
    
    # mapping 확인 - controller 호스트가 cell과 함께 뜨면 성공
    sudo nova-manage cell_v2 list_hosts 
    
    # nova scheduler/API 재시작
    sudo systemctl restart devstack@n-sch devstack@n-api devstack@n-cpu
    ```
    
    - 원인 : `./stack.sh`를 재실행한 것
    - nova는 compute 호스트들을 "cell"이라는 단위로 묶어서 관리합니다. 인스턴스를 만들면 nova 스케줄러가 "어느 cell의 어느 compute 호스트에 올릴까"를 찾는데, 이때 **compute 호스트가 cell에 등록(매핑)돼 있어야** 보입니다. `discover_hosts`라는 과정이 새로 생긴 compute 호스트를 찾아서 cell에 연결해주는 작업이에요.
    - 재부팅하면서 nova의 상태(DB에 기록된 호스트-cell 매핑이나 compute 서비스 등록 정보)가 어긋난 상태가 됐고, 그 위에서 `./stack.sh`를 다시 돌렸습니다. 재실행 시 DB가 일부 초기화되거나 compute 서비스 등록 순서가 꼬이면, compute 호스트는 떠 있는데 cell에는 등록이 안 된 어정쩡한 상태가 남습니다. 그래서 스케줄러가 "controller라는 호스트가 어느 cell에도 매핑돼 있지 않다"며 인스턴스 배치를 거부한 거예요. 그게 `'Host controller' is not mapped to any cell` 메시지입니다.
    - 재발하지 않을 두 가지 방법
        - VM을 끄지 말고 VirtualBox의 "스냅샷" 또는 "상태 저장"으로 일시정지했다 재개
        - 재부팅 후 `./stack.sh`를 다시 돌리기보다 죽은 서비스만 `sudo systemctl restart devstack@*` 실행

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%2010.png)

### 6. Floating IP 붙이기

```bash
# floating IP 하나 생성
openstack floating ip create public

# 인스턴스에 붙이기 (위에서 나온 IP를 넣으세요)
openstack server add floating ip ubuntu-vm 172.24.4.39
```

- SSH 22포트 열기

```bash
# default 보안그룹에 규칙 추가
openstack security group rule create --proto tcp --dst-port 22 <보안그룹 이름>
openstack security group rule create --proto icmp <보안그룹 이름>
```

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%2011.png)

- 접속

```bash
# 확인
ping <floating-ip>

# SSH 접속
ssh -i ~/keypair.pem ubuntu@<floating-ip>
```

- ping에 대한 pong이 안오고 ssh 접속도 실패
- 트러블슈팅
    
    ```bash
    # br-ex가 살아있고 IP를 갖고 있는지 확인
    sudo ovs-vsctl show
    ip addr show br-ex
    ```
    
    - `br-ex`에 `172.24.4.1`이 안잡혀 있었음
    
    ```bash
    # 수동으로 ip 잡기
    sudo ip addr add 172.24.4.1/24 dev br-ex
    sudo ip link set br-ex up
    ```
    
    - 이후 ping-pong 이랑 ssh 접속 성공
    - OVN에서 floating IP 트래픽은 namespace가 아니라 **`br-ex` 브리지**를 통해 흐릅니다. `ip addr show br-ex`를 확인하니 br-ex가 IP도 없고 link도 DOWN(`<BROADCAST,MULTICAST>`만) 상태였습니다. **재부팅으로 br-ex 설정이 날아간 게 진짜 원인**이었어요. floating IP 대역(172.24.4.x)으로 가는 관문이 끊겨 있던 거죠.
    

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%2012.png)

### 7. Docker compose 진행

- Nova instance에서 진행하려 했으나 이중 NAT 구조라 NAT 처리량 한계
- 인스턴스 → br-ex NAT → VirtualBox NAT → 호스트 → 인터넷

```bash
ubuntu@ubuntu-vm:~$ curl -o /dev/null http://archive.ubuntu.com/ubuntu/dists/jammy/InRelease
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  **263k**  100  263k    0     0   1995      0  0:02:15  **0:02:15** --:--:-- 73353
```

- virtualbox vm에서 Docker compose 실행
- docker-compose.yml
    
    ```yaml
    services:
      db:
        image: mysql:8.0
        container_name: capstone-db
        environment:
          MYSQL_DATABASE: ${MYSQL_DATABASE}
          MYSQL_USER: ${MYSQL_USER}
          MYSQL_PASSWORD: ${MYSQL_PASSWORD}
          MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
          TZ: Asia/Seoul
        volumes:
          - db-data:/var/lib/mysql
        # ports: 3306 publish 안 함 (controller MySQL과 충돌 방지)
        healthcheck:
          test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
          interval: 10s
          timeout: 5s
          retries: 10
          start_period: 30s
        restart: unless-stopped
    
      app:
        build:
          context: .
          dockerfile: Dockerfile
        container_name: capstone-app
        depends_on:
          db:
            condition: service_healthy
        environment:
          SPRING_DATASOURCE_URL: jdbc:mysql://db:3306/${MYSQL_DATABASE}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Seoul&characterEncoding=UTF-8
          SPRING_DATASOURCE_USERNAME: ${MYSQL_USER}
          SPRING_DATASOURCE_PASSWORD: ${MYSQL_PASSWORD}
          SPRING_DATASOURCE_DRIVER_CLASS_NAME: com.mysql.cj.jdbc.Driver
          SPRING_JPA_HIBERNATE_DDL_AUTO: update
          SPRING_JPA_DATABASE_PLATFORM: org.hibernate.dialect.MySQLDialect
          SPRING_SQL_INIT_MODE: always
          SPRING_JPA_DEFER_DATASOURCE_INITIALIZATION: "true"
          GITHUB_BASE_URL: https://api.github.com
          GITHUB_DEFAULT_OWNER: octocat
          GITHUB_DEFAULT_REPO: Hello-World
          GITHUB_DEFAULT_BRANCH: main
          TZ: Asia/Seoul
        # ports 제거: 호스트에 8080 노출 안 함. nginx만이 접근 가능
        expose:
          - "8080"   # 내부 네트워크에만 노출 (문서화 목적, 사실 생략해도 됨)
        restart: unless-stopped
    
      nginx:
        image: nginx:1.27-alpine
        container_name: capstone-nginx
        depends_on:
          - app
        ports:
          - "80:80"
        volumes:
          - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
        restart: unless-stopped
    
    volumes:
      db-data:
    ```
    
- nginx.conf
    
    ```bash
    events {}
    
    http {
        resolver 127.0.0.11 valid=10s ipv6=off;
    
        server {
            listen 80;
            server_name _;
    
            location / {
                set $upstream_app http://app:8080;
                proxy_pass         $upstream_app;
                proxy_http_version 1.1;
                proxy_set_header   Host              $host;
                proxy_set_header   X-Real-IP         $remote_addr;
                proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
                proxy_set_header   X-Forwarded-Proto $scheme;
            }
    
            location /ws-chat {
                set $upstream_ws http://app:8080;
                proxy_pass         $upstream_ws;
                proxy_http_version 1.1;
                proxy_set_header   Host       $host;
                proxy_set_header   Upgrade    $http_upgrade;
                proxy_set_header   Connection "upgrade";
                proxy_read_timeout 3600s;
                proxy_send_timeout 3600s;
            }
        }
    }
    ```
    

```bash
docker compose up -d --build

docker compose ps
```

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%2013.png)

- `http://192.168.56.101` 브라우저 접속

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%2014.png)

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%2015.png)

### Network flow

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%2016.png)

![image.png](Openstack%20%EA%B3%B5%EB%B6%802%20-%203%20week/image%2017.png)

**이 3 tier architecture에서 고가용성을 위해 어떠한 부분을 중복으로 두는지, 아니면 어떠한 방법이 있는지**