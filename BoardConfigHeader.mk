# SPDX-License-Identifier: Apache-2.0
# Measured from this unit's slot _a images on 2026-10-02.
# Slot _b of all four partitions is zeros. Do not use it as a second firmware.
#
# vendor_boot load addresses use base 0x40000000:
#   kernel  0x40080000
#   ramdisk 0x47c80000
#   tags    0x4bc80000
#   dtb     0x4bc80000
# Partition sizes are the dumped file sizes.

BOARD_BOOT_HEADER_VERSION := 4
BOARD_PAGE_SIZE := 4096
BOARD_KERNEL_BASE := 0x40000000
BOARD_KERNEL_OFFSET := 0x00080000
BOARD_RAMDISK_OFFSET := 0x07c80000
BOARD_TAGS_OFFSET := 0x0bc80000
BOARD_DTB_OFFSET := 0x0bc80000
BOARD_DTB_SIZE := 148134
BOARD_HEADER_SIZE := 2128

BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_DTBOIMG_PARTITION_SIZE := 8388608

# super and the main group size are not in these images. They stay undefined.
# vendorbootimage does not need them. Do not invent a size from another device.

# vendor_boot ramdisks and the init_boot ramdisk are LZ4 (magic 0x184C2102).
# The boot kernel is gzip. boot stays stock, so that does not change this flag.
BOARD_VENDOR_RAMDISK_USE_LZ4 := true
