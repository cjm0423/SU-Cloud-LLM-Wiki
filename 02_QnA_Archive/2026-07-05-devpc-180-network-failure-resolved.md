---
title: "개발계(.180) 네트워크 장애 — 원인 확정 및 MAC 스푸핑 임시 조치"
type: "qa"
date: 2026-07-05
tags: ["#networking", "#troubleshooting", "#devpc", "#campus-network"]
related_nodes: ["[[02_QnA_Archive/2026-07-05-devpc-180-internet-outage-runbook]]", "[[01_Concepts/SU-Cloud-Campus-Network]]"]
author: "AI Assistant"
status: "resolved"
raw_source: "[[00_Inbox/2026-07-05-devpc-network-failure-raw]]"
---

# 개발계(.180) 네트워크 장애 — 원인 확정 및 MAC 스푸핑 임시 조치

## 1. ❓ 질의 및 배경 (Context)

- **상황:** 런북([[02_QnA_Archive/2026-07-05-devpc-180-internet-outage-runbook]]) 전수 조사 완료 후 원인 확정 및 임시 조치
- **핵심 결론:** 개발계 서버 MAC(`88:ae:dd:5d:00:28`)이 캠퍼스 네트워크에서 MAC 주소 기준으로 차단됨

## 2. 🧠 분석 및 추론 (Analysis)

### 전수 조사 최종 결과

| 계층 | 검증 결과 |
|------|-----------|
| D. 로컬 방화벽 (ufw/iptables/nft) | **배제** — 전부 비활성/ACCEPT |
| D. rp_filter | **배제** — all/default/enp7s0f0 전부 `2`(loose) |
| B. netplan 설정 | **배제** — 정확, 문법 오류 없음 |
| B. systemd-networkd | **배제** — `State: routable` 정상 |
| C. 라우팅 테이블 | **배제** — default route 1개, 이상 없음 |
| A. 하드웨어/드라이버 | **배제 확정** — 설치 시점(2026-07-06 04:08) `kr.archive.ubuntu.com` HTTP 200 기록 확인 |
| **F/H. MAC 기반 차단** | **확정** — MAC 교체 시 5/5 성공(0% 손실), 원복 시 100% 손실 즉시 재현 |

### 결정적 증거
동일 서버·케이블·포트·IP를 고정하고 MAC만 변경 → 증상이 완전히 사라짐 = 순수 MAC 기반 차단

### 설치 당시엔 통신 됐었음
`journalctl`에서 2026-07-06 04:08~04:22, 동일 MAC/IP로 `kr.archive.ubuntu.com` HTTP 200 반복 성공 기록 확인 → 최초엔 허용됐으나 이후 등록 만료/정책 변경 가능성 유력

## 3. 💡 해결책 및 결과 (Solution)

### 임시 조치 — netplan MAC 스푸핑

팀원 노트북의 등록된 MAC(`b0:38:6c:e1:a9:7f`)을 개발계 NIC에 영구 적용:

```yaml
# /etc/netplan/*.yaml
network:
  version: 2
  ethernets:
    enp7s0f0:
      match:
        macaddress: "88:ae:dd:5d:00:28"
      set-name: enp7s0f0
      macaddress: "b0:38:6c:e1:a9:7f"    # 노트북 MAC 스푸핑
      addresses:
        - "210.94.240.180/24"
      nameservers:
        addresses: [210.94.224.10]
      routes:
        - to: "default"
          via: "210.94.240.254"
```

```bash
sudo netplan apply
ip link show enp7s0f0   # link/ether b0:38:6c:e1:a9:7f 확인
```

### ⚠️ 주의사항 — 동시 접속 절대 금지
이 MAC은 팀원 노트북의 실제 등록 MAC. **개발계 서버가 연결된 동안 해당 노트북은 같은 대역에 절대 동시 연결 금지** (IP/MAC 충돌 → 둘 다 통신 불가)

## 4. 🔗 추가 통찰 (Insights & Next Steps)

- 정식 해결: 조충희 교수님 경유 캠퍼스 네트워크팀에 `88:ae:dd:5d:00:28` / `210.94.240.180` 조합 등록 요청
- 정확한 차단 메커니즘(Sticky MAC violation, IP Source Guard, MAC 화이트리스트)은 캠퍼스 장비 접근 권한 없어 특정 불가
- 임시 MAC 스푸핑 상태로 Kolla-Ansible AIO 배포 진행 완료
