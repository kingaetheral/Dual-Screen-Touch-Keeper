#!/system/bin/sh
# Restore the kernel default so USB power saving returns to stock.
P=/sys/module/usbcore/parameters/autosuspend
[ -w "$P" ] && echo 2 > "$P" 2>/dev/null
# Leave per-device settings alone; they reset on reboot / re-enumeration.
rm -rf /data/adb/ds_touch_keeper 2>/dev/null
