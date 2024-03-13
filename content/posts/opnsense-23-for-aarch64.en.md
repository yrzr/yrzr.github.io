---
title: "OPNsense 23 for aarch64"
date: 2023-07-13T15:13:36+08:00
lastmod: 2023-08-16T11:49:35+08:00
tags: [OPNsense, FreeBSD, aarch64, rpi3, rpi4, r4s, ESXi, QEMU, KVM]
resources:
featuredImage: "/images/opnsense-23-for-aarch64/dashboard.png"
featuredImagePreview: "/images/opnsense-23-for-aarch64/dashboard-preview.png"
---

- These experimental images are NOT official releases. It's a proof of concept that OPNsense is workable for aarch64. Use at your own risk.
- Since version 22, OPNsense is now based on FreeBSD 13. Therefore, all the devices on [this wiki page](https://wiki.freebsd.org/arm64) shall all work under good development. Images for **Raspberry Pi 4** and **NanoPi R4S** are built here.
- The `OPNsense-${VER}-vm-aarch64.vmdk` image works for [ESXi](#31-esxi) and [QEMU](#32-qemu).
- The `OPNsense-${VER}-arm-aarch64-RPI.img` image works for Raspberry Pi 3b, 3b+ and 4b, while the `OPNsense-${VER}-arm-aarch64-R4S.img` image works for NanoPi R4S. See [section 4](#4-rpis-and-r4s) for details.
- For NanoPi R6S, please see [my steps](../running-opnsense-on-r6s/) to make the device running.

## 1 Introduction

The OPNsense images for aarch64 are built on FreeBSD aarch64 using the tools[^tools].

* [OPNsense 23.1 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/23.1)
* [OPNsense 23.1.11 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/23.1.11)
* [OPNsense 23.7 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/23.7)
* [OPNsense 23.7.1 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/23.7.1)
* [OPNsense 23.7.6 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/23.7.6)
* [OPNsense 23.7.9 for aarch64](https://github.com/yrzr/opnsense-tools/releases/tag/23.7.9)

Please visit OPNsense forum[^forum] if you encountered any problems. You can also [create an issue](https://github.com/yrzr/opnsense-tools/issues/new) if you believe I can help.

The default user name and password is `root:opnsense` for a fresh install.

## 2 Commons

### 2.1 Repo

You can use `https://ftp.yrzr.tk/opnsense/` as the repo URL to get almost all the plugins as if on AMD64 and the updates (however, I will not update the packages frequently).

Accept the fingerprint of my server from the shell:

```bash
curl https://ftp.yrzr.tk/opnsense/fingerprint -o /usr/local/etc/pkg/fingerprints/OPNsense/trusted/ftp.yrzr.tk
```

Then modify the `Mirror` section in `System/Firmware/Settings` on WebUI to `(other)` and `https://ftp.yrzr.tk/opnsense`.

![Alt text](/images/opnsense-23-for-aarch64/mirror.png "Modify the Mirror section.")

Check updates and then go to `System/Firmware/Plugins` to download the plugins you want.

![Alt text](/images/opnsense-23-for-aarch64/plugins.png "Plugins list.")

You can also edit `/usr/local/etc/pkg/repos/OPNsense.conf` as an alternative option:

```txt
OPNsense: {
  fingerprints: "/usr/local/etc/pkg/fingerprints/OPNsense",
  url: "pkg+https://ftp.yrzr.tk/opnsense/${ABI}/23.X/latest",
  signature_type: "fingerprints",
  mirror_type: "srv",
  priority: 11,
  enabled: yes
}
```

### 2.2 PowerD

`PowerD` is a daemon running on FreeBSD to enable CPU Scaling and power saving. By default, `PowerD` is installed but not enabled on OPNsense. You could enable `PowerD` to gain performance improvement.

![Alt text](/images/opnsense-23-for-aarch64/powerd.png "Enable PowerD.")

### 2.3 Extract

Install `xz-utils` for `.xz` files:

```bash
xz -d OPNsense-*-aarch64*.*.xz
```

## 3 Virtual machines

### 3.1 ESXi

Install ESXi on RPI4 (4g or 8g version only) from the official website[^ESXi]. Then, convert the `vmdk` image from the shell of ESXi:

```bash
vmkfstools -i OPNsense-*-vm-aarch64.vmdk OPNsense-out.vmdk
```

You can also resize the virtual disk size as you want:

```bash
vmkfstools -X 32G OPNsense-out.vmdk
```

Finally, import the `OPNsense-out.vmdk` to your virtual machine as the boot disk and run.

### 3.2 QEMU

Convert `vmdk` image to `raw` image:

```bash
qemu-img convert -f vmdk -O raw OPNsense-*-vm-aarch64.vmdk OPNsense-out.raw
```

Run virtual machine with **KVM** on aarch64 machines (RPI4 with 64-bit Raspbian OS, for example):

```bash
qemu-system-aarch64 \
  -bios /usr/share/qemu/edk2-aarch64-code.fd \
  -M virt,gic-version=max \
  -enable-kvm \
  -cpu host \
  -smp 1 \
  -m 1024M \
  -nographic \
  -drive format=raw,file=OPNsense-out.raw,cache=none,if=virtio
```

Or **emulate** from AMD64 machines:

```bash
qemu-system-aarch64 \
  -bios /usr/share/qemu/edk2-aarch64-code.fd \
  -M virt,gic-version=max \
  -cpu cortex-a57 \
  -smp 4 \
  -m 1024M \
  -nographic \
  -drive format=raw,file=OPNsense-out.raw,cache=none,if=virtio
```

Don't forget to add your **network-related** options, for example:

```
  -net nic,macaddr="11:22:33:44:55:66" -net bridge,br=br0
```

For more information, you can also refer to the FreeBSD wiki[^qemu_wiki].

## 4 RPIs and R4S

- The RPI images are built for aarch64. Therefore, RPIs with SoCs before BCM2837 will NOT be compatible.

### 4.1 Writing the image

The image writing process is trivial, so that you can refer to the official document of RPI [^document].

Here is an example of writing to the disk under UNIX-like systems using the `dd` command.

```bash
sudo dd status=progress if=OPNsense-${VER}-arm-aarch64-{RPI,R4S}.img of=/dev/sdX bs=8M conv=fsync
```

Now you can insert the sd card into your device and power on it.

### 4.2 Modify `config.txt` (RPI only)

The `config.txt` in the first partition needs to be modified depending on the RPI model you get. There are also `config_rpi*.txt` files for your reference.

For example you are using an RPI4, insert the sd card to a linux machine:

```bash
mkdir -p /mnt/temp
mount /dev/sdX1 /mnt/temp
cp -v /mnt/temp/config_rpi4.txt /mnt/temp/config.txt
# here, edit /mnt/temp/config.txt as you wish 
umount /mnt/temp
```

Additionally, you can append the following lines in `config.txt` to enable serial console (learn more about serial console here[^serial]):

```txt
# Fix mini UART input frequency, and setup/enable up the UART.
uart_2ndstage=1
enable_uart=1
```

### 4.3 Grow root partition

After the system is booted, you will need to grow the root partition in the shell manually. Go to the console and type `8` to enter the shell, and excuse the following command.

```bash
service growfs onestart
```

### 4.4 Booting logs

OPNsense 23.1 on Qemu (KVM)

```text
Loading kernel...
/boot/kernel/kernel text=0x2a8 text=0x929310 text=0x21d15c data=0x1b25d0 data=0x0+0x38a000 syms=[0x8+0x1319a0+0x8+0x156da4]
Loading configured modules...
/boot/entropy size=0x1000
/boot/kernel/if_bridge.ko text=0x3637 text=0x7178 data=0xd30+0x8 syms=[0x8+0x1b78+0x8+0x15a8]
loading required module 'bridgestp'
/boot/kernel/bridgestp.ko text=0x12e4 text=0x4acc data=0x2c8+0x28 syms=[0x8+0xb88+0x8+0x6e9]
/boot/kernel/if_enc.ko text=0x15ca text=0x934 data=0x750 syms=[0x8+0xca8+0x8+0xb71]
/boot/kernel/pfsync.ko text=0x2f1c text=0x7b34 data=0xb30+0x8 syms=[0x8+0x1800+0x8+0x117d]
loading required module 'pf'
/boot/kernel/pf.ko text=0xe3cc text=0x3e604 data=0x59e8+0x3e4 syms=[0x8+0x5940+0x8+0x4714]
/boot/kernel/pflog.ko text=0xf78 text=0x898 data=0x430 syms=[0x8+0x9f0+0x8+0x712]
can't find '/etc/hostid'
/boot/kernel/if_lagg.ko text=0x3d27 text=0xa628 data=0xd18+0x8 syms=[0x8+0x1cb0+0x8+0x15bd]
loading required module 'if_infiniband'
/boot/kernel/if_infiniband.ko text=0x1102 text=0x10fc data=0x300+0x8 syms=[0x8+0x8d0+0x8+0x59a]
/boot/kernel/if_gre.ko text=0x2736 text=0x4938 data=0x8c8+0x40 syms=[0x8+0x16f8+0x8+0xfaf]
/boot/kernel/carp.ko text=0x33ec text=0x6e54 data=0xc60+0x48 syms=[0x8+0x1980+0x8+0x1225]
No valid device tree blob found!
WARNING! Trying to fire up the kernel, but no device tree blob found!
EFI framebuffer information:
addr, size     0x0, 0x0
dimensions     0 x 0
stride         0
masks          0x00000000, 0x00000000, 0x00000000, 0x00000000
---<<BOOT>>---
KDB: debugger backends: ddb
KDB: current backend: ddb
Copyright (c) 1992-2021 The FreeBSD Project.
Copyright (c) 1979, 1980, 1983, 1986, 1988, 1989, 1991, 1992, 1993, 1994
        The Regents of the University of California. All rights reserved.
FreeBSD is a registered trademark of The FreeBSD Foundation.
FreeBSD 13.1-RELEASE-p5 stable/23.1-n250372-c4ad069e50a SMP arm64
FreeBSD clang version 13.0.0 (git@github.com:llvm/llvm-project.git llvmorg-13.0.0-0-gd7b669b3a303)
VT: init without driver.
module firmware already present!
real memory  = 1071251456 (1021 MB)
avail memory = 1016135680 (969 MB)
Starting CPU 1 (1)
Starting CPU 2 (2)
Starting CPU 3 (3)
FreeBSD/SMP: Multiprocessor System Detected: 4 CPUs
random: unblocking device.
random: entropy device external interface
MAP 7bf80000 mode 2 pages 128
MAP 7c020000 mode 2 pages 368
MAP 7c190000 mode 2 pages 80
MAP 7c1e0000 mode 2 pages 160
MAP 7c280000 mode 2 pages 240
MAP 7f650000 mode 2 pages 144
MAP 7f6f0000 mode 2 pages 288
MAP 4000000 mode 0 pages 16384
MAP 9010000 mode 0 pages 1
kbd0 at kbdmux0
acpi0: <BOCHS BXPC>
acpi0: Power Button (fixed)
acpi0: Sleep Button (fixed)
acpi0: Could not update all GPEs: AE_NOT_CONFIGURED
psci0: <ARM Power State Co-ordination Interface Driver> on acpi0
gic0: <ARM Generic Interrupt Controller> iomem 0x8000000-0x8000fff,0x8010000-0x8010fff on acpi0
gic0: pn 0x2, arch 0x2, rev 0x1, implementer 0x43b irqs 288
gic0: frame: 0 8020000 1 64 80
gicv2m0: <ARM Generic Interrupt Controller MSI/MSIX> mem 0x8020000-0x8020fff on gic0
generic_timer0: <ARM Generic Timer> irq 34,35,36 on acpi0
Timecounter "ARM MPCore Timecounter" frequency 24000000 Hz quality 1000
Event timer "ARM MPCore Eventtimer" frequency 24000000 Hz quality 1000
efirtc0: <EFI Realtime Clock>
efirtc0: registered as a time-of-day clock, resolution 1.000000s
cpu0: <ACPI CPU> on acpi0
uart0: <PrimeCell UART (PL011)> iomem 0x9000000-0x9000fff irq 0 on acpi0
uart0: console (9600,n,8,1)
pcib0: <Generic PCI host controller> on acpi0
pci0: <PCI bus> on pcib0
virtio_pci0: <VirtIO PCI (legacy) Network adapter> port 0x80-0x9f mem 0x10041000-0x10041fff,0x8000000000-0x8000003fff at device 1.0 on pci0
vtnet0: <VirtIO Networking Adapter> on virtio_pci0
vtnet0: Ethernet address: aa:01:10:10:10:12
vtnet0: netmap queues/slots: TX 1/256, RX 1/128
000.000061 [ 450] vtnet_netmap_attach       vtnet attached txq=1, txd=256 rxq=1, rxd=128
virtio_pci1: <VirtIO PCI (legacy) Block adapter> mem 0x10040000-0x10040fff,0x8000004000-0x8000007fff at device 2.0 on pci0
vtblk0: <VirtIO Block Adapter> on virtio_pci1
vtblk0: 21765MB (44574720 512 byte sectors)
acpi_button0: <Power Button> on acpi0
armv8crypto0: <AES-CBC,AES-XTS,AES-GCM>
Timecounters tick every 1.000 msec
usb_needs_explore_all: no devclass
CPU  0: ARM Cortex-A73 r0p2 affinity:  0
                   Cache Type = <64 byte D-cacheline,64 byte I-cacheline,VIPT ICache,64 byte ERG,64 byte CWG>
 Instruction Set Attributes 0 = <CRC32,SHA2,SHA1,AES+PMULL>
 Instruction Set Attributes 1 = <>
         Processor Features 0 = <CSV3,AdvSIMD,FP,EL3 32,EL2 32,EL1 32,EL0 32>
         Processor Features 1 = <>
      Memory Model Features 0 = <TGran4,TGran64,SNSMem,BigEnd,16bit ASID,1TB PA>
      Memory Model Features 1 = <8bit VMID>
      Memory Model Features 2 = <32bit CCIDX,48bit VA>
             Debug Features 0 = <DoubleLock,2 CTX BKPTs,4 Watchpoints,6 Breakpoints,Debugv8>
             Debug Features 1 = <>
         Auxiliary Features 0 = <>
         Auxiliary Features 1 = <>
AArch32 Instruction Set Attributes 5 = <CRC32,SHA2,SHA1,AES+VMULL,SEVL>
AArch32 Media and VFP Features 0 = <FPRound,FPSqrt,FPDivide,DP VFPv3+v4,SP VFPv3+v4,AdvSIMD>
AArch32 Media and VFP Features 1 = <SIMDFMAC,FPHP DP Conv,SIMDHP SP Conv,SIMDSP,SIMDInt,SIMDLS,FPDNaN,FPFtZ>
CPU  1: ARM Cortex-A73 r0p2 affinity:  1
CPU  2: ARM Cortex-A73 r0p2 affinity:  2
CPU  3: ARM Cortex-A73 r0p2 affinity:  3
Release APs...done
Trying to mount root from ufs:/dev/gpt/rootfs [rw]...
Mounting filesystems...
tunefs: soft updates set
tunefs: file system reloaded
camcontrol: cam_lookup_pass: CAMGETPASSTHRU ioctl failed
cam_lookup_pass: No such file or directory
cam_lookup_pass: either the pass driver isn't in your kernel
cam_lookup_pass: or vtbd0 doesn't exist
vtbd0 recovering is not needed
vtbd0p4 resized
super-block backups (for fsck_ffs -b #) at:

** /dev/gpt/rootfs
FILE SYSTEM CLEAN; SKIPPING CHECKS
clean, 4704955 free (387 frags, 588071 blocks, 0.0% fragmentation)
/etc/rc.d/hostid: WARNING: hostid: unable to figure out a UUID from DMI data, generating a new one
Setting hostuuid: f90bff45-2220-11ee-9e22-936dc1b65e00.
Setting hostid: 0x91c0d0c7.
Press any key to start the configuration importer: .........
Bootstrapping config.xml...done.
Configuring crash dump device: /dev/gpt/swapfs
swapon: adding /dev/gpt/swapfs as swap device
.ELF ldconfig path: /lib /usr/lib /usr/lib/compat /usr/local/lib /usr/local/lib/compat/pkg /usr/local/lib/compat/pkg /usr/local/lib/ipsec /usr/local/lib/perl5/5.32/mach/CORE
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
Starting device manager...done.
Configuring login behaviour...done.

Default interfaces not found -- Running interface assignment option.

Press any key to start the manual interface assignment: 1
Do you want to configure LAGGs now? [y/N]: n
Do you want to configure VLANs now? [y/N]: n

Valid interfaces are:

vtnet0           aa:01:10:10:10:12 VirtIO Networking Adapter

If you do not know the names of your interfaces, you may choose to use
auto-detection. In that case, disconnect all interfaces now before
hitting 'a' to initiate auto detection.

Enter the WAN interface name or 'a' for auto-detection:

Enter the LAN interface name or 'a' for auto-detection
NOTE: this enables full Firewalling/NAT mode.
(or nothing if finished): vtnet0

Enter the Optional interface 1 name or 'a' for auto-detection
(or nothing if finished):

The interfaces will be assigned as follows:

LAN  -> vtnet0

Do you want to proceed? [y/N]: y

Writing configuration...done.
Configuring loopback interface...lo0: link state changed to UP
done.
Configuring kernel modules...done.
Setting up extended sysctls...done.
Setting timezone: Etc/UTC
Writing firmware setting...done.
Writing trust files...done.
Setting hostname: OPNsense.localdomain
Generating /etc/resolv.conf...done.
Generating /etc/hosts...done.
Configuring system logging...done.
Configuring firewall.......pflog0: permanently promiscuous mode enabled
done.
Configuring hardware interfaces...done.
Configuring loopback interface...done.
Configuring LAGG interfaces...done.
Configuring VLAN interfaces...done.
Configuring LAN interface...done.
Generating /etc/resolv.conf...done.
Generating /etc/hosts...done.
Configuring firewall.......done.
Starting web GUI...done.
Setting up routes...done.
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
>>> Invoking start script 'newwanip'
>>> Invoking start script 'freebsd'
>>> Invoking start script 'syslog'
>>> Invoking start script 'dnsbl'
>>> Invoking start script 'carp'
>>> Invoking start script 'cron'
Starting Cron: OK
>>> Invoking start script 'sysctl'
Service `sysctl' has been restarted.
>>> Invoking start script 'beep'
>>> Error in start script 'beep'
Root file system: /dev/gpt/rootfs
Fri Jul 14 08:33:21 UTC 2023
```

OPNsense 23.1 on Raspberry Pi 4

```text
Booting [/boot/kernel/kernel]...
Using DTB provided by EFI at 0x7ef0000.
EFI framebuffer information:
addr, size     0x3eac2000, 0x103000
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
FreeBSD 13.1-RELEASE-p5 stable/23.1-n250372-c4ad069e50a SMP arm64
FreeBSD clang version 13.0.0 (git@github.com:llvm/llvm-project.git llvmorg-13.0.0-0-gd7b669b3a303)
VT(efifb): resolution 592x448
module firmware already present!
real memory  = 4147961856 (3955 MB)
avail memory = 4019216384 (3833 MB)
Starting CPU 1 (1)
Starting CPU 2 (2)
Starting CPU 3 (3)
FreeBSD/SMP: Multiprocessor System Detected: 4 CPUs
random: unblocking device.
random: entropy device external interface
MAP 39f26000 mode 2 pages 1
MAP 39f2a000 mode 2 pages 1
MAP 39f2c000 mode 2 pages 2
MAP 39f2f000 mode 2 pages 4
MAP 3b340000 mode 2 pages 16
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
fb0: fbswap: 1, pitch 2368, base 0x3eac2000, screen_size 1060864
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
genet0: Ethernet address: dc:a6:32:06:9e:53
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
ugen0.1: <(0x1106) XHCI root HUB> at usbus0
uhub0 on usbus0
uhub0: <(0x1106) XHCI root HUB, class 9/0, rev 3.00/1.00, addr 1> on usbus0
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
mmcsd0: 16GB <SDHC SC16G 8.0 SN 6C39D344 MFG 11/2017 by 3 SD> at mmc1 50.0MHz/4bit/65535-block
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
uhub1: <vendor 0x2109 USB2.0 Hub, class 9/0, rev 2.10/4.21, addr 1> on usbus0
Mounting filesystems...
tunefs: soft updates remains unchanged as enabled
tunefs: file system reloaded
camcontrol: cam_lookup_pass: CAMGETPASSTHRU ioctl failed
cam_lookup_pass: No such file or directory
cam_lookup_pass: either the pass driver isn't in your kernel
cam_lookup_pass: or mmcsd0 doesn't exist
mmcsd0 recovering is not needed
gpart: autofill: No space left on device
growfs: requested size 3.0GB is equal to the current filesystem size 3.0GB
uhub1: 4 ports with 4 removable, self powered
** /dev/ufs/OPNsense
FILE SYSTEM CLEAN; SKIPPING CHECKS
clean, 375215 free (599 frags, 46827 blocks, 0.1% fragmentation)
Setting hostuuid: 30303031-3030-3030-3536-346262373331.
Setting hostid: 0xb66522e0.
Configuring vt: blanktime.
Press any key to start the configuration importer: .........
Bootstrapping config.xml...done.
Setting up /var/log memory disk...done.
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

Default interfaces not found -- Running interface assignment option.

Press any key to start the manual interface assignment: 1
Do you want to configure LAGGs now? [y/N]: n
Do you want to configure VLANs now? [y/N]: n

Valid interfaces are:

genet0           dc:a6:32:06:9e:53 RPi4 Gigabit Ethernet

If you do not know the names of your interfaces, you may choose to use
auto-detection. In that case, disconnect all interfaces now before
hitting 'a' to initiate auto detection.

Enter the WAN interface name or 'a' for auto-detection:

Enter the LAN interface name or 'a' for auto-detection
NOTE: this enables full Firewalling/NAT mode.
(or nothing if finished): genet0

Enter the Optional interface 1 name or 'a' for auto-detection
(or nothing if finished):

The interfaces will be assigned as follows:

LAN  -> genet0

Do you want to proceed? [y/N]: y

Writing configuration...done.
Configuring loopback interface...lo0: link state changed to UP
done.
Configuring kernel modules...done.
Setting up extended sysctls...done.
Setting timezone: Etc/UTC
Writing firmware setting...done.
Writing trust files...done.
Setting hostname: OPNsense.localdomain
Generating /etc/resolv.conf...done.
Generating /etc/hosts...done.
Configuring system logging...done.
Configuring firewall.......pflog0: permanently promiscuous mode enabled
done.
Configuring hardware interfaces...done.
Configuring loopback interface...done.
Configuring LAGG interfaces...done.
Configuring VLAN interfaces...done.
Configuring LAN interface...done.
Generating /etc/resolv.conf...done.
Generating /etc/hosts...done.
Configuring firewall.......done.
Starting web GUI...done.
Setting up routes...done.
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
>>> Invoking start script 'newwanip'
>>> Invoking start script 'freebsd'
>>> Invoking start script 'syslog'
>>> Invoking start script 'dnsbl'
>>> Invoking start script 'carp'
>>> Invoking start script 'cron'
Starting Cron: OK
>>> Invoking start script 'sysctl'
Service `sysctl' has been restarted.
>>> Invoking start script 'beep'
>>> Error in start script 'beep'
Root file system: /dev/ufs/OPNsense
Fri Jul  7 02:38:53 UTC 2023
```

OPNsense 23.7 on Nanopi R4S ([hw-probe](https://bsd-hardware.info/?probe=a9a3896275))

```txt
U-Boot TPL 2023.01 (Apr 08 2023 - 05:11:00)
lpddr4_set_rate: change freq to 400MHz 0, 1
Channel 0: LPDDR4, 400MHz
BW=32 Col=10 Bk=8 CS0 Row=15 CS1 Row=15 CS=2 Die BW=16 Size=2048MB
Channel 1: LPDDR4, 400MHz
BW=32 Col=10 Bk=8 CS0 Row=15 CS1 Row=15 CS=2 Die BW=16 Size=2048MB
256B stride
lpddr4_set_rate: change freq to 800MHz 1, 0
Trying to boot from BOOTROM
Returning to boot ROM...
cLoading kernel...
/boot/kernel/kernel text=0x2a8 text=0x942160 text=0x236b0c data=0x1ba3b8 data=0x0+0x2b2000 0x8+0x13b990+0x8+0x161b8d\
Loading configured modules...
/etc/hostid...can't find '/etc/hostid'
failed!
if_bridge.../boot/kernel/if_bridge.ko text=0x3884 text=0x6e2c data=0xde8+0x8 0x8+0x1c98+0x8+0x16b2
loading required module 'bridgestp'
/boot/kernel/bridgestp.ko text=0x12e5 text=0x4cd8 data=0x2c8+0x28 0x8+0xb40+0x8+0x6b4
if_gre.../boot/kernel/if_gre.ko text=0x2736 text=0x40f8 data=0x8c8+0x40 0x8+0x1728+0x8+0xfd5
umass...if_enc.../boot/kernel/if_enc.ko text=0x15ca text=0x934 data=0x750 0x8+0xca8+0x8+0xb71
if_vlan...ugen...can't find 'ugen'
failed!
uhid.../boot/kernel/uhid.ko text=0x1fe0 text=0x1650 data=0x6d0+0x10 0x8+0xeb8+0x8+0xa75
carp.../boot/kernel/carp.ko text=0x3500 text=0x6f80 data=0xcd0+0x48 0x8+0x1a28+0x8+0x12ef
usb...if_gif...pflog.../boot/kernel/pflog.ko text=0xf78 text=0x888 data=0x430 0x8+0x9f0+0x8+0x712
loading required module 'pf'
/boot/kernel/pf.ko text=0xed00 text=0x3d030 data=0x5a40+0x3ac 0x8+0x5ca0+0x8+0x4b21
pf...ukbd...if_tun...if_lagg.../boot/kernel/if_lagg.ko text=0x3d0f text=0x9890 data=0xd10+0x8 0x8+0x1c80+0x8+0x15a3
loading required module 'if_infiniband'
/boot/kernel/if_infiniband.ko text=0x1102 text=0x112c data=0x300+0x8 0x8+0x8d0+0x8+0x59a
if_tap...pfsync.../boot/kernel/pfsync.ko text=0x2f63 text=0x7fcc data=0xb38+0x8 0x8+0x1830+0x8+0x1192
/boot/entropy.../boot/entropy size=0x1000

Hit [Enter] to boot immediately, or any other key for command prompt.
Booting [/boot/kernel/kernel]...               
Using DTB provided by EFI at 0x80ec000.
EFI framebuffer information:
addr, size     0x0, 0x0
dimensions     0 x 0
stride         0
masks          0x00000000, 0x00000000, 0x00000000, 0x00000000
---<<BOOT>>---
KDB: debugger backends: ddb
KDB: current backend: ddb
WARNING: Cannot find freebsd,dts-version property, cannot check DTB compliance
Copyright (c) 1992-2021 The FreeBSD Project.
Copyright (c) 1979, 1980, 1983, 1986, 1988, 1989, 1991, 1992, 1993, 1994
        The Regents of the University of California. All rights reserved.
FreeBSD is a registered trademark of The FreeBSD Foundation.
FreeBSD 13.2-RELEASE-p1 stable/23.7-n254737-f223233eef4 SMP arm64
FreeBSD clang version 14.0.5 (https://github.com/llvm/llvm-project.git llvmorg-14.0.5-0-gc12386ae247c)
VT: init without driver.
module firmware already present!
real memory  = 4158652416 (3966 MB)
avail memory = 4029468672 (3842 MB)
Starting CPU 1 (1)
Starting CPU 2 (2)
Starting CPU 3 (3)
Starting CPU 4 (100)
Starting CPU 5 (101)
FreeBSD/SMP: Multiprocessor System Detected: 6 CPUs
random: unblocking device.
random: entropy device external interface
MAP f0f1b000 mode 2 pages 2
MAP f0f1e000 mode 2 pages 2
MAP f0f21000 mode 2 pages 4
MAP f3f40000 mode 2 pages 16
kbd0 at kbdmux0
ofwbus0: <Open Firmware Device Tree>
clk_fixed0: <Fixed clock> on ofwbus0
rk_grf0: <RockChip General Register Files> mem 0xff320000-0xff320fff on ofwbus0
rk3399_pmucru0: <Rockchip RK3399 PMU Clock and Reset Unit> mem 0xff750000-0xff750fff on ofwbus0
rk3399_cru0: <Rockchip RK3399 Clock and Reset Unit> mem 0xff760000-0xff760fff on ofwbus0
rk_grf1: <RockChip General Register Files> mem 0xff770000-0xff77ffff on ofwbus0
clk_fixed1: <Fixed clock> on ofwbus0
regfix0: <Fixed Regulator> on ofwbus0
regfix1: <Fixed Regulator> on ofwbus0
regfix2: <Fixed Regulator> on ofwbus0
regfix3: <Fixed Regulator> on ofwbus0
regfix4: <Fixed Regulator> on ofwbus0
regfix5: <Fixed Regulator> on ofwbus0
regfix6: <Fixed Regulator> on ofwbus0
regfix7: <Fixed Regulator> on ofwbus0
simple_mfd0: <Simple MFD (Multi-Functions Device)> mem 0xff310000-0xff310fff on ofwbus0
psci0: <ARM Power State Co-ordination Interface Driver> on ofwbus0
gic0: <ARM Generic Interrupt Controller v3.0> mem 0xfee00000-0xfee0ffff,0xfef00000-0xfefbffff,0xfff00000-0xfff0ffff,0xfff10000-0xfff1ffff,0xfff20000-0xfff20
its0: <ARM GIC Interrupt Translation Service> mem 0xfee20000-0xfee3ffff on gic0
rk_iodomain0: <RockChip IO Voltage Domain> mem 0xff320000-0xff320fff on rk_grf0
rk_iodomain1: <RockChip IO Voltage Domain> mem 0-0xff76ffff,0-0xffff on rk_grf1
rk_pinctrl0: <RockChip Pinctrl controller> on ofwbus0
gpio0: <RockChip GPIO Bank controller> mem 0xff720000-0xff7200ff irq 73 on rk_pinctrl0
gpiobus0: <OFW GPIO bus> on gpio0
gpio1: <RockChip GPIO Bank controller> mem 0xff730000-0xff7300ff irq 74 on rk_pinctrl0
gpiobus1: <OFW GPIO bus> on gpio1
gpio2: <RockChip GPIO Bank controller> mem 0xff780000-0xff7800ff irq 75 on rk_pinctrl0
gpiobus2: <OFW GPIO bus> on gpio2
gpio3: <RockChip GPIO Bank controller> mem 0xff788000-0xff7880ff irq 76 on rk_pinctrl0
gpiobus3: <OFW GPIO bus> on gpio3
gpio4: <RockChip GPIO Bank controller> mem 0xff790000-0xff7900ff irq 77 on rk_pinctrl0
gpiobus4: <OFW GPIO bus> on gpio4
rk_i2c0: <RockChip I2C> mem 0xff110000-0xff110fff irq 20 on ofwbus0
iicbus0: <OFW I2C bus> on rk_i2c0
rk_i2c1: <RockChip I2C> mem 0xff120000-0xff120fff irq 21 on ofwbus0
iicbus1: <OFW I2C bus> on rk_i2c1
rk_i2c2: <RockChip I2C> mem 0xff160000-0xff160fff irq 25 on ofwbus0
iicbus2: <OFW I2C bus> on rk_i2c2
rk_i2c3: <RockChip I2C> mem 0xff3c0000-0xff3c0fff irq 38 on ofwbus0
iicbus3: <OFW I2C bus> on rk_i2c3
syr8270: <Silergy SYR827 regulator> at addr 0x80 on iicbus3
rk805_pmu0: <RockChip RK805 PMIC> at addr 0x36 irq 78 on iicbus3
generic_timer0: <ARMv8 Generic Timer> irq 2,3,4,5 on ofwbus0
Timecounter "ARM MPCore Timecounter" frequency 24000000 Hz quality 1000
Event timer "ARM MPCore Eventtimer" frequency 24000000 Hz quality 1000
rk_tsadc0: <RockChip temperature sensors> mem 0xff260000-0xff2600ff irq 35 on ofwbus0
mmc_pwrseq0: <MMC Simple Power sequence> on ofwbus0
mmc_pwrseq0: Node have a clocks property but no clocks named "ext_clock"
device_attach: mmc_pwrseq0 attach returned 6
rk_usb2phy0: <Rockchip RK3399 USB2PHY> mem 0-0xff76ffff,0-0xffff on rk_grf1
rk_usb2phy1: <Rockchip RK3399 USB2PHY> mem 0-0xff76ffff,0-0xffff on rk_grf1
rk_usb2phy1: host-port isn't okay
rk_pcie_phy0: <Rockchip RK3399 PCIe PHY> mem 0-0xff76ffff,0-0xffff on rk_grf1
rk_typec_phy0: <Rockchip RK3399 PHY TYPEC> mem 0xff7c0000-0xff7fffff on ofwbus0
rk_typec_phy1: <Rockchip RK3399 PHY TYPEC> mem 0xff800000-0xff83ffff on ofwbus0
mmc_pwrseq0: <MMC Simple Power sequence> on ofwbus0
mmc_pwrseq0: Node have a clocks property but no clocks named "ext_clock"
device_attach: mmc_pwrseq0 attach returned 6
cpulist0: <Open Firmware CPU Group> on ofwbus0
cpu0: <Open Firmware CPU> on cpulist0
cpufreq_dt0: <Generic cpufreq driver> on cpu0
cpu1: <Open Firmware CPU> on cpulist0
cpufreq_dt1: <Generic cpufreq driver> on cpu1
cpu2: <Open Firmware CPU> on cpulist0
cpufreq_dt2: <Generic cpufreq driver> on cpu2
cpu3: <Open Firmware CPU> on cpulist0
cpufreq_dt3: <Generic cpufreq driver> on cpu3
cpu4: <Open Firmware CPU> on cpulist0
cpufreq_dt4: <Generic cpufreq driver> on cpu4
cpu5: <Open Firmware CPU> on cpulist0
cpufreq_dt5: <Generic cpufreq driver> on cpu5
pmu0: <Performance Monitoring Unit> irq 0 on ofwbus0
pmu1: <Performance Monitoring Unit> irq 1 on ofwbus0
pcib0: <Rockchip PCIe controller> mem 0xf8000000-0xf9ffffff,0xfd000000-0xfdffffff irq 6,7,8 on ofwbus0
pci0: <PCI bus> on pcib0
pcib1: <PCI-PCI bridge> at device 0.0 on pci0
pcib0: failed to reserve resource for pcib1
pcib1: failed to allocate initial memory window: 0-0xfffff
pci1: <PCI bus> on pcib1
re0: <RealTek 8168/8111 B/C/CP/D/DP/E/F/G PCIe Gigabit Ethernet> at device 0.0 on pci1
re0: Using 1 MSI-X message
re0: turning off MSI enable bit.
re0: Chip rev. 0x54000000
re0: MAC rev. 0x00100000
miibus0: <MII bus> on re0
rgephy0: <RTL8251/8153 1000BASE-T media interface> PHY 1 on miibus0
rgephy0:  none, 10baseT, 10baseT-FDX, 10baseT-FDX-flow, 100baseTX, 100baseTX-FDX, 100baseTX-FDX-flow, 1000baseT-FDX, 1000baseT-FDX-master, 1000baseT-FDX-flw
re0: Using defaults for TSO: 65518/35/2048
re0: netmap queues/slots: TX 1/256, RX 1/256
dwc0: <Rockchip Gigabit Ethernet Controller> mem 0xfe300000-0xfe30ffff irq 9 on ofwbus0
miibus1: <MII bus> on dwc0
rgephy1: <RTL8169S/8110S/8211 1000BASE-T media interface> PHY 0 on miibus1
rgephy1:  none, 10baseT, 10baseT-FDX, 100baseTX, 100baseTX-FDX, 1000baseT, 1000baseT-master, 1000baseT-FDX, 1000baseT-FDX-master, auto
rgephy2: <RTL8169S/8110S/8211 1000BASE-T media interface> PHY 1 on miibus1
rgephy2:  none, 10baseT, 10baseT-FDX, 100baseTX, 100baseTX-FDX, 1000baseT, 1000baseT-master, 1000baseT-FDX, 1000baseT-FDX-master, auto
dwc0: Ethernet address: 62:73:64:1e:22:28
rockchip_dwmmc0: <Synopsys DesignWare Mobile Storage Host Controller (RockChip)> mem 0xfe320000-0xfe323fff irq 11 on ofwbus0
rockchip_dwmmc0: Hardware version ID is 270a
mmc0: <MMC/SD bus> on rockchip_dwmmc0
ehci0: <Generic EHCI Controller> mem 0xfe380000-0xfe39ffff irq 13 on ofwbus0
usbus0: EHCI version 1.0
usbus0 on ehci0
ohci0: <Generic OHCI Controller> mem 0xfe3a0000-0xfe3bffff irq 14 on ofwbus0
usbus1 on ohci0
ehci1: <Generic EHCI Controller> mem 0xfe3c0000-0xfe3dffff irq 15 on ofwbus0
usbus2: EHCI version 1.0
usbus2 on ehci1
ohci1: <Generic OHCI Controller> mem 0xfe3e0000-0xfe3fffff irq 16 on ofwbus0
usbus3 on ohci1
rk_dwc30: <Rockchip RK3399 DWC3> on ofwbus0
snps_dwc3_fdt0: <Synopsys Designware DWC3> mem 0xfe800000-0xfe8fffff irq 80 on rk_dwc30
snps_dwc3_fdt0: 64 bytes context size, 32-bit DMA
usbus4: trying to attach
usbus4 on snps_dwc3_fdt0
rk_dwc31: <Rockchip RK3399 DWC3> on ofwbus0
snps_dwc3_fdt1: <Synopsys Designware DWC3> mem 0xfe900000-0xfe9fffff irq 81 on rk_dwc31
snps_dwc3_fdt1: 64 bytes context size, 32-bit DMA
usbus5: trying to attach
usbus5 on snps_dwc3_fdt1
iic0: <I2C generic I/O> on iicbus0
iic1: <I2C generic I/O> on iicbus1
iic2: <I2C generic I/O> on iicbus2
uart0: <16750 or compatible> mem 0xff1a0000-0xff1a00ff irq 28 on ofwbus0
uart0: console (1500000,n,8,1)
iicbus3: <unknown card> at addr 0x82
iic3: <I2C generic I/O> on iicbus3
pwm0: <Rockchip PWM> mem 0xff420000-0xff42000f on ofwbus0
pwmbus0: <OFW PWM bus> on pwm0
pwmc0: <PWM Control> channel 0 on pwmbus0
pwm1: <Rockchip PWM> mem 0xff420010-0xff42001f on ofwbus0
pwmbus1: <OFW PWM bus> on pwm1
pwmc1: <PWM Control> channel 0 on pwmbus1
pwm2: <Rockchip PWM> mem 0xff420020-0xff42002f on ofwbus0
pwmbus2: <OFW PWM bus> on pwm2
pwmc2: <PWM Control> channel 0 on pwmbus2
gpioc0: <GPIO controller> on gpio0
gpioc1: <GPIO controller> on gpio1
gpioc2: <GPIO controller> on gpio2
gpioc3: <GPIO controller> on gpio3
gpioc4: <GPIO controller> on gpio4
gpioled0: <GPIO LEDs> on ofwbus0
mmc_pwrseq0: <MMC Simple Power sequence> on ofwbus0
mmc_pwrseq0: Node have a clocks property but no clocks named "ext_clock"
device_attach: mmc_pwrseq0 attach returned 6
armv8crypto0: <AES-CBC,AES-XTS,AES-GCM>
Timecounters tick every 1.000 msec
usbus0: 480Mbps High Speed USB v2.0
usbus1: 12Mbps Full Speed USB v1.0
usbus2: 480Mbps High Speed USB v2.0
usbus3: 12Mbps Full Speed USB v1.0
usbus4: 5.0Gbps Super Speed USB v3.0
usbus5: 5.0Gbps Super Speed USB v3.0
rk805_pmu0: registered as a time-of-day clock, resolution 1.000000s
ugen1.1: <Generic OHCI root HUB> at usbus1
uhub0 on usbus1
uhub0: <Generic OHCI root HUB, class 9/0, rev 1.00/1.00, addr 1> on usbus1
ugen0.1: <Generic EHCI root HUB> at usbus0
uhub1 on usbus0
uhub1: <Generic EHCI root HUB, class 9/0, rev 2.00/1.00, addr 1> on usbus0
ugen3.1: <Generic OHCI root HUB> at usbus3
uhub2 on usbus3
uhub2: <Generic OHCI root HUB, class 9/0, rev 1.00/1.00, addr 1> on usbus3
ugen2.1: <Generic EHCI root HUB> at usbus2
uhub3 on usbus2
uhub3: <Generic EHCI root HUB, class 9/0, rev 2.00/1.00, addr 1> on usbus2
ugen5.1: <Synopsys XHCI root HUB> at usbus5
uhub4 on usbus5
uhub4: <Synopsys XHCI root HUB, class 9/0, rev 3.00/1.00, addr 1> on usbus5
ugen4.1: <Synopsys XHCI root HUB> at usbus4
uhub5 on usbus4
uhub5: <Synopsys XHCI root HUB, class 9/0, rev 3.00/1.00, addr 1> on usbus4
mmcsd0: 8GB <SDHC SA08G 8.0 SN A54C5353 MFG 04/2019 by 3 SD> at mmc0 50.0MHz/4bit/1016-block
CPU  0: ARM Cortex-A53 r0p4 affinity:  0  0
                   Cache Type = <64 byte D-cacheline,64 byte I-cacheline,VIPT ICache,64 byte ERG,64 byte CWG>
 Instruction Set Attributes 0 = <CRC32,SHA2,SHA1,AES+PMULL>
 Instruction Set Attributes 1 = <>
 Instruction Set Attributes 2 = <>
         Processor Features 0 = <GIC,AdvSIMD,FP,EL3 32,EL2 32,EL1 32,EL0 32>
         Processor Features 1 = <>
      Memory Model Features 0 = <TGran4,TGran64,SNSMem,BigEnd,16bit ASID,1TB PA>
      Memory Model Features 1 = <8bit VMID>
      Memory Model Features 2 = <32bit CCIDX,48bit VA>
             Debug Features 0 = <DoubleLock,2 CTX BKPTs,4 Watchpoints,6 Breakpoints,PMUv3,Debugv8>
             Debug Features 1 = <>
         Auxiliary Features 0 = <>
         Auxiliary Features 1 = <>
AArch32 Instruction Set Attributes 5 = <CRC32,SHA2,SHA1,AES+VMULL,SEVL>
AArch32 Media and VFP Features 0 = <FPRound,FPSqrt,FPDivide,DP VFPv3+v4,SP VFPv3+v4,AdvSIMD>
AArch32 Media and VFP Features 1 = <SIMDFMAC,FPHP DP Conv,SIMDHP SP Conv,SIMDSP,SIMDInt,SIMDLS,FPDNaN,FPFtZ>
CPU  1: ARM Cortex-A53 r0p4 affinity:  0  1
CPU  2: ARM Cortex-A53 r0p4 affinity:  0  2
CPU  3: ARM Cortex-A53 r0p4 affinity:  0  3
CPU  4: ARM Cortex-A72 r0p2 affinity:  1  0
                   Cache Type = <64 byte D-cacheline,64 byte I-cacheline,PIPT ICache,64 byte ERG,64 byte CWG>
      Memory Model Features 0 = <TGran4,TGran64,SNSMem,BigEnd,16bit ASID,16TB PA>
CPU  5: ARM Cortex-A72 r0p2 affinity:  1  1
Release APs...done
Trying to mount root from ufs:/dev/ufs/OPNsense [rw]...
Warning: bad time from time-of-day clock, system time will not be set accurately
Dual Console: Serial Primary, Video Secondary
uhub0: 1 port with 1 removable, self powered
uhub2: 1 port with 1 removable, self powered
uhub5: 2 ports with 2 removable, self powered
uhub4: 2 ports with 2 removable, self powered
Mounting filesystems...
tunefs: soft updates remains unchanged as enabled
uhub1: 1 port with 1 removable, self powered
uhub3: 1 port with 1 removable, self powered
camcontrol: cam_lookup_pass: CAMGETPASSTHRU ioctl failed
cam_lookup_pass: No such file or directory
cam_lookup_pass: either the pass driver isn't in your kernel
cam_lookup_pass: or mmcsd0 doesn't exist
mmcsd0 recovering is not needed
mmcsd0s1 resized
growfs: requested size 3.0GB is equal to the current filesystem size 3.0GB
** /dev/ufs/OPNsense                                                                          
FILE SYSTEM CLEAN; SKIPPING CHECKS                                                            
clean, 372793 free (153 frags, 46580 blocks, 0.0% fragmentation)                              
/etc/rc.d/hostid: WARNING: hostid: unable to figure out a UUID from DMI data, generating a new one
Setting hostuuid: dbe4733b-a359-4c5c-807a-e186ef62cec1.                                       
Setting hostid: 0x7d75e276.
Press any key to start the configuration importer: .........
Bootstrapping config.xml...done.
Setting up /var/log memory disk...done.
Configuring crash dump device: /dev/null
.ELF ldconfig path: /lib /usr/lib /usr/lib/compat /usr/local/lib /usr/local/lib/compat/pkg /usr/local/lib/compat/pkg /usr/local/lib/ipsec /usr/local/lib/peE
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
re0: link state changed to UP
Starting device manager...done.
Configuring login behaviour...done.

Default interfaces not found -- Running interface assignment option.

Press any key to start the manual interface assignment: 3�
U-Boot TPL 2023.01 (Jul 03 2023 - 11:22:46)
lpddr4_set_rate: change freq to 400MHz 0, 1
Channel 0: LPDDR4, 400MHz
BW=32 Col=10 Bk=8 CS0 Row=15 CS1 Row=15 CS=2 Die BW=16 Size=2048MB
Channel 1: LPDDR4, 400MHz
BW=32 Col=10 Bk=8 CS0 Row=15 CS1 Row=15 CS=2 Die BW=16 Size=2048MB
256B stride
lpddr4_set_rate: change freq to 800MHz 1, 0
Trying to boot from BOOTROM
Returning to boot ROM...
cLoading kernel...
/boot/kernel/kernel text=0x2a8 text=0x942160 text=0x236b0c data=0x1ba3b8 data=0x0+0x2b2000 0x8+0x13b990+0x8+0x161b8d\
Loading configured modules...
/etc/hostid...can't find '/etc/hostid'
failed!
if_bridge.../boot/kernel/if_bridge.ko text=0x3884 text=0x6e2c data=0xde8+0x8 0x8+0x1c98+0x8+0x16b2
loading required module 'bridgestp'
/boot/kernel/bridgestp.ko text=0x12e5 text=0x4cd8 data=0x2c8+0x28 0x8+0xb40+0x8+0x6b4
if_gre.../boot/kernel/if_gre.ko text=0x2736 text=0x40f8 data=0x8c8+0x40 0x8+0x1728+0x8+0xfd5
umass...if_enc.../boot/kernel/if_enc.ko text=0x15ca text=0x934 data=0x750 0x8+0xca8+0x8+0xb71
if_vlan...ugen...can't find 'ugen'
failed!
uhid.../boot/kernel/uhid.ko text=0x1fe0 text=0x1650 data=0x6d0+0x10 0x8+0xeb8+0x8+0xa75
carp.../boot/kernel/carp.ko text=0x3500 text=0x6f80 data=0xcd0+0x48 0x8+0x1a28+0x8+0x12ef
usb...if_gif...pflog.../boot/kernel/pflog.ko text=0xf78 text=0x888 data=0x430 0x8+0x9f0+0x8+0x712
loading required module 'pf'
/boot/kernel/pf.ko text=0xed00 text=0x3d030 data=0x5a40+0x3ac 0x8+0x5ca0+0x8+0x4b21
pf...ukbd...if_tun...if_lagg.../boot/kernel/if_lagg.ko text=0x3d0f text=0x9890 data=0xd10+0x8 0x8+0x1c80+0x8+0x15a3
loading required module 'if_infiniband'
/boot/kernel/if_infiniband.ko text=0x1102 text=0x112c data=0x300+0x8 0x8+0x8d0+0x8+0x59a
if_tap...pfsync.../boot/kernel/pfsync.ko text=0x2f63 text=0x7fcc data=0xb38+0x8 0x8+0x1830+0x8+0x1192
/boot/entropy.../boot/entropy size=0x1000

Hit [Enter] to boot immediately, or any other key for command prompt.
Booting [/boot/kernel/kernel]...               
Using DTB provided by EFI at 0x80ec000.
EFI framebuffer information:
addr, size     0x0, 0x0
dimensions     0 x 0
stride         0
masks          0x00000000, 0x00000000, 0x00000000, 0x00000000
---<<BOOT>>---
KDB: debugger backends: ddb
KDB: current backend: ddb
WARNING: Cannot find freebsd,dts-version property, cannot check DTB compliance
Copyright (c) 1992-2021 The FreeBSD Project.
Copyright (c) 1979, 1980, 1983, 1986, 1988, 1989, 1991, 1992, 1993, 1994
        The Regents of the University of California. All rights reserved.
FreeBSD is a registered trademark of The FreeBSD Foundation.
FreeBSD 13.2-RELEASE-p1 stable/23.7-n254737-f223233eef4 SMP arm64
FreeBSD clang version 14.0.5 (https://github.com/llvm/llvm-project.git llvmorg-14.0.5-0-gc12386ae247c)
VT: init without driver.
module firmware already present!
real memory  = 4158652416 (3966 MB)
avail memory = 4029468672 (3842 MB)
Starting CPU 1 (1)
Starting CPU 2 (2)
Starting CPU 3 (3)
Starting CPU 4 (100)
Starting CPU 5 (101)
FreeBSD/SMP: Multiprocessor System Detected: 6 CPUs
random: unblocking device.
random: entropy device external interface
MAP f0f1b000 mode 2 pages 2
MAP f0f1e000 mode 2 pages 2
MAP f0f21000 mode 2 pages 4
MAP f3f40000 mode 2 pages 16
kbd0 at kbdmux0
ofwbus0: <Open Firmware Device Tree>
clk_fixed0: <Fixed clock> on ofwbus0
rk_grf0: <RockChip General Register Files> mem 0xff320000-0xff320fff on ofwbus0
rk3399_pmucru0: <Rockchip RK3399 PMU Clock and Reset Unit> mem 0xff750000-0xff750fff on ofwbus0
rk3399_cru0: <Rockchip RK3399 Clock and Reset Unit> mem 0xff760000-0xff760fff on ofwbus0
rk_grf1: <RockChip General Register Files> mem 0xff770000-0xff77ffff on ofwbus0
clk_fixed1: <Fixed clock> on ofwbus0
regfix0: <Fixed Regulator> on ofwbus0
regfix1: <Fixed Regulator> on ofwbus0
regfix2: <Fixed Regulator> on ofwbus0
regfix3: <Fixed Regulator> on ofwbus0
regfix4: <Fixed Regulator> on ofwbus0
regfix5: <Fixed Regulator> on ofwbus0
regfix6: <Fixed Regulator> on ofwbus0
regfix7: <Fixed Regulator> on ofwbus0
simple_mfd0: <Simple MFD (Multi-Functions Device)> mem 0xff310000-0xff310fff on ofwbus0
psci0: <ARM Power State Co-ordination Interface Driver> on ofwbus0
gic0: <ARM Generic Interrupt Controller v3.0> mem 0xfee00000-0xfee0ffff,0xfef00000-0xfefbffff,0xfff00000-0xfff0ffff,0xfff10000-0xfff1ffff,0xfff20000-0xfff20
its0: <ARM GIC Interrupt Translation Service> mem 0xfee20000-0xfee3ffff on gic0
rk_iodomain0: <RockChip IO Voltage Domain> mem 0xff320000-0xff320fff on rk_grf0
rk_iodomain1: <RockChip IO Voltage Domain> mem 0-0xff76ffff,0-0xffff on rk_grf1
rk_pinctrl0: <RockChip Pinctrl controller> on ofwbus0
gpio0: <RockChip GPIO Bank controller> mem 0xff720000-0xff7200ff irq 73 on rk_pinctrl0
gpiobus0: <OFW GPIO bus> on gpio0
gpio1: <RockChip GPIO Bank controller> mem 0xff730000-0xff7300ff irq 74 on rk_pinctrl0
gpiobus1: <OFW GPIO bus> on gpio1
gpio2: <RockChip GPIO Bank controller> mem 0xff780000-0xff7800ff irq 75 on rk_pinctrl0
gpiobus2: <OFW GPIO bus> on gpio2
gpio3: <RockChip GPIO Bank controller> mem 0xff788000-0xff7880ff irq 76 on rk_pinctrl0
gpiobus3: <OFW GPIO bus> on gpio3
gpio4: <RockChip GPIO Bank controller> mem 0xff790000-0xff7900ff irq 77 on rk_pinctrl0
gpiobus4: <OFW GPIO bus> on gpio4
rk_i2c0: <RockChip I2C> mem 0xff110000-0xff110fff irq 20 on ofwbus0
iicbus0: <OFW I2C bus> on rk_i2c0
rk_i2c1: <RockChip I2C> mem 0xff120000-0xff120fff irq 21 on ofwbus0
iicbus1: <OFW I2C bus> on rk_i2c1
rk_i2c2: <RockChip I2C> mem 0xff160000-0xff160fff irq 25 on ofwbus0
iicbus2: <OFW I2C bus> on rk_i2c2
rk_i2c3: <RockChip I2C> mem 0xff3c0000-0xff3c0fff irq 38 on ofwbus0
iicbus3: <OFW I2C bus> on rk_i2c3
syr8270: <Silergy SYR827 regulator> at addr 0x80 on iicbus3
rk805_pmu0: <RockChip RK805 PMIC> at addr 0x36 irq 78 on iicbus3
generic_timer0: <ARMv8 Generic Timer> irq 2,3,4,5 on ofwbus0
Timecounter "ARM MPCore Timecounter" frequency 24000000 Hz quality 1000
Event timer "ARM MPCore Eventtimer" frequency 24000000 Hz quality 1000
rk_tsadc0: <RockChip temperature sensors> mem 0xff260000-0xff2600ff irq 35 on ofwbus0
mmc_pwrseq0: <MMC Simple Power sequence> on ofwbus0
mmc_pwrseq0: Node have a clocks property but no clocks named "ext_clock"
device_attach: mmc_pwrseq0 attach returned 6
rk_usb2phy0: <Rockchip RK3399 USB2PHY> mem 0-0xff76ffff,0-0xffff on rk_grf1
rk_usb2phy1: <Rockchip RK3399 USB2PHY> mem 0-0xff76ffff,0-0xffff on rk_grf1
rk_usb2phy1: host-port isn't okay
rk_pcie_phy0: <Rockchip RK3399 PCIe PHY> mem 0-0xff76ffff,0-0xffff on rk_grf1
rk_typec_phy0: <Rockchip RK3399 PHY TYPEC> mem 0xff7c0000-0xff7fffff on ofwbus0
rk_typec_phy1: <Rockchip RK3399 PHY TYPEC> mem 0xff800000-0xff83ffff on ofwbus0
mmc_pwrseq0: <MMC Simple Power sequence> on ofwbus0
mmc_pwrseq0: Node have a clocks property but no clocks named "ext_clock"
device_attach: mmc_pwrseq0 attach returned 6
cpulist0: <Open Firmware CPU Group> on ofwbus0
cpu0: <Open Firmware CPU> on cpulist0
cpufreq_dt0: <Generic cpufreq driver> on cpu0
cpu1: <Open Firmware CPU> on cpulist0
cpufreq_dt1: <Generic cpufreq driver> on cpu1
cpu2: <Open Firmware CPU> on cpulist0
cpufreq_dt2: <Generic cpufreq driver> on cpu2
cpu3: <Open Firmware CPU> on cpulist0
cpufreq_dt3: <Generic cpufreq driver> on cpu3
cpu4: <Open Firmware CPU> on cpulist0
cpufreq_dt4: <Generic cpufreq driver> on cpu4
cpu5: <Open Firmware CPU> on cpulist0
cpufreq_dt5: <Generic cpufreq driver> on cpu5
pmu0: <Performance Monitoring Unit> irq 0 on ofwbus0
pmu1: <Performance Monitoring Unit> irq 1 on ofwbus0
pcib0: <Rockchip PCIe controller> mem 0xf8000000-0xf9ffffff,0xfd000000-0xfdffffff irq 6,7,8 on ofwbus0
pci0: <PCI bus> on pcib0
pcib1: <PCI-PCI bridge> at device 0.0 on pci0
pcib0: failed to reserve resource for pcib1
pcib1: failed to allocate initial memory window: 0-0xfffff
pci1: <PCI bus> on pcib1
re0: <RealTek 8168/8111 B/C/CP/D/DP/E/F/G PCIe Gigabit Ethernet> at device 0.0 on pci1
re0: Using 1 MSI-X message
re0: turning off MSI enable bit.
re0: Chip rev. 0x54000000
re0: MAC rev. 0x00100000
miibus0: <MII bus> on re0
rgephy0: <RTL8251/8153 1000BASE-T media interface> PHY 1 on miibus0
rgephy0:  none, 10baseT, 10baseT-FDX, 10baseT-FDX-flow, 100baseTX, 100baseTX-FDX, 100baseTX-FDX-flow, 1000baseT-FDX, 1000baseT-FDX-master, 1000baseT-FDX-flw
re0: Using defaults for TSO: 65518/35/2048
re0: netmap queues/slots: TX 1/256, RX 1/256
dwc0: <Rockchip Gigabit Ethernet Controller> mem 0xfe300000-0xfe30ffff irq 9 on ofwbus0
miibus1: <MII bus> on dwc0
rgephy1: <RTL8169S/8110S/8211 1000BASE-T media interface> PHY 0 on miibus1
rgephy1:  none, 10baseT, 10baseT-FDX, 100baseTX, 100baseTX-FDX, 1000baseT, 1000baseT-master, 1000baseT-FDX, 1000baseT-FDX-master, auto
rgephy2: <RTL8169S/8110S/8211 1000BASE-T media interface> PHY 1 on miibus1
rgephy2:  none, 10baseT, 10baseT-FDX, 100baseTX, 100baseTX-FDX, 1000baseT, 1000baseT-master, 1000baseT-FDX, 1000baseT-FDX-master, auto
dwc0: Ethernet address: 62:73:64:62:2a:dc
rockchip_dwmmc0: <Synopsys DesignWare Mobile Storage Host Controller (RockChip)> mem 0xfe320000-0xfe323fff irq 11 on ofwbus0
rockchip_dwmmc0: Hardware version ID is 270a
mmc0: <MMC/SD bus> on rockchip_dwmmc0
ehci0: <Generic EHCI Controller> mem 0xfe380000-0xfe39ffff irq 13 on ofwbus0
usbus0: EHCI version 1.0
usbus0 on ehci0
ohci0: <Generic OHCI Controller> mem 0xfe3a0000-0xfe3bffff irq 14 on ofwbus0
usbus1 on ohci0
ehci1: <Generic EHCI Controller> mem 0xfe3c0000-0xfe3dffff irq 15 on ofwbus0
usbus2: EHCI version 1.0
usbus2 on ehci1
ohci1: <Generic OHCI Controller> mem 0xfe3e0000-0xfe3fffff irq 16 on ofwbus0
usbus3 on ohci1
rk_dwc30: <Rockchip RK3399 DWC3> on ofwbus0
snps_dwc3_fdt0: <Synopsys Designware DWC3> mem 0xfe800000-0xfe8fffff irq 80 on rk_dwc30
snps_dwc3_fdt0: 64 bytes context size, 32-bit DMA
usbus4: trying to attach
usbus4 on snps_dwc3_fdt0
rk_dwc31: <Rockchip RK3399 DWC3> on ofwbus0
snps_dwc3_fdt1: <Synopsys Designware DWC3> mem 0xfe900000-0xfe9fffff irq 81 on rk_dwc31
snps_dwc3_fdt1: 64 bytes context size, 32-bit DMA
usbus5: trying to attach
usbus5 on snps_dwc3_fdt1
iic0: <I2C generic I/O> on iicbus0
iic1: <I2C generic I/O> on iicbus1
iic2: <I2C generic I/O> on iicbus2
uart0: <16750 or compatible> mem 0xff1a0000-0xff1a00ff irq 28 on ofwbus0
uart0: console (1500000,n,8,1)
iicbus3: <unknown card> at addr 0x82
iic3: <I2C generic I/O> on iicbus3
pwm0: <Rockchip PWM> mem 0xff420000-0xff42000f on ofwbus0
pwmbus0: <OFW PWM bus> on pwm0
pwmc0: <PWM Control> channel 0 on pwmbus0
pwm1: <Rockchip PWM> mem 0xff420010-0xff42001f on ofwbus0
pwmbus1: <OFW PWM bus> on pwm1
pwmc1: <PWM Control> channel 0 on pwmbus1
pwm2: <Rockchip PWM> mem 0xff420020-0xff42002f on ofwbus0
pwmbus2: <OFW PWM bus> on pwm2
pwmc2: <PWM Control> channel 0 on pwmbus2
gpioc0: <GPIO controller> on gpio0
gpioc1: <GPIO controller> on gpio1
gpioc2: <GPIO controller> on gpio2
gpioc3: <GPIO controller> on gpio3
gpioc4: <GPIO controller> on gpio4
gpioled0: <GPIO LEDs> on ofwbus0
mmc_pwrseq0: <MMC Simple Power sequence> on ofwbus0
mmc_pwrseq0: Node have a clocks property but no clocks named "ext_clock"
device_attach: mmc_pwrseq0 attach returned 6
armv8crypto0: <AES-CBC,AES-XTS,AES-GCM>
Timecounters tick every 1.000 msec
usbus0: 480Mbps High Speed USB v2.0
usbus1: 12Mbps Full Speed USB v1.0
usbus2: 480Mbps High Speed USB v2.0
usbus3: 12Mbps Full Speed USB v1.0
usbus4: 5.0Gbps Super Speed USB v3.0
usbus5: 5.0Gbps Super Speed USB v3.0
rk805_pmu0: registered as a time-of-day clock, resolution 1.000000s
ugen1.1: <Generic OHCI root HUB> at usbus1
uhub0 on usbus1
uhub0: <Generic OHCI root HUB, class 9/0, rev 1.00/1.00, addr 1> on usbus1
ugen0.1: <Generic EHCI root HUB> at usbus0
uhub1 on usbus0
uhub1: <Generic EHCI root HUB, class 9/0, rev 2.00/1.00, addr 1> on usbus0
ugen3.1: <Generic OHCI root HUB> at usbus3
uhub2 on usbus3
uhub2: <Generic OHCI root HUB, class 9/0, rev 1.00/1.00, addr 1> on usbus3
ugen2.1: <Generic EHCI root HUB> at usbus2
uhub3 on usbus2
uhub3: <Generic EHCI root HUB, class 9/0, rev 2.00/1.00, addr 1> on usbus2
ugen5.1: <Synopsys XHCI root HUB> at usbus5
uhub4 on usbus5
uhub4: <Synopsys XHCI root HUB, class 9/0, rev 3.00/1.00, addr 1> on usbus5
ugen4.1: <Synopsys XHCI root HUB> at usbus4
uhub5 on usbus4
uhub5: <Synopsys XHCI root HUB, class 9/0, rev 3.00/1.00, addr 1> on usbus4
mmcsd0: 8GB <SDHC SA08G 8.0 SN A54C5353 MFG 04/2019 by 3 SD> at mmc0 50.0MHz/4bit/1016-block
CPU  0: ARM Cortex-A53 r0p4 affinity:  0  0
                   Cache Type = <64 byte D-cacheline,64 byte I-cacheline,VIPT ICache,64 byte ERG,64 byte CWG>
 Instruction Set Attributes 0 = <CRC32,SHA2,SHA1,AES+PMULL>
 Instruction Set Attributes 1 = <>
 Instruction Set Attributes 2 = <>
         Processor Features 0 = <GIC,AdvSIMD,FP,EL3 32,EL2 32,EL1 32,EL0 32>
         Processor Features 1 = <>
      Memory Model Features 0 = <TGran4,TGran64,SNSMem,BigEnd,16bit ASID,1TB PA>
      Memory Model Features 1 = <8bit VMID>
      Memory Model Features 2 = <32bit CCIDX,48bit VA>
             Debug Features 0 = <DoubleLock,2 CTX BKPTs,4 Watchpoints,6 Breakpoints,PMUv3,Debugv8>
             Debug Features 1 = <>
         Auxiliary Features 0 = <>
         Auxiliary Features 1 = <>
AArch32 Instruction Set Attributes 5 = <CRC32,SHA2,SHA1,AES+VMULL,SEVL>
AArch32 Media and VFP Features 0 = <FPRound,FPSqrt,FPDivide,DP VFPv3+v4,SP VFPv3+v4,AdvSIMD>
AArch32 Media and VFP Features 1 = <SIMDFMAC,FPHP DP Conv,SIMDHP SP Conv,SIMDSP,SIMDInt,SIMDLS,FPDNaN,FPFtZ>
CPU  1: ARM Cortex-A53 r0p4 affinity:  0  1
CPU  2: ARM Cortex-A53 r0p4 affinity:  0  2
CPU  3: ARM Cortex-A53 r0p4 affinity:  0  3
CPU  4: ARM Cortex-A72 r0p2 affinity:  1  0
                   Cache Type = <64 byte D-cacheline,64 byte I-cacheline,PIPT ICache,64 byte ERG,64 byte CWG>
      Memory Model Features 0 = <TGran4,TGran64,SNSMem,BigEnd,16bit ASID,16TB PA>
CPU  5: ARM Cortex-A72 r0p2 affinity:  1  1
Release APs...done
Trying to mount root from ufs:/dev/ufs/OPNsense [rw]...
Warning: bad time from time-of-day clock, system time will not be set accurately
Dual Console: Serial Primary, Video Secondary
uhub0: 1 port with 1 removable, self powered
uhub2: 1 port with 1 removable, self powered
uhub4: 2 ports with 2 removable, self powered
uhub5: 2 ports with 2 removable, self powered
Mounting filesystems...
tunefs: soft updates remains unchanged as enabled
uhub3: 1 port with 1 removable, self powered
uhub1: 1 port with 1 removable, self powered
camcontrol: cam_lookup_pass: CAMGETPASSTHRU ioctl failed
cam_lookup_pass: No such file or directory
cam_lookup_pass: either the pass driver isn't in your kernel
cam_lookup_pass: or mmcsd0 doesn't exist
mmcsd0 recovering is not needed
mmcsd0s1 resized
growfs: requested size 3.0GB is equal to the current filesystem size 3.0GB
** /dev/ufs/OPNsense
FILE SYSTEM CLEAN; SKIPPING CHECKS
clean, 372793 free (153 frags, 46580 blocks, 0.0% fragmentation)
/etc/rc.d/hostid: WARNING: hostid: unable to figure out a UUID from DMI data, generating a new one
Setting hostuuid: d8213690-8873-4ac9-a161-c5dc0109a707.
Setting hostid: 0xc78036f3.
Press any key to start the configuration importer: .........
Bootstrapping config.xml...done.
Setting up /var/log memory disk...done.
Configuring crash dump device: /dev/null
.ELF ldconfig path: /lib /usr/lib /usr/lib/compat /usr/local/lib /usr/local/lib/compat/pkg /usr/local/lib/compat/pkg /usr/local/lib/ipsec /usr/local/lib/peE
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
re0: link state changed to UP
Starting device manager...done.
Configuring login behaviour...done.

Default interfaces not found -- Running interface assignment option.

Press any key to start the manual interface assignment: 1
Do you want to configure LAGGs now? [y/N]: n
Do you want to configure VLANs now? [y/N]: n

Valid interfaces are:

re0              00:00:00:00:00:00 RealTek 8168/8111 B/C/CP/D/DP/E/F/G PCIe Gigabit Ethernet
dwc0             62:73:64:62:2a:dc Rockchip Gigabit Ethernet Controller

If you do not know the names of your interfaces, you may choose to use
auto-detection. In that case, disconnect all interfaces now before
hitting 'a' to initiate auto detection.

Enter the WAN interface name or 'a' for auto-detection: dwc0

Enter the LAN interface name or 'a' for auto-detection
NOTE: this enables full Firewalling/NAT mode.
(or nothing if finished): re0

Enter the Optional interface 1 name or 'a' for auto-detection
(or nothing if finished): 

The interfaces will be assigned as follows:

WAN  -> dwc0
LAN  -> re0

Do you want to proceed? [y/N]: y

Writing configuration...done.
Configuring loopback interface...lo0: link state changed to UP
done.
Configuring kernel modules...done.
Setting up extended sysctls...done.
Setting timezone: Etc/UTC
Writing firmware setting...done.
Writing trust files...done.
Setting hostname: OPNsense.localdomain
Generating /etc/resolv.conf...done.
Generating /etc/hosts...done.
Configuring system logging...done.
Configuring firewall.......done.
Configuring hardware interfaces...done.
Configuring loopback interface...done.
Configuring LAGG interfaces...done.
Configuring VLAN interfaces...done.
Configuring LAN interface...done.
Configuring WAN interface...done.
Generating /etc/resolv.conf...done.
Generating /etc/hosts...done.
Configuring firewall.......done.
Starting web GUI...done.
Setting up routes...done.
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
>>> Invoking start script 'newwanip'
Reconfiguring IPv4 on dwc0
Reconfiguring IPv6 on dwc0
>>> Invoking start script 'freebsd'
>>> Invoking start script 'syslog'
>>> Invoking start script 'carp'
>>> Invoking start script 'cron'
Starting Cron: OK
>>> Invoking start script 'openvpn'
>>> Invoking start script 'sysctl'
Service `sysctl' has been restarted.
>>> Invoking start script 'beep'
>>> Error in start script '95-beep'
Root file system: /dev/ufs/OPNsense
Wed Aug  2 03:52:56 UTC 2023
```

[^tools]: https://github.com/opnsense/tools
[^forum]: https://forum.opnsense.org/index.php?topic=12186
[^ESXi]: https://flings.vmware.com/esxi-arm-edition
[^qemu_wiki]: https://wiki.freebsd.org/arm64/QEMU
[^document]: https://www.raspberrypi.org/documentation/installation/installing-images/
[^serial]: https://www.jeffgeerling.com/blog/2021/attaching-raspberry-pis-serial-console-uart-debugging
