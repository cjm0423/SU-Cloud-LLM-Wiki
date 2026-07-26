---
title: "[이름]"
type: "person"
date: YYYY-MM-DD
tags: []
# 허브 노드는 주제 태그를 붙이지 않는다. type: "person"으로 충분하다.
role: "[예: 팀 리더 / 인프라 담당 / 지도교수]"
affiliation: "[예: 삼육대학교 컴퓨터공학부]"
focus_areas: ["[예: 네트워크]", "[예: Kolla-Ansible 배포]"]
---

# [이름]

> **역할:** (한 줄) · **담당 영역:** (한 줄)

허브 노드 — 이 페이지와 연결된 문서들이 그래프 뷰에서 시각화된다.

## 담당 영역

- (이 사람이 주로 맡고 있는 작업 영역)

## 참여 회의

```dataview
LIST
FROM "04_Meetings"
WHERE contains(participants, "[[이름]]")
SORT date ASC
```

## 결정 참여

```dataview
LIST
FROM "06_Decisions"
WHERE contains(deciders, "[[이름]]")
SORT date DESC
```

## 검토한 문서

```dataview
LIST
FROM "01_Concepts" OR "03_Guides" OR "04_Meetings"
WHERE contains(reviewed_by, "[[이름]]")
SORT reviewed_date DESC
```

## 진행 중인 Action Item

```dataview
TASK
FROM "04_Meetings"
WHERE !completed AND contains(text, "이름")
```
