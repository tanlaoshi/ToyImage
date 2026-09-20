#!/bin/bash
# PR-H-msc-8：QEMU usb-storage 冒烟（验 msc-7b Live auto mux）
#   TOY_USB_MSC=1 ./smoke-boot.sh
# 须已有 Kernel.elf；通过条件：ToyOS ready + boot: msc auto mux ok + keyboard
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$IMAGE_ROOT"
export TOY_USB_MSC=1
exec "$SCRIPT_DIR/smoke-boot.sh" "$@"
