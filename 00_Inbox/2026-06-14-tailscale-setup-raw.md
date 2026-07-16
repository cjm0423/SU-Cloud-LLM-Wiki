---
title: "tailscale 구성 및 설정"
type: "raw"
date: 2026-06-14
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/Tailscale-Setup-Guide]]"
---
# tailscale 구성 및 설정

**1. 엔터프라이즈 저장소 비활성화 (업데이트 오류 방지)**

Proxmox 무료 사용 시 발생하는

`401 Unauthorized`

에러를 방지하기 위해 상용 저장소를 꺼줍니다.

```bash
vi /etc/apt/sources.list.d/pve-enterprise.list
```

- 열린 파일에서 `deb https://...` 줄 맨 앞에 `#`을 붙여 주석 처리합니다.
- `Ctrl + O` ➡️ `Enter` ➡️ `Ctrl + X`를 눌러 저장 후 종료합니다.

**2. 패키지 업데이트 및 Tailscale 설치**
시스템을 최신 상태로 갱신한 뒤, 공식 설치 스크립트를 다운로드하여 실행합니다.

```bash
apt update
curl -fsSL https://tailscale.com/install.sh | sh
```

3. Tailscale 실행 및 계정 연동

```bash
tailscale up
```

- 위 명령어를 치면 화면에 `https://login.tailscale.com/a/...` 형태의 인증 링크가 출력됩니다.
- 해당 링크를 스마트폰이나 노트북 웹 브라우저에 입력하여 접속합니다.
- 팀 **공용 구글 계정**으로 로그인을 진행하여 기기 등록을 완료합니다.

**4. 할당된 고정 IP 확인 및 기록**

```bash
tailscale ip -4
```

출력되는 `100.x.x.x` 형태의 IP 주소를 기록해 둡니다. (이 주소가 앞으로 접속할 Proxmox 고정 주소입니다.)

### 4. 팀원별 자원 풀(Resource Pool) 생성

공용 계정을 사용하되, 각 팀원의 작업 공간을 논리적으로 분리하기 위해 자원 풀을 생성합니다.

1. Proxmox 웹 GUI에서 **[Datacenter]** ➡️ **[Permissions]** ➡️ **[Pools]** 메뉴로 이동합니다.
2. **[Create]** 버튼을 누릅니다.
3. **ID(Name):** 팀원별 이니셜을 넣은 이름을 입력합니다. (예: `Pool-cjm`, `Pool-kjh` 등)
4. 팀원 수에 맞게 총 4개의 풀을 생성합니다.

### 5. 내부 격리 가상 스위치(SDN NAT 망) 구성

학교 보안 스위치의 포트 차단 대참사를 막고, VM들이 외부 인터넷을 안전하게 쓸 수 있도록 내부 사설 NAT 네트워크를 구축합니다.

- **1단계: 가상 구역(Zone) 생성**
    1. **[Datacenter]** ➡️ **[SDN]** ➡️ **[Zones]** 메뉴에서 **[Add]** ➡️ [Simple]을 클릭합니다.
    2. **ID:** `natzone` 입력 (**주의:** 하이픈 등의 특수문자는 인식 불가하므로 오직 영문과 숫자만 사용)
    3. **IPAM:** `pve` 선택 후 저장합니다.
- **2단계: 가상 스위치(VNet) 생성**
    1. SDN 메뉴 아래의 [VNets]로 이동하여 [Add]를 클릭합니다.
    2. **Name:** `vmnet` 입력
    3. **Zone:** 방금 만든 `natzone` 선택 후 저장합니다.
- **3단계: 내부 사설 IP 대역(Subnet) 설정**
    1. 생성된 `vmnet`을 선택하고 우측 하단의 **[Subnets]** 영역에서 [Create]를 누릅니다.
    2. **Subnet:** `192.168.100.0/24` 입력 (학교 및 Tailscale 망과 겹치지 않는 사설 대역)
    3. **Gateway:** `192.168.100.1` 입력
    4. **SNAT:** ⭐**반드시 체크** (이 설정을 켜야 안쪽 VM들이 인터넷 연결이 가능해짐) 후 저장합니다.
- **4단계: 네트워크 최종 적용**
    1. 최상위 **[SDN]** 메뉴를 다시 클릭한 뒤, 상단의 **[Apply]** 버튼을 눌러 설정을 물리 서버에 최종 반영합니다.

### 6. 오픈스택 실습용 가상머신(VM) 생성 및 네트워크 연결

1. 우측 상단의 **[Create VM]** 버튼을 누르고 아래 핵심 설정을 적용합니다.
    - **[General] 탭:** Name(예: `vm-cjm`)을 입력하고, **Resource Pool**에서 본인의 풀을 지정합니다.
    - **[OS] 탭:** 미리 다운로드해 둔 우분투 서버 ISO 이미지를 선택합니다.
    - **[Disks] 탭:** Storage는 `local-lvm`(NVMe SSD)으로 두고, 오픈스택 환경에 맞게 용량을 `300` GiB 이상 넉넉하게 입력합니다.
    - **[CPU] 탭:** Cores를 `8`로 설정하고, 오픈스택 중첩 가상화(Nested)를 위해 **Type을 반드시 `host`로 변경**합니다.
    - **[Memory] 탭:** 램 용량을 `24576` MiB (24GB)로 입력합니다.
    - **[Network] 탭:** Bridge 항목을 기본값 대신 방금 만든 가상 스위치인 `vmnet`으로 변경합니다.
    - **[Confirm] 탭:** `Start after created`(생성 후 바로 시작) 체크가 해제되어 있는지 확인하고 [Finish]를 누릅니다.