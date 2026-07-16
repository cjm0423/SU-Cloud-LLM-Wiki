---
title: "SU Cloud 프로젝트 로드맵 (6월 ~ 12월)"
type: "raw"
date: 2026-06-01
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# SU Cloud 프로젝트 로드맵 (6월 ~ 12월)

## Phase 0 · 6월 — 학습 & 기반 세팅

> Proxmox 위 VM에서 OpenStack을 수동 설치해 Horizon에 로그인하는 것까지 완료 (학습 목적)
> 
- [ ]  **P520에 Proxmox VE 설치** — 공동계정으로 멘티 4명 접속 환경 구성
- [ ]  **외부 접근 세팅** — Tailscale 설치, 집·외부에서 Proxmox 콘솔 접근 확인
- [ ]  **멘티 4명 OpenStack 수동 설치 실습** — Proxmox VM 위 OpenStack and Kolla 직접 설치, Nova / Neutron / Keystone 흐름 손으로 익히기
- [ ]  **학교 네트워크 파악** — 전산실 협의: VLAN 가능 여부, 스위치 구매 필요성, Public IP 2개 할당 방식 확정
- [ ]  **외부 진입 아키텍처 확정** — Edge VM + nginx 2 listen 구조, 라우터 브리지 vs 1:1 NAT 결정

### Phase 1 · 7월 — 개발계 구축 & Portal 기반 개발

> 개발계 오픈스택 배포 완료 및 Portal UI/UX 설계와 백엔드 기본 API 구현 진행
> 
- [ ]  **[Infra]** Gaming5에 Ubuntu 설치
- [ ]  **[Infra]** OpenStack 수동 설치 혹은 Kolla-Ansible 멀티노드 배포 (globals.yml 기준)
- [ ]  **[Infra]** VLAN 구성 확정 및 Edge-GW 세팅 (VLAN 110/120, 10/20, 스위치 트렁크, nginx 2 listen)
- [ ]  **[Portal]** 사용자 시나리오 정의 및 Horizon 갭 분석 (교수/연구실/학생 신청 흐름 문서화)
- [ ]  **[Portal]** Portal UI/UX 와이어프레임 설계 및 백엔드 뼈대 구축 (DB 스키마 및 CRUD API)

### Phase 2 · 8–9월 — 운영계 구축 & Portal 연동 (MVP)

> 운영계 오픈스택 전체 서비스 기동 및 개발계와 Portal 백엔드를 연동해 VM 자동 생성 흐름 완성
> 
- [ ]  **[Infra]** P520 베어메탈 Kolla-Ansible 배포 (Cinder / Horizon 포함, 전체 서비스 기동)
- [ ]  **[Infra]** E2E 사용자 흐름 검증 (VM 생성 → FIP → SG → SSH → 3-tier 앱 배포)
- [ ]  **[Portal]** OpenStack SDK 연동 및 API 구현 (포털 백엔드와 개발계 연동)
- [ ]  **[Portal]** 얇은 Portal 보완 (승인 버튼 클릭 시 개발계 VM 자동 생성 및 FIP 할당 플로우 완성)

### Phase 3 · 10월 — 통합 테스트(QA) 및 고도화

> Portal의 API 타겟을 운영계로 전환하여 엣지 케이스를 테스트하고 실제 서비스 오픈 준비
> 
- [ ]  **[공통]** 운영계(P520) Endpoint 전환 (Portal API 타겟을 개발계에서 운영계로 변경 및 통신 확인)
- [ ]  **[공통]** 엣지 케이스 및 예외 처리 QA (자원 초과, IP 고갈, 승인 반려 등 테스트)
- [ ]  **[Infra]** 모니터링 기초 세팅 (서버 리소스 및 서비스 상태 확인 체계 구성)
- [ ]  **[Portal]** UI 폴리싱 및 가이드 작성 (베타 오픈을 위한 화면 정돈, 사용자 가이드 작성)

### Phase 4 · 11–12월 — 소수 서비스 오픈

> 실제 사용자가 SU Cloud를 통해 VM을 발급받고, 최소 2주 이상 안정적으로 운용된 상태
> 
- [ ]  **[공통]** 베타 사용자 온보딩 (교수님 1–2명, 연구실 1–2곳 대상 소수 오픈 및 계정 발급)
- [ ]  **[Infra]** 운영 체계 수립 (장애 대응 Runbook, 이슈 트래킹, 자원 관리 프로세스)
- [ ]  **[공통]** 트래픽 수집 & 모니터링 (실사용 데이터 기반 병목 파악 및 개선 우선순위 정리)
- [ ]  **[공통]** 프로젝트 회고 & 2027 로드맵 (올해 산출물 정리, 후배에게 이어질 문서화)

[SU-Cloud 2026 · 로드맵](SU%20Cloud%20%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8%20%EB%A1%9C%EB%93%9C%EB%A7%B5%20(6%EC%9B%94%20~%2012%EC%9B%94)/SU-Cloud%202026%20%C2%B7%20%EB%A1%9C%EB%93%9C%EB%A7%B5%2037fd8e51100c80fc840adb735cfd6832.md)