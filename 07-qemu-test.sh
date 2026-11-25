#!/usr/bin/env bash
# Imagem MINIMA do CLLD para testar no qemu (smoke test): kernel aarch64 + userland BusyBox (Alpine
# minirootfs) com a identidade CLLD, como initramfs. NAO e o LFS completo e nao tem interface grafica;
# serve para validar o arranque, o shell, o teclado (consola serie) e a memoria (zram).
# Requisitos no host: curl tar gzip cpio qemu-system-aarch64   (ex.: apt install qemu-system-arm cpio curl)
set -euo pipefail
cd "$(dirname "$0")"
W=${W:-$PWD/qemu-test}; mkdir -p "$W"; cd "$W"
BASE=https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64

echo "==> A descobrir versoes"
curl -fsS "$BASE/latest-releases.yaml" -o releases.yaml
MINI=$(grep -oE 'alpine-minirootfs-[0-9.]+-aarch64\.tar\.gz' releases.yaml | head -1)
NETB=$(grep -oE 'alpine-netboot-[0-9.]+-aarch64\.tar\.gz' releases.yaml | head -1)
[ -n "$MINI" ] && [ -n "$NETB" ] || { echo "Nao encontrei os ficheiros no indice"; exit 1; }

echo "==> Download: $MINI e $NETB"
curl -fsSLO "$BASE/$MINI"
curl -fsSLO "$BASE/$NETB"

echo "==> Kernel"
rm -rf netboot && mkdir netboot && tar -xzf "$NETB" -C netboot
K=$(ls netboot/boot/vmlinuz-* | head -1)
if gzip -t "$K" 2>/dev/null; then gunzip -c "$K" > Image; else cp "$K" Image; fi

echo "==> Rootfs CLLD"
rm -rf root && mkdir root && tar -xzf "$MINI" -C root
echo clld > root/etc/hostname
cat > root/etc/os-release <<'EOF'
NAME="CLLD"
PRETTY_NAME="CLLD - Claude LFS Linux Distro (qemu test)"
ID=clld
VERSION_ID="1.0"
EOF
cat > root/etc/motd <<'EOF'

  CLLD - Claude LFS Linux Distro (imagem de teste qemu)
  Teclado: escreve aqui.  Memoria: 'free -m'.  Sair do qemu: Ctrl-A depois X

EOF
cat > root/init <<'EOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mkdir -p /dev/pts /tmp && mount -t devpts devpts /dev/pts && mount -t tmpfs tmpfs /tmp
hostname clld
# swap zram (se o kernel tiver o modulo/suporte)
if [ -e /sys/block/zram0/disksize ] || modprobe zram 2>/dev/null; then
  MEM=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  echo $((MEM*1024/2)) > /sys/block/zram0/disksize && mkswap /dev/zram0 >/dev/null && swapon /dev/zram0
fi
cat /etc/motd
exec setsid cttyhack /bin/sh -l
EOF
chmod +x root/init

echo "==> initramfs"
( cd root && find . | cpio -o -H newc --quiet | gzip -9 ) > initramfs.cpio.gz

cat > run.sh <<'EOF'
#!/bin/sh
exec qemu-system-aarch64 -M virt -cpu cortex-a72 -m 2G -nographic \
  -kernel Image -initrd initramfs.cpio.gz \
  -append "console=ttyAMA0 rdinit=/init"
EOF
chmod +x run.sh
echo
echo "Pronto. Arranca com:  $W/run.sh   (sair: Ctrl-A, X)"
echo "Se o kernel nao arrancar, o ficheiro pode ser EFI-zboot: usa antes o Image do passo 03 (kernel RPi)."
