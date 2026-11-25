#!/usr/bin/env bash
# CLLD - Claude LFS Linux Distro (Raspberry Pi 4 Model B, aarch64)
# Usar com:  source clld-env.sh
export CLLD=${CLLD:-/mnt/clld}
export CLLD_TGT=aarch64-clld-linux-gnu
export CLLD_SRC=$CLLD/sources
export CLLD_BUILD=$CLLD/build
export PATH=$CLLD/tools/bin:/usr/local/bin:/usr/bin:/bin
export MAKEFLAGS="-j$(nproc)"
export LC_ALL=POSIX
umask 022

# Fontes do LFS (usa a lista oficial para as versoes ficarem consistentes com o livro).
# Confirma que a versao do livro corresponde a tua escolha (stable = sysvinit).
export LFS_BOOK_URL=https://www.linuxfromscratch.org/lfs/downloads/stable

# Kernel e firmware da Raspberry Pi Foundation
export RPI_KERNEL_BRANCH=rpi-6.6.y
export RPI_KERNEL_REPO=https://github.com/raspberrypi/linux
export RPI_FIRMWARE_REPO=https://github.com/raspberrypi/firmware

# Imagem final
export CLLD_IMG=${CLLD_IMG:-$PWD/clld-rpi4.img}
export CLLD_IMG_MB=${CLLD_IMG_MB:-6144}
export CLLD_BOOT_MB=256
export CLLD_BOOTFILES=$CLLD/bootfiles
