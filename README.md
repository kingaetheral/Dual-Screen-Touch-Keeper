Dual Screen Touch Keeper
A Magisk module that stops the touchscreen on the Retroid Dual Screen Add-On from going dead after a minute of inactivity.
The picture stays. Touch doesn't. Tap it and nothing happens — until you unplug and replug the cable, or poke it before the timeout hits. This module fixes that.
What's actually going wrong
The Dual Screen sends video over DisplayPort Alt Mode and touch over USB. Same cable, two completely separate paths — which is why the display keeps working while touch dies.
The touch controller enumerates as a normal USB device:
Code
And Android's USB power management puts it to sleep. On the Odin 3, that device ships with a 60,000 ms autosuspend delay, sitting on top of a kernel-wide default of 2 seconds. Once the touch controller goes idle past that window, the kernel suspends it and it drops off the bus. The video feed never notices, because it isn't USB.
That's the whole bug. It isn't the accessory being faulty, and it isn't something AYN or Retroid needs to patch — it's stock Linux power management doing exactly what it was told.
What the module does
Three layers, so it holds up whether the screen is attached at boot or plugged in later:
Sets the kernel-wide USB autosuspend default to -1, so anything that enumerates from then on never gets a suspend timer in the first place.
Writes on to the touch controller's power/control (and -1 to its autosuspend delay), which is the documented way to pin a USB device awake.
Runs a 20-second watchdog, because a device plugged in after boot enumerates with kernel defaults — not your settings. Unplug and replug the screen as much as you like; it gets re-applied.
By default it targets the Dual Screen by USB ID rather than blanket-disabling autosuspend across the board. Your other USB devices keep their power saving.
Requirements
Rooted Android device with Magisk
Retroid Dual Screen Add-On, or another USB-C touch display
Confirmed working on the AYN Odin 3. The mechanism is generic Linux USB power management, so it should apply to any Android device with the same problem — but the Odin 3 is what it's been tested on.
Install
Flash the zip in Magisk → Modules → Install from storage
Reboot
Connect the Dual Screen
That's it. No configuration needed if you're using the Retroid accessory.
Verifying it works
Code
With the screen connected you should see:
Code
CONTROL reading on for the RDS Touchscreen is the one that matters. The root hubs staying on auto is correct — they're meant to be left alone.
Then the real test: leave the screen untouched for a few minutes and tap it.
Configuration
Everything lives in /data/adb/ds_touch_keeper/config.conf:
Setting
Purpose
TARGET_MODE
match (by USB ID, default), hid (any HID device), or all
MATCH_IDS
Space-separated vid:pid list. Defaults to 222a:0001
SET_GLOBAL_DEFAULT
Set the kernel-wide autosuspend default to -1
POLL_INTERVAL
Watchdog interval in seconds. 0 disables it
VERBOSE
Log every device touched, not just changes
Using a different USB-C touch display? Find its ID with:
Code
then add vid:pid to MATCH_IDS. Or just set TARGET_MODE=all and skip the lookup.
Logs are at /data/adb/ds_touch_keeper/keeper.log.
Trade-offs
Keeping a USB device out of suspend costs a little power. It's minor — and the Dual Screen is already drawing from your handheld while it's attached — but it isn't free, which is why the module targets one device by ID instead of pinning the whole bus awake.
If touch still drops after installing this and status.sh shows control=on, then host-side power management isn't your problem and the accessory is sleeping on its own firmware. Nothing on the Android side will fix that one.
Uninstall
Remove it in Magisk and reboot. The kernel default is restored and per-device settings reset on re-enumeration.
Credits
Diagnosed and built for the AYN Odin 3 community. Thanks to the folks in #odin3 who kept poking at this instead of writing it off as broken hardware.
License
MIT