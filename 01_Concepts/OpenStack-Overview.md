---
title: "OpenStack 전체 구조 개요"
type: "concept"
date: 2026-06-18
tags: ["#openstack", "#architecture", "#cloud-engineering"]
status: "review"
related_nodes: ["[[Provider-vs-SelfService-Network]]", "[[Neutron]]", "[[DevStack]]", "[[SU Cloud 프로젝트 개요]]"]
author: "SU-Cloud Team"
---

# OpenStack 전체 구조 개요

## 한 줄 정의

OpenStack은 서버, 네트워크, 스토리지 자원을 소프트웨어로 관리하는 오픈소스 IaaS 클라우드 플랫폼이다.

## 핵심 컴포넌트

| 컴포넌트 | 역할 |
|---------|------|
| **Nova** | 컴퓨트 — VM 생성/관리 |
| **Neutron** | 네트워킹 — 가상 네트워크, 라우터, Floating IP |
| **Glance** | 이미지 서비스 — VM 부팅 이미지 저장 |
| **Keystone** | 인증 — 사용자/프로젝트/토큰 관리 |
| **Cinder** | 블록 스토리지 — VM에 붙이는 디스크 |
| **Horizon** | 대시보드 — 웹 UI |
| **Swift** | 오브젝트 스토리지 |

## 노드 구성

```
Controller Node      Compute Node
─────────────        ─────────────
Keystone             Nova-Compute
Nova-API             Neutron-Agent
Neutron-Server       KVM/QEMU (Hypervisor)
Glance
Horizon
```

- **Controller**: API 엔드포인트, DB, 메시지 큐(RabbitMQ), 스케줄러
- **Compute**: 실제 VM이 구동되는 노드. KVM/QEMU로 하이퍼바이저 역할

## 트래픽 흐름 요약

```
사용자 요청
  → Keystone 인증
    → Nova API (VM 생성 명령)
      → Nova Scheduler (어느 Compute Node에 배치할지 결정)
        → Nova Compute (VM 실제 생성)
          → Neutron (네트워크 연결)
            → VM 부팅 완료
```

## SU Cloud에서의 활용

- **1단계 목표:** 학교 서버 2대(Controller + Compute)에 OpenStack 수동 설치
- **2단계 목표:** Self-Service Portal을 통해 학생/연구실이 VM을 신청·생성
- 수동 설치(DevStack → 단일 노드 → 멀티 노드)를 통해 패킷 흐름을 손으로 이해하는 것이 핵심

## 관련 개념

- [[Provider-vs-SelfService-Network]] — 네트워크 유형 이해 필수
- [[Neutron]] — 가상 네트워크 상세
- [[DevStack]] — 로컬 실습 환경
- [[Proxmox]] — SU Cloud 실습 하이퍼바이저 계층
- [[VXLAN]] — Compute Node 간 VM 트래픽 터널링
