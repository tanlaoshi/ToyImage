ToyOS FW/ — wireless firmware blobs (classroom)

IWL8265.UCODE
  Chip: Intel Wireless 8265/8275 (PCI 8086:24fd)
  Source: host /lib/firmware/intel/iwlwifi/iwlwifi-8265-36.ucode.zst
          (linux-firmware; decompressed, API rev 36)
  Size: ~2.3 MiB
  SHA256: 1336afcd028ed094d1fe33893c84c273bb5711be52970040344a75a12f276d56
  License: Intel redistributable firmware via linux-firmware (NOT ToyOS code).
           Do not claim as original; keep this notice with the blob.
  Guest path: FW/IWL8265.UCODE  (FileSystemReadFile)

Driver loads this in PR-N-wifi-1 (Iwl). Missing file → soft-fail, desktop OK.
