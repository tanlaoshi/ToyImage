#!/bin/bash
# Dual FAT: disk0=cwd (ESP/Boot), disk1=rootfs (Kernel+user ELFs)
set -e
cd "$(dirname "$0")"

. ./dock-icon.sh
install_toyos_dock_icon

./prepare-rootfs.sh

CODE="${OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd}"
VARS_TEMPLATE="${OVMF_VARS_SRC:-/usr/share/OVMF/OVMF_VARS_4M.fd}"
if [ ! -f "$CODE" ]; then
    CODE=/usr/share/OVMF/OVMF_CODE.fd
fi
if [ ! -f "$VARS_TEMPLATE" ]; then
    VARS_TEMPLATE=/usr/share/OVMF/OVMF_VARS.fd
fi
if [ ! -f "$CODE" ] || [ ! -f "$VARS_TEMPLATE" ]; then
    echo "error: OVMF not found (install ovmf or set OVMF_CODE / OVMF_VARS_SRC)" >&2
    exit 1
fi
if [ ! -f OVMF_VARS.fd.clean ]; then
    cp -f "$VARS_TEMPLATE" OVMF_VARS.fd.clean
fi
cp -f OVMF_VARS.fd.clean OVMF_VARS.fd

FORCE_SECOND=0
for Arg in "$@"; do
    case "$Arg" in
        --force-second) FORCE_SECOND=1 ;;
    esac
done

if [ "$FORCE_SECOND" = 1 ] && [ -f Kernel.elf ]; then
    mv -f Kernel.elf Kernel.elf.onboot
    echo "Moved Kernel.elf aside -> boot volume has no kernel (use disk1)"
    trap 'mv -f Kernel.elf.onboot Kernel.elf 2>/dev/null || true' EXIT
fi

qemu-system-x86_64 \
    -name "ToyOS",process=qemu-system-x86_64 \
    -drive if=pflash,format=raw,readonly=on,file="$CODE" \
    -drive if=pflash,format=raw,file=OVMF_VARS.fd \
    -drive format=raw,file=fat:rw:.,if=ide,index=0,media=disk \
    -drive format=raw,file=fat:rw:rootfs,if=ide,index=1,media=disk \
    -m 512M \
    -smp 2 \
    -vga std \
    -display gtk,zoom-to-fit=off \
    -device qemu-xhci,id=xhci \
    -device usb-kbd,bus=xhci.0 \
    -device usb-tablet,bus=xhci.0 \
    -netdev user,id=n0,hostfwd=udp::5555-:5555,hostfwd=tcp::2222-:7,hostfwd=tcp::9000-:9000 \
    -device virtio-net-pci,netdev=n0 \
    -serial stdio
