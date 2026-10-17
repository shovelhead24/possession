# Collision inspection and Plasma Rifle — 10 October 2026

Launch **Rebuild Demo** from its existing desktop shortcut after restarting.

- **Tab:** hide HUD text and crosshair, retaining a small FPS counter. Press again to restore. Editor menus remain usable.
- **F1 → Loaded collision wireframe:** toggle in either the terrain/tools menu or construction menu. The setting stays enabled when returning to play.
- **Wire colours:** cyan terrain, gold static scenery, pink dynamic bodies. These are lines from the loaded physics shapes, not inferred from visible render meshes. Disabled/unloaded shapes disappear, moving bodies update, and newly loaded geometry is added progressively. Initial wireframe generation and drawing can lower FPS; turn it off for performance measurements.
- **3:** Plasma Rifle. **1:** Carbine. **2:** Railgun. **Q:** cycle all three. **LMB:** fire. **R:** reload.
- **F8:** start a recording including five seconds of history; press again to finish.

## Confirmed construction cause and fix

The wheel suspension ray mask was 1 | 4. Construction uses layer 2. The chassis collided with floors and ramps but wheel rays ignored them, allowing the vehicle to sink onto its chassis and get stuck. Rebuild Demo now explicitly uses 1 | 2 | 4 for its suspension. Other scenes retain their existing default. Diagnostic contact probes use the actual suspension mask and vehicle-up direction.

Both supplied recordings show zero grounded wheels throughout: 418 vehicle samples in the 11:51:21 clip and 386 in the 11:51:58 clip, mostly with four chassis contacts. Replaying their rays against the saved construction yields 0 contacts with the old mask and 852/1672 plus 1529/1544 ray contacts with the corrected mask. These are rays from an already sunk/moving vehicle, so not every old ray is expected to hit after replay.

A controlled test confirms 0 → 4 wheel contacts on both floor and ramp geometry at a distant, rotated ring location. A rendered test also settled the real imported Warthog on the copied player platform with all four tyres contacting layer 2.

## Mountain seam finding

The saved mountain is near arc 409 / lateral 468, radius 120 m and height 110 m. The recordings are near construction around arc 0 / lateral 200, so they do not capture that mountain's seam.

An audit rebuilt all four mountain tiles from a copy of the current terrain save. All four full-detail collision face arrays exactly matched the render face arrays. There is no separately coarsened near collision mesh in this path.

The visible normals are smoothed, while physical contact uses planar triangle normals. In the sampled outer band (80–105% of mountain radius), the 95th percentile physical face slope was 65.6 degrees; the 95th percentile shading/face normal difference was 10.9 degrees, with larger outliers. This supports inspecting real facets rather than assuming a visually rounded surface has rounded collision. The vehicle also uses one downward ray per tyre, not a swept tyre volume, so sharp transitions can produce abrupt support changes. A bounce at a particular seam is not proven solely by this audit. Mountain geometry and suspension force tuning were left unchanged for inspection.

Distant edited-terrain visual LOD/fallback can intentionally differ from collision beyond its display threshold; close inspection uses the full edited surface. Wheel visuals themselves are not collision shapes and therefore do not appear as tyre hulls in the wireframe.

## Plasma Rifle

Copied the requested Downloads GLB into this rebuild's assets, preserving the original file. Added a first-person pose, cyan shot effect, existing plasma firing sound, and the common mode/input safeguards. Initial workshop settings: 100 shots, 0.12 s fire interval, 14 damage, 200 m range, 1.5 s refill with unlimited reserve. These use the rebuild's existing reload system; no heat/overheat mechanic was introduced. Idle view rendering is cached like the other weapons.

## Validation

- Construction layer A/B test passed on floor and ramp.
- Real Warthog platform support passed with four tyre contacts.
- HUD/menu isolation, both wireframe switches, moving/disabled/unloaded geometry, wireframe-only surfaces and cleanup checked in a rendered scene with isolated saves.
- Three-weapon firing/damage, ammo, reload and Q cycling passed.
- Loading-screen SOP updated and the actual UI rendered.

See collision-investigation.json, construction-suspension.log, collision-ui.log and the accompanying screenshots. Player terrain, trees and construction saves were not changed. No new 120 FPS claim is made.
