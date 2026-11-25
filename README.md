# CLLD - Claude LFS Linux Distro (Raspberry Pi 4 Model B)

Distribuição Linux From Scratch para **aarch64 / Raspberry Pi 4B** com:

| Requisito | Como é cumprido |
|---|---|
| Rato e teclado | Kernel RPi com USB xHCI (VL805) + HID + evdev; libinput + `xf86-input-libinput`; layout `pt` |
| Memória | Kernel 64 bit (4/8 GB de RAM), swap **zram** (lz4) a 50 % da RAM, `swappiness=100` |
| Interface visual | KMS/V3D (`vc4-kms-v3d`), Mesa, Xorg (driver modesetting), LXQt (leve, ideal para 2 GB) sobre Openbox, arranque automático |
| Raspberry Pi 4B | `kernel8.img`, `start4.elf`, `fixup4.dat`, `bcm2711-rpi-4-b.dtb`, `config.txt`, `cmdline.txt` |

Init: sysvinit + LFS-Bootscripts. Utilizador por omissão: `clld` / `clld` (e root com a mesma palavra-passe) - **muda-as**.

## Estado (honestidade)
Isto é um **kit de compilação** escrito sem poder ser executado de ponta a ponta no ambiente onde foi gerado
(sem rede, e a compilação demora horas). Os scripts seguem o livro LFS/BLFS e a documentação da Raspberry Pi,
mas **não foram testados em hardware**; espera ter de ajustar versões e corrigir pequenos erros.
Não há imagem pré-compilada.

## Requisitos do host
Linux x86_64 (Debian/Ubuntu/Fedora), ~40 GB livres, 8 GB RAM, ligação à Internet, e:
`build-essential bison gawk texinfo flex bc git rsync parted dosfstools e2fsprogs openssl qemu-user-static binfmt-support libssl-dev`
(e, para o passo do kernel, opcionalmente `gcc-aarch64-linux-gnu`).

## Passos
```bash
chmod +x *.sh
source clld-env.sh                # define $CLLD (/mnt/clld) e variáveis
./01-toolchain.sh                 # cross-toolchain aarch64 (LFS cap. 5)
# LFS caps. 6-8: ferramentas temporárias, chroot (./02-chroot.sh) e sistema final
#   - substituir $LFS -> $CLLD e $LFS_TGT -> $CLLD_TGT; usar os 'wget-list-sysv' já descarregados
./03-kernel-firmware.sh           # kernel RPi + firmware de arranque
# BLFS: seguir 05-gui-stack.md dentro do chroot (libinput, Mesa, Xorg, Qt6, Openbox...)
./09-lxqt.sh                      # (dentro do chroot) compila o LXQt
./04-rootfs-config.sh             # hostname, fstab, zram, autologin, Xorg/Openbox, teclado/rato
./06-make-image.sh                # gera clld-rpi4.img
sudo dd if=clld-rpi4.img of=/dev/sdX bs=4M conv=fsync status=progress
```

## Notas importantes
- O Pi 4 arranca pelo EEPROM; só precisa dos ficheiros `start4*.elf`/`fixup4*.dat` na partição FAT (feito no passo 03).
- Os capítulos 6-8 do LFS (≈80 pacotes) são feitos **à mão seguindo o livro**: não os reproduzi aqui para
  não duplicar centenas de linhas que dependem da versão exata do livro. Compilar em qemu-user é lento;
  numa máquina aarch64 (ou no próprio Pi 4) é muito mais rápido.
- Wi-Fi/Bluetooth precisam de `linux-firmware` (ficheiros brcm) e `wpa_supplicant`/`bluez`; não incluídos por omissão.
- Sem systemd/logind, o Xorg usa o `Xorg.wrap` setuid (ver `05-gui-stack.md`). Para algo mais seguro, adiciona o `elogind`.

## Teste rápido no qemu
`./07-qemu-test.sh` descarrega um kernel aarch64 + BusyBox (Alpine) e monta uma **imagem mínima CLLD** como
initramfs, para validar o arranque no qemu (`qemu-test/run.sh`). Não é o LFS completo nem tem interface gráfica.

## APT (gestor de pacotes)
Depois de compilar a pilha base (e as dependências: curl, cmake, perl, gnupg/gpgv, gnutls, lz4, zstd, xxhash, ncurses),
corre **dentro do chroot** `./08-apt.sh`. Compila `dpkg` + `apt`, cria os diretórios, cria pacotes "virtuais" para o que
o LFS já fornece (libc6, bash, coreutils...), instala as chaves Debian e configura `sources.list` (Debian `trixie` arm64;
muda com `SUITE=`). Bloqueia por pin o kernel, libc, init e firmware (`/etc/apt/preferences.d/clld-hold`).
Uso: `apt update && apt install <pacote>`.

Avisos: misturar pacotes Debian num LFS não é um cenário suportado. Funciona melhor com pacotes "folha"
(editores, utilitários); pacotes que dependem de systemd, ou que precisem de uma libc mais recente do que a do
CLLD, podem falhar. Como o 08-apt.sh também não foi testado, espera ter de ajustar.
