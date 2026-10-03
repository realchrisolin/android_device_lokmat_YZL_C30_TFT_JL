Place files extracted from this serial here. Leave the directory empty until then.

- `dtb` — the 148,134-byte DTB from this unit's `vendor_boot_a`, already extracted. `scripts/check-headers.sh` requires this file.
- `vendor_ramdisk_platform.lz4` — the platform ramdisk from that same image, 6,213,182 bytes, LZ4 legacy. The recovery build copies it unchanged into the new `vendor_boot`.
- `modules/` — `sttddi.ko`, `gpio_keys.ko`, `wiite_con.ko`, `wiite_corp.ko`, `mtk_disp_sec.ko`, and the ST7102 panel module. The first five were listed in `/vendor/lib/modules`. The panel module was loaded and its path was not readable from the shell.

Do not drop in images from another APPLLP 9 MAX, and do not use the APPLLP 5 MAX recovery image.
