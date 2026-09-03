# Shared helpers for run-split.sh (NVRAM + args + THEME + SMP)
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
    TOY_KILL_QEMU="${TOY_KILL_QEMU:-0}"
    TOY_HEADLESS="${TOY_HEADLESS:-0}"
    for Arg in "$@"; do
        case "$Arg" in
            --clean-nvram) CLEAN_NVRAM=1 ;;
            --kill-qemu) TOY_KILL_QEMU=1 ;;
            --headless) TOY_HEADLESS=1 ;;
            --smp=*)
                TOY_SMP="${Arg#--smp=}"
                ;;
            --smp)
                echo "error: use --smp=N (e.g. --smp=1)" >&2
                return 1
                ;;
            --force-second)
                # 兼容旧参数：现已默认只用第二盘
                ;;
            -h|--help)
                cat <<'EOF'
Usage: ./run-split.sh [options]

  Dual-disk QEMU (only supported entry):
    disk0 = cwd       ESP / Boot (EFI only after stash)
    disk1 = rootfs/   TOYOS system volume (Kernel.elf, THEME.CFG, ELFs)

Options:
  --clean-nvram     Reset OVMF_VARS.fd from clean template
  --kill-qemu       pkill leftover qemu-system-x86_64 before start
  --headless        -display none (CI / smoke; serial still on stdio)
  --smp=N           Pass -smp N (default 2; auto 1 if other QEMU exist)
  -h, --help        This help

Env:
  TOY_SMP=N         Same as --smp=N
  TOY_KILL_QEMU=1   Same as --kill-qemu
  TOY_HEADLESS=1    Same as --headless
  TOY_NO_HOSTFWD=1  Skip hostfwd (smoke/CI; avoids port bind failures)
  TOY_QEMU_XRES/YRES  Override VGA edid (else rootfs/THEME.CFG mode=)
  CLEAN_NVRAM=1     Same as --clean-nvram
  OVMF_CODE / OVMF_VARS_SRC  Custom firmware paths

Troubleshoot SIPI/AP timeout:
  ./run-split.sh --kill-qemu
  TOY_SMP=1 ./run-split.sh
EOF
                exit 0
                ;;
        esac
    done
    export CLEAN_NVRAM TOY_KILL_QEMU TOY_HEADLESS
    if [ -n "${TOY_SMP:-}" ]; then
        export TOY_SMP
    fi
}

# 统计其它 qemu-system-x86_64（不含本脚本即将启动的实例）
toy_qemu_count_others() {
    local N
    N="$(pgrep -c -f 'qemu-system-x86_64' 2>/dev/null | head -n1 || true)"
    N="${N:-0}"
    case "$N" in
        ''|*[!0-9]*) N=0 ;;
    esac
    printf '%s' "$N"
}

# 杀掉残留 QEMU，避免 SIPI 饿死 / AP timeout → 访客连环复位
toy_qemu_kill_others() {
    local N
    N="$(toy_qemu_count_others)"
    if [ "$N" -le 0 ]; then
        echo "qemu: no leftover qemu-system-x86_64"
        return 0
    fi
    echo "qemu: killing ${N} leftover qemu-system-x86_64 (SIPI safety)" >&2
    pkill -9 -f 'qemu-system-x86_64' 2>/dev/null || true
    sleep 0.3
}

# 残留实例时默认单核；可选先杀干净
toy_qemu_prepare_smp() {
    local Other
    Other="$(toy_qemu_count_others)"

    if [ "${TOY_KILL_QEMU:-0}" = 1 ]; then
        toy_qemu_kill_others
        Other=0
    elif [ "$Other" -gt 0 ]; then
        echo "warning: ${Other} qemu-system-x86_64 already running — SIPI/AP may timeout." >&2
        echo "warning: re-run with --kill-qemu, or: pkill -9 -f qemu-system-x86_64" >&2
        if [ -z "${TOY_SMP:-}" ]; then
            TOY_SMP=1
            echo "warning: defaulting TOY_SMP=1 while other QEMU exist" >&2
        fi
    fi

    TOY_SMP="${TOY_SMP:-2}"
    export TOY_SMP
    echo "qemu: -smp ${TOY_SMP}"
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
