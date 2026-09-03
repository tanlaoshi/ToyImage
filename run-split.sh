#!/bin/bash
# Dual FAT: disk0=cwd (ESP/Boot), disk1=rootfs (Kernel+user ELFs)
set -e
cd "$(dirname "$0")"

. ./dock-icon.sh
install_toyos_dock_icon
# shellcheck source=toy-qemu-lib.sh
. ./toy-qemu-lib.sh

toy_qemu_parse_args "$@"
./prepare-rootfs.sh
# Settings 写在 rootfs；按 mtime 与启动盘 THEME.CFG 双向同步（勿用启动盘旧文件覆盖）
toy_qemu_sync_theme_cfg THEME.CFG rootfs/THEME.CFG
toy_qemu_read_theme_mode THEME.CFG

toy_qemu_setup_ovmf

if [ "$FORCE_SECOND" = 1 ] && [ -f Kernel.elf ]; then
    mv -f Kernel.elf Kernel.elf.onboot
    echo "Moved Kernel.elf aside -> boot volume has no kernel (use disk1)"
    trap 'mv -f Kernel.elf.onboot Kernel.elf 2>/dev/null || true' EXIT
fi

# 不用 -vga std：显式 VGA+edid 首选分辨率，减轻 ToyBoot SetMode 后 GTK 跳变导致的二次复位。
# x86_64 无 -g；zoom-to-fit=off 让窗口跟 guest 分辨率走。
qemu-system-x86_64 \
    -name "ToyOS",process=qemu-system-x86_64 \
    -drive if=pflash,format=raw,readonly=on,file="$CODE" \
    -drive if=pflash,format=raw,file=OVMF_VARS.fd \
    -drive format=raw,file=fat:rw:.,if=ide,index=0,media=disk \
    -drive format=raw,file=fat:rw:rootfs,if=ide,index=1,media=disk \
    -m 512M \
    -smp 2 \
    -device VGA,edid=on,xres="${TOY_QEMU_XRES}",yres="${TOY_QEMU_YRES}" \
    -display gtk,zoom-to-fit=off \
    -device qemu-xhci,id=xhci \
    -device usb-kbd,bus=xhci.0 \
    -device usb-tablet,bus=xhci.0 \
    -netdev user,id=n0,hostfwd=udp::5555-:5555,hostfwd=tcp::2222-:7,hostfwd=tcp::9000-:9000 \
    -device virtio-net-pci,netdev=n0 \
    -serial stdio
