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

# 内核：cwd 有则覆盖 rootfs（构建产物落点）
if [ -f Kernel.elf ]; then
    cp -f Kernel.elf "$ROOT/Kernel.elf"
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

printf "ToyOS root volume\n" > "$ROOT/TOYOS.ID"
echo "Prepared $ROOT (TOYOS system disk):"
ls -lh "$ROOT"
find "$ROOT/Assets" -type f 2>/dev/null | sort || true
