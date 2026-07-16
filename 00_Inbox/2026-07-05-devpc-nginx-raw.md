---
title: "개발계 외부 접속 확인 (NGINX)"
type: "raw"
date: 2026-07-05
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# 개발계 외부 접속 확인(NGINX)

## 외부 접속 가능 여부 검증 (Tailscale 없이)

### 목적

개발계에 nginx를 설치해서, **Tailscale을 거치지 않고 순수 캠퍼스 공인 IP(210.94.240.180)로 외부에서 직접 접속 가능한지** 확인.

### 1. 사전 확인 — 포트 점유 현황

bash

```bash
sudo ss -tlnp|grep -E':80|:443'
```

| 포트 | 서비스 | 바인딩 주소 |
| --- | --- | --- |
| 80 | uwsgi (Horizon) | `210.94.240.180`에만 바인딩 |
| 8000 | uwsgi (Nova/Placement 추정) | `210.94.240.180`에만 바인딩 |
| 8004 | uwsgi (Heat 추정) | `210.94.240.180`에만 바인딩 |
| 8022, 8023 | sshd | `210.94.240.180`에만 바인딩 |

→ 80이 이미 점유되어 있어 nginx는 **8888 포트**로 대체 구성.

### 2. nginx 설치 및 8888 포트 구성

```bash
sudo apt install -y nginx

sudo sed -i's/listen 80 default_server;/listen 8888 default_server;/' /etc/nginx/sites-available/default

sudo sed -i's/listen \[::\]:80 default_server;/listen [::]:8888 default_server;/' /etc/nginx/sites-available/default

sudo systemctl restart nginx
```

- 개발계 pc에서 로컬 확인(`curl localhost:8888`) → `200 OK` 정상
- nginx는 `0.0.0.0:8888`로 전체 인터페이스에 바인딩됨 (Horizon과 달리 특정 IP 제한 없음)

### 3. 1차 테스트 — 외부(집 PC) 테스트 결과

| 접속 경로 | 결과 | 원인 |
| --- | --- | --- |
| `curl http://210.94.240.180:8888` (SSH 터널/Tailscale 없이 순수 외부) | **Timeout** | 캠퍼스 경계 방화벽이 화이트리스트에 없는 포트의 인바운드 패킷 자체를 차단 |
| `curl http://100.114.87.22:8888` (Tailscale IP) | **200 OK** | Tailscale WireGuard 터널이 캠퍼스 인바운드 방화벽을 완전히 우회 |
| `curl http://100.114.87.22:80` (Tailscale IP) | **Connection refused** | 방화벽과 무관. Horizon(uwsgi)이 `210.94.240.180`에만 바인딩되어 있어 tailscale IP(`100.x`)로는 애초에 서비스가 없어서 커널이 즉시 거부 |
- 순수 개발계 PC IP(학교망 - 210.94.240.180:8888)

![image.png](%EA%B0%9C%EB%B0%9C%EA%B3%84%20%EC%99%B8%EB%B6%80%20%EC%A0%91%EC%86%8D%20%ED%99%95%EC%9D%B8(NGINX)/image.png)

- 개발계 PC에 붙인 Tailscale IP(Tailscale - 100.114.87.22:8888)

![image.png](%EA%B0%9C%EB%B0%9C%EA%B3%84%20%EC%99%B8%EB%B6%80%20%EC%A0%91%EC%86%8D%20%ED%99%95%EC%9D%B8(NGINX)/image%201.png)

## 4. 2차 테스트 — 가설 검증 (포트별 재확인, 집 PC 기준)

`ss` 바인딩 결과만으로 "80/8000/8004/8022/8023이 화이트리스트 포트"라고 추론했던 것이 실제 검증된 적은 없었기 때문에, 각 포트를 외부에서 직접 재확인함.

powershell

```powershell
curl.exe-v--connect-timeout 5 http://210.94.240.180:443
curl.exe-v--connect-timeout 5 http://210.94.240.180:22
curl.exe-v--connect-timeout 5 http://210.94.240.180:80
curl.exe-v--connect-timeout 5 http://210.94.240.180:8022
```

| 포트 | 로컬 서비스 | 결과 (집 PC → 외부) |
| --- | --- | --- |
| 443 | 없음 | Timeout |
| 22 | 있음 (`0.0.0.0`) | **Timeout** |
| 80 (Horizon) | 있음 (`210.94.240.180`) | **Timeout** |
| 8022 | 있음 (`210.94.240.180`) | **Timeout** |
| 3306, 8888 | 있음 | Timeout |

→ **로컬에 서비스가 떠 있고 공인 IP에 바인딩되어 있어도, 포트를 바꿔가며 테스트해도 전부 timeout.** 포트 기준 화이트리스트 가설은 기각됨.

## 5. 3차 테스트 — 교내망 vs 외부망 대조 확인

동일한 `210.94.240.180:80`을 **교내 wifi**에서 접속 시도.

```bash
curl -v --connect-timeout 5 http://210.94.240.180:80
curl -v --connect-timeout 5 http://210.94.240.180:8888

curl.exe -v --connect-timeout 5 http://210.94.240.180:80
```

| 접속 위치 | 결과 |
| --- | --- |
| 교내 wifi → `210.94.240.180:80` | **접속 성공** |
| 외부 인터넷(집) → `210.94.240.180:80` | Timeout |

→ 포트가 아니라 **접속 출발지(source)** 가 결과를 가른다는 것이 확인됨.

## 6. 결론

1. **캠퍼스 경계 방화벽은 포트 화이트리스트 방식이 아니라, 출발지(source) 기준으로 인바운드를 필터링한다.** 교내 IP 대역에서 오는 트래픽은 통과시키고, 순수 외부 인터넷發 트래픽은 목적지 포트와 무관하게 전면 차단한다. (기존에 "80/8000/8004/8022/8023이 화이트리스트 포트"라고 판단했던 1차 결론은 오류였음 — 실제로는 해당 포트들도 외부에서는 전부 막혀 있었고, 교내에서만 열려 있었음.)
2. **Tailscale은 이 인바운드 방화벽을 완전히 우회한다.** 서버가 Tailscale coordination 서버로 아웃바운드 연결을 먼저 맺어두고 그 위에 WireGuard 터널을 유지하는 구조이기 때문에, 캠퍼스 방화벽 입장에서는 새로운 외부發 인바운드 커넥션이 아니라 서버가 직접 맺어둔 기존 아웃바운드 세션에 대한 응답 트래픽으로 인식되어 검사 대상이 되지 않는다.
3. `Timeout`(방화벽 차단)과 `Connection refused`(포트에 서비스 없음)는 **원인이 완전히 다른 증상**이므로 진단 시 반드시 구분해서 봐야 한다.
4. **결론적으로, 순수 캠퍼스 공인 IP를 통한 Tailscale 미경유 외부 접속은 포트 종류와 무관하게 불가능하다.** 외부에서 개발계 서비스에 접근하려면 Tailscale(또는 이에 준하는 아웃바운드 기반 터널링)을 반드시 거쳐야 한다.