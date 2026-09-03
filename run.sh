#!/bin/bash
set -e
cd "$(dirname "$0")"

# Ensure Dock shows QEMU logo (Ubuntu 22.04 Wayland often shows a gear otherwise).
# shellcheck source=dock-icon.sh
. ./dock-icon.sh
install_toyos_dock_icon
# shellcheck source=toy-qemu-lib.sh
. ./toy-qemu-lib.sh

toy_qemu_parse_args "$@"
toy_qemu_setup_ovmf

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
