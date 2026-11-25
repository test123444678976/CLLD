#!/usr/bin/env bash
# LXQt para o CLLD. Corre DENTRO do chroot (./02-chroot.sh), depois de compilar a pilha base (05-gui-stack.md).
#
# Pre-requisitos ja compilados (BLFS): Qt6 (qtbase, qtsvg, qttools), cmake, meson/ninja, pkg-config,
#   glib2, dbus, xorg + xcb-util-image, libexif, openbox, polkit (opcional), git/curl,
#   autoconf, automake, libtool, intltool, gettext (para libfm e menu-cache).
#
# As versoes sao resolvidas automaticamente pela ultima release de cada projeto no GitHub/KDE.
# Para fixar versoes: LXQT_REF=2.1.0 ./09-lxqt.sh   (so afeta os componentes lxqt-* com a mesma versao).
set -euo pipefail
W=/sources/lxqt-build; mkdir -p "$W"; cd "$W"
J=${MAKEFLAGS:--j2}      # no Pi com 2 GB usa -j2
export CMAKE_BUILD_PARALLEL_LEVEL=${J#-j}

latest_tag() { # org repo -> tag da ultima release (sem API: segue o redirect)
  curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$1/$2/releases/latest" | sed 's|.*/tag/||'
}
fetch_gh() { # org repo [tag] -> descarrega e extrai para ./$repo
  local org=$1 repo=$2 tag=${3:-$(latest_tag "$1" "$2")}
  echo "==> $repo $tag"
  curl -fsSL "https://github.com/$org/$repo/archive/refs/tags/$tag.tar.gz" -o "$repo.tar.gz"
  rm -rf "$repo" && mkdir "$repo" && tar -xzf "$repo.tar.gz" -C "$repo" --strip-components=1
}
cmake_build() { # dir [opcoes cmake...]
  local d=$1; shift
  cmake -S "$d" -B "$d/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_LIBDIR=lib "$@"
  cmake --build "$d/build" && cmake --install "$d/build"
  ldconfig
}
lxqt() { # repo [opcoes cmake...]
  local r=$1; shift
  fetch_gh lxqt "$r" "${LXQT_REF:-}"; cmake_build "$r" "$@"
}

echo "##### KDE Frameworks 6: extra-cmake-modules + kwindowsystem #####"
KF=$(curl -fsS https://download.kde.org/stable/frameworks/ | grep -oE 'href="[0-9]+\.[0-9]+/"' | grep -oE '[0-9]+\.[0-9]+' | sort -uV | tail -1)
KFV=$(curl -fsS "https://download.kde.org/stable/frameworks/$KF/" | grep -oE 'extra-cmake-modules-[0-9.]+\.tar\.xz' | sort -uV | tail -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
for p in extra-cmake-modules kwindowsystem; do
  echo "==> $p $KFV"
  curl -fsSLO "https://download.kde.org/stable/frameworks/$KF/$p-$KFV.tar.xz"
  rm -rf "$p" && mkdir "$p" && tar -xf "$p-$KFV.tar.xz" -C "$p" --strip-components=1
  cmake_build "$p" -DBUILD_TESTING=OFF -DBUILD_QCH=OFF -DBUILD_DESIGNERPLUGIN=OFF
done

echo "##### Base LXQt #####"
# Ficam sem LXQT_REF porque estes projetos tem numeracao propria
( unset LXQT_REF
  lxqt lxqt-build-tools
  lxqt libqtxdg
  lxqt libsysstat
  lxqt libdbusmenu-lxqt
)
lxqt liblxqt
lxqt lxqt-menu-data
lxqt lxqt-globalkeys
lxqt lxqt-qtplugin
lxqt lxqt-themes

echo "##### libfm-extra + menu-cache (para o gestor de ficheiros) #####"
fetch_gh lxde menu-cache
( cd menu-cache && ./autogen.sh && ./configure --prefix=/usr --disable-static && make $J && make install )
fetch_gh lxde libfm
( cd libfm && ./autogen.sh && ./configure --prefix=/usr --with-extra-only --without-gtk --disable-demo \
    --disable-static && make $J && make install )
ldconfig
( unset LXQT_REF; lxqt libfm-qt )

echo "##### Sessao e aplicacoes #####"
lxqt lxqt-session
lxqt lxqt-panel -DVOLUME_PLUGIN=OFF -DSENSORS_PLUGIN=OFF -DSTATUSNOTIFIER_PLUGIN=ON
lxqt lxqt-config
lxqt lxqt-runner
lxqt lxqt-notificationd
lxqt pcmanfm-qt
( unset LXQT_REF; lxqt qtermwidget; lxqt qterminal )

echo "##### Configuracao por omissao: Openbox como gestor de janelas #####"
mkdir -p /etc/xdg/lxqt
cat > /etc/xdg/lxqt/session.conf <<'EOF'
[General]
window_manager=openbox
EOF
# /etc/skel para novos utilizadores
install -d /etc/skel/.config/lxqt
cp /etc/xdg/lxqt/session.conf /etc/skel/.config/lxqt/session.conf

echo "Pronto. Corre ./04-rootfs-config.sh no host (ja arranca com startlxqt) e testa com 'startx'."
