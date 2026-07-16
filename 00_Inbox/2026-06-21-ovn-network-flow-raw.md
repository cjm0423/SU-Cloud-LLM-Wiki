---
title: "OVN 네트워크 흐름 확인 (Kolla Ansible)"
type: "raw"
date: 2026-06-21
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[01_Concepts/OVN-Network-Flow]]"
---
# OVN 네트워크 흐름 확인 (Kolla Ansible)

---

```bash
[사람이 접속할 때]         사용자 PC
                             │ Tailscale 암호화 터널(100.x.x.x)
                             ▼
                           pve (100.98.185.101)
                             │ vmnet 브리지(192.168.100.1)
                             ▼
                    OpenStack VM들 / Horizon / SSH
                    → Tailscale이 여기서만 등장

[VM이 인터넷 나갈 때]      cirros (172.22.0.154)
                             │ br-int → Geneve 터널
                             ▼
                           gateway chassis (ct03)
                             │ br-ex → ens19
                             ▼
                    Proxmox natzone → vmbr0 → 인터넷
                    → Tailscale 관여 안 함
```

```bash
100.98.185.101  pve          ← Proxmox 호스트 (Tailscale 서버)
```

# 1. Compute node (cp02, 192.168.100.206)

### 1-1. OpenStack instance (Nova VM)

```bash
$ ip addr
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1442
    inet 172.22.0.154/24
    link/ether fa:16:3e:e0:44:66
```

OpenStack instance(cirros) ip: `172.22.0.154` → `ping -c 1 8.8.8.8`

### 1-2. tap interface & OVS (br-int)

```bash
ubuntu@openstack-cp02:~$ ip link show | grep tap

9:  tap1f430626-97  → VM(172.22.0.154)의 가상 NIC  (master ovs-system)
10: tap4be8df35-70  → DHCP 포트                     (master ovs-system)
```

```bash
ubuntu@openstack-cp02:~$ sudo docker exec openvswitch_vswitchd ovs-vsctl show

Bridge br-int
    Port tap1f430626-97       ← VM tap 포트
    Port tap4be8df35-70       ← DHCP 포트
    Port ovn-openst-0         geneve → 192.168.100.205 (cp01)
    Port ovn-openst-1         geneve → 192.168.100.202 (ct01)
    Port ovn-openst-2         geneve → 192.168.100.203 (ct02)
    Port ovn-openst-3         geneve → 192.168.100.204 (ct03) ← gateway chassis
```

### 1-3. Packet Geneve Encapsulation

```bash
ubuntu@openstack-cp02:~$ sudo tcpdump -ni ens18 udp port 6081 -e -vv -c 5

# VM → gateway chassis(ct03) 방향 패킷
192.168.100.206.6469 > 192.168.100.204.6081: Geneve, vni 0x0, proto TEB (0x6558)
    fa:16:3e:e0:44:66 > ...   ← VM MAC
    172.22.0.154 > 8.8.8.8   ← 내부 페이로드 (캡슐화된 원본 패킷)
```

`Compute(cp02)` → `gateway chassis(ct03)` 로 보내기 위해 **Geneve 캡슐화**
(오버레이 = 관리망 `.206 → .204`, UDP/6081)

---

# 2. Gateway Chassis (ct03, 192.168.100.204)

가상 네트워크 내부의 트래픽이 외부 물리 네트워크(인터넷 등)로 드나드는 '출입구' 역할을 전담하는 물리적 서버(노드)를 의미

- 남북(North-South) 트래픽 집중 처리
- NAT (Network Address Translation) 수행
- 고가용성 (High Availability, HA) 지원
- 분산 논리 라우터포트 바인딩

### 2-1. Gateway Chassis 확인

```bash
# gateway chassis UUID 확인
ubuntu@openstack-lb:~$ ssh ubuntu@192.168.100.202 \
    "sudo docker exec ovn_northd ovn-sbctl find port_binding type=chassisredirect \
    | grep -E 'chassis|logical_port'"

chassis : 60a45818-513a-41ad-9c89-ece4d03d3d35   ← ct03의 UUID
logical_port : cr-lrp-ab60914c-...

# UUID → hostname 매핑
ubuntu@openstack-lb:~$ ssh ubuntu@192.168.100.202 \
    "sudo docker exec ovn_northd ovn-sbctl list chassis \
    | grep -E '_uuid|hostname'" | grep -A1 '60a45818'

_uuid    : 60a45818-513a-41ad-9c89-ece4d03d3d35
hostname : openstack-ct03    ← 현재 gateway chassis
```

### 2-2. OVN 논리 라우터 (main-router)

```bash
ubuntu@openstack-lb:~$ ssh ubuntu@192.168.100.202 \
    "sudo docker exec ovn_northd ovn-nbctl show"

router (main-router)
    port lrp-ab60914c (external측)
        networks: 192.168.100.221/24        ← 라우터 외부 IP
        gateway chassis: [ct01, ct03, ct02] ← HA, ct03이 현재 active
    port lrp-f08badd8 (internal측)
        networks: 172.22.0.1/24             ← 테넌트 게이트웨이
    nat c642d225
        external ip: 192.168.100.243        ← floating IP
        logical ip:  172.22.0.154           ← VM IP
        type: dnat_and_snat                 ← Floating IP 1:1 NAT
    nat f6f5dbc9
        external ip: 192.168.100.221        ← 라우터 외부 IP
        logical ip:  172.22.0.0/24          ← 테넌트 전체 대역
        type: snat                          ← 인터넷 출구 SNAT
```

### 2-3. br-ex → ens19 (외부 출구)

```bash
ubuntu@openstack-ct03:~$ sudo docker exec openvswitch_vswitchd ovs-vsctl show

Bridge br-ex
    Port ens19          ← 외부망 NIC (IP 없음)
    Port br-ex
```

### 2-4. 실제 패킷 캡처 (ct03 ens19)

```bash
# ct03의 ens19에서 캡처 (ping 날리는 동안)
ubuntu@openstack-lb:~$ ssh ubuntu@192.168.100.204 "sudo tcpdump -ni ens19 icmp -e"

01:44:21.567238 fa:16:3e:2f:30:1e > 86:97:4e:2a:67:bc
    192.168.100.243 > 8.8.8.8: ICMP echo request

01:44:21.605622 86:97:4e:2a:67:bc > fa:16:3e:2f:30:1e
    8.8.8.8 > 192.168.100.243: ICMP echo reply
```

```
fa:16:3e:2f:30:1e  ← OVN 라우터(main-router) external 포트 MAC
86:97:4e:2a:67:bc  ← Proxmox natzone 게이트웨이 MAC
192.168.100.243    ← floating IP (SNAT 후 주소)
```

---

# 3. Proxmox Server

### 3-1. natzone SNAT

```bash
root@pve:~# iptables -t nat -L POSTROUTING -n

MASQUERADE  192.168.100.0/24 → vmbr0 (공인 IP)
```

가상머신 ip(`192.168.100.0/24`) → 물리 Proxmox 공인 IP로 SNAT
`vmbr0 → eno1` 타고 인터넷으로

---

# 전체 흐름 요약

```
[cp02] cirros (172.22.0.154)
  │ eth0 (MTU 1442)
  │
  ▼ tap1f430626-97
[cp02] br-int (OVS)
  │
  ▼ Geneve 캡슐화 (UDP/6081)
  │ 192.168.100.206 → 192.168.100.204
  │
[ct03] br-int (OVS) ← gateway chassis
  │ Geneve 디캡슐화
  │
  ▼ OVN logical router (main-router)
  │ SNAT: 172.22.0.154 → 192.168.100.243 (floating IP)
  │ SNAT: 192.168.100.243 → 192.168.100.221 (라우터 외부 IP)
  │
  ▼ br-ex → ens19
  │
[Proxmox] natzone MASQUERADE
  │ 192.168.100.0/24 → 공인 IP
  │
  │ eno1(물리 NIC)
  ▼
인터넷 (8.8.8.8)
```

---

# Geneve Encapsulation 구조

```
[Outer Header]
  src MAC: cp02 ens18 MAC
  dst MAC: ct03 ens18 MAC
  src IP:  192.168.100.206 (cp02)
  dst IP:  192.168.100.204 (ct03, gateway chassis)
  proto:   UDP / port 6081

[Geneve Header]
  vni: flow key (OVN이 자동 관리)

[Inner Payload]
  src MAC: fa:16:3e:e0:44:66 (VM eth0)
  src IP:  172.22.0.154 (cirros)
  dst IP:  8.8.8.8
  proto:   ICMP
```

> VXLAN과 달리 Geneve는 가변 길이 옵션 필드를 가져
OVN이 포트/정책 메타데이터를 터널 헤더에 실어 전달 가능.
> 

---

[세부 내용](OVN%20%EB%84%A4%ED%8A%B8%EC%9B%8C%ED%81%AC%20%ED%9D%90%EB%A6%84%20%ED%99%95%EC%9D%B8%20(Kolla%20Ansible)/%EC%84%B8%EB%B6%80%20%EB%82%B4%EC%9A%A9%20388d8e51100c80f0b5eac38bbdaec066.md)