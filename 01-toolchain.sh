#!/usr/bin/env bash
# Capitulo 5 do LFS adaptado a aarch64: cross-toolchain x86_64 -> RPi 4.
# Corre num host Linux (Debian/Ubuntu/Fedora) como utilizador normal com sudo.
set -euo pipefail
source "$(dirname "$0")/clld-env.sh"

echo "==> Verificar ferramentas do host"
for t in bash bison gawk gcc g++ make patch perl python3 sed tar xz wget git bc flex \
         rsync parted mkfs.ext4 mkfs.vfat qemu-aarch64-static openssl; do
  command -v "$t" >/dev/null || { echo "FALTA: $t"; MISSING=1; }
done
[ -z "${MISSING:-}" ] || { echo "Instala o que falta (ex.: apt install build-essential bison gawk texinfo qemu-user-static binfmt-support dosfstools parted rsync git bc flex libssl-dev)"; exit 1; }

echo "==> Diretorias"
sudo mkdir -p "$CLLD"/{sources,build,tools,etc,var,usr/{bin,lib,sbin},boot,bootfiles}
sudo chown -R "$USER" "$CLLD"
for i in bin lib sbin; do ln -sfn usr/$i "$CLLD/$i"; done

echo "==> Fontes"
cd "$CLLD_SRC"
wget -nc "$LFS_BOOK_URL/wget-list-sysv" -O wget-list
wget -nc "$LFS_BOOK_URL/md5sums" -O md5sums
wget -nc --input-file=wget-list --continue
md5sum -c md5sums

unpack() { rm -rf "$CLLD_BUILD/$1"; mkdir -p "$CLLD_BUILD/$1"; tar -xf "$CLLD_SRC"/$2 -C "$CLLD_BUILD/$1" --strip-components=1; }

echo "==> Binutils (passo 1)"
unpack binutils 'binutils-[0-9]*.tar.*'
mkdir "$CLLD_BUILD/binutils/build" && cd "$CLLD_BUILD/binutils/build"
../configure --prefix="$CLLD/tools" --with-sysroot="$CLLD" --target="$CLLD_TGT" \
  --disable-nls --enable-gprofng=no --disable-werror --enable-new-dtags \
  --enable-default-hash-style=gnu
make && make install

echo "==> GCC (passo 1)"
unpack gcc 'gcc-[0-9]*.tar.*'
cd "$CLLD_BUILD/gcc"
for p in mpfr gmp mpc; do
  mkdir $p && tar -xf "$CLLD_SRC"/$p-*.tar.* -C $p --strip-components=1
done
mkdir build && cd build
GLIBC_VER=$(ls "$CLLD_SRC"/glibc-*.tar.* | sed -E 's/.*glibc-([0-9.]+)\.tar.*/\1/' | head -1)
../configure --target="$CLLD_TGT" --prefix="$CLLD/tools" --with-glibc-version="$GLIBC_VER" \
  --with-sysroot="$CLLD" --with-newlib --without-headers --enable-default-pie \
  --enable-default-ssp --disable-nls --disable-shared --disable-multilib \
  --disable-threads --disable-libatomic --disable-libgomp --disable-libquadmath \
  --disable-libssp --disable-libvtv --disable-libstdcxx --enable-languages=c,c++
make && make install
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  "$(dirname "$("$CLLD_TGT-gcc" -print-libgcc-file-name)")/include/limits.h"

echo "==> Cabecalhos do kernel (arm64)"
unpack linux 'linux-[0-9]*.tar.*'
cd "$CLLD_BUILD/linux"
make mrproper
make ARCH=arm64 headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include "$CLLD/usr"

echo "==> Glibc"
unpack glibc 'glibc-[0-9]*.tar.*'
cd "$CLLD_BUILD/glibc"
patch -Np1 -i "$CLLD_SRC"/glibc-*-fhs-1.patch
mkdir build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr --host="$CLLD_TGT" --build="$(../scripts/config.guess)" \
  --enable-kernel=5.4 --with-headers="$CLLD/usr/include" --disable-nscd \
  libc_cv_slibdir=/usr/lib
make && make DESTDIR="$CLLD" install
sed '/RTLDLIST=/s@/usr@@g' -i "$CLLD/usr/bin/ldd"

echo "==> Teste da toolchain"
echo 'int main(){}' | "$CLLD_TGT-gcc" -xc -
readelf -l a.out | grep ld-linux-aarch64 && echo "OK: toolchain funcional" && rm -f a.out

echo "==> Libstdc++"
cd "$CLLD_BUILD/gcc" && rm -rf build-lstd && mkdir build-lstd && cd build-lstd
../libstdc++-v3/configure --host="$CLLD_TGT" --build="$(../config.guess)" --prefix=/usr \
  --disable-multilib --disable-nls --disable-libstdcxx-pch \
  --with-gxx-include-dir=/tools/$CLLD_TGT/include/c++/$(sed -n 's/.*"\(.*\)".*/\1/p' ../gcc/BASE-VER)
make && make DESTDIR="$CLLD" install
rm -v "$CLLD"/usr/lib/lib{stdc++{,exp,fs},supc++}.la

cat <<EOF

Toolchain pronta. Proximo passo: capitulos 6, 7 e 8 do livro LFS (temp tools, chroot, sistema final),
substituindo \$LFS -> \$CLLD e \$LFS_TGT -> \$CLLD_TGT. No capitulo 7 usa ./02-chroot.sh
EOF
