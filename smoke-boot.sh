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
    pkill -9 -f 'qemu-system-x86_64.*ToyOS' 2>/dev/null || \
        pkill -9 -f 'qemu-system-x86_64' 2>/dev/null || true
    if [ -n "${QEMU_PID:-}" ] && kill -0 "$QEMU_PID" 2>/dev/null; then
        kill -9 "$QEMU_PID" 2>/dev/null || true
        wait "$QEMU_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

if [ ! -f rootfs/Kernel.elf ] && [ ! -f Kernel.elf ]; then
    echo "error: missing Kernel.elf — build ToyKernel first" >&2
    exit 1
fi

echo "smoke: TOY_SMP=${TOY_SMP} TOY_DISK=${TOY_DISK:-ide} TOY_NET=${TOY_NET:-virtio} TOY_USB_HUB=${TOY_USB_HUB:-0} timeout=${TIMEOUT_SEC}s log=${LOG}"
rm -f "$LOG"
: >"$LOG"
./run-split.sh --kill-qemu --headless --smp="${TOY_SMP}" >"$LOG" 2>&1 &
QEMU_PID=$!

i=0
while [ "$i" -lt "$TIMEOUT_SEC" ]; do
    # 去掉 CR，避免某些 grep 把串口日志当怪异文本
    # PR-I18N2：就绪串可中/英（lang=zh →「ToyOS 就绪」）
    if tr -d '\r' <"$LOG" 2>/dev/null | grep -E 'ToyOS ready|ToyOS 就绪' >/dev/null 2>&1; then
        echo "smoke: PASS — found ToyOS ready/就绪"
        if [ "${TOY_DISK:-ide}" = "ahci" ] || [ "${TOY_DISK:-}" = "AHCI" ]; then
            if tr -d '\r' <"$LOG" | grep -F 'boot: ahci drives=' >/dev/null 2>&1; then
                echo "smoke: PASS — AHCI backend (PR-H1)"
                tr -d '\r' <"$LOG" | grep -F 'boot: ahci drives=' | tail -1 || true
            else
                echo "smoke: FAIL — TOY_DISK=ahci but no boot: ahci line" >&2
                tr -d '\r' <"$LOG" | grep -E 'ahci|block:|ata' | tail -20 >&2 || true
                exit 1
            fi
        fi
        if [ "${TOY_DISK:-ide}" = "nvme" ] || [ "${TOY_DISK:-}" = "NVME" ] || [ "${TOY_DISK:-}" = "NVMe" ]; then
            if tr -d '\r' <"$LOG" | grep -F 'boot: nvme drives=' >/dev/null 2>&1; then
                echo "smoke: PASS — NVMe backend (PR-H5)"
                tr -d '\r' <"$LOG" | grep -F 'boot: nvme drives=' | tail -1 || true
            else
                echo "smoke: FAIL — TOY_DISK=nvme but no boot: nvme line" >&2
                tr -d '\r' <"$LOG" | grep -E 'nvme|block:|ata' | tail -20 >&2 || true
                exit 1
            fi
        fi
        tr -d '\r' <"$LOG" | grep -F 'smp: APs started=' | tail -1 || true
        tr -d '\r' <"$LOG" | grep -F 'smp: continue single-CPU' | tail -1 || true
        # PR-H2：课堂 QEMU 应有 USB 键盘 ready（真机可能是 PS2）
        if tr -d '\r' <"$LOG" | grep -E 'boot: xhci-hid keyboard|boot: ps2-kbd keyboard' >/dev/null 2>&1; then
            echo "smoke: PASS — keyboard backend (PR-H2)"
            tr -d '\r' <"$LOG" | grep -E 'boot: xhci-hid keyboard|boot: ps2-kbd keyboard' | tail -1 || true
        else
            echo "smoke: WARN — no boot: *keyboard line (headless may still PASS)" >&2
        fi
        # QEMU 可见 MSI（课堂 dual 形）；真机 base=poll，dual 另刀
        if tr -d '\r' <"$LOG" | grep -E 'boot: xhci irq=msi' >/dev/null 2>&1; then
            echo "smoke: PASS — xhci irq=msi (QEMU; real-PC H-xhci-base then dual)"
        elif tr -d '\r' <"$LOG" | grep -E 'boot: xhci irq=(ioapic|poll)' >/dev/null 2>&1; then
            echo "smoke: WARN — xhci irq fallback (not msi)" >&2
            tr -d '\r' <"$LOG" | grep -E 'boot: xhci irq=' | tail -1 || true
        else
            echo "smoke: WARN — no boot: xhci irq= line" >&2
        fi
        if [ "${TOY_USB_HUB:-0}" = 1 ]; then
            if tr -d '\r' <"$LOG" | grep -F 'boot: xhci-hid via hub' >/dev/null 2>&1; then
                echo "smoke: PASS — hub keyboard (PR-H-hub)"
            else
                echo "smoke: FAIL — TOY_USB_HUB=1 but no boot: xhci-hid via hub" >&2
                tr -d '\r' <"$LOG" | grep -E 'xhci|hub' | tail -30 >&2 || true
                exit 1
            fi
        fi
        # PR-H3：默认应有 COM1（QEMU）；无则走 GOP（NO_COM1=1）
        if tr -d '\r' <"$LOG" | grep -F 'boot: COM1 serial ok' >/dev/null 2>&1; then
            echo "smoke: PASS — COM1 serial (PR-H3)"
        fi
        # PR-H4：TOY_NET=e1000 时应见 boot: e1000
        if [ "${TOY_NET:-virtio}" = "e1000" ] || [ "${TOY_NET:-}" = "E1000" ]; then
            if tr -d '\r' <"$LOG" | grep -F 'boot: e1000' >/dev/null 2>&1; then
                echo "smoke: PASS — e1000 backend (PR-H4)"
            else
                echo "smoke: FAIL — TOY_NET=e1000 but no boot: e1000 line" >&2
                tr -d '\r' <"$LOG" | grep -E 'e1000|net:|virtio' | tail -20 >&2 || true
                exit 1
            fi
        fi
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
