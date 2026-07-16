---
title: "개발계(.180) 인터넷 불가 — 원인 전수 조사 런북"
type: "qa"
date: 2026-07-05
tags: ["#networking", "#troubleshooting", "#devpc", "#campus-network"]
related_nodes: ["[[02_QnA_Archive/2026-07-05-devpc-180-network-failure-resolved]]", "[[01_Concepts/SU-Cloud-Campus-Network]]"]
author: "AI Assistant"
status: "resolved"
raw_source: "[[00_Inbox/2026-07-05-devpc-internet-outage-raw]]"
---

# 개발계(.180) 인터넷 불가 — 원인 전수 조사 런북

## 1. ❓ 질의 및 배경 (Context)

- **상황:** 개발계 서버(MAC `88:ae:dd:5d:00:28`, IP `210.94.240.180`)가 게이트웨이/외부 인터넷 통신 전혀 안 됨
- **원칙:** 특정 가설에 꿰맞추지 않고 계층별 전수 조사 → 가능한 모든 원인을 배제하거나 확정

## 2. 🧠 분석 및 추론 (Analysis) — 계층별 원인 분류

### 이미 배제된 항목 (실측)
| 항목 | 배제 근거 |
|------|-----------|
| 1820 스위치 자체 | 벽포트72 직결해도 동일 증상 |
| STP 재계산 지연 | GUI에서 Spanning Tree: Disabled 확인 |
| Speed/Duplex mismatch | ethtool: 1000Mb/s Full 확인 |
| Proxy ARP 착시 | 게이트웨이 MAC `00:31:46:5b:d4:80` 확정 |
| 노트북 하드웨어 | 노트북은 같은 .180 IP로 정상 통신 성공 |

### 원인 후보 계층 분류
- **A. 하드웨어**: NIC 고장, 케이블, 스위치 포트 불량
- **B. OS/드라이버**: NIC 드라이버, netplan 설정 오류
- **C. IP/라우팅**: 서브넷 오기입, 라우팅 테이블 중복, MTU 불일치
- **D. 로컬 방화벽**: ufw, iptables/nftables, rp_filter
- **E. 우리 1820 스위치**: Port Security, VLAN 불일치
- **F. 캠퍼스 EX3300**: DHCP Snooping/IP Source Guard, Sticky MAC (→ **유력 후보**)
- **H. 캠퍼스 등록 시스템**: MAC 화이트리스트, 802.1X 미인증

### F2 유력 가설 — DHCP Snooping / IP Source Guard
- 엔터프라이즈 스위치는 DHCP로 할당된 IP-MAC 조합만 신뢰 바인딩으로 기록
- 정적(static) IP 서버는 이 바인딩 테이블에 없음 → 하드웨어 레벨에서 조용히 drop

## 3. 💡 해결책 및 결과 (Solution)

### Step 6 — MAC 스푸핑 교차 검증 (결정적)
```bash
sudo ip link set enp7s0f0 down
sudo ip link set enp7s0f0 address b0:38:6c:e1:a9:7f   # 노트북 MAC으로 교체
sudo ip link set enp7s0f0 up
sudo ip neigh flush dev enp7s0f0
ping -c 5 210.94.240.254
ping -c 5 8.8.8.8

# 테스트 후 반드시 원복
sudo ip link set enp7s0f0 down
sudo ip link set enp7s0f0 address 88:ae:dd:5d:00:28
sudo ip link set enp7s0f0 up
```

결과: MAC 교체 시 통신 성공 → **MAC 기반 차단 확정**

### 사전 확인 순서 (Step 1~5)
```bash
# D. 로컬 방화벽 확인
sudo ufw status verbose
sudo iptables -L -n -v
sudo nft list ruleset
sysctl net.ipv4.conf.all.rp_filter

# B. netplan 설정 확인
cat /etc/netplan/*.yaml
sudo netplan apply

# C. 라우팅 테이블 중복 확인
ip route show
ip route show table all
```

## 4. 🔗 추가 통찰 (Insights & Next Steps)

- 최종 원인 확정 및 임시조치: [[02_QnA_Archive/2026-07-05-devpc-180-network-failure-resolved]]
- 캠퍼스팀 문의 시 구체적 표현: "DHCP Snooping / IP Source Guard 설정 여부, 개발계 서버 IP-MAC 바인딩 예외 등록 요청"
- 조충희 교수님 경유 네트워크팀 정식 MAC 등록 요청 필요
