#!/usr/bin/env bash
# Kernel Raspberry Pi (arm64) + firmware de arranque do RPi 4B.
# Cross-compila com a toolchain do passo 01 (ou com aarch64-linux-gnu-gcc do host).
set -euo pipefail
source "$(dirname "$0")/clld-env.sh"

CROSS=${CROSS:-$CLLD_TGT-}
command -v "${CROSS}gcc" >/dev/null || CROSS=aarch64-linux-gnu-

cd "$CLLD_SRC"
[ -d rpi-linux ] || git clone --depth=1 -b "$RPI_KERNEL_BRANCH" "$RPI_KERNEL_REPO" rpi-linux
[ -d rpi-firmware ] || git clone --depth=1 "$RPI_FIRMWARE_REPO" rpi-firmware

cd rpi-linux
make ARCH=arm64 CROSS_COMPILE="$CROSS" bcm2711_defconfig

# Rato/teclado (USB HID via controlador VL805/xHCI do Pi 4), video (VC4/V3D), memoria (zram)
scripts/config \
  -e USB -e USB_XHCI_HCD -e USB_XHCI_PCI -e PCIE_BRCMSTB \
  -e HID -e HID_GENERIC -e USB_HID -e HIDRAW -e HID_LOGITECH -e HID_APPLE \
  -e INPUT -e INPUT_EVDEV -e INPUT_MOUSEDEV -e INPUT_KEYBOARD -e INPUT_MOUSE \
  -e DRM -e DRM_VC4 -e DRM_V3D -e DRM_FBDEV_EMULATION -e FRAMEBUFFER_CONSOLE -e VT \
  -e DEVTMPFS -e DEVTMPFS_MOUNT -e TMPFS -e TMPFS_POSIX_ACL \
  -e SWAP -e ZRAM -e ZSMALLOC -e CRYPTO_LZO -e CRYPTO_LZ4 -e ZSWAP \
  -e EXT4_FS -e VFAT_FS -e FAT_FS -e NLS_CODEPAGE_437 -e NLS_ISO8859_1 \
  -e INOTIFY_USER -e SIGNALFD -e TIMERFD -e EPOLL -e UNIX -e NET -e INET \
  --set-str LOCALVERSION "-clld"
make ARCH=arm64 CROSS_COMPILE="$CROSS" olddefconfig
make ARCH=arm64 CROSS_COMPILE="$CROSS" Image modules dtbs
make ARCH=arm64 CROSS_COMPILE="$CROSS" INSTALL_MOD_PATH="$CLLD" INSTALL_MOD_STRIP=1 modules_install

# Ficheiros da particao de arranque (FAT)
B=$CLLD_BOOTFILES
mkdir -p "$B/overlays"
cp arch/arm64/boot/Image "$B/kernel8.img"
cp arch/arm64/boot/dts/broadcom/bcm2711-rpi-4-b.dtb "$B/"
cp arch/arm64/boot/dts/overlays/*.dtb* "$B/overlays/"
cp arch/arm64/boot/dts/overlays/README "$B/overlays/" 2>/dev/null || true
cd "$CLLD_SRC/rpi-firmware/boot"
cp start4.elf start4x.elf start4cd.elf start4db.elf fixup4.dat fixup4x.dat fixup4cd.dat fixup4db.dat "$B/"

cat > "$B/config.txt" <<'EOF'
# CLLD - config do RPi 4B
arm_64bit=1
kernel=kernel8.img
enable_uart=1
disable_overscan=1
hdmi_force_hotplug=1
dtoverlay=vc4-kms-v3d
max_framebuffers=2
gpu_mem=64
EOF

cat > "$B/cmdline.txt" <<'EOF'
console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait fsck.repair=yes quiet loglevel=3
EOF

echo "Kernel + firmware prontos em $B  (modulos em $CLLD/lib/modules)"
