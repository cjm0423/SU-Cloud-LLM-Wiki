---
title: "tailscale 원격 접속 방법"
type: "raw"
date: 2026-06-14
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/Tailscale-Setup-Guide]]"
---
# tailscale 원격 접속 방법

**1. 개인 PC(클라이언트) Tailscale 설치**
각 팀원은 본인의 노트북이나 데스크탑에 Tailscale 클라이언트를 설치합니다.

- 다운로드 링크: [Tailscale 공식 홈페이지](https://tailscale.com/download)

**2. 공용 계정 로그인 (VPN망 합류)**

- 설치된 Tailscale 프로그램을 실행합니다.
- 서버(Proxmox)를 등록할 때 사용했던 **동일한 공용 구글 계정(sahmyookcloud@gmail.com)**으로 로그인합니다.
- 로그인이 완료되면 서버와 동일한 가상 사설망(VPN)에 묶이게 됩니다.

**3. Proxmox 웹 GUI 접속**

- 웹 브라우저 주소창에 서버의 Tailscale IP와 포트 번호를 입력합니다.

```bash
https://100.x.x.x:8006
```

- 브라우저에서 '연결이 비공개로 설정되어 있지 않습니다' 등의 보안 경고가 뜨면 [고급] ➡️ [~로 이동(안전하지 않음)]을 클릭하여 무시하고 진입합니다.
- Proxmox 로그인 화면이 뜨면 서버 관리자 계정(`root` / `syu3636!!`)으로 로그인하여 자신의 가상머신(VM)을 제어합니다.

# SSH로 접속하는 법

### 우분투 설치 화면(Network Connections)

가장 깔끔하고 편한 방법입니다. 설치 화면에서 바로 입력합니다.

1. 네트워크 카드(예: `ens18`)를 선택하고 [Edit IPv4]를 누릅니다.

![image.png](tailscale%20%EC%9B%90%EA%B2%A9%20%EC%A0%91%EC%86%8D%20%EB%B0%A9%EB%B2%95/image.png)

1. `Automatic (DHCP)`로 되어 있는 것을 `Manual` (수동)로 변경합니다.

![image.png](tailscale%20%EC%9B%90%EA%B2%A9%20%EC%A0%91%EC%86%8D%20%EB%B0%A9%EB%B2%95/image%201.png)

1. 아래 값들을 빈칸에 똑같이 채워 넣습니다:
    - **Subnet:** `192.168.100.0/24`
    - **Address:** `192.168.100.##` (지만님 본인 VM 기준)
        - ~~지만님 VM (vm-cjm): 192.168.100.11~~
        - 재현님 VM (vm-kjh): 192.168.100.12
        - 민기님 VM (vm-lmg): 192.168.100.13
        - 지원님 VM (vm-pjw): 192.168.100.14
        - 지만 lb vm 192.168.100.200 / 201
        - 지만 ct vm 202 / 203 / 204
        - 지만 cp vm 205 / 206
        - 지만 st vm 207
        - GPU VLLM vm 50
    - **Gateway:** `192.168.100.1` (우리가 만든 가상 스위치 주소)
    - **Name servers:** `8.8.8.8` (구글 외부 DNS)
2. 저장하고 설치를 그대로 진행하시면 됩니다.

![image.png](tailscale%20%EC%9B%90%EA%B2%A9%20%EC%A0%91%EC%86%8D%20%EB%B0%A9%EB%B2%95/image%202.png)

- 방향키를 위아래로 움직여서, 화면 아래쪽 `USED DEVICES` 구역에 있는 **`ubuntu-lv` (100.000G)** 항목을 선택합니다.
- 엔터를 누르고 메뉴가 뜨면 `Edit` (편집)을 선택합니다.
- 팝업창에서 **Size** 칸에 적힌 `100.000G`를 싹 지우고, 남은 용량을 전부 털어 넣습니다.
*(사진에 보이는 최대 용량인 `297.996G`를 직접 입력하시면 됩니다.)*
- `Save` (저장)를 눌러 창을 닫습니다.

![image.png](tailscale%20%EC%9B%90%EA%B2%A9%20%EC%A0%91%EC%86%8D%20%EB%B0%A9%EB%B2%95/image%203.png)

- ~~한 번만 진행하면 됨(제가 이미 진행 했습니다)~~
    
    
    ### pve에서 포워딩 활성화하기
    
    지금 열려있는 그 쉘(Shell) 창에 아래 명령어 3줄을 순서대로 복사해서 붙여넣기 해주세요. (리눅스 커널에 포워딩을 영구적으로 허용하는 작업입니다.)
    
    **1단계: 포워딩 허용 설정 저장**
    
    ```bash
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-tailscale.conf
    echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
    ```
    
    2단계: 방금 바꾼 설정 즉시 적용
    
    ```bash
    sysctl -p /etc/sysctl.d/99-tailscale.conf
    ```
    
    3단계: 다시 Tailscale 라우팅 명령 실행 (확인용)
    
    ```bash
    tailscale up --advertise-routes=192.168.100.0/24
    ```
    
    ### 1단계: Proxmox 서버에서 서브넷 라우팅 광고(Advertise)
    
    Proxmox 내부 사설망 대역을 Tailscale 네트워크에 알리는 작업입니다.
    
    1. Proxmox 웹 GUI에서 `pve` 노드를 클릭한 뒤 우측 상단의 [>_ Shell]을 열거나, 서버 CLI 창으로 갑니다.
    2. 아래 명령어를 입력하여 `192.168.100.0/24` 대역을 라우팅하겠다고 선언합니다.
    
    ```bash
    tailscale up --advertise-routes=192.168.100.0/24
    ```
    
    ### 2단계: Tailscale 관리자 패널에서 라우트 승인(Approve)
    
    보안을 위해 관리자 페이지에서 이 통로를 최종 승인해 주어야 합니다.
    
    1. 노트북이나 스마트폰에서 [Tailscale 관리자 콘솔(login.tailscale.com)](https://login.tailscale.com/)에 접속합니다.
    2. 팀 공용 구글 계정으로 로그인합니다.
    3. 기기 목록(Machines)에서 본인의 Proxmox 서버(`pve`)를 찾아 클릭합니다.
    4. **[Routing settings]** 메뉴로 이동합니다.
    5. **Subnet routes** 항목에 방금 광고한 `192.168.100.0/24` 대역이 나타나 있는 것을 볼 수 있습니다.
    6. 해당 대역 옆의 스위치를 켜서 **승인(Approve)** 상태로 변경합니다.

### 3단계: 노트북 터미널에서 SSH 접속하기

1. 노트북에서 터미널 프로그램(Windows의 PowerShell/CMD, macOS의 Terminal, 또는 VS Code나 MobaXterm 등)을 켭니다.
2. 우분투 설치 시 설정했던 본인의 계정명과 생성한 VM의 사설 IP 주소를 사용해 아래 명령어를 입력합니다.

```bash
# VM 접속 예시 (ssh ubuntu@192.168.100.##) -> 각자 ubuntu 설치 시에 입력한 정적 IP
ssh 계정이름@192.168.100.##
```

- 처음 접속할 때 `Are you sure you want to continue connecting (yes/no)?` 라는 문구가 뜨면 `yes`를 입력하고 엔터를 누릅니다.
- 우분투 설치 시 만들었던 비밀번호를 입력하면 Proxmox 웹 콘솔을 거치지 않고 노트북에서 바로 리눅스를 제어할 수 있게 됩니다.