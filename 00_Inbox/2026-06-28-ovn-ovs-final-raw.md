---
title: "OVN OVS 최종정리"
type: "raw"
date: 2026-06-28
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# OVN / OVS 최종정리

---

## 1. OVS와 OVN은 다른 레이어

가장 먼저 헷갈리기 쉬운 부분입니다.

- **OVS (Open vSwitch)**: 실제로 패킷을 스위칭하는 **소프트웨어 스위치 엔진**. 커널 모듈 + `ovs-vswitchd` 데몬으로 구성됨. OVN 없이도 단독으로 쓸 수 있음 (예: 예전 Neutron OVS ML2 드라이버).
- **OVN (Open Virtual Network)**: OVS **위에 얹는 논리 네트워크 오케스트레이션 레이어**. "논리 스위치/논리 라우터를 어떻게 물리 OVS flow로 변환할지"를 계산해주는 컨트롤 플레인. OVN 자체는 패킷을 스위칭하지 않고, OVS에게 "이렇게 스위칭해라"라는 flow를 넘겨줌.

즉 **OVN = 두뇌(control plane), OVS = 손발(data plane)** 관계입니다.

---

## 2. 핵심 컴포넌트 5개

| 컴포넌트 | 역할 | 실행 위치 |
| --- | --- | --- |
| **NB DB** (Northbound DB) | 논리 토폴로지 저장 (Logical_Switch, Logical_Router, ACL 등) | 컨트롤러 (ct01~03), `ovn_nb_db` 컨테이너 |
| **SB DB** (Southbound DB) | 물리 배치 정보 저장 (Logical_Flow, Port_Binding, Chassis, Encap) | 컨트롤러 (ct01~03), `ovn_sb_db` 컨테이너 |
| **ovn-northd** | NB DB → SB DB 변환(컴파일) 담당 프로세스 | 컨트롤러 중 1개 active, `ovn_northd` 컨테이너 |
| **ovn-controller** | SB DB를 구독(watch)해서 자기 노드 담당 flow만 OpenFlow로 로컬 OVS에 프로그래밍 | **모든 노드** (ct01~03, cp01~02) |
| **ovsdb-server / ovs-vswitchd** | 실제 OVS 브리지, flow table 관리 | 모든 노드 (호스트 레벨) |

**중요:** `ovn-nbctl` / `ovn-sbctl` 명령은 반드시 `ovn_northd` 컨테이너 **내부**에서 실행해야 합니다. 호스트에서 직접 실행 불가.

```bash
docker exec -it ovn_northd ovn-nbctl show
docker exec -it ovn_northd ovn-sbctl show
```

---

## 3. NB DB / SB DB는 MariaDB가 아니다

이전에 확인했듯이, MariaDB(Galera)는 `neutron`, `nova`, `keystone` 등 **OpenStack 서비스의 SQL 스키마**만 저장합니다.

OVN NB/SB DB는:

- 엔진 자체가 다름: **OVSDB** (JSON 기반, RFC 7047), MySQL 계열이 아님
- 클러스터링도 다름: OVSDB에 내장된 **RAFT** 프로토콜로 복제 (Galera의 wsrep과는 무관한 별개 메커니즘)
- 저장 형태: 컨테이너 내부 `.db` 파일

```
MariaDB Galera  ─── neutron/nova/cinder/keystone SQL 테이블
OVSDB (NB/SB)   ─── OVN 전용, 완전히 별도 프로세스/파일/RAFT
```

neutron-server는 neutron DB(MariaDB)에 쓰는 동시에, ovn ML2 드라이버를 통해 NB DB(OVSDB)에도 **동시에(dual-write)** 씁니다.

---

## 4. 브리지 구조 — LinuxBridge/VXLAN 방식과의 차이

수동설치 환경(mingi)에서 쓰던 LinuxBridge+VXLAN 방식과 OVN은 브리지 구조가 다릅니다.

| 항목 | LinuxBridge (구) | OVN (현재 SU Cloud) |
| --- | --- | --- |
| 가상 스위치 | Linux bridge (`brq...`) | OVS 브리지 |
| 터널 브리지 | 별도 없음 (vxlan 인터페이스 직결) | **br-tun 없음** — 모든 것이 br-int에서 처리 |
| 게이트웨이 전용 브리지 | qrouter 네임스페이스 | **br-ex** (gateway chassis에만 존재) |
| 캡슐화 | VXLAN | **Geneve** (UDP/6081) |
| 라우터 구현 | Linux network namespace (qrouter-...) | OVN Logical Router (namespace 없이 flow로 구현) |
| MAC 학습 | 브리지가 학습 | OVN이 SB DB에 미리 계산해둠 |

**br-int** (Integration Bridge)

- **모든 노드**(compute + gateway)에 존재
- VM NIC(tap), OVN 논리 포트(ovn-openst-N), DHCP 포트, Octavia HM 포트 등이 전부 여기 붙음
- 논리 스위치/논리 라우터의 flow가 실제로 프로그래밍되는 곳

**br-ex** (External Bridge)

- **gateway chassis 역할을 하는 노드에만** 존재 (SU Cloud에서는 ct03)
- br-int와 `patch-br-int-to-provnet-...` / `patch-br-int-to-provnet-...-to-br-int` **patch port 쌍**으로 연결됨
- 실제 외부 물리 NIC(ens19 등)와 연결되어 진짜 외부망으로 나가는 통로

---

## 5. 논리(Logical) 개념 — NB DB에 저장되는 것들

- **Logical_Switch**: OpenStack의 Neutron network 1개에 대응. Geneve로 오버레이됨.
- **Logical_Switch_Port**: VM NIC, 라우터로 가는 포트, DHCP 포트 등 논리 스위치에 붙는 모든 포트.
- **Logical_Router**: OpenStack의 Neutron router 1개에 대응. 예: `main-router`. namespace가 아니라 flow 집합으로 구현됨.
- **Logical_Router_Port (`lrp-...`)**: 논리 라우터가 각 서브넷과 연결되는 인터페이스. 내부용(int)과 외부용(ext) 각각 존재.
- **NAT 규칙**: `dnat_and_snat`(Floating IP 1:1), `snat`(테넌트 공용 출구) 두 종류가 Logical_Router 객체 안에 리스트로 저장됨.
- **ACL**: Security Group이 여기로 컴파일됨.
- **DHCP_Options**: Neutron subnet의 DHCP 설정이 여기 저장.

## 6. 물리(Physical) 개념 — SB DB에 저장되는 것들

- **Chassis**: 물리 노드(ct01~03, cp01~02) 1개당 1개. hostname, encap IP 등을 가짐.
- **Encap**: 각 Chassis가 캡슐화에 쓰는 정보 (Geneve, IP).
- **Port_Binding**: 논리 포트가 **어느 물리 Chassis**에 실제로 붙어있는지 매핑. VM이 live migration 되면 이 값이 바뀜.
- **Gateway_Chassis**: 어떤 Chassis가 특정 Logical_Router의 gateway(외부 연결점) 역할을 하는지 지정.
- **Logical_Flow**: ovn-northd가 컴파일해낸 "논리적인" OpenFlow 유사 flow. 아직 물리 노드별로 특화되기 전 단계.
- **Datapath_Binding**: 논리 스위치/라우터가 실제 OVS datapath(tunnel key)에 매핑되는 정보.

---

## 7. 캡슐화 (Encapsulation)

- OVN은 **Geneve** (Generic Network Virtualization Encapsulation, UDP 포트 6081)를 씀. VXLAN(UDP 4789)이 아님.
- Geneve를 쓰는 이유: VXLAN보다 확장 가능한 옵션 헤더(TLV)를 가지고 있어서 metadata를 더 유연하게 실어나를 수 있음. OVN은 여기에 논리 스위치 ID 등 부가정보를 실음.
- **MTU 계산**: VM 내부 MTU 1442 = 물리 MTU 1500 − 약 58바이트 Geneve 오버헤드(외부 IP/UDP/Geneve 헤더). 이 값이 안 맞으면 큰 패킷에서 단편화/드롭 발생.
- 관리망(Management/Underlay, 192.168.100.0/24)을 타고 노드 간에 Geneve 터널이 형성됨. BFD(Bidirectional Forwarding Detection)로 터널 상태를 모니터링(다이어그램의 "BFD up" 표시).

패킷 예시 (실습환경 실측 구조):

```
[Outer] 192.168.100.206 -> 192.168.100.204  UDP/6081 (Geneve)
[Inner] 172.22.0.154 -> 8.8.8.8 (ICMP)
```

---

## 8. Gateway Chassis 개념

- 모든 노드가 br-int는 갖지만, **외부로 나가는 실제 물리 경로(br-ex)는 gateway 역할을 맡은 chassis만** 가짐.
- 실습 환경에서는 **ct03**이 이 역할. SB DB의 `Gateway_Chassis` 테이블에 지정되어 있음.
- 장점: 모든 compute 노드가 외부 NIC를 가질 필요 없이, 논리 라우터의 외부 트래픽만 특정 노드로 몰아서 처리 가능 (중앙집중형 NAT/라우팅).
- 단점/트레이드오프: 해당 chassis가 다운되면 외부 연결이 끊김 → 실무에서는 여러 chassis를 gateway 후보로 등록하고 priority를 매겨 failover 하는 것도 가능(HA chassis group). 현재 SU Cloud는 단일 gateway(ct03) 구성.

---

## 9. 패킷이 실제로 지나가는 경로 (데이터 플레인)

VM(cirros, cp02) → 인터넷(8.8.8.8) ping 예시로 정리:

1. **cirros VM** (`eth0`, 172.22.0.154/24) → `tap...` VM NIC
2. **cp02의 br-int**: 목적지가 로컬 서브넷이 아님 → gateway(ct03)로 가야 한다고 판단 → `ovn-openst-3` 포트(ct03 방향)로 라우팅
3. **cp02 물리 NIC(ens18)**: Geneve로 캡슐화해서 관리망을 통해 ct03(192.168.100.204)으로 전송
4. **ct03 물리 NIC(ens18)**: Geneve 수신
5. **ct03의 br-int**: 디캡슐화 → **main-router**(OVN Logical Router) 파이프라인 진입
    - `dnat_and_snat`(Floating IP 있는 VM) 또는 `snat`(공용 출구) 규칙 적용
    - src가 192.168.100.243(SNAT/DNAT된 주소)로 바뀜
6. **patch port**를 통해 br-int → **br-ex**로 전달
7. **br-ex → ens19(외부 NIC)**: 물리 네트워크로 송출
8. **Proxmox 호스트**: `iptables MASQUERADE`로 한 번 더 NAT (192.168.100.243 → 210.94.240.179) — 이것이 **Double NAT** (OVN SNAT + Proxmox MASQUERADE는 순차적이지만 별개의 레이어)
9. **vmbr0 → eno1**: 캠퍼스 백본으로 나감

---

## 10. OVS Fast Path / Slow Path

- **Slow path**: 새로운 flow의 첫 패킷은 커널의 datapath에 매칭되는 flow가 없어서, **Netlink upcall**로 유저스페이스의 `ovs-vswitchd`까지 올라가서 처리됨. 상대적으로 느림.
- **Fast path**: 첫 패킷 처리 후 커널 datapath에 flow가 캐싱되어, 이후 같은 흐름의 패킷은 **커널 안에서만** 처리됨 (유저스페이스 안 거침). 훨씬 빠름.
- 진단 명령:

```bash
ovs-dpctl dump-flows          # 커널 datapath에 캐싱된 flow (fast path)
ovs-ofctl dump-flows br-int   # OpenFlow 테이블 (전체 룰)
```

---

## 11. RAFT 클러스터링 (NB DB / SB DB)

- OVSDB에 내장된 합의(consensus) 알고리즘. Raft는 리더 하나 + 팔로워들로 구성되고, 과반수 노드가 살아있으면 클러스터가 동작함.
- 실습 환경처럼 3노드(ct01~03) 구성이면 1개 노드가 죽어도 과반(2/3) 유지되어 계속 동작. 2개가 죽으면 quorum 상실.
- MariaDB Galera(multi-master, 모든 노드가 쓰기 가능)와는 다르게, Raft는 **리더만 쓰기 담당**, 나머지는 팔로워로 리더의 로그를 복제받는 구조.
- 리더 확인:

```bash
docker exec -it ovn_northd ovn-nbctl cluster-status OVN_Northbound
docker exec -it ovn_northd ovn-sbctl cluster-status OVN_Southbound
```

---

## 12. Neutron ↔ OVN 연동 (dual-write)

- neutron-server는 **ovn ML2 mechanism driver**를 사용.
- 사용자가 `openstack network create` 등을 호출하면:
    1. neutron-server가 **MariaDB(neutron DB)**에 SQL row로 기록
    2. 동시에 ovn ML2 드라이버가 **NB DB(OVSDB)**에 대응하는 Logical_Switch 등을 기록
- 두 기록은 같은 API 호출 안에서 일어나지만, 저장소 자체는 완전히 분리되어 있음.

---

## 13. 실무 진단 명령어 모음

| 목적 | 명령어 |
| --- | --- |
| 논리 토폴로지 확인 | `ovn-nbctl show` |
| 물리 배치(chassis) 확인 | `ovn-sbctl show` |
| 컴파일된 논리 flow 확인 | `ovn-sbctl lflow-list` |
| 특정 노드의 실제 OpenFlow 규칙 | `ovs-ofctl dump-flows br-int` |
| 커널 fast path flow | `ovs-dpctl dump-flows` |
| OVS 브리지/포트 구조 | `ovs-vsctl show` |
| Geneve 터널 상태(BFD) | `ovs-appctl bfd/show` |
| RAFT 클러스터 상태 | `ovn-nbctl cluster-status OVN_Northbound` |
| conntrack(NAT 상태) 확인 | `conntrack -L` |
| tap/patch 포트 상세 | `ovs-vsctl list Interface <port>` |

---

## 14. 용어 미니 사전

| 용어 | 뜻 |
| --- | --- |
| ML2 | Modular Layer 2 — Neutron의 플러그인 아키텍처, mechanism driver로 OVN/LinuxBridge/OVS 등을 교체 가능 |
| Chassis | OVN에서 "물리 노드 하나"를 부르는 이름 (SB DB 테이블명이기도 함) |
| Datapath | OVS에서 flow가 매칭/처리되는 실제 커널 또는 userspace 처리 단위 |
| Patch port | 같은 호스트 안에서 서로 다른 두 OVS 브리지를 연결하는 가상 링크 (br-int ↔ br-ex) |
| Geneve | Generic Network Virtualization Encapsulation, OVN 기본 캡슐화 프로토콜 |
| BFD | Bidirectional Forwarding Detection — 터널/링크 상태를 빠르게 감지하는 프로토콜 |
| Northbound / Southbound | OVN에서 "논리(사용자 의도) 쪽 = North", "물리(실제 배치) 쪽 = South"라는 방향성 은유 |

---