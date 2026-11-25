# CLLD - Pilha gráfica, rato e teclado (BLFS, dentro do chroot)

Entra com `./02-chroot.sh` e compila **por esta ordem** (versões do livro BLFS correspondente ao teu LFS).
Em qemu-user a compilação é lenta (Mesa e Xorg demoram horas); alternativa: compilar em
Pi 4 real ou numa máquina aarch64.

## 1. Base de utilizador
| Pacote | Notas |
|---|---|
| eudev | `udev` para detetar rato/teclado; instalar regras do LFS-udev-lfs |
| dbus | `--disable-systemd`; criar utilizador messagebus |
| libpng, freetype, fontconfig, harfbuzz | texto |
| dejavu-fonts | pelo menos uma fonte |

## 2. Entrada (rato e teclado)
| Pacote | Notas |
|---|---|
| mtdev, libevdev | dependências do libinput |
| libinput | `meson setup build -Dlibwacom=false -Ddebug-gui=false -Dtests=false` |
| xkeyboard-config, libxkbcommon | mapas de teclado (layout `pt`) |

Verificação na placa: `libinput list-devices` e `cat /proc/bus/input/devices`.

## 3. Gráficos (VC4/V3D)
| Pacote | Notas |
|---|---|
| libdrm | `-Dvc4=enabled -Dintel=disabled -Damdgpu=disabled -Dradeon=disabled -Dnouveau=disabled` |
| Xorg: xorgproto, libXau, libXdmcp, xcb-proto, libxcb, xtrans, libX11 … | seguir BLFS "Xorg Libraries" |
| pixman | |
| Mesa | `meson setup build -Dgallium-drivers=v3d,vc4,kmsro,swrast -Dvulkan-drivers= -Dllvm=disabled -Dplatforms=x11 -Dglx=dri` (v3d = GPU do Pi 4, vc4 = display) |
| xorg-server | `-Dsuid_wrapper=true -Dxkb_output_dir=/var/lib/xkb -Dglamor=true`; depois `chmod 4755 /usr/libexec/Xorg.wrap`. Sem logind precisa deste wrapper |
| xf86-input-libinput | driver de entrada para o Xorg |
| xinit, xterm, xsetroot | `startx`, terminal |

O driver de vídeo é o `modesetting` embutido no xorg-server (não é preciso driver DDX extra).

## 4. Ambiente de trabalho (leve)
| Pacote | Notas |
|---|---|
| imlib2, cairo, pango, glib2, libxml2 | dependências |
| openbox | gestor de janelas (`openbox-session`) |
| tint2 | barra de tarefas |
| (opcional) pcmanfm, leafpad, dillo/netsurf | ficheiros, editor, browser leve |

## 5. Rede (opcional mas útil)
dhcpcd, wpa_supplicant + `linux-firmware` (ficheiros `brcm/*43455*` para o Wi-Fi do Pi 4).

## Dica
Depois de cada pacote: `strip --strip-unneeded` nas libs e apagar `/usr/share/doc`, `/usr/share/man`
se precisares de poupar espaço na imagem.
