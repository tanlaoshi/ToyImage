#!/bin/bash
# PR-Q1：无头冒烟 — 清残留 QEMU、默认单核、等到串口出现 ToyOS ready
set -eu
cd "$(dirname "$0")"

export TOY_KILL_QEMU=1
export TOY_HEADLESS=1
export TOY_NO_HOSTFWD=1
export TOY_SMP="${TOY_SMP:-1}"
TIMEOUT_SEC="${SMOKE_TIMEOUT:-90}"
LOG="${SMOKE_LOG:-/tmp/toyos-smoke-$$.log}"

cleanup() {
    if [ -n "${QEMU_PID:-}" ] && kill -0 "$QEMU_PID" 2>/dev/null; then
        kill -9 "$QEMU_PID" 2>/dev/null || true
        wait "$QEMU_PID" 2>/dev/null || true
    fi
    # 只杀本日志对应实例较难；冒烟结束清掉本机 ToyOS QEMU
    pkill -9 -f 'qemu-system-x86_64.*ToyOS' 2>/dev/null || \
        pkill -9 -f 'qemu-system-x86_64' 2>/dev/null || true
}
trap cleanup EXIT

if [ ! -f rootfs/Kernel.elf ] && [ ! -f Kernel.elf ]; then
    echo "error: missing Kernel.elf — build ToyKernel first" >&2
    exit 1
fi

echo "smoke: TOY_SMP=${TOY_SMP} timeout=${TIMEOUT_SEC}s log=${LOG}"
rm -f "$LOG"
./run-split.sh --kill-qemu --headless --smp="${TOY_SMP}" >"$LOG" 2>&1 &
QEMU_PID=$!

i=0
while [ "$i" -lt "$TIMEOUT_SEC" ]; do
    # 去掉 CR，避免某些 grep 把串口日志当怪异文本
    if tr -d '\r' <"$LOG" 2>/dev/null | grep -F 'ToyOS ready' >/dev/null 2>&1; then
        echo "smoke: PASS — found 'ToyOS ready'"
        tr -d '\r' <"$LOG" | grep -F 'smp: APs started=' | tail -1 || true
        tr -d '\r' <"$LOG" | grep -F 'smp: continue single-CPU' | tail -1 || true
        exit 0
    fi
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        wait "$QEMU_PID" || true
        echo "smoke: FAIL — QEMU exited before ready" >&2
        tail -n 40 "$LOG" >&2 || true
        exit 1
    fi
    i=$((i + 1))
    sleep 1
done

echo "smoke: FAIL — timeout waiting for ToyOS ready" >&2
tail -n 60 "$LOG" >&2 || true
exit 1
