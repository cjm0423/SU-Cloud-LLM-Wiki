---
title: "260621 주간 회의 — 네트워크 파악 & IaC 사전 준비"
type: "meeting"
date: 2026-06-21
tags: ["#meeting", "#su-cloud"]
status: "stable"
related_nodes: ["[[04_Meetings/2026-06-13-kickoff]]", "[[04_Meetings/2026-06-28-meeting-weekly]]", "[[01_Concepts/VXLAN]]", "[[01_Concepts/Proxmox]]"]
participants: ["[[05_People/차지만]]", "[[05_People/이민기]]", "[[05_People/박준우]]", "[[05_People/안현]]", "[[05_People/백지원]]", "[[05_People/김재현]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-06-21-meeting-weekly-raw]]"
---

# 260621 주간 회의 — 네트워크 파악 & IaC 사전 준비

## 📋 Session Snapshot

- 날짜: 2026-06-21
- 참여자: [[05_People/차지만]], [[05_People/이민기]], [[05_People/박준우]], [[05_People/안현]], [[05_People/백지원]], [[05_People/김재현]] (조충희 교수님 불참)
- 이전 회의: [[04_Meetings/2026-06-13-kickoff]]
- 다음 회의: [[04_Meetings/2026-06-28-meeting-weekly]]

## 📝 Summary

Kolla-Ansible 구축 전 네트워크 이론(VPN·백본·VLAN) 선행 학습 및 패킷 트레이싱 집중 요청. 실습 안전성을 위한 스냅샷 체계화, qcow2/cloud-init 포맷 실험, MariaDB Galera와 HA/클러스터링 개념 사전 파악을 과제로 부여. 지만 학생이 진행한 작업을 다른 멘티들도 따라해 보도록 권장.

## 💬 주요 논의 내용

### 네트워크 파악 방향
- VPN 원리 공부 — 다른 네트워크에서 서버에 어떻게 접속하는지 (Tailscale 중심)
- Proxmox 단 네트워크도 함께 파악 (민기 오빠 자료 참고)
- 패킷을 집요하게 까봐야 함 → hop 수, 경로 파악
- 백본, VLAN 이론을 먼저 공부한 뒤 학교 현장 방문

### 실습 관련 피드백
- **⭐ 실습 초기 세팅 완료 시 반드시 스냅샷 찍기**
- ISO 설치 대신 **qcow2 이미지 형식** (cloud-init 연동, 스크립트 삽입 가능) 실험 권장
- 지만 학생 작업 흐름을 다른 멘티들도 직접 따라해 볼 것

### 공부하면 좋을 것
- MariaDB Galera — MariaDB 여러 대를 묶어 HA 클러스터로 운영하는 구조
- HA(고가용성)가 무엇인지, 왜 Controller를 3대로 구성하는지
- 클러스터링 개념

### 4주차 일정 방향
- Kolla-Ansible 구축 전 IaC 개념 선행
  - **Terraform**: 인프라 자원 자체를 만드는 도구
  - **Ansible**: 기존 서버에 들어가서 설정·자동화하는 도구 (Playbook = YAML 작업 목록)
- 시간 여유 있으면 지만 학생처럼 하드한 실습 진행

## ✅ Action Items

- [ ] 전원 — VPN(Tailscale) 원리 학습, 패킷 트레이싱 실습
- [ ] 전원 — 백본, VLAN 이론 선행 학습 후 학교 현장 방문 일정 조율
- [ ] 전원 — IaC(Terraform, Ansible) 개념 공부
- [ ] 전원 — MariaDB Galera, HA, 클러스터링 개념 파악
- [ ] 멘티 전원 — qcow2/cloud-init 이미지 포맷 실험

## 🔗 Related Notes

- People: [[05_People/차지만]], [[05_People/이민기]], [[05_People/박준우]], [[05_People/안현]], [[05_People/백지원]], [[05_People/김재현]]
- Topics: [[01_Concepts/VXLAN]], [[01_Concepts/Proxmox]]
- Next Meeting: [[04_Meetings/2026-06-28-meeting-weekly]]
