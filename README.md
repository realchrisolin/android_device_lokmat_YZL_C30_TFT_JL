# TWRP device tree for the LOKMAT APPLLP 9 MAX

Board `YZL_C30_TFT_JL`, product `vnd_YZL_C30_TFT_JL`, platform `mt6768`.
The SoC on the unit this tree was written from is MT6769V/CB. Android 15,
kernel `6.6.66-android15-8-g9b6ad5b4b813-ab13433063-4k`.

This is a source tree for a recovery ramdisk packed into `vendor_boot`.
The watch has no `recovery` partition. `init_boot` is the generic ramdisk and
stays stock. `boot` stays stock. Nothing here is a bootable image yet.

The APPLLP 5 MAX tree (`full_WP_C17S_PIX_TFT_D4`, MT6762/MT6765, Android 10)
is a different device.

## What was read off the watch

On 2026-10-02, over adb, while the bootloader was locked:

- Slot `_a`. Dynamic partitions and virtual A/B with compression are on.
  `ro.boot.force_normal_boot=1`.
- Logical `system`, `system_ext`, `vendor`, `product`, `vendor_dlkm`,
  `odm_dlkm`, and `system_dlkm` are erofs. `/` is erofs. `metadata`
  (`mmcblk0p12`) and `userdata` are f2fs. Userdata uses file-based encryption
  v2 (`aes-256-xts:aes-256-cts:v2`) and metadata encryption.
- Framebuffer is 480×640 at 60 Hz, density 180. The UI override is rotation 3.
  The panel EDID string is the MTKDEV placeholder.
- `panel_st7102_480x640_tft_vdo` and `sttddi` are loaded. Module files visible
  in `/vendor/lib/modules` include `sttddi.ko`, `gpio_keys.ko`, `wiite_con.ko`,
  `wiite_corp.ko`, and `mtk_disp_sec.ko`. The panel module path was not readable.
- Security patch `2025-06-05`. Verified boot was green. `sys.oem_unlock_allowed`
  was 0.

Slot `_a` images were read on 2026-10-02.
`BoardConfigHeader.mk` and `prebuilt/dtb` come from those files.

- `boot_a` is a version 4 image, 64 MiB. The kernel is gzip and the ramdisk
  is empty. Page size is 4096.
- `init_boot_a` is a version 4 image, 8 MiB. No kernel. The generic ramdisk
  is LZ4.
- `vendor_boot_a` is a version 4 image, 64 MiB, header size 2128. Cmdline is
  `bootopt=64S3,32N2,64N2`. Bootconfig is empty. Both ramdisk entries are LZ4:
  a platform ramdisk and a ramdisk named `recovery`. The DTB is 148,134 bytes
  and starts with a big-endian dt table followed by an FDT.
- `dtbo_a` is 8 MiB. Its table is big-endian, one entry, total size 54,369
  bytes.
- Slot `_b` of all four partitions is zeros.

`BOARD_SUPER_PARTITION_SIZE` and `BOARD_MAIN_SIZE` are not set. They are not
in these images, and packing `vendor_boot` does not need them.

The platform ramdisk from `vendor_boot_a` is `prebuilt/vendor_ramdisk_platform.lz4`.
The build must copy that blob unchanged and use it as ramdisk type PLATFORM.
The TWRP ramdisk is a second entry, type RECOVERY, name `recovery`. Replacing
the platform entry would remove first-stage modules and the first-stage fstab.

## Build gate

`BoardConfig.mk` stops the build while a header field is `UNSET`.
`scripts/check-headers.sh` checks the same list and also requires a non-empty
`prebuilt/dtb` taken from this unit.

```sh
scripts/check-headers.sh
```

When that passes, this directory belongs at `device/lokmat/YZL_C30_TFT_JL`
inside a [twrp-14.1](https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp/tree/twrp-14.1)
tree. The lunch target is `twrp_YZL_C30_TFT_JL-eng`. The image target is
`vendorbootimage`, because that is where this layout puts the recovery ramdisk.

Decryption, touch, and the panel are configured from the running system and
have not been tested in recovery. `TW_LOAD_VENDOR_MODULES` stays commented
until the module files from this unit are in `prebuilt/modules/`.

Radio-identity partitions are not in `recovery.fstab`.
