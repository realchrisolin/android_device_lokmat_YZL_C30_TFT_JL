#!/bin/bash
# Repack vendor_boot from the already-built TWRP recovery cpio plus the
# recovery/root overlay. The platform ramdisk is the stock bytes, unchanged.
# Does not flash.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -ne 1 || ! -f $1 ]]; then
    echo "usage: $0 stock-vendor_boot.img" >&2
    exit 1
fi
STOCK=$1
# The device tree sits at device/<vendor>/<device> inside the Android tree.
# ANDROID_BUILD_TOP is that tree after envsetup. Otherwise walk up to it.
if [[ -n ${ANDROID_BUILD_TOP:-} && -f $ANDROID_BUILD_TOP/build/envsetup.sh ]]; then
    TREE=$ANDROID_BUILD_TOP
else
    TREE=$ROOT
    while [[ $TREE != / && ! -f $TREE/build/envsetup.sh ]]; do
        TREE=$(dirname "$TREE")
    done
    if [[ ! -f $TREE/build/envsetup.sh ]]; then
        echo "ANDROID_BUILD_TOP is unset and build/envsetup.sh was not found above $ROOT" >&2
        exit 1
    fi
fi
# lunch sets OUT to the product directory. The fallback is envsetup's default.
PRODUCT_OUT=${OUT:-$TREE/out/target/product/YZL_C30_TFT_JL}
CPIO_LZ4="$TREE/out/target/product/YZL_C30_TFT_JL/obj/PACKAGING/vendor_ramdisk_fragments_intermediates/recovery.cpio.lz4"
PLATFORM="$ROOT/prebuilt/vendor_ramdisk_platform.lz4"
DTB="$ROOT/prebuilt/dtb"
MKBOOTIMG="$TREE/system/tools/mkbootimg/mkbootimg.py"
VERIFY="$ROOT/scripts/verify-vendor-boot.py"
WORK="${TMPDIR:-/tmp}/yzl-pack-$$"
UNPADDED="$PRODUCT_OUT/vendor_boot_twrp_YZL_C30_TFT_JL_debug.img"
IMAGE="$PRODUCT_OUT/vendor_boot_twrp_YZL_C30_TFT_JL_debug_64m.img"
FP="alps/vnd_YZL_C30_TFT_JL/YZL_C30_TFT_JL:15/AP3A.240905.015.A2/mp1V13742:user/test-keys"

mkdir -p "$WORK/ramdisk" "$PRODUCT_OUT"
lz4 -d -f "$CPIO_LZ4" "$WORK/recovery.cpio"
( cd "$WORK/ramdisk" && cpio -idm < "$WORK/recovery.cpio" )
cp -a "$ROOT/recovery/root/." "$WORK/ramdisk/"
chmod 755 "$WORK/ramdisk/system/bin/yzl-bootlog.sh"
chmod 755 "$WORK/ramdisk/system/bin/yzl-touch.sh"
# Rebuilt recovery init. IsEnforcing() goes permissive when yzl-bootlog.sh
# is present. The cpio snapshot does not contain that rebuild.
INIT_BIN="$TREE/out/target/product/YZL_C30_TFT_JL/recovery/root/system/bin/init"
if [[ ! -f "$INIT_BIN" ]]; then
    echo "missing $INIT_BIN" >&2
    exit 1
fi
# The Oct 2 recovery init ignores the marker and stays enforcing. Refuse it.
if ! grep -a -q 'yzl-bootlog.sh' "$INIT_BIN"; then
    echo "init has no yzl-bootlog marker check: $INIT_BIN" >&2
    exit 1
fi
cp -a "$INIT_BIN" "$WORK/ramdisk/system/bin/init"
chmod 755 "$WORK/ramdisk/system/bin/init"
# These are DT_NEEDED by recovery and libtar. They were linked from
# out/system/lib64 but never installed into the recovery ramdisk, so the
# binary exits before the UI. Copy the closure that readelf found missing.
LIB64="$TREE/out/target/product/YZL_C30_TFT_JL/system/lib64"
PLATFORM_LIBS=(
    android.hardware.confirmationui-V1-ndk.so
    android.hardware.security.keymint-V1-ndk_platform.so
    android.hardware.security.keymint-V3-ndk.so
    android.hardware.security.keymint-V3-ndk_platform.so
    android.hardware.security.rkp-V3-ndk.so
    android.hardware.security.secureclock-V1-ndk_platform.so
    android.security.aaid_aidl-cpp.so
    android.security.apc-ndk_platform.so
    android.security.authorization-ndk_platform.so
    android.security.maintenance-ndk_platform.so
    android.system.keystore2-V1-ndk_platform.so
    android.system.keystore2-V4-ndk.so
    android.system.keystore2-V4-ndk_platform.so
    android.system.suspend-V1-ndk.so
)
mkdir -p "$WORK/ramdisk/system/lib64"
for lib in "${PLATFORM_LIBS[@]}"; do
    if [[ ! -f "$LIB64/$lib" ]]; then
        echo "missing $LIB64/$lib" >&2
        exit 1
    fi
    cp -a "$LIB64/$lib" "$WORK/ramdisk/system/lib64/$lib"
done
# newc headers need root ownership. GNU cpio writes that without being root.
( cd "$WORK/ramdisk" && find . -print | sed 's|^\./||;/^$/d' | sort | cpio -o -H newc --owner=0:0 > "$WORK/recovery-debug.cpio" )
lz4 -l -9 -f "$WORK/recovery-debug.cpio" "$WORK/recovery.cpio.lz4"
python3 "$MKBOOTIMG" \
    --vendor_boot "$WORK/vendor_boot.img" \
    --header_version 4 \
    --base 0x40000000 \
    --pagesize 4096 \
    --kernel_offset 0x00080000 \
    --ramdisk_offset 0x07c80000 \
    --tags_offset 0x0bc80000 \
    --dtb_offset 0x0bc80000 \
    --vendor_cmdline "bootopt=64S3,32N2,64N2" \
    --dtb "$DTB" \
    --vendor_ramdisk "$PLATFORM" \
    --ramdisk_type RECOVERY \
    --ramdisk_name recovery \
    --vendor_ramdisk_fragment "$WORK/recovery.cpio.lz4"
cp -f "$WORK/vendor_boot.img" "$UNPADDED"
cp -f "$WORK/vendor_boot.img" "$IMAGE"
avbtool add_hash_footer \
    --image "$IMAGE" \
    --partition_size 67108864 \
    --partition_name vendor_boot \
    --hash_algorithm sha256 \
    --algorithm NONE \
    --prop "com.android.build.vendor_boot.fingerprint:${FP}"
python3 "$VERIFY" "$STOCK" "$UNPADDED"
python3 "$VERIFY" "$STOCK" "$IMAGE"
echo "packed $IMAGE"
rm -rf "$WORK"
