---
title: "DevStack 설치 가이드 (Ubuntu 22.04 + Antelope 2023.1)"
type: "guide"
date: 2026-06-18
tags: ["#devstack", "#openstack", "#installation", "#antelope"]
related_nodes: ["[[OpenStack-Overview]]", "[[Provider-vs-SelfService-Network]]", "[[DevStack-Flamingo-Python-Error]]"]
author: "SU-Cloud Team (차지만 실습 기반)"
---

# DevStack 설치 가이드

> SU Cloud 팀 차지만의 실습 경험 기반. 2026-05-24 사전학습 2차에서 검증된 stable/2023.1 (Antelope) 기준.

## ⚠️ 브랜치 선택 주의

| 브랜치 | 상태 | 권장 여부 |
|--------|------|----------|
| `stable/2025.2` (Flamingo) | Python/Sphinx 버전 충돌 발생 | ❌ |
| `stable/2023.1` (Antelope) | 안정적으로 설치 확인 | ✅ |

Flamingo에서 발생하는 오류는 [[DevStack-Flamingo-Python-Error]] 참고.

## 환경 요구사항

- OS: Ubuntu 22.04 LTS
- RAM: 최소 8GB (권장 16GB)
- CPU: 4코어 이상, **가상화 지원 필수** (VirtualBox: 중첩 가상화 활성화)
- 디스크: 40GB 이상
- 네트워크: 외부 인터넷 연결 필요

## 1단계 — 사용자 준비

```bash
# stack 전용 사용자 생성 (root 말고 반드시 이 사용자로 실행)
sudo useradd -s /bin/bash -d /opt/stack -m stack
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack
sudo su - stack
```

## 2단계 — DevStack 소스 클론

```bash
git clone https://opendev.org/openstack/devstack
cd devstack
# ⚠️ 반드시 stable 브랜치로 체크아웃
git checkout stable/2023.1
```

## 3단계 — local.conf 작성

```bash
cat > local.conf << 'EOF'
[[local|localrc]]
ADMIN_PASSWORD=secret
DATABASE_PASSWORD=secret
RABBIT_PASSWORD=secret
SERVICE_PASSWORD=secret

# Self-Service Network 활성화
enable_plugin neutron https://opendev.org/openstack/neutron stable/2023.1

# 실습용 최소 서비스
ENABLED_SERVICES=g-api,g-reg,key,n-api,n-cond,n-cpu,n-novnc,n-sch,placement-api,q-svc,q-agt,q-dhcp,q-l3,q-meta,horizon,mysql,rabbit,tempest

HOST_IP=$(hostname -I | awk '{print $1}')
EOF
```

## 4단계 — 설치 실행

```bash
./stack.sh
# 완료까지 약 20~40분 소요
```

## 5단계 — 설치 확인

```bash
# OpenStack CLI 환경변수 로드
source openrc admin admin

# 컴포넌트 상태 확인
openstack service list
openstack network list
openstack image list
```

## 설치 후 실습 체크리스트

- [ ] Horizon(대시보드) 접속: `http://<HOST_IP>/dashboard`
- [ ] Provider Network 생성 확인
- [ ] Self-Service Network + Router 생성
- [ ] VM 생성 후 Floating IP 부여
- [ ] Security Group에서 22번 포트 열고 SSH 접속
- [ ] `ip netns` 명령으로 qrouter, qdhcp namespace 확인

## 자주 발생하는 오류

| 오류 | 원인 | 해결 |
|------|------|------|
| `ModuleNotFoundError: sphinx` | Flamingo 브랜치 Python 충돌 | stable/2023.1로 체크아웃 |
| `OOM Killed` | RAM 부족 | 스왑 추가 또는 RAM 증설 |
| Apple Silicon 오류 | ARM64 미지원 | x86_64 VM 또는 클라우드 인스턴스 사용 |

## 관련 문서

- [[DevStack-Flamingo-Python-Error]] — Flamingo 브랜치 오류 상세
- [[Provider-vs-SelfService-Network]] — 설치 후 네트워크 개념 학습
- [[OpenStack-Overview]] — 전체 구조 이해
