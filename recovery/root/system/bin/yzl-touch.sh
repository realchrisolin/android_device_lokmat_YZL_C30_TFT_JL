#!/system/bin/sh
# Sitronix answers a probe in the first seconds of boot. A probe minutes
# later reads chip id 0 and creates no input device. One insmod, once.
sleep 8
insmod /lib/modules/sttddi.ko
echo "recovery: sttddi insmod $?" > /dev/kmsg
