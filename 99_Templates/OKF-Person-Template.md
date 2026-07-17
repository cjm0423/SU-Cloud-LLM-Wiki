---
title: "[이름]"
type: "person"
date: YYYY-MM-DD
tags: ["#people", "#su-cloud"]
---

# [이름]

허브 노드 — 이 페이지와 연결된 문서들이 그래프 뷰에서 시각화됩니다.

## 참여 회의

```dataview
LIST
FROM "04_Meetings"
WHERE contains(participants, "[[이름]]")
SORT date ASC
```
