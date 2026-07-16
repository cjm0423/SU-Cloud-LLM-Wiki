---
title: "SU Cloud 인프라 현황 (Server & Network Inventory)"
type: "concept"
date: 2026-07-16
tags: ["#su-cloud", "#infra", "#inventory"]
status: "stable"
related_nodes: ["[[01_Concepts/SU-Cloud-Campus-Network]]", "[[01_Concepts/SU-Cloud-Project-Overview]]", "[[01_Concepts/Kolla-Ansible]]"]
author: "AI Assistant"
---

# SU Cloud 인프라 현황 (Server & Network Inventory)

> 이 문서는 **운영 중인 실제 상태**를 기록한다. 변경이 있을 때마다 업데이트할 것.
> 마지막 업데이트: 2026-07-16

---

## 서버 현황

| 서버 | 모델 | 역할 | OS | 위치 |
|------|------|------|----|----|
| **P520** | Lenovo ThinkStation P520 | 운영계 (Proxmox + OpenStack 멀티노드) | Proxmox VE 8.4 | 405호 조교실 |
| **Gaming5** | Lenovo IdeaCentre Gaming5 17ACN7 | 개발계 (베어메탈 OpenStack AIO) | Ubuntu 24.04 | 405호 조교실 |

### P520 상세 사양

| 항목 | 값 |
|------|-----|
| CPU | Xeon W-2295 |
| RAM | 128GB ECC |
| GPU | RTX A5500 × 2 |
| 공인 IP | `210.94.240.179` |
| 내부 VM망 | `192.168.100.0/24` (Proxmox natzone) |
| Tailscale IP | `100.98.185.101` |

### Gaming5 상세 사양

| 항목 | 값 |
|------|-----|
| NIC | 1개 (`enp7s0f0`) |
| 공인 IP | `210.94.240.180` |
| MAC (실제) | `88:ae:dd:5d:00:28` |
| MAC (스푸핑) | `b0:38:6c:e1:a9:7f` ← 캠퍼스 차단 문제로 임시 적용 |
| Tailscale IP | `100.114.87.22` |

---

## OpenStack 노드 구성 (운영계 — P520 Proxmox 위 VM)

| VMID | 이름 | IP (ens18) | 역할 | CPU | RAM | 디스크 |
|------|------|-----------|------|-----|-----|--------|
| 200 | cjm-lb | 192.168.100.201 | Deploy host + HAProxy | 1 | 1GB | 10GB |
| — | VIP | 192.168.100.200 | Keepalived VIP (별도 VM 아님) | — | — | — |
| 201 | cjm-ct01 | 192.168.100.202 | Controller 1 | 2 | 4GB | 40GB |
| 202 | cjm-ct02 | 192.168.100.203 | Controller 2 | 2 | 4GB | 40GB |
| 203 | cjm-ct03 | 192.168.100.204 | Controller 3 + **Gateway Chassis** | 2 | 4GB | 40GB |
| 204 | cjm-cp01 | 192.168.100.205 | Compute 1 | 2 | 3.5GB | 50GB |
| 205 | cjm-cp02 | 192.168.100.206 | Compute 2 | 2 | 3.5GB | 50GB |
| 206 | cjm-st01 | 192.168.100.207 | Storage (Cinder LVM + Swift) | 1 | 4GB | OS20+Cinder50+Swift30 |
| — | GPU VM | 192.168.100.50 | vLLM 실행 (RTX A5500 #2 패스스루) | — | — | — |

---

## IP 할당 현황

### 공인 IP (`210.94.240.x`)

| IP | 용도 |
|----|------|
| `.179` | P520 운영계 서버 (Proxmox) |
| `.180` | Gaming5 개발계 서버 |
| `.254` | 캠퍼스 게이트웨이 |

### 내부망 (`192.168.100.x`)

| IP | 용도 |
|----|------|
| `.1` | Proxmox natzone 게이트웨이 |
| `.200` | OpenStack VIP (Keepalived) |
| `.201~.207` | OpenStack VM들 |
| `.210~.250` | Floating IP pool |
| `.50` | GPU vLLM VM |

### Tailscale 망 (`100.x.x.x`)

| IP | 장비 |
|----|------|
| `100.98.185.101` | P520 (Proxmox pve) |
| `100.114.87.22` | Gaming5 (개발계) |

---

## 네트워크 장비

| 장비 | 위치 | 역할 |
|------|------|------|
| TL-SG108 (TP-Link 8포트) | 405호 조교실 | 서버 ↔ 벽면 잭 연결 |
| HPE OfficeConnect 1820 (J9981A) | 405호 조교실 | 개발계·운영계 연결 |
| Juniper EX3300 | 415호 랙 | 캠퍼스 분배 스위치 (우리 제어 불가) |
| DASAN V1824 R3 | 415호 KT 구간 | 실제 게이트웨이 역할 |

---

## OpenStack 서비스 구성

| 서비스 | 버전/설정 |
|--------|---------|
| Kolla-Ansible | 22.0.0 |
| OpenStack 릴리즈 | 2026.1 (Gazpacho) |
| Neutron 백엔드 | OVN + Geneve (UDP/6081) |
| 블록 스토리지 | Cinder LVM (st01 /dev/sdb) |
| 오브젝트 스토리지 | Swift (st01 /dev/sdc) |
| LB | Octavia (Amphora) |
| HA | HAProxy + Keepalived (VRRP) |
| DB | MariaDB Galera (ct01~03) |
| MQ | RabbitMQ 클러스터 (ct01~03) |

---

## 외부 접근 현황

| 접근 방법 | 가능 여부 | 비고 |
|---------|---------|------|
| 교내 wifi → 공인 IP | ✅ 가능 | source 기준 필터링, 교내는 허용 |
| 외부 인터넷 → 공인 IP | ❌ 불가 | 캠퍼스 방화벽 source 차단 |
| Tailscale VPN | ✅ 가능 | 외부에서 서버 접근 유일한 방법 |

→ 캠퍼스 방화벽 상세: [[02_QnA_Archive/2026-07-05-devpc-nginx-external-access]]

## 관련 문서

- [[01_Concepts/SU-Cloud-Campus-Network]]
- [[01_Concepts/SU-Cloud-Project-Overview]]
- [[03_Guides/Tailscale-Setup-Guide]]
- [[03_Guides/Kolla-Ansible-Install-Guide]]
