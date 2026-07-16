---
title: "Devstack 실습 & Openstack 공부 - 2 week"
type: "raw"
date: 2026-05-18
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[01_Concepts/OpenStack-Overview]]"
---
# Devstack 실습 & Openstack 공부 - 2 week

## Devstack 실습

https://jsyeo.tistory.com/entry/OpenStack%EC%9D%84-%EC%9D%B4%EC%9A%A9%ED%95%B4-%EB%A1%9C%EC%BB%AC-%ED%99%98%EA%B2%BD%EC%97%90-%ED%81%B4%EB%9D%BC%EC%9A%B0%EB%93%9C-%EC%8B%9C%EC%8A%A4%ED%85%9C-%EA%B5%AC%EC%B6%95%ED%95%98%EA%B8%B0

[2주차(DevStack 환경 구성)](../%EC%82%AC%EC%A0%84%ED%95%99%EC%8A%B5%20%EC%A0%95%EB%A6%AC/%EC%82%AC%EC%A0%84%ED%95%99%EC%8A%B5/2%EC%A3%BC%EC%B0%A8(DevStack%20%ED%99%98%EA%B2%BD%20%EA%B5%AC%EC%84%B1)%20361d8e51100c8017b50ce21615b41472.md) 

‣

Openstack Nova Instance을 3대 만들었으나 2대만 Running되고 한 대는  Shut Down 되었다. 그리고 아래처럼 메모리 부족 로그 발생

```jsx
[2721.742706] Out of memory: Killed process 56994 (mysqld) total-vm: 2994520KB, anon-rss: 700060KB,  file-rss:0KB, shmem-rss:0KB, UID:120 pgtables:2064KB oom_score_adj:0

[2748.357321] Out of memory: Killed process 113241 (qmeu-system-x86) total-vm: 1426856KB, anon-rss: 524372KB,  file-rss:1540KB, shmem-rss:0KB, UID:64055 pgtables:1444KB oom_score_adj:0
```

원인: Openstack Service들이 6GB의 메모리를 다 잡아먹고 있어, 남은 메모리로 vm이 2대만 만들어지고, 가장 큰 프로세스 (mysqld, qmeu)를 죽임

---

## Openstack 공부

- Openstack Architecture
    
    ![openstack_architecture1.jpg](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/openstack_architecture1.jpg)
    
    ![openstack_architecture2.png](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/openstack_architecture2.png)
    

### NAT(Network Address Translation) Network

https://inpa.tistory.com/entry/WEB-%F0%9F%8C%90-NAT-%EB%9E%80-%EB%AC%B4%EC%97%87%EC%9D%B8%EA%B0%80

사설 네트워크의 호스트가 외부의 공개된 네트워크에 연결할 수 있도록 상호 간에 주소를 변환해 주는 기술

- 사용 이유: IPv4 주소 부족
- NAT를 사용하면 하나의 공인 IP 주소를 여러 기기가 공유할 수 있음.
- 외부에서 내부로 접속하려면 Port Forwarding 필요

#### 사설 IP 주소 대역

NAT와 함께 쓰이는 사설 IP 주소 대역(RFC 1918)

- `10.0.0.0 ~ 10.255.255.255` (10.0.0.0/8)
- `172.16.0.0 ~ 172.31.255.255` (172.16.0.0/12)
- `192.168.0.0 ~ 192.168.255.255` (192.168.0.0/16)

#### 사용 예시

1. 위키피디아라는 사이트에 접속하고 싶으면, 컴퓨터는 Gateway addr에 해당되는 IP 머신(공유기)에게 신호를 보낸다.
2. 공유기는 먼저 요청 받은 내부ip를 기록한다. (192.168.0.4). 누가 요청했는지 알아야하기 때문.
3. 요청한 컴퓨터 ip는 외부에서 접속할 수 없는 사설ip이다. 따라서 사설ip를 공인ip로 변환한다.
4. 공유기는 이 요청을 public ip address 로 위키피디아에게 요청을 하고 위키피디아는 그 요청을 처리한다.
5. 위키피디아에서 보낸 응답을 공유기가 받아 다시 사설 ip로 변환해 사설 ip에 해당하는 컴퓨터로 보낸다.

![image.png](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/image.png)

![image.png](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/image%201.png)

### Host-only Network

Host와 그 Guest (VM)들로만 이루어진 **외부와 단절된 사설 네트워크**

![image.png](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/image%202.png)

### Bridge

공유기로부터 IP를 할당 받아, 호스트PC와 동일한 네트워크 대역의 IP를 갖게됨, 공유기를 통해 외부 네트워크통신이 가능.

![image.png](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/image%203.png)

---

## Network Virtualization

 물리적인 네트워크 형태를 따르지 않는 가상적/논리적 망 또는 회선

스위치나 라우터 등의 물리적 네트워크 장비 기능을 가상화하여 가상 머신(VM)이나 컨테이너(Container), 또는 범용 프로세서를 탑재한 하드웨어에서 구동하는 방식

이를 통해 새로운 장비를 설치하지 않아도 소프트웨어적으로 라우팅, 방화벽, 로드밸런싱, WAN 가속, 암호화 등의 네트워크 기능을 구현하거나 네트워크 상의 다양한 위치로 이동이 가능

- 네트워크 가상화의 예
    - VLAN (Virtual LAN)
    - VXLAN (Virtual eXtensible LAN)
    - vSwitch
    - NFV (Network Function Virtualization)
    - SDN (Software Defined Network)

### VLAN (Virtual LAN)

https://aws-hyoh.tistory.com/75

물리적인 네트워크를 논리적인 네트워크로 분할하는 가상화 기술

사용 이유: Broadcast Domain을 분할하기 위해서 (ARP Broadcast)

![image.png](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/image%204.png)

**IEEE 802.1Q Tag Frame**

![image.png](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/image%205.png)

- TPID (Tag Protocol Identifier, 16bit): 2Byte 태그(0x8100)가 존재함을 알리는 식별자
- PCP (Priority Control Information, 3bit): 0~7까지 우선순위 (CoS)
- CIF (Canonical Format Identifier, 1bit): Ethernet = 0 / Token Ring = 1
- VID (VLAN Identifier, 12bit): 각각의 VLAN 식별

### VXLAN (Virtual eXtensible LAN)

https://blog.naver.com/jkjk010jkjk/222355639180

VLAN의 한계를 극복하기 위해 등장한 기술로, L3 네트워크 위에 가상의 L2 네트워크를 얹는 Overlay 기술**.**

VXLAN은 50byte 헤더(Mac over IP, UDP Header, 24bit VLAN ID)를 추가로 구성하여 16,000,000개 이상의 VLAN을 제공 가능.

![image.png](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/image%206.png)

- **Overlay Network란?**
    - https://white-polarbear.tistory.com/69
    - 물리적인 인프라를 기반으로 네트워크 가상화 기술을 사용하여 End-to-End 통신을 수행하는 기술
    - Tunnel 구성을 한다고 표현
    
    ![image.png](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/image%207.png)
    
    - 오버레이 네트워크의 특징
        
        
        | 정보 은닉 | - 오버레이 기술을 사용하게 되면 새로운 헤더가 추가되어 원본 IP헤더를 감싸는 캡슐화가 수행 됨- 새로운 헤더 정보를 이용하여 라우팅이 수행되기 때문에 원본 헤더는 외부에 노출되지 않음 |
        | --- | --- |
        | SDN 활용 | - 오버레이 네트워크는 일반적으로 SDN (Software Defined Network)를 이용하며 컨트롤러를 통해 트래픽 부하분산 수행하여 링크의 대역폭 사용율이 높음 |
        | 독립성 | - 언더레이 네트워크 위에 오버레이 네트워크가 구성되지만 서로 독립적인 서비스로 오버레이 네트워크의 구성 변경이 언더레이에 영향을 주지 않음.- 반면, 언더레이의 구성 변경은 오버레이 네트워크에 영향을 줄 수 있음 |
        | 높은 효율성 | - Network Slicing과 Segmentation을 지원하여 네트워크를 분할하여 사용할 수 있음- 분할 된 네트워크에 자원을 할당하여 네트워크 자원의 사용을 최대로 높일 수 있음 |
        | 높은 보안성 | - 오버레이 네트워크 구성 시 암호화 알고리즘을 적용하여 End-to-End 통신에 높은 보안성을 얻을 수 있음 |

**VXLAN Packet**

![image.png](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/image%208.png)

**L2 Network와의 차이점**

- L2 Network에서는 Broadcast를 이용하여 ARP 테이블을 수집하고, MAC address는 스위치에서 수집하여 관리
- 하지만 VxLAN은 VM들이 직접 ARP 테이블을 보유하고 vSwitch에서 테이블을 관리
- VXLAN에서 BUM 트래픽에 대해서 **IP Multicast**를 기반으로 전송
    - Multicast로 ARP 테이블을 갱신하고 직접 해당 스위치쪽에 P2P Tunnel로 통신하는 방식

**VXLAN을 사용하는 이유**

- MAC Address Table의 한계
    - 가상화 환경이 생기면서 수많은 VM이 생성되는데, 이때 MAC 주소를 부여하면 MAC 주소가 기하급수적으로 늘어남
    - 이 많은 MAC 주소를 스위치의 MAC Table에 담으면 스위치의 처리 속도와 메모리에 엄청난 무리
    - 이를 해결하기 위해 VXLAN은 스위치에서 MAC 주소를 담당하지 않고 가상 스위치에서 MAC 주소를 담당하게 함.
- 유연성
    - VLAN에서는 서로간의 통신을 위해 VLAN Trunk를 구성하는데 이는 정적이고 변경에 빠르게 대처하기가 힘듬
    - VxLAN에서는 이러한 VLAN Trunk 없이 Multicast를 이용하여 Tree를 구성해 통신을 진행하기 때문에 동적이고 유연한 구성이 가능

### vSwitch

vSwitch vNIC을 물리적 NIC에 연결하고, local 통신을 위해 vNIC을 다른 서버의 vNIC들과 연결

![image.png](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/image%209.png)

- Access Port (Untagged Port) : 하나의 VLAN에 속한 포트, VLAN Tag 전달 X (Switch와 End device 연결)
- Trunk Port (Tagged Port): VLAN 정보를 넘겨 여러 VLAN이 한꺼번에 통신하도록 해주는 포트, VLAN Tag 전달 O
- Trunk Port로 들어온 VLAN을 vSwitch가 분류하여 해당 VLAN ID에 맞는 Access Port(Tag 떼고)로 전송

**vSwitch 종류**

**단순 브리지형 (기본형) : Linux Bridge**가 대표적입니다. 기본적인 L2 스위칭만 수행하는 단순하고 가벼운 가상 스위치입니다. 

**고급 기능형 (프로그래머블)**: Open vSwitch(OVS)가 대표적입니다. 단순 스위칭을 넘어 VLAN, VXLAN 캡슐화, QoS, 트래픽 모니터링, 그리고 SDN 제어(OpenFlow)까지 지원하는 강력한 가상 스위치입니다. OpenStack Neutron이 바로 이 OVS를 핵심 엔진으로 사용합니다.

### NFV (Network Function Virtualization)

네트워크 기능을 추상화하여 표준화된 컴퓨팅 노드에서 실행되는 소프트웨어를 통해 네트워크 기능을 설치, 제어 및 조작하도록 지원하는 기술

하드웨어 장비가 수행하던 네트워크 기능들을, 하드웨어에서 떼어내 범용 서버 위의 소프트웨어로 구현하는 기술 **(방화벽, LB, Router → Software (VM, Container)) - 장비 가상화**

### SDN (Software-Defined Networking)

소프트웨어를 통해 네트워크 리소스를 가상화하고 추상화하는 네트워크 인프라에 대한 접근 방식을 의미

네트워크의 제어부(Control Plane)와 데이터 전송부(Data Plane)를 분리하고, 제어부를 소프트웨어로 중앙 집중화하는 네트워크 아키텍처

![image.png](Devstack%20%EC%8B%A4%EC%8A%B5%20&%20Openstack%20%EA%B3%B5%EB%B6%80%20-%202%20week/image%2010.png)

### NFV vs SDN

- **SDN** : 네트워크를 보다 쉽게 제어 및 관리를 할 수 있도록 지원
- **NFV**는 네트워크를 보다 쉽게 구축하고 확장할 수 있는 소프트웨어이며, 상호 보완적인 관계를 통해 빠르게 변화하는 IT 서비스 변화에 능동적이고 빠른 대처를 가능하게 하며, 시스템 구축 및 통합 운용/관리비용 절감 효과 제공

| 구분 | NFV (Network Function Virtualization) | SDN (Software-Defined Networking) |
| --- | --- | --- |
| **목적** | 네트워크 장비의 기능을 가상화하여 하드웨어 종속성을 줄이고 유연성 및 효율성을 향상 | 네트워크의 제어(plane)와 데이터 전송(plane)을 분리하여 네트워크를 중앙에서 소프트웨어로 관리하고 제어함으로써 네트워크 관리와 운영을 자동화하고 유연 |
| **배경** | 네트워크 기능 이동 : 독립 Appliance → 통합 Appliance (서버 기반) | Control Plane(제어)과 Data Plane(트래픽 처리)을 분리,
중앙집중식 제어와 네트워크의 프로그램화 |
| **특징** | 단일 플랫폼 형태에서 소프트웨어 기반의 다양한 솔루션에 대해 구축의 편의성과 확장의 용이성 제공 | 중앙화와 원격화를 통해 네트워크 설정과 관리의 효율성 및 편의성 제공 |
| **적용 위치** | Service Provider Network | Datacenter / Cloud |
| **적용 장비** | 범용 스위치, 범용 서버 | 범용 스위치, 범용 서버 |
| **서비스 영역** | Router, Switch, Firewall, Gateway, CDN 등 | 클라우드 형태의 범용 네트워크 제어 및 관리 플랫폼 |
| **프로토콜** | 현재 없음 (표준화 진행 중) | OpenFlow |