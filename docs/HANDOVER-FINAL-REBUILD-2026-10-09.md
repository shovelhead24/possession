# Final rebuild handover — 9 October 2026

## Start here

The user is happy with the current result and requested a handover for the next agent to finish rebuilding the world by restoring **models, buildings and behaviour**. Work from the approved Tree Demo, adding features incrementally while preserving performance and the terrain/vehicle/editor systems. This document is context for the next task, not a request to launch a new background task.

The user began this phase with a terrain/vehicle foundation they described as steady 120 FPS. Trees, many painted instances, lighting and shadows subsequently consumed significant frame budget. **Do not advertise the populated, shadowed world as a proven locked 120 FPS build.** The user accepted the current quality/performance compromise. Keep measuring total frame time against 8.33 ms for 120 FPS and 16.67 ms for 60 FPS, including p95/p99 and moving routes.

### Authoritative workspace and launch

- Working repository: `C:\Users\Bran the builder\Documents\Codex\2026-10-08\tree-demo`
- Branch: `tree-demo`; starting checkpoint: `6b4c047 Create isolated Tree demo starting point with saved terrain`; final work is in the subsequent closeout commit.
- Godot project: repository `game` directory; current main scene **`res://world/tree_demo.tscn`**.
- Engine: `C:\Godot\Godot_v4.5.1-stable_win64.exe`, Godot 4.5.1, GL Compatibility.
- Current viewport: 1366×768; Intel UHD Graphics was the benchmark device.
- Desktop shortcut: `C:\Users\Bran the builder\Desktop\Tree demo.lnk`.
- Shortcut verified: target above engine; arguments `--path "C:\Users\Bran the builder\Documents\Codex\2026-10-08\tree-demo\game" res://world/tree_demo.tscn`; working directory the same `game` directory.
- This conversation's deliverables: `C:\Users\Bran the builder\Documents\Codex\2026-10-08\we-x20\outputs`.
- No Godot processes were found at the handover check. Do not assume that remains true when the next task starts.

Read the repository `AGENTS.md` and `TREE-DEMO-HANDOVER.md`. The latter describes the original isolated copy, before trees were added; its startup scene description is historical. Current project configuration and shortcut point at Tree Demo.

**Keep the original terrain checkout and launcher intact:**
`C:\Users\Bran the builder\Documents\Codex\2026-09-27\we-h\work\world-foundation`.
Do not retarget `Terrain Demo.lnk`. Only update Tree demo if required, and read back its target/arguments/working directory afterward. The shared `game/mocks/dem` junction points at `C:\Games\possession\game\mocks\dem`; source DEM data is read-only for this work.

### Git and preservation

The approved tree, painting, lighting, on-foot and explicit terrain-LOD changes are included in the final checkpoint commit containing this document. The branch is `tree-demo`; resolve its latest commit with `git log -1`. The worktree also contains many modified documentation, vehicle/audio and imported-cache files from preceding work. Preserve all of it; do not reset, clean, blanket-stage or attribute every dirty file to this phase. Use explicit paths for any future checkpoint. The user subsequently requested committing and pushing this checkpoint to `origin/tree-demo`. See the latest Git state and closeout message for the resulting commit.

Git may require `git -c safe.directory='C:/Users/Bran the builder/Documents/Codex/2026-10-08/tree-demo' ...`.

## Historical context and what supersedes it

The user specifically asked to incorporate:
`C:\Users\Bran the builder\Documents\Codex\2026-10-05\read-handoff-2026-10-05-md\outputs\HANDOFF-2026-10-06.md`.
It was read for this handover. It documents the earlier feature-rich workshop and its poor performance, useful recovery sources, and optimization work. Its roughly 30 FPS results, old F4 tree toggle, 96 m orthogonal shadows, old tree tiers and original launch rules describe that workshop, **not current Tree Demo**. Its historical stop instruction does not override the user's subsequent rebuild work and current approval.

Other background:
- `C:\Users\Bran the builder\Documents\Codex\2026-10-07\co\outputs\HANDOVER-TREE-DEMO-2026-10-08.md`
- `C:\Users\Bran the builder\Documents\Codex\2026-10-07\co\outputs\HANDOVER-CONTINUOUS-TERRAIN-2026-10-08.md`
- Original workshop history: `C:\Users\Bran the builder\Documents\Codex\2026-09-27\we-h\HANDOFF-2026-10-05.md`

Current Tree Demo deliberately builds on the stable terrain/vehicle slice rather than loading the old expanded workshop wholesale.

## Current foundation and integration constraints

`tree_demo.gd` extends `terrain_drive.gd`, which extends the terrain baseline. Tree Demo adds trees, painted-tree storage, daylight, an edited-terrain render manager, on-foot movement and an extended editor. The existing Warthog controller/camera, unified DEM/SDF terrain generation, ring coordinate system, collision, streaming, satellite terrain materials and editing remain the foundation.

Relevant terrain files in `game/world`: `terrain_baseline_source.gd`, `terrain_drive_ring.gd`, `terrain_drive_stream.gd`, `terrain_drive_cuts.gd`, `terrain_drive_destruction.gd`, `terrain_drive_edit_cache.gd`, `terrain_drive_recipe.gd`, `terrain_drive_editor.gd`, `terrain_render_lods.gd`, `terrain_drive_backdrop.gd` and `terrain_drive_trace.gd`.

Use the current ring frame and local up for placements, orientations, movement and queries. Old adapters often assume `Vector3.UP`, flat X/Z ground, legacy arena fields and fixed patrol points; their interfaces require adaptation. Physics collision and fine terrain ownership must stay correct through edits and streaming. Never simplify collision merely because the render mesh has a distant LOD.

Terrain layer is 1; vehicles/trees/other solid objects commonly use layer 2 and moving characters mask 3. Adding buildings to layer 2 needs checking against on-foot clearance and vehicle collision. Keep physics resource publication on the established safe thread; worker outputs should be primitive arrays unless a new threading design is explicitly validated.

## Implemented during this phase

### Trees, LODs and instancing

Files: `tree_patch_assets.gd`, `tree_patch.gd`, `tree_paint.gd`, `tree_paint_store.gd`, `tree_paint_editor.gd`; all under `game/world`.

- Reuses `assets/realistic_fir_trees_pack_lods_gameready.zip`, with tall, medium and sapling variants.
- Mesh LOD0/1/2 plus original authored multi-plane billboard LOD3. These preserve the source atlas UVs; they are not generic full-atlas crossed quads or new multi-view impostors.
- Triangle counts LOD0/1/2/3: tall 12969/6633/3268/20; medium 6813/3598/2278/20; sapling 599/437/318/20.
- Normalized variant meshes retain matching base/height across levels. Distance selection scales with tree height: effective distance is distance × 10 / height; thresholds 22/55/110, with 4 m adjacent-band hysteresis. Cull range 650 m.
- **MultiMesh instancing is active** for painted trees. Spatial cells: 96 m for meshes, 192 m for billboard batches. Do not replace this with a node per visual tree.
- Grounding follows actual resident terrain, ring orientation and a 38-degree slope limit. Nearby trunk collision support is bounded around the vehicle, approximately 80 m.
- Static instance ownership disables physics interpolation to prevent unrelated instance slots streaking during LOD transitions.
- Black billboard/leaf-card fringes were improved by extending colour into transparent texels (`fix_alpha_edges`) before mipmap generation, with cache invalidation.
- Foliage uses alpha cutout, two-sided normals and wrapped diffuse lighting. It is not alpha-blended foliage.
- The 4K atlas is about 26% opaque overall, but used mesh UV regions have materially higher coverage (~39% leaf regions; ~44–50% billboards). Tight geometry trimming was investigated, not applied: naive trimming increased triangles substantially. No wind, cluster LOD or new camera-facing multi-view impostor system was added.

### Tree painting and persistence

F1 editor adds Paint trees / Erase trees alongside terrain tools. Mixed/Tall/Medium/Sapling, size 1–30 m with variation, density 1–12 per 100 m², radius 2–60 m. Spacing and slope/resident-ground checks bound placements. Stroke work is paced; settings are latched per stroke.

Painted-tree storage has stable IDs and ring coordinates, schema/base identity, a temporary 4096-placement limit for the entire painted save layer (not a renderer/world capacity; needs spatial streaming before large-world population), 32 undo strokes and atomic save handling. Erase removes painted trees only. Ctrl+Z/Y operates on the selected tool context; Ctrl+S saves both terrain and painted trees. Saves autoload separately. The latest analysed capture had **818 painted trees**.

### Authored-terrain LODs are an explicit editor pass

File: `tree_edited_terrain_lods.gd`. **F1 → Terrain rendering…**:
- Use distant LODs / unbuilt-edit fallback (default on).
- Build loaded terrain LODs.
- Stop after tile, plus progress/status.

No automatic simplification of edited terrain during play. The explicit pass snapshots currently loaded edited tiles; it does not traverse the entire world or automatically bake later edits. Cached results load automatically when valid. Re-editing invalidates replacement results.

Without a built render LOD, distant edits are replaced with the underlying unmodified terrain beyond 220 m from tile bounds, restoring full authored visuals within 180 m. This avoids holes while temporarily hiding authored features; collision retains authored geometry. Trees/proxies attached to hidden edited tiles are hidden too. Disabling the panel toggle forces full authored geometry at distance.

Built LODs use native screen-error index reductions while keeping full source vertices and collision. Base DEM tiles also have cached native render LODs; the edited-terrain checkbox is not a global switch for those. The coarse ring/backdrop is a separate presentation layer, not a substitute for resident terrain collision.

### Lighting and shadows — accepted current settings

Files: `tree_daylight.gd`, `tree_shadow_proxy.gd`; foliage shader `game/mocks/tree_foliage.gdshader`.

**F1 → Daylight…**, session controls:
- Sun elevation 48 degrees, azimuth -30, brightness 1.0; ambient brightness 0.48 by default.
- Near shadows now enabled by default.
- Balanced quality selected; total shadow distance **121 m**, first cascade split **12%** (~14.5 m), cascade blending **off**. These came from the user's F8 recording; user reports they work on foot and in the vehicle.
- Shadow distance slider 10–200 m; split slider 1–90%; live approximate metre readout; blending checkbox.
- Shadow edge filter: **Soft (5 samples)** default, Sharp, or Softer (13 samples).
- Compare original lighting restores original sun/ambient and disables shadows.
- Settings revert to code defaults on restart; there is no persistent lighting preset save yet.

Quality presets:
- Balanced: opaque simplified tree shadow proxies (48 triangles per tree), two cascades, 2048 atlas; selecting preset resets distance to 121 m.
- Fast: same proxies, one orthogonal cascade, 1024 atlas, resets distance to 45 m. Split/blend controls are inactive because there is only one cascade.
- Detailed: original tree LOD0/1 leaf-card/mesh shadow casters, two cascades, 2048 atlas, resets distance to 121 m.

Tree proxies are shadow-only spatial MultiMeshes, cached against tree revisions/visibility; transforms are not re-uploaded every refresh. Terrain and vehicle use their own geometry. One directional light produces the apparent sharp and soft vehicle shadow regions; there is no second vehicle blob-shadow system. No special controlled-car shadow preset was implemented.

Shadow fade starts at 75% of distance. Bias 0.3, normal bias 3.0; retaining normal bias prevents conspicuous terrain acne. The sun/ambient drive resident terrain, foliage and backdrop brightness; sky local up follows the camera's ring frame.

Last investigation: user's tree screenshot showed a sharp/soft cascade boundary and edge displacement. Enlarging near coverage spreads a fixed map over more ground and reduces sharpness. Higher 4096 resolution sharpened the Warthog but cost frame time; four cascades increased car-view draws from 487 to 706. Neither was adopted. Lower normal bias reintroduced terrain striping. Compatibility ignores the light's blur multiplier in its sampling path; the working new filter selector uses `RenderingServer.directional_soft_shadow_filter_set_quality`. Sharp reduces softness at unchanged draw count but exposes jagged pixels and some banding, so Soft remains default. Blending can soften the boundary; it does not create missing resolution. This limitation remains visible at some views and is documented, not claimed fixed completely.

No temporal dithering was implemented. Godot 4.5 Compatibility lacks TAA; temporally changing a dither mask without accumulation risks grain/shimmer. No renderer migration was attempted.

### On-foot movement restored

File: `tree_on_foot.gd`, integrated with `tree_demo.gd` and editor transitions. Adapted old capsule and vehicle-exit logic to the current ring world.

E exits/enters the Warthog; WASD walk (5 m/s), Shift sprint (9 m/s), Space jump. Capsule radius 0.35 m / height 1.8 m, eye 1.6 m. Mouse look; Esc releases cursor, click captures it. Exit checks speed (<=3 m/s), resident ground and capsule clearance among candidate positions. Entry checks proximity (~6 m), line of sight and speed. Real CharacterBody movement/collision and local gravity are active; movement respects editor/loading/streaming gates.

F1 editor returns to the foot camera on close. Driving camera/handling remain established. F9 debug tree views leave foot mode. This restores movement only: no player body mesh, viewmodel, weapons or possession/combat port in Tree Demo yet.

## Controls quick reference

| Control | Current Tree Demo action |
| --- | --- |
| F1 | Terrain + tree editor; Daylight… and Terrain rendering… panels |
| Ctrl+S | Save terrain and painted trees |
| Ctrl+Z / Ctrl+Y | Undo/redo selected editing context |
| E | Vehicle exit / enter; walking mode available |
| WASD / Shift / Space on foot | Walk / sprint / jump |
| WASD / Space / R / C driving | Drive / brake / recover / camera mode |
| F5 | Existing vehicle/camera tuning |
| F6 | Toggle painted-tree visuals |
| F9 | Three debug tree viewpoints |
| F10 | Auto → LOD0 → LOD1 → LOD2 → LOD3 → Auto |
| F11 | 120 FPS cap / uncapped |
| F8 | Start/stop diagnostic capture, including five-second pre-roll |
| F2 | Loading/briefing screen |

Avoid key conflicts when restoring weapons, possession, interaction and AI tools. The inherited briefing/HUD may still contain some historical wording; actual current input handlers are authoritative.

## Saves, diagnostics and benchmark discipline

Tree Demo user directory:
`C:\Users\Bran the builder\AppData\Roaming\Godot\app_userdata\Tree Demo`.

- Terrain: `terrain-drive-edits.json`.
- Trees: `painted-trees.json`.
- F8: `terrain-drive-traces\jitter-*.jsonl`.
- Vehicle tuning and persistent mesh/terrain caches also live under the project user directory.
- `baseline-state` in the repository contains starting snapshots; preserve it.
- Original `HaloTest` user data is a different project namespace; do not mix saves.

F8 stores frame times, draws/triangles, camera/car poses, physics/streaming state, tree/LOD/proxy counts, edited-LOD/fallback state, movement mode and lighting parameters. Events contain **nested `samples` arrays**; read those rather than looking for lighting at the JSONL event root. Latest reviewed recording: `jitter-2026-10-09T17-06-43-250487358.jsonl`; 643 frames had stable recorded settings and driving mode. Latest user acceptance followed the filter controls; no newer filter-choice recording was analysed.

Before performance runs, check for other Godot/editor instances. A console wrapper plus its spawned GUI can be one test, not two games. Do not benchmark alongside the user's playtest or close an unsaved user session. Stop only your own disposable tests. Copy saves and pass **`--drive-edits-file=<copy>`** and **`--tree-paint-file=<copy>`** after `--`. Existing benchmark scripts contain absolute output/pose paths from this conversation: review and adapt them before use. Do not purge player caches to manufacture a cold test.

Measure matched views, then re-check driving, foot movement and editing. Timing drift was substantial in some short runs; draw counts are clearer than precise percentage speedups. User's earlier ~70 FPS far from trees was not proof that shadows alone caused the cost. Distant authored terrain and backdrop were investigated separately. Explicit render LODs improved far cost; backdrop optimization remains a possible follow-up. Heavy shadows/population still consume budget.

Useful validation scripts in `game/benchmarks`: `check_tree_edges.gd`, `check_tree_paint.gd`, `check_tree_paint_editor.gd`, `check_tree_shadow_proxy.gd`, `check_explicit_terrain_lods.gd`, `check_tree_on_foot.gd`, `check_tree_on_foot_editor.gd`, `check_shadow_controls.gd`. These passed during their respective implementation stages. Last change was validated with shadow-control tests and rendered filter comparisons; this was not a fresh full-suite rerun.

Evidence in this conversation's outputs: `tree-patch-guide.md`, `tree-edge-and-trim-findings.md`, `tree-paint-guide.md`, `shadow-optimisation.md`, `distance-performance.md`, `explicit-terrain-pass-and-shadows.md`, `on-foot-guide.md`, and **`shadow-cascade-review/notes.md`** with captures/results. Older guides can describe superseded UI/defaults; this handover and current source take precedence.

## Recovering models, buildings and behaviour

The following assets were verified to exist in the current repository:
- `assets/halo_warthog.zip` (already active).
- `game/altay_main_battle_tank_fbx.glb`.
- `prototypes/first-operation/lizard_rig.glb`.
- `prototypes/first-operation/seated_driver.glb` (driver already reused).
- `assets/rigged-t-rex-fabulous/source/rigged_t-rex_fabulous.glb`.
- `assets/fp_arms.zip`.

Start by reading these **existing recovery adapters**, under `game/world`:
- `content_gallery.gd`: archive/GLTF importer and source specs.
- `arena_content.gd`: terrain-grounded content placement and source preparation.
- `arena_live_content.gd`: live actor/vehicle assembly; vehicle mesh LOD preparation, tank batching, audio, turret and gameplay initialization. Current Tree Demo imports through parts of this infrastructure; it does not run the full old setup.
- `arena_compounds.gd`: procedural FOB/building/relay geometry, preserved dimensions/openings/furniture and solid collision. The planning-table diagram is a visual; do not assume it contains mission state.
- `arena_actor.gd`: simplified workshop patrol/combat adapters.
- `arena_gameplay.gd`: weapons/viewmodel, health, combat/possession and actor management; requires adapting old arena assumptions.
- `arena_vehicles.gd`, `tank_controller.gd`, `tank_finish.gd`, `tank_tracks.gd`, `warthog_turret.gd`: vehicle interactions and detailed implementation.
- `runtime_mesh_lod.gd`, `rigid_mesh_batch.gd`, `vehicle_shadow_lod.gd`: reusable optimizations, with caveats below.

**Preferred richer alien reference**, per the user's earlier feedback:
`C:\Games\possession\prototypes\first-operation`.
Verified files: `tactical.tscn`, `study.gd`, `arena_trees.gd`, `lizard_actor.gd`, `rig_scale_bake.gd`. Read this reference without modifying/saving it. The older handoff says the alien GLB hashes matched between reference and repository; that was historical verification, not rehashed here.

Tactical aliens have baked rig scale, manual distance-based animation update rates (60/30/15/8 Hz), richer states, elite materials and ragdolls. Workshop adapters are simplified. Preserve the good behaviour, but adapt animation scale, ring movement, grounding and possession rather than copying asset-specific scale-bake constants blindly. The final expanded tactical scene had 4550 trees and was **not a proven 60 FPS baseline**.

The old workshop had roughly 598,512 source tank triangles, versus Warthog 14,484, alien 6,693 and Rex 7,594. Source totals differ from submitted distance/shadow geometry. Tank visuals alone cost about 4 ms in a historical test; do not restore the tank without checking real LOD and shadow cost.

`runtime_mesh_lod.gd` caches index-only reductions and preserves full arrays. Vehicle importing is active; skinned actor mode is optional via `--actor-mesh-lods` and still needs visual quality checks. Rigid tank batching preserves pivots/excluded moving parts, but historical batching reduced draws while increasing submitted triangles: its net benefit was not established. Inspect cached index/LOD counts before adopting it. `vehicle_shadow_lod.gd` is instantiated in old arena live setup, not automatically a current Tree Demo car feature.

Do not reintroduce the old five-layer transparent cloud stack as part of model restoration: it was a large measured rendering cost and is outside the requested final content stage unless separately chosen.

## Suggested sequence for the next agent

1. Read these sources and inspect the approved current scene, saves and controls. Record a reproducible current populated baseline before adding content; keep simulation/render/shadow costs separate.
2. Restore a small representative building/compound on ring-correct terrain. Verify doors, interior collision, sightlines, foot movement and vehicle clearance. Establish material batching, distance culling/LODs and bounded shadow rules before duplicating it across the world.
3. Restore one alien visually, then animation and behaviour from the richer tactical reference. Validate scale/rig orientation, collisions, perception, terrain edits and possession interfaces. Pace distant AI and animation work; do not run every actor fully every frame.
4. Restore viewmodel/weapons/interaction and additional vehicle content in measured increments. Resolve conflicts with E, F1, F5, camera and editor input. Keep current Warthog handling and foot/editor transitions intact.
5. Test small and stress populations with component toggles, stationary and moving measurements. Prepare expensive LOD/cache data explicitly, keeping runtime selection cheap. Report total frame budget and tail latency, plus visual/collision checks.

The objective is to recover the desired game content on the rebuilt foundation. No universal actor/building streaming, navigation, behaviour scheduler, far compound impostors or finished mission-state integration has been implemented in this phase. Design those against the current terrain/coordinate system, using the old content as a source of assets and proven interactions rather than replacing the approved foundation with the old scene.
