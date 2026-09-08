# ToyImage 快速开始（PR-Q1）

唯一推荐启动入口：**`./run-split.sh`**（`run.sh` 仅转发到此脚本）。

## 双盘布局

| 盘 | QEMU 路径 | 内容 |
|----|-----------|------|
| **disk0** | cwd（`.`） | ESP / Boot：`EFI/BOOT/BOOTX64.EFI`；启动前会 stash 掉 Kernel/THEME/ELF |
| **disk1** | `rootfs/` | **TOYOS 系统盘**：`TOYOS.ID`、`Kernel.elf`、`THEME.CFG`、用户 ELF |

Guest 侧 ToyBoot **优先**从含 `TOYOS.ID` 的卷加载 `Kernel.elf`。请把内核与主题放在 / 同步进 `rootfs/`（`prepare-rootfs.sh` 会在启动前自动做）。

```bash
cd ../ToyKernel && ./build.sh          # 产物拷到 ToyImage/ 与 rootfs/
cd ../ToyImage  && ./run-split.sh
```

## 常用选项

```bash
./run-split.sh --help
./run-split.sh --kill-qemu             # 杀掉残留 qemu-system-x86_64（防 SIPI/AP 超时）
TOY_SMP=1 ./run-split.sh               # 单核（宿主忙 / CI）
./run-split.sh --smp=2                 # 显式双核
./run-split.sh --headless              # 无 GTK 窗口，串口仍在终端
./run-split.sh --clean-nvram           # 重置 OVMF 变量盘
./smoke-boot.sh                        # 冒烟：kill + headless + TOY_SMP=1，等到 ToyOS ready
# （冒烟默认 TOY_NO_HOSTFWD=1，避免 hostfwd 端口占用）
```

分辨率：改 `rootfs/THEME.CFG` 的 `mode=WxH` 后 **退出 QEMU 再跑** `./run-split.sh`（Guest reboot 不会改宿主 edid）。

## SMP / 连环重启排查

残留或过多 QEMU 实例会饿死 SIPI，表现为 AP timeout，严重时整机复位环：

1. `./run-split.sh --kill-qemu` 或 `pkill -9 -f qemu-system-x86_64`
2. 仍失败则 `TOY_SMP=1 ./run-split.sh`
3. 内核已在 AP 超时后 **park AP 并单核继续**（串口：`smp: continue single-CPU (AP failed)`），不应再无限重启

## 冒烟验收

```bash
./smoke-boot.sh                 # 默认 TOY_SMP=1
TOY_SMP=2 ./smoke-boot.sh       # 可选双核冒烟
```

成功条件：串口日志出现 `ToyOS ready`。

## 真机 U 盘（PR-H0）

课堂双盘可压成 U 盘 **ESP 256MiB + TOYOS 剩余**（GPT）。目标机约定与缺口：

→ [`../ToyKernel/HAL/X64/NOTES-UEFI-PC.md`](../ToyKernel/HAL/X64/NOTES-UEFI-PC.md)  
→ [`../ToyBoot/README.md`](../ToyBoot/README.md)（Real PC 节）  
→ [`../ToyKernel/Documents/真机冒烟清单.md`](../ToyKernel/Documents/真机冒烟清单.md)（**PR-PC-smoke**）

### 制作 / 同步脚本

```bash
# 一次性：擦盘分区（仅 USB；需 --yes）
cd ToyImage
./make-usb-stick.sh --device /dev/sdX --yes --sync

# 日常：当前进展刷到已挂载的 ESP + TOYOS
./sync-usb.sh              # 同步 Boot + rootfs
./sync-usb.sh --build      # 先 ./build.sh Kernel+Boot 再同步
./sync-usb.sh --kernel-only  # 只刷 Kernel.elf（旧 sync-kernel-usb.sh 同效）
```

桌面自动挂载后应看到卷标 **ESP** 与 **TOYOS**。Secure Boot 请关。
