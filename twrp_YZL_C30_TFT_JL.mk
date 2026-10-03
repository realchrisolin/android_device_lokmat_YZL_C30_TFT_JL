# SPDX-License-Identifier: Apache-2.0
# TWRP product for the LOKMAT APPLLP 9 MAX (YZL_C30_TFT_JL).
# Lunch name: twrp_YZL_C30_TFT_JL-eng

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, device/lokmat/YZL_C30_TFT_JL/device.mk)

PRODUCT_DEVICE := YZL_C30_TFT_JL
PRODUCT_NAME := twrp_YZL_C30_TFT_JL
PRODUCT_BRAND := alps
PRODUCT_MODEL := APPLLP 9 MAX
PRODUCT_MANUFACTURER := LOKMAT

PRODUCT_RELEASE_NAME := YZL_C30_TFT_JL
