---
title: "260628 주간 회의"
type: "raw"
date: 2026-06-28
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# 260628

---

## 1. 핵심 논의 요약

배포 자체는 완료된 상태에서, **Production 수준으로 끌어올리기 위한 네트워크 분리 · 고가용성(HA) · 메시지 큐 · 시각화 자료** 보강이 주요 피드백.

---

## 2. 네트워크 설계 (Production 관점)

- **네트워크 대역 분리 필요**: 현재 tunnel / mgmt / provider가 같은 대역대를 공유 중인데, Production 환경에서는 **모든 대역대를 분리**해야 함.
- 특히 tunnel network는 별도로 분리되어 있어야 함.

### VXLAN / VLAN / 터널링 / 오버레이

- compute 노드가 **같은 네트워크 대역대**에 있으면 VXLAN 통신이 필요 없음.
- compute 노드가 **서로 다른 대역대**에 있을 때 오버레이(VXLAN)가 사용됨.
- **여러 데이터센터(리전)에 compute 노드가 분산**되면 각 데이터센터의 망이 다르므로, 이를 **하나의 L2 네트워크로 묶기 위해 터널링**을 사용.
- controller cluster와 AZ cluster의 대역대가 나뉘어 있는(다른 데이터센터) 경우, 같은 망으로 구성하기 위해 VXLAN 사용.
- **터널링 정의**: 분리되어 있는 L2/L3 네트워크들을 하나로 묶는 기술.
- → **VLAN vs VXLAN 차이**를 별도로 학습하기.

### Geneve

- VXLAN은 **MTU 크기 증가**로 인해 패킷 드랍이 자주 발생.
- Geneve는 **가변 길이 옵션 필드**로 이를 보완 → 학습 권장.

### OVN / OVS

- **OVN이 OVS를 제어**하는 구조.
- → **OVN 통신 구조 시각화 자료** 제작 필요. (OVN 네트워크 분석 결과를 참고)

---

## 3. 로드밸런싱 · VIP (HAProxy / Keepalived / VRRP)

- HAProxy가 **controller 3대에 모두 설치되어 있는지** 확인 필요.
    - (필요 시 HAProxy를 별도 노드로 분리하여 구성하는 것도 가능)
- HAProxy 앞단에 둔 LB의 역할이 무엇인지 정리.
- **keepalived(VRRP)를 통해 VIP가 어떻게 할당되는지** 동작 원리 정리.
- 현재 구성한 LB 노드는 통상 **bootstrap node(관리용 노드)** 로 부르는 형태에 해당함.

---

## 4. 고가용성(HA) · 쿼럼

- **쿼럼 유지 기술 조사**: OpenStack에서 고가용성을 위해 어떤 방식으로 쿼럼을 유지하는지 조사.
    - 참고: Kubernetes는 etcd를 사용 (투표 기반으로, 한 대가 죽으면 어떤 노드를 마스터로 승격할지 규칙이 존재).
- **HA에서 가장 중요한 영역은 DB** → 그래서 쿼럼이 핵심.
    - 구성 방식: **MariaDB Galera / active-standby / active-active** 등.
    - **동시 쓰기(read & write)** 발생 시 데이터 처리 방식이 중요한 포인트.
- **HA 실험 진행 권장**: OpenStack 운영 시 발생 가능한 시나리오(노드 장애 등)에서 어떻게 쿼럼이 유지되는지 디테일하게 실험.
- OpenStack 운영 관점에서 **어떤 데이터가 들어있고 쿼럼이 어떻게 동작하는지** 파악.

---

## 5. 메시지 큐 (RabbitMQ / Kafka)

- 실시간으로 들어오는 요청을 **Kafka에 적재**할 필요성을 인지하고 있음.
- 실시간 처리 방식에 따라 성능 차이가 발생하므로, **RabbitMQ · Kafka 등 메시지 큐(비동기 처리) 개념** 학습 권장.
- 특히 **대용량 트래픽 · 운영 단계**를 고려한 이해가 필요.

---

## 6. OpenStack CLI

- OpenStack CLI는 **REST API를 분석해 Python으로 구현한 래퍼**.
- → CLI ↔ REST API 관계 정리.

---

## 7. 접근 제어 (Tailscale ACL)

- Tailscale ACL은 **태그(tag) 기반 권한 부여**가 가능.
- **현 문제점**: 동일 계정이면 개인 end device 등록 시 서로 접근이 가능함.
- **개선안**: 각자 이메일을 걸어 서버 태그별 권한을 분리하는 방식 검토.

---

## 8. 향후 과제 / 기타

- Kubernetes 환경 위에 구축할 경우 **Registry를 별도로 구성** + Helm 도입 검토 (시점은 추후 결정).
- 시간 여유가 있으면 **네트워크 장비 분석** 및 아키텍처 구성 리뷰 진행.
- **노션 정리 내용을 GitHub에 통합**.

---

## 9. 액션 아이템

- [ ]  **백지원** — 기존 draw.io 기반 network flow 그림을 확장해 VXLAN/VNI, `br-int`, `br-tun`, Linux bridge, tcpdump 확인 흐름을 팀에 공유한다.
- [x]  **백지원 · 차지만** — OVN/Geneve packet flow와 gateway chassis 구조를 함께 시각화해 다음 회의에서 설명한다.
- [ ]  **이민기** — Tailscale ACL, tag, collaborator/email 분리 방식이 실습 tailnet에 어떻게 적용될 수 있는지 정리한다.
- [ ]  **이민기** — Kolla HA 환경을 지우지 말고 Galera quorum, VIP failover, OpenStack 운영 데이터 변경 시나리오를 추가 실험한다.
- [x]  **차지만** — Kolla Ansible 배포 과정의 image timeout, pre-pull, ProxySQL/Keepalived, Octavia issue를 troubleshooting log로 정리한다.
- [x]  **차지만** — school network 진단 명령어와 script를 KakaoTalk 방에 공유하고, 팀원이 현장에서 실행할 수 있게 정리한다.
- [ ]  **박준우 · 안현** — 학교 network 현장 확인 일정을 조율하고, 김재현/관련 참여자에게 확정 일정을 전달한다.
- [ ]  **전원** — KakaoTalk에 올라온 장비 사진과 기존 조사 내용을 바탕으로 campus network architecture 초안을 각자 그려 온다.
- [ ]  **박준우** — Notion에 흩어진 개인 정리 자료를 GitHub wiki 형태로 통합하는 방향과 예시를 공유한다.
- [x]  **전원** — 다음 오프라인 회의는 2026-07-04 오후 후보로 조율하되, 참석 가능 시간과 여행/개인 일정을 다시 확인한다.

---

## 10. 다음 미팅

- **일시**: 7/4 (토) 14:00~15:00경
- **안건**: 함께 모여 네트워크 구성 파악