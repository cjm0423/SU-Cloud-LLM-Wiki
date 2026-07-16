---
title: "OVN 다이어그램"
type: "raw"
date: 2026-06-28
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# OVN 다이어그램

# 컨트롤 플레인 다이어그램

- `main-router`, 보안그룹, FIP 어디에도 '실체'가 없고, 전부 NB DB에 적힌 선언이 SB의 logical flow로 컴파일돼 각 노드의 br-int에 OpenFlow로 박힌 결과일 뿐

![OVN_컨트롤플레인.png](OVN%20%EB%8B%A4%EC%9D%B4%EC%96%B4%EA%B7%B8%EB%9E%A8/OVN_%EC%BB%A8%ED%8A%B8%EB%A1%A4%ED%94%8C%EB%A0%88%EC%9D%B8.png)

[OVN_컨트롤플레인.drawio](OVN%20%EB%8B%A4%EC%9D%B4%EC%96%B4%EA%B7%B8%EB%9E%A8/OVN_%EC%BB%A8%ED%8A%B8%EB%A1%A4%ED%94%8C%EB%A0%88%EC%9D%B8.drawio)

# 데이터 플레인 다이어그램

```bash
① cirros eth0 → tap1f430626-97 → br-int          (파랑: 172.22.0.154 → 8.8.8.8)
② br-int(ovn-…-3 포트) → ens18                    (주황: 여기서 Geneve 캡슐화)
③ ens18(cp02) → 관리망 → ens18(ct03)             (주황: .206 → .204, UDP/6081)
④ ens18 → br-int(디캡슐화) → main-router          (다시 파랑: 원본 복원)
⑤ main-router SNAT → br-ex                        (초록으로 전환: .154 ⇒ .243)
⑥ br-ex → ens19                                   (초록: .243 → 8.8.8.8)
⑦ ens19 → natzone(MASQUERADE) → eno1 → 인터넷    (초록: .243 ⇒ 210.94.240.179 공인)
```

![OVN 다이어그램.png](OVN%20%EB%8B%A4%EC%9D%B4%EC%96%B4%EA%B7%B8%EB%9E%A8/OVN_%EB%8B%A4%EC%9D%B4%EC%96%B4%EA%B7%B8%EB%9E%A8.png)

[OVN 다이어그램.drawio](OVN%20%EB%8B%A4%EC%9D%B4%EC%96%B4%EA%B7%B8%EB%9E%A8/OVN_%EB%8B%A4%EC%9D%B4%EC%96%B4%EA%B7%B8%EB%9E%A8.drawio)