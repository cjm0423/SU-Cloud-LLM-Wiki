---
title: "DevStack stable/2025.2 (Flamingo) Python/Sphinx 버전 충돌 오류"
type: "troubleshooting"
date: 2026-05-15
tags: ["#devstack", "#troubleshooting", "#python", "#flamingo"]
related_nodes: ["[[DevStack-Installation-Guide]]", "[[OpenStack-Overview]]"]
author: "AI Assistant & 차지만"
status: "resolved"
---

# DevStack stable/2025.2 (Flamingo) Python/Sphinx 버전 충돌 오류

## 1. ❓ 질의 및 배경 (Context)

- **상황:** 차지만이 Ubuntu 22.04에서 DevStack `stable/2025.2` (Flamingo) 브랜치로 설치를 시도했을 때 설치 중단 발생
- **핵심 질문:** Flamingo 브랜치에서 왜 Python/Sphinx 관련 오류가 나고, 어떻게 해결하는가?

## 2. 🧠 분석 및 추론 (Analysis)

- Flamingo(2025.2)는 최신 브랜치라 `Tempest`(테스트 프레임워크)가 **branchless 설계**로 바뀌었음
- Tempest가 최신 Python 패키지를 요구하는데, Ubuntu 22.04의 시스템 Python과 충돌
- 특히 `Sphinx` 빌드 의존성이 시스템에 설치된 버전과 맞지 않아 설치 중단
- 근본 원인: Ubuntu 22.04는 Python 3.10 기반인데, Flamingo의 일부 패키지는 3.11+ 또는 특정 라이브러리 버전을 가정

## 3. 💡 해결책 및 결과 (Solution)

**즉시 해결:** `stable/2023.1` (Antelope) 브랜치로 다운그레이드

```bash
cd devstack
git checkout stable/2023.1
# local.conf도 브랜치 맞게 수정 후 재실행
./stack.sh
```

**근본 해결 (선택):** Ubuntu 24.04 + Flamingo 조합 사용 (Python 3.12 기본 제공)

```bash
# Ubuntu 24.04에서 시도 시
git checkout stable/2025.2
./stack.sh
```

→ 차지만은 stable/2023.1로 우회하여 **정상 설치 확인** (2026-05-24 기준)

## 4. 🔗 추가 통찰 (Insights & Next Steps)

- DevStack은 **개발/학습 환경 전용**이며, 프로덕션에는 Kolla-Ansible 사용 권장
- 이민기는 같은 시도에서 OOM(Out of Memory) 이슈 발생 → RAM 16GB 이상 권장
- 김재현은 Apple Silicon(ARM64) 이슈 발생 → x86_64 환경 필요
- 다음 단계: DevStack 설치 확인 후 [[Provider-vs-SelfService-Network]] 개념 학습 + VM 생성 실습
