---
title: "Tailscale 설치 및 Proxmox 원격 접속 가이드"
type: "guide"
date: 2026-06-14
tags: ["#guide", "#tailscale", "#proxmox", "#vpn"]
related_nodes: ["[[01_Concepts/HA-Concepts]]", "[[01_Concepts/Proxmox]]", "[[03_Guides/Proxmox-Installation-Guide]]"]
author: "AI Assistant"
raw_source: ["[[00_Inbox/2026-06-14-tailscale-setup-raw]]", "[[00_Inbox/2026-06-14-tailscale-remote-raw]]"]
---

# Tailscale 설치 및 Proxmox 원격 접속 가이드

## 개요

Proxmox 서버에 Tailscale을 설치해 팀원들이 외부에서 학교 서버 내부망(`192.168.100.x`)에 접속할 수 있도록 VPN 터널을 구성하는 가이드.

## 사전 조건

- Proxmox VE가 설치된 서버
- 팀 공용 구글 계정 (Tailscale 로그인용)
- 루트 권한

---

## Part A. Proxmox 서버 측 설정

### A-1. 엔터프라이즈 저장소 비활성화

Proxmox 무료 버전 사용 시 `401 Unauthorized` 오류 방지:

```bash
vi /etc/apt/sources.list.d/pve-enterprise.list
# deb https://... 줄 맨 앞에 # 추가해서 주석 처리
```

### A-2. Tailscale 설치

```bash
apt update
curl -fsSL https://tailscale.com/install.sh | sh
```

### A-3. Tailscale 실행 및 계정 연동

```bash
tailscale up
# → 출력된 https://login.tailscale.com/a/... 링크를 브라우저에서 열어
# → 팀 공용 구글 계정(sahmyookcloud@gmail.com)으로 로그인
```

### A-4. Tailscale IP 확인 및 기록

```bash
tailscale ip -4   # → 100.x.x.x 형태의 IP 기록 (앞으로 접속할 주소)
```

### A-5. Subnet Router 설정 (vmnet 접근 허용)

Proxmox 내부 VM망(`192.168.100.0/24`)을 Tailscale을 통해 접근 가능하게:

```bash
# 1단계: 포워딩 영구 허용
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
sysctl -p /etc/sysctl.d/99-tailscale.conf

# 2단계: 서브넷 라우팅 광고
tailscale up --advertise-routes=192.168.100.0/24
```

### A-6. Tailscale 관리자 패널에서 라우트 승인

1. https://login.tailscale.com/ → 팀 공용 계정 로그인
2. Machines에서 `pve` 클릭 → **Routing settings**
3. Subnet routes `192.168.100.0/24` 항목 스위치 **Approve(승인)**

### A-7. Proxmox SDN 내부 VM망 구성

1. **Zone 생성**: Datacenter → SDN → Zones → Add → Simple
   - ID: `natzone` (특수문자 제외, 영문+숫자만)
   - IPAM: `pve`
2. **VNet 생성**: SDN → VNets → Add
   - Name: `vmnet`, Zone: `natzone`
3. **Subnet 설정**: vmnet → Subnets → Create
   - Subnet: `192.168.100.0/24`, Gateway: `192.168.100.1`
   - **SNAT: 체크** (VM들의 인터넷 연결 필수)
4. **적용**: SDN → Apply

---

## Part B. 팀원 PC (클라이언트) 설정

### B-1. Tailscale 클라이언트 설치

- https://tailscale.com/download 에서 OS별 설치
- 설치 후 팀 공용 구글 계정으로 로그인 → 서버와 같은 VPN망에 합류

### B-2. Proxmox 웹 GUI 접속

```
https://100.x.x.x:8006
```
- 브라우저 보안 경고 → 고급 → 이동(안전하지 않음)
- 계정: `root` / 비밀번호: 서버 설정 시 입력한 값

---

## Part C. VM SSH 접속 설정

### C-1. Ubuntu VM 설치 시 고정 IP 설정

Ubuntu 설치 화면 → Network Connections → 네트워크 카드(ens18) → Edit IPv4 → Manual:

| 항목 | 값 |
|------|-----|
| Subnet | `192.168.100.0/24` |
| Address | `192.168.100.##` (팀원별 할당) |
| Gateway | `192.168.100.1` |
| Name servers | `8.8.8.8` |

### C-2. VM IP 할당표

| VM | 사용자 | IP |
|----|--------|-----|
| vm-kjh | 김재현 | 192.168.100.12 |
| vm-lmg | 이민기 | 192.168.100.13 |
| vm-pjw | 박준우 | 192.168.100.14 |
| GPU VLLM VM | - | 192.168.100.50 |
| LB (cjm-lb) | - | 192.168.100.201 |
| CT01~03 | - | 192.168.100.202~204 |
| CP01~02 | - | 192.168.100.205~206 |
| ST01 | - | 192.168.100.207 |

### C-3. SSH 접속

```bash
ssh 계정이름@192.168.100.##
```

---

## 주의사항

- 팀원 PC가 같은 Tailscale 계정에 연결되어 있으면 `192.168.100.x` 전체 대역에 접근 가능
- Subnet 광고 승인이 안 되면 IP 직접 접근 불가

## 관련 문서

- [[01_Concepts/HA-Concepts]] — Tailscale의 VPN 개념 설명
- [[01_Concepts/SU-Cloud-Campus-Network]] — 캠퍼스 네트워크와 Tailscale 우회
