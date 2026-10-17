# Rebuild weapons — 10 October 2026

Open **Rebuild Demo** from the desktop. The original Carbine, Railgun, first-person arms and firing sounds are restored on the rebuild scene.

| Action | Control |
| --- | --- |
| Leave / enter Warthog | E |
| Fire / hold to repeat | Left mouse |
| Cycle weapons | Q |
| Carbine / Railgun | 1 / 2 |
| Reload | R |
| Release cursor | Esc |
| Reopen briefing | F2 |

Carbine holds 30 rounds, fires every 0.18 seconds, deals 25 damage to compatible targets and reaches 250 m. Railgun holds 5 rounds, fires every second, deals 120 damage and reaches 600 m. Reload takes 1.5 seconds with unlimited reserve ammunition, matching the previous weapon setup. Recoil, shot traces, impact flashes, audio, crosshair and ammunition display are included.

Driving, construction editing, the briefing, vehicle tuning and unavailable terrain block firing. The first click after releasing the cursor only recaptures it. Construction keeps its own Q/E rotation controls. Switching modes cancels an unfinished reload.

The loading screen now presents this build's weapons, controls and current scope. Its initialization was fixed so the revised briefing is actually read before the UI is created. Future feature changes must update this screen, per SOP.

Shots stop at terrain and physics objects. Additional per-shot tests preserve obstruction by distant construction and painted tree trunks without adding distant physics bodies. Door/window openings and ramp slopes retain their real shapes. Ordinary scenery is not assigned weapon damage; enemies and possession are still a later restoration phase.

The weapon viewport reuses its rendered image while idle, refreshes during recoil/reload/switching, and stops rendering when holstered. Effects use bounded, reused geometry. Original archive assets remain unchanged.

Validation covers actual model imports and visible briefing text, firing/damage, reload/ammo/cooldowns, ring-aligned aiming, nearby and distant obstruction, editor input isolation, cursor recapture, vehicle transitions and idle viewport caching. See weapons-validation.json for the final rendered run and stationary frame measurements. Those short measurements do not establish a 120 FPS route average.

Implementation: game/world/rebuild_weapons.gd and weapon_obstruction.gd, integrated only through rebuild_demo.gd. Test scripts: check_rebuild_weapons.gd, check_weapon_obstruction.gd and check_rebuild_weapons_integration.gd under game/benchmarks. Tests use separate terrain/tree/construction saves.

Final rendered run: PASS on Intel UHD Graphics at 1366 × 749. Stationary 240-frame samples after 60 warm-up frames: overlay hidden 98.75 FPS; Carbine idle 93.66 FPS; Carbine firing 81.10 FPS; Railgun idle 87.29 FPS. This does not meet the 120 FPS target. Sequential short samples are subject to scene/driver timing drift and are not a controlled route benchmark. Startup was approximately 64 seconds including original archive imports. The diagnostic FPS shown in early screenshots includes startup and is not the settled benchmark result.

## Plasma Rifle — 2026-10-10
Weapon 3 is the user's halo_-_plasma_rifle.glb copied into assets. Q now cycles all three weapons. Initial workshop settings are 100 shots, 0.12 s interval, 14 damage, 200 m range; existing 1.5 s reload/refill and plasma sound. Read COLLISION-INSPECTION.md for the combined update.


## Plasma facing, sound and sprites — 2026-10-10
The Plasma Rifle now faces 180 degrees from the previous import, uses the user's Terminator plasma MP3, and renders bounded cyan-white billboard muzzle/bolt/impact effects. Read PLASMA-EFFECTS.md. Its damage remains instant-hit; the travelling bolts are visual.

