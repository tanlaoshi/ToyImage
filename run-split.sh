#!/bin/bash
# 双盘 QEMU（唯一推荐入口）— PR-Q1
#   disk0 = cwd          → ESP/Boot（仅 EFI/BOOT/BOOTX64.EFI 等）
#   disk1 = RootFs/X64/  → TOYOS 系统盘（Kernel.elf、THEME.CFG、用户 ELF）
#
# 常用：
#   ./run-split.sh
#   ./run-split.sh --kill-qemu          # 清残留，避免 SIPI/AP 超时
#   TOY_SMP=1 ./run-split.sh            # 宿主忙或 CI 用单核
#   ./run-split.sh --headless           # 无图形（冒烟 / CI）
#   TOY_DISK=ahci ./run-split.sh        # PR-H1：AHCI 第二 Block（非 IDE）
#   TOY_DISK=nvme ./run-split.sh        # PR-H5：NVMe Block
#   TOY_NET=e1000 ./run-split.sh        # PR-H4：e1000 代替 virtio-net
#   TOY_NET=e1000e ./run-split.sh       # PR-H4e-1：e1000e（82574）
#   TOY_USB_HUB=1 ./run-split.sh        # PR-H-hub：键盘挂在一层 usb-hub 后
#   TOY_USB_MSC=1 ./run-split.sh        # PR-H-msc-8：额外 usb-storage（msc-stick/）
set -e
cd "$(dirname "$0")"

. ./dock-icon.sh
install_toyos_dock_icon || true
# shellcheck source=toy-qemu-lib.sh
. ./toy-qemu-lib.sh

toy_qemu_parse_args "$@"
./prepare-rootfs.sh

# edid 只读系统盘主题，避免与启动盘旧 THEME.CFG 冲突
toy_qemu_read_theme_mode RootFs/X64/THEME.CFG
toy_qemu_setup_ovmf
toy_qemu_prepare_smp

# 启动期间启动盘不含 Kernel/THEME，强制 Guest 走第二盘
toy_qemu_stash_boot_payloads
trap 'toy_qemu_restore_boot_payloads' EXIT

DISPLAY_ARGS=(-display gtk,zoom-to-fit=off)
if [ "${TOY_HEADLESS:-0}" = 1 ]; then
    DISPLAY_ARGS=(-display none)
    toy_qemu_info "qemu: headless (-display none)"
fi

# PR-H-hub：TOY_USB_HUB=1 时键盘在一层 hub 后；默认仍直挂根口
USB_ARGS=()
if [ "${TOY_USB_HUB:-0}" = 1 ]; then
    # QEMU 6.x：hub 后设备用 port 路径（bus=hub0.0 在本机无效）
    USB_ARGS=(-device usb-hub,bus=xhci.0,port=1 -device usb-kbd,bus=xhci.0,port=1.1 -device usb-tablet,bus=xhci.0,port=2)
    toy_qemu_info "qemu: TOY_USB_HUB=1 (kbd behind hub port 1.1)"
else
    USB_ARGS=(-device usb-kbd,bus=xhci.0 -device usb-tablet,bus=xhci.0)
fi

# PR-H-msc-8：TOY_USB_MSC=1 → 挂 msc-stick/ 为 usb-storage（验 7b auto mux）
MSC_DISK_ARGS=()
if [ "${TOY_USB_MSC:-0}" = 1 ]; then
    if [ ! -d msc-stick ] || [ ! -f msc-stick/TOYOS.ID ]; then
        echo "error: TOY_USB_MSC=1 needs msc-stick/TOYOS.ID" >&2
        exit 1
    fi
    toy_qemu_info "qemu: TOY_USB_MSC=1 (usb-storage ← msc-stick/)"
    MSC_DISK_ARGS=(
        -drive if=none,id=toymsc,format=raw,file=fat:rw:msc-stick
        -device usb-storage,drive=toymsc,bus=xhci.0
    )
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
        toy_qemu_info "qemu: disk=ahci (PR-H1)"
        DISK_ARGS=(
            -device ich9-ahci,id=ahci
            -drive if=none,id=toyesp,format=raw,file=fat:rw:.
            -device ide-hd,drive=toyesp,bus=ahci.0,bootindex=0
            -drive if=none,id=toyroot,format=raw,file=fat:rw:RootFs/X64
            -device ide-hd,drive=toyroot,bus=ahci.1,bootindex=1
        )
        ;;
    nvme|NVMe|NVME)
        toy_qemu_info "qemu: disk=nvme (PR-H5)"
        DISK_ARGS=(
            -drive if=none,id=toyesp,format=raw,file=fat:rw:.
            -device nvme,serial=toyesp,drive=toyesp,logical_block_size=512,physical_block_size=512,bootindex=0
            -drive if=none,id=toyroot,format=raw,file=fat:rw:RootFs/X64
            -device nvme,serial=toyroot,drive=toyroot,logical_block_size=512,physical_block_size=512,bootindex=1
        )
        ;;
    *)
        # IDE：bootindex 须挂在 device 上（raw -drive 不认该选项）
        DISK_ARGS=(
            -drive if=none,id=toyesp,format=raw,file=fat:rw:.
            -device ide-hd,drive=toyesp,bus=ide.0,unit=0,bootindex=0
            -drive if=none,id=toyroot,format=raw,file=fat:rw:RootFs/X64
            -device ide-hd,drive=toyroot,bus=ide.0,unit=1,bootindex=1
        )
        ;;
esac

# PR-FS-inst-1：空白第三盘（AHCI 口 2）；Guest：install 2 --yes --mib 512
# 镜像勿放在 fat:rw:.（cwd）内，否则 ESP vvfat 撑爆
if [ "${TOY_INSTALL_DISK:-0}" = 1 ]; then
    if [ "${TOY_DISK:-ide}" != "ahci" ] && [ "${TOY_DISK:-ide}" != "AHCI" ]; then
        echo "error: TOY_INSTALL_DISK=1 requires TOY_DISK=ahci (third AHCI port)" >&2
        exit 1
    fi
    INSTALL_IMG="${TOY_INSTALL_IMG:-/tmp/toyos-install-target.img}"
    INSTALL_MIB="${TOY_INSTALL_MIB:-512}"
    if [ ! -f "$INSTALL_IMG" ]; then
        toy_qemu_info "qemu: create $INSTALL_IMG (${INSTALL_MIB}MiB)"
        qemu-img create -f raw "$INSTALL_IMG" "${INSTALL_MIB}M" >/dev/null
    fi
    toy_qemu_info "qemu: TOY_INSTALL_DISK=1 → $INSTALL_IMG on ahci.2 (Guest drive 2)"
    DISK_ARGS+=(
        -drive if=none,id=toyinst,format=raw,file="$INSTALL_IMG"
        -device ide-hd,drive=toyinst,bus=ahci.2
    )
fi

# 网卡：默认 virtio-net-pci；TOY_NET=e1000|e1000e → Intel（PR-H4 / H4e-1）
NET_ARGS=()
case "${TOY_NET:-virtio}" in
    e1000e|E1000E)
        toy_qemu_info "qemu: net=e1000e (PR-H4e-1)"
        NET_ARGS=(-device e1000e,netdev=n0)
        ;;
    e1000|E1000)
        toy_qemu_info "qemu: net=e1000 (PR-H4)"
        NET_ARGS=(-device e1000,netdev=n0)
        ;;
    *)
        NET_ARGS=(-device virtio-net-pci,netdev=n0)
        ;;
esac

# 冒烟/无头默认 -no-reboot（三重故障不循环）；交互桌面勿加，否则开始菜单「重启」只退出 QEMU
NO_REBOOT_ARGS=()
if [ "${TOY_HEADLESS:-0}" = 1 ] || [ "${TOY_NO_REBOOT:-0}" = 1 ]; then
    NO_REBOOT_ARGS=(-no-reboot)
fi

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
    "${USB_ARGS[@]}" \
    "${MSC_DISK_ARGS[@]}" \
    -netdev "${NETDEV_ARGS[@]}" \
    "${NET_ARGS[@]}" \
    -serial stdio \
    "${NO_REBOOT_ARGS[@]}"
