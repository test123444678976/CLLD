#!/usr/bin/env bash
# Adiciona dpkg + APT ao CLLD. Corre DENTRO do chroot (./02-chroot.sh), depois de compilar a pilha base.
# Fonte dos pacotes: repositorio Debian arm64 (por omissao "trixie"). Muda com: SUITE=... ./08-apt.sh
#
# Pre-requisitos ja compilados (BLFS): curl (ou wget), cmake, perl, pkg-config, gnupg (gpgv), gnutls,
#   zlib, bzip2, xz, lz4, zstd, xxhash, ncurses, eudev (libudev), make, gcc.
set -euo pipefail
SUITE=${SUITE:-trixie}
POOL=http://deb.debian.org/debian/pool/main
W=/sources/apt-build; mkdir -p "$W"; cd "$W"
J=${MAKEFLAGS:--j$(nproc)}

# devolve o nome do ficheiro mais recente em $POOL/$1/$2/ que case com o padrao $3
latest() { curl -fsS "$POOL/$1/$2/" | grep -oE "$3" | sort -uV | tail -1; }
fetch()  { curl -fsSLO "$POOL/$1/$2/$3"; }

echo "==> triehash (necessario para compilar o APT)"
T=$(latest t triehash 'triehash_[0-9.]+\.orig\.tar\.gz')
fetch t triehash "$T"; tar -xzf "$T"
install -m755 "$(find . -name triehash.pl -o -name triehash | head -1)" /usr/bin/triehash

echo "==> dpkg"
D=$(latest d dpkg 'dpkg_[0-9.]+\.tar\.xz')
fetch d dpkg "$D"; rm -rf dpkg-src && mkdir dpkg-src && tar -xf "$D" -C dpkg-src --strip-components=1
( cd dpkg-src
  ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
    --disable-nls --disable-dselect --disable-devel-docs --disable-unicode \
    --with-libz --with-liblzma --with-libzstd --with-libbz2
  make $J && make install )

echo "==> Estrutura do dpkg/apt"
mkdir -p /var/lib/dpkg/{info,updates,alternatives} /var/cache/apt/archives/partial \
         /var/lib/apt/lists/partial /etc/apt/{apt.conf.d,preferences.d,sources.list.d} \
         /etc/dpkg/dpkg.cfg.d /usr/share/keyrings
touch /var/lib/dpkg/status /var/lib/dpkg/available

echo "==> APT"
A=$(latest a apt 'apt_[0-9.]+\.tar\.xz')
fetch a apt "$A"; rm -rf apt-src && mkdir apt-src && tar -xf "$A" -C apt-src --strip-components=1
( cd apt-src
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib -DWITH_DOC=OFF -DWITH_TESTS=OFF -DUSE_NLS=OFF
  cmake --build build $J && cmake --install build )

echo "==> Utilizador _apt (APT descarta privilegios para descarregar)"
grep -q '^nogroup:' /etc/group  || echo 'nogroup:x:65534:' >> /etc/group
grep -q '^_apt:'    /etc/passwd || echo '_apt:x:42:65534::/nonexistent:/usr/sbin/nologin' >> /etc/passwd

echo "==> Pacotes 'virtuais': o que o CLLD ja fornece (LFS) e o dpkg nao conhece"
GLIBC=$(ldd --version | head -1 | grep -oE '[0-9]+\.[0-9]+$')
stub() { # nome [provides]
  { echo "Package: $1"; echo "Status: install ok installed"; echo "Priority: required"
    echo "Section: libs"; echo "Maintainer: CLLD <clld@localhost>"; echo "Architecture: arm64"
    echo "Version: 9:99.0-clld1"; [ -n "${2:-}" ] && echo "Provides: $2"
    echo "Description: fornecido pelo LFS (CLLD)"; echo; } >> /var/lib/dpkg/status
}
: > /var/lib/dpkg/status
for p in libc6 libc-bin libgcc-s1 libstdc++6 zlib1g libbz2-1.0 liblzma5 libzstd1 liblz4-1 \
         libxxhash0 libncurses6 libncursesw6 libtinfo6 bash dash coreutils util-linux \
         tar gzip bzip2 xz-utils sed grep gawk findutils diffutils perl-base base-files \
         debianutils libudev1 adduser; do stub "$p"; done
stub awk; stub mawk

echo "==> Repositorio e chaves"
K=$(latest d debian-archive-keyring 'debian-archive-keyring_[0-9.]+_all\.deb')
fetch d debian-archive-keyring "$K"; dpkg-deb -x "$K" /
cat > /etc/apt/sources.list <<EOF
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] http://deb.debian.org/debian $SUITE main
EOF

cat > /etc/apt/apt.conf.d/10clld <<'EOF'
APT::Architecture "arm64";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Acquire::Languages "none";
EOF

# Nunca deixar o APT substituir o que o CLLD controla (kernel, libc, init, firmware de arranque)
cat > /etc/apt/preferences.d/clld-hold <<'EOF'
Package: linux-image-* linux-headers-* linux-base raspi-firmware libc6 libc6-dev libc-bin locales base-files systemd systemd-* udev init sysvinit-* initscripts
Pin: release *
Pin-Priority: -1
EOF

# Bibliotecas de pacotes Debian usam multiarch
echo /usr/lib/aarch64-linux-gnu > /etc/ld.so.conf.d/multiarch.conf 2>/dev/null || \
  { mkdir -p /etc/ld.so.conf.d; echo /usr/lib/aarch64-linux-gnu > /etc/ld.so.conf.d/multiarch.conf; }
grep -q 'ld.so.conf.d' /etc/ld.so.conf 2>/dev/null || echo 'include /etc/ld.so.conf.d/*.conf' >> /etc/ld.so.conf
ldconfig

echo "Pronto. Testa (precisa de rede):  apt update && apt install nano"
