#!/bin/bash
# 把刚编好的 Kernel.elf 刷到已挂载的 TOYOS 卷
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${ROOT}/../ToyKernel/Build/HAL/X64/Kernel.elf"
if [[ ! -f "$SRC" ]]; then
  echo "missing $SRC — run: make -C ToyKernel ARCH=x86_64" >&2
  exit 1
fi
cp -f "$SRC" "$ROOT/Kernel.elf"
cp -f "$SRC" "$ROOT/rootfs/Kernel.elf"
DEST=""
for d in /media/*/TOYOS /media/"$USER"/TOYOS /run/media/"$USER"/TOYOS; do
  if [[ -d "$d" ]]; then DEST="$d"; break; fi
done
if [[ -z "$DEST" ]]; then
  echo "TOYOS not mounted. Kernel ready at $ROOT/Kernel.elf ($(stat -c%s "$SRC") bytes)"
  exit 0
fi
cp -f "$SRC" "$DEST/Kernel.elf"
sync
echo "synced $(stat -c%s "$DEST/Kernel.elf") bytes -> $DEST/Kernel.elf"
md5sum "$DEST/Kernel.elf" "$SRC"
