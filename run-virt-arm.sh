#!/bin/bash
# QEMU virt aarch64 验收（PR-V6）— 入口在 ToyImage；内核 ../ToyKernel
# 自有 Boot：-kernel + DTB loader + ramfb/virtio；不是 run-split.sh / AAVMF。
set -e
cd "$(dirname "$0")"
BOARD=virt
# shellcheck source=run-virt-common.sh
source ./run-virt-common.sh

TOY_VIRT_ARCH=arm64
TOY_VIRT_MAKE_ARCH=arm64
TOY_VIRT_HAL_ARCH=Arm64
export TOY_VIRT_MAKE_ARCH TOY_VIRT_HAL_ARCH
TOY_VIRT_ELF="${TOY_VIRT_ELF:-Build/HAL/Arm64/Kernel.elf}"
TOY_VIRT_QEMU="${QEMU_AARCH64:-qemu-system-aarch64}"
TOY_VIRT_HELLO_PAT='ToyOS Arm64 virt: hello'

toy_virt_main "$@"
