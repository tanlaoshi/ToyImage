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
