---
title: "Floating IP"
type: "concept"
date: 2026-06-18
tags: ["#openstack", "#networking", "#floating-ip"]
status: "stable"
related_nodes: ["[[Provider-vs-SelfService-Network]]", "[[Neutron]]", "[[Security-Group]]"]
author: "SU-Cloud Team"
---

# Floating IP

## 한 줄 정의

Floating IP는 Self-Service Network의 사설 IP를 가진 VM에, 외부에서 접근 가능한 공인 IP를 동적으로 매핑하는 OpenStack 기능이다.

## 동작 원리

```
외부 요청 → Floating IP (203.0.113.10)
                  │
          qrouter namespace에서 DNAT
                  │
          VM Private IP (192.168.1.5)
```

- VM 자체 IP는 바뀌지 않음
- qrouter의 iptables DNAT/SNAT 규칙으로 IP 변환
- **언제든 다른 VM에 재할당 가능** (Floating = 떠다니는)

## AWS와의 비교

| OpenStack | AWS |
|-----------|-----|
| Floating IP | Elastic IP |
| Provider Network Pool | VPC Public Subnet |
| qrouter DNAT | NAT Gateway / Internet Gateway |

## 자주 나오는 실수

- Security Group에서 포트를 열지 않으면 Floating IP를 붙여도 접근 불가
- VM에 Floating IP를 붙이려면 먼저 Router가 Provider Network(외부 게이트웨이)에 연결되어 있어야 함

## SU Cloud에서의 활용

- 학생이 신청한 VM 중 SSH/웹 접근이 필요한 경우 Floating IP 부여
- Self-Service Portal에서 VM 신청 시 Floating IP 옵션 선택 가능하게 설계 예정

## 관련 개념

- [[Provider-vs-SelfService-Network]]
- [[Security-Group]]
- [[Neutron]]
