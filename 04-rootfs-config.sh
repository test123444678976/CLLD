#!/usr/bin/env bash
# Configuracao do sistema CLLD (sysvinit + LFS-Bootscripts): identidade, fstab, zram (memoria),
# autologin, arranque grafico automatico (Xorg + Openbox). Corre no HOST, depois do cap. 8 do LFS.
set -euo pipefail
source "$(dirname "$0")/clld-env.sh"
[ "$EUID" -eq 0 ] || exec sudo -E "$0" "$@"
R=$CLLD

echo clld > "$R/etc/hostname"
cat > "$R/etc/hosts" <<'EOF'
127.0.0.1 localhost
127.0.1.1 clld
::1       localhost
EOF

cat > "$R/etc/os-release" <<'EOF'
NAME="CLLD"
PRETTY_NAME="CLLD - Claude LFS Linux Distro"
ID=clld
VERSION_ID="1.0"
HOME_URL="https://www.linuxfromscratch.org/"
EOF
cp "$R/etc/os-release" "$R/usr/lib/os-release" 2>/dev/null || true
echo "CLLD 1.0 (LFS, aarch64, Raspberry Pi 4B)" > "$R/etc/clld-release"

cat > "$R/etc/fstab" <<'EOF'
# <dispositivo>    <ponto>  <tipo>  <opcoes>                 <dump> <fsck>
/dev/mmcblk0p2     /        ext4    defaults,noatime         1      1
/dev/mmcblk0p1     /boot    vfat    defaults,noatime         0      2
tmpfs              /tmp     tmpfs   defaults,nosuid,nodev    0      0
proc               /proc    proc    nosuid,noexec,nodev      0      0
sysfs              /sys     sysfs   nosuid,noexec,nodev      0      0
devpts             /dev/pts devpts  gid=5,mode=620           0      0
tmpfs              /run     tmpfs   defaults                 0      0
devtmpfs           /dev     devtmpfs mode=0755,nosuid        0      0
EOF

# --- Memoria: swap comprimido em RAM (zram), dimensionado a 50% da RAM ---
install -d "$R/etc/rc.d/init.d"
cat > "$R/etc/rc.d/init.d/zram" <<'EOF'
#!/bin/sh
# Begin /etc/rc.d/init.d/zram
. /lib/lsb/init-functions
case "$1" in
  start)
    log_info_msg "A ativar swap zram..."
    modprobe zram 2>/dev/null
    MEM_KB=$(awk '/MemTotal/{print $2}' /proc/meminfo)
    echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null
    echo $((MEM_KB * 1024 / 2)) > /sys/block/zram0/disksize
    mkswap /dev/zram0 >/dev/null && swapon -p 100 /dev/zram0
    evaluate_retval ;;
  stop)
    log_info_msg "A desativar swap zram..."
    swapoff /dev/zram0 2>/dev/null
    evaluate_retval ;;
  *) echo "Uso: $0 {start|stop}"; exit 1 ;;
esac
# End /etc/rc.d/init.d/zram
EOF
chmod 755 "$R/etc/rc.d/init.d/zram"
mkdir -p "$R/etc/rc.d/rc3.d" "$R/etc/rc.d/rc0.d" "$R/etc/rc.d/rc6.d"
ln -sf ../init.d/zram "$R/etc/rc.d/rc3.d/S06zram"
ln -sf ../init.d/zram "$R/etc/rc.d/rc0.d/K94zram"
ln -sf ../init.d/zram "$R/etc/rc.d/rc6.d/K94zram"

cat > "$R/etc/sysctl.d/clld.conf" 2>/dev/null <<'EOF' || { mkdir -p "$R/etc/sysctl.d"; echo "vm.swappiness=100" > "$R/etc/sysctl.d/clld.conf"; }
vm.swappiness=100
vm.vfs_cache_pressure=50
EOF

# --- Utilizador, grupos e autologin ---
grep -q '^input:' "$R/etc/group" || echo 'input:x:24:' >> "$R/etc/group"
grep -q '^video:' "$R/etc/group" || echo 'video:x:12:' >> "$R/etc/group"
grep -q '^clld:'  "$R/etc/group" || echo 'clld:x:1000:' >> "$R/etc/group"
sed -i -E 's/^(video:x:12:).*/\1clld/; s/^(input:x:24:).*/\1clld/' "$R/etc/group"
grep -q '^clld:' "$R/etc/passwd" || echo 'clld:x:1000:1000:CLLD User:/home/clld:/bin/bash' >> "$R/etc/passwd"
HASH=$(openssl passwd -6 clld)
grep -q '^clld:' "$R/etc/shadow" 2>/dev/null || echo "clld:$HASH:19000:0:99999:7:::" >> "$R/etc/shadow"
sed -i "s|^root:[^:]*:|root:$HASH:|" "$R/etc/shadow" 2>/dev/null || true
chmod 600 "$R/etc/shadow"
mkdir -p "$R/home/clld"

# tty1: login automatico do utilizador clld
sed -i 's|^1:2345:respawn:.*|1:2345:respawn:/sbin/agetty --autologin clld --noclear tty1 linux|' "$R/etc/inittab" || true

cat > "$R/home/clld/.bash_profile" <<'EOF'
# Arranca o ambiente grafico automaticamente no tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx -- -keeptty >~/.xorg.log 2>&1
fi
EOF
cat > "$R/home/clld/.xinitrc" <<'EOF'
xsetroot -solid '#1e2a3a'
tint2 &
xterm -geometry 100x30+40+40 &
exec openbox-session
EOF
chmod 755 "$R/home/clld/.xinitrc"

# Xorg: driver modesetting (KMS) + libinput para teclado e rato
mkdir -p "$R/etc/X11/xorg.conf.d"
cat > "$R/etc/X11/xorg.conf.d/10-clld.conf" <<'EOF'
Section "OutputClass"
  Identifier "vc4"
  MatchDriver "vc4"
  Driver "modesetting"
  Option "PrimaryGPU" "true"
EndSection

Section "InputClass"
  Identifier "libinput keyboard"
  MatchIsKeyboard "on"
  Driver "libinput"
  Option "XkbLayout" "pt"
EndSection

Section "InputClass"
  Identifier "libinput pointer"
  MatchIsPointer "on"
  Driver "libinput"
EndSection
EOF
cat > "$R/etc/X11/Xwrapper.config" <<'EOF'
needs_root_rights = yes
allowed_users = anybody
EOF

# Teclado da consola em portugues
echo 'KEYMAP="pt-latin1"' > "$R/etc/sysconfig/console" 2>/dev/null || true

chown -R 1000:1000 "$R/home/clld"
echo "Configuracao do CLLD escrita em $R  (utilizador clld / palavra-passe clld -- MUDA-A!)"
