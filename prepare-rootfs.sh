#!/bin/bash
# 把宿主暂存区（ToyImage 根目录）同步到第二盘 rootfs/（TOYOS 系统卷）
# 规范：Kernel.elf / THEME.CFG / 用户 ELF 等只以 rootfs 为准；启动盘仅保留 EFI。
set -e
cd "$(dirname "$0")"
ROOT=rootfs
mkdir -p "$ROOT"

if [ ! -f Kernel.elf ] && [ ! -f "$ROOT/Kernel.elf" ]; then
    echo "Missing Kernel.elf — build ToyKernel and copy to ToyImage/ (or $ROOT/)" >&2
    exit 1
fi

# 内核：取 Build / cwd 里较新的一份写入 rootfs（避免 QEMU stash 还原的旧 Kernel 盖掉新构建）
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
        echo "Prepared kernel from $KERNEL_SRC"
    fi
fi

# 主题：优先 rootfs；若仅 cwd 有则迁入；两边都有时取较新
if [ -f theme.cfg ]; then
    if [ ! -f THEME.CFG ] || [ theme.cfg -nt THEME.CFG ]; then
        cp -f theme.cfg THEME.CFG
    fi
    rm -f theme.cfg
fi
if [ -f "$ROOT/theme.cfg" ]; then
    if [ ! -f "$ROOT/THEME.CFG" ] || [ "$ROOT/theme.cfg" -nt "$ROOT/THEME.CFG" ]; then
        cp -f "$ROOT/theme.cfg" "$ROOT/THEME.CFG"
    fi
    rm -f "$ROOT/theme.cfg"
fi
if [ -f THEME.CFG ] && [ ! -f "$ROOT/THEME.CFG" ]; then
    cp -f THEME.CFG "$ROOT/THEME.CFG"
elif [ -f THEME.CFG ] && [ -f "$ROOT/THEME.CFG" ]; then
    if [ THEME.CFG -nt "$ROOT/THEME.CFG" ]; then
        cp -f THEME.CFG "$ROOT/THEME.CFG"
    fi
fi

# 用户程序 / 共享库
for F in \
    HELLO.ELF COUNT.ELF FORK.ELF CAT.ELF WRITE.ELF \
    SYSHELLO.ELF SYSFORK.ELF WAITNH.ELF EXECDEMO.ELF PIPEDEMO.ELF BRKDEMO.ELF \
    KILLDEMO.ELF DYNDEMO.ELF NETDEMO.ELF NETSRV.ELF LIBTOY.SO \
    LIBCDEMO.ELF DIRDEMO.ELF GUIDEMO.ELF WINDEMO.ELF NETLIB.ELF
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
# PR-S0：已安装 / 缓存目录占位
mkdir -p "$ROOT/Apps" "$ROOT/Store"
if [ -d ../ToyKernel/Apps ]; then
    cp -a ../ToyKernel/Apps/. "$ROOT/Apps/" 2>/dev/null || true
fi
if [ -d ../ToyKernel/Store ]; then
    cp -a ../ToyKernel/Store/. "$ROOT/Store/" 2>/dev/null || true
fi
if [ -d Apps ]; then
    cp -a Apps/. "$ROOT/Apps/" 2>/dev/null || true
fi
if [ -d Store ]; then
    cp -a Store/. "$ROOT/Store/" 2>/dev/null || true
fi

printf "ToyOS root volume\n" > "$ROOT/TOYOS.ID"
echo "Prepared $ROOT (TOYOS system disk):"
ls -lh "$ROOT"
find "$ROOT/Assets" -type f 2>/dev/null | sort || true
