# Shared helpers for run-split.sh (NVRAM + args + THEME)
# shellcheck shell=bash

toy_qemu_setup_ovmf() {
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
        return 1
    fi
    if [ ! -f OVMF_VARS.fd.clean ]; then
        cp -f "$VARS_TEMPLATE" OVMF_VARS.fd.clean
    fi
    # 默认保留 NVRAM（BootOrder 等）。需要干净变量存储时：
    #   CLEAN_NVRAM=1 ./run-split.sh  或  ./run-split.sh --clean-nvram
    if [ "${CLEAN_NVRAM:-0}" = 1 ] || [ ! -f OVMF_VARS.fd ]; then
        cp -f OVMF_VARS.fd.clean OVMF_VARS.fd
    fi
}

toy_qemu_parse_args() {
    CLEAN_NVRAM="${CLEAN_NVRAM:-0}"
    for Arg in "$@"; do
        case "$Arg" in
            --clean-nvram) CLEAN_NVRAM=1 ;;
            --force-second)
                # 兼容旧参数：现已默认只用第二盘
                ;;
        esac
    done
    export CLEAN_NVRAM
}

# 从 rootfs/THEME.CFG 读 mode=WxH（系统盘为唯一权威）
toy_qemu_read_theme_mode() {
    local Cfg="${1:-rootfs/THEME.CFG}"
    local Line W H

    TOY_QEMU_XRES="${TOY_QEMU_XRES:-}"
    TOY_QEMU_YRES="${TOY_QEMU_YRES:-}"
    if [ -n "$TOY_QEMU_XRES" ] && [ -n "$TOY_QEMU_YRES" ]; then
        echo "qemu: VGA edid ${TOY_QEMU_XRES}x${TOY_QEMU_YRES} (env override)"
        return 0
    fi
    if [ ! -f "$Cfg" ]; then
        TOY_QEMU_XRES=1600
        TOY_QEMU_YRES=900
        echo "qemu: VGA edid ${TOY_QEMU_XRES}x${TOY_QEMU_YRES} (default; no $Cfg)"
        return 0
    fi
    Line="$(grep -E '^[[:space:]]*mode=' "$Cfg" | head -1 || true)"
    W="$(printf '%s' "$Line" | sed -n 's/.*mode=\([0-9][0-9]*\)[xX]\([0-9][0-9]*\).*/\1/p')"
    H="$(printf '%s' "$Line" | sed -n 's/.*mode=\([0-9][0-9]*\)[xX]\([0-9][0-9]*\).*/\2/p')"
    if [ -z "$W" ] || [ -z "$H" ]; then
        TOY_QEMU_XRES=1600
        TOY_QEMU_YRES=900
        echo "qemu: VGA edid ${TOY_QEMU_XRES}x${TOY_QEMU_YRES} (default; no mode= in $Cfg)"
        return 0
    fi
    TOY_QEMU_XRES="$W"
    TOY_QEMU_YRES="$H"
    echo "qemu: VGA edid ${TOY_QEMU_XRES}x${TOY_QEMU_YRES} (from $Cfg)"
}

# 启动盘不应再挂系统文件：把 cwd 上的 Kernel/THEME/ELF 暂存到 .boot-stash/
# QEMU 退出后还原，方便继续把构建产物丢在 ToyImage/ 再 sync 进 rootfs。
toy_qemu_stash_boot_payloads() {
    local Stash=".boot-stash"
    local F

    mkdir -p "$Stash"
    for F in Kernel.elf THEME.CFG theme.cfg LIBTOY.SO \
        HELLO.ELF COUNT.ELF FORK.ELF CAT.ELF WRITE.ELF \
        SYSHELLO.ELF SYSFORK.ELF WAITNH.ELF \
        DYNDEMO.ELF NETDEMO.ELF NETSRV.ELF
    do
        if [ -e "$F" ]; then
            mv -f "$F" "$Stash/$F"
        fi
    done
    if [ -d "$Stash" ] && [ -n "$(ls -A "$Stash" 2>/dev/null || true)" ]; then
        echo "boot disk: stashed payloads -> $Stash/ (guest loads from rootfs only)"
    fi
}

toy_qemu_restore_boot_payloads() {
    local Stash=".boot-stash"
    local F

    [ -d "$Stash" ] || return 0
    for F in "$Stash"/*; do
        [ -e "$F" ] || continue
        mv -f "$F" "./$(basename "$F")"
    done
    rmdir "$Stash" 2>/dev/null || true
}
