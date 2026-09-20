#!/bin/bash
# PR-V6：Arm + RiscV virt 无头冒烟（CI）— 入口在 ToyImage
set -e
cd "$(dirname "$0")"

BOARD=virt
export BOARD

echo "=== Arm64 virt --headless ==="
./run-virt-arm.sh --headless
echo "=== RiscV virt --headless ==="
./run-virt-riscv.sh --headless
echo "smoke-virt: PASS"
