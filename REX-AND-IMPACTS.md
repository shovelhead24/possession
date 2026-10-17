# Alien vehicle impacts and restored T. rex — 12 October 2026

Use the existing **Rebuild Demo** desktop shortcut. F7 resets both squads and the Tyrant; the HUD shows Tyrant health and distance. Player saves and the other desktop launchers are unchanged.

## Warthog collision response

Actual rigid-body contact supplies relative velocity and contact normal. Closing speed below 3 m/s and tangential grazes do no damage. Above that threshold, damage is `(closing_speed - 3) * 12`, with a 700 ms cooldown per alien to prevent multiple chassis contact points from multiplying damage.

The launch preserves the ring-local upward direction: horizontal relative velocity is multiplied by 1.1 and capped at 24 m/s; upward speed is `clamp(2 + closing_speed * .35, 4.5, 8)` m/s. Survivors receive temporary ballistic movement. Fatal hits retain that launch in the physical ragdoll instead of losing upward momentum to the lower generic gunshot-ragdoll speed cap. The existing three-active-corpse budget remains.

The vehicle contact hook is inactive without a subscriber; only Rebuild's alien manager subscribes. Existing suspension, traction, player health and vehicle tuning are not retuned.

## T. rex restoration

Source: `C:/Games/possession/prototypes/first-operation/trex.gd`, `trex_grounding.gd` and `trex_audio.gd`. The original already handled hills. This port preserves its authored walking excerpt (frames 312–413), foot-placement/CCD solver, body tilt, seven positional sounds, sight checks, bites, up/left/right throws and slam/stomp/eat sequence. Terrain sampling and vector directions now follow the rebuild's edited collision surface and ring-local up.

One 4,000 HP Tyrant starts around +150 m arc / +110 m lateral relative to the initial vehicle spawn, patrolling a nearby four-point route. It hunts visible nearby aliens or the player. Alien plasma, player hits and combat frags can damage it. Its death persists until F7 or restart; reset releases held victims before removing actors and cannot create duplicates.

The mesh and sounds come from this checkout's existing assets, not the original installation at runtime. Source GLB data is cached for the session. Initial preparation occurs during loading when its terrain is resident. Animation advances at 60 Hz near the camera/during bites, 30 Hz at intermediate distance, and 15 Hz farther away. Simulation holds outside 300 m or when terrain is unavailable; shadow distance has 180/200 m hysteresis. No geometry is regenerated while it walks.

Its large torso/skull colliders use bounded collision-tested detours and slope checks. They do not use the alien-sized navigation grid. This is outdoor patrol steering, not general building navigation; construction remains solid. The subsequent bite fix restores the original Tyrant-only tree-trunk exceptions; see REX-BITE-FIX.md. A single retained actor avoids respawn/health discontinuities when terrain streams away.

## Validation

`check_rebuild_rex_impacts.gd` includes the existing tactical-alien regressions plus slow contact, grazing, moderate hit, cooldown, fatal ragdoll launch, a real moving Warthog chassis collision, and measured airborne ragdoll rise. It also checks source clips/audio, enemy plasma and frag damage against the Rex, walking and foot placement on a slope at ring arc 100,000 m, all four attack sequences, mouth attachment, and reset cleanup. Worst sampled foot target error: 0.0168 m.

`check_rebuild_rex_world.gd` uses all three isolated saved-world fixtures. It checks loading, actual patrol movement, rendered briefing, HUD/FPS behavior, health/reset and the one-Rex invariant. Performance samples and screenshots are in the current chat outputs. Tests use one Godot process at a time and do not mutate live player saves.

The 120 FPS target remains unmet. Short stationary samples do not establish stable 60 FPS across all driving routes, dense forest or prolonged combat. Normal forest shadows remain restored; the rejected canopy-overlap optimization was not reintroduced.

## Final saved-world performance sample

Intel UHD Graphics, Godot 4.5.1 Compatibility, 1366 x 749, uncapped, vsync off. Each case samples 360 frames after two seconds warmup, one engine instance. Same final camera; other aliens are held during isolated Rex cases, then resumed for the live encounter. The live encounter is not a sustained on-foot combat or driving benchmark.

| Case | Mean ms | FPS | p95 ms | p99 ms | Draws |
| --- | ---: | ---: | ---: | ---: | ---: |
| live_encounter | 11.20 | 89.3 | 14.98 | 16.19 | 256 |
| rex_hold | 11.49 | 87.0 | 18.48 | 24.45 | 256 |
| rex_off | 9.72 | 102.9 | 13.05 | 14.92 | 250 |
| rex_off_repeat | 9.77 | 102.4 | 13.27 | 14.76 | 250 |
| rex_walk | 11.89 | 84.1 | 15.95 | 17.84 | 256 |

In this view the walking Rex adds about 2.1 ms relative to the repeated hidden baseline, and six draw calls. Earlier short samples with a closer camera were 85–96 FPS; timing varied. These results do not prove stable 60 FPS everywhere and do not meet 120 FPS. The hold sample has a p95 above 16.67 ms. The reported Rex physics counter excludes skeleton grounding, animation, audio and rendering and is not its total frame cost.

## Shared contact reporting fix / 2026-10-16
The upward kick was intact, but only terrain_drive enabled chassis contact reports for its original Warthog. Tanks and authored Warthogs inherited zero reports, preventing actor_impact dispatch. wishbone_vehicle now sets max_contacts_reported=16 in _ready for every vehicle. Alien mass and launch tuning are unchanged. The regression no longer enables reports in its fixture; actual chassis contact, survivor damage, lethal ragdoll upward velocity and visible airborne rise passed, alongside Rex/tactical checks. Updated loading briefing rendered and visually checked. Restart required; no player saves or distribution ZIP changed.

## Impact tuning / 2026-10-16
F5 > Impacts on both vehicle types exposes minimum closing speed (0.25-8 m/s), damage per m/s above minimum (0-100), forward multiplier (0-4), and upward multiplier (0-4). Defaults: 1 m/s, 30 damage, 1.4 forward, 1.5 upward. Damage uses closing speed along the contact normal; glancing hits remain weaker. Horizontal launch caps at 48 m/s; lift scales the original 4.5-8 m/s kick. The 700 ms repeat-contact cooldown remains. Values apply immediately to the selected vehicle and use existing separate Warthog/tank tuning files. Regression covers stronger defaults and original tuning with actual collisions; isolated slider test covers values, save/load and reset. Menu and briefing visually checked. Restart required; ZIP unchanged.
