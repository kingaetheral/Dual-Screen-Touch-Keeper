#!/system/bin/sh
CONF_DIR=/data/adb/ds_touch_keeper

ui_print "*************************************"
ui_print "  Dual Screen Touch Keeper v1.0.0"
ui_print "  by KingAether"
ui_print "*************************************"
ui_print " "
ui_print "- Keeps USB touch digitizers awake on"
ui_print "  USB-C external displays."
ui_print " "

mkdir -p "$CONF_DIR"
if [ -f "$CONF_DIR/config.conf" ]; then
  ui_print "- Existing config kept."
else
  cp -f "$MODPATH/config.conf" "$CONF_DIR/config.conf"
  ui_print "- Default config installed."
fi

# Report what the kernel currently does, so the user has a baseline
GP=/sys/module/usbcore/parameters/autosuspend
if [ -f "$GP" ]; then
  ui_print "- Kernel usbcore autosuspend: $(cat "$GP" 2>/dev/null)"
else
  ui_print "- Kernel usbcore param not present (per-device mode)"
fi

ui_print " "
ui_print "- Config : $CONF_DIR/config.conf"
ui_print "- Log    : $CONF_DIR/keeper.log"
ui_print "- Status : su -c 'sh $MODPATH/status.sh'"
ui_print " "
ui_print "- Reboot, then connect the dual screen."
ui_print " "

chmod 755 "$MODPATH/service.sh" "$MODPATH/status.sh"
