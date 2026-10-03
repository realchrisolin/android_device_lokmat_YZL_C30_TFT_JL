# SPDX-License-Identifier: Apache-2.0
DEVICE_PATH := device/lokmat/YZL_C30_TFT_JL

include $(DEVICE_PATH)/BoardConfigHeader.mk

# Refuse to configure a flashable image while the header is still a placeholder.
ifneq ($(filter UNSET,$(BOARD_BOOT_HEADER_VERSION) $(BOARD_PAGE_SIZE) $(BOARD_KERNEL_BASE) $(BOARD_KERNEL_OFFSET) $(BOARD_RAMDISK_OFFSET) $(BOARD_TAGS_OFFSET) $(BOARD_DTB_OFFSET) $(BOARD_DTB_SIZE) $(BOARD_HEADER_SIZE) $(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE) $(BOARD_BOOTIMAGE_PARTITION_SIZE) $(BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE) $(BOARD_DTBOIMG_PARTITION_SIZE) $(BOARD_VENDOR_RAMDISK_USE_LZ4)),)
$(error YZL_C30_TFT_JL: BoardConfigHeader.mk still contains UNSET. Fill it from this unit, then re-run scripts/check-headers.sh. This tree does not pack vendor_boot yet)
endif

ifeq ($(wildcard $(DEVICE_PATH)/prebuilt/dtb),)
$(error YZL_C30_TFT_JL: prebuilt/dtb is missing. It has to come from this unit.)
endif

ifeq ($(BOARD_VENDOR_RAMDISK_USE_LZ4),true)
BOARD_RAMDISK_USE_LZ4 := true
endif

# Architecture. ro.product.cpu.abi on the watch is arm64-v8a.
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic

# Platform string is mt6768. The SoC reported by the watch is MT6769V/CB.
TARGET_BOARD_PLATFORM := mt6768
TARGET_BOOTLOADER_BOARD_NAME := YZL_C30_TFT_JL
TARGET_NO_BOOTLOADER := true
TARGET_NO_KERNEL := true
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb

# No recovery partition. Stock vendor_boot already carries the recovery
# ramdisk: entry 0 is the platform ramdisk (6,213,182 bytes, LZ4) and entry 1
# is named "recovery" (17,543,336 bytes, LZ4). A TWRP vendor_boot replaces
# that recovery entry and has to keep the platform ramdisk. boot is a v4
# image with a gzip kernel and an empty ramdisk. init_boot is a v4 image with
# an LZ4 generic ramdisk and no kernel. Both stay stock.
# Slot _b of boot, vendor_boot, init_boot, and dtbo is erased (all zeros).
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT := true

# Slot _a vendor_boot has two ramdisks. The built TWRP ramdisk replaces only
# the recovery entry. The platform entry is this unit's first-stage ramdisk
# (fstab plus the modules named in modules.load.recovery, including the
# ST7102 panel). It is copied byte for byte. Normal boot loads that entry.
# The build adds the recovery fragment itself (type RECOVERY, name recovery).
# Do not also tag the default ramdisk as recovery.
BOARD_VENDOR_RAMDISK_FRAGMENTS := platform
BOARD_VENDOR_RAMDISK_FRAGMENT.platform.PREBUILT := $(DEVICE_PATH)/prebuilt/vendor_ramdisk_platform.lz4
BOARD_VENDOR_RAMDISK_FRAGMENT.platform.MKBOOTIMG_ARGS := --ramdisk_type PLATFORM

# This build does not derive page size, header version, load offsets, or the
# DTB path for vendor_boot. These match slot _a.
BOARD_KERNEL_PAGESIZE := 4096
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb $(DEVICE_PATH)/prebuilt/dtb

AB_OTA_UPDATER := true
# Names only. Sizes are not set, and this target does not pack those images.
AB_OTA_PARTITIONS += \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    system \
    system_ext \
    vendor \
    product \
    vendor_dlkm \
    odm_dlkm \
    system_dlkm
# BOARD_USES_RECOVERY_AS_BOOT stays unset. GKI recovery lives in vendor_boot.

# Verified boot is present and was green and locked when this tree was written.
# Key paths are intentionally omitted. A custom vendor_boot needs a vbmeta
# decision that is separate from this tree.
BOARD_AVB_ENABLE := true

BOARD_FLASH_BLOCK_SIZE := 262144

# super is mmcblk0p45. Its size is still unknown, so this tree does not build
# a super image or the logical partition images. Those mounts are erofs on
# the watch. Userdata and metadata are f2fs.
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_USERIMAGES_USE_F2FS := true
TARGET_USERIMAGES_USE_EXT4 := true

# File-based encryption v2 plus metadata encryption. Not tested in recovery.
BOARD_USES_METADATA_PARTITION := true
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
# libtar links the legacy AIDL *-ndk_platform stubs (android.security.apc and
# the keystore2 family). This tree only emits those modules when this is set.
NEED_AIDL_NDK_PLATFORM_BACKEND := true
# This twrp-14.1 tree's release config is Android 14. Do not override
# PLATFORM_VERSION here: version_util.mk rejects PLATFORM_VERSION_LAST_STABLE,
# and the CTS check only has a release list for 14. The watch is Android 15.
# ro.build.version.security_patch on this unit.
PLATFORM_SECURITY_PATCH := 2025-06-05
VENDOR_SECURITY_PATCH := 2025-06-05

TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab

# Physical framebuffer is 480x640 at 60 Hz, density 180. The Android UI override
# is rotation 3, so the watch face is landscape. Panel EDID is the MTKDEV
# placeholder and is not a size source.
TW_THEME := portrait_mdpi
TW_ROTATION := 270
TW_EXTRA_LANGUAGES := false
TW_DEFAULT_LANGUAGE := en
TARGET_SCREEN_WIDTH := 480
TARGET_SCREEN_HEIGHT := 640

TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true
TW_INCLUDE_RESETPROP := true
TW_EXCLUDE_APEX := true

# Confirmed present as files under /vendor/lib/modules on this unit.
# The panel module panel_st7102_480x640_tft_vdo.ko is loaded while Android is
# running. Its path was not readable from the shell (likely vendor_dlkm).
# Leave the loader disabled until those blobs are copied into prebuilt/modules
# from this unit. A missing insmod aborts recovery boot.
# TW_LOAD_VENDOR_MODULES := "wiite_corp.ko wiite_con.ko sttddi.ko gpio_keys.ko mtk_disp_sec.ko"
# TW_LOAD_VENDOR_BOOT_MODULES := true

# Stock boot cmdline is empty. This string is the vendor_boot cmdline.
# vendor_boot bootconfig_size is 0.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2
