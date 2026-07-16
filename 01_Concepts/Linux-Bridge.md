---
title: "Linux Bridge"
type: "concept"
date: 2026-07-16
tags: ["#networking", "#linux-bridge", "#openstack"]
status: "stable"
related_nodes: ["[[01_Concepts/VXLAN]]", "[[01_Concepts/Neutron]]", "[[01_Concepts/Provider-vs-SelfService-Network]]", "[[01_Concepts/OVN-OVS-Architecture]]"]
author: "AI Assistant"
raw_source: ""
---

# Linux Bridge

## 한 줄 정의

Linux Bridge는 Linux 커널에 내장된 소프트웨어 L2 스위치로, OpenStack 구형(수동 설치) Neutron 배포에서 `brq-<net-id>` 브리지 + VXLAN 터널 인터페이스 조합으로 가상 네트워크를 구현하는 데 쓰인다.

## 상세 설명

### 기본 동작

- 커널 모듈로 동작하는 단순한 L2 스위치 (MAC 주소 학습, 브로드캐스트 도메인 구성)
- OpenFlow 같은 프로그래머블 제어 기능은 없음 — OVS 대비 기능은 제한적이지만 가볍고 안정적

### OpenStack에서의 구조 (LinuxBridge ML2 드라이버)

```
brq-<net-id>  ← 네트워크마다 별도 브리지
  ├─ tap<port-id>  ← VM NIC
  └─ vxlan-<vni>   ← 터널 인터페이스 (노드별 직접 연결)
```

- 네트워크(Neutron network)마다 브리지가 하나씩 생성됨 (`brq-` 접두사)
- Compute Node 간 트래픽은 VXLAN 터널로 캡슐화되어 전달 → [[01_Concepts/VXLAN]]
- 라우팅은 `qrouter-xxx` network namespace가 담당 (Linux Bridge 자체는 라우팅하지 않음)

### 한계

- 노드 수가 늘어나면 `vxlan-N` 인터페이스가 노드 쌍마다 선형으로 증가 → 관리 복잡도 상승
- OVN 같은 논리 오케스트레이션 레이어가 없어 대규모 환경에서는 OVS/OVN으로 대체되는 추세

## SU Cloud에서의 활용

- SU Cloud 초기 수동 설치 실습(2026년 6월 이전, Kolla-Ansible 도입 전) 단계에서 사용된 방식
- 현재 Kolla-Ansible 배포는 OVS/OVN + Geneve로 전환됨 → [[01_Concepts/OVN-OVS-Architecture]]

## 관련 개념

- [[01_Concepts/VXLAN]]
- [[01_Concepts/Neutron]]
- [[01_Concepts/Provider-vs-SelfService-Network]]
- [[01_Concepts/OVN-OVS-Architecture]]
