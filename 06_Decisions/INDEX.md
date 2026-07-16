---
title: "결정 기록 인덱스"
type: "index"
date: 2026-07-16
tags: ["#index", "#decision"]
---

# 06_Decisions — 기술 결정 기록 (Decision Log)

회의록이 "무슨 얘기를 했는가"를 담는다면, Decision Log는 **"왜 이 방향으로 결정했는가"** 를 담는다.

나중에 "그때 왜 이걸 선택했지?" 라는 질문이 생길 때, 회의록을 뒤지지 않아도 바로 찾을 수 있도록.

---

## 전체 결정 목록 (Dataview)

```dataview
TABLE date, status, deciders, file.link AS "결정 문서"
FROM "06_Decisions"
WHERE type = "decision"
SORT date DESC
```

---

## 재검토 필요 항목

```dataview
TABLE date, title, file.link
FROM "06_Decisions"
WHERE type = "decision" AND status = "review"
SORT date ASC
```

---

## 수동 목록

| 날짜 | 결정 | 상태 |
|------|------|------|
| 2026-06-13 | [[06_Decisions/2026-06-13-decision-kolla-ansible-deployment]] | stable |
| 2026-06-21 | [[06_Decisions/2026-06-21-decision-ovn-networking]] | stable |
| 2026-07-05 | [[06_Decisions/2026-07-05-decision-devpc-aio-deployment]] | stable |
| 2026-07-15 | [[06_Decisions/2026-07-15-decision-llm-wiki-harness]] | stable |
