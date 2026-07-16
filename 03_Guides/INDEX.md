---
title: "가이드 인덱스"
type: "index"
date: 2026-07-16
tags: ["#index", "#guide"]
---

# 03_Guides — 가이드 인덱스

처음부터 끝까지 따라 하면 되는 검증된 절차 모음입니다.
개념 설명은 [[01_Concepts/INDEX]], 트러블슈팅 기록은 [[02_QnA_Archive/INDEX]] 참고.

---

## 전체 목록 (Dataview)

~~~
```dataview
TABLE date, status, tags, file.link
FROM "03_Guides"
WHERE type = "guide"
SORT date ASC
```
~~~

---

## 재검토 필요 항목 (Dataview)

~~~
```dataview
TABLE date, title, file.link
FROM "03_Guides"
WHERE type = "guide" AND status = "review"
SORT date ASC
```
~~~

---

## 수동 목록

| 파일 | 제목 | 태그 |
|------|------|------|
| [[Campus-Network-Runbook]] | SU Cloud 학내망 경로 추적 Runbook | #guide #networking #campus-network #runbook |
| [[DevPC-Kolla-Ansible-Setup-Guide]] | 개발계 PC (Gaming5) Kolla-Ansible AIO 배포 가이드 | #guide #kolla-ansible #devpc #openstack |
| [[DevStack-App-Deploy-Task]] | DevStack 이후 — OpenStack VM 위 앱 배포 과제 가이드 | #guide #prestudy #devstack #docker #openstack |
| [[DevStack-Installation-Guide]] | DevStack 설치 가이드 (Ubuntu 22.04 + Antelope 2023.1) | #devstack #openstack #installation #antelope |
| [[Kolla-Ansible-Install-Guide]] | Kolla-Ansible 멀티노드 배포 가이드 (Ubuntu 24.04 + OpenStack 2026.1) | #guide #kolla-ansible #openstack #ubuntu |
| [[LLM-Wiki-Usage-Guide]] | SU-Cloud-LLM-Wiki 사용가이드 | #guide #wiki #obsidian |
| [[OpenStack-Manual-Install-Guide]] | OpenStack 7-Node HA 수동 설치 가이드 (개요) | #guide #openstack #ha #manual-install |
| [[Ops-PC-Network-Setup-Guide]] | 운영 PC 실습 환경 네트워크 구성 가이드 | #guide #proxmox #networking #tailscale |
| [[P520-GPU-VLLM-Passthrough-Guide]] | P520 RTX A5500 GPU 패스스루 → VLLM VM 가이드 | #guide #gpu #proxmox #vllm #passthrough |
| [[Prestudy-4Week-Roadmap]] | OpenStack 4주 사전학습 로드맵 및 액션 플랜 | #guide #prestudy #openstack |
| [[Prestudy-Shopping-Pipeline-Week3]] | 사전학습 3주차 — 쇼핑몰 3-tier 파이프라인 Docker Compose 구성 | #guide #prestudy #docker #kafka #pipeline |
| [[Prestudy-Submit-Template]] | 사전학습 제출 템플릿 및 1~3주차 제출 기록 | #guide #prestudy #template |
| [[Proxmox-Installation-Guide]] | Proxmox 설치 가이드 (v8.4, 학교 서버) | #proxmox #installation #su-cloud #infrastructure |
| [[Tailscale-Setup-Guide]] | Tailscale 설치 및 Proxmox 원격 접속 가이드 | #guide #tailscale #proxmox #vpn |
