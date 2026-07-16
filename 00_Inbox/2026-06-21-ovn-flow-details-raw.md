---
title: "OVN 네트워크 흐름 확인 세부 내용"
type: "raw"
date: 2026-06-21
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[01_Concepts/OVN-Network-Flow]]"
---
# 세부 내용

### 전체 그림

패킷이 이동하는 경로

```bash
cirros VM → cp02 → (Geneve 터널) → ct03 → ens19 → Proxmox → 인터넷
```

---

### 1단계. VM 안 (cirros)

VM 안에서 `ping 8.8.8.8`을 치면 패킷 생성

```bash
출발: 172.22.0.154 (내 IP)
목적: 8.8.8.8 (구글 DNS)
```

---

### 2단계. cp02 안 (br-int, OVS)

VM의 패킷이 `tap1f430626-97` 인터페이스를 타고 `br-int`로 들어옴

```bash
VM eth0 → tap1f430626-97 → br-int
```

`br-int`는 OVN이 관리하는 **가상 스위치**. 수동 설치 때의 `brq<net-id>`와 같은 역할인데, 차이가 있음

- 수동 설치: 브리지마다 `vxlan-657` 같은 터널 인터페이스가 물리적으로 붙어있었음
- OVN: `br-int` 하나에 모든 터널이 논리적으로 연결됨 (`ovn-openst-0~3`)

br-int가 이 패킷을 보고 목적지가 8.8.8.8이니까 게이트웨이(172.22.0.1)로 보내야겠다고 판단.

그리고 **gateway chassis인 ct03(.204)으로 Geneve 터널을 통해 전달.**

---

### 3단계. Geneve 캡슐화

cp02가 ct03으로 패킷을 보낼 때 그냥 보내는 게 아니라 **포장**

```bash
[바깥 포장]
  출발 IP: 192.168.100.206 (cp02 관리망)
  목적 IP: 192.168.100.204 (ct03 관리망)
  프로토콜: UDP / 포트 6081 (Geneve)

[안에 든 원본 패킷]
  출발 IP: 172.22.0.154 (cirros)
  목적 IP: 8.8.8.8
```

관리망을 **터널**처럼 써서 VM 패킷을 실어 나르는 것

VXLAN이랑 같은 개념인데 Geneve는 헤더에 메타데이터를 더 실을 수 있다.

---

### 4단계. ct03 (gateway chassis)

ct03이 Geneve 패킷을 받아서 디캡슐화. 안에서 원본 패킷(`172.22.0.154 → 8.8.8.8`)이 나옴.

이제 OVN 논리 라우터가 동작. 수동 설치 때의 `qrouter namespace`가 하던 일을 여기서 함.

**SNAT 두 번 발생**

첫 번째, floating IP SNAT:

```bash
172.22.0.154 → 192.168.100.243 (cirros vm의 floating IP)
```

두 번째, 라우터 외부 IP로 SNAT:

```bash
192.168.100.243 → 192.168.100.221 (라우터 external IP)
```

그리고 패킷이 `br-ex → ens19`로 나감.

---

### 5단계. Proxmox natzone

ct03의 `ens19`에서 나온 패킷이 Proxmox의 natzone을 통과하면서 마지막 SNAT 발생.

```bash
192.168.100.221 → 공인 IP (210.94.240.179)
```

그리고 `vmbr0 → eno1`을 타고 실제 인터넷으로 나감.

---

### 한 줄 요약

```bash
VM 패킷
  → br-int(OVS)에서 Geneve로 포장
  → 관리망 타고 gateway chassis(ct03)로 이동
  → ct03에서 포장 뜯고 SNAT 두 번
  → ens19 → Proxmox SNAT → 인터넷
```