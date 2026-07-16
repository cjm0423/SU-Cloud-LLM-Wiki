---
title: "Security Group"
type: "concept"
date: 2026-07-16
tags: ["#openstack", "#security-group", "#networking"]
status: "stable"
related_nodes: ["[[01_Concepts/Floating-IP]]", "[[01_Concepts/Neutron]]", "[[01_Concepts/OVN-OVS-Architecture]]"]
author: "AI Assistant"
raw_source: ""
---

# Security Group

## 한 줄 정의

Security Group은 OpenStack VM의 포트(NIC) 단위로 적용되는 상태 기반(stateful) 가상 방화벽으로, ingress/egress 트래픽을 프로토콜·포트·CIDR 기준으로 허용·차단한다.

## 상세 설명

### 동작 방식

- VM이 생성될 때 하나 이상의 Security Group이 포트에 연결됨 (기본값: `default` 그룹)
- 규칙은 방향(ingress/egress), 프로토콜(TCP/UDP/ICMP), 포트 범위, CIDR(출발지) 기준으로 정의
- Stateful — 허용된 연결의 응답 트래픽은 별도 규칙 없이 자동 통과

### 백엔드 구현

| Neutron 백엔드 | Security Group 구현 방식 |
|---------------|--------------------------|
| LinuxBridge | iptables 규칙으로 컴파일 |
| OVN (현재 SU Cloud) | OVN ACL(Access Control List)로 컴파일 → [[01_Concepts/OVN-OVS-Architecture]] |

### Floating IP와의 관계

Floating IP를 VM에 연결해도 Security Group에서 해당 포트를 열어두지 않으면 외부 접근이 불가능하다 — 두 설정은 독립적으로 함께 필요하다 → [[01_Concepts/Floating-IP]]

## SU Cloud에서의 활용

- VM에 SSH(22)/HTTP(80) 접근을 열 때 Horizon → Network → Security Groups에서 Ingress 규칙 추가 (→ [[03_Guides/DevStack-App-Deploy-Task]])
- OVN 환경에서는 Security Group 규칙이 NB DB의 ACL 객체로 컴파일되어 각 노드 OVS flow에 반영됨

## 관련 개념

- [[01_Concepts/Floating-IP]]
- [[01_Concepts/Neutron]]
- [[01_Concepts/OVN-OVS-Architecture]]
