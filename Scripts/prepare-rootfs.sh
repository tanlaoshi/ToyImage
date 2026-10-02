#!/bin/bash
# 兼容入口 → Scripts/lib 或 ToyKernel/OpenBox/Scripts/lib
set -euo pipefail
# shellcheck source=_exec-lib.sh
. "$(cd "$(dirname "$0")" && pwd)/_exec-lib.sh"
toyos_exec_lib "prepare-rootfs.sh" "$@"
