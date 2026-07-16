---
title: "Proxmox"
type: "concept"
date: 2026-06-18
tags: ["#proxmox", "#hypervisor", "#su-cloud", "#infrastructure"]
status: "stable"
related_nodes: ["[[OpenStack-Overview]]", "[[VXLAN]]", "[[2026-06-13-kickoff]]"]
author: "SU-Cloud Team"
---

# Proxmox

## 한 줄 정의

Proxmox VE(Virtual Environment)는 KVM과 LXC를 지원하는 오픈소스 하이퍼바이저로, SU Cloud에서는 OpenStack 수동 설치 실습을 위한 중간 가상화 계층으로 사용한다.

## SU Cloud에서의 역할

```
학교 물리 서버 (ThinkStation)
        │
    Proxmox VE
        │
 ┌──────┼──────┐
VM1    VM2    VM3
(Controller) (Compute) (실습용)
        │
   OpenStack
```

- 학생들이 **같은 물리 서버에서 여러 VM을 생성**하여 Controller Node, Compute Node 역할을 나눠 OpenStack 수동 설치 실습 가능
- 실습 후 VM을 초기화하거나 스냅샷으로 되돌리기 용이
- 운영계 전환 시에는 가상화 병목을 줄이기 위해 **native Ubuntu/OpenStack** 으로 이동 예정

## 설치 이력 (2026-06-15)

| 버전 | 결과 |
|------|------|
| Proxmox 9.2 | ❌ 하드웨어 인식 충돌 |
| Proxmox 8.4 | ✅ 정상 설치 확인 |

→ 카카오톡 기록에 "최신 Proxmox 9.2 설치 시 하드웨어 인식 충돌 → 8.4로 설치하면 정상" 기록됨

## 원격 접속 구조

```
외부 (학생 PC)
      │
  Tailscale VPN
      │
학교 서버 Proxmox Web UI (8006 포트)
      │
학생별 VM 접속
```

- [[Tailscale]]로 외부에서 학교 장비에 안전하게 접근
- 공용 계정 및 접근 권한 정책은 별도 확인 필요

## 관련 개념

- [[OpenStack-Overview]] — Proxmox 위에서 설치되는 클라우드 플랫폼
- [[VXLAN]] — Compute Node 간 네트워크 (멀티 노드 확장 시)
- [[Tailscale]] — 원격 접속 VPN
- [[2026-06-13-kickoff]] — Proxmox 도입 결정 배경
