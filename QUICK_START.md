# ToyImage 快速开始（PR-Q1）

唯一推荐启动入口：树根 **`$TOYOS_ROOT/Scripts/run-split.sh`**（或 `Scripts/run.sh x86`）。

## 布局（公共与架构分离）

| 路径 | 角色 |
|------|------|
| `Assets/` | Guest 资源种子（Fonts/Icons/Locale/Images/Packs/Sounds） |
| `Store/` | 商店货架真源（catalog + packages → Guest `Store/`） |
| `RootFs/X64/` | x86 系统盘（`Kernel.elf` 等；QEMU `fat:rw`） |
| `RootFs/{Arm64,RiscV}/` | virt staging + `disk.img`（`prepare-virt-rootfs` 生成） |
| `Esp/X64/` | x86 ESP（`EFI/BOOT/BOOTX64.EFI`） |
| `Fw/` | OVMF 变量盘种子（`OVMF_VARS.fd.clean`） |
| `Msc/` | QEMU `usb-storage` 种子（`TOY_USB_MSC=1`）；与 `RootFs`/`Esp` 同级 |

### 双盘 QEMU（x86）

| 盘 | QEMU 路径 | 内容 |
|----|-----------|------|
| **disk0** | `Esp/X64/` | ESP / Boot |
| **disk1** | `RootFs/X64/` | `TOYOS.ID`、`Kernel.elf`、`THEME.CFG`、用户 ELF |

Guest 侧 ToyBoot **优先**从含 `TOYOS.ID` 的卷加载 `Kernel.elf`。`$TOYOS_ROOT/Scripts/prepare-rootfs.sh` 会在启动前把 Build 产物与 `Assets/` 同步进 `RootFs/X64/`。

```bash
cd $TOYOS_ROOT/ToyKernel && ./build.sh   # 产物只拷到 ToyImage/RootFs/X64/
cd $TOYOS_ROOT && ./Scripts/run-split.sh
```

## 常用选项

```bash
$TOYOS_ROOT/Scripts/run-split.sh --help
$TOYOS_ROOT/Scripts/run-split.sh --kill-qemu             # 杀掉残留 qemu-system-x86_64（防 SIPI/AP 超时）
TOY_SMP=1 $TOYOS_ROOT/Scripts/run-split.sh               # 单核（宿主忙 / CI）
$TOYOS_ROOT/Scripts/run-split.sh --smp=2                 # 显式双核
$TOYOS_ROOT/Scripts/run-split.sh --headless              # 无 GTK 窗口，串口仍在终端
$TOYOS_ROOT/Scripts/run-split.sh --clean-nvram           # 重置 OVMF 变量盘
$TOYOS_ROOT/Scripts/smoke-boot.sh                        # 冒烟：kill + headless + TOY_SMP=1，等到 ToyOS ready
```

分辨率：改 `RootFs/X64/THEME.CFG` 的 `mode=WxH` 后 **退出 QEMU 再跑** `$TOYOS_ROOT/Scripts/run-split.sh`。

## SMP / 连环重启排查

1. `$TOYOS_ROOT/Scripts/run-split.sh --kill-qemu` 或 `pkill -9 -f qemu-system-x86_64`
2. 仍失败则 `TOY_SMP=1 $TOYOS_ROOT/Scripts/run-split.sh`
3. 内核已在 AP 超时后 **park AP 并单核继续**

## 冒烟验收

```bash
$TOYOS_ROOT/Scripts/smoke-boot.sh                 # x86 OVMF；默认 TOY_SMP=1
TOY_SMP=2 $TOYOS_ROOT/Scripts/smoke-boot.sh       # 可选双核冒烟
$TOYOS_ROOT/Scripts/smoke-virt.sh                 # Arm64+RiscV 自有 Boot 无头冒烟
$TOYOS_ROOT/Scripts/run-virt-arm.sh --headless    # / $TOYOS_ROOT/Scripts/run-virt-riscv.sh
```

成功条件：串口日志出现 `ToyOS ready`。

## 网络课默认路径（PR-N-lwip）

```bash
nc -l -p 8888

cd $TOYOS_ROOT/ToyKernel && ./build.sh
cd $TOYOS_ROOT && ./Scripts/run-split.sh
```

Guest Shell：

```text
ping 10.0.2.2
lwip on
dns 10.0.2.2
exec NETLIB.ELF
```

## 真机刷盘（NUC SSD 日常 · U 盘备选）

| 脚本 | 目标 | 说明 |
|------|------|------|
| `$TOYOS_ROOT/Scripts/sync-nuc.sh` | 本机 `LABEL=ToyOS` | **日常**；`--boot` → `/boot/efi/EFI/toyos/BOOTX64.EFI` |
| `$TOYOS_ROOT/Scripts/sync-usb.sh` | U 盘 ESP+TOYOS | **备选**；勿用来刷本机 `/boot/efi` |

```bash
# NUC SSD
$TOYOS_ROOT/Scripts/sync-nuc.sh
$TOYOS_ROOT/Scripts/sync-nuc.sh --boot              # 更新 chainloader（常需 sudo）
$TOYOS_ROOT/Scripts/sync-nuc.sh --kernel-only       # 只刷 Kernel.elf + FW/

# U 盘备选
$TOYOS_ROOT/Scripts/make-usb-stick.sh --device /dev/sdX --yes --sync
$TOYOS_ROOT/Scripts/sync-usb.sh
$TOYOS_ROOT/Scripts/sync-usb.sh --kernel-only
```

细布局见 ToyKernel `HAL/X64/NOTES-UEFI-PC.md` §2；路线图暗号 **TBN** / **TBU**。