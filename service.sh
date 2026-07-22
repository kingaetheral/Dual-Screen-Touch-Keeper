#!/system/bin/sh
#
# Dual Screen Touch Keeper - boot service
#
# Problem: on USB-C external displays (Retroid Dual Screen and similar),
# video travels over DisplayPort Alt Mode while touch travels over USB.
# Linux/Android USB autosuspend puts the idle touch controller to sleep
# after a short delay, so the picture stays but touch goes dead until
# something wakes the bus.
#
# Fix: prevent the USB subsystem from autosuspending. Per the kernel docs,
# writing "on" to power/control or -1 to power/autosuspend_delay_ms both
# stop a device from being autosuspended.
#
# Because a device that is plugged in AFTER boot enumerates with the kernel
# default, this runs a light watchdog so hotplugging the screen still works.

MODDIR=${0%/*}
PERSIST=/data/adb/ds_touch_keeper
CONF="$PERSIST/config.conf"
LOG="$PERSIST/keeper.log"

# ---- defaults (overridden by config) ----
ENABLE=1
TARGET_MODE=match
MATCH_IDS="222a:0001"
SET_GLOBAL_DEFAULT=1
POLL_INTERVAL=20
BOOT_DELAY=25
LOG_MAX_KB=64
VERBOSE=0

mkdir -p "$PERSIST" 2>/dev/null

log() {
  echo "$(date '+%m-%d %H:%M:%S') $1" >> "$LOG" 2>/dev/null
  # trim if oversized
  sz=$(wc -c < "$LOG" 2>/dev/null || echo 0)
  if [ "$((sz / 1024))" -gt "${LOG_MAX_KB:-64}" ]; then
    tail -c $(( LOG_MAX_KB * 512 )) "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
  fi
}

vlog() { [ "${VERBOSE:-0}" = "1" ] && log "$1"; }

# ---- wait for boot ----
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done

[ -f "$CONF" ] && . "$CONF"
[ "${ENABLE:-1}" = "1" ] || exit 0

sleep "${BOOT_DELAY:-25}"

: > "$LOG"
log "=== Dual Screen Touch Keeper started ==="
log "mode=$TARGET_MODE global=$SET_GLOBAL_DEFAULT poll=${POLL_INTERVAL}s"

# ---------------------------------------------------------------
# 1. Kernel-wide default: newly enumerated devices never autosuspend
# ---------------------------------------------------------------
set_global_default() {
  P=/sys/module/usbcore/parameters/autosuspend
  if [ -w "$P" ]; then
    cur=$(cat "$P" 2>/dev/null)
    if [ "$cur" != "-1" ]; then
      if echo -1 > "$P" 2>/dev/null; then
        log "usbcore autosuspend default: $cur -> -1"
      else
        log "WARN: could not write $P (read-only on this kernel)"
      fi
    fi
  else
    log "NOTE: $P not writable/present - relying on per-device writes"
  fi
}

# ---------------------------------------------------------------
# 2. Per-device: write 'on' to power/control (and -1 to the delay)
# ---------------------------------------------------------------
id_matches() {
  # $1 = device sysfs dir. True if its vid:pid is in MATCH_IDS.
  vid=$(cat "$1/idVendor" 2>/dev/null)
  pid=$(cat "$1/idProduct" 2>/dev/null)
  [ -n "$vid" ] && [ -n "$pid" ] || return 1
  for want in $MATCH_IDS; do
    [ "$want" = "$vid:$pid" ] && return 0
  done
  return 1
}

has_hid() {
  # true if this usb device has any interface with bInterfaceClass 03 (HID)
  for i in "$1"/*:*/bInterfaceClass; do
    [ -f "$i" ] || continue
    [ "$(cat "$i" 2>/dev/null)" = "03" ] && return 0
  done
  return 1
}

apply_pass() {
  changed=0
  for d in /sys/bus/usb/devices/*/; do
    # only real devices (they expose idVendor); skip interface nodes
    [ -f "$d/idVendor" ] || continue

    case "${TARGET_MODE:-match}" in
      match) id_matches "$d" || continue ;;
      hid)   has_hid   "$d" || continue ;;
      all)   : ;;   # no filter
    esac

    ctl="$d/power/control"
    dly="$d/power/autosuspend_delay_ms"
    name=$(basename "$d")

    if [ -w "$ctl" ]; then
      if [ "$(cat "$ctl" 2>/dev/null)" != "on" ]; then
        if echo on > "$ctl" 2>/dev/null; then
          prod=$(cat "$d/product" 2>/dev/null)
          vid=$(cat "$d/idVendor" 2>/dev/null)
          pid=$(cat "$d/idProduct" 2>/dev/null)
          log "kept awake: $name ($vid:$pid) ${prod:+- $prod}"
          changed=$((changed + 1))
        fi
      else
        vlog "already on: $name"
      fi
    fi

    # Belt and braces. Some drivers reject this with an I/O error; harmless.
    if [ -w "$dly" ]; then
      [ "$(cat "$dly" 2>/dev/null)" != "-1" ] && echo -1 > "$dly" 2>/dev/null
    fi
  done
  return $changed
}

[ "${SET_GLOBAL_DEFAULT:-1}" = "1" ] && set_global_default

apply_pass
log "initial pass complete"

# ---------------------------------------------------------------
# 3. Watchdog - catches the screen being plugged in after boot
# ---------------------------------------------------------------
if [ "${POLL_INTERVAL:-20}" -gt 0 ] 2>/dev/null; then
  log "watchdog running every ${POLL_INTERVAL}s"
  while true; do
    sleep "$POLL_INTERVAL"
    [ -f "$CONF" ] && . "$CONF"
    [ "${ENABLE:-1}" = "1" ] || { log "disabled via config - watchdog exiting"; exit 0; }
    apply_pass
  done
else
  log "watchdog disabled (POLL_INTERVAL=0) - boot-time only"
fi
