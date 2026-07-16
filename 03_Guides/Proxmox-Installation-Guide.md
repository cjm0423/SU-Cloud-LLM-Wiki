---
title: "Proxmox 설치 가이드 (v8.4, 학교 서버)"
type: "guide"
date: 2026-06-15
tags: ["#proxmox", "#installation", "#su-cloud", "#infrastructure"]
status: "stable"
related_nodes: ["[[Proxmox]]", "[[OpenStack-Overview]]", "[[2026-06-13-kickoff]]"]
author: "SU-Cloud Team (2026-06-15 실습 기반)"
---

# Proxmox 설치 가이드

> 2026-06-15 학교 ThinkStation 서버에서 검증된 내용 기반.

## ⚠️ 버전 선택 주의

| 버전 | 결과 |
|------|------|
| Proxmox VE 9.2 | ❌ 하드웨어 인식 충돌 (BIOS/부팅 이슈) |
| Proxmox VE 8.4 | ✅ 정상 설치 |

**반드시 8.4 ISO를 사용할 것.**

## 다운로드

```
https://www.proxmox.com/en/downloads/proxmox-virtual-environment
→ Proxmox VE 8.4 ISO 선택
```

## 부팅 USB 준비

Windows에서는 [Rufus](https://rufus.ie/ko/) 사용:
1. Rufus 실행 → ISO 이미지 선택 → 시작
2. ISO 모드(DD 아님)로 쓰기

Linux에서는 `dd`:
```bash
dd if=proxmox-ve_8.4.iso of=/dev/sdX bs=4M status=progress
```

## 설치 절차

1. USB로 부팅 (BIOS/UEFI에서 Boot Priority → USB 최우선)
   - 진입키: `Del`, `F2`, `F8` (메인보드마다 다름)
2. Proxmox 설치 마법사 진행
   - **Target Disk**: 설치할 디스크 선택
     - 단일 디스크 → **ext4** 권장
     - 여러 디스크 → **ZFS** (RAID 기능)
   - Country: Korea, Timezone: Asia/Seoul
   - Admin Email + root 비밀번호 설정
   - Network: 서버 IP, Gateway, DNS 입력
3. 설치 완료 후 터미널에 표시된 IP로 웹 접속

## 설치 후 접속

```bash
# 같은 네트워크에서 브라우저로 접속
https://<서버IP>:8006

# 로그인: root / 설정한 비밀번호
```

## Tailscale 연결 (원격 접속용)

```bash
# Proxmox 쉘에서 실행
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
# 표시된 URL로 인증 완료
```

→ 이후 외부에서 `https://<tailscale-IP>:8006` 으로 접속 가능

## 학생용 VM 생성 (실습 환경)

1. Proxmox Web UI → `Create VM`
2. Ubuntu 22.04 ISO 업로드 후 선택
3. CPU: 2코어 이상, RAM: 4GB 이상, Disk: 20GB 이상
4. Network: `vmbr0` (기본 브리지)
5. VM 시작 후 OpenStack 수동 설치 실습 진행

## 중첩 가상화 활성화 (OpenStack KVM 실습 필수)

```bash
# Proxmox 호스트 쉘에서
echo "options kvm-intel nested=1" > /etc/modprobe.d/kvm-intel.conf
# 또는 AMD CPU라면
echo "options kvm-amd nested=1" > /etc/modprobe.d/kvm-amd.conf
modprobe -r kvm-intel && modprobe kvm-intel
```

## 관련 문서

- [[Proxmox]] — 개념 설명
- [[DevStack-Installation-Guide]] — Proxmox VM 위에서 DevStack 설치
- [[OpenStack-Overview]] — 최종 목표 스택
