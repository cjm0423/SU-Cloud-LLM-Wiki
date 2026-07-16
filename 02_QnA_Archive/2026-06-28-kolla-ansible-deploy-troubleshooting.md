---
title: "Kolla-Ansible 배포 트러블슈팅 로그 (Ubuntu 24.04 + OpenStack Gazpacho)"
type: "qa"
date: 2026-06-28
tags: ["#kolla-ansible", "#openstack", "#troubleshooting", "#ovn", "#octavia"]
related_nodes: ["[[03_Guides/Kolla-Ansible-Install-Guide]]", "[[01_Concepts/OVN-OVS-Architecture]]", "[[01_Concepts/Kolla-Ansible]]"]
author: "AI Assistant"
status: "resolved"
raw_source: "[[00_Inbox/2026-06-28-kolla-deploy-troubleshoot-raw]]"
---

# Kolla-Ansible 배포 트러블슈팅 로그 (Ubuntu 24.04 + OpenStack Gazpacho)

## 1. ❓ 질의 및 배경 (Context)

- **환경:** Kolla-Ansible 22.0.0, ansible-core 2.19.11, OpenStack 2026.1 (Gazpacho), Ubuntu 24.04
- **노드:** VIP(.200) + LB(.201) + Controller 3대(.202~.204) + Compute 2대(.205~.206) + Storage 1대(.207)
- **네트워킹:** OVN + Geneve, Cinder LVM, Swift, Octavia

## 2. 🧠 분석 및 추론 (Analysis) — 이슈별 원인

### ①-1. OS·버전 조합 불일치 → install-deps 실패
- kolla-ansible 19.x `stable/2024.2` 브랜치가 EOL로 삭제되어 의존성 설치 실패
- **핵심**: kolla 버전 ↔ OpenStack 릴리즈 ↔ 브랜치 생존 여부를 먼저 확인해야 함

### ①-2. prechecks 이미지 실패
- `quay.io/openstack.kolla` 레지스트리에 정식 태그 이미지 부족 → prechecks 실패
- deploy 단계와 prechecks 단계에서 플래그 구분 필요

### ②-2. VIP 미부착 (핵심 이슈)
- Kolla의 keepalived role이 `enable_proxysql` 설정과 무관하게 `check_alive_proxysql.sh`를 무조건 생성
- MariaDB는 VIP가 있어야 올라오는데, VIP는 이 헬스체크 통과에 묶임 → **순환 의존**
- 컨테이너 재시작 시 원본 스크립트가 복원되어 반복 발생

### ②-3. rp_filter → VIP 통신 차단
- strict 모드(=1)에서 비대칭 라우팅 환경의 VIP 패킷 드롭

### ③ Octavia 관련 다수 이슈
- RabbitMQ stream 큐 타입 문제, debootstrap 미설치, 이미지 visibility, dhclient 부재 등

## 3. 💡 해결책 및 결과 (Solution)

### ①-1. 버전 조합 변경
```bash
# Ubuntu 24.04 + kolla-ansible 22.0.0 + ansible-core 2.19.11 + OpenStack 2026.1(Gazpacho)로 전환
```

### ①-2. prechecks/deploy 플래그 분리
```bash
kolla-ansible -i multinode prechecks --use-test-images   # prechecks만
kolla-ansible -i multinode deploy                        # deploy: 플래그 없이
```

### ①-3. pre-pull 패턴
```bash
kolla-ansible -i multinode pull
ansible all -i multinode -m shell -a "docker images | grep kolla | wc -l"
kolla-ansible -i multinode deploy
```

### ②-2. check_alive_proxysql.sh 순환 의존 우회
```bash
# deploy 도는 동안 별도 터미널에서 5초마다 덮어씀
while true; do
  docker exec keepalived sh -c 'echo "exit 0" > /checks/check_alive_proxysql.sh' 2>/dev/null
  sleep 5
done
```
> ⚠️ 재시작마다 원복되므로 deploy 동안 루프로 계속 눌러줘야 함

### ②-3. rp_filter 완화
```bash
sysctl -w net.ipv4.conf.all.rp_filter=2   # loose 모드
```

### ③-0. RabbitMQ stream 큐
```ini
# /etc/kolla/octavia-*/octavia.conf
rabbit_stream_fanout = false
```

### ③-1. Amphora 빌드
```bash
apt install -y debootstrap qemu-utils git kpartx
./diskimage-create.sh   # → 361MB qcow2 생성
```

### ③-2. Amphora 이미지 visibility
```bash
openstack image set <amphora-id> --community
```

### ③-3. octavia_network_type
```yaml
# globals.yml
octavia_network_type: "tenant"
```

### ③-5. dhclient 부재 (Ubuntu 24.04)
```bash
apt install -y isc-dhcp-client   # ct01~ct03 전부
```

### ③-6. health-manager bind_ip
```ini
controller_ip_port_list = 10.1.0.74:5555,10.1.0.167:5555,10.1.0.21:5555
```

## 4. 🔗 추가 통찰 (Insights & Next Steps)

### 트러블슈팅 요약표

| # | 이슈 | 원인 | 해결 |
|---|------|------|------|
| ①-1 | install-deps 실패 | kolla 19.x stable/2024.2 EOL | Ubuntu 24.04 + kolla 22.0.0 |
| ①-2 | prechecks 이미지 실패 | 레지스트리 정식 태그 부족 | prechecks만 `--use-test-images` |
| ②-2 | VIP 미부착 | keepalived 순환 의존 | deploy 중 `exit 0` 루프 |
| ②-3 | VIP 통신 차단 | rp_filter strict | sysctl loose(2) |
| ③-0 | Octavia 큐 이상 | fanout 큐 stream 타입 | `rabbit_stream_fanout=false` |
| ③-1 | amphora 빌드 무음 실패 | debootstrap 미설치 | 패키지 설치 |
| ③-2 | worker 이미지 못 찾음 | private visibility | community로 변경 |
| ③-3 | o-hm0 미생성 | network_type=provider | tenant로 명시 |
| ③-5 | octavia-interface 실패 | 24.04 dhclient 부재 | isc-dhcp-client 설치 |
| ③-6 | HM 통신 실패 | bind_ip 0.0.0.0 | o-hm0 IP 명시 |

### 최종 검증 결과
- Gateway Chassis = ct03, OVS Geneve(UDP/6081), br-int가 brq 대체
- test-vm FIP `192.168.100.243` → ping 8.8.8.8 / SSH OK
- LB ACTIVE, amphora haproxy 정상 포워딩 확인
