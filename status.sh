#!/system/bin/sh
#
# Dual Screen Touch Keeper - status helper
# Run with:  su -c 'sh /data/adb/modules/ds_touch_keeper/status.sh'
#
# Shows every USB device and whether autosuspend is disabled on it.
# Run this with the dual screen CONNECTED to confirm it's covered.

echo "=== Dual Screen Touch Keeper - status ==="
echo

P=/sys/module/usbcore/parameters/autosuspend
if [ -f "$P" ]; then
  echo "kernel usbcore autosuspend default : $(cat "$P" 2>/dev/null)   (-1 = disabled, good)"
else
  echo "kernel usbcore autosuspend default : (not present)"
fi
echo

printf "%-10s %-10s %-8s %-7s %s\n" "DEVICE" "VID:PID" "CONTROL" "DELAY" "PRODUCT"
printf "%-10s %-10s %-8s %-7s %s\n" "------" "-------" "-------" "-----" "-------"

found=0
for d in /sys/bus/usb/devices/*/; do
  [ -f "$d/idVendor" ] || continue
  found=$((found + 1))
  name=$(basename "$d")
  vid=$(cat "$d/idVendor" 2>/dev/null)
  pid=$(cat "$d/idProduct" 2>/dev/null)
  ctl=$(cat "$d/power/control" 2>/dev/null || echo "?")
  dly=$(cat "$d/power/autosuspend_delay_ms" 2>/dev/null || echo "?")
  prod=$(cat "$d/product" 2>/dev/null)
  printf "%-10s %-10s %-8s %-7s %s\n" "$name" "$vid:$pid" "$ctl" "$dly" "$prod"
done

echo
echo "Devices found: $found"
echo "CONTROL should read 'on' for every device (that means autosuspend off)."
echo
echo "--- recent log ---"
tail -n 15 /data/adb/ds_touch_keeper/keeper.log 2>/dev/null || echo "(no log yet)"
