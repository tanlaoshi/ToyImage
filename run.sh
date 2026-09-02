#!/bin/bash
set -e
cd "$(dirname "$0")"

# Ensure Dock shows QEMU logo (Ubuntu 22.04 Wayland often shows a gear otherwise).
# shellcheck source=dock-icon.sh
. ./dock-icon.sh
install_toyos_dock_icon

# OVMF: Ubuntu ovmf 包常见为 4M 版；旧环境可能是 OVMF_CODE.fd / OVMF_VARS.fd
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

qemu-system-x86_64 \
    -name "ToyOS",process=qemu-system-x86_64 \
    -drive if=pflash,format=raw,readonly=on,file="$CODE" \
    -drive if=pflash,format=raw,file=OVMF_VARS.fd \
    -drive format=raw,file=fat:rw:. \
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
