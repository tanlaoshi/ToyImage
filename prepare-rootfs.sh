#!/bin/bash
# Prepare independent TOYOS FAT dir (second IDE disk via vvfat)
set -e
cd "$(dirname "$0")"
ROOT=rootfs
mkdir -p "$ROOT"
if [ ! -f Kernel.elf ]; then
    echo "Missing Kernel.elf — build ToyKernel and copy first"
    exit 1
fi
cp -f Kernel.elf "$ROOT/Kernel.elf"
for F in HELLO.ELF COUNT.ELF FORK.ELF CAT.ELF WRITE.ELF SYSHELLO.ELF SYSFORK.ELF; do
    if [ -f "$F" ]; then cp -f "$F" "$ROOT/$F"; fi
done
printf "ToyOS root volume\n" > "$ROOT/TOYOS.ID"
echo "Prepared $ROOT:"
ls -lh "$ROOT"
