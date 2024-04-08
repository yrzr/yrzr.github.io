---
title: "Notes: Build U-Boot for Rock5b"
date: 2024-03-29T15:37:24+08:00
tags: [note, rock5b, rk3588, rockchip, aarch64, U-Boot, extlinux, efi]
draft: true
---

This is a note on building U-Boot for Radxa Rock5b[^rock5b] and makeing it boot. There are two versions of U-Boot for Rock5b; one is from Radxa (legacy version), and the other is from Collabora (mainline version, still under development but is pretty complete). Both versions can load bootloaders from SPI flash, NVME SSD, SD card, eMMC, and USB drive. However, only the mainline version can boot EFI applications like `grub`.

## 1 `rkdeveloptool` (maskrom tool)

`rkdeveloptool` is a tool by Rockchip that provides a simple way to read/write rockusb devices.

Rock5b has a maskrom button, which could load the device into maskrom mode and flash the SPI with `rkdeveloptool` from another device connected with a USB cable[^maskrom].

### 1.1 Compile

```bash
git clone --depth=1 https://github.com/radxa/rkdeveloptool.git
cd rkdeveloptool
aclocal
autoreconf -i
autoheader
automake --add-missing
./configure
make -j4
```

### 1.2 Usage examples

```bash
sudo ./rkdeveloptool db RKXXLoader.bin    //download usbplug to device
sudo ./rkdeveloptool wl 0x8000 kernel.img //0x8000 is the offsets in blocks.
sudo ./rkdeveloptool rd                   //reset device
```

## 2 Radxa U-Boot (legacy)

The `bootefi` command can not work on this version[^bootefi failed]. Therefore, you can not use `grub` with this version.

### 2.1 Compile

The official document from Radxa[^radxa uboot] is a little outdated. You need to use `develop-v2024.03` branch of `rkbin` to compile the U-Boot successfully. And as I tested, you need a GCC version lower than 13 to compile it.

```bash
mkdir ./radxa && cd ./radxa
git clone --depth=1 -b stable-5.10-rock5 https://github.com/radxa/u-boot.git
git clone --depth=1 -b develop-v2024.03 https://github.com/radxa/rkbin.git
git clone --depth=1 -b debian https://github.com/radxa/build.git
./build/mk-uboot.sh rk3588-rock-5b
```

There is a trick to speed up the build process. You can add `-j$(nproc)` to the `make` command in `./build/mk-uboot.sh` to use all the CPU cores of your machine.

```diff
diff --git a/mk-uboot.sh b/mk-uboot.sh
index 30aeeb7b6..b0aadc621 100755
--- a/mk-uboot.sh
+++ b/mk-uboot.sh
@@ -365,7 +365,7 @@ elif [ "${CHIP}" == "rk3568" ]; then
        generate_spi_image
 elif [ "${CHIP}" == "rk3588s" ] || [ "${CHIP}" == "rk3588" ]; then
        make ${UBOOT_DEFCONFIG}
-       make BL31=../rkbin/bin/rk35/rk3588_bl31_v1.45.elf spl/u-boot-spl.bin u-boot.dtb u-boot.itb
+       make BL31=../rkbin/bin/rk35/rk3588_bl31_v1.45.elf spl/u-boot-spl.bin u-boot.dtb u-boot.itb -j$(nproc)
        ./tools/mkimage -n rk3588 -T rksd -d ../rkbin/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin:spl/u-boot-spl.bin idbloader.img
        cp u-boot.itb ${OUT}/u-boot/
        cp idbloader.img ${OUT}/u-boot/
```

Output:

```
./out/u-boot
├── idbloader.img
├── rk3588_spl_loader_v1.08.111.bin
├── spi
│   └── spi_image.img
└── u-boot.itb
```

### 2.2 Flash

#### 2.2.1 Use `dd` to MTD (SPI)

**This will erase all the data on the SPI, and should only be excused on your target Rock5b.**

Write the `spi_image.img` [^flash spi], which takes approximately 180 seconds.

```bash
sudo dd status=progress if=./out/u-boot/spi/spi_image.img of=/dev/mtdblock0 bs=512
```

Or, in a faster way, just flash the SPL and U-Boot image.

```bash
sudo dd status=progress if=./out/u-boot/idbloader.img of=/dev/mtdblock0 bs=512 seek=64
sudo dd status=progress if=./out/u-boot/u-boot.itb of=/dev/mtdblock0 bs=512 seek=16384
```

#### 2.2.2 Use `dd` to MMC devices

**This may cause data loss on the MMC devices if you do not understand what it is doing. So, do back up your data first.** Change `/dev/mmcblk0` to your target device (SD card or eMMC flash) before executing the command.

```bash
sudo dd status=progress if=./out/u-boot/idbloader.img of=/dev/mmcblk0 bs=512 seek=64
sudo dd status=progress if=./out/u-boot/u-boot.itb of=/dev/mmcblk0 bs=512 seek=16384
```

#### 2.2.3 Use `rkdeveloptool` by maskrom

If you can not boot the device, you can use `rkdeveloptool` to flash the SPI through maskrom mode. The steps[^maskrom] are as follows:

- Power the board
- **Remove SD card and eMMC** (or the `spi_image.img` will be flashed to the SD card or eMMC, and corrupt your data)
- Press maskrom button
- Connect the board to another device (master device) with a USB cable through the type-c port on rock5b
- Then excuse the following commands on the master device

```bash
# list devices
$ sudo ./rkdeveloptool ld
DevNo=1 Vid=0x2207,Pid=0x350b,LocationID=106    Maskrom
# clear spi, not necessary every time, only needed a failed flash
$ sudo ./rkdeveloptool ef
# download bootloader to rock5b
$ sudo ./rkdeveloptool db ../radxa/out/u-boot/rk3588_spl_loader_v1.08.111.bin
Downloading bootloader succeeded.
# download image to SPI
$ sudo ./rkdeveloptool wl 0 ../radxa/out/u-boot/spi/spi_image.img
Write LBA from file (100%)
# reset device (reboot to normal mode)
$ rkdeveloptool rd
```

### 2.3 U-Boot load log (legacy)

```log
DDR Version V1.08 20220617
LPDDR4X, 2112MHz
channel[0] BW=16 Col=10 Bk=8 CS0 Row=17 CS1 Row=17 CS=2 Die BW=8 Size=4096MB
channel[1] BW=16 Col=10 Bk=8 CS0 Row=17 CS1 Row=17 CS=2 Die BW=8 Size=4096MB
channel[2] BW=16 Col=10 Bk=8 CS0 Row=17 CS1 Row=17 CS=2 Die BW=8 Size=4096MB
channel[3] BW=16 Col=10 Bk=8 CS0 Row=17 CS1 Row=17 CS=2 Die BW=8 Size=4096MB
Manufacturer ID:0x6
CH0 RX Vref:29.7%, TX Vref:24.8%,24.8%
CH1 RX Vref:29.7%, TX Vref:24.8%,24.8%
CH2 RX Vref:28.7%, TX Vref:22.8%,23.8%
CH3 RX Vref:28.7%, TX Vref:24.8%,24.8%
change to F1: 528MHz
change to F2: 1068MHz
change to F3: 1560MHz
change to F0: 2112MHz
out
U-Boot SPL board init
U-Boot SPL 2017.09-gbf47e8171f4-220414-dirty #stephen (Jun 07 2023 - 17:56:02)
Trying to boot from MMC2
MMC: no card present
mmc_init: -123, time 0
spl: mmc init failed with error: -123
Trying to boot from MMC1
Card did not respond to voltage select!
mmc_init: -95, time 14
spl: mmc init failed with error: -95
Trying to boot from MTD2
Trying fit image at 0x4000 sector
## Verified-boot: 0
## Checking atf-1 0x00040000 ... sha256(bb1bbbc832...) + OK
## Checking uboot 0x00200000 ... sha256(59a5130fc0...) + OK
## Checking fdt 0x0031b2c0 ... sha256(e05417ddb3...) + OK
## Checking atf-2 0x000f0000 ... sha256(30812190d0...) + OK
## Checking atf-3 0xff100000 ... sha256(cb7bdbec2b...) + OK
Jumping to U-Boot(0x00200000) via ARM Trusted Firmware(0x00040000)
Total: 500.709 ms

INFO:    Preloader serial: 2
NOTICE:  BL31: v2.3():v2.3-499-ge63a16361:derrick.huang
NOTICE:  BL31: Built : 10:58:38, Jan 10 2023
INFO:    spec: 0x1
INFO:    ext 32k is not valid
INFO:    ddr: stride-en 4CH
INFO:    GICv3 without legacy support detected.
INFO:    ARM GICv3 driver initialized in EL3
INFO:    valid_cpu_msk=0xff bcore0_rst = 0x0, bcore1_rst = 0x0
INFO:    system boots from cpu-hwid-0
INFO:    idle_st=0x21fff, pd_st=0x11fff9, repair_st=0xfff70001
INFO:    dfs DDR fsp_params[0].freq_mhz= 2112MHz
INFO:    dfs DDR fsp_params[1].freq_mhz= 528MHz
INFO:    dfs DDR fsp_params[2].freq_mhz= 1068MHz
INFO:    dfs DDR fsp_params[3].freq_mhz= 1560MHz
INFO:    BL31: Initialising Exception Handling Framework
INFO:    BL31: Initializing runtime services
WARNING: No OPTEE provided by BL2 boot loader, Booting device without OPTEE initialization. SMC`s destined for OPTEE will return SMCK
ERROR:   Error initializing runtime service opteed_fast
INFO:    BL31: Preparing for EL3 exit to normal world
INFO:    Entry point address = 0x200000
INFO:    SPSR = 0x3c9


U-Boot 2017.09-gbf47e8171f4-220414-dirty #stephen (Jun 07 2023 - 17:56:02 +0800)

Model: Radxa ROCK 5B
PreSerial: 2, raw, 0xfeb50000
DRAM:  15.7 GiB
Sysmem: init
Relocation Offset: eda42000
Relocation fdt: eb9f9f98 - eb9fecd8
CR: M/C/I
Using default environment

SF: Detected sfc_nor with page size 256 Bytes, erase size 4 KiB, total 16 MiB
Bootdev(atags): mtd 2
PartType: EFI
DM: v2
No misc partition
boot mode: None
FIT: No boot partition
No resource partition
No resource partition
Failed to load DTB, ret=-19
No find valid DTB, ret=-22
Failed to get kernel dtb, ret=-22
Model: Radxa ROCK 5B
CLK: (sync kernel. arm: enter 1008000 KHz, init 1008000 KHz, kernel 0N/A)
  b0pll 24000 KHz
  b1pll 24000 KHz
  lpll 24000 KHz
  v0pll 24000 KHz
  aupll 24000 KHz
  cpll 1500000 KHz
  gpll 1188000 KHz
  npll 24000 KHz
  ppll 1100000 KHz
  aclk_center_root 702000 KHz
  pclk_center_root 100000 KHz
  hclk_center_root 396000 KHz
  aclk_center_low_root 500000 KHz
  aclk_top_root 750000 KHz
  pclk_top_root 100000 KHz
  aclk_low_top_root 396000 KHz
Net:   No ethernet found.
Hit key to stop autoboot('CTRL+C'):  0
pcie@fe150000: PCIe Linking... LTSSM is 0x1
pcie@fe150000: PCIe Linking... LTSSM is 0x210022
pcie@fe150000: PCIe Linking... LTSSM is 0x210023
pcie@fe150000: PCIe Link up, LTSSM is 0x230011
pcie@fe150000: PCIE-0: Link up (Gen3-x4, Bus0)
pcie@fe150000: invalid flags type!

Device 0: Vendor: 0xc0a9 Rev: P7CR403  Prod: 22323A6C27E2
            Type: Hard Disk
            Capacity: 476940.0 MB = 465.7 GB (976773168 x 512)
... is now current device
Scanning nvme 0:1...
Found /extlinux/extlinux.conf
Retrieving file: /extlinux/extlinux.conf
reading /extlinux/extlinux.conf
1844 bytes read in 4 ms (450.2 KiB/s)
```

## 3 Collabora U-Boot (mainline)

The `bootefi` command works and can load `grub` successfully on this version. The official document is here[^collabora uboot].

### 3.1 Compile

```bash
mkdir ./collabora && cd ./collabora
git clone --depth=1 https://gitlab.collabora.com/hardware-enablement/rockchip-3588/trusted-firmware-a.git
git clone --depth=1 https://gitlab.collabora.com/hardware-enablement/rockchip-3588/rkbin.git
git clone --depth=1 -b 2024.01-rk3588 https://gitlab.collabora.com/hardware-enablement/rockchip-3588/u-boot.git

# build bl31
cd trusted-firmware-a
make PLAT=rk3588 bl31

# build maskrom bootloader, e.g. rk3588_spl_loader_v1.08.111.bin
cd ../rkbin/
./tools/boot_merger RKBOOT/RK3588MINIALL.ini

# build U-Boot
cd ../u-boot
make rock5b-rk3588_defconfig
export ROCKCHIP_TPL=../rkbin/bin/rk35/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.08.bin
export BL31=../trusted-firmware-a/build/rk3588/release/bl31/bl31.elf
make -j4

# copy binary files
mkdir out
cp -lv {idbloader.img,u-boot.itb,u-boot-rockchip.bin,u-boot-rockchip-spi.bin,../rkbin/rk3588_spl_loader_v1.08.111.bin} out/
```

Output:

```
out/
├── idbloader.img
├── rk3588_spl_loader_v1.08.111.bin
├── u-boot.itb
├── u-boot-rockchip.bin
└── u-boot-rockchip-spi.bin
```

### 3.2 Flash

#### 3.2.1 Use `dd` to MTD (SPI)

**This will erase all the data on the SPI and should only be excused on your target Rock5b.**

Write the `u-boot-rockchip-spi.bin`, which takes approximately 180 seconds.

```bash
dd status=progress if=./out/u-boot-rockchip-spi.bin of=/dev/mtdblock0 bs=512
```

Or a faster way, just flash the bootloader and U-Boot image.

```bash
dd status=progress if=./out/idbloader.img of=/dev/mtdblock0 bs=512 seek=64
dd status=progress if=./out/u-boot.itb of=/dev/mtdblock0 bs=512 seek=16384
```

#### 3.2.2 Use `dd` to MMC devices

**This may cause data loss on the MMC devices if you do not understand what it is doing. So, do back up your data first.** Change `/dev/mmcblk0` to your target device (SD card or eMMC flash) before executing the command.

```bash
dd status=progress if=./out/idbloader.img of=/dev/mmcblk0 bs=512 seek=64
dd status=progress if=./out/u-boot.itb of=/dev/mmcblk0 bs=512 seek=16384
```

or

```bash
dd status=progress if=./out/u-boot-rockchip.bin of=/dev/mmcblk0 seek=64
```

#### 3.2.3 Use `rkdeveloptool` by maskrom

If you can not boot the device, you can use `rkdeveloptool` to flash the SPI through maskrom mode. The steps are as follows:

- Power the board
- **Remove the SD card and eMMC** (or the `spi_image.img` will be flashed to the SD card or eMMC and corrupt your data)
- Press maskrom button
- Connect the board to another device (master device) with a USB cable through the type-c port on rock5b
- Then excuse the following commands on the master device

```bash
# list devices
$ sudo ./rkdeveloptool ld
DevNo=1 Vid=0x2207,Pid=0x350b,LocationID=106    Maskrom
# clear spi, not necessary every time, only needed a failed flash
$ sudo ./rkdeveloptool ef
# download bootloader to rock5b
$ sudo ./rkdeveloptool db ./out/rk3588_spl_loader_v1.08.111.bin
Downloading bootloader succeeded.
# download image to SPI
$ sudo ./rkdeveloptool wl 0 ./out/u-boot-rockchip-spi.bin
Write LBA from file (100%)
# reset device (reboot to normal mode)
$ rkdeveloptool rd
```

### 3.3 U-Boot load log (mainline)

```log
DDR Version V1.08 20220617
LPDDR4X, 2112MHz
channel[0] BW=16 Col=10 Bk=8 CS0 Row=17 CS1 Row=17 CS=2 Die BW=8 Size=4096MB
channel[1] BW=16 Col=10 Bk=8 CS0 Row=17 CS1 Row=17 CS=2 Die BW=8 Size=4096MB
channel[2] BW=16 Col=10 Bk=8 CS0 Row=17 CS1 Row=17 CS=2 Die BW=8 Size=4096MB
channel[3] BW=16 Col=10 Bk=8 CS0 Row=17 CS1 Row=17 CS=2 Die BW=8 Size=4096MB
Manufacturer ID:0x6
CH0 RX Vref:28.7%, TX Vref:24.8%,24.8%
CH1 RX Vref:28.7%, TX Vref:24.8%,23.8%
CH2 RX Vref:28.7%, TX Vref:22.8%,23.8%
CH3 RX Vref:28.7%, TX Vref:24.8%,24.8%
change to F1: 528MHz
change to F2: 1068MHz
change to F3: 1560MHz
change to F0: 2112MHz
out

U-Boot SPL 2024.01-g5557bfdc (Mar 29 2024 - 23:12:45 +0800)
Trying to boot from SPI
## Checking hash(es) for config config-1 ... OK
## Checking hash(es) for Image atf-1 ... sha256+ OK
## Checking hash(es) for Image U-Boot ... sha256+ OK
## Checking hash(es) for Image fdt-1 ... sha256+ OK
## Checking hash(es) for Image atf-2 ... sha256+ OK
NOTICE:  BL31: v2.10.0  (release):002d8e8
NOTICE:  BL31: Built : 21:40:23, Mar 29 2024


U-Boot 2024.01-g5557bfdc (Mar 29 2024 - 23:12:45 +0800)

Model: Radxa ROCK 5 Model B
DRAM:  16 GiB (effective 15.7 GiB)
Core:  352 devices, 30 uclasses, devicetree: separate
MMC:   mmc@fe2c0000: 1, mmc@fe2d0000: 2, mmc@fe2e0000: 0
Loading Environment from nowhere... OK
In:    serial@feb50000
Out:   serial@feb50000
Err:   serial@feb50000
Model: Radxa ROCK 5 Model B
Net:   No ethernet found.
Hit any key to stop autoboot:  0
Card did not respond to voltage select! : -110
Card did not respond to voltage select! : -110
pcie_dw_rockchip pcie@fe170000: PCIe-4 Link Fail
** Booting bootflow 'nvme#0.blk#1.bootdev.part_1' with extlinux
```

## 4 Partition layout

If you are using the U-Boot and your filesystems on the same device, you would not want to destroy the U-Boot when partitioning the disk. The offsets in the partition layout should look like this (assuming the block size is 512):

|               Start |     End |              Size | Content                 |
| ------------------: | ------: | ----------------: | ----------------------- |
|                   0 |     63s |      64s (32 kiB) | GPT Table               |
|        64s (32 kiB) |  16383s |            16320s | SPL+TPL (idbloader.img) |
|     16384s  (8 MiB) |  32767s |    16384s (8 MiB) | U-Boot (u-boot.itb)     |
| **32768s** (16 MiB) | 557055s | 524289s (256 MiB) | Bootfs                  |
|   557056s (272 MiB) |       - |                 - | Rootfs                  |

## 5 Example: extlinux.conf

Here is an example of my `/boot/extlinux/extlinux.conf`.

```
default l0
menu title U-Boot menu
prompt 1
timeout 30

label l0
    menu label 6.8.2-edge-rockchip-rk3588
    linux /vmlinuz-6.8.2-edge-rockchip-rk3588
    initrd /initrd.img-6.8.2-edge-rockchip-rk3588
    fdtdir /dtbs/6.8.2-edge-rockchip-rk3588/
    append root=UUID=2c8037be-439b-4432-8453-deb802a5b964 rootfstype=xfs quiet splash rw earlycon console=tty1 console=ttyS2,1500000n8 coherent_pool=2M irqchip.gicv3_pseudo_nmi=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 panic=10 net.ifnames=0

label l1
    menu label 6.8.2-edge-rockchip-rk3588 Recovery
    linux /vmlinuz-6.8.2-edge-rockchip-rk3588
    initrd /initrd.img-6.8.2-edge-rockchip-rk3588
    fdtdir /dtbs/6.8.2-edge-rockchip-rk3588/
    append root=UUID=2c8037be-439b-4432-8453-deb802a5b964 rootfstype=xfs quiet splash rw single earlycon console=tty1 console=ttyS2,1500000n8 coherent_pool=2M irqchip.gicv3_pseudo_nmi=0 panic=10 net.ifnames=0
```

[^rock5b]: https://radxa.com/products/rock5/5b/
[^maskrom]: https://wiki.radxa.com/Rock5/install/spi#Advanced_.28external.29_method
[^radxa uboot]: https://wiki.radxa.com/Rock5/install/spi#Advanced_.28external.29_methodhttps://wiki.radxa.com/Rock5/guide/build-u-boot-on-5b
[^bootefi failed]: https://github.com/radxa/u-boot/issues/12
[^flash spi]: https://wiki.radxa.com/Rock5/install/spi#Simple_method
[^collabora uboot]: https://gitlab.collabora.com/hardware-enablement/rockchip-3588/notes-for-rockchip-3588/-/blob/main/upstream_uboot.md
