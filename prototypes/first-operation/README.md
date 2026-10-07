# FOB and sky study

The newer [tactical valley](VALLEY.md) adds grounded walking, a ridge/gully approach and enterable compound buildings. Open Launch-valley.vbs for that scene; this original study remains available.

This standalone Godot 4.5.1 greybox tests a physical planning table, two approach choices, relay connection and support acknowledgement. It also provides an outdoor material bench and a proposed slowly moving sky. It does not change the main game's renderer.

Double-click **Launch-study.vbs** on this machine to open the study without a console wrapper. The launcher reports a missing Godot installation instead of silently disappearing.

## Controls

| Control | Action |
| --- | --- |
| WASD / right mouse held | Move / look |
| Q / Z / Shift | Rise / descend / move faster |
| 1 / 2 / 3 / 4 | Planning table / outdoor view / material bench / relay |
| R near table | Select ridge or valley approach |
| E near relay | Advance hostile → secured offline → linking → operational; test shortcut, not combat |
| E near support terminal | Request support acknowledgement |
| L / B | Debug: interrupt link / toggle support availability |
| F / P | Compare original sky shader with proposed sky / freeze cloud motion |
| Tab / Escape | Hide control guide / release mouse |

Try requesting support before connecting the relay, then press 4 and use E three times. Return to the table with 1: onward links become available. Interrupting the link retains the selected approach. A working link does not guarantee available support. No strike is spawned yet.

## What is established, and what remains open

- Relay and support rules have automated state tests. The physical layout is a free-flight fixture without collision, combat, deployment or functioning rearm.
- Purple map routes show selection and onward link availability. The diagram is symbolic; route geometry, unknown-sector treatment and fresh-player readability need further work.
- Rubber, steel, paint and violet reference objects can be compared under one Godot environment. This does **not** certify the separate Blender asset-review renderer; calibration of that shared pipeline remains a production gate.
- `baseline_sky.gdshader` is copied unchanged from `game/mocks/ring_sky.gdshader`. Haze uses the current renderer's exponential expression and density 0.00001. The coarse 3,000 km circumference / 50 km width ring is a proxy, not the current DEM terrain. Full atmospheric exit, cloud cards, day/night and terrain streaming are not reproduced.
- The alternative sky is a procedural colour/motion study, not approved E3 art or a final painted sky. Distant ring geography is separate world geometry. Compare it in motion and at altitude before selecting a direction.
- Foreground camera precision requires a 0.5 m near plane here. This fixture does not solve the main game's full distance-range problem.

## Verification

With Godot's normal user-cache access:

```powershell
& 'C:\Godot\Godot_v4.5.1-stable_win64_console.exe' --headless --path . --script res://test_state.gd
& 'C:\Godot\Godot_v4.5.1-stable_win64_console.exe' --headless --path . --quit-after 3
```

For seven reproducible rendered views, launch the GUI executable with `--path` pointing here and `-- --capture` followed by an absolute output directory. Captures include offline/online planning, material references, both skies, a later cloud phase and an elevated viewpoint. Generated images and caches are not source assets.

2026-09-12: state tests passed; scene rendered on Intel UHD / OpenGL Compatibility. Initial restricted-cache launch crashed before testing. Initial camera range hid geometry; a larger near plane fixed it. High-precision world positions fixed distant haze rendering. Main terrain source files were not edited.
