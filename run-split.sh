#!/bin/bash
# 双盘 QEMU（唯一推荐入口）
#   disk0 = cwd          → ESP/Boot（仅 EFI/BOOT/BOOTX64.EFI 等）
#   disk1 = rootfs/      → TOYOS 系统盘（Kernel.elf、THEME.CFG、用户 ELF）
set -e
cd "$(dirname "$0")"

. ./dock-icon.sh
install_toyos_dock_icon
# shellcheck source=toy-qemu-lib.sh
. ./toy-qemu-lib.sh

toy_qemu_parse_args "$@"
./prepare-rootfs.sh

# edid 只读系统盘主题，避免与启动盘旧 THEME.CFG 冲突
toy_qemu_read_theme_mode rootfs/THEME.CFG
toy_qemu_setup_ovmf

# pgrep -c 在无匹配时仍打印 0 且 exit=1；不能用 || echo 0（会变成 "0\n0"）
OTHER_QEMU="$(pgrep -c -f 'qemu-system-x86_64' 2>/dev/null | head -n1)"
OTHER_QEMU="${OTHER_QEMU:-0}"
case "$OTHER_QEMU" in
    ''|*[!0-9]*) OTHER_QEMU=0 ;;
esac
if [ "$OTHER_QEMU" -gt 0 ]; then
    echo "warning: ${OTHER_QEMU} qemu-system-x86_64 already running — SIPI/AP may timeout. Kill leftovers first." >&2
    if [ -z "${TOY_SMP:-}" ]; then
        TOY_SMP=1
        echo "warning: defaulting TOY_SMP=1 while other QEMU exist" >&2
    fi
fi

# 启动期间启动盘不含 Kernel/THEME，强制 Guest 走第二盘
toy_qemu_stash_boot_payloads
trap 'toy_qemu_restore_boot_payloads' EXIT

TOY_SMP="${TOY_SMP:-2}"

# 不用 -vga std：显式 VGA+edid；zoom-to-fit=off 让窗口跟 guest 分辨率走。
qemu-system-x86_64 \
    -name "ToyOS",process=qemu-system-x86_64 \
    -drive if=pflash,format=raw,readonly=on,file="$CODE" \
    -drive if=pflash,format=raw,file=OVMF_VARS.fd \
    -drive format=raw,file=fat:rw:.,if=ide,index=0,media=disk \
    -drive format=raw,file=fat:rw:rootfs,if=ide,index=1,media=disk \
    -m 512M \
    -smp "$TOY_SMP" \
    -device VGA,edid=on,xres="${TOY_QEMU_XRES}",yres="${TOY_QEMU_YRES}" \
    -display gtk,zoom-to-fit=off \
    -device qemu-xhci,id=xhci \
    -device usb-kbd,bus=xhci.0 \
    -device usb-tablet,bus=xhci.0 \
    -netdev user,id=n0,hostfwd=udp::5555-:5555,hostfwd=tcp::2222-:7,hostfwd=tcp::9000-:9000 \
    -device virtio-net-pci,netdev=n0 \
    -serial stdio \
    -no-reboot
