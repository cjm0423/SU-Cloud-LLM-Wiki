---
title: "SU Cloud 캠퍼스 네트워크 구조"
type: "concept"
date: 2026-07-04
tags: ["#networking", "#campus", "#su-cloud", "#infra"]
status: "stable"
related_nodes: ["[[01_Concepts/SU-Cloud-Project-Overview]]", "[[01_Concepts/Proxmox]]", "[[01_Concepts/Floating-IP]]"]
author: "AI Assistant"
raw_source: ["[[00_Inbox/2026-06-28-campus-network-draft-raw]]", "[[00_Inbox/2026-07-04-campus-network-analysis-raw]]"]
---

# SU Cloud 캠퍼스 네트워크 구조

## 한 줄 정의

SU Cloud 프로젝트 서버들이 학교 캠퍼스 네트워크를 통해 인터넷에 연결되는 물리·논리 경로 구조.

## 상세 설명

### 전체 물리 경로

```
405호 조교실                       415호 랙           백본/관문      외부
────────────                      ─────────         ─────────    ────
운영계(.179) ─┐
              ├─ HPE 1820 ─ 72번 벽포트 ─ [분배 스위치] ─ 백본L3 ─ .254 ─ 인터넷
개발계(.180) ─┘
```

### 405호 조교실 구성

| 구분 | 서버 | Public IP | 방식 |
|------|------|-----------|------|
| 운영계 | Lenovo ThinkStation P520 | `.179` | Proxmox VE + Kolla-Ansible |
| 개발계 | Lenovo IdeaCentre Gaming5 | `.180` | 베어메탈 + Kolla-Ansible AIO |

**HPE OfficeConnect 1820 스위치 (J9981A)**
- 운영계·개발계 서버를 하나의 포트에 연결
- AIO 구성이라 VLAN 분리 불필요 → 일반 L2 스위칭만 사용

### 415호 랙 구성 (2026-07-04 현장 확인)

데이터 흐름 (각 호실 → 인터넷):
```
각 호실 벽포트 (72번 포함)
    ↓
패치패널 (AMP/NETCONNECT, 호실별 라벨)
    ↓
교내망 구간 — DASAN V2624G-POES / Juniper EX3300
    (여러 호실 트래픽 집결)
    ↓
KT 인입 구간 — olleh 스위치 → PREMIER → PoE 인젝터 → Ubiquoss → HPE 1820(415호) → DASAN V1824 R3 라우터
    (KT 장비, 마지막 라우터가 실제 게이트웨이)
    ↓
광분배반 (VSOF-FDF-12C)
```

### 확정된 정보 (실측값)

| 항목 | 값 |
|------|-----|
| 운영계 공인 IP | `210.94.240.179/24` |
| 개발계 공인 IP | `210.94.240.180/24` |
| 게이트웨이 | `210.94.240.254` (traceroute hop1 확정) |
| 할당 공인 IP | `.179~.180` (2개) |
| 내부 VM망 | `192.168.100.0/24` (Proxmox vmbr1) |
| 외부 아웃바운드 | 정상 (Loss 0%, `mtr` 확인) |
| DNS | `210.94.224.10` |

### 캠퍼스 방화벽 특성

- **인바운드 차단**: 포트 화이트리스트 방식이 아님 → **출발지(source) 기준**으로 필터링
  - 교내 IP 대역: 통과
  - 외부 인터넷: 포트 무관 전면 차단
- **외부 접속 방법**: Tailscale(WireGuard 기반 아웃바운드 터널) 필수

### MAC 기반 접근 제어

Juniper EX3300 (415호) 사용 가능성 있는 보안 기능:
- **DHCP Snooping**: DHCP로 할당된 IP-MAC 조합만 신뢰 바인딩 기록
- **IP Source Guard**: 바인딩 테이블에 없는 IP-MAC 패킷 드롭
- 정적 IP 서버는 사전 등록 필요 → 조충희 교수님 경유 네트워크팀 신청

### 진단 도구

| 보고 싶은 것 | 도구 |
|------------|------|
| 외부 L3 경로 | `traceroute`, `mtr` |
| 바로 위 L2 스위치 | `lldpctl`, `tcpdump` |
| 같은 L2 이웃 | `ip neigh`, `arp-scan -l` |
| 인바운드 외부 도달성 | 외부 vantage에서 테스트 |
| 호스트 NAT 경로 | `conntrack`, `iptables -t nat` |

## SU Cloud에서의 활용

- Kolla-Ansible `globals.yml`의 `network_interface`, `neutron_external_interface` 설정 시 이 토폴로지 기반으로 NIC 지정
- 외부 서비스 접근은 Tailscale을 통한 우회 방식 사용 (캠퍼스 방화벽 우회)
- 공인 IP 추가 필요 시 조충희 교수님 경유 전산실 신청

## 관련 개념

- [[01_Concepts/SU-Cloud-Project-Overview]]
- [[01_Concepts/Proxmox]]
- [[01_Concepts/Floating-IP]]
- [[02_QnA_Archive/2026-07-05-devpc-180-network-failure-resolved]]
- [[02_QnA_Archive/2026-07-05-devpc-nginx-external-access]]
