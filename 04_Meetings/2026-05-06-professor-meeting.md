---
title: "OpenStack Pilot Project 교수님 회의"
type: "meeting"
date: 2026-05-06
tags: ["#meeting", "#openstack", "#architecture", "#su-cloud"]
status: "stable"
related_nodes: ["[[2026-05-07-cha-jiman-1on1]]", "[[OpenStack-Overview]]", "[[조충희 교수님]]"]
participants: ["[[박준우]]", "[[조충희 교수님]]", "[[안현]]"]
author: "SU-Cloud Archive"
---

# OpenStack Pilot Project 교수님 회의

## 📋 Session Snapshot

- 날짜: 2026-05-06 23:07–23:46
- 참여자: [[박준우]], [[조충희 교수님]], [[안현]]
- 다음 회의: [[2026-05-07-cha-jiman-1on1]]

## 📝 Summary

교수님이 제공 가능한 학교 서버 자원과 네트워크 조건을 확인한 첫 공식 회의.
OpenStack Infrastructure MVP와 Self-Service Portal MVP를 분리하고,
서버/네트워크 확인을 최우선 과제로 두기로 했다.

현업 경험 공유(Kubernetes, Rancher, RKE, 폐쇄망 인프라)도 이루어졌으며,
학생들이 OpenStack 구조와 설치를 직접 경험하는 것이 핵심 목표임을 확인했다.

## 💬 주요 논의 내용

### 서버/네트워크 자원 확인
- 고사양 서버(Hypervisor/Worker용) 보유 확인
- Controller + Worker 2대 구성, Public IP 2개 검토 가능
- 조교실 공유기, 건물 라우터, Floating IP 구성 가능 여부는 네트워크 담당자 확인 필요

### 프로젝트 로드맵 합의
1. 학생들이 OpenStack 구조와 수동 설치를 직접 학습
2. 이후 Horizon형 VM 관리 포털, Kolla Ansible 자동화로 확장
3. 장기: Kubernetes 기반 OpenStack, CRD/Operator 실습

### 교수님 조언
- "회사에서 시키는 일만 하기보다 OpenStack/CSP 성격의 미니 프로젝트를 능동적으로 제안해 경험을 쌓아라"

## ✅ Action Items

- [x] 교수님이 학교 네트워크 담당자에게 Public IP, 스위치, Floating IP 구성 가능 여부 확인
- [x] 박준우/안현이 학생 컨택 및 사전학습 자료 전달
- [ ] 서버 스펙(RAM, storage, GPU, NIC) 상세 inventory 확보

## 🔗 Related Notes

- People: [[박준우]], [[조충희 교수님]], [[안현]]
- Topics: [[OpenStack-Overview]], [[Provider-vs-SelfService-Network]]
- Next: [[2026-05-07-cha-jiman-1on1]]
