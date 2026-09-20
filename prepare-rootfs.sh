#!/bin/bash
# 把宿主暂存区（ToyImage 根目录）同步到第二盘 RootFs/X64/（TOYOS 系统卷）
# 规范：Kernel.elf / THEME.CFG / 用户 ELF 等只以 RootFs/X64 为准；启动盘仅保留 EFI。
set -e
cd "$(dirname "$0")"
ROOT=RootFs/X64
mkdir -p "$ROOT"

if [ ! -f Kernel.elf ] && [ ! -f "$ROOT/Kernel.elf" ]; then
    echo "Missing Kernel.elf — build ToyKernel and copy to ToyImage/ (or $ROOT/)" >&2
    exit 1
fi

# 内核：取 Build / cwd 里较新的一份写入 RootFs/X64（避免 QEMU stash 还原的旧 Kernel 盖掉新构建）
BUILD_KERNEL=../ToyKernel/Build/HAL/X64/Kernel.elf
KERNEL_SRC=
if [ -f "$BUILD_KERNEL" ]; then
    KERNEL_SRC="$BUILD_KERNEL"
fi
if [ -f Kernel.elf ]; then
    if [ -z "$KERNEL_SRC" ] || [ Kernel.elf -nt "$KERNEL_SRC" ]; then
        KERNEL_SRC=Kernel.elf
    fi
fi
if [ -n "$KERNEL_SRC" ]; then
    if [ ! -f "$ROOT/Kernel.elf" ] || [ "$KERNEL_SRC" -nt "$ROOT/Kernel.elf" ] ||
       ! cmp -s "$KERNEL_SRC" "$ROOT/Kernel.elf" 2>/dev/null; then
        cp -f "$KERNEL_SRC" "$ROOT/Kernel.elf"
        if [ "${TOY_QEMU_VERBOSE:-0}" = 1 ]; then echo "Prepared kernel from $KERNEL_SRC"; fi
    fi
fi

# 主题：RootFs/X64/THEME.CFG 是唯一权威（Guest Settings / QEMU edid 都认它）。
# 勿用 cwd 上较新的旧副本盖掉系统盘（stash 还原曾导致 1280x720→1600x900）。
if [ -f theme.cfg ]; then
    if [ ! -f THEME.CFG ]; then
        cp -f theme.cfg THEME.CFG
    fi
    rm -f theme.cfg
fi
if [ -f "$ROOT/theme.cfg" ]; then
    if [ ! -f "$ROOT/THEME.CFG" ]; then
        cp -f "$ROOT/theme.cfg" "$ROOT/THEME.CFG"
    fi
    rm -f "$ROOT/theme.cfg"
fi
if [ -f "$ROOT/THEME.CFG" ]; then
    # 镜像到 cwd 仅供查看；绝不反向覆盖 RootFs/X64
    cp -f "$ROOT/THEME.CFG" THEME.CFG
elif [ -f THEME.CFG ]; then
    cp -f THEME.CFG "$ROOT/THEME.CFG"
    if [ "${TOY_QEMU_VERBOSE:-0}" = 1 ]; then echo "Prepared THEME.CFG -> $ROOT/ (first-time migrate)"; fi
else
    # vvfat 曾弄丢宿主文件时兜底（与默认 1920×1080 对齐）
    cat > "$ROOT/THEME.CFG" <<'EOF'
desktop=404040
shell=c0c0c0
font=0
mode=1920x1080
EOF
    cp -f "$ROOT/THEME.CFG" THEME.CFG
    if [ "${TOY_QEMU_VERBOSE:-0}" = 1 ]; then echo "Prepared THEME.CFG -> $ROOT/ (reseed default 1920x1080)"; fi
fi
# vvfat 以当前用户写回；只读/root 属主会导致 Guest「saved」但宿主 mode 不变
for F in "$ROOT/THEME.CFG" "$ROOT/TOYOS.DB" THEME.CFG; do
    if [ -e "$F" ]; then
        chmod u+rw "$F" 2>/dev/null || true
    fi
done
if [ -f "$ROOT/THEME.CFG" ] && [ ! -w "$ROOT/THEME.CFG" ]; then
    echo "warning: $ROOT/THEME.CFG not writable by $(id -un) — Settings resolution will not persist" >&2
fi

# 用户程序 / 共享库
for F in \
    HELLO.ELF COUNT.ELF FORK.ELF CAT.ELF WRITE.ELF \
    SYSHELLO.ELF SYSFORK.ELF WAITNH.ELF EXECDEMO.ELF PIPEDEMO.ELF BRKDEMO.ELF \
    KILLDEMO.ELF DYNDEMO.ELF NETDEMO.ELF NETSRV.ELF LIBTOY.SO \
    LIBCDEMO.ELF DIRDEMO.ELF GUIDEMO.ELF WINDEMO.ELF BLITDEMO.ELF NETLIB.ELF MMAPDEMO.ELF
do
    if [ -f "$F" ]; then
        cp -f "$F" "$ROOT/$F"
    fi
done

# 运行时资源（Assets/Icons、Assets/Images）— 不链入 Kernel.elf
mkdir -p "$ROOT/Assets/Icons" "$ROOT/Assets/Images"
if [ -d Assets ]; then
    cp -a Assets/. "$ROOT/Assets/"
fi
# 兼容旧扁平 WALL.BMP
if [ -f WALL.BMP ]; then
    cp -f WALL.BMP "$ROOT/Assets/Images/WALL.BMP"
    rm -f WALL.BMP
fi
rm -f "$ROOT/WALL.BMP"
# 仓库侧兜底（cwd 未带 Assets 时）
if [ ! -f "$ROOT/Assets/Images/WALL.BMP" ] && [ -f ../ToyKernel/Assets/Images/WALL.BMP ]; then
    cp -f ../ToyKernel/Assets/Images/WALL.BMP "$ROOT/Assets/Images/WALL.BMP"
fi
if [ ! -f "$ROOT/Assets/Icons/bmp48/SHELL.BMP" ] && [ -d ../ToyKernel/Assets/Icons ]; then
    mkdir -p "$ROOT/Assets/Icons"
    cp -a ../ToyKernel/Assets/Icons/. "$ROOT/Assets/Icons/"
fi
if [ ! -f "$ROOT/Assets/Locale/en.txt" ] && [ -d ../ToyKernel/Assets/Locale ]; then
    mkdir -p "$ROOT/Assets/Locale"
    cp -a ../ToyKernel/Assets/Locale/. "$ROOT/Assets/Locale/"
fi
if [ ! -f "$ROOT/Assets/Fonts/VGA8X16.FNT" ] && [ -d ../ToyKernel/Assets/Fonts ]; then
    mkdir -p "$ROOT/Assets/Fonts"
    cp -a ../ToyKernel/Assets/Fonts/. "$ROOT/Assets/Fonts/"
fi
if [ ! -f "$ROOT/Assets/Store/catalog.txt" ] && [ -d ../ToyKernel/Assets/Store ]; then
    mkdir -p "$ROOT/Assets/Store"
    cp -a ../ToyKernel/Assets/Store/. "$ROOT/Assets/Store/"
fi
# PR-S3：资源包安装目录占位
mkdir -p "$ROOT/Assets/Packs"
if [ -d ../ToyKernel/Assets/Packs ]; then
    cp -a ../ToyKernel/Assets/Packs/. "$ROOT/Assets/Packs/" 2>/dev/null || true
fi
# Guest 可写占位（已装 ELF / 商店缓存）；仓库不再另建 Apps/、StoreCache/
mkdir -p "$ROOT/Apps" "$ROOT/StoreCache"
if [ -d Apps ]; then
    cp -a Apps/. "$ROOT/Apps/" 2>/dev/null || true
fi
if [ -d StoreCache ]; then
    cp -a StoreCache/. "$ROOT/StoreCache/" 2>/dev/null || true
elif [ -d Store ]; then
    # 兼容旧名 Store/
    cp -a Store/. "$ROOT/StoreCache/" 2>/dev/null || true
fi

printf "ToyOS root volume\n" > "$ROOT/TOYOS.ID"
# 默认一行摘要；TOY_QEMU_VERBOSE=1 才 ls/find 刷屏
if [ "${TOY_QEMU_VERBOSE:-0}" = 1 ]; then
    echo "Prepared $ROOT (TOYOS system disk):"
    ls -lh "$ROOT"
    find "$ROOT/Assets" -type f 2>/dev/null | sort || true
else
    echo "Prepared $ROOT (TOYOS system disk)"
fi
