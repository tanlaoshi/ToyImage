#!/bin/bash
# sync-usb.sh — 把当前 ToyImage / 构建产物同步到已挂载的 ESP + TOYOS 分区
#
# 真机布局（见 make-usb-stick.sh）：
#   ESP   → EFI/BOOT/BOOTX64.EFI
#   TOYOS → rootfs/（Kernel.elf、TOYOS.ID、THEME、Assets、*.ELF…）
#
# 用法：
#   ./sync-usb.sh                 # 自动找 LABEL=ESP 与 LABEL=TOYOS
#   ./sync-usb.sh --build         # 先编 Kernel + Boot，再 prepare-rootfs，再同步
#   ./sync-usb.sh --kernel-only   # 只更新 TOYOS/Kernel.elf（快迭代）
#   TOY_ESP_MNT=/mnt/esp TOY_TOYOS_MNT=/mnt/toy ./sync-usb.sh
#
# 兼容旧单分区：若只有 TOYOS、没有 ESP，则把 EFI 也写进 TOYOS（单 FAT 布局）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DO_BUILD=0
KERNEL_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    --build|-b) DO_BUILD=1; shift ;;
    --kernel-only|-k) KERNEL_ONLY=1; shift ;;
    *)
      echo "unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

find_label_mnt() {
  local Label="$1"
  local Dev Mnt
  Dev="$(blkid -L "$Label" 2>/dev/null || true)"
  if [[ -z "$Dev" ]]; then
    return 1
  fi
  Mnt="$(lsblk -ln -o MOUNTPOINT "$Dev" 2>/dev/null | awk 'NF{print; exit}')"
  if [[ -z "$Mnt" || "$Mnt" == "-" ]]; then
    return 1
  fi
  printf '%s\n' "$Mnt"
}

ESP_MNT="${TOY_ESP_MNT:-}"
TOY_MNT="${TOY_TOYOS_MNT:-}"

if [[ -z "$ESP_MNT" ]]; then
  ESP_MNT="$(find_label_mnt ESP || true)"
fi
if [[ -z "$ESP_MNT" ]]; then
  ESP_MNT="$(find_label_mnt EFI || true)"
fi
if [[ -z "$TOY_MNT" ]]; then
  TOY_MNT="$(find_label_mnt TOYOS || true)"
fi

# 常见自动挂载路径兜底
if [[ -z "$TOY_MNT" ]]; then
  for d in /media/*/TOYOS /media/"${USER:-tank}"/TOYOS /run/media/"${USER:-tank}"/TOYOS; do
    if [[ -d "$d" ]]; then TOY_MNT="$d"; break; fi
  done
fi
if [[ -z "$ESP_MNT" ]]; then
  for d in /media/*/ESP /media/"${USER:-tank}"/ESP /run/media/"${USER:-tank}"/ESP \
           /media/*/EFI /media/"${USER:-tank}"/EFI; do
    if [[ -d "$d" ]]; then ESP_MNT="$d"; break; fi
  done
fi

if [[ -z "$TOY_MNT" ]]; then
  echo "error: TOYOS volume not mounted (label TOYOS)." >&2
  echo "  Format: $ROOT/make-usb-stick.sh --yes --sync" >&2
  echo "  Or mount the TOYOS partition and re-run." >&2
  exit 1
fi

if [[ ! -d "$TOY_MNT" || ! -w "$TOY_MNT" ]]; then
  echo "error: TOYOS mount not writable: $TOY_MNT" >&2
  exit 1
fi

SINGLE_FAT=0
if [[ -z "$ESP_MNT" ]]; then
  SINGLE_FAT=1
  ESP_MNT="$TOY_MNT"
  echo "note: no ESP mount — writing EFI into TOYOS (single-FAT layout)"
elif [[ ! -w "$ESP_MNT" ]]; then
  echo "error: ESP mount not writable: $ESP_MNT" >&2
  exit 1
fi

echo "ESP   -> $ESP_MNT"
echo "TOYOS -> $TOY_MNT"

if [[ "$DO_BUILD" -eq 1 ]]; then
  echo "== build Kernel =="
  (cd "$ROOT/../ToyKernel" && ./build.sh)
  echo "== build Boot =="
  if [[ -x "$ROOT/../ToyBoot/build.sh" ]]; then
    (cd "$ROOT/../ToyBoot" && ./build.sh)
  else
    echo "warning: ToyBoot/build.sh missing; keep existing BOOTX64.EFI" >&2
  fi
fi

if [[ "$KERNEL_ONLY" -eq 1 ]]; then
  SRC=""
  for C in \
    "$ROOT/../ToyKernel/Build/HAL/X64/Kernel.elf" \
    "$ROOT/rootfs/Kernel.elf" \
    "$ROOT/Kernel.elf"
  do
    if [[ -f "$C" ]]; then SRC="$C"; break; fi
  done
  if [[ -z "$SRC" ]]; then
    echo "error: no Kernel.elf — build first or drop --kernel-only" >&2
    exit 1
  fi
  cp -f "$SRC" "$TOY_MNT/Kernel.elf"
  sync
  echo "synced Kernel.elf ($(stat -c%s "$TOY_MNT/Kernel.elf") bytes)"
  md5sum "$SRC" "$TOY_MNT/Kernel.elf"
  exit 0
fi

echo "== prepare-rootfs =="
(cd "$ROOT" && ./prepare-rootfs.sh)

BOOT_EFI="$ROOT/EFI/BOOT/BOOTX64.EFI"
if [[ ! -f "$BOOT_EFI" ]]; then
  echo "error: missing $BOOT_EFI — build ToyBoot" >&2
  exit 1
fi

echo "== sync ESP (Boot) =="
mkdir -p "$ESP_MNT/EFI/BOOT"
cp -f "$BOOT_EFI" "$ESP_MNT/EFI/BOOT/BOOTX64.EFI"
# 可选：若仓库有 startup.nsh 等可在此追加
sync

echo "== sync TOYOS (rootfs) =="
# FAT 无 Unix owner/mode；勿用纯 -a（会 chown 失败 → exit 23）
if command -v rsync >/dev/null 2>&1; then
  rsync -rltD --delete \
    --no-owner --no-group --no-perms \
    --exclude 'System Volume Information' \
    --exclude '.Trash*' \
    --exclude 'lost+found' \
    "$ROOT/rootfs/" "$TOY_MNT/"
else
  # 粗同步：先拷文件，不 --delete（避免误删用户在 U 盘上的笔记）
  cp -a "$ROOT/rootfs/." "$TOY_MNT/"
fi

# 单 FAT 时 EFI 已在上面写入同一卷
if [[ "$SINGLE_FAT" -eq 1 ]]; then
  mkdir -p "$TOY_MNT/EFI/BOOT"
  cp -f "$BOOT_EFI" "$TOY_MNT/EFI/BOOT/BOOTX64.EFI"
fi

# 确保识别文件存在
if [[ ! -f "$TOY_MNT/TOYOS.ID" ]]; then
  printf "ToyOS root volume\n" > "$TOY_MNT/TOYOS.ID"
fi

sync
echo
echo "=== sync done ==="
echo "ESP BOOTX64.EFI : $(stat -c%s "$ESP_MNT/EFI/BOOT/BOOTX64.EFI") bytes"
echo "TOYOS Kernel    : $(stat -c%s "$TOY_MNT/Kernel.elf") bytes"
ls -lh "$TOY_MNT/Kernel.elf" "$TOY_MNT/TOYOS.ID" "$TOY_MNT/THEME.CFG" 2>/dev/null || true
echo
echo "Boot Menu: select this USB (UEFI). Expect GOP desktop / ToyOS ready."
