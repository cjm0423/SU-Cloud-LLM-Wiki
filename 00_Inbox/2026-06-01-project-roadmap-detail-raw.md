---
title: "SU-Cloud 2026 로드맵 상세"
type: "raw"
date: 2026-06-01
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[01_Concepts/SU-Cloud-Project-Roadmap]]"
---
# SU-Cloud 2026 · 로드맵

멘토 2 + 멘티 4 · 405호(server pc) · 6월 → 12월

---

## Phase 0 · 6월 — 학습 & 기반 세팅

> Proxmox 위 VM에서 OpenStack을 수동 설치해 Horizon에 로그인하는 것까지 완료 (학습 목적)
> 
- [ ]  **P520에 Proxmox VE 설치** — 공동계정으로 멘티 4명 접속 환경 구성
- [ ]  **외부 접근 세팅** — Tailscale 설치, 집·외부에서 Proxmox 콘솔 접근 확인
- [ ]  **멘티 4명 OpenStack 수동 설치 실습** — Proxmox VM 위 OpenStack and Kolla 직접 설치, Nova / Neutron / Keystone 흐름 손으로 익히기
- [ ]  **학교 네트워크 파악** — 전산실 협의: VLAN 가능 여부, 스위치 구매 필요성, Public IP 2개 할당 방식 확정
- [ ]  **외부 진입 아키텍처 확정** — Edge VM + nginx 2 listen 구조, 라우터 브리지 vs 1:1 NAT 결정

---

## Phase 1 · 7월 — 개발계 구축 (Ubuntu native)

> 개발계 Horizon에서 VM 생성 → Floating IP 할당 → SSH 접속 전체 흐름 동작 확인
> 
- [ ]  **Gaming5에 Ubuntu 설치** — Proxmox 제거 후 베어메탈 Ubuntu로 전환
- [ ]  OpenStack 수동 설치 혹은 **Kolla-Ansible 멀티노드 배포** — globals.yml 기준, Nova / Neutron / Keystone / Glance / Horizon
- [ ]  **VLAN 구성 확정** — VLAN 110/120 개발계, VLAN 10/20 운영계, 스위치 구매 후 트렁크 설정
- [ ]  **Edge-GW 구성** — P520에 nginx 2 listen 설정, 개발계 / 운영계 분기
- [ ]  **팀 원격 접근 환경 통일** — Tailscale or VPN, 멘티 4명 전원 접근 확인

---

## Phase 2 · 8–9월 — 운영계 구축 & 흐름 검증

> 멘티가 운영계 OpenStack에서 VM을 발급받아 3-tier 앱을 배포하고, 외부에서 접근 가능한 상태까지 완료
> 
- [ ]  **P520 베어메탈 Kolla-Ansible 배포** — Cinder / Horizon 포함, 운영계 OpenStack 전체 서비스 기동
- [ ]  **E2E 사용자 흐름 검증** — VM 생성 → FIP 할당 → Security Group → SSH 접속 → 앱 배포
- [ ]  **VM 위 3-tier 앱 배포** — Ubuntu cloud image + Docker Compose, Nginx / Flask / MySQL 구조 배포 및 요청 흐름 설명
- [ ]  **모니터링 기초 세팅** — 서버 리소스 및 OpenStack 서비스 상태 확인 체계 구성

---

## Phase 3 · 10월 — Self-service Portal MVP

> 사용자가 VM 신청 → 승인 → 자동 생성까지 이어지는 흐름이 최소 수준으로 동작
> 
- [ ]  **Horizon 갭 분석** — 신청 · 승인 · 알림 흐름 중 Horizon이 커버 못 하는 부분 정의
- [ ]  **사용자 시나리오 정의** — 교수님 · 연구실 · 학생 각각의 신청 흐름 문서화
- [ ]  **OpenStack SDK 연동 PoC** — VM 생성 자동화 API, 승인 플로우 프로토타입
- [ ]  **얇은 Portal 보완** — 필요한 흐름만 최소 구현, 처음부터 크게 만들지 않음

---

## Phase 4 · 11–12월 — 소수 서비스 오픈

> 실제 사용자가 SU Cloud를 통해 VM을 발급받고, 최소 2주 이상 안정적으로 운용된 상태
> 
- [ ]  **베타 사용자 온보딩** — 교수님 1–2명, 연구실 1–2곳 대상 소수 오픈, 계정 발급 및 사용 가이드 제공
- [ ]  **운영 체계 수립** — 장애 대응 Runbook, 이슈 트래킹, 자원 관리 프로세스
- [ ]  **트래픽 수집 & 모니터링** — 실사용 데이터 기반으로 병목 파악 및 개선 우선순위 정리
- [ ]  **프로젝트 회고 & 2027 로드맵** — 올해 산출물 정리, 후배에게 이어질 문서화