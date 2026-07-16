---
title: "네트워크 경로 진단 — 명령어 & 개념 정리"
type: "raw"
date: 2026-06-21
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[01_Concepts/Network-Path-Diagnosis]]"
---
# 네트워크 경로 진단 — 명령어 & 개념 정리

---

## Part 0. 먼저 잡고 갈 큰 그림 — L2 vs L3

모든 진단 도구의 분기점은 **"이 도구가 L2를 보는가 L3를 보는가"** 다. 여기만 잡으면 "왜 traceroute에 스위치가 안 보이지?" 같은 혼란이 사라진다.

| 계층 | 주소 체계 | 다루는 장비 | 진단 도구 |
| --- | --- | --- | --- |
| **L2 (Data Link)** | MAC 주소 | 스위치, 브리지 | `ip neigh`, `arp-scan`, `lldpctl`, `tcpdump` |
| **L3 (Network)** | IP 주소 | 라우터, L3 스위치 | `traceroute`, `mtr`, `ip route` |

**핵심 규칙: 스위치(L2 장비)는 IP를 라우팅하지 않으므로 L3 도구에 안 보임.**
TL-SG108이나 415호 랙 access 스위치는 패킷의 TTL을 건드리지 않고 그대로 전달만 함. 

그래서 `traceroute`의 hop1이 곧바로 게이트웨이(`.254`)로 나온다. 중간 L2 구간은 **별도의 L2 도구(LLDP)** 로 따로 봐야 함.

```
P520 ── TL-SG108 ── 벽면잭 ── [랙 access SW] ─광─ [백본 L3] ─ .254 ─ 외부
        └──────── L2 구간 (traceroute에 안 보임) ────────┘  └ hop1 ┘
                  ↑ LLDP / ARP 로 식별
```

---

## Part 1. 핵심 개념

### 1.1 백본 (Backbone)

네트워크의 **간선 도로**. 건물·층을 잇는 고용량 회선과 코어 스위치 묶음. 말단(각 방 PC/서버)은 층 스위치 → 백본 → 인터넷 순으로 빠져나간다. 백본이 병목이면 학교 전체가 느려진다. P520도 결국 이 백본을 타고 외부로 나간다.

```
            [인터넷]
               │
        백본 코어 (고속 L3)
      /        |        \
   건물A     건물B     건물C
     │         │         │
  층 스위치 → 방의 PC/서버
```

### 1.2 VLAN (Virtual LAN) — 같은 스위치, 다른 세계

물리적으로 한 스위치에 꽂혀 있어도 **논리적으로 브로드캐스트 도메인을 쪼개는** 기술. VLAN이 다르면 같은 스위치에 있어도 L2로는 서로 못 본다(라우터를 거쳐야 통신).

```
       물리적으로 하나의 스위치
              │
   ├── VLAN 10  교수망
   ├── VLAN 20  학생망
   └── VLAN 30  서버망     ← 서로 L2 격리
```

#### 802.1Q 태그 — VLAN을 구분하는 메커니즘

이더넷 프레임 안에 4바이트짜리 **VLAN 태그(802.1Q)** 를 끼워 넣어서 "이 프레임은 VLAN 30 소속"이라고 표시한다. 이 태그가 있냐 없냐로 포트 성격이 갈린다.

| 포트 모드 | 태그 | 의미 |
| --- | --- | --- |
| **Access** | 태그 없음 | 단 하나의 VLAN만 전달. 일반 PC가 꽂히는 포트 |
| **Trunk** | 802.1Q 태그 있음 | 여러 VLAN을 한 케이블로 동시 전달. 스위치↔스위치, 스위치↔서버 |

> **왜 중요한가**: 운영계 VLAN과 VM 트래픽(여러 VLAN)을 케이블 한 가닥으로 받으려면 그 포트가 **trunk** 여야 한다. 우리 프로젝트 architecture에서 "10GbE 트렁크 → P520"이 바로 이 얘기. access면 VLAN 하나밖에 못 받아서 별도 포트를 요청해야 한다.
> 

### 1.3 패킷 트레이싱 — traceroute는 어떻게 경로를 알아내나

핵심은 **TTL(Time To Live)** 필드를 악용하는 트릭이다.

1. IP 헤더에는 TTL 값이 있다. 라우터를 하나 지날 때마다 **TTL이 1씩 감소**한다.
2. TTL이 0이 되면 그 라우터는 패킷을 버리고 송신자에게 **"ICMP Time Exceeded"** 를 돌려준다.
3. traceroute는 이걸 이용한다 — TTL=1로 보내면 첫 라우터가 응답(=hop1 식별), TTL=2면 두 번째 라우터가 응답(=hop2)... 이렇게 **TTL을 1부터 늘려가며** 경로를 한 hop씩 그려낸다.

```
TTL=1 → 첫 라우터에서 죽음 → "Time Exceeded" 응답 → hop1 = 210.94.240.254
TTL=2 → 두 번째 라우터에서 죽음 → 응답 → hop2 = 백본 L3
TTL=3 → ...
TTL=n → 목적지(8.8.8.8) 도달 → "Port Unreachable"(UDP) → 끝
```

**hop이 많을수록 지연(latency)이 누적된다.** 어느 구간에서 느려지는지를 hop별 RTT로 짚어낼 수 있다.

#### `* *` (별표)는 장애가 아닐 수 있다

중간 hop이 `* * *`로 나와도 **목적지까지 도달하면 정상**이다. 그 라우터가 보안상 ICMP Time Exceeded를 안 보내도록 설정됐을 뿐, 패킷은 통과하고 있다. **목적지를 포함해 그 지점 이후 전부 `* * *`** 이면 그제서야 진짜 차단이다.

```
hop1: 210.94.240.254   ← 정상
hop2: * * *            ← 이 라우터가 ICMP 응답만 안 함 (통과는 됨)
hop3: * * *
hop4: 8.8.8.8          ← 목적지 도달 → 전체 정상
```

### 1.4 LLDP — 바로 위 L2 스위치 식별

**Link Layer Discovery Protocol.** L2 장비들이 "나는 어느 스위치의 어느 포트다"를 약 30초 주기로 멀티캐스트 방송하는 프로토콜. IP 없이 이더넷 레벨에서 동작하므로 **L3 도구로 안 보이는 물리 연결을 알아내는 유일한 수단**에 가깝다.

```
P520 ── TL-SG108 ── 벽면잭 ── [랙 스위치]
                              └ "나는 core-sw-415의 Gi0/12다" 라고 광고
                                → P520이 lldpctl로 수신 → 물리 연결 확정
```

- 잡히면: 415호 어느 스위치·포트인지 자동 파악 → 전산실 질문 절반 해결.
- 안 잡히면: TL-SG108이 unmanaged라 LLDP 프레임을 흘려보냈거나, 스위치가 LLDP off. → 케이블 toner 추적 또는 전산실 문의.
- 참고: Cisco는 LLDP 대신 독자 프로토콜 **CDP**(멀티캐스트 `01:00:0c:cc:cc:cc`)를 쓰기도 해서, tcpdump로 둘 다 잡는다.

### 1.5 NAT / conntrack — 사설망이 인터넷에 나가는 원리

VM망(`192.168.100.0/24`)은 사설 대역이라 인터넷에서 라우팅이 안 된다. 그래서 호스트가 **SNAT(Source NAT)** 으로 출발지 IP를 공인 IP로 바꿔서 내보낸다.

```
VM 192.168.100.11 ──[패킷: src=192.168.100.11]──▶ 호스트
호스트가 SNAT ──[src=210.94.240.179 로 변경]──▶ 인터넷
응답 돌아옴 ──[dst=210.94.240.179]──▶ 호스트
호스트가 역변환 ──[dst=192.168.100.11 로 복원]──▶ VM
```

이 "누가 무엇을 무엇으로 바꿨는지"의 매핑 상태를 커널이 **conntrack(connection tracking)** 테이블로 들고 있다. `conntrack -L`로 이 변환 세션을 직접 볼 수 있다 — 프로젝트에서 이미 VXLAN 환경 패킷 캡처로 검증한 그 흐름이다.

### 1.6 MTU — OVN/터널 환경에서 꼭 따라오는 함정

이더넷 표준 MTU는 1500바이트. 그런데 Geneve/VXLAN 터널은 원본 패킷을 한 번 더 감싸므로 헤더 오버헤드(Geneve ≈ 58B)가 붙는다. VM MTU를 그대로 1500으로 두면 캡슐화 후 1500을 초과해 단편화/드롭이 난다 → VM MTU를 **약 1442**로 낮춰야 한다. 진단 시 "ping은 되는데 큰 패킷만 안 간다"면 MTU를 의심.

---

## Part 2. 명령어 레퍼런스 (계층별)

### 2.1 내 위치 확정 — `ip` 계열 (L2 + L3 상태)

```bash
ip -br link            # NIC 목록 (brief)
ip -br addr            # 인터페이스별 IP 할당
ip route               # 라우팅 테이블 전체
ip route get 8.8.8.8   # 특정 목적지로 갈 때 커널이 실제 선택할 경로
ip neigh               # ARP 테이블 (L2 이웃의 IP↔MAC)
```

| 명령 | 무엇을 보나 | 읽는 법 |
| --- | --- | --- |
| `ip -br link/addr` | NIC와 붙은 IP | 어떤 인터페이스가 살아있고 IP가 뭔지 |
| `ip route` | 라우팅 정책 | `default via 210.94.240.254 dev eno1` 보이면 기본 경로 정상 |
| `ip route get` | **실제 선택 경로** | 단순 조회가 아니라 커널에게 직접 물음. src/iface/gw를 한 줄로 |
| `ip neigh` | ARP 캐시 | gw(`.254`)의 MAC이 보이면 L2 연결 정상 |

```
# ip route get 출력 예
8.8.8.8 via 210.94.240.254 dev eno1 src 210.94.240.179
         └ 게이트웨이        └ 나가는 NIC  └ 내 출발지 IP
```

```bash
curl -4 --max-time 8 https://ifconfig.me   # 외부에서 보이는 내 공인 IP
```

- 내 IP == ifconfig.me → **공인 IP 직결**(provider network 후보로 좋음)
- 내 IP 사설 / ifconfig.me 다른 공인 → **NAT 뒤**

### 2.2 아웃바운드 L3 — `traceroute` / `mtr`

방화벽이 프로토콜별로 다르게 통과시키므로 **모드 전환이 핵심.**

```bash
traceroute -n 8.8.8.8                 # 기본 UDP, -n=DNS 역조회 생략(빠름)
sudo traceroute -n -I 8.8.8.8         # ICMP echo (UDP 막힐 때, ping과 같은 프로토콜)
sudo traceroute -n -T -p 443 8.8.8.8  # TCP SYN to 443 (방화벽 우회 최강)
traceroute -n -A 8.8.8.8              # 각 hop의 AS 번호 (어느 사업자망 경유)
```

| 모드 | 옵션 | 언제 |
| --- | --- | --- |
| UDP | (기본) | 1차 시도 |
| ICMP | `-I` | UDP가 `* * *`로 다 막힐 때 |
| TCP443 | `-T -p 443` | UDP·ICMP 다 막혀도 HTTPS는 보통 열림 → 최후 수단 |
| AS | `-A` | 학교망→KT→Google 경유 사업자 확인 |

> **진단 포인트**: UDP는 막히는데 `-T -p 443`만 뚫리면 → 방화벽이 443만 허용. 이건 서비스 포트 정책 설계에 직접 반영된다.
> 

```bash
mtr -n -r -c 100 8.8.8.8            # 100회 반복, hop별 Loss%/Avg ms 통계
mtr -n -r -c 50 210.94.240.254     # 게이트웨이 구간 품질만 (외부 변수 제거)
```

`mtr`은 traceroute를 반복 측정해 **구간별 손실률·지연 통계**를 낸다. `-r`=리포트 모드(1회 출력 후 종료), `-c N`=N회.

**Loss% 읽는 법**

- 중간 hop만 Loss↑ + 마지막 hop 0% → ICMP rate-limit일 뿐, **실손실 아님(무시)**
- 특정 hop부터 끝까지 Loss↑ → **그 hop부터 진짜 문제**

### 2.3 L2 상위 식별 — `lldpctl` / `tcpdump` (가장 중요)

```bash
sudo apt-get install -y lldpd && sudo systemctl restart lldpd
sleep 40          # LLDP 광고 주기(~30s)보다 길게 대기
lldpctl           # SysName(스위치)/PortID(포트)/VLAN 확인
```

```
# lldpctl 출력 예
Interface: eno1, via: LLDP
  Chassis:
    SysName: core-sw-415          ← 연결된 스위치 이름
    SysDescr: Cisco Catalyst 2960
  Port:
    PortID: GigabitEthernet0/12   ← 내가 꽂힌 스위치 포트
    VLAN:   100                   ← 이 포트의 VLAN
```

데몬 없이 프레임만 직접 캡처:

```bash
sudo tcpdump -i eno1 -nn -e -v \
  '(ether proto 0x88cc) or (ether dst 01:00:0c:cc:cc:cc)'
#                  └ LLDP 이더타입        └ Cisco CDP 멀티캐스트
```

- `e`=L2 헤더(MAC)까지 출력, `nn`=이름/포트 숫자로, `0x88cc`=LLDP, CDP는 멀티캐스트 MAC으로 필터. **둘을 OR로 묶어 LLDP·CDP 동시 포착.**

### 2.4 VLAN 성격 판정 — access vs trunk

```bash
# (1) passive: 태그 붙은 프레임이 들어오나 그냥 보기만
sudo tcpdump -i eno1 -e -nn -c 50 vlan

# (2) active: 승인된 VID로만 subinterface 만들어 IP 받아보기
sudo ip link add link eno1 name eno1.100 type vlan id 100
sudo ip link set eno1.100 up
sudo dhclient -v eno1.100     # IP 받으면 그 VLAN이 trunk로 내려온다는 뜻
sudo ip link del eno1.100     # ★ 테스트 후 반드시 삭제
```

- passive에서 태그 안 보임 → access 가능성 / 특정 VID 보임 → trunk
- subinterface로 IP가 할당되면 그 VLAN이 trunk로 실제 내려오는 것 확정
- **subinterface는 테스트 후 꼭 `ip link del`. 안 지우면 의도치 않은 트래픽 발생.**

### 2.5 호스트 내부 NAT / 포워딩

```bash
sudo iptables -t nat -L -n -v   # NAT 규칙 (SNAT/DNAT/MASQUERADE)
sudo nft list table ip nat      # nftables 환경 (최신 커널)
sudo conntrack -L               # 현재 NAT 변환 세션 (실시간)
ss -tunap                       # 듣는/연결된 소켓 (-t TCP -u UDP -n 숫자 -a 전체 -p 프로세스)
```

```
# iptables -t nat 에서 보고 싶은 줄
Chain POSTROUTING
MASQUERADE  all  192.168.100.0/24  anywhere   ← VM망 → 공인 IP SNAT 규칙
```

```
# conntrack -L 변환 세션 읽는 법
tcp ESTABLISHED
  src=192.168.100.2 dst=8.8.8.8       sport=54321 dport=443   ← 원본
  src=8.8.8.8       dst=210.94.240.179 sport=443 dport=54321  ← 변환 후(SNAT)
  └ VM가 보낸 패킷이 공인 IP로 바뀐 세션
```

| 명령 | 역할 |
| --- | --- |
| `iptables -t nat` / `nft list table ip nat` | NAT **규칙**(정책) 확인. Proxmox는 둘 혼재 가능 → 양쪽 다 봄 |
| `conntrack -L` | NAT **세션**(실제 동작) 확인. 규칙이 의도대로 도는지 변환항목으로 검증 |
| `ss -tunap` | 어떤 서비스가 어느 IP:포트에서 듣는지, 의도치 않은 포트 안 열렸는지 |

실시간 패킷 경로 추적(디버깅 막혔을 때):

```bash
sudo nft add table inet trace_tbl
sudo nft add chain inet trace_tbl prerouting \
  '{ type filter hook prerouting priority -300; }'
sudo nft add rule inet trace_tbl prerouting ip protocol icmp meta nftrace set 1
sudo nft monitor trace
sudo nft delete table inet trace_tbl   # ★ 반드시 정리
```

### 2.6 Inbound 검증 — `.179/.180`이 진짜 돌아오는가

> **핵심: 관측 지점(vantage)을 반드시 학교망 *밖*에 둔다.** 나가는 건 돼도 외부→우리 경로가 없으면 공인 IP는 무의미. 캠퍼스망 안에서 자기 IP로 traceroute 하면 내부 경로를 타서 검증이 안 됨.
> 

```bash
# (학교망 밖 = 클라우드 VM / LTE 테더링 등에서)
mtr -n -r -c 50 210.94.240.179
traceroute -n -T -p 443 210.94.240.180

# 도달성 최종 확인: P520에 잠깐 서버 띄우고 외부에서 curl
#   P520:  sudo python3 -m http.server 80 --bind 210.94.240.180
#   외부:  curl -v http://210.94.240.180/      # 응답 오면 inbound 완전 동작
```

- 외부→`.180`이 `.254` 부근까지 옴 → inbound route 살아있음
- 마지막 1~2 hop에서 멈춤 → 방화벽/ARP 정책 차단 → 전산실 inbound 정책 질의
- **비대칭 경로 주의**: 도달성은 오직 "외부→우리" 방향 결과로만 판단. 나가는 경로와 들어오는 경로는 다를 수 있다.
- 임시 `http.server`는 확인 즉시 종료.

---

## Part 3. 계층별 도구 한눈에

| 보고 싶은 것 | 계층 | 도구 | 한계 |
| --- | --- | --- | --- |
| 내 IP/라우팅/실제 경로 | L3 | `ip addr/route/route get` | 호스트 로컬만 |
| 외부 L3 경로 | L3 | `traceroute`, `mtr` | L2 안 보임, ICMP 차단 시 별표 |
| 경로 품질(손실/지연) | L3 | `mtr -r -c` | hop별 rate-limit 주의 |
| 바로 위 L2 스위치 | L2 | `lldpctl`, `tcpdump` | 스위치 LLDP off면 안 보임 |
| 같은 L2 이웃 | L2 | `ip neigh`, `arp-scan -l` | 브로드캐스트 도메인 한정 |
| VLAN 태그 유무 | L2 | `tcpdump ... vlan` | 태그 트래픽 없으면 판정 불가 |
| `.179/.180` inbound | L3 | **외부** vantage→우리 | 비대칭 경로·방화벽 |
| 호스트 NAT 경로 | L3/L4 | `conntrack`, `nft`, `iptables -t nat` | 호스트 내부만 |

---

## Part 4. 자주 막히는 것

| 증상 | 원인 | 대응 |
| --- | --- | --- |
| traceroute 전부 `* * *` | UDP 차단 | `-I` → `-T -p 443` 순서로 |
| 스위치가 hop에 없음 | L2 장비는 traceroute에 안 나옴 | 정상. LLDP로 확인 |
| LLDP 무응답 | unmanaged 스위치 / LLDP off | 케이블 toner 추적·전산실 |
| mtr 중간 hop만 Loss↑ | ICMP rate-limit | 마지막 0%면 무시 |
| 나가는 건 되는데 외부→`.180` 안 옴 | inbound 방화벽/route | 전산실 inbound 정책 질의 |
| conntrack에 변환 없음 | NAT 규칙 미매칭 | 조건/iface 재확인 |
| ping은 되는데 큰 패킷만 드롭 | 터널 MTU 초과 | VM MTU ~1442로 |

---

## Part 5. 권한 경계 (작업 전 필독)

원칙: **"내 서버에서 바깥으로 나가는 경로 관측"은 OK. "남의 호스트를 훑는 것"은 승인 전까지 금지.**

| 등급 | 작업 | 협의 |
| --- | --- | --- |
| 🟢 안전 | 내 호스트 ip/route/neigh, 알려진 목적지 traceroute/mtr, passive tcpdump, 내 호스트 conntrack/nat 관찰 | 불필요(기록만) |
| 🟡 주의 | 상위 스위치 포트모드/VLAN 변경, VLAN subif 테스트, 케이블 추적 | 전산실/조교 협의 |
| 🔴 금지 | 타 망 호스트 능동 포트스캔(`nmap -p-`), 서비스 enum, 임의 VLAN 스위핑 | 전산실 승인 필수 |

[SU Cloud — 학내망 경로 추적 Runbook](%EB%84%A4%ED%8A%B8%EC%9B%8C%ED%81%AC%20%EA%B2%BD%EB%A1%9C%20%EC%A7%84%EB%8B%A8%20%E2%80%94%20%EB%AA%85%EB%A0%B9%EC%96%B4%20&%20%EA%B0%9C%EB%85%90%20%EC%A0%95%EB%A6%AC/SU%20Cloud%20%E2%80%94%20%ED%95%99%EB%82%B4%EB%A7%9D%20%EA%B2%BD%EB%A1%9C%20%EC%B6%94%EC%A0%81%20Runbook%20388d8e51100c808f8b87c8efcbde5686.md)