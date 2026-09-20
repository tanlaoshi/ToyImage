#!/bin/bash
# QEMU virt riscv64 验收（PR-V6）— 入口在 ToyImage；内核 ../ToyKernel
# 自有 Boot：OpenSBI + -kernel；不是 run-split.sh / RiscVVirt EDK2。
set -e
cd "$(dirname "$0")"
BOARD=virt
# shellcheck source=run-virt-common.sh
source ./run-virt-common.sh

TOY_VIRT_ARCH=riscv
TOY_VIRT_MAKE_ARCH=riscv
TOY_VIRT_HAL_ARCH=RiscV
export TOY_VIRT_MAKE_ARCH TOY_VIRT_HAL_ARCH
TOY_VIRT_ELF="${TOY_VIRT_ELF:-Build/HAL/RiscV/Kernel.elf}"
TOY_VIRT_QEMU="${QEMU_RISCV64:-qemu-system-riscv64}"
TOY_VIRT_HELLO_PAT='ToyOS RiscV virt: hello'

toy_virt_main "$@"
