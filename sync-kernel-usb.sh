#!/bin/bash
# sync-kernel-usb.sh — 兼容入口：转发到 sync-usb.sh --kernel-only
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec "$ROOT/sync-usb.sh" --kernel-only "$@"
