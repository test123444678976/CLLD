#!/usr/bin/env bash
# Cria a imagem .img (MBR: p1 FAT32 /boot, p2 ext4 /) para gravar no cartao SD do RPi 4B.
set -euo pipefail
source "$(dirname "$0")/clld-env.sh"
[ "$EUID" -eq 0 ] || exec sudo -E "$0" "$@"

# Desmontar chroot se ainda estiver montado
for m in dev/pts dev proc sys run; do umount -l "$CLLD/$m" 2>/dev/null || true; done

truncate -s "${CLLD_IMG_MB}M" "$CLLD_IMG"
parted -s "$CLLD_IMG" mklabel msdos \
  mkpart primary fat32 1MiB "${CLLD_BOOT_MB}MiB" \
  mkpart primary ext4 "${CLLD_BOOT_MB}MiB" 100%
LOOP=$(losetup --find --show --partscan "$CLLD_IMG")
trap 'umount -R /mnt/clld-img 2>/dev/null || true; losetup -d "$LOOP" 2>/dev/null || true' EXIT

mkfs.vfat -F32 -n BOOT "${LOOP}p1"
mkfs.ext4 -F -L clldroot "${LOOP}p2"

mkdir -p /mnt/clld-img
mount "${LOOP}p2" /mnt/clld-img
mkdir -p /mnt/clld-img/boot
mount "${LOOP}p1" /mnt/clld-img/boot

rsync -aHAX --info=progress2 \
  --exclude=/sources --exclude=/build --exclude=/tools --exclude=/bootfiles \
  --exclude=/boot/'*' --exclude=/dev/'*' --exclude=/proc/'*' --exclude=/sys/'*' --exclude=/run/'*' \
  "$CLLD"/ /mnt/clld-img/
mkdir -p /mnt/clld-img/{dev,proc,sys,run,tmp}; chmod 1777 /mnt/clld-img/tmp
rm -f /mnt/clld-img/usr/bin/qemu-aarch64-static

cp -r "$CLLD_BOOTFILES"/. /mnt/clld-img/boot/
sync
umount -R /mnt/clld-img
losetup -d "$LOOP"; trap - EXIT

echo "Imagem pronta: $CLLD_IMG"
echo "Gravar:  sudo dd if=$CLLD_IMG of=/dev/sdX bs=4M conv=fsync status=progress"
