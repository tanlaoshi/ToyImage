# ToyImage 快速开始（PR-Q1）

唯一推荐启动入口：**`./Scripts/run-split.sh`**（`Scripts/run.sh` 仅转发）。

## 布局（公共与架构分离）

| 路径 | 角色 |
|------|------|
| `Assets/` | 公共资源种子（Fonts/Icons/Locale/Images/Store） |
| `RootFs/{X64,Arm64,RiscV}/` | 各架构 TOYOS 系统盘 |
| `Esp/X64/` | x86 ESP（`EFI/BOOT/BOOTX64.EFI`） |
| `Fw/` | OVMF 变量盘种子（`OVMF_VARS.fd.clean`） |
| `Fixtures/` | 课堂夹具（`msc-stick/`、`store-repo/`） |
| `Scripts/` | 构建辅助 / QEMU / 冒烟 / U 盘 |

### 双盘 QEMU（x86）

| 盘 | QEMU 路径 | 内容 |
|----|-----------|------|
| **disk0** | `Esp/X64/` | ESP / Boot |
| **disk1** | `RootFs/X64/` | `TOYOS.ID`、`Kernel.elf`、`THEME.CFG`、用户 ELF |

Guest 侧 ToyBoot **优先**从含 `TOYOS.ID` 的卷加载 `Kernel.elf`。`Scripts/prepare-rootfs.sh` 会在启动前把 Build 产物与 `Assets/` 同步进 `RootFs/X64/`。

```bash
cd ../ToyKernel && ./build.sh          # 产物只拷到 ToyImage/RootFs/X64/
cd ../ToyImage  && ./Scripts/run-split.sh
```

## 常用选项

```bash
./Scripts/run-split.sh --help
./Scripts/run-split.sh --kill-qemu             # 杀掉残留 qemu-system-x86_64（防 SIPI/AP 超时）
TOY_SMP=1 ./Scripts/run-split.sh               # 单核（宿主忙 / CI）
./Scripts/run-split.sh --smp=2                 # 显式双核
./Scripts/run-split.sh --headless              # 无 GTK 窗口，串口仍在终端
./Scripts/run-split.sh --clean-nvram           # 重置 OVMF 变量盘
./Scripts/smoke-boot.sh                        # 冒烟：kill + headless + TOY_SMP=1，等到 ToyOS ready
```

分辨率：改 `RootFs/X64/THEME.CFG` 的 `mode=WxH` 后 **退出 QEMU 再跑** `./Scripts/run-split.sh`。

## SMP / 连环重启排查

1. `./Scripts/run-split.sh --kill-qemu` 或 `pkill -9 -f qemu-system-x86_64`
2. 仍失败则 `TOY_SMP=1 ./Scripts/run-split.sh`
3. 内核已在 AP 超时后 **park AP 并单核继续**

## 冒烟验收

```bash
./Scripts/smoke-boot.sh                 # x86 OVMF；默认 TOY_SMP=1
TOY_SMP=2 ./Scripts/smoke-boot.sh       # 可选双核冒烟
./Scripts/smoke-virt.sh                 # Arm64+RiscV 自有 Boot 无头冒烟
./Scripts/run-virt-arm.sh --headless    # / ./Scripts/run-virt-riscv.sh
```

成功条件：串口日志出现 `ToyOS ready`。

## 网络课默认路径（PR-N-lwip）

```bash
nc -l -p 8888

cd ../ToyKernel && ./build.sh
cd ../ToyImage  && ./Scripts/run-split.sh
```

Guest Shell：

```text
ping 10.0.2.2
lwip on
dns 10.0.2.2
exec NETLIB.ELF
```

## 真机 U 盘（PR-H0）

```bash
./Scripts/make-usb-stick.sh --device /dev/sdX --yes --sync
./Scripts/sync-usb.sh              # 同步 Boot + RootFs/X64
./Scripts/sync-usb.sh --kernel-only  # 只刷 Kernel.elf
```
