---
title: "QnA Archive 인덱스"
type: "index"
date: 2026-06-18
tags: ["#index", "#qna"]
---

# QnA Archive 인덱스

AI와 나눈 트러블슈팅, 개념 질문, 분석 결과를 OKF 포맷으로 추출한 문서들입니다.

> **새 문서 추가 방법:** [[99_Templates/OKF-QnA-Template]]을 복사해서 작성 후 이 폴더에 저장하세요.
> 파일명 형식: `YYYY-MM-DD-keyword-english.md`

---

## 전체 QnA 목록 (Dataview)

Obsidian + Dataview 플러그인 설치 시 아래 쿼리가 동적 테이블로 렌더링됩니다.

~~~
```dataview
TABLE date, tags, author, status
FROM "02_QnA_Archive"
WHERE type = "qa" OR type = "troubleshooting"
SORT date DESC
```
~~~

---

## 수동 목록

| 날짜 | 제목 | 태그 |
|------|------|------|
| 2026-05-15 | [[2026-05-15-devstack-flamingo-python-error]] | #devstack #troubleshooting |

---

## 자주 등장하는 주제

- **DevStack 설치** → [[03_Guides/DevStack-Installation-Guide]]
- **네트워크 개념** → [[01_Concepts/Provider-vs-SelfService-Network]]
- **Proxmox 설정** → 추가 예정
