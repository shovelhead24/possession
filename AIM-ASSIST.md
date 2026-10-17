# CE-inspired aiming — 2026-10-15

This replaces the first, moving-reticle aim-assist pass. Restart Rebuild Demo.

The reticle stays centred. Blue means no eligible target; red means a visible
living enemy is within this weapon's assist cone and range. Red is evaluated
before spread and remains useful even with correction strength set to zero.
A red reticle does not guarantee that a shot will hit.

Correction selects the nearest visible point on existing box, sphere or capsule
collision volumes. It does not aim at a designated head/torso point. The current
aliens use simple body capsules, so this is not per-limb rendered-mesh targeting.
A direct manual hit is preserved rather than redirected elsewhere on the body.
Walls and the existing tree-obstruction checks still block acquisition and shots.

Random spread is applied after correction. Sustained fire grows per-weapon
error, which recovers between shots. Plasma stays ballistic after launch: no
automatic lead or homing. The existing hitscan weapons remain hitscan.

Controller friction scales active right-stick look near eligible targets.
Adhesion follows a bounded amount of target/player-relative angular movement,
rather than snapping the camera to the target centre. Neutral sticks disable
both effects; the radial deadzone is 18%. Mouse look bypasses both effects.
Shot correction works independently of the camera-input gate.

## Controls and saved tuning

| Input | Adjustment |
| --- | --- |
| [ / ] | Shot correction strength, 0–100% |
| Shift+[ / Shift+] | Weapon cone scale; effective angle shown in HUD |
| Ctrl+[ / Ctrl+] | Controller friction strength, 0–100% |
| Alt+[ / Alt+] | Controller tracking strength, 0–100% |

Default strengths: correction 35%, friction 40%, tracking 35%. Existing saved
correction settings are preserved. Controller adhesion is capped at 12 degrees
per second. These are demo tuning choices, not verified original Halo values.
Settings save to user://Rebuild Demo/aim-assist.cfg. Tests use an isolated file.

On foot: left stick moves, right stick looks, RT fires, A jumps, X reloads,
Y switches weapon. Mouse/keyboard controls remain available. E still handles
vehicle entry/exit; this change does not overhaul vehicle controller controls.

| Weapon | Red range | Default cone | Base / maximum spread |
| --- | ---: | ---: | ---: |
| Carbine | 85 m | 2 degrees | 0.08 / 0.35 degrees |
| Railgun | 140 m | 1 degree | 0.02 / 0.02 degrees |
| Plasma Rifle | 45 m | 3 degrees | 0.35 / 1.6 degrees |
| Doom Plasma Gun | 40 m | 3.5 degrees | 0.5 / 2 degrees |
| Halo CE Plasma Rifle | 45 m | 3 degrees | 0.3 / 1.5 degrees |

The demo mixes weapons from different games. These profiles are approximations
for this arsenal, not copied CE weapon tags. Reticles use weapon-specific simple
shapes, with an expanding plasma ring to reflect firing error.

## References and limits

The community's first-hand H1 tag documentation distinguishes per-weapon
[autoaim range/angle and controller magnetism](https://c20.reclaimers.net/h1/tags/object/item/weapon/#aim-assist)
and identifies autoaim pills. That supports the separation used here. The user
primer supplied the requested nearest-surface, post-correction spread and
input-gated controller design. We have not verified every claim about the exact
original Xbox standstill rules or percentages; this is CE-inspired behavior,
not an exact engine recreation or a claim that mouse/controller ports match.

## Validation

check_weapon_aim.gd passed: eligibility independent of correction strength;
nearest body surface; fixed centred red reticle; distinct red ranges; wall,
dead and out-of-cone rejection; post-correction spread and bloom recovery;
neutral/active stick gates; rotation cap; independent layer disabling; actual
on-foot controller input path using simulated sticks; unfiltered mouse look;
settings persistence; editor gate; real projectile launch without instant damage.

check_rebuild_weapons.gd passed existing ring-oriented shots, damage, obstruction,
ammo, cooldown, reload, switching, recapture and mode gates. Rendered weapon
reticles and the updated briefing were visually inspected. F8 now includes aim
strength, cone, range, controller settings and last-shot spread/correction.

No physical controller playtest or full-world FPS measurement was performed.
Target acquisition runs at 20 Hz, checks at most six visibility candidates and
re-evaluates at firing time. Player world saves were not changed.
