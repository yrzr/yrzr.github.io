---
title: "Running OPNsense on R6S"
date: 2023-07-25T12:59:15+08:00
tags: [OPNsense, FreeBSD, aarch64, r6s, 2.5GE]
resources:
# featuredImage: "/images/port-opnsense-to-r6s/booted.jpg"
featuredImagePreview: "/images/port-opnsense-to-r6s/booted.jpg"
---

## 1 Introduction

> The NanoPi R6S (as “R6S”) is an open-sourced mini IoT gateway device with two 2.5G and one Gbps Ethernet ports, designed and developed by FriendlyElec.[^wiki]

The R6S is built on RK3588S, which has Quad-core ARM Cortex-A76 (up to 2.4GHz) and quad-core Cortex-A55 CPU (up to 1.8GHz), and 8GB LPDDR4X RAM at 2133MHz. It has 32GB eMMC and supports an SD card or disk drive through USB 3.0 port. And the charming points are the three Ethernet ports. Moreover, Friendlyelec claims[^friendlyelec] that R6S has extremely high encryption performance.

In general, the R6S is a promising home router hardware, except there is only OpenWRT running on it. Then the idea came to me that I might port OPNsense to it if I get one. What I did was share this idea with FriendlyELEC through email. And things go magic,  they replied without hesitation and delivered me a brand new R6S. 

***So, thanks to FriendlyELEC, we have this post.***

## 2 A Little Research

Before I got the board, I'd already got a Rock 5B. I noticed that the official U-boot provided by Rockchip cannot boot EFI[^radxa], and the problem will not be solved in the near future. The [mainline effords](https://gitlab.collabora.com/hardware-enablement/rockchip-3588/u-boot) have been made only on Rock 5B.

While [EDK2 UEFI firmware for RK3588](https://github.com/edk2-porting/edk2-rk3588) is workable on many devices, including R6S since this commit[^initdc]. And we can directly get the [firmware artifacts](https://github.com/edk2-porting/edk2-rk3588/actions/runs/5651189824) from the `Nightly build `GitHub action. From the [introduction](https://github.com/edk2-porting/edk2-rk3588/blob/v0.7.1/README.md), the GMAC Ethernet is not working, while PCIe 3.0 is partially working. Let's hope we have two 2.5G Ethernet running.

## 3 Build OPNsense

The build processes are similar to other devices. It will do with a bit of modification. Thanks to [Sleep Walker](https://twitter.com/S199pWa1k9r), I realize that package `net/realtek-re-kmod` is required to drive the two 2.5G Ethernet chips. And we also want to turn off `arm_install_uboot()` since we are not using U-Boot. And we get the `efi` console instead of `video` console.

The tools is pushed to my [repo](https://github.com/yrzr/opnsense-tools/tree/r6s) on branch `r6s`, among with the [artifacts](https://github.com/yrzr/opnsense-tools/releases/tag/23.7.r1).

## 4 Booting R6S

I am wondering whether the FreeBSD kernel could read from the onboard eMMC. And I have an SSD drive and a SATA to USB bridge by hand. So I just jump to using an SSD driver through the USB 3.0 port.

```bash
$ sudo dd status=progress if=OPNsense-23.7.r1-arm-aarch64-R6S.img of=/dev/sdb bs=16M
```

Moreover, we need an SD card to carry the UEFI firmware, which will load the OPNsense.

```bash
$ unzip nanopi-r6s\ UEFI\ Debug\ image.zip
Archive:  nanopi-r6s UEFI Debug image.zip       
  inflating: nanopi-r6s_UEFI_Debug_6eeff50.img
$ sudo dd status=progress if=nanopi-r6s_UEFI_Debug_6eeff50.img of=/dev/sdc bs=4M
1+1 records in
1+1 records out
7011840 bytes (7.0 MB, 6.7 MiB) copied, 1.25968 s, 5.6 MB/s
```

Next, we insert the SD card and plug in the SSD drive, the keyboard, HDMI, and network cables. And we power on the R6S.

The first screen tells us to press `Esc` on the keyboard for the boot options. However, you would want to press it over and over until the screen changes.

![Alt text](/images/port-opnsense-to-r6s/escape.jpg "press `ESCAPE` for the boot options")

When the boot options show, navigate to `Boot Manager` and press `Enter`.

![Alt text](/images/port-opnsense-to-r6s/boot_options.jpg "boot options")

Here, we find our SATA to USB bridge showing up, which is the right we want.

![Alt text](/images/port-opnsense-to-r6s/boot_device.jpg "choose boot device")

Everything works like a charm. The OPNsense is loading!

![Alt text](/images/port-opnsense-to-r6s/load_opnsense.jpg "OPNsense is loading!")

And Finally, OPNsense booted successfully, and the two 2.5G Ethernets are working!

![Alt text](/images/port-opnsense-to-r6s/booted.jpg "OPNsense booted successfully!")

## 5 Tests & Run

So, let's see how everything is working.

### 5.1 A genernal view on `hw-probe` & `dmesg`

Let's get a genernal view first.

After using my mirror (~~https://ftp.yrzr.tk/opnsense~~ `http://147.8.92.207/opnsense`), we could install packages and do a hw-probe and see the [result](https://bsd-hardware.info/?probe=ebca9e6d70).

```bash
root@OPNsense:~ # pkg install -y hw-probe
Updating OPNsense repository catalogue...
OPNsense repository is up to date.
All repositories are up to date.
Checking integrity... done (0 conflicting)
The following 4 package(s) will be affected (of 0 checked):

New packages to be INSTALLED:
        hw-probe: 1.6.5
        hwstat: 0.5.1
        lsblk: 3.7
        smartmontools: 7.3_1

Number of packages to be installed: 4

The process will require 2 MiB more space.
[1/4] Installing hwstat-0.5.1...
[1/4] Extracting hwstat-0.5.1: 100%
[2/4] Installing lsblk-3.7...
[2/4] Extracting lsblk-3.7: 100%
[3/4] Installing smartmontools-7.3_1...
[3/4] Extracting smartmontools-7.3_1: 100%
[4/4] Installing hw-probe-1.6.5...
[4/4] Extracting hw-probe-1.6.5: 100%
=====
Message from smartmontools-7.3_1:

--
smartmontools has been installed

To check the status of drives, use the following:

        /usr/local/sbin/smartctl -a /dev/ad0    for first ATA/SATA drive
        /usr/local/sbin/smartctl -a /dev/da0    for first SCSI drive
        /usr/local/sbin/smartctl -a /dev/ada0   for first SATA drive

To include drive health information in your daily status reports,
add a line like the following to /etc/periodic.conf:
        daily_status_smart_devices="/dev/ad0 /dev/da0"
substituting the appropriate device names for your SMART-capable disks.

To enable drive monitoring, you can use /usr/local/sbin/smartd.
A sample configuration file has been installed as
/usr/local/etc/smartd.conf.sample
Copy this file to /usr/local/etc/smartd.conf and edit appropriately

To have smartd start at boot
        echo 'smartd_enable="YES"' >> /etc/rc.conf
root@OPNsense:~ # hw-probe -all -upload
Probe for hardware ... ofwdump: ioctl(..., OFIOCGETPROPLEN, ...) failed: Invalid argument
Ok
Reading logs ... Ok
Uploaded to DB, Thank you!

Probe URL: https://bsd-hardware.info/?probe=ebca9e6d70
```

And by looking at the `dmesg`, we can find both `<Realtek PCIe 2.5GbE Family Controller>` are recognized by the kernel. We also get four `Cortex-A55` and four `Cortex-A76`, as well as 7917 MB memory. Both the USB 3.0 and USB 2.0 ports are reported, but R6S is not responding to any device plugged into the USB 2.0 port. And both SD card and eMMC is not showing up.

```txt
KDB: debugger backends: ddb
KDB: current backend: ddb
Copyright (c) 1992-2021 The FreeBSD Project.
Copyright (c) 1979, 1980, 1983, 1986, 1988, 1989, 1991, 1992, 1993, 1994
        The Regents of the University of California. All rights reserved.
FreeBSD is a registered trademark of The FreeBSD Foundation.
FreeBSD 13.2-RELEASE-p1 stable/23.7-n254734-db656ecc44c SMP arm64
FreeBSD clang version 14.0.5 (https://github.com/llvm/llvm-project.git llvmorg-14.0.5-0-gc12386ae247c)
VT(efifb): resolution 1920x1080
module firmware already present!
real memory  = 8302219264 (7917 MB)
avail memory = 7933530112 (7566 MB)
Starting CPU 1 (100)
Starting CPU 2 (200)
Starting CPU 3 (300)
Starting CPU 4 (400)
Starting CPU 5 (500)
Starting CPU 6 (600)
Starting CPU 7 (700)
FreeBSD/SMP: Multiprocessor System Detected: 8 CPUs
random: unblocking device.
random: entropy device external interface
MAP 7c0000 mode 2 pages 48
MAP e2780000 mode 2 pages 128
MAP e2830000 mode 2 pages 32768
MAP eab70000 mode 2 pages 64
MAP eabb0000 mode 2 pages 64
MAP eabf0000 mode 2 pages 64
MAP eac40000 mode 2 pages 112
MAP eacb0000 mode 2 pages 80
MAP ead00000 mode 2 pages 80
MAP ead50000 mode 2 pages 80
MAP eada0000 mode 2 pages 80
MAP eadf0000 mode 2 pages 80
MAP eae40000 mode 2 pages 80
MAP eae90000 mode 2 pages 144
MAP eaf20000 mode 2 pages 80
MAP eaf70000 mode 2 pages 80
MAP effb0000 mode 2 pages 48
MAP fd7c0000 mode 0 pages 16
MAP fe2b0000 mode 0 pages 16
kbd0 at kbdmux0
acpi0: <RKCP RK3588>
acpi0: Power Button (fixed)
acpi0: Could not update all GPEs: AE_NOT_CONFIGURED
psci0: <ARM Power State Co-ordination Interface Driver> on acpi0
gic0: <ARM Generic Interrupt Controller v3.0> iomem 0xfe600000-0xfe61ffff,0xfe680000-0xfe77ffff on acpi0
generic_timer0: <ARM Generic Timer> irq 5,6,7 on acpi0
Timecounter "ARM MPCore Timecounter" frequency 24000000 Hz quality 1000
Event timer "ARM MPCore Eventtimer" frequency 24000000 Hz quality 1000
efirtc0: <EFI Realtime Clock>
efirtc0: registered as a time-of-day clock, resolution 1.000000s
cpu0: <ACPI CPU> on acpi0
uart0: <Non-standard ns8250 class UART with FIFOs> iomem 0xfeb50000-0xfeb50fff irq 2 on acpi0
xhci0: <Generic USB 3.0 controller> iomem 0xfc000000-0xfc3fffff irq 3 on acpi0
xhci0: 64 bytes context size, 32-bit DMA
usbus0 on xhci0
xhci1: <Generic USB 3.0 controller> iomem 0xfcd00000-0xfd0fffff irq 4 on acpi0
xhci1: 64 bytes context size, 32-bit DMA
usbus1 on xhci1
pcib0: <Generic PCI host controller> on acpi0
pci0: <PCI bus> on pcib0
re0: <Realtek PCIe 2.5GbE Family Controller> mem 0xf3000000-0xf300ffff,0xf3010000-0xf3013fff at device 0.0 on pci0
re0: Using Memory Mapping!
re0: Using line-based interrupt
re0: Invalid ether addr: 00:00:00:00:00:00
re0: Random ether addr: 58:9c:fc:10:1a:fb
re0: version:1.98.00
re0: Ethernet address: 58:9c:fc:10:1a:fb

This product is covered by one or more of the following patents:
US6,570,884, US6,115,776, and US6,327,625.
re0: Ethernet address: 58:9c:fc:10:1a:fb
pcib1: <Generic PCI host controller> on acpi0
pci1: <PCI bus> on pcib1
re1: <Realtek PCIe 2.5GbE Family Controller> mem 0xf4000000-0xf400ffff,0xf4010000-0xf4013fff at device 0.0 on pci1
re1: Using Memory Mapping!
re1: Using line-based interrupt
re1: Invalid ether addr: 00:00:00:00:00:00
re1: Random ether addr: 58:9c:fc:00:aa:d9
re1: version:1.98.00
re1: Ethernet address: 58:9c:fc:00:aa:d9

This product is covered by one or more of the following patents:
US6,570,884, US6,115,776, and US6,327,625.
re1: Ethernet address: 58:9c:fc:00:aa:d9
armv8crypto0: <AES-CBC,AES-XTS,AES-GCM>
Timecounters tick every 1.000 msec
usbus0: 5.0Gbps Super Speed USB v3.0
usbus1: 5.0Gbps Super Speed USB v3.0
CPU  0: ARM Cortex-A55 r2p0 affinity:  0  0
                   Cache Type = <64 byte D-cacheline,64 byte I-cacheline,VIPT ICache,64 byte ERG,64 byte CWG>
 Instruction Set Attributes 0 = <DP,RDM,Atomic,CRC32,SHA2,SHA1,AES+PMULL>
 Instruction Set Attributes 1 = <RCPC-8.3,DCPoP>
 Instruction Set Attributes 2 = <>
         Processor Features 0 = <RAS,GIC,AdvSIMD+HP,FP+HP,EL3 32,EL2 32,EL1 32,EL0 32>
         Processor Features 1 = <PSTATE.SSBS>
      Memory Model Features 0 = <TGran4,TGran64,TGran16,SNSMem,BigEnd,16bit ASID,1TB PA>
      Memory Model Features 1 = <XNX,PAN+ATS1E1,LO,HPD+TTPBHA,VH,16bit VMID,HAF+DS>
      Memory Model Features 2 = <32bit CCIDX,48bit VA,IESB,UAO,CnP>
             Debug Features 0 = <DoubleLock,2 CTX BKPTs,4 Watchpoints,6 Breakpoints,PMUv3 v8.1,Debugv8.2>
             Debug Features 1 = <>
         Auxiliary Features 0 = <>
         Auxiliary Features 1 = <>
AArch32 Instruction Set Attributes 5 = <RDM,CRC32,SHA2,SHA1,AES+VMULL,SEVL>
AArch32 Media and VFP Features 0 = <FPRound,FPSqrt,FPDivide,DP VFPv3+v4,SP VFPv3+v4,AdvSIMD>
AArch32 Media and VFP Features 1 = <SIMDFMAC,FPHP Arith,SIMDHP Arith,SIMDSP,SIMDInt,SIMDLS,FPDNaN,FPFtZ>
CPU  1: ARM Cortex-A55 r2p0 affinity:  1  0
CPU  2: ARM Cortex-A55 r2p0 affinity:  2  0
CPU  3: ARM Cortex-A55 r2p0 affinity:  3  0
CPU  4: ARM Cortex-A76 r4p0 affinity:  4  0
                   Cache Type = <64 byte D-cacheline,64 byte I-cacheline,PIPT ICache,64 byte ERG,64 byte CWG,IDC>
         Processor Features 0 = <CSV3,CSV2,RAS,GIC,AdvSIMD+HP,FP+HP,EL3,EL2,EL1,EL0 32>
CPU  5: ARM Cortex-A76 r4p0 affinity:  5  0
CPU  6: ARM Cortex-A76 r4p0 affinity:  6  0
CPU  7: ARM Cortex-A76 r4p0 affinity:  7  0
Release APs...done
ugen1.1: <Generic XHCI root HUB> at usbus1
ugen0.1: <Generic XHCI root HUB> at usbus0
uhub0 on usbus1
uhub0: <Generic XHCI root HUB, class 9/0, rev 3.00/1.00, addr 1> on usbus1
uhub1 on usbus0
uhub1: <Generic XHCI root HUB, class 9/0, rev 3.00/1.00, addr 1> on usbus0
Trying to mount root from ufs:/dev/ufs/OPNsense [rw]...
uhub0: 2 ports with 2 removable, self powered
uhub1: 2 ports with 2 removable, self powered
ugen0.2: <GenesysLogic USB2.0 Hub> at usbus0
uhub2 on uhub1
uhub2: <GenesysLogic USB2.0 Hub, class 9/0, rev 2.00/92.16, addr 1> on usbus0
uhub2: MTT enabled
Root mount waiting for: usbus0
uhub2: 4 ports with 4 removable, self powered
Root mount waiting for: usbus0
usb_msc_auto_quirk: UQ_MSC_NO_GETMAXLUN set for USB mass storage device VLI Manufacture String VLI Product String (0x2109:0x0715)
ugen0.3: <VLI Manufacture String VLI Product String> at usbus0
umass0 on uhub2
umass0: <VLI Manufacture String VLI Product String, class 0/0, rev 2.10/0.00, addr 2> on usbus0
umass0:  SCSI over Bulk-Only; quirks = 0x0100
umass0:0:0: Attached to scbus0
(probe0:umass-sim0:0:0:0): REPORT LUNS. CDB: a0 00 00 00 00 00 00 00 00 10 00 00
(probe0:umass-sim0:0:0:0): CAM status: SCSI Status Error
(probe0:umass-sim0:0:0:0): SCSI status: Check Condition
(probe0:umass-sim0:0:0:0): SCSI sense: ILLEGAL REQUEST asc:20,0 (Invalid command operation code)
(probe0:umass-sim0:0:0:0): Error 22, Unretryable error
da0 at umass-sim0 bus 0 scbus0 target 0 lun 0
da0: <TOSHIBA Q300 Pro JURA> Fixed Direct Access SPC-4 SCSI device
da0: Serial Number 000000124230
da0: 40.000MB/s transfers
da0: 122104MB (250069680 512 byte sectors)
da0: quirks=0x2<NO_6_BYTE>
ugen0.4: <vendor 0x04d9 USB Keyboard> at usbus0
ukbd0 on uhub2
ukbd0: <vendor 0x04d9 USB Keyboard, class 0/0, rev 1.10/1.05, addr 3> on usbus0
kbd1 at ukbd0
WARNING: / was not properly dismounted
WARNING: /: TRIM flag on fs but disk does not support TRIM
Dual Console: Serial Primary, Video Secondary
ums0 on uhub2
ums0: <vendor 0x04d9 USB Keyboard, class 0/0, rev 1.10/1.05, addr 3> on usbus0
lo0: link state changed to UP
pflog0: permanently promiscuous mode enabled
re0: link state changed to UP
re1: link state changed to UP
re0: link state changed to DOWN
re0: link state changed to UP
```

### 5.2 Encryption performance

Let's then take a look at the encryption performance. The result show 318361.38k at 64 bytes, which certainly reaches FriendlyELEC's claims[^friendlyelec].

```bash
root@OPNsense:~ # openssl speed -evp aes-256-gcm
Doing aes-256-gcm for 3s on 16 size blocks: 22659225 aes-256-gcm's in 3.09s
Doing aes-256-gcm for 3s on 64 size blocks: 15039777 aes-256-gcm's in 3.02s
Doing aes-256-gcm for 3s on 256 size blocks: 5707717 aes-256-gcm's in 3.05s
Doing aes-256-gcm for 3s on 1024 size blocks: 1605998 aes-256-gcm's in 3.03s
Doing aes-256-gcm for 3s on 8192 size blocks: 213267 aes-256-gcm's in 3.05s
Doing aes-256-gcm for 3s on 16384 size blocks: 107378 aes-256-gcm's in 3.07s
OpenSSL 1.1.1t-freebsd  7 Feb 2023
built on: reproducible build, date unspecified
options:bn(64,64) rc4(int) des(int) aes(partial) idea(int) blowfish(ptr)
compiler: clang
The 'numbers' are in 1000s of bytes per second processed.
type             16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes  16384 bytes
aes-256-gcm     117483.78k   318361.38k   478338.80k   542529.30k   571935.19k   572997.42k
```

Let's also take a comparsion to other devices that I have.

Nanopi R4S runing OpenWRT 22.03.3

```bash
$ openssl speed -evp aes-256-gcm
Doing aes-256-gcm for 3s on 16 size blocks: 15531106 aes-256-gcm's in 2.99s
Doing aes-256-gcm for 3s on 64 size blocks: 5110094 aes-256-gcm's in 2.99s
Doing aes-256-gcm for 3s on 256 size blocks: 1399361 aes-256-gcm's in 2.99s
Doing aes-256-gcm for 3s on 1024 size blocks: 357787 aes-256-gcm's in 3.00s
Doing aes-256-gcm for 3s on 8192 size blocks: 45123 aes-256-gcm's in 2.99s
Doing aes-256-gcm for 3s on 16384 size blocks: 22567 aes-256-gcm's in 2.98s
OpenSSL 1.1.1u  30 May 2023
built on: Sat Jun 17 10:56:58 2023 UTC
options:bn(64,64) rc4(char) des(int) aes(partial) blowfish(ptr) 
compiler: aarch64-openwrt-linux-musl-gcc -fPIC -pthread -Wa,--noexecstack -Wall -O3 -Os -pipe -mcpu=generic -fno-caller-saves -fno-plt -fhonour-copts -Wno-error=unused-but-set-variable -Wno-error=unused-result -Wformat -Werror=format-security -fstack-protector -D_FORTIFY_SOURCE=1 -Wl,-z,now -Wl,-z,relro -DPIC -fPIC -ffunction-sections -fdata-sections -Os -pipe -mcpu=generic -fno-caller-saves -fno-plt -fhonour-copts -Wno-error=unused-but-set-variable -Wno-error=unused-result -Wformat -Werror=format-security -fstack-protector -fPIC -ffunction-sections -fdata-sections -znow -zrelro -DOPENSSL_USE_NODELETE -DOPENSSL_PIC -DOPENSSL_CPUID_OBJ -DOPENSSL_BN_ASM_MONT -DSHA1_ASM -DSHA256_ASM -DSHA512_ASM -DKECCAK1600_ASM -DVPAES_ASM -DECP_NISTZ256_ASM -DPOLY1305_ASM -DNDEBUG -D_FORTIFY_SOURCE=1 -DPIC -DOPENSSL_SMALL_FOOTPRINT
The 'numbers' are in 1000s of bytes per second processed.
type             16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes  16384 bytes
aes-256-gcm      83109.60k   109379.94k   119811.51k   122124.63k   123627.97k   124073.06k
```

Rock 5B running Gentoo Linux

```bash
$ openssl speed -evp aes-256-gcm
Doing AES-256-GCM for 3s on 16 size blocks: 59922571 AES-256-GCM's in 3.00s
Doing AES-256-GCM for 3s on 64 size blocks: 40697794 AES-256-GCM's in 3.00s
Doing AES-256-GCM for 3s on 256 size blocks: 15779876 AES-256-GCM's in 3.00s
Doing AES-256-GCM for 3s on 1024 size blocks: 4983462 AES-256-GCM's in 2.99s
Doing AES-256-GCM for 3s on 8192 size blocks: 680420 AES-256-GCM's in 2.99s
Doing AES-256-GCM for 3s on 16384 size blocks: 341334 AES-256-GCM's in 3.00s
version: 3.0.9
built on: Sun Jul 23 18:01:08 2023 UTC
options: bn(64,64)
compiler: aarch64-unknown-linux-gnu-gcc -fPIC -pthread -Wa,--noexecstack -O2 -march=armv8.2-a+crypto+fp16+rcpc+dotprod -mtune=cortex-a76.cortN
CPUINFO: OPENSSL_armcap=0xbd
The 'numbers' are in 1000s of bytes per second processed.
type             16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes  16384 bytes
AES-256-GCM     319587.05k   868219.61k  1346549.42k  1706710.73k  1864214.26k  1864138.75k
```

Odroid N2 running Gentoo Linux

```bash
$ openssl speed -evp aes-256-gcm
Doing AES-256-GCM for 3s on 16 size blocks: 28868677 AES-256-GCM's in 3.00s
Doing AES-256-GCM for 3s on 64 size blocks: 19435758 AES-256-GCM's in 3.00s
Doing AES-256-GCM for 3s on 256 size blocks: 8221697 AES-256-GCM's in 3.00s
Doing AES-256-GCM for 3s on 1024 size blocks: 3039490 AES-256-GCM's in 3.00s
Doing AES-256-GCM for 3s on 8192 size blocks: 421912 AES-256-GCM's in 3.00s
Doing AES-256-GCM for 3s on 16384 size blocks: 212736 AES-256-GCM's in 3.00s
version: 3.0.9
built on: Sun Jul 23 18:02:40 2023 UTC
options: bn(64,64)
compiler: aarch64-unknown-linux-gnu-gcc -fPIC -pthread -Wa,--noexecstack -O2 -march=armv8-a+crc+fp+simd+crypto -mtune=cortex-a73.cortex-a53 -mcpu=cortex-a73.cortex-a53+crc+fp+simd+crypto -fomit-frame-pointer -ftree-vectorize --param l1-cache-size=32 --param l1-cache-line-size=64 --param l2-cache-size=256 -fno-strict-aliasing -Wa,--noexecstack -DOPENSSL_USE_NODELETE -DOPENSSL_PIC -DOPENSSL_BUILDING_OPENSSL -DNDEBUG -DL_ENDIAN
CPUINFO: OPENSSL_armcap=0xbd
The 'numbers' are in 1000s of bytes per second processed.
type             16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes  16384 bytes
AES-256-GCM     153966.28k   414629.50k   701584.81k  1037479.25k  1152101.03k  1161822.21k
```

RPI4 runing Freebsd 13.2

```bash
$ openssl speed -evp aes-256-gcm
Doing aes-256-gcm for 3s on 16 size blocks: 4740209 aes-256-gcm's in 3.00s
Doing aes-256-gcm for 3s on 64 size blocks: 1354746 aes-256-gcm's in 3.10s
Doing aes-256-gcm for 3s on 256 size blocks: 345494 aes-256-gcm's in 3.08s
Doing aes-256-gcm for 3s on 1024 size blocks: 85985 aes-256-gcm's in 3.04s
Doing aes-256-gcm for 3s on 8192 size blocks: 10650 aes-256-gcm's in 3.02s
Doing aes-256-gcm for 3s on 16384 size blocks: 5335 aes-256-gcm's in 3.02s
OpenSSL 1.1.1t-freebsd  7 Feb 2023
built on: reproducible build, date unspecified
options:bn(64,64) rc4(int) des(int) aes(partial) idea(int) blowfish(ptr) 
compiler: clang
The 'numbers' are in 1000s of bytes per second processed.
type             16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes  16384 bytes
aes-256-gcm      25281.11k    27954.86k    28733.88k    28972.30k    28930.92k    28910.35k
```

### 5.3 Ethernet speed

I only have two devices with 2.5G Ethernet: Rock 5B and this R6S.

Let's test the WAN for 1G Ethernet first. The result shows the device could reach 940 Mbps. But it acts strange that its speed is slower in direct mode.

```bash
root@OPNsense:~ # ifconfig re1
re1: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> metric 0 mtu 1500
        description: WAN (wan)
        options=2008<VLAN_MTU,WOL_MAGIC>
        ether 58...d9
        inet6 fe...d9%re1 prefixlen 64 scopeid 0x2
        inet6 24...d9 prefixlen 64 autoconf
        inet6 fd...d9 prefixlen 64 autoconf
        inet6 24...9c prefixlen 128
        inet6 fd...9c prefixlen 128
        inet 10.8.5.133 netmask 0xffffff00 broadcast 10.8.5.255
        media: Ethernet autoselect (1000baseT <full-duplex>)
        status: active
        nd6 options=23<PERFORMNUD,ACCEPT_RTADV,AUTO_LINKLOCAL>
root@OPNsense:~ # iperf3 -c 10.8.5.5
Connecting to host 10.8.5.5, port 5201
[  5] local 10.8.5.133 port 44874 connected to 10.8.5.5 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   103 MBytes   865 Mbits/sec   31    221 KBytes
[  5]   1.00-2.00   sec   103 MBytes   867 Mbits/sec   34   67.0 KBytes       
[  5]   2.00-3.00   sec   103 MBytes   868 Mbits/sec   35    247 KBytes       
[  5]   3.00-4.00   sec   104 MBytes   870 Mbits/sec   35    153 KBytes       
[  5]   4.00-5.00   sec   103 MBytes   867 Mbits/sec   31    165 KBytes       
[  5]   5.00-6.00   sec   103 MBytes   868 Mbits/sec   32    204 KBytes       
[  5]   6.00-7.00   sec   103 MBytes   865 Mbits/sec   33    127 KBytes       
[  5]   7.00-8.00   sec   104 MBytes   872 Mbits/sec   34   67.0 KBytes       
[  5]   8.00-9.00   sec   103 MBytes   867 Mbits/sec   31    190 KBytes       
[  5]   9.00-10.00  sec   103 MBytes   868 Mbits/sec   32    255 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  1.01 GBytes   868 Mbits/sec  328             sender
[  5]   0.00-10.00  sec  1.01 GBytes   867 Mbits/sec                  receiver

iperf Done.
root@OPNsense:~ # iperf3 -c 10.8.5.5 -R
Connecting to host 10.8.5.5, port 5201
Reverse mode, remote host 10.8.5.5 is sending
[  5] local 10.8.5.133 port 38665 connected to 10.8.5.5 port 5201
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec   111 MBytes   935 Mbits/sec
[  5]   1.00-2.00   sec   112 MBytes   941 Mbits/sec
[  5]   2.00-3.00   sec   112 MBytes   941 Mbits/sec
[  5]   3.00-4.00   sec   112 MBytes   941 Mbits/sec
[  5]   4.00-5.00   sec   112 MBytes   940 Mbits/sec
[  5]   5.00-6.00   sec   112 MBytes   941 Mbits/sec
[  5]   6.00-7.00   sec   112 MBytes   941 Mbits/sec
[  5]   7.00-8.00   sec   112 MBytes   941 Mbits/sec
[  5]   8.00-9.00   sec   112 MBytes   941 Mbits/sec
[  5]   9.00-10.00  sec   112 MBytes   941 Mbits/sec
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  1.10 GBytes   942 Mbits/sec    0             sender
[  5]   0.00-10.00  sec  1.09 GBytes   940 Mbits/sec                  receiver

iperf Done.
```

Then, we plug the Rock 5B into the LAN and test. `ethtool` showing 2500Mb/s at the Rock 5B side.

```bash
root@rock5b ~ # ethtool eth0
Settings for eth0:
        Supported ports: [ TP ]
        Supported link modes:   10baseT/Half 10baseT/Full
                                100baseT/Half 100baseT/Full
                                1000baseT/Full
                                2500baseT/Full
        Supported pause frame use: Symmetric Receive-only
        Supports auto-negotiation: Yes
        Supported FEC modes: Not reported
        Advertised link modes:  10baseT/Half 10baseT/Full
                                100baseT/Half 100baseT/Full
                                1000baseT/Full
                                2500baseT/Full
        Advertised pause frame use: Symmetric Receive-only
        Advertised auto-negotiation: Yes
        Advertised FEC modes: Not reported
        Link partner advertised link modes:  10baseT/Half 10baseT/Full
                                             100baseT/Half 100baseT/Full
                                             1000baseT/Full
                                             2500baseT/Full
        Link partner advertised pause frame use: Symmetric Receive-only
        Link partner advertised auto-negotiation: Yes
        Link partner advertised FEC modes: Not reported
        Speed: 2500Mb/s
        Duplex: Full
        Auto-negotiation: on
        Port: Twisted Pair
        PHYAD: 0
        Transceiver: internal
        MDI-X: Unknown
        Supports Wake-on: pumbg
        Wake-on: g
        Current message level: 0x00000033 (51)
                               drv probe ifdown ifup
        Link detected: yes
```

Although R6S also reports `2500Base-T <full-duplex>` mode, the result fails to meet our expectations.

```bash
root@OPNsense:~ # ifconfig re0
re0: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> metric 0 mtu 1500
        description: LAN (lan)
        options=2008<VLAN_MTU,WOL_MAGIC>
        ether 58:9c:fc:10:1a:fb
        inet 192.168.1.1 netmask 0xffffff00 broadcast 192.168.1.255
        media: Ethernet autoselect (2500Base-T <full-duplex>)
        status: active
        nd6 options=29<PERFORMNUD,IFDISABLED,AUTO_LINKLOCAL>
root@OPNsense:~ # iperf3 -c 192.168.1.102
Connecting to host 192.168.1.102, port 5201
[  5] local 192.168.1.1 port 29443 connected to 192.168.1.102 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec  70.8 MBytes   593 Mbits/sec  142   67.0 KBytes
[  5]   1.00-2.00   sec  71.2 MBytes   597 Mbits/sec  142   65.6 KBytes       
[  5]   2.00-3.00   sec  70.9 MBytes   595 Mbits/sec  143   7.13 KBytes       
[  5]   3.00-4.00   sec  70.4 MBytes   590 Mbits/sec  141   82.7 KBytes       
[  5]   4.00-5.00   sec  71.3 MBytes   598 Mbits/sec  148   35.7 KBytes       
[  5]   5.00-6.00   sec  71.0 MBytes   596 Mbits/sec  143   55.6 KBytes       
[  5]   6.00-7.00   sec  70.5 MBytes   591 Mbits/sec  146   77.0 KBytes       
[  5]   7.00-8.00   sec  71.1 MBytes   597 Mbits/sec  141   4.28 KBytes       
[  5]   8.00-9.00   sec  71.0 MBytes   596 Mbits/sec  147   2.85 KBytes       
[  5]   9.00-10.00  sec  71.3 MBytes   598 Mbits/sec  145   1.43 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec   709 MBytes   595 Mbits/sec  1438             sender
[  5]   0.00-10.25  sec   709 MBytes   581 Mbits/sec                  receiver

iperf Done.
root@OPNsense:~ # iperf3 -c 192.168.1.102 -R
Connecting to host 192.168.1.102, port 5201
Reverse mode, remote host 192.168.1.102 is sending
[  5] local 192.168.1.1 port 60411 connected to 192.168.1.102 port 5201
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec  38.8 MBytes   326 Mbits/sec
[  5]   1.00-2.00   sec  39.0 MBytes   327 Mbits/sec
[  5]   2.00-3.00   sec  39.0 MBytes   327 Mbits/sec
[  5]   3.00-4.00   sec  39.0 MBytes   327 Mbits/sec
[  5]   4.00-5.00   sec  39.0 MBytes   327 Mbits/sec
[  5]   5.00-6.00   sec  39.0 MBytes   327 Mbits/sec
[  5]   6.00-7.00   sec  39.1 MBytes   328 Mbits/sec
[  5]   7.00-8.00   sec  39.2 MBytes   329 Mbits/sec
[  5]   8.00-9.00   sec  39.2 MBytes   329 Mbits/sec
[  5]   9.00-10.00  sec  39.2 MBytes   329 Mbits/sec
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec   392 MBytes   328 Mbits/sec    0             sender
[  5]   0.00-10.00  sec   391 MBytes   328 Mbits/sec                  receiver

iperf Done.
```

Then I notice that A `Cortex-A55` core is running at full speed on the run. I suspect the system does not correctly handle the IRQs. The result shows significant improvement but still fails to meet our expectations. But at least we know the port reaches over 1 Gbps.

```bash
root@OPNsense:~ # cpuset -l 6-7 -C -p 0
root@OPNsense:~ # iperf3 -c 192.168.1.102
Connecting to host 192.168.1.102, port 5201
[  5] local 192.168.1.1 port 43559 connected to 192.168.1.102 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   143 MBytes  1.20 Gbits/sec   18    154 KBytes       
[  5]   1.00-2.00   sec   144 MBytes  1.21 Gbits/sec   20   41.3 KBytes       
[  5]   2.00-3.00   sec   143 MBytes  1.20 Gbits/sec   19   61.3 KBytes       
[  5]   3.00-4.00   sec   144 MBytes  1.21 Gbits/sec   19   41.3 KBytes       
[  5]   4.00-5.00   sec   143 MBytes  1.20 Gbits/sec   18    153 KBytes       
[  5]   5.00-6.00   sec   147 MBytes  1.23 Gbits/sec   19   95.5 KBytes       
[  5]   6.00-7.00   sec   147 MBytes  1.23 Gbits/sec   20    107 KBytes       
[  5]   7.00-8.00   sec   145 MBytes  1.21 Gbits/sec   18    137 KBytes       
[  5]   8.00-9.00   sec   144 MBytes  1.21 Gbits/sec   19   25.7 KBytes       
[  5]   9.00-10.00  sec   142 MBytes  1.20 Gbits/sec   19   65.6 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  1.41 GBytes  1.21 Gbits/sec  189             sender
[  5]   0.00-10.00  sec  1.41 GBytes  1.21 Gbits/sec                  receiver

iperf Done.
root@OPNsense:~ # iperf3 -c 192.168.1.102 -R
Connecting to host 192.168.1.102, port 5201
Reverse mode, remote host 192.168.1.102 is sending
[  5] local 192.168.1.1 port 18188 connected to 192.168.1.102 port 5201
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec   126 MBytes  1.06 Gbits/sec
[  5]   1.00-2.00   sec   126 MBytes  1.06 Gbits/sec
[  5]   2.00-3.00   sec   126 MBytes  1.06 Gbits/sec
[  5]   3.00-4.00   sec   126 MBytes  1.05 Gbits/sec
[  5]   4.00-5.00   sec   126 MBytes  1.06 Gbits/sec
[  5]   5.00-6.00   sec   126 MBytes  1.05 Gbits/sec
[  5]   6.00-7.00   sec   126 MBytes  1.06 Gbits/sec
[  5]   7.00-8.00   sec   126 MBytes  1.06 Gbits/sec
[  5]   8.00-9.00   sec   126 MBytes  1.06 Gbits/sec
[  5]   9.00-10.00  sec   126 MBytes  1.06 Gbits/sec
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.00  sec  1.23 GBytes  1.06 Gbits/sec    0             sender
[  5]   0.00-10.00  sec  1.23 GBytes  1.06 Gbits/sec                  receiver

iperf Done.
```

## 6 Conclusion and future works

We have got OPNsense running on Nanopi R6S through UEFI firmware. The system boots but still have some problems.

Some are related to the UEFI firmware, for example, the GMAC Ethernet. Hopefully, they will be solved by the updates.

Some are expected, including the USB 2.0 port, SD card, and eMMC, that are not working. For the Ethernet speed, I will look deeper into the IRQs to see if there is a solution.

Finally, the official and Mainline U-Boot could also be worth a try.


[^wiki]: https://wiki.friendlyelec.com/wiki/index.php/NanoPi_R6S#Introduction
[^friendlyelec]: https://www.friendlyelec.com/index.php?route=product/product&product_id=289
[^radxa]: https://github.com/radxa/u-boot/issues/12
[^initdc]: https://github.com/edk2-porting/edk2-rk3588/commit/4815cc03c0ebedc058abd8e0b72cd56ca841fa3f
