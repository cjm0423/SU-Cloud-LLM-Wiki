---
title: "Neutron"
type: "concept"
date: 2026-07-16
tags: ["#openstack", "#neutron", "#networking"]
status: "stable"
related_nodes: ["[[01_Concepts/Provider-vs-SelfService-Network]]", "[[01_Concepts/Floating-IP]]", "[[01_Concepts/Security-Group]]", "[[01_Concepts/OVN-OVS-Architecture]]", "[[01_Concepts/VXLAN]]"]
author: "AI Assistant"
raw_source: ""
---

# Neutron

## 한 줄 정의

Neutron은 OpenStack의 네트워킹 서비스로, 가상 네트워크·서브넷·라우터·포트·Floating IP·Security Group을 테넌트별로 관리하는 컴포넌트다.

## 상세 설명

### 역할

Neutron은 "Networking as a Service"를 제공하는 OpenStack 컴포넌트로, 사용자가 API/CLI/Horizon을 통해 다음을 직접 정의할 수 있게 한다.

| 리소스 | 의미 |
|--------|------|
| Network | 논리적으로 격리된 L2 브로드캐스트 도메인 |
| Subnet | Network에 할당된 IP 대역 (DHCP 포함) |
| Port | VM NIC이 붙는 논리적 연결점 |
| Router | Network 간 L3 라우팅 + NAT (Floating IP) |
| Security Group | 포트 단위 방화벽 규칙 → [[01_Concepts/Security-Group]] |

### ML2 플러그인과 백엔드 구조

Neutron 자체는 API/DB 레이어만 담당하고, 실제 패킷 처리는 백엔드 드라이버(ML2 plugin)에 위임한다.

| 백엔드 | 사용 시기 |
|--------|----------|
| LinuxBridge + VXLAN | 구형 수동 설치 (SU Cloud 초기 실습) |
| OVS + OVN + Geneve | 현재 SU Cloud (Kolla-Ansible) — [[01_Concepts/OVN-OVS-Architecture]] |

neutron-server가 neutron DB(MariaDB)에 상태를 저장하는 동시에, ML2 드라이버를 통해 백엔드(OVN이면 NB DB)에도 반영한다.

### Provider Network vs Self-Service Network

Neutron이 관리하는 두 네트워크 모델의 차이는 → [[01_Concepts/Provider-vs-SelfService-Network]] 참고.

## SU Cloud에서의 활용

- 현재 백엔드: OVN + Geneve (`neutron_plugin_agent: "ovn"`, Kolla-Ansible globals.yml)
- Floating IP, Security Group 모두 Neutron API로 관리
- 자세한 패킷 흐름: [[01_Concepts/OVN-Network-Flow]]

## 관련 개념

- [[01_Concepts/Provider-vs-SelfService-Network]]
- [[01_Concepts/Floating-IP]]
- [[01_Concepts/Security-Group]]
- [[01_Concepts/OVN-OVS-Architecture]]
- [[01_Concepts/VXLAN]]
