---
title: "개발계(180) 네트워크 장애 — 원인 확정 및 조치 기록"
type: "raw"
date: 2026-07-05
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[02_QnA_Archive/2026-07-05-devpc-180-network-failure-resolved]]"
---
# 개발계(.180) 네트워크 장애 — 원인 확정 및 조치 기록

작성: 2026-07-06 ~ 07-07 / 상태: **원인 확정, 임시조치 적용 완료**

---

## 0. 한 줄 요약

개발계 서버(MAC `88:ae:dd:5d:00:28`)가 캠퍼스 네트워크에서 **MAC 주소 기준으로 차단**되고 있음을 실측으로 확정. 하드웨어/드라이버/서버 설정은 전부 정상이며, 설치 시점(2026-07-06 04:08경)에는 이 MAC으로 정상 통신했던 기록도 확인됨. 임시로 팀원 노트북의 등록된 MAC(`b0:38:6c:e1:a9:7f`)을 netplan에서 스푸핑해 통신을 복구하고, 정식 MAC 등록은 캠퍼스 네트워크팀(조충희 교수님 경유)에 요청 필요.

---

## 1. 원인 전수조사 결과표 (최종)

| 계층 | 항목 | 검증 방법 | 결과 |
| --- | --- | --- | --- |
| D. 로컬 방화벽 | ufw / iptables / nftables | `ufw status`, `iptables -L`, `nft list ruleset` | **배제** — ufw inactive, iptables 전부 ACCEPT 0 rules, nftables 룰셋 비어있음 |
| D. 커널 필터링 | rp_filter | `sysctl net.ipv4.conf.*.rp_filter` | **배제** — all/default/enp7s0f0 전부 `2`(loose), `/etc/sysctl.d/`에 명시 설정 확인 |
| B. netplan 설정 | 문법/내용 | `cat /etc/netplan/*.yaml` | **배제** — addresses/gateway/DNS 전부 정확, 문법 오류 없음 |
| B. systemd-networkd | 상태 | `networkctl status enp7s0f0` | **배제** — `State: routable`, `Online state: online` 정상 |
| C. 라우팅 테이블 | 중복/충돌 | `ip route show`, `ip route show table all`, `ip rule show` | **배제** — default route 1개만 존재, 이상 없음 |
| A. 하드웨어/드라이버 | 설치 시점 실제 통신 여부 | `journalctl --list-boots`, `/var/log/installer/*.log` | **배제 확정** — 2026-07-06 04:08~04:22, 동일 MAC/IP로 `kr.archive.ubuntu.com`과 HTTP 200 반복 성공 기록 확인. 하드웨어/드라이버는 처음부터 완전 정상이었음 |
| A. 물리 링크 | 설치 후 첫 부팅 link flapping | `journalctl -b <오래된 인덱스>` | **참고사항, 원인 아님으로 결론** — 04:49~04:57 사이 Link Up/Down 반복 및 일시적 100Mbps 폴백 관측됨. 다만 Step6(MAC 스왑)에서 동일 물리 경로로 완전 정상 통신이 확인되어, 이 flapping은 근본 원인이 아닌 것으로 결론 |
| G. Proxy ARP | 게이트웨이 대리응답 여부 | `arp -d *` 후 신선 조회 | **배제** — 게이트웨이 MAC `00:31:46:5b:d4:80`으로 확정, 이전에 의심했던 `68:ed:a4`(Shenzhen Seavo)는 게이트웨이와 무관한 별개 항목이었음 (stale 캐시 오판) |
| **F/H. MAC 기반 차단** | **MAC 교차 스왑 테스트** | 동일 서버·케이블·포트·IP 조건에서 MAC만 교체 | **확정** — 노트북 MAC(`b0:38:6c:e1:a9:7f`)으로 교체 시 게이트웨이/8.8.8.8 5/5 성공(0% 손실). 원래 MAC(`88:ae:dd:5d:00:28`) 복구 시 즉시 100% 손실 재현 |

**결정적 실험(Step 6) 결과가 이 문제의 유일한 원인을 확정지었습니다.** 다른 모든 변수(하드웨어, 케이블, 포트, 서버 설정)를 동일하게 고정한 상태에서 MAC 주소 하나만 바꿔서 증상이 완전히 사라짐 → 순수 MAC 기반 차단.

---

## 2. 최종 원인

**캠퍼스 네트워크(EX3300 또는 상위 장비)에서 개발계 서버 MAC(`88:ae:dd:5d:00:28`)이 현재 통신 허용 목록에 없거나 차단된 상태.**

- 설치 당시(04:08경, 벽포트72 직결)에는 이 MAC이 정상 통신했던 기록이 있어, **최초엔 허용되어 있었으나 이후 등록이 만료되었거나 정책이 바뀌었을 가능성**이 유력.
- 정확한 차단 메커니즘(sticky MAC violation, IP Source Guard/DHCP Snooping, MAC 화이트리스트 등)은 캠퍼스 장비 접근 권한이 없어 우리 쪽에서 특정 불가 — 네트워크팀 확인 필요 항목으로 요청서에 포함함.

---

## 3. 임시조치 (2026-07-07 적용)

### 검토했으나 채택하지 않은 방안

- **USB 랜카드(팀원 노트북용)를 개발계 PC에 물리적으로 옮겨 꽂는 방법**: 실현 가능하나 대역폭이 낮고, 매번 물리적으로 옮겨야 하는 번거로움이 있어 보류.

### 채택한 방안 — netplan MAC 스푸핑 (소프트웨어)

개발계 서버 온보드 NIC(`enp7s0f0`)에서, 팀원 노트북의 등록된 MAC(`b0:38:6c:e1:a9:7f`)을 그대로 사용하도록 netplan에 영구 반영:

```yaml
network:
  version: 2
  ethernets:
    enp7s0f0:
      match:
        macaddress: "88:ae:dd:5d:00:28"
      set-name: enp7s0f0
      macaddress: "b0:38:6c:e1:a9:7f"
      addresses:
        - "210.94.240.180/24"
      nameservers:
        addresses:
          - 210.94.224.10
        search: []
      routes:
        - to: "default"
          via: "210.94.240.254"
```

적용:

```bash
sudo netplan apply
ip link show enp7s0f0   # link/ether b0:38:6c:e1:a9:7f 확인
```

**⚠️ 반드시 지킬 것 — 팀원 노트북과 동시 접속 금지**
이 MAC은 팀원 노트북에 실제 등록된 MAC을 그대로 빌려 쓰는 것이므로, **개발계 서버가 이 MAC으로 네트워크에 붙어있는 동안 팀원 노트북은 같은 대역에 절대 동시 연결하면 안 됨** (동시 접속 시 이전에 겪었던 IP/MAC 충돌이 그대로 재현되어 둘 다 통신 불가 상태가 됨). 팀원에게 공지 완료 필요.

이 상태로 Kolla-Ansible AIO 배포 진행 예정.

---

## 5. 남아있는 미확인 사항 (참고용, 우선순위 낮음 — 원인이 이미 확정되어 추가 조사 불필요)

| 항목 | 상태 |
| --- | --- |
| tcpdump로 ARP vs ICMP 왕복 확인 (Step 7) | 미실시 — MAC 스왑으로 원인이 이미 확정되어 실익 없음 |
| 1820 스위치 Port Security GUI 확인 (Step 8) | 미실시 — 문제가 우리 스위치가 아닌 캠퍼스 장비 쪽으로 확인되어 우선순위 낮음 |
| 부팅 초반 link flapping의 정확한 원인 | 미확인 — 근본 원인이 아니었던 것으로 결론났으나, 혹시 재발 시 케이블/포트 물리 점검 필요할 수 있음 |