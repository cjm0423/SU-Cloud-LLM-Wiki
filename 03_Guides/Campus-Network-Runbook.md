---
title: "SU Cloud 학내망 경로 추적 Runbook"
type: "guide"
date: 2026-06-21
tags: ["#guide", "#networking", "#campus-network", "#runbook"]
status: "stable"
related_nodes: ["[[01_Concepts/SU-Cloud-Campus-Network]]", "[[01_Concepts/Network-Path-Diagnosis]]", "[[02_QnA_Archive/2026-07-05-devpc-180-internet-outage-runbook]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-06-21-campus-network-runbook-raw]]"
---

# SU Cloud 학내망 경로 추적 Runbook

## 개요

운영계 서버(P520, `210.94.240.179`)에서 출발해 `TL-SG108 → 조교실 벽면 → 1실습관 랙 → 학교 백본 → gateway .254 → 외부`로 이어지는 물리·논리 경로를 직접 관측하고, 할당 공인 IP가 외부에서 실제로 돌아오는지(inbound)까지 검증하는 Runbook.

> 전체 원본(스크린샷, netscan.sh 스크립트 포함): [[00_Inbox/2026-06-21-campus-network-runbook-raw]]

---

## Phase 1. 아웃바운드 경로 확인 (서버 → 인터넷)

### 1-1. traceroute로 L3 hop 파악

```bash
# 기본 경로 확인 (DNS lookup 없이)
traceroute -n 8.8.8.8

# 예상 결과
# hop1: 210.94.240.254  ← 게이트웨이 (L2 스위치들은 hop에 안 나타남)
# hop2: xxx.xxx.xxx.xxx ← 학교 백본 L3
# ...
# hopN: 8.8.8.8
```

### 1-2. mtr로 지속 모니터링 (패킷 손실 파악)

```bash
mtr --report --report-cycles 20 8.8.8.8
# Loss%가 지속되면 해당 hop에서 문제 발생
```

### 1-3. 게이트웨이 ARP 확인

```bash
# ARP 캐시 초기화 후 신선한 조회
ip neigh flush dev ens18
ping -c 1 210.94.240.254
ip neigh show | grep 210.94.240.254
# → 게이트웨이 MAC 확인 (예: 00:31:46:5b:d4:80)
```

---

## Phase 2. L2 구간 파악 (스위치 식별)

### 2-1. LLDP로 직접 연결된 스위치 식별

```bash
apt install -y lldpd
lldpctl
# → 직접 연결된 스위치 이름, 포트 ID, VLAN 정보 출력
# → 415호 랙 스위치가 어느 장비인지 확인 가능
```

### 2-2. 같은 L2 세그먼트 장비 스캔

```bash
apt install -y arp-scan
arp-scan -l   # 로컬 서브넷 전체
arp-scan 210.94.240.0/24   # 공인 IP 대역
```

### 2-3. VLAN 태그 확인

```bash
# 수신 프레임에 VLAN 태그가 있는지 확인
tcpdump -ni ens18 -e vlan
# VLAN 태그 없으면 access 포트, 있으면 trunk 포트
```

---

## Phase 3. 인바운드 도달성 확인 (외부 → 서버)

### 3-1. 외부 vantage에서 테스트

교외(집 PC 등)에서 실행:
```bash
# 캠퍼스 경계 방화벽이 포트 기준인지 source 기준인지 확인
curl -v --connect-timeout 5 http://210.94.240.179:80
curl -v --connect-timeout 5 http://210.94.240.179:8888
curl -v --connect-timeout 5 http://210.94.240.179:22

# 모두 Timeout이면 source 기준 차단 (포트 무관)
# Connection refused이면 서버에 도달했으나 해당 포트 서비스 없음
```

> **SU Cloud 확인 결과:** 외부에서는 포트 종류와 무관하게 전면 차단 (source 기준 필터링)
> → Tailscale을 통한 접근만 가능
> → 상세: [[02_QnA_Archive/2026-07-05-devpc-nginx-external-access]]

### 3-2. 교내 wifi에서 테스트

교내 wifi 연결 상태에서:
```bash
curl -v --connect-timeout 5 http://210.94.240.179:80
# 교내에서는 접속 성공 → 캠퍼스 경계가 source 필터링임을 확인
```

---

## Phase 4. netscan.sh 자동화 스크립트

> 원본 스크립트 전체: [[00_Inbox/2026-06-21-campus-network-runbook-raw]]

```bash
#!/bin/bash
# 기본 경로 정보 수집
echo "=== IP 설정 ==="
ip -br addr

echo "=== 라우팅 테이블 ==="
ip route show

echo "=== 게이트웨이 ARP ==="
arp -n | grep -E "ens|eth"

echo "=== traceroute ==="
traceroute -n -w 2 -q 1 8.8.8.8

echo "=== LLDP 이웃 ==="
lldpctl 2>/dev/null || echo "lldpd 미설치"

echo "=== 포트 리스닝 ==="
ss -tlnp
```

---

## 결과 기록 양식

| 확인 항목 | 확인 방법 | 결과 |
|---------|---------|------|
| 게이트웨이 IP | `ip route` | 210.94.240.254 |
| 게이트웨이 MAC | `ip neigh` | 00:31:46:5b:d4:80 |
| traceroute hop1 | `traceroute -n 8.8.8.8` | .254 |
| L2 스위치명 | `lldpctl` | (확인 필요) |
| 연결 포트 모드 | `tcpdump vlan` | access/trunk |
| 외부 inbound | 외부 curl | 전면 차단 |
| 교내 접속 | 교내 curl | 성공 |

---

## 권한 경계

| 구간 | 권한 | 대응 |
|------|------|------|
| P520 내부 | ✅ 완전 제어 | 직접 수행 |
| TL-SG108 | ✅ 웹 GUI | 직접 수행 |
| 415호 랙 스위치 | ❌ 캠퍼스 | 교수님 경유 요청 |
| 백본·게이트웨이 | ❌ 캠퍼스 | 전산실 문의 |

## 관련 문서

- [[01_Concepts/SU-Cloud-Campus-Network]]
- [[01_Concepts/Network-Path-Diagnosis]]
- [[02_QnA_Archive/2026-07-05-devpc-180-internet-outage-runbook]]
- [[02_QnA_Archive/2026-07-05-devpc-nginx-external-access]]
