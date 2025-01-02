---
title: "OPNsense 22 for aarch64"
date: 2022-02-17T14:33:00+08:00
tags: [OPNsense, FreeBSD, aarch64, rpi3, rpi4, r4s, ESXi, QEMU, KVM]
resources:
featuredImage: "/images/opnsense-22-for-aarch64/dashboard.png"
featuredImagePreview: "/images/opnsense-22-for-aarch64/dashboard-preview.png"
---

- These experimental images are NOT official releases. It's a proof of concept that OPNsense is workable for aarch64. Use at your own risk.
- As of version 22, OPNsense is now based on FreeBSD 13. Therefore, all the devices on [this wiki page](https://wiki.freebsd.org/arm64) shall all work under good development. **Raspberry Pi 4** and **NanoPi R4S** are added here.
- The `OPNsense-${VER}-OpenSSL-vm-aarch64.vmdk` image works for [ESXi](#31-esxi) and [QEMU](#32-qemu).
- The `OPNsense-${VER}-OpenSSL-arm-aarch64-RPI.img` image works for Raspberry Pi 3b, 3b+ and 4b, while the `OPNsense-${VER}-OpenSSL-arm-aarch64-R4S.img` image works for NanoPi R4S. See [section 4](#4-rpis-and-r4s) for details.

## 1 Introduction

The OPNsense images for aarch64 are built on FreeBSD aarch64 using the tools[^tools].

* [OPNsense 22.1 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/22.1)
* [OPNsense 22.1.10 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/22.1.10)
* [OPNsense 22.7 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/22.7)
* [OPNsense 22.7.5 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/22.7.5)
* [OPNsense 22.7.11 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/22.7.11)

Please visit OPNsense forum[^forum] if you encountered any problems. You can also [create an issue](https://github.com/yrzr/opnsense-tools/issues?q=is%3Aissue) if you believe I can help.

The default user name and password is `root:opnsense` for a fresh install.

## 2 Commons

### 2.1 Repo

You can use my firmware repo ~~https://ftp.yrzr.tk/opnsense~~ ~~http://147.8.92.207/opnsense (update on 2024/03/28, the domain yrzr.tk is no longer used, see [this post](../hello-github-io/))~~ [http://168.138.176.159/opnsense/](http://168.138.176.159/opnsense/) (update on 2025/01/01) as the repo URL to get almost all the plugins as if on AMD64 and the updates (however, I will not update the packages frequently).

Accept the fingerprint of my server from the shell:

```bash
curl http://147.8.92.207/opnsense/fingerprint -o /usr/local/etc/pkg/fingerprints/OPNsense/trusted/yrzr
```

Then modify the `Mirror` section in `System/Firmware/Settings` on WebUI to `(other)` and `http://147.8.92.207/opnsense`.

![Alt text](/images/opnsense-22-for-aarch64/mirror.png "Modify the Mirror section.")

Check updates and then go to `System/Firmware/Plugins` to download the plugins you want.

![Alt text](/images/opnsense-22-for-aarch64/plugins.png "Plugins list.")

You can also edit `/usr/local/etc/pkg/repos/OPNsense.conf` as an alternative option:

```txt
OPNsense: {
  fingerprints: "/usr/local/etc/pkg/fingerprints/OPNsense",
  url: "pkg+http://147.8.92.207/opnsense/${ABI}/22.X/latest",
  signature_type: "NONE",
  mirror_type: "NONE",
  priority: 11,
  enabled: yes
}
```

### 2.2 Extract

Install `lzop` for `.lzo` files:

```bash
lzop -x OPNsense-*-OpenSSL-*-aarch64*.*.lzo
```

Install `xz-utils` for `.xz` files:

```bash
xz -d OPNsense-*-OpenSSL-*-aarch64*.*.xz
```

`.lzo` files take much lower CPU and memory consumption and are extremely fast, while `.xz` files are smaller.

## 3 Virtual machines

### 3.1 ESXi

Install ESXi on RPI4 (4g or 8g version only) from the official website[^ESXi]. Then, convert the `vmdk` image from the shell of ESXi:

```bash
vmkfstools -i OPNsense-*-OpenSSL-vm-aarch64.vmdk OPNsense-out.vmdk
```

You can also resize the virtual disk size as you want:

```bash
vmkfstools -X 32G OPNsense-out.vmdk
```

Finally, import the `OPNsense-out.vmdk` to your virtual machine as the boot disk and run.

### 3.2 QEMU

Convert `vmdk` image to `raw` image:

```bash
qemu-img convert -f vmdk -O raw OPNsense-*-OpenSSL-vm-aarch64.vmdk OPNsense-out.raw
```

Download and compile U-Boot(`u-boot.bin`):

```bash
git clone -b v2021.07 --depth=1 https://github.com/u-boot/u-boot.git
make -C u-boot qemu_arm64_defconfig
make -C u-boot
```

Run virtual machine with **KVM** on aarch64 machines using the `u-boot.bin` file as the firmware (RPI4 with 64-bit Raspbian OS, for example):

```bash
qemu-system-aarch64 \
  -bios u-boot.bin \
  -M virt,gic-version=max \
  -enable-kvm \
  -cpu host,pmu=off \
  -smp 1 \
  -m 1024M \
  -nographic \
  -drive format=raw,file=OPNsense-out.raw,cache=none,if=virtio
```

Or **emulate** from AMD64 machines:

```bash
qemu-system-aarch64 \
  -bios u-boot.bin \
  -M virt,gic-version=max \
  -cpu cortex-a57 \
  -smp 4 \
  -m 1024M \
  -nographic \
  -drive format=raw,file=OPNsense-out.raw,cache=none,if=virtio
```

Don't forget to add your network-related options.

For more information, you can also refer to the FreeBSD wiki[^qemu_wiki].

## 4 RPIs and R4S

- The RPI images are built for aarch64. Therefore, RPIs with SoCs before BCM2837 will NOT be compatible.

### 4.1 Writing the image

The image writing process is trivial, so that you can refer to the official document of RPI [^document].

Here is an example of writing to the disk under UNIX-like systems using the `dd` command.

```bash
sudo dd status=progress if=OPNsense-${VER}-OpenSSL-arm-aarch64-{RPI,R4S}.img of=/dev/sdX bs=8M conv=fsync
```

Now you can insert the sd card into your device and power on it.

### 4.2 Modify `config.txt` (RPI only)

The `config.txt` in the first partition needs to be modified depending on the RPI model you get. There are also `config_rpi*.txt` files for your reference.

Additionally, you can add the following lines in `config.txt` to enable serial console:

```txt
# Fix mini UART input frequency, and setup/enable up the UART.
uart_2ndstage=1
enable_uart=1
```

### 4.3 Grow root partition

After the system is booted, you will need to grow the root partition in the shell manually.

```bash
service growfs onestart
```

### 4.4 Booting logs

Raspberry Pi 3

```txt
Loading kernel...
/boot/kernel/kernel text=0x2a8 text=0x924830 text=0x219e64 data=0x1b21c8 data=0x0+0x36a000 syms=[0x8+0x1312e0+0x8+0x156774]
Loading configured modules...
/boot/kernel/pfsync.ko text=0x2f1c text=0x7b24 data=0xb30+0x8 syms=[0x8+0x1800+0x8+0x117d]
loading required module 'pf'
/boot/kernel/pf.ko text=0xe344 text=0x3dc7c data=0x59c0+0x39c syms=[0x8+0x5910+0x8+0x46ec]
/boot/kernel/if_gre.ko text=0x2736 text=0x4938 data=0x8c8+0x40 syms=[0x8+0x16f8+0x8+0xfaf]
/boot/kernel/if_enc.ko text=0x15ca text=0x934 data=0x750 syms=[0x8+0xca8+0x8+0xb71]
/boot/entropy size=0x1000
/boot/kernel/if_lagg.ko text=0x3c93 text=0xa41c data=0xd08+0x8 syms=[0x8+0x1c80+0x8+0x15a6]
loading required module 'if_infiniband'
/boot/kernel/if_infiniband.ko text=0x1102 text=0x10fc data=0x300+0x8 syms=[0x8+0x8d0+0x8+0x59a]
/boot/kernel/pflog.ko text=0xf78 text=0x898 data=0x430 syms=[0x8+0x9f0+0x8+0x712]
/etc/hostid size=0x25
/boot/kernel/if_bridge.ko text=0x3677 text=0x7168 data=0xd38+0x8 syms=[0x8+0x1b90+0x8+0x15b5]
loading required module 'bridgestp'
/boot/kernel/bridgestp.ko text=0x12e4 text=0x4acc data=0x2c8+0x28 syms=[0x8+0xb88+0x8+0x6e9]
/boot/kernel/carp.ko text=0x33ec text=0x6e54 data=0xc60+0x48 syms=[0x8+0x1980+0x8+0x1225]
Using DTB provided by EFI at 0x7ef5000.
EFI framebuffer information:
addr, size     0x3eaf0000, 0x10a800
dimensions     656 x 416
stride         656
masks          0x00ff0000, 0x0000ff00, 0x000000ff, 0xff000000
---<<BOOT>>---
KDB: debugger backends: ddb
KDB: current backend: ddb
WARNING: Cannot find freebsd,dts-version property, cannot check DTB compliance
Copyright (c) 1992-2021 The FreeBSD Project.
Copyright (c) 1979, 1980, 1983, 1986, 1988, 1989, 1991, 1992, 1993, 1994
        The Regents of the University of California. All rights reserved.
FreeBSD is a registered trademark of The FreeBSD Foundation.
FreeBSD 13.0-STABLE stable/22.1-n248056-228cd6949d3 SMP arm64
FreeBSD clang version 13.0.0 (git@github.com:llvm/llvm-project.git llvmorg-13.0.0-0-gd7b669b3a303)
VT(efifb): resolution 656x416
module firmware already present!
real memory  = 993845248 (947 MB)
avail memory = 943996928 (900 MB)
Starting CPU 1 (1)
Starting CPU 2 (2)
Starting CPU 3 (3)
FreeBSD/SMP: Multiprocessor System Detected: 4 CPUs
random: unblocking device.
random: entropy device external interface
MAP 39f38000 mode 2 pages 4
MAP 39f3d000 mode 2 pages 4
MAP 3b350000 mode 2 pages 16
MAP 3f100000 mode 0 pages 1
kbd0 at kbdmux0
ofwbus0: <Open Firmware Device Tree>
simplebus0: <Flattened device tree simple bus> on ofwbus0
ofw_clkbus0: <OFW clocks bus> on ofwbus0
clk_fixed0: <Fixed clock> on ofw_clkbus0
clk_fixed1: <Fixed clock> on ofw_clkbus0
regfix0: <Fixed Regulator> on ofwbus0
regfix1: <Fixed Regulator> on ofwbus0
bcm2835_firmware0: <BCM2835 Firmware> on simplebus0
ofw_clkbus1: <OFW clocks bus> on bcm2835_firmware0
psci0: <ARM Power State Co-ordination Interface Driver> on ofwbus0
lintc0: <BCM2836 Interrupt Controller> mem 0x40000000-0x400000ff on simplebus0
intc0: <BCM2835 Interrupt Controller> mem 0x7e00b200-0x7e00b3ff irq 39 on simplebus0
gpio0: <BCM2708/2835 GPIO controller> mem 0x7e200000-0x7e2000b3 irq 7,8 on simplebus0
gpiobus0: <OFW GPIO bus> on gpio0
gpio1: <Raspberry Pi Firmware GPIO controller> on bcm2835_firmware0
gpiobus1: <GPIO bus> on gpio1
mbox0: <BCM2835 VideoCore Mailbox> mem 0x7e00b880-0x7e00b8bf irq 6 on simplebus0
generic_timer0: <ARMv7 Generic Timer> irq 1,2,3,4 on ofwbus0
Timecounter "ARM MPCore Timecounter" frequency 19200000 Hz quality 1000
Event timer "ARM MPCore Eventtimer" frequency 19200000 Hz quality 1000
usb_nop_xceiv0: <USB NOP PHY> on ofwbus0
bcm2835_clkman0: <BCM283x Clock Manager> mem 0x7e101000-0x7e102fff on simplebus0
gpioc0: <GPIO controller> on gpio0
uart0: <PrimeCell UART (PL011)> mem 0x7e201000-0x7e2011ff irq 9 on simplebus0
uart0: console (115200,n,8,1)
spi0: <BCM2708/2835 SPI controller> mem 0x7e204000-0x7e2041ff irq 11 on simplebus0
spibus0: <OFW SPI bus> on spi0
spibus0: <unknown card> at cs 0 mode 0
spibus0: <unknown card> at cs 1 mode 0
iichb0: <BCM2708/2835 BSC controller> mem 0x7e804000-0x7e804fff irq 19 on simplebus0
bcm283x_dwcotg0: <DWC OTG 2.0 integrated USB controller (bcm283x)> mem 0x7e980000-0x7e98ffff,0x7e006000-0x7e006fff irq 21,22 on simplebus0
usbus1 on bcm283x_dwcotg0
bcm_dma0: <BCM2835 DMA Controller> mem 0x7e007000-0x7e007eff irq 23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38 on simplebus0
bcmwd0: <BCM2708/2835 Watchdog> mem 0x7e100000-0x7e100113,0x7e00a000-0x7e00a023 on simplebus0
bcmrng0: <Broadcom BCM2835/BCM2838 RNG> mem 0x7e104000-0x7e10400f irq 40 on simplebus0
sdhci_bcm0: <Broadcom 2708 SDHCI controller> mem 0x7e300000-0x7e3000ff irq 48 on simplebus0
mmc0: <MMC/SD bus> on sdhci_bcm0
gpioc1: <GPIO controller> on gpio1
fb0: <BCM2835 VT framebuffer driver> on simplebus0
fb0: keeping existing fb bpp of 32
fbd0 on fb0
WARNING: Device "fb" is Giant locked and may be deleted before FreeBSD 14.0.
VT: Replacing driver "efifb" with new "fb".
fb0: 656x416(656x416@0,0) 32bpp
fb0: fbswap: 1, pitch 2624, base 0x3eaf0000, screen_size 1091584
pmu0: <Performance Monitoring Unit> irq 0 on ofwbus0
cpulist0: <Open Firmware CPU Group> on ofwbus0
cpu0: <Open Firmware CPU> on cpulist0
bcm2835_cpufreq0: <CPU Frequency Control> on cpu0
cpu1: <Open Firmware CPU> on cpulist0
cpu2: <Open Firmware CPU> on cpulist0
cpu3: <Open Firmware CPU> on cpulist0
gpioled0: <GPIO LEDs> on ofwbus0
armv8crypto0: CPU lacks AES instructions
Timecounters tick every 1.000 msec
usbus1: 480Mbps High Speed USB v2.0
iicbus0: <OFW I2C bus> on iichb0
iic0: <I2C generic I/O> on iicbus0
ugen1.1: <DWCOTG OTG Root HUB> at usbus1
uhub0 on usbus1
uhub0: <DWCOTG OTG Root HUB, class 9/0, rev 2.00/1.00, addr 1> on usbus1
mmcsd0: 32GB <SDHC SC32G 8.0 SN 9D401AD9 MFG 10/2018 by 3 SD> at mmc0 50.0MHz/4bit/65535-block
bcm2835_cpufreq0: ARM 600MHz, Core 250MHz, SDRAM 400MHz, Turbo OFF
CPU  0: ARM Cortex-A53 r0p4 affinity:  0
                   Cache Type = <64 byte D-cacheline,64 byte I-cacheline,VIPT ICache,64 byte ERG,64 byte CWG>
 Instruction Set Attributes 0 = <CRC32>
 Instruction Set Attributes 1 = <>
         Processor Features 0 = <AdvSIMD,FP,EL3 32,EL2 32,EL1 32,EL0 32>
Trying to mount root from ufs:/dev/ufs/OPNsense [rw]...
         Processor Features 1 = <>
      Memory Model Features 0 = <TGran4,TGran64,SNSMem,BigEnd,16bit ASID,1TB PA>
      Memory Model Features 1 = <8bit VMID>
      Memory Model Features 2 = <32bit CCIDX,48bit VA>
             Debug Features 0 = <DoubleLock,2 CTX BKPTs,4 Watchpoints,6 Breakpoints,PMUv3,Debugv8>
             Debug Features 1 = <>
         Auxiliary Features 0 = <>
         Auxiliary Features 1 = <>
AArch32 Instruction Set Attributes 5 = <CRC32,SEVL>
AArch32 Media and VFP Features 0 = <FPRound,FPSqrt,FPDivide,DP VFPv3+v4,SP VFPv3+v4,AdvSIMD>
AArch32 Media and VFP Features 1 = <SIMDFMAC,FPHP DP Conv,SIMDHP SP Conv,SIMDSP,SIMDInt,SIMDLS,FPDNaN,FPFtZ>
CPU  1: ARM Cortex-A53 r0p4 affinity:  1
CPU  2: ARM Cortex-A53 r0p4 affinity:  2
CPU  3: ARM Cortex-A53 r0p4 affinity:  3
Release APs...done
Warning: no time-of-day clock registered, system time will not be set accurately
uhub0: 1 port with 1 removable, self powered
Mounting filesystems...
tunefs: soft updates remains unchanged as enabled
tunefs: file system reloaded
ugen1.2: <vendor 0x0424 product 0x2514> at usbus1
uhub1 on uhub0
uhub1: <vendor 0x0424 product 0x2514, class 9/0, rev 2.00/b.b3, addr 2> on usbus1
uhub1: MTT enabled
camcontrol: cam_lookup_pass: CAMGETPASSTHRU ioctl failed
cam_lookup_pass: No such file or directory
cam_lookup_pass: either the pass driver isn't in your kernel
cam_lookup_pass: or mmcsd0 doesn't exist
** /dev/ufs/OPNsense
FILE SYSTEM CLEAN; SKIPPING CHECKS
clean, 7219689 free (417 frags, 902409 blocks, 0.0% fragmentation)
uhub1: 4 ports with 3 removable, self powered
ugen1.3: <vendor 0x0424 product 0x2514> at usbus1
uhub2 on uhub1
uhub2: <vendor 0x0424 product 0x2514, class 9/0, rev 2.00/b.b3, addr 3> on usbus1
uhub2: MTT enabled
Setting hostuuid: 30303030-3030-3030-3139-663138353365.
Setting hostid: 0x56d89878.
Configuring vt: blanktime.
uhub2: 3 ports with 2 removable, self powered
ugen1.4: <vendor 0x0424 product 0x7800> at usbus1
muge0 on uhub2
muge0: <vendor 0x0424 product 0x7800, rev 2.10/3.00, addr 4> on usbus1
muge0: Chip ID 0x7800 rev 0002
miibus0: <MII bus> on muge0
ukphy0: <Generic IEEE 802.3u media interface> PHY 1 on miibus0
ukphy0:  none, 10baseT, 10baseT-FDX, 100baseTX, 100baseTX-FDX, 1000baseT, 1000baseT-master, 1000baseT-FDX, 1000baseT-FDX-master, auto
ue0: <USB Ethernet> on muge0
ue0: Ethernet address: b8:27:eb:f1:85:3e
Setting up memory disks...done.
Configuring crash dump device: /dev/null
.ELF ldconfig path: /lib /usr/lib /usr/lib/compat /usr/local/lib /usr/local/lib/compat/pkg /usr/local/lib/compat/pkg /usr/local/lib/ipsec /usr/local/lib/perlE
done.
>>> Invoking early script 'upgrade'
>>> Invoking early script 'configd'
Starting configd.
>>> Invoking early script 'templates'
Generating configuration: OK
>>> Invoking early script 'backup'
>>> Invoking backup script 'captiveportal'
>>> Invoking backup script 'dhcpleases'
>>> Invoking backup script 'duid'
>>> Invoking backup script 'netflow'
>>> Invoking backup script 'rrd'
>>> Invoking early script 'carp'
CARP event system: OK
Launching the init system...done.
Initializing...........done.
ue0: link state changed to DOWN
Starting device manager...done.
Configuring login behaviour...done.
Configuring loopback interface...done.
Configuring kernel modules...done.
Setting up extended sysctls...done.
Setting timezone...done.
Writing firmware setting...done.
Writing trust files...done.
Setting hostname: OPNsense.localdomain
Generating /etc/hosts...done.
Configuring system logging...done.
Configuring loopback interface...done.
Creating wireless clone interfaces...done.
Configuring WAN interface...done.
Creating IPsec VTI instances...done.
Generating /etc/resolv.conf...done.
Configuring firewall.......done.
Configuring OpenSSH...done.
Starting web GUI...done.
Setting up routes...done.
Generating /etc/hosts...done.
Starting Unbound DNS...done.
Setting up gateway monitors...done.
Configuring firewall.......done.
Syncing OpenVPN settings...done.
Starting NTP service...done.
Starting Unbound DNS...done.
Generating RRD graphs...done.
Configuring system logging...done.
>>> Invoking start script 'newwanip'
>>> Invoking start script 'freebsd'
>>> Invoking start script 'syslog-ng'
Stopping syslog_ng.
Waiting for PIDS: 18945.
Starting syslog_ng.
>>> Invoking start script 'carp'
>>> Invoking start script 'cron'
Starting Cron: OK
>>> Invoking start script 'beep'
>>> Error in start script 'beep'
Root file system: /dev/ufs/OPNsense
Tue Feb 15 03:33:45 UTC 2022

*** OPNsense.localdomain: OPNsense 22.1 (aarch64/OpenSSL) ***
```

Raspberry Pi 4

```txt
Loading kernel...
/boot/kernel/kernel text=0x2a8 text=0x924830 text=0x219e64 data=0x1b21c8 data=0x0+0x36a000 syms=[0x8+0x1312e0+0x8+0x156774]
Loading configured modules...
/boot/kernel/if_enc.ko text=0x15ca text=0x934 data=0x750 syms=[0x8+0xca8+0x8+0xb71]
/boot/kernel/pflog.ko text=0xf78 text=0x898 data=0x430 syms=[0x8+0x9f0+0x8+0x712]
loading required module 'pf'
/boot/kernel/pf.ko text=0xe344 text=0x3dc7c data=0x59c0+0x39c syms=[0x8+0x5910+0x8+0x46ec]
/boot/kernel/pfsync.ko text=0x2f1c text=0x7b24 data=0xb30+0x8 syms=[0x8+0x1800+0x8+0x117d]
/boot/kernel/if_lagg.ko text=0x3c93 text=0xa41c data=0xd08+0x8 syms=[0x8+0x1c80+0x8+0x15a6]
loading required module 'if_infiniband'
/boot/kernel/if_infiniband.ko text=0x1102 text=0x10fc data=0x300+0x8 syms=[0x8+0x8d0+0x8+0x59a]
/boot/kernel/if_bridge.ko text=0x3677 text=0x7168 data=0xd38+0x8 syms=[0x8+0x1b90+0x8+0x15b5]
loading required module 'bridgestp'
/boot/kernel/bridgestp.ko text=0x12e4 text=0x4acc data=0x2c8+0x28 syms=[0x8+0xb88+0x8+0x6e9]
/boot/entropy size=0x1000
/boot/kernel/carp.ko text=0x33ec text=0x6e54 data=0xc60+0x48 syms=[0x8+0x1980+0x8+0x1225]
/boot/kernel/if_gre.ko text=0x2736 text=0x4938 data=0x8c8+0x40 syms=[0x8+0x16f8+0x8+0xfaf]
/etc/hostid size=0x25
Using DTB provided by EFI at 0x7ef0000.
EFI framebuffer information:
addr, size     0x3eaf5000, 0x103000
dimensions     592 x 448
stride         592
masks          0x00ff0000, 0x0000ff00, 0x000000ff, 0xff000000
---<<BOOT>>---
KDB: debugger backends: ddb
KDB: current backend: ddb
WARNING: Cannot find freebsd,dts-version property, cannot check DTB compliance
Copyright (c) 1992-2021 The FreeBSD Project.
Copyright (c) 1979, 1980, 1983, 1986, 1988, 1989, 1991, 1992, 1993, 1994
        The Regents of the University of California. All rights reserved.
FreeBSD is a registered trademark of The FreeBSD Foundation.
FreeBSD 13.0-STABLE stable/22.1-n248053-232cb14f501 SMP arm64
FreeBSD clang version 13.0.0 (git@github.com:llvm/llvm-project.git llvmorg-13.0.0-0-gd7b669b3a303)
VT(efifb): resolution 592x448
module firmware already present!
real memory  = 4147916800 (3955 MB)
avail memory = 4019552256 (3833 MB)
Starting CPU 1 (1)
Starting CPU 2 (2)
Starting CPU 3 (3)
FreeBSD/SMP: Multiprocessor System Detected: 4 CPUs
random: unblocking device.
random: entropy device external interface
MAP 39f30000 mode 2 pages 1
MAP 39f34000 mode 2 pages 3
MAP 39f38000 mode 2 pages 4
MAP 3b350000 mode 2 pages 16
MAP fe100000 mode 0 pages 1
kbd0 at kbdmux0
ofwbus0: <Open Firmware Device Tree>
simplebus0: <Flattened device tree simple bus> on ofwbus0
ofw_clkbus0: <OFW clocks bus> on ofwbus0
clk_fixed0: <Fixed clock> on ofw_clkbus0
clk_fixed1: <Fixed clock> on ofw_clkbus0
clk_fixed2: <Fixed clock> on ofwbus0
clk_fixed3: <Fixed clock> on ofwbus0
simplebus1: <Flattened device tree simple bus> on ofwbus0
simplebus2: <Flattened device tree simple bus> on ofwbus0
regfix0: <Fixed Regulator> on ofwbus0
regfix1: <Fixed Regulator> on ofwbus0
regfix2: <Fixed Regulator> on ofwbus0
simplebus3: <Flattened device tree simple bus> on ofwbus0
simple_mfd0: <Simple MFD (Multi-Functions Device)> mem 0x7d5d2000-0x7d5d2eff on simplebus0
bcm2835_firmware0: <BCM2835 Firmware> on simplebus0
ofw_clkbus1: <OFW clocks bus> on bcm2835_firmware0
psci0: <ARM Power State Co-ordination Interface Driver> on ofwbus0
gic0: <ARM Generic Interrupt Controller> mem 0x40041000-0x40041fff,0x40042000-0x40043fff,0x40044000-0x40045fff,0x40046000-0x40047fff irq 30 on simplebus0
gic0: pn 0x2, arch 0x2, rev 0x1, implementer 0x43b irqs 256
gpio0: <BCM2708/2835 GPIO controller> mem 0x7e200000-0x7e2000b3 irq 14,15 on simplebus0
gpiobus0: <OFW GPIO bus> on gpio0
gpio1: <Raspberry Pi Firmware GPIO controller> on bcm2835_firmware0
gpiobus1: <GPIO bus> on gpio1
regfix0: Cannot set GPIO pin: 6
REGNODE_INIT failed: 6
regfix0: Cannot register regulator.
mbox0: <BCM2835 VideoCore Mailbox> mem 0x7e00b880-0x7e00b8bf irq 13 on simplebus0
gpioregulator0: <GPIO controlled regulator> on ofwbus0
generic_timer0: <ARMv8 Generic Timer> irq 4,5,6,7 on ofwbus0
Timecounter "ARM MPCore Timecounter" frequency 54000000 Hz quality 1000
Event timer "ARM MPCore Eventtimer" frequency 54000000 Hz quality 1000
usb_nop_xceiv0: <USB NOP PHY> on ofwbus0
gpioc0: <GPIO controller> on gpio0
uart0: <PrimeCell UART (PL011)> mem 0x7e201000-0x7e2011ff irq 16 on simplebus0
uart0: console (115200,n,8,1)
bcm_dma0: <BCM2835 DMA Controller> mem 0x7e007000-0x7e007aff irq 31,32,33,34,35,36,37,38,39,40,41 on simplebus0
bcmwd0: <BCM2708/2835 Watchdog> mem 0x7e100000-0x7e100113,0x7e00a000-0x7e00a023,0x7ec11000-0x7ec1101f on simplebus0
bcmrng0: <Broadcom BCM2835/BCM2838 RNG> mem 0x7e104000-0x7e104027 on simplebus0
gpioc1: <GPIO controller> on gpio1
sdhci_bcm0: <Broadcom 2708 SDHCI controller> mem 0x7e300000-0x7e3000ff irq 73 on simplebus0
mmc0: <MMC/SD bus> on sdhci_bcm0
fb0: <BCM2835 VT framebuffer driver> on simplebus0
fb0: keeping existing fb bpp of 32
fbd0 on fb0
WARNING: Device "fb" is Giant locked and may be deleted before FreeBSD 14.0.
VT: Replacing driver "efifb" with new "fb".
fb0: 592x448(592x448@0,0) 32bpp
fb0: fbswap: 1, pitch 2368, base 0x3eaf5000, screen_size 1060864
sdhci_bcm1: <Broadcom 2708 SDHCI controller> mem 0x7e340000-0x7e3400ff irq 79 on simplebus1
mmc1: <MMC/SD bus> on sdhci_bcm1
pmu0: <Performance Monitoring Unit> irq 0,1,2,3 on ofwbus0
cpulist0: <Open Firmware CPU Group> on ofwbus0
cpu0: <Open Firmware CPU> on cpulist0
bcm2835_cpufreq0: <CPU Frequency Control> on cpu0
cpu1: <Open Firmware CPU> on cpulist0
cpu2: <Open Firmware CPU> on cpulist0
cpu3: <Open Firmware CPU> on cpulist0
pcib0: <BCM2838-compatible PCI-express controller> mem 0x7d500000-0x7d50930f irq 80,81 on simplebus2
pcib0: hardware identifies as revision 0x304.
pci1: <PCI bus> on pcib0
pcib1: <PCI-PCI bridge> irq 91 at device 0.0 on pci1
pci2: <PCI bus> on pcib1
bcm_xhci0: <VL805 USB 3.0 controller (on the Raspberry Pi 4b)> irq 92 at device 0.0 on pci2
bcm_xhci0: 32 bytes context size, 64-bit DMA
usbus0 on bcm_xhci0
pci0: <PCI bus> on pcib0
pci0: failed to allocate bus number
device_attach: pci0 attach returned 6
genet0: <RPi4 Gigabit Ethernet> mem 0x7d580000-0x7d58ffff irq 82,83 on simplebus2
genet0: GENET version 5.0 phy 0x0000
miibus0: <MII bus> on genet0
brgphy0: <BCM54213PE 1000BASE-T media interface> PHY 1 on miibus0
brgphy0:  10baseT, 10baseT-FDX, 100baseTX, 100baseTX-FDX, 1000baseT, 1000baseT-master, 1000baseT-FDX, 1000baseT-FDX-master, auto
genet0: Ethernet address: dc:a6:32:06:9c:bb
gpioled0: <GPIO LEDs> on ofwbus0
armv8crypto0: CPU lacks AES instructions
Timecounters tick every 1.000 msec
usbus0: 5.0Gbps Super Speed USB v3.0
sdhci_bcm0-slot0: Got command interrupt 0x00030000, but there is no active command.
sdhci_bcm0-slot0: ============== REGISTER DUMP ==============
sdhci_bcm0-slot0: Sys addr: 0x00000000 | Version:  0x00009902
sdhci_bcm0-slot0: Blk size: 0x00000000 | Blk cnt:  0x00000000
sdhci_bcm0-slot0: Argument: 0x000001aa | Trn mode: 0x00000000
sdhci_bcm0-slot0: Present:  0x000f0000 | Host ctl: 0x00000001
sdhci_bcm0-slot0: Power:    0x0000000f | Blk gap:  0x00000000
sdhci_bcm0-slot0: Wake-up:  0x00000000 | Clock:    0x00003947
sdhci_bcm0-slot0: Timeout:  0x00000000 | Int stat: 0x00000000
sdhci_bcm0-slot0: Int enab: 0x01ff00bb | Sig enab: 0x01ff00bb
sdhci_bcm0-slot0: AC12 err: 0x00000000 | Host ctl2:0x00000000
sdhci_bcm0-slot0: Caps:     0x00000000 | Caps2:    0x00000000
sdhci_bcm0-slot0: Max curr: 0x00000001 | ADMA err: 0x00000000
sdhci_bcm0-slot0: ADMA addr:0x00000000 | Slot int: 0x00000000
sdhci_bcm0-slot0: ===========================================
ugen0.1: <0x1106 XHCI root HUB> at usbus0
uhub0 on usbus0
uhub0: <0x1106 XHCI root HUB, class 9/0, rev 3.00/1.00, addr 1> on usbus0
sdhci_bcm0-slot0: Got command interrupt 0x00030000, but there is no active command.
sdhci_bcm0-slot0: ============== REGISTER DUMP ==============
sdhci_bcm0-slot0: Sys addr: 0x00000000 | Version:  0x00009902
sdhci_bcm0-slot0: Blk size: 0x00000000 | Blk cnt:  0x00000000
sdhci_bcm0-slot0: Argument: 0x000001aa | Trn mode: 0x00000000
sdhci_bcm0-slot0: Present:  0x000f0000 | Host ctl: 0x00000001
sdhci_bcm0-slot0: Power:    0x0000000f | Blk gap:  0x00000000
sdhci_bcm0-slot0: Wake-up:  0x00000000 | Clock:    0x00003947
sdhci_bcm0-slot0: Timeout:  0x00000000 | Int stat: 0x00000000
sdhci_bcm0-slot0: Int enab: 0x01ff00bb | Sig enab: 0x01ff00bb
sdhci_bcm0-slot0: AC12 err: 0x00000000 | Host ctl2:0x00000000
sdhci_bcm0-slot0: Caps:     0x00000000 | Caps2:    0x00000000
sdhci_bcm0-slot0: Max curr: 0x00000001 | ADMA err: 0x00000000
sdhci_bcm0-slot0: ADMA addr:0x00000000 | Slot int: 0x00000000
sdhci_bcm0-slot0: ===========================================
sdhci_bcm0-slot0: Got command interrupt 0x00030000, but there is no active command.
sdhci_bcm0-slot0: ============== REGISTER DUMP ==============
sdhci_bcm0-slot0: Sys addr: 0x00000000 | Version:  0x00009902
sdhci_bcm0-slot0: Blk size: 0x00000000 | Blk cnt:  0x00000000
sdhci_bcm0-slot0: Argument: 0x000001aa | Trn mode: 0x00000000
sdhci_bcm0-slot0: Present:  0x000f0000 | Host ctl: 0x00000001
sdhci_bcm0-slot0: Power:    0x0000000f | Blk gap:  0x00000000
sdhci_bcm0-slot0: Wake-up:  0x00000000 | Clock:    0x00003947
sdhci_bcm0-slot0: Timeout:  0x00000000 | Int stat: 0x00000000
sdhci_bcm0-slot0: Int enab: 0x01ff00bb | Sig enab: 0x01ff00bb
sdhci_bcm0-slot0: AC12 err: 0x00000000 | Host ctl2:0x00000000
sdhci_bcm0-slot0: Caps:     0x00000000 | Caps2:    0x00000000
sdhci_bcm0-slot0: Max curr: 0x00000001 | ADMA err: 0x00000000
sdhci_bcm0-slot0: ADMA addr:0x00000000 | Slot int: 0x00000000
sdhci_bcm0-slot0: ===========================================
sdhci_bcm0-slot0: Got command interrupt 0x00030000, but there is no active command.
sdhci_bcm0-slot0: ============== REGISTER DUMP ==============
sdhci_bcm0-slot0: Sys addr: 0x00000000 | Version:  0x00009902
sdhci_bcm0-slot0: Blk size: 0x00000000 | Blk cnt:  0x00000000
sdhci_bcm0-slot0: Argument: 0x000001aa | Trn mode: 0x00000000
sdhci_bcm0-slot0: Present:  0x000f0000 | Host ctl: 0x00000001
sdhci_bcm0-slot0: Power:    0x0000000f | Blk gap:  0x00000000
sdhci_bcm0-slot0: Wake-up:  0x00000000 | Clock:    0x00003947
sdhci_bcm0-slot0: Timeout:  0x00000000 | Int stat: 0x00000000
sdhci_bcm0-slot0: Int enab: 0x01ff00bb | Sig enab: 0x01ff00bb
sdhci_bcm0-slot0: AC12 err: 0x00000000 | Host ctl2:0x00000000
sdhci_bcm0-slot0: Caps:     0x00000000 | Caps2:    0x00000000
sdhci_bcm0-slot0: Max curr: 0x00000001 | ADMA err: 0x00000000
sdhci_bcm0-slot0: ADMA addr:0x00000000 | Slot int: 0x00000000
sdhci_bcm0-slot0: ===========================================
sdhci_bcm0-slot0: Got command interrupt 0x00030000, but there is no active command.
sdhci_bcm0-slot0: ============== REGISTER DUMP ==============
sdhci_bcm0-slot0: Sys addr: 0x00000000 | Version:  0x00009902
sdhci_bcm0-slot0: Blk size: 0x00000000 | Blk cnt:  0x00000000
sdhci_bcm0-slot0: Argument: 0x00000000 | Trn mode: 0x00000000
sdhci_bcm0-slot0: Present:  0x000f0000 | Host ctl: 0x00000001
sdhci_bcm0-slot0: Power:    0x0000000f | Blk gap:  0x00000000
sdhci_bcm0-slot0: Wake-up:  0x00000000 | Clock:    0x00003947
sdhci_bcm0-slot0: Timeout:  0x00000000 | Int stat: 0x00000000
sdhci_bcm0-slot0: Int enab: 0x01ff00bb | Sig enab: 0x01ff00bb
sdhci_bcm0-slot0: AC12 err: 0x00000000 | Host ctl2:0x00000000
sdhci_bcm0-slot0: Caps:     0x00000000 | Caps2:    0x00000000
sdhci_bcm0-slot0: Max curr: 0x00000001 | ADMA err: 0x00000000
sdhci_bcm0-slot0: ADMA addr:0x00000000 | Slot int: 0x00000000
sdhci_bcm0-slot0: ===========================================
sdhci_bcm0-slot0: Got command interrupt 0x00030000, but there is no active command.
sdhci_bcm0-slot0: ============== REGISTER DUMP ==============
sdhci_bcm0-slot0: Sys addr: 0x00000000 | Version:  0x00009902
sdhci_bcm0-slot0: Blk size: 0x00000000 | Blk cnt:  0x00000000
sdhci_bcm0-slot0: Argument: 0x00000000 | Trn mode: 0x00000000
sdhci_bcm0-slot0: Present:  0x000f0000 | Host ctl: 0x00000001
sdhci_bcm0-slot0: Power:    0x0000000f | Blk gap:  0x00000000
sdhci_bcm0-slot0: Wake-up:  0x00000000 | Clock:    0x00003947
sdhci_bcm0-slot0: Timeout:  0x00000000 | Int stat: 0x00000000
sdhci_bcm0-slot0: Int enab: 0x01ff00bb | Sig enab: 0x01ff00bb
sdhci_bcm0-slot0: AC12 err: 0x00000000 | Host ctl2:0x00000000
sdhci_bcm0-slot0: Caps:     0x00000000 | Caps2:    0x00000000
sdhci_bcm0-slot0: Max curr: 0x00000001 | ADMA err: 0x00000000
sdhci_bcm0-slot0: ADMA addr:0x00000000 | Slot int: 0x00000000
sdhci_bcm0-slot0: ===========================================
sdhci_bcm0-slot0: Got command interrupt 0x00030000, but there is no active command.
sdhci_bcm0-slot0: ============== REGISTER DUMP ==============
sdhci_bcm0-slot0: Sys addr: 0x00000000 | Version:  0x00009902
sdhci_bcm0-slot0: Blk size: 0x00000000 | Blk cnt:  0x00000000
sdhci_bcm0-slot0: Argument: 0x00000000 | Trn mode: 0x00000000
sdhci_bcm0-slot0: Present:  0x000f0000 | Host ctl: 0x00000001
sdhci_bcm0-slot0: Power:    0x0000000f | Blk gap:  0x00000000
sdhci_bcm0-slot0: Wake-up:  0x00000000 | Clock:    0x00003947
sdhci_bcm0-slot0: Timeout:  0x00000000 | Int stat: 0x00000000
sdhci_bcm0-slot0: Int enab: 0x01ff00bb | Sig enab: 0x01ff00bb
sdhci_bcm0-slot0: AC12 err: 0x00000000 | Host ctl2:0x00000000
sdhci_bcm0-slot0: Caps:     0x00000000 | Caps2:    0x00000000
sdhci_bcm0-slot0: Max curr: 0x00000001 | ADMA err: 0x00000000
sdhci_bcm0-slot0: ADMA addr:0x00000000 | Slot int: 0x00000000
sdhci_bcm0-slot0: ===========================================
sdhci_bcm0-slot0: Got command interrupt 0x00030000, but there is no active command.
sdhci_bcm0-slot0: ============== REGISTER DUMP ==============
sdhci_bcm0-slot0: Sys addr: 0x00000000 | Version:  0x00009902
sdhci_bcm0-slot0: Blk size: 0x00000000 | Blk cnt:  0x00000000
sdhci_bcm0-slot0: Argument: 0x00000000 | Trn mode: 0x00000000
sdhci_bcm0-slot0: Present:  0x000f0000 | Host ctl: 0x00000001
sdhci_bcm0-slot0: Power:    0x0000000f | Blk gap:  0x00000000
sdhci_bcm0-slot0: Wake-up:  0x00000000 | Clock:    0x00003947
sdhci_bcm0-slot0: Timeout:  0x00000000 | Int stat: 0x00000000
sdhci_bcm0-slot0: Int enab: 0x01ff00bb | Sig enab: 0x01ff00bb
sdhci_bcm0-slot0: AC12 err: 0x00000000 | Host ctl2:0x00000000
sdhci_bcm0-slot0: Caps:     0x00000000 | Caps2:    0x00000000
sdhci_bcm0-slot0: Max curr: 0x00000001 | ADMA err: 0x00000000
sdhci_bcm0-slot0: ADMA addr:0x00000000 | Slot int: 0x00000000
sdhci_bcm0-slot0: ===========================================
mmc0: No compatible cards found on bus
mmcsd0: 32GB <SDHC SC32G 8.0 SN 9D401AD9 MFG 10/2018 by 3 SD> at mmc1 50.0MHz/4bit/65535-block
uhub0: 5 ports with 4 removable, self powered
bcm2835_cpufreq0: ARM 600MHz, Core 200MHz, SDRAM 400MHz, Turbo OFF
CPU  0: ARM Cortex-A72 r0p3 affinity:  0
                   Cache Type = <64 byte D-cacheline,64 byte I-cacheline,PIPT ICache,64 byte ERG,64 byte CWG>
Trying to mount root from ufs:/dev/ufs/OPNsense [rw]...
 Instruction Set Attributes 0 = <CRC32>
 Instruction Set Attributes 1 = <>
         Processor Features 0 = <AdvSIMD,FP,EL3 32,EL2 32,EL1 32,EL0 32>
         Processor Features 1 = <>
      Memory Model Features 0 = <TGran4,TGran64,SNSMem,BigEnd,16bit ASID,16TB PA>
      Memory Model Features 1 = <8bit VMID>
      Memory Model Features 2 = <32bit CCIDX,48bit VA>
             Debug Features 0 = <DoubleLock,2 CTX BKPTs,4 Watchpoints,6 Breakpoints,PMUv3,Debugv8>
             Debug Features 1 = <>
         Auxiliary Features 0 = <>
         Auxiliary Features 1 = <>
AArch32 Instruction Set Attributes 5 = <CRC32,SEVL>
AArch32 Media and VFP Features 0 = <FPRound,FPSqrt,FPDivide,DP VFPv3+v4,SP VFPv3+v4,AdvSIMD>
AArch32 Media and VFP Features 1 = <SIMDFMAC,FPHP DP Conv,SIMDHP SP Conv,SIMDSP,SIMDInt,SIMDLS,FPDNaN,FPFtZ>
CPU  1: ARM Cortex-A72 r0p3 affinity:  1
CPU  2: ARM Cortex-A72 r0p3 affinity:  2
CPU  3: ARM Cortex-A72 r0p3 affinity:  3
Release APs...done
Warning: no time-of-day clock registered, system time will not be set accurately
Dual Console: Serial Primary, Video Secondary
ugen0.2: <vendor 0x2109 USB2.0 Hub> at usbus0
uhub1 on uhub0
uhub1: <vendor 0x2109 USB2.0 Hub, class 9/0, rev 2.10/4.20, addr 1> on usbus0
Mounting filesystems...
tunefs: soft updates remains unchanged as enabled
tunefs: file system reloaded
camcontrol: cam_lookup_pass: CAMGETPASSTHRU ioctl failed
cam_lookup_pass: No such file or directory
cam_lookup_pass: either the pass driver isn't in your kernel
cam_lookup_pass: or mmcsd0 doesn't exist
** /dev/ufs/OPNsense
FILE SYSTEM CLEAN; SKIPPING CHECKS
clean, 184247 free (95 frags, 23019 blocks, 0.0% fragmentation)
uhub1: 4 ports with 4 removable, self powered
Setting hostuuid: 30303031-3030-3030-3132-343636356465.
Setting hostid: 0xe5570d8f.
Configuring vt: blanktime.
Setting up memory disks...done.
Configuring crash dump device: /dev/null
.ELF ldconfig path: /lib /usr/lib /usr/lib/compat /usr/local/lib /usr/local/lib/compat/pkg /usr/local/lib/compat/pkg /usr/local/lib/ipsec /usr/local/lib/perlE
done.
>>> Invoking early script 'upgrade'
>>> Invoking early script 'configd'
Starting configd.
>>> Invoking early script 'templates'
Generating configuration: OK
>>> Invoking early script 'backup'
>>> Invoking backup script 'captiveportal'
>>> Invoking backup script 'dhcpleases'
>>> Invoking backup script 'duid'
>>> Invoking backup script 'netflow'
>>> Invoking backup script 'rrd'
>>> Invoking early script 'carp'
CARP event system: OK
Launching the init system...done.
Initializing...........done.
genet0: link state changed to DOWN
Starting device manager...done.
Configuring login behaviour...done.
Configuring loopback interface...lo0: link state changed to UP
done.
Configuring kernel modules...done.
Setting up extended sysctls...done.
Setting timezone...done.
Writing firmware setting...done.
Writing trust files...done.
Setting hostname: OPNsense.localdomain
Generating /etc/hosts...done.
Configuring system logging...done.
Configuring loopback interface...done.
Creating wireless clone interfaces...done.
Configuring LAN interface...done.
Creating IPsec VTI instances...done.
Generating /etc/resolv.conf...done.
Configuring firewall.......pflog0: permanently promiscuous mode enabled
done.
Starting web GUI...done.
Setting up routes...done.
Generating /etc/hosts...done.
Starting DHCPv4 service...done.
Starting DHCPv6 service...done.
Starting router advertisement service...done.
Starting Unbound DNS...done.
Setting up gateway monitors...done.
Configuring firewall.......done.
Syncing OpenVPN settings...done.
Starting NTP service...done.
Starting Unbound DNS...done.
Generating RRD graphs...done.
Configuring system logging...done.
>>> Invoking start script 'newwanip'
>>> Invoking start script 'freebsd'
>>> Invoking start script 'syslog-ng'
Stopping syslog_ng.
Waiting for PIDS: 6916.
Starting syslog_ng.
>>> Invoking start script 'carp'
>>> Invoking start script 'cron'
Starting Cron: OK
>>> Invoking start script 'beep'
>>> Error in start script 'beep'
Root file system: /dev/ufs/OPNsense
Sun Feb 13 06:34:03 UTC 2022

*** OPNsense.localdomain: OPNsense 22.1 (aarch64/OpenSSL) ***
```

[^tools]: https://github.com/opnsense/tools
[^forum]: https://forum.opnsense.org/index.php?topic=12186
[^ESXi]: https://flings.vmware.com/esxi-arm-edition
[^qemu_wiki]: https://wiki.freebsd.org/arm64/QEMU
[^document]: https://www.raspberrypi.org/documentation/installation/installing-images/
