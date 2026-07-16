---
title: "개발계(180) 인터넷 불가 — 원인 전수 조사 및 실행 런북"
type: "raw"
date: 2026-07-05
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[02_QnA_Archive/2026-07-05-devpc-180-internet-outage-runbook]]"
---
# 개발계(.180) 인터넷 불가 — 원인 전수 조사 및 실행 런북

작성: 2026-07-06 / 목적: 특정 가설(MAC 필터링)에 꿰맞추지 않고, 가능한 모든 원인을 계층별로 나열한 뒤 하나씩 확정/배제한다.
원칙: 한 번에 변수 하나만 바꾼다. 결론은 전수 조사가 끝난 뒤, 남은 것으로 내린다.

---

## 0. 지금까지 실측으로 이미 배제된 것 (재검증 불필요)

| 항목 | 상태 | 근거 |
| --- | --- | --- |
| 1820 스위치 자체 (경유 여부) | 배제 | 벽포트72 직결해도 동일 증상 |
| STP 재계산 지연 | 배제 | GUI에서 Spanning Tree: Disabled 확인 |
| Speed/Duplex mismatch | 배제 | ethtool: 1000Mb/s Full 확인 |
| 링크 물리 단선 (첫 조사 시점) | 배제 가능성 높음 | LOWER_UP 상태 유지, 링크 LED 정상 |
| Proxy ARP (게이트웨이 자체가 대리응답) | 배제 | 신선한 조회로 게이트웨이 MAC 00-31-46-5b-d4-80 확정, 68:ed:a4는 무관 |
| 노트북 하드웨어/드라이버 자체 문제 | 배제 | 노트북은 같은 .180 IP로 정상 통신 성공 |

아직 검증 안 됨 (이번 런북의 핵심 공백): 방화벽/커널 필터링, netplan 설정 파일 자체의 무결성, 라우팅 테이블 중복, 설치 시점 인터넷 연결 여부.

---

## 1. 원인 전수 분류표 (계층별 전체 후보)

### A. 하드웨어 계층

- A1. NIC 자체 고장/미인식
- A2. 케이블 불량
- A3. 1820 스위치 포트 물리적 불량
- A4. 벽포트/캠퍼스 포트 물리적 불량

### B. OS/드라이버 계층

- B1. NIC 드라이버 미탑재/오작동 (r8169 로드 실패 등)
- B2. 인터페이스 자체가 admin-down
- B3. netplan 설정 파일 문법 오류로 의도와 다르게 적용됨 (미검증)
- B4. systemd-networkd가 설정을 제대로 반영 못 함 (미검증)

### C. IP/라우팅 설정 계층 (로컬 설정 실수)

- C1. 서브넷 마스크 오기입
- C2. 게이트웨이 주소 오기입
- C3. 라우팅 테이블 중복/충돌 (default route 2개, 잘못된 metric) (미검증)
- C4. MTU 불일치 (jumbo frame 9194로 설정된 이력 있음, 확인 필요)
- C5. DNS 설정 (ping IP 테스트엔 무관하지만 완전성을 위해 포함)

### D. 로컬 방화벽/커널 필터링 계층 — 지금까지 전혀 확인 안 한 영역

- D1. ufw 활성화 + 아웃바운드 차단 규칙
- D2. iptables/nftables 수동 규칙으로 차단
- D3. sysctl rp_filter 설정 (운영계 구축 시 이 값을 만졌던 이력이 있음 — 개발계에도 잘못 적용/미적용됐을 가능성)

### E. L2 스위치(1820, 우리 소유) 계층

- E1. Port Security/Sticky MAC 위반으로 포트 disable
- E2. VLAN 설정 불일치
- E3. 포트 자체가 admin-down으로 설정
- E4. Speed/Duplex mismatch (배제됨, 표 0 참고)

### F. L2 캠퍼스 스위치(EX3300) 계층

- F1. 포트 보안/Sticky MAC
- F2. DHCP Snooping + IP Source Guard / Dynamic ARP Inspection — 정적 IP가 스누핑 테이블에 없어 차단 (신규 유력 후보, 아래 설명 참고)
- F3. VLAN 태깅 불일치
- F4. ACL로 특정 MAC/IP 차단

### G. L3 게이트웨이/라우터 계층

- G1. 라우터 ACL로 특정 MAC/IP 차단
- G2. Proxy ARP 착시 (배제됨, 표 0 참고)
- G3. NAT/PAT 테이블 미등록

### H. 캠퍼스 네트워크 등록 시스템 계층

- H1. MAC/IP 사전 등록제 (신청 안 하면 라우팅 자체 불가)
- H2. 802.1X 인증 미완료
- H3. NAC(Network Access Control) 미승인 기기

### I. IP 충돌/경쟁 계층

- I1. 동일 IP를 다른 기기(Seavo 68:ed:a4 등)가 사용 중
- I2. ARP 캐시 오염/중복 응답

---

## F2 상세 설명 — DHCP Snooping / IP Source Guard (신규 유력 후보)

Juniper EX3300 같은 엔터프라이즈 스위치는 보안 기능으로 다음을 자주 씁니다.

1. DHCP Snooping: 스위치가 DHCP로 정상 할당된 IP-MAC-포트 조합만 신뢰할 수 있는 바인딩으로 기록.
2. IP Source Guard: 이 바인딩 테이블에 없는 IP-MAC 조합으로 나가는 패킷은 하드웨어 레벨에서 드롭.
3. Dynamic ARP Inspection(DAI): 마찬가지로 바인딩 테이블 기준으로 ARP 패킷도 검증.

이 조합이 걸려있으면 정확히 지금 증상과 일치합니다.

- 개발계 서버는 IP를 DHCP로 받은 게 아니라 정적(static)으로 직접 박았기 때문에 스위치의 신뢰 바인딩 테이블에 존재하지 않음 → 트래픽이 스위치 하드웨어 단에서 조용히 drop.
- 반면 노트북이 어떻게 정상 통신됐는지는 노트북도 static IP였다면 설명이 애매해지므로, 이 가설이 맞다면 "노트북도 원래는 DHCP로 먼저 붙었다가 static으로 전환했을 가능성"을 확인해야 함 (아래 5번 항목).
- 캠퍼스팀에 문의할 때 "DHCP Snooping / IP Source Guard 설정 여부, 개발계 서버 IP-MAC 바인딩 예외 등록 요청"으로 구체적으로 질문 가능해짐 (막연한 "MAC 등록해주세요"보다 훨씬 정확한 요청).

---

## 2. 실행 순서 (미검증 항목부터 우선)

### ~~Step 1 — 로컬 방화벽/커널 필터링 확인 (D1~D3, 5분 이내, 가장 먼저)~~

```
sudo ufw status verbose
sudo iptables -L -n -v --line-numbers
sudo iptables -t nat -L -n -v
sudo nft list ruleset
sysctl net.ipv4.conf.all.rp_filter
sysctl net.ipv4.conf.default.rp_filter
sysctl net.ipv4.conf.enp7s0f0.rp_filter
cat /etc/sysctl.d/*.conf 2>/dev/null | grep -i rp_filter
```

판단: ufw가 active이고 outgoing deny 규칙이 있거나, iptables/nft에 DROP/REJECT 규칙이 있으면 로컬 방화벽이 범인. rp_filter가 0이 아니고 비대칭 라우팅 상황이면 자체 패킷을 drop할 수 있음(strict mode에서 흔함).

### ~~Step 2 — netplan 설정 파일 원본 확인 (B3, B4)~~

```
cat /etc/netplan/*.yaml
sudo netplan apply
networkctl status enp7s0f0
resolvectl status enp7s0f0
```

판단: YAML 들여쓰기 오류, addresses 항목 오타, dhcp4: true와 static이 동시에 잘못 설정된 경우 등이 있는지 육안 확인. networkctl 출력에서 상태가 routable인지 degraded인지 확인.

### ~~Step 3 — 라우팅 테이블 중복 확인 (C3)~~

```
ip route show
ip route show table all
ip rule show
```

판단: default route가 두 개 이상 있거나, 이상한 metric/scope가 잡혀있으면 트래픽이 엉뚱한 인터페이스로 나갈 수 있음.

### ~~Step 4 — 우분투 설치 시점에 인터넷이 실제로 됐었는지 확인~~

중요: 이건 하드웨어/드라이버/케이블/스위치포트가 애초부터 멀쩡했는지를 가르는 결정적 증거가 됩니다. 설치 시점엔 인터넷이 됐다면 A(하드웨어), 상당수 B(드라이버) 항목을 통째로 배제할 수 있습니다.

```
journalctl --list-boots

journalctl -b <가장_오래된_인덱스> | grep -iE "dhcp|carrier|enp7s0f0|link is|networkd"

ls -la /var/log/installer/ 2>/dev/null
sudo grep -iE "network|dhcp|http|archive.ubuntu" /var/log/installer/*.log 2>/dev/null | tail -80

cat /var/log/apt/history.log 2>/dev/null | head -40
```

판단:

- journalctl --list-boots에서 로그가 1개(현재 부팅)만 있다면 persistent journal이 꺼져있어서 설치 시점 로그 자체가 사라진 것. 이 경우 이 방법으로는 증명 불가, Step6으로.
- 설치 로그나 apt history에 실제 archive.ubuntu.com 접속 성공 기록이 있다면 그 시점엔 100% 인터넷이 됐다는 확정적 증거. 이러면 문제는 "하드웨어가 원래부터 고장"이 아니라 "그 이후 뭔가(설정 변경, 캠퍼스 등록 만료/변경 등)가 바뀌었다"로 좁혀짐.
- 접속 실패 흔적만 있다면(오프라인 설치였다면) 이 검증 자체가 무의미, 설치 시점 상태는 알 수 없음.

### ~~Step 5 — (참고) 노트북도 원래 DHCP였는지 확인~~

노트북이 처음부터 static .180이었는지, 아니면 DHCP로 먼저 뭔가를 받은 이력이 있었는지 기억을 더듬어 주세요. F2(DHCP Snooping) 가설을 검증하는 데 필요합니다. 노트북도 순수 static이었는데 통과됐다면 F2 가설은 약해지고, 다시 MAC 화이트리스트(H1) 쪽에 무게가 실립니다.

### Step 6 — MAC 스푸핑 교차 검증 (가장 결정적)

```
sudo ip link set enp7s0f0 down
sudo ip link set enp7s0f0 address b0:38:6c:e1:a9:7f
sudo ip link set enp7s0f0 up
sudo ip neigh flush dev enp7s0f0
ping -c 5 210.94.240.254
ping -c 5 8.8.8.8

# 테스트 후 반드시 원복
sudo ip link set enp7s0f0 down
sudo ip link set enp7s0f0 address 88:ae:dd:5d:00:28
sudo ip link set enp7s0f0 up
```

판단: 이걸로 통신되면 하드웨어/드라이버/케이블/포트/netplan/방화벽 전부 무죄, 순수하게 MAC 기반 필터링(F1/F2/H1) 확정.

![IMG_9088.jpeg](%EA%B0%9C%EB%B0%9C%EA%B3%84(%20180)%20%EC%9D%B8%ED%84%B0%EB%84%B7%20%EB%B6%88%EA%B0%80%20%E2%80%94%20%EC%9B%90%EC%9D%B8%20%EC%A0%84%EC%88%98%20%EC%A1%B0%EC%82%AC%20%EB%B0%8F%20%EC%8B%A4%ED%96%89%20%EB%9F%B0%EB%B6%81/IMG_9088.jpeg)

---

## 3. 결과 기록표

| 단계 | 항목 | 결과 | 배제/확정 |
| --- | --- | --- | --- |
| 1 | ufw/iptables/nft |  |  |
| 1 | rp_filter 값 |  |  |
| 2 | netplan 파일 내용 |  |  |
| 2 | networkctl 상태 |  |  |
| 3 | 라우팅 테이블 중복 |  |  |
| 4 | journalctl 부팅 로그 개수 |  |  |
| 4 | 설치 로그 네트워크 흔적 |  |  |
| 4 | apt history 시각 |  |  |
| 5 | 노트북 원래 DHCP 여부 (기억) |  |  |
| 6 | MAC 스왑 후 통신 여부 |  |  |
| 7 | tcpdump ARP/ICMP 왕복 |  |  |
| 8 | 1820 Port Security 상태 |  |  |

---

## 4. 최종 결론 도출 로직

```
Step1(방화벽) 문제 있음? YES: 로컬 문제, 종료. NO: 다음
Step2(netplan) 문법 오류? YES: 로컬 문제, 종료. NO: 다음
Step3(라우팅 중복)? YES: 로컬 문제, 종료. NO: 다음
Step4(설치시점 인터넷 됐음이 확인됨)? YES: 하드웨어/드라이버 배제 확정 다음
Step6(MAC 스왑 시 결과 뒤집힘)?
  YES: MAC 기반 필터링 확정
    Step7에서 ARP는 통과, ICMP만 막힘?
      YES: F2(IP Source Guard/DHCP Snooping) 또는 G1(ACL) 의심
      NO(ARP도 안됨): E1/F1(Port Security/Sticky MAC) 의심
  NO(결과 안 바뀜): MAC 문제 아님, A(하드웨어) 재의심, 다른 NIC/포트로 전체 교체 테스트 필요
```

---

## 5. 캠퍼스팀 제출용 요약 템플릿 (실험 후 채워넣기)

개발계 서버(MAC 88:ae:dd:5d:00:28)가 정적 IP 210.94.240.180으로 게이트웨이(254)/외부 통신이 전혀 안 되는 문제로 문의드립니다.

확인된 사항:

- 로컬 방화벽/라우팅/netplan 설정 이상 없음 확인 (Step 1~3 결과 요약 채우기)
- 동일 IP를 노트북 MAC으로 사용 시 정상 통신 확인
- (Step6/7 결과에 따라 문장 선택)
(a) "MAC을 노트북 것으로 바꾸면 개발계 서버에서도 정상 통신되어, 순수 MAC 기반 차단임을 확인했습니다."
(b) "ARP는 정상 응답하나 ICMP는 응답이 없어, DHCP Snooping/IP Source Guard 또는 ACL에 의한 차단으로 추정됩니다."

요청: 개발계 서버 MAC(88:ae:dd:5d:00:28) / IP(210.94.240.180) 조합을 캠퍼스 스위치(EX3300)의 신뢰 바인딩(또는 등록 대장)에 등록 부탁드립니다.