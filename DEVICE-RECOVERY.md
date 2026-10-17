# Controller disconnects and audio routing — 2026-10-15

Evidence preserved in controller-audio-disconnects.log before test launches.
The captured game log contains seven selections of No controller and 17 WASAPI
output-device invalidations, plus a HIDAPI device-disconnected error. The input
endpoint repeatedly switches between native DualSense and virtual XInput. The
latest F8 capture contains 47 fired shots (counter 37 to 84), so the weapon
system was still processing firing. F8 did not previously record audio output
or device selection, so precise audio/disconnect correlation is unavailable.

This is evidence of real device loss, not proof that the USB cable is faulty.
A cable, port, controller connection or driver/virtual-device issue could cause
it. The physical and virtual controller both disappearing warrants trying a
known-good data cable/port or Bluetooth.

## Implemented
- Game output defaults explicitly to Realtek, as requested. Runtime test selected
  Speakers (3- Realtek(R) Audio), independently of the DualSense audio endpoint.
- F5 > Devices selects controller source: Auto, Native DualSense, XInput only.
  Native bypasses the virtual DS4Windows endpoint in this game. No DS4 profile,
  Windows default audio setting, driver or Bluetooth pairing was changed.
- Auto retains a connected device instead of replacing it whenever virtual
  XInput reappears. Explicit Native/XInput modes do not silently fail over.
- Device preferences save separately to user://Rebuild Demo/devices.cfg.
  Test override: --devices-file=<isolated config>.
- Audio output is selectable in the same tab; unavailable preference is reported.
- F8 now includes audio preference/output, controller id/name and selection changes.

Restart Rebuild Demo to load the changes. Then choose F5 > Devices > Native
DualSense to try direct USB. A faulty physical connection can still disconnect.
To test without the USB cable, pair via Windows Bluetooth: controller off and
USB unplugged, hold Create + PS until flashing, then add the controller in
Windows Settings > Bluetooth & devices. Once paired, Native mode can use it.
Sony supports DualSense USB/Bluetooth on PC and notes its headset jack requires
USB; Realtek PC audio avoids that limitation.
Source: https://www.playstation.com/en-au/support/hardware/pair-dualsense-controller-bluetooth/

Validation: actual Realtek selection, audio-name matching, preference persistence,
rendered Devices UI, native/virtual exclusivity, stable Auto selection and prior
controller regressions passed. Briefing rendered and visually inspected. Bluetooth
pairing, actual audio audibility and cable diagnosis still need user-side checks.
