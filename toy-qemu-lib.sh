# Shared helpers for run.sh / run-split.sh (NVRAM + args)
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
    #   CLEAN_NVRAM=1 ./run.sh  或  ./run.sh --clean-nvram
    if [ "${CLEAN_NVRAM:-0}" = 1 ] || [ ! -f OVMF_VARS.fd ]; then
        cp -f OVMF_VARS.fd.clean OVMF_VARS.fd
    fi
}

toy_qemu_parse_args() {
    CLEAN_NVRAM="${CLEAN_NVRAM:-0}"
    FORCE_SECOND=0
    for Arg in "$@"; do
        case "$Arg" in
            --clean-nvram) CLEAN_NVRAM=1 ;;
            --force-second) FORCE_SECOND=1 ;;
        esac
    done
    export CLEAN_NVRAM FORCE_SECOND
}

# 从 THEME.CFG 读 mode=WxH；供 VGA edid 首选分辨率（x86_64 无 -g）。
# 输出：设置 TOY_QEMU_XRES / TOY_QEMU_YRES；打印一行说明。
toy_qemu_read_theme_mode() {
    local Cfg="${1:-THEME.CFG}"
    local Line W H

    TOY_QEMU_XRES="${TOY_QEMU_XRES:-}"
    TOY_QEMU_YRES="${TOY_QEMU_YRES:-}"
    if [ -n "$TOY_QEMU_XRES" ] && [ -n "$TOY_QEMU_YRES" ]; then
        echo "qemu: VGA edid ${TOY_QEMU_XRES}x${TOY_QEMU_YRES} (env override)"
        return 0
    fi
    if [ ! -f "$Cfg" ]; then
        # 与 ToyBoot ScoreModeQemu 首选一致，避免 SetMode 触发 QEMU+GTK 二次复位
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

# Settings 写 rootfs/THEME.CFG；启动盘 cwd/THEME.CFG 常是旧副本。
# 按 mtime 把较新的同步到另一侧；去掉 Linux 大小写重复的 theme.cfg（vvfat 易乱）。
toy_qemu_sync_theme_cfg() {
    local BootCfg="${1:-THEME.CFG}"
    local RootCfg="${2:-rootfs/THEME.CFG}"
    local RootLower
    RootLower="$(dirname "$RootCfg")/theme.cfg"

    if [ -f "$RootLower" ]; then
        if [ ! -f "$RootCfg" ] || [ "$RootLower" -nt "$RootCfg" ]; then
            cp -f "$RootLower" "$RootCfg"
            echo "THEME.CFG: promoted $RootLower -> $RootCfg"
        fi
        rm -f "$RootLower"
    fi
    if [ -f theme.cfg ]; then
        if [ ! -f "$BootCfg" ] || [ theme.cfg -nt "$BootCfg" ]; then
            cp -f theme.cfg "$BootCfg"
            echo "THEME.CFG: promoted theme.cfg -> $BootCfg"
        fi
        rm -f theme.cfg
    fi

    if [ -f "$RootCfg" ] && [ ! -f "$BootCfg" ]; then
        cp -f "$RootCfg" "$BootCfg"
        echo "THEME.CFG: copied $RootCfg -> $BootCfg"
    elif [ -f "$BootCfg" ] && [ ! -f "$RootCfg" ]; then
        mkdir -p "$(dirname "$RootCfg")"
        cp -f "$BootCfg" "$RootCfg"
        echo "THEME.CFG: copied $BootCfg -> $RootCfg"
    elif [ -f "$BootCfg" ] && [ -f "$RootCfg" ]; then
        if [ "$RootCfg" -nt "$BootCfg" ]; then
            cp -f "$RootCfg" "$BootCfg"
            echo "THEME.CFG: synced newer $RootCfg -> $BootCfg"
        elif [ "$BootCfg" -nt "$RootCfg" ]; then
            cp -f "$BootCfg" "$RootCfg"
            echo "THEME.CFG: synced newer $BootCfg -> $RootCfg"
        fi
    fi
}
