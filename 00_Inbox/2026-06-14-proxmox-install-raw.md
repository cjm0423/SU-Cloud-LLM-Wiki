---
title: "proxmox 설치방법"
type: "raw"
date: 2026-06-14
tags: ["#raw", "#inbox"]
status: "promoted"
source: "notion-export"
promoted_to: "[[03_Guides/Proxmox-Installation-Guide]]"
---
# proxmox 설치방법

## **준비물**

설치는 크게 어렵지 않습니다.

USB에 이미지를 받고 부팅순서바꿔주고 설치하면 끝이거든요 ㅎㅎ

USB를 준비해주시고 이미지를 쓰기위한 Rufus 정도만 미리 받아주세요.

[Rufus - 간편한 방법으로 부팅 가능한 USB 드라이브 만들기Rufus: Create bootable USB drives the easy wayby Pete Batard from RUFUS.IE](https://rufus.ie/ko/)

![](https://rufus.ie/pics/rufus-128.png)

## **Proxmox 부팅 USB 준비하기**

먼저 Proxmox 의 최신 이미지를 다운로드 받아줍니다.

![image.png](https://svrforum.com/files/attach/images/2025/08/25/455b97edcf168852dc88f5fb14be1d82.png)

다운로드가 다 되었으면 rufus를 실행해주시고 이미지를 선택해주세요

![image.png](https://svrforum.com/files/attach/images/2025/08/25/0be1b242d78c18dd3ce6870c72dac744.png)

확인을 눌러주시고 시작을 누르면 USB가 포맷된다고하는데 기존 데이터가 중요하시다면 반드시 백업해주세요.

![image.png](https://svrforum.com/files/attach/images/2025/08/25/75abb14804200b16f0b71ea2da42af69.png)

부팅 USB가 준비되면 이제 절반은 끝난겁니다.

## **PC/서버의 부팅순서 조정하기**

부팅할때 del or f8 or f2 등 bios 진입키를 눌러서 바이오스로 진입합니다.

그리고 Boot 섹션으로 가서 boot option의 첫번째를 USB로 지정해주세요

![image.png](https://svrforum.com/files/attach/images/2025/08/25/9579e64803e88ed0067ea856950bc667.png)

그리고 save&exit로 저장후 재부팅해주시면됩니다.

이제 Proxmox 설치창이 나오면서 설치가 진행됩니다.

![image.png](https://svrforum.com/files/attach/images/2025/08/25/7a07664b0745869e3abe99295342be5e.png)

시간이 좀 지나면 라이선스 동의창이 나옵니다.

![image.png](https://svrforum.com/files/attach/images/2025/08/25/9f42ac90470818f57160fb148c997383.png)

그다음은 설치 디스크 설정

기본적으로 디스크 한장이면 ext4로 설치되며 여러 디스크를 사용한다면 zfs로 구성하시는걸 추천드립니다.

![image.png](https://svrforum.com/files/attach/images/2025/08/25/5110a0838da2a631abe6bbc7fe5af0a5.png)

언어 타임존 키보드 레이아웃은 건드릴거 없이 next

![image.png](https://svrforum.com/files/attach/images/2025/08/25/a26357a3c690a46018aed72194f01b4d.png)

그리고 root로 사용할 pw와 이메일 정보를 입력해줍니다.

![image.png](https://svrforum.com/files/attach/images/2025/08/25/bb017fb3f41554c5cceafae9805f47d4.png)

그리고 기본 네트워크 어댑터 구성 및 ip설정도 진행해줍니다.

저희집 내부망은 192.168.1.0/24 대역을 쓰고있어서 해당대역중 하나의 ip로 넣어줬습니다.

hostname은 서버이름과 같은게 여기서는 ds-node1 이 hostname 이라고 보시면됩니다.

![image.png](https://svrforum.com/files/attach/images/2025/08/25/c27c68f42575057639eb562c6ad553c1.png)

마지막검토 후 install을 눌러주면 설치가 진행됩니다.

![image.png](https://svrforum.com/files/attach/images/2025/08/25/6f7445293fdf986d2bf3a27030cf5e28.png)

설치가 완료되면 이렇게 터미널 창이 나오는데 여기나오는 ip로 접속해주세요

![image.png](https://svrforum.com/files/attach/images/2025/08/25/ed8cb647c77bf776490326888835d1f9.png)

웹으로접속하면 이렇게 설치가 잘되신걸 확인할 수 있습니다.

![image.png](https://svrforum.com/files/attach/images/2025/08/25/3ca62ab4a3260c6191af5faf6a0f85c2.png)