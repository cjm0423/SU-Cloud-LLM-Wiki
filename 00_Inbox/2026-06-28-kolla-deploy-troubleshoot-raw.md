---
title: "Kolla-Ansible 배포 트러블슈팅 로그"
type: "raw"
date: 2026-06-28
tags: ["#raw", "#inbox"]
status: "raw"
source: "notion-export"
promoted_to: ""
---
# Kolla-Ansible 배포 트러블슈팅 로그

---

## 0. 환경

| 항목 | 값 |
| --- | --- |
| 배포 도구 | **Kolla-Ansible 22.0.0**, ansible-core **2.19.11** |
| OpenStack 릴리즈 | **2026.1 (Gazpacho)** |
| OS | **Ubuntu 24.04** (22.04에서 전환 — 아래 ① 참고) |
| 호스트 | 공유 Proxmox `pve` (128GB RAM), vmbr0 학교망, Tailscale 외부접근 |
| SDN/대역 | vmnet NAT zone `192.168.100.0/24` |
| 네트워킹 | **OVN** + Geneve (LinuxBridge+VXLAN 수동설치에서 이전) |
| 활성 서비스 | OVN, Cinder LVM, Swift, Octavia |

**노드 배치 (VMID 200~207)**

| 노드 | IP | 역할 | 비고 |
| --- | --- | --- | --- |
| VIP | `192.168.100.200` | Keepalived VIP |  |
| cjm-lb | `.201` | deploy host |  |
| ct01~ct03 | `.202`~`.204` | controller ×3 |  |
| cp01~cp02 | `.205`~`.206` | compute ×2 | CPU type `host` (nested) |
| st01 | `.207` | storage | OS 20G + Cinder 50G(sdb) + Swift 30G(sdc) |
- `ens18`: management, static IP
- `ens19`: **IP 없음**, `neutron_external_interface` (br-ex로 흡수)

---

## 1. 이미지 · 레지스트리 / pre-pull

### 1-1. OS·버전 조합 불일치 → `install-deps` 실패

**증상**: Ubuntu 22.04 + kolla-ansible 19.x로 시작했으나 `install-deps` 단계 실패.
**원인**: kolla-ansible 19.x의 `stable/2024.2` 브랜치가 **EOL로 삭제**되어 의존성 설치가 깨짐.
**해결**: 조합을 **Ubuntu 24.04 + kolla-ansible 22.0.0 + ansible-core 2.19.11 + OpenStack 2026.1(Gazpacho)** 로 전환 → 정상.

> kolla 버전 ↔ OpenStack 릴리즈 ↔ 브랜치 생존여부를 먼저 확인.                                        EOL 삭제된 브랜치를 물면 deps부터 깨진다.
> 

### 1-2. 레지스트리 이미지 — prechecks vs deploy 불일치

**증상**: `quay.io/openstack.kolla` 레지스트리에서 **prechecks**가 이미지 못 찾고 실패.
**원인**: 해당 시점 레지스트리에 정식 태그 이미지가 부족 → prechecks가 통과 못 함.
**해결**:

- **prechecks 단계**에서만 `-use-test-images` 플래그 사용 → 통과
- **deploy 단계**에서는 `-use-test-images` **빼고** 실행 (deploy엔 불필요/부적합)

```bash
# prechecks: 테스트 이미지로 통과
kolla-ansible -i multinode prechecks --use-test-images
# deploy: 플래그 없이
kolla-ansible -i multinode deploy
```

> 핵심: `--use-test-images`는 **prechecks 전용 우회**. deploy까지 끌고 가지 말 것.
> 

### 1-3. pre-pull (이미지 선반입) 패턴

대용량 이미지를 deploy 한 방에 받다 멈추는 걸 피하려면 **pull을 분리**:

```bash
kolla-ansible -i multinode pull          # 전 노드 이미지 선반입
# 노드별 적재 확인
ansible all -i multinode -m shell -a "docker images | grep kolla | wc -l"
kolla-ansible -i multinode deploy        # 그 다음 deploy
```

> ⚠️ 이 pre-pull 단계의 **실제 타임아웃 로그/조치 디테일**이 기록에서 짧게만 잡혔다. 그때 실제로 본 에러 메시지가 있으면 여기에 붙여 확정.
> 

---

## 2. ProxySQL · Keepalived (VIP)

### 2-1. ProxySQL는 결국 **미사용**

**판단**: MariaDB가 **Galera 멀티마스터**라 ProxySQL이 불필요. 연결 분산은 **HAProxy**가 처리.
→ `enable_proxysql` 비활성 방향으로 정리.

### 2-2. check_alive_proxysql.sh 순환 의존 (핵심 이슈)

**증상**: 배포 중 Keepalived의 `check_alive_proxysql.sh` 헬스체크가 실패 → **VIP가 안 붙거나 빠짐**.
**원인 (순환 의존)**:

- Kolla의 keepalived role이 **`enable_proxysql` 설정과 무관하게** `check_alive_proxysql.sh`를 **무조건 생성**
- 배포 도중 ProxySQL이 `-initial` 모드로 떠 있는데 그 뒤의 MariaDB가 아직 없음
- MariaDB는 **VIP가 있어야** 올라오는데, VIP는 이 헬스체크 통과에 묶임 → 서로 물림
- 게다가 **컨테이너 재시작 시 원본 스크립트가 복원**되어 다시 실패

**해결 (워크어라운드)**: deploy 진행 중 keepalived 컨테이너 안의 체크 스크립트를 **주기적으로 `exit 0`으로 덮어쓰기**.

```bash
# deploy 도는 동안 별도 터미널에서 (5초마다 덮어씀)
while true; do
  docker exec keepalived sh -c 'echo "exit 0" > /checks/check_alive_proxysql.sh' 2>/dev/null
  sleep 5
done
# deploy 끝나면 루프 종료(Ctrl+C)
```

> 주의: 이건 **자동 생성되는** 스크립트라 한 번 고치고 끝이 아님. 재시작마다 원복되므로 deploy 동안 루프로 눌러줘야 한다.
> 

### 2-3. rp_filter → VIP 통신 차단

**증상**: VIP가 붙어도 연결이 안 됨.
**원인**: `rp_filter`(reverse path filter) 설정이 VIP 경로 패킷을 드롭.
**해결**: sysctl로 완화 (인터페이스 구성에 맞게 loose/off).

rp_filter(Reverse Path Filtering)는 들어온 패킷의 **출발지 IP로 역방향 경로를 확인**해서, "이 source가 이 인터페이스로 들어오는 게 맞나"를 검사하는 커널 기능이에요. VIP/멀티NIC 환경에서 경로가 비대칭(들어온 인터페이스 ≠ 응답 라우트가 고른 인터페이스)이면 strict 모드가 패킷을 드롭해서, keepalived VIP 통신이 막힌다.

**값 3가지**

| 값 | 의미 |
| --- | --- |
| `0` | off — source 검증 안 함 |
| `1` | strict (RFC 3704) — 응답 라우트가 쓸 인터페이스로 들어와야만 통과. 비대칭이면 드롭 |
| `2` | loose — source가 **아무 인터페이스로든** 도달 가능하면 통과 (VIP 환경 권장) |

```bash
sysctl -w net.ipv4.conf.all.rp_filter=2     # → 환경에 맞춰 loose(2) 또는 off(0)
# 영구화: /etc/sysctl.d/ 에 기록
```

> 우리 케이스는 rp_filter가 VIP를 막던 상태에서 sysctl로 해소. 실제 적용값은 인터페이스 구성에 맞춰 확정.
> 

---

## 3. Octavia (Amphora LBaaS)

> Kolla 환경 기준 정리. (참고: **Kolla/OVN 성공 경로** 중심.)
> 

### 3-0. RabbitMQ stream 큐 이슈 (deploy 단계)

**증상**: `octavia_provisioning_v2_fanout` 큐가 **stream 타입**으로 생성되어 Octavia 동작 이상.
**해결**: 각 controller 호스트의 `/etc/kolla/octavia-*/octavia.conf`에 `rabbit_stream_fanout = false` 설정.

### 3-1. Amphora 이미지 빌드가 조용히 실패

**증상**: `diskimage-create.sh` 실행했는데 이미지가 안 만들어짐 (에러 없이 실패).
**원인**: **`debootstrap` 미설치**.
**해결**: 빌드 의존 패키지 설치 후 재실행 → **361MB qcow2** 생성.

```bash
apt install -y debootstrap qemu-utils git kpartx
cd /tmp/octavia/diskimage-create/
./diskimage-create.sh
```

### 3-2. 이미지 visibility — worker가 못 찾음

**증상**: amphora 이미지를 Glance에 올렸는데 octavia worker가 `ImageGetException`으로 못 찾음.
**원인**: octavia 서비스 계정으로 등록 + `private` visibility라 worker가 접근 불가.
**해결**: visibility를 **`community`** 로 변경 (`--tag amphora` 유지).

```bash
openstack image create amphora-x64-haproxy \
  --file amphora-x64-haproxy.qcow2 --disk-format qcow2 \
  --container-format bare --tag amphora
openstack image set <amphora-id> --community
```

### 3-3. octavia_network_type 기본값 → o-hm0 미생성

**증상**: `hm-interface.yml`이 안 돌아서 `o-hm0` 인터페이스가 안 생김.
**원인**: `octavia_network_type` 기본값 `"provider"`가 hm-interface 단계를 막음.
**해결**: `globals.yml`에 `octavia_network_type: "tenant"` 명시.

### 3-4. octavia_amp_network 타입 오류

**증상**: `object of type 'str' has no attribute 'name'`.
**원인**: `octavia_amp_network`를 **문자열**로 줌.
**해결**: **전체 YAML 딕셔너리**로 작성.

```yaml
# globals.yml — 문자열 X, 딕셔너리 O
octavia_amp_network:
  name: lb-mgmt-net
  provider_network_type: vlan          # 환경값에 맞게
  ...
```

### 3-5. Ubuntu 24.04 dhclient 부재

**증상**: `octavia-interface.service` 시작 실패.
**원인**: Ubuntu 24.04는 **`dhclient` 미포함**.
**해결**: 모든 ct 노드에 `isc-dhcp-client` 설치.

```bash
# ct01~ct03 전부
apt install -y isc-dhcp-client
```

### 3-6. health-manager bind_ip

**증상**: HM가 amphora와 통신 못 함.
**원인**: `bind_ip = 0.0.0.0` 기본값 문제.
**해결**: `/etc/kolla/config/octavia/octavia-health-manager.conf`에서 `controller_ip_port_list`를 **o-hm0 실제 IP**로 지정.

```
# ct01/ct02/ct03 각각의 o-hm0 IP
controller_ip_port_list = 10.1.0.74:5555,10.1.0.167:5555,10.1.0.21:5555
```

### 3-7. 검증 (성공)

- cirros test-vm에서 `nc` 기반 서버는 haproxy 헬스체크에 불안정 → **`busybox httpd`** 사용
- test-vm에서 `curl http://172.22.0.21` → HTTP 응답 확인 = **amphora haproxy 정상 포워딩**
- LB **ACTIVE** 도달

---

## 4. 배포 후 검증 (Phase 4~5 참고)

**Phase 4 — 네트워크 자원**

- external-net(flat, physnet1, `192.168.100.0/24`, pool `.210~.250`)
- internal-net(`172.22.0.0/24`), main-router 연결
- cirros 이미지, m1.tiny flavor, test-sg(ICMP + TCP/22)
- test-vm(cp02) + FIP `192.168.100.243` → `ping 8.8.8.8` / SSH OK

**Phase 5 — OVN flow 검증**

- Gateway Chassis = **ct03** (UUID `60a45818-...-d3d35`)
- ct03 `ens19` tcpdump: OVN router MAC `fa:16:3e:2f:30:1e`로 Proxmox natzone 향해 나감
- OVS는 Geneve(UDP/6081), `br-int`가 brq 대체
- `ovn-nbctl`/`ovn-sbctl`은 **`ovn_northd` 컨테이너 안에서** 실행 (호스트에서 X)

---

## 부록 — 트러블슈팅 요약표

| # | 이슈 | 원인 | 해결 |
| --- | --- | --- | --- |
| ①-1 | install-deps 실패 | kolla 19.x stable/2024.2 EOL 삭제 | Ubuntu 24.04 + kolla 22.0.0 조합 |
| ①-2 | prechecks 이미지 실패 | 레지스트리 정식 태그 부족 | prechecks만 `--use-test-images` |
| ②-2 | VIP 미부착 | keepalived가 check_alive_proxysql.sh 무조건 생성(순환의존) | deploy 중 `exit 0` 루프 덮어쓰기 |
| ②-3 | VIP 통신 차단 | rp_filter | sysctl 조정 |
| ③-0 | Octavia 큐 이상 | fanout 큐 stream 타입 생성 | `rabbit_stream_fanout=false` |
| ③-1 | amphora 빌드 무음 실패 | debootstrap 미설치 | 의존 패키지 설치 후 재빌드 |
| ③-2 | worker 이미지 못 찾음 | private visibility | `community`로 변경 |
| ③-3 | o-hm0 미생성 | network_type 기본 provider | `tenant`로 명시 |
| ③-4 | str attribute 오류 | amp_network 문자열 | YAML 딕셔너리로 |
| ③-5 | octavia-interface 실패 | 24.04 dhclient 부재 | isc-dhcp-client 설치 |
| ③-6 | HM 통신 실패 | bind_ip 0.0.0.0 | controller_ip_port_list = o-hm0 IP |

---