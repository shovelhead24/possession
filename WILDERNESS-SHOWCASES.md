# Wilderness showcases — 2026-10-25

Direction: vistas are destinations in their own right. Each should have a distinct reveal, places worth stopping, and several rewarding viewing angles. Passes and shorelines shape travel, but scenery must not read solely as corridors around obstacles.

Four new 4.8 km landscape patches are authored separately from the original play area. Centres: arc 10,000 / 16,000 / 22,000 / 28,000 m, lateral 10,000 m. Terrain, collision, materials and vegetation placements are baked into game/assets/showcases/*.scn by game/benchmarks/bake_showcases.gd. The generator uses isolated test saves, reads existing backdrop heights for boundary blending, and does not write source DEM data. No runtime terrain generator or cache scheduler is introduced.

Themes: autumn forest and lakes; alpine braided river; rocky mountain pass; highland lake. Named entries are appended to Ctrl+F4 viewpoints. Existing spawn controls can land the player below a view or save a start. The current home start is not changed. New roots participate in floating-origin rebasing. The established fir assets replace the temporary conifers at load; original distant billboard LODs keep the forest manageable. Opaque textured grass blades avoid grass alpha overdraw. Foliage is spatially batched. The areas are hidden beyond 6.8 km from the camera to keep the original play area inexpensive.

These are authored reference-inspired environments, not exact copies. Water is visual and has no swimming/buoyancy gameplay. Existing far backdrop remains; the patch outskirts blend down to its sampled height. Snow is a baked material mask. Tree trunks and rocks have collision; the original fir assets supply the visible trees.

Validation is recorded after the scene review. Files are generated ahead of time and loaded from disk.


## Review and reproducibility

After bake_showcases.gd, run benchmarks/refine_showcase_assets.gd to apply the final shared textures, tapered textured grass mesh, water tuning and elevated reveal views. Both tools operate only on generated assets. The showcase review flag is --showcase-review in benchmarks/profile_performance_weather.gd; always supply all four isolated save paths.

Final assets: 53,274,851 bytes (about 53.3 MB decimal), excluding already-existing shared fir assets/cache. Autumn forest has 10,488 placements; alpine 1,227; pass 41; lake 222. Nearby batches use original fir LOD2; distant batches use original billboard LOD3. Original home terrain and saved start remain intact.

Final validation: work/showcase-review-final.log in the 2026-10-17/rea task folder. Exit 0, four grounded landings, four finite camera/origin transitions and four short Warthog drives passed. Travel distances were 14.8 / 21.8 / 16.3 / 20.1 metres. Screenshots and visible briefing inspected. This is not an exhaustive driving-route or performance benchmark. Observed screenshot FPS varies and some ground views are below 70 FPS; further performance tuning remains before treating these as production-ready environments.

The visual direction is established but the landscapes remain an initial art pass. Grass distribution currently concentrates around the landing/reveal areas; terrain collision covers the whole patch. Water gameplay, authored missions, fully distributed ground dressing and final composition/material polish are not completed by this study.

## Summit snow and grass scale review — 2026-10-26

Installed golden straw and upland tussock albedos in the four showcase landscapes. Default coverage is 1 x 1 metre per tile; Ctrl+F4 offers session-only sample and tile-size controls (0.5–8 m). The original home material is unchanged. New albedos have no matching height maps; the unrelated old grass height map is not used for their relief.

The refinement script stores ring-relative height in terrain UV2 and sets a separate snowline for each landscape: fade starts at 86% of peak height above the site base and reaches full strength at 96%, multiplied by the existing slope mask. Lower rock is darker to distinguish it from snow. No geometry or collision changes are needed.

Rendered validation: rea/work/summit-grass-review.log, exit 0, SHOWCASE_REVIEW_PASS, no script/shader errors. All four grounded landings, four short drives and floating-origin transitions passed. Inspected all four vista captures, visible briefing and Warthog scale comparisons. The 1 m sample reads more plausibly than 4 m; comparison images are rea/outputs/grass-scale-{1,2}-{1,2,4}m.png. These captures are not a performance benchmark. Far terrain remains visually uniform, and standing grass still needs art polish; this change does not resolve those separate issues.

## Grass distance layering — 2026-10-26

The showcase material now fades the one-metre albedo detail from 8 to 35 metres. Mipmaps remain enabled for filtering; explicit distance blending controls recognizable blade detail. Far colour uses the source textures' coarsest mip averages, with a saved 512-square RGB variation map representing approximately 90, 350 and 1100 metre noise scales. Broad modulation applies at all distances to avoid a moving colour boundary. The refinement tool generates this map offline and embeds it in saved materials. Fine rock relief uses the same short range. This is a visual change, not a texture-streaming system or a demonstrated GPU speedup: source textures remain resident and sampled.

Rendered validation: rea/work/grass-distance-review.log exited 0 with all four showcase checks passing and no script/shader errors. Inspected the visible briefing, autumn vista and near Warthog comparison. Close strands now give way to broad patches; distant ground remains an initial colour-blocking pass, not finished biome artwork. No FPS improvement is claimed.

## Layered landscape and track study — 2026-10-26

Replaced the bright source-average far palette with muted olive, straw-brown and earth colours while retaining near albedo strand contrast. A saved seamless 512-square three-channel data texture supplies roughly 3.5, 18 and 85 metre breakup. These clump, soil and outcrop patterns persist after the 8–35 metre blade fade. Larger vertical rock projections and crag/strata modulation supply detail on mountain faces; slope masks still control exposed rock. Procedural clump/crag relief affects normals (not silhouette or collision), fading at 100–450 m for clumps and 400–1600 m for crags. These are artistic procedural relief fields, not physically recovered heights from the generated grass photograph.

A saved 512 x 1024 tyre-mark mask covers a small 64 x 240 metre study region beside the autumn landing. The actual curved pair of tracks extends about 180 metres, at 1.76 metre wheel spacing, and blends dark soil plus shallow normal relief into the terrain material. No extra transparent geometry, decal dependency, runtime stamp history, collision ruts or live wheel tracking was added. Animal tracks remain future work. Track study centre near arc 10006 / lateral 9165; the review flag --landscape-detail-review captures this area. Standing grass is not yet flattened by the study mask.

Final rendered validation: rea/work/landscape-detail-final.log exited 0; all four vistas, grounded landings, short drives and origin transitions passed, with no script or shader errors. Inspected autumn/pass vistas, track close-up and visible briefing. Revised the initial overly horizontal rock bands with two differently oriented vertical projections and lifted the grass palette. Surface variation is improved, but some stretching on steep foreground slopes, simple grass cards and coarse terrain silhouettes remain. This is not a performance benchmark; no FPS gain is claimed.

## Mountain projection and proposed wind — 2026-10-26

Mountain material now derives three projection weights from the actual surface derivatives in ring-relative terrain coordinates. Fine and broad rock samples use those weights, preventing the previous fixed pair of projections from stretching across faces. Broad coordinates have static multi-scale variation and different rotations/scales per projection, reducing repeated rows. This adds texture sampling; it is not a measured performance improvement.

Wind proposal (not implemented): one shared direction, mean strength and slowly varying gust signal, with calm/breeze/gust review controls. Keep tree trunks and collision stationary initially. Apply small, height-weighted foliage displacement in the vertex shader; normalized tree meshes already have roots at y=0 and tops near y=1. Near LODs can add branch-tip flutter weighted by height and distance from the trunk; distant billboards use only low-amplitude canopy sway, fading motion at long distance. Keep matching slow motion across LODs, while removing flutter smoothly before billboard transitions. Use stable ring-coordinate anchors for phase so floating-origin shifts do not reset gusts; transform the common direction into each instance's local basis, since planted trees have different rotations. Expand culling bounds to cover maximum sway. A fir's response must remain small enough that foliage does not visibly detach from its fixed woody branches. Strong trunk bending would require applying the same bend to bark and foliage, and is outside the initial prototype. Grass should use the same wind/gust field with a stronger and faster response. No per-tree CPU update, skeleton, new transparent layer or physics spring is needed for this first pass. Validate calm, gusts, LOD transitions and origin shifts; measure a controlled wind-on/off GPU comparison before enabling broadly.

Mountain projection validation: rea/work/mountain-projection-review.log exited 0 with four landing/driving/origin checks passing and no script/shader errors. Inspected autumn/pass vistas and visible briefing. Repeated bands are reduced; coarse foreground geometry and some soft/stretching material detail remain. Wind remains a proposal, not a completed feature.

## Wilderness wind prototype — 2026-10-26

Implemented the first shared wind trial in the four showcase landscapes. Ctrl+F4 / Viewpoints now has Calm, Breeze (default), Gusts and a ring-relative direction in degrees. Settings are session-only and independent of weather presets for now. The original home tree materials are not modified: showcase meshes/materials are duplicated once at setup, and every LOD switch selects those wind-enabled variants.

showcase_wind.gdshaderinc supplies a common direction and low-frequency travelling gust using absolute ring anchors plus the floating-origin offset. Each tree/grass instance converts that direction to its own local basis. Trees use a restrained normalized-height-squared canopy displacement; roots and bark/collision are fixed. Nearby foliage adds small flutter fading between 90 and 200 m; billboards omit flutter but share the slow sway, with tree motion fading from 450 to 1100 m. Grass uses a larger response to the same gust. Expanded instance culling margins cover movement. No per-tree CPU animation, physics, skeleton or extra alpha layer is introduced. Normals are not bent for this small-displacement study.

Isolated rendered validation: benchmarks/check_showcase_wind.gd, rea/work/showcase-wind-check.log. Calm images at two frozen times matched exactly; gust images differed in 5,475 channel samples; shifting the origin by (512,128,512) changed only 49 samples beyond a 3/255 tolerance. LOD2, billboard and grass rendered without shader errors. VSync-disabled frame means in calm/breeze/gust/calm order were 1.930 / 2.246 / 1.997 / 1.903 ms, p95 3.455 / 3.967 / 3.490 / 3.442 ms. This is a small two-tree/100-tuft scene with CPU frame timings, not GPU timing or a forest-scale performance result. Calm uses the same shader, so this is not a measurement against the original no-wind shader.

Full-demo integration: rea/work/showcase-wind-integration.log exited 0, all four landscape landing/driving/origin checks passed, all preset material values asserted and no script/shader errors. Inspected the Viewpoints wind controls and visible briefing. The control default and applied direction are both 30 degrees. The trial is ready for visual judgement; weather coupling and forest-scale GPU profiling remain outstanding.

## Stronger, localized wind revision — 2026-10-26

Responding to barely visible and over-synchronized motion: canopy bend coefficient increased from .012 to .038, with a cubic height weight to keep lower foliage steadier; grass response increased from .22 to .48. Replaced the single repeating phase wave with two travelling spatial fields and per-instance variations in frequency, phase and response strength. Local eddies also vary direction slightly. Spatial fields sample the already-saved ground-breakup texture in the vertex shader, rather than evaluating procedural noise for every vertex. Calm remains zero displacement. Settings and scope remain the four Wilderness areas.

Final isolated check: rea/work/showcase-wind-local-check.log. WIND_POSE_PASS calm=0, gust=11525, rebase=34 changed channel samples (3/255 tolerance); WIND_REVIEW_PASS. Frame means calm/breeze/gust/calm: 1.722 / 1.797 / 1.772 / 1.706 ms, p95 2.543 / 2.634 / 3.023 / 2.596 ms. This small-scene CPU frame-time comparison is not a forest-scale GPU benchmark. The user's visual assessment of the movement remains important.

Localized wind full integration: rea/work/showcase-wind-local-integration.log exited 0 with all four landscape checks passing and no script/shader errors. Updated briefing visually inspected. Ctrl+F4 controls remain Calm/Breeze/Gusts and direction; default is Breeze.

## Whole-tree bend prototype — 2026-10-26

Bark and foliage now share showcase_tree_bend.gdshaderinc: a normalized-height-squared bend with anchored roots, transformed normals and a separate small foliage-tip flutter. Bark materials are converted using their existing albedo texture, colour and UV transform. The shared mesh preparation helper is used in both production and the isolated render test. Billboard trees use the same overall bend; distance fade now spans 650–1600 m. Culling margins increased to 12 m for the stronger/exaggerated motion. This remains visual bending: trunk collision is stationary and there are no branch skeletons or physics springs.

Controls moved to the separate Ctrl+F4 / Wind tab. Tree bend multiplier 0–3 defaults to 1. Exaggerated tree wind selects Gusts and a 2.5 bend multiplier. Test grove beside Warthog creates three temporary visual trees beside the current Warthog (8, 12 and 16 m; two mesh trees and one billboard), using raycast ground and an origin-aware root; Clear test grove removes it. These trees have no collision and are not written to saves. Wilderness wind remains enabled as before; the original home trees remain unchanged.

Isolated validation: rea/work/whole-tree-wind-check.log exited successfully with calm=0, gust=21335 and rebase=181 changed channel samples beyond tolerance. Exaggerated bend produced more visible movement than regular Gusts. Inspected both strong-pose captures: the billboard bends visibly while its root stays planted. Mean small-scene frame times were 1.69/1.65/1.56/1.56 ms (calm/breeze/gust/calm); these are CPU frame times and not a forest-scale GPU benchmark.

Full integration: rea/work/whole-tree-wind-integration.log exited 0 and all four landscape landing/driving/origin checks passed. Test grove created three grounded trees; inspected Wind controls and two frozen-time Warthog comparison captures with visible crown/trunk motion. No script/shader errors; existing asset-import and setup interpolation warnings remain.

## Curved wind billboards — 2026-10-26

Showcase billboard preparation clips each original triangle into four horizontal height bands, preserving position, interpolated normal and atlas UV. Flat cap triangles are emitted once. The three original fir billboards each increase from 20 to 52 triangles, with unchanged surface/material count. This is one-time preparation of three shared meshes, not per-frame geometry generation. Cards now follow the same quadratic bend as close trees. Exaggerated tree wind selects Gusts with tree bend 3.0, matching the user's preferred comparison; normal startup remains Breeze/bend 1.0.

LOD policy: close mesh below 240 m batch distance; curved 52-triangle billboard through 1800 m; original static 20-triangle billboard beyond 1800 m. Wind itself fades from 650 to 1600 m, so the geometry simplification occurs after the motion fade (with a batch-distance margin). No dithering, additional transparent surfaces or screen-space wind pass.

Isolated validation: rea/work/billboard-curve-check.log, WIND_REVIEW_PASS. All three variants preserve bounds and area within tolerance. The rendered Calm comparison against original cards passed the atlas/appearance check. Calm time comparison is identical; Gusts changes 19522 channel samples; rebase changes 197 beyond 3/255 tolerance. Strong-pose review uses bend 3.0. Small-scene frame samples are variable (roughly 3.8–4.5 ms) and are not a controlled before/after forest benchmark.

Integration validation: rea/work/billboard-curve-integration.log exited 0 with all four landscape checks passing. Inspected strong-pose image and visible briefing. The later far-static selection change was separately checked by benchmarks/check_showcase_far_lod.gd: mesh/curved/static/curved/mesh transitions all passed (rea/work/billboard-far-lod-check.log).


## 2026-10-26: foliage, grass authoring and landscape character

- Startup now selects Gusts, tree bend 3.0 and Halo CE Plasma Rifle (weapon 4).
- Plasma bolt histories, firing origins and impacts rebase together; the world
  presentation batch resets to identity. Rendered regression covers repeated
  shifts, new bolts after shifting, swept hits and impacts. Headless dummy
  rendering cannot validate MultiMesh instance transforms; use the rendered test.
- All three original fir species now use at least 0.35 cutout threshold with
  explicit mipmapped anisotropic clamp sampling, including moving and static
  impostors. Transparent RGB bleeding remains enabled. This tightens dark fringes;
  it does not remove baked shadows within the photographed tree textures.
- Saved tree scales have deterministic extra height variation with matching trunk
  collision scaling. Refinement metadata prevents cumulative scaling on rebakes.
- Grass assets from the user's realistic-grass-pack-for-games-free are documented
  in assets/terrain/grass-cards/SOURCE.md. Three cutouts mix with original blades.
  Wheat UVs select small blade groups from its atlas. Wind bends subdivided cards;
  no grass rigid bodies or per-clump nodes are created.
- F1 has Paint grass / Erase grass, mixed or individual clumps, height and density.
  Density 10–400 clumps/100 m² widens height spread from ±10% to ±55%. Radius uses
  the existing brush control (max 30 m). LMB drag paints, Ctrl+Z/Y undo/redo selected
  foliage, Ctrl+S saves. Erase only removes authored grass, not showcase scatter.
  Grass is in `<tree-layout-path>.grass.json`, automatically isolating test layouts.
  Ring coordinates plus radial ground height survive floating-origin shifts.
  Painting is bounded to 64 candidate raycasts/tick; 32 m spatial batches load near
  the camera, at most four cells/refresh. 50,000 total authored clumps, 16 undo
  snapshots. Grass is grounded when painted; later sculpting does not yet reproject
  saved clumps. Paint vegetation after shaping terrain for this version.
- Offline RGBA landscape masks store wetness, green meadow cover, exposed bluffs
  and grass density. They combine saved terrain slope/concavity, water proximity,
  authored irregular districts and independent noise at several scales. No
  satellite roads/field patterns are copied. Western meadow and eastern dry-rise
  regions give recognisable directional character. Colour, texture blending,
  restrained wet/dry roughness, and saved scatter density use the same masks.
  Only the four wilderness showcases use these masks; terrain geometry and the
  original play area are unchanged. Masks are saved with each scene, not generated
  during play. Grass source metadata makes thinning/height changes repeatable.

Validation: four remote rifle shots with in-flight origin shifts; four grounded
landings and drives passed in vegetation-integration.log. The isolated rendered
plasma-origin-rendered.log passes. vegetation-assets.log checks all four saved
scenes. grass-paint-integration.log passes actual terrain painting (441 clumps),
erase, editor undo/redo, save/reload and height range 0.4504–1.5495 m at 1 m / max
density. Visual loading brief and F1 controls checked. Timings in screenshots are
not a controlled performance comparison. Latest character screenshots/logs live
under the rea outputs/work directories.


Bake correction: run `refine_showcase_assets.gd` with a rendering device (without
`--headless`). The dummy renderer returned zero transforms for copied MultiMeshes
while loading the preserved source metadata. The script now rejects headless
baking. Original scatter sources were intact; a rendered rebake restored them and
`vegetation-restored-audit.log` checks every grass transform in all four scenes.
`landscape-character-final.log` passed paint/erase/undo/redo/save/reload and plasma
with the new masks. The final restored-asset render is in
`landscape-restored-final.log`; east/west captures use ring arc direction rather
than camera-local right (the tangent basis reverses that axis).

Final verification: landscape-restored-final.log passes the complete autumn
paint/erase/undo/redo/save/reload, plasma/rebase and drive check. The original
headless tree bake had retained original visual scales while changing collision;
rendered refinement now uses tree_visual_height_v2 and assigns collision from the
final visual basis. foliage-final-audit.log verifies every tree visual/collision
basis and every grass transform in all four scenes. Autumn tree height scales now
span 0.749–3.768 (runtime multiplies normalised fir meshes by 10). The latest
height-only correction was asset-validated after the rendered landscape check.

## Ring daylight and daytime stars - 2026-10-27

Restored the original ring_vibes tilted sun orbit through RingFrame.sun_direction, with the same rotation applied to the original spherical starfield. Both painterly sky shaders now include that starfield; the established daytime visibility remains 0.4. Local daylight uses the camera ring-up vector, including floating-origin shifts.

The performance review patches only its distant terrain and wall materials with performance_ring_light.gdshaderinc. Their illumination and distant haze follow the surface hemisphere instead of local player sun/ambient energy. Regional haze blends beyond 20-120 km, with extinction capped at 0.82 during preview to retain distant surface detail. Cloud cards and the full-ring high painterly layer receive regional tint in their vertex shaders. Weather gains remain independent of camera-local daylight. Disabling the preview returns to the existing material path.

Regression entry: profile_performance_weather.gd --ring-day-review, with all four isolated sky-test save overrides. Captures noon, midnight, sunrise, sunset and daytime stars; asserts opposing hemisphere sun heights, origin rebasing and preview reset. These are visual/correctness checks, not FPS benchmarks.

Final rendered run: rea/work/ring-day-final.log passed all assertions without script/shader errors. Reviewed ring-day-12.png, ring-day-0.png, ring-day-18.png and ring-stars-day.png: opposite hemisphere reverses brightness and stars remain visible in daylight. Updated loading briefing verified visually.

## Living environment defaults - 2026-10-27

On entering play, performance_cloud_review starts evolving cloud drift (mode 2, speed 1), a 20-minute day/night loop at noon, and automatic weather. Existing Gusts / tree bend 3.0 defaults remain. Weather cycles every 180 seconds with a 45-second smooth blend: Scattered, Overcast, Drizzle, Passing showers, Clear, Scattered, Mist, Scattered, Steady rain, Wind-driven rain, Overcast, Clear. Passing showers retain their internal rain pulses. Fog density, valley mist, rain, cloud coverage/brightness and lighting gains blend together. Valley mist is separate from global fog so it can fade in/out during transitions.

Ctrl+F4 Weather has an automatic-cycle checkbox. Selecting a preset or editing rain/wind/visibility pauses the cycle; re-enabling begins at Scattered. Daylight scrubbing holds the hour; Animate day resumes it. These settings remain session-local; defaults reapply on restart, with no edits to player saves. Full weather cycle and manual overrides validated by benchmarks/check_weather_cycle.gd.

Final full-scene run (rea/work/environment-defaults-final.log): ENVIRONMENT_DEFAULTS_PASS and RING_DAY_PASS. Startup, all weather transitions, manual override/restart, opposing hemispheres, origin shifts and reset passed. Updated briefing inspected visually. Initial test-only constant-intensity assumption for Passing showers was corrected to allow its existing pulse.

## Blue planet and far haze - 2026-10-27

User-supplied blue planet copied unchanged to game/world/materials/sky_blue_planet.png. The painterly sky shaders sample its disc directly through performance_planet.gdshaderinc, at a two-degree angular diameter (four typical full moons). Clouds and ring geometry occlude it normally. It rotates with the celestial frame. PlanetMoonlight is a cool-blue DirectionalLight3D capped at 0.035 energy, without shadows; fades by local daylight, planet elevation and cloud cover. This is a fixed photographed phase, not a dynamic phase simulation.

Far-ring manual haze cap eases from 0.82 near the horizon to 0.55 beyond 120 km; the existing local haze is retained. Day/night preview and normal environment defaults remain enabled.

Verified planet-final.log: environment defaults, ring daylight/origin tests and PLANET_PASS all passed. Moonlight measured 0.035000000149 (float precision), zero in daylight, shadows disabled. Inspected normal-FOV and zoomed planet captures plus updated loading briefing. Source texture uses generated mipmaps at load time.

## Larger planet and usable ground moonlight - 2026-10-27

Planet angular diameter is now 10 degrees, five times the preceding version. The existing directional moonlight cap rises from 0.035 to 0.14; a diffuse-only, shadow-free 28 m OmniLight follows the camera with a 3 m upward offset, providing gentle nearby navigation fill. Both follow daylight, planet elevation and weather attenuation. Far terrain/walls receive independent regional moon diffuse light before haze; this uses each surface radial up so remote regions do not inherit local daylight. Water has a dedicated moon specular emission term after its night tint, preventing the sun-only highlight/tint pipeline from suppressing moon glints. No new shadow maps.

Final rendered moonlight-final.log passed environment, daylight, origin and moonlight checks. Shared assets/showcases/water.res now also receives live sun/night tint and moon uniforms. Night landscape and loading briefing visually reviewed; test saves isolated. Directional energy 0.14, nearby fill enabled, no extra shadows, daylight fade verified.

### Moonlight tuning follow-up
Planet diameter 20 degrees. Nearby fill multiplier 1.3 -> 1.9, attenuation 1.5 -> 1.2, same 28 m range. Water moon lobe exponent 64 -> 32 plus a subtle exponent-10 skirt; gain .65 -> .9 for a broader shimmering area. Parameter-only visual adjustment; no full terrain benchmark repeated.

## World-lit first-person weapons - 2026-10-27

The weapon SubViewport previously had a permanent white ambient energy of .7 and a fixed directional studio light. weapon_world_lighting.gd now mirrors world sun, moon and ambient illumination into that isolated viewport, transforming directional bases into camera space. Nearby moon fill contributes a small ambient lift. No new shadow maps. The shared viewport covers guns and hands.

Checks run at 10 Hz while the viewmodel is active; quantized unchanged lighting preserves its cached image. Changed lighting requests a redraw, while weapon switches/other existing redraws also force a current lighting sample. Does not sample world occlusion or arbitrary point lights: this restores the outdoor sun/moon/weather response.

Rendered check_weapon_world_lighting.gd passed daylight, view rotation, moonlight, dark gap and unchanged-cache retention. Inspected actual Halo CE plasma-rifle captures weapon-light-day/moon/gap.png; no fixed-light appearance remains. Planet settings unchanged.
