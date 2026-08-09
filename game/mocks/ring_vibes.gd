extends Node3D
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
const SPACE_LO := 14_000.0        # m above the ring surface where thinning starts
const SPACE_HI := 48_000.0        # m by which it reads as vacuum
var _space := 0.0                 # 0 = in atmosphere, 1 = space
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
	# trees 0.1 is right and stays. Two defects logged instead -- see docs/patch-review.md.
	{"name": "danube_delta", "arc_pct": 0.252, "tint": Color(0.30, 0.34, 0.24), "trees": 0.1, "tree_hi": 40.0, "weather": "overcast", "species": "scrub"},
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
const WARTHOG_PACK := "res://halo_warthog/scene.gltf"  # local-only asset (gitignored); box car is the fallback
const VEHICLE_LEN := 5.2          # metres nose-to-tail; the box car is 4.2, the warthog reads as bigger
# Scale and length-axis are measured from the model's AABB, so the only thing not derivable is which
# END is the nose. Eyeball logs/shots/vehicle_warthog.png; if it drives tail-first, set this to PI.
const WARTHOG_YAW := 0.0
var _wheel_spin := 0.0
var _dust: GPUParticles3D = null
var _offroad := 0.0               # 0 = on tarmac, 1 = fully off it
var _car_arc := 0.0
var _car_lat := 0.0
var _car_heading := 0.0
var _car_speed := 0.0
var _hud_timer := 0.0

# First-slice creature test (slice-mock.md) — generic startle/flee proxy, deer + wolf presets
const CreatureScript := preload("res://mocks/creature.gd")
var _creatures: Array = []
var _threat_active := false
var _walls: Array[MeshInstance3D] = []
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
		for shot in [
				{"n": "ground", "h": 2.2, "pitch": -0.04, "fov": 70.0},
				{"n": "road", "h": 6.0, "pitch": -0.18, "fov": 60.0},
				{"n": "air", "h": 400.0, "pitch": -0.55, "fov": 70.0},
			]:
			_cam.position = _ring_pos(arc / r, lat, _terrain_h(arc, lat) + float(shot["h"]))
			_cam.fov = float(shot["fov"])
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
			print("SHOT %-18s %-7s tris=%d fps=%d  %s" % [
				pname, shot["n"],
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				int(Engine.get_frames_per_second()), path])
	# VEHICLES. The patch loop above never enters DRIVE, so an imported car model could be sideways,
	# giant or underground and no frame would catch it. Enter DRIVE at home, let the chase cam settle,
	# and shoot each vehicle from behind -- the framing that shows orientation, scale and grounding.
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
		print("SHOT vehicle %-8s %s" % [vname, vpath])
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
		if REBASE_PATCHES:
			var floor_h := _patch_floor(floats)
			_patch_offset.append(REBASE_FLOOR - floor_h if floor_h > REBASE_ABOVE else 0.0)
		else:
			_patch_offset.append(0.0)   # real absolute elevation
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
	var h := _terrain_h_raw(arc, lat)
	return SEA_LEVEL if (ocean_enabled and h < SEA_LEVEL) else h

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
		var nx := clampf(_cam.position.x, ox, ox + size)
		var nz := clampf(_cam.position.z, oz, oz + size)
		if _cam.position.distance_to(Vector3(nx, 0.0, nz)) < _lod_range[level - 1]:
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
	var cp := Vector3(_cam.position.x, _cam.position.y, _cam.position.z)
	var r := _radius()
	var w: float = WIDTHS[w_idx]
	for i in _used:
		_mats[i].set_shader_parameter("cam_pos", cp)
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
var wall_top_h := 4000.0       # rim height toward the axis; live-tunable ([O]) since it sets shadow reach

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
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		if not _wall_mat:
			_wall_mat = ShaderMaterial.new()
			_wall_mat.shader = load("res://mocks/ring_vibes_wall.gdshader") as Shader
		mi.material_override = _wall_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_walls.append(mi)

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
	_space = smoothstep(SPACE_LO, SPACE_HI, cam_alt)
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
			for v in [a, a + Vector3(0, bh, 0), b, b, a + Vector3(0, bh, 0), b + Vector3(0, bh, 0)]:
				st.set_color(bc)
				st.add_vertex(v)
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
	for vi in _tree_mm.size():
		for l in TREE_LODS:
			if _tree_mm[vi][l] == null:
				continue
			var m := _species_mesh(kind, vi, l)
			m.surface_set_material(0, mat)
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
	for i in n:
		var o := 8 + i * 24
		var lt := b.decode_float(o + 4) + lat_off
		if absf(lt) > lat_lim:
			continue
		var ar := b.decode_float(o) + arc_off
		_bldg.append(fposmod(ar, circ))
		_bldg.append(lt)
		_bldg.append(b.decode_float(o + 8))
		_bldg.append(b.decode_float(o + 12))
		_bldg.append(b.decode_float(o + 16))
		_bldg.append(b.decode_float(o + 20))
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
		print("ring_vibes: %s — %d of %d buildings kept (%d fell outside the %0.0fkm ring width)"
			% [name, kept, n, n - kept, WIDTHS[w_idx] / 1000.0])
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

func _make_car() -> Node3D:
	_wheels = []
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 1.0, 4.2)
	body.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.33, 0.36, 0.30)
	body.material_override = bmat
	body.position.y = 0.9
	root.add_child(body)
	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(1.7, 0.5, 1.1)
	glass.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.45, 0.75, 0.80)  # frutiger windscreen, obviously
	glass.material_override = gmat
	glass.position = Vector3(0, 1.55, -0.5)
	root.add_child(glass)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.10, 0.10, 0.10)
	for wp in [Vector3(-1.05, 0.45, 1.4), Vector3(1.05, 0.45, 1.4), Vector3(-1.05, 0.45, -1.4), Vector3(1.05, 0.45, -1.4)]:
		var wheel := MeshInstance3D.new()
		var cm := CylinderMesh.new()
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
		_wheels.append({"pivot": pivot, "mesh": wheel, "front": wp.z > 0.0})
	add_child(root)
	return root

func _build_vehicles() -> void:
	# One box car was the whole fleet; the halo_warthog model sat unused in assets/. Build both once
	# and let [L] swap between them in DRIVE. The box keeps its rolling/steering wheels; the warthog
	# is a proper silhouette. The asset is gitignored (local only), so a machine without it just gets
	# the box -- hence the box stays index 0 and the fallback.
	if not _vehicles.is_empty():
		return
	var box := _make_car()          # sets _wheels as a side effect
	box.visible = false
	_vehicles.append({"root": box, "wheels": _wheels, "name": "box"})
	var hog := _make_warthog()
	if hog:
		hog.visible = false
		_vehicles.append({"root": hog, "wheels": _collect_wheels(hog), "name": "warthog"})

func _select_vehicle(i: int) -> void:
	if _vehicles.is_empty():
		return
	_veh_idx = posmod(i, _vehicles.size())
	for j in _vehicles.size():
		_vehicles[j]["root"].visible = (j == _veh_idx and _mode == Mode.DRIVE)
	var e: Dictionary = _vehicles[_veh_idx]
	_car = e["root"]
	_wheels = e["wheels"]
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
				out.append({"pivot": n, "mesh": n, "front": (n as Node3D).position.z > 0.0})
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

func _drive_tick(delta: float) -> void:
	var accel := 0.0
	if Input.is_key_pressed(KEY_W): accel += 9.0
	if Input.is_key_pressed(KEY_S): accel -= 12.0
	_car_speed = clampf(_car_speed + accel * delta, -6.0, 22.0)  # ~80 km/h top (was 160)
	# offroad drags harder and steers vaguer -- the difference should be felt in the
	# handling, not just seen in a particle effect. Off-roading is a mode, not a penalty:
	# top speed drops maybe a third, it does not become unusable.
	_car_speed *= 1.0 - (0.35 + 0.55 * _offroad) * delta
	var steer := 0.0
	if Input.is_key_pressed(KEY_A): steer -= 1.0
	if Input.is_key_pressed(KEY_D): steer += 1.0
	_car_heading += steer * (1.5 - 0.45 * _offroad) * delta * clampf(abs(_car_speed) / 12.0, 0.0, 1.0) * signf(_car_speed)
	_car_arc += cos(_car_heading) * _car_speed * delta
	_car_lat += sin(_car_heading) * _car_speed * delta
	var pos := _car_pos(_car_arc, _car_lat)
	var ahead := _car_pos(_car_arc + cos(_car_heading) * 5.0, _car_lat + sin(_car_heading) * 5.0)
	var up := _ring_up(pos)
	_car.global_position = pos + up * 0.4
	if not pos.is_equal_approx(ahead):
		_car.look_at(ahead + up * 0.4, up)
	# WHEELS. They were four static cylinders: the single loudest tell that a vehicle is a prop.
	# Roll rate is circumference-correct rather than a guessed multiplier, so it never looks
	# like it is skating.
	_wheel_spin += (_car_speed * delta) / 0.45
	for w in _wheels:
		var mesh: MeshInstance3D = w["mesh"]
		mesh.rotation = Vector3(0.0, 0.0, PI * 0.5)
		mesh.rotate_object_local(Vector3(0, 1, 0), -_wheel_spin)
		var piv: Node3D = w["pivot"]
		piv.rotation.y = (steer * -0.42) if bool(w["front"]) else 0.0
	# OFFROAD. The road mask is 44m per cell, which cannot say "am I on this lane" -- but the
	# 8m road cells built from the centrelines can, and already exist for the grass.
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
	var cam_target: Vector3 = cam_ground + cam_up * 5.0
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
			KEY_L:
				# swap vehicle -- only meaningful while driving, and only if the warthog asset loaded
				if _mode == Mode.DRIVE and _vehicles.size() > 1:
					_select_vehicle(_veh_idx + 1)
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
	if _mode == Mode.DRIVE:
		var vn: String = _vehicles[_veh_idx]["name"] if _veh_idx < _vehicles.size() else "box"
		mode = "DRIVE  %d km/h  [%s]  (WASD steer, [L] vehicle, [V] cycle mode)" % [int(abs(_car_speed) * 3.6), vn]
	elif _mode == Mode.WALK:
		mode = "WALK  (WASD + mouse-look, Shift run, ESC release, [V] cycle mode)"
	if not _hud_full:
		_hud.text = "[ESC] release mouse   [TAB] controls   [O] sliders   [G] warp   %s" % mode
		return
	var haze_km: float = 1.0 / maxf(haze_density, 1e-9) / 1000.0
	var lc := _tree_counts if _tree_counts.size() == TREE_LODS else PackedInt32Array([0, 0, 0, 0])
	var threat := "THREAT (wolf closing)" if _threat_active else "calm (null-write holding)"
	# grouped by system rather than one long undifferentiated key dump
	var lines := [
		"[ESC] release mouse    [TAB] hide controls    [O] sliders %s    [G] warp menu %s" % [
			("(open)" if _panel_open else ""), ("(open)" if _warp_open else "")],
		"mode: %s" % mode,
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
