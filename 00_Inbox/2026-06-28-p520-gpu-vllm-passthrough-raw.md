---
title: "P520 GPU VLLM 패스스루 가이드"
type: "raw"
date: 2026-06-28
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/P520-GPU-VLLM-Passthrough-Guide]]"
---
# P520 GPU VLLM 패스스루 가이드

> 대상: 운영계 Lenovo P520 (Xeon W-2295 / 128GB ECC / **RTX A5500 ×2**) · Proxmox VE (`pve`)
목표: A5500 **#2번(`b3:00`)** 카드를 Linux VM에 패스스루 → Tailscale·SSH 접속 → 골든이미지화
우선순위: 성현 SSH 접속 먼저, GPU는 그 다음 붙여도 됨
> 
> 
> **이 환경 실측 결론**
> 
> - VT-d·IOMMU·인터럽트 리매핑 **이미 활성**
> - 카드 2장 ID 동일(`10de:2233`) → **ID 바인딩 금지, 주소 단위로만** 분리
> - `#2 = b3:00`은 IOMMU **Group 1에 GPU+오디오 단독** → 격리 완벽
> - `#1 = 65:00`은 보존(nouveau 유지), `#2`만 vfio-pci 고정 → **OpenStack 무중단**

---

## 0. 사전 상태 확인

### 0-1. IOMMU/VT-d 활성 여부 — **이미 켜져 있었음**

```bash
dmesg | grep -e DMAR -e IOMMU
```

확인된 핵심 라인:

- `Intel(R) Virtualization Technology for Directed I/O` → VT-d 활성
- `Enabled IRQ remapping in x2apic mode` → 인터럽트 리매핑 활성(패스스루 필수)

### 0-2. IOMMU 그룹 채워짐 + vfio 모듈

```bash
ls /sys/kernel/iommu_groups/ | wc -l        # 85 → 정상
modprobe vfio vfio_iommu_type1 vfio_pci      # 라이브 로드(재부팅 X)
```

---

## 1. GPU 식별 + 그룹 격리 확인

### 1-1. NVIDIA 디바이스 / 주소 확정

```bash
lspci -nn | grep -i nvidia
```

결과:

```
65:00.0 VGA  [RTX A5500] [10de:2233]   ← #1번 카드 (보존)
65:00.1 Audio                [10de:1aef]
b3:00.0 VGA  [RTX A5500] [10de:2233]   ← #2번 카드 (패스스루 대상)
b3:00.1 Audio                [10de:1aef]
```

→ **넘길 카드 = `0000:b3:00`** (VGA `.0` + Audio `.1`).

> 두 카드 ID가 `10de:2233`로 동일하므로 **반드시 주소로만** 작업.
> 

### 1-2. b3:00 IOMMU 그룹 격리 확인

```bash
for d in /sys/kernel/iommu_groups/*/devices/0000:b3:00.*; do
  g=$(echo "$d" | sed 's|.*iommu_groups/||; s|/devices.*||')
  echo "Group $g: $(lspci -nns $(basename $d))"
done
```

결과: **Group 1에 `b3:00.0` + `b3:00.1` 둘만** → NIC/디스크 등 안 섞임 → 격리 완벽.

---

## 2. 카드만 vfio-pci로 고정 (driverctl, 무중단)

초기 상태: 두 카드 모두 호스트 `nouveau`가 점유 중.

ID 블랙리스트(`blacklist nouveau`)를 쓰면 `#1`까지 떨어지므로 사용 금지.

→ **주소 단위 override**로 `b3:00`만 분리(재부팅 불필요, 영구 저장).

```bash
apt install -y driverctl
driverctl set-override 0000:b3:00.0 vfio-pci
driverctl set-override 0000:b3:00.1 vfio-pci

# 확인
lspci -nnk -d 10de:2233
```

기대 결과(달성됨):

```
65:00.0 ... Kernel driver in use: nouveau      ← #1 보존
b3:00.0 ... Kernel driver in use: vfio-pci      ← #2 넘길 준비 완료(실제 사용할 gpu)
```

> override 해제(원복)가 필요하면: `driverctl unset-override 0000:b3:00.0` (`.1`도)
> 

---

## 3. Linux VM 생성 + GPU attach (vLLM 데모용)

### 3-1. VM 생성 (GUI)

- **General**: VMID `300`, Name `gpu-vllm`
- **OS**: Ubuntu 24.04 Server ISO
- **System**: Machine `q35`, BIOS `OVMF (UEFI)` + EFI Disk(local-lvm)
    
    ![image.png](P520%20GPU%20VLLM%20%ED%8C%A8%EC%8A%A4%EC%8A%A4%EB%A3%A8%20%EA%B0%80%EC%9D%B4%EB%93%9C/image.png)
    
- **Disk**: local-lvm, `200` GB
- **CPU**: Type `host`, Cores `16`
- **Memory**: `32768` (32GB)
- **Network**: Bridge `vmnet`
- 생성 후 바로 시작 체크 해제

### 3-2. GPU 붙이기 (주소 지정)

```bash
qm set 300 -hostpci0 0000:b3:00,pcie=1
qm start 300
```

> compute 전용이라 `x-vga=1` 불필요. Display는 Default/none 무방 (패스스루 시 NoVNC엔 화면 안 뜸 — 정상, SSH로 작업).
> 

### 3-3. Ubuntu 설치 + 고정 IP

- Address `192.168.100.50/24` (기존 ip와 비충돌)
- Gateway `192.168.100.1`, DNS `8.8.8.8`

### 3-4. NVIDIA 드라이버 + 검증

```bash
sudo apt update
sudo ubuntu-drivers install      # 또는 sudo apt install -y nvidia-driver-570-server
sudo reboot
# 재부팅 후
nvidia-smi
```

A5500 한 장 인식되면 패스스루 성공.

```bash
ubuntu@gpu-vllm:~$ nvidia-smi
Tue Jun 30 05:18:06 2026
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 595.71.05              Driver Version: 595.71.05      CUDA Version: 13.2     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA RTX A5500               Off |   00000000:01:00.0 Off |                  Off |
| 30%   40C    P8              8W /  230W |       1MiB /  24564MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+
```

> 인식 실패 시 호스트에서 `lspci -nnk -d 10de:2233` → `b3:00`이 `vfio-pci`인지 재확인.
> 

---

## 4. SSH 접속

> **방침**: VM엔 Tailscale 안 깖. 호스트(`pve`)가 이미 `192.168.100.0/24`를 subnet router로 advertise 중이라, 성현이 본인 PC에만 Tailscale 깔면 `192.168.100.50`으로 바로 접속됨.
계정은 설치 때 만든 `ubuntu` / `ubuntu` 사용 (별도 계정 생성 불필요).
> 

### 4-1. 접속 확인

1. **공용 계정** `sahmyookcloud@gmail.com`로 본인 PC에 Tailscale 설치 + 로그인
2. 접속: `ssh ubuntu@192.168.100.50` (비번: `ubuntu`)

---

## 5. 골든이미지(템플릿)화

### 5-1. 골든 마스터 복제 (호스트 PVE Shell)

```bash
qm shutdown 300                                    # 복제 위해 잠깐 끔
qm clone 300 9000 --full --name gpu-vllm-golden    # 골든 마스터로 복제
qm set 9000 -delete hostpci0                       # 골든엔 GPU 미포함
qm start 9000                                      # 부팅(300 꺼져있어 .50 충돌 없음)
```

### 5-2. cloud-init 네트워크 차단 + IP 비우기 + 지문 지우기 (9000 콘솔, ubuntu/ubuntu)

`50-cloud-init.yaml`은 cloud-init 관리 파일 → 먼저 cloud-init이 네트워크 못 건드리게 막고, 고정 IP(.50)를 비운 뒤 지문 제거.

```bash
# 1) cloud-init 네트워크 관리 차단
sudo bash -c 'echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg'

# 2) 고정 IP(.50) 제거 → DHCP 백지 상태 (인터페이스: enp6s18)
sudo bash -c 'cat > /etc/netplan/50-cloud-init.yaml' <<'EOF'
network:
  version: 2
  ethernets:
    enp6s18:
      dhcp4: true
EOF
sudo chmod 600 /etc/netplan/50-cloud-init.yaml

# 3) 지문 지우기 (machine-id / ssh host key / 로그)
sudo cloud-init clean --logs 2>/dev/null || true
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo rm -f /etc/ssh/ssh_host_*           # 첫 부팅 시 재생성
sudo apt clean && sudo journalctl --vacuum-time=1d
history -c

# 4) 종료
sudo shutdown now
```

> vmnet엔 DHCP 서버 없음 → DHCP는 "IP 미지정 백지" 의미. 클론은 부팅해도 IP 안 잡히므로 5-4에서 콘솔로 고정 IP 부여.
> 

### 5-3. 템플릿 변환 + 데모 VM 복구

```bash
qm template 9000     # 9000을 복제 전용 템플릿으로
qm start 300         # GPU-VLLM 데모 VM 복구
```

### 5-4. 나중에 골든이미지 사용

```bash
qm clone 9000 301 --full --name gpu-vllm-2
qm start 301
```

부팅 후 **콘솔에서 고정 IP 부여**(골든은 IP 백지 상태):

```bash
sudo bash -c 'cat > /etc/netplan/50-cloud-init.yaml' <<'EOF'
network:
  version: 2
  ethernets:
    enp6s18:
      addresses: ["192.168.100.##/24"]    # 사용중인 ip와 안 겹치는 값
      routes: [{to: "default", via: "192.168.100.1"}]
      nameservers: {addresses: ["8.8.8.8"]}
EOF

sudo chmod 600 /etc/netplan/50-cloud-init.yaml

sudo netplan apply
```

GPU 부여(300이 꺼져 있을 때만):

```bash
qm set 301 -hostpci0 0000:b3:00,pcie=1
```

> **핵심 2가지**: ① 클론은 IP 백지 → 부팅 후 콘솔에서 고정 IP 새로 부여. 
                    ② **물리 GPU 1장 = 동시 VM 1대** — 300과 클론은 동시 기동 불가.
> 

> **물리 GPU 1장 = 동시 VM 1대.** Linux VM 켜면 Windows VM은 GPU 못 받음.
> 

---

## 6. Windows VM 패스스루 (선택, Linux 검증 후) - 진행X

1. VM: `q35` + `OVMF(UEFI)` + EFI Disk, SCSI Controller `VirtIO SCSI single`.
2. Windows ISO + **virtio-win ISO** 둘 다 마운트(설치 중 VirtIO 드라이버 로드).
3. **Linux VM 꺼진 상태**에서 GPU attach: `qm set <WinVMID> -hostpci0 0000:b3:00,pcie=1`
4. Windows에서 NVIDIA 워크스테이션 드라이버 설치.
5. **RDP 활성화**(NoVNC엔 GPU 화면 안 뜸).
6. (만약) Error 43: A5500은 프로 카드라 거의 안 뜸. 떠도 R530+에서 대부분 해소. 막히면 VM args:
`args: -cpu host,hv_vendor_id=proxmox,kvm=off`

---

## 진행 현황 체크리스트

- [x]  VT-d/IOMMU 활성 확인 — **이미 켜짐, 재부팅 불필요**
- [x]  vfio 모듈 로드
- [x]  #2 카드 주소 확정 (`b3:00`), 그룹 격리 확인(Group 1 단독)
- [x]  driverctl로 `b3:00`만 vfio-pci 고정 (`65:00`은 nouveau 보존, **무중단**)
- [x]  Linux VM 생성 (q35/OVMF/host/vmnet/.50)
- [x]  `qm set 300 -hostpci0 0000:b3:00,pcie=1` → `nvidia-smi`
- [x]  vLLM 테스트
- [x]  **Tailscale + 성현 SSH 계정 → 접속 전달 (이번 주 목표)**
- [x]  정리 후 템플릿화 (GPU 디바이스 제외)
- [ ]  (선택) Windows VM + RDP

---

## 부록: 핵심 명령 모음

```bash
# GPU 드라이버 점유 상태 확인 (호스트)
lspci -nnk -d 10de:2233

# override 원복(필요 시)
driverctl unset-override 0000:b3:00.0
driverctl unset-override 0000:b3:00.1

# VM에 GPU 붙이기 / 떼기
qm set <VMID> -hostpci0 0000:b3:00,pcie=1
qm set <VMID> -delete hostpci0
```

LLM 질문 예시

```bash
curl http://192.168.100.50:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-8B",
    "messages": [
      {"role": "user", "content": "너는 무슨 모델이야?"}
    ],
    "max_tokens": 512
  }'
```

```bash
저는 알리바바 클라우드에서 개발한 대규모 언어 모델인 Qwen입니다. 저는 다양한 주제에 대해 질문에 답변하고, 글쓰기, 대화, 창의적인 작업 등 여러 작업을 수행할 수 있습니다. 저는 2024년까지의 정보를 기반으로 훈련되었으며, 여러 언어를 지원합니다. 궁금한 점이나 도와드릴 일이 있으신가요?
```