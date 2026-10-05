# SPDX-License-Identifier: Apache-2.0
LOCAL_PATH := device/lokmat/YZL_C30_TFT_JL

PRODUCT_PACKAGES += \
    fastbootd \
    android.hardware.boot-service.yzl

# recovery/root/ is copied into the recovery ramdisk, which this layout
# packs into vendor_boot.
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/recovery/root,$(TARGET_COPY_OUT_RECOVERY)/root)
