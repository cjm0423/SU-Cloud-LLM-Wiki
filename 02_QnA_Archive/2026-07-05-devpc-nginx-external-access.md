---
title: "개발계 외부 접속 검증 — 캠퍼스 방화벽은 포트가 아닌 source 기준 차단"
type: "qa"
date: 2026-07-05
tags: ["#networking", "#nginx", "#firewall", "#devpc", "#tailscale"]
related_nodes: ["[[02_QnA_Archive/2026-07-05-devpc-180-network-failure-resolved]]", "[[01_Concepts/SU-Cloud-Campus-Network]]"]
author: "AI Assistant"
status: "resolved"
raw_source: "[[00_Inbox/2026-07-05-devpc-nginx-raw]]"
---

# 개발계 외부 접속 검증 — 캠퍼스 방화벽은 포트가 아닌 source 기준 차단

## 1. ❓ 질의 및 배경 (Context)

- **상황:** 개발계(`210.94.240.180`)에 Tailscale 없이 순수 캠퍼스 공인 IP로 외부에서 직접 접속 가능한지 검증
- **핵심 질문:** 캠퍼스 방화벽은 포트 화이트리스트 방식인가, 아니면 다른 기준으로 필터링하는가?

## 2. 🧠 분석 및 추론 (Analysis)

### 포트 점유 현황
```bash
sudo ss -tlnp | grep -E ':80|:443'
```
| 포트 | 서비스 | 바인딩 |
|------|--------|--------|
| 80 | uwsgi (Horizon) | `210.94.240.180`만 |
| 8000, 8004 | uwsgi (Nova/Heat) | `210.94.240.180`만 |
→ 80이 점유되어 nginx는 **8888 포트**로 구성

### 3단계 테스트 결과

**1차: 외부(집)에서 직접 접속**
| 접속 방식 | 결과 |
|-----------|------|
| `http://210.94.240.180:8888` (순수 외부) | **Timeout** |
| `http://100.114.87.22:8888` (Tailscale IP) | **200 OK** |
| `http://100.114.87.22:80` (Tailscale IP) | Connection refused (Horizon이 .180에만 바인딩) |

**2차: 포트별 재확인 (집 PC)**
포트 443, 22, 80, 8022, 3306, 8888 — **전부 Timeout**
→ 포트 화이트리스트 가설 기각

**3차: 교내 wifi vs 외부 대조**
| 접속 위치 | 결과 |
|-----------|------|
| 교내 wifi → `:80` | **접속 성공** |
| 외부 인터넷 → `:80` | Timeout |

## 3. 💡 해결책 및 결과 (Solution)

### 결론 (3가지)

1. **캠퍼스 방화벽은 포트 화이트리스트 방식이 아니라, 출발지(source) 기준으로 인바운드를 필터링한다.**
   - 교내 IP 대역: 통과 / 외부 인터넷: 포트 무관 전면 차단

2. **Tailscale은 캠퍼스 인바운드 방화벽을 완전히 우회한다.**
   - 서버가 coordination 서버에 아웃바운드 연결을 먼저 맺어두고 WireGuard 터널 유지
   - 방화벽 입장에서는 새 인바운드가 아닌 기존 아웃바운드 세션 응답으로 인식

3. **`Timeout` vs `Connection refused` 구분 필수**
   - Timeout = 방화벽 차단 (패킷이 서버에 도달 못 함)
   - Connection refused = 서버 도달했으나 해당 포트에 서비스 없음

## 4. 🔗 추가 통찰 (Insights & Next Steps)

- 순수 캠퍼스 공인 IP로 외부 접속은 불가능 → Tailscale 필수
- Horizon `bind: 210.94.240.180` 방식은 Tailscale IP에서 접근 불가 → 외부 서비스 시 `0.0.0.0` 바인딩 또는 nginx 역방향 프록시 필요
- 이전 분석("80/8022 포트가 화이트리스트")은 오류 판단 → 실제로는 교내에서만 열려 있었음
