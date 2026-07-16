---
title: "운영 PC 실습 환경 네트워크 구성 가이드"
type: "guide"
date: 2026-06-14
tags: ["#guide", "#proxmox", "#networking", "#tailscale"]
related_nodes: ["[[01_Concepts/Proxmox]]", "[[01_Concepts/HA-Concepts]]", "[[03_Guides/Tailscale-Setup-Guide]]", "[[03_Guides/Proxmox-Installation-Guide]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-06-14-ops-pc-network-setup-raw]]"
---

# 운영 PC 실습 환경 네트워크 구성 가이드

## 개요

Proxmox가 설치된 운영 PC에 VM 4대를 생성하고 내부 사설망 + Tailscale 원격 접속 환경을 구성하는 가이드.

## 전체 구조

```
외부 PC
    │
    ▼
Tailscale Network (100.x.x.x)
    │
    ▼
Proxmox Host
    ├─ vmbr0 (외부망, 공인 IP)
    └─ vmbr1 (내부망 192.168.100.0/24)
            ├─ VM1 (192.168.100.11)
            ├─ VM2 (192.168.100.12)
            ├─ VM3 (192.168.100.13)
            └─ VM4 (192.168.100.14)
```

---

## 단계별 절차

### Step 1. Proxmox 내부 브리지 생성 (vmbr1)

Proxmox GUI: Datacenter → pve → Network → Create → Linux Bridge

```
Name: vmbr1
IPv4/CIDR: 192.168.100.1/24
VLAN aware: No (단순 실습)
```

### Step 2. SNAT 설정 (VM → 인터넷)

VM들의 사설 IP(`192.168.100.x`)가 인터넷에 나갈 수 있도록:

```bash
# Proxmox Host에서 실행
iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o vmbr0 -j MASQUERADE
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p
```

또는 Proxmox SDN natzone 사용 (더 권장, [[03_Guides/Tailscale-Setup-Guide]] 참고).

### Step 3. VM 생성 및 내부 IP 설정

VM 생성 시 Network → Bridge: `vmbr1` 선택

각 VM 내부에서 고정 IP 설정:
```bash
# /etc/netplan/01-network.yaml
network:
  version: 2
  ethernets:
    ens18:
      addresses: [192.168.100.11/24]   # 각 VM별 할당
      gateway4: 192.168.100.1
      nameservers:
        addresses: [8.8.8.8]
```

### Step 4. Tailscale Subnet Router 설정

```bash
# Proxmox Host에서
tailscale up --advertise-routes=192.168.100.0/24
```

Tailscale 관리 콘솔에서 라우트 승인 → 외부 PC에서 `192.168.100.x`로 직접 접속 가능.

---

## 통신 흐름 정리

| 통신 유형 | 경로 |
|----------|------|
| VM ↔ VM | vmbr1 내부 (L2, 외부 안 거침) |
| VM → 인터넷 | VM → vmbr1 → Proxmox SNAT → vmbr0 → 인터넷 |
| 외부 PC → VM | 외부 PC → Tailscale → Proxmox Subnet Router → vmbr1 → VM |

---

## OpenStack 관점

`192.168.100.0/24` 내부망은 OpenStack 노드들이 통신하는 **Underlay Network** 역할:

```
물리 PC
    ↓
Proxmox (vmbr1: 192.168.100.0/24) ← Underlay
    ↓
OpenStack Neutron
    ↓
Tenant Network (OVN/Geneve) ← Overlay
    ↓
Instance
```

## 관련 문서

- [[01_Concepts/Proxmox]]
- [[03_Guides/Tailscale-Setup-Guide]]
- [[01_Concepts/OVN-Network-Flow]]
