#!/bin/bash
set -e
cd "$(dirname "$0")"

# Ensure Dock shows QEMU logo (Ubuntu 22.04 Wayland often shows a gear otherwise).
# shellcheck source=dock-icon.sh
. ./dock-icon.sh
install_toyos_dock_icon

# Office QEMU 6.2: distro OVMF pflash (CODE readonly + VARS reset each run).
CODE=/usr/share/OVMF/OVMF_CODE.fd
VARS_TEMPLATE=/usr/share/OVMF/OVMF_VARS.fd
if [ ! -f OVMF_VARS.fd.clean ]; then
    cp -f "$VARS_TEMPLATE" OVMF_VARS.fd.clean
fi
cp -f OVMF_VARS.fd.clean OVMF_VARS.fd

qemu-system-x86_64 \
    -name "ToyOS",process=qemu-system-x86_64 \
    -drive if=pflash,format=raw,readonly=on,file="$CODE" \
    -drive if=pflash,format=raw,file=OVMF_VARS.fd \
    -drive format=raw,file=fat:rw:. \
    -m 512M \
    -vga std \
    -display gtk,zoom-to-fit=off \
    -device qemu-xhci,id=xhci \
    -device usb-kbd,bus=xhci.0 \
    -device usb-tablet,bus=xhci.0 \
    -netdev user,id=n0,hostfwd=udp::5555-:5555,hostfwd=tcp::2222-:7 \
    -device virtio-net-pci,netdev=n0 \
    -serial stdio
