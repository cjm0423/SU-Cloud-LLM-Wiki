---
title: "오픈스택 수동설치 구성"
type: "raw"
date: 2026-06-14
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/OpenStack-Manual-Install-Guide]]"
---
# 오픈스택 수동설치 구성

# 🌐 OpenStack 7-Node HA 고가용성 클러스터 구축 계획

> **목적:** 제한된 자원(8 Cores, 24GB RAM) 내에서 실제 프로덕션 환경의 고가용성(3-Controller, Load Balancer 분리) 아키텍처와 네트워크 통신 구조를 검증하기 위한 초경량 PoC(개념 증명) 환경 설계
> 

## 📊 1. 전체 자원 할당 요약 (Total Budget)

- **CPU:** 8 Cores 물리 자원 (최대 12 Cores로 오버커밋 허용, 약 1.5배)
- **RAM:** 24 GB (가상머신 총합 24 GB 배정 / 호스트 OS 안전 마진 확보)
- **Storage:** 300 GB (Thin Provisioning 활성화 권장)

## 🖥️ 2. 노드별 세부 가상머신(VM) 사양 개요

| **VM 명칭** | **수량** | **CPU (Cores)** | **Memory (RAM)** | **Storage (Disk)** | **주요 역할 및 필수 패키지** |
| --- | --- | --- | --- | --- | --- |
| **openstack-lb** | 1대 | 1 | **1024 MiB(1 GB)** | 10 GB | HAProxy, Keepalived (VIP 관리 및 API 로드밸런싱) |
| **openstack-ct01** | 1대 | 2 | **4096 MiB(4 GB)** | 40 GB | Controller 1 (Keystone, Glance, Nova-API, DB 1, MQ 1) |
| **openstack-ct02** | 1대 | 2 | **4096 MiB(4 GB)** | 40 GB | Controller 2 (Keystone, Glance, Nova-API, DB 2, MQ 2) |
| **openstack-ct03** | 1대 | 2 | **4096 MiB(4 GB)** | 40 GB | Controller 3 (Keystone, Glance, Nova-API, DB 3, MQ 3) |
| **openstack-cp01** | 1대 | 2 | **3584 MiB(3.5  GB)** | 50 GB | Compute 1 (Nova-Compute, **CPU Type: host 필수**) |
| **openstack-cp02** | 1대 | 2 | **3584 MiB(3.5  GB)** | 50 GB | Compute 2 (Nova-Compute, **CPU Type: host 필수**) |
| **openstack-st01** | 1대 | 1 | **4096 MiB(4 GB)** | OS: 20 GB
Data: 50 GB(cinder)
Data: 30GB(Swift) | Storage (Cinder-Volume, LVM 전용 빈 디스크 추가 마운트) |

### 1. 공통 설정 (7대 모두 동일하게 적용)

VM 생성 창을 띄우고 다음 탭들을 순서대로 설정합니다.

- **[General] 탭:** * `Name`: 설계도의 이름(`openstack-lb`, `openstack-ct01` 등)을 입력합니다.
    - `Resource Pool`: 본인에게 할당된 풀(Pool)을 선택합니다.
- **[OS] 탭:** * 다운로드해 둔 **Ubuntu Server ISO 이미지**를 선택합니다. (오픈스택 호환성이 가장 좋은 **Ubuntu 22.04 LTS** 버전을 강력히 권장합니다.)
- **[System] 탭:** 기본값 그대로 둡니다.
- **[Disks] 탭:** * `Storage`: `local-lvm`을 선택합니다.
    - `Disk size (GiB)`: 설계도에 기재된 각 VM의 OS 용량을 입력합니다.
- **[CPU] 탭:** * `Cores`: 설계도에 기재된 코어 수를 입력합니다.
- **[Memory] 탭 (🚨 매우 중요):** * `Memory (MiB)`: 설계도의 RAM 용량을 메가바이트 단위로 입력합니다. (예: 4GB = 4096, 1GB = 1024)
    - **Advanced 란의 `Ballooning Device` 체크를 반드시 해제하세요.** (메모리가 빡빡한 환경에서 Proxmox가 램을 임의로 회수하면 오픈스택 DB가 즉사합니다.)
- **[Network] 탭:** * `Bridge`: 먼저 내부망인 `vmnet`을 선택합니다.
- **[Confirm] 탭:** `Start after created` 체크가 해제되어 있는지 확인 후 [Finish]를 누릅니다.

### 2. 특정 노드별 하드웨어 추가 설정 (VM 생성 직후)

VM 생성을 마친 후, 해당 VM을 클릭하고 **[Hardware]** 탭으로 이동하여 아래의 필수 추가 작업을 진행합니다.

- **전체 7대 공통 (외부망 랜카드 추가):** * 상단의 `Add` -> `Network Device` 클릭 -> Bridge를 `vmbr0`로 선택하고 추가합니다. (이제 모든 VM은 `vmnet`, `vmbr0` 2개의 랜카드를 가집니다.)

## 🔌 3. 네트워크 아키텍처 및 IP 배정 계획 (2-NIC 구성)

### 1) 가상 스위치(Bridge) 구성

- **NIC 1 (Management 망):** `vmnet` 브릿지 연결. 노드 간 제어 신호, DB 동기화, 내부 API 전용. (모든 노드 고정 IP 할당)
- **NIC 2 (Provider 망):** `vmbr0` 브릿지 연결. 오픈스택 내부 인스턴스들의 외부 통신용 통로. (호스트 OS단에서는 IP 미할당, `up` 상태만 유지)

### 2) IP 토폴로지 (Management 대역: `192.168.100.0/24`)

- **가상 VIP (Load Balancer용):** `192.168.100.200`
- **openstack-lb:** `192.168.100.201`
- **openstack-ct01 / ct02 / ct03:** `192.168.100.202` / `192.168.100.203` / `192.168.100.204`
- **openstack-cp01 / cp02:** `192.168.100.205` / `192.168.100.206`
- **openstack-st01:** `192.168.100.207`

[Claude](https://claude.ai/share/99efaad9-e9f0-46d4-90e5-25db559d8737)

---

![image.png](%EC%98%A4%ED%94%88%EC%8A%A4%ED%83%9D%20%EC%88%98%EB%8F%99%EC%84%A4%EC%B9%98%20%EA%B5%AC%EC%84%B1/image.png)

### Phase 0 — 사전 준비 (7대 전체)

**목표:** 모든 노드를 동일한 베이스라인으로 맞춘다.

1. Ubuntu 22.04 Server 설치 완료 확인 (각 VM)
2. 호스트명 설정 `hostnamectl set-hostname openstack-ct01` 등
3. `/etc/hosts` 에 7대 전부 IP↔호스트명 매핑 추가
4. `ens18` (vmnet, Management) 고정 IP 설정 — Netplan으로 `192.168.100.201~207`
5. `ens19` (vmbr0, Provider) — IP 없이 `up` 상태만 유지 (`optional: true`)
6. Swap 파일 생성 (2GB 이상 필수)

```jsx
fallocate -l 2G /swapfile && chmod 600 /swapfile
   mkswap /swapfile && swapon /swapfile
   echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
```

1. `chrony` 설치 + NTP 동기화 확인 (Galera 클러스터에 치명적)
2. 패키지 업데이트 `apt update && apt upgrade -y`
3. 관리 노드(ct01)에서 나머지 6대로 SSH 키 배포
4. Python3, pip 설치 확인

> ✅ 검증: 모든 노드에서 `ping 192.168.100.200` (VIP) 제외하고 상호 ping 성공
> 

- 실제 작업
    
    ### Step 1: 호스트명 설정 (각 노드마다 다르게)
    
    ```jsx
    # 201 (lb)
    sudo hostnamectl set-hostname openstack-lb
    
    # 202 (ct01)
    sudo hostnamectl set-hostname openstack-ct01
    
    # 203 (ct02)
    sudo hostnamectl set-hostname openstack-ct02
    
    # 204 (ct03)
    sudo hostnamectl set-hostname openstack-ct03
    
    # 205 (cp01)
    sudo hostnamectl set-hostname openstack-cp01
    
    # 206 (cp02)
    sudo hostnamectl set-hostname openstack-cp02
    
    # 207 (st01)
    sudo hostnamectl set-hostname openstack-st01
    ```
    
    ### Step 2: /etc/hosts 설정 (7대 전부 동일)
    
    ```jsx
    sudo tee -a /etc/hosts <<'EOF'
    
    # OpenStack HA Cluster
    192.168.100.200 openstack-vip
    192.168.100.201 openstack-lb
    192.168.100.202 openstack-ct01
    192.168.100.203 openstack-ct02
    192.168.100.204 openstack-ct03
    192.168.100.205 openstack-cp01
    192.168.100.206 openstack-cp02
    192.168.100.207 openstack-st01
    EOF
    ```
    
    ### Step 3: Swap 생성 (7대 전부 동일)
    
    ```jsx
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    # 확인
    free -h
    ```
    
    ### Step 4: 패키지 업데이트 + 기본 도구 설치 (7대 전부 동일)
    
    ```jsx
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y chrony curl wget vim net-tools
    ```
    
    ### Step 5: NTP 동기화 확인 (7대 전부 동일)
    
    ```jsx
    sudo systemctl enable --now chrony
    chronyc tracking | grep "System time"
    ```
    
    ### Step 6: SSH 키 배포
    
    ```jsx
    # ct01 (192.168.100.202) 에서 실행
    # SSH 키 생성
    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
    
    # 나머지 6대에 키 배포
    for ip in 201 203 204 205 206 207; do
        ssh-copy-id ubuntu@192.168.100.$ip
    done
    ```
    
    ### Step 7: 스냅샷
    
    **1대 기준 순서:**
    
    1. 왼쪽 트리에서 vm 클릭
    2. 왼쪽 메뉴에서 **Snapshots** 클릭
    3. 상단 **Take Snapshot** 버튼 클릭
    4. Name: `phase0-complete` 입력
    5. **Include RAM** 체크 해제 (VM 켜진 상태면 오래 걸리니까)
    6. **Take Snapshot** 클릭
    

---

### Phase 1 — 인프라 기반 (lb + ct01~03)

**목표:** API 엔드포인트 VIP, DB 클러스터, MQ 클러스터를 완성한다.

### lb 노드

1. HAProxy 설치 및 기본 설정 (`/etc/haproxy/haproxy.cfg`)
    - frontend/backend 블록: Keystone(5000), Nova-API(8774), Glance(9292), Neutron(9696), Cinder(8776), Placement(8778), Octavia(9876) 포트
2. Keepalived 설치 + VIP `192.168.100.200` 설정 (`/etc/keepalived/keepalived.conf`)
3. `haproxy`, `keepalived` 서비스 활성화 및 VIP 부착 확인

### ct01~03 노드 (MariaDB Galera 클러스터)

1. MariaDB 설치 (`apt install mariadb-server python3-pymysql`)
2. `galera.cnf` 작성 — `wsrep_cluster_address`, `wsrep_node_address`, `wsrep_node_name` 3대 각각 설정
3. ct01에서 `galera_new_cluster` 로 부트스트랩
4. ct02, ct03 순서대로 mariadb 시작 → `SHOW STATUS LIKE 'wsrep_cluster_size'` = 3 확인
5. OpenStack DB 미리 생성 (keystone, glance, nova, neutron, cinder, placement, octavia)

### ct01~03 노드 (RabbitMQ 클러스터)

1. RabbitMQ 설치 (`apt install rabbitmq-server`)
2. Erlang cookie 동기화 (ct01 기준으로 ct02, ct03에 `/var/lib/rabbitmq/.erlang.cookie` 복사)
3. ct02, ct03에서 `rabbitmqctl join_cluster rabbit@openstack-ct01`
4. `rabbitmqctl cluster_status` 확인 + openstack 유저 생성

> ✅ 검증: `curl http://192.168.100.200:5000` → HAProxy 응답, Galera 3-node, RabbitMQ 3-node 확인
> 

- 실제 작업
    
    ### Step 1: HAProxy + Keepalived (lb 노드)
    
    `ssh ubuntu@192.168.100.201` 접속하고:
    
    ```jsx
    sudo apt install -y haproxy keepalived
    ```
    
    설치 되면 HAProxy 설정 파일 작성해:
    
    ```jsx
    sudo tee /etc/haproxy/haproxy.cfg <<'EOF'
    global
        log /dev/log local0
        maxconn 4096
        daemon
    
    defaults
        log global
        mode http
        option httplog
        timeout connect 10s
        timeout client 300s
        timeout server 300s
    
    frontend keystone_public
        bind *:5000
        default_backend keystone_back
    
    frontend nova_api
        bind *:8774
        default_backend nova_back
    
    frontend glance_api
        bind *:9292
        default_backend glance_back
    
    frontend neutron_api
        bind *:9696
        default_backend neutron_back
    
    frontend placement_api
        bind *:8778
        default_backend placement_back
    
    frontend cinder_api
        bind *:8776
        default_backend cinder_back
    
    backend keystone_back
        balance roundrobin
        option httpchk GET /v3
        http-check expect status 200
        server ct01 192.168.100.202:5000 check inter 2s
        server ct02 192.168.100.203:5000 check inter 2s
        server ct03 192.168.100.204:5000 check inter 2s
    
    backend nova_back
        balance roundrobin
        server ct01 192.168.100.202:8774 check inter 2s
        server ct02 192.168.100.203:8774 check inter 2s
        server ct03 192.168.100.204:8774 check inter 2s
    
    backend glance_back
        balance roundrobin
        server ct01 192.168.100.202:9292 check inter 2s
        server ct02 192.168.100.203:9292 check inter 2s
        server ct03 192.168.100.204:9292 check inter 2s
    
    backend neutron_back
        balance roundrobin
        server ct01 192.168.100.202:9696 check inter 2s
        server ct02 192.168.100.203:9696 check inter 2s
        server ct03 192.168.100.204:9696 check inter 2s
    
    backend placement_back
        balance roundrobin
        server ct01 192.168.100.202:8778 check inter 2s
        server ct02 192.168.100.203:8778 check inter 2s
        server ct03 192.168.100.204:8778 check inter 2s
    
    backend cinder_back
        balance roundrobin
        server ct01 192.168.100.202:8776 check inter 2s
        server ct02 192.168.100.203:8776 check inter 2s
        server ct03 192.168.100.204:8776 check inter 2s
    EOF
    ```
    
    그 다음 Keepalived 설정:
    
    ```jsx
    sudo tee /etc/keepalived/keepalived.conf <<'EOF'
    vrrp_instance VI_1 {
        state MASTER
        interface ens18
        virtual_router_id 51
        priority 100
        advert_int 1
        authentication {
            auth_type PASS
            auth_pass openstack123
        }
        virtual_ipaddress {
            192.168.100.200/24 dev ens18
        }
    }
    EOF
    ```
    
    설정 적용:
    
    ```jsx
    sudo systemctl restart haproxy
    sudo systemctl enable haproxy
    sudo systemctl restart keepalived
    sudo systemctl enable keepalived
    
    # VIP 붙었는지 확인
    ip addr show ens18 | grep 192.168.100.200
    ```
    
    마지막 줄에 `192.168.100.200` 보이면 성공
    
    ### Step 2: MariaDB Galera 설치
    
    ```jsx
    # ct01, ct02, ct03 전부 동일
    sudo apt install -y mariadb-server python3-pymysql
    ```
    
    ### Step 3: Galera 설정 파일 작성
    
    ct01 (192.168.100.202):
    
    ```jsx
    sudo tee /etc/mysql/mariadb.conf.d/99-galera.cnf <<'EOF'
    [mysqld]
    binlog_format=ROW
    default-storage-engine=innodb
    innodb_autoinc_lock_mode=2
    bind-address=0.0.0.0
    
    wsrep_on=ON
    wsrep_provider=/usr/lib/galera/libgalera_smm.so
    wsrep_cluster_name="openstack_galera"
    wsrep_cluster_address="gcomm://192.168.100.202,192.168.100.203,192.168.100.204"
    wsrep_node_address="192.168.100.202"
    wsrep_node_name="openstack-ct01"
    wsrep_sst_method=rsync
    EOF
    ```
    
    ct02 (192.168.100.203):
    
    ```jsx
    sudo tee /etc/mysql/mariadb.conf.d/99-galera.cnf <<'EOF'
    [mysqld]
    binlog_format=ROW
    default-storage-engine=innodb
    innodb_autoinc_lock_mode=2
    bind-address=0.0.0.0
    
    wsrep_on=ON
    wsrep_provider=/usr/lib/galera/libgalera_smm.so
    wsrep_cluster_name="openstack_galera"
    wsrep_cluster_address="gcomm://192.168.100.202,192.168.100.203,192.168.100.204"
    wsrep_node_address="192.168.100.203"
    wsrep_node_name="openstack-ct02"
    wsrep_sst_method=rsync
    EOF
    ```
    
    ct03 (192.168.100.204):
    
    ```jsx
    sudo tee /etc/mysql/mariadb.conf.d/99-galera.cnf <<'EOF'
    [mysqld]
    binlog_format=ROW
    default-storage-engine=innodb
    innodb_autoinc_lock_mode=2
    bind-address=0.0.0.0
    
    wsrep_on=ON
    wsrep_provider=/usr/lib/galera/libgalera_smm.so
    wsrep_cluster_name="openstack_galera"
    wsrep_cluster_address="gcomm://192.168.100.202,192.168.100.203,192.168.100.204"
    wsrep_node_address="192.168.100.204"
    wsrep_node_name="openstack-ct03"
    wsrep_sst_method=rsync
    EOF
    ```
    
    ### Step 4: bootstrap 실행
    
    ```jsx
    # ct01에서
    sudo systemctl stop mariadb
    sudo galera_new_cluster
    ```
    
    오류 없이 프롬프트 돌아오면:
    
    ```jsx
    sudo mysql -u root -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
    ```
    
    `Value = 1` 나오면 성공
    
    ct02, ct03 순서대로 합류
    
    ```jsx
    # ct02에서
    sudo systemctl restart mariadb
    ```
    
    ct02 완료되면 ct01에서 확인:
    
    ```jsx
    # ct01에서
    sudo mysql -u root -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
    ```
    
    `Value = 2` 나오면 ct03도 같은 방식으로 진행:
    
    ```jsx
    
    # ct03에서
    sudo systemctl restart mariadb
    ```
    
    `Value = 3` 나오면 Galera 클러스터 완성
    
    ### Step 5: RabbitMQ 설치
    
    ct01, ct02, ct03 **3개 탭 동시에** 설치:
    
    ```jsx
    sudo apt install -y rabbitmq-server
    ```
    
    ### Step 6: Erlang 쿠키 동기화
    
    ct01에서 쿠키 값 확인:
    
    ```jsx
    # ct01에서
    sudo cat /var/lib/rabbitmq/.erlang.cookie
    ```
    
     ct02, ct03에 동일한 쿠키 복사:
    
    ```jsx
    # ct02, ct03 둘 다 동일하게 실행
    sudo systemctl stop rabbitmq-server
    echo '${확인한 쿠키값}' | sudo tee /var/lib/rabbitmq/.erlang.cookie
    sudo chmod 400 /var/lib/rabbitmq/.erlang.cookie
    sudo chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
    sudo systemctl start rabbitmq-server
    ```
    
    ct02, ct03을 ct01 클러스터에 합류시켜.
    
    **ct02에서:**
    
    ```jsx
    sudo rabbitmqctl stop_app
    sudo rabbitmqctl reset
    sudo rabbitmqctl join_cluster rabbit@openstack-ct01
    sudo rabbitmqctl start_app
    ```
    
    완료되면 **ct03에서도 동일하게:**
    
    ```jsx
    sudo rabbitmqctl stop_app
    sudo rabbitmqctl reset
    sudo rabbitmqctl join_cluster rabbit@openstack-ct01
    sudo rabbitmqctl start_app
    ```
    
    - rabbitmq 오류 메세지
        
        ```jsx
        12:27:40.547 [error] Failed to create a tracked connection table for node :"rabbit@openstack-ct03": {:node_not_running, :"rabbit@openstack-ct03"}
        
        12:27:40.548 [error] Failed to create a per-vhost tracked connection table for node :"rabbit@openstack-ct03": {:node_not_running, :"rabbit@openstack-ct03"}
        
        12:27:40.548 [error] Failed to create a per-user tracked connection table for node :"rabbit@openstack-ct03": {:node_not_running, :"rabbit@openstack-ct03"}
        ```
        
        **`feature_flags` 파일 write 실패 경고**는 ct02가 이전에 standalone으로 한번 실행됐다가 reset 됐을 때 feature flags 상태 파일이 정상적으로 안 닫힌 거야. 클러스터 합류하면서 ct01 기준으로 덮어쓰니까 무시해도 돼.
        
        **`Failed to create a tracked connection table`** 에러는 `join_cluster` 명령 시점에 ct02 앱이 `stop_app` 상태라서 테이블 생성을 못한 거야. `start_app` 하면 ct01에서 테이블 동기화해서 자동으로 해결돼 — 실제로 `cluster_status` 에서 3노드 다 뜬 게 그 증거야.
        
    
    둘 다 되면 ct01에서 확인:
    
    ```jsx
    sudo rabbitmqctl cluster_status | grep -A5 "Running Nodes"
    ```
    
    `rabbit@openstack-ct01`, `rabbit@openstack-ct02`, `rabbit@openstack-ct03` 3개 다 보이면 성공
    
    ### Step 7: OpenStack DB 생성
    
    ct01에서 OpenStack DB 전부 생성:
    
    ```jsx
    sudo mysql -u root <<'EOF'
    CREATE DATABASE keystone;
    CREATE DATABASE glance;
    CREATE DATABASE nova;
    CREATE DATABASE nova_api;
    CREATE DATABASE nova_cell0;
    CREATE DATABASE neutron;
    CREATE DATABASE cinder;
    CREATE DATABASE placement;
    CREATE DATABASE octavia;
    
    GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'keystonepass';
    GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'glancepass';
    GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'novapass';
    GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'novapass';
    GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'novapass';
    GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'neutronpass';
    GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'cinderpass';
    GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY 'placementpass';
    GRANT ALL PRIVILEGES ON octavia.* TO 'octavia'@'%' IDENTIFIED BY 'octaviapass';
    
    FLUSH PRIVILEGES;
    EOF
    ```
    
    완료되면 확인:
    
    ```jsx
    sudo mysql -u root -e "SHOW DATABASES;"
    ```
    

---

### Phase 2 — Identity · Image (ct01~03)

**목표:** Keystone 토큰 발급, Glance 이미지 업로드까지 동작 확인.

### Keystone

1. `apt install keystone` (3대 모두)
2. `/etc/keystone/keystone.conf` — DB 연결(VIP), memcached, fernet 설정
3. ct01에서 `keystone-manage db_sync`, `keystone-manage fernet_setup`, `keystone-manage bootstrap`
4. fernet 키를 ct02, ct03에 복사 + 권한 설정
5. Apache2 WSGI 설정 (`keystone-wsgi-public`) 3대 모두 활성화
6. 관리자 `openrc` 파일 생성 (`OS_AUTH_URL=http://192.168.100.200:5000/v3`)
7. 서비스 카탈로그에 각 서비스 endpoint 등록 (region=RegionOne)

### Glance

1. `apt install glance` (ct01~03)
2. `/etc/glance/glance-api.conf` — DB, MQ, Keystone 인증 설정
3. ct01에서 `glance-manage db_sync`
4. glance-api 서비스 3대 활성화
5. cirros 테스트 이미지 업로드 → `openstack image list` 확인

> ✅ 검증: `openstack token issue` 성공, `openstack image list` 응답
> 

- 실제 작업
    
    ### Step 1: Keystone 설치
    
    ct01, ct02, ct03 **3개 탭 동시에** Keystone 설치:
    
    ```jsx
    sudo apt install -y keystone python3-openstackclient
    ```
    
    ### Step 2: keystone.conf 설정
    
    ct01, ct02, ct03 **3대 전부 동일하게** keystone.conf 설정:
    
    ```jsx
    sudo tee /etc/keystone/keystone.conf <<'EOF'
    [DEFAULT]
    log_dir = /var/log/keystone
    
    [database]
    connection = mysql+pymysql://keystone:keystonepass@192.168.100.202/keystone
    
    [token]
    provider = fernet
    
    [cache]
    enabled = true
    backend = dogpile.cache.memcached
    memcache_servers = 192.168.100.202:11211,192.168.100.203:11211,192.168.100.204:11211
    EOF
    ```
    
    ### Step 3: memcached 설치
    
    ct01, ct02, ct03 **3대 동시에** memcached 설치:
    
    ```jsx
    sudo apt install -y memcached python3-memcache
    ```
    
    설치 완료되면 각 노드에서 **자기 IP로** 바인딩 설정:
    
    **ct01:**
    
    ```jsx
    sudo sed -i 's/127.0.0.1/192.168.100.202/' /etc/memcached.conf
    sudo systemctl restart memcached
    sudo systemctl enable memcached
    ```
    
    **ct02:**
    
    ```jsx
    sudo sed -i 's/127.0.0.1/192.168.100.203/' /etc/memcached.conf
    sudo systemctl restart memcached
    sudo systemctl enable memcached
    ```
    
    **ct03:**
    
    ```jsx
    sudo sed -i 's/127.0.0.1/192.168.100.204/' /etc/memcached.conf
    sudo systemctl restart memcached
    sudo systemctl enable memcached
    ```
    
    ### Step 4: DB sync 진행
    
    **ct01에서만** DB sync하고 fernet 키 생성:
    
    ```jsx
    # ct01에서만
    sudo keystone-manage db_sync
    sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
    sudo keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
    ```
    
    ### Step 5: Keystone 부트스트랩
    
    **ct01에서:**
    
    ```jsx
    sudo keystone-manage bootstrap --bootstrap-password adminpass \
      --bootstrap-admin-url http://192.168.100.200:5000/v3/ \
      --bootstrap-internal-url http://192.168.100.200:5000/v3/ \
      --bootstrap-public-url http://192.168.100.200:5000/v3/ \
      --bootstrap-region-id RegionOne
    ```
    
    ### Step 6: Apache2 WSGI 설정
    
    ct01, ct02, ct03 **3대 동시에:**
    
    ```jsx
    sudo apt install -y apache2 libapache2-mod-wsgi-py3
    ```
    
    ct01, ct02, ct03 **3대 동시에** Apache 설정:
    
    ```jsx
    sudo tee /etc/apache2/sites-available/keystone.conf <<'EOF'
    Listen 5000
    
    <VirtualHost *:5000>
        WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
        WSGIProcessGroup keystone-public
        WSGIScriptAlias / /usr/bin/keystone-wsgi-public
        WSGIApplicationGroup %{GLOBAL}
        WSGIPassAuthorization On
        ErrorLogFormat "%{cu}t %M"
        ErrorLog /var/log/apache2/keystone.log
        CustomLog /var/log/apache2/keystone_access.log combined
    
        <Directory /usr/bin>
            Require all granted
        </Directory>
    </VirtualHost>
    EOF
    
    sudo a2ensite keystone
    sudo a2dissite 000-default
    sudo systemctl restart apache2
    sudo systemctl enable apache2
    ```
    
    fernet 키를 ct02, ct03에 복사. ct01에서:
    
    ```jsx
    # ct02로 복사
    sudo scp /etc/keystone/fernet-keys/0 ubuntu@192.168.100.203:/tmp/fernet-key-0
    sudo scp /etc/keystone/fernet-keys/1 ubuntu@192.168.100.203:/tmp/fernet-key-1
    sudo scp /etc/keystone/credential-keys/0 ubuntu@192.168.100.203:/tmp/credential-key-0
    sudo scp /etc/keystone/credential-keys/1 ubuntu@192.168.100.203:/tmp/credential-key-1
    
    # ct03으로 복사
    sudo scp /etc/keystone/fernet-keys/0 ubuntu@192.168.100.204:/tmp/fernet-key-0
    sudo scp /etc/keystone/fernet-keys/1 ubuntu@192.168.100.204:/tmp/fernet-key-1
    sudo scp /etc/keystone/credential-keys/0 ubuntu@192.168.100.204:/tmp/credential-key-0
    sudo scp /etc/keystone/credential-keys/1 ubuntu@192.168.100.204:/tmp/credential-key-1
    ```
    
    완료되면 **ct02, ct03에서:**
    
    ```bash
    sudo mv /tmp/fernet-key-0 /etc/keystone/fernet-keys/0
    sudo mv /tmp/fernet-key-1 /etc/keystone/fernet-keys/1
    sudo mv /tmp/credential-key-0 /etc/keystone/credential-keys/0
    sudo mv /tmp/credential-key-1 /etc/keystone/credential-keys/1
    sudo chown keystone:keystone /etc/keystone/fernet-keys/0
    sudo chown keystone:keystone /etc/keystone/fernet-keys/1
    sudo chown keystone:keystone /etc/keystone/credential-keys/0
    sudo chown keystone:keystone /etc/keystone/credential-keys/1
    sudo chmod 640 /etc/keystone/fernet-keys/0
    sudo chmod 640 /etc/keystone/fernet-keys/1
    sudo chmod 640 /etc/keystone/credential-keys/0
    sudo chmod 640 /etc/keystone/credential-keys/1
    sudo systemctl restart apache2
    ```
    
    ### Step 7:  openrc 파일 생성 및 Keystone 동작 확인
    
    **ct01에서:**
    
    ```jsx
    tee ~/openrc <<'EOF'
    export OS_PROJECT_DOMAIN_NAME=Default
    export OS_USER_DOMAIN_NAME=Default
    export OS_PROJECT_NAME=admin
    export OS_USERNAME=admin
    export OS_PASSWORD=adminpass
    export OS_AUTH_URL=http://192.168.100.200:5000/v3
    export OS_IDENTITY_API_VERSION=3
    export OS_IMAGE_API_VERSION=2
    EOF
    
    source ~/openrc
    ```
    
    토큰 발급 테스트:
    
    ```jsx
    openstack token issue
    ```
    
    토큰 확인:
    
    ```jsx
    +------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    | Field      | Value                                                                                                                                                                                   |
    +------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    | expires    | 2026-06-18T14:19:03+0000                                                                                                                                                                |
    | id         | gAAAAABqM_BHRI7UAS78oci1Hi8baSCXR7run0Tf8rvoJO4T4g0tLiFd85H0QFEmEMf9G9fMnuRKUrzrEPCl2ek4cXlsFOyF7MSdZkfCBlvxGsFKXD6pmWN1LcxOEky92S44oNMdj6opDQIZw1TxqV9VV6JjRINA_2arFwPXz3a9Rx0vU9H-DOo |
    | project_id | 158c14d88b0c46f399fb66b4d5f713af                                                                                                                                                        |
    | user_id    | 53599cb4f696431f8bbe15e533488545                                                                                                                                                        |
    +------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    ```
    
    ### Step 8: Galnce 설치
    
    ct01, ct02, ct03 **3대 동시에** Glance 설치:
    
    ```jsx
    sudo apt install -y glance
    ```
    
    ct01, ct02, ct03 **3대 동일하게** glance.conf 설정:
    
    ```jsx
    sudo tee /etc/glance/glance-api.conf <<'EOF'
    [DEFAULT]
    log_dir = /var/log/glance
    
    [database]
    connection = mysql+pymysql://glance:glancepass@192.168.100.202/glance
    
    [keystone_authtoken]
    www_authenticate_uri = http://192.168.100.200:5000
    auth_url = http://192.168.100.200:5000
    memcached_servers = 192.168.100.202:11211,192.168.100.203:11211,192.168.100.204:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = glance
    password = glancepass
    
    [paste_deploy]
    flavor = keystone
    
    [glance_store]
    stores = file,http
    default_store = file
    filesystem_store_datadir = /var/lib/glance/images/
    EOF
    ```
    
    ct01에서만 Glance 서비스 계정 생성 및 DB sync 진행:
    
    ```jsx
    source ~/openrc
    
    # 서비스 계정 생성
    openstack user create --domain default --password glancepass glance
    openstack project create --domain default --description "Service Project" service
    openstack role add --project service --user glance admin
    openstack service create --name glance --description "OpenStack Image" image
    
    # 엔드포인트 등록
    openstack endpoint create --region RegionOne image public http://192.168.100.200:9292
    openstack endpoint create --region RegionOne image internal http://192.168.100.200:9292
    openstack endpoint create --region RegionOne image admin http://192.168.100.200:9292
    
    # DB sync
    sudo glance-manage db_sync
    ```
    
    ct01, ct02, ct03 **3대 동시에** glance-api 서비스 활성화:
    
    ```bash
    sudo systemctl enable glance-api
    sudo systemctl start glance-api
    sudo systemctl status glance-api | tail -3
    ```
    
    ### Step 9: cirros 테스트 이미지 업로드 확인
    
    ct01에서:
    
    ```bash
    wget https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img
    
    openstack image create "cirros-0.6.2" \
      --file cirros-0.6.2-x86_64-disk.img \
      --disk-format qcow2 \
      --container-format bare \
      --shared
    
    openstack image list
    ```
    

---

### Phase 3 — Compute · Network (ct01~03 + cp01~02)

**목표:** VM 인스턴스 기동 가능한 상태까지. LinuxBridge+VXLAN Self-Service 구성.

### Placement (ct01~03)

1. `apt install placement-api`
2. `/etc/placement/placement.conf` 설정
3. `placement-manage db sync`
4. Apache2 WSGI 설정

### Nova

1. ct01~03: `apt install nova-api nova-conductor nova-scheduler nova-novncproxy`
2. `/etc/nova/nova.conf` — DB(cell0/cell1), MQ, Keystone, Placement, VNC 설정 (VIP 기준)
3. ct01에서 `nova-manage api_db sync`, `nova-manage cell_v2 map_cell0`, `nova-manage db sync`
4. cell1 생성: `nova-manage cell_v2 create_cell --name=cell1`
5. nova 서비스들 3대 활성화
6. cp01~02: `apt install nova-compute`
7. cp01~02 `/etc/nova/nova.conf` — `[libvirt] virt_type = kvm`, `cpu_mode = host-passthrough`
8. `nova-manage cell_v2 discover_hosts` → Compute 노드 등록 확인

### Neutron (LinuxBridge + VXLAN)

1. ct01~03: `apt install neutron-server neutron-plugin-ml2`
2. `/etc/neutron/neutron.conf` — MQ, Keystone 설정
3. `/etc/neutron/plugins/ml2/ml2_conf.ini` — `type_drivers = flat,vxlan`, `mechanism_drivers = linuxbridge,l2population`
4. `/etc/neutron/plugins/ml2/linuxbridge_agent.ini` — `physical_interface_mappings = provider:ens19`, `vxlan local_ip = 192.168.100.20X`
5. ct01~03: `neutron-server` 서비스 활성화
6. cp01~02: `apt install neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent neutron-l3-agent`
7. cp01~02 linuxbridge-agent, l3-agent, dhcp-agent 설정 후 활성화
8. `neutron-manage db upgrade`
9. Keystone endpoint 등록

> ✅ 검증: `openstack network agent list` — ct01~03 서버, cp01~02 linuxbridge/dhcp/l3 에이전트 전부 `:-)` 상태
> 

- 실제 작업
    
    ### Step 1: Placement 설치
    
    ct01, ct02, ct03 **3대 동시에** Placement 설치:
    
    ```bash
    sudo apt install -y placement-api
    ```
    
    ### Step 2: placement.conf 설정
    
    ct01, ct02, ct03 **3대 동일하게** placement.conf 설정:
    
    ```bash
    sudo tee /etc/placement/placement.conf <<'EOF'
    [DEFAULT]
    log_dir = /var/log/placement
    
    [api]
    auth_strategy = keystone
    
    [keystone_authtoken]
    auth_url = http://192.168.100.200:5000/v3
    memcached_servers = 192.168.100.202:11211,192.168.100.203:11211,192.168.100.204:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = placement
    password = placementpass
    
    [placement_database]
    connection = mysql+pymysql://placement:placementpass@192.168.100.202/placement
    EOF
    ```
    
    ct01에서만 서비스 계정 생성 및 DB sync 진행:
    
    ```bash
    source ~/openrc
    
    # 서비스 계정 생성
    openstack user create --domain default --password placementpass placement
    openstack role add --project service --user placement admin
    openstack service create --name placement --description "Placement API" placement
    
    # 엔드포인트 등록
    openstack endpoint create --region RegionOne placement public http://192.168.100.200:8778
    openstack endpoint create --region RegionOne placement internal http://192.168.100.200:8778
    openstack endpoint create --region RegionOne placement admin http://192.168.100.200:8778
    
    # DB sync
    sudo placement-manage db sync
    ```
    
    ct01, ct02, ct03 **3대에** Apache 설정 적용(자동생성):
    
    ```bash
    sudo systemctl restart apache2
    ```
    
    완료되면 ct01에서 확인:
    
    ```bash
    curl http://192.168.100.200:8778/
    ```
    
    ### Step 3: Nova 설치
    
    ct01, ct02, ct03 **3대에:**
    
    ```bash
    sudo apt install -y nova-api nova-conductor nova-scheduler nova-novncproxy
    ```
    
    ### Step 4: nova.conf 설정:
    
    ct01, ct02, ct03 **3대:**
    
    - `MY_IP_HERE` 부분을 각 노드 IP로 바꿔야 합니다:
    **ct01:**
        
        `sudo sed -i 's/MY_IP_HERE/192.168.100.202/g' /etc/nova/nova.conf`
        
        **ct02:**
        
        `sudo sed -i 's/MY_IP_HERE/192.168.100.203/g' /etc/nova/nova.conf`
        
        **ct03:**
        
        `sudo sed -i 's/MY_IP_HERE/192.168.100.204/g' /etc/nova/nova.conf`
        
    
    ```bash
    sudo tee /etc/nova/nova.conf <<'EOF'
    [DEFAULT]
    log_dir = /var/log/nova
    transport_url = rabbit://openstack:openstack@192.168.100.202:5672,openstack:openstack@192.168.100.203:5672,openstack:openstack@192.168.100.204:5672
    my_ip = MY_IP_HERE
    
    [api]
    auth_strategy = keystone
    
    [keystone_authtoken]
    www_authenticate_uri = http://192.168.100.200:5000/v3
    auth_url = http://192.168.100.200:5000/v3
    memcached_servers = 192.168.100.202:11211,192.168.100.203:11211,192.168.100.204:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = nova
    password = novapass
    
    [database]
    connection = mysql+pymysql://nova:novapass@192.168.100.202/nova
    
    [api_database]
    connection = mysql+pymysql://nova:novapass@192.168.100.202/nova_api
    
    [placement]
    region_name = RegionOne
    project_domain_name = Default
    project_name = service
    auth_type = password
    user_domain_name = Default
    auth_url = http://192.168.100.200:5000/v3
    username = placement
    password = placementpass
    
    [glance]
    api_servers = http://192.168.100.200:9292
    
    [oslo_concurrency]
    lock_path = /var/lib/nova/tmp
    
    [vnc]
    enabled = true
    server_listen = 0.0.0.0
    server_proxyclient_address = MY_IP_HERE
    EOF
    ```
    
    RabbitMQ에 openstack 유저 생성. ct01에서:
    
    ```bash
    # RabbitMQ openstack 유저 생성 및 권한 설정
    sudo rabbitmqctl add_user openstack openstack
    sudo rabbitmqctl set_user_tags openstack administrator
    sudo rabbitmqctl set_permissions -p / openstack ".*" ".*" ".*"
    ```
    
    ct01에서만 DB sync 및 서비스 계정 생성:
    
    ```bash
    source ~/openrc
    
    # 서비스 계정 생성
    openstack user create --domain default --password novapass nova
    openstack role add --project service --user nova admin
    openstack service create --name nova --description "OpenStack Compute" compute
    
    # 엔드포인트 등록
    openstack endpoint create --region RegionOne compute public http://192.168.100.200:8774/v2.1
    openstack endpoint create --region RegionOne compute internal http://192.168.100.200:8774/v2.1
    openstack endpoint create --region RegionOne compute admin http://192.168.100.200:8774/v2.1
    
    # DB sync
    sudo nova-manage api_db sync
    sudo nova-manage cell_v2 map_cell0
    sudo nova-manage db sync
    sudo nova-manage cell_v2 create_cell --name=cell1 --verbose
    ```
    
    ct01, ct02, ct03 **3대** Nova 서비스 시작:
    
    ```bash
    sudo systemctl enable nova-api nova-conductor nova-scheduler nova-novncproxy
    sudo systemctl start nova-api nova-conductor nova-scheduler nova-novncproxy
    sudo systemctl status nova-api | tail -3
    ```
    
    ### Step 5: CP01, CP02에 Nova Compute 설치
    
    cp01, cp02 **2대에:**
    
    ```bash
    sudo apt install -y nova-compute
    ```
    
    ### Step 6: CP01, CP02에 nova.conf 설정
    
    cp01, cp02 **2대에:**
    
    ```bash
    sudo tee /etc/nova/nova.conf <<'EOF'
    [DEFAULT]
    log_dir = /var/log/nova
    transport_url = rabbit://openstack:openstack@192.168.100.202:5672,openstack:openstack@192.168.100.203:5672,openstack:openstack@192.168.100.204:5672
    my_ip = MY_IP_HERE
    instances_path = /var/lib/nova/instances
    
    [api]
    auth_strategy = keystone
    
    [keystone_authtoken]
    www_authenticate_uri = http://192.168.100.200:5000/v3
    auth_url = http://192.168.100.200:5000/v3
    memcached_servers = 192.168.100.202:11211,192.168.100.203:11211,192.168.100.204:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = nova
    password = novapass
    
    [placement]
    region_name = RegionOne
    project_domain_name = Default
    project_name = service
    auth_type = password
    user_domain_name = Default
    auth_url = http://192.168.100.200:5000/v3
    username = placement
    password = placementpass
    
    [glance]
    api_servers = http://192.168.100.200:9292
    
    [oslo_concurrency]
    lock_path = /var/lib/nova/tmp
    
    [vnc]
    enabled = true
    server_listen = 0.0.0.0
    server_proxyclient_address = MY_IP_HERE
    novncproxy_base_url = http://192.168.100.200:6080/vnc_auto.html
    
    [libvirt]
    virt_type = kvm
    cpu_mode = host-passthrough
    
    [service_user]
    send_service_user_token = true
    auth_url = http://192.168.100.200:5000/v3
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = nova
    password = novapass
    EOF
    ```
    
    - `MY_IP_HERE` 부분을 각 노드 IP로 바꿔야 합니다:
    **cp01:**
        
        `sudo sed -i 's/MY_IP_HERE/192.168.100.205/g' /etc/nova/nova.conf`
        
        **cp02:**
        
        `sudo sed -i 's/MY_IP_HERE/192.168.100.206/g' /etc/nova/nova.conf`
        
    
    cp01, cp02 **2대에** nova-compute 서비스 시작:
    
    ```bash
    # cp01, cp02 2대에 nova-compute 설치 후 디렉토리 먼저 생성
    sudo mkdir -p /var/lib/nova/instances
    sudo chown nova:nova /var/lib/nova/instances
    
    sudo systemctl enable nova-compute
    sudo systemctl start nova-compute
    sudo systemctl status nova-compute | tail -3
    ```
    
     ct01에서 Compute 노드 등록 확인:
    
    ```bash
    sudo nova-manage cell_v2 discover_hosts --verbose
    openstack compute service list
    ```
    
    모든 서비스가 `enabled` / `up` 상태 확인.
    
    - nova-conductor 3대 (ct01~03) ✅
    - nova-scheduler 3대 (ct01~03) ✅
    - nova-compute 2대 (cp01~02) ✅
    
    ### Step 7: Neutron 설치
    
    ct01, ct02, ct03 **3대에:**
    
    ```bash
    sudo apt install -y neutron-server neutron-plugin-ml2 \
      neutron-linuxbridge-agent neutron-dhcp-agent \
      neutron-metadata-agent neutron-l3-agent
    ```
    
    ct01, ct02, ct03 **3대에** neutron.conf 설정:
    
    ```bash
    sudo tee /etc/neutron/neutron.conf <<'EOF'
    [DEFAULT]
    core_plugin = ml2
    service_plugins = router
    transport_url = rabbit://openstack:openstack@192.168.100.202:5672,openstack:openstack@192.168.100.203:5672,openstack:openstack@192.168.100.204:5672
    auth_strategy = keystone
    notify_nova_on_port_status_changes = true
    notify_nova_on_port_data_changes = true
    
    [database]
    connection = mysql+pymysql://neutron:neutronpass@192.168.100.202/neutron
    
    [keystone_authtoken]
    www_authenticate_uri = http://192.168.100.200:5000
    auth_url = http://192.168.100.200:5000
    memcached_servers = 192.168.100.202:11211,192.168.100.203:11211,192.168.100.204:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = neutron
    password = neutronpass
    
    [nova]
    auth_url = http://192.168.100.200:5000
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    region_name = RegionOne
    project_name = service
    username = nova
    password = novapass
    
    [oslo_concurrency]
    lock_path = /var/lib/neutron/tmp
    EOF
    ```
    
    ct01, ct02, ct03 **3대 동일하게** ML2 설정:
    
    ```bash
    sudo tee /etc/neutron/plugins/ml2/ml2_conf.ini <<'EOF'
    [ml2]
    type_drivers = flat,vlan,vxlan
    tenant_network_types = vxlan
    mechanism_drivers = linuxbridge,l2population
    extension_drivers = port_security
    
    [ml2_type_flat]
    flat_networks = provider
    
    [ml2_type_vxlan]
    vni_ranges = 1:1000
    
    [securitygroup]
    enable_ipset = true
    EOF
    ```
    
     LinuxBridge agent 설정:
    
    ct01:
    
    ```bash
    sudo tee /etc/neutron/plugins/ml2/linuxbridge_agent.ini <<'EOF'
    [linux_bridge]
    physical_interface_mappings = provider:ens19
    
    [vxlan]
    enable_vxlan = true
    local_ip = 192.168.100.202
    l2_population = true
    
    [securitygroup]
    enable_security_group = true
    firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
    EOF
    ```
    
    ct02:
    
    ```bash
    sudo tee /etc/neutron/plugins/ml2/linuxbridge_agent.ini <<'EOF'
    [linux_bridge]
    physical_interface_mappings = provider:ens19
    
    [vxlan]
    enable_vxlan = true
    local_ip = 192.168.100.203
    l2_population = true
    
    [securitygroup]
    enable_security_group = true
    firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
    EOF
    ```
    
    ct03:
    
    ```bash
    sudo tee /etc/neutron/plugins/ml2/linuxbridge_agent.ini <<'EOF'
    [linux_bridge]
    physical_interface_mappings = provider:ens19
    
    [vxlan]
    enable_vxlan = true
    local_ip = 192.168.100.204
    l2_population = true
    
    [securitygroup]
    enable_security_group = true
    firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
    EOF
    ```
    
    ct01, ct02, ct03 **3대 동일하게** L3 agent 설정:
    
    ```bash
    sudo tee /etc/neutron/l3_agent.ini <<'EOF'
    [DEFAULT]
    interface_driver = linuxbridge
    EOF
    ```
    
    DHCP agent 설정:
    
    ```bash
    sudo tee /etc/neutron/dhcp_agent.ini <<'EOF'
    [DEFAULT]
    interface_driver = linuxbridge
    dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
    enable_isolated_metadata = true
    EOF
    ```
    
    metadata agent 설정:
    
    ```bash
    sudo tee /etc/neutron/metadata_agent.ini <<'EOF'
    [DEFAULT]
    nova_metadata_host = 192.168.100.200
    metadata_proxy_shared_secret = metasecret
    EOF
    ```
    
    ct01에서만 서비스 계정 생성 및 DB sync 진행:
    
    ```bash
    source ~/openrc
    
    # 서비스 계정 생성
    openstack user create --domain default --password neutronpass neutron
    openstack role add --project service --user neutron admin
    openstack service create --name neutron --description "OpenStack Networking" network
    
    # 엔드포인트 등록
    openstack endpoint create --region RegionOne network public http://192.168.100.200:9696
    openstack endpoint create --region RegionOne network internal http://192.168.100.200:9696
    openstack endpoint create --region RegionOne network admin http://192.168.100.200:9696
    
    # DB sync
    sudo neutron-db-manage --config-file /etc/neutron/neutron.conf \
      --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head
    ```
    
    Nova에 Neutron 연동 설정 추가 필요. ct01, ct02, ct03 **3대 nova.conf에** 추가:
    
    ```bash
    sudo tee -a /etc/nova/nova.conf <<'EOF'
    
    [neutron]
    auth_url = http://192.168.100.200:5000
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    region_name = RegionOne
    project_name = service
    username = neutron
    password = neutronpass
    service_metadata_proxy = true
    metadata_proxy_shared_secret = metasecret
    EOF
    ```
    
    ct01, ct02, ct03 **3대에** Neutron 서비스 시작:
    
    ```bash
    sudo systemctl enable neutron-server neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent neutron-l3-agent
    sudo systemctl start neutron-server neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent neutron-l3-agent
    sudo systemctl status neutron-server | tail -3
    ```
    
    cp01, cp02에 Neutron linuxbridge agent 설치:
    
    ```bash
    # cp01, cp02 동시에
    sudo apt install -y neutron-linuxbridge-agent
    ```
    
    cp01, cp02 **각각** linuxbridge_agent.ini 설정:
    
    cp01:
    
    ```bash
    sudo tee /etc/neutron/plugins/ml2/linuxbridge_agent.ini <<'EOF'
    [linux_bridge]
    physical_interface_mappings = provider:ens19
    
    [vxlan]
    enable_vxlan = true
    local_ip = 192.168.100.205
    l2_population = true
    
    [securitygroup]
    enable_security_group = true
    firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
    EOF
    ```
    
    cp02:
    
    ```bash
    sudo tee /etc/neutron/plugins/ml2/linuxbridge_agent.ini <<'EOF'
    [linux_bridge]
    physical_interface_mappings = provider:ens19
    
    [vxlan]
    enable_vxlan = true
    local_ip = 192.168.100.206
    l2_population = true
    
    [securitygroup]
    enable_security_group = true
    firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
    EOF
    ```
    
    cp01, cp02 **neutron.conf** 설정:
    
    ```bash
    sudo tee /etc/neutron/neutron.conf <<'EOF'
    [DEFAULT]
    transport_url = rabbit://openstack:openstack@192.168.100.202:5672,openstack:openstack@192.168.100.203:5672,openstack:openstack@192.168.100.204:5672
    auth_strategy = keystone
    
    [keystone_authtoken]
    www_authenticate_uri = http://192.168.100.200:5000
    auth_url = http://192.168.100.200:5000
    memcached_servers = 192.168.100.202:11211,192.168.100.203:11211,192.168.100.204:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = neutron
    password = neutronpass
    
    [oslo_concurrency]
    lock_path = /var/lib/neutron/tmp
    EOF
    ```
    
    cp01, cp02 **2대 모두:**
    
    ```bash
    sudo tee /etc/systemd/system/neutron-linuxbridge-agent.service <<'EOF'
    [Unit]
    Description=Openstack Neutron Linux Bridge Agent
    After=network.target
    
    [Service]
    User=neutron
    Group=neutron
    WorkingDirectory=/var/lib/neutron
    ExecStartPre=/bin/mkdir -p /var/lock/neutron /var/log/neutron /var/lib/neutron
    ExecStartPre=/bin/chown neutron:neutron /var/lock/neutron /var/log/neutron /var/lib/neutron
    ExecStartPre=-/sbin/modprobe br_netfilter
    ExecStart=/usr/bin/neutron-linuxbridge-agent --config-file=/etc/neutron/neutron.conf --config-file=/etc/neutron/plugins/ml2/linuxbridge_agent.ini
    Restart=on-failure
    LimitNOFILE=65535
    
    [Install]
    WantedBy=multi-user.target
    EOF
    
    sudo systemctl daemon-reload
    ```
    
    cp01, cp02 **2대 모두** 생성:
    
    ```bash
    sudo tee /etc/sudoers.d/neutron-rootwrap <<'EOF'
    Defaults:neutron !requiretty
    neutron ALL=(root) NOPASSWD: /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf *
    neutron ALL=(root) NOPASSWD: /usr/bin/neutron-rootwrap-daemon /etc/neutron/rootwrap.conf
    neutron ALL=(root) NOPASSWD: /usr/bin/privsep-helper *
    EOF
    
    sudo chmod 440 /etc/sudoers.d/neutron-rootwrap
    ```
    
    완료 후 서비스 시작:
    
    ```bash
    sudo systemctl enable neutron-linuxbridge-agent
    sudo systemctl start neutron-linuxbridge-agent
    sudo systemctl status neutron-linuxbridge-agent | tail -3
    ```
    
    ct01~03에도 동일하게 sudoers 파일 추가하고 linuxbridge-agent 재시작:
    
    ```bash
    # ct01, ct02, ct03 3대 모두
    sudo tee /etc/sudoers.d/neutron-rootwrap <<'EOF'
    Defaults:neutron !requiretty
    neutron ALL=(root) NOPASSWD: /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf *
    neutron ALL=(root) NOPASSWD: /usr/bin/neutron-rootwrap-daemon /etc/neutron/rootwrap.conf
    neutron ALL=(root) NOPASSWD: /usr/bin/privsep-helper *
    EOF
    
    sudo chmod 440 /etc/sudoers.d/neutron-rootwrap
    sudo systemctl restart neutron-linuxbridge-agent
    ```
    
    완료 후 ct01에서 확인:
    
    ```bash
    openstack network agent list | grep "Linux bridge"
    ```
    
    nova 서비스도 재시작 후 최종 확인:
    
    ct01, ct02, ct03 **3대:**
    
    ```bash
    sudo systemctl restart nova-api nova-conductor nova-scheduler
    ```
    
    ct01에서 최종 확인:
    
    ```bash
    openstack network agent list
    ```
    

---

### Phase 4 — Block Storage (ct01~03 + st01)

**목표:** 인스턴스에 Cinder 볼륨 Attach/Detach 성공.

### st01 노드 LVM 준비

1. `lsblk` 로 추가 디스크 확인 (예: `/dev/sdb`)
2. `pvcreate /dev/sdb` → `vgcreate cinder-volumes /dev/sdb`
3. LVM 필터 설정 (`/etc/lvm/lvm.conf` → `filter = [ "a/sdb/", "r/.*/"]`)

### Cinder (ct01~03)

1. `apt install cinder-api cinder-scheduler`
2. `/etc/cinder/cinder.conf` — DB, MQ, Keystone 설정
3. ct01에서 `cinder-manage db sync`
4. cinder-api, cinder-scheduler 3대 활성화
5. Nova에 Cinder 연동 설정 추가 (`nova.conf` → `[cinder]`)

### Cinder-Volume (st01)

1. `apt install cinder-volume tgt`
2. `/etc/cinder/cinder.conf` — `[lvm]` 섹션: `volume_driver = LVMVolumeDriver`, `volume_group = cinder-volumes`, `iscsi_protocol = iscsi`
3. cinder-volume 서비스 활성화

> ✅ 검증: `openstack volume create --size 1 test-vol` → `available` 상태, 인스턴스에 attach 성공
> 
- 실제 작업
    
    ### Step 1: st01에서 디스크 확인 및 LVM 설정
    
    st01에서:
    
    ```bash
    lsblk
    ```
    
    st01에서:
    
    ```bash
    sudo apt install -y lvm2
    sudo pvcreate /dev/sdb
    sudo vgcreate cinder-volumes /dev/sdb
    sudo pvs
    sudo vgs
    ```
    
     LVM 필터 설정 추가:
    
    ```bash
    sudo tee /etc/lvm/lvmlocal.conf <<'EOF'
    devices {
        filter = [ "a/sdb/", "r/.*/"]
    }
    EOF
    
    sudo vgs
    ```
    
    ### Step 2: CT에 Cinder 설치
    
    ct01, ct02, ct03 **3대에** Cinder 설치:
    
    ```bash
    sudo apt install -y cinder-api cinder-scheduler
    ```
    
    ct01, ct02, ct03 **3대에** cinder.conf 설정:
    
    - `MY_IP_HERE` 부분을 각 노드 IP로 바꿔야 합니다:
    **ct01:**
        
        `sudo sed -i 's/MY_IP_HERE/192.168.100.202/' /etc/cinder/cinder.conf`
        
        **ct02:**
        
        `sudo sed -i 's/MY_IP_HERE/192.168.100.203/' /etc/cinder/cinder.conf`
        
        **ct03:**
        
        `sudo sed -i 's/MY_IP_HERE/192.168.100.204/' /etc/cinder/cinder.conf`
        
    
    ```bash
    sudo tee /etc/cinder/cinder.conf <<'EOF'
    [DEFAULT]
    log_dir = /var/log/cinder
    transport_url = rabbit://openstack:openstack@192.168.100.202:5672,openstack:openstack@192.168.100.203:5672,openstack:openstack@192.168.100.204:5672
    auth_strategy = keystone
    my_ip = MY_IP_HERE
    
    [database]
    connection = mysql+pymysql://cinder:cinderpass@192.168.100.202/cinder
    
    [keystone_authtoken]
    www_authenticate_uri = http://192.168.100.200:5000
    auth_url = http://192.168.100.200:5000
    memcached_servers = 192.168.100.202:11211,192.168.100.203:11211,192.168.100.204:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = cinder
    password = cinderpass
    
    [oslo_concurrency]
    lock_path = /var/lib/cinder/tmp
    EOF
    ```
    
    ct01에서만 서비스 계정 생성 및 DB sync 진행:
    
    ```bash
    source ~/openrc
    
    # 서비스 계정 생성
    openstack user create --domain default --password cinderpass cinder
    openstack role add --project service --user cinder admin
    
    # 서비스 및 엔드포인트 등록
    openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
    
    openstack endpoint create --region RegionOne volumev3 public http://192.168.100.200:8776/v3/%\(project_id\)s
    openstack endpoint create --region RegionOne volumev3 internal http://192.168.100.200:8776/v3/%\(project_id\)s
    openstack endpoint create --region RegionOne volumev3 admin http://192.168.100.200:8776/v3/%\(project_id\)s
    
    # DB sync
    sudo cinder-manage db sync
    ```
    
    ct01, ct02, ct03 **3대 cinder-wsgi 활성화 후 Apache 재시작:**
    
    ```bash
    sudo a2enconf cinder-wsgi
    sudo systemctl restart apache2
    sudo systemctl enable cinder-scheduler
    sudo systemctl start cinder-scheduler
    sudo systemctl status cinder-scheduler | tail -3
    ```
    
    ct01, ct02, ct03 **3대에** Cinder 서비스 시작:
    
    ```bash
    sudo systemctl enable cinder-api cinder-scheduler
    sudo systemctl start cinder-api cinder-scheduler
    sudo systemctl status cinder-api | tail -3
    ```
    
    st01에 cinder-volume 설치:
    
    ```bash
    sudo apt install -y cinder-volume tgt
    ```
    
    st01에 cinder.conf 설정:
    
    ```bash
    sudo tee /etc/cinder/cinder.conf <<'EOF'
    [DEFAULT]
    log_dir = /var/log/cinder
    transport_url = rabbit://openstack:openstack@192.168.100.202:5672,openstack:openstack@192.168.100.203:5672,openstack:openstack@192.168.100.204:5672
    auth_strategy = keystone
    my_ip = 192.168.100.207
    enabled_backends = lvm
    glance_api_servers = http://192.168.100.200:9292
    
    [database]
    connection = mysql+pymysql://cinder:cinderpass@192.168.100.202/cinder
    
    [keystone_authtoken]
    www_authenticate_uri = http://192.168.100.200:5000
    auth_url = http://192.168.100.200:5000
    memcached_servers = 192.168.100.202:11211,192.168.100.203:11211,192.168.100.204:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = cinder
    password = cinderpass
    
    [lvm]
    volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
    volume_group = cinder-volumes
    target_protocol = iscsi
    target_helper = tgtadm
    
    [oslo_concurrency]
    lock_path = /var/lib/cinder/tmp
    EOF
    ```
    
    st01에서 cinder-volume 서비스 시작:
    
    ```bash
    sudo systemctl enable cinder-volume tgt
    sudo systemctl start cinder-volume tgt
    sudo systemctl status cinder-volume | tail -3
    ```
    
     ct01에서 최종 확인:
    
    ```bash
    openstack volume service list
    ```
    
    - cinder-scheduler 3대 (ct01~03) ✅
    - cinder-volume 1대 (st01@lvm) ✅
    
    볼륨 생성 테스트:
    
    ```bash
    openstack volume create --size 1 test-vol
    openstack volume list
    ```
    
    테스트 볼륨 삭제:
    
    ```bash
    openstack volume delete test-vol
    ```
    

---

### Phase 5 — Advanced Services (ct01~03 + st01)

**목표:** Octavia (LBaaS), Swift (Object Storage) 추가.

### Octavia

1. `apt install octavia-api octavia-health-manager octavia-housekeeping octavia-worker`
2. Octavia 전용 네트워크/서브넷/Security Group 생성 (amphora 관리망)
3. amphora 이미지 빌드 또는 prebuilt 이미지 다운로드
4. `/etc/octavia/octavia.conf` 설정 — 인증, amphora 설정
5. `octavia-manage db upgrade`
6. 서비스 활성화

### Swift (st01 활용)

1. `apt install swift swift-proxy swift-account swift-container swift-object`
2. Ring 파일 생성 (`swift-ring-builder` — account/container/object ring)
3. `/etc/swift/swift.conf` — `swift_hash_path_suffix`, `swift_hash_path_prefix`
4. `/etc/swift/proxy-server.conf` — Keystone 인증 연동
5. st01에 Object Storage 디렉토리 마운트 및 서비스 활성화
6. Keystone endpoint 등록

> ✅ 검증: `openstack loadbalancer list`, `swift stat`, `openstack object store account show`
> 
- 실제 작업
    
    ### Step 1: Swift 설치
    
    st01에서 디스크 상황 확인:
    
    ```bash
    df -h
    lsblk
    ```
    
     Swift 패키지 설치. ct01, ct02, ct03, st01 **4대에:**
    
    ```bash
    sudo apt install -y swift swift-account swift-container swift-object
    ```
    
    Swift용 파티션 및 파일시스템 설정:
    
    ```bash
    sudo mkfs.xfs /dev/sdc
    sudo mkdir -p /srv/node/sdc
    sudo mount /dev/sdc /srv/node/sdc
    echo '/dev/sdc /srv/node/sdc xfs noatime,nodiratime,nobarrier,logbufs=8 0 2' | sudo tee -a /etc/fstab
    sudo chown -R swift:swift /srv/node
    ```
    
    ct01, ct02, ct03에도 swift-proxy 설치:
    
    ```bash
    # ct01, ct02, ct03 3대 동시에
    sudo apt install -y swift-proxy python3-keystoneclient python3-keystonemiddleware python3-memcache
    ```
    
    ct01에서 Swift 서비스 계정 생성:
    
    ```bash
    source ~/openrc
    
    openstack user create --domain default --password swiftpass swift
    openstack role add --project service --user swift admin
    openstack service create --name swift --description "OpenStack Object Storage" object-store
    
    openstack endpoint create --region RegionOne object-store public http://192.168.100.200:8080/v1/AUTH_%\(project_id\)s
    openstack endpoint create --region RegionOne object-store internal http://192.168.100.200:8080/v1/AUTH_%\(project_id\)s
    openstack endpoint create --region RegionOne object-store admin http://192.168.100.200:8080/v1
    ```
    
    ct01, ct02, ct03 **3대 동일하게** proxy-server.conf 설정:
    
    ```bash
    sudo tee /etc/swift/proxy-server.conf <<'EOF'
    [DEFAULT]
    bind_port = 8080
    user = swift
    swift_dir = /etc/swift
    
    [pipeline:main]
    pipeline = catch_errors gatekeeper healthcheck proxy-logging cache listing_formats token_auth bulk tempurl ratelimit authtoken keystoneauth copy container_sync container_quotas account_quotas slo dlo versioned_writes symlink proxy-logging proxy-server
    
    [app:proxy-server]
    use = egg:swift#proxy
    allow_account_management = true
    account_autocreate = true
    
    [filter:token_auth]
    use = egg:swift#tempauth
    user_admin_admin = admin .admin .reseller_admin
    user_test_tester = testing
    
    [filter:keystoneauth]
    use = egg:swift#keystoneauth
    operator_roles = admin,user
    
    [filter:authtoken]
    paste.filter_factory = keystonemiddleware.auth_token:filter_factory
    www_authenticate_uri = http://192.168.100.200:5000
    auth_url = http://192.168.100.200:5000
    memcached_servers = 192.168.100.202:11211,192.168.100.203:11211,192.168.100.204:11211
    auth_type = password
    project_domain_id = default
    user_domain_id = default
    project_name = service
    username = swift
    password = swiftpass
    delay_auth_decision = True
    
    [filter:cache]
    use = egg:swift#memcache
    memcache_servers = 192.168.100.202:11211,192.168.100.203:11211,192.168.100.204:11211
    
    [filter:catch_errors]
    use = egg:swift#catch_errors
    
    [filter:healthcheck]
    use = egg:swift#healthcheck
    
    [filter:proxy-logging]
    use = egg:swift#proxy_logging
    
    [filter:gatekeeper]
    use = egg:swift#gatekeeper
    
    [filter:listing_formats]
    use = egg:swift#listing_formats
    
    [filter:bulk]
    use = egg:swift#bulk
    
    [filter:tempurl]
    use = egg:swift#tempurl
    
    [filter:ratelimit]
    use = egg:swift#ratelimit
    
    [filter:copy]
    use = egg:swift#copy
    
    [filter:container_sync]
    use = egg:swift#container_sync
    
    [filter:container_quotas]
    use = egg:swift#container_quotas
    
    [filter:account_quotas]
    use = egg:swift#account_quotas
    
    [filter:slo]
    use = egg:swift#slo
    
    [filter:dlo]
    use = egg:swift#dlo
    
    [filter:versioned_writes]
    use = egg:swift#versioned_writes
    
    [filter:symlink]
    use = egg:swift#symlink
    EOF
    ```
    
    Swift Ring 파일 생성. ct01에서:
    
    ```bash
    # Ring 빌더 생성
    sudo swift-ring-builder /etc/swift/account.builder create 10 1 1
    sudo swift-ring-builder /etc/swift/container.builder create 10 1 1
    sudo swift-ring-builder /etc/swift/object.builder create 10 1 1
    
    # st01 디바이스 추가
    sudo swift-ring-builder /etc/swift/account.builder add --region 1 --zone 1 --ip 192.168.100.207 --port 6002 --device sdc --weight 100
    sudo swift-ring-builder /etc/swift/container.builder add --region 1 --zone 1 --ip 192.168.100.207 --port 6001 --device sdc --weight 100
    sudo swift-ring-builder /etc/swift/object.builder add --region 1 --zone 1 --ip 192.168.100.207 --port 6000 --device sdc --weight 100
    
    # Ring 밸런싱
    sudo swift-ring-builder /etc/swift/account.builder rebalance
    sudo swift-ring-builder /etc/swift/container.builder rebalance
    sudo swift-ring-builder /etc/swift/object.builder rebalance
    ```
    
    Ring 파일을 ct02, ct03, st01에 배포. ct01에서:
    
    ```bash
    # ct02로 복사
    sudo scp /etc/swift/account.ring.gz ubuntu@192.168.100.203:/tmp/
    sudo scp /etc/swift/container.ring.gz ubuntu@192.168.100.203:/tmp/
    sudo scp /etc/swift/object.ring.gz ubuntu@192.168.100.203:/tmp/
    
    # ct03으로 복사
    sudo scp /etc/swift/account.ring.gz ubuntu@192.168.100.204:/tmp/
    sudo scp /etc/swift/container.ring.gz ubuntu@192.168.100.204:/tmp/
    sudo scp /etc/swift/object.ring.gz ubuntu@192.168.100.204:/tmp/
    
    # st01으로 복사
    sudo scp /etc/swift/account.ring.gz ubuntu@192.168.100.207:/tmp/
    sudo scp /etc/swift/container.ring.gz ubuntu@192.168.100.207:/tmp/
    sudo scp /etc/swift/object.ring.gz ubuntu@192.168.100.207:/tmp/
    ```
    
    완료되면 ct02, ct03, st01에서:
    
    ```bash
    sudo mv /tmp/account.ring.gz /etc/swift/
    sudo mv /tmp/container.ring.gz /etc/swift/
    sudo mv /tmp/object.ring.gz /etc/swift/
    sudo chown swift:swift /etc/swift/account.ring.gz
    sudo chown swift:swift /etc/swift/container.ring.gz
    sudo chown swift:swift /etc/swift/object.ring.gz
    ```
    
     swift.conf 설정. ct01, ct02, ct03, st01 **4대에서:**
    
    ```bash
    sudo tee /etc/swift/swift.conf <<'EOF'
    [swift-hash]
    swift_hash_path_suffix = openstack_swift_suffix
    swift_hash_path_prefix = openstack_swift_prefix
    
    [storage-policy:0]
    name = Policy-0
    default = yes
    EOF
    
    sudo chown swift:swift /etc/swift/swift.conf
    ```
    
    st01에서 account, container, object 서비스 시작:
    
    ```bash
    sudo systemctl enable swift-account swift-account-auditor swift-account-reaper swift-account-replicator
    sudo systemctl enable swift-container swift-container-auditor swift-container-replicator swift-container-sync swift-container-updater
    sudo systemctl enable swift-object swift-object-auditor swift-object-replicator swift-object-updater
    
    sudo systemctl start swift-account swift-account-auditor swift-account-reaper swift-account-replicator
    sudo systemctl start swift-container swift-container-auditor swift-container-replicator swift-container-sync swift-container-updater
    sudo systemctl start swift-object swift-object-auditor swift-object-replicator swift-object-updater
    
    sudo systemctl status swift-object | tail -3
    ```
    
    ct01, ct02, ct03에서 swift-proxy 시작:
    
    ```bash
    sudo systemctl enable swift-proxy
    sudo systemctl start swift-proxy
    sudo systemctl status swift-proxy | tail -3
    ```
    
     lb에서 HAProxy에 Swift 8080 포트 추가:
    
    ```bash
    sudo tee -a /etc/haproxy/haproxy.cfg <<'EOF'
    
    frontend swift_proxy
        bind *:8080
        default_backend swift_back
    
    backend swift_back
        balance roundrobin
        server ct01 192.168.100.202:8080 check inter 2s
        server ct02 192.168.100.203:8080 check inter 2s
        server ct03 192.168.100.204:8080 check inter 2s
    EOF
    
    sudo systemctl restart haproxy
    ```
    
    ct01에서 Swift 동작 확인:
    
    ```bash
    source ~/openrc
    swift stat
    ```
    
    ### Step 2: Octavia 설치
    
    ct01, ct02, ct03 **3대에** 설치:
    
    ```bash
    sudo apt install -y octavia-api octavia-health-manager octavia-housekeeping octavia-worker python3-octavia python3-octaviaclient
    ```
    
    ct01에서 Octavia 서비스 계정 및 네트워크 설정:
    
    ```bash
    source ~/openrc
    
    # 서비스 계정 생성
    openstack user create --domain default --password octaviapass octavia
    openstack role add --project service --user octavia admin
    openstack role create load-balancer_admin
    openstack role add --project admin --user admin load-balancer_admin
    
    # 서비스 및 엔드포인트 등록
    openstack service create --name octavia --description "OpenStack Load Balancer" load-balancer
    
    openstack endpoint create --region RegionOne load-balancer public http://192.168.100.200:9876
    openstack endpoint create --region RegionOne load-balancer internal http://192.168.100.200:9876
    openstack endpoint create --region RegionOne load-balancer admin http://192.168.100.200:9876
    ```
    
     Octavia 전용 네트워크 생성. ct01에서:
    
    ```bash
    # Octavia 관리 네트워크 생성
    openstack network create lb-mgmt-net
    openstack subnet create --network lb-mgmt-net \
      --subnet-range 192.168.200.0/24 \
      --gateway 192.168.200.1 \
      lb-mgmt-subnet
    
    # Octavia 전용 보안그룹 생성
    openstack security group create lb-mgmt-sec-grp
    openstack security group rule create --protocol icmp lb-mgmt-sec-grp
    openstack security group rule create --protocol tcp --dst-port 22 lb-mgmt-sec-grp
    openstack security group rule create --protocol tcp --dst-port 9443 lb-mgmt-sec-grp
    
    openstack security group create lb-health-mgr-sec-grp
    openstack security group rule create --protocol udp --dst-port 5555 lb-health-mgr-sec-grp
    ```
    
    Octavia용 인증서 생성. ct01에서:
    
    ```bash
    # 인증서 디렉토리 생성
    sudo mkdir -p /etc/octavia/certs
    
    # CA 키 및 인증서 생성
    sudo openssl genrsa -out /etc/octavia/certs/ca_key.pem 2048
    sudo openssl req -new -x509 -days 3650 -key /etc/octavia/certs/ca_key.pem \
      -out /etc/octavia/certs/ca_cert.pem -subj "/C=KR/ST=Seoul/L=Seoul/O=OpenStack/CN=Octavia CA"
    
    # 클라이언트 키 및 인증서 생성
    sudo openssl genrsa -out /etc/octavia/certs/client_key.pem 2048
    sudo openssl req -new -key /etc/octavia/certs/client_key.pem \
      -out /etc/octavia/certs/client_csr.pem -subj "/C=KR/ST=Seoul/L=Seoul/O=OpenStack/CN=Octavia Client"
    sudo openssl x509 -req -days 3650 -in /etc/octavia/certs/client_csr.pem \
      -CA /etc/octavia/certs/ca_cert.pem -CAkey /etc/octavia/certs/ca_key.pem \
      -CAcreateserial -out /etc/octavia/certs/client_cert.pem
    
    # 권한 설정
    sudo chown -R octavia:octavia /etc/octavia/certs
    sudo chmod 700 /etc/octavia/certs
    sudo chmod 600 /etc/octavia/certs/ca_key.pem
    sudo chmod 600 /etc/octavia/certs/ca_cert.pem
    sudo chmod 600 /etc/octavia/certs/client_key.pem
    sudo chmod 600 /etc/octavia/certs/client_csr.pem
    sudo chmod 600 /etc/octavia/certs/client_cert.pem
    ```
    
    ct02, ct03에도 인증서 복사. ct01에서:
    
    ```bash
    # ct02로 복사
    sudo scp /etc/octavia/certs/ca_key.pem ubuntu@192.168.100.203:/tmp/
    sudo scp /etc/octavia/certs/ca_cert.pem ubuntu@192.168.100.203:/tmp/
    sudo scp /etc/octavia/certs/client_key.pem ubuntu@192.168.100.203:/tmp/
    sudo scp /etc/octavia/certs/client_cert.pem ubuntu@192.168.100.203:/tmp/
    
    # ct03으로 복사
    sudo scp /etc/octavia/certs/ca_key.pem ubuntu@192.168.100.204:/tmp/
    sudo scp /etc/octavia/certs/ca_cert.pem ubuntu@192.168.100.204:/tmp/
    sudo scp /etc/octavia/certs/client_key.pem ubuntu@192.168.100.204:/tmp/
    sudo scp /etc/octavia/certs/client_cert.pem ubuntu@192.168.100.204:/tmp/
    ```
    
    완료되면 ct02, ct03에서:
    
    ```bash
    sudo mkdir -p /etc/octavia/certs
    sudo mv /tmp/ca_key.pem /etc/octavia/certs/
    sudo mv /tmp/ca_cert.pem /etc/octavia/certs/
    sudo mv /tmp/client_key.pem /etc/octavia/certs/
    sudo mv /tmp/client_cert.pem /etc/octavia/certs/
    sudo chown -R octavia:octavia /etc/octavia/certs
    sudo chmod 700 /etc/octavia/certs
    sudo chmod 600 /etc/octavia/certs/ca_key.pem
    sudo chmod 600 /etc/octavia/certs/ca_cert.pem
    sudo chmod 600 /etc/octavia/certs/client_key.pem
    sudo chmod 600 /etc/octavia/certs/client_cert.pem
    ```
    
    octavia.conf 설정. 먼저 lb-mgmt-net ID 확인. ct01에서:
    
    ```bash
    openstack network show lb-mgmt-net -f value -c id
    openstack subnet show lb-mgmt-subnet -f value -c id
    openstack security group show lb-mgmt-sec-grp -f value -c id
    openstack security group show lb-health-mgr-sec-grp -f value -c id
    ```
    
    ```bash
    ubuntu@openstack-ct01:~$ openstack network show lb-mgmt-net -f value -c id
    9d60e440-0c80-497b-b0cc-34d18c3d4466
    ubuntu@openstack-ct01:~$ openstack subnet show lb-mgmt-subnet -f value -c id
    ff54d6d3-d18f-44fb-bab0-07a2b8121191
    ubuntu@openstack-ct01:~$ openstack security group show lb-mgmt-sec-grp -f value -c id
    92690c3f-aada-4e70-9d07-1bd748bc6b88
    ubuntu@openstack-ct01:~$ openstack security group show lb-health-mgr-sec-grp -f value -c id
    f1daadf8-4169-489f-a1aa-6a2712365883
    ```
    
    ct01, ct02, ct03 **3대 동일하게** octavia.conf 설정(위에서 확인한 id값 넣어야함):
    
    - host를 각 ct에 맞는 값 넣기
    
    ```bash
    sudo tee /etc/octavia/octavia.conf <<'EOF'
    [DEFAULT]
    log_dir = /var/log/octavia
    transport_url = rabbit://openstack:openstack@192.168.100.202:5672,openstack:openstack@192.168.100.203:5672,openstack:openstack@192.168.100.204:5672
    host = openstack-ct01
    
    [api_settings]
    bind_host = 0.0.0.0
    bind_port = 9876
    auth_strategy = keystone
    
    [database]
    connection = mysql+pymysql://octavia:octaviapass@192.168.100.202/octavia
    
    [keystone_authtoken]
    www_authenticate_uri = http://192.168.100.200:5000
    auth_url = http://192.168.100.200:5000
    memcached_servers = 192.168.100.202:11211,192.168.100.203:11211,192.168.100.204:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = octavia
    password = octaviapass
    
    [service_auth]
    auth_url = http://192.168.100.200:5000
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = admin
    username = admin
    password = adminpass
    
    [certificates]
    ca_private_key = /etc/octavia/certs/ca_key.pem
    ca_certificate = /etc/octavia/certs/ca_cert.pem
    client_cert = /etc/octavia/certs/client_cert.pem
    
    [haproxy_amphora]
    client_cert = /etc/octavia/certs/client_cert.pem
    client_key = /etc/octavia/certs/client_key.pem
    client_ca = /etc/octavia/certs/ca_cert.pem
    server_ca = /etc/octavia/certs/ca_cert.pem
    
    [controller_worker]
    amp_boot_network_list = 9d60e440-0c80-497b-b0cc-34d18c3d4466
    amp_secgroup_list = 92690c3f-aada-4e70-9d07-1bd748bc6b88
    amp_flavor_id =
    amp_image_tag = amphora
    amp_ssh_key_name =
    network_driver = allowed_address_pairs_driver
    compute_driver = compute_nova_driver
    amphora_driver = amphora_haproxy_rest_driver
    
    # amp_flavor_id: openstack flavor show m1.tiny -f value -c id 로 확인한 값 입력
    amp_flavor_id = 7528f78c-187c-43c3-9b92-6c55a5d3391d
    
    # ComputeWaitTimeoutException 방지
    amp_active_retries = 60
    amp_active_wait_sec = 10
    
    [health_manager]
    bind_port = 5555
    bind_ip = 0.0.0.0
    controller_ip_port_list = 192.168.100.202:5555,192.168.100.203:5555,192.168.100.204:5555
    
    [oslo_messaging]
    topic = octavia_provisioning_v2
    
    [oslo_concurrency]
    lock_path = /var/lib/octavia/tmp
    EOF
    ```
    
    ct01에서 DB 생성 및 sync 진행:
    
    ```bash
    # octavia DB가 없으면 생성
    sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS octavia;"
    sudo mysql -u root -e "GRANT ALL PRIVILEGES ON octavia.* TO 'octavia'@'%' IDENTIFIED BY 'octaviapass';"
    sudo mysql -u root -e "FLUSH PRIVILEGES;"
    
    # DB sync
    sudo octavia-db-manage upgrade head
    ```
    
    Apache WSGI로 설정. ct01, ct02, ct03 **3대 모두:**
    
    ```bash
    # octavia-api 서비스 중단 (Apache WSGI로 대체) 추가
    sudo systemctl stop octavia-api
    sudo systemctl disable octavia-api
    
    sudo tee /etc/apache2/sites-available/octavia-api.conf <<'EOF'
    <VirtualHost *:9876>
        WSGIDaemonProcess octavia-api processes=3 threads=1 user=octavia group=octavia display-name=%{GROUP}
        WSGIProcessGroup octavia-api
        WSGIScriptAlias / /usr/bin/octavia-wsgi
        WSGIApplicationGroup %{GLOBAL}
        WSGIPassAuthorization On
        ErrorLog /var/log/octavia/octavia-api.log
        CustomLog /var/log/apache2/octavia_access.log combined
    
        <Directory /usr/bin>
            Require all granted
        </Directory>
    </VirtualHost>
    EOF
    
    # ports.conf에 9876 추가
    echo "Listen 9876" | sudo tee -a /etc/apache2/ports.conf
    
    sudo a2ensite octavia-api
    sudo systemctl restart apache2
    ```
    
    HAProxy에 Octavia 포트 추가하고 서비스 시작:
    
    lb에서:
    
    ```bash
    sudo tee -a /etc/haproxy/haproxy.cfg <<'EOF'
    
    frontend octavia_api
        bind *:9876
        default_backend octavia_back
    
    backend octavia_back
        balance roundrobin
        server ct01 192.168.100.202:9876 check inter 2s
        server ct02 192.168.100.203:9876 check inter 2s
        server ct03 192.168.100.204:9876 check inter 2s
    EOF
    ```
    
    ct01, ct02, ct03 **3대 동시에** 서비스 시작:
    
    ```bash
    sudo systemctl enable octavia-worker octavia-health-manager octavia-housekeeping
    sudo systemctl start octavia-worker octavia-health-manager octavia-housekeeping
    sudo systemctl status octavia-api | tail -3
    ```
    
    lb에서 HAProxy 재시작:
    
    ```bash
    sudo systemctl restart haproxy
    ```
    
    ct01에서 연결 잘 됐는지 확인:
    
    - 빈칸 나오면 정상
    
    ```bash
    openstack loadbalancer list
    ```
    

---

### Phase 6 — 통합 검증

**목표:** 실제 프로덕션 시나리오로 전체 스택을 검증한다.

1. Self-Service 네트워크 + 라우터 생성, External 네트워크 연결
2. cirros 인스턴스 기동 → Security Group 설정 → Floating IP 할당 → SSH 접속
3. Cinder 볼륨 생성 → 인스턴스에 Attach → 포맷 후 마운트 확인
4. Octavia LB 생성 → 2개 인스턴스에 분산 확인
5. Swift에 오브젝트 업로드/다운로드

> 📸 **최종 스냅샷 촬영**
> 
- 실제 작업
    
    ### Step 1: Self-Service network 구성
    
    ```bash
    - Management 대역: 192.168.100.0/24 (노드 간 제어, API)
    - External/Provider 대역: 172.16.100.0/24 (Floating IP, 인스턴스 외부 통신)
    ```
    
    네트워크 구성. ct01에서:
    
    ```bash
    source ~/openrc
    
    # External 네트워크 생성 (Provider 네트워크)
    openstack network create --share --external \
      --provider-physical-network provider \
      --provider-network-type flat \
      external-net
    
    openstack subnet create --network external-net \
      --allocation-pool start=172.16.100.100,end=172.16.100.200 \
      --dns-nameserver 8.8.8.8 \
      --gateway 172.16.100.1 \
      --subnet-range 172.16.100.0/24 \
      --no-dhcp \
      external-subnet
    ```
    
    Self-Service 네트워크와 라우터 생성. ct01에서:
    
    ```bash
    # Self-Service 내부 네트워크 생성
    openstack network create internal-net
    
    openstack subnet create --network internal-net \
      --dns-nameserver 8.8.8.8 \
      --gateway 10.0.0.1 \
      --subnet-range 10.0.0.0/24 \
      internal-subnet
    
    # 라우터 생성 및 연결
    openstack router create main-router
    openstack router set --external-gateway external-net main-router
    openstack router add subnet main-router internal-subnet
    ```
    
    cp의 nova.conf에 neutron 섹션 추가. cp01, cp02**에서:**
    
    ```bash
    sudo tee -a /etc/nova/nova.conf <<'EOF'
    
    [neutron]
    auth_url = http://192.168.100.200:5000
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    region_name = RegionOne
    project_name = service
    username = neutron
    password = neutronpass
    service_metadata_proxy = true
    metadata_proxy_shared_secret = metasecret
    EOF
    
    sudo systemctl restart nova-compute
    ```
    
    HAProxy가 HTTP 모드라 큰 파일 전송 시 문제가 생기는 거예요. Glance 백엔드를 TCP 모드로 변경(이미지를 못받아오는 문제 해결). lb에서:
    
    ```bash
    sudo tee /etc/haproxy/haproxy.cfg <<'EOF'
    global
        log /dev/log local0
        maxconn 4096
        daemon
    
    defaults
        log global
        mode http
        option httplog
        timeout connect 10s
        timeout client 300s
        timeout server 300s
    
    frontend keystone_public
        bind *:5000
        default_backend keystone_back
    
    frontend nova_api
        bind *:8774
        default_backend nova_back
    
    frontend placement_api
        bind *:8778
        default_backend placement_back
    
    frontend neutron_api
        bind *:9696
        default_backend neutron_back
    
    frontend cinder_api
        bind *:8776
        default_backend cinder_back
    
    frontend octavia_api
        bind *:9876
        default_backend octavia_back
    
    frontend swift_proxy
        bind *:8080
        default_backend swift_back
    
    backend keystone_back
        balance roundrobin
        option httpchk GET /v3
        http-check expect status 200
        server ct01 192.168.100.202:5000 check inter 2s
        server ct02 192.168.100.203:5000 check inter 2s
        server ct03 192.168.100.204:5000 check inter 2s
    
    backend nova_back
        balance roundrobin
        server ct01 192.168.100.202:8774 check inter 2s
        server ct02 192.168.100.203:8774 check inter 2s
        server ct03 192.168.100.204:8774 check inter 2s
    
    backend placement_back
        balance roundrobin
        server ct01 192.168.100.202:8778 check inter 2s
        server ct02 192.168.100.203:8778 check inter 2s
        server ct03 192.168.100.204:8778 check inter 2s
    
    backend neutron_back
        balance roundrobin
        server ct01 192.168.100.202:9696 check inter 2s
        server ct02 192.168.100.203:9696 check inter 2s
        server ct03 192.168.100.204:9696 check inter 2s
    
    backend cinder_back
        balance roundrobin
        server ct01 192.168.100.202:8776 check inter 2s
        server ct02 192.168.100.203:8776 check inter 2s
        server ct03 192.168.100.204:8776 check inter 2s
    
    backend octavia_back
        balance roundrobin
        server ct01 192.168.100.202:9876 check inter 2s
        server ct02 192.168.100.203:9876 check inter 2s
        server ct03 192.168.100.204:9876 check inter 2s
    
    backend swift_back
        balance roundrobin
        server ct01 192.168.100.202:8080 check inter 2s
        server ct02 192.168.100.203:8080 check inter 2s
        server ct03 192.168.100.204:8080 check inter 2s
    
    frontend glance_api
        bind *:9292
        mode tcp
        default_backend glance_back
    
    backend glance_back
        mode tcp
        balance roundrobin
        server ct01 192.168.100.202:9292 check inter 2s
        server ct02 192.168.100.203:9292 check inter 2s
        server ct03 192.168.100.204:9292 check inter 2s
    EOF
    
    sudo systemctl restart haproxy
    ```
    
    ### Step 2: cirros 인스턴스 기동
    
    Security Group 설정하고 인스턴스 기동. ct01에서:
    
    - 결과
        
        ```bash
        +-------------------------+--------------------------------------+
        | Field                   | Value                                |
        +-------------------------+--------------------------------------+
        | created_at              | 2026-06-19T04:55:35Z                 |
        | description             |                                      |
        | direction               | ingress                              |
        | ether_type              | IPv4                                 |
        | id                      | eefd26d3-c328-4654-97ee-f4d87feeb4d3 |
        | name                    | None                                 |
        | port_range_max          | None                                 |
        | port_range_min          | None                                 |
        | project_id              | 158c14d88b0c46f399fb66b4d5f713af     |
        | protocol                | icmp                                 |
        | remote_address_group_id | None                                 |
        | remote_group_id         | None                                 |
        | remote_ip_prefix        | 0.0.0.0/0                            |
        | revision_number         | 0                                    |
        | security_group_id       | 2468527e-75f5-485a-99a0-43155760bf54 |
        | tags                    | []                                   |
        | tenant_id               | 158c14d88b0c46f399fb66b4d5f713af     |
        | updated_at              | 2026-06-19T04:55:35Z                 |
        +-------------------------+--------------------------------------+
        ubuntu@openstack-ct01:~$ openstack security group rule create --proto tcp --dst-port 22 default
        +-------------------------+--------------------------------------+
        | Field                   | Value                                |
        +-------------------------+--------------------------------------+
        | created_at              | 2026-06-19T04:55:40Z                 |
        | description             |                                      |
        | direction               | ingress                              |
        | ether_type              | IPv4                                 |
        | id                      | 0a68a408-2a47-49cd-9883-8604cec6973a |
        | name                    | None                                 |
        | port_range_max          | 22                                   |
        | port_range_min          | 22                                   |
        | project_id              | 158c14d88b0c46f399fb66b4d5f713af     |
        | protocol                | tcp                                  |
        | remote_address_group_id | None                                 |
        | remote_group_id         | None                                 |
        | remote_ip_prefix        | 0.0.0.0/0                            |
        | revision_number         | 0                                    |
        | security_group_id       | 2468527e-75f5-485a-99a0-43155760bf54 |
        | tags                    | []                                   |
        | tenant_id               | 158c14d88b0c46f399fb66b4d5f713af     |
        | updated_at              | 2026-06-19T04:55:40Z                 |
        +-------------------------+--------------------------------------+
        ubuntu@openstack-ct01:~$ openstack flavor create --ram 512 --disk 5 --vcpus 1 m1.tiny
        +----------------------------+--------------------------------------+
        | Field                      | Value                                |
        +----------------------------+--------------------------------------+
        | OS-FLV-DISABLED:disabled   | False                                |
        | OS-FLV-EXT-DATA:ephemeral  | 0                                    |
        | description                | None                                 |
        | disk                       | 5                                    |
        | id                         | 7528f78c-187c-43c3-9b92-6c55a5d3391d |
        | name                       | m1.tiny                              |
        | os-flavor-access:is_public | True                                 |
        | properties                 |                                      |
        | ram                        | 512                                  |
        | rxtx_factor                | 1.0                                  |
        | swap                       |                                      |
        | vcpus                      | 1                                    |
        +----------------------------+--------------------------------------+
        ubuntu@openstack-ct01:~$ openstack keypair create --public-key ~/.ssh/id_ed25519.pub mykey
        +-------------+-------------------------------------------------+
        | Field       | Value                                           |
        +-------------+-------------------------------------------------+
        | created_at  | None                                            |
        | fingerprint | 31:18:a9:fa:45:a6:59:51:05:13:f3:96:5d:3b:df:e4 |
        | id          | mykey                                           |
        | is_deleted  | None                                            |
        | name        | mykey                                           |
        | type        | ssh                                             |
        | user_id     | 53599cb4f696431f8bbe15e533488545                |
        +-------------+-------------------------------------------------+
        ubuntu@openstack-ct01:~$ openstack server create \
        >   --flavor m1.tiny \
        >   --image cirros-0.6.2 \
        >   --network internal-net \
        >   --security-group default \
        >   --key-name mykey \
        >   test-instance-1
        +-------------------------------------+-----------------------------------------------------+
        | Field                               | Value                                               |
        +-------------------------------------+-----------------------------------------------------+
        | OS-DCF:diskConfig                   | MANUAL                                              |
        | OS-EXT-AZ:availability_zone         |                                                     |
        | OS-EXT-SRV-ATTR:host                | None                                                |
        | OS-EXT-SRV-ATTR:hypervisor_hostname | None                                                |
        | OS-EXT-SRV-ATTR:instance_name       |                                                     |
        | OS-EXT-STS:power_state              | NOSTATE                                             |
        | OS-EXT-STS:task_state               | scheduling                                          |
        | OS-EXT-STS:vm_state                 | building                                            |
        | OS-SRV-USG:launched_at              | None                                                |
        | OS-SRV-USG:terminated_at            | None                                                |
        | accessIPv4                          |                                                     |
        | accessIPv6                          |                                                     |
        | addresses                           |                                                     |
        | adminPass                           | xU3Qnwri92ce                                        |
        | config_drive                        |                                                     |
        | created                             | 2026-06-19T04:56:00Z                                |
        | flavor                              | m1.tiny (7528f78c-187c-43c3-9b92-6c55a5d3391d)      |
        | hostId                              |                                                     |
        | id                                  | bbab35e9-3246-45f8-84c2-7315a6367478                |
        | image                               | cirros-0.6.2 (f3e781bb-2d0a-4c3f-8f60-cb0faab07a8a) |
        | key_name                            | mykey                                               |
        | name                                | test-instance-1                                     |
        | progress                            | 0                                                   |
        | project_id                          | 158c14d88b0c46f399fb66b4d5f713af                    |
        | properties                          |                                                     |
        | security_groups                     | name='2468527e-75f5-485a-99a0-43155760bf54'         |
        | status                              | BUILD                                               |
        | updated                             | 2026-06-19T04:56:00Z                                |
        | user_id                             | 53599cb4f696431f8bbe15e533488545                    |
        | volumes_attached                    |                                                     |
        +-------------------------------------+-----------------------------------------------------+
        ```
        
    
    ```bash
    # Security Group 규칙 추가 (default 그룹)
    openstack security group rule create --proto icmp default
    openstack security group rule create --proto tcp --dst-port 22 default
    
    # Flavor 생성
    openstack flavor create --ram 512 --disk 5 --vcpus 1 m1.tiny
    
    # 키페어 생성
    openstack keypair create --public-key ~/.ssh/id_ed25519.pub mykey
    
    # 인스턴스 기동
    openstack server create \
      --flavor m1.tiny \
      --image cirros-0.6.2 \
      --network internal-net \
      --security-group default \
      --key-name mykey \
      test-instance-1
    ```
    
    인스턴스 상태 확인. ct01에서:
    
    - 결과
        
        ```bash
        ubuntu@openstack-ct01:~$ openstack server list
        +--------------------------------------+-----------------+--------+------------------------+--------------+---------+
        | ID                                   | Name            | Status | Networks               | Image        | Flavor  |
        +--------------------------------------+-----------------+--------+------------------------+--------------+---------+
        | e7103e4a-1cc9-4a7d-b567-1a1dc8d02ae8 | test-instance-1 | ACTIVE | internal-net=10.0.0.66 | cirros-0.6.2 | m1.tiny |
        +--------------------------------------+-----------------+--------+------------------------+--------------+---------+
        ```
        
    
    ```bash
    openstack server list
    ```
    
    sudoers 권한 부여. ct01, ct02, ct03에서:
    
    ```bash
    sudo tee /etc/sudoers.d/neutron-rootwrap <<'EOF'
    Defaults:neutron !requiretty
    neutron ALL=(root) NOPASSWD: /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf *
    neutron ALL=(root) NOPASSWD: /usr/bin/neutron-rootwrap-daemon /etc/neutron/rootwrap.conf
    neutron ALL=(root) NOPASSWD: /usr/bin/privsep-helper *
    neutron ALL=(root) NOPASSWD: /usr/sbin/dnsmasq *
    neutron ALL=(root) NOPASSWD: /usr/sbin/ip *
    neutron ALL=(root) NOPASSWD: /sbin/ip *
    neutron ALL=(root) NOPASSWD: /usr/bin/ip *
    neutron ALL=(root) NOPASSWD: /usr/sbin/haproxy *
    EOF
    
    sudo chmod 440 /etc/sudoers.d/neutron-rootwrap
    sudo systemctl restart neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent
    ```
    
    ct01에서 라우팅 추가
    
    ```bash
    # Provider 브릿지 이름 확인
    PROVIDER_BR=$(sudo brctl show | grep -B3 ens19 | grep "^brq" | awk '{print $1}')
    echo $PROVIDER_BR
    
    # 172.16.100.0/24를 Provider 브릿지로 라우팅
    sudo ip route add 172.16.100.0/24 dev $PROVIDER_BR
    ```
    
    Floating IP 할당. ct01에서:
    
    ```bash
    # Floating IP 생성
    openstack floating ip create external-net
    
    # 인스턴스에 할당
    FLOATING_IP=$(openstack floating ip list -f value -c "Floating IP Address" | head -1)
    openstack server add floating ip test-instance-1 $FLOATING_IP
    
    # 확인
    openstack server show test-instance-1 | grep addresses
    
    # qrouter 네임스페이스 통해 ping 및 SSH 접속
    ROUTER_NS=$(ip netns list | grep qrouter | awk '{print $1}')
    sudo ip netns exec $ROUTER_NS ping -c 3 $FLOATING_IP
    sudo ip netns exec $ROUTER_NS ssh -i ~/.ssh/id_ed25519 cirros@$FLOATING_IP
    ```
    
    ### Step 3: Cinder 볼륨 생성
    
     ct01, ct02, ct03 **3대 모두** nova.conf에 cinder 섹션 추가:
    
    ```bash
    sudo tee -a /etc/nova/nova.conf <<'EOF'
    
    [cinder]
    os_region_name = RegionOne
    EOF
    
    sudo systemctl restart nova-api nova-conductor nova-scheduler
    ```
    
    tgt 권한 부여. st01에서: 
    
    ```bash
    # tgt 권한 및 volumes_dir 설정 (st01에서)
    sudo tee /etc/tmpfiles.d/tgt.conf <<'EOF'
    d /var/run/tgtd 0777 root root -
    EOF
    
    sudo mkdir -p /etc/tgt/conf.d
    sudo tee /etc/tgt/tgtd.conf <<'EOF'
    include /var/lib/cinder/volumes/*
    EOF
    
    sudo tee /etc/tgt/conf.d/cinder.conf <<'EOF'
    include /var/lib/cinder/volumes/*
    EOF
    
    sudo systemctl restart tgt
    sudo chmod 777 /var/run/tgtd/socket.0
    sudo systemctl restart cinder-volume
    ```
    
    Cinder 볼륨 생성 및 Attach 진행. ct01에서:
    
    - 결과
        
        ```bash
        ubuntu@openstack-ct01:~$ openstack volume create --size 1 test-vol
        +---------------------+--------------------------------------+
        | Field               | Value                                |
        +---------------------+--------------------------------------+
        | attachments         | []                                   |
        | availability_zone   | nova                                 |
        | bootable            | false                                |
        | consistencygroup_id | None                                 |
        | created_at          | 2026-06-19T06:39:10.159150           |
        | description         | None                                 |
        | encrypted           | False                                |
        | id                  | 8ad46648-a1bd-41f1-8eb4-60dcb2a50b85 |
        | migration_status    | None                                 |
        | multiattach         | False                                |
        | name                | test-vol                             |
        | properties          |                                      |
        | replication_status  | None                                 |
        | size                | 1                                    |
        | snapshot_id         | None                                 |
        | source_volid        | None                                 |
        | status              | creating                             |
        | type                | __DEFAULT__                          |
        | updated_at          | None                                 |
        | user_id             | 53599cb4f696431f8bbe15e533488545     |
        +---------------------+--------------------------------------+
        ubuntu@openstack-ct01:~$ openstack server add volume test-instance-1 test-vol
        +-----------------------+--------------------------------------+
        | Field                 | Value                                |
        +-----------------------+--------------------------------------+
        | ID                    | 8ad46648-a1bd-41f1-8eb4-60dcb2a50b85 |
        | Server ID             | e7103e4a-1cc9-4a7d-b567-1a1dc8d02ae8 |
        | Volume ID             | 8ad46648-a1bd-41f1-8eb4-60dcb2a50b85 |
        | Device                | /dev/vdb                             |
        | Tag                   | None                                 |
        | Delete On Termination | False                                |
        +-----------------------+--------------------------------------+
        ubuntu@openstack-ct01:~$ openstack volume list
        +--------------------------------------+----------+--------+------+------------------------------------------+
        | ID                                   | Name     | Status | Size | Attached to                              |
        +--------------------------------------+----------+--------+------+------------------------------------------+
        | 8ad46648-a1bd-41f1-8eb4-60dcb2a50b85 | test-vol | in-use |    1 | Attached to test-instance-1 on /dev/vdb  |
        +--------------------------------------+----------+--------+------+------------------------------------------+
        ```
        
    
    ```bash
    # 볼륨 생성
    openstack volume create --size 1 test-vol
    
    # 인스턴스에 Attach
    openstack server add volume test-instance-1 test-vol
    
    # 상태 확인
    openstack volume list
    ```
    
    인스턴스 내부 볼륨 마운트 확인. cp01 virsh콘솔:
    
    ```bash
    # cp01, cp02에서
    sudo virsh list --all
    
    # 생성한 인스턴스 id로 접속
    sudo virsh console instance-00000009
    ```
    
    - 결과
        
        ```bash
        $ cat /mnt/vol/test.txt
        test
        ```
        
    
    ```bash
    sudo -s
    fdisk -l | grep vdb
    mkfs.ext4 /dev/vdb
    mkdir /mnt/vol
    mount /dev/vdb /mnt/vol
    df -h | grep vdb
    echo "test" > /mnt/vol/test.txt
    cat /mnt/vol/test.txt
    ```
    
    ### ~~Step 4: Octivia LB 생성 - 현재 안됨~~
    
    - 막힌 문제
        
        ---
        
        ### ~~Step 4: Octavia LB 생성 — 미완료~~
        
        ### 해결된 문제 목록
        
        | 문제 | 원인 | 해결 |
        | --- | --- | --- |
        | `ca_01.pem` FileNotFoundError | `client_ca` 경로 오기재 | `ca_cert.pem`으로 수정 |
        | `amp_flavor_id` 미설정 | conf 공란 | `m1.tiny` ID 입력 |
        | Amphora 이미지 다운로드 실패 | `visibility: shared` | `public`으로 변경 |
        | Nova Glance 인증 실패 | `[service_user]` 미설정 | cp01, cp02에 추가 |
        | `service_auth` project 불일치 | project=service, user=octavia | project=admin, user=admin으로 변경 |
        | octavia-api 중복 실행 | systemd + apache2 동시 기동 | systemd octavia-api disable |
        | worker가 메시지를 못 받음 | RabbitMQ topic 불일치 | `octavia_prov` → `octavia_provisioning_v2` |
        | Amphora VM ACTIVE 대기 timeout | 기본값 10초 | `amp_active_retries=60`, `amp_active_wait_sec=10` |
        
        ### 현재 미해결 문제
        
        **ct01 → Amphora VM (lb-mgmt-net 192.168.200.x) 네트워크 연결 불가**
        
        - Amphora VM 자체는 ACTIVE 상태로 정상 부팅됨
        - DHCP namespace에서는 Amphora에 ping 성공 → L2 연결 자체는 살아있음
        - ct01에 veth pair(`o-hm0 ↔ tapc3b12ea0-9e`)를 수동으로 생성해 linuxbridge에 연결했으나 패킷 전달 안 됨
        - **원인:** linuxbridge 환경에서 수동으로 생성한 veth는 Neutron port security(MAC/IP 필터링)를 통과하지 못함. Neutron이 직접 포트를 바인딩하고 tap 인터페이스를 생성해야만 정상 통신 가능
        
        ### 다음 시도 방향
        
        1. **octavia-health-manager를 cp01 또는 cp02로 이전** — compute 노드는 이미 Neutron linuxbridge에 정상 연결되어 있으므로 lb-mgmt-net 접근이 가능
        2. **openstack-lb 노드에 health-manager 설치** — lb 노드가 별도로 존재하므로, lb-mgmt-net 포트를 lb 노드에 바인딩하는 방식 검토
        3. **OVS(Open vSwitch) 도입** — linuxbridge 대신 OVS를 사용하면 `ovs-vsctl add-port`로 컨트롤러 노드를 lb-mgmt-net에 직접 연결 가능. 단, 전체 Neutron 에이전트 재구성 필요
    
    amphora 이미지 다운. ct01에서:
    
    ```bash
    # amphora 이미지 다운로드 (Ubuntu 기반 prebuilt)
    wget https://tarballs.opendev.org/openstack/octavia/test-images/test-only-amphora-x64-haproxy-ubuntu-focal.qcow2
    ```
    
    이미지 등록. ct01에서:
    
    ```bash
    openstack image create \
      --disk-format qcow2 \
      --container-format bare \
      --file test-only-amphora-x64-haproxy-ubuntu-focal.qcow2 \
      --tag amphora \
      --public \
      amphora-x64-haproxy
      
    openstack image list | grep amphora
    ```
    
     두 번째 인스턴스 생성. ct01에서:
    
    - 결과
        
        ```bash
        ubuntu@openstack-ct01:~$ openstack server list
        +--------------------------------------+-----------------+--------+----------------------------------------+--------------+---------+
        | ID                                   | Name            | Status | Networks                               | Image        | Flavor  |
        +--------------------------------------+-----------------+--------+----------------------------------------+--------------+---------+
        | 0758cd60-a733-4aa6-a05c-77fad30af734 | test-instance-2 | ACTIVE | internal-net=10.0.0.181                | cirros-0.6.2 | m1.tiny |
        | e7103e4a-1cc9-4a7d-b567-1a1dc8d02ae8 | test-instance-1 | ACTIVE | internal-net=10.0.0.66, 172.16.100.158 | cirros-0.6.2 | m1.tiny |
        +--------------------------------------+-----------------+--------+----------------------------------------+--------------+---------+
        ```
        
    
    ```bash
    # 두 번째 인스턴스 생성
    openstack server create \
      --flavor m1.tiny \
      --image cirros-0.6.2 \
      --network internal-net \
      --security-group default \
      --key-name mykey \
      test-instance-2
    
    openstack server list
    ```
    
    LB 생성. ct01에서:
    
    ```bash
    # DB 연결 증가
    sudo mysql -u root -e "SET GLOBAL max_connections = 500;"
    
    # LB 생성
    openstack loadbalancer create \
      --name test-lb \
      --vip-subnet-id internal-subnet
    
    watch -n 5 "openstack loadbalancer show test-lb | grep provisioning_status"
    openstack loadbalancer show test-lb | grep provisioning_status
    ```
    
    ### Step 5: Swift 오브젝트 업로드/다운로드
    
    Swift 서비스 상태 확인:
    
    - 결과
        
        ```bash
        ubuntu@openstack-ct01:~$ ubuntu@openstack-ct01:~$ openstack object store account show
        +------------+---------------------------------------+
        | Field      | Value                                 |
        +------------+---------------------------------------+
        | Account    | AUTH_158c14d88b0c46f399fb66b4d5f713af |
        | Bytes      | 0                                     |
        | Containers | 0                                     |
        | Objects    | 0                                     |
        +------------+---------------------------------------+
        ubuntu@openstack-ct01:~$ openstack container list
        
        ```
        
    
    ```bash
    # ct01에서
    openstack object store account show
    openstack container list
    ```
    
    컨테이너 생성 후 오브젝트 업로드 테스트 진행:
    
    - 결과
        
        ```bash
        ubuntu@openstack-ct01:~$ openstack container create test-container
        +---------------------------------------+----------------+------------------------------------+
        | account                               | container      | x-trans-id                         |
        +---------------------------------------+----------------+------------------------------------+
        | AUTH_158c14d88b0c46f399fb66b4d5f713af | test-container | txb6f7c502aa1c4ecd9509a-006a353a2e |
        +---------------------------------------+----------------+------------------------------------+
        ubuntu@openstack-ct01:~$ echo "SU Cloud Swift Test - $(date)" > /tmp/test-object.txt
        ubuntu@openstack-ct01:~$ openstack object create test-container /tmp/test-object.txt
        +----------------------+----------------+----------------------------------+
        | object               | container      | etag                             |
        +----------------------+----------------+----------------------------------+
        | /tmp/test-object.txt | test-container | c8f09b822886dc2c9ced6c43a470e4bb |
        +----------------------+----------------+----------------------------------+
        ubuntu@openstack-ct01:~$ openstack object list test-container
        +----------------------+
        | Name                 |
        +----------------------+
        | /tmp/test-object.txt |
        +----------------------+
        ```
        
    
    ```bash
    # 컨테이너 생성
    openstack container create test-container
    
    # 테스트 파일 생성
    echo "SU Cloud Swift Test - $(date)" > /tmp/test-object.txt
    
    # 오브젝트 업로드
    openstack object create test-container /tmp/test-object.txt
    
    # 업로드 확인
    openstack object list test-container
    ```
    
    오브젝트 다운로드 테스트:
    
    - 결과
        
        ```bash
        ubuntu@openstack-ct01:~$ openstack object save test-container /tmp/test-object.txt --file /tmp/test-download.txt
        ubuntu@openstack-ct01:~$ cat /tmp/test-download.txt
        SU Cloud Swift Test - Fri Jun 19 12:46:43 PM UTC 2026
        ubuntu@openstack-ct01:~$ diff /tmp/test-object.txt /tmp/test-download.txt && echo "파일 일치 ✅"
        파일 일치 ✅
        ```
        
    
    ```bash
    # 다운로드
    openstack object save test-container /tmp/test-object.txt --file /tmp/test-download.txt
    
    # 내용 확인
    cat /tmp/test-download.txt
    
    # 원본과 비교
    diff /tmp/test-object.txt /tmp/test-download.txt && echo "파일 일치 ✅"
    ```