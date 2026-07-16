---
title: "운영pc 실습 환경 네트워크 구성 정리"
type: "raw"
date: 2026-06-14
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/Ops-PC-Network-Setup-Guide]]"
---
# 운영pc 실습 환경 네트워크 구성 정리

## 전체 구성

운영 PC에 Proxmox를 설치하고, 그 위에 OpenStack 실습용 VM 4대를 생성하였다.

```bash
외부 PC
    │
    ▼
Tailscale Network
    │
    ▼
Proxmox Host
    │
    ├─ vmbr0 (외부망)
    │
    └─ vmbr1 (내부망 192.168.100.0/24)
            │
            ├─ VM1
            ├─ VM2
            ├─ VM3
            └─ VM4
```

# 1. Proxmox 역할

Proxmox는 물리 서버 위에서 여러 개의 가상 머신(VM)을 실행하는 하이퍼바이저 역할을 수행한다.

```bash
운영 PC
 └─ Proxmox
      ├─ VM1
      ├─ VM2
      ├─ VM3
      └─ VM4
```

# 2. 내부 네트워크 구성

Proxmox 내부에 Linux Bridge(vmbr1)를 생성하여 VM들을 동일한 네트워크에 연결하였다.

```bash
vmbr1
 ├─ VM1 (192.168.100.11)
 ├─ VM2 (192.168.100.12)
 ├─ VM3 (192.168.100.13)
 └─ VM4 (192.168.100.14)
```

vmbr1은 물리 스위치와 동일한 역할을 수행한다.

따라서 VM 간 통신은 Proxmox 내부에서 직접 처리된다.

예시:

```bash
ping 192.168.100.12
```

패킷 흐름:

```bash
VM1
 ↓
vmbr1
 ↓
VM2
```

외부 인터넷을 거치지 않고 내부 네트워크에서만 통신한다.

---

# 3. 인터넷 연결 (SNAT)

내부 VM들은 사설 IP 대역(192.168.100.0/24)을 사용하므로 인터넷에서 직접 라우팅할 수 없다.

따라서 Proxmox Host에서 SNAT(Source NAT)을 수행한다.

## 패킷 흐름

### VM에서 인터넷 접속

```bash
VM1
IP: 192.168.100.11
```

```bash
curl google.com
```

### 1단계

VM이 패킷 생성

```
SRC = 192.168.100.11
DST = Google
```

### 2단계

Proxmox가 NAT 수행

```
SRC = Proxmox 공인IP
DST = Google
```

으로 변경

### 3단계

Google 응답

```
DST = Proxmox 공인IP
```

### 4단계

Proxmox NAT 테이블 확인

```
192.168.100.11이 요청한 패킷
```

으로 인식

### 5단계

다시 내부 IP로 변환

```
DST = 192.168.100.11
```

### 결과

```
VM ↔ 인터넷
```

통신 가능

---

# 4. Tailscale 구성

Proxmox Host에 Tailscale을 설치하였다.

설정 명령:

```
tailscale up--advertise-routes=192.168.100.0/24
```

---

# 5. advertise-routes 의미

위 설정은 Tailscale 네트워크에 다음 내용을 광고(advertise)한다.

```
192.168.100.0/24 네트워크는
Proxmox Host를 통해 접근 가능
```

즉,

```
Proxmox = Subnet Router
```

역할을 수행하게 된다.

---

# 6. Subnet Router 동작 원리

외부 PC가 Tailscale에 접속하면 다음 경로를 자동으로 학습한다.

```
192.168.100.0/24
        ↓
Tailscale
        ↓
Proxmox
```

따라서 외부에서도 내부 VM에 직접 접근할 수 있다.

예시:

```
ssh192.168.100.11
```

---

# 7. 실제 통신 흐름

외부 노트북에서

```
ssh192.168.100.11
```

실행

### 1단계

노트북

```
SRC = Tailscale IP
DST = 192.168.100.11
```

패킷 생성

### 2단계

Tailscale WireGuard 터널로 암호화

```
외부 노트북
     ↓
Tailscale
```

### 3단계

Proxmox 수신

```
Proxmox
 ↓
192.168.100.11은
내부 네트워크(vmbr1)에 존재
```

판단

### 4단계

내부 네트워크 전달

```
Proxmox
 ↓
vmbr1
 ↓
VM1
```

### 5단계

응답 반환

```
VM1
 ↓
Proxmox
 ↓
Tailscale
 ↓
외부 노트북
```

---

# 8. 현재 환경의 장점

### VM 간 통신

```
VM ↔ VM
```

내부 브리지 네트워크 사용

### 인터넷 접속

```
VM ↔ Proxmox ↔ Internet
```

SNAT 사용

### 외부 원격 접속

```
외부 PC ↔ Tailscale ↔ Proxmox
```

### 내부 VM 직접 접속

```
외부 PC
    ↓
Tailscale
    ↓
Proxmox (Subnet Router)
    ↓
192.168.100.0/24
    ↓
VM
```

---

# OpenStack 관점

현재 구축한 `192.168.100.0/24` 네트워크는 OpenStack 노드들이 통신하는 **Underlay Network** 역할을 수행한다.

향후 OpenStack 설치 시에는 Neutron이 생성하는 VXLAN/GRE 기반의 Tenant Network가 이 네트워크 위에서 동작하게 된다.

```
물리 PC
    ↓
Proxmox
    ↓
192.168.100.0/24 (Underlay)
    ↓
OpenStack Neutron
    ↓
Tenant Network (Overlay)
    ↓
Instance
```