---
title: "status 필드 정의"
type: "index"
date: 2026-07-16
tags: ["#index", "#status"]
---

# status 필드 정의

위키 문서 종류별로 `status` 값이 뭘 의미하는지 정리한 표.

## 위키 문서 (`01_Concepts`, `03_Guides`, `04_Meetings`, `06_Decisions`)

| status | 의미 |
|---|---|
| `draft` | AI가 초안만 작성, 사람이 아직 내용을 확인 안 함 |
| `review` | 사람이 봤는데 내용에 문제가 있어서 수정이 필요하다고 표시한 상태 |
| `stable` | 사람이 검토 완료, 내용을 신뢰할 수 있음 |

## QnA (`02_QnA_Archive`)

| status | 의미 |
|---|---|
| `open` | 문제가 아직 해결 안 됨 |
| `resolved` | 문제 해결 완료 |
| `wontfix` | 해결하지 않기로 결정함 |

## 원본 (`00_Inbox`)

| status | 의미 |
|---|---|
| `raw` | 저장만 된 원본, 아직 위키 문서로 추출 안 됨 |
| `promoted` | 위키 문서로 추출 완료 (원본 자체는 그대로 보존) |

## 흐름

```
00_Inbox: raw → promoted
위키 문서: draft → review → stable
QnA: open → resolved
```
