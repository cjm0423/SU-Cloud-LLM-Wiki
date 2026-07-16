---
title: "P520 RTX A5500 GPU 패스스루 → VLLM VM 가이드"
type: "guide"
date: 2026-06-28
tags: ["#guide", "#gpu", "#proxmox", "#vllm", "#passthrough"]
status: "stable"
related_nodes: ["[[01_Concepts/Proxmox]]", "[[03_Guides/Tailscale-Setup-Guide]]"]
author: "AI Assistant"
raw_source: "[[00_Inbox/2026-06-28-p520-gpu-vllm-passthrough-raw]]"
---

# P520 RTX A5500 GPU 패스스루 → VLLM VM 가이드

## 개요

운영계 Lenovo P520 (RTX A5500 ×2)에서 **#2번 카드(`b3:00`)** 만 Linux VM에 패스스루해서 vLLM 실행 환경 구성. #1번 카드는 OpenStack용으로 보존.

## 사전 조건

- Proxmox VE 설치된 P520
- VT-d/IOMMU 활성 (이미 활성 확인됨)
- 루트 권한

---

## 단계별 절차

### Step 0. 사전 상태 확인

```bash
# VT-d/IOMMU 활성 여부
dmesg | grep -e DMAR -e IOMMU
# 확인 키: "Intel(R) Virtualization Technology for Directed I/O" + "Enabled IRQ remapping"

# IOMMU 그룹 개수 확인
ls /sys/kernel/iommu_groups/ | wc -l   # 85 = 정상

# vfio 모듈 로드 (재부팅 없이)
modprobe vfio vfio_iommu_type1 vfio_pci
```

### Step 1. GPU 식별 및 IOMMU 그룹 격리 확인

```bash
lspci -nn | grep -i nvidia
```

출력:
```
65:00.0 VGA [RTX A5500] [10de:2233]  ← #1번 카드 (보존, OpenStack용)
65:00.1 Audio                [10de:1aef]
b3:00.0 VGA [RTX A5500] [10de:2233]  ← #2번 카드 (패스스루 대상)
b3:00.1 Audio                [10de:1aef]
```

> ⚠️ 두 카드 ID가 `10de:2233`으로 동일 → **반드시 주소(`b3:00`)로만 작업**, ID 바인딩 금지

```bash
# b3:00 IOMMU 그룹 격리 확인
for d in /sys/kernel/iommu_groups/*/devices/0000:b3:00.*; do
  g=$(echo "$d" | sed 's|.*iommu_groups/||; s|/devices.*||')
  echo "Group $g: $(lspci -nns $(basename $d))"
done
# 결과: Group 1에 b3:00.0 + b3:00.1만 → 격리 완벽
```

### Step 2. #2번 카드만 vfio-pci로 고정 (주소 기반)

```bash
# driverctl로 #2번만 오버라이드 (재부팅 영구 적용)
apt install -y driverctl
driverctl set-override 0000:b3:00.0 vfio-pci
driverctl set-override 0000:b3:00.1 vfio-pci

# 확인
driverctl list-overrides
# 0000:b3:00.0 vfio-pci
# 0000:b3:00.1 vfio-pci
```

### Step 3. VM 생성 (Proxmox GUI)

| 항목 | 값 |
|------|-----|
| Machine Type | q35 (IOMMU 지원 필수) |
| BIOS | OVMF (UEFI) |
| CPU | host, 8~16 cores |
| RAM | 32GB 이상 권장 |
| Disk | VirtIO SCSI, 100GB+ |
| Network | vmnet (192.168.100.x 대역) |

### Step 4. PCI 패스스루 추가

VM 생성 후: VM 선택 → Hardware → Add → PCI Device
- `b3:00.0` (VGA) + `b3:00.1` (Audio) 각각 추가
- `All Functions`: 체크
- `Primary GPU`: 체크 (VGA 카드 경우)
- `ROM-Bar`: 체크

### Step 5. NVIDIA 드라이버 설치 (VM 안)

```bash
# Ubuntu 22.04/24.04 기준
apt install -y ubuntu-drivers-common
ubuntu-drivers autoinstall   # 또는 수동: apt install nvidia-driver-535

# 확인
nvidia-smi   # GPU 인식 확인
```

### Step 6. vLLM 설치

```bash
pip install vllm

# 테스트 실행
python -c "from vllm import LLM; llm = LLM(model='facebook/opt-125m'); print('OK')"
```

### Step 7. 골든 이미지화 (선택)

VM이 정상 동작하면 Proxmox에서 스냅샷 또는 템플릿으로 저장:
- VM 우클릭 → Convert to Template
- 이후 새 VM 생성 시 이 템플릿에서 Clone

---

## 주의사항

- `10de:2233`으로 ID가 같아서 ID 바인딩(`vfio-pci.ids=10de:2233`)하면 양쪽 카드 모두 vfio로 전환 → OpenStack 중단. **반드시 주소 단위로만 바인딩**.
- #1번 카드(`65:00`)는 nouveau 드라이버 유지 → OpenStack nova-compute가 계속 사용
- GPU VM은 `192.168.100.50`으로 Tailscale 통해 접속

## 관련 문서

- [[01_Concepts/Proxmox]]
- [[03_Guides/Tailscale-Setup-Guide]]
