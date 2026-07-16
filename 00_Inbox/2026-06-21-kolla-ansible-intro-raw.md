---
title: "Kolla-Ansible이란"
type: "raw"
date: 2026-06-21
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# Kolla-Ansible이란?

> OpenStack을 Docker 컨테이너로 자동 배포해주는 도구
> 

---

## 왜 만들어졌나

OpenStack은 서비스가 매우 많다. Keystone, Nova, Neutron, Glance, Cinder, Swift, Octavia, RabbitMQ, MariaDB, Memcached...

수동 설치를 하면 노드마다 이 과정을 반복해야 한다.

```
1. 패키지 설치
2. 설정 파일 수정 (/etc/nova/nova.conf, /etc/neutron/neutron.conf ...)
3. DB 초기화
4. 서비스 시작 (systemctl start nova-api ...)
5. 의존성 문제 해결
6. 노드마다 반복 (ct01, ct02, ct03, cp01, cp02, st01 ...)
```

Kolla-Ansible은 이 전 과정을 자동화한다.

```
globals.yml에 NIC 이름 두 개 적고
kolla-ansible deploy 실행
→ 30~60분 후 OpenStack 완성
```

---

## Kolla vs Ansible — 역할 분리

Kolla-Ansible은 이름 그대로 **Kolla**와 **Ansible** 두 프로젝트의 조합이다.

### Kolla — 이미지 담당

OpenStack 각 서비스를 Docker 이미지로 패키징해두는 프로젝트.

```
quay.io/openstack.kolla/keystone
quay.io/openstack.kolla/nova-api
quay.io/openstack.kolla/nova-compute
quay.io/openstack.kolla/neutron-server
quay.io/openstack.kolla/glance-api
quay.io/openstack.kolla/cinder-api
quay.io/openstack.kolla/octavia-api
...
```

수십 개의 서비스가 각각 독립된 컨테이너 이미지로 존재한다. 버전 관리, 의존성 충돌이 컨테이너 단위로 격리된다.

### Ansible — 배포 담당

각 노드에 SSH로 접속해서 이 이미지들을 실행하는 자동화 도구.

```
deploy host (cjm-lb)
  │ SSH
  ├── ct01, ct02, ct03 → keystone, nova-api, neutron-server 컨테이너 실행
  ├── cp01, cp02       → nova-compute, ovs-agent 컨테이너 실행
  └── st01             → cinder-volume, swift 컨테이너 실행
```

---

## Ansible 기본 개념

### Ansible이란

**서버 설정을 코드로 자동화하는 도구**. SSH로 원격 노드에 접속해서 명령어를 실행한다. 에이전트 설치가 필요 없다(agentless).

```
Ansible이 하는 일:
SSH로 서버에 접속 → 명령어 실행 → 패키지 설치 → 설정 파일 배포 → 서비스 시작
```

IaC(Infrastructure as Code) 도구 중 하나다.

|  | Terraform | Ansible |
| --- | --- | --- |
| 역할 | 자원 생성/삭제 (VM, 네트워크, 스토리지) | 서버 내부 설정/구성 자동화 |
| 비유 | 건물 짓기 | 인테리어 하기 |
| 방식 | 선언형 (원하는 상태만 기술) | 절차형 (순서대로 실행) |
| 대상 | 클라우드 자원 | 서버 내부 (패키지, 설정, 서비스) |

실제로는 **Terraform으로 VM 만들고 → Ansible로 그 안을 설정**하는 식으로 같이 쓴다.

## IaC (Infrastructure as Code)

**코드로 인프라를 관리하는 것**.

기존에는 서버를 만들고 설정할 때 사람이 직접 함. IaC는 그 과정을 코드로 작성해두고 실행하면 자동으로 됨.

```
[기존 방식]
사람이 직접 → 서버 생성 클릭 → SSH 접속 → 패키지 설치 → 설정 파일 수정

[IaC 방식]
코드 작성해두고 → 실행 한 번 → 자동으로 전부 처리
```

**장점**:

- 100대 서버도 코드 한 번 실행으로 동일하게 설정
- 코드가 곧 문서 (어떻게 설정됐는지 코드 보면 됨)
- Git으로 버전 관리 가능 (언제 뭐가 바뀌었는지 추적)
- 실수가 줄어듦 (사람이 직접 치다가 오타 나는 경우 없음)

---

### Terraform

**인프라 자원 자체를 만드는 도구**.

VM, 네트워크, 스토리지 등 **자원(Resource)을 생성/수정/삭제**.

```hcl
# 예시: OpenStack에 VM 만들기
resource "openstack_compute_instance_v2" "test-vm" {
  name      = "test-vm"
  image_id  = "cirros-image-id"
  flavor_id = "m1.tiny"

  network {
    name = "internal-net"
  }
}
```

위 코드를 `terraform apply` 하면 OpenStack에 VM이 생김. `terraform destroy` 하면 지워짐.

**핵심 개념**:

- **선언형**: "이런 상태여야 해"라고 선언하면 Terraform이 알아서 현재 상태와 비교해서 필요한 작업만 함
- **State 파일**: 현재 인프라 상태를 파일로 저장해서 추적

```
Terraform이 하는 일:
  현재 상태 확인 → 원하는 상태와 비교 → 차이만 적용
```

### Playbook

**Ansible이 실행할 작업 목록을 적어놓은 YAML 파일**.

```yaml
# 예시 playbook
- name: OpenStack nova-compute 설치
  hosts: compute          # multinode의 [compute] 그룹 노드들에서 실행
  tasks:
    - name: Docker 설치
      apt:
        name: docker.io
        state: present

    - name: nova-compute 컨테이너 실행
      docker_container:
        name: nova_compute
        image: quay.io/openstack.kolla/nova-compute
        state: started
```

`kolla-ansible deploy`를 실행하면 내부적으로 이런 playbook들이 순서대로 실행된다.

```
playbook.yml
  └── play (어느 호스트 그룹에서 실행할지)
        └── task (실제 작업 하나하나)
              ├── apt 패키지 설치
              ├── 설정 파일 복사
              ├── 컨테이너 실행
              └── 서비스 헬스체크
```

## 전체 관계 정리

```
Terraform                    Ansible (Playbook)
    │                              │
VM/네트워크 생성              서버 내부 설정 자동화
    │                              │
    └──────── 함께 사용 ───────────┘
                    │
              IaC (코드로 인프라 관리)
```

Kolla Ansible은 Ansible 기반이라 `multinode`(인벤토리)와 `globals.yml`(변수)만 작성하면 playbook이 알아서 OpenStack 전체를 설치.

### Inventory (인벤토리)

**어떤 IP가 어떤 역할을 맡는지** 정의하는 파일. Kolla-Ansible에서는 `multinode` 파일이 이 역할을 한다.

```
[control]
ct01 ansible_host=192.168.100.202 ansible_user=ubuntu
ct02 ansible_host=192.168.100.203 ansible_user=ubuntu
ct03 ansible_host=192.168.100.204 ansible_user=ubuntu

[compute]
cp01 ansible_host=192.168.100.205 ansible_user=ubuntu
cp02 ansible_host=192.168.100.206 ansible_user=ubuntu

[storage]
st01 ansible_host=192.168.100.207 ansible_user=ubuntu
```

playbook의 `hosts: compute`가 이 파일의 `[compute]` 그룹을 참조한다. Ansible은 이 파일을 보고 어느 IP에 SSH로 접속할지 결정한다.

### Variables (변수)

playbook에서 반복해서 쓰이는 값들을 별도 파일로 관리한다. Kolla-Ansible에서는 `globals.yml`이 이 역할이다.

```yaml
# globals.yml — playbook 전체에서 참조하는 변수들
kolla_internal_vip_address: "192.168.100.200"
network_interface: "ens18"
neutron_external_interface: "ens19"
neutron_plugin_agent: "ovn"
enable_cinder: "yes"
enable_octavia: "yes"
```

playbook 안에서 `{{ network_interface }}`처럼 참조해서 쓴다. 변수 하나만 바꾸면 전체 배포 설정이 바뀐다.

### Role (롤)

**관련된 task들을 묶어놓은 재사용 단위**. Kolla-Ansible은 서비스별로 role이 나뉘어 있다.

```
kolla-ansible/ansible/roles/
  ├── nova/          ← nova 관련 task 모음
  ├── neutron/       ← neutron 관련 task 모음
  ├── cinder/        ← cinder 관련 task 모음
  ├── octavia/       ← octavia 관련 task 모음
  └── ...
```

`kolla-ansible deploy --tags nova`처럼 특정 role만 실행할 수 있다. 전체 재배포 없이 특정 서비스만 업데이트할 때 쓴다.

### Tag (태그)

task나 role에 붙이는 레이블. 특정 태그가 달린 task만 골라서 실행할 수 있다.

```bash
# nova 관련 task만 실행
kolla-ansible deploy -i ~/multinode --tags nova

# octavia만 재설정
kolla-ansible reconfigure -i ~/multinode --tags octavia
```

---

## Kolla-Ansible 핵심 파일

### globals.yml

"무엇을 어떻게 설치할지"를 정의하는 마스터 설정 파일.

```yaml
kolla_base_distro: "ubuntu"
kolla_internal_vip_address: "192.168.100.200"  # HAProxy VIP
network_interface: "ens18"                      # 관리망 NIC
neutron_external_interface: "ens19"             # 외부망 NIC (IP 없음)
neutron_plugin_agent: "ovn"                     # 네트워크 드라이버

enable_haproxy: "yes"      # HA 구성
enable_cinder: "yes"       # 블록 스토리지
enable_cinder_backend_lvm: "yes"
enable_swift: "yes"        # 오브젝트 스토리지
enable_octavia: "yes"      # LBaaS
enable_valkey: "yes"       # Redis 대체 캐시

cinder_volume_group: "cinder-volumes"
```

### multinode

"어느 노드에 어떤 역할을 맡길지"를 정의하는 인벤토리 파일. 그룹 이름이 곧 역할이다.

```
[control]    → Keystone, Nova-API, Neutron, MariaDB, RabbitMQ
[network]    → OVN, DHCP agent
[compute]    → nova-compute, OVS agent
[storage]    → Cinder-volume, Swift
[loadbalancer] → HAProxy, keepalived (VIP 관리)
[monitoring] → Fluentd 로그 수집
```

한 노드가 여러 그룹에 동시에 속할 수 있다. 이 실습에서는 ct01~03이 control + network + loadbalancer를 모두 담당했다.

### passwords.yml

각 서비스의 DB 비밀번호, 토큰, 자격증명 모음. `kolla-genpwd`가 자동으로 무작위 값으로 채워준다.

```bash
kolla-genpwd  # passwords.yml 자동 생성

# 나중에 Horizon 접속 비밀번호 확인할 때
grep keystone_admin_password /etc/kolla/passwords.yml
```

---

## 배포 명령어 순서와 역할

```bash
# 1. Octavia TLS 인증서 생성 (deploy 전에 필요)
kolla-ansible octavia-certificates -i ~/multinode

# 2. 모든 노드에 Docker 설치, 커널 모듈 로드 등 OS 준비
kolla-ansible bootstrap-servers -i ~/multinode

# 3. 사전 검증 — OS 버전, NIC 존재 여부, 그룹 정의 등
kolla-ansible prechecks -i ~/multinode

# 4. 컨테이너 이미지 미리 다운로드
kolla-ansible pull -i ~/multinode

# 5. 실제 배포 (30~60분)
kolla-ansible deploy -i ~/multinode

# 6. admin-openrc.sh 생성
kolla-ansible post-deploy -i ~/multinode

# 특정 서비스만 재설정
kolla-ansible reconfigure -i ~/multinode --tags octavia
```

각 명령어는 내부적으로 서로 다른 playbook을 실행한다. `prechecks`에서 잡은 오류가 `deploy` 중 오류보다 훨씬 디버깅하기 쉽기 때문에 단계를 나눠서 실행한다.

---

## 서비스 설정 오버라이드

컨테이너를 직접 수정하면 `reconfigure` 시 덮어씌워진다. `/etc/kolla/config/` 아래에 파일을 두면 배포 시 컨테이너 내부에 자동으로 주입된다.

```bash
# 예: octavia health-manager 설정 오버라이드
mkdir -p /etc/kolla/config/octavia

cat > /etc/kolla/config/octavia/octavia-health-manager.conf << 'EOF'
[health_manager]
bind_ip = 0.0.0.0
controller_ip_port_list = 10.1.0.74:5555,10.1.0.167:5555,10.1.0.21:5555
EOF

# 설정 반영
kolla-ansible reconfigure -i ~/multinode --tags octavia
```

---

## 수동 설치와 비교

| 항목 | 수동 설치 | Kolla-Ansible |
| --- | --- | --- |
| 네트워크 구성 | brq, vxlan, netns 직접 설정 | `globals.yml` NIC 이름만 적으면 자동 |
| HA 구성 | HAProxy + keepalived 수동 설치 | `enable_haproxy: yes` 한 줄 |
| 서비스 재시작 | 각 노드에 `systemctl` 직접 실행 | `kolla-ansible reconfigure --tags <서비스>` |
| 설정 파일 | `/etc/nova/nova.conf` 등 직접 편집 | `/etc/kolla/config/` 아래에만 오버라이드 |
| 라우터 확인 | `ip netns exec qrouter-... iptables` | `ovn-nbctl show` |
| 멀티노드 | 노드마다 개별 작업 | multinode 인벤토리에 IP 적으면 자동 |
| 컴포넌트 격리 | 시스템에 직접 설치, 의존성 충돌 위험 | Docker 컨테이너, 서비스별 완전 격리 |