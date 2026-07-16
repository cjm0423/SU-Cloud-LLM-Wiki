---
title: "개발계(baremetal ubuntu) tailscale 구성"
type: "raw"
date: 2026-07-05
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/Tailscale-Setup-Guide]]"
---
# 개발계(baremetal ubuntu) tailscale 구성

- 완료된 과정
    
    ### 1. 개발계(210.94.240.180)에 Tailscale 설치
    
    ```bash
    curl -fsSL https://tailscale.com/install.sh|sh
    ```
    
    ### 2. Tailscale 실행 및 계정 연동
    
    ```bash
    sudo tailscale up
    ```
    
    - 터미널에 `https://login.tailscale.com/a/...` 형태의 인증 링크가 출력됩니다.
    
    ```bash
    https://login.tailscale.com/a/a0ba7da01581f?refreshed=true
    ```
    
    - 팀 공용 구글 계정(`sahmyookcloud@gmail.com`)으로 로그인해서 기기 등록 완료.
    
    > subnet router가 아니라 baremetal 자체가 노드이므로 `--advertise-routes` 옵션은 필요 없습니다. 그냥 `tailscale up`만 하면 됩니다.
    > 
    
    ### 3. 할당된 Tailscale IP 확인
    
    ```bash
    tailscale ip -4
    ```
    
    `100.x.x.x` 형태 IP가 나오는데, 이게 앞으로 집에서 SSH 접속할 주소입니다.
    
    ```bash
    100.114.87.22
    ```
    
    ### ~~4. SSH 서버 활성화 확인 (개발계에서)~~
    
    ```bash
    sudo systemctl status ssh
    ```
    
    혹시 안 깔려 있으면:
    
    ```bash
    sudo apt install -y openssh-server
    sudo systemctl enable --now ssh
    ```
    
    ### 5. 집 PC(클라이언트)에도 Tailscale 설치 & 로그인
    
    - Tailscale 공식 사이트에서 다운로드
    - 동일한 공용 구글 계정으로 로그인 → 같은 tailnet에 합류

### 6. 집에서 SSH 접속

```bash
ssh 계정이름@100.x.x.x
```

```bash
ssh ubuntu@100.114.87.22
```

### 7. Horizon 접속

```bash
ssh -L 8080:210.94.240.180:80 ubuntu@100.114.87.22
```

- 터미널 창 열어둔 상태로

```bash
http://localhost:8080/
```

- 사용자 이름

```bash
admin
```

- 암호

```bash
JfAkaXhgAgqpcU74CZABjQ1imqkFurZSjM8lDglw
```