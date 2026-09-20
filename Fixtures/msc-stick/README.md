# QEMU usb-storage stick (PR-H-msc-8)

Used when `TOY_USB_MSC=1` with `run-split.sh` / `smoke-msc.sh`.
QEMU maps this directory as `fat:rw:msc-stick` on xHCI.

- `TOYOS.ID` — marks a ToyOS volume for `MountAllVolumes`
- `MSCDSMO.TXT` — marker file for classroom checks

Default IDE `rootfs/` still boots the system disk; this stick exercises
USB MSC auto (msc-7b): serial should show `boot: msc auto mux ok`.
