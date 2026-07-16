---
title: "OVN / OVS 아키텍처"
type: "concept"
date: 2026-06-28
tags: ["#openstack", "#ovn", "#ovs", "#networking"]
status: "stable"
related_nodes: ["[[01_Concepts/OVN-Network-Flow]]", "[[01_Concepts/VXLAN]]", "[[01_Concepts/Provider-vs-SelfService-Network]]", "[[01_Concepts/Kolla-Ansible]]"]
author: "AI Assistant"
raw_source: ["[[00_Inbox/2026-06-28-ovn-ovs-final-raw]]", "[[00_Inbox/2026-06-28-ovn-diagram-raw]]"]
---

# OVN / OVS 아키텍처

## 한 줄 정의

OVN은 논리 네트워크를 정의하는 컨트롤 플레인, OVS는 실제 패킷을 스위칭하는 데이터 플레인. **OVN = 두뇌, OVS = 손발**.

## 상세 설명

### OVN과 OVS의 레이어 구분

| 컴포넌트 | 역할 |
|----------|------|
| **OVS (Open vSwitch)** | 실제로 패킷을 스위칭하는 소프트웨어 스위치 엔진 (커널 모듈 + `ovs-vswitchd` 데몬) |
| **OVN (Open Virtual Network)** | OVS 위에 얹는 논리 네트워크 오케스트레이션 레이어. 논리 스위치/라우터를 물리 OVS flow로 변환하는 컨트롤 플레인 |

OVN 자체는 패킷을 스위칭하지 않는다. OVS에게 "이렇게 스위칭해라"라는 flow만 넘긴다.

---

### 핵심 컴포넌트 5개

| 컴포넌트 | 역할 | 실행 위치 |
|----------|------|-----------|
| **NB DB** (Northbound DB) | 논리 토폴로지 저장 (Logical_Switch, Logical_Router, ACL 등) | controller (ct01~03), `ovn_nb_db` 컨테이너 |
| **SB DB** (Southbound DB) | 물리 배치 정보 저장 (Logical_Flow, Port_Binding, Chassis, Encap) | controller (ct01~03), `ovn_sb_db` 컨테이너 |
| **ovn-northd** | NB DB → SB DB 변환(컴파일) 담당 | controller 중 1개 active, `ovn_northd` 컨테이너 |
| **ovn-controller** | SB DB를 구독(watch)해서 자기 노드 담당 flow를 로컬 OVS에 프로그래밍 | **모든 노드** (ct01~03, cp01~02) |
| **ovsdb-server / ovs-vswitchd** | 실제 OVS 브리지, flow table 관리 | 모든 노드 |

> **주의**: `ovn-nbctl`/`ovn-sbctl`은 반드시 `ovn_northd` **컨테이너 내부**에서 실행. 호스트에서 직접 실행 불가.
> ```bash
> docker exec -it ovn_northd ovn-nbctl show
> docker exec -it ovn_northd ovn-sbctl show
> ```

---

### NB DB / SB DB는 MariaDB가 아니다

| DB | 용도 | 엔진 | 클러스터링 |
|----|------|------|-----------|
| MariaDB (Galera) | OpenStack 서비스 SQL 스키마 (neutron, nova, keystone...) | MySQL 계열 | Galera wsrep |
| OVN NB/SB DB | OVN 전용 논리/물리 토폴로지 | **OVSDB** (JSON, RFC 7047) | 내장 RAFT 프로토콜 |

neutron-server는 neutron DB(MariaDB)에 쓰는 동시에, ovn ML2 드라이버를 통해 NB DB(OVSDB)에도 **동시에(dual-write)** 씁니다.

---

### 브리지 구조

**br-int** (Integration Bridge)
- **모든 노드** (compute + gateway)에 존재
- VM NIC(tap), OVN 논리 포트(ovn-openst-N), DHCP 포트 등이 전부 여기 붙음
- 논리 스위치/라우터의 flow가 실제로 프로그래밍되는 곳

**br-ex** (External Bridge)
- **gateway chassis 노드에만** 존재 (SU Cloud에서는 ct03)
- br-int와 patch port 쌍으로 연결
- 실제 외부 물리 NIC(`ens19`)와 연결 → 외부망으로 나가는 통로

---

### LinuxBridge+VXLAN vs OVN 비교

| 항목 | LinuxBridge (수동 설치) | OVN (Kolla, 현재 SU Cloud) |
|------|------------------------|---------------------------|
| 가상 스위치 | Linux bridge (`brq...`) | OVS 브리지 |
| 터널 | 별도 `vxlan-N` 인터페이스 직결 | br-int에 논리적 통합 |
| 게이트웨이 | `qrouter` 네임스페이스 | **br-ex** (gateway chassis에만) |
| 캡슐화 | VXLAN (UDP/4789) | **Geneve** (UDP/6081) |
| 라우터 구현 | Linux network namespace | OVN Logical Router (namespace 없이 flow로 구현) |
| MAC 학습 | 브리지가 동적 학습 | OVN이 SB DB에 미리 계산 |

---

### NB DB에 저장되는 논리 객체

| 객체 | 의미 |
|------|------|
| **Logical_Switch** | Neutron network 1개 대응, Geneve로 오버레이 |
| **Logical_Switch_Port** | VM NIC, 라우터 포트, DHCP 포트 등 |
| **Logical_Router** | Neutron router 1개 대응 (`main-router`), flow 집합으로 구현 |
| **NAT 규칙** | `dnat_and_snat` (Floating IP 1:1), `snat` (테넌트 공용 출구) |
| **ACL** | Security Group이 여기로 컴파일됨 |
| **DHCP_Options** | Neutron subnet의 DHCP 설정 |

## SU Cloud에서의 활용

- Kolla-Ansible OVN 구성: controller 3대에 NB/SB DB + northd, 전 노드에 ovn-controller
- Gateway Chassis: ct03 (UUID `60a45818-513a-41ad-9c89-ece4d03d3d35`)
- 캡슐화: Geneve (UDP/6081), br-int 기반
- `ens19`: IP 없음, br-ex로 흡수 → gateway 역할

## 관련 개념

- [[01_Concepts/OVN-Network-Flow]]
- [[01_Concepts/VXLAN]]
- [[01_Concepts/Kolla-Ansible]]
- [[01_Concepts/HA-Concepts]]
