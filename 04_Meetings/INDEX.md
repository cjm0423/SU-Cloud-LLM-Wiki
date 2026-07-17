---
title: "회의 아카이브 인덱스"
type: "index"
date: 2026-06-18
tags: ["#index", "#meeting"]
---

# 회의 아카이브 인덱스

SU Cloud 프로젝트의 모든 회의 요약본입니다. 원본 STT 전사/review-log는 [[00_Inbox/INDEX]] 참고.

---

## 회의 목록 (Dataview)

~~~
```dataview
TABLE date, participants, file.link
FROM "04_Meetings"
WHERE type = "meeting"
SORT date ASC
```
~~~

---

## 미완료 Action Items (Dataview)

~~~
```dataview
TASK
FROM "04_Meetings"
WHERE !completed
GROUP BY file.link
```
~~~

---

## 수동 목록 (시간순)

| 날짜 | 회의 | 참여자 |
|------|------|--------|
| 2026-05-06 | [[2026-05-06-professor-meeting]] | 박준우, 조충희 교수님, 안현 |
| 2026-05-07 | [[2026-05-07-cha-jiman-1on1]] | 박준우, 차지만 |
| 2026-05-17 | [[2026-05-17-prestudy-1]] | 박준우, 차지만, 이민기, 백지원, 안현 |
| 2026-06-13 | [[2026-06-13-leader-prep]] | 박준우, 차지만 |
| 2026-06-13 | [[2026-06-13-kickoff]] | 박준우, 차지만, 백지원, 이민기, 김재현 |
| 2026-06-21 | [[2026-06-21-meeting-weekly]] | 전원 — 네트워크 파악·IaC 사전 준비 |
| 2026-06-28 | [[2026-06-28-meeting-weekly]] | 전원 — Production 네트워크·HA·메시지 큐 피드백 |
| 2026-07-12 | [[2026-07-12-meeting-weekly]] | 전원 — Public IP 부족·Self-service 포탈·위키 통합 |
| 2026-07-15 | [[2026-07-15-meeting-wiki-setup]] | 조충희 교수님, 차지만, 백지원 — 위키 시스템 설계 |

---

## 프로젝트 타임라인 요약

```
2026-04  산학협력 멘토링 시작, 프로젝트 제안서 공유
2026-05-06  교수님 회의 → 서버/네트워크 확인, MVP 범위 설정
2026-05-07  차지만 1:1 → 학생 의지 확인, 사전학습 계획 수립
2026-05-10  전체 사전학습 공지 (DevStack + 네트워크 기본기)
2026-05-17  사전학습 1차 점검 → DevStack 실습 방향으로 전환
2026-05-24  사전학습 2차 → DevStack 2023.1 안정화, Aolda 레퍼런스
2026-05-31  사전학습 3차 → 5월 말 기준 관리 문서 정리
2026-06-13  리더 사전 미팅 + 킥오프 미팅 → SU Cloud 본격 전환
2026-06-14  서버 하드웨어 확인 (ThinkStation)
2026-06-15  Proxmox 설치 (v8.4, v9.2는 하드웨어 충돌)
2026-06-16  SU Cloud 비전/Outer Architecture 구체화
```
