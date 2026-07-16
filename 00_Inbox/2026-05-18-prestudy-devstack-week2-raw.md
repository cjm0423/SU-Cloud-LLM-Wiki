---
title: "사전학습 2주차 (DevStack 환경 구성)"
type: "raw"
date: 2026-05-18
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/DevStack-Installation-Guide]]"
---
# 2주차(DevStack 환경 구성)

### 1. 실습 환경 구성

- **가상화 소프트웨어:** Oracle VirtualBox
- **운영체제 (OS):** Ubuntu 22.04 LTS Server
- **권장 자원 설정:**
    - **Memory:** 6GB (6144 MB) 이상
    - **Disk:** 40GB 이상
    - **CPU:** 4 Core 이상

### 2. DevStack 설치 핵심 절차 (5단계)

1. **Repository Update 및 필수 패키지 설치**
    - `apt update` 및 `apt upgrade`를 통해 우분투 패키지 목록을 최신화하고 설치 환경을 준비
2. **`stack` 사용자 생성 및 권한 설정**
    - 보안상 root 계정에서의 직접 설치를 권장하지 않으므로, 전용 `stack` 계정을 생성
    - 설치 중 패스워드 입력으로 인한 중단을 막기 위해 sudo 권한(`NOPASSWD: ALL`)을 부여
3. **DevStack 다운로드**
    - Git을 이용해 OpenStack 공식 리포지토리에서 DevStack 스크립트를 Clone
4. **`local.conf` 설정**
    - 관리자, 데이터베이스, 메세지 큐 등 설치에 필요한 각종 비밀번호와 호스트 IP 네트워크 환경을 정의하는 핵심 구성 파일
5. **DevStack 설치 실행**
    - 설정이 완료되면 `stack` 계정에서 `./stack.sh` 스크립트를 실행하여 설치를 진행

### 3. 추가 학습 포인트 (중첩 가상화의 이해)

- **구조적 특징:** 호스트 운영체제(VirtualBox) 위에 우분투 가상머신을 띄우고, 그 우분투 내부의 KVM을 통해 OpenStack 인스턴스를 다시 띄우는 이중 가상화 구조
- **네트워크 유의사항:** 우분투 가상머신 내부에서 구축된 OpenStack 대시보드(Horizon)에 접근하기 위해서는, VirtualBox 네트워크 설정에서 '포트 포워딩'을 적용하거나 '호스트 전용 어댑터'를 추가하는 작업이 수반되어야 함

## DevStack 설치 시 문제 1.

```bash
WARNING: this script has not been tested on jammy
+./stack.sh:main:236                       [[ '' != \y\e\s ]]
+./stack.sh:main:237                       die 237 'If you wish to run this script anyway run with FORCE=yes'
+functions-common:die:290                  local exitcode=0
+functions-common:die:291                  set +o xtrace
[Call Trace]
./stack.sh:237:die
[ERROR] ./stack.sh:237 If you wish to run this script anyway run with FORCE=yes
/opt/stack/devstack/functions-common: line 336: /opt/stack/logs/error.log: No such file or directory
```

`WARNING: this script has not been tested on jammy` ⇒ 'jammy'는 현재 가상 머신에 설치하신 Ubuntu 22.04 LTS(Jammy Jellyfish) 버전이다. 

22.04버전에서 test가 진행되지 않아서 ./stack.sh:237:die가 호출 → 237번 라인에서 ./stack.sh를 die

해결방법: `If you wish to run this script anyway run with FORCE=yes`  FORCE=yes 옵션을 추가하여 실행하면 된다. → `FORCE=yes ./stack.sh`

추가 정보: `/opt/stack/devstack/functions-common: line 336: /opt/stack/logs/error.log: No such file or directory` 에러 로그를 저장할 `/opt/stack/logs/error.log` 가 생성 되기도 전에 에러가 발생하여 에러 로그를 적재하지 못하는 오류.

---

## DevStack 설치 시 문제 2. (중요 - 현재 [github](2%EC%A3%BC%EC%B0%A8(DevStack%20%ED%99%98%EA%B2%BD%20%EA%B5%AC%EC%84%B1)%20361d8e51100c8017b50ce21615b41472.md)로 진행 시 설치 문제)

```bash
Requirement already satisfied: setuptools!=24.0.0,!=34.0.0,!=34.0.1,!=34.0.2,!=34.0.3,!=34.1.0,!=34.1.1,!=34.2.0,!=34.3.0,!=34.3.1,!=34.3.2,!=36.2.0,>=21.0.0 in /opt/stack/requirements/.venv/lib/python3.10/site-packages (from openstack_requirements==1.2.1.dev8348) (82.0.1)
ERROR: Package 'openstack-requirements' requires a different Python: 3.10.12 not in '>=3.11'
+inc/python:pip_install:1                  exit_trap
+./stack.sh:exit_trap:519                  local r=1
++./stack.sh:exit_trap:520                  jobs -p
+./stack.sh:exit_trap:520                  jobs=
+./stack.sh:exit_trap:523                  [[ -n '' ]]
+./stack.sh:exit_trap:529                  '[' -f '' ']'
+./stack.sh:exit_trap:534                  kill_spinner
+./stack.sh:kill_spinner:429               '[' '!' -z '' ']'
+./stack.sh:exit_trap:536                  [[ 1 -ne 0 ]]
+./stack.sh:exit_trap:537                  echo 'Error on exit'
Error on exit
+./stack.sh:exit_trap:539                  type -p generate-subunit
+./stack.sh:exit_trap:540                  generate-subunit 1778827217 142 fail
+./stack.sh:exit_trap:542                  [[ -z /opt/stack/logs ]]
+./stack.sh:exit_trap:545                  /opt/stack/data/venv/bin/python3 /opt/stack/devstack/tools/worlddump.py -d /opt/stack/logs
+./stack.sh:exit_trap:554                  exit 1
```

`Package 'openstack-requirements' requires a different Python: 3.10.12 not in '>=3.11'`  현재 

`https://opendev.org/openstack/devstack` 이 최신 devstack을 다운 받아서 ./stack.sh를 진행했을 시 ubuntu 22.04를 지원하지 않고 python 버전이 3.11 이상이 필요하다.

해결 방안:  Ubuntu 22.04에 맞는 DevStack 안정화 버전 다운로드

현재 VM을 그대로 살리면서 해결하는 방법입니다. 최신 개발 버전(`master`) 대신, 우분투 22.04와 파이썬 3.10을 공식 지원하는 오픈스택 안정화 브랜치

![image.png](2%EC%A3%BC%EC%B0%A8(DevStack%20%ED%99%98%EA%B2%BD%20%EA%B5%AC%EC%84%B1)/image.png)

- ~~꼬여서 문제 발생~~
    
    ```bash
    # 1. 설치 중단으로 꼬여있을 수 있는 기존 devstack 폴더 및 설정 삭제
    cd ~/devstack
    ./unstack.sh
    ./clean.sh
    sudo rm -f /usr/local/bin/privsep-helper
    cd ~
    sudo rm -rf devstack /opt/stack
    
    # 2. stack 계정의 삭제한 홈디렉토리 만들어주기
    sudo mkdir -p /opt/stack
    sudo chown -R stack:stack /opt/stack 
    sudo chmod +x /opt/stack
    cd /opt/stack
    
    # 3. 우분투 22.04를 완벽 지원하는 2023.1 버전으로 다시 다운로드
    git clone -b unmaintained/2023.1 https://opendev.org/openstack/devstack
    cd devstack
    
    # 4. local.conf 설정'
    
    # 4.1 local.conf 파일 생성 및 수정
    cp ./samples/local.conf local.conf
    vim local.conf
    
    # 4.2 local.conf 파일 수정 내용
    ADMIN_PASSWORD=stack
    DATABASE_PASSWORD=stack
    RABBIT_PASSWORD=stack
    SERVICE_PASSWORD=stack
    
    HOST_IP=192.168.x.x  # ip a 명령어를 통해 확인한 2번째 IP 입력
    
    # 5. 설치 스크립트 실행
    ./stack.sh
    ```
    

---

## VM 처음 생성 시 **설치 절차(해결 방안)**

**1. Repository Update 및 필수 패키지 설치**

```bash
sudo apt update
sudo apt install python3 python3-pip virtualenv git -y
```

**2. stack 사용자 생성 및 권한 설정**

```bash
sudo useradd -s /bin/bash -d /opt/stack -m stack
sudo chmod +x /opt/stack
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack
sudo -u stack -i
```

**3. DevStack 다운로드**

- [**~~영상](https://youtu.be/efGyEr54Jyw) 속 2025.2 버전(오류 발생)~~**
    
    ```bash
    git clone -b stable/2025.2 https://opendev.org/openstack/devstack
    cd devstack
    ```
    
    ---
    
    에러 내용: 
    
    ```bash
    ERROR: Cannot install sphinx!=2.1.0 and >=2.0.0 because these package versions have conflicting dependencies.
    
    The conflict is caused by:
        The user requested sphinx!=2.1.0 and >=2.0.0
        The user requested (constraint) sphinx===9.0.4
    
    To fix this you could try to:
    1. loosen the range of package versions you've specified
    2. remove package versions to allow pip to attempt to solve the dependency conflict
    
    [notice] A new release of pip is available: 25.1.1 -> 26.1.1
    [notice] To update, run: pip install --upgrade pip
    ERROR: ResolutionImpossible: for help visit https://pip.pypa.io/en/latest/topics/dependency-resolution/#dealing-with-dependency-conflicts
    
    =================================== log end ====================================
    ERROR: could not install deps [-chttps://releases.openstack.org/constraints/upper/master, -r/opt/stack/tempest/requirements.txt, -r/opt/stack/tempest/doc/requirements.txt]; v = InvocationError('/opt/stack/tempest/.tox/venv/bin/python -m pip install -chttps://releases.openstack.org/constraints/upper/master -r/opt/stack/tempest/requirements.txt -r/opt/stack/tempest/doc/requirements.txt', 1)
    ___________________________________ summary ____________________________________
    ERROR:   venv: could not install deps [-chttps://releases.openstack.org/constraints/upper/master, -r/opt/stack/tempest/requirements.txt, -r/opt/stack/tempest/doc/requirements.txt]; v = InvocationError('/opt/stack/tempest/.tox/venv/bin/python -m pip install -chttps://releases.openstack.org/constraints/upper/master -r/opt/stack/tempest/requirements.txt -r/opt/stack/tempest/doc/requirements.txt', 1)
    +lib/tempest:configure_tempest:1           exit_trap
    +./stack.sh:exit_trap:549                  local r=1
    ++./stack.sh:exit_trap:550                  jobs -p
    +./stack.sh:exit_trap:550                  jobs=
    +./stack.sh:exit_trap:553                  [[ -n '' ]]
    +./stack.sh:exit_trap:559                  '[' -f /tmp/tmp.YqJUzrN8U9 ']'
    +./stack.sh:exit_trap:560                  rm /tmp/tmp.YqJUzrN8U9
    +./stack.sh:exit_trap:564                  kill_spinner
    +./stack.sh:kill_spinner:459               '[' '!' -z '' ']'
    +./stack.sh:exit_trap:566                  [[ 1 -ne 0 ]]
    +./stack.sh:exit_trap:567                  echo 'Error on exit'
    Error on exit
    +./stack.sh:exit_trap:569                  type -p generate-subunit
    +./stack.sh:exit_trap:570                  generate-subunit 1778835440 767 fail
    +./stack.sh:exit_trap:572                  [[ -z /opt/stack/logs ]]
    +./stack.sh:exit_trap:575                  /opt/stack/data/venv/bin/python3 /opt/stack/devstack/tools/worlddump.py -d /opt/stack/logs
    +./stack.sh:exit_trap:584                  exit 1
    ```
    
    에러 원인: **DevStack 브랜치와 제약 사항(Constraints) 버전이 꼬였기 때문**
    
    - 현재 로그를 보면 `https://releases.openstack.org/constraints/upper/master`를 참조 → master브랜치(최신 버전)
    
    해결 방법: `local.conf`  내용 추가
    
    ```bash
    vi local.conf
    ```
    
    ```bash
    # 2025.2 버전의 의존성 패키지 버전을 강제 지정
    UPPER_CONSTRAINTS_FILE=https://releases.openstack.org/constraints/upper/2025.2
    ```
    
    - 기타 주요 서비스 브랜치가 여전히 master를 참조 중 - (오류 발생)
    
    해결 방법: `local.conf`  내용 추가
    
    ```bash
    vi local.conf
    ```
    
    ```bash
    # 기타 주요 서비스 브랜치도 안전하게 고정
    TEMPEST_BRANCH=stable/2025.2
    NOVA_BRANCH=stable/2025.2
    NEUTRON_BRANCH=stable/2025.2
    GLANCE_BRANCH=stable/2025.2
    KEYSTONE_BRANCH=stable/2025.2
    ```
    
    → 고정 해도 여전히 오류 발생(local.conf의 설정이 적용되지 않는 중)
    
- **(ubuntu 22.04를 지원하는 2023.1 버전 다운) - 설치 되는 것 확인 완료**
    
    ```bash
    git clone -b unmaintained/2023.1 https://opendev.org/openstack/devstack
    cd devstack
    ```
    
    ![image.png](2%EC%A3%BC%EC%B0%A8(DevStack%20%ED%99%98%EA%B2%BD%20%EA%B5%AC%EC%84%B1)/image%201.png)
    

**4. local.conf 설정**

**(1) local.conf 파일 생성 및 수정**

```bash
cp ./samples/local.conf local.conf
vim local.conf
```

**(2) local.conf 파일 수정 내용**

```bash
ADMIN_PASSWORD=stack
DATABASE_PASSWORD=stack
RABBIT_PASSWORD=stack
SERVICE_PASSWORD=stack

HOST_IP=192.168.x.x  # ip a 명령어를 통해 확인한 2번째 IP 입력
```

**5. DevStack 설치 실행**

```bash
./stack.sh
```

### [**OpenStack CLI를 이용한 기본 리소스 조회 실습**](https://github.com/NOOJU/openstack-devstack-lab#openstack-cli%EB%A5%BC-%EC%9D%B4%EC%9A%A9%ED%95%9C-%EA%B8%B0%EB%B3%B8-%EB%A6%AC%EC%86%8C%EC%8A%A4-%EC%A1%B0%ED%9A%8C-%EC%8B%A4%EC%8A%B5)

- 깃허브에 이어서 실습 진행

DevStack 버전 차이로 인한 논리적 네트워크 구성 안됨

### **🛠️ private 네트워크 및 NAT 라우터 구성 방법**

**1. 네트워크 및 서브넷 생성**

- 좌측 메뉴에서 **[네트워크]** > [네트워크]로 이동하여 **[네트워크 생성]**
- **네트워크 탭:** 네트워크 이름 `private`
- **서브넷 탭:** 서브넷 이름을 `private-subnet`으로 지정하고, 할당할 사설 네트워크 주소(CIDR, 예: `10.0.0.0/26`)를 입력한 뒤 생성

**2. 라우터 생성 (NAT 역할)**

- 좌측 메뉴에서 **[네트워크]** > [라우터]로 이동하여 [라우터 생성]을 클릭합니다.
- 라우터 이름 `router1` 을 입력하고, 외부 네트워크(External Network)를 현재 가지고 계신 `public`으로 지정하여 생성합니다.

**3. 라우터에 내부 네트워크 인터페이스 연결**

- 생성된 라우터의 이름을 클릭하여 상세 페이지로 들어갑니다.
- **[인터페이스]** 탭으로 이동하여 [인터페이스 추가]를 클릭합니다.
- 서브넷 선택란에서 1번에서 만든 `private-subnet`을 찾아 연결해 줍니다.

이렇게 설정하여 라우터가 외부(`public`)와 내부(`private`)를 모두 연결하게 만들면 NAT 구성이 완료