#!/system/bin/sh
# Snapshot recovery boot state. USB may never enumerate, so the latest
# snapshot is also written to the last 1 MiB of expdb. The start of expdb
# is left alone. A host can find the text by searching for YZLLOG1.

KMSG=/dev/kmsg
PART=/dev/block/by-name/expdb
LOG=/tmp/yzl-boot.log
SLOT=/tmp/yzl-slot
TAIL=1048576
MIN_PART=8388608

logk() {
    echo "recovery: $1" > "$KMSG"
}

logk "yzl-bootlog start"

setprop sys.usb.configfs 1
setprop sys.usb.controller musb-hdrc
setprop sys.usb.ffs.aio_compat 0

n=0
while [ ! -b "$PART" ] && [ "$n" -lt 30 ]; do
    n=$((n + 1))
    sleep 1
done

SEQ=0
while true; do
    SEQ=$((SEQ + 1))
    {
        echo YZLLOG1
        echo "seq=$SEQ"
        echo "---- props ----"
        getprop ro.boot.mode
        getprop ro.boot.force_normal_boot
        getprop ro.boot.hardware
        getprop ro.debuggable
        getprop sys.usb.controller
        getprop sys.usb.config
        getprop sys.usb.configfs
        getprop sys.usb.state
        getprop init.svc.adbd
        getprop init.svc.recovery
        echo "---- cmode ----"
        cat /sys/class/udc/musb-hdrc/device/cmode 2>&1
        echo "---- nodes ----"
        ls -l /dev/dri /dev/graphics /sys/class/drm /sys/class/udc /dev/block/by-name/expdb 2>&1
        echo "---- ps ----"
        ps -A 2>&1
        echo "---- dmesg ----"
        dmesg 2>&1 | tail -n 300
        echo "---- logcat ----"
        logcat -d -t 150 2>&1
        echo "---- recovery.log ----"
        tail -n 150 /tmp/recovery.log 2>&1
        echo YZLLOGEND
    } > "$LOG" 2>&1

    if [ -b "$PART" ]; then
        BYTES=$(blockdev --getsize64 "$PART" 2>/dev/null)
        if [ -n "$BYTES" ] && [ "$BYTES" -ge "$MIN_PART" ]; then
            START=$(( (BYTES - TAIL) / 4096 * 4096 ))
            SEEK=$((START / 4096))
            if [ $((START + TAIL)) -le "$BYTES" ]; then
                dd if=/dev/zero of="$SLOT" bs=1024 count=1024 2>/dev/null
                dd if="$LOG" of="$SLOT" bs=1024 conv=notrunc 2>/dev/null
                dd if="$SLOT" of="$PART" bs=4096 seek="$SEEK" count=256 conv=notrunc 2>/dev/null
                logk "expdb snapshot $SEQ bytes=$BYTES seek=$SEEK"
            else
                logk "expdb tail does not fit bytes=$BYTES"
            fi
        else
            logk "expdb size refused bytes=${BYTES:-unknown}"
        fi
    else
        logk "expdb node missing snapshot $SEQ"
    fi
    sleep 3
done
