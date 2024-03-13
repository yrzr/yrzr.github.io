---
title: "OPNsense 21 for aarch64"
date: 2021-03-20T18:36:38+08:00
lastmod: 2023-07-20T21:14:35+08:00
tags: [OPNsense, FreeBSD, aarch64, rpi3, rpi4, ESXi, QEMU, KVM]
resources:
featuredImage: "/images/opnsense-21-for-aarch64/dashboard.png"
featuredImagePreview: "/images/opnsense-21-for-aarch64/dashboard-preview.png"
---

- These experimental images are NOT official releases. It's a proof of concept that OPNsense is workable for aarch64. Use at your own risks.
- Read [this issue](#21-reboot-issue-must-read) before the first reboot.
- The `OPNsense-${VER}-OpenSSL-vm-aarch64.vmdk` image works for [ESXi](#31-esxi) and [QEMU](#32-qemu).
- The `OPNsense-${VER}-OpenSSL-arm-aarch64-RPI3.img` image works for [RPI3b and RPI3b+](#4-rpis) (RPI4 is ~~tested not working yet~~ bootable with a dirty image now).

## 1 Introduction

The OPNsense images for aarch64 are built on FreeBSD aarch64 using the tools[^tools].

* [OPNsense 21.1.8 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/21.1.8)
* [OPNsense 21.1.9 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/21.1.9)
* [OPNsense 21.7 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/21.7)
* [OPNsense 21.7.1 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/21.7.1)

Please visit OPNsense forum[^forum] if you encountered any problems. You can also [create an issue](https://github.com/yrzr/opnsense-tools/issues/new) if you believe I can help.

The default user name and password is `root:opnsense` for a fresh install.

## 2 Commons

### 2.1 Reboot issue *(MUST Read)*

The console will go to nowhere starting from the second boot. The issue could be fixed by adding `hw.uart.console=""` to `/boot/loader.conf.local` that force the console back. Remember to do this **before** the first reboot!

```bash
echo 'hw.uart.console=""' > /boot/loader.conf.local
```

### 2.2 Repo

You can use `https://ftp.yrzr.tk/opnsense/` as the repo URL to get almost all the plugins as if on AMD64, as well as the updates (however, I will not update the packages frequently).

Accept the fingerprint of my server from the shell:

```bash
curl https://ftp.yrzr.tk/opnsense/fingerprint -o /usr/local/etc/pkg/fingerprints/OPNsense/trusted/ftp.yrzr.tk
```

Then modify the `Mirror` section in `System/Firmware/Settings` on WebUI to `(other)` and `https://ftp.yrzr.tk/opnsense`.

![Alt text](/images/opnsense-21-for-aarch64/mirror.png "Modify the Mirror section.")

Check updates and then go to `System/Firmware/Plugins` to download the plugins you want.

![Alt text](/images/opnsense-21-for-aarch64/plugins.png "Plugins list.")

You can also edit `/usr/local/etc/pkg/repos/OPNsense.conf` as an alternative option:

```txt
OPNsense: {
  fingerprints: "/usr/local/etc/pkg/fingerprints/OPNsense",
  url: "pkg+https://ftp.yrzr.tk/opnsense/${ABI}/21.X/latest",
  signature_type: "NONE",
  mirror_type: "NONE",
  priority: 11,
  enabled: yes
}
```

### 2.3 Extract

Install `lzop` for `.lzo` files:

```bash
lzop -x OPNsense-*-OpenSSL-*-aarch64*.*.lzo
```

Install `xz-utils` for `.xz` files:

```bash
xz -d OPNsense-*-OpenSSL-*-aarch64*.*.xz
```

`.lzo` files take much lower CPU and memory consumption and are extremely fast, while `.xz` files are smaller in size.

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

You can also refer to the FreeBSD wiki[^qemu_wiki] for more information.

**known problems:**

- ~~The booting process is stuck on KVM when `smp` is set to more than 1 during my tests. The problem can be repeated using all FreeBSD 12 aarch64 series. Should be some problem with either FreeBSD kernel, or QEMU.~~ Solved by compiling and taking U-Boot as the firmware according to Staf Wagemakers[^Staf].

## 4 RPIs

- The images are built for aarch64. Therefore, RPIs with SoCs before BCM2837 will NOT be compatible.
- ~~The FreeBSD kernel supports RPI4 with and the ethernet after revision r360181[^r360181]. While the current OPNsense 21.1[^opn21.1] on this day of writing (and is not expected to change before next release) is built on HardenedBSD v1200059[^v1200059], which is built on FreeBSD v1201000. From the FreeBSD porter's handbook[^handbook], it is still on revision r352546[^r352546]. Thus, RPI4 support will not be ready until the upstream merge.~~ [A dirty image](https://ftp.yrzr.tk/opnsense/FreeBSD%3A12%3Aaarch64/21.1/images/dirty/) is made by replacing HardenedBSD kernel with FreeBSD 13.0-RELEASE kernel, which is bootable on RPI4. Meanwhile, the modules `if_bridge` and `if_enc` are disabled due to boot issue.

### 4.1 Writing the image

The image writing process is trivial on RPIs so you can refer to the official document[^document].

Here is an example to write to the disk under UNIX-like systems using `dd` command.

```bash
sudo dd status=progress if=OPNsense-${VER}-OpenSSL-arm-aarch64-RPI3.img of=/dev/sdX bs=8M conv=fsync
```

### 4.2 Modify `config.txt`

The `config.txt` in the first partition needs to be modified depending on the RPI model you get. There are also `config_rpi*.txt` files for your reference.

Additionally, you can add the following lines in `config.txt` to enable serial console:

```txt
# Fix mini UART input frequency, and setup/enable up the UART.
uart_2ndstage=1
enable_uart=1
```

### 4.3 Grow root partition

After the system is booted, you will need to manually grow the root partition.

```bash
gpart resize -i 2 mmcsd0
growfs -y /
```

### 4.4 Booting log (RPI3+)

```txt
Raspberry Pi Bootcode
Read File: config.txt, 171
Read File: start.elf, 2857060 (bytes)
Read File: fixup.dat, 6666 (bytes)
MESS:00:00:01.056002:0: brfs: File read: /mfs/sd/config.txt
MESS:00:00:01.060264:0: brfs: File read: 171 bytes
MESS:00:00:01.074138:0: HDMI:EDID error reading EDID block 0 attempt 0
MESS:00:00:01.080209:0: HDMI:EDID error reading EDID block 0 attempt 1
MESS:00:00:01.086459:0: HDMI:EDID error reading EDID block 0 attempt 2
MESS:00:00:01.092709:0: HDMI:EDID error reading EDID block 0 attempt 3
MESS:00:00:01.098959:0: HDMI:EDID error reading EDID block 0 attempt 4
MESS:00:00:01.105209:0: HDMI:EDID error reading EDID block 0 attempt 5
MESS:00:00:01.111459:0: HDMI:EDID error reading EDID block 0 attempt 6
MESS:00:00:01.117709:0: HDMI:EDID error reading EDID block 0 attempt 7
MESS:00:00:01.123959:0: HDMI:EDID error reading EDID block 0 attempt 8
MESS:00:00:01.130209:0: HDMI:EDID error reading EDID block 0 attempt 9
MESS:00:00:01.136222:0: HDMI:EDID giving up on reading EDID block 0
MESS:00:00:01.156338:0: brfs: File read: /mfs/sd/config.txt
MESS:00:00:01.160469:0: HDMI:Setting property pixel encoding to Default
MESS:00:00:01.166548:0: HDMI:Setting property pixel clock type to PAL
MESS:00:00:01.172711:0: HDMI:Setting property content type flag to No data
MESS:00:00:01.179308:0: HDMI:Setting property fuzzy format match to enabled
MESS:00:00:01.407853:0: gpioman: gpioman_get_pin_num: pin DISPLAY_DSI_PORT not defined
MESS:00:00:01.415330:0: hdmi: HDMI:hdmi_get_state is deprecated, use hdmi_get_display_state instead
MESS:00:00:01.422845:0: hdmi: HDMI:>>>>>>>>>>>>>Rx sensed, reading EDID<<<<<<<<<<<<<
MESS:00:00:01.430591:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 0
MESS:00:00:01.438324:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 1
MESS:00:00:01.445089:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 2
MESS:00:00:01.451860:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 3
MESS:00:00:01.458632:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 4
MESS:00:00:01.465402:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 5
MESS:00:00:01.472172:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 6
MESS:00:00:01.478944:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 7
MESS:00:00:01.485714:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 8
MESS:00:00:01.492485:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 9
MESS:00:00:01.499019:0: hdmi: HDMI:EDID giving up on reading EDID block 0
MESS:00:00:01.504534:0: hdmi: HDMI: No lookup table for resolution group 0
MESS:00:00:01.511118:0: hdmi: HDMI: hotplug attached with DVI support
MESS:00:00:01.517297:0: hdmi: HDMI:hdmi_get_state is deprecated, use hdmi_get_display_state instead
MESS:00:00:01.526330:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 0
MESS:00:00:01.534065:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 1
MESS:00:00:01.540836:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 2
MESS:00:00:01.547606:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 3
MESS:00:00:01.554378:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 4
MESS:00:00:01.561148:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 5
MESS:00:00:01.567919:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 6
MESS:00:00:01.574690:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 7
MESS:00:00:01.581461:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 8
MESS:00:00:01.588232:0: hdmi: HDMI:EDID error reading EDID block 0 attempt 9
MESS:00:00:01.594767:0: hdmi: HDMI:EDID giving up on reading EDID block 0
MESS:00:00:01.600286:0: hdmi: HDMI: hotplug deassert
MESS:00:00:01.604952:0: hdmi: HDMI: HDMI is currently off
MESS:00:00:01.610073:0: hdmi: HDMI: changing mode to unplugged
MESS:00:00:01.615639:0: hdmi: HDMI:hdmi_get_state is deprecated, use hdmi_get_display_state instead
MESS:00:00:01.625853:0: *** Restart logging
MESS:00:00:01.628343:0: brfs: File read: 171 bytes
MESS:00:00:01.634030:0: Failed to open command line file 'cmdline.txt'
MESS:00:00:01.643603:0: brfs: File read: /mfs/sd/armstub8.bin
MESS:00:00:01.647652:0: Loading 'armstub8.bin' to 0x0 size 0x1700
MESS:00:00:01.653495:0: brfs: File read: 5888 bytes
MESS:00:00:01.690171:0: brfs: File read: /mfs/sd/u-boot.bin

>> FreeBSD EFI boot block
   Loader path: /boot/loader.efi

   Initializing modules: ZFS UFS
   Load Path: /efi\boot\bootaa64.efi
   Load Device: /VenHw(e61d73b9-a384-4acc-aeab-82e828f3628b)/SD(1)/SD(0)/HD(1,0x01,0,0x800,0x10000)
   Probing 3 block devices.....* done
    ZFS found no pools
    UFS found 1 partition
    command args: -S115200 -D

Consoles: EFI console  
console comconsole is invalid!
Available consoles:
    efi
FreeBSD/arm64 EFI loader, Revision 1.1
(Sun Mar 21 06:55:21 HKT 2021 root@freebsd12)

   Command line arguments: loader.efi -S115200 -D
   EFI version: 2.70
   EFI Firmware: Das U-Boot (rev 8217.1792)
   Console: efi comconsole (0x20000000)
   Load Device: /VenHw(e61d73b9-a384-4acc-aeab-82e828f3628b)/SD(1)/SD(0)/HD(2,0x01,0,0x10800,0x3b61800)
Trying ESP: /VenHw(e61d73b9-a384-4acc-aeab-82e828f3628b)/SD(1)/SD(0)/HD(2,0x01,0,0x10800,0x3b61800)
Setting currdev to disk0p2:
Loading /boot/defaults/loader.conf
console vidconsole is invalid!
console comconsole is invalid!
no valid consoles!
Available consoles:
    efi
/boot/kernel/kernel text=0x97f068 data=0x19b1f0+0x7a3084 syms=[0x8+0x141c48+0x8+0x12dbbb]
/boot/entropy size=0x1000
/boot/kernel/carp.ko text=0x34c0 text=0x63d0 data=0x10258+0xfdf0 syms=[0x8+0x1980+0x8+0x121f]
/boot/kernel/if_bridge.ko text=0x351e text=0x69a0 data=0x10428+0xfbe0 syms=[0x8+0x1a40+0x8+0x14a3]
/boot/kernel/if_enc.ko text=0x1602 text=0x8d0 data=0x10168 syms=[0x8+0xc90+0x8+0xb66]
/boot/kernel/if_gre.ko text=0x2458 text=0x4640 data=0x10228+0xfe18 syms=[0x8+0x1668+0x8+0xf17]
/boot/kernel/if_lagg.ko text=0x35c0 text=0x7c30 data=0x10440+0xfbc8 syms=[0x8+0x1a70+0x8+0x1325]
/boot/kernel/if_tap.ko text=0x2613 text=0x2b90 data=0x10160+0xff18 syms=[0x8+0x1260+0x8+0xbc4]
/boot/kernel/pf.ko text=0x6061 text=0x2cb90 data=0x10490+0xfd38 syms=[0x8+0x4170+0x8+0x308c]
/boot/kernel/pflog.ko text=0xfb0 text=0x830 data=0x10148 syms=[0x8+0x9f0+0x8+0x716]
/boot/kernel/pfsync.ko text=0x2e14 text=0x6ad0 data=0x102e8+0xfd20 syms=[0x8+0x1758+0x8+0x10f0]

Hit [Enter] to boot immediately, or any other key for command prompt.
Booting [/boot/kernel/kernel]...               
Using DTB provided by EFI at 0x7ef6000.
EFI framebuffer information:
addr, size     0x3eaf0000, 0x10a800
dimensions     656 x 416
stride         656
masks          0x00ff0000, 0x0000ff00, 0x000000ff, 0xff000000
---<<BOOT>>---
KDB: debugger backends: ddb
KDB: current backend: ddb
Copyright (c) 2013-2019 The HardenedBSD Project.
Copyright (c) 1992-2019 The FreeBSD Project.
Copyright (c) 1979, 1980, 1983, 1986, 1988, 1989, 1991, 1992, 1993, 1994
        The Regents of the University of California. All rights reserved.
FreeBSD is a registered trademark of The FreeBSD Foundation.
FreeBSD 12.1-RELEASE-p14-HBSD #0  e10a7efce(stable/21.1)-dirty: Sun Mar 21 08:00:57 HKT 2021
    root@freebsd12:/usr/obj/usr/src/arm64.aarch64/sys/SMP-ARM arm64
FreeBSD clang version 8.0.1 (tags/RELEASE_801/final 366581) (based on LLVM 8.0.1)
VT(efifb): resolution 656x416
HardenedBSD: initialize and check features (__HardenedBSD_version 1200059 __FreeBSD_version 1201000).
KLD file if_bridge.ko is missing dependencies
Starting CPU 1 (1)
Starting CPU 2 (2)
Starting CPU 3 (3)
FreeBSD/SMP: Multiprocessor System Detected: 4 CPUs
random: unblocking device.
random: entropy device external interface
MAP 39f4a000 mode 2 pages 1
MAP 39f4f000 mode 2 pages 1
MAP 3b350000 mode 2 pages 16
MAP 3f100000 mode 1 pages 1
000.000021 [4336] netmap_init               netmap: loaded module
kbd0 at kbdmux0
ofwbus0: <Open Firmware Device Tree>
simplebus0: <Flattened device tree simple bus> on ofwbus0
ofw_clkbus0: <OFW clocks bus> on ofwbus0
clk_fixed0: <Fixed clock> on ofw_clkbus0
clk_fixed1: <Fixed clock> on ofw_clkbus0
regfix0: <Fixed Regulator> on ofwbus0
regfix1: <Fixed Regulator> on ofwbus0
psci0: <ARM Power State Co-ordination Interface Driver> on ofwbus0
lintc0: <BCM2836 Interrupt Controller> mem 0x40000000-0x400000ff on simplebus0
intc0: <BCM2835 Interrupt Controller> mem 0x7e00b200-0x7e00b3ff irq 20 on simplebus0
gpio0: <BCM2708/2835 GPIO controller> mem 0x7e200000-0x7e2000b3 irq 23,24 on simplebus0
gpiobus0: <OFW GPIO bus> on gpio0
generic_timer0: <ARMv7 Generic Timer> irq 0,1,2,3 on ofwbus0
Timecounter "ARM MPCore Timecounter" frequency 19200000 Hz quality 1000
Event timer "ARM MPCore Eventtimer" frequency 19200000 Hz quality 1000
usb_nop_xceiv0: <USB NOP PHY> on ofwbus0
bcm_dma0: <BCM2835 DMA Controller> mem 0x7e007000-0x7e007eff irq 4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19 on simplebus0
bcmwd0: <BCM2708/2835 Watchdog> mem 0x7e100000-0x7e100027 on simplebus0
bcmrng0: <Broadcom BCM2835 RNG> mem 0x7e104000-0x7e10400f irq 21 on simplebus0
mbox0: <BCM2835 VideoCore Mailbox> mem 0x7e00b880-0x7e00b8bf irq 22 on simplebus0
gpioc0: <GPIO controller> on gpio0
uart0: <PrimeCell UART (PL011)> mem 0x7e201000-0x7e201fff irq 25 on simplebus0
spi0: <BCM2708/2835 SPI controller> mem 0x7e204000-0x7e204fff irq 27 on simplebus0
spibus0: <OFW SPI bus> on spi0
spibus0: <unknown card> at cs 0 mode 0
spibus0: <unknown card> at cs 1 mode 0
uart1: <BCM2835 Mini-UART> mem 0x7e215040-0x7e21507f irq 33 on simplebus0
uart1: console (115200,n,8,1)
iichb0: <BCM2708/2835 BSC controller> mem 0x7e804000-0x7e804fff irq 40 on simplebus0
bcm283x_dwcotg0: <DWC OTG 2.0 integrated USB controller (bcm283x)> mem 0x7e980000-0x7e98ffff,0x7e006000-0x7e006fff irq 46,47 on simplebus0
usbus0 on bcm283x_dwcotg0
sdhci_bcm0: <Broadcom 2708 SDHCI controller> mem 0x7e300000-0x7e3000ff irq 49 on simplebus0
mmc0: <MMC/SD bus> on sdhci_bcm0
fb0: <BCM2835 VT framebuffer driver> on simplebus0
fbd0 on fb0
VT: Replacing driver "efifb" with new "fb".
fb0: 656x416(656x416@0,0) 24bpp
fb0: fbswap: 1, pitch 1968, base 0x3eb33000, screen_size 818688
pmu0: <Performance Monitoring Unit> irq 53 on simplebus0
cpulist0: <Open Firmware CPU Group> on ofwbus0
cpu0: <Open Firmware CPU> on cpulist0
bcm2835_cpufreq0: <CPU Frequency Control> on cpu0
cpu1: <Open Firmware CPU> on cpulist0
cpu2: <Open Firmware CPU> on cpulist0
cpu3: <Open Firmware CPU> on cpulist0
gpioled0: <GPIO LEDs> on ofwbus0
gpioled0: <led1> failed to map pin
cryptosoft0: <software crypto>
Timecounters tick every 1.000 msec
usbus0: 480Mbps High Speed USB v2.0
iicbus0: <OFW I2C bus> on iichb0
iic0: <I2C generic I/O> on iicbus0
ugen0.1: <DWCOTG OTG Root HUB> at usbus0
uhub0: <DWCOTG OTG Root HUB, class 9/0, rev 2.00/1.00, addr 1> on usbus0
mmcsd0: 32GB <SDHC SC32G 8.0 SN 9DC03993 MFG 10/2018 by 3 SD> at mmc0 50.0MHz/4bit/65535-block
bcm2835_cpufreq0: ARM 600MHz, Core 250MHz, SDRAM 400MHz, Turbo OFF
mbox0: mbox response error
bcm2835_cpufreq0: can't set clock rate (id=4)
Release APs...done
CPU  0: ARM Cortex-A53 r0p4 affinity:  0
Trying to mount root from ufs:/dev/ufs/OPNsense [rw]...
 Instruction Set Attributes 0 = <CRC32>
 Instruction Set Attributes 1 = <>
         Processor Features 0 = <AdvSIMD,Float,EL3 32,EL2 32,EL1 32,EL0 32>
         Processor Features 1 = <0>
      Memory Model Features 0 = <4k Granule,64k Granule,S/NS Mem,MixedEndian,16bit ASID,1TB PA>
      Memory Model Features 1 = <>
      Memory Model Features 2 = <32b CCIDX,48b VA>
             Debug Features 0 = <2 CTX Breakpoints,4 Watchpoints,6 Breakpoints,PMUv3,Debug v8>
             Debug Features 1 = <0>
         Auxiliary Features 0 = <0>
         Auxiliary Features 1 = <0>
CPU  1: ARM Cortex-A53 r0p4 affinity:  1
CPU  2: ARM Cortex-A53 r0p4 affinity:  2
CPU  3: ARM Cortex-A53 r0p4 affinity:  3
Warning: no time-of-day clock registered, system time will not be set accurately
uhub0: 1 port with 1 removable, self powered
Mounting filesystems...
tunefs: soft updates remains unchanged as enabled
tunefs: file system reloaded
camcontrol: cam_ugen0.2: <vendor 0x0424 product 0x2514> at usbus0
uhub1 on uhub0
uhub1: <vendor 0x0424 product 0x2514, class 9/0, rev 2.00/b.b3, addr 2> on usbus0
uhub1: MTT enabled
lookup_pass: CAMGETPASSTHRU ioctl failed
cam_lookup_pass: No such file or directory
cam_lookup_pass: either the pass driver isn't in your kernel
cam_lookup_pass: or mmcsd0 doesn't exist
** /dev/ufs/OPNsense
FILE SYSTEM CLEAN; SKIPPING CHECKS
clean, 7101844 fuhub1: 4 ports with 3 removable, self powered
ree (220 frags, 887703 blocks, 0.0% fragmentation)
ugen0.3: <vendor 0x0424 product 0x2514> at usbus0
uhub2 on uhub1
uhub2: <vendor 0x0424 product 0x2514, class 9/0, rev 2.00/b.b3, addr 3> on usbus0
uhub2: MTT enabled
Setting hostuuid: 30303030-3030-3030-3139-663138353365.
Setting hostid: 0x56d89878.
Configurinuhub2: 3 ports with 2 removable, self powered
g vt: blanktime.
ugen0.4: <vendor 0x0424 product 0x7800> at usbus0
muge0 on uhub2
muge0: <vendor 0x0424 product 0x7800, rev 2.10/3.00, addr 4> on usbus0
muge0: Chip ID 0x7800 rev 0002
miibus0: <MII bus> on muge0
ukphy0: <Generic IEEE 802.3u media interface> PHY 1 on miibus0
ukphy0:  none, 10baseT, 10baseT-FDX, 100baseTX, 100baseTX-FDX, 1000baseT, 1000baseT-master, 1000baseT-FDX, 1000baseT-FDX-master, auto
ue0: <USB Ethernet> on muge0
ue0: Ethernet address: b8:27:eb:f1:85:3e
Setting up memory disks...done.
Configuring crash dump device: /dev/null
.ELF ldconfig path: /lib /usr/lib /usr/local/lib /usr/local/lib/compat/pkg /usr/local/lib/compat/pkg /usr/local/lib/ipsec /usr/local/lib/perl5/5.32/mach/CORE
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
ue0: link state changed to UP
Starting device manager...done.
Configuring login behaviour...done.
Configuring looplo0: link state changed to UP
back interface...done.
Configuring kernel modules...done.
Setting up extended sysctls...done.
Setting timezone...done.
Writing firmware setting...done.
Writing trust files...done.
Setting hostname: opnsense.yrzr.tk
Generating /etc/hosts...done.
Configuring system logging...done.
Configuring loopback interface...done.
Creating wireless clone interfaces...donmuge0: Chip ID 0x7800 rev 0002
e.
Configuring WAN interface...done.
Creating IPsec VTI instances...done.
Generating /etc/resolv.conf...done.
Configuring firewall........done.
Starting PFLOG...done.
Configuring OpenSSH...done.
Starting web GUI...done.
Configuring CRON...done.
Setting up routes...done.
Generating /etc/hosts...done.
Starting Unbound DNS...done.
Setting up gateway monitors...done.
Configuring firewall........done.
Starting PFLOG...done.
Syncing OpenVPN settings...done.
Starting NTP service...deferred.
Starting Unbound DNS...done.
Generating RRD graphs...done.
Configuring system logging...done.
>>> Invoking start script 'newwanip'
Reconfiguring IPv4 on ue0: OK
Reconfiguring routes: OK
>>> Invoking start script 'freebsd'
Starting powerd.
>>> Invoking start script 'syslog-ng'
Stopping syslog_ng.
Waiting for PIDS: 31435.
Starting syslog_ng.
>>> Invoking start script 'wireguard'
Setting up routes...done.
Setting up gateway monitors...done.
Configuring firewall........done.
Starting PFLOG...done.
>>> Invoking start script 'carp'
>>> Invoking start script 'cron'
Starting Cron: OK
>>> Invoking start script 'beep'
Root file system: /dev/ufs/OPNsense
Fri Mar 26 20:11:52 HKT 2021

*** opnsense.yrzr.tk: OPNsense 21.1.3 (aarch64/OpenSSL) ***
```

[^tools]: https://github.com/yrzr/tools/tree/master
[^forum]: https://forum.opnsense.org/index.php?topic=12186
[^ESXi]: https://flings.vmware.com/esxi-arm-edition
[^qemu_wiki]: https://wiki.freebsd.org/arm64/QEMU
[^Staf]: https://stafwag.github.io/blog/blog/2021/03/14/howto_run_freebsd_as_vm_on_pi/
[^r360181]: https://svnweb.freebsd.org/base?view=revision&revision=360181
[^opn21.1]: https://github.com/opnsense/src/blob/21.1/UPDATING-HardenedBSD
[^v1200059]: https://github.com/HardenedBSD/hardenedBSD-stable/releases/tag/HardenedBSD-12-STABLE-v1200059
[^handbook]: https://docs.freebsd.org/en_US.ISO8859-1/books/porters-handbook/book.html
[^r352546]: https://svnweb.freebsd.org/base?view=revision&revision=352546
[^document]: https://www.raspberrypi.org/documentation/installation/installing-images/
