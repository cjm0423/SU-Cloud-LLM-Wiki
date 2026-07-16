---
title: "네트워크 경로 진단 — L2/L3 도구 레퍼런스"
type: "concept"
date: 2026-06-21
tags: ["#networking", "#troubleshooting", "#vlan", "#traceroute"]
related_nodes: ["[[01_Concepts/SU-Cloud-Campus-Network]]", "[[01_Concepts/VXLAN]]", "[[01_Concepts/SDN-OVS-OVN-VXLAN]]", "[[03_Guides/Campus-Network-Runbook]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-06-21-network-path-diagnosis-raw]]"
---

# 네트워크 경로 진단 — L2/L3 도구 레퍼런스

## 한 줄 정의

네트워크 경로 문제를 진단할 때 L2(스위치·MAC)와 L3(라우터·IP)를 나눠서 접근하는 방법론과 도구 레퍼런스.

## 상세 설명

### 핵심 원칙: L2 vs L3 구분

모든 진단 도구의 분기점은 **"이 도구가 L2를 보는가 L3를 보는가"**:

| 계층 | 주소 체계 | 다루는 장비 | 진단 도구 |
|------|----------|-----------|----------|
| **L2 (Data Link)** | MAC 주소 | 스위치, 브리지 | `ip neigh`, `arp-scan`, `lldpctl`, `tcpdump` |
| **L3 (Network)** | IP 주소 | 라우터, L3 스위치 | `traceroute`, `mtr`, `ip route`, `ping` |

> **핵심**: 스위치(L2 장비)는 IP를 라우팅하지 않으므로 **L3 도구(traceroute)에 안 보임**. TL-SG108이나 랙 access 스위치는 TTL을 건드리지 않고 그대로 전달. 중간 L2 구간은 LLDP로 별도 확인 필요.

```
P520 ── TL-SG108 ── 벽면잭 ── [랙 access SW] ─광─ [백본 L3] ─ .254 ─ 외부
        └──────── L2 구간 (traceroute에 안 보임) ────────┘  └ hop1 ┘
                  ↑ LLDP / ARP 로 식별
```

---

### 핵심 개념

#### 백본 (Backbone)
네트워크의 간선 도로. 건물·층을 잇는 고용량 회선과 코어 스위치 묶음. P520도 이 백본을 타고 외부로 나감.

#### VLAN — 같은 스위치, 다른 세계
물리적으로 한 스위치에 꽂혀 있어도 논리적으로 브로드캐스트 도메인을 쪼개는 기술.

| 포트 모드 | 태그 | 의미 |
|---------|------|------|
| **Access** | 없음 | 단 하나의 VLAN만 전달. 일반 PC 포트 |
| **Trunk** | 802.1Q | 여러 VLAN을 한 케이블로 동시 전달 |

> 운영계 VLAN + VM 트래픽(여러 VLAN)을 케이블 한 가닥으로 받으려면 그 포트가 **trunk**여야 함.

#### traceroute 동작 원리 — TTL 트릭
1. IP 헤더 TTL값이 라우터를 지날 때마다 1씩 감소
2. TTL=0 → 라우터가 패킷 버리고 "ICMP Time Exceeded" 응답
3. traceroute: TTL=1부터 1씩 늘려가며 경로를 한 hop씩 그림

```bash
TTL=1 → 첫 라우터 응답 → hop1 = 210.94.240.254
TTL=2 → 두 번째 라우터 응답 → hop2 = 백본 L3
TTL=n → 목적지 도달 = 끝
```

> **`* * *` 는 장애가 아닐 수 있다.** 목적지까지 도달하면 정상. 그 hop이 ICMP 응답만 안 보내도록 설정한 것. 목적지 포함 이후 전부 `*`이면 그때 진짜 차단.

---

### 도구 레퍼런스

#### L3 도구

```bash
# 기본 경로 추적
traceroute -n 8.8.8.8          # IP로만 표시 (-n: DNS lookup 스킵)
traceroute -I 8.8.8.8          # ICMP 모드 (기본 UDP, 방화벽 환경에서는 ICMP)

# 연속 모니터링 (실시간 패킷 손실·지연 확인)
mtr 8.8.8.8
mtr --report --report-cycles 10 8.8.8.8

# 라우팅 테이블 확인
ip route show
ip route show table all
ip rule show                   # policy routing 규칙

# 특정 경로 확인
ip route get 8.8.8.8
```

#### L2 도구

```bash
# ARP 테이블 (알려진 L2 이웃)
ip neigh show
arp -n

# 같은 L2 세그먼트의 모든 장비 스캔
arp-scan -l                    # 로컬 서브넷 전체 스캔
arp-scan 192.168.100.0/24

# L2 이웃 장비 정보 (스위치 식별)
lldpctl                        # 직접 연결된 스위치명·포트 확인

# 패킷 레벨 분석
tcpdump -ni ens18 arp          # ARP 패킷만 캡처
tcpdump -ni ens18 icmp -e      # ICMP + L2 헤더(MAC) 표시
tcpdump -ni ens18 udp port 6081 -vv   # Geneve 터널 패킷
```

#### 포트/서비스 확인

```bash
# 열린 포트 확인
ss -tlnp                       # TCP 리스닝
ss -tlnp | grep ':80\|:443'

# 연결 상태
ss -tnp
```

#### 진단 체크리스트

| 확인 항목 | 도구 |
|---------|------|
| 외부 L3 경로 | `traceroute -n`, `mtr` |
| 바로 위 L2 스위치 식별 | `lldpctl` |
| 같은 L2 이웃 목록 | `arp-scan -l`, `ip neigh` |
| inbound 외부 도달성 | 외부 vantage에서 테스트 |
| 호스트 NAT 경로 | `conntrack`, `iptables -t nat -L` |
| 로컬 방화벽 확인 | `ufw status`, `iptables -L`, `nft list ruleset` |
| MTU 불일치 | `ping -M do -s 1400 8.8.8.8` |

---

### 권한 경계 — 우리가 볼 수 없는 것

| 구간 | 권한 |
|------|------|
| P520 서버 내부 | ✅ 완전 제어 |
| TL-SG108 (우리 소유) | ✅ 웹 GUI 접근 가능 |
| 405호 벽면 잭 이후 | ❌ 캠퍼스 네트워크팀 권한 |
| 415호 랙 스위치 (Juniper EX3300 등) | ❌ 캠퍼스 권한 |
| 백본·게이트웨이 | ❌ 캠퍼스/KT 권한 |

→ 캠퍼스 장비 진단이 필요하면 조충희 교수님 경유 네트워크팀 요청

## SU Cloud에서의 활용

- Proxmox에서 `traceroute -n 8.8.8.8` → hop1 = `.254` 확인 (L2 스위치는 보이지 않음)
- `lldpctl`로 직접 연결된 스위치(115호 랙 장비) 식별 시도
- Geneve 터널 패킷 분석: `tcpdump -ni ens18 udp port 6081`
- 개발계 인터넷 불가 진단: [[02_QnA_Archive/2026-07-05-devpc-180-internet-outage-runbook]]

## 관련 개념

- [[01_Concepts/SU-Cloud-Campus-Network]]
- [[01_Concepts/VXLAN]]
- [[01_Concepts/SDN-OVS-OVN-VXLAN]]
- [[03_Guides/Campus-Network-Runbook]]
