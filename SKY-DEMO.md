# Sky comparison scene — 2026-10-16

Branch `sky-demo` was created from the current `tree-demo` checkout, retaining all
existing modified and untracked Rebuild work. No commit or push was made.
`game/world/sky_demo.tscn` extends the complete current Rebuild scene. The new
desktop shortcut is **Sky Demo**. Its four layout overrides point at separate,
hash-verified copies in `%APPDATA%/Godot/app_userdata/Sky Demo`. Other shortcuts
are unchanged. Tuning and caches retain the existing Tree Demo namespace.

The default remains the Rebuild sky with all added clouds off. Ctrl+F3 opens
individual sky/cloud toggles and presets; Ctrl+F12 cycles presets. Ctrl+F9 toggles
the painterly sky; Ctrl+F10 toggles the ring deck. The panel is also reachable
through F1 > Daylight. Settings are session-only.

## Available comparisons

1. Rebuild baseline.
2. Billboard clouds: original procedural FBM cylindrical cards.
3. Marching cubes: original density field, tables, resolution and surface shader.
4. Legacy three layers: original flat FBM planes, placed in the local ring tangent.
5. Ring five layers: current curved deck and original fresh-weather tuning.
6. Painterly sky: the procedural study, with local ring-up adaptation.
7. Marching cubes near + billboards farther away.
8. Billboards + ring cirrus preset.
9. Marching cubes + billboards + ring cirrus preset.

Individual switches allow further combinations, including painterly with any
cloud geometry. The weather selector applies to the ring deck, not the old MC
density or billboard shader. The three-layer method keeps its original fresh preset.

## Source inventory and implementation notes

Git history contains MC alpha-hash and alpha-blend iterations, cylindrical and
earlier billboard variants, the three-layer FBM approach (`ae54493`), scattered
noise-textured horizontal cards (`637ef5f`), and the later ring deck. The original
MC/billboard implementation is in `game/cloud_system.gd`; later shader repairs
addressed transparency and Compatibility-renderer behavior. These historical
failures do not establish that a representation is unsuitable.

The sky also has an older procedural sun/stars/planet shader, a five-face
Installation05 skybox dome and an equirectangular panorama experiment. They remain
preserved in the source/history; this comparison pass exposes the cloud methods
above plus the painterly study and existing Rebuild sky. Archived horizontal
scatter cards and skybox variants have not been added as separate presets.

`sky_legacy_clouds.gd` reuses the original noise, mesher and cards without editing
the shared historical implementation. It limits generation to one MC chunk or
12 cards per frame, remembers empty cells, and refreshes desired cells at 2 Hz.
Original code could generate its entire radius synchronously and regenerate
empty cells repeatedly. MC vertices/normals now bend onto the ring; the shader's
wind offset is shared with streaming. Billboard positions and upright axes use
the ring frame. MC remains CPU-generated and may hitch during fill-in. No claim
of a frame-rate target or final visual quality is made.

Captures use the full scene and copied forest/construction/actor layouts, with
the world paused and one fixed camera for all nine views. The capture test checks
default-off state, sky restoration and unchanged sun energy. Live saves are not
used as test destinations. The user will judge the screenshots.

## Revision 2 — user feedback, without image inspection

MC normals now sample the continuous density gradient at each vertex instead of
using triangle face normals. Shared vertices receive matching normals, including
across chunks. Mesh silhouettes/resolution are retained; specular response is off.

Billboards use deterministic clustered gaps, jittered positions, varied widths,
heights and noise seeds. Altitude is now 850–1550 m instead of 2800 m. Their new
shader makes broader cloud masses with rotated noise octaves and softened edges.

Ring deck density previously underwent powers and macro attenuation before a
threshold tuned for raw noise. The comparison adapter now uses density power 1,
less macro attenuation, and fresh coverage [0.58, 0.43, 0.26, 0.12, 0.15]. Shared
ring-cloud source and other scenes are unchanged.

Painterly sky now samples continuous 3D directional noise with domain warping and
rotated octaves, replacing the folded 2D direction projection. Its palette is
softened. This is a proposed revision, not a visual-quality claim.

Ctrl+F3 adds cloud brightness 0.25–1.8, default 1.0. The legacy layers previously
used shader default 0.5; choosing 0.5 restores that dark treatment without changing
their silhouette. This adjusts cloud colour, not scene sunlight or ambient light;
those remain available in the existing Daylight controls. Brightness applies to
all enabled cloud methods and remains session-only.

Revision-2 captures are generated automatically into the current chat outputs.
No images were opened or visually assessed in this revision, per user instruction.
Validation: parser check and complete rendered capture run exited 0. Smooth-normal check passed for 155,896 triangles, with shared-vertex consistency; sky restoration and unchanged sun checks passed. No visual assessment performed.

## Billboard foundation — 2026-10-16

Supersedes the earlier default-off instruction: the user selected billboards as
the basis for further work, so Sky Demo now starts with preset 1 enabled. The
baseline and all other comparison presets remain selectable; Rebuild is unchanged.

Cards face camera POSITION using a shortest-arc rotation of a world-anchored,
downward-facing frame. Camera yaw/pitch/roll no longer determine cloud orientation.
This also removes the upright-card singularity at zenith. Conservative spherical
bounds contain rotated cards for frustum culling. Flying through a cloud or directly
above it remains a 2D-card representation, not a volumetric cloud simulation.

The old local field ended at 6.5 km. Two deterministic MultiMesh tiers extend
coverage to 125 km in both ring directions, within the habitat width, at 850–1550 m
altitude. Local and distant tiers use distance fades. Each distant tier uses one
batch; far cards are broader and more widely spaced. This is not an FPS guarantee.

check_sky_billboard_orientation.gd renders the production vertex shader with a
solid diagnostic fragment and counts pixels automatically (no visual inspection).
It checks overhead, either side of zenith, lateral views and four camera rolls.
It also verifies clouds beyond 90 km in both arc directions at origin and +/-100 km,
correct ring altitude and two distant batches. Passed, exit 0.
Full-scene integration also passed (exit 0): billboard default, isolated layouts, both ring directions, overhead captures and off/on restoration. No image was opened; captures are for user review.

## Correcting the billboard visual regression — 2026-10-16

The user-approved revision-2 silhouettes remain the reference. The downward-frame
shortest-arc orientation made wide cards stand vertically in ring-axis views;
combined with oversized distant cards, this produced the rejected radial streaks.

Width now follows cross(local ring up, cloud-to-viewer direction). Nearby cards
retain a previous projected right axis through the zenith cone, then ease toward
horizon alignment at a bounded angular rate. Only camera position affects this
frame, not yaw/pitch/roll. Distant cards stay horizon-aligned. Their dimensions are
650–1400 by 250–550 m in the medium band and 1100–2300 by 350–700 m in the far band,
with reduced spacing rather than stretching giant cards. Cloud fragment noise,
colour, near placement and local dimensions are unchanged.

Tests cover smooth zenith crossing, horizontal width in opposing directions,
rendered projected area and far coverage. Capture script now includes the exact
revision-2 comparison camera plus both ring directions and eight overhead turns.
Validation passed: focused orientation/render checks and full-scene run exited 0. Visually compared the approved camera, both ring horizons and overhead: the rejected radial vertical cloud streaks are gone; near overhead cards now show their full area, so they appear fuller than the old cylindrical cards. Distant coverage remains subject to user review.

## Cached billboards and physical painterly layer — 2026-10-17

Default preset is now **Billboards + high painterly layer** (index 9), following
user approval of that combination. Ctrl+F3 retains individual toggles, brightness,
and adds upper-layer altitude 3000–12000 m (default 6000). Ctrl+F9 toggles the upper
layer. Other presets, gameplay and the Rebuild shortcut remain intact.

### Runtime changes

- `sky_cached_billboards.gd` replaces per-card near nodes and whole-horizon rebuilds
  with spatial MultiMesh chunks across the same three distance bands. Chunks contain
  16x16 possible cells. Deterministic noise gaps, jitter, size ranges and ring
  altitude remain. Near frames retain the previous zenith-safe orientation algorithm.
- Stationary frames stop uploading near transforms after settling; rotating the
  camera alone does not rebuild geometry. At most one missing chunk is created or
  loaded per frame. Memory retains inactive batches for revisits (64-chunk target;
  active chunks are never evicted just to meet it).
- Immutable placement/seed MultiMeshes are saved before any camera-facing changes
  to `user://sky-cloud-chunks-v1/`. Revisited chunks reuse memory; later sessions
  load disk resources. New regions still require first-time placement generation.
- Billboard density and shading use a 64-variant 2048px atlas (256px per shape),
  generated once from the approved noise shader. Runtime uses a mipmapped texture
  sample rather than ten noise octaves per transparent fragment. Individual seeds
  now select a baked shape; the former tiny per-pixel shape evolution is frozen.
- `sky_high_painterly.gd` is a full ring-following ceiling, not a sky-direction cloud
  projection. One mesh, 16,384 triangles, 6000m default altitude, retained pastel
  palette and a seamless cached 2048px texture drifting in ring coordinates.
  There are exactly 48 texture periods around the ring, avoiding an arc-zero seam.
  It participates in depth testing, so clouds on the near side of distant terrain
  are visible in front of that terrain. It does not force clouds through foreground
  terrain. The background retains the painterly gradient only.
- Both PNGs are bundled in `game/world/cloud_cache/` (~6.8MB total). Runtime builds
  mipmaps once and shares textures (~43MiB uncompressed including mipmaps). Offline
  rebake: `--script res://benchmarks/bake_sky_textures.gd`. No image-generation API.
- Distant groups remain individual cards within batches. No giant texture sheets
  replace billboard silhouettes. Transparent overlap still costs pixels.

### Validation and measurement

`check_sky_cache.gd` passed atlas alpha/transparent borders, no stationary
regeneration, retained batch identity after travel, restart disk hits, 6000m ring
geometry and altitude setting. Warm sample loaded 20 chunks from disk with six
memory reactivations; worst observed warm chunk load/setup ~5.7ms, cold ~14.5ms.
These are bounded chunk operations, not zero-hitch claims. Fixture near plane was
corrected to 0.5m to match long-range rendering precision. Physics interpolation
is explicitly off for render-driven cloud transforms.

`profile_sky_cache.gd` uses a preserved source snapshot in benchmarks/sky_before
for the before run and live code for after. Same 1366x768 viewport and fixed view,
Intel UHD Compatibility, vsync/cap off, all four saves isolated. Gameplay/terrain
streaming paused. Each case warms 90 frames and measures 240. Moving case is a
synthetic 3.8km camera route through the frozen scene, NOT a driving benchmark.

| Case | Before mean / p95 ms | After mean / p95 ms | Draws before -> after |
|---|---:|---:|---:|
| Baseline | 14.157 / 15.896 | 12.024 / 15.829 | 101 -> 101 |
| Billboards | 17.478 / 22.424 | 12.939 / 16.779 | 216 -> 111 |
| Combined | 21.949 / 26.072 | 12.459 / 15.980 | 216 -> 112 |
| Synthetic moving camera | 16.058 / 24.355 | 8.678 / 13.808 | 113 -> 14 |
| Baseline again | 12.605 / 16.734 | 10.687 / 13.478 | 101 -> 101 |

Combined mean decreased ~43%. Baseline timing also drifted between runs; do not
attribute the entire difference to the patch or extrapolate to live combat. The
first before-baseline case had a 472ms outlier. No 120 FPS guarantee. Raw JSON and
matching screenshots are in the current chat outputs. The source snapshot is a
benchmark reference, not another live scene or launcher.
Final integration passed (exit 0): combined default, layer toggle/altitude/brightness, retained batch identities across presets and shader rendering. No script/shader errors or interpolation warnings in the final log. Briefing, controls, combined sky and distant-ring overlap were visually inspected. Player saves and previous shortcuts unchanged.

## 2026-10-17 — Upper coverage, haze controls and antipode depth
- Sky Demo only: upper cloud shader samples cached coverage at two additional broad scales (six and two repeats per circumference). Alpha and shade variation survive distant texture minification. Ctrl+F3 coverage variation 0..1 restores the previous uniform coverage at zero; default 0.8.
- Blue distance haze now has on/off, strength 0..1 and reach 10..1,500 km. Reach is the exponential 63% distance before strength scaling; default remains 100 km / strength 1. Ring terrain and rim wall share settings. The containment field is a separate existing effect. Controls are session-only, applied after backdrop lighting updates.
- Camera near plane changed only in Sky Demo from 0.2 to 0.5 m. GL sky depth was covering the opaque antipodal terrain at 0.2 m; the transparent high cloud pass remained visible. An isolated actual-size ring fixture reproduces 352/640 visible center-row pixels at 0.2 and 640/640 at 0.3, 0.5, 0.75, 1 and 2 m. Without the sky pass all 640 pixels render, confirming sky/depth precision interaction. The first-person weapon camera remains separate at 0.01 m.
- Billboard range, placement, batching and cache unchanged.
- Verification: capture_sky_atmosphere.gd full scene with four isolated saves; compares old/new clip planes, haze settings, cloud controls and retained batch identities. check_sky_depth.gd is the focused depth reproduction. Screenshots/logs in the sky chat outputs/work directories.

## Controller UI and crater grenades — 2026-10-17
- Controller input now yields to any focused visible GUI control, leaving mouse mode visible while settings are adjusted. Sky comparison dialog is explicitly marked modal so it receives controller navigation even before a child control has focus.
- Controller L1 now calls the same `terrain_drive.throw_grenade()` action as keyboard B. Elite squad members treat both the terrain crater grenade and tactical frag as dive threats through the shared `dive_grenades` group; the terrain grenade exposes its existing velocity to the same proximity prediction.

## 2026-10-17 — Crater preparation and response performance
The full-scene crater request-to-publication timings are now 271 / 197 / 224 ms for L1/B/B throws. The isolated saved-edit tile improved from 1,213 ms first-use to 142 ms prepared; following shots 194/194 to 142/157 ms. Main-thread collision attachment is ~0.03 ms in the final full scene. Frame-time p95 still 38–46 ms across throw windows, so this is not a claim that overall battle performance is solved.

TerrainGrenade now owns shared launch/fuse/gravity/crater constants plus a conservative preparation reach. Destruction reserves initial spawn-area cache entries during tile loading, completes preparation before ready-to-play, then refreshes protection as the player moves. Full throw bounds include inherited car velocity using max(configured top speed, actual speed). Default foot radius ~66 m; 45 m/s vehicle ~156 m. Only loaded tiles can be prepared. The extra explicit preparation at load took ~0.6 s in the final run (nearby builders no longer evicted then rebuilt).

Edit cache retains 24 entries normally, protecting the current grenade area; protected entries may exceed that at extreme coverage. Cuts caches base triangle indexing/extents and unchanged pure-carve patches. Collision resources and private body/shape nodes are created off-thread, outside the active scene tree, then attached on main and swapped with visual ownership on the physics tick. Worker exit cleanup frees unpublished bodies. Pure-carve appends preserve recipe order and strip internal stroke metadata; canonical save signatures append a canonical suffix only when the prefix count is valid, otherwise rebuild fully.

`busy()` includes cache preparation for worker exclusion. `editing()` excludes preparation and is used by actor residency, dirty-state/HUD checks, preventing preparation from pausing combat or pretending to change terrain. Actual terrain changes retain existing actor safeguards.

Tests: profile_crater_stages.gd (before/prepared JSON, independent fresh geometry and fingerprint equivalence, eviction pressure), profile_crater_scene.gd (all four isolated sky-test saves, actual L1/B throws, modal pointer, stationary and movement readiness), check_crater_preparation.gd (120 trajectories at 0/45/80 m/s plus actor/dirty-state behavior), check_drive_grenades.gd (seams, overlap, far ring and replay), check_drive_editor.gd (tools, undo/redo, save/load). The editor fixture now writes scratch saves into this chat's work folder. Full-scene logs have no script/runtime errors; existing GLTF conversion warnings remain. User-facing report: yo/outputs/CRATER-PERFORMANCE-2026-10-17.md.

## 2026-10-17 — Rocket launcher and continuous crate physics
Added weapon 6 using the supplied Rocket Launcher glTF and textures, copied into assets/rocket_launcher with the original CC-BY-4.0 credit. Model: irons3th, https://sketchfab.com/3d-models/rocket-launcher-ae125b08563542b3bea3e3da0faa6996. The launcher has a two-shot magazine, 0.65 s firing interval, 1.5 s reload, unlimited reserve, straight 55 m/s swept rockets and a 350 m range. Impact blasts have a 10 m damage/prop radius and request 3 m terrain cuts. Nearby walls shield blast damage and crate impulses; the initial sweep includes camera-to-muzzle space. Flight visuals, explosion flashes and generated launch/blast sounds are included. 6 selects it, Q/Triangle cycles, LMB/R2 fires, R/Square reloads.

The reported crate freezes were deliberate: aliens.manager.resident() returned false during every terrain edit, causing heavy_crate to freeze and ignore subsequent blast impulses. Residency now tests streamed collision availability only. The old terrain collision remains active throughout worker preparation and all replacement tiles swap on the same physics tick, so there is no reason to suspend actors for the whole edit. Genuine missing terrain and editor/loading pauses retain suspension. This supersedes the earlier note above about retaining the global edit pause.

Validation: check_rocket_blasts.gd exercised three chained real rocket impacts and terrain publications, three crate impulses, continuous motion on every editing frame, enemy splash damage, wall shielding, missing-terrain suspension/resume and camera-to-muzzle obstruction. check_crater_preparation.gd passed 120 throw trajectories and revised active-edit residency assertions. check_rocket_scene.gd used all four isolated sky-test save overrides: actual weapon 6 selection, two impact craters, empty-magazine guard, reload and controller cycling passed. Briefing and first-person screenshots were inspected. No player saves were modified. Distant rocket impacts outside the prepared grenade area can still need cold terrain work, and cuts require loaded tiles; removing the deliberate freeze does not eliminate all frame-time hitches.
