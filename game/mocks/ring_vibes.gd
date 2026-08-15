extends Node3D

# VehicleDef is preloaded, not referenced by class_name. A `class_name` only resolves once the
# Godot EDITOR has registered it in the global class cache, and this project runs headless --
# so the type was unresolvable and the whole script failed to parse. Exactly the failure the
# hedge texture had: a new file that silently needs the editor to have opened it once.
const VehicleDef = preload("res://mocks/vehicle_def.gd")
const WeaponDef = preload("res://mocks/weapon_def.gd")
# Ring scale vibe mock — issue #9. Standalone: open this scene, F6.
# Honest geometry: camera stands on the interior of a cylinder of radius R.
# Config keys: 1/2/3 circumference, Q/W/E width, Up/Down haze, T sun speed, P pause sun, F flip sun, R rebuild.
#
# Terrain graduated 2026-07-27 from the terrain-lod/object-lod branches: CDLOD quadtree (morphed,
# real DEM + Sentinel-2/roads drape, procedural fallback beyond the DEM patch) replaces the old
# static band+strip meshes near the camera; a static coarse band still covers the REST of the ring
# (see mocks/LOD-STRESS-FINDINGS.md) so the far-side curve reveal still reads. Trees graduated from
# object-lod: distance-bucketed LOD0/1/2/billboard from a real LOD pack, analytic placement (no
# raycast — the CDLOD bubble is always finest-LOD at the camera/forest, so analytic height already
# matches the drawn mesh exactly; this also means player/car no longer raycast onto collision).

const CIRCUMFERENCES := [1_500_000.0, 2_097_152.0, 3_000_000.0]  # m (2^21 = substrate proposal)
const WIDTHS := [10_000.0, 32_768.0, 50_000.0]                    # m (2^15 = substrate proposal)
const SUN_PERIODS := [0.0, 1140.0, 60.0, 8.0]                     # s per full day: off, ~19min honest, fast, terminator-sweep
# the orbit was exactly Z=0 -- exactly the ring's own cross-section plane -- so the sun always sat
# on the same great-circle as the ring's silhouette (always "behind" it). Tilting the orbit off that
# plane by SUN_TILT means the ring only occults the sun where the tilted path crosses back through
# Z=0, which happens twice per cycle (at sun_angle = pi/2 and 3pi/2), not continuously.
var sun_tilt := deg_to_rad(15.0)   # live-tunable via the [O] panel; also sets rim-wall shadow reach
# single source of truth for both the sky dome (ring_sky.gdshader) and the terrain/band/wall fog-
# fade target -- these used to be two independent hardcoded gradients (a leftover flat-background
# color calc never updated when the real sky shader was built), so far from spawn the terrain's fog
# faded toward a colour that didn't match what the actual sky looked like there, reading as "haze
# only works near the start."
const DAY_ZENITH := Color(0.20, 0.42, 0.72)
const DAY_HORIZON := Color(0.62, 0.74, 0.86)
const NIGHT_ZENITH := Color(0.02, 0.03, 0.06)
const NIGHT_HORIZON := Color(0.07, 0.09, 0.15)
# 1024 segs over 3000km was 2.9km per segment -- too coarse to resolve an 84km splice into anything
# but a smear (~29 segments per patch). 3000 gives 1km segments, ~84 per patch.
const BAND_SEGS := 3000
const BAND_ROWS := 16
const WALL_HEIGHT := 3_000.0
const WALL_RAMP := 2_500.0        # lat meters over which wall rises
const RIDGE_ARC := 50_000.0       # far-band decorative ridge (never walked to — see _far_terrain_h)
const RIDGE_AMP := 1_500.0
const NOISE_AMP := 1_100.0

var c_idx := 2   # locked 2026-07-23: widest circumference (3,000 km) — mock-tested, see TODO.md
var w_idx := 2   # locked 2026-07-23: widest width (50 km)
var haze_density := 0.00001       # 1/m — ~100km extinction (Up/Dn tunes). Stretching haze to try to
                                   # reach the far side (hundreds of km away) was the wrong approach --
                                   # haze should only read as atmosphere within the immediate pre-horizon
                                   # playspace (the near DEM/CDLOD area); the sense of the far ring is a
                                   # cloud layer's job (see mocks/ring_clouds.gd), not haze stretched thin.
# ATMOSPHERE EXIT. Climb out and the daylight sky effects have to go, or space reads as "very high
# up on a blue day" instead of space. Drives haze, sky tint, star visibility and ambient fill off
# one altitude factor. No shader change needed -- the sky already takes its colours as uniforms.
# These were 14km and 48km -- Earth's numbers, and wrong for this place. A ringworld has no gravity
# well to hold an atmosphere; spin presses it to the floor, but nothing stops it spilling over the
# rim. Something at the edge has to contain it, and that container is what sets the ceiling.
#
# Briefly this was derived from wall_top_h, which was wrong in a different way: it made ONE number
# answer two unrelated questions. Wall height is an AESTHETIC call -- at 4km the rim dominates the
# horizon from anywhere on the ring -- while the ceiling is a GAMEPLAY call, the altitude where a
# wing gives up and thrusters take over. Tying them means you cannot lower the skyline without also
# lowering the flight envelope.
#
# So: the wall is the visible masonry, and a CONTAINMENT FIELD carries the rest of the way up. The
# air tops out at atmo_top_h whatever the wall does, and the field is simply the span the wall does
# not cover -- drawn as a faint shimmer, so the ceiling is something you can see rather than a number
# you discover by stalling.
const SPACE_LO_FRAC := 0.5        # fraction of the ceiling where thinning starts
var _space := 0.0                 # 0 = in atmosphere, 1 = space

func _space_lo() -> float:
	return atmo_top_h * SPACE_LO_FRAC

func _space_hi() -> float:
	return atmo_top_h
var _haze_off := false            # [N] disables haze entirely regardless of haze_density, for A/B testing
var _hud_full := true              # [TAB] collapses the control/debug text down to one line, for clean "vibe check" screenshots
var _clouds: Node3D = null          # [Z] cycle type, [X] toggle -- see mocks/ring_clouds.gd
var _panel: PanelContainer = null   # [O] live tuning sliders
var _panel_open := false
var _warp: PanelContainer = null    # [G] warp menu -- jump straight to a named splice
var _warp_open := false
var _warp_list: VBoxContainer = null
var _wall_shadow_soft := 220.0      # penumbra width at the wall-shadow edge, metres
var sun_speed_idx := 1
var sun_angle := 0.35             # radians around ring plane; 0 = noon at camera
var sun_paused := false

var _cam: Camera3D
var _hud: Label
var _perf: Label = null
var _perf_t := 0.0
var _probe_on := false
var _mat: ShaderMaterial          # far band material (ring_vibes.gdshader, unchanged)
var _band: MeshInstance3D
var _noise := FastNoiseLite.new() # far-band decorative ridge/noise fallback only (see _far_terrain_h)
var _look := Vector2.ZERO
var _captured := false
var _env: Environment
var _sky_mat: ShaderMaterial
# live debug readout for the day/night investigation -- ground truth numbers instead of guessing
# from screenshots. cam_theta/sun_theta in degrees, 0 = spawn's arc position.
var _dbg_cam_theta_deg := 0.0
var _dbg_sun_theta_deg := 0.0
var _dbg_local_lit := 0.0
var _dbg_day := 0.0
var _sun: DirectionalLight3D = null

# Real-DEM terrain (splice_dem prototype) — generated by tools/dem/export_to_game.py, gitignored
const DEM_R16 := "res://mocks/dem/millstreet.r16"
const DEM_META := "res://mocks/dem/millstreet.json"
const DEM_SAT := "res://mocks/dem/millstreet_sat.dat"
const DEM_ROADS := "res://mocks/dem/millstreet_roads.dat"
# R/G encode east/north height gradients at FULL DEM resolution, B = height/4m. Gives the home area
# per-pixel relief shading finer than the mesh itself carries. The CDLOD rewrite dropped this and
# the starting area lost its crispness as a result -- restored 2026-07-29.
const DEM_DETAIL := "res://mocks/dem/millstreet_detail.dat"
var _dem := PackedByteArray()     # full-res u16 heights, /16 = metres (far-band fallback path only)
var _dem_w := 0
var _dem_h := 0
var _dem_mpp := 23.45
# heights are u16 in units of 1/h_scale metres; read from each patch's JSON. Defaults to the old 16
# for files exported before the scale changed to 4 (16 clipped anything above 4095.9m -- 17% of the
# Atacama patch came out as a flat fake plateau).
var _dem_hscale := 16.0
var _dem_cam := Vector2i.ZERO
var _dem_name := ""
var _sat_tex: ImageTexture = null
var _roads_tex: ImageTexture = null
# CPU copy of the road mask, so the scatter can read it. The shader has had this texture all
# along, but nothing on the CPU could tell a road from a field, which is why conifers grew down
# the middle of the N72. Kept as raw bytes at ROAD_RES rather than an Image: the scatter takes
# five samples per candidate over ~90k candidates, and get_pixel() at that rate is not viable.
const ROAD_RES := 2048
# Thresholds are calibrated to the DOWNSAMPLED mask, not the 8192^2 one the shader reads. Roads are
# 1-3px lines up there, so resizing to 2048 spreads each one into a low, soft ridge -- measured max
# over the spawn area is 0.306, which is why a 0.35 cut-off matched nothing at all. The upside is
# that the blur is itself a proximity field, so a second set of offset probes is unnecessary:
# high = carriageway, low-but-present = the verge beside it.
const ROAD_ON := 0.14             # at/above this, it is road surface: nothing grows
const ROAD_NEAR := 0.03           # above this but below ROAD_ON: roadside, plant a hedge
var _road_mask := PackedByteArray()
# Loaded as raw bytes from a .dat, not as a res:// texture. A .jpg dropped into the project has no
# .import file until the Godot editor has been opened, so ResourceLoader.exists() returned false
# and this silently fell through to the procedural fallback -- which looked like a working hedge
# with a bad texture rather than a texture that never loaded at all. Same PNG-in-dat convention
# the DEM drapes already use to sidestep the importer.
const HEDGE_TEX := "res://mocks/dem/hedge_tex.dat"
# 2200m needed ~42k quads to cover rural Cork road density and so ran into the cap, which breaks
# out of the build in list order rather than by distance -- meaning the road you are ON can go
# unhedged while one 2km away is done. 1400m covers completely inside the budget.
const HEDGE_RANGE := 1400.0       # metres of road either side of the camera that gets hedged
const HEDGE_STEP := 11.0          # resample spacing along a centreline, metres
# Roadside boundary CHARACTER per biome. One profile and one colour everywhere was wrong: an
# Irish blackthorn bank, a Mediterranean dry-stone wall and a tropical roadside are not the same
# object. Keyed off the biome tree density, which already tracks how much grows here.
#   [half-width, height, colour, gap chance]  -- gap chance opens field entrances and lay-bys
const HEDGE_KINDS := {
	"bank":  {"w": 0.78, "h": 1.90, "col": Color(1.00, 1.00, 1.00), "gap": 0.04},   # Irish/Atlantic
	"scrub": {"w": 0.62, "h": 1.15, "col": Color(1.06, 0.98, 0.72), "gap": 0.16},   # dry, gappy
	"wall":  {"w": 0.45, "h": 1.05, "col": Color(0.86, 0.84, 0.76), "gap": 0.10},   # stone, arid
	"none":  {"w": 0.00, "h": 0.00, "col": Color(1, 1, 1), "gap": 1.00},
}
const HEDGE_MAX_QUADS := 30000    # ceiling on the ribbon, so a dense junction cannot spike frame time
var _hedge_mi: MeshInstance3D = null
var _roadlines: Array = []
var _junc := {}                   # 30m cells where two or more ways meet
var _road_cells := {}             # 8m cells containing carriageway
var _roadline_patch := -1         # which splice's centrelines are resident
var _grass_shown := 0
var _species_now := "fir"
var _hedge_quads := 0
var _detail_tex: ImageTexture = null
var dem_scale := 1.0  # [H] cycles 1..5 — real-height exaggeration (DEM branch only)

# CDLOD terrain (see mocks/cdlod.gd for the original prototype + tuning notes)
const GRID := 16
const MAX_LEVEL := 9
const LEAF_SIZE := 128.0
const BASE_RANGE := 200.0
const TERRAIN_SIZE := 262144.0    # ~262km LOD bubble centred on the DEM/spawn area
const DISP := 800.0
const FEATURE := 3500.0
const POOL := 1200
const SKIRT := 0.15
const MORPH_LO := 0.9             # tuned live in cdlod.gd to a hairline seam; baked in here
const MORPH_HI := 1.0
var _grid_mesh: ArrayMesh
var _pool: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []
var _used := 0
var _lod_range: Array[float] = []
var _heightmap: NoiseTexture2D    # procedural fallback texture, beyond the DEM patch
var _dem_tex: ImageTexture = null # half-res float DEM for the shader + exact CPU height queries
var _dem_hf := PackedFloat32Array()
var _dem_hf_w := 0
var _dem_hf_h := 0
var _dem_hf_mpp := 46.9
var _dem_hf_cam := Vector2.ZERO
var _show_lod := false            # [M] LOD-colour debug view

# ---------------------------------------------------------------------------------------------
# Multi-patch splice system (2026-07-29). millstreet stays the high-res HOME patch (loaded above,
# full resolution, where you actually play). Secondary splices are placed around the arc at their
# geography.md positions and packed into one Texture2DArray at reduced resolution -- they exist to
# make the ring VARY as you travel, are only ever seen at distance or in passing, and 7 of them at
# full res would be both a big VRAM bill and pointless detail. Gaps between patches fall through to
# procedural terrain, which is unavoidable anyway: 3000km of arc, patches are 22-84km.
# ---------------------------------------------------------------------------------------------
# Progressive reduction: source patches are 3584^2 heights + 4096^2 imagery (~54MB each on disk).
# Tiling the whole ring at that resolution is ~2GB and pointless -- you only ever stand in one
# patch. So the array tier is downsampled hard; the home patch keeps its full-res path.
# 36 patches x 512^2: heights 37MB (RF) + colour 28MB (RGB8). Comfortable on shared-memory UHD.
const PATCH_RES := 512            # height resolution in the array  (84km / 512 = 164 m/px)
const PATCH_COL_RES := 512        # colour resolution in the array
const MAX_PATCHES := 40           # ring needs 36 at 84km; headroom for overlap/repeats
# arc_pct follows docs/geography.md's walked-spinward layout; tint is a broad biome colour used
# instead of a satellite drape (fetching Sentinel-2 for every patch is a separate, heavier job).
# `trees` is density 0-1 and `tree_hi` the altitude ceiling in metres (a crude treeline). Both are
# biome facts, not decoration: nothing grows on a salt flat, the Dolomites are bare above ~2000m,
# and the whole reason tatra_spruce got reclassified during scouting was a treeline check.
# FULL RING COVERAGE. 84km patches are 2.8% of arc each, so 36 tile the 3000km circumference;
# millstreet holds 0% as the home patch and the remaining 35 slots run spinward at 2.8% intervals,
# ordered to follow docs/geography.md's walked-spinward biome sequence (city -> ford-town -> sea ->
# barrens -> enclave/desert -> steppe -> highland -> jungle -> lost-world -> eroded hub approach).
# The last three repeat earlier eroded/volcanic splices to close the loop rather than leave a
# procedural gap on the hub-spire approach -- duplicated array layers, which is cheap at 512^2.
# Entries whose data hasn't been fetched yet are skipped at load, so this list is safe to keep
# complete while tools/dem/pipeline.py is still running.
const PATCHES := [
	{"name": "schwarzwald", "arc_pct": 0.028, "tint": Color(0.13, 0.22, 0.14), "trees": 1.0, "tree_hi": 1400.0, "weather": "fresh"},
	{"name": "cork_city", "arc_pct": 0.056, "tint": Color(0.34, 0.38, 0.30), "trees": 0.3, "tree_hi": 200.0, "weather": "fresh", "species": "broadleaf"},
	# COASTAL BATCH. The ring came out ~95% land because every box was centred on a landform; these
	# five are centred on WATER. Sea fraction, measured: palawan 88%, lofoten 84%, cape 80%,
	# halong 64%, big_sur 29%. They also retire the last two duplicate slots and the two patches
	# that had drifted out of character once the boxes went to 84km, so coverage is now 35/35 unique.
	{"name": "big_sur", "arc_pct": 0.084, "tint": Color(0.24, 0.30, 0.20), "trees": 0.5, "tree_hi": 1200.0, "weather": "fresh", "species": "broadleaf"},
	{"name": "wye_valley", "arc_pct": 0.112, "tint": Color(0.32, 0.40, 0.22), "trees": 0.5, "tree_hi": 400.0, "weather": "overcast", "species": "broadleaf"},
	# imaged: dense dark forest with agricultural clearings and a river. 0.5 was well under it.
	{"name": "dordogne", "arc_pct": 0.140, "tint": Color(0.20, 0.26, 0.15), "trees": 0.85, "tree_hi": 450.0, "weather": "fresh", "species": "broadleaf"},
	# imaged: near-continuous forest, only narrow valley clearings and small towns on the roads.
	# 99% measured and the image agrees, so 0.6 was well under. Forest carries over most summits.
	{"name": "vermont", "arc_pct": 0.168, "tint": Color(0.13, 0.24, 0.12), "trees": 0.92, "tree_hi": 1100.0, "weather": "fresh", "species": "broadleaf"},
	{"name": "mizen_head", "arc_pct": 0.196, "tint": Color(0.30, 0.38, 0.30), "trees": 0.25, "tree_hi": 300.0, "weather": "storm", "species": "scrub"},
	{"name": "camargue", "arc_pct": 0.224, "tint": Color(0.40, 0.44, 0.36), "trees": 0.1, "tree_hi": 30.0, "weather": "fresh", "species": "scrub"},
	# imaged 2026-08-08: the 92% "vegetation" the census measures is REED BED, not canopy, so
	# trees 0.1 is right and stays. sea_pct lifts the datum so the reed bed reads as land, not
	# ocean: the DEM is 63.8% sea at the 0.5m clamp but the imagery is ~25% water (see patch-review).
	{"name": "danube_delta", "arc_pct": 0.252, "tint": Color(0.30, 0.34, 0.24), "trees": 0.1, "tree_hi": 40.0, "weather": "overcast", "species": "scrub", "sea_pct": 25.0},
	# fynbos, not forest -- scrub to the waterline on both oceans, and almost no trees
	{"name": "cape_peninsula", "arc_pct": 0.280, "tint": Color(0.38, 0.38, 0.28), "trees": 0.15, "tree_hi": 700.0, "weather": "clear", "species": "scrub"},
	{"name": "salar_uyuni", "arc_pct": 0.308, "tint": Color(0.78, 0.78, 0.80), "trees": 0.0, "tree_hi": 0.0, "weather": "cirrus"},
	{"name": "scablands", "arc_pct": 0.336, "tint": Color(0.44, 0.40, 0.32), "trees": 0.0, "tree_hi": 0.0, "weather": "cirrus"},
	{"name": "loop_head", "arc_pct": 0.364, "tint": Color(0.30, 0.38, 0.30), "trees": 0.2, "tree_hi": 250.0, "weather": "storm", "species": "scrub"},
	{"name": "monument_valley", "arc_pct": 0.392, "tint": Color(0.62, 0.38, 0.24), "trees": 0.0, "tree_hi": 0.0, "weather": "cirrus"},
	{"name": "atacama", "arc_pct": 0.420, "tint": Color(0.58, 0.44, 0.32), "trees": 0.0, "tree_hi": 0.0, "weather": "cirrus"},
	{"name": "namib_dunes", "arc_pct": 0.448, "tint": Color(0.64, 0.42, 0.24), "trees": 0.0, "tree_hi": 0.0, "weather": "cirrus", "species": "scrub"},
	# imaged: dry brown scrub west, reservoir and forest east, split by the worst mosaic seam in
	# the portfolio -- two scenes, different seasons. trees 0.4 averages the two halves fairly;
	# tint was green where the dominant half is brown.
	{"name": "guri_dam", "arc_pct": 0.476, "tint": Color(0.30, 0.26, 0.19), "trees": 0.4, "tree_hi": 500.0, "weather": "monsoon", "species": "broadleaf"},
	{"name": "palawan", "arc_pct": 0.504, "tint": Color(0.18, 0.28, 0.20), "trees": 0.9, "tree_hi": 900.0, "weather": "monsoon", "style": "meru", "foliage": Color(1.05, 1.02, 0.66), "tree_mul": 1.3, "species": "palm"},
	# imaged: olive-brown semi-arid, finely dissected, no tree in 93km. trees 0.05 confirmed --
	# the census reads 80% "vegetation" here because excess-green fires on khaki. tint nudged
	# warmer to the measured mean; tree_hi is vestigial at this density.
	{"name": "mongolia_steppe", "arc_pct": 0.532, "tint": Color(0.44, 0.40, 0.26), "trees": 0.05, "tree_hi": 1900.0, "weather": "cirrus"},
	{"name": "tuscany_hills", "arc_pct": 0.560, "tint": Color(0.42, 0.42, 0.26), "trees": 0.6, "tree_hi": 700.0, "weather": "fresh", "species": "broadleaf"},
	{"name": "slea_head", "arc_pct": 0.588, "tint": Color(0.30, 0.38, 0.30), "trees": 0.2, "tree_hi": 350.0, "weather": "storm", "species": "scrub"},
	{"name": "priests_leap", "arc_pct": 0.616, "tint": Color(0.28, 0.34, 0.26), "trees": 0.5, "tree_hi": 450.0, "weather": "overcast"},
	# imaged 2026-08-08: heather moor throughout, forestry confined to the straths, bare granite
	# plateau in the middle. Authored trees 0.5 was roughly double the real canopy, and the
	# plantations stop well under the old 700m ceiling.
	{"name": "cairngorms", "arc_pct": 0.644, "tint": Color(0.30, 0.27, 0.18), "trees": 0.25, "tree_hi": 550.0, "weather": "storm", "species": "scrub"},
	# imaged: conifer fills the valleys, pale limestone massifs above a hard treeline. trees 0.7
	# and tree_hi 2000 both check out; the TINT was set to the rock when forest dominates the frame.
	{"name": "dolomites", "arc_pct": 0.672, "tint": Color(0.26, 0.28, 0.22), "trees": 0.7, "tree_hi": 2000.0, "weather": "fresh"},
	# imaged: spruce dominates, bare granite and tarns only on the central massif above a hard
	# treeline. trees 0.7 and tree_hi 1500 both correct; the tint was rock-grey, same mistake as
	# dolomites -- named for the headline feature instead of what fills the frame.
	{"name": "tatra_spruce", "arc_pct": 0.700, "tint": Color(0.21, 0.26, 0.17), "trees": 0.7, "tree_hi": 1500.0, "weather": "fresh"},
	{"name": "norwegian_fjord", "arc_pct": 0.728, "tint": Color(0.30, 0.36, 0.32), "trees": 0.6, "tree_hi": 900.0, "weather": "storm"},
	{"name": "olympic_forest", "arc_pct": 0.756, "tint": Color(0.14, 0.24, 0.16), "trees": 1.0, "tree_hi": 1200.0, "weather": "overcast"},
	{"name": "borneo_highland", "arc_pct": 0.784, "tint": Color(0.16, 0.28, 0.16), "trees": 1.0, "tree_hi": 2500.0, "weather": "monsoon", "species": "broadleaf"},
	{"name": "costa_rica_jungle", "arc_pct": 0.812, "tint": Color(0.16, 0.30, 0.18), "trees": 1.0, "tree_hi": 2000.0, "weather": "monsoon", "species": "broadleaf"},
	{"name": "tepui", "arc_pct": 0.840, "tint": Color(0.24, 0.32, 0.24), "trees": 0.5, "tree_hi": 1500.0, "weather": "monsoon", "species": "broadleaf"},
	{"name": "iceland_highland", "arc_pct": 0.868, "tint": Color(0.42, 0.36, 0.32), "trees": 0.02, "tree_hi": 400.0, "weather": "storm", "species": "scrub"},
	{"name": "badlands_sd", "arc_pct": 0.896, "tint": Color(0.54, 0.44, 0.34), "trees": 0.05, "tree_hi": 900.0, "weather": "cirrus"},
	# East Java: teak over volcanic ash, Arjuno-Welirang at 3,339m, and Trowulan -- a living town
	# sitting on the Majapahit capital. Tropical treeline runs high, so the massif is wooded almost
	# to the summit. "style": meru gives it tiered roofs instead of the default gable.
	{"name": "java_majapahit", "arc_pct": 0.924, "tint": Color(0.17, 0.27, 0.16), "trees": 1.0, "tree_hi": 2900.0, "weather": "monsoon", "style": "meru", "foliage": Color(1.06, 1.02, 0.62), "tree_mul": 1.45, "species": "palm"},
	{"name": "halong_bay", "arc_pct": 0.952, "tint": Color(0.20, 0.30, 0.22), "trees": 0.7, "tree_hi": 600.0, "weather": "monsoon", "style": "meru", "foliage": Color(1.02, 1.03, 0.72), "tree_mul": 1.1, "species": "broadleaf"},
	# arctic: birch scrub in the shelter of the fjords, bare rock above it
	{"name": "lofoten", "arc_pct": 0.980, "tint": Color(0.34, 0.36, 0.32), "trees": 0.08, "tree_hi": 250.0, "weather": "storm", "species": "scrub"},
]
const HOME_TREES := 1.0        # millstreet: Irish valley, trees throughout
const HOME_TREE_HI := 600.0
var _lod_center_arc := 0.0        # arc the CDLOD bubble is centred on, snapped to a root
var _band_cd := 0.0
const BAND_REBUILD_MAX_SPEED := 3000.0   # m/s above which the band rebuild waits
var _tree_center := Vector2.ZERO      # (arc, lat) the current forest was scattered around
# Real-OSM buildings (tools/dem/fetch_osm_buildings.py). Position is real; footprint and roof are
# stand-ins, exactly as the road drape is real geometry with invented surfacing.
const BLDG_RADIUS := 8000.0        # instance houses within this of the camera, metres
const BLDG_RESCATTER := 500.0      # camera travel before the visible set is rebuilt
const BLDG_MAX := 14000            # hard instance cap
var _bldg := PackedFloat32Array()  # world arc, lat, w, d, yaw, height -- 6 floats per building
var _bldg_mmi: Array = []           # one MultiMeshInstance3D per building style
var _bldg_style := PackedByteArray()  # style index per building
var _bldg_focus := {}               # patch name -> world (arc, lat) of its densest cluster
var _bldg_center := Vector2(1e12, 1e12)
var _bldg_shown := 0
const TREE_RESCATTER := 700.0         # re-scatter once the camera has moved this far from it
# A scatter walks a 90,000-position grid with per-candidate terrain lookups (~100ms). At 5x fly
# boost you cross TREE_RESCATTER every 0.17s, which would mean ~6 full scatters per SECOND and a
# dead framerate. So: a hard cooldown, and no re-scatter at all while travelling fast -- at boost
# speed the forest is billboards streaming past and nobody is inspecting where the trees are.
const TREE_RESCATTER_CD := 2.0        # seconds; floor on how often a scatter can run
const TREE_RESCATTER_MAX_SPEED := 120.0   # m/s above which scattering is skipped entirely
var _tree_cd := 0.0
var _cam_prev_pos := Vector3.ZERO
var _cam_speed := 0.0
var _patch_tex: Texture2DArray = null
var _patch_col_tex: Texture2DArray = null   # real Sentinel-2 per patch, replaces the flat tints

# --- streaming high-res tier -------------------------------------------------------------------
# The 512^2 array is 164 m/px over an 84km patch -- fine at distance, mush underfoot. So the patch
# you are actually STANDING IN gets streamed in at HIRES_RES and takes priority. Decoding a 3584^2
# u16 heightmap is a multi-million-iteration GDScript loop (~1s), which would hitch every time you
# crossed a patch boundary, so it runs on a WorkerThreadPool task and the texture is created on the
# main thread when the task reports done. Every step is guarded: any failure just leaves the array
# tier serving that patch, which is exactly the pre-streaming behaviour.
const HIRES_RES := 1536       # streamed height resolution
# Colour/detail stream at higher res than heights -- they are pure texture lookups, so resolution is
# cheap there, whereas heights cost a GDScript decode loop per texel. 2048^2 RGB is ~12.6MB each;
# with the height field that is ~35MB resident for the active patch, comfortable on shared-memory UHD.
# (The home patch still uses its native 4096^2 imagery, so it remains slightly ahead.)
# VRAM compression for the streamed drape. A PNG is compressed on DISK and then decompressed to
# raw pixels in VRAM -- 4096^2 RGB8 is 50MB there no matter how small the file was. DXT/BPTC stay
# compressed in memory and are decoded per-sample by the texture unit, so the saving is permanent
# and free to read. [U] cycles them so they can be compared on the actual GPU rather than argued
# about: DXT1 is 8x smaller than RGBA8 but blocky on gradients, BPTC is 4x and much closer to
# lossless. Satellite imagery is high-frequency and noisy, which hides block artefacts well.
enum TexMode { RAW, S3TC, BPTC }
var _tex_mode: int = TexMode.S3TC   # measured 8MB vs 48MB at 4096; [U] to compare
var _tex_step := 1   # matches the S3TC default above
var _tex_bytes := 0            # actual bytes of the streamed colour image, whatever the format
# Matches the Sentinel-2 canvas fetch_s2.py writes (OUT_W/H = 4096), i.e. ~24 m/px over an 84km
# patch. Going above this in the runtime only interpolates -- the extra pixels carry no
# information. Real detail needs OUT_W/H raised and the imagery refetched; S2 is 10 m/px native,
# so 8192 would be a genuine 2x and, as S3TC, would cost 32MB against the 48MB 4096-raw costs now.
# A var rather than a const so a refetched patch can be tested without a rebuild.
var hires_tex_res := 8192   # CAP, not a target -- see the resize in _hires_decode
var _hires_tex: ImageTexture = null
var _hires_col_tex: ImageTexture = null
var _hires_detail_tex: ImageTexture = null
var _hires_idx := -1              # patch index currently resident at high res
var _hires_pending := -1          # patch index being decoded right now
var _hires_task := -1             # WorkerThreadPool task id, -1 = idle
var _hires_result := {}           # filled by the worker, consumed on the main thread
var _hires_field := PackedFloat32Array()   # CPU copy, so _terrain_h matches the streamed tier
var _hires_res := 0
var _jump_idx := -1               # [,] / [.] cycle through loaded splices
var _patch_rects := PackedVector4Array()   # (arc_centre, lat_centre, half_arc, half_lat) metres
var _patch_tints := PackedColorArray()
var _patch_fields: Array = []              # CPU copies, so placement matches what's drawn
var _patch_names: Array = []
# PATCHES entries whose data hasn't been fetched are SKIPPED at load, so loaded-patch indices do
# NOT line up with PATCHES indices. Everything downstream must go through these parallel arrays --
# indexing PATCHES with a loaded-patch index silently reads a different location's biome/filename
# (caught by the --selftest: it made 6 of 10 streams load the wrong file and fail).
var _patch_own := PackedFloat32Array()   # ownership half-arc per patch: half the gap to
                                        # its nearest neighbour. NOT _patch_rects.z, which
                                        # is the sampling extent and must stay unclipped.
var _patch_meta: Array = []
# Per-patch height re-basing -- OFF by design (2026-07-29, user call: "lock them to their real
# heights"). Splices are real places with real absolute elevations: the Bolivian altiplano floors at
# 3562m, the Camargue at 1m. With re-basing off, each patch renders at its TRUE elevation, which is
# the honest data and the right base to judge edge work against.
#
# The cost is real and expected: butting real elevations edge-to-edge produces ~3.5km cliffs at
# patch boundaries (salar_uyuni vs scablands) and ~1.2km elsewhere. Re-basing shifted every
# high-floored patch down to a common low floor to hide that. Kept, not deleted, because it is the
# fallback if edge feathering turns out not to be enough on its own.
const REBASE_PATCHES := false
var _patch_offset := PackedFloat32Array()
const REBASE_ABOVE := 100.0   # only re-base patches whose floor exceeds this
const REBASE_FLOOR := 20.0    # where a re-based floor lands (above SEA_LEVEL, so salt flats stay dry)

enum Mode { FLY, DRIVE, WALK }
var _mode: Mode = Mode.FLY
const WALK_SPEED := 10.0   # reused from game/player.gd's SPEED for consistency with the real game
const WALK_RUN_MULT := 2.0
const EYE_HEIGHT := 1.7
var _walk_arc := 0.0
var _walk_lat := 0.0

# fly speed: [Shift] used to be held-for-boost; now a 3-way toggle (normal/boost/5x-boost) since
# a 3000km ring makes even the old boost speed tedious for covering real distance.
# 20x boost (16000 m/s) laps the 3000km ring in ~3min, so the whole circumference is reviewable in
# one sitting rather than 12 minutes at 5x.
const FLY_SPEEDS := [60.0, 800.0, 4000.0, 16000.0]
var _fly_speed_idx := 0

# Drive mode: car lives in ring coordinates, no physics — terrain sampled analytically
var _car: Node3D = null
var _wheels: Array = []           # [{pivot, mesh, front}] -- rolling and steering
var _vehicles: Array = []         # [{root, wheels, name}] -- [L] cycles between them in DRIVE
var _veh_idx := 0
var _vehicle_defs := {}           # name -> VehicleDef, built lazily from VEHICLE_ROWS on first _vdef()
const WARTHOG_PACK := "res://halo_warthog/scene.gltf"  # local-only asset (gitignored); box car is the fallback
const VEHICLE_LEN := 5.2          # metres nose-to-tail; the box car is 4.2, the warthog reads as bigger
# Scale and length-axis are measured from the model's AABB, so the only thing not derivable is which
# END is the nose. Eyeball logs/shots/vehicle_warthog.png; if it drives tail-first, set this to PI.
const WARTHOG_YAW := 0.0
var _wheel_spin := 0.0
var _gait_phase := 0.0            # legged stride cycle, advances with distance travelled (see _loco_legged)
var _stamina := 1.0               # 1 = fresh, 0 = spent; a mount that tires (horse) drains this galloping
var _spooked := 0.0               # 0 = calm, 1 = bolting; ramps up while a threat closes (see _loco_legged)
var _jump_h := 0.0                # metres above the ground point; >0 = airborne (powered suit only, see _drive_tick)
var _jump_v := 0.0                # vertical velocity along ring-up, m/s
var _land_dip := 0.0              # hard-landing body crouch, scaled by impact speed, decays back to 0
var _sprinting := false           # sprint input held this tick (suit); _loco_legged reads it for the burst
var _dust: GPUParticles3D = null
var _offroad := 0.0               # 0 = on tarmac, 1 = fully off it
var _cam_ring := Vector3.ZERO     # camera in RING space (arc, height, lat) -- see _select_lod
var _wave_time := 0.0             # sea-swell clock; drives the shader's wave_time AND the CPU twin _wave_h
var _aground := false             # a hull run into water shallower than its draft; kills way and rudder
var _boat_vel := Vector2.ZERO     # hull velocity in ring (arc,lat) -- a boat's course is not its heading
var _air_vel := Vector2.ZERO      # ballistic course in ring (arc,lat) -- above the air it stops following the nose
var _dive := 0.0                  # metres a submersible sits BELOW the water surface; 0 = surfaced (see _loco_sub)
var _altitude := 0.0              # metres a flyer sits ABOVE the surface along ring-up; 0 = on the ground (see _loco_air)
var _vspeed := 0.0                # a flyer's vertical speed, m/s along ring-up (climb +, sink -)
var _docked := false              # latched onto the axis-structure port; motion frozen, station held (see _dock_update)
var _boarded := false             # left the pilot seat for the structure while docked ([Enter]); interior authored later
var _car_arc := 0.0
var _car_lat := 0.0
var _car_heading := 0.0
var _car_speed := 0.0
var _hud_timer := 0.0

# First-slice creature test (slice-mock.md) — generic startle/flee proxy, deer + wolf presets
const CreatureScript := preload("res://mocks/creature.gd")
var _creatures: Array = []
var _threat_active := false
var _walls: Array[Node3D] = []   # rim walls, field curtains and the dock port: freed together on rebuild
var _field_mat: ShaderMaterial = null   # containment-field shimmer above the rim walls
var _wall_mat: ShaderMaterial = null

# Object-LOD trees (ported from object-lod branch, see mocks/LOD-STRESS-FINDINGS.md "Object LOD: trees")
const TREE_PACK := "res://realistic_fir_trees_pack_lods_gameready/scene.gltf"
const FOREST_HALF := 1200.0
const TREE_H := 9.0
const TREE_LODS := 4
const TREE_DENSITY := 0.6         # baked at the "full" setting that read well in cdlod.gd
var _forest_noise := FastNoiseLite.new()   # placeholder for L4 tree_density field, see TODO.md
var _tree_meshes: Array = []
var _tree_mm: Array = []
var _tree_nvar := 0
var _tree_scale := 1.0
var _foliage_shader: Shader = null
var _tree_ground := PackedVector3Array()
var _tree_basis: Array[Basis] = []
var _tree_variant := PackedInt32Array()
# Trample state (TASKS.md "Elephants"). _tree_down is a set of flattened tree indices (into the arrays
# above), skipped by _update_tree_lod when it rebuilds the MultiMesh buckets; _hedge_down is a list of
# ring (arc,lat) crush points the ribbon rebuild leaves gaps around. Both are only ever written by a
# vehicle with trample > 0 (the elephant) -- see _do_trample. _tree_down clears on rescatter (the indices
# no longer point at the same trees); _hedge_down is capped so old crushes regrow.
var _tree_down := {}
var _hedge_down: Array[Vector2] = []
var _trample_prev := Vector3.ZERO
const TRAMPLE_TREE_MAX_H := 9.6      # trees taller than this stand (fir pack's proxy for "too big to push over")
const TRAMPLE_HEDGE_MAX := 48        # cap on remembered hedge crush points; oldest regrows
const TRAMPLE_HEDGE_R2 := 49.0       # (7m)^2 -- a crush point clears hedge spans within 7m, covering the verge offset
var _tree_lod_dist := [20.0, 35.0, 55.0, 220.0]
var _tree_lod_scale := 1.0        # [G]/[B] tune all bands live
var _tree_fly_mult := 14.0        # FLY mode reaches this much further on the billboard tier
var _tree_last_cam := Vector3(1e9, 1e9, 1e9)
var _tree_counts := PackedInt32Array()

func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.fractal_octaves = 4
	_noise.frequency = 1.0 / 9_000.0
	_load_dem()
	_build_dem_texture()
	_load_patches()

	_cam = Camera3D.new()
	_cam.position = Vector3(0, 120, 0)
	_cam.near = 0.5
	_cam.far = 3_000_000.0
	add_child(_cam)
	_cam.make_current()

	_env = Environment.new()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://mocks/ring_sky.gdshader") as Shader
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.5, 0.6, 0.72)
	_env.ambient_light_energy = 0.4
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	# sun light for StandardMaterial3D objects (trees, car, creatures) — terrain/band/walls keep
	# their own manual in-shader lighting; this just makes the real-material props shade to match.
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 1.1
	add_child(_sun)

	var shader := load("res://mocks/ring_vibes.gdshader") as Shader
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	if _sat_tex:
		_mat.set_shader_parameter("sat_tex", _sat_tex)
		_mat.set_shader_parameter("has_sat", true)
	if _roads_tex:
		_mat.set_shader_parameter("road_tex", _roads_tex)
		_mat.set_shader_parameter("has_roads", true)
	# the far band uses the SAME splice patches as the near terrain -- see the note in
	# ring_vibes.gdshader; without this it tiled one location around ~2870km of the ring
	if _patch_col_tex:
		_mat.set_shader_parameter("patch_col_tex", _patch_col_tex)
		_mat.set_shader_parameter("patch_count", _patch_rects.size())
		_mat.set_shader_parameter("patch_rect", _patch_rects)
		_mat.set_shader_parameter("patch_own", _patch_own)
		_mat.set_shader_parameter("patch_tint", _patch_tints)
		_mat.set_shader_parameter("ring_circumference", CIRCUMFERENCES[c_idx])
	if _dem_w > 0:
		_mat.set_shader_parameter("home_patch_size",
			Vector2(float(_dem_w) * _dem_mpp, float(_dem_h) * _dem_mpp))

	var noise := FastNoiseLite.new()
	noise.frequency = 0.0025
	noise.fractal_octaves = 5
	_heightmap = NoiseTexture2D.new()
	_heightmap.width = 1024
	_heightmap.height = 1024
	_heightmap.seamless = true
	_heightmap.noise = noise
	await _heightmap.changed

	_grid_mesh = _build_unit_grid()
	var terrain_shader := load("res://mocks/cdlod_ring.gdshader") as Shader
	for i in POOL:
		var mat := ShaderMaterial.new()
		mat.shader = terrain_shader
		mat.set_shader_parameter("heightmap", _heightmap)
		mat.set_shader_parameter("terrain_size", TERRAIN_SIZE)
		mat.set_shader_parameter("disp", DISP)
		mat.set_shader_parameter("grid", float(GRID))
		mat.set_shader_parameter("feature", FEATURE)
		mat.set_shader_parameter("skirt", SKIRT)
		mat.set_shader_parameter("morph_horizontal", true)
		if _dem_tex:
			mat.set_shader_parameter("dem_tex", _dem_tex)
			mat.set_shader_parameter("dem_cam", _dem_hf_cam)
			mat.set_shader_parameter("dem_mpp", _dem_hf_mpp)
			mat.set_shader_parameter("dem_size", Vector2(_dem_hf_w, _dem_hf_h))
			mat.set_shader_parameter("use_dem", true)
		if _sat_tex:
			mat.set_shader_parameter("sat_tex", _sat_tex)
			mat.set_shader_parameter("has_sat", true)
		if _roads_tex:
			mat.set_shader_parameter("road_tex", _roads_tex)
			mat.set_shader_parameter("has_roads", true)
		if _detail_tex:
			mat.set_shader_parameter("detail_tex", _detail_tex)
			mat.set_shader_parameter("has_detail", true)
		mat.set_shader_parameter("sea_level", SEA_LEVEL)
		mat.set_shader_parameter("ocean_enabled", ocean_enabled)
		if _patch_tex:
			mat.set_shader_parameter("patch_tex", _patch_tex)
			mat.set_shader_parameter("patch_col_tex", _patch_col_tex)
			mat.set_shader_parameter("patch_count", _patch_rects.size())
			mat.set_shader_parameter("patch_rect", _patch_rects)
			mat.set_shader_parameter("patch_own", _patch_own)
			mat.set_shader_parameter("patch_tint", _patch_tints)
			mat.set_shader_parameter("patch_offset", _patch_offset)
			mat.set_shader_parameter("ring_circumference", CIRCUMFERENCES[c_idx])
		var mi := MeshInstance3D.new()
		mi.mesh = _grid_mesh
		mi.material_override = mat
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_pool.append(mi)
		_mats.append(mat)
	_recompute_lod_ranges()

	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)
	_hud = Label.new()
	_hud.position = Vector2(12, 12)
	_hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_hud.add_theme_constant_override("outline_size", 4)
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hud_layer.add_child(_hud)
	# always-on perf readout, top right, independent of [TAB]. Triangle count is the number that
	# actually explains this scene's frame time, and it was invisible while we kept adding to it.
	_perf = Label.new()
	_perf.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_perf.anchor_left = 1.0
	_perf.anchor_right = 1.0
	_perf.offset_left = -300.0
	_perf.offset_top = 12.0
	_perf.offset_right = -12.0
	_perf.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_perf.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_perf.add_theme_constant_override("outline_size", 4)
	_perf.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hud_layer.add_child(_perf)
	# built here, not with the tuning panel below: _rebuild() populates it, so the container
	# has to exist before _rebuild() runs or the menu comes up empty.
	_build_warp_panel(hud_layer)

	if _load_tree_lods():
		pass  # _scatter_trees() runs inside _rebuild() below
	_rebuild()
	if "--texprobe" in OS.get_cmdline_user_args():
		# nothing streams at spawn: the home DEM is not a splice patch, so _patch_at returns
		# -1 and the streaming tier never engages. Warp into one so there is something to measure.
		_warp_to(0)
	if _dem_w > 0:
		_cam.position.y = _terrain_h(0.0, 0.0) + 40.0  # spawn just above Millstreet

	if OS.get_cmdline_user_args().has("--selftest"):
		_run_selftest()
	if OS.get_cmdline_user_args().has("--align"):
		_align_sweep()
	if OS.get_cmdline_user_args().has("--shots"):
		_shot_run()
	if OS.get_cmdline_user_args().has("--proving"):
		_prove_run()
	if OS.get_cmdline_user_args().has("--range"):
		_range_run()
	_clouds = preload("res://mocks/ring_clouds.gd").new()
	_clouds.ring_radius = _radius()   # must be set BEFORE _ready() builds the bent sheets
	_clouds.ring_width = WIDTHS[w_idx]
	_clouds.wall_top = wall_top_h
	add_child(_clouds)
	_build_tuning_panel(hud_layer)

func _add_slider(vb: VBoxContainer, label: String, lo: float, hi: float, val: float, setter: Callable) -> void:
	var row := VBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "%s  %.2f" % [label, val]
	row.add_child(name_lbl)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 0.01
	sl.value = val
	sl.custom_minimum_size = Vector2(290, 0)
	sl.value_changed.connect(func(v: float) -> void:
		name_lbl.text = "%s  %.2f" % [label, v]
		setter.call(v))
	row.add_child(sl)
	vb.add_child(row)

func _build_warp_panel(layer: CanvasLayer) -> void:
	# One button per loaded splice, in arc order, with its arc % and biome. Built AFTER the patches
	# load so it lists what is actually on disk, not what PATCHES hopes for -- the same index
	# divergence that made _patch_meta necessary would otherwise send you to the wrong place.
	_warp = PanelContainer.new()
	_warp.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_warp.offset_left = 12.0
	_warp.offset_right = 372.0
	_warp.offset_top = 12.0
	_warp.offset_bottom = 700.0
	_warp.visible = false
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_warp.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	scroll.add_child(vb)
	_warp_list = vb
	var title := Label.new()
	title.text = "WARP  ([G] close)"
	vb.add_child(title)
	layer.add_child(_warp)

func _populate_warp_panel() -> void:
	if _warp_list == null:
		return
	for c in _warp_list.get_children():
		if c is Button:
			c.queue_free()
	var home := Button.new()
	home.text = "· home — %s" % DEM_R16.get_file().get_basename()
	home.pressed.connect(func(): _warp_to(-1))
	_warp_list.add_child(home)
	var circ: float = CIRCUMFERENCES[c_idx]
	var order := range(_patch_rects.size())
	order.sort_custom(func(a, b): return _patch_rects[a].x < _patch_rects[b].x)
	for i in order:
		var r: Vector4 = _patch_rects[i]
		var m: Dictionary = _patch_meta[i]
		var b := Button.new()
		b.text = "%5.1f%%  %s%s" % [100.0 * r.x / circ, _patch_names[i],
			"   [trees %.0f%%]" % (100.0 * float(m.get("trees", 0.0)))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _warp_to(i))
		_warp_list.add_child(b)

func _warp_to(idx: int) -> void:
	var rad := _radius()
	var arc := 0.0
	var lat := 0.0
	var label := "home"
	if idx >= 0 and idx < _patch_rects.size():
		var r: Vector4 = _patch_rects[idx]
		arc = r.x
		lat = r.y
		label = str(_patch_names[idx])
		if _bldg_focus.has(label):
			var f: Vector2 = _bldg_focus[label]
			arc = f.x
			lat = clampf(f.y, -WIDTHS[w_idx] * 0.45, WIDTHS[w_idx] * 0.45)
			label += " (settlement)"
		_jump_idx = idx
	_cam.position = _ring_pos(arc / rad, lat, _terrain_h(arc, lat) + 250.0)
	_look = Vector2(0.0, -0.18)
	_apply_look()
	_tree_center = Vector2(arc, lat)
	_scatter_trees()
	_refill_buildings(true)
	print("ring_vibes: warped to %s (%.1f%% arc)" % [label, 100.0 * arc / CIRCUMFERENCES[c_idx]])
	_update_hud()

func _build_tuning_panel(layer: CanvasLayer) -> void:
	# live cloud tuning -- feel is faster to dial in by dragging than by editing constants
	# anchored top-RIGHT and scrollable: sat on top of the HUD text at the old fixed left position,
	# and the last two sliders fell off the bottom of the screen entirely.
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -350.0
	_panel.offset_right = -12.0
	_panel.offset_top = 12.0
	_panel.offset_bottom = -12.0
	_panel.visible = false
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)
	var title := Label.new()
	title.text = "TUNING  ([O] close)   clouds: 1.00 = preset default"
	vb.add_child(title)
	_add_slider(vb, "coverage x", 0.2, 3.0, 1.0, func(v): _clouds.cov_mult = v; _clouds.retune())
	_add_slider(vb, "opacity x", 0.2, 2.0, 1.0, func(v): _clouds.alpha_mult = v; _clouds.retune())
	_add_slider(vb, "softness x", 0.2, 3.0, 1.0, func(v): _clouds.soft_mult = v; _clouds.retune())
	_add_slider(vb, "warp x", 0.0, 3.0, 1.0, func(v): _clouds.warp_mult = v; _clouds.retune())
	_add_slider(vb, "brightness x", 0.3, 2.0, 1.0, func(v): _clouds.bright_mult = v)
	# drift vs churn: churn must stay well under drift or clouds boil in place instead of moving
	_add_slider(vb, "wind (drift) x", 0.0, 6.0, 1.0, func(v): _clouds.wind_mult = v; _clouds.retune())
	_add_slider(vb, "churn (morph) x", 0.0, 8.0, 1.0, func(v): _clouds.churn_mult = v; _clouds.retune())
	var sun_title := Label.new()
	sun_title.text = "— sun / wall shadow —"
	vb.add_child(sun_title)
	# tilt drives how far the rim-wall shadow reaches inward: reach ~= wall_top * tan(tilt), so at
	# 15 deg it's only ~1km and barely reads; push it up to see the shadow properly.
	_add_slider(vb, "sun tilt (deg)", 0.0, 60.0, 15.0, func(v): sun_tilt = deg_to_rad(v))
	_add_slider(vb, "wall height (m)", 500.0, 12000.0, wall_top_h, func(v):
		wall_top_h = v
		_build_walls()
		if _clouds:
			_clouds.wall_top = v
			_clouds.retune())
	# Deliberately its own slider and not derived from the wall: the wall is how the horizon looks, this
	# is where a wing stops working. Moving it rebuilds the field curtain, so you can see the ceiling
	# you are setting rather than infer it.
	_add_slider(vb, "atmosphere top (m)", 800.0, 12000.0, atmo_top_h, func(v):
		atmo_top_h = v
		_build_walls())
	_add_slider(vb, "shadow softness (m)", 20.0, 2000.0, _wall_shadow_soft, func(v): _wall_shadow_soft = v)
	layer.add_child(_panel)

func _radius() -> float:
	return CIRCUMFERENCES[c_idx] / TAU

# Ring-space to local: theta=0 under camera, floor y=0, spinward = +x, lat = z.
func _ring_pos(theta: float, lat: float, h: float) -> Vector3:
	var r: float = _radius() - h
	return Vector3(r * sin(theta), _radius() - r * cos(theta), lat)

func _surface_pos(arc: float, lat: float) -> Vector3:
	return _ring_pos(arc / _radius(), lat, _terrain_h(arc, lat))

func _load_dem() -> void:
	if not FileAccess.file_exists(DEM_R16) or not FileAccess.file_exists(DEM_META):
		print("ring_vibes: no DEM found (run tools/dem/fetch_dem.py then export_to_game.py) — using noise terrain")
		return
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEM_META))
	_dem = FileAccess.get_file_as_bytes(DEM_R16)
	_dem_w = int(meta["w"])
	_dem_h = int(meta["h"])
	_dem_mpp = float(meta["m_per_px"])
	_dem_cam = Vector2i(int(meta["camera_px"][0]), int(meta["camera_px"][1]))
	_dem_hscale = float(meta.get("h_scale", 16.0))
	_dem_name = str(meta["name"])
	if FileAccess.file_exists(DEM_SAT):
		var simg := Image.new()
		if simg.load_png_from_buffer(FileAccess.get_file_as_bytes(DEM_SAT)) == OK:
			simg.generate_mipmaps()
			_sat_tex = ImageTexture.create_from_image(simg)
	if FileAccess.file_exists(DEM_ROADS):
		var rimg := Image.new()
		if rimg.load_png_from_buffer(FileAccess.get_file_as_bytes(DEM_ROADS)) == OK:
			var cpu := Image.new()
			cpu.copy_from(rimg)
			cpu.resize(ROAD_RES, ROAD_RES, Image.INTERPOLATE_LANCZOS)
			cpu.convert(Image.FORMAT_L8)
			_road_mask = cpu.get_data()
			rimg.generate_mipmaps()
			_roads_tex = ImageTexture.create_from_image(rimg)
	if FileAccess.file_exists(DEM_DETAIL):
		var dimg := Image.new()
		if dimg.load_png_from_buffer(FileAccess.get_file_as_bytes(DEM_DETAIL)) == OK:
			dimg.generate_mipmaps()
			_detail_tex = ImageTexture.create_from_image(dimg)
	print("ring_vibes: DEM loaded — ", _dem_name, " ", _dem_w, "x", _dem_h,
		"  sat_tex: ", "yes" if _sat_tex else "no")

func _build_dem_texture() -> void:
	# half-res GPU float texture + matching CPU field, derived from the already-loaded full-res DEM
	# bytes — used by the CDLOD shader AND by _terrain_h, so render and physical placement are the
	# exact same data (render-authoritative placement law; see .decisions/terrain.md).
	if _dem.is_empty():
		return
	var dw := _dem_w / 2
	var dh := _dem_h / 2
	var floats := PackedFloat32Array()
	floats.resize(dw * dh)
	for y in dh:
		var sy := y * 2
		for x in dw:
			floats[y * dw + x] = float(_dem.decode_u16((sy * _dem_w + x * 2) * 2)) / _dem_hscale
	var img := Image.create_from_data(dw, dh, false, Image.FORMAT_RF, floats.to_byte_array())
	_dem_tex = ImageTexture.create_from_image(img)
	_dem_hf = floats
	_dem_hf_w = dw
	_dem_hf_h = dh
	_dem_hf_mpp = _dem_mpp * 2.0
	_dem_hf_cam = Vector2(float(_dem_cam.x) * 0.5, float(_dem_cam.y) * 0.5)
	print("ring_vibes: DEM texture %dx%d, mpp=%.1f" % [dw, dh, _dem_hf_mpp])

const ALIGN_N := 11               # grid resolution per patch for --align

# What a frame actually costs, in milliseconds, with nothing else happening.
#
# This used to be Engine.get_frames_per_second(), which is a rolling average over the last SECOND --
# and the second before every shot contains a synchronous _scatter_trees, _refill_buildings,
# _build_hedge_ribbon and the previous shot's PNG encode. It was reporting the rebuild stall as if it
# were the render cost, which is why the same 619,696 triangles scored 18 fps from one camera and 1
# fps from the next. Every fps figure in JOURNAL.md before 2026-08-10 came from that and means
# nothing.
#
# Render a fixed number of frames back to back and time them. Discard the first: it pays for whatever
# shader variants this camera angle just touched, and that cost is real but it is a one-off, not the
# steady state we are budgeting against.
func _measure_frame_ms(frames: int = 24) -> String:
	await RenderingServer.frame_post_draw
	var t0 := Time.get_ticks_usec()
	for i in frames:
		await RenderingServer.frame_post_draw
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(frames)
	return "%5.1fms (%d fps)" % [ms, int(round(1000.0 / maxf(ms, 0.001)))]

func _tri_breakdown() -> String:
	# Where the triangles actually go. Every cut so far has been aimed by guesswork at whatever was
	# most visible in the last screenshot; this counts instances against their mesh so the biggest
	# consumer is a fact rather than an impression.
	var out: Array = []
	var total := 0
	var tri_of := func(m: Mesh) -> int:
		if m == null:
			return 0
		var n := 0
		for si in m.get_surface_count():
			var arr := m.surface_get_arrays(si)
			if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
				n += arr[Mesh.ARRAY_INDEX].size() / 3
			elif arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
				n += arr[Mesh.ARRAY_VERTEX].size() / 3
		return n
	var tree_t := 0
	for vi in _tree_mm.size():
		for l in TREE_LODS:
			var mmi = _tree_mm[vi][l]
			if mmi != null:
				tree_t += mmi.multimesh.instance_count * int(tri_of.call(mmi.multimesh.mesh))
	out.append("trees %d" % tree_t); total += tree_t
	var b_t := 0
	for mmi in _bldg_mmi:
		b_t += mmi.multimesh.instance_count * int(tri_of.call(mmi.multimesh.mesh))
	out.append("buildings %d" % b_t); total += b_t
	var h_t: int = _hedge_quads * 2
	out.append("hedges %d" % h_t); total += h_t
	var g_t := 0
	if _grass_mm != null:
		g_t = _grass_mm.multimesh.instance_count * int(tri_of.call(_grass_mm.multimesh.mesh))
	out.append("grass %d" % g_t); total += g_t
	var terr := _used * GRID * GRID * 2
	out.append("terrain ~%d (%d nodes)" % [terr, _used]); total += terr
	var band := BAND_SEGS * BAND_ROWS * 2
	out.append("far band %d" % band); total += band
	return "TRIS  %s   accounted %d" % [", ".join(out), total]


# ---------------------------------------------------------------------------
# PROVING GROUND. `-- --proving [vehicle,vehicle]`
#
# Drives each vehicle through a fixed sequence of manoeuvres with scripted inputs and reports the
# numbers: top speed, braking distance, turning circle, how much it loses off the tarmac, the
# steepest grade it will still climb, and how hard it gets thrown around on rough ground.
#
# Mechanics before looks. A vehicle that reads well and handles badly is worse than a box that
# handles well, and handling cannot be judged from a screenshot -- it needs the same treatment the
# terrain got: measure it, compare the numbers, believe them over the impression. Every vehicle runs
# the identical course, so the table is comparable rather than a list of separate impressions.
# ---------------------------------------------------------------------------

const PROVE_PHASES := [
	{"name": "accel",  "secs": 14.0, "throttle": 1.0, "steer": 0.0},
	{"name": "brake",  "secs": 6.0,  "throttle": -1.0, "steer": 0.0},
	{"name": "circle", "secs": 12.0, "throttle": 1.0, "steer": 1.0},
	{"name": "rough",  "secs": 12.0, "throttle": 1.0, "steer": 0.0, "offroad": true},
	{"name": "climb",  "secs": 14.0, "throttle": 1.0, "steer": 0.0, "uphill": true},
	# the calibrated bump strip: washboard, swell, kerbs, a ramp and a drop, then potholes
	{"name": "bumps",  "secs": 40.0, "throttle": 1.0, "steer": 0.0, "strip": true},
	# open water. Warps the course to a coastal patch (mizen_head/slea_head -- real coastline, 0%
	# nodata) so a boat has sea under it instead of being aground at millstreet for the whole run. The
	# land classes flounder here (offroad drag on the water), which is the comparison: this is the
	# phase the hover/boat/sub rows exist for. See _prove_find_water.
	{"name": "water",  "secs": 20.0, "throttle": 1.0, "steer": 0.0, "water": true},
]

var _prove_throttle := 0.0        # scripted input; _drive_tick reads these when _proving is set
var _prove_steer := 0.0
var _prove_offroad := -1.0        # -1 = derive from position; >=0 = pin (proving pins per phase)
var _proving := false
var _susp_travel := 0.0           # max compression seen this phase
var _susp_airborne := 0
var _body_pitch := 0.0
var _body_roll := 0.0
var _body_height := 0.0


# ---------------------------------------------------------------------------
# SUSPENSION, and a calibrated surface to test it on.
#
# There was none. The body was pinned to terrain height + 0.4 with the wheels welded to it, so it
# slid over the ground like a decal -- no pitch under braking, no roll in a turn, no wheel dropping
# into a hollow, and nothing to leave the ground. Which also meant "test suspension behaviour" had
# nothing to measure.
#
# Each wheel samples the terrain under itself and compresses a spring. The body then sits on the
# average and tilts to match the plane through the four contacts, so pitch and roll fall out of the
# ground rather than being animated onto it.
# Spring travel/sag/stiffness/damping are per-vehicle now -- they live on the VehicleDef
# (vehicle_def.gd) so every vehicle rides its own springs over the bump strip.
# ---------------------------------------------------------------------------

# A DELIBERATELY BUMPY STRIP for testing, laid over flat ground at a fixed arc nobody visits.
# Real terrain is whatever it happens to be -- Millstreet is 95.7% drivable, so the "rough" phase was
# measuring gentle pasture. Calibrated obstacles make the numbers mean something and repeat exactly.
# MIRRORED into cdlod_ring.gdshader's proving_surface() so the mesh draws exactly what the car drives
# over -- the constants below and there are one source split across CPU and GPU and MUST stay in sync.
# It is added unconditionally (not gated on _proving), so drive to this arc in DRIVE and you'll see it.
const PROVE_STRIP_ARC := 900_000.0     # 30% arc, well away from every splice
const PROVE_STRIP_LAT := 0.0
const PROVE_STRIP_LEN := 700.0

func _proving_surface(arc: float, lat: float) -> float:
	# 0 outside the strip. Inside, a sequence of calibrated obstacles laid end to end:
	#   0-150m   washboard, 2.5m wavelength, 8cm  -- the corrugation that shakes a chassis apart
	#   150-300m washboard, 9m wavelength, 45cm   -- the swell that unloads a suspension
	#   300-420m four square steps, 10/20/30/40cm -- kerbs; where a wheel radius stops coping
	#   420-560m ramp to 2.2m and a sharp drop    -- airtime and landing
	#   560-700m random potholes                  -- asymmetric, so roll and single-wheel drop
	var d := arc - PROVE_STRIP_ARC
	if d < 0.0 or d > PROVE_STRIP_LEN or absf(lat - PROVE_STRIP_LAT) > 40.0:
		return 0.0
	if d < 150.0:
		return sin(d * TAU / 2.5) * 0.08
	if d < 300.0:
		return sin(d * TAU / 9.0) * 0.45
	if d < 420.0:
		var step: float = floor((d - 300.0) / 30.0)
		return clampf(step, 0.0, 3.0) * 0.10 + 0.10
	if d < 560.0:
		var r := (d - 420.0) / 140.0
		return 2.2 * r if r < 0.85 else 0.0          # ramp then nothing: a drop, not a landing ramp
	var px: float = floor((d - 560.0) / 12.0)
	var py: float = floor(lat / 9.0)
	return -0.55 if fposmod(sin(px * 91.7 + py * 47.3) * 4371.0, 1.0) < 0.34 else 0.0

func _susp_update(delta: float, pos: Vector3, up: Vector3, fwd: Vector3) -> void:
	# springs come from the vehicle definition, not constants -- otherwise every vehicle rides
	# identically over the bump strip and the proving table cannot tell them apart
	var vd := _vdef()
	var travel: float = vd.susp_travel
	var sag: float = vd.susp_sag
	var stiff: float = vd.susp_stiff
	var damp: float = vd.susp_damp
	# sample under each wheel, compress its spring, and let the body follow the contact plane
	if _wheels.is_empty():
		return
	var right := fwd.cross(up).normalized()
	var sum := 0.0
	var pitch := 0.0
	var roll := 0.0
	var airborne := 0
	for i in _wheels.size():
		var w: Dictionary = _wheels[i]
		var off: Vector3 = w.get("offset", Vector3.ZERO)
		var wa := _car_arc + off.z * cos(_car_heading) - off.x * sin(_car_heading)
		var wl := _car_lat + off.z * sin(_car_heading) + off.x * cos(_car_heading)
		var gh := _terrain_h(wa, wl) + _proving_surface(wa, wl)
		# STATIC SAG. A parked vehicle sits partway down its travel under its own weight; it does
		# not hang fully extended. Resting at full travel meant every wheel was permanently at the
		# extension limit, so the airborne test read four wheels off the ground while braking on
		# the flat, and there was no droop left to absorb anything.
		var rest := gh + travel * sag
		var cur: float = float(w.get("h", rest))
		var vel: float = float(w.get("v", 0.0))
		# spring toward rest, damped. Below the ground it pushes hard; above it just falls.
		var accel := (rest - cur) * stiff - vel * damp
		# AIRBORNE means the spring is fully extended and STILL not reaching ground -- not merely
		# "above the rest position", which is true for half of every oscillation and reported all
		# four wheels off the ground while braking on the flat.
		if cur - gh >= travel:
			accel = -9.81
			airborne += 1
		vel += accel * delta
		cur += vel * delta
		if cur < gh:
			cur = gh
			vel = maxf(vel, 0.0)
		w["h"] = cur
		w["v"] = vel
		var comp: float = clampf(rest - cur, -travel, travel)
		_susp_travel = maxf(_susp_travel, absf(comp))
		sum += cur
		pitch += comp * signf(off.z)
		roll += comp * signf(off.x)
		var mesh: Node3D = w["mesh"]
		mesh.position.y = float(w.get("y0", mesh.position.y)) - comp
		if not w.has("y0"):
			w["y0"] = mesh.position.y + comp
	_susp_airborne = airborne
	_body_pitch = lerpf(_body_pitch, clampf(pitch * 0.5, -0.35, 0.35), delta * 8.0)
	_body_roll = lerpf(_body_roll, clampf(roll * 0.5, -0.35, 0.35), delta * 8.0)
	_body_height = lerpf(_body_height, sum / float(_wheels.size()), delta * 12.0)

func _prove_run() -> void:
	await get_tree().create_timer(1.5).timeout
	_mode = Mode.DRIVE
	if _vehicles.is_empty():
		_build_vehicles()
	var args := OS.get_cmdline_user_args()
	var want: Array = []
	var pi := args.find("--proving")
	if pi >= 0 and pi + 1 < args.size() and not args[pi + 1].begins_with("--"):
		want = Array(args[pi + 1].split(","))
	if want.is_empty():
		for v in _vehicles:
			want.append(str(v["name"]))

	print("\nPROVING GROUND — identical course, every vehicle\n")
	print("%-10s %-8s %8s %8s %8s %8s %8s %6s %5s" % [
		"vehicle", "phase", "top m/s", "dist m", "turn r", "jolt m", "grade",
		"susp", "air"])
	_proving = true
	for vname in want:
		var vi := -1
		for j in _vehicles.size():
			if str(_vehicles[j]["name"]) == vname:
				vi = j
		if vi < 0:
			print("  skip %s (not built)" % vname)
			continue
		_select_vehicle(vi)
		for phase in PROVE_PHASES:
			await _prove_phase(vname, phase)
	_proving = false
	_prove_throttle = 0.0
	_prove_steer = 0.0
	_prove_offroad = -1.0
	print("\nPROVING done")
	get_tree().quit()

func _prove_phase(vname: String, phase: Dictionary) -> void:
	# reset to a known start: on a road for the on-road phases, deliberately off it for "rough",
	# pointed at the steepest ground nearby for "climb"
	var start_arc := 0.0
	var start_lat := 0.0
	var road_heading := 0.0
	var have_road := false
	if not _roadlines.is_empty():
		var pts: PackedVector2Array = _roadlines[mini(4, _roadlines.size() - 1)]["pts"]
		var i0 := mini(2, pts.size() - 1)
		var p: Vector2 = pts[i0]
		start_arc = p.x
		start_lat = p.y
		# Tangent DOWN the carriageway. Heading 0 drove the car straight off the 8m ribbon within a
		# car length, so "accel" measured the offroad terminal (9.8) not the road one (~22).
		if i0 + 1 < pts.size():
			var tdir := pts[i0 + 1] - p
			if tdir.length() > 0.01:
				road_heading = atan2(tdir.y, tdir.x)
				have_road = true
	if bool(phase.get("offroad", false)):
		start_lat += 60.0                      # well clear of the carriageway
	if bool(phase.get("strip", false)):
		start_arc = PROVE_STRIP_ARC - 20.0
		start_lat = PROVE_STRIP_LAT
	var water_heading := 0.0
	if bool(phase.get("water", false)):
		var wp := await _prove_find_water()
		if wp.x < 1e19:
			start_arc = wp.x
			start_lat = wp.y
			# point at the deepest water within a short sweep, so the hull runs to open sea rather
			# than the beach it started near -- a boat that drives itself aground measures nothing
			var wbest := _sea_depth(start_arc, start_lat)
			for wk in 16:
				var wa := TAU * float(wk) / 16.0
				var wdh := _sea_depth(start_arc + cos(wa) * 120.0, start_lat + sin(wa) * 120.0)
				if wdh > wbest:
					wbest = wdh
					water_heading = wa
	_car_arc = start_arc
	_car_lat = start_lat
	_car_speed = 0.0
	_boat_vel = Vector2.ZERO   # a hull starts each phase dead in the water, not carrying the last phase's course
	# FULL TANK, NO WEAR, every phase. The proving course measures HANDLING, and the first run after
	# fuel landed had the sportscar reading 0.0 through rough and climb -- it had simply run dry during
	# accel/brake/circle, because burn scales with power and it has the most. Left alone the table
	# would quietly have become a fuel-capacity table wearing a handling table's column headings,
	# which is the exact failure this harness exists to prevent.
	_service_vehicle()
	_air_vel = Vector2.ZERO    # and a ballistic course does not survive a phase change either
	_dive = 0.0           # each phase starts surfaced, so a sub's dive can't carry over between phases
	_altitude = 0.0       # each phase starts on the ground, so a flyer's altitude can't carry over between phases
	_vspeed = 0.0
	_docked = false       # each phase starts free-flying, not latched to the port
	_boarded = false
	_stamina = 1.0        # each phase measures a fresh mount, so the table isn't skewed by the prior phase
	_spooked = 0.0
	var pure_road: bool = have_road and not bool(phase.get("offroad", false)) and not bool(phase.get("strip", false)) and not bool(phase.get("uphill", false)) and not bool(phase.get("water", false))
	if bool(phase.get("water", false)):
		_car_heading = water_heading
	elif pure_road:
		_car_heading = road_heading
	else:
		_car_heading = 0.0
	# PIN the drag term to the phase's intended surface, don't derive it from live position. Deriving
	# it meant a 14s full-throttle run drove off the 8m ribbon within a car length (a straight tangent
	# can't follow a curving polyline), so "accel" settled at the OFF-road terminal (9.8) and the
	# on-road figure was never measured. Pinning makes the course identical and the table comparable,
	# which is the whole point of the harness. On-road for accel/brake/circle and the synthetic bump
	# strip (so it carries enough speed to cross every obstacle); off-road for rough and climb.
	_prove_offroad = 1.0 if (bool(phase.get("offroad", false)) or bool(phase.get("uphill", false)) or bool(phase.get("water", false))) else 0.0
	_offroad = _prove_offroad
	if bool(phase.get("uphill", false)):
		# aim at the steepest uphill within a short sweep, so "grade" means something
		var best := -1.0
		for k in 16:
			var a := TAU * float(k) / 16.0
			var h0 := _terrain_h(_car_arc, _car_lat)
			var h1 := _terrain_h(_car_arc + cos(a) * 40.0, _car_lat + sin(a) * 40.0)
			if h1 - h0 > best:
				best = h1 - h0
				_car_heading = a
	_prove_throttle = float(phase["throttle"])
	_prove_steer = float(phase["steer"])

	var t := 0.0
	var top := 0.0
	var start := Vector2(_car_arc, _car_lat)
	# jolt is the ground the WHEELS ride, which on the strip is base terrain PLUS the bump profile.
	# Measuring _terrain_h alone meant the calibrated strip (its whole purpose) never showed in the
	# jolt column -- it read the flat base under the strip and reported ~0.
	var h_start := _terrain_h(_car_arc, _car_lat) + _proving_surface(_car_arc, _car_lat)
	var jolt := 0.0
	_susp_travel = 0.0
	var air := 0
	var prev_h := h_start
	var min_x := 1e20
	var max_x := -1e20
	var min_y := 1e20
	var max_y := -1e20
	while t < float(phase["secs"]):
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		t += dt
		top = maxf(top, absf(_car_speed))
		var h := _terrain_h(_car_arc, _car_lat) + _proving_surface(_car_arc, _car_lat)
		jolt = maxf(jolt, absf(h - prev_h))
		air = maxi(air, _susp_airborne)
		prev_h = h
		min_x = minf(min_x, _car_arc); max_x = maxf(max_x, _car_arc)
		min_y = minf(min_y, _car_lat); max_y = maxf(max_y, _car_lat)
	var dist := Vector2(_car_arc, _car_lat).distance_to(start)
	# turning circle from the swept bounding box, which is the diameter for a full lock circle
	var turn_r: float = maxf(max_x - min_x, max_y - min_y) * 0.5
	var climbed := _terrain_h(_car_arc, _car_lat) - h_start
	var grade: float = 0.0 if dist < 1.0 else rad_to_deg(atan(climbed / dist))
	print("%-10s %-8s %8.1f %8.1f %8.1f %8.2f %7.1f  %6.2f %5d" % [
		vname, phase["name"], top, dist,
		turn_r if str(phase["name"]) == "circle" else 0.0,
		jolt, grade if str(phase["name"]) == "climb" else 0.0,
		_susp_travel, air])

func _prove_find_water() -> Vector2:
	# Warp the proving course to a coastal patch and return an offshore point with land in sight, or
	# (1e20,1e20) if none is reachable. The rest of the course runs at millstreet, where the sea is a
	# thin fringe and a boat is aground for the whole run; the water phase needs real coastline under
	# it (mizen_head/slea_head are 0% nodata) for the boat/hover/sub rows to measure at all.
	var idx := -1
	for pname in ["mizen_head", "slea_head", "halong_bay", "palawan"]:
		idx = _patch_names.find(pname)
		if idx >= 0:
			break
	if idx < 0:
		print("  water: no coastal patch loaded")
		return Vector2(1e20, 1e20)
	_warp_to(idx)
	# let the stream land so the hull rides the streamed tier, not the 512 array -- only the FIRST
	# water phase waits; the patch stays resident for the vehicles that follow (matches --shots)
	var waited := 0.0
	while _hires_idx != idx and waited < 20.0:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	var r: Vector4 = _patch_rects[idx]
	# spiral out from the patch centre for water deep enough to float even the deepest-draft barge
	# (2.4m) that also HAS a coast -- the land-in-sight test rejects the phantom void that would float
	# a hull on nothing (the same guard the shot harness's sea framing uses).
	for ring_i in range(1, 80):
		var rad := float(ring_i) * 250.0
		for k in 12:
			var a := TAU * float(k) / 12.0
			var p := Vector2(r.x + cos(a) * rad, r.y + sin(a) * rad)
			if absf(p.y) > WIDTHS[w_idx] * 0.45 or _sea_depth(p.x, p.y) <= 3.0:
				continue
			if not _land_in_sight(p.x, p.y):
				continue
			print("  water: %s, %.0fm offshore, depth %.1fm"
				% [_patch_names[idx], rad, _sea_depth(p.x, p.y)])
			return p
	print("  water: no sea within reach of %s" % _patch_names[idx])
	return Vector2(1e20, 1e20)

# Triangles belonging to ONE node's subtree. The frame total is useless for comparing vehicles: the
# first roster run reported 338,444 for all twenty-one of them, because that is the terrain, the trees
# and the hedges, against which a placeholder car is a rounding error. The item asks for the set to be
# COMPARABLE, and that means the vehicle's own cost, not the cost of standing next to it.
func _node_tris(n: Node) -> int:
	var total := 0
	var stack: Array = [n]
	while not stack.is_empty():
		var c = stack.pop_front()
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var m: Mesh = (c as MeshInstance3D).mesh
			for si in m.get_surface_count():
				var arr := m.surface_get_arrays(si)
				var idx = arr[Mesh.ARRAY_INDEX]
				if idx != null and idx.size() > 0:
					total += idx.size() / 3
				else:
					var vtx = arr[Mesh.ARRAY_VERTEX]
					if vtx != null:
						total += vtx.size() / 3
		for k in (c as Node).get_children():
			stack.append(k)
	return total


# The weapon roster, same shape as VEHICLE_ROW: data, not code. Only the carbine for now -- the item
# says build the harness BEFORE any weapon, and a harness with nothing to fire cannot be trusted, so
# this is the reference round the range was calibrated against rather than the start of the tree.
const WEAPON_ROWS := {
	# --- MELEE (TASKS.md "Melee: reach, wind-up, commitment"). Four rows, one parameter set. What
	# separates them is not damage, it is what you are risking to land it: the spear keeps you out of
	# reach but is helpless if you miss, the club is slow and catches a crowd, the blade is quick and
	# forgiving, and the improvised thing is what you have when you have nothing.
	"spear": {
		"purpose": "the spear — hits first from outside their reach; miss and you are wide open",
		"cls": "melee", "muzzle": 0.0, "damage": 55.0,
		"reach": 2.6, "windup_s": 0.42, "commit_s": 0.70, "arc_deg": 25.0,
		"rpm": 0.0, "cycle_s": 1.10, "mag": 0, "reload_s": 0.0, "spread_mrad": 0.0,
	},
	"blade": {
		"purpose": "the blade — quick and forgiving, but you have to be close enough to be hit back",
		"cls": "melee", "muzzle": 0.0, "damage": 38.0,
		"reach": 1.3, "windup_s": 0.22, "commit_s": 0.28, "arc_deg": 70.0,
		"rpm": 0.0, "cycle_s": 0.55, "mag": 0, "reload_s": 0.0, "spread_mrad": 0.0,
	},
	"club": {
		"purpose": "the club — slow, heavy, sweeps a crowd; the swing owns you once it starts",
		"cls": "melee", "muzzle": 0.0, "damage": 62.0,
		"reach": 1.5, "windup_s": 0.58, "commit_s": 0.85, "arc_deg": 120.0,
		"rpm": 0.0, "cycle_s": 1.35, "mag": 0, "reload_s": 0.0, "spread_mrad": 0.0,
	},
	"improvised": {
		"purpose": "whatever was to hand — short, weak, and better than open palms",
		"cls": "melee", "muzzle": 0.0, "damage": 18.0,
		"reach": 1.0, "windup_s": 0.30, "commit_s": 0.45, "arc_deg": 50.0,
		"rpm": 0.0, "cycle_s": 0.70, "mag": 0, "reload_s": 0.0, "spread_mrad": 0.0,
	},
	# --- THROWN (TASKS.md "Thrown: arc, weight, fuse"). Same free-fall model as a bullet; what changes
	# is the TIME OF FLIGHT, which is seconds instead of milliseconds -- long enough for the ring to
	# rotate meaningfully underneath. A thrown charge is the first weapon where which way you are
	# facing changes the range by a useful fraction.
	"rock": {
		"purpose": "a rock — free, silent, always available, and barely a weapon",
		"cls": "thrown", "muzzle": 22.0, "drag_k": 0.0009, "mass_g": 400.0, "damage": 12.0,
		"blast_r": 0.0, "fuse_s": 0.0, "lob_mrad": 785.0, "spread_mrad": 12.0,
		"rpm": 0.0, "cycle_s": 1.4, "mag": 0, "reload_s": 0.0,
	},
	"javelin": {
		"purpose": "the thrown spear — flat, fast and heavy; one you have to go and pick up again",
		"cls": "thrown", "muzzle": 28.0, "drag_k": 0.0004, "mass_g": 800.0, "damage": 48.0,
		"blast_r": 0.0, "fuse_s": 0.0, "lob_mrad": 500.0, "spread_mrad": 8.0,
		"rpm": 0.0, "cycle_s": 2.0, "mag": 0, "reload_s": 0.0,
	},
	"grenade": {
		"purpose": "the fragmentation charge — a timed decision, not an aimed one",
		"cls": "thrown", "muzzle": 20.0, "drag_k": 0.0011, "mass_g": 450.0, "damage": 90.0,
		"blast_r": 6.0, "fuse_s": 4.0, "lob_mrad": 785.0, "spread_mrad": 15.0,
		"rpm": 0.0, "cycle_s": 1.6, "mag": 0, "reload_s": 0.0,
	},
	"molotov": {
		"purpose": "burning fuel — denies the ground rather than killing what is standing on it",
		"cls": "thrown", "muzzle": 17.0, "drag_k": 0.0014, "mass_g": 700.0, "damage": 25.0,
		"blast_r": 4.5, "fuse_s": 0.0, "lob_mrad": 785.0, "spread_mrad": 18.0,
		"rpm": 0.0, "cycle_s": 1.8, "mag": 0, "reload_s": 0.0,
	},
	"sticky": {
		"purpose": "the sticky charge — short, heavy, and meant for something that is not moving",
		"cls": "thrown", "muzzle": 15.0, "drag_k": 0.0012, "mass_g": 1200.0, "damage": 160.0,
		"blast_r": 3.5, "fuse_s": 2.5, "lob_mrad": 600.0, "spread_mrad": 20.0,
		"rpm": 0.0, "cycle_s": 2.4, "mag": 0, "reload_s": 0.0,
	},
	# --- TENSIONED (TASKS.md "Tensioned: draw time, hold penalty, drop"). Stored muscle or spring, so
	# the shot costs time BEFORE it happens and holding it drawn costs accuracy -- you cannot sit at
	# the ready the way you can with a firearm. The drop is not a parameter: at 35-90 m/s the existing
	# ballistics do it for free, and it is severe.
	"sling": {
		"purpose": "the sling — ammunition is any stone; everything else about it is a penalty",
		"cls": "tensioned", "muzzle": 40.0, "drag_k": 0.0008, "mass_g": 60.0, "damage": 22.0,
		"draw_s": 1.6, "hold_s": 0.6, "hold_mrad": 9.0,
		"spread_mrad": 9.0, "bloom_mrad": 0.0, "bloom_max": 0.0, "settle_s": 0.5,
		"recoil": 0.0, "recover_s": 0.1, "rpm": 0.0, "cycle_s": 2.2, "mag": 0, "reload_s": 0.0,
	},
	"bow": {
		"purpose": "the bow — quiet, quick to loose, and you feel every second you hold it drawn",
		"cls": "tensioned", "muzzle": 62.0, "drag_k": 0.0005, "mass_g": 32.0, "damage": 46.0,
		"draw_s": 0.9, "hold_s": 1.8, "hold_mrad": 4.0,
		"spread_mrad": 3.2, "bloom_mrad": 0.0, "bloom_max": 0.0, "settle_s": 0.5,
		"recoil": 0.0, "recover_s": 0.1, "rpm": 0.0, "cycle_s": 1.7, "mag": 0, "reload_s": 0.0,
	},
	"crossbow": {
		"purpose": "the crossbow — holds itself at full draw, and makes you pay for it in reload",
		"cls": "tensioned", "muzzle": 92.0, "drag_k": 0.0004, "mass_g": 40.0, "damage": 68.0,
		"draw_s": 3.4, "hold_s": 999.0, "hold_mrad": 0.0,
		"spread_mrad": 1.6, "bloom_mrad": 0.0, "bloom_max": 0.0, "settle_s": 0.5,
		"recoil": 0.0, "recover_s": 0.1, "rpm": 0.0, "cycle_s": 4.0, "mag": 0, "reload_s": 0.0,
	},
	"speargun": {
		"purpose": "the speargun — one heavy shot, and it works where powder does not",
		"cls": "tensioned", "muzzle": 34.0, "drag_k": 0.0006, "mass_g": 900.0, "damage": 85.0,
		"draw_s": 2.8, "hold_s": 999.0, "hold_mrad": 0.0,
		"spread_mrad": 2.4, "bloom_mrad": 0.0, "bloom_max": 0.0, "settle_s": 0.5,
		"recoil": 0.0, "recover_s": 0.1, "rpm": 0.0, "cycle_s": 3.6, "mag": 0, "reload_s": 0.0,
	},
	# --- CHEMICAL PROJECTILE (TASKS.md), the big family. Every row is the same parameter set; what
	# separates them is where each one puts its ceiling. The musket's is the reload, the bolt-action's
	# is the cycle, the SMG's is spread growth, the LMG's is HEAT, the autocannon's is that it hits
	# like a vehicle weapon because it is one. Rate/recoil/magazine/reload/heat/spread-growth, as the
	# item lists -- heat being the brake that is not the magazine.
	"musket": {
		"purpose": "the musket — one shot, then you are holding a stick for fifteen seconds",
		"cls": "chemical", "muzzle": 450.0, "drag_k": 0.0009, "mass_g": 28.0, "damage": 78.0,
		"rpm": 0.0, "cycle_s": 0.9, "mag": 1, "reload_s": 15.0,
		"spread_mrad": 4.5, "bloom_mrad": 0.0, "bloom_max": 0.0, "settle_s": 1.0,
		"recoil": 9.0, "recover_s": 1.1,
	},
	"bolt_action": {
		"purpose": "the bolt-action — the most accurate thing anyone on the ring can build by hand",
		"cls": "chemical", "muzzle": 820.0, "drag_k": 0.00030, "mass_g": 11.0, "damage": 82.0,
		"rpm": 0.0, "cycle_s": 1.5, "mag": 5, "reload_s": 4.0,
		"spread_mrad": 0.35, "bloom_mrad": 0.4, "bloom_max": 1.2, "settle_s": 1.2,
		"recoil": 6.0, "recover_s": 0.9,
	},
	"smg": {
		"purpose": "the SMG — wins every argument inside a room and loses all of them outside it",
		"cls": "chemical", "muzzle": 380.0, "drag_k": 0.0008, "mass_g": 8.0, "damage": 22.0,
		"rpm": 900.0, "cycle_s": 0.0, "mag": 32, "reload_s": 2.0,
		"spread_mrad": 1.8, "bloom_mrad": 2.6, "bloom_max": 14.0, "settle_s": 0.45,
		"recoil": 2.0, "recover_s": 0.22,
	},
	"lmg": {
		"purpose": "the LMG — fires until the barrel glows, which is sooner than the belt runs out",
		"cls": "chemical", "muzzle": 840.0, "drag_k": 0.00032, "mass_g": 12.0, "damage": 38.0,
		"rpm": 650.0, "cycle_s": 0.0, "mag": 100, "reload_s": 6.5,
		"spread_mrad": 1.2, "bloom_mrad": 1.1, "bloom_max": 7.0, "settle_s": 0.8,
		"recoil": 3.4, "recover_s": 0.35,
		"heat_per_shot": 2.2, "heat_max": 100.0, "cool_rate": 14.0, "overheat_lock_s": 4.0,
	},
	"autocannon": {
		"purpose": "the autocannon — a vehicle weapon; carrying it is the whole cost",
		"cls": "chemical", "muzzle": 1020.0, "drag_k": 0.00022, "mass_g": 240.0, "damage": 155.0,
		"rpm": 220.0, "cycle_s": 0.0, "mag": 20, "reload_s": 7.0,
		"spread_mrad": 1.0, "bloom_mrad": 3.0, "bloom_max": 10.0, "settle_s": 1.0,
		"recoil": 14.0, "recover_s": 0.8,
		"heat_per_shot": 5.0, "heat_max": 100.0, "cool_rate": 10.0, "overheat_lock_s": 6.0,
	},
	# --- DIRECTED ENERGY (TASKS.md). No drop and no lead, which on THIS world is worth more than
	# anywhere else: every other weapon has to be aimed off for a drop that depends on which way you
	# are facing, and a beam simply does not. It pays for that by being unable to sustain -- charge
	# before the shot, heat after it -- so it is a weapon for one considered shot, not for a firefight.
	"beam_rifle": {
		"purpose": "the beam rifle — point at it and it is hit; the ring stops mattering entirely",
		"cls": "energy", "muzzle": 0.0, "damage": 60.0, "beam": false, "charge_s": 0.9,
		"falloff_m": 600.0, "spread_mrad": 0.25, "bloom_mrad": 0.0, "bloom_max": 0.0, "settle_s": 1.0,
		"recoil": 0.0, "recover_s": 0.1, "rpm": 0.0, "cycle_s": 1.4, "mag": 0, "reload_s": 0.0,
		"heat_per_shot": 26.0, "heat_max": 100.0, "cool_rate": 11.0, "overheat_lock_s": 5.0,
	},
	"cutter": {
		"purpose": "the cutting beam — continuous, brutal, and only at arm's length",
		"cls": "energy", "muzzle": 0.0, "damage": 140.0, "beam": true, "charge_s": 0.0,
		"falloff_m": 14.0, "spread_mrad": 0.1, "bloom_mrad": 0.0, "bloom_max": 0.0, "settle_s": 1.0,
		"recoil": 0.0, "recover_s": 0.1, "rpm": 0.0, "cycle_s": 0.05, "mag": 0, "reload_s": 0.0,
		"heat_per_shot": 12.0, "heat_max": 100.0, "cool_rate": 18.0, "overheat_lock_s": 3.5,
	},
	"carbine": {
		# FOR: the baseline everything else is measured against. It already exists as a model with FP
		# arms, so it is the one weapon where "does the table match how it feels" can actually be asked.
		"purpose": "the carbine — the reference weapon; every other row is an argument against this one",
		"cls": "chemical", "muzzle": 900.0, "drag_k": 0.00035, "mass_g": 8.0,
		"rpm": 700.0, "cycle_s": 0.0, "mag": 30, "reload_s": 2.3,
		"spread_mrad": 0.7, "bloom_mrad": 1.5, "bloom_max": 8.0, "settle_s": 0.5,
		"recoil": 2.6, "recover_s": 0.28, "damage": 34.0, "pellets": 1,
	},
}

func _weapon_def(name: String) -> WeaponDef:
	var wd := WeaponDef.new()
	var row: Dictionary = WEAPON_ROWS.get(name, {})
	for k in row.keys():
		wd.set(k, row[k])
	return wd

# ---------------------------------------------------------------------------
# FIRING RANGE (TASKS.md, "Build this before any weapon"). The proving-ground lesson applied to
# weapons: feel is measurable, and a table that compares is worth more than a set of separate
# impressions. Identical course per weapon, seeded, so re-running it means something.
#
# RING BALLISTICS, done properly, because the harness is worthless measuring the wrong model.
# A ringworld has NO meaningful self-gravity -- the floor is held under you by spin, not attraction.
# So a projectile, once it leaves the muzzle, is in free fall and travels in a PERFECTLY STRAIGHT
# LINE in the inertial frame. Every bit of "drop" is the ring's floor curving UP to meet it, and
# every bit of lateral behaviour is the ring rotating beneath it. That is both the correct physics
# and much simpler than faking a gravity constant, so there is no reason to approximate.
#
# Consequence worth knowing before tuning any weapon: firing SPINWARD and ANTISPINWARD are not the
# same shot, and the direction is the opposite of the intuition. Firing SPINWARD adds to the round's
# tangential speed, so it needs MORE centripetal force to stay at that radius than the floor is
# providing -- it falls outward, toward the floor, faster. Firing ANTISPINWARD subtracts, so it
# drops far less. Measured, not reasoned: at 400m the carbine drops 2.02m spinward and 0.27m
# antispinward. Nearly 2m of difference on the same shot depending on which way you face. (This
# comment said the reverse until the first run contradicted it.)
const RANGE_TARGETS := [5.0, 10.0, 25.0, 50.0, 100.0, 200.0, 400.0]
const RANGE_SHOTS := 12            # shots per range; enough for a group, few enough to stay quick
const RANGE_TARGET_HP := 100.0
const RANGE_TARGET_R := 0.25       # standard target radius, m (a torso-ish 50cm circle)
const RANGE_EYE := 1.6
# Short-range rows report about -1cm of "rise". That is the model's own noise floor, not lift: the
# arc is computed at the round's radius and compared against a target sitting on the floor 1.6m
# below the muzzle, so the two disagree by roughly the eye height over the first few metres. Against
# a 25cm target radius it is irrelevant, and chasing it would mean a more careful arc definition for
# no gain at the ranges that matter.

func _omega() -> float:
	# spin rate that produces the surface gravity the rest of the sim uses: omega^2 * R = AIR_GRAVITY
	return sqrt(AIR_GRAVITY / _radius())

func _shot_flight(dist: float, elev_mrad: float, spinward: bool, muzzle: float, drag_k: float) -> Dictionary:
	# Straight line in the inertial frame; the ring turns under it. Returns time of flight and how far
	# BELOW the line of sight the round crosses the target's arc (positive = dropped).
	if muzzle <= 0.0:
		return {"t": 0.0, "drop": 0.0}
	var R := _radius()
	var w := _omega()
	var r0 := R - RANGE_EYE
	var dirs := 1.0 if spinward else -1.0
	# muzzle velocity in the ROTATING frame: down-range along the arc, plus the aimed elevation
	var v_arc := muzzle * cos(elev_mrad * 0.001) * dirs
	var v_up := muzzle * sin(elev_mrad * 0.001)          # toward the axis = radius decreasing
	# to inertial: add the floor's own tangential speed
	var vt := v_arc + w * r0
	var vr := -v_up
	# integrate in small steps so drag can bleed speed; without drag this is a closed form, but a
	# monotonic drag term is worth more to a weapons table than an analytic solution
	var t := 0.0
	var pos := Vector2(0.0, r0)          # (tangential, radial) in the inertial plane
	var vel := Vector2(vt, vr)
	# ~400 steps whatever the range: a fixed 0.0008s step is 2.4m of travel at these speeds, which
	# resolved a 5m shot in two steps and reported a 1cm RISE that was pure integration error.
	var step: float = maxf(dist / maxf(muzzle, 1.0) / 400.0, 0.000002)
	var guard := 0
	while guard < 200000:
		guard += 1
		var speed := vel.length()
		var rel := speed - w * r0        # airspeed relative to the co-rotating atmosphere
		if drag_k > 0.0 and rel > 0.0:
			vel -= vel.normalized() * (rel * rel * drag_k * step)
		pos += vel * step
		t += step
		# where is this in RING coordinates? undo the ring's rotation
		var r := pos.length()
		var theta := atan2(pos.x, pos.y) - w * t
		var arc := theta * R
		if absf(arc) >= dist:
			# height above the floor is R - r; drop is how far that has fallen below the muzzle
			return {"t": t, "drop_m": RANGE_EYE - (R - r)}
	return {"t": t, "drop_m": 0.0}

func _shot_vertical(muzzle: float, drag_k: float) -> Dictionary:
	# Fire straight "up" (toward the axis) and see where it comes back to eye height. On a planet it
	# lands on your head. Here it does not, and WHERE it lands is the ring effect stated plainly.
	var R := _radius()
	var w := _omega()
	var r0 := R - RANGE_EYE
	var pos := Vector2(0.0, r0)
	var vel := Vector2(w * r0, -muzzle)     # carried along by the floor, plus straight up
	var t := 0.0
	var step := 0.002
	var guard := 0
	while guard < 400000:
		guard += 1
		var speed := vel.length()
		var rel := speed - w * r0
		if drag_k > 0.0 and rel > 0.0:
			vel -= vel.normalized() * (rel * rel * drag_k * step)
		pos += vel * step
		t += step
		var r := pos.length()
		if R - r <= RANGE_EYE and t > 0.5:
			var theta := atan2(pos.x, pos.y) - w * t
			return {"t": t, "arc": theta * R}
	return {"t": t, "arc": 0.0}

func _throw_flight(muzzle: float, drag_k: float, elev_mrad: float, spinward: bool) -> Dictionary:
	# Lobbed, and released from eye height, so it ends when it comes back down to the floor. Same
	# straight-line-in-the-inertial-frame model as a bullet -- a thrown rock is in free fall too. The
	# difference is time: seconds rather than milliseconds, so the ring's rotation has time to matter.
	var R := _radius()
	var w := _omega()
	var r0 := R - RANGE_EYE
	var dirs := 1.0 if spinward else -1.0
	var v_arc := muzzle * cos(elev_mrad * 0.001) * dirs
	var v_up := muzzle * sin(elev_mrad * 0.001)
	var pos := Vector2(0.0, r0)
	var vel := Vector2(v_arc + w * r0, -v_up)
	var t := 0.0
	var step := 0.004
	var guard := 0
	while guard < 200000:
		guard += 1
		var speed := vel.length()
		var rel := speed - w * r0
		if drag_k > 0.0 and rel > 0.0:
			vel -= vel.normalized() * (rel * rel * drag_k * step)
		pos += vel * step
		t += step
		var r := pos.length()
		if R - r <= 0.0 and t > 0.05:
			var theta := atan2(pos.x, pos.y) - w * t
			return {"t": t, "arc": absf(theta * R)}
	return {"t": t, "arc": 0.0}

func _range_run() -> void:
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var want: Array = []
	var ri := args.find("--range")
	if ri >= 0 and ri + 1 < args.size() and not args[ri + 1].begins_with("--"):
		want = Array(args[ri + 1].split(","))
	if want.is_empty():
		want = WEAPON_ROWS.keys()
	print("RANGE  ring R=%.0fm  omega=%.6f rad/s  surface %.0f m/s" % [_radius(), _omega(), _omega() * _radius()])
	print("%-10s %-9s %6s %6s %7s %7s %8s %8s %7s" % ["weapon", "range", "cold%", "burst%", "group", "drop", "flight", "spin-dif", "ttk"])
	for wname in want:
		if not WEAPON_ROWS.has(wname):
			print("RANGE skip %s (no such weapon)" % wname)
			continue
		var wd: WeaponDef = _weapon_def(str(wname))
		# MELEE has no projectile, so every ranged column above is meaningless for it -- group size at
		# 400m for a club is not a number worth printing. Its own row instead, reporting what the class
		# actually trades: how far it reaches, how long it telegraphs, and how long it owns you after.
		# THROWN reports how FAR, not how tight -- and reports it both ways round, because at these
		# flight times the ring asymmetry stops being a curiosity and starts being a targeting problem.
		if wd.cls == "thrown":
			var ts := _throw_flight(wd.muzzle, wd.drag_k, wd.lob_mrad, true)
			var ta := _throw_flight(wd.muzzle, wd.drag_k, wd.lob_mrad, false)
			var fuse_txt := "impact" if wd.fuse_s <= 0.0 else ("%.1fs fuse" % wd.fuse_s)
			print("%-10s thrown   spinward %5.0fm (%.2fs)  antispin %5.0fm (%.2fs)  diff %+.0fm  "
				% [wname, float(ts["arc"]), float(ts["t"]), float(ta["arc"]), float(ta["t"]),
				float(ta["arc"]) - float(ts["arc"])]
				+ "blast %.1fm  %s" % [wd.blast_r, fuse_txt])
			continue
		# ENERGY gets its own line: every ranged column here is about drop, lead and holdover, and this
		# is the one class for which all three are identically zero. Printing a drop table of nothing
		# would bury the only fact that matters about it.
		if wd.cls == "energy":
			# A BEAM IS RATED PER SECOND, a pulse per shot -- the contract says so, and the first run
			# ignored it and reported the cutter at 2,800 dps by dividing per-second damage by a 0.05s
			# tick. For a beam, heat_per_shot is heat PER SECOND and damage is damage per second; for a
			# pulse, both are per shot and a shot costs cycle + charge.
			var secs: float
			var dps: float
			if wd.beam:
				secs = wd.heat_max / maxf(wd.heat_per_shot, 0.001)
				dps = wd.damage
			else:
				var shot_t: float = wd.cycle_s + wd.charge_s
				secs = (wd.heat_max / maxf(wd.heat_per_shot, 0.001)) * shot_t
				dps = wd.damage / maxf(shot_t, 0.001)
			var duty: float = secs / maxf(secs + wd.overheat_lock_s, 0.001) * 100.0
			print("%-10s energy   NO DROP, NO LEAD, no flight time  charge %.1fs  falloff %.0fm  "
				% [wname, wd.charge_s, wd.falloff_m]
				+ "%s %.1fs before overheat (%.0f%% duty)  dps %.0f"
				% ["beam" if wd.beam else "pulsed", secs, duty, dps])
			continue
		if wd.cls == "tensioned":
			# the ranged table below still applies -- it has a projectile -- but draw and hold are the
			# class and appear nowhere in it. A crossbow that holds at full draw forever and a bow that
			# starts shaking after two seconds are the same row otherwise.
			var hold_txt := "holds indefinitely" if wd.hold_s > 100.0 				else "steady %.1fs then +%.0f mrad/s" % [wd.hold_s, wd.hold_mrad]
			print("%-10s tension  draw %.1fs  %s  (drop below is the real cost)"
				% [wname, wd.draw_s, hold_txt])
		if wd.cls == "melee":
			var swing: float = wd.windup_s + wd.commit_s
			var dps: float = wd.damage / maxf(wd.cycle_s, 0.01)
			var kill: float = ceil(RANGE_TARGET_HP / maxf(wd.damage, 0.001)) * wd.cycle_s + wd.windup_s
			print("%-10s  melee   reach %.1fm  arc %3.0fdeg  windup %.2fs  committed %.2fs  "
				% [wname, wd.reach, wd.arc_deg, wd.windup_s, swing]
				+ "dps %5.1f  ttk %.2fs" % [dps, kill])
			continue
		var rng := RandomNumberGenerator.new()
		for dist in RANGE_TARGETS:
			rng.seed = hash(str(wname) + str(dist))     # identical course per weapon, per range
			# HOLDOVER ERROR. The hit test used to model dispersion only, so the bow scored 100% at
			# 100m while dropping 13m and the speargun scored 33% at 400m while dropping over a
			# kilometre. A shooter ZEROES for the range, so the drop itself is not the miss -- the miss
			# is misjudging the range and holding over by the wrong amount. Take the drop difference
			# across a 10% range error: that is the vertical error in metres, and for a flat-shooting
			# rifle it is centimetres while for a lobbed spear it is most of the drop.
			var f_near := _shot_flight(dist, 0.0, true, wd.muzzle, wd.drag_k)
			var f_far := _shot_flight(dist * 1.1, 0.0, true, wd.muzzle, wd.drag_k)
			var hold_err: float = absf(float(f_far.get("drop_m", 0.0)) - float(f_near.get("drop_m", 0.0)))
			var bloom := 0.0
			var hits := 0
			var worst := 0.0
			var pts: Array[Vector2] = []
			var shot_dt: float = (60.0 / wd.rpm) if wd.rpm > 0.0 else maxf(wd.cycle_s, 0.05)
			shot_dt = maxf(shot_dt, wd.cycle_s)
			for i in RANGE_SHOTS:
				# accumulated dispersion this shot: inherent + bloom, minus whatever settled between shots
				var sp := wd.spread_mrad + bloom
				var ang := rng.randf_range(0.0, TAU)
				var mag_mrad: float = absf(rng.randfn(0.0, sp * 0.5))
				# recoil is a systematic RISE, not scatter -- it walks the group up, and only partly recovers
				var rec: float = wd.recoil * (1.0 - clampf(shot_dt / maxf(wd.recover_s, 0.01), 0.0, 1.0))
				var off := Vector2(cos(ang), sin(ang)) * mag_mrad + Vector2(0.0, rec)
				# dispersion is angular (mrad -> metres at this range); the holdover error is already
				# in metres and does not scale with anything else
				var pt: Vector2 = off * dist * 0.001
				pt.y += rng.randf_range(-1.0, 1.0) * hold_err
				pts.append(pt)
				bloom = minf(bloom + wd.bloom_mrad, wd.bloom_max)
				bloom = maxf(bloom - (shot_dt / maxf(wd.settle_s, 0.01)) * wd.bloom_mrad, 0.0)
			# COLD BORE, the first aimed shot: no bloom, no accumulated recoil, just inherent dispersion
			# plus the holdover error. Without this the table conflates "how accurate is this weapon"
			# with "how accurate is it twelve rounds into a burst" -- which is why the carbine read 0%
			# at 200m, a range it should own. The item asks for time-to-first-hit; this is that.
			var cold_hits := 0
			for i in RANGE_SHOTS:
				var ca := rng.randf_range(0.0, TAU)
				var cm: float = absf(rng.randfn(0.0, wd.spread_mrad * 0.5))
				var cp: Vector2 = Vector2(cos(ca), sin(ca)) * cm * dist * 0.001
				cp.y += rng.randf_range(-1.0, 1.0) * hold_err
				if cp.length() <= RANGE_TARGET_R:
					cold_hits += 1
			var cold_frac := float(cold_hits) / float(RANGE_SHOTS)
			# group size = extreme spread, the way a shooter would measure it
			for a in pts.size():
				for b in range(a + 1, pts.size()):
					worst = maxf(worst, pts[a].distance_to(pts[b]))
				if pts[a].length() <= RANGE_TARGET_R:
					hits += 1
			var fs := _shot_flight(dist, 0.0, true, wd.muzzle, wd.drag_k)
			var fa := _shot_flight(dist, 0.0, false, wd.muzzle, wd.drag_k)
			var drop_s: float = float(fs.get("drop_m", 0.0))
			var drop_a: float = float(fa.get("drop_m", 0.0))
			# time to kill: rounds needed at this hit rate, paced by cycle and reloads
			var hit_frac := float(hits) / float(RANGE_SHOTS)
			# SUSTAINED RATE. Cyclic rate is a lie for anything belt-fed: the real ceiling is whichever
			# comes first, the magazine or the barrel. Rounds until overheat, then a forced pause.
			var sustained: float = 60.0 / maxf(shot_dt, 0.001)
			if wd.heat_per_shot > 0.0:
				var burst: float = floor(wd.heat_max / wd.heat_per_shot)
				var burst_t: float = burst * shot_dt
				sustained = burst / maxf(burst_t + wd.overheat_lock_s, 0.001) * 60.0
			var ttk_s := "  --  "
			if hit_frac > 0.0:
				# rounds needed at THIS hit rate, paced by the cycle and by reloads
				var need: float = ceil(RANGE_TARGET_HP / maxf(wd.damage, 0.001)) / hit_frac
				var ttk: float = need * shot_dt + floor(need / maxf(float(wd.mag), 1.0)) * wd.reload_s 					+ float(fs.get("t", 0.0))
				ttk_s = "%5.2fs" % ttk
			# no hits means no time-to-kill. Clamping the hit rate to 0.001 to avoid the divide printed
			# 487s, which reads as a slow weapon rather than as a weapon that cannot reach.
			print("%-10s %7.0fm %5.0f%% %5.0f%% %6.2fm %6.2fm %7.3fs %7.2fm %7s" % [
				wname, dist, cold_frac * 100.0, hit_frac * 100.0, worst, drop_s,
				float(fs.get("t", 0.0)), drop_a - drop_s, ttk_s])
	# THE VERTICAL SHOT. The item says long shots "drift sideways"; they do not, and this is the test
	# that shows why. Coriolis is -2*omega x v, and omega points along the SPIN AXIS -- so for anyone
	# standing on the floor, the deflection is always in the ARC-radial plane and never across the
	# ring's width. There is no windage on a ringworld. What there is instead: fire straight up and
	# the round does not come back to you, it lands a long way spinward or antispinward of you.
	for wname in want:
		if not WEAPON_ROWS.has(wname):
			continue
		var vd2: WeaponDef = _weapon_def(str(wname))
		var vv := _shot_vertical(vd2.muzzle, vd2.drag_k)
		print("RANGE %s: straight up -> back down %.0fs later, %.0fm along the arc (never sideways: "
			% [wname, float(vv["t"]), float(vv["arc"])]
			+ "omega is along the spin axis, so there is no width-wise deflection at all)")
	# DOES PLAY MATCH THE TABLE? The harness integrates in one tight loop; play integrates per frame
	# with sub-steps. If those two disagree, every number printed above is fiction the moment you pull
	# a trigger. Re-run the reference at 60Hz-with-substeps and compare.
	var chk: WeaponDef = _weapon_def("carbine")
	var ref := _shot_flight(400.0, 0.0, true, chk.muzzle, chk.drag_k)
	var Rr := _radius()
	var wr := _omega()
	var r0c := Rr - RANGE_EYE
	var pc := Vector2(0.0, r0c)
	var vc := Vector2(chk.muzzle + wr * r0c, 0.0)
	var tc := 0.0
	while tc < 5.0:
		var frame := 1.0 / 60.0
		var sub := clampi(int(ceil(vc.length() * frame / 2.0)), 1, 32)
		var sdt := frame / float(sub)
		var done := false
		for _i in sub:
			var rel := vc.length() - wr * r0c
			if chk.drag_k > 0.0 and rel > 0.0:
				vc -= vc.normalized() * (rel * rel * chk.drag_k * sdt)
			pc += vc * sdt
			tc += sdt
			var th2: float = atan2(pc.x, pc.y) - wr * tc
			if absf(th2 * Rr) >= 400.0:
				done = true
				break
		if done:
			break
	print("RANGE selfcheck: reference drop %.3fm at 400m, live integrator %.3fm (delta %.3fm)" % [
		float(ref.get("drop_m", 0.0)), RANGE_EYE - (Rr - pc.length()),
		absf(float(ref.get("drop_m", 0.0)) - (RANGE_EYE - (Rr - pc.length())))])
	print("RANGE done")
	get_tree().quit()

func _shot_run() -> void:
	# `-- --shots [patch,patch,...]` warps to each patch, waits for its stream, and writes a set of
	# framings to logs/shots/. Exists so I can LOOK at my own work instead of shipping it and
	# waiting to be told it is wrong -- which is how the inside-out houses, the pixelated ground,
	# the scattered hedges and the misaligned drape all reached the screen.
	await get_tree().create_timer(1.5).timeout
	# Timestamped, never overwritten. Shots are evidence: they get reviewed later against the
	# journal note saying what they were meant to show and what fell out of looking at them.
	# Writing every run to the same filename destroyed the previous finding each time.
	var label := ""
	var li := OS.get_cmdline_user_args().find("--label")
	if li >= 0 and li + 1 < OS.get_cmdline_user_args().size():
		label = "_" + OS.get_cmdline_user_args()[li + 1]
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var dir := "res://../logs/shots/%s%s" % [stamp.substr(0, 13), label]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var args := OS.get_cmdline_user_args()
	var want: Array = []
	var si := args.find("--shots")
	if si >= 0 and si + 1 < args.size() and not args[si + 1].begins_with("--"):
		want = Array(args[si + 1].split(","))
	if want.is_empty():
		want = ["millstreet", "dordogne", "java_majapahit", "halong_bay"]

	# WALL HEIGHT OVERRIDE (`--wall 2500`). The rim height has never actually been settled -- 4000 is a
	# placeholder that "dominates the landscape even when you are not near it" -- and it is now the one
	# number the atmosphere depth is derived from too, so it decides both how the horizon reads AND
	# where a wing's ceiling is. That is a judgement to make by looking at the same framing at several
	# heights, which needs it settable from the command line rather than off a runtime slider.
	# WHAT ARE WE ACTUALLY TRYING TO SEE? Every run used to fire all three landscape framings AND a
	# parade of every vehicle in the roster -- twenty-odd frames and a Godot launch to answer one
	# question, with the answer usually not among them (the wall-height runs never once put the rim in
	# frame). `--only ground,rim` shoots just those; the vehicle parade is now opt-in via `--vehicles`
	# rather than the tax on every single run.
	var only: Array = []
	var oi := args.find("--only")
	if oi >= 0 and oi + 1 < args.size() and not args[oi + 1].begins_with("--"):
		only = Array(args[oi + 1].split(","))
	var want_vehicles := args.has("--vehicles")
	var wi := args.find("--wall")
	if wi >= 0 and wi + 1 < args.size():
		wall_top_h = float(args[wi + 1])
		_build_walls()
	var ai := args.find("--atmo")
	if ai >= 0 and ai + 1 < args.size():
		atmo_top_h = float(args[ai + 1])
		_build_walls()
	if wi >= 0 or ai >= 0:
		print("SHOT wall %.0fm, ceiling %.0fm (air thins %.0f-%.0fm, field spans %.0fm)"
			% [wall_top_h, atmo_top_h, _space_lo(), _space_hi(),
			maxf(atmo_top_h - wall_top_h, 0.0)])
	# STOP THE CLOCK. It keeps running while the harness streams patches, so whether a shot came out
	# lit depended on how long the fetch took -- the first palawan swell run came back black. The
	# ANGLE is then set per patch inside the loop, not here: see the note at the warp.
	sun_paused = true
	# UNCAP THE FRAME TIMER. With vsync on, _measure_frame_ms can only ever report 16.6ms and every
	# scene alike reads "60 fps" -- it would be timing the wait, not the work.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	for pname in want:
		var idx := _patch_names.find(pname)
		if idx < 0 and pname != "millstreet":
			print("SHOT skip %s (not loaded)" % pname)
			continue
		if pname == "millstreet":
			_warp_to(-1)
		else:
			_warp_to(idx)
		# let the stream land, or the shot shows the 512 array tier and proves nothing
		var waited := 0.0
		while _hires_idx != idx and waited < 20.0 and idx >= 0:
			await get_tree().create_timer(0.5).timeout
			waited += 0.5
		# ground level, looking along -- the framing that actually shows roads, hedges and scale
		var r := _radius()
		var cam := _cam.global_position
		var arc: float = atan2(cam.x, r - cam.y) * r
		var lat: float = cam.z
		# DAYLIGHT IS PER-ARC. sun_angle is one global number, but on a ringworld whether it is day
		# where you stand depends on where you stand: local up at arc theta is (-sin, cos, 0), so the
		# sun is overhead when cos(theta + sun_angle) is 1. The terrain lighting already models this
		# correctly ("your night, their day") -- which is why pinning a fixed global angle still gave
		# three black frames at palawan. It was not a bug in the sun; the patch was genuinely on the
		# far side of the ring. Set the angle to put THIS patch in mid-morning.
		sun_angle = fposmod(-arc / r + 0.45, TAU)
		# clean frames: the HUD is not the thing being reviewed, and a shot taken inside a tree
		# tells you nothing. Step off the exact scatter centre before framing.
		if _hud: _hud.visible = false
		if _perf: _perf.visible = false
		arc += 60.0
		# STAND ON A ROAD. Framing the patch centre tells you nothing about hedgerows -- the
		# centre is usually open country. Walk the centrelines for the nearest point and put the
		# camera beside it, looking along the run, which is the only view that shows whether the
		# ribbon follows the road, meshes at junctions, or floats.
		var best_d := 1e20
		var best_p := Vector2(arc, lat)
		var best_t := Vector2(1.0, 0.0)
		for line in _roadlines:
			var pts: PackedVector2Array = line["pts"]
			for i in pts.size():
				var d: float = pts[i].distance_squared_to(Vector2(arc, lat))
				if d < best_d:
					best_d = d
					best_p = pts[i]
					best_t = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)])
		# Only if a road is actually NEARBY. _roadlines currently holds the home patch only, so at
		# any other patch the nearest point was 229km away and the shot framed empty ring instead
		# of the place it claimed to be photographing -- 108k triangles of nothing.
		if best_d < 5000.0 * 5000.0:
			arc = best_p.x
			lat = best_p.y
			if best_t.length_squared() > 1e-6:
				_look.x = atan2(best_t.y, best_t.x)
			print("SHOT %s: framed on a road, %.0fm from the settlement" % [pname, sqrt(best_d)])
		else:
			print("SHOT %s: NO ROAD DATA within 5km — framing the settlement instead" % pname)
		# RIM WALL + CONTAINMENT FIELD. None of the three framings below ever turns to face the rim, so
		# the wall height, the atmosphere ceiling and the field shimmer spanning between them have never
		# been in a shot -- the wall/ceiling judgement was being made blind, and the field shimmer has
		# never been seen. Aim across the strip at the NEARER rim (yaw +/-90deg toward it): one framing
		# from inside at eye level (does the wall dominate the horizon from where you play?), one from
		# above the wall top looking back (how tall the masonry is, how far the field carries it up).
		var rim_yaw: float = (PI * 0.5) if lat >= 0.0 else (-PI * 0.5)
		var field_mid: float = wall_top_h + maxf(atmo_top_h - wall_top_h, 500.0) * 0.5
		var frames := [
				{"n": "ground", "h": 2.2, "pitch": -0.04, "fov": 70.0},
				{"n": "road", "h": 6.0, "pitch": -0.18, "fov": 60.0},
				{"n": "air", "h": 400.0, "pitch": -0.55, "fov": 70.0},
				{"n": "rim", "h": 3.0, "pitch": 0.06, "fov": 45.0, "yaw": rim_yaw},
				# rimtop stands NEAR the rim, not across the strip. It was taking its lat from the patch
				# (mid-strip, ~25km out), so "above the wall top looking back" was actually a distant grey
				# band and the field it exists to show was a couple of pixels of haze. 2.5km inboard puts
				# the masonry and the shimmer above it at a size you can actually judge.
				# The docking port sits 8km up at arc 0 -- nothing on the ground can see it, so the beacon
				# was built and never once looked at. Stand off it at station-keeping range.
				{"n": "dock", "abs_h": DOCK_ALT, "pitch": 0.0, "fov": 60.0,
					"arc": DOCK_ARC - 260.0, "lat": DOCK_LAT, "yaw": 0.0},
				{"n": "rimtop", "abs_h": field_mid, "pitch": -0.05, "fov": 62.0, "yaw": rim_yaw,
					"lat": signf(rim_yaw) * (WIDTHS[w_idx] * 0.5 - 2500.0)},
			]
		# ON THE WATER. None of the three framings above ever looks at sea -- they walk to a road or a
		# settlement, both of which are on land by definition -- so a coastal patch photographed three
		# times could still show no water at all, which is exactly what happened to the swell run.
		# Spiral out from the framing point for water and sit just above it, looking level: the view
		# that shows whether the surface moves.
		#
		# The candidate must have LAND IN SIGHT. Without that test the search happily "found" 12m-deep
		# ocean 250m from palawan's anchor -- it had walked off the edge of the patch's data, and a
		# no-data sample reads as height 0, which is below sea_level, which is sea. The whole ring is
		# ringed by that phantom ocean (it is the magenta band on the horizon in the probe shot). Real
		# coastal water has a coast; the void does not.
		var sea_p := Vector2.ZERO
		var sea_found := false
		for ring_i in range(1, 40):
			var rad := float(ring_i) * 250.0
			for k in 12:
				var a := TAU * float(k) / 12.0
				var p := Vector2(arc + cos(a) * rad, lat + sin(a) * rad)
				if absf(p.y) > WIDTHS[w_idx] * 0.45 or _sea_depth(p.x, p.y) <= 1.0:
					continue
				if not _land_in_sight(p.x, p.y):
					continue
				sea_p = p
				sea_found = true
				break
			if sea_found:
				break
		if sea_found:
			frames.append({"n": "sea", "h": 3.0, "pitch": -0.02, "fov": 70.0,
				"arc": sea_p.x, "lat": sea_p.y})
			print("SHOT %s: sea framing %.0fm out, depth %.1fm"
				% [pname, sea_p.distance_to(Vector2(arc, lat)), _sea_depth(sea_p.x, sea_p.y)])
			print("      swell here: %+.2fm, %+.2fm 20m on, %+.2fm 40m on"
				% [_surface_h(sea_p.x, sea_p.y) - SEA_LEVEL,
				_surface_h(sea_p.x + 20.0, sea_p.y) - SEA_LEVEL,
				_surface_h(sea_p.x + 40.0, sea_p.y) - SEA_LEVEL])
		# capture the road-tangent yaw set above so a rim framing can override it (`yaw` key) without
		# leaking its across-strip heading into the next patch's ground/road/air frames.
		var base_yaw := _look.x
		if not only.is_empty():
			frames = frames.filter(func(f): return only.has(str(f["n"])))
		print("SHOT %s: %d framings %s" % [pname, frames.size(),
			str(frames.map(func(f): return f["n"]))])
		for shot in frames:
			# most framings share the patch's walk-to point; the sea framing carries its own
			var sa: float = float(shot.get("arc", arc))
			var sl: float = float(shot.get("lat", lat))
			if shot.has("yaw"):
				_look.x = float(shot["yaw"])
			# abs_h places the camera at an ABSOLUTE ring height (rimtop, which sits above the wall top
			# where terrain height is meaningless); every other framing is terrain-relative.
			var cam_h: float = float(shot["abs_h"]) if shot.has("abs_h") else _terrain_h(sa, sl) + float(shot["h"])
			_cam.position = _ring_pos(sa / r, sl, cam_h)
			_cam.fov = float(shot["fov"])
			_look.x = float(shot.get("yaw", base_yaw))
			_look.y = float(shot["pitch"])
			_apply_look()
			# roadside furniture follows the streamed patch too, or hedges, verge and the grass
			# road-avoidance stay stuck on the home patch wherever you actually are
			if _roadline_patch != _hires_idx:
				_roadline_patch = _hires_idx
				_load_roadlines()
			_scatter_trees()
			_refill_buildings(true)
			_build_hedge_ribbon()
			# two frames: one to submit the new transforms, one to render them
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var path := "%s/%s_%s.png" % [dir, pname, shot["n"]]
			img.save_png(path)
			print("      " + _tri_breakdown())
			print("SHOT %-18s %-7s tris=%d %s  %s" % [
				pname, shot["n"],
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				await _measure_frame_ms(), path])
	# VEHICLES. The patch loop above never enters DRIVE, so an imported car model could be sideways,
	# giant or underground and no frame would catch it. Enter DRIVE at home, let the chase cam settle,
	# and shoot each vehicle from behind -- the framing that shows orientation, scale and grounding.
	# OPT-IN (`--vehicles`): this is a whole-roster parade, and it was running on every landscape
	# question anybody asked.
	if not want_vehicles:
		print("SHOT vehicles skipped (pass --vehicles for the roster parade)")
		if _hud: _hud.visible = true
		if _perf: _perf.visible = true
		get_tree().quit()
		return
	_warp_to(-1)
	_set_mode(Mode.DRIVE)
	# start the chase cam near the car, else it eases down from the last aerial framing (400 m up) and
	# the car is a speck in the shot.
	var cpos := _car_pos(_car_arc, _car_lat)
	_cam.position = cpos + _ring_up(cpos) * 6.0
	for _k in 30:
		await get_tree().process_frame
	for vi in _vehicles.size():
		_select_vehicle(vi)
		for _k in 24:
			await get_tree().process_frame       # let the eased chase cam swing onto this one
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var vname: String = _vehicles[vi]["name"]
		var vpath := "%s/vehicle_%s.png" % [dir, vname]
		get_viewport().get_texture().get_image().save_png(vpath)
		# COST PER VEHICLE (TASKS.md "Test harness for all of them"). The parade proved orientation and
		# scale but reported nothing measurable, so a model that costs ten times its neighbour looked
		# identical in the log. tris and frame time make the roster comparable instead of a set of
		# separate impressions -- the same argument the proving course makes for handling.
		print("SHOT vehicle %-10s tris=%-6d scene=%-7d %s  %s" % [vname,
			_node_tris(_car) if _car != null else 0,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			await _measure_frame_ms(12), vpath])
	if _hud: _hud.visible = true
	if _perf: _perf.visible = true
	print("SHOTS done")
	get_tree().quit()

func _align_sweep() -> void:
	# `-- --align` sweeps a GRID of sample points across every patch and checks that the CPU and the
	# shader would resolve to the same height tier at each one. The [Y] probe only ever answers for
	# the point the camera happens to occupy, which is exactly why this class of bug kept surviving:
	# every fix looked correct where I was standing. Ownership boundaries, the streamed patch's own
	# rect edge, and the lat clamp are all places the two sides can diverge, and none of them are
	# where you naturally stand.
	await get_tree().create_timer(1.0).timeout
	print("\nALIGN: %d patches, %dx%d samples each" % [_patch_rects.size(), ALIGN_N, ALIGN_N])
	var bad_total := 0
	var worst_all := 0.0
	var worst_where := ""
	for i in _patch_rects.size():
		var r: Vector4 = _patch_rects[i]
		var own: float = _patch_own[i] if i < _patch_own.size() else r.z
		var lat_lim: float = minf(r.w, WIDTHS[w_idx] * 0.47)
		var bad := 0
		var worst := 0.0
		var sea := 0
		# sample right out to the ownership edge -- the interior was never the problem
		for gy in ALIGN_N:
			for gx in ALIGN_N:
				var fx := (float(gx) / float(ALIGN_N - 1)) * 2.0 - 1.0
				var fy := (float(gy) / float(ALIGN_N - 1)) * 2.0 - 1.0
				var arc: float = r.x + fx * own * 0.995
				var lat: float = r.y + fy * lat_lim * 0.995
				var t := _probe_tiers(arc, lat)
				# what the shader's sample_h_raw would pick, in its order
				var gpu := "procedural"
				if not is_nan(float(t["home"])):
					gpu = "HOME"
				elif not is_nan(float(t["hires"])):
					gpu = "HIRES"
				elif not is_nan(float(t["array"])):
					gpu = "ARRAY"
				if gpu != str(t["tier"]):
					bad += 1
					var g := _terrain_h(arc, lat)
					var o: float = float(t[gpu.to_lower()]) if not is_nan(float(t.get(gpu.to_lower(), NAN))) else g
					worst = maxf(worst, absf(o - g))
				if _terrain_h(arc, lat) <= SEA_LEVEL + 0.5:
					sea += 1
		bad_total += bad
		if worst > worst_all:
			worst_all = worst
			worst_where = str(_patch_names[i])
		var tag := "ok" if bad == 0 else ("MISMATCH x%d, worst %.1fm" % [bad, worst])
		print("ALIGN  %-18s arc %5.1f%%  own +-%5.0fm  sea %3d%%   %s" % [
			_patch_names[i], 100.0 * r.x / CIRCUMFERENCES[c_idx], own,
			100 * sea / (ALIGN_N * ALIGN_N), tag])
	print("ALIGN: %d/%d sample points disagree about which tier to use%s" % [
		bad_total, _patch_rects.size() * ALIGN_N * ALIGN_N,
		"" if bad_total == 0 else ("   worst %.1fm in %s" % [worst_all, worst_where])])
	# second pass: do OBJECTS sit on the surface? placement and drawing share _terrain_h, so this is
	# checking the thing that actually reaches the screen rather than the thing I keep reasoning about
	var float_bad := 0
	var float_worst := 0.0
	var i2 := 0
	while i2 < _bldg.size():
		var gh := _terrain_h(_bldg[i2], _bldg[i2 + 1])
		if gh > SEA_LEVEL + 0.5:
			var hw: float = _bldg[i2 + 2] * 0.5
			var hd: float = _bldg[i2 + 3] * 0.5
			var yc := cos(_bldg[i2 + 4])
			var ys := sin(_bldg[i2 + 4])
			var top := -1e20
			var low := 1e20
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var c := _terrain_h(_bldg[i2] + sx * hw * yc - sz * hd * ys,
						_bldg[i2 + 1] + sx * hw * ys + sz * hd * yc)
					top = maxf(top, c)
					low = minf(low, c)
			# the undercroft is one building-height deep, so a drop bigger than that shows daylight
			if top - low > _bldg[i2 + 5]:
				float_bad += 1
				float_worst = maxf(float_worst, top - low)
		i2 += 6
	print("ALIGN: %d/%d buildings on ground steeper than their undercroft can cover (worst %.1fm drop)"
		% [float_bad, _bldg.size() / 6, float_worst])
	get_tree().quit()

func _run_selftest() -> void:
	# `--selftest` (after a -- separator) walks every loaded splice and reports whether the
	# high-res stream landed and whether CPU height agrees with the patch data. Exists because the
	# streaming path can't be exercised from a headless smoke test any other way -- there is no one
	# to press [.] -- and a threaded decode silently falling back to the array tier would otherwise
	# look identical to success in the log.
	await get_tree().create_timer(1.0).timeout
	print("SELFTEST: %d patches loaded" % _patch_rects.size())
	var streamed := 0
	for i in _patch_rects.size():
		_jump_splice(1)
		var waited := 0.0
		while _hires_idx != _jump_idx and waited < 12.0:
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
		var r := _patch_rects[_jump_idx]
		var hcpu := _terrain_h(r.x, r.y)
		var ok: bool = _hires_idx == _jump_idx
		if ok:
			streamed += 1
		# sample a grid across the patch: sea fraction validates the ocean clamp against real data
		# (a coastal splice reporting 0% would mean the clamp never fires), and min/max height
		# catches a patch that decoded as flat or garbage.
		var wet := 0
		var n := 0
		var hmin := 1e9
		var hmax := -1e9
		for gy in 24:
			for gx in 24:
				var sa: float = r.x + (float(gx) / 23.0 - 0.5) * 2.0 * r.z * 0.98
				var sl: float = r.y + (float(gy) / 23.0 - 0.5) * 2.0 * r.w * 0.98
				var hh := _terrain_h(sa, sl)
				hmin = minf(hmin, hh)
				hmax = maxf(hmax, hh)
				if hh <= SEA_LEVEL:
					wet += 1
				n += 1
		var bio := _biome_at(r.x, r.y)
		print("SELFTEST  %-18s arc %5.1f%%  stream=%s (%.1fs)  h %.0f..%.0fm  sea %4.1f%%  trees=%-6d dens=%.2f hi=%.0f  wx=%s" % [
			_patch_names[_jump_idx], 100.0 * r.x / CIRCUMFERENCES[c_idx],
			"OK" if ok else "FAIL", waited, hmin, hmax,
			100.0 * float(wet) / float(n), _tree_ground.size(),
			bio["trees"], bio["tree_hi"], bio["weather"]])
	print("SELFTEST: %d/%d streamed OK" % [streamed, _patch_rects.size()])
	get_tree().quit()

func _jump_splice(dir: int) -> void:
	# hop to the next/previous loaded splice along the arc. 3000km at 4000 m/s is 12 minutes of
	# flying to see the whole ring, which makes reviewing the splices impractical without this.
	if _patch_rects.is_empty():
		return
	_jump_idx = wrapi(_jump_idx + dir, 0, _patch_rects.size())
	var r := _patch_rects[_jump_idx]
	var rad := _radius()
	var theta: float = r.x / rad
	var h := _terrain_h(r.x, r.y) + 250.0
	_cam.position = _ring_pos(theta, r.y, h)
	# yaw 0 is spinward in the local ring frame, so arriving level and slightly nose-down is just
	# (0, -0.18) -- no need to derive a world-space forward vector any more.
	_look = Vector2(0.0, -0.18)
	_apply_look()
	_tree_center = Vector2(r.x, r.y)
	_scatter_trees()
	_refill_buildings(true)
	print("ring_vibes: jumped to %s (%.1f%% arc)" % [_patch_names[_jump_idx], 100.0 * r.x / CIRCUMFERENCES[c_idx]])
	_update_hud()

func _hires_decode(idx: int) -> void:
	# WORKER THREAD. Only touches FileAccess + Image (both thread-safe in Godot 4); the texture is
	# created by the main thread in _hires_poll(). Result is handed over via _hires_result.
	var out := {"idx": idx, "ok": false}
	var base: String = "res://mocks/dem/%s" % _patch_names[idx]   # NOT PATCHES[idx], see _patch_meta
	if FileAccess.file_exists(base + ".r16") and FileAccess.file_exists(base + ".json"):
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
		var w := int(meta["w"])
		var h := int(meta["h"])
		var hs := float(meta.get("h_scale", 16.0))
		var raw := FileAccess.get_file_as_bytes(base + ".r16")
		if raw.size() >= w * h * 2:
			var res: int = mini(HIRES_RES, mini(w, h))
			var floats := PackedFloat32Array()
			floats.resize(res * res)
			# box mean, matching the pre-filtered array tier. This runs on a WorkerThreadPool task,
			# so the extra reads cost nothing the player can feel -- and without it this tier and the
			# array tier answer different heights for the same ground.
			for y in res:
				var y0: int = int(float(y) * float(h) / float(res))
				var y1: int = maxi(int(float(y + 1) * float(h) / float(res)), y0 + 1)
				for x in res:
					var x0: int = int(float(x) * float(w) / float(res))
					var x1: int = maxi(int(float(x + 1) * float(w) / float(res)), x0 + 1)
					var acc := 0.0
					var n := 0
					for yy in range(y0, mini(y1, h)):
						var row := yy * w
						for xx in range(x0, mini(x1, w)):
							acc += float(raw.decode_u16((row + xx) * 2))
							n += 1
					floats[y * res + x] = (acc / float(maxi(n, 1))) / hs
			out["img"] = Image.create_from_data(res, res, false, Image.FORMAT_RF, floats.to_byte_array())
			out["field"] = floats
			out["res"] = res
			out["ok"] = true
			if FileAccess.file_exists(base + "_sat.dat"):
				var ci := Image.new()
				if ci.load_png_from_buffer(FileAccess.get_file_as_bytes(base + "_sat.dat")) == OK:
					# Never upsample. Take the smaller of the cap and what the file actually contains, so a
					# patch refetched at 8192 gets 8192 and one still on the old 4096 canvas stays 4096 --
					# rather than inventing pixels, which measurably cost memory and stream time for nothing.
					var tgt: int = mini(hires_tex_res, mini(ci.get_width(), ci.get_height()))
					if ci.get_width() != tgt or ci.get_height() != tgt:
						ci.resize(tgt, tgt, Image.INTERPOLATE_LANCZOS)
					ci.convert(Image.FORMAT_RGB8)
					# compressing a 4096^2 is seconds of work -- it belongs here on the worker task,
					# not on the frame that swaps the texture in
					if _tex_mode == TexMode.S3TC:
						ci.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_SRGB)
					elif _tex_mode == TexMode.BPTC:
						ci.compress(Image.COMPRESS_BPTC, Image.COMPRESS_SOURCE_SRGB)
					out["col"] = ci
					out["col_bytes"] = ci.get_data().size()
			# full-res gradient normals, same asset the home patch uses. These were generated for
			# every patch all along (export_to_game.py always writes them) and simply never loaded,
			# which is why only the starting area had fine relief.
			if FileAccess.file_exists(base + "_detail.dat"):
				var di := Image.new()
				if di.load_png_from_buffer(FileAccess.get_file_as_bytes(base + "_detail.dat")) == OK:
					di.resize(hires_tex_res, hires_tex_res, Image.INTERPOLATE_LANCZOS)
					di.convert(Image.FORMAT_RGB8)
					out["detail"] = di
	_hires_result = out

func _hires_poll() -> void:
	# MAIN THREAD. Kick off a decode when the camera changes patch; adopt the result when ready.
	if _hires_task >= 0:
		if not WorkerThreadPool.is_task_completed(_hires_task):
			return
		WorkerThreadPool.wait_for_task_completion(_hires_task)
		_hires_task = -1
		var r: Dictionary = _hires_result
		_hires_result = {}
		if r.get("ok", false) and int(r.get("idx", -1)) == _hires_pending:
			_hires_tex = ImageTexture.create_from_image(r["img"])
			_hires_col_tex = ImageTexture.create_from_image(r["col"]) if r.has("col") else null
			_tex_bytes = int(r.get("col_bytes", 0))
			if "--texprobe" in OS.get_cmdline_user_args():
				print("TEXPROBE mode=%s res=%d bytes=%d (%.1f MB, RGB8 would be %.1f MB)" % [
					["raw", "s3tc", "bptc"][_tex_mode], hires_tex_res, _tex_bytes,
					float(_tex_bytes) / 1048576.0,
					float(hires_tex_res * hires_tex_res * 3) / 1048576.0])
			_hires_detail_tex = ImageTexture.create_from_image(r["detail"]) if r.has("detail") else null
			_hires_idx = int(r["idx"])
			_hires_field = r["field"]
			_hires_res = int(r["res"])
			var rect := _patch_rects[_hires_idx]
			for m in _mats:
				m.set_shader_parameter("hires_tex", _hires_tex)
				if _hires_col_tex:
					m.set_shader_parameter("hires_col_tex", _hires_col_tex)
				m.set_shader_parameter("hires_has_col", _hires_col_tex != null)
				if _hires_detail_tex:
					m.set_shader_parameter("hires_detail_tex", _hires_detail_tex)
				m.set_shader_parameter("hires_has_detail", _hires_detail_tex != null)
				m.set_shader_parameter("hires_rect", rect)
				m.set_shader_parameter("hires_own", _patch_own[_hires_idx])
				m.set_shader_parameter("hires_offset", _patch_offset[_hires_idx])
				m.set_shader_parameter("hires_valid", true)
			# A landed stream CHANGES WHAT _terrain_h ANSWERS -- the hires tier now wins where the
			# 512^2 array did, and the two disagree by whatever detail the array threw away. Anything
			# already placed against the old tier is now at the wrong height, which is trees and the
			# car ending up at one level and houses at another. Re-place both.
			# The centrelines must follow the stream too, or the ribbon and the tree-clearing stay
			# pinned to the home patch wherever you drive -- the shot harness already does this, live
			# play did not.
			if _roadline_patch != _hires_idx:
				_roadline_patch = _hires_idx
				_load_roadlines()
			_scatter_trees()
			_refill_buildings(true)
			_build_hedge_ribbon()
			print("ring_vibes: streamed %s @ %d^2%s — re-placed objects onto the new tier" % [
				_patch_names[_hires_idx], _hires_res, "" if _hires_col_tex else " (no imagery)"])
		_hires_pending = -1
		return
	# idle: does the camera's current patch differ from what's resident?
	if _patch_rects.is_empty():
		return
	var r_now := _radius()
	var arc: float = atan2(_cam.global_position.x, r_now - _cam.global_position.y) * r_now
	var want := _patch_at(arc, _cam.global_position.z)
	if want < 0 or want == _hires_idx:
		return
	_hires_pending = want
	_hires_task = WorkerThreadPool.add_task(_hires_decode.bind(want))

func _biome_at(arc: float, lat: float) -> Dictionary:
	# home DEM first (it wins for heights too), then splice patches, then a generic default for the
	# procedural stretches between them.
	if _dem_hf_w > 0:
		var fx := _dem_hf_cam.x + arc / _dem_hf_mpp
		var fy := _dem_hf_cam.y - lat / _dem_hf_mpp
		if fx >= 0.0 and fy >= 0.0 and fx < float(_dem_hf_w - 1) and fy < float(_dem_hf_h - 1):
			return {"trees": HOME_TREES, "tree_hi": HOME_TREE_HI, "weather": "fresh",
				"foliage": Color(1, 1, 1), "tree_mul": 1.0, "species": "fir"}
	var pi := _patch_at(arc, lat)
	if pi >= 0:
		var p: Dictionary = _patch_meta[pi]   # NOT PATCHES[pi] -- indices diverge, see _patch_meta
		return {"trees": float(p.get("trees", 0.5)), "tree_hi": float(p.get("tree_hi", 800.0)),
				"weather": str(p.get("weather", "fresh")),
				"foliage": p.get("foliage", Color(1, 1, 1)),
			"species": str(p.get("species", "fir")),
				"tree_mul": float(p.get("tree_mul", 1.0))}
	return {"trees": 0.35, "tree_hi": 700.0, "weather": "fresh",
			"foliage": Color(1, 1, 1), "tree_mul": 1.0, "species": "fir"}   # procedural filler

func _here_splice() -> String:
	# which splice the camera is currently standing in, for the HUD
	var r := _radius()
	var arc: float = atan2(_cam.global_position.x, r - _cam.global_position.y) * r
	if _dem_hf_w > 0:
		var fx := _dem_hf_cam.x + arc / _dem_hf_mpp
		var fy := _dem_hf_cam.y - _cam.global_position.z / _dem_hf_mpp
		if fx >= 0.0 and fy >= 0.0 and fx < float(_dem_hf_w - 1) and fy < float(_dem_hf_h - 1):
			return "millstreet (home, full res)"
	var pi := _patch_at(arc, _cam.global_position.z)
	return str(_patch_names[pi]) if pi >= 0 else "procedural (no splice)"

func _patch_floor(field: PackedFloat32Array) -> float:
	# 2nd percentile of a subsample, NOT the minimum -- Terrarium mosaics carry single-pixel decode
	# artifacts (the known Savannah/Guri glitch class), and one bogus low pixel would drag a whole
	# patch's re-basing with it. Subsampled because sorting 262k floats in GDScript is not free.
	var s := PackedFloat32Array()
	var stride: int = maxi(1, field.size() / 4096)
	var i := 0
	while i < field.size():
		s.append(field[i])
		i += stride
	if s.is_empty():
		return 0.0
	s.sort()
	return s[int(float(s.size()) * 0.02)]

func _load_patches() -> void:
	# each splice is resampled to PATCH_RES^2 and stacked into one Texture2DArray; a CPU copy is
	# kept alongside so _terrain_h returns exactly what the shader draws (render-authoritative
	# placement -- see .decisions/terrain.md#render-authoritative-placement).
	var imgs: Array[Image] = []
	var cols: Array[Image] = []
	var any_col := false
	_patch_rects = PackedVector4Array()
	_patch_tints = PackedColorArray()
	_patch_fields = []
	_patch_names = []
	_patch_meta = []
	_patch_offset = PackedFloat32Array()
	var circumference: float = CIRCUMFERENCES[c_idx]
	for p in PATCHES:
		if imgs.size() >= MAX_PATCHES:
			break
		var base: String = "res://mocks/dem/%s" % p["name"]
		if not (FileAccess.file_exists(base + ".r16") and FileAccess.file_exists(base + ".json")):
			continue
		# real imagery if the pipeline has fetched it; a flat tint plate stands in until then, so a
		# half-finished fetch still renders (the array needs every layer present and same-size).
		var cimg: Image = null
		if FileAccess.file_exists(base + "_sat.dat"):
			var ci := Image.new()
			if ci.load_png_from_buffer(FileAccess.get_file_as_bytes(base + "_sat.dat")) == OK:
				ci.resize(PATCH_COL_RES, PATCH_COL_RES, Image.INTERPOLATE_LANCZOS)
				ci.convert(Image.FORMAT_RGB8)
				cimg = ci
				any_col = true
		if cimg == null:
			cimg = Image.create(PATCH_COL_RES, PATCH_COL_RES, false, Image.FORMAT_RGB8)
			cimg.fill(p["tint"])
		cols.append(cimg)
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
		var w := int(meta["w"])
		var h := int(meta["h"])
		var mpp := float(meta["m_per_px"])
		var hs := float(meta.get("h_scale", 16.0))
		var floats := PackedFloat32Array()
		floats.resize(PATCH_RES * PATCH_RES)
		# Prefer the box-filtered 512 written by export_to_game.py. Decimating here by POINT SAMPLE
		# -- one source pixel per block, the rest discarded -- disagreed with the 1536 stream, which
		# point-sampled at a different rate and so picked a different pixel. Measured difference from
		# the block mean: 63.8m average at Millstreet, 40m at Cape, p99 in the hundreds. Objects were
		# floating by whichever pixel each tier happened to land on.
		var mip := base + "_512.r16"
		var used_mip := false
		if FileAccess.file_exists(mip):
			var mraw := FileAccess.get_file_as_bytes(mip)
			if mraw.size() >= PATCH_RES * PATCH_RES * 2:
				for i in PATCH_RES * PATCH_RES:
					floats[i] = float(mraw.decode_u16(i * 2)) / hs
				used_mip = true
		if not used_mip:
			var raw := FileAccess.get_file_as_bytes(base + ".r16")
			for y in PATCH_RES:
				var sy: int = mini(int(float(y) / float(PATCH_RES) * float(h)), h - 1)
				for x in PATCH_RES:
					var sx: int = mini(int(float(x) / float(PATCH_RES) * float(w)), w - 1)
					floats[y * PATCH_RES + x] = float(raw.decode_u16((sy * w + sx) * 2)) / hs
		imgs.append(Image.create_from_data(PATCH_RES, PATCH_RES, false, Image.FORMAT_RF, floats.to_byte_array()))
		_patch_fields.append(floats)
		_patch_names.append(p["name"])
		_patch_meta.append(p)
		var off := 0.0
		if REBASE_PATCHES:
			var floor_h := _patch_floor(floats)
			off = REBASE_FLOOR - floor_h if floor_h > REBASE_ABOVE else 0.0
		# Per-patch sea offset. A river delta or salt marsh sits within a metre or two of the global
		# SEA_LEVEL clamp, so most of its land renders as ocean. Author the fraction the IMAGERY shows
		# as water and lift the whole patch's datum so the DEM's sea fraction matches -- derived from
		# THIS patch's own heights, so it generalises to any low-lying splice. Applied before the clamp
		# in both shader (patch_offset[] in cdlod_ring.gdshader) and CPU, so placement stays in sync.
		if p.has("sea_pct"):
			var sorted := floats.duplicate()
			sorted.sort()
			var q: float = clampf(float(p["sea_pct"]) * 0.01, 0.0, 1.0)
			var pct_h: float = sorted[clampi(int(q * float(sorted.size() - 1)), 0, sorted.size() - 1)]
			off += SEA_LEVEL - pct_h
		_patch_offset.append(off)   # 0 = real absolute elevation (REBASE off)
		_patch_rects.append(Vector4(
			fposmod(float(p["arc_pct"]) * circumference, circumference),   # arc centre
			0.0,                                                            # lat centre (ring midline)
			float(w) * mpp * 0.5, float(h) * mpp * 0.5))                    # half extents
		_patch_tints.append(p["tint"])
	if imgs.is_empty():
		print("ring_vibes: no secondary splice patches found (run tools/dem export for them)")
		return
	_clip_patch_overlap()
	_patch_tex = Texture2DArray.new()
	_patch_tex.create_from_images(imgs)
	_patch_col_tex = Texture2DArray.new()
	_patch_col_tex.create_from_images(cols)
	print("ring_vibes: %d splice patches @ %d^2 heights%s -> %s" % [
		imgs.size(), PATCH_RES, (" + %d^2 imagery" % PATCH_COL_RES) if any_col else " (tints only, no sat yet)",
		str(_patch_names)])

func _clip_patch_overlap() -> void:
	# CLEAN SEAMS, NO OVERLAP. Patches are ~97km wide but seated 84km apart, so every adjacent pair
	# overlapped by ~13km, and with real (un-rebased) elevations the two claimants disagree about the
	# ground by tens of metres. That produced a genuine second terrain layer with its own houses on
	# it: the shader tests in_hires() first over the streamed patch's whole extent, while the CPU only
	# uses hires when _patch_at() -- which returns the first index that matches -- returns that same
	# patch. Inside the overlap the two picked differently, so objects sat on a surface the GPU was
	# not drawing there. Backface culling hid the upper layer until you flew above it.
	#
	# Ownership gets half the gap to the nearest neighbour, so exactly one patch claims any arc and
	# CPU and GPU cannot disagree. SAMPLING still uses the full extent -- clipping that instead would
	# squash every patch's heights and imagery into 84km of the 97km they cover.
	var circ: float = CIRCUMFERENCES[c_idx]
	_patch_own = PackedFloat32Array()
	_patch_own.resize(_patch_rects.size())
	var clipped := 0
	for i in _patch_rects.size():
		var nearest := circ
		for j in _patch_rects.size():
			if i == j:
				continue
			var d: float = absf(wrapf(_patch_rects[j].x - _patch_rects[i].x, -circ * 0.5, circ * 0.5))
			nearest = minf(nearest, d)
		_patch_own[i] = minf(nearest * 0.5, _patch_rects[i].z)
		if _patch_own[i] < _patch_rects[i].z:
			clipped += 1
	if clipped > 0:
		print("ring_vibes: %d patch(es) clipped to non-overlapping arc windows" % clipped)

func _patch_at(arc: float, lat: float) -> int:
	# CPU mirror of the shader's patch lookup. Arc is compared with wraparound so a patch near the
	# 0%/100% seam still matches from either side.
	var circumference: float = CIRCUMFERENCES[c_idx]
	for i in _patch_rects.size():
		var r := _patch_rects[i]
		var d_arc: float = absf(wrapf(arc - r.x, -circumference * 0.5, circumference * 0.5))
		# fall back to the sampling extent if ownership has not been computed yet
		var own: float = _patch_own[i] if i < _patch_own.size() else r.z
		if d_arc < own and absf(lat - r.y) < r.w:
			return i
	return -1

func _patch_height(i: int, arc: float, lat: float) -> float:
	var r := _patch_rects[i]
	var circumference: float = CIRCUMFERENCES[c_idx]
	var d_arc: float = wrapf(arc - r.x, -circumference * 0.5, circumference * 0.5)
	var u: float = clampf(d_arc / (2.0 * r.z) + 0.5, 0.0, 0.999)
	var v: float = clampf(0.5 - (lat - r.y) / (2.0 * r.w), 0.0, 0.999)
	var field: PackedFloat32Array = _patch_fields[i]
	return (_bilerp(field, PATCH_RES, PATCH_RES,
			u * float(PATCH_RES) - 0.5, v * float(PATCH_RES) - 0.5)
			+ _patch_offset[i]) * dem_scale

const SEA_LEVEL := 0.5      # must match cdlod_ring.gdshader's sea_level uniform
var ocean_enabled := true

func _bilerp(field: PackedFloat32Array, w: int, h: int, fx: float, fy: float) -> float:
	# Matches GLSL texture() with linear filtering, which interpolates around (uv * size - 0.5) --
	# the texel-CENTRE convention. Two bugs lived here and both put placed objects under the drawn
	# surface: the patch and hires tiers sampled NEAREST while the shader sampled bilinear, and the
	# home DEM sampled at uv*size instead of uv*size-0.5, half a texel off. At a 190m patch texel
	# that is ~95m of horizontal error, which on any slope is metres of vertical -- hence the car
	# driving under the ground in the starting area and buildings sinking on the Java volcano.
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var x1 := clampi(x0 + 1, 0, w - 1)
	var y1 := clampi(y0 + 1, 0, h - 1)
	x0 = clampi(x0, 0, w - 1)
	y0 = clampi(y0, 0, h - 1)
	return lerpf(lerpf(field[y0 * w + x0], field[y0 * w + x1], tx),
			lerpf(field[y1 * w + x0], field[y1 * w + x1], tx), ty)

func _terrain_h(arc: float, lat: float) -> float:
	# clamp to sea level exactly as the shader does, so you stand ON the water surface rather than
	# on the seabed under it (render-authoritative placement).
	#
	# STATIC on purpose. This is the placement authority -- trees, buildings, hedges, road cells, the
	# collision body and the --align selftest all call it, and every one of them wants an answer that
	# does not change between two calls a frame apart. The swell is deliberately NOT here: adding it
	# would make the forests bob. Anything that should ride the live water surface calls _surface_h
	# below instead. Do not "unify" these two.
	var h := _terrain_h_raw(arc, lat)
	return SEA_LEVEL if (ocean_enabled and h < SEA_LEVEL) else h

# --- SWELL, CPU side. Twin of wave_h/wave_fade in cdlod_ring.gdshader; the two must match to the
# metre or a hull rides through the drawn surface. Same three sines, same fade terms, same centre.
var _wave_center := Vector2.ZERO
var wave_amp := 1.0
const WAVE_NEAR := 400.0
const WAVE_FAR := 1200.0

func _wave_h(arc: float, lat: float) -> float:
	var w := sin(arc * 0.031 + lat * 0.017 + _wave_time * 0.90) * 0.55
	w += sin(arc * -0.013 + lat * 0.043 + _wave_time * 1.31) * 0.34
	w += sin(arc * 0.071 + lat * -0.059 + _wave_time * 1.87) * 0.15
	w += sin(arc * 0.21 + lat * 0.16 + _wave_time * 3.10) * 0.09
	return w

const SHOAL_D := 0.35   # see cdlod_ring.gdshader: 0.35 and not 8.0 because there is no bathymetry

func _wave_fade(arc: float, lat: float, depth: float) -> float:
	return smoothstep(0.0, SHOAL_D, depth) * (1.0
		- smoothstep(WAVE_NEAR, WAVE_FAR, _wave_center.distance_to(Vector2(arc, lat))))

# The LIVE surface: ground where there is ground, moving water where there is sea. What floats reads
# this; what is planted reads _terrain_h.
func _surface_h(arc: float, lat: float) -> float:
	var h := _terrain_h_raw(arc, lat)
	if ocean_enabled and h < SEA_LEVEL:
		return SEA_LEVEL + _wave_h(arc, lat) * wave_amp * _wave_fade(arc, lat, SEA_LEVEL - h)
	return h + _proving_surface(arc, lat)

# How deep is the water here? Negative means dry land.
#
# NOT (SEA_LEVEL - height), which is the obvious implementation and is useless: Terrarium floors its
# tiles at 0m, so 87.2% of palawan is EXACTLY 0.0 and the sea is a flat plate half a metre below the
# clamp. There is no bathymetry anywhere on the ring. Measured, not assumed -- and it silently broke
# two things built on top of it before it was caught: the swell faded itself to 2cm, and a barge with
# a 2.4m draft would have been aground in mid-ocean.
#
# So depth is INFERRED FROM DISTANCE TO SHORE: probe outward for the nearest land and read off a
# synthetic shelf. It is not real bathymetry, but it gets the property that actually matters for
# boats -- shallow near the beach, deep offshore -- and it is derived from the coastline, which IS
# real data. Replace it the day a bathymetric source lands.
const SEA_SHELF := 400.0     # metres offshore at which the synthetic shelf reaches full depth
const SEA_MAX_DEPTH := 12.0
# SYNTHESISED SEABED (see .decisions/terrain.md#synthetic-seabed). There is no real bathymetry -- Terrarium
# floors its tiles at 0 -- so rather than block the submersible on a GEBCO download the deep floor is
# generated the way this project generates everything else: past the shelf edge it keeps falling toward
# SEA_ABYSS, and noise lays banks and trenches (SEA_RELIEF) over it so there is varied ground to descend to.
const SEA_ABYSS := 60.0      # deepest the offshore floor reaches, m below SEA_LEVEL -- the dive target
const SEA_RELIEF := 9.0      # +/- amplitude of the generated banks and trenches on that floor, m

# Is there a coastline within a few km? Distinguishes real sea from the PHANTOM OCEAN that surrounds
# every patch: outside a patch's data the height sampler returns 0, which is below SEA_LEVEL, which
# renders and tests as water. It looks exactly like ocean and is not -- nothing is there.
func _land_in_sight(arc: float, lat: float, radius: float = 2500.0) -> bool:
	for rad in [600.0, 1200.0, radius]:
		for k in 8:
			var a := TAU * float(k) / 8.0
			if _terrain_h_raw(arc + cos(a) * rad, lat + sin(a) * rad) > SEA_LEVEL:
				return true
	return false

# Is this sample backed by real data (home DEM or a splice patch), or is it the procedural
# fallback? The distinction is the whole of the phantom-ocean decision: outside all data the height
# is `maxf(noise,0)*DISP`, whose low half sits below SEA_LEVEL and is indistinguishable from real
# coastal sea by value alone -- but nothing is there. See .decisions/terrain.md#void-is-not-sea.
func _has_terrain_data(arc: float, lat: float) -> bool:
	if _dem_hf_w > 0:
		var fx := _dem_hf_cam.x + arc / _dem_hf_mpp
		var fy := _dem_hf_cam.y - lat / _dem_hf_mpp
		if fx >= 0.0 and fy >= 0.0 and fx < float(_dem_hf_w - 1) and fy < float(_dem_hf_h - 1):
			return true
	return _patch_at(arc, lat) >= 0

func _sea_depth(arc: float, lat: float) -> float:
	if _terrain_h_raw(arc, lat) > SEA_LEVEL:
		return -1.0
	# The VOID is not sea. Off every patch the height sampler floors to a procedural value that dips
	# below SEA_LEVEL, so the old code walked out to SEA_SHELF, found no shore (there is none), and
	# returned SEA_MAX_DEPTH -- the "12 m of ocean by walking off the data" that broke the framing
	# search and would float a boat on nothing. No data backing => dry, before any shore probe.
	if not _has_terrain_data(arc, lat):
		return -1.0
	# SHELF: the nearest-land distance sets the shallow->deep trend, derived from the real coastline. `off`
	# is 0 at the beach and 1 past SEA_SHELF; the shelf depth grades with it exactly as before, so the
	# near-shore water where boats ground is UNCHANGED. (Same nearest-radius probe, just kept as a fraction.)
	var off := 1.0
	for rad in [25.0, 60.0, 120.0, 250.0, SEA_SHELF]:
		var found := false
		for k in 8:
			var a := TAU * float(k) / 8.0
			if _terrain_h_raw(arc + cos(a) * rad, lat + sin(a) * rad) > SEA_LEVEL:
				found = true
				break
		if found:
			off = rad / SEA_SHELF
			break
	var shelf := SEA_MAX_DEPTH * off
	# ABYSS + RELIEF: past the shelf edge the floor keeps falling toward SEA_ABYSS, and noise lays banks and
	# trenches over it -- the SYNTHESISED bathymetry the submersible descends through. Both fade in with `off`
	# (off^2 for the abyss, so the slope steepens offshore), so only open water gets the deep, varied floor
	# and the shelf that boat grounding reads stays as it was.
	var abyss := (SEA_ABYSS - SEA_MAX_DEPTH) * off * off
	var relief := _noise.get_noise_2d(arc * 0.02, lat * 0.02) * SEA_RELIEF * off
	return maxf(0.3, shelf + abyss + relief)

func _terrain_h_raw(arc: float, lat: float) -> float:
	# EXACT match to what the CDLOD shader draws (same half-res field + UV mapping) — render-
	# authoritative placement without raycast/collision (near camera is always CDLOD's finest LOD,
	# so this analytic value already equals the drawn vertex height there).
	if _dem_hf_w > 0:
		var fx := _dem_hf_cam.x + arc / _dem_hf_mpp
		var fy := _dem_hf_cam.y - lat / _dem_hf_mpp
		if fx >= 0.0 and fy >= 0.0 and fx < float(_dem_hf_w - 1) and fy < float(_dem_hf_h - 1):
			return _bilerp(_dem_hf, _dem_hf_w, _dem_hf_h, fx - 0.5, fy - 0.5) * dem_scale
	# outside the home DEM: try the secondary splice patches placed around the arc
	var pi := _patch_at(arc, lat)
	if pi >= 0:
		# streamed high-res tier wins for the patch you're standing in, matching the shader's order
		if pi == _hires_idx and _hires_res > 0:
			var rr := _patch_rects[pi]
			var circ: float = CIRCUMFERENCES[c_idx]
			var da: float = wrapf(arc - rr.x, -circ * 0.5, circ * 0.5)
			var hu: float = clampf(da / (2.0 * rr.z) + 0.5, 0.0, 0.999)
			var hv: float = clampf(0.5 - (lat - rr.y) / (2.0 * rr.w), 0.0, 0.999)
			return (_bilerp(_hires_field, _hires_res, _hires_res,
					hu * float(_hires_res) - 0.5, hv * float(_hires_res) - 0.5)
					+ _patch_offset[pi]) * dem_scale
		return _patch_height(pi, arc, lat)
	# no patch here: approximate procedural match to the shader's noise-heightmap fallback. Gaps are
	# unavoidable -- 3000km of arc, patches are 22-84km -- so most of the ring is this.
	return maxf(_noise.get_noise_2d(arc * 0.05, lat * 0.05), 0.0) * DISP

func _dem_sample(arc: float, lat: float) -> float:
	# full-res bilinear sample — used ONLY by the far band's decorative fallback (_far_terrain_h),
	# which is never walked on. -1 = outside coverage.
	var fx: float = float(_dem_cam.x) + arc / _dem_mpp
	var fy: float = float(_dem_cam.y) - lat / _dem_mpp
	if fx < 1.0 or fy < 1.0 or fx >= float(_dem_w) - 2.0 or fy >= float(_dem_h) - 2.0:
		return -1.0
	var x0 := int(fx); var y0 := int(fy)
	var tx: float = fx - float(x0); var ty: float = fy - float(y0)
	var h00 := float(_dem.decode_u16((y0 * _dem_w + x0) * 2)) / _dem_hscale
	var h10 := float(_dem.decode_u16((y0 * _dem_w + x0 + 1) * 2)) / _dem_hscale
	var h01 := float(_dem.decode_u16(((y0 + 1) * _dem_w + x0) * 2)) / _dem_hscale
	var h11 := float(_dem.decode_u16(((y0 + 1) * _dem_w + x0 + 1) * 2)) / _dem_hscale
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), ty)

func _far_terrain_h(arc: float, lat: float) -> float:
	# Height for the far band (everything beyond the CDLOD bubble, round to the antipodal point).
	# Consults the SAME splice patches the near terrain uses — without this the band baked
	# millstreet-or-noise for ~2870km of the 3000km ring, so the far side showed one repeated valley
	# no matter how many unique splices were placed.
	var pi := _patch_at(arc, lat)
	if pi >= 0:
		return _patch_height(pi, arc, lat)
	if _dem_w > 0:
		var dh: float = _dem_sample(arc, lat)
		if dh >= 0.0:
			return dh * dem_scale
	var h: float = maxf(_noise.get_noise_2d(arc, lat), 0.0) * NOISE_AMP
	var ridge_d: float = (arc - RIDGE_ARC) / 9_000.0
	h += RIDGE_AMP * exp(-ridge_d * ridge_d)
	return h

func _recompute_lod_ranges() -> void:
	_lod_range.clear()
	for l in MAX_LEVEL + 1:
		_lod_range.append(BASE_RANGE * pow(2.0, l))

func _build_unit_grid() -> ArrayMesh:
	# unit grid in [0,1] on X/Z (Y=0), plus a skirt ribbon around the perimeter whose bottom verts
	# are marked Y=-1 — the shader drops those below the terrain to hide residual hairline cracks.
	var verts: Array[Vector3] = []
	var idx: Array[int] = []
	for i in GRID + 1:
		for j in GRID + 1:
			verts.append(Vector3(float(i) / GRID, 0.0, float(j) / GRID))
	for i in GRID:
		for j in GRID:
			var a := i * (GRID + 1) + j
			var b := a + GRID + 1
			idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	var edges := [
		func(k: int) -> Vector3: return Vector3(float(k) / GRID, 0.0, 0.0),
		func(k: int) -> Vector3: return Vector3(float(k) / GRID, 0.0, 1.0),
		func(k: int) -> Vector3: return Vector3(0.0, 0.0, float(k) / GRID),
		func(k: int) -> Vector3: return Vector3(1.0, 0.0, float(k) / GRID),
	]
	for edge in edges:
		for k in GRID:
			var t0: Vector3 = edge.call(k)
			var t1: Vector3 = edge.call(k + 1)
			var base := verts.size()
			verts.append(t0)
			verts.append(t1)
			verts.append(Vector3(t0.x, -1.0, t0.z))
			verts.append(Vector3(t1.x, -1.0, t1.z))
			idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in verts:
		st.set_uv(Vector2(v.x, v.z))
		st.add_vertex(v)
	for i in idx:
		st.add_index(i)
	return st.commit()

func _select_lod(ox: float, oz: float, size: float, level: int) -> void:
	if _used >= POOL:
		return
	# entirely outside the playable ring width (+margin) -> never emit at all; the shader would sink
	# it out of sight anyway (behind the walls), so skip the whole subtree and save pool budget for
	# terrain that's actually visible.
	var half_w: float = WIDTHS[w_idx] * 0.5 + 500.0
	if oz + size < -half_w or oz > half_w:
		return
	if level > 0:
		# _cam_ring, NOT _cam.position. ox/oz are absolute ring coordinates (arc, lat) but
		# _cam.position is the BENT world position -- _ring_pos maps arc to r*sin(arc/R), so at arc
		# -1,485,690 the camera's world x is about -14,600. The two only agree near arc 0, which is
		# why this test passed at spawn and silently failed everywhere else: the distance came out
		# enormous, no node ever subdivided, and the whole ring away from home was drawn at 65km root
		# nodes. That is roughly 2km between vertices -- which is why the sea looked flat however
		# correct the swell was, and it is the same coordinate-space fault already logged against the
		# shader's cam_pos morph term.
		var nx := clampf(_cam_ring.x, ox, ox + size)
		var nz := clampf(_cam_ring.z, oz, oz + size)
		if _cam_ring.distance_to(Vector3(nx, 0.0, nz)) < _lod_range[level - 1]:
			var h := size * 0.5
			_select_lod(ox, oz, h, level - 1)
			_select_lod(ox + h, oz, h, level - 1)
			_select_lod(ox, oz + h, h, level - 1)
			_select_lod(ox + h, oz + h, h, level - 1)
			return
	_emit_lod(ox, oz, size, level)

func _emit_lod(ox: float, oz: float, size: float, level: int) -> void:
	var mi := _pool[_used]
	var mat := _mats[_used]
	var band_near: float = 0.0 if level == 0 else _lod_range[level - 1]
	var band_far: float = _lod_range[level]
	mat.set_shader_parameter("node_origin", Vector2(ox, oz))
	mat.set_shader_parameter("node_size", size)
	mat.set_shader_parameter("morph_start", lerpf(band_near, band_far, MORPH_LO))
	mat.set_shader_parameter("morph_end", lerpf(band_near, band_far, MORPH_HI))
	mat.set_shader_parameter("lod_tint", float(level) / float(MAX_LEVEL))
	mat.set_shader_parameter("show_lod", _show_lod)
	mat.set_shader_parameter("dem_scale", dem_scale)
	var r := _radius()
	var aabb := AABB(_surface_pos(ox, oz), Vector3.ZERO)
	for cx in [ox, ox + size]:
		for cz in [oz, oz + size]:
			aabb = aabb.expand(_ring_pos((cx) / r, cz, DISP))
			aabb = aabb.expand(_ring_pos((cx) / r, cz, -DISP - size * SKIRT))
	mi.custom_aabb = aabb.grow(size * 0.5)
	mi.visible = true
	_used += 1

func _rebuild_lod() -> void:
	_used = 0
	# The camera in RING space (arc, height above the floor, lat) -- the same coordinates the LOD
	# nodes and the shader's wxz are in. Everything that compares a camera position against terrain
	# coordinates must use this, not _cam.position; see the note in _select_lod.
	var rr := _radius()
	var axis_d := Vector2(_cam.position.x, rr - _cam.position.y).length()
	_cam_ring = Vector3(atan2(_cam.position.x, rr - _cam.position.y) * rr, rr - axis_d, _cam.position.z)
	var root_size: float = LEAF_SIZE * pow(2.0, MAX_LEVEL)
	var roots := int(ceil(TERRAIN_SIZE / root_size))
	var half := roots * root_size * 0.5
	# The bubble follows the camera. It used to be nailed to world origin, which meant the fine
	# terrain was a fixed 262km box around spawn and 32 of the 35 splices were never drawn at
	# anything better than band resolution -- the real reason buildings sank away from home.
	for gx in roots:
		for gz in roots:
			_select_lod(_lod_center_arc + gx * root_size - half, gz * root_size - half,
				root_size, MAX_LEVEL)
	for i in range(_used, _pool.size()):
		_pool[i].visible = false
	var r := _radius()
	var w: float = WIDTHS[w_idx]
	for i in _used:
		_mats[i].set_shader_parameter("cam_pos", _cam_ring)
		_mats[i].set_shader_parameter("wave_time", _wave_time)
		_mats[i].set_shader_parameter("wave_amp", wave_amp)
		_mats[i].set_shader_parameter("wave_center", _wave_center)
		_mats[i].set_shader_parameter("ring_radius", r)
		_mats[i].set_shader_parameter("ring_width", w)
		_mats[i].set_shader_parameter("wall_top", wall_top_h)
		_mats[i].set_shader_parameter("wall_shadow_soft", _wall_shadow_soft)

func _rebuild() -> void:
	_lod_center_arc = _snap_lod_center()
	_build_band(_lod_center_arc)
	_build_walls()
	_report_tex_support()
	_make_dust()
	_load_grass()
	# `-- --tex s3tc|bptc` picks a mode at launch, so all three can be measured without a human
	# holding [U] down and reading a HUD
	var _ua := OS.get_cmdline_user_args()
	var _ti := _ua.find("--tex")
	if _ti >= 0 and _ti + 1 < _ua.size():
		match _ua[_ti + 1]:
			"s3tc": _tex_mode = TexMode.S3TC
			"bptc": _tex_mode = TexMode.BPTC
	var _ri := _ua.find("--texres")
	if _ri >= 0 and _ri + 1 < _ua.size():
		hires_tex_res = int(_ua[_ri + 1])
	_load_roadlines()   # before the scatter: that is what builds the ribbon
	_scatter_trees()
	_load_buildings()
	_populate_warp_panel()
	_update_hud()

func _snap_lod_center() -> float:
	# Snapped to a whole root so the LOD grid does not swim under the camera as you move; the band
	# only needs rebuilding when this value actually changes, i.e. every root_size of travel.
	if _cam == null:
		return 0.0
	var r := _radius()
	var root_size: float = LEAF_SIZE * pow(2.0, MAX_LEVEL)
	var cam_arc: float = atan2(_cam.position.x, r - _cam.position.y) * r
	return floor(cam_arc / root_size) * root_size

func _build_band(center_arc: float) -> void:
	# Far band: the ring BEYOND the CDLOD bubble. It reads the same splice patches the near terrain
	# does (see _far_terrain_h) but at BAND_SEGS resolution -- ~1km along the arc and ~3km across
	# the width -- so it is a backdrop, not a surface to stand on. Anything placed from _terrain_h
	# (which resolves 190m or better) sits on relief the band simply does not have, which is why
	# buildings buried themselves in valleys everywhere except inside the bubble.
	#
	# The hole in this band is where the CDLOD terrain goes, so it has to follow the camera too.
	var t0 := Time.get_ticks_msec()
	if _band:
		_band.queue_free()
		_band = null
	var w: float = WIDTHS[w_idx]
	var r: float = _radius()
	var seam: float = (TERRAIN_SIZE * 0.5) / r
	var c_theta: float = center_arc / r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in BAND_SEGS + 1:
		var theta: float = c_theta + lerpf(seam, TAU - seam, float(i) / float(BAND_SEGS))
		var arc: float = theta * r
		for j in BAND_ROWS + 1:
			var lat: float = w * (float(j) / float(BAND_ROWS) - 0.5)
			st.set_uv(Vector2(arc, lat))
			st.add_vertex(_ring_pos(theta, lat, _far_terrain_h(arc, lat)))
	_grid_indices(st, BAND_SEGS, BAND_ROWS)
	st.generate_normals()
	_band = MeshInstance3D.new()
	_band.mesh = st.commit()
	_band.material_override = _mat
	_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_band)
	print("ring_vibes: far band rebuilt around arc %.0f km (%d ms)"
		% [center_arc / 1000.0, Time.get_ticks_msec() - t0])

const WALL_BASE_H := -200.0   # absolute height (below lowest terrain), from ring centre — not terrain-relative
var wall_top_h := 1500.0       # rim height toward the axis; live-tunable ([O]) since it sets shadow reach
# The ceiling the AIR reaches, independent of how tall the masonry is (see the SPACE_LO_FRAC note).
# NOT SETTLED -- 4000 sits in the 2-5km range the ceiling was described as wanting, but the number is
# a judgement to make by flying to it, not by reasoning about it.
var atmo_top_h := 4000.0

func _build_walls() -> void:
	# rim walls: continuous around the WHOLE ring (like the band), at ABSOLUTE heights from
	# centre — a fixed rim structure, not following the terrain and not just the local region.
	for m in _walls:
		m.queue_free()
	_walls.clear()
	var w: float = WIDTHS[w_idx]
	var segs := 512   # full ring, uniform (no terrain sampling) so this can be coarse + cheap
	for side in [-1.0, 1.0]:
		var lat: float = side * w * 0.5
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in segs + 1:
			var theta: float = TAU * float(i) / float(segs)
			st.set_uv(Vector2(float(i) / float(segs) * 40.0, 1.0))
			st.add_vertex(_ring_pos(theta, lat, WALL_BASE_H))
			st.set_uv(Vector2(float(i) / float(segs) * 40.0, 0.0))
			st.add_vertex(_ring_pos(theta, lat, wall_top_h))
		for i in segs:
			var a := i * 2
			st.add_index(a); st.add_index(a + 2); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(a + 2); st.add_index(a + 3)
		st.generate_normals()
		# CONTAINMENT FIELD: the span the masonry does not reach, carried up to the atmosphere ceiling.
		# Same rim, same segment count, just the strip above the wall -- and skipped entirely when the
		# wall is already tall enough to contain the air on its own.
		if atmo_top_h > wall_top_h + 1.0:
			var fst := SurfaceTool.new()
			fst.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in segs + 1:
				var ft: float = TAU * float(i) / float(segs)
				fst.set_uv(Vector2(float(i) / float(segs) * 40.0, 0.0))
				fst.add_vertex(_ring_pos(ft, lat, wall_top_h))
				fst.set_uv(Vector2(float(i) / float(segs) * 40.0, 1.0))
				fst.add_vertex(_ring_pos(ft, lat, atmo_top_h))
			for i in segs:
				var fa := i * 2
				fst.add_index(fa); fst.add_index(fa + 2); fst.add_index(fa + 1)
				fst.add_index(fa + 1); fst.add_index(fa + 2); fst.add_index(fa + 3)
			fst.generate_normals()
			var fmi := MeshInstance3D.new()
			fmi.mesh = fst.commit()
			if not _field_mat:
				_field_mat = ShaderMaterial.new()
				_field_mat.shader = load("res://mocks/ring_vibes_field.gdshader") as Shader
			fmi.material_override = _field_mat
			fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(fmi)
			_walls.append(fmi)   # tracked with the walls so a rebuild frees it too
			print("ring_vibes: containment field %.0f-%.0fm on lat %.0f" % [wall_top_h, atmo_top_h, lat])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		if not _wall_mat:
			_wall_mat = ShaderMaterial.new()
			_wall_mat.shader = load("res://mocks/ring_vibes_wall.gdshader") as Shader
		mi.material_override = _wall_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_walls.append(mi)
	# Axis-structure docking port (TASKS.md "Docking / boarding"). A fixed beacon at (DOCK_ARC, DOCK_LAT)
	# reaching toward the axis -- authored directly, NOT derived from ring-surface tiling (substrate.md gate 5).
	# Something to aim for; the dock MECHANIC keys off ring coordinates (_dock_update), NOT this mesh, so a
	# mispositioned marker can only make the target harder to see, never break docking. A cube so orientation
	# can't be wrong. Tracked with the walls so a rebuild (which changes _radius()) frees and re-places it.
	# Rendering NOT eyeballed here (Godot binary is out-of-repo/gated), same caveat as the wall/field.
	# A 60m emissive CUBE was the first pass, and from the approach it read as exactly that: a flat
	# cyan rectangle pasted on the sky, the same failure as the tree billboards. A docking port is the
	# one piece of builders' architecture the player ever gets close to, so it has to read as built:
	# a spine along the approach axis, a docking collar you aim INTO, and radial struts that give the
	# eye something to judge range and roll against. Still placeholder geometry, but dimensional --
	# roughly 300 triangles, authored directly per substrate.md gate 5.
	var port := Node3D.new()
	add_child(port)
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.30, 0.33, 0.38)
	hull.metallic = 0.6
	hull.roughness = 0.45
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(0.20, 0.55, 0.75)
	lamp.emission_enabled = true
	lamp.emission = Color(0.5, 0.9, 1.0)
	lamp.emission_energy_multiplier = 1.1   # 3.0 blew the panels to flat white against black sky
	# spine: the structure continues toward the axis, so it reads as the bottom of something much larger
	var spine := MeshInstance3D.new()
	var sbm := BoxMesh.new()
	sbm.size = Vector3(26.0, 320.0, 26.0)
	spine.mesh = sbm
	spine.material_override = hull
	# the collar is the capture point, so the spine runs UP from it toward the axis rather than
	# straddling it -- otherwise you soft-capture into the middle of a girder
	spine.position = Vector3(0.0, 172.0, 0.0)
	port.add_child(spine)
	# collar: eight segments around the approach axis -- the ring you fly into, and the thing that
	# makes roll and range legible at a glance
	for i in 8:
		var a := TAU * float(i) / 8.0
		var seg := MeshInstance3D.new()
		var cbm := BoxMesh.new()
		cbm.size = Vector3(34.0, 12.0, 12.0)
		seg.mesh = cbm
		seg.material_override = hull if i % 2 == 0 else lamp
		seg.position = Vector3(sin(a) * 62.0, 0.0, cos(a) * 62.0)
		seg.rotation.y = -a
		port.add_child(seg)
		# strut back to the spine
		var strut := MeshInstance3D.new()
		var tbm := BoxMesh.new()
		tbm.size = Vector3(52.0, 5.0, 5.0)
		strut.mesh = tbm
		strut.material_override = hull
		strut.position = Vector3(sin(a) * 34.0, 0.0, cos(a) * 34.0)
		strut.rotation.y = -a
		port.add_child(strut)
	# Orient the spine along RING UP (toward the axis), not world up. They coincide at DOCK_ARC 0 and
	# nowhere else, so building the basis properly means moving the port later is a constant change
	# rather than a bug. Basis() takes COLUMNS.
	var ppos := _ring_pos(DOCK_ARC / _radius(), DOCK_LAT, DOCK_ALT)
	var pup := _ring_up(ppos)
	var pright := pup.cross(Vector3(0.0, 0.0, 1.0)).normalized()
	port.global_transform = Transform3D(Basis(pright, pup, pright.cross(pup)), ppos)
	_walls.append(port)

func _grid_indices(st: SurfaceTool, segs: int, rows: int) -> void:
	# 2026-07-23: attempted a winding flip + cull_back here, got the direction wrong (rendered
	# almost nothing). Reverted to the original order + cull_disabled (double-sided, known-working)
	# rather than guess again. Walk mode (ground-snapped) is the real fix for "finding the floor."
	for i in segs:
		for j in rows:
			var a: int = i * (rows + 1) + j
			var b: int = a + rows + 1
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)

func _process(delta: float) -> void:
	# Advance the swell and park its bubble on the camera, in ABSOLUTE ring arc -- the same
	# coordinate _wave_h takes, so the CPU twin and the shader agree about where the waves are.
	if _cam != null:
		_wave_time += delta
		var wr := _radius()
		_wave_center = Vector2(atan2(_cam.position.x, wr - _cam.position.y) * wr, _cam.position.z)
	var period: float = SUN_PERIODS[sun_speed_idx]
	if period > 0.0 and not sun_paused:
		sun_angle = fmod(sun_angle + TAU * delta / period, TAU)
	var to_sun := Vector3(sin(sun_angle), cos(sun_angle) * cos(sun_tilt), cos(sun_angle) * sin(sun_tilt))
	# day/night is only "to_sun.y" as a global scalar when the camera sits near arc=0 (spawn) --
	# the terrain's OWN lighting (and the ring-in-sky element) correctly varies by arc position via
	# dot(normal(theta), to_sun), which is what makes the far side of the ring show a genuinely
	# different day/night state than where you're standing (real ringworld physics -- your night,
	# their day). The sky background/ambient/sun-energy were still using the theta=0 special case
	# unconditionally, so as soon as 5x fly-boost lets you actually travel far, they'd report
	# "day here" while the visible terrain/ring correctly showed night, or vice versa -- exactly the
	# "almost the opposite" mismatch found by flying far. Computing the camera's own current theta
	# and evaluating the SAME formula there keeps everything consistent regardless of position.
	var r_now := _radius()
	var cam_theta := atan2(_cam.global_position.x, r_now - _cam.global_position.y)
	var local_lit := clampf(-sin(cam_theta) * to_sun.x + cos(cam_theta) * to_sun.y, 0.0, 1.0)
	var sun_theta := atan2(-to_sun.x, to_sun.y)   # arc position most face-on to the sun; mirrors ring_sky.gdshader
	_dbg_cam_theta_deg = rad_to_deg(cam_theta)
	_dbg_sun_theta_deg = rad_to_deg(sun_theta)
	_dbg_local_lit = local_lit
	# the raw cosine curve spent most of its "day half" ramping through a dim dusk-like value and
	# only briefly touched full brightness near the very peak -- it LOOKED like night was ~50% of
	# the cycle but day was mostly a fast dim transition, not a comparable bright half. Remapping
	# widens the plateau: day reaches 1.0 well before the sun nears its max height, and holds there.
	var day: float = smoothstep(0.0, 0.35, local_lit)
	_dbg_day = day
	if _clouds:
		_clouds.set_day(day, to_sun)
		_clouds.update_around(_cam.global_position)
		# weather follows the biome you're over, eased in (see ring_clouds.WEATHER_BLEND) -- checked
		# on the same cheap cadence as the forest, not every frame
		if _tree_cd <= 0.0:
			_clouds.transition_to(_biome_at(cam_theta * r_now, _cam.global_position.z)["weather"])
	# altitude above the ring surface, toward the axis
	var cam_alt: float = r_now - Vector2(_cam.position.x, r_now - _cam.position.y).length()
	_space = smoothstep(_space_lo(), _space_hi(), cam_alt)
	var eff_haze: float = (0.0 if _haze_off else haze_density) * (1.0 - _space)
	_mat.set_shader_parameter("to_sun", to_sun)
	_mat.set_shader_parameter("haze_density", eff_haze)
	_mat.set_shader_parameter("ring_width", WIDTHS[w_idx])
	_mat.set_shader_parameter("wall_ramp", WALL_RAMP)
	if _sun:
		# full 3D direction now that SUN_TILT gives to_sun a Z component (the old X-only rotation
		# derived from to_sun.y alone would ignore the tilt, leaving tree/car lighting out of sync
		# with the terrain/sky, which both use the full to_sun vector directly).
		_sun.global_transform.basis = Basis.looking_at(-to_sun.normalized(), Vector3.UP)
		_sun.light_energy = day * 1.3
		_sun.light_color = Color(1.0, 0.95, 0.86)
	if _wall_mat:
		_wall_mat.set_shader_parameter("to_sun", to_sun)
		_wall_mat.set_shader_parameter("haze_density", eff_haze)
	# camera-local day factor drives the sky + fog-blend colour -- fog fades toward the HORIZON
	# colour (not zenith), matching what the real sky shader shows near the ground far away.
	var sky := DAY_HORIZON.lerp(NIGHT_HORIZON, 1.0 - day)
	# in vacuum there is no scattering, so no blue and no skylight -- just the sun and the stars
	var vac := Color(0.006, 0.008, 0.014)
	var dz := DAY_ZENITH.lerp(vac, _space)
	var dh := DAY_HORIZON.lerp(vac, _space)
	var nz := NIGHT_ZENITH.lerp(vac, _space)
	var nh := NIGHT_HORIZON.lerp(vac, _space)
	sky = sky.lerp(vac, _space)
	_sky_mat.set_shader_parameter("star_day_visibility", lerpf(0.4, 1.0, _space))
	_sky_mat.set_shader_parameter("star_rot", sun_angle)
	# the sun sweeps the plane spanned by (1,0,0) and (0,cos t,sin t); their cross product is
	# its rotation axis, so the stars must turn about that same axis rather than about Z
	_sky_mat.set_shader_parameter("star_axis",
		Vector3(0.0, -sin(sun_tilt), cos(sun_tilt)).normalized())
	if _env:
		_env.ambient_light_energy = lerpf(0.4, 0.04, _space)
	_sky_mat.set_shader_parameter("to_sun", to_sun)
	_sky_mat.set_shader_parameter("day", day)
	_sky_mat.set_shader_parameter("day_zenith", Vector3(dz.r, dz.g, dz.b))
	_sky_mat.set_shader_parameter("day_horizon", Vector3(dh.r, dh.g, dh.b))
	_sky_mat.set_shader_parameter("night_zenith", Vector3(nz.r, nz.g, nz.b))
	_sky_mat.set_shader_parameter("night_horizon", Vector3(nh.r, nh.g, nh.b))
	# ambient was fixed-intensity regardless of day/night — trees/car/creatures (engine-lit) stayed
	# bright at "night" off ambient alone while the manually-lit terrain correctly went near-black.
	# Scale it down at night so everything dims together. Max raised (0.4 -> 0.65) -- daytime overall
	# read as "way too dark".
	_env.ambient_light_energy = lerpf(0.12, 0.8, day)
	_mat.set_shader_parameter("sky_color", Vector3(sky.r, sky.g, sky.b))
	if _wall_mat:
		_wall_mat.set_shader_parameter("sky_color", Vector3(sky.r, sky.g, sky.b))
	for i in _used:
		_mats[i].set_shader_parameter("to_sun", to_sun)
		_mats[i].set_shader_parameter("haze_density", eff_haze)
		_mats[i].set_shader_parameter("sky_color", Vector3(sky.r, sky.g, sky.b))
	match _mode:
		Mode.DRIVE: _drive_tick(delta)
		Mode.WALK: _walk_tick(delta)
		_: _fly(delta)
	_shots_tick(delta)   # rounds in flight, and the action cycling/reloading
	_rebuild_lod()
	_hires_poll()
	# forest follows the camera around the ring, re-scattering with the local biome when you've
	# travelled far enough that the old patch of woodland is behind you -- throttled hard, see
	# TREE_RESCATTER_CD.
	_cam_speed = _cam.global_position.distance_to(_cam_prev_pos) / maxf(delta, 0.0001)
	_cam_prev_pos = _cam.global_position
	_tree_cd = maxf(_tree_cd - delta, 0.0)
	var cam_arc := cam_theta * r_now
	if (_tree_cd <= 0.0 and _cam_speed < TREE_RESCATTER_MAX_SPEED
			and Vector2(cam_arc, _cam.global_position.z).distance_to(_tree_center) > TREE_RESCATTER):
		_tree_center = Vector2(cam_arc, _cam.global_position.z)
		_scatter_trees()
		_tree_cd = TREE_RESCATTER_CD
	_update_tree_lod()
	_refill_buildings()
	_scatter_grass()
	_perf_t -= delta
	if _perf != null and _perf_t <= 0.0:
		_perf_t = 0.25
		var tris := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		_perf.text = "%d fps
%s tris
%d draws" % [
			int(round(Engine.get_frames_per_second())),
			("%.2fM" % (float(tris) / 1_000_000.0)) if tris > 1_000_000 else ("%dk" % (tris / 1000)),
			draws]
	# the band carries a hole where the CDLOD bubble sits, so it has to be rebuilt whenever the
	# bubble moves to a new root. ~51k vertices of _far_terrain_h, so only on an actual change.
	# ...but it costs ~430ms, and a root is only 65km, which at 20x fly speed is under a second.
	# Same treatment as the tree re-scatter: defer while travelling fast and catch up on slowing
	# down. The band is a backdrop; you cannot judge it at 80 km/s anyway.
	_band_cd = maxf(_band_cd - delta, 0.0)
	var want := _snap_lod_center()
	if (not is_equal_approx(want, _lod_center_arc)
		and _band_cd <= 0.0 and _cam_speed < BAND_REBUILD_MAX_SPEED):
		_lod_center_arc = want
		_build_band(want)
		_band_cd = 1.5
	_update_hud()

# ---------------------------------------------------------------------------
# Object-LOD trees (ported from object-lod branch)
# ---------------------------------------------------------------------------

func _rel_xform(node: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

func _prep_material(mat: Material) -> Material:
	# foliage/billboard surfaces -> the soft wrapped-lighting foliage shader (kills the blown-out
	# up-facing billboard cap). Bark keeps its opaque StandardMaterial (real shape/shading).
	if mat is BaseMaterial3D:
		var nm := mat.resource_name.to_lower()
		if "brunch" in nm or "branch" in nm or "billboard" in nm or "leaf" in nm or "leaves" in nm or "needle" in nm:
			var tex: Texture2D = (mat as BaseMaterial3D).albedo_texture
			if tex and _foliage_shader:
				var sm := ShaderMaterial.new()
				sm.shader = _foliage_shader
				sm.set_shader_parameter("tex", tex)
				return sm
			var m := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			if m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			return m
	return mat

func _append_surfaces(out: ArrayMesh, src: Mesh, xf: Transform3D) -> void:
	for s in src.get_surface_count():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(src, s, xf)
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, _prep_material(src.surface_get_material(s)))

func _rebake(out: ArrayMesh, src: Mesh, xf: Transform3D) -> void:
	for s in src.get_surface_count():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(src, s, xf)
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))

func _billboard_from(src: Mesh) -> ArrayMesh:
	# two crossed quads, unit height, origin at the base -- 4 triangles against the pack's ~16, and
	# it inherits the source material so it still reads as the same tree at distance.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.34
	for pair in [[Vector3(-w, 0, 0), Vector3(w, 0, 0)], [Vector3(0, 0, -w), Vector3(0, 0, w)]]:
		var a: Vector3 = pair[0]
		var b: Vector3 = pair[1]
		var at := a + Vector3(0, 1, 0)
		var bt := b + Vector3(0, 1, 0)
		st.set_uv(Vector2(0, 1)); st.add_vertex(a)
		st.set_uv(Vector2(0, 0)); st.add_vertex(at)
		st.set_uv(Vector2(1, 1)); st.add_vertex(b)
		st.set_uv(Vector2(1, 1)); st.add_vertex(b)
		st.set_uv(Vector2(0, 0)); st.add_vertex(at)
		st.set_uv(Vector2(1, 0)); st.add_vertex(bt)
	st.generate_normals()
	var m := st.commit()
	var sm := src.surface_get_material(0)
	if sm != null:
		m.surface_set_material(0, sm)
	return m

func _normalize_mesh(src: ArrayMesh) -> ArrayMesh:
	# scale each LOD independently to unit height, base at y=0, centred on X/Z — so all LODs of a
	# tree render the SAME size regardless of their intrinsic mesh scale (fixes LOD0-too-small /
	# position-jump-on-switch bugs found in the object-lod mock).
	if src == null: return null
	var ab := src.get_aabb()
	var s := 1.0 / maxf(ab.size.y, 0.001)
	var pivot := Vector3(ab.position.x + ab.size.x * 0.5, ab.position.y, ab.position.z + ab.size.z * 0.5)
	var xf := Transform3D(Basis().scaled(Vector3(s, s, s)), -pivot * s)
	var out := ArrayMesh.new()
	_rebake(out, src, xf)
	return out

func _walk_lod_meshes(node: Node, root: Node, re: RegEx, by_variant: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh:
		var m := re.search(node.name)
		if m:
			var vname := m.get_string(1)
			var lod := int(m.get_string(2))
			if lod < TREE_LODS:
				if not by_variant.has(vname): by_variant[vname] = {}
				if not by_variant[vname].has(lod): by_variant[vname][lod] = ArrayMesh.new()
				_append_surfaces(by_variant[vname][lod], node.mesh, _rel_xform(node, root))
	for c in node.get_children():
		_walk_lod_meshes(c, root, re, by_variant)

func _load_tree_lods() -> bool:
	# parse the fir pack: node names like "Christmas tree_2_LOD1_Bark_Mat_0" -> variant + LOD level.
	# Build one combined mesh per (variant, LOD), and one MultiMeshInstance3D per (variant, LOD).
	if not ResourceLoader.exists(TREE_PACK):
		print("ring_vibes: tree pack not found ", TREE_PACK)
		return false
	var packed := load(TREE_PACK) as PackedScene
	if not packed: return false
	_foliage_shader = load("res://mocks/tree_foliage.gdshader") as Shader
	var inst := packed.instantiate()
	var re := RegEx.new()
	re.compile("(?i)^(.+?)_LOD(\\d)")
	var by_variant := {}
	_walk_lod_meshes(inst, inst, re, by_variant)
	inst.queue_free()
	if by_variant.is_empty():
		print("ring_vibes: no LOD meshes parsed from tree pack")
		return false
	var vnames := by_variant.keys()
	vnames.sort()
	_tree_nvar = vnames.size()
	_tree_meshes = []
	for vi in _tree_nvar:
		var lods := []
		for l in TREE_LODS:
			lods.append(_normalize_mesh(by_variant[vnames[vi]].get(l, null)))
		# THE PACK'S OWN FAR LOD IS NOT CHEAP. Measured: trees are 71% of the frame's triangles
		# and 24,019 of 24,037 are already in this tier, so its mesh costs ~16 triangles, not the
		# 2 a billboard implies. An artist LOD chain bottoms out at "very simple mesh"; it does not
		# bottom out at a quad. Replace the last rung with a real crossed billboard carrying the
		# same foliage material, which is what the tier was always meant to be.
		var far: Mesh = lods[TREE_LODS - 1]
		if far != null and far.get_surface_count() > 0:
			lods[TREE_LODS - 1] = _billboard_from(far)
		_tree_meshes.append(lods)
	_tree_scale = TREE_H   # meshes normalized to unit height, so per-tree scale == world height
	_tree_mm = []
	for vi in _tree_nvar:
		var mms := []
		for l in TREE_LODS:
			var m: Mesh = _tree_meshes[vi][l]
			if m == null:
				mms.append(null); continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = m
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			mms.append(mmi)
		_tree_mm.append(mms)
	print("ring_vibes: tree pack — %d variants x %d LODs loaded" % [_tree_nvar, TREE_LODS])
	return true

func _road_at(arc: float, lat: float) -> float:
	# Same mapping the shader uses for road_tex: normalised over the home DEM extent, since that is
	# the bbox fetch_osm_roads.py rasterised into. Returns 0 outside the home patch -- the other 34
	# splices have no road data yet (deferred: Overpass rate limits).
	if _road_mask.is_empty() or _dem_hf_w == 0:
		return 0.0
	var u := (_dem_hf_cam.x + arc / _dem_hf_mpp) / float(_dem_hf_w)
	var v := (_dem_hf_cam.y - lat / _dem_hf_mpp) / float(_dem_hf_h)
	if u < 0.0 or u >= 1.0 or v < 0.0 or v >= 1.0:
		return 0.0
	# bilinear, like the shader. Nearest quantised the mask to 44m cells, so the on/off road
	# decision stepped in blocks and the hedgerow inherited those steps.
	var fx: float = u * float(ROAD_RES) - 0.5
	var fy: float = v * float(ROAD_RES) - 0.5
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var x1 := clampi(x0 + 1, 0, ROAD_RES - 1)
	var y1 := clampi(y0 + 1, 0, ROAD_RES - 1)
	x0 = clampi(x0, 0, ROAD_RES - 1)
	y0 = clampi(y0, 0, ROAD_RES - 1)
	var h0 := lerpf(float(_road_mask[y0 * ROAD_RES + x0]), float(_road_mask[y0 * ROAD_RES + x1]), tx)
	var h1 := lerpf(float(_road_mask[y1 * ROAD_RES + x0]), float(_road_mask[y1 * ROAD_RES + x1]), tx)
	return lerpf(h0, h1, ty) / 255.0

func _hedge_texture() -> ImageTexture:
	# Generated rather than authored: a hedge at driving distance is a texture of small dark gaps and
	# lit leaf clumps, which is two octaves of noise and a vertical bias. Cheap, and it means no new
	# art dependency for a mock.
	var res := 256
	var img := Image.create(res, res, false, Image.FORMAT_RGB8)
	var leaf := FastNoiseLite.new()
	leaf.noise_type = FastNoiseLite.TYPE_SIMPLEX
	leaf.frequency = 0.10
	var fine := FastNoiseLite.new()
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fine.frequency = 0.42
	var twig := FastNoiseLite.new()
	twig.noise_type = FastNoiseLite.TYPE_SIMPLEX
	twig.frequency = 0.03
	for y in res:
		for x in res:
			var c := leaf.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var f := fine.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			# vertical streaks: growth runs upward, and it stops the tiling reading as a blob field
			var t := twig.get_noise_2d(float(x) * 4.0, float(y) * 0.35) * 0.5 + 0.5
			var v: float = clampf(0.30 + c * 0.55 + f * 0.22 - t * 0.20, 0.0, 1.0)
			# darker toward the base of the tile: light does not reach into a hedge
			v *= lerpf(0.55, 1.0, float(y) / float(res))
			img.set_pixel(x, y, Color(0.10 + v * 0.22, 0.17 + v * 0.42, 0.07 + v * 0.16))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _report_tex_support() -> void:
	# asked, not assumed -- this targets the Compatibility renderer on Intel integrated, where a
	# missing format means Godot silently decompresses on the CPU and the saving evaporates
	print("ring_vibes: texture compression — s3tc %s, bptc %s, etc2 %s" % [
		RenderingServer.has_os_feature("s3tc"), RenderingServer.has_os_feature("bptc"),
		RenderingServer.has_os_feature("etc2")])


# ---------------------------------------------------------------------------
# Close-range ground cover. The satellite drape is ~11 m/px at best, so the ground under the car has
# no detail of its own -- the noise overlay breaks the colour up but nothing has SHAPE. Grass gives
# the near field something with parallax, which is most of what sells speed when driving.
# Deliberately tiny radius: this is a motion cue, not scenery, and the frame budget is already tight.
# ---------------------------------------------------------------------------
const GRASS_PACK := "res://grass_pack_of_9_vars_lowpoly_game_ready/scene.gltf"
const GRASS_RADIUS := 42.0        # metres; beyond this the drape carries it
const GRASS_MAX := 3000           # hard instance cap
const GRASS_STEP := 1.6           # scatter spacing, metres
var _grass_mm: MultiMeshInstance3D = null
var _grass_centre := Vector2(1e12, 1e12)

func _load_grass() -> bool:
	if not ResourceLoader.exists(GRASS_PACK):
		print("ring_vibes: grass pack not found, skipping ground cover")
		return false
	var packed := load(GRASS_PACK) as PackedScene
	if packed == null:
		return false
	var inst := packed.instantiate()
	# take the first mesh in the pack -- the 9 variants share one atlas, and at this size and
	# distance the difference between them is well below a pixel
	var found: Mesh = null
	var stack: Array = [inst]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and found == null:
			found = (n as MeshInstance3D).mesh
		for c in n.get_children():
			stack.append(c)
	inst.queue_free()
	if found == null:
		print("ring_vibes: no mesh in the grass pack")
		return false
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = found
	_grass_mm = MultiMeshInstance3D.new()
	_grass_mm.multimesh = mm
	_grass_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a 42m bubble that follows the camera has no business being frustum-culled against its own
	# origin, and the AABB is otherwise computed from instance 0 alone
	_grass_mm.custom_aabb = AABB(Vector3(-GRASS_RADIUS, -80, -GRASS_RADIUS),
		Vector3(GRASS_RADIUS * 2, 160, GRASS_RADIUS * 2))
	add_child(_grass_mm)
	print("ring_vibes: grass pack loaded (%d surfaces)" % found.get_surface_count())
	return true

func _scatter_grass(force := false) -> void:
	if _grass_mm == null:
		return
	var cam := _cam.global_position
	var r := _radius()
	var here := Vector2(atan2(cam.x, r - cam.y) * r, cam.z)
	if not force and here.distance_to(_grass_centre) < GRASS_RADIUS * 0.35:
		return
	_grass_centre = here
	var bio := _biome_at(here.x, here.y)
	# grass follows the same biome signal as trees: bare ground stays bare. Scaled up a little at
	# low tree density, because open grassland has MORE grass than woodland floor, not less.
	var dens: float = clampf(0.35 + float(bio.get("trees", 0.5)) * 0.5, 0.0, 1.0)
	var fol: Color = bio.get("foliage", Color(1, 1, 1))
	var xfs: Array = []
	var cols: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(here.x) * 7919 + int(here.y)
	var a := -GRASS_RADIUS
	while a <= GRASS_RADIUS and xfs.size() < GRASS_MAX:
		var l := -GRASS_RADIUS
		while l <= GRASS_RADIUS and xfs.size() < GRASS_MAX:
			if rng.randf() < dens:
				var px := here.x + a + rng.randf_range(-0.8, 0.8)
				var pz := here.y + l + rng.randf_range(-0.8, 0.8)
				if Vector2(px - here.x, pz - here.y).length() <= GRASS_RADIUS:
					var h := _terrain_h(px, pz)
					# not in the sea, and not on the carriageway
					# NOT the road mask: that is 44m per cell against a 42m grass radius, so it rejects
					# everything -- the identical resolution mistake the hedge junction test just made.
					if h > SEA_LEVEL + 0.5 and not _road_cells.has(
						Vector2i(int(floor(px / 8.0)), int(floor(pz / 8.0)))):
						var g := _surface_pos(px, pz)
						var up := _ring_up(g)
						var ax := up.cross(Vector3.FORWARD).normalized()
						if ax.length_squared() < 0.25:
							ax = up.cross(Vector3.RIGHT).normalized()
						var az := ax.cross(up).normalized()
						var yaw := rng.randf() * TAU
						# the pack's clumps are authored small -- at 0.5-1.1 they were 5cm specks on the ground,
						# invisible from a car. Roadside grass wants to be 40-90cm to read at all.
						var sc := rng.randf_range(3.0, 6.5)
						xfs.append(Transform3D(Basis(
							(ax * cos(yaw) + az * sin(yaw)) * sc, up * sc,
							(az * cos(yaw) - ax * sin(yaw)) * sc), g))
						var t := rng.randf_range(0.75, 1.15)
						cols.append(Color(fol.r * t, fol.g * t, fol.b * t))
			l += GRASS_STEP
		a += GRASS_STEP
	var mm := _grass_mm.multimesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cols[i])
	_grass_shown = xfs.size()
	if force:
		print("ring_vibes: %d grass instances in a %.0fm bubble" % [_grass_shown, GRASS_RADIUS])

func _load_roadline_file(name: String, arc_off: float, lat_off: float) -> int:
	var path := "res://mocks/dem/%s_roadlines.dat" % name
	if not FileAccess.file_exists(path):
		return 0
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 8 or b.decode_u8(0) != 0x52 or b.decode_u8(1) != 0x44:   # "RD"
		return 0
	var circ: float = CIRCUMFERENCES[c_idx]
	var n := int(b.decode_u32(4))
	var o := 8
	var added := 0
	for i in n:
		if o + 4 > b.size():
			break
		var wdt := int(b.decode_u16(o))
		var cnt := int(b.decode_u16(o + 2))
		o += 4
		var pts := PackedVector2Array()
		for k in cnt:
			if o + 8 > b.size():
				break
			pts.append(Vector2(fposmod(b.decode_float(o) + arc_off, circ),
				b.decode_float(o + 4) + lat_off))
			o += 8
		if pts.size() > 1:
			_roadlines.append({"w": wdt, "pts": pts})
			added += 1
	return added

func _load_roadlines() -> void:
	# Road CENTRELINES for the home patch AND the patch you are standing in. The mask stays the right
	# tool for the drape; a hedgerow is a ribbon along a line, and scattering objects over a blurred
	# bitmap to reconstruct that line gives a dotted row of separate bushes.
	#
	# Two patches, not all 27: 250k points each, and _road_cells would hold millions of entries for
	# ground nobody is within 100km of. Reloaded when the streamed patch changes, on the same trigger
	# as the drape, so the roadside furniture follows you the way everything else already does.
	_roadlines = []
	var total := 0
	if _dem_w > 0:
		var ax := (float(_dem_w) * 0.5 - float(_dem_cam.x)) * _dem_mpp
		var lx := (float(_dem_cam.y) - float(_dem_h) * 0.5) * _dem_mpp
		total += _load_roadline_file(DEM_R16.get_file().get_basename(), ax, lx)
	if _roadline_patch >= 0 and _roadline_patch < _patch_names.size():
		var r: Vector4 = _patch_rects[_roadline_patch]
		total += _load_roadline_file(str(_patch_names[_roadline_patch]), r.x, r.y)
	print("ring_vibes: %d road centrelines loaded (home + %s)" % [
		total, _patch_names[_roadline_patch] if _roadline_patch >= 0 else "none"])
	_build_junctions()

func _build_junctions() -> void:
	# Mark where roads MEET, once, from the centrelines. Hash every point into 30m cells and record
	# which way owns it; a cell holding points from more than one way is a junction. Done at load
	# because the ribbon rebuilds every few hundred metres and this must not be paid per rebuild.
	_junc = {}
	_road_cells = {}
	var owner := {}
	for wi in _roadlines.size():
		var pts: PackedVector2Array = _roadlines[wi]["pts"]
		# WALK THE SEGMENTS, not just the nodes. OSM only puts a node where a road changes
		# direction, so a straight run can be 200m between points -- marking nodes alone left
		# the road between them unmarked, and grass grew down the middle of the carriageway.
		for i in pts.size() - 1:
			var seg := pts[i + 1] - pts[i]
			# A segment longer than any real road span is the arc seam: two consecutive points that
			# wrapped to opposite ends of the ring. Walking that at 5m is 600,000 cells for one
			# segment, which is how the cell count hit 26,976,535 for a patch with 8,450km of road.
			var seg_len := seg.length()
			if seg_len > 5000.0:
				continue
			var steps: int = maxi(1, int(ceil(seg_len / 5.0)))
			for k in steps + 1:
				var q := pts[i] + seg * (float(k) / float(steps))
				_road_cells[Vector2i(int(floor(q.x / 8.0)), int(floor(q.y / 8.0)))] = true
		for p in pts:
			var key := Vector2i(int(floor(p.x / 30.0)), int(floor(p.y / 30.0)))
			var prev = owner.get(key, -1)
			if prev == -1:
				owner[key] = wi
			elif prev != wi:
				_junc[key] = true
	print("ring_vibes: %d junction cells, %d road cells from %d centrelines"
		% [_junc.size(), _road_cells.size(), _roadlines.size()])

func _near_junction(p: Vector2) -> bool:
	return _junc.has(Vector2i(int(floor(p.x / 30.0)), int(floor(p.y / 30.0))))

func _build_hedges() -> void:
	var mat := StandardMaterial3D.new()
	# real texture if one has been dropped in, generated foliage noise otherwise, so the mock
	# still runs on a clean checkout (game/mocks/tex/ is an art drop, not a build artefact)
	var tex: Texture2D = null
	if FileAccess.file_exists(HEDGE_TEX):
		var img := Image.new()
		if img.load_jpg_from_buffer(FileAccess.get_file_as_bytes(HEDGE_TEX)) == OK:
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
			print("ring_vibes: hedge texture %dx%d loaded" % [img.get_width(), img.get_height()])
	if tex == null:
		print("ring_vibes: hedge texture MISSING — falling back to generated noise")
	mat.albedo_texture = tex if tex != null else _hedge_texture()
	mat.uv1_triplanar = true
	# 0.4 tiled the texture once per 2.5m, so a hedge showed a fraction of one tile and read
	# as flat colour. Foliage wants many tiles across its face.
	mat.uv1_scale = Vector3(1.6, 1.6, 1.6)
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true   # per-kind tint rides on the vertex colour
	_hedge_mi = MeshInstance3D.new()
	_hedge_mi.material_override = mat
	_hedge_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hedge_mi)

func _build_hedge_ribbon() -> void:
	# ONE mesh, built by walking each road centreline near the camera and extruding a hedge profile
	# up either side of it. A Cork boreen is a continuous green bank, not a row of shrubs -- and a
	# ribbon is also far cheaper than the scatter it replaces: ~5,600 instances at ~40 tris each
	# became a few thousand triangles total.
	if _hedge_mi == null or _roadlines.is_empty():
		return
	var cam := _cam.global_position
	var r := _radius()
	var here := Vector2(atan2(cam.x, r - cam.y) * r, cam.z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for line in _roadlines:
		var pts: PackedVector2Array = line["pts"]
		# half carriageway plus a narrow verge. Was 3.2 + w*2.6, which stood them 6-8m off the
		# centreline -- reading as a field boundary across a wide green bank rather than as
		# hedge tight against a boreen.
		var off: float = 2.4 + float(line["w"]) * 1.5
		var prev := []
		var prev_ok := false
		for i in pts.size() - 1:
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			if (minf(p0.x, p1.x) - here.x > HEDGE_RANGE or here.x - maxf(p0.x, p1.x) > HEDGE_RANGE
					or minf(p0.y, p1.y) - here.y > HEDGE_RANGE or here.y - maxf(p0.y, p1.y) > HEDGE_RANGE):
				prev_ok = false
				continue
			# RESAMPLE. OSM puts a node only where a road changes direction, so a straight run can be
			# 200m between points -- and a hedge drawn straight between them cuts through every rise
			# in between. Step it at HEDGE_STEP so the ribbon follows the ground.
			var seg := p1 - p0
			var len_m := seg.length()
			if len_m < 0.01:
				continue
			var steps: int = maxi(1, int(ceil(len_m / HEDGE_STEP)))
			var tg := seg / len_m
			var nrm := Vector2(-tg.y, tg.x)
			for k in steps + 1:
				var p := p0 + seg * (float(k) / float(steps))
				if absf(p.x - here.x) > HEDGE_RANGE or absf(p.y - here.y) > HEDGE_RANGE:
					prev_ok = false
					continue
				var cur := [p - nrm * off, p + nrm * off]
				var junc := _near_junction(p)
				if prev_ok:
					for side in 2:
						var pa: Vector2 = prev[side]
						var pb: Vector2 = cur[side]
						# JUNCTIONS, from the precomputed flags rather than the road mask. The mask was the
						# obvious tool and the wrong one: it is 2048 cells over 90km, i.e. 44m per cell, and
						# the hedge sits 3.9m off the centreline -- so "beside the road" and "on the road"
						# land in the SAME cell and it rejected 82% of the ribbon. Resolution has to match the
						# question being asked of it.
						if junc:
							continue
						var kind := _hedge_kind(pa.x, pa.y)
						if float(kind["h"]) <= 0.01:
							continue
						# gaps: a real hedgerow is not continuous for kilometres. Hashed off position so the
						# same gate is in the same place every rebuild rather than flickering as you drive.
						if _hash2(floor(pa.x / 37.0), floor(pa.y / 37.0)) < float(kind["gap"]):
							continue
						# trampled flat by an elephant (TASKS.md "Elephants") -- leave a gap in the ribbon
						if _hedge_trampled(pa):
							continue
						st.set_color(kind["col"])
						_hedge_span(st, pa, pb, rng)
						quads += 4
				prev = cur
				prev_ok = true
				if quads > HEDGE_MAX_QUADS:
					break
			if quads > HEDGE_MAX_QUADS:
				break
		if quads > HEDGE_MAX_QUADS:
			break
	if quads == 0:
		_hedge_mi.mesh = null
		_hedge_quads = 0
		return
	st.generate_normals()
	_hedge_mi.mesh = st.commit()
	_hedge_quads = quads

func _hash2(a: float, b: float) -> float:
	return fposmod(sin(a * 127.1 + b * 311.7) * 43758.5453, 1.0)

func _hedge_trampled(p: Vector2) -> bool:
	# has an elephant crushed the hedge here? _hedge_down is small (capped at TRAMPLE_HEDGE_MAX), so a
	# linear scan per span is cheap and only runs at all once a trample point exists.
	for q in _hedge_down:
		if p.distance_squared_to(q) < TRAMPLE_HEDGE_R2:
			return true
	return false

func _hedge_kind(arc: float, lat: float) -> Dictionary:
	# what bounds a road here. Deserts get a low stone wall or nothing, dry country gets gappy
	# scrub, anywhere with real growth gets a proper bank. tree_hi doubles as a proxy for how
	# vigorous the local growth is, which keeps this on one source of truth rather than a new table.
	var b := _biome_at(arc, lat)
	var t: float = float(b.get("trees", 0.5))
	if t < 0.04:
		return HEDGE_KINDS["none"]
	if t < 0.20:
		return HEDGE_KINDS["wall"]
	if t < 0.45:
		return HEDGE_KINDS["scrub"]
	return HEDGE_KINDS["bank"]

func _hedge_dims(p: Vector2) -> Vector2:
	# Width and height as a SMOOTH FUNCTION OF POSITION, not a per-span random draw.
	# Randomising per span meant span A's end vertices and span B's start vertices disagreed, so the
	# run was visibly notched every 11m -- clearly wrong in the first screenshot of it. Two spans
	# sharing a point now compute the same dimensions there by construction, so the ribbon is
	# continuous while still varying along its length.
	var n1 := sin(p.x * 0.021 + p.y * 0.013)
	var n2 := sin(p.x * 0.0043 - p.y * 0.0071)
	var k := _hedge_kind(p.x, p.y)
	return Vector2(
		float(k["w"]) * (1.0 + 0.34 * n1),
		float(k["h"]) * (1.0 + 0.24 * n2 + 0.14 * n1))

func _hedge_span(st: SurfaceTool, a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> void:
	# one length of hedge between two centreline offsets: a trapezoid section swept along the run
	var ha := _surface_pos(a.x, a.y)
	var hb := _surface_pos(b.x, b.y)
	var ua := _ring_up(ha)
	var ub := _ring_up(hb)
	var dir := (b - a)
	if dir.length_squared() < 1e-6:
		return
	dir = dir.normalized()
	var la := _ring_lateral(ua, dir)
	var lb := _ring_lateral(ub, dir)
	var da := _hedge_dims(a)
	var db := _hedge_dims(b)
	# profile: base wide, shoulder, narrower top -- the shape a flail-cut roadside hedge holds
	var a0 := ha - la * da.x
	var a1 := ha + la * da.x
	var b0 := hb - lb * db.x
	var b1 := hb + lb * db.x
	var a0s := ha - la * da.x * 0.82 + ua * da.y * 0.55
	var a1s := ha + la * da.x * 0.82 + ua * da.y * 0.55
	var b0s := hb - lb * db.x * 0.82 + ub * db.y * 0.55
	var b1s := hb + lb * db.x * 0.82 + ub * db.y * 0.55
	var at := ha + ua * da.y
	var bt := hb + ub * db.y
	_hedge_quad(st, a0, b0, b0s, a0s)
	_hedge_quad(st, a0s, b0s, bt, at)
	_hedge_quad(st, a1s, b1s, b1, a1)
	_hedge_quad(st, at, bt, b1s, a1s)

func _ring_lateral(up: Vector3, dir: Vector2) -> Vector3:
	# unit vector across the run, in the ground plane at this point
	var ax := up.cross(Vector3.FORWARD).normalized()
	if ax.length_squared() < 0.25:
		ax = up.cross(Vector3.RIGHT).normalized()
	var az := ax.cross(up).normalized()
	var along := (ax * dir.x + az * dir.y).normalized()
	return along.cross(up).normalized()

func _hedge_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, c, b, a, d, c]:
		st.add_vertex(v)


# ---------------------------------------------------------------------------
# Tree SPECIES, generated. The fir pack is the only imported tree, so Java, Cape fynbos and Lofoten
# birch were all firs with a colour tint on them -- which reads as one forest painted five ways.
# There is no teak, palm or scrub model in assets/, but this project already generates its houses,
# its joglo roofs, its hedge profile and its hedge texture, and it targets 2001-era fidelity
# deliberately (see .decisions/rendering.md). A palm is a trunk and eight fronds. Generate them.
#
# Unit height, +Y up, origin at the base -- same contract as the normalised fir meshes, so these
# drop straight into the existing MultiMesh/LOD machinery without touching it.
# ---------------------------------------------------------------------------

func _sp_trunk(st: SurfaceTool, r0: float, r1: float, h: float, sides: int, col: Color) -> void:
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var b0 := Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
		var b1 := Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
		var t0 := Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var t1 := Vector3(cos(a1) * r1, h, sin(a1) * r1)
		for v in [b0, t0, b1, b1, t0, t1]:
			st.set_color(col)
			st.add_vertex(v)

func _sp_blob(st: SurfaceTool, centre: Vector3, rx: float, ry: float, col: Color, seg: int) -> void:
	# a squashed octahedron -- eight triangles reads as a canopy mass at the distance trees are seen
	var top := centre + Vector3(0, ry, 0)
	var bot := centre - Vector3(0, ry * 0.7, 0)
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var p0 := centre + Vector3(cos(a0) * rx, 0, sin(a0) * rx)
		var p1 := centre + Vector3(cos(a1) * rx, 0, sin(a1) * rx)
		for v in [p0, top, p1, p1, bot, p0]:
			st.set_color(col)
			st.add_vertex(v)

func _species_billboard_tex(kind: String) -> ImageTexture:
	# An alpha silhouette for the far-LOD quad. Without one the impostor is a SOLID GREEN RECTANGLE:
	# the imported fir pack gets away with a flat quad because its material carries a cutout that
	# carves a tree shape out of it, and the generated species inherited the quad without the cutout.
	# Drawn rather than imported, same as everything else here.
	var res := 64
	var img := Image.create(res, res, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var leaf := Color(0.22, 0.36, 0.17)
	for y in res:
		for x in res:
			var u := (float(x) / float(res)) * 2.0 - 1.0     # -1..1 across
			var v := 1.0 - float(y) / float(res)             # 0 at base, 1 at top
			var on := false
			var c := leaf
			match kind:
				"palm":
					# bare trunk most of the way up, then fronds arcing out and down from the crown
					if absf(u) < 0.045 and v < 0.78:
						on = true
						c = Color(0.30, 0.22, 0.15)
					elif v > 0.60:
						var t := (v - 0.78) / 0.30
						if absf(u) < 0.62 - absf(t) * 0.9 and absf(u) > 0.02:
							# thin out toward the tips so it does not read as a fan
							on = absf(sin(u * 11.0)) > 0.18 * (absf(u) / 0.62)
				"broadleaf":
					if absf(u) < 0.06 and v < 0.42:
						on = true
						c = Color(0.30, 0.22, 0.15)
					else:
						var dy := (v - 0.68) / 0.34
						var dx := u / 0.62
						on = dx * dx + dy * dy < 1.0
				_:
					var dy2 := (v - 0.30) / 0.32
					var dx2 := u / 0.78
					on = dx2 * dx2 + dy2 * dy2 < 1.0
			if on:
				# a little vertical shading so the silhouette is not a flat cut-out
				var sh: float = 0.72 + 0.34 * v
				img.set_pixel(x, y, Color(c.r * sh, c.g * sh, c.b * sh, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _species_mesh(kind: String, variant: int, lod: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) * 31 + variant
	# THE FAR TIER MUST BE A BILLBOARD. The fir pack drops to 2 triangles out here; my first
	# pass kept full geometry at every LOD and only thinned the segment count, so 27k palms cost
	# 1,055,008 triangles and 3 fps at Java. A generated species has to honour the same LOD
	# contract as an imported one, not just look right up close.
	if lod >= TREE_LODS - 1:
		var bc := Color(0.24, 0.36, 0.18) if kind != "scrub" else Color(0.26, 0.32, 0.18)
		var bw := 0.34 if kind != "scrub" else 0.42
		var bh := 1.0 if kind != "scrub" else 0.45
		for pair in [[Vector3(-bw, 0, 0), Vector3(bw, 0, 0)], [Vector3(0, 0, -bw), Vector3(0, 0, bw)]]:
			var a: Vector3 = pair[0]
			var b: Vector3 = pair[1]
			var quad := [a, a + Vector3(0, bh, 0), b, b, a + Vector3(0, bh, 0), b + Vector3(0, bh, 0)]
			var uvs := [Vector2(0, 1), Vector2(0, 0), Vector2(1, 1),
				Vector2(1, 1), Vector2(0, 0), Vector2(1, 0)]
			for qi in quad.size():
				st.set_color(Color(1, 1, 1))
				st.set_uv(uvs[qi])
				st.add_vertex(quad[qi])
		st.generate_normals()
		return st.commit()
	# nearer tiers thin the segment count
	var seg: int = [7, 5, 4][clampi(lod, 0, 2)]
	var bark := Color(0.32, 0.24, 0.17)
	match kind:
		"palm":
			# tall bare trunk, crown of drooping fronds. The bare trunk IS the read.
			_sp_trunk(st, 0.022, 0.014, 0.80, maxi(seg - 2, 3), bark)
			var frond := Color(0.30, 0.46, 0.20)
			var n: int = [8, 5, 3][clampi(lod, 0, 2)]
			for i in n:
				var a := TAU * float(i) / float(n) + rng.randf() * 0.2
				var dir := Vector3(cos(a), 0.0, sin(a))
				var base := Vector3(0, 0.80, 0)
				var mid := base + dir * 0.20 + Vector3(0, 0.13, 0)
				var tip := base + dir * 0.40 - Vector3(0, 0.10, 0)
				var w := dir.cross(Vector3.UP).normalized() * 0.045
				for v in [base - w, mid - w * 0.7, mid + w * 0.7,
						base - w, mid + w * 0.7, base + w,
						mid - w * 0.7, tip, mid + w * 0.7]:
					st.set_color(frond)
					st.add_vertex(v)
		"broadleaf":
			# short trunk, two or three overlapping canopy masses -- a rounded silhouette, which is
			# the entire difference from a conifer at any distance you actually see a tree from
			_sp_trunk(st, 0.045, 0.030, 0.36, maxi(seg - 2, 3), bark)
			var leaf := Color(0.20, 0.38, 0.16)
			_sp_blob(st, Vector3(0, 0.62, 0), 0.32, 0.30, leaf, seg)
			if lod < 2:
				_sp_blob(st, Vector3(0.13, 0.52, 0.06), 0.20, 0.19, leaf.darkened(0.12), seg - 1)
				_sp_blob(st, Vector3(-0.10, 0.55, -0.10), 0.18, 0.17, leaf.lightened(0.06), seg - 1)
		_:   # "scrub" -- fynbos, birch scrub, anything low and woody. No trunk to speak of.
			var bush := Color(0.26, 0.32, 0.18)
			_sp_blob(st, Vector3(0, 0.34, 0), 0.40, 0.34, bush, seg)
			if lod < 2:
				_sp_blob(st, Vector3(0.20, 0.24, 0.10), 0.24, 0.22, bush.darkened(0.15), seg - 1)
	st.generate_normals()
	return st.commit()

func _apply_species(kind: String) -> void:
	# Swap the geometry inside the existing MultiMeshes rather than building a parallel system: the
	# scatter, the distance bucketing and the LOD tables all keep working untouched, and only one
	# species is ever on screen because the scatter is biome-local anyway.
	if kind == _species_now or _tree_mm.is_empty():
		return
	_species_now = kind
	if kind == "fir":
		for vi in _tree_mm.size():
			for l in TREE_LODS:
				if _tree_mm[vi][l] != null and vi < _tree_meshes.size():
					_tree_mm[vi][l].multimesh.mesh = _tree_meshes[vi][l]
		return
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# separate material for the far tier: it needs the alpha silhouette and a cutout, or the
	# impostor is a solid rectangle standing where a tree should be
	var bill := StandardMaterial3D.new()
	bill.albedo_texture = _species_billboard_tex(kind)
	bill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	bill.alpha_scissor_threshold = 0.5
	bill.vertex_color_use_as_albedo = true
	bill.roughness = 1.0
	bill.cull_mode = BaseMaterial3D.CULL_DISABLED
	for vi in _tree_mm.size():
		for l in TREE_LODS:
			if _tree_mm[vi][l] == null:
				continue
			var m := _species_mesh(kind, vi, l)
			m.surface_set_material(0, bill if l >= TREE_LODS - 1 else mat)
			_tree_mm[vi][l].multimesh.mesh = m
	print("ring_vibes: tree species -> %s" % kind)

func _scatter_trees() -> void:
	# conifers clumped by noise into woods + clearings, in a patch near spawn. Placed analytically
	# on the DEM+curve (no raycast — see file header). Positions/variants baked once; LOD tier
	# chosen per-frame by distance in _update_tree_lod().
	if _tree_meshes.is_empty() or _dem_w == 0:
		return
	_tree_ground = PackedVector3Array()
	_tree_basis = []
	_tree_variant = PackedInt32Array()
	_tree_down = {}   # a fresh scatter is a different patch of woodland; trampled indices no longer apply
	# scatter around wherever the camera IS, not around spawn -- on a 3000km ring the forest has to
	# travel with you. Density and treeline come from the local biome, so the salt flat and the
	# dunes are genuinely bare rather than sprouting Irish conifers.
	var biome := _biome_at(_tree_center.x, _tree_center.y)
	var density: float = biome["trees"] * TREE_DENSITY
	# recolour and resize the fir pack per biome -- it is the only tree mesh we have, so a
	# tropical patch gets tinted firs rather than looking like Cork transplanted onto Java.
	_apply_species(str(biome.get("species", "fir")))
	var fol: Color = biome.get("foliage", Color(1, 1, 1))
	var tmul: float = float(biome.get("tree_mul", 1.0))
	for vlods in _tree_mm:
		for mmi in vlods:
			if mmi != null and mmi.multimesh != null and mmi.multimesh.mesh != null:
				var sm := mmi.multimesh.mesh.surface_get_material(0) as ShaderMaterial
				if sm != null:
					sm.set_shader_parameter("tint", Vector3(fol.r, fol.g, fol.b))
	var tree_hi: float = biome["tree_hi"]
	if density <= 0.0:
		_update_tree_lod(true)
		return
	_forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_forest_noise.frequency = 1.0 / 300.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var n_road := 0
	var n_hedge := 0
	var arc := -FOREST_HALF
	while arc <= FOREST_HALF:
		var lat := -FOREST_HALF
		while lat <= FOREST_HALF:
			var jx := _tree_center.x + arc + rng.randf_range(-3.5, 3.5)
			var jz := _tree_center.y + lat + rng.randf_range(-3.5, 3.5)
			# Nothing grows on the carriageway. The road mask has been in the shader since the
			# drape went in, but the scatter could not read it, so conifers grew down the middle
			# of every road in the starting area.
			# cells, not the raster mask: the mask only exists for the home patch, so away from it
			# trees grew straight down the carriageway and no hedgerow was planted at all
			var cell := Vector2i(int(floor(jx / 8.0)), int(floor(jz / 8.0)))
			var on_road := _road_cells.has(cell)
			var side := false
			if not on_road:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if _road_cells.has(cell + d):
						side = true
						break
			# ...and roads are LINED. A hedgerow ignores the forest mask entirely: it is there
			# because the road is there, which is exactly how field boundaries work.
			if on_road:
				n_road += 1
			elif side or (_forest_noise.get_noise_2d(jx, jz) > 0.0 and rng.randf() < density):
				var gh := _terrain_h(jx, jz)
				# no trees in the water or above the local treeline; fade out near the ceiling
				# rather than cutting a hard line across the slope.
				var ok := gh > SEA_LEVEL + 1.0 and gh < tree_hi
				if ok and gh > tree_hi - 150.0:
					ok = rng.randf() < (tree_hi - gh) / 150.0
				if ok:
					var ground := _surface_pos(jx, jz)
					var up := _ring_up(ground)
					# The roadside ribbon owns the hedge now, so a roadside cell only ever contributes the
					# occasional standard tree grown out of the line -- the rest would be inside the ribbon.
					if side and rng.randf() > 0.09:
						lat += 8.0
						continue
					if side:
						n_hedge += 1
					var sc: float = _tree_scale * tmul * rng.randf_range(0.8, 1.3)
					var basis := Basis()
					basis.y = up
					basis.x = up.cross(Vector3.FORWARD).normalized()
					basis.z = basis.x.cross(up).normalized()
					basis = basis.rotated(up, rng.randf() * TAU).scaled(Vector3(sc, sc, sc))
					_tree_ground.append(ground - up * 0.3)
					_tree_basis.append(basis)
					_tree_variant.append(rng.randi() % _tree_nvar)
					if side:
						n_hedge += 1
			lat += 8.0
		arc += 8.0
	if _hedge_mi == null:
		_build_hedges()
	_build_hedge_ribbon()
	_update_tree_lod(true)
	print("ring_vibes: %d trees placed (%d variants x %d LODs) — %d standards, %d off-road, %d hedge quads"
		% [_tree_ground.size(), _tree_nvar, TREE_LODS, n_hedge, n_road, _hedge_quads])

func _fill_mm(mmi: MultiMeshInstance3D, xfs: Array) -> void:
	if mmi == null: return
	var mm := mmi.multimesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])

# ---------------------------------------------------------------------------
# Rudimentary buildings, placed from REAL OpenStreetMap footprints
# see .decisions/terrain.md — same principle as the road drape: position is real, detail is not.
# tools/dem/fetch_osm_buildings.py writes <patch>_bldg.dat as
#   "BLD1" | u32 count | count x (arc_local, lat_local, w, d, yaw, height) float32
# arc_local/lat_local are metres from the PATCH CENTRE; the home DEM uses its camera_px origin
# instead, so the offset is applied here per patch rather than baked into the file.
# ---------------------------------------------------------------------------

func _plinth(st: SurfaceTool, quad: Callable, e: float) -> void:
	# An undercroft dropping a full building-height below the floor. Buildings are placed on the
	# HIGHEST corner of their footprint so nothing is buried; that leaves the downhill side in the
	# air, and this fills it. Which is also what hillside buildings actually do -- cut into the
	# slope at the back, stand on stone or stilts at the front. Invisible on flat ground.
	var base := Color(0.34, 0.31, 0.28)
	quad.call(Vector3(-e, -1.0, e), Vector3(e, -1.0, e), Vector3(e, 0.02, e), Vector3(-e, 0.02, e), base)
	quad.call(Vector3(e, -1.0, -e), Vector3(-e, -1.0, -e), Vector3(-e, 0.02, -e), Vector3(e, 0.02, -e), base)
	quad.call(Vector3(e, -1.0, e), Vector3(e, -1.0, -e), Vector3(e, 0.02, -e), Vector3(e, 0.02, e), base)
	quad.call(Vector3(-e, -1.0, -e), Vector3(-e, -1.0, e), Vector3(-e, 0.02, e), Vector3(-e, 0.02, -e), base)

func _house_mesh() -> ArrayMesh:
	# Unit house: footprint 1x1 in x/z, total height 1, walls to 0.72, gable ridge along z.
	# Instance transforms scale it to real width/depth/height, so one mesh covers every building.
	# Vertex colours carry wall-vs-roof; per-instance colour tints the whole thing for variety.
	#
	# Winding defines the normals here (generate_normals at the end) rather than both being
	# asserted separately -- stating them independently is how you get geometry that is lit
	# correctly and culled inside out, or vice versa. See the shader-winding note in
	# .decisions/terrain.md: never hand-assert a normal and a winding and hope they agree.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := Color(0.82, 0.80, 0.75)
	var roof := Color(0.30, 0.29, 0.31)
	var wt := 0.72
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
		for v in [a, c, b, a, d, c]:
			st.set_color(col)
			st.add_vertex(v)
	var tri := func(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
		for v in [a, c, b]:
			st.set_color(col)
			st.add_vertex(v)
	# walls, each wound as seen from OUTSIDE the house
	quad.call(Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5), Vector3(0.5, wt, 0.5), Vector3(-0.5, wt, 0.5), wall)
	quad.call(Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, -0.5), Vector3(-0.5, wt, -0.5), Vector3(0.5, wt, -0.5), wall)
	quad.call(Vector3(0.5, 0, 0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, wt, -0.5), Vector3(0.5, wt, 0.5), wall)
	quad.call(Vector3(-0.5, 0, -0.5), Vector3(-0.5, 0, 0.5), Vector3(-0.5, wt, 0.5), Vector3(-0.5, wt, -0.5), wall)
	# roof planes, ridge along z at x=0
	quad.call(Vector3(-0.5, wt, 0.5), Vector3(0.0, 1.0, 0.5), Vector3(0.0, 1.0, -0.5), Vector3(-0.5, wt, -0.5), roof)
	quad.call(Vector3(0.0, 1.0, 0.5), Vector3(0.5, wt, 0.5), Vector3(0.5, wt, -0.5), Vector3(0.0, 1.0, -0.5), roof)
	# gable ends
	tri.call(Vector3(-0.5, wt, 0.5), Vector3(0.5, wt, 0.5), Vector3(0.0, 1.0, 0.5), wall)
	tri.call(Vector3(0.5, wt, -0.5), Vector3(-0.5, wt, -0.5), Vector3(0.0, 1.0, -0.5), wall)
	_plinth(st, quad, 0.5)
	st.generate_normals()
	return st.commit()

func _joglo_mesh() -> ArrayMesh:
	# Javanese domestic form: low walls under a big tiered roof. That ratio -- wall almost nothing,
	# roof almost everything -- is what reads as South-East Asian at a glance, far more than any
	# ornament would at this distance. Lower hip skirt overhangs the walls; steep pyramid above.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := Color(0.74, 0.70, 0.62)
	var roof := Color(0.26, 0.19, 0.15)
	var wt := 0.30            # wall top -- deliberately low
	var eave := 0.62          # skirt overhang half-extent
	var mid := 0.30           # where the skirt meets the upper pyramid
	var midy := 0.58
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
		for v in [a, c, b, a, d, c]:
			st.set_color(col)
			st.add_vertex(v)
	var tri := func(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
		for v in [a, c, b]:
			st.set_color(col)
			st.add_vertex(v)
	# walls
	quad.call(Vector3(-0.42, 0, 0.42), Vector3(0.42, 0, 0.42), Vector3(0.42, wt, 0.42), Vector3(-0.42, wt, 0.42), wall)
	quad.call(Vector3(0.42, 0, -0.42), Vector3(-0.42, 0, -0.42), Vector3(-0.42, wt, -0.42), Vector3(0.42, wt, -0.42), wall)
	quad.call(Vector3(0.42, 0, 0.42), Vector3(0.42, 0, -0.42), Vector3(0.42, wt, -0.42), Vector3(0.42, wt, 0.42), wall)
	quad.call(Vector3(-0.42, 0, -0.42), Vector3(-0.42, 0, 0.42), Vector3(-0.42, wt, 0.42), Vector3(-0.42, wt, -0.42), wall)
	# lower hip skirt: outer ring at eave height, inner ring at midy
	var e := 0.34
	quad.call(Vector3(-eave, e, eave), Vector3(eave, e, eave), Vector3(mid, midy, mid), Vector3(-mid, midy, mid), roof)
	quad.call(Vector3(eave, e, -eave), Vector3(-eave, e, -eave), Vector3(-mid, midy, -mid), Vector3(mid, midy, -mid), roof)
	quad.call(Vector3(eave, e, eave), Vector3(eave, e, -eave), Vector3(mid, midy, -mid), Vector3(mid, midy, mid), roof)
	quad.call(Vector3(-eave, e, -eave), Vector3(-eave, e, eave), Vector3(-mid, midy, mid), Vector3(-mid, midy, -mid), roof)
	# steep upper pyramid
	var apex := Vector3(0, 1.0, 0)
	tri.call(Vector3(-mid, midy, mid), Vector3(mid, midy, mid), apex, roof)
	tri.call(Vector3(mid, midy, -mid), Vector3(-mid, midy, -mid), apex, roof)
	tri.call(Vector3(mid, midy, mid), Vector3(mid, midy, -mid), apex, roof)
	tri.call(Vector3(-mid, midy, -mid), Vector3(-mid, midy, mid), apex, roof)
	_plinth(st, quad, 0.42)
	st.generate_normals()
	return st.commit()

func _build_buildings() -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mat.metallic_specular = 0.1
	_bldg_mmi = []
	for m in [_house_mesh(), _joglo_mesh()]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = m
		mm.mesh.surface_set_material(0, mat)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_bldg_mmi.append(mmi)

func _load_bldg_file(name: String, arc_off: float, lat_off: float, style: int) -> int:
	var path := "res://mocks/dem/%s_bldg.dat" % name
	if not FileAccess.file_exists(path):
		return 0
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 8 or b.decode_u8(0) != 0x42 or b.decode_u8(1) != 0x4C:   # "BL"
		print("ring_vibes: %s_bldg.dat has a bad header, skipped" % name)
		return 0
	var n := int(b.decode_u32(4))
	if b.size() < 8 + n * 24:
		print("ring_vibes: %s_bldg.dat truncated (%d of %d records), using what is there"
			% [name, (b.size() - 8) / 24, n])
		n = (b.size() - 8) / 24
	var circ: float = CIRCUMFERENCES[c_idx]
	# Patches are 84-97km across but the ring is only 50km wide, so a patch overhangs the rim by a
	# long way in latitude. Buildings out there would sit past the wall on nothing. Filter them, and
	# build the density histogram from the survivors -- otherwise the "densest cluster" a warp aims
	# at can be a town that is not on the ring at all, which is exactly what Java's was.
	var lat_lim: float = WIDTHS[w_idx] * 0.47
	var cell := {}
	var best_key := 0
	var best_n := 0
	var kept := 0
	var lat_out := 0
	var cliff := 0
	for i in n:
		var o := 8 + i * 24
		var lt := b.decode_float(o + 4) + lat_off
		if absf(lt) > lat_lim:
			lat_out += 1
			continue
		var ar := b.decode_float(o) + arc_off
		var aw := fposmod(ar, circ)
		var bw := b.decode_float(o + 8)
		var bd := b.decode_float(o + 12)
		var byaw := b.decode_float(o + 16)
		var bh := b.decode_float(o + 20)
		# Reject cliff sites at placement. The undercroft is one building-height deep, so a footprint
		# whose corners drop by more than that stands on daylight (mirrors the ALIGN float check).
		var hw := bw * 0.5
		var hd := bd * 0.5
		var yc := cos(byaw)
		var ys := sin(byaw)
		var top := -1e20
		var low := 1e20
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var c := _terrain_h(aw + sx * hw * yc - sz * hd * ys, lt + sx * hw * ys + sz * hd * yc)
				top = maxf(top, c)
				low = minf(low, c)
		if top - low > bh:
			cliff += 1
			continue
		_bldg.append(aw)
		_bldg.append(lt)
		_bldg.append(bw)
		_bldg.append(bd)
		_bldg.append(byaw)
		_bldg.append(bh)
		_bldg_style.append(style)
		kept += 1
		# densest 4km cell, so a warp lands in the settlement rather than the middle of the bbox
		var cx := int(floor(ar / 4000.0))
		var cy := int(floor(lt / 4000.0))
		# +50000 bias: lat cells go negative, and cx*100000 + cy is ambiguous without it
		var key := cx * 100000 + (cy + 50000)
		var v: int = int(cell.get(key, 0)) + 1
		cell[key] = v
		if v > best_n:
			best_n = v
			best_key = key
	if best_n > 0:
		var bx: int = int(floor(float(best_key) / 100000.0))
		var by: int = best_key - bx * 100000 - 50000
		_bldg_focus[name] = Vector2((float(bx) + 0.5) * 4000.0, (float(by) + 0.5) * 4000.0)
	if kept < n:
		print("ring_vibes: %s — %d of %d buildings kept (%d outside the %0.0fkm ring width, %d on cliffs)"
			% [name, kept, n, lat_out, WIDTHS[w_idx] / 1000.0, cliff])
	return kept
	return n

func _load_buildings() -> void:
	_bldg = PackedFloat32Array()
	_bldg_style = PackedByteArray()
	var total := 0
	# home patch: origin is camera_px, not the DEM centre (see _dem_hf_cam / _biome_at).
	# Slug comes from the file path -- _dem_name is the DISPLAY name out of the JSON
	# ("Millstreet (Cork-Kerry route)") and will not match anything on disk.
	if _dem_w > 0:
		var ax := (float(_dem_w) * 0.5 - float(_dem_cam.x)) * _dem_mpp
		var lx := (float(_dem_cam.y) - float(_dem_h) * 0.5) * _dem_mpp
		total += _load_bldg_file(DEM_R16.get_file().get_basename(), ax, lx, 0)
	# splice patches: origin is the patch centre on the ring midline
	for i in _patch_names.size():
		var r := _patch_rects[i]
		var style := 1 if str(_patch_meta[i].get("style", "gable")) == "meru" else 0
		total += _load_bldg_file(str(_patch_names[i]), r.x, r.y, style)
	if total > 0:
		if _bldg_mmi.is_empty():
			_build_buildings()
		_refill_buildings(true)
		print("ring_vibes: %d OSM buildings loaded (%d styles)" % [total, _bldg_mmi.size()])

func _refill_buildings(force := false) -> void:
	# Only the ones near you get instanced. 120k buildings sit in memory happily; 120k MultiMesh
	# instances do not, and almost all of them are over the horizon anyway.
	if _bldg_mmi.is_empty() or _bldg.is_empty():
		return
	var cam := _cam.global_position
	var r := _radius()
	var cam_arc: float = atan2(cam.x, r - cam.y) * r
	var here := Vector2(cam_arc, cam.z)
	if not force and here.distance_to(_bldg_center) < BLDG_RESCATTER:
		return
	_bldg_center = here
	var circ: float = CIRCUMFERENCES[c_idx]
	var xfs := []
	var cols := []
	for _s in _bldg_mmi:
		xfs.append([])
		cols.append([])
	var rng := RandomNumberGenerator.new()
	var shown := 0
	var i := 0
	while i < _bldg.size():
		var d_arc: float = absf(wrapf(_bldg[i] - here.x, -circ * 0.5, circ * 0.5))
		if d_arc < BLDG_RADIUS and absf(_bldg[i + 1] - here.y) < BLDG_RADIUS:
			if _terrain_h(_bldg[i], _bldg[i + 1]) > SEA_LEVEL + 0.5:
				# A level box on a slope buries its uphill half if you place it by its centre: a 12m
				# footprint on a 20-degree slope spans 4m of rise. Sample the four corners and sit on
				# the highest, so nothing is ever underground; the plinth covers the downhill gap.
				var hw: float = _bldg[i + 2] * 0.5
				var hd: float = _bldg[i + 3] * 0.5
				var yc := cos(_bldg[i + 4])
				var ys := sin(_bldg[i + 4])
				var top := -1e20
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						top = maxf(top, _terrain_h(_bldg[i] + sx * hw * yc - sz * hd * ys,
							_bldg[i + 1] + sx * hw * ys + sz * hd * yc))
				var ground := _ring_pos(_bldg[i] / _radius(), _bldg[i + 1], top)
				var up := _ring_up(ground)
				var ax := up.cross(Vector3.FORWARD).normalized()
				if ax.length_squared() < 0.25:
					ax = up.cross(Vector3.RIGHT).normalized()
				var az := ax.cross(up).normalized()
				var cs := cos(_bldg[i + 4])
				var sn := sin(_bldg[i + 4])
				var rx := (ax * cs + az * sn).normalized()
				var rz := (az * cs - ax * sn).normalized()
				# Basis(x, y, z) takes COLUMNS, so scale bakes in cleanly. Basis.scaled() would
				# scale along global axes instead and shear every rotated house.
				var si: int = _bldg_style[i / 6] if (i / 6) < _bldg_style.size() else 0
				xfs[si].append(Transform3D(
					Basis(rx * _bldg[i + 2], up * _bldg[i + 5], rz * _bldg[i + 3]),
					ground))
				rng.seed = i
				var t := rng.randf_range(0.82, 1.12)
				cols[si].append(Color(t, t * rng.randf_range(0.97, 1.02), t * rng.randf_range(0.94, 1.0)))
				shown += 1
		if shown >= BLDG_MAX:
			break
		i += 6
	var dbg := PackedStringArray()
	for s in _bldg_mmi.size():
		var mm: MultiMesh = _bldg_mmi[s].multimesh
		dbg.append("style%d=%d" % [s, xfs[s].size()])
		mm.instance_count = xfs[s].size()
		for k in xfs[s].size():
			mm.set_instance_transform(k, xfs[s][k])
			mm.set_instance_color(k, cols[s][k])
	_bldg_shown = shown
	if force:
		print("ring_vibes: buildings in range at arc %.0f lat %.0f -> %s" % [here.x, here.y, ", ".join(dbg)])

func _update_tree_lod(force := false) -> void:
	if _tree_mm.is_empty():
		return
	var cam := _cam.global_position
	if not force and cam.distance_to(_tree_last_cam) < 3.0:
		return
	_tree_last_cam = cam
	var d := []
	for k in TREE_LODS:
		var r: float = _tree_lod_dist[k] * _tree_lod_scale
		if k == TREE_LODS - 1 and _mode == Mode.FLY:
			r *= _tree_fly_mult
		d.append(r * r)
	var buckets := []
	for v in _tree_nvar:
		var per := []
		for l in TREE_LODS:
			per.append([])
		buckets.append(per)
	for i in _tree_ground.size():
		if _tree_down.has(i):
			continue   # flattened by an elephant (TASKS.md "Elephants") -- omitted from every bucket
		var dist2 := cam.distance_squared_to(_tree_ground[i])
		var lod := -1
		for k in TREE_LODS:
			if dist2 < d[k]:
				lod = k; break
		if lod >= 0:
			buckets[_tree_variant[i]][lod].append(Transform3D(_tree_basis[i], _tree_ground[i]))
	_tree_counts = PackedInt32Array()
	_tree_counts.resize(TREE_LODS)
	for v in _tree_nvar:
		for l in TREE_LODS:
			_tree_counts[l] += buckets[v][l].size()
			_fill_mm(_tree_mm[v][l], buckets[v][l])

# ---------------------------------------------------------------------------

func _player_pos() -> Vector3:
	return _cam.global_position

func _spawn_creatures(preset: String, n: int, dist: float) -> void:
	if _dem_w == 0:
		return
	var base := _cam.global_position
	var fwd := -_cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	# deer ahead (+dist along view), wolves behind (-dist); scatter around that point
	var center := base + fwd * (dist if preset == "deer" else -dist)
	for i in n:
		var c = CreatureScript.new()
		c.configure(preset)
		c.height_fn = _terrain_h
		c.threat_fn = _player_pos
		if preset == "wolf":
			c.became_threat.connect(_on_threat)
		add_child(c)
		var off := Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))
		var p := center + off
		p.y = _terrain_h(p.x, p.z)
		c.global_position = p
		_creatures.append(c)
	_update_hud()

func _clear_creatures() -> void:
	for c in _creatures:
		if is_instance_valid(c):
			c.queue_free()
	_creatures.clear()
	_threat_active = false
	_update_hud()

func _on_threat(active: bool) -> void:
	# null-write test surface: deer must NEVER reach here; only a wolf in APPROACH does
	_threat_active = active
	_update_hud()


func _make_dust() -> void:
	# Dust off the back wheels once you leave the tarmac. The trigger was already free -- the 8m road
	# cells exist for the grass -- so this is the cheap half of making off-road feel different.
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 35.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 3.4
	pm.gravity = Vector3(0, -1.6, 0)
	pm.scale_min = 0.5
	pm.scale_max = 2.2
	pm.damping_min = 1.0
	pm.damping_max = 2.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.62, 0.55, 0.44, 0.55))
	ramp.set_color(1, Color(0.62, 0.55, 0.44, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	var qm := QuadMesh.new()
	qm.size = Vector2(1.4, 1.4)
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.vertex_color_use_as_albedo = true
	dm.albedo_color = Color(0.62, 0.55, 0.44, 0.5)
	qm.material = dm
	_dust = GPUParticles3D.new()
	_dust.process_material = pm
	_dust.draw_pass_1 = qm
	_dust.amount = 48
	_dust.lifetime = 1.6
	_dust.emitting = false
	add_child(_dust)

func _make_car(d: VehicleDef = null) -> Node3D:
	# The box is both the default car AND the placeholder for any def without a bespoke mesh, so it
	# takes its length and tint from the def -- a 4.2m green box for `box`, a longer khaki one for the
	# warthog when its GLTF is absent. Wheelbase scales off the length (was hardcoded 1.4 = 4.2/3) so
	# the wheels stay under the corners at any size. Pass no def and it reproduces the original box.
	var length: float = d.length if d else 4.2
	var tint: Color = d.tint if d else Color(0.33, 0.36, 0.30)
	var wz: float = length / 3.0
	_wheels = []
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 1.0, length)
	body.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = tint
	body.material_override = bmat
	body.position.y = 0.9
	root.add_child(body)
	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(1.7, 0.5, 1.1)
	glass.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.45, 0.75, 0.80)  # frutiger windscreen, obviously
	glass.position = Vector3(0, 1.55, -0.12 * length)
	glass.material_override = gmat
	root.add_child(glass)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.10, 0.10, 0.10)
	for wp in [Vector3(-1.05, 0.45, wz), Vector3(1.05, 0.45, wz), Vector3(-1.05, 0.45, -wz), Vector3(1.05, 0.45, -wz)]:
		var wheel := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		# 64 radial segments is Godot's default and absurd for a placeholder wheel: it put the box car
		# at 3,096 triangles, which is a silly baseline to measure a whole roster against on a
		# potato-hardware target. Twelve reads as round at the distance a chase camera sits.
		cm.radial_segments = 12
		cm.rings = 1
		cm.height = 0.35
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		wheel.mesh = cm
		wheel.rotation_degrees = Vector3(0, 0, 90)
		wheel.position = wp
		wheel.material_override = wmat
		root.add_child(wheel)
		# front pair steers, all four roll. Held in a pivot so the roll (local X) and the steer
		# (parent Y) do not fight each other on one transform.
		var pivot := Node3D.new()
		pivot.position = wp
		root.remove_child(wheel)
		wheel.position = Vector3.ZERO
		pivot.add_child(wheel)
		root.add_child(pivot)
		_wheels.append({"pivot": pivot, "mesh": wheel, "front": wp.z > 0.0, "offset": wp,
			"rest": wheel.transform.basis, "axle": _wheel_axle(wheel)})
	add_child(root)
	return root

# THE AXLE IS THE SHORTEST AXIS OF THE WHEEL. Derived, not assumed: the procedural cylinder spins
# about its own Y, an imported GLTF wheel about whatever axis the artist modelled it on, and the code
# that spins them cannot know which without looking. A wheel is wide in two dimensions and narrow in
# the third, so its local AABB says so unambiguously. This replaces a hardcoded 90-degree Z rotation
# that was applied to EVERY wheel every frame -- right for the box car's cylinders, and exactly the
# reason the warthog's wheels sat rotated 90 degrees out.
func _wheel_axle(n: Node3D) -> Vector3:
	var box := AABB()
	var got := false
	var stack: Array = [n]
	while not stack.is_empty():
		var c = stack.pop_front()
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var a: AABB = (c as MeshInstance3D).mesh.get_aabb()
			box = a if not got else box.merge(a)
			got = true
		for k in (c as Node).get_children():
			stack.append(k)
	if not got:
		return Vector3.UP
	var sz := box.size
	if sz.x <= sz.y and sz.x <= sz.z:
		return Vector3.RIGHT
	if sz.y <= sz.z:
		return Vector3.UP
	return Vector3.BACK

func _build_vehicles() -> void:
	# The DEFINITION TABLE is the roster: build one entry per VEHICLE_ROW so [L] cycles every vehicle
	# that exists as data, not just the ones that happen to have art. A row with a bespoke mesh (the
	# warthog GLTF) gets it; every other row -- and the warthog on a machine without the gitignored
	# pack -- gets a placeholder box sized and tinted from its def, still fully drivable on its own
	# handling. That is the framing for the whole 40-vehicle programme: a data row plus a mesh, and the
	# mesh is optional to start. The box is index 0, so it stays the fallback current() returns to.
	if not _vehicles.is_empty():
		return
	if _vehicle_defs.is_empty():
		_build_vehicle_defs()
	for name in VEHICLE_ROWS:
		var d: VehicleDef = _vehicle_defs[name]
		var root: Node3D = null
		var wheels: Array = []
		if name == "warthog" and ResourceLoader.exists(WARTHOG_PACK):
			root = _make_warthog()               # may still be null if the load fails
			if root != null:
				wheels = _collect_wheels(root)
		if root == null:
			root = _make_car(d)                  # placeholder box, sized+tinted per def; sets _wheels
			wheels = _wheels
		root.visible = false
		_vehicles.append({"root": root, "wheels": wheels, "name": name})

func _select_vehicle(i: int) -> void:
	if _vehicles.is_empty():
		return
	_veh_idx = posmod(i, _vehicles.size())
	for j in _vehicles.size():
		_vehicles[j]["root"].visible = (j == _veh_idx and _mode == Mode.DRIVE)
	var e: Dictionary = _vehicles[_veh_idx]
	_car = e["root"]
	_wheels = e["wheels"]
	_stamina = 1.0        # a mount you climb onto is fresh; only the horse row reads this
	_spooked = 0.0
	_boat_vel = Vector2.ZERO   # never inherit a stale hull course; a boat you board is dead in the water
	_air_vel = Vector2.ZERO    # nor a stale ballistic course when you cycle onto an aircraft
	_dive = 0.0           # never cycle onto a vehicle already submerged; a sub you board is on the surface
	_jump_h = 0.0         # never leave the suit airborne when cycling off it; only the suit row jumps
	_jump_v = 0.0
	_land_dip = 0.0
	_altitude = 0.0       # never cycle onto a flyer already airborne; a vehicle you board starts on the ground
	_vspeed = 0.0
	_docked = false       # nor latched to the port; a vehicle you cycle onto is free-flying, not station-kept
	_boarded = false
	_update_hud()

func _model_aabb(root_node: Node) -> AABB:
	# Union of every child mesh AABB, each mapped through its transform chain relative to root_node.
	# Godot resolves the GLTF's internal node transforms for us, so this footprint is exact without
	# hand-reading the file -- scale and orientation come from data, not a guess.
	var out := AABB()
	var first := true
	var stack: Array = [root_node]
	while stack.size() > 0:
		var n = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var box: AABB = _rel_xform(n, root_node) * (n as MeshInstance3D).mesh.get_aabb()
			out = box if first else out.merge(box)
			first = false
		for c in n.get_children():
			stack.append(c)
	return out

func _make_warthog() -> Node3D:
	if not ResourceLoader.exists(WARTHOG_PACK):
		print("ring_vibes: warthog pack not found ", WARTHOG_PACK, " — box car only")
		return null
	var packed := load(WARTHOG_PACK) as PackedScene
	if not packed:
		return null
	var model := packed.instantiate() as Node3D
	if model == null:
		return null
	var local := _model_aabb(model)
	if local.size == Vector3.ZERO:
		model.queue_free()
		return null
	# GLTF imports Y-up, so up is settled; only the horizontal facing is unknown. The longer footprint
	# axis is the length -- turn it to lie along -Z, which is the car's forward (what look_at expects).
	var rot := Basis.IDENTITY
	if local.size.x > local.size.z:
		rot = Basis(Vector3.UP, -PI * 0.5)
	rot = Basis(Vector3.UP, WARTHOG_YAW) * rot     # nose-flip knob (see WARTHOG_YAW)
	var oriented: AABB = Transform3D(rot, Vector3.ZERO) * local
	var s: float = VEHICLE_LEN / maxf(oriented.size.z, 0.001)
	var basis := rot.scaled(Vector3(s, s, s))
	var final: AABB = Transform3D(basis, Vector3.ZERO) * local
	# Centre the footprint over the root and sit its lowest point on y=0, matching how the box car's
	# wheels bottom out at 0 (the drive tick lifts either the same amount).
	var pos := Vector3(
		-final.position.x - final.size.x * 0.5,
		-final.position.y,
		-final.position.z - final.size.z * 0.5)
	model.transform = Transform3D(basis, pos)
	var root := Node3D.new()
	root.name = "Warthog"
	root.add_child(model)
	add_child(root)
	print("ring_vibes: warthog model loaded (%.1fm long, scale %.3f)" % [final.size.z, s])
	return root

func _collect_wheels(root: Node) -> Array:
	# The warthog was registered with an EMPTY wheel list, so swapping to it lost the rolling and
	# steering the box car has -- the imported vehicle was the static prop the box no longer is.
	# The pack names them Wheel1..Wheel4 and nests a mesh of the SAME name inside each, so take the
	# outermost match only; spinning both would double the rotation.
	var out: Array = []
	var re := RegEx.new()
	re.compile("(?i)^wheel[0-9]")
	var seen := {}
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_front()
		var matched := false
		if n is Node3D and re.search(String(n.name)) != null:
			var key := String(n.name).to_lower()
			if not seen.has(key):
				seen[key] = true
				out.append({"pivot": n, "mesh": n, "front": (n as Node3D).position.z > 0.0,
					"offset": (n as Node3D).position,
					# rest = however the artist oriented it. Never overwrite it, only spin RELATIVE
					# to it -- the imported wheel is already pointing the right way.
					"rest": (n as Node3D).transform.basis, "axle": _wheel_axle(n as Node3D)})
				matched = true
		if not matched:
			for c in n.get_children():
				stack.append(c)
	return out

func _car_pos(arc: float, lat: float) -> Vector3:
	return _surface_pos(arc, lat)

# local up at a ring surface point = toward the cylinder axis (0, R, lat/z)
func _apply_look() -> void:
	# Orient the camera in the LOCAL ring frame rather than world space. `_cam.rotation = (pitch,
	# yaw, 0)` is a world-space Euler, which only reads correctly near arc 0 where local up happens
	# to be world +Y. Local up on a ring points at the axis, so it swings a full 360 deg around the
	# circumference -- at 25% of arc it is 90 deg from spawn's, which is why jumping splices left the
	# ground sideways and then upside down.
	#   _look.x = yaw, 0 = spinward (along the arc), positive turns toward +lat
	#   _look.y = pitch, positive is up
	var up := _ring_up(_cam.global_position)
	var lat_dir := Vector3(0.0, 0.0, 1.0)          # cylinder axis: always perpendicular to up
	var spin := up.cross(lat_dir).normalized()      # spinward tangent
	var flat := (spin * cos(_look.x) + lat_dir * sin(_look.x)).normalized()
	var fwd := (flat * cos(_look.y) + up * sin(_look.y)).normalized()
	_cam.global_transform.basis = Basis.looking_at(fwd, up)

func _ring_up(pos: Vector3) -> Vector3:
	return (Vector3(0.0, _radius(), pos.z) - pos).normalized()


# ---------------------------------------------------------------------------
# VEHICLE DEFINITIONS. Every number the handling model reads lives in a VehicleDef (vehicle_def.gd),
# so adding a vehicle is a data row rather than new movement code -- the only way ~40 of them is a
# fortnight instead of forty separate jobs. A row here overrides the resource's defaults; whatever it
# omits (mass, buoyancy, lift on a plain car) keeps the default. Later a vehicle can be a .tres loaded
# in place of a row without touching this code.
#
# `loco` picks the movement model. Each is a Locomotion function (_loco_<class>); they share the
# ring-frame integration and differ only in how throttle, steering and terrain become velocity.
# Anything not listed falls back to the wheeled model, so a new row is drivable before its class is
# written.
# ---------------------------------------------------------------------------
const VEHICLE_ROWS := {
	"box": {
		# FOR: the runabout you always have. Light and quick to turn on the tarmac, but the first
		# vehicle you own and the one you WANT to trade up from once the road runs out -- it washes
		# out badly off the carriageway, which is the whole reason the warthog exists.
		"purpose": "the runabout you start with — nimble on-road, washes out in the rough",
		"loco": "wheeled", "mass": 1200.0, "power": 9.0, "brake": 12.0, "top": 22.0, "reverse": -6.0,
		"drag": 0.35, "offroad_drag": 0.55, "turn": 1.5, "offroad_turn": 0.45,
		"grip_speed": 12.0, "ride": 0.40, "wheel_r": 0.45, "length": 4.2, "tint": Color(0.33, 0.36, 0.30),
		"susp_travel": 0.34, "susp_stiff": 34.0, "susp_damp": 6.0, "susp_sag": 0.55,
	},
	"warthog": {
		# FOR: the off-roader. Heavier and more powerful, softer springs, keeps its grip where the
		# box lets go -- so it measures worse on the road and far better off it, which is the whole
		# point of having more than one: they must not read the same on the proving course.
		"purpose": "the off-roader — heavy and sure-footed where the box lets go",
		"loco": "wheeled", "mass": 2400.0, "power": 12.0, "brake": 14.0, "top": 27.0, "reverse": -7.0,
		"drag": 0.30, "offroad_drag": 0.34, "turn": 1.3, "offroad_turn": 0.20,
		"grip_speed": 14.0, "ride": 0.55, "wheel_r": 0.52, "length": 5.2, "tint": Color(0.40, 0.44, 0.28),
		"susp_travel": 0.46, "susp_stiff": 26.0, "susp_damp": 5.0, "susp_sag": 0.55,
	},
	# --- Wheeled variants (TASKS.md "Ground"). Same _loco_wheeled model, pure data. They earn their
	# place by spreading the two axes the class actually has: on-road speed vs how hard they wash out
	# once the carriageway ends (offroad_drag/offroad_turn, driven by the _road_cells test). The box
	# and warthog sit in the middle; these push to the corners.
	"sportscar": {
		# FOR: eating the tarmac between towns. Fastest thing on a road and the most punished off it --
		# low, stiff, wide slicks that need speed to bite and find nothing in the dirt. The reason you
		# stay on the carriageway; the opposite end of the axis from the tractor.
		"purpose": "the road car — devours tarmac, helpless the moment the road ends",
		"loco": "wheeled", "mass": 1050.0, "power": 16.0, "brake": 18.0, "top": 42.0, "reverse": -6.0,
		"drag": 0.22, "offroad_drag": 0.95, "turn": 1.8, "offroad_turn": 0.75,
		"grip_speed": 18.0, "ride": 0.26, "wheel_r": 0.34, "length": 4.4, "tint": Color(0.55, 0.18, 0.16),
		"susp_travel": 0.18, "susp_stiff": 48.0, "susp_damp": 8.0, "susp_sag": 0.50,
	},
	"sixby": {
		# FOR: going where the warthog hesitates. Six wheels, tall and slow, barely registers the road
		# ending -- keeps almost all its grip and speed off the tarmac. Ponderous to turn; you point it
		# and it goes. (Placeholder box shows four wheels for now; the geometry is a mesh job.)
		"purpose": "the heavy 6x6 — slow and unstoppable, hardly notices the road ending",
		"loco": "wheeled", "mass": 4200.0, "power": 14.0, "brake": 16.0, "top": 24.0, "reverse": -6.0,
		"drag": 0.34, "offroad_drag": 0.22, "turn": 1.0, "offroad_turn": 0.12,
		"grip_speed": 12.0, "ride": 0.70, "wheel_r": 0.62, "length": 7.0, "tint": Color(0.52, 0.44, 0.30),
		"susp_travel": 0.55, "susp_stiff": 30.0, "susp_damp": 6.0, "susp_sag": 0.55,
	},
	"bike": {
		# FOR: the scout. Lightest, sharpest-turning, bites at low speed so it flicks between obstacles;
		# quick off the line but nervous everywhere -- decent in the rough only because it is small, not
		# because it is planted. The vehicle you take to look, not to fight.
		"purpose": "the scout bike — nimblest and quickest to turn, twitchy and fragile",
		"loco": "wheeled", "mass": 220.0, "power": 14.0, "brake": 13.0, "top": 34.0, "reverse": -4.0,
		"drag": 0.28, "offroad_drag": 0.60, "turn": 2.4, "offroad_turn": 0.55,
		"grip_speed": 8.0, "ride": 0.35, "wheel_r": 0.33, "length": 2.1, "tint": Color(0.18, 0.18, 0.22),
		"susp_travel": 0.30, "susp_stiff": 30.0, "susp_damp": 5.0, "susp_sag": 0.50,
	},
	"tractor": {
		# FOR: the workhorse. Slowest top speed of the lot and it does not care -- huge lugged tyres
		# give it the best grip off the tarmac of anything wheeled, so it plods across ploughed ground
		# the sportscar would bog in. Torque over speed; the honest opposite of the road car.
		"purpose": "the tractor — crawls, but crosses soft ground nothing else will",
		"loco": "wheeled", "mass": 3200.0, "power": 10.0, "brake": 12.0, "top": 12.0, "reverse": -4.0,
		"drag": 0.40, "offroad_drag": 0.18, "turn": 1.2, "offroad_turn": 0.10,
		"grip_speed": 6.0, "ride": 0.75, "wheel_r": 0.80, "length": 4.0, "tint": Color(0.30, 0.45, 0.20),
		"susp_travel": 0.40, "susp_stiff": 24.0, "susp_damp": 5.0, "susp_sag": 0.60,
	},
	"hauler": {
		# FOR: moving mass down a road. Longest and heaviest, a wide turning arc and weak brakes for its
		# weight, and it washes out almost as badly as the sportscar the instant it leaves the tarmac --
		# a load has no traction in dirt. The reason roads matter; needs room and hates the rough.
		"purpose": "the articulated hauler — road-bound freight, ponderous and wide-turning",
		"loco": "wheeled", "mass": 14000.0, "power": 11.0, "brake": 10.0, "top": 26.0, "reverse": -4.0,
		"drag": 0.30, "offroad_drag": 0.85, "turn": 0.7, "offroad_turn": 0.55,
		"grip_speed": 16.0, "ride": 0.60, "wheel_r": 0.55, "length": 14.0, "tint": Color(0.30, 0.36, 0.46),
		"susp_travel": 0.35, "susp_stiff": 40.0, "susp_damp": 7.0, "susp_sag": 0.60,
	},
	# --- Tracked (TASKS.md "Ground"). The FIRST class that is not _loco_wheeled -- a sibling movement
	# model, not a data row. Its whole reason to exist is to be the vehicle roads and gradients do not
	# constrain: it ignores the on/off-road split every wheeled vehicle obeys (one drag, on tarmac and
	# ploughed field alike) and steers at any speed, so it claws up broken ground the sportscar bogs in.
	# offroad_drag/offroad_turn/grip_speed are left 0 to SAY the model does not read them.
	"crawler": {
		# FOR: the ground everything else refuses. Slow, heavy, and utterly indifferent to whether it
		# is on a road -- it plods up the steep, broken patches (where --align says the slope actually
		# bites) that stop wheels dead. You take it not to travel but to go somewhere untravellable.
		"purpose": "the tracked crawler — slow and road-blind, climbs the broken ground wheels can't",
		"loco": "tracked", "mass": 9000.0, "power": 9.0, "brake": 12.0, "top": 9.0, "reverse": -4.0,
		"drag": 0.35, "offroad_drag": 0.0, "turn": 1.4, "offroad_turn": 0.0,
		"grip_speed": 0.0, "ride": 0.55, "wheel_r": 0.50, "length": 6.5, "tint": Color(0.34, 0.36, 0.32),
		"susp_travel": 0.30, "susp_stiff": 40.0, "susp_damp": 7.0, "susp_sag": 0.55,
	},
	# --- Hover / ground-effect (TASKS.md "Ground"). A THIRD movement class, _loco_hover -- no wheel, no
	# track, no ground grip. Like tracked it ignores the road/offroad split; unlike ANYTHING else it
	# crosses water, which is the whole point: it is the class that turns a coastal patch from 5%
	# drivable into all of it. Its price is gradients -- it cannot climb and slides down cross-slopes,
	# the exact inverse of the crawler. offroad_drag/offroad_turn/grip_speed/susp_* are 0: unread.
	"skiff": {
		# FOR: the water and the flats. Fast and frictionless over the sea, the salt pans and the
		# carriageway alike -- the one vehicle that makes the coastal patches (palawan 5% drivable,
		# cape 8%, lofoten 10%) reachable. Helpless on a hill: point it up a grade and it wallows,
		# point it across one and it slides. You take it to the coast, never to the mountains.
		"purpose": "the hover skiff — crosses water and flats at speed, wallows and slides on any slope",
		"loco": "hover", "mass": 800.0, "power": 11.0, "brake": 10.0, "top": 30.0, "reverse": -6.0,
		"drag": 0.30, "offroad_drag": 0.0, "turn": 1.3, "offroad_turn": 0.0,
		"grip_speed": 0.0, "ride": 1.40, "wheel_r": 0.45, "length": 4.6, "tint": Color(0.24, 0.40, 0.46),
		"lift": 1.0, "buoyancy": 0.0,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	# --- Boats (TASKS.md "Water"). The FIFTH movement class, _loco_boat, and the first that cannot go
	# everywhere: it needs water under it. It exists now because the sea does -- the ocean used to be a
	# flat clamp at SEA_LEVEL, indistinguishable from a salt pan, and the hover skiff already crossed
	# that. With a swell to ride there is finally something a hull does that a cushion does not.
	# The two rows are a real mechanical split, not two sets of numbers: PLANING vs DISPLACEMENT.
	"launch": {
		# FOR: crossing open water fast, and being punished for it in a sea. Gets over plane_speed,
		# climbs onto its own bow wave and sheds most of its drag -- then skates through every turn
		# (high drift) and pitches hard on the swell because a planing hull slams rather than parts.
		# Shallow draft, so it can be driven right up a beach before it grounds.
		"purpose": "the planing launch — fast over open water, skates through turns, slams in a swell",
		"loco": "boat", "mass": 1400.0, "power": 8.0, "brake": 4.0, "top": 26.0, "reverse": -4.0,
		"drag": 0.55, "offroad_drag": 0.0, "turn": 1.1, "offroad_turn": 0.0,
		"grip_speed": 6.0, "ride": 0.55, "wheel_r": 0.45, "length": 6.0, "tint": Color(0.72, 0.70, 0.64),
		"lift": 0.0, "buoyancy": 1.0, "draft": 0.8, "plane_speed": 9.0, "drift": 0.8,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	"barge": {
		# FOR: the opposite argument. A displacement hull makes a wave and is held down by it, so it has
		# no plane to climb onto and `top` is a hard ceiling however long you hold the throttle. In
		# exchange the swell barely moves it and it tracks straight (low drift). Deep draft: it grounds
		# a long way off the beach, which is what makes shallow water a real obstacle rather than
		# scenery -- and the reason the coastal patches need reading as depth, not as "sea".
		"purpose": "the displacement barge — slow, deep, unbothered by swell; grounds far off the beach",
		"loco": "boat", "mass": 9000.0, "power": 2.2, "brake": 1.6, "top": 8.0, "reverse": -2.0,
		"drag": 0.30, "offroad_drag": 0.0, "turn": 0.55, "offroad_turn": 0.0,
		"grip_speed": 3.0, "ride": 0.70, "wheel_r": 0.45, "length": 14.0, "tint": Color(0.36, 0.33, 0.28),
		"lift": 0.0, "buoyancy": 1.0, "draft": 2.4, "plane_speed": 0.0, "drift": 0.25,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	# --- Legged (TASKS.md "Mounts and legged"). The FOURTH movement class, _loco_legged, and the one
	# genuinely new movement model: gait, not roll. Shared by mounts and mechs -- this row is the class
	# exemplar; the horse, elephant, mech and powered-suit rows are the FOLLOWING items, each pure data
	# on this model (a mech is this with a longer stride and a taller step). Like tracked it ignores the
	# road/offroad split (one drag term); unlike anything it CLIMBS -- holds speed up a grade and steps
	# over roughness up to step_height that stops a wheel dead. offroad_*/grip_speed/susp_* are 0: unread.
	"strider": {
		# FOR: the ground even the crawler refuses -- steep, stepped, broken terrain where tracks lose
		# purchase. Legs place feet: it climbs onto a kerb, strides over a washboard, and holds its pace
		# up a slope that washes out anything wheeled. Slow and exposed, but nothing is unreachable to it.
		# The chassis the mounts and mechs are built on.
		"purpose": "the legged strider — climbs and steps over ground no wheel or track will cross",
		"loco": "legged", "mass": 1600.0, "power": 10.0, "brake": 12.0, "top": 11.0, "reverse": -4.0,
		"drag": 0.35, "offroad_drag": 0.0, "turn": 1.6, "offroad_turn": 0.0,
		"grip_speed": 0.0, "ride": 1.20, "wheel_r": 0.45, "length": 3.4, "tint": Color(0.42, 0.34, 0.40),
		"step_height": 0.9, "gait": 2.4,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	# --- Horse (TASKS.md "Mounts and legged"). The first MOUNT: pure data on _loco_legged EXCEPT for the
	# two traits that make it a horse and not a strider, and both are data too -- `stamina`/`winded_top`
	# switch on the tire mechanic, `spooks` on the bolt. A living animal, so it is fast but cannot hold the
	# gallop, and a closing wolf (the [J] pack, which already sets _threat_active) makes it run itself. The
	# creature system exists (deer/wolves), so the mount and the herd meet here rather than being two builds.
	"horse": {
		# FOR: covering open ground FAST when there is no road -- the legged answer to the sportscar, but
		# alive. It out-runs every wheeled vehicle cross-country in a sprint, then blows: hold the gallop and
		# it winds itself down to a walk until it recovers, so distance is paced, not floored. And it is not
		# fully yours -- a wolf pack closing (press [J] in DRIVE) spooks it into bolting where you didn't ask.
		"purpose": "the horse — fastest thing off-road in a sprint, but it tires and it spooks",
		"loco": "legged", "mass": 600.0, "power": 15.0, "brake": 11.0, "top": 18.0, "reverse": -3.0,
		"drag": 0.40, "offroad_drag": 0.0, "turn": 1.9, "offroad_turn": 0.0,
		"grip_speed": 0.0, "ride": 1.50, "wheel_r": 0.45, "length": 2.4, "tint": Color(0.36, 0.24, 0.16),
		"step_height": 0.5, "gait": 2.8,
		"stamina": 14.0, "winded_top": 6.0, "spooks": true,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	# --- Elephant (TASKS.md "Elephants"). Pure data on _loco_legged like the strider/horse EXCEPT for one
	# new switch: `trample`. It is the mount that makes the hedge and tree systems DESTRUCTIBLE -- slow and
	# unstoppable, it flattens small trees and hedgerows it walks through (see _do_trample). Tireless
	# (stamina 0) and fearless (spooks false), the opposite of the horse: it does not run and it does not
	# panic, it just keeps going. Legged, so it climbs and steps like the strider; the trample is the only
	# thing genuinely its own, and it is switched on by data, so every other row stays untouched.
	"elephant": {
		# FOR: going through, not around. Where the horse flees and the wheeled rows detour, the elephant
		# holds a straight line and the obstacle gives way -- hedgerows and saplings go down under it. Slow,
		# heavy, unhurried; you take it to make a path, not to make time.
		"purpose": "the elephant — slow and unstoppable, flattens hedgerows and small trees in its path",
		"loco": "legged", "mass": 5200.0, "power": 8.0, "brake": 9.0, "top": 7.5, "reverse": -2.5,
		"drag": 0.45, "offroad_drag": 0.0, "turn": 0.9, "offroad_turn": 0.0,
		"grip_speed": 0.0, "ride": 2.6, "wheel_r": 0.45, "length": 6.0, "tint": Color(0.44, 0.42, 0.40),
		"step_height": 1.2, "gait": 4.6, "trample": 4.0,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	# --- Mechs (TASKS.md "Mounts and legged"). Pure data on _loco_legged like the strider/horse/elephant --
	# no movement code, exactly the abstraction's payoff. The item names the two axes and only those: form
	# (bipedal vs quadrupedal) and scale (3m to 15m), and both resolve to the two fields the class already
	# reads -- mass and step_height. The biped is the small, agile end; the quad the 15m walking-fortress
	# end. Tireless and fearless machines: stamina 0 / spooks false / trample 0 (the item asks only for a
	# different mass and step height, so the elephant keeps destructibility to itself). offroad_*/grip_speed/
	# susp_* stay 0: the legged model reads none of them. Placeholder box still shows wheels -- a mesh job,
	# same caveat as the strider and sixby.
	"mech_biped": {
		# FOR: the war-walker at soldier scale -- roughly a tall man, so it goes where infantry goes but
		# armoured and stepping. Tall legs give it the highest step of anything but the quad: it climbs onto
		# a wall or a roof a strider only steps over. Quicker and lighter than the giant; the skirmisher of
		# the legged rows, sitting between the strider's civilian chassis and the quad's fortress.
		"purpose": "the biped mech — man-scale war walker, climbs onto walls and roofs, agile for its armour",
		"loco": "legged", "mass": 3600.0, "power": 12.0, "brake": 13.0, "top": 13.0, "reverse": -4.0,
		"drag": 0.35, "offroad_drag": 0.0, "turn": 1.5, "offroad_turn": 0.0,
		"grip_speed": 0.0, "ride": 2.0, "wheel_r": 0.45, "length": 3.0, "tint": Color(0.30, 0.32, 0.34),
		"step_height": 1.5, "gait": 3.0,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	"mech_quad": {
		# FOR: the 15m end of the scale -- a four-legged walking fortress. Vast mass makes it ponderous and
		# slow to turn, but its stride steps clean over walls, hedgerows and small buildings that stop every
		# other vehicle, and it never washes out or slides. The heaviest thing in the roster (past the
		# hauler); you take it not to travel but to be the terrain other things route around.
		"purpose": "the quad mech — a 15m walking fortress, strides over walls and buildings, slow and unstoppable",
		"loco": "legged", "mass": 42000.0, "power": 9.0, "brake": 9.0, "top": 6.0, "reverse": -2.0,
		"drag": 0.45, "offroad_drag": 0.0, "turn": 0.6, "offroad_turn": 0.0,
		"grip_speed": 0.0, "ride": 6.5, "wheel_r": 0.45, "length": 15.0, "tint": Color(0.26, 0.27, 0.29),
		"step_height": 3.2, "gait": 7.0,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	# --- Powered suit (TASKS.md "Powered suits"). The LAST legged row and the one that blurs the DRIVE/WALK
	# line: the player IS the vehicle, not something you climb into. Pure data on _loco_legged like the
	# strider/mech EXCEPT for the two traits this item names that nothing else in the roster has -- it JUMPS
	# and it SPRINTS -- and BOTH are switched on by data (jump/sprint), so every other row and class stays
	# untouched (the no-change gate holds). Man-scale: light, quick to turn, a large man's step and stride.
	# A machine, so tireless/fearless (stamina 0 / spooks false / trample 0). Jump/sprint are player-triggered
	# (Space/Shift in DRIVE, the FLY-rise and WALK-run keys, so it feels like on-foot), which means --proving
	# does not exercise them -- exactly as the horse's spook needs [J] rather than showing on the course.
	"suit": {
		# FOR: the bridge between driving and walking -- the capability you keep when the vehicles run out.
		# Slow flat-out but it JUMPS onto ledges and over gaps nothing else clears, and SPRINTS in bursts;
		# lands hard, so a big drop costs speed. You wear it to go on foot where a vehicle cannot follow.
		"purpose": "the powered suit — you ARE the vehicle: jump onto ledges, sprint in bursts, land hard",
		"loco": "legged", "mass": 320.0, "power": 16.0, "brake": 16.0, "top": 12.0, "reverse": -5.0,
		"drag": 0.35, "offroad_drag": 0.0, "turn": 2.6, "offroad_turn": 0.0,
		"grip_speed": 0.0, "ride": 1.1, "wheel_r": 0.45, "length": 1.2, "tint": Color(0.36, 0.38, 0.42),
		"step_height": 0.6, "gait": 1.8,
		"jump": 3.2, "sprint": 2.0,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	# --- Amphibious + submersible (TASKS.md "Water"). The SIXTH movement class, _loco_sub, and the first to
	# treat DEPTH as a driven axis. It exists because the seabed now does: Terrarium floors its tiles at 0, so
	# there was nowhere to descend -- rather than block on a GEBCO download the floor is SYNTHESISED from the
	# coastline plus noise (see _sea_depth / .decisions/terrain.md#synthetic-seabed), exactly as this project
	# generates its houses, hedges and palms. The class is amphibious by construction (it crawls ashore where a
	# hull grounds); `dive_max` is the data switch that also makes a row go under. Two rows split the pairing:
	# a surface amphibian that stitches the shoreline, and a deep submersible that uses the new seabed.
	"duck": {
		# FOR: never swapping vehicle at the waterline. It drives down a beach, floats off, motors across the
		# shallows and climbs out the far side -- the one craft that makes a coastal patch one continuous drive
		# rather than a car for the dry half and a boat for the wet. Ducks just under the surface, no deeper.
		"purpose": "the amphibian — drives straight across the waterline, land to sea to land, ducks just under",
		"loco": "sub", "mass": 1600.0, "power": 9.0, "brake": 10.0, "top": 14.0, "reverse": -5.0,
		"drag": 0.45, "offroad_drag": 0.0, "turn": 1.4, "offroad_turn": 0.0,
		"grip_speed": 0.0, "ride": 0.55, "wheel_r": 0.45, "length": 5.4, "tint": Color(0.30, 0.42, 0.38),
		"buoyancy": 1.0, "draft": 0.6, "dive_max": 2.5,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	"sub": {
		# FOR: going DOWN. Slow and heavy on the surface and reluctant on land (it can crawl out but hates it),
		# it earns its place submerged -- the only vehicle that descends to the synthesised seabed and moves
		# along it, so the deep water every other class treats as a flat lid becomes somewhere to go. The reason
		# the seabed had to be synthesised at all; without a floor it would be a boat that can sink.
		"purpose": "the submersible — slow on top, but the only thing that dives to the seabed and runs along it",
		"loco": "sub", "mass": 12000.0, "power": 5.0, "brake": 6.0, "top": 9.0, "reverse": -3.0,
		"drag": 0.40, "offroad_drag": 0.0, "turn": 1.0, "offroad_turn": 0.0,
		"grip_speed": 0.0, "ride": 0.50, "wheel_r": 0.45, "length": 11.0, "tint": Color(0.20, 0.28, 0.34),
		"buoyancy": 1.0, "draft": 2.0, "dive_max": 55.0,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	# --- Air (TASKS.md "Air"). The SEVENTH movement class, _loco_air, and the first that leaves the surface and
	# STAYS off it (the suit only hops). FLY mode is a noclip camera; these obey lift. `lift` is the class switch
	# (>0 flies); stall_speed splits the two rows the item names -- a rotor (0) hovers and never stalls, a
	# fixed-wing (>0) must hold airspeed or drop. Both fall out of the same function, the abstraction's payoff.
	# Thinning air (the atmosphere-exit falloff, reused by _air_density) caps the ceiling for free.
	"rotor": {
		# FOR: going straight up and standing still in the air. It hovers, climbs vertically and pivots on the
		# spot, reaching a ledge or rooftop no wheel or wing can -- the flyer for tight, slow, precise work.
		"purpose": "the rotary — hovers, climbs vertically, pivots in place; slow but goes anywhere and waits there",
		"loco": "air", "mass": 2400.0, "power": 8.0, "brake": 8.0, "top": 28.0, "reverse": -6.0,
		"drag": 0.45, "offroad_drag": 0.0, "turn": 1.3, "offroad_turn": 0.0,
		"grip_speed": 0.0, "ride": 0.6, "wheel_r": 0.5, "length": 9.0, "tint": Color(0.28, 0.30, 0.34),
		"lift": 1.0, "stall_speed": 0.0,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	"airplane": {
		# FOR: covering ground fast. It must keep flying speed or the wing stalls, and it banks through a wide
		# turn, but nothing else on the ring crosses a 3,000 km circumference at this pace -- the long-haul flyer.
		"purpose": "the fixed-wing — fast and far, but must hold airspeed or stall and banks through a wide turn",
		"loco": "air", "mass": 3200.0, "power": 12.0, "brake": 6.0, "top": 90.0, "reverse": 0.0,
		"drag": 0.12, "offroad_drag": 0.0, "turn": 1.1, "offroad_turn": 0.0,
		"grip_speed": 40.0, "ride": 0.5, "wheel_r": 0.5, "length": 11.0, "tint": Color(0.40, 0.40, 0.44),
		"lift": 1.0, "stall_speed": 30.0,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
	"lifter": {
		# FOR: getting OUT. Neither row above can -- their lift dies with the air just over the rim wall, which is the
		# ceiling working as designed, not a bug. This one carries thrusters (rcs), so as the wing gives up the
		# reaction control takes over and the same stick keeps flying it. The trade is that it is a poor
		# aircraft: heavy, draggy, a high stall speed and a wide turn, all of which stop mattering the moment
		# the air does. Down low the airplane beats it everywhere; over the wall it is the only thing still flying.
		"purpose": "the lifter — a mediocre aeroplane and the only craft that keeps flying once the air runs out",
		"loco": "air", "mass": 9000.0, "power": 16.0, "brake": 6.0, "top": 120.0, "reverse": 0.0,
		"drag": 0.22, "offroad_drag": 0.0, "turn": 0.7, "offroad_turn": 0.0,
		"grip_speed": 60.0, "ride": 0.7, "wheel_r": 0.6, "length": 16.0, "tint": Color(0.52, 0.50, 0.46),
		"lift": 0.85, "stall_speed": 45.0, "rcs": 7.0,
		"susp_travel": 0.0, "susp_stiff": 0.0, "susp_damp": 0.0, "susp_sag": 0.0,
	},
}

func _build_vehicle_defs() -> void:
	# Turn each data row into a typed VehicleDef, applying the row over the resource's defaults.
	for name in VEHICLE_ROWS:
		var d := VehicleDef.new()
		for k in VEHICLE_ROWS[name]:
			d.set(k, VEHICLE_ROWS[name][k])
		_vehicle_defs[name] = d

func _vdef() -> VehicleDef:
	# current vehicle's parameters, falling back to the box so an unregistered vehicle still drives
	if _vehicle_defs.is_empty():
		_build_vehicle_defs()
	var name := str(_vehicles[_veh_idx]["name"]) if not _vehicles.is_empty() else "box"
	return _vehicle_defs.get(name, _vehicle_defs["box"])

func _loco_wheeled(d: VehicleDef, delta: float, accel: float, steer: float) -> void:
	# Grip and drag scale with how far off the tarmac we are. Everything here reads from `d`, so a
	# tracked or hover model is a sibling _loco_<class> function rather than an edit to this one.
	_car_speed = clampf(_car_speed + accel * delta, d.reverse, d.top)
	_car_speed *= 1.0 - (d.drag + d.offroad_drag * _offroad) * delta
	var bite: float = d.turn - d.offroad_turn * _offroad
	_car_heading += steer * bite * delta 		* clampf(absf(_car_speed) / d.grip_speed, 0.0, 1.0) * signf(_car_speed)
	_car_arc += cos(_car_heading) * _car_speed * delta
	_car_lat += sin(_car_heading) * _car_speed * delta

func _loco_tracked(d: VehicleDef, delta: float, accel: float, steer: float) -> void:
	# Tracks, not wheels. Two deliberate departures from _loco_wheeled, and they ARE the class:
	# (1) it ignores the road/offroad split everything else obeys -- ONE drag term, no offroad_drag,
	#     so tarmac and a ploughed field damp the same. A tank does not care about the carriageway.
	# (2) skid-steer: full turn authority at any speed (no grip_speed ramp), so it pivots on the spot
	#     and keeps steering while crawling. That, plus keeping all its speed off-road, is why it owns
	#     the steep broken patches -- the climb phase pins _offroad=1 and this model simply doesn't read
	#     it, where the wheeled model washes out. Slow is data (low `top`); unstoppable is geometry.
	# _offroad is still computed by _drive_tick for the dust plume; the handling just never consults it.
	_car_speed = clampf(_car_speed + accel * delta, d.reverse, d.top)
	_car_speed *= 1.0 - d.drag * delta
	_car_heading += steer * d.turn * delta
	_car_arc += cos(_car_heading) * _car_speed * delta
	_car_lat += sin(_car_heading) * _car_speed * delta

# Gradient response is the hover class trait (every cushion craft hates a slope for the same reason),
# so it lives as constants here rather than per-vehicle data -- a skiff's numbers can move to VehicleDef
# the day a second hover vehicle needs to differ. PULL: uphill deceleration per unit of along-track
# slope. SLIDE: sideways drift speed per unit of cross-track slope.
const HOVER_SLOPE_PULL := 18.0
const HOVER_SLOPE_SLIDE := 12.0

func _loco_hover(d: VehicleDef, delta: float, accel: float, steer: float) -> void:
	# Ground-effect, not wheels or tracks. Three departures, and together they ARE the class:
	# (1) no ground grip and no road/offroad split -- ONE drag term (d.drag), so sea, salt pan and
	#     tarmac all glide the same. That is what "crosses water" means here: the ocean is a flat clamp
	#     at SEA_LEVEL and _car_pos already floats the body ON it (via _terrain_h's clamp), so the skiff
	#     runs over water exactly as over a road -- the one class that makes a 90%-ocean coastal patch
	#     drivable rather than a 5% sliver of beach.
	# (2) full turn authority at any speed (no grip_speed ramp), like tracked -- it yaws freely.
	# (3) it HATES gradients, the exact inverse of the crawler. A cushion has nothing to grip a slope
	#     with, so gravity along the surface is its master: it bleeds speed climbing, gains it
	#     descending (cannot climb a real grade), and slides bodily down any cross-slope regardless of
	#     where it is pointed. Over open water the surface is flat, so none of this bites -- which is
	#     why it owns the coast and wallows in the mountains.
	_car_speed = clampf(_car_speed + accel * delta, d.reverse, d.top)
	_car_speed *= 1.0 - d.drag * delta
	_car_heading += steer * d.turn * delta
	# surface gradient in ring space (metres of rise per metre travelled), central-differenced. Reads
	# the clamped _terrain_h, so the sea is flat (zero gradient) and shorelines are a wall it slides along.
	var e := 3.0
	var dh_arc := (_terrain_h(_car_arc + e, _car_lat) - _terrain_h(_car_arc - e, _car_lat)) / (2.0 * e)
	var dh_lat := (_terrain_h(_car_arc, _car_lat + e) - _terrain_h(_car_arc, _car_lat - e)) / (2.0 * e)
	# split the slope into along-heading and cross-heading components. left unit in (arc,lat) = (-sin,cos)
	var ch := cos(_car_heading)
	var sh := sin(_car_heading)
	var g_fwd := dh_arc * ch + dh_lat * sh          # +uphill ahead: bleed momentum, cannot climb
	var g_side := -dh_arc * sh + dh_lat * ch        # slope across the beam: drift down it, not carve it
	_car_speed -= HOVER_SLOPE_PULL * g_fwd * delta
	# forward motion plus a bodily downhill slide along the beam (downhill on the left axis = -g_side)
	var slide := -g_side * HOVER_SLOPE_SLIDE
	_car_arc += (ch * _car_speed + (-sh) * slide) * delta
	_car_lat += (sh * _car_speed + (ch) * slide) * delta

# Boat trim: how hard the swell throws the hull about. Class constants like the hover slope terms --
# a hull's response to a wave is hull shape, and every displacement hull answers a 1m swell much the
# same way. PITCH/ROLL convert wave slope (m per m) to radians of body attitude.
const BOAT_PITCH := 2.2
const BOAT_ROLL := 1.8
const BOAT_GROUND_DRAG := 6.0     # how violently a hull stops when it runs aground

func _loco_boat(d: VehicleDef, delta: float, accel: float, steer: float) -> void:
	# A HULL IN WATER -- the fifth movement class, and the first one that can be somewhere it cannot
	# go. Four departures, and together they are the class:
	#
	# (1) IT NEEDS WATER. Every other class can be put down anywhere on the ring and will move. Run a
	#     boat at the beach and the hull touches: it grounds, dumps speed and stops steering. That is
	#     why this item was gated on a water surface existing at all -- before the swell, "sea" was a
	#     flat clamp indistinguishable from a salt pan, and the skiff already crossed it.
	# (2) RUDDER, NOT STEERING. Turn authority is proportional to speed through the water, because a
	#     rudder is a wing and a stationary rudder does nothing. This is the exact inverse of the
	#     tracked/hover classes, which pivot on the spot: a boat with no way on cannot be turned, and
	#     a boat that has just cut its engine still can, until it loses steerage.
	# (3) IT DRIFTS. Every land class moves exactly along its heading -- `_car_arc += cos(heading) *
	#     speed`. A hull does not. It carries a velocity VECTOR that the heading only slowly pulls
	#     round, so it skates wide through a turn and crabs on. That is why _boat_vel exists rather
	#     than reusing _car_speed alone.
	# (4) DISPLACEMENT VS PLANING is a data row, not two functions. A displacement hull is held to its
	#     hull speed by the wave it makes; a planing hull that gets over plane_speed climbs onto its
	#     own bow wave and the drag falls away. Same code, two rows.
	var depth := _sea_depth(_car_arc, _car_lat)
	_aground = depth < d.draft
	_car_speed = clampf(_car_speed + accel * delta, d.reverse, d.top)
	# planing: over the threshold the hull lifts and sheds most of its wavemaking drag
	var planing: bool = d.plane_speed > 0.0 and absf(_car_speed) > d.plane_speed
	var drag: float = d.drag * (0.35 if planing else 1.0)
	if _aground:
		# keel in the mud. Bleed speed hard and lose the rudder with it.
		drag += BOAT_GROUND_DRAG * clampf((d.draft - depth) / maxf(d.draft, 0.1), 0.0, 1.0)
	_car_speed *= 1.0 - drag * delta
	# rudder authority: needs water flowing past it. grip_speed is reused as "steerage way".
	var steerage := clampf(absf(_car_speed) / maxf(d.grip_speed, 0.1), 0.0, 1.0)
	if _aground:
		steerage = 0.0
	_car_heading += steer * d.turn * delta * steerage * signf(_car_speed)
	# The hull's velocity vector chases the heading rather than snapping to it. drift=0 reproduces the
	# land classes exactly (velocity is always along the nose), so this one function still covers a
	# rigid-inflatable that does not skate.
	var want := Vector2(cos(_car_heading), sin(_car_heading)) * _car_speed
	if d.drift > 0.0:
		# larger drift = slower to settle onto the new course = more skating
		_boat_vel = _boat_vel.lerp(want, 1.0 - exp(-delta * (6.0 / maxf(d.drift, 0.01))))
	else:
		_boat_vel = want
	_car_arc += _boat_vel.x * delta
	_car_lat += _boat_vel.y * delta

func _boat_trim(d: VehicleDef, delta: float) -> void:
	# Attitude from the swell: sample the live water surface fore/aft and abeam and let the hull lie on
	# the slope between, the same idea as the wheeled suspension's contact plane but with two samples
	# per axis instead of four wheels. Uses _surface_h, NOT _terrain_h -- the whole point is to ride
	# the water that is actually drawn.
	var half: float = maxf(d.length, 1.0) * 0.5
	var ch := cos(_car_heading)
	var sh := sin(_car_heading)
	var bow := _surface_h(_car_arc + ch * half, _car_lat + sh * half)
	var stern := _surface_h(_car_arc - ch * half, _car_lat - sh * half)
	var port := _surface_h(_car_arc - sh * half, _car_lat + ch * half)
	var stbd := _surface_h(_car_arc + sh * half, _car_lat - ch * half)
	_body_pitch = lerpf(_body_pitch, clampf((stern - bow) / (2.0 * half) * BOAT_PITCH, -0.4, 0.4), delta * 5.0)
	_body_roll = lerpf(_body_roll, clampf((port - stbd) / (2.0 * half) * BOAT_ROLL, -0.4, 0.4), delta * 5.0)

# Submersible class constants (see .decisions/terrain.md#synthetic-seabed), like the hover/boat terms.
# SUB_DIVE is how fast it changes depth (m/s); SUB_KEEL keeps the hull that far off the synthesised seabed
# so it never clips through; SUB_LAND_FRAC is the share of its water top speed it keeps while crawling ashore.
const SUB_DIVE := 3.5
const SUB_KEEL := 1.2
const SUB_LAND_FRAC := 0.4

func _loco_sub(d: VehicleDef, delta: float, accel: float, steer: float) -> void:
	# AMPHIBIOUS + SUBMERSIBLE -- the SIXTH movement class and the first to treat DEPTH as a driven axis.
	# It exists because the seabed now does: there was nowhere to descend until _sea_depth synthesised a
	# floor (Terrarium floors its tiles at 0, so no real bathymetry). This function is the HORIZONTAL half;
	# the dive is integrated in _drive_tick where the vertical keys live, exactly as the suit's jump is.
	# Two traits make it the class:
	# (1) AMPHIBIOUS. Unlike the boat it does NOT ground helplessly. Where there is water to float in it
	#     propels at `top`; on land or in shallows too thin to float it CRAWLS at SUB_LAND_FRAC of that --
	#     one drag term either way -- so it drives down a beach, off into the water and out the far side,
	#     stitching a coastal patch's land and sea into one drive instead of a car for the dry half and a
	#     boat for the wet. That is the inverse of _loco_boat, which loses way and rudder the moment it grounds.
	# (2) full turn authority at any speed, submerged or crawling (no grip_speed ramp), like tracked/hover.
	# The SUBMERSIBLE half -- descending to the synthesised seabed -- is _drive_tick's dive integration,
	# gated on d.dive_max; a row with dive_max 0 is a pure amphibian that never leaves the surface.
	var depth := _sea_depth(_car_arc, _car_lat)
	var afloat := depth > d.draft
	_aground = false   # amphibious: never stuck -- it crawls where a hull would be beached
	var top := d.top if afloat else d.top * SUB_LAND_FRAC
	_car_speed = clampf(_car_speed + accel * delta, d.reverse, top)
	_car_speed *= 1.0 - d.drag * delta
	_car_heading += steer * d.turn * delta
	_car_arc += cos(_car_heading) * _car_speed * delta
	_car_lat += sin(_car_heading) * _car_speed * delta

# Air-flight class constants (TASKS.md "Air" / "Ring-specific flight"), like the hover/boat/sub terms. A naive but
# honest model: lift vs weight decides whether it holds altitude, thinning air sets the ceiling, ground effect
# floats it near the deck. RING-SPECIFIC: "gravity" is the full spinning-frame reaction -- centrifugal spin
# gravity (omega^2 * r) plus the Coriolis and centripetal coupling of the ring-relative orbital model -- see
# _loco_air. AIR_GRAVITY is the SURFACE spin gravity (r = _radius()); omega and the ~2.1 km/s spin speed derive
# from it (_spin_omega). Only the UNPOWERED free-flight projectile (a rifle round in ballistic fall while the
# ring spins under it) stays the WEAPONS programme's job; a powered craft flies the coupling here.
const AIR_GRAVITY := 9.0          # SURFACE spin gravity (omega^2 * R), m/s^2; the orbital model in _loco_air builds on it
const AIR_LIFT := 11.0            # lift authority scale, tuned so a fixed-wing near stall / a rotor at neutral holds level
const AIR_VDRAG := 0.8            # vertical-speed damping, so climb and sink settle rather than run away
const AIR_GROUND_EFFECT := 0.6    # extra lift fraction riding the cushion at zero height, faded out over a wingspan
const AIR_STALL_LIFT := 0.2       # lift a stalled wing keeps below stall_speed -- enough to fall with, not to fly
const AIR_ELEVATOR := 6.0         # m/s of climb/descent the pilot commands with Space/Shift
const AIR_TRADE := 0.10           # airspeed a fixed-wing trades per m/s climbed (pull up -> bleed speed -> stall)
const AIR_BANK := 0.7             # radians a fixed-wing visibly rolls into a full-authority turn

func _air_density(alt: float) -> float:
	# Reuse the atmosphere-exit falloff (_space_lo().._space_hi(), the SAME smoothstep that fades haze/sky to vacuum
	# in _process) so lift and the sky agree on where the air is: 1 at the surface, 0 above the wall top. This is the
	# item's payoff -- "the atmosphere-exit work already models thinning air" -- so a long enough climb runs the
	# wing out of air and gives a natural ceiling, not a hard clamp.
	return 1.0 - smoothstep(_space_lo(), _space_hi(), alt)

func _spin_omega() -> float:
	# Ring spin rate. AIR_GRAVITY is the SURFACE spin gravity omega^2*R, so omega = sqrt(g/R), and the surface
	# speed omega*R = sqrt(g*R) ~ 2.1 km/s at the ~477 km radius -- the number "Ring-relative orbital mechanics"
	# quotes. One source for every ring-frame term (orbital gravity in _loco_air, the HUD ground-track readout).
	return sqrt(AIR_GRAVITY / _radius())

# Docking at an axis structure (TASKS.md "Docking / boarding"; substrate.md places the leave-ending hub at
# a fixed (lon,lat) reaching toward the axis). The port is PART OF THE RING, so it is ground-fixed in the
# rotating frame -- docking is therefore the "match the spin and hover over one spot" case the orbital item
# named: arrive within the capture envelope with your ring-frame velocity nulled (GROUND ~ 0). Only the air
# class can reach it, so nothing else reads these. DOCK_ALT is a placeholder height -- a spire reaching TOWARD
# the axis, not at it (the true axis is r=R ~477km, an authored-geometry + look-at-it call like the wall/atmo
# knobs); 8km sits clear above the 4km default ceiling, so the approach is in vacuum, flown on the RCS.
const DOCK_ARC := 0.0            # fixed ring arc of the port -- climb straight up over the spawn origin (arc 0)
const DOCK_LAT := 0.0            # on the centreline
const DOCK_ALT := 8000.0         # metres toward the axis (placeholder; above the atmosphere = an RCS approach)
const DOCK_CAPTURE_R := 150.0    # metres: within this range of the port, a matched craft soft-captures
const DOCK_MATCH_V := 6.0        # m/s: ring-frame closing speed under this counts as matched (else you sail past)

func _dock_range() -> float:
	# straight-line ring-space distance (m) from the flyer to the fixed axis-structure port
	var circ: float = CIRCUMFERENCES[c_idx]
	var da: float = wrapf(_car_arc - DOCK_ARC, -circ * 0.5, circ * 0.5)
	return Vector3(da, _car_lat - DOCK_LAT, _altitude - DOCK_ALT).length()

func _dock_update(accel: float, elevator: float) -> bool:
	# DOCKING (TASKS.md). Called only from the air dispatch arm, so no other class touches it. Returns true when
	# the craft is HELD at the port, telling the caller to skip flight integration this frame. The port is
	# ground-fixed in the rotating frame, so "matched" means the ring-frame velocity is nulled -- exactly the
	# orbital item's "match the spin and hover over one spot", reusing _air_vel/_vspeed as the closing velocity.
	if _docked:
		# any pilot command (throttle or elevator/RCS) casts off and hands control back; boarding blocks that
		if not _boarded and (absf(accel) > 0.01 or absf(elevator) > 0.01):
			_docked = false
			_boarded = false
			return false
		# HELD: snap onto the port and freeze every driven axis, so it station-keeps exactly
		_car_arc = DOCK_ARC
		_car_lat = DOCK_LAT
		_altitude = DOCK_ALT
		_air_vel = Vector2.ZERO
		_vspeed = 0.0
		_car_speed = 0.0
		return true
	# SOFT CAPTURE: close enough to the port AND slow enough relative to it (the port is stationary in this frame)
	var closing := Vector3(_air_vel.x, _air_vel.y, _vspeed).length()
	if _dock_range() < DOCK_CAPTURE_R and closing < DOCK_MATCH_V:
		_docked = true
		_service_vehicle()   # the port refuels and repairs -- see _service_vehicle for why only here
		return true
	return false

func _loco_air(d: VehicleDef, delta: float, accel: float, steer: float, elevator: float) -> void:
	# ACTUAL FLIGHT -- the SEVENTH movement class, and the first to leave the surface and STAY off it (the suit's
	# jump is a sub-second hop; this holds altitude). FLY mode is a noclip camera; this is a vehicle that obeys
	# lift. Four traits, and together they are the class:
	# (1) LIFT, not drive. It stays up only while the wing works. A fixed-wing's lift is airspeed^2; a rotor makes
	#     its own airflow from power, so it hangs at zero speed -- that ONE difference is why rotary vs fixed-wing
	#     are two DATA rows and not two functions (stall_speed 0 = rotary).
	# (2) STALL. Below stall_speed a fixed-wing's wing lets go (AIR_STALL_LIFT) and it drops; you dive to rebuild
	#     speed, which is why a climb trades airspeed (AIR_TRADE) -- pull up too hard and you stall.
	# (3) GROUND EFFECT. Within a wingspan of the deck the wing rides a cushion and lift rises, so it floats on
	#     take-off and landing -- the item names this one explicitly.
	# (4) THINNING AIR. Lift scales with _air_density, the same atmosphere-exit falloff the sky thins by, so the
	#     ceiling is where the air runs out -- the setting's own physics, for free.
	var rotary := d.stall_speed <= 0.0
	# (5) LEAVING THE ATMOSPHERE (TASKS.md). Everything above is a force against AIR. `q` is how much air
	# there is -- the same _space_lo().._space_hi() curve the sky fades to vacuum by -- so it is also exactly how
	# much of this class still applies. Every aerodynamic term is scaled by q and every reaction-control term
	# by (1 - q), and the handover falls out as one continuous blend rather than a mode switch with a seam:
	# lift, stall, ground effect, the energy trade, the bank and the rudder all fade out together, drag goes
	# with them, and the thrusters fade in. No `if in_space` anywhere.
	var q := _air_density(_altitude)
	var vac := 1.0 - q
	# airspeed on the existing longitudinal axis (W/S throttle). DRAG SCALES WITH THE AIR: in vacuum there is
	# nothing to damp against, so speed persists and this stops being a top-speed problem and starts being a
	# momentum one -- the ballistic handover the item asks for. `top` is an aerodynamic limit, so it lifts as
	# the air thins; thrust above the atmosphere comes from rcs, not the propeller.
	# the same throttle input drives the propeller in air and the thrusters in vacuum
	var thrust: float = accel * q + (accel / maxf(d.power, 0.1)) * d.rcs * vac
	# `top` is an AERODYNAMIC limit (thrust against drag). With no drag there is no terminal velocity, so the
	# ceiling opens out to 10x in vacuum -- still bounded, because an unbounded float here would eventually
	# tunnel the integrator through the ring in one frame, but high enough that the limit is fuel and patience.
	var vmax: float = d.top * (1.0 + 9.0 * vac)
	_car_speed = clampf(_car_speed + thrust * delta, -vmax if d.rcs > 0.0 else d.reverse, vmax)
	_car_speed *= 1.0 - d.drag * q * delta
	# LIFT SOURCE: fixed-wing from airspeed^2 (collapsing below stall); rotor from throttle so it can hover
	var lift_src: float
	if rotary:
		# collective ~ neutral-plus-throttle: at rest it already balances weight (hovers), W climbs, S descends
		lift_src = clampf(0.82 + (accel / maxf(d.power, 0.1)) * 0.40, 0.0, 1.3)
	else:
		var vr := absf(_car_speed) / maxf(d.stall_speed, 0.1)
		lift_src = vr * vr
		if absf(_car_speed) < d.stall_speed:
			lift_src *= AIR_STALL_LIFT   # STALL: the wing lets go and it sinks until it has speed again
	# GROUND EFFECT: a wingspan of extra lift at the deck, faded out with height
	var span := maxf(d.length, 4.0)
	var ge := 1.0 + AIR_GROUND_EFFECT * clampf(1.0 - _altitude / span, 0.0, 1.0)
	# THINNING AIR: lift falls off with the same curve the sky thins by, so the air runs out overhead
	var lift := AIR_LIFT * maxf(d.lift, 0.0) * q * lift_src * ge
	# vertical: lift up, the ring's spin-frame pull down, plus the pilot's elevator, all damped so it settles.
	# RING-RELATIVE ORBITAL MECHANICS (TASKS.md). "Up" is toward the axis and _car_arc is the ground-fixed
	# (rotating) frame, so _air_vel.x is your velocity RELATIVE TO THE GROUND. The honest way to get orbits on a
	# spinning ring is to ask what a free body does in the INERTIAL frame and read it back out here: a body with
	# inertial tangential speed v_i at radius r needs centripetal v_i^2/r to hold that radius, and nothing real
	# provides it (a ringworld has no gravity well), so the net pull toward the floor is exactly v_i^2/r.
	#   v_i = (ground-relative arc speed) + (co-rotation speed omega*r)
	# That ONE term is spin gravity, Coriolis and centripetal at once, and every case the item names falls out:
	#   - hover, matched to the spin (v_arc = 0): pull = (omega*r)^2/r = omega^2*r = the surface gravity you
	#     hold with thrust -- identical to the old constant model, so low flight is unchanged.
	#   - fly PROGRADE (v_arc > 0): v_i rises, the floor pulls harder -- the ring throws you down.
	#   - fly RETROGRADE at v_arc = -omega*r: v_i = 0, you are inertially still, pull = 0, you hold altitude with
	#     no thrust while the ring streams past beneath you at omega*R (~2.1 km/s). That IS the orbit.
	# It still weakens toward the axis (r -> 0) and flips past it (r < 0 pulls to the far surface), so the
	# previous item's "a long enough climb crosses to the far side" is preserved, now for the right reason.
	var omega := _spin_omega()
	var rr := _radius() - _altitude                                             # radius from the spin axis; up shrinks it
	var rr_safe: float = maxf(rr, 1000.0) if rr >= 0.0 else minf(rr, -1000.0)   # guard the axis singularity (unreachable by wing)
	var v_arc := _air_vel.x                                                     # ground-relative arc speed (rotating frame)
	var v_i := v_arc + omega * rr                                               # INERTIAL tangential speed
	var g_eff: float = clampf((v_i * v_i) / rr_safe, -200.0, 200.0)             # net floor-ward pull; clamp keeps the integrator sane near the axis
	# The elevator is a control SURFACE -- it needs air over it. In vacuum the same stick input feeds the
	# vertical thrusters instead, which is the whole "reaction control instead of aerodynamics" swap. Note the
	# thruster is NOT scaled by airspeed: an RCS jet works standing still, which is exactly why it is the only
	# thing that can point you when the wing has nothing to bite on.
	var vctl: float = elevator * (AIR_ELEVATOR * q + d.rcs * vac)
	_vspeed += (lift - g_eff + vctl) * delta
	# vertical damping is air resistance too -- without it a ballistic arc would be damped by nothing at all,
	# which is the point: above the atmosphere you coast, and only gravity and the thrusters change that.
	_vspeed *= 1.0 - AIR_VDRAG * q * delta
	# ENERGY EXCHANGE (fixed-wing): a climb is paid for in airspeed, a dive buys it back -- the coupling that
	# makes stall a live threat rather than a number. A rotor has no wing to trade, so it is exempt, and so is
	# anything in vacuum: there is no wing to trade WITH, so a ballistic climb costs you nothing but fuel.
	if not rotary:
		_car_speed = clampf(_car_speed - _vspeed * AIR_TRADE * q * delta, -vmax if d.rcs > 0.0 else d.reverse, vmax)
	_altitude += _vspeed * delta
	if _altitude <= 0.0:
		# touchdown: a hard arrival costs speed (naive undercarriage), and it cannot sink through the ground
		if _vspeed < -4.0:
			_car_speed *= clampf(1.0 + _vspeed * 0.03, 0.4, 1.0)
		_altitude = 0.0
		_vspeed = maxf(_vspeed, 0.0)
	# TURN: a rotor yaws freely (pivots like tracked/hover); a fixed-wing banks and needs airflow over the
	# rudder, so its authority scales with airspeed (steerage) -- the same rule the boat's rudder obeys.
	# A rudder needs airflow; a thruster couple does not. In vacuum the fixed-wing's steerage requirement
	# lifts and yaw becomes free -- so a spaceplane can point anywhere at any speed, INCLUDING backwards along
	# its own velocity to brake, which is the only way to slow down once the drag term is gone.
	if rotary:
		_car_heading += steer * d.turn * delta
	else:
		var steerage := clampf(absf(_car_speed) / maxf(d.grip_speed, 0.1), 0.0, 1.0)
		_car_heading += steer * d.turn * delta * maxf(steerage * q, vac)
	# BALLISTIC. In air, the wing and fin force velocity to follow the nose -- that alignment IS an aerodynamic
	# effect, and every land class gets it for free by writing `arc += cos(heading) * speed`. Take the air away
	# and nothing turns the velocity: you keep going the way you were going while the nose points elsewhere.
	# So the course vector chases the heading at a rate proportional to q, and in vacuum stops chasing at all.
	# Same mechanism as the boat's `drift`, at the opposite end of the scale -- and it is what makes pointing
	# retrograde and burning the actual way to change course up there.
	var want := Vector2(cos(_car_heading), sin(_car_heading)) * _car_speed
	if vac > 0.001:
		_air_vel = _air_vel.lerp(want, 1.0 - exp(-delta * 4.0 * q))
	else:
		_air_vel = want
	# TANGENTIAL COUPLING (the other half of the orbital model). The same inertial bookkeeping conserves angular
	# momentum r*v_i, so as r changes the ground-relative arc speed must change with it -- a climb (r shrinks)
	# throws you spinward, a descent retrograde. You cannot change altitude without the ground sliding under you.
	# To leading order this is the Coriolis 2*omega*_vspeed; the v_arc/r part is the exact companion to g_eff.
	# Applied AFTER the nose-follow lerp: in air the wing re-aligns you next frame (small trim); in vacuum there
	# is nothing to re-align, so it accumulates as real ballistic drift.
	_air_vel.x += _vspeed * (v_arc / rr_safe + 2.0 * omega) * delta
	_car_arc += _air_vel.x * delta
	_car_lat += _air_vel.y * delta

# Gait signature: amplitude of the vertical bob and the fore-aft rock, per stride. Kept as constants
# like the hover slope terms -- move to VehicleDef the day a mech's lumbering stride must differ from a
# horse's (the next items). BOB is metres, ROCK is radians.
const LEGGED_BOB := 0.10
const LEGGED_ROCK := 0.05

# Powered-suit jump gravity (TASKS.md "Powered suits"). A class constant like the hover slope terms: a
# few metres of hop, sub-second, so plain gravity is the right naive model -- the ring-frame ballistics
# subtlety (a projectile in free fall while the ring spins under it) is the WEAPONS programme's job, not a
# 3m jump. Snappier than 9.81 so a game jump doesn't hang; peak height still lands on d.jump because the
# launch velocity is derived from it (sqrt(2 g h)).
const SUIT_GRAVITY := 18.0

func _loco_legged(d: VehicleDef, delta: float, accel: float, steer: float) -> void:
	# Legs, not wheels/tracks/cushion -- the FOURTH movement class and the one genuinely new model, the
	# chassis the mounts and mechs (the next items) are built on. Three traits, each earning the class:
	# (1) it CLIMBS. Like tracked it ignores the road/offroad split -- ONE drag term, no offroad_drag, so
	#     tarmac and ploughed field damp the same; and it never consults _offroad, so on the climb phase
	#     (pinned _offroad=1) it holds its speed uphill where every wheeled vehicle washes out. Legs place
	#     feet: that is "climbs what wheels cannot" made measurable in the grade column.
	# (2) full turn authority at any speed, like tracked/hover -- a walker pivots in place, no grip_speed ramp.
	# (3) GAIT, not roll. It advances in a stride cadence rather than a continuous wheel: _gait_phase
	#     accumulates with DISTANCE (so a halted walker's legs are still), and _drive_tick poses the body's
	#     bob and fore-aft rock from it -- the visible tell of the class, and why its ground point comes
	#     from the gait plus a stepped-over strip, not springs or a contact plane.
	# offroad_drag/offroad_turn/grip_speed/susp_* are left 0 in the row to SAY the model reads none of them.
	# A MOUNT (the horse row) layers two living traits over this same walker, both switched on by data so
	# the strider/mech rows are untouched -- see TASKS.md "Horses". They alter the effective top and the
	# input, then the identical clamp/drag/heading integration below runs; the gait code is shared as-is.
	var top := d.top
	if d.stamina > 0.0:
		# TIRES. Holding a gallop (above the trot line) spends stamina at 1/`stamina` per second, so it is
		# fully blown after `stamina` seconds of hard running; walking or resting restores it, slower than it
		# drains so a blown mount stays winded a while. Effective top lerps down to `winded_top` as it empties
		# -- the horse smoothly loses its legs rather than hitting a wall, which is what tiring should feel like.
		var galloping := absf(_car_speed) > d.top * 0.45
		_stamina = clampf(_stamina + (-1.0 if galloping else 0.35) / d.stamina * delta, 0.0, 1.0)
		top = lerpf(d.winded_top, d.top, _stamina)
	if d.spooks:
		# SPOOKS. A closing threat (the [J] wolf pack in APPROACH sets _threat_active, the existing hook) ramps
		# _spooked up; it decays when calm. While spooked the mount throws in its OWN throttle (it bolts, so a
		# standing horse breaks into a run you didn't ask for) and shies its heading -- an oscillation tied to
		# the stride so it reads as panic, not noise. Bolting drives speed up, which drains stamina: flee and tire.
		_spooked = clampf(_spooked + (2.0 if _threat_active else -1.0) * delta, 0.0, 1.0)
		accel += d.power * _spooked
		steer += sin(_gait_phase * 3.0) * _spooked
	if d.sprint > 1.0 and _sprinting:
		# SPRINT (the powered suit). Holding the sprint input lifts the effective top by d.sprint -- a
		# powered burst on demand, the machine's answer to the horse's gallop. It is switched on by data
		# (sprint > 1), so the strider/mech/mount rows, which leave sprint at 1, are untouched.
		top *= d.sprint
	_car_speed = clampf(_car_speed + accel * delta, d.reverse, top)
	_car_speed *= 1.0 - d.drag * delta
	_car_heading += steer * d.turn * delta
	_car_arc += cos(_car_heading) * _car_speed * delta
	_car_lat += sin(_car_heading) * _car_speed * delta
	# stride cadence tied to the ground: one full bob per `gait` metres travelled, so footfalls sync to
	# distance rather than a wall-clock timer that would slide as speed changes.
	if d.gait > 0.0:
		_gait_phase += absf(_car_speed) * delta * TAU / d.gait

func _do_trample(d: VehicleDef, pos: Vector3) -> void:
	# The elephant's reason to exist: it FLATTENS what it walks over, which is the only thing that makes the
	# hedge and tree systems destructible at all (TASKS.md "Elephants"). Two targets, each crushed in its
	# own system's terms:
	#   trees  -- mark the index down; _update_tree_lod rebuilds the MultiMesh buckets from these arrays
	#             every few metres anyway and simply skips it, so no parallel geometry is needed.
	#   hedges -- the ribbon is one committed mesh, so record the crush POINT and rebuild the ribbon with
	#             that span left out. Rebuild only when a new point lands near a road, not every frame.
	# Only SMALL trees go down: taller than TRAMPLE_TREE_MAX_H and it stands (the fir pack has no true
	# canopy giants, so height is the proxy for "too big to push over"). "Unstoppable" is in the handling
	# table (heavy, tireless, one drag term); this is the visible consequence of it.
	if absf(_car_speed) < 1.0:
		return
	# throttle the O(trees) scan to when the body has moved about a crush-width since the last one
	if pos.distance_to(_trample_prev) < d.trample * 0.5:
		return
	_trample_prev = pos
	var r2 := d.trample * d.trample
	var downed := false
	for i in _tree_ground.size():
		if _tree_down.has(i):
			continue
		if _tree_basis[i].get_scale().y > TRAMPLE_TREE_MAX_H:
			continue
		if pos.distance_squared_to(_tree_ground[i]) < r2:
			_tree_down[i] = true
			downed = true
	if downed:
		_update_tree_lod(true)
	# hedges only exist beside roads, so only bother recording/rebuilding when on or next to one
	var cell := Vector2i(int(floor(_car_arc / 8.0)), int(floor(_car_lat / 8.0)))
	var near_road := false
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _road_cells.has(cell + o):
			near_road = true
			break
	if not near_road:
		return
	var here := Vector2(_car_arc, _car_lat)
	if _hedge_down.is_empty() or here.distance_to(_hedge_down[_hedge_down.size() - 1]) > 3.0:
		_hedge_down.append(here)
		if _hedge_down.size() > TRAMPLE_HEDGE_MAX:
			_hedge_down.remove_at(0)   # oldest crush regrows -- bounds the list and the per-span test
		_build_hedge_ribbon()

# ---------------------------------------------------------------------------
# WEAR, FUEL AND DAMAGE (TASKS.md). The item states its own purpose: "the reason to change vehicle
# rather than keep the best one." A roster where the best machine is simply always the best is a
# roster with one vehicle in it, so the job here is to make holding onto a favourite cost something.
#
# DERIVED, not authored. Capacity comes from mass and burn from power, so every row in the table gets
# the mechanic without twenty hand-tuned numbers -- and the coupling is the design: the powerful thing
# is the thirsty thing. A row overrides only where it should be unusual.
#
# Condition is PER VEHICLE and PERSISTS across [L] cycling. That is the whole point: the machine you
# have been thrashing is still worn when you come back to it, and the fresh one in the shed is not.
# ---------------------------------------------------------------------------
const FUEL_PER_KG := 0.06         # litres of capacity per kg -- a 1200kg car carries ~72
const BURN_PER_POWER := 0.010     # litres per (unit of thrust * second)
const WEAR_BITE := 0.55           # fraction of thrust lost at fully worn; never total, so you limp home
const WEAR_SUSP := 0.020          # wear per second of bottomed-out suspension
const WEAR_LAND := 0.06           # wear per hard landing (scaled by how hard)
const WEAR_AGROUND := 0.05        # wear per second of dragging a hull over the bottom
const WEAR_OFFROAD := 0.0022      # wear per second of full off-road abrasion
var _veh_cond := {}               # vehicle name -> {"fuel": litres, "wear": 0..1}

func _cond_cap(d: VehicleDef) -> float:
	# A living mount has no tank; it runs on stamina, which is already modelled. Returning 0 opts the
	# horse and the elephant out of the fuel system entirely rather than giving them a fictional one.
	if d.stamina > 0.0:
		return 0.0
	return d.fuel_cap if d.fuel_cap > 0.0 else d.mass * FUEL_PER_KG

func _cond() -> Dictionary:
	var n := str(_vehicles[_veh_idx]["name"]) if _veh_idx < _vehicles.size() else "box"
	if not _veh_cond.has(n):
		_veh_cond[n] = {"fuel": _cond_cap(_vdef()), "wear": 0.0}
	return _veh_cond[n]

func _condition_tick(d: VehicleDef, delta: float, accel: float) -> float:
	# Returns the multiplier to apply to thrust. Burns fuel for the work actually demanded and accrues
	# wear from the things that genuinely punish a machine -- all of which are already measured
	# elsewhere, so this reads existing signals rather than inventing new ones.
	var c := _cond()
	var cap := _cond_cap(d)
	if d.toughness > 0.0:
		var w := 0.0
		# bottoming the suspension is the classic way to destroy a vehicle over rough ground
		if d.susp_travel > 0.0 and _susp_travel >= d.susp_travel * 0.98:
			w += WEAR_SUSP
		w += _land_dip * WEAR_LAND            # hard landings (suit/air), scaled by impact
		if _aground:
			w += WEAR_AGROUND                 # a hull grinding over the bottom
		w += _offroad * WEAR_OFFROAD          # abrasion, the slow background cost of off-roading
		c["wear"] = clampf(float(c["wear"]) + w * delta / maxf(d.toughness, 0.05), 0.0, 1.0)
	if cap <= 0.0:
		return 1.0 - float(c["wear"]) * WEAR_BITE
	var rate: float = d.burn if d.burn > 0.0 else d.power * BURN_PER_POWER
	c["fuel"] = maxf(float(c["fuel"]) - absf(accel) * rate * delta, 0.0)
	if float(c["fuel"]) <= 0.0:
		return 0.0                            # dry: no thrust at all. You are where you stopped.
	return 1.0 - float(c["wear"]) * WEAR_BITE

func _service_vehicle() -> void:
	# Docking at the axis port services the craft. This is deliberately the ONLY place that does, for
	# now: it gives the port a reason to exist beyond being a destination, and it keeps fuel scarce
	# enough on the surface that the roster gets used. Ground refuelling is its own queued item.
	var c := _cond()
	c["fuel"] = _cond_cap(_vdef())
	c["wear"] = 0.0


# ---------------------------------------------------------------------------
# CARRYING AND FIRING A WEAPON. Until now the roster existed only as numbers the range harness
# printed -- fourteen weapons nobody could pick up. This is the play side, and the one hard rule is
# that it must use THE SAME BALLISTICS AS `--range`: a live round that flies differently from the
# table would make the table a lie, which is the drawn-vs-simulated mismatch this project keeps
# getting caught by. Both integrate a straight line in the inertial frame and convert back.
# ---------------------------------------------------------------------------
var _wep_idx := 0
var _wep_names: Array[String] = []
var _wep_mag := 0                 # rounds left in the current magazine
var _wep_cool := 0.0              # seconds until the action can cycle again
var _wep_reload := 0.0            # seconds left in a reload
var _wep_bloom := 0.0             # accumulated dispersion, same units and decay as the harness
var _shots: Array = []            # live rounds; inertial (tangential, radial) + lat
var _shot_root: Node3D = null
var _tracer_mesh: BoxMesh = null
var _tracer_mat: StandardMaterial3D = null

func _wep_name() -> String:
	if _wep_names.is_empty():
		_wep_names.assign(WEAPON_ROWS.keys())
	return _wep_names[_wep_idx % _wep_names.size()]

func _wep() -> WeaponDef:
	return _weapon_def(_wep_name())

func _cycle_weapon(step: int) -> void:
	if _wep_names.is_empty():
		_wep_names.assign(WEAPON_ROWS.keys())
	_wep_idx = posmod(_wep_idx + step, _wep_names.size())
	var w := _wep()
	_wep_mag = w.mag
	_wep_bloom = 0.0
	_wep_cool = 0.0
	_wep_reload = 0.0
	_update_hud()

func _fire_weapon() -> void:
	var w := _wep()
	if _wep_cool > 0.0 or _wep_reload > 0.0:
		return
	# melee has no projectile: it is a wind-up and a committed window, so it just costs the time
	if w.muzzle <= 0.0:
		_wep_cool = w.windup_s + w.commit_s
		_update_hud()
		return
	if w.mag > 0 and _wep_mag <= 0:
		_wep_reload = w.reload_s
		_update_hud()
		return
	# muzzle direction from where the camera is actually looking, in RING axes: x along the arc,
	# y toward the axis ("up"), z across the width
	var R := _radius()
	var wv := _omega()
	var cam_b := _cam.global_transform.basis
	var pos3 := _cam.global_position
	var up := _ring_up(pos3)
	var fwd := -cam_b.z
	var arc_axis := up.cross(Vector3(0.0, 0.0, 1.0)).normalized()
	var lat_axis := Vector3(0.0, 0.0, 1.0)
	var d_arc := fwd.dot(arc_axis)
	var d_up := fwd.dot(up)
	var d_lat := fwd.dot(lat_axis)
	# dispersion, using the same inherent+bloom model the harness samples
	var sp: float = w.spread_mrad + _wep_bloom
	d_arc += randfn(0.0, sp * 0.0005)
	d_up += randfn(0.0, sp * 0.0005)
	d_lat += randfn(0.0, sp * 0.0005)
	var arc0: float = _cam_ring.x
	var lat0: float = _cam_ring.z
	var alt0: float = maxf(_cam_ring.y, _terrain_h(arc0, lat0) + 0.2)
	var r0 := R - alt0
	# to the inertial frame: the floor's own tangential speed plus the muzzle
	var vel := Vector2(d_arc * w.muzzle + wv * r0, -d_up * w.muzzle)
	_shots.append({
		"p": Vector2(0.0, r0), "v": vel, "lat": lat0, "vlat": d_lat * w.muzzle,
		"t": 0.0, "arc0": arc0, "life": 0.0, "k": w.drag_k, "r0": r0, "node": _make_tracer(),
	})
	_wep_bloom = minf(_wep_bloom + w.bloom_mrad, w.bloom_max)
	_wep_cool = (60.0 / w.rpm) if w.rpm > 0.0 else maxf(w.cycle_s, 0.05)
	_wep_cool = maxf(_wep_cool, w.cycle_s)
	if w.mag > 0:
		_wep_mag -= 1
	_update_hud()

func _make_tracer() -> Node3D:
	if _shot_root == null:
		_shot_root = Node3D.new()
		add_child(_shot_root)
	if _tracer_mesh == null:
		_tracer_mesh = BoxMesh.new()
		_tracer_mesh.size = Vector3(0.09, 0.09, 1.1)
		_tracer_mat = StandardMaterial3D.new()
		_tracer_mat.albedo_color = Color(1.0, 0.82, 0.45)
		_tracer_mat.emission_enabled = true
		_tracer_mat.emission = Color(1.0, 0.72, 0.30)
		_tracer_mat.emission_energy_multiplier = 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = _tracer_mesh
	mi.material_override = _tracer_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shot_root.add_child(mi)
	return mi

func _shots_tick(delta: float) -> void:
	# Same integration as _shot_flight, per frame instead of in a loop: straight line in the inertial
	# frame, ring rotated out at the end. A round that flew any other way here would make --range
	# fiction.
	var w := _wep()
	_wep_cool = maxf(_wep_cool - delta, 0.0)
	_wep_bloom = maxf(_wep_bloom - (delta / maxf(w.settle_s, 0.01)) * w.bloom_mrad, 0.0)
	if _wep_reload > 0.0:
		_wep_reload -= delta
		if _wep_reload <= 0.0:
			_wep_mag = w.mag
			_update_hud()
	if _shots.is_empty():
		return
	var R := _radius()
	var wv := _omega()
	var dead: Array = []
	for sh in _shots:
		# SUB-STEP. A 900 m/s round covers 15 metres in one 60Hz frame, so a single step per frame
		# would sail straight through a hillside and never register -- the projectile equivalent of
		# the LOD bug, where the thing being tested is smaller than the step used to test it. Cap each
		# step at ~2m of travel and iterate; a slow thrown rock still costs exactly one step.
		var vel: Vector2 = sh["v"]
		var sub := clampi(int(ceil(vel.length() * delta / 2.0)), 1, 32)
		var sdt := delta / float(sub)
		var hit := false
		for _i in sub:
			var speed := vel.length()
			var rel: float = speed - wv * float(sh["r0"])
			var k: float = float(sh["k"])
			if k > 0.0 and rel > 0.0:
				vel -= vel.normalized() * (rel * rel * k * sdt)
			sh["p"] = (sh["p"] as Vector2) + vel * sdt
			sh["t"] = float(sh["t"]) + sdt
			sh["lat"] = float(sh["lat"]) + float(sh["vlat"]) * sdt
			var pp: Vector2 = sh["p"]
			var rr := pp.length()
			var th: float = atan2(pp.x, pp.y) - wv * float(sh["t"])
			var aa: float = float(sh["arc0"]) + th * R
			if (R - rr) <= _terrain_h(aa, float(sh["lat"])):
				hit = true
				break
		sh["v"] = vel
		sh["life"] = float(sh["life"]) + delta
		var p: Vector2 = sh["p"]
		var r := p.length()
		var theta: float = atan2(p.x, p.y) - wv * float(sh["t"])
		var arc: float = float(sh["arc0"]) + theta * R
		var alt := R - r
		var lat: float = sh["lat"]
		var node: Node3D = sh["node"]
		node.global_position = _ring_pos(arc / R, lat, alt)
		if hit or float(sh["life"]) > 12.0:
			dead.append(sh)
	for sh in dead:
		(sh["node"] as Node3D).queue_free()
		_shots.erase(sh)

func _drive_tick(delta: float) -> void:
	var accel := 0.0
	var steer := 0.0
	var want_jump := false
	_sprinting = false
	var d := _vdef()
	if _proving:
		# scripted course input, so every vehicle is driven identically and the table compares
		accel = _prove_throttle * (d.power if _prove_throttle > 0.0 else d.brake)
		steer = _prove_steer
	else:
		if Input.is_key_pressed(KEY_W): accel += d.power
		if Input.is_key_pressed(KEY_S): accel -= d.brake
		if Input.is_key_pressed(KEY_A): steer -= 1.0
		if Input.is_key_pressed(KEY_D): steer += 1.0
		# POWERED SUIT controls, deliberately the WALK/FLY keys so the suit blurs into on-foot rather than
		# being a separate thing to get into: Shift sprints (WALK's run key), Space jumps (FLY's rise key).
		want_jump = Input.is_key_pressed(KEY_SPACE)
		_sprinting = Input.is_key_pressed(KEY_SHIFT)
	# elevator command for the air class: Space climbs, Shift descends -- the FLY-mode up/down keys, so flight
	# plays like the noclip camera it replaces. 0 during proving and unread by every non-air class.
	var elevator := (1.0 if want_jump else 0.0) - (1.0 if _sprinting else 0.0)
	# CONDITION gates the thrust before anything else sees it: a dry tank is zero power regardless of
	# class, and a worn machine simply has less to give. Applied here, once, rather than inside seven
	# locomotion functions that would each have to remember.
	accel *= _condition_tick(d, delta, accel)
	# LOCOMOTION DISPATCH -- one call per class, selected by the def's `loco`. Add a case here and a
	# sibling _loco_<class> to make a whole vehicle class drivable. Off-roading is a mode, not a
	# penalty: drag and steering bite both worsen off the tarmac, but the vehicle stays usable.
	match d.loco:
		"hover": _loco_hover(d, delta, accel, steer)
		"tracked": _loco_tracked(d, delta, accel, steer)
		"legged": _loco_legged(d, delta, accel, steer)
		"boat": _loco_boat(d, delta, accel, steer)
		"sub": _loco_sub(d, delta, accel, steer)
		"air":
			# check the axis-structure port first: if we soft-capture or are held there, skip flight integration
			if not _dock_update(accel, elevator):
				_loco_air(d, delta, accel, steer, elevator)
		"wheeled", _: _loco_wheeled(d, delta, accel, steer)
	var hover := d.loco == "hover"
	var legged := d.loco == "legged"
	var boat := d.loco == "boat"
	var sub := d.loco == "sub"
	var air := d.loco == "air"
	# SUBMERSIBLE dive, integrated here where the vertical keys already live (like the suit's jump). _dive is
	# metres below the surface: Shift descends, Space rises -- the WALK-run / FLY-rise keys, so it plays like
	# on-foot and the boat's helpless grounding is inverted into an amphibian that simply goes under. It can
	# only dive where the water is deep enough to float and only as far as the synthesised seabed (staying
	# SUB_KEEL above it); with no water under it, it is pushed back to the surface onto land. dive_max 0
	# (every non-sub row, and a pure surface amphibian) never enters this, so nothing else is touched.
	if sub and d.dive_max > 0.0:
		var sdepth := _sea_depth(_car_arc, _car_lat)
		if sdepth > d.draft:
			var dv := 0.0
			if _sprinting: dv += SUB_DIVE * delta      # Shift: descend
			if want_jump: dv -= SUB_DIVE * delta       # Space: surface
			var floor_d: float = maxf(0.0, minf(d.dive_max, sdepth - SUB_KEEL))
			_dive = clampf(_dive + dv, 0.0, floor_d)
		else:
			_dive = move_toward(_dive, 0.0, SUB_DIVE * 2.0 * delta)   # no water to dive in -- surface onto land
	# A hover craft floats level at a fixed clearance: the calibrated bump strip never reaches it (that
	# is what "ignores ground roughness" MEANS), so it is left out of its ground point. A walker STEPS
	# over roughness up to its step_height -- feet absorb small features, so the body feels only the part
	# of the strip that exceeds step_height (a kerb it climbs onto, not a washboard it strides across).
	# Everything else rides the whole strip through its springs.
	var strip: float = _proving_surface(_car_arc, _car_lat)
	if hover:
		strip = 0.0
	elif air:
		strip = 0.0   # a flyer rides no ground -- its clearance is _altitude, added along ring-up below
	elif legged:
		strip -= clampf(strip, -d.step_height, d.step_height)
	elif boat:
		# A hull rides the LIVE water, but `base` below is built from the static _terrain_h (which
		# clamps the sea flat). The difference between the two IS the swell, so feeding it in here
		# lifts the boat onto the drawn wave using the same ring-up offset the bump strip uses --
		# no second position path, and it stays exactly consistent with what the shader displaced.
		strip = _surface_h(_car_arc, _car_lat) - _terrain_h(_car_arc, _car_lat)
	elif sub:
		# rides the drawn water surface like a hull (swell = _surface_h - _terrain_h), then sits _dive
		# metres UNDER it -- the same ring-up offset path, so the submerged body stays consistent with the
		# shader's water and descends toward the synthesised seabed. On land (_dive forced to 0 above) this
		# is just the bump strip, so it sits on the ground like any wheeled vehicle while crawling ashore.
		strip = (_surface_h(_car_arc, _car_lat) - _terrain_h(_car_arc, _car_lat)) - _dive
	var base := _car_pos(_car_arc, _car_lat)
	# gait bob rises the body on each stride, added along ring-up -- legs, not springs.
	var bob: float = absf(sin(_gait_phase)) * LEGGED_BOB if legged else 0.0
	# POWERED SUIT: the one vehicle that leaves the ground under power (TASKS.md "Powered suits"). A jump is a
	# ballistic hop along ring-up -- launch at sqrt(2 g h) for a peak of d.jump metres, plain gravity pulls it
	# back -- and the return is a HARD landing: a body crouch that decays plus a bite out of forward speed,
	# both scaled by impact speed. Gated on d.jump > 0, so every other row (jump 0) never touches _jump_* and
	# is unchanged; jump is the trait that makes the suit move like a person, not a machine on wheels.
	if d.jump > 0.0:
		if _jump_h <= 0.0 and _jump_v <= 0.0 and want_jump:
			_jump_v = sqrt(2.0 * SUIT_GRAVITY * d.jump)    # launch: peak height lands on d.jump
		if _jump_h > 0.0 or _jump_v > 0.0:
			_jump_v -= SUIT_GRAVITY * delta
			_jump_h += _jump_v * delta
			if _jump_h <= 0.0 and _jump_v < 0.0:
				var impact: float = -_jump_v                # hard landing: crouch and stagger by how fast it hit
				_land_dip = clampf(impact * 0.06, 0.0, 0.6)
				_car_speed *= clampf(1.0 - impact * 0.02, 0.4, 1.0)
				_jump_h = 0.0
				_jump_v = 0.0
		_land_dip = lerpf(_land_dip, 0.0, delta * 6.0)
	# _altitude lifts a flyer off the deck along the same ring-up offset the bump strip / dive use; it is 0 for
	# every other class (reset on cycle and never touched), so this is a no-op for them, like _dive / _jump_h.
	var pos := base + _ring_up(base) * (strip + bob + _jump_h - _land_dip + _altitude)
	if d.trample > 0.0:
		_do_trample(d, pos)
	var ahead := _car_pos(_car_arc + cos(_car_heading) * 5.0, _car_lat + sin(_car_heading) * 5.0)
	if air:
		# the look-at target is a SURFACE point; lift it to the flyer's altitude too, or the nose points at the
		# ground below and pitches straight down. Level flight then reads level; the climb pitch is _body_pitch.
		ahead += _ring_up(ahead) * _altitude
	var up := _ring_up(pos)
	var fwd := (ahead - pos).normalized() if not pos.is_equal_approx(ahead) else up.cross(Vector3.FORWARD).normalized()
	if hover:
		# no wheels, no springs -- level the body toward flat rather than tilting it to a contact plane
		_body_pitch = lerpf(_body_pitch, 0.0, delta * 8.0)
		_body_roll = lerpf(_body_roll, 0.0, delta * 8.0)
	elif legged:
		# gait posture: a fore-aft rock driven by the stride phase, not a contact plane or springs -- the
		# body walks. Roll settles to level; there are no wheels to lean it into a hollow.
		_body_pitch = sin(_gait_phase) * LEGGED_ROCK
		_body_roll = lerpf(_body_roll, 0.0, delta * 8.0)
	elif air:
		# attitude from the controls, not a contact plane it isn't touching: a fixed-wing banks into its turn
		# and both pitch to the climb rate. Signs are cosmetic (a placeholder box) and NOT eyeballed here --
		# confirm the lean/pitch read right on the laptop, same caveat as the box showing wheels.
		# banking is the wing rolling into the turn -- an aerodynamic effect, so it fades with the air. Above
		# the atmosphere a craft yaws flat on its thrusters instead of leaning on a wing that has nothing to
		# lean on.
		var bank: float = 0.0 if d.stall_speed <= 0.0 else -steer * AIR_BANK * _air_density(_altitude)
		_body_roll = lerpf(_body_roll, clampf(bank, -0.7, 0.7), delta * 4.0)
		_body_pitch = lerpf(_body_pitch, clampf(_vspeed * 0.03, -0.5, 0.5), delta * 4.0)
	elif boat:
		# attitude from the wave slope under the hull, not from a contact plane or a stride
		_boat_trim(d, delta)
	elif sub:
		# at the surface it lies on the swell like a hull; submerged there is no wave over it, so it levels
		if _dive > 1.0:
			_body_pitch = lerpf(_body_pitch, 0.0, delta * 6.0)
			_body_roll = lerpf(_body_roll, 0.0, delta * 6.0)
		else:
			_boat_trim(d, delta)
	else:
		_susp_update(delta, pos, up, fwd)
	_car.global_position = pos + up * d.ride
	if not pos.is_equal_approx(ahead):
		_car.look_at(ahead + up * d.ride, up)
		# pitch and roll come from the contact plane, so braking dips the nose and a hollow
		# under one wheel leans the body -- rather than the whole car sliding as one decal
		_car.rotate_object_local(Vector3(1, 0, 0), _body_pitch)
		_car.rotate_object_local(Vector3(0, 0, 1), _body_roll)
	# WHEELS. They were four static cylinders: the single loudest tell that a vehicle is a prop.
	# Roll rate is circumference-correct rather than a guessed multiplier, so it never looks
	# like it is skating.
	_wheel_spin += (_car_speed * delta) / d.wheel_r
	for w in _wheels:
		# Node3D, not MeshInstance3D: the box car's wheels ARE meshes but the warthog's are
		# transform nodes with meshes beneath. The stricter type threw every frame on the
		# warthog and the proving run surfaced it in seconds.
		var mesh: Node3D = w["mesh"]
		var piv: Node3D = w["pivot"]
		var rest: Basis = w.get("rest", Basis())
		var axle: Vector3 = w.get("axle", Vector3.UP)
		var roll := Basis(axle, -_wheel_spin)
		var steer_y: float = (steer * -0.42) if bool(w["front"]) else 0.0
		if piv == mesh:
			# imported wheels are their own pivot, so steer and roll have to compose into one basis --
			# writing rotation.y afterwards used to wipe the roll straight back out again
			mesh.transform.basis = Basis(Vector3.UP, steer_y) * rest * roll
		else:
			mesh.transform.basis = rest * roll
			piv.rotation.y = steer_y
	# OFFROAD. The road mask is 44m per cell, which cannot say "am I on this lane" -- but the
	# 8m road cells built from the centrelines can, and already exist for the grass.
	if _proving and _prove_offroad >= 0.0:
		# the proving course pins the surface per phase; live position must not override it, or the
		# on-road terminal is never measured (the car leaves the ribbon and reads the off-road one)
		_offroad = _prove_offroad
	else:
		var on_road := _road_cells.has(Vector2i(int(floor(_car_arc / 8.0)), int(floor(_car_lat / 8.0))))
		_offroad = move_toward(_offroad, 0.0 if on_road else 1.0, delta * 3.0)
	if _dust:
		_dust.global_position = pos
		_dust.emitting = _offroad > 0.35 and absf(_car_speed) > 3.0
		_dust.amount_ratio = clampf(_offroad * absf(_car_speed) / 18.0, 0.0, 1.0)
	# chase cam SEATED on the terrain behind the car (analytic ring-space, exact match to render) —
	# can never sink through a slope behind the car (the under-floor cause found in the LOD mock).
	var cam_ground := _car_pos(_car_arc - cos(_car_heading) * 12.0, _car_lat - sin(_car_heading) * 12.0)
	var cam_up := _ring_up(cam_ground)
	# drop the chase cam with a diving submersible so it follows underwater, keeping the same relative
	# framing it had on the surface. _dive is 0 for every other class, so this is a no-op for them.
	# lift the chase cam with a climbing flyer so it keeps its framing instead of craning up at the aircraft;
	# _altitude is 0 for every non-air class, so this is a no-op for them (as _dive is for non-subs).
	var cam_target: Vector3 = cam_ground + cam_up * (5.0 - _dive + _altitude)
	_cam.position = _cam.position.lerp(cam_target, 1.0 - exp(-6.0 * delta))
	_cam.look_at(pos + up * 2.0, up)
	_hud_timer += delta
	if _hud_timer > 0.25:
		_hud_timer = 0.0
		_update_hud()

func _walk_tick(delta: float) -> void:
	var speed: float = WALK_SPEED * (WALK_RUN_MULT if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	var f := 0.0  # forward/back
	var s := 0.0  # strafe
	if Input.is_key_pressed(KEY_W): f += 1.0
	if Input.is_key_pressed(KEY_S): f -= 1.0
	if Input.is_key_pressed(KEY_D): s += 1.0
	if Input.is_key_pressed(KEY_A): s -= 1.0
	var mv := Vector2(s, f)
	if mv != Vector2.ZERO:
		mv = mv.normalized()
	var yaw: float = _look.x
	# camera-relative in ring (arc, lat) space, matching _apply_look's frame: yaw 0 faces SPINWARD,
	# so forward = (cos yaw, sin yaw) and strafe-right = (-sin yaw, cos yaw). Was derived against the
	# old world-space euler where yaw 0 faced -Z, which no longer holds anywhere but arc 0.
	var d_arc := (mv.y * cos(yaw) - mv.x * sin(yaw)) * speed * delta
	var d_lat := (mv.y * sin(yaw) + mv.x * cos(yaw)) * speed * delta
	var w: float = WIDTHS[w_idx]
	_walk_arc += d_arc
	_walk_lat = clampf(_walk_lat + d_lat, -w * 0.5 + 50.0, w * 0.5 - 50.0)
	var ground := _car_pos(_walk_arc, _walk_lat)   # exact analytic surface point — no raycast needed
	var up := _ring_up(ground)
	_cam.position = ground + up * EYE_HEIGHT
	_apply_look()

func _set_mode(m: Mode) -> void:
	_mode = m
	if m == Mode.DRIVE:
		if _vehicles.is_empty():
			_build_vehicles()
		_select_vehicle(_veh_idx)
		if _car:
			_car.visible = true
		_car_speed = 0.0
		# place the car where the CAMERA is (in ring coords) -- it kept its previous arc/lat before,
		# so entering drive after jumping a splice snapped the car back to the last place you drove
		var rd := _radius()
		_car_arc = atan2(_cam.position.x, rd - _cam.position.y) * rd
		_car_lat = clampf(_cam.position.z, -WIDTHS[w_idx] * 0.5 + 50.0, WIDTHS[w_idx] * 0.5 - 50.0)
		_car_heading = 0.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_captured = false
	else:
		for e in _vehicles:
			e["root"].visible = false
		if m == Mode.WALK:
			var w: float = WIDTHS[w_idx]
			# derive arc from the ring angle, NOT world x -- those only coincide near arc 0, so
			# entering walk mode anywhere else used to teleport you back toward spawn
			var rr := _radius()
			_walk_arc = atan2(_cam.position.x, rr - _cam.position.y) * rr
			_walk_lat = clampf(_cam.position.z, -w * 0.5 + 50.0, w * 0.5 - 50.0)
			var ground := _car_pos(_walk_arc, _walk_lat)
			var up := _ring_up(ground)
			_cam.position = ground + up * EYE_HEIGHT
		_apply_look()
	_update_hud()

func _fly(delta: float) -> void:
	# fly only while mouse captured; config keys only while released — no key conflicts
	if not _captured: return
	var speed: float = FLY_SPEEDS[_fly_speed_idx]
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= _cam.global_basis.z
	if Input.is_key_pressed(KEY_S): dir += _cam.global_basis.z
	if Input.is_key_pressed(KEY_A): dir -= _cam.global_basis.x
	if Input.is_key_pressed(KEY_D): dir += _cam.global_basis.x
	# vertical follows LOCAL up, or "ascend" drifts sideways once you are round the ring
	var local_up := _ring_up(_cam.global_position)
	if Input.is_key_pressed(KEY_SPACE): dir += local_up
	if Input.is_key_pressed(KEY_CTRL): dir -= local_up
	if dir != Vector3.ZERO:
		_cam.position += dir.normalized() * speed * delta

func _fire_input(event: InputEvent) -> bool:
	# Left mouse fires whenever the pointer is captured, in any mode -- on foot, driving, flying. A
	# weapon you can only use in one mode is a weapon you forget you have.
	if event is InputEventMouseButton and _captured:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_fire_weapon()
			return true
	return false

func _input(event: InputEvent) -> void:
	# ESC lives here, NOT in _unhandled_input: once a slider in the [O] panel takes focus the GUI
	# consumes the event and _unhandled_input never fires, so ESC silently stopped releasing the
	# mouse. _input() always fires. Also drops GUI focus so the panel stops eating keys afterwards.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_captured = false
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
		_update_hud()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _fire_input(event):
		return
	if event is InputEventMouseButton and event.pressed and not _captured and not _panel_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_captured = true
		_update_hud()
	if event is InputEventMouseMotion and _captured and _mode != Mode.DRIVE:
		# yaw sign is OPPOSITE to pitch here: in the ring frame yaw increases toward +lat, whereas the
		# old world-euler had it increasing counter-clockwise, so sharing one sign inverted look-left/right
		_look.x += event.relative.x * 0.0022
		_look.y -= event.relative.y * 0.0022
		_look.y = clampf(_look.y, -1.55, 1.55)
		_apply_look()
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			return   # handled in _input() above
		# always-available keys
		match event.keycode:
			KEY_UP: haze_density *= 1.5; _update_hud()
			KEY_DOWN: haze_density /= 1.5; _update_hud()
			KEY_T: sun_speed_idx = (sun_speed_idx + 1) % SUN_PERIODS.size(); _update_hud()
			KEY_P: sun_paused = not sun_paused
			KEY_F: sun_angle = fmod(sun_angle + PI, TAU)
			KEY_R: _rebuild()
			KEY_K: _spawn_creatures("deer", 6, 60.0)   # herd ahead
			KEY_J: _spawn_creatures("wolf", 3, 90.0)    # pack behind
			KEY_C: _clear_creatures()
			KEY_M: _show_lod = not _show_lod
			KEY_N: _haze_off = not _haze_off
			KEY_Y: _probe_on = not _probe_on; _update_hud()
			KEY_U:
				# raw -> s3tc -> bptc, all at 4096. NOT 8192: fetch_s2.py writes a 4096 canvas, so asking
				# for more here interpolates pixels that carry no information -- measurably slower to
				# stream, measurably more memory, and not one extra thing visible on the ground.
				_tex_step = (_tex_step + 1) % 3
				_tex_mode = [TexMode.RAW, TexMode.S3TC, TexMode.BPTC][_tex_step]
				_hires_idx = -1   # force a re-stream so the change is visible where you stand
				_update_hud()
			KEY_COMMA: _jump_splice(-1)
			KEY_PERIOD: _jump_splice(1)
			KEY_TAB: _hud_full = not _hud_full; _update_hud()
			KEY_K:
				# swap weapon. [L] is already vehicles, and the two are cycled the same way for the
				# same reason: the roster is only variety if you can get at all of it.
				_cycle_weapon(1)
			KEY_L:
				# swap vehicle -- only meaningful while driving, and only if the warthog asset loaded
				if _mode == Mode.DRIVE and _vehicles.size() > 1:
					_select_vehicle(_veh_idx + 1)
			KEY_ENTER, KEY_KP_ENTER:
				# board / leave the axis structure -- only meaningful once docked (see _dock_update)
				if _mode == Mode.DRIVE and _docked:
					_boarded = not _boarded
					_update_hud()
			KEY_O:
				# sliders need a visible cursor, so opening the panel releases mouse capture
				_panel_open = not _panel_open
				if _panel:
					_panel.visible = _panel_open
				if _panel_open:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					_captured = false
				_update_hud()
			KEY_G:
				# warp menu. [,] and [.] cycle, but 35 splices is too many to hunt through one
				# at a time when you want a named one.
				_warp_open = not _warp_open
				if _warp:
					_warp.visible = _warp_open
				if _warp_open:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					_captured = false
				_update_hud()
			KEY_Z:
				if _clouds:
					_clouds.cycle_type()
					_update_hud()
			KEY_X:
				if _clouds:
					_clouds.toggle_visible()
					_update_hud()
			KEY_G: _tree_lod_scale = maxf(0.25, _tree_lod_scale - 0.25); _update_tree_lod(true)
			KEY_B: _tree_lod_scale = minf(4.0, _tree_lod_scale + 0.25); _update_tree_lod(true)
			KEY_H:
				if _dem_w > 0:
					dem_scale = 1.0 if dem_scale >= 5.0 else dem_scale + 1.0
			KEY_V:
				if _dem_w > 0:
					var order := [Mode.FLY, Mode.DRIVE, Mode.WALK]
					_set_mode(order[(order.find(_mode) + 1) % 3])
			KEY_SHIFT:
				if _mode == Mode.FLY:
					_fly_speed_idx = (_fly_speed_idx + 1) % FLY_SPEEDS.size()
					_update_hud()
		if _captured or _mode == Mode.DRIVE: return
		# config keys only while mouse is released
		match event.keycode:
			KEY_1: c_idx = 0; _rebuild()
			KEY_2: c_idx = 1; _rebuild()
			KEY_3: c_idx = 2; _rebuild()
			KEY_Q: w_idx = 0; _rebuild()
			KEY_W: w_idx = 1; _rebuild()
			KEY_E: w_idx = 2; _rebuild()

func _probe_tiers(arc: float, lat: float) -> Dictionary:
	# Every height source that COULD answer at this point, side by side, plus which one actually
	# does. The whole placement stack is "the CPU mirrors the shader"; when it does not, the symptom
	# is always the same (something floats or sinks) and the cause has been different every time --
	# nearest vs bilinear, half a texel, overlapping patch ownership, stale data after a stream
	# landed. Guessing from a screenshot has cost more time than this readout will.
	var out := {"home": NAN, "hires": NAN, "array": NAN, "proc": NAN,
		"tier": "procedural", "pi": -1, "name": "-", "offset": 0.0, "own": 0.0, "rect": 0.0}

	if _dem_hf_w > 0:
		var fx := _dem_hf_cam.x + arc / _dem_hf_mpp
		var fy := _dem_hf_cam.y - lat / _dem_hf_mpp
		if fx >= 0.0 and fy >= 0.0 and fx < float(_dem_hf_w - 1) and fy < float(_dem_hf_h - 1):
			out["home"] = _bilerp(_dem_hf, _dem_hf_w, _dem_hf_h, fx - 0.5, fy - 0.5) * dem_scale
			out["tier"] = "HOME"

	var pi := _patch_at(arc, lat)
	out["pi"] = pi
	if pi >= 0:
		var rr: Vector4 = _patch_rects[pi]
		out["name"] = str(_patch_names[pi])
		out["offset"] = _patch_offset[pi]
		out["own"] = _patch_own[pi] if pi < _patch_own.size() else rr.z
		out["rect"] = rr.z
		out["array"] = _patch_height(pi, arc, lat)
		if pi == _hires_idx and _hires_res > 0:
			var circ: float = CIRCUMFERENCES[c_idx]
			var da: float = wrapf(arc - rr.x, -circ * 0.5, circ * 0.5)
			var hu: float = clampf(da / (2.0 * rr.z) + 0.5, 0.0, 0.999)
			var hv: float = clampf(0.5 - (lat - rr.y) / (2.0 * rr.w), 0.0, 0.999)
			out["hires"] = (_bilerp(_hires_field, _hires_res, _hires_res,
				hu * float(_hires_res) - 0.5, hv * float(_hires_res) - 0.5)
				+ _patch_offset[pi]) * dem_scale
		if is_nan(float(out["home"])):
			out["tier"] = "HIRES" if not is_nan(float(out["hires"])) else "ARRAY"
	out["proc"] = maxf(_noise.get_noise_2d(arc * 0.05, lat * 0.05), 0.0) * DISP
	return out

func _probe_text() -> String:
	if _cam == null:
		return ""
	var r := _radius()
	var cam := _cam.global_position
	var arc: float = atan2(cam.x, r - cam.y) * r
	var lat: float = cam.z
	var t := _probe_tiers(arc, lat)
	var ground := _terrain_h(arc, lat)
	var alt: float = r - Vector2(cam.x, r - cam.y).length()
	var f := func(v) -> String:
		return "     -  " if is_nan(float(v)) else "%8.1f" % float(v)
	# WHICH disagreement matters. Objects only fall through a gap when the CPU and the shader
	# resolve to different tiers -- and they now share their selection rule, so they should not.
	# A difference between the tier in use and one nobody is reading is not an error: the array
	# averages over a far wider footprint than the stream, so on steep ground they legitimately
	# answer differently. Flagging that as a fault made the probe cry wolf at Big Sur.
	var chosen := float(ground)
	var worst: float = 0.0
	var idle: float = 0.0
	for k in ["home", "hires", "array"]:
		if is_nan(float(t[k])) or str(t["tier"]).to_lower() == k:
			continue
		idle = maxf(idle, absf(float(t[k]) - chosen))
	# the shader picks home -> hires -> array by the same tests; if that ever diverges from what
	# _terrain_h_raw just did, THAT is the bug, and it is what this line is watching for
	var gpu_tier := "procedural"
	if not is_nan(float(t["home"])):
		gpu_tier = "HOME"
	elif not is_nan(float(t["hires"])):
		gpu_tier = "HIRES"
	elif not is_nan(float(t["array"])):
		gpu_tier = "ARRAY"
	var agree: bool = gpu_tier == str(t["tier"])
	if not agree:
		worst = idle
	return "\n".join([
		"PROBE   arc %.0f (%.2f%%)  lat %.0f   cam alt %.1f m   above ground %.1f m" % [
			arc, 100.0 * fposmod(arc, CIRCUMFERENCES[c_idx]) / CIRCUMFERENCES[c_idx],
			lat, alt, alt - ground],
		"        patch %d %s   own +-%.0f  rect +-%.0f  offset %.1f  dem_scale %.0f" % [
			t["pi"], t["name"], t["own"], t["rect"], t["offset"], dem_scale],
		"        answering: %s     home %s  hires %s  array %s  proc %s" % [
			t["tier"], f.call(t["home"]), f.call(t["hires"]), f.call(t["array"]), f.call(t["proc"])],
		"        terrain_h %.1f   CPU %s / GPU %s %s" % [
			ground, t["tier"], gpu_tier,
			("AGREE" if agree else "MISMATCH %.1f m <-- objects WILL float/sink" % worst)],
		"        idle-tier spread %.1f m %s" % [idle,
			"(nothing reads it here; wider averaging footprint on steep ground)" if agree
			else "(and the two sides disagree about which to use)"],
		"        texture [U] %s   colour = %.1f MB in VRAM   (RGB8 would be %.1f MB)" % [
			["RAW RGB8", "S3TC / DXT1", "BPTC / BC7"][_tex_mode],
			float(_tex_bytes) / 1048576.0,
			float(_tex_bytes) * (6.0 if _tex_mode == TexMode.S3TC else (3.0 if _tex_mode == TexMode.BPTC else 1.0)) / 1048576.0],
		"        stream: %s @ %d^2 heights, colour %s   road mask %s" % [
			(_patch_names[_hires_idx] if _hires_idx >= 0 else "none"),
			_hires_res,
			("%d^2" % hires_tex_res) if _hires_col_tex != null else "NONE (array 512^2 -> smeared)",
			("%d^2" % ROAD_RES) if not _road_mask.is_empty() else "none (home patch only)"],
	])

func _update_hud() -> void:
	if _hud == null:
		return   # input can arrive mid-startup, before the label exists
	var c: float = CIRCUMFERENCES[c_idx]
	var w: float = WIDTHS[w_idx]
	var r: float = _radius()
	var rise20: float = 20_000.0 * 20_000.0 / (2.0 * r)
	var rise50: float = 50_000.0 * 50_000.0 / (2.0 * r)
	var band_deg: float = rad_to_deg(2.0 * atan((w * 0.5) / (2.0 * r)))
	var fly_speed_name: String = ["normal", "boost", "5x boost", "20x boost"][_fly_speed_idx]
	var mode := "FLY %s (WASD + Space/Ctrl, [Shift] cycle speed, ESC to release, [V] cycle mode)" % fly_speed_name if _captured else "CONFIG ([1/2/3] circ  [Q/W/E] width — click to fly, [V] cycle drive/walk)"
	# WHAT AM I HOLDING. Without this the weapon roster is invisible in play: [K] would cycle
	# fourteen things that all look identical from behind the camera.
	var wnow := _wep()
	var wtxt := "  |  %s" % _wep_name()
	if wnow.muzzle <= 0.0:
		wtxt += " (melee %.1fm)" % wnow.reach
	elif wnow.mag > 0:
		wtxt += "  %d/%d" % [_wep_mag, wnow.mag]
		if _wep_reload > 0.0:
			wtxt += " RELOADING"
	wtxt += "  [K] weapon, LMB fire"
	if _mode == Mode.DRIVE:
		var vn: String = _vehicles[_veh_idx]["name"] if _veh_idx < _vehicles.size() else "box"
		# show what this vehicle is FOR, not just its name -- the census discipline made visible, so
		# cycling with [L] tells you why you'd pick it, not merely which box you're in
		var purpose: String = _vdef().purpose
		# a living mount shows its condition: stamina bleeds as it gallops, and it flags when it bolts, so
		# the tire/spook behaviour is legible while riding rather than only felt (matches the census discipline)
		var vd := _vdef()
		var mount := ""
		if vd.stamina > 0.0:
			mount += "  stamina %d%%%s" % [int(_stamina * 100.0), " WINDED" if _stamina < 0.15 else ""]
		if vd.spooks and _spooked > 0.05:
			mount += "  SPOOKED"
		# a powered suit reads its own state, so the jump/sprint traits are legible while worn: it flags
		# airborne (Space) and sprinting (Shift), and shows the keys so you know it plays like on-foot
		var suit := ""
		if vd.jump > 0.0:
			suit = "  (Space jump, Shift sprint)%s%s" % [
				"  AIRBORNE" if _jump_h > 0.05 else "", "  SPRINT" if _sprinting else ""]
		# a submersible reads its own depth: DIVE metres while under, ASHORE when crawling on land, and the
		# dive keys otherwise -- so the amphibious/submersible traits are legible while driving, not just felt
		var subm := ""
		if vd.loco == "sub":
			if _dive > 0.5:
				subm = "  DIVE %.0fm" % _dive
			elif _sea_depth(_car_arc, _car_lat) <= vd.draft:
				subm = "  ASHORE"
			elif vd.dive_max > 0.0:
				subm = "  (Shift dive, Space surface)"
		# a flyer reads its altitude and, for a fixed-wing, whether the wing is still flying -- STALL below stall
		# speed -- so the class's live constraint is legible, not just felt as a sudden drop
		var airinfo := ""
		if vd.loco == "air":
			airinfo = "  ALT %.0fm" % _altitude
			# WHICH REGIME. The handover is a continuous blend, so the one number that actually tells you what
			# is flying the craft is how much air is left. STALL only means anything while there IS air.
			var q_hud := _air_density(_altitude)
			if q_hud < 0.02:
				airinfo += "  VACUUM  RCS" if vd.rcs > 0.0 else "  VACUUM  NO CONTROL"
			elif q_hud < 0.98:
				airinfo += "  AIR %.0f%%" % (q_hud * 100.0)
				if vd.rcs > 0.0:
					airinfo += "+RCS"
			if q_hud > 0.02 and vd.stall_speed > 0.0 and absf(_car_speed) < vd.stall_speed:
				airinfo += "  STALL"
			# ballistic drift: once the course stops following the nose, the angle between them is the thing
			# you have to fly, and it is invisible without a readout
			if q_hud < 0.5 and _air_vel.length() > 1.0:
				var drift_deg: float = rad_to_deg(absf(angle_difference(_car_heading, _air_vel.angle())))
				if drift_deg > 5.0:
					airinfo += "  DRIFT %.0f deg" % drift_deg
			# RING-RELATIVE ORBITAL STATE (TASKS.md). _car_arc is the ground-fixed frame, so _air_vel.x is the
			# rate the ring slides beneath you: 0 = matched the spin (hover over one spot); -omega*r = inertially
			# still, ground streaming past at spin speed = orbit. Invisible without a readout.
			if q_hud < 0.5:
				var omega_h := _spin_omega()
				var rr_h: float = maxf(_radius() - _altitude, 1.0)
				airinfo += "  GROUND %+.0f m/s" % _air_vel.x
				if _altitude > 100.0 and absf(_air_vel.x + omega_h * rr_h) < omega_h * rr_h * 0.12:
					airinfo += "  ORBIT"
			# DOCKING (TASKS.md). The axis-structure port is invisible from range without a readout, same as
			# ORBIT: show the closing range as you approach, prompt in the envelope, and the latched/boarded state.
			if _docked:
				airinfo += "  BOARDED (axis structure) — [Enter] pilot" if _boarded else "  DOCKED — [Enter] board"
			elif _altitude > 100.0:
				var dr := _dock_range()
				airinfo += "  PORT %.1fkm" % (dr / 1000.0)
				if dr < DOCK_CAPTURE_R:
					airinfo += "  (null velocity to dock)"
			airinfo += "  (Space climb, Shift descend)"
		# CONDITION. Fuel and wear are invisible until they bite, and "the engine just stopped" with no
		# warning is a bug report rather than a decision. Shown for anything that carries a tank.
		var cc := _cond()
		var ccap := _cond_cap(vd)
		if ccap > 0.0:
			var pct: float = float(cc["fuel"]) / ccap * 100.0
			airinfo += "  FUEL %.0f%%" % pct
			if pct <= 0.0:
				airinfo += " DRY"
		if float(cc["wear"]) > 0.02:
			airinfo += "  WEAR %.0f%%" % (float(cc["wear"]) * 100.0)
		mode = "DRIVE  %d km/h  [%s] — %s%s%s%s%s  (WASD steer, [L] vehicle, [V] cycle mode)" % [int(abs(_car_speed) * 3.6), vn, purpose, mount, suit, subm, airinfo]
	elif _mode == Mode.WALK:
		mode = "WALK  (WASD + mouse-look, Shift run, ESC release, [V] cycle mode)"
	if not _hud_full:
		_hud.text = "[ESC] release mouse   [TAB] controls   [O] sliders   [G] warp   %s%s" % [mode, wtxt]
		return
	var haze_km: float = 1.0 / maxf(haze_density, 1e-9) / 1000.0
	var lc := _tree_counts if _tree_counts.size() == TREE_LODS else PackedInt32Array([0, 0, 0, 0])
	var threat := "THREAT (wolf closing)" if _threat_active else "calm (null-write holding)"
	# grouped by system rather than one long undifferentiated key dump
	var lines := [
		"[ESC] release mouse    [TAB] hide controls    [O] sliders %s    [G] warp menu %s" % [
			("(open)" if _panel_open else ""), ("(open)" if _warp_open else "")],
		"mode: %s%s" % [mode, wtxt],
		"",
		"RING    C %.0f km   W %.1f km   R %.1f km   rise @20km %.0f m  @50km %.0f m   far-side %.2f deg (moon 0.52)" % [
			c / 1000.0, w / 1000.0, r / 1000.0, rise20, rise50, band_deg],
		"        [1/2/3] circumference   [Q/W/E] width   [R] rebuild        (config keys: release mouse first)",
		"",
		"SKY     sun period %s s   haze ~%.0f km %s   day %.2f   atmos %s" % [
			("off" if SUN_PERIODS[sun_speed_idx] == 0.0 else str(SUN_PERIODS[sun_speed_idx])),
			haze_km, "(OFF)" if _haze_off else "", _dbg_day,
			("VACUUM" if _space > 0.98 else ("%.0f%% thinned" % (_space * 100.0)) if _space > 0.01 else "sea level")],
		"        [T] sun speed   [P] pause sun   [F] flip day/night   [Up/Dn] haze   [N] haze on/off",
		"",
		"CLOUDS  %s   %s" % [
			(_clouds.type_name() if _clouds else "n/a"),
			("visible" if (_clouds and _clouds.is_visible_flag()) else "HIDDEN")],
		"        [Z] cycle type   [X] show/hide   [O] tuning sliders",
		"",
		"TERRAIN %s   LOD nodes %d   trees %d (LOD0/1/2/bill %d/%d/%d/%d)" % [
			("none (noise)" if _dem_w == 0 else "%s  height x%.0f" % [_dem_name, dem_scale]),
			_used, _tree_ground.size(), lc[0], lc[1], lc[2], lc[3]],
		"        OSM buildings %d of %d in range %.1fkm   grass %d" % [
			_bldg_shown, _bldg.size() / 6, BLDG_RADIUS / 1000.0, _grass_shown],
		"        splice here: %s   (%d placed)   [,] [.] jump splice   hi-res: %s" % [
			_here_splice(), _patch_rects.size(),
			(_patch_names[_hires_idx] if _hires_idx >= 0 else ("loading..." if _hires_pending >= 0 else "-"))],
		"        [H] terrain height   [G]/[B] tree LOD band x%.2f   [M] LOD colour %s" % [
			_tree_lod_scale, "ON" if _show_lod else "off"],
		"",
		"SLICE   creatures %d   %s" % [_creatures.size(), threat],
		"        [K] deer herd   [J] wolf pack   [C] clear",
		"",
		"DBG     cam_theta %.1f deg   sun_theta %.1f deg   local_lit %.2f   [Y] probe %s" % [
			_dbg_cam_theta_deg, _dbg_sun_theta_deg, _dbg_local_lit, "on" if _probe_on else "off"],
	]
	if _probe_on:
		lines.append("")
		lines.append(_probe_text())
	_hud.text = "\n".join(lines)
