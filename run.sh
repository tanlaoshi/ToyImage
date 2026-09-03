#!/bin/bash
# 已废弃单盘启动：统一走双盘 run-split.sh（Kernel/THEME 只从第二盘 rootfs 读）
set -e
cd "$(dirname "$0")"
echo "note: run.sh -> run-split.sh (ESP + rootfs; payloads on disk1 only)" >&2
exec ./run-split.sh "$@"
