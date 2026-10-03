#!/bin/sh
# Exit 0 only when BoardConfigHeader.mk has no UNSET placeholders and a
# non-empty prebuilt DTB from this unit is present.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
header="$root/BoardConfigHeader.mk"
missing=0

keys="
BOARD_BOOT_HEADER_VERSION
BOARD_PAGE_SIZE
BOARD_KERNEL_BASE
BOARD_KERNEL_OFFSET
BOARD_RAMDISK_OFFSET
BOARD_TAGS_OFFSET
BOARD_DTB_OFFSET
BOARD_DTB_SIZE
BOARD_HEADER_SIZE
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE
BOARD_BOOTIMAGE_PARTITION_SIZE
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE
BOARD_DTBOIMG_PARTITION_SIZE
BOARD_VENDOR_RAMDISK_USE_LZ4
"

for key in $keys; do
    line=$(grep -E "^${key} := " "$header" || true)
    if [ -z "$line" ]; then
        echo "missing assignment: $key"
        missing=1
        continue
    fi
    val=${line#"$key := "}
    val=$(printf '%s' "$val" | tr -d '[:space:]')
    if [ -z "$val" ] || [ "$val" = "UNSET" ]; then
        echo "unset: $key"
        missing=1
    fi
done

if [ ! -s "$root/prebuilt/dtb" ]; then
    echo "missing: prebuilt/dtb from this unit's vendor_boot or boot image"
    missing=1
fi

if [ "$missing" -ne 0 ]; then
    echo "header check failed"
    exit 1
fi

echo "header check passed"
exit 0
