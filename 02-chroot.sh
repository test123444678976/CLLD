#!/usr/bin/env bash
# Entra no chroot aarch64 do CLLD usando qemu-user (necessario para os caps. 7-8 e BLFS).
set -euo pipefail
source "$(dirname "$0")/clld-env.sh"
[ "$EUID" -eq 0 ] || exec sudo -E "$0" "$@"

# binfmt para aarch64 (qemu-user-static + binfmt-support instalados no host)
update-binfmts --enable qemu-aarch64 2>/dev/null || true
install -D /usr/bin/qemu-aarch64-static "$CLLD/usr/bin/qemu-aarch64-static"

mkdir -p "$CLLD"/{dev,proc,sys,run}
mountpoint -q "$CLLD/dev"     || mount --bind /dev "$CLLD/dev"
mountpoint -q "$CLLD/dev/pts" || mount -t devpts devpts -o gid=5,mode=0620 "$CLLD/dev/pts"
mountpoint -q "$CLLD/proc"    || mount -t proc proc "$CLLD/proc"
mountpoint -q "$CLLD/sys"     || mount -t sysfs sysfs "$CLLD/sys"
mountpoint -q "$CLLD/run"     || mount -t tmpfs tmpfs "$CLLD/run"

exec chroot "$CLLD" /usr/bin/env -i HOME=/root TERM="$TERM" \
  PS1='(clld chroot) \u:\w\$ ' MAKEFLAGS="$MAKEFLAGS" \
  PATH=/usr/bin:/usr/sbin /bin/bash --login
