#!/bin/bash
# 双盘 QEMU（唯一推荐入口）— PR-Q1
#   disk0 = cwd          → ESP/Boot（仅 EFI/BOOT/BOOTX64.EFI 等）
#   disk1 = rootfs/      → TOYOS 系统盘（Kernel.elf、THEME.CFG、用户 ELF）
#
# 常用：
#   ./run-split.sh
#   ./run-split.sh --kill-qemu          # 清残留，避免 SIPI/AP 超时
#   TOY_SMP=1 ./run-split.sh            # 宿主忙或 CI 用单核
#   ./run-split.sh --headless           # 无图形（冒烟 / CI）
#   TOY_DISK=ahci ./run-split.sh        # PR-H1：AHCI 第二 Block（非 IDE）
#   TOY_DISK=nvme ./run-split.sh        # PR-H5：NVMe Block
#   ./smoke-boot.sh                     # 自动 headless+kill，等 ToyOS ready
set -e
cd "$(dirname "$0")"

. ./dock-icon.sh
install_toyos_dock_icon || true
# shellcheck source=toy-qemu-lib.sh
. ./toy-qemu-lib.sh

toy_qemu_parse_args "$@"
./prepare-rootfs.sh

# edid 只读系统盘主题，避免与启动盘旧 THEME.CFG 冲突
toy_qemu_read_theme_mode rootfs/THEME.CFG
toy_qemu_setup_ovmf
toy_qemu_prepare_smp

# 启动期间启动盘不含 Kernel/THEME，强制 Guest 走第二盘
toy_qemu_stash_boot_payloads
trap 'toy_qemu_restore_boot_payloads' EXIT

DISPLAY_ARGS=(-display gtk,zoom-to-fit=off)
if [ "${TOY_HEADLESS:-0}" = 1 ]; then
    DISPLAY_ARGS=(-display none)
    echo "qemu: headless (-display none)"
fi

NETDEV_ARGS=(user,id=n0)
if [ "${TOY_NO_HOSTFWD:-0}" != 1 ]; then
    NETDEV_ARGS=(user,id=n0,hostfwd=udp::5555-:5555,hostfwd=tcp::2222-:7,hostfwd=tcp::9000-:9000)
fi

# 存储：默认 IDE；TOY_DISK=ahci（H1）/ nvme（H5）
# bootindex：干净 NVRAM 时仍优先从 ESP 找 \EFI\BOOT\BOOTX64.EFI
DISK_ARGS=()
case "${TOY_DISK:-ide}" in
    ahci|AHCI)
        echo "qemu: disk=ahci (PR-H1)"
        DISK_ARGS=(
            -device ich9-ahci,id=ahci
            -drive if=none,id=toyesp,format=raw,file=fat:rw:.
            -device ide-hd,drive=toyesp,bus=ahci.0,bootindex=0
            -drive if=none,id=toyroot,format=raw,file=fat:rw:rootfs
            -device ide-hd,drive=toyroot,bus=ahci.1,bootindex=1
        )
        ;;
    nvme|NVMe|NVME)
        echo "qemu: disk=nvme (PR-H5)"
        DISK_ARGS=(
            -drive if=none,id=toyesp,format=raw,file=fat:rw:.
            -device nvme,serial=toyesp,drive=toyesp,logical_block_size=512,physical_block_size=512,bootindex=0
            -drive if=none,id=toyroot,format=raw,file=fat:rw:rootfs
            -device nvme,serial=toyroot,drive=toyroot,logical_block_size=512,physical_block_size=512,bootindex=1
        )
        ;;
    *)
        # IDE：bootindex 须挂在 device 上（raw -drive 不认该选项）
        DISK_ARGS=(
            -drive if=none,id=toyesp,format=raw,file=fat:rw:.
            -device ide-hd,drive=toyesp,bus=ide.0,unit=0,bootindex=0
            -drive if=none,id=toyroot,format=raw,file=fat:rw:rootfs
            -device ide-hd,drive=toyroot,bus=ide.0,unit=1,bootindex=1
        )
        ;;
esac

# 不用 -vga std：显式 VGA+edid；zoom-to-fit=off 让窗口跟 guest 分辨率走。
qemu-system-x86_64 \
    -name "ToyOS",process=qemu-system-x86_64 \
    -drive if=pflash,format=raw,readonly=on,file="$CODE" \
    -drive if=pflash,format=raw,file=OVMF_VARS.fd \
    "${DISK_ARGS[@]}" \
    -m 512M \
    -smp "$TOY_SMP" \
    -device VGA,edid=on,xres="${TOY_QEMU_XRES}",yres="${TOY_QEMU_YRES}" \
    "${DISPLAY_ARGS[@]}" \
    -device qemu-xhci,id=xhci \
    -device usb-kbd,bus=xhci.0 \
    -device usb-tablet,bus=xhci.0 \
    -netdev "${NETDEV_ARGS[@]}" \
    -device virtio-net-pci,netdev=n0 \
    -serial stdio \
    -no-reboot
