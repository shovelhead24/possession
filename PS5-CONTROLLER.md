# PS5 / DS4Windows controller restored — 2026-10-15

Restart Rebuild Demo with DS4Windows running. The running game has not been
closed or restarted automatically.

The original lighting_test_controller.gd explicitly documented unreliable
InputEventJoypadButton delivery with DS4Windows and PS5 controllers. Rebuild
now uses that polling/edge-detection approach for buttons, sticks and triggers.
It prefers the virtual XInput/Xbox endpoint and consumes raw duplicate events.
It falls back to the native controller when no virtual endpoint is present.

Hardware discovery in a normal Godot window detected:
- Device 0: DualSense Wireless Controller.
- Device 1: XInput Controller (Xbox 360 virtual device).
DS4Windows was running. The headless probe returned zero controllers, so it
was not used to infer connection failure. We did not change DS4Windows profiles
or driver settings. Physical movement/button presses have not been playtested.

| PS5 control | Action |
| --- | --- |
| Left stick | Walk / steer |
| Right stick | Look, including vehicle camera orbit |
| Cross | Jump; enter ready loading briefing |
| R2 | Fire / vehicle accelerator |
| L2 | Vehicle brake, then reverse |
| Circle | Vehicle brake |
| Square | Reload; enter nearby vehicle or exit current vehicle |
| Triangle | Switch weapon |
| L1 | Combat grenade |
| Hold L3 | Sprint |
| Create | Toggle information overlays, same as Tab |
| Options | Release / capture cursor |

Tab and Create preserve the on-foot aiming reticle while hiding information.
Menus/editor/vehicle transitions still gate weapon presentation normally.
After capturing the cursor or changing mode, release R2 before firing.
Connection changes refresh selection; losing focus releases controller firing
and movement ownership. Mouse/keyboard input can take over without duplicate
controller actions. The controller isn't a full editor/menu navigation rewrite.

Validation: check_rebuild_controller.gd passed virtual/native selection, polled
button edges, trigger levels, focus loss and rearm, reload/vehicle interaction,
Create/Tab reticle alpha preservation, duplicate suppression and mouse takeover.
check_weapon_aim.gd passed existing aim tests plus visible reticle/hidden ammo
with HUD hidden. The clean reticle and updated briefing were rendered and
visually inspected; rebuild_demo.gd passed script checking. Player saves unchanged.
