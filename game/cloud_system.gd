extends Node3D
class_name CloudSystem

const CUMULUS_BASE := 600.0
const CUMULUS_TOP  := 1200.0
const CHUNK_XZ     := 512.0
const CHUNK_Y      := (CUMULUS_TOP - CUMULUS_BASE)
const ALTOCUM_Y    := 2800.0
const CIRRUS_BASE  := 4500.0
const CIRRUS_TOP   := 5500.0

# [max_horiz_dist, lod_type (0=MC 1=billboard), grid_xz, grid_y]
const LODS := [
	[2400.0, 0, 24, 12],   # < 2400m 3D: marching cubes (cumulus)
	[3500.0, 1,  0,  0],   # < 3500m: billboard (altocumulus)
	[7000.0, 1,  0,  0],   # < 7000m: billboard far
]

const PLANE_SIZE        := 32000.0  # 32km — covers camera.far in every direction
const DENSITY_PRESETS   := [[0.25, 0.12], [0.52, 0.18], [0.72, 0.22]]
const DENSITY_NAMES     := ["wispy", "normal", "heavy"]
const SPEED_PRESETS     := [0.003, 0.008, 0.025]
const SPEED_NAMES       := ["slow", "normal", "fast"]
const DIR_PRESETS       := [
	Vector2( 1.0,  0.0), Vector2( 0.7,  0.7), Vector2( 0.0,  1.0),
	Vector2(-0.7,  0.7), Vector2(-1.0,  0.0), Vector2(-0.7, -0.7),
	Vector2( 0.0, -1.0), Vector2( 0.7, -0.7),
]
const DIR_NAMES         := ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]
const LAYER_DIR_OFFSETS := [0.0, 35.0, -25.0]  # degrees from base dir per layer
const LAYER_SPEED_MULT  := [1.0, 0.55, 0.30]   # speed factor per layer
const VIEW_RADIUS := 12   # chunks each direction
const ISO         := 0.05

var _noise    : FastNoiseLite
var _mat      : ShaderMaterial
var _billboard_shader : Shader = null
var _chunks   : Dictionary = {}   # Vector2i → {mi, lod}
var _camera   : Camera3D = null

var show_mc        : bool = false
var show_billboard : bool = false
var show_layers    : bool = true
var debug_active   : bool = false
var layer_count    : int  = 1
var preset_density : int  = 1
var preset_speed   : int  = 1
var preset_dir     : int  = 0
var _layers        : Array = []

# ── Marching-cubes lookup tables ─────────────────────────────────────────────
# edgeTable[256] — which of the 12 edges are cut for each of 256 vertex configs
const EDGE_TABLE := [
	0x000,0x109,0x203,0x30a,0x406,0x50f,0x605,0x70c,
	0x80c,0x905,0xa0f,0xb06,0xc0a,0xd03,0xe09,0xf00,
	0x190,0x099,0x393,0x29a,0x596,0x49f,0x795,0x69c,
	0x99c,0x895,0xb9f,0xa96,0xd9a,0xc93,0xf99,0xe90,
	0x230,0x339,0x033,0x13a,0x636,0x73f,0x435,0x53c,
	0xa3c,0xb35,0x83f,0x936,0xe3a,0xf33,0xc39,0xd30,
	0x3a0,0x2a9,0x1a3,0x0aa,0x7a6,0x6af,0x5a5,0x4ac,
	0xbac,0xaa5,0x9af,0x8a6,0xfaa,0xea3,0xda9,0xca0,
	0x460,0x569,0x663,0x76a,0x066,0x16f,0x265,0x36c,
	0xc6c,0xd65,0xe6f,0xf66,0x86a,0x963,0xa69,0xb60,
	0x5f0,0x4f9,0x7f3,0x6fa,0x1f6,0x0ff,0x3f5,0x2fc,
	0xdfc,0xcf5,0xfff,0xef6,0x9fa,0x8f3,0xbf9,0xaf0,
	0x650,0x759,0x453,0x55a,0x256,0x35f,0x055,0x15c,
	0xe5c,0xf55,0xc5f,0xd56,0xa5a,0xb53,0x859,0x950,
	0x7c0,0x6c9,0x5c3,0x4ca,0x3c6,0x2cf,0x1c5,0x0cc,
	0xfcc,0xec5,0xdcf,0xcc6,0xbca,0xac3,0x9c9,0x8c0,
	0x8c0,0x9c9,0xac3,0xbca,0xcc6,0xdcf,0xec5,0xfcc,
	0x0cc,0x1c5,0x2cf,0x3c6,0x4ca,0x5c3,0x6c9,0x7c0,
	0x950,0x859,0xb53,0xa5a,0xd56,0xc5f,0xf55,0xe5c,
	0x15c,0x055,0x35f,0x256,0x55a,0x453,0x759,0x650,
	0xaf0,0xbf9,0x8f3,0x9fa,0xef6,0xfff,0xcf5,0xdfc,
	0x2fc,0x3f5,0x0ff,0x1f6,0x6fa,0x7f3,0x4f9,0x5f0,
	0xb60,0xa69,0x963,0x86a,0xf66,0xe6f,0xd65,0xc6c,
	0x36c,0x265,0x16f,0x066,0x76a,0x663,0x569,0x460,
	0xca0,0xda9,0xea3,0xfaa,0x8a6,0x9af,0xaa5,0xbac,
	0x4ac,0x5a5,0x6af,0x7a6,0x0aa,0x1a3,0x2a9,0x3a0,
	0xd30,0xc39,0xf33,0xe3a,0x936,0x83f,0xb35,0xa3c,
	0x53c,0x435,0x73f,0x636,0x13a,0x033,0x339,0x230,
	0xe90,0xf99,0xc93,0xd9a,0xa96,0xb9f,0x895,0x99c,
	0x69c,0x795,0x49f,0x596,0x29a,0x393,0x099,0x190,
	0xf00,0xe09,0xd03,0xc0a,0xb06,0xa0f,0x905,0x80c,
	0x70c,0x605,0x50f,0x406,0x30a,0x203,0x109,0x000,
]

# triTable[256*16] — up to 5 triangles per case, edge indices, -1 = end
const TRI_TABLE := [
	-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,8,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,1,9,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	1,8,3,9,8,1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	1,2,10,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,8,3,1,2,10,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	9,2,10,0,2,9,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	2,8,3,2,10,8,10,9,8,-1,-1,-1,-1,-1,-1,-1,
	3,11,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,11,2,8,11,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	1,9,0,2,3,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	1,11,2,1,9,11,9,8,11,-1,-1,-1,-1,-1,-1,-1,
	3,10,1,11,10,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,10,1,0,8,10,8,11,10,-1,-1,-1,-1,-1,-1,-1,
	3,9,0,3,11,9,11,10,9,-1,-1,-1,-1,-1,-1,-1,
	9,8,10,10,8,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	4,7,8,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	4,3,0,7,3,4,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,1,9,8,4,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	4,1,9,4,7,1,7,3,1,-1,-1,-1,-1,-1,-1,-1,
	1,2,10,8,4,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	3,4,7,3,0,4,1,2,10,-1,-1,-1,-1,-1,-1,-1,
	9,2,10,9,0,2,8,4,7,-1,-1,-1,-1,-1,-1,-1,
	2,10,9,2,9,7,2,7,3,7,9,4,-1,-1,-1,-1,
	8,4,7,3,11,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	11,4,7,11,2,4,2,0,4,-1,-1,-1,-1,-1,-1,-1,
	9,0,1,8,4,7,2,3,11,-1,-1,-1,-1,-1,-1,-1,
	4,7,11,9,4,11,9,11,2,9,2,1,-1,-1,-1,-1,
	3,10,1,3,11,10,7,8,4,-1,-1,-1,-1,-1,-1,-1,
	1,11,10,1,4,11,1,0,4,7,11,4,-1,-1,-1,-1,
	4,7,8,9,0,11,9,11,10,11,0,3,-1,-1,-1,-1,
	4,7,11,4,11,9,9,11,10,-1,-1,-1,-1,-1,-1,-1,
	9,5,4,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	9,5,4,0,8,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,5,4,1,5,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	8,5,4,8,3,5,3,1,5,-1,-1,-1,-1,-1,-1,-1,
	1,2,10,9,5,4,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	3,0,8,1,2,10,4,9,5,-1,-1,-1,-1,-1,-1,-1,
	5,2,10,5,4,2,4,0,2,-1,-1,-1,-1,-1,-1,-1,
	2,10,5,3,2,5,3,5,4,3,4,8,-1,-1,-1,-1,
	9,5,4,2,3,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,11,2,0,8,11,4,9,5,-1,-1,-1,-1,-1,-1,-1,
	0,5,4,0,1,5,2,3,11,-1,-1,-1,-1,-1,-1,-1,
	2,1,5,2,5,8,2,8,11,4,8,5,-1,-1,-1,-1,
	10,3,11,10,1,3,9,5,4,-1,-1,-1,-1,-1,-1,-1,
	4,9,5,0,8,1,8,10,1,8,11,10,-1,-1,-1,-1,
	5,4,0,5,0,11,5,11,10,11,0,3,-1,-1,-1,-1,
	5,4,8,5,8,10,10,8,11,-1,-1,-1,-1,-1,-1,-1,
	9,7,8,5,7,9,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	9,3,0,9,5,3,5,7,3,-1,-1,-1,-1,-1,-1,-1,
	0,7,8,0,1,7,1,5,7,-1,-1,-1,-1,-1,-1,-1,
	1,5,3,3,5,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	9,7,8,9,5,7,10,1,2,-1,-1,-1,-1,-1,-1,-1,
	10,1,2,9,5,0,5,3,0,5,7,3,-1,-1,-1,-1,
	8,0,2,8,2,5,8,5,7,10,5,2,-1,-1,-1,-1,
	2,10,5,2,5,3,3,5,7,-1,-1,-1,-1,-1,-1,-1,
	7,9,5,7,8,9,3,11,2,-1,-1,-1,-1,-1,-1,-1,
	9,5,7,9,7,2,9,2,0,2,7,11,-1,-1,-1,-1,
	2,3,11,0,1,8,1,7,8,1,5,7,-1,-1,-1,-1,
	11,2,1,11,1,7,7,1,5,-1,-1,-1,-1,-1,-1,-1,
	9,5,8,8,5,7,10,1,3,10,3,11,-1,-1,-1,-1,
	5,7,0,5,0,9,7,11,0,1,0,10,11,10,0,-1,
	11,10,0,11,0,3,10,5,0,8,0,7,5,7,0,-1,
	11,10,5,7,11,5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	10,6,5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,8,3,5,10,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	9,0,1,5,10,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	1,8,3,1,9,8,5,10,6,-1,-1,-1,-1,-1,-1,-1,
	1,6,5,2,6,1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	1,6,5,1,2,6,3,0,8,-1,-1,-1,-1,-1,-1,-1,
	9,6,5,9,0,6,0,2,6,-1,-1,-1,-1,-1,-1,-1,
	5,9,8,5,8,2,5,2,6,3,2,8,-1,-1,-1,-1,
	2,3,11,10,6,5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	11,0,8,11,2,0,10,6,5,-1,-1,-1,-1,-1,-1,-1,
	0,1,9,2,3,11,5,10,6,-1,-1,-1,-1,-1,-1,-1,
	5,10,6,1,9,2,9,11,2,9,8,11,-1,-1,-1,-1,
	6,3,11,6,5,3,5,1,3,-1,-1,-1,-1,-1,-1,-1,
	0,8,11,0,11,5,0,5,1,5,11,6,-1,-1,-1,-1,
	3,11,6,0,3,6,0,6,5,0,5,9,-1,-1,-1,-1,
	6,5,9,6,9,11,11,9,8,-1,-1,-1,-1,-1,-1,-1,
	5,10,6,4,7,8,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	4,3,0,4,7,3,6,5,10,-1,-1,-1,-1,-1,-1,-1,
	1,9,0,5,10,6,8,4,7,-1,-1,-1,-1,-1,-1,-1,
	10,6,5,1,9,7,1,7,3,7,9,4,-1,-1,-1,-1,
	6,1,2,6,5,1,4,7,8,-1,-1,-1,-1,-1,-1,-1,
	1,2,5,5,2,6,3,0,4,3,4,7,-1,-1,-1,-1,
	8,4,7,9,0,5,0,6,5,0,2,6,-1,-1,-1,-1,
	7,3,9,7,9,4,3,2,9,5,9,6,2,6,9,-1,
	3,11,2,7,8,4,10,6,5,-1,-1,-1,-1,-1,-1,-1,
	5,10,6,4,7,2,4,2,0,2,7,11,-1,-1,-1,-1,
	0,1,9,4,7,8,2,3,11,5,10,6,-1,-1,-1,-1,
	9,2,1,9,11,2,9,4,11,7,11,4,5,10,6,-1,
	8,4,7,3,11,5,3,5,1,5,11,6,-1,-1,-1,-1,
	5,1,11,5,11,6,1,0,11,7,11,4,0,4,11,-1,
	0,5,9,0,6,5,0,3,6,11,6,3,8,4,7,-1,
	6,5,9,6,9,11,4,7,9,7,11,9,-1,-1,-1,-1,
	10,4,9,6,4,10,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	4,10,6,4,9,10,0,8,3,-1,-1,-1,-1,-1,-1,-1,
	10,0,1,10,6,0,6,4,0,-1,-1,-1,-1,-1,-1,-1,
	8,3,1,8,1,6,8,6,4,6,1,10,-1,-1,-1,-1,
	1,4,9,1,2,4,2,6,4,-1,-1,-1,-1,-1,-1,-1,
	3,0,8,1,2,9,2,4,9,2,6,4,-1,-1,-1,-1,
	0,2,4,4,2,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	8,3,2,8,2,4,4,2,6,-1,-1,-1,-1,-1,-1,-1,
	10,4,9,10,6,4,11,2,3,-1,-1,-1,-1,-1,-1,-1,
	0,8,2,2,8,11,4,9,10,4,10,6,-1,-1,-1,-1,
	3,11,2,0,1,6,0,6,4,6,1,10,-1,-1,-1,-1,
	6,4,1,6,1,10,4,8,1,2,1,11,8,11,1,-1,
	9,6,4,9,3,6,9,1,3,11,6,3,-1,-1,-1,-1,
	8,11,1,8,1,0,11,6,1,9,1,4,6,4,1,-1,
	3,11,6,3,6,0,0,6,4,-1,-1,-1,-1,-1,-1,-1,
	6,4,8,11,6,8,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	7,10,6,7,8,10,8,9,10,-1,-1,-1,-1,-1,-1,-1,
	0,7,3,0,10,7,0,9,10,6,7,10,-1,-1,-1,-1,
	10,6,7,1,10,7,1,7,8,1,8,0,-1,-1,-1,-1,
	10,6,7,10,7,1,1,7,3,-1,-1,-1,-1,-1,-1,-1,
	1,2,6,1,6,8,1,8,9,8,6,7,-1,-1,-1,-1,
	2,6,9,2,9,1,6,7,9,0,9,3,7,3,9,-1,
	7,8,0,7,0,6,6,0,2,-1,-1,-1,-1,-1,-1,-1,
	7,3,2,6,7,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	2,3,11,10,6,8,10,8,9,8,6,7,-1,-1,-1,-1,
	2,0,7,2,7,11,0,9,7,6,7,10,9,10,7,-1,
	1,8,0,1,7,8,1,10,7,6,7,10,2,3,11,-1,
	11,2,1,11,1,7,10,6,1,6,7,1,-1,-1,-1,-1,
	8,9,6,8,6,7,9,1,6,11,6,3,1,3,6,-1,
	0,9,1,11,6,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	7,8,0,7,0,6,3,11,0,11,6,0,-1,-1,-1,-1,
	7,11,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	7,6,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	3,0,8,11,7,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,1,9,11,7,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	8,1,9,8,3,1,11,7,6,-1,-1,-1,-1,-1,-1,-1,
	10,1,2,6,11,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	1,2,10,3,0,8,6,11,7,-1,-1,-1,-1,-1,-1,-1,
	2,9,0,2,10,9,6,11,7,-1,-1,-1,-1,-1,-1,-1,
	6,11,7,2,10,3,10,8,3,10,9,8,-1,-1,-1,-1,
	7,2,3,6,2,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	7,0,8,7,6,0,6,2,0,-1,-1,-1,-1,-1,-1,-1,
	2,7,6,2,3,7,0,1,9,-1,-1,-1,-1,-1,-1,-1,
	1,6,2,1,8,6,1,9,8,8,7,6,-1,-1,-1,-1,
	10,7,6,10,1,7,1,3,7,-1,-1,-1,-1,-1,-1,-1,
	10,7,6,1,7,10,1,8,7,1,0,8,-1,-1,-1,-1,
	0,3,7,0,7,10,0,10,9,6,10,7,-1,-1,-1,-1,
	7,6,10,7,10,8,8,10,9,-1,-1,-1,-1,-1,-1,-1,
	6,8,4,11,8,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	3,6,11,3,0,6,0,4,6,-1,-1,-1,-1,-1,-1,-1,
	8,6,11,8,4,6,9,0,1,-1,-1,-1,-1,-1,-1,-1,
	9,4,6,9,6,3,9,3,1,11,3,6,-1,-1,-1,-1,
	6,8,4,6,11,8,2,10,1,-1,-1,-1,-1,-1,-1,-1,
	1,2,10,3,0,11,0,6,11,0,4,6,-1,-1,-1,-1,
	4,11,8,4,6,11,0,2,9,2,10,9,-1,-1,-1,-1,
	10,9,3,10,3,2,9,4,3,11,3,6,4,6,3,-1,
	8,2,3,8,4,2,4,6,2,-1,-1,-1,-1,-1,-1,-1,
	0,4,2,4,6,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	1,9,0,2,3,4,2,4,6,4,3,8,-1,-1,-1,-1,
	1,9,4,1,4,2,2,4,6,-1,-1,-1,-1,-1,-1,-1,
	8,1,3,8,6,1,8,4,6,6,10,1,-1,-1,-1,-1,
	10,1,0,10,0,6,6,0,4,-1,-1,-1,-1,-1,-1,-1,
	4,6,3,4,3,8,6,10,3,0,3,9,10,9,3,-1,
	10,9,4,6,10,4,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	4,9,5,7,6,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,8,3,4,9,5,11,7,6,-1,-1,-1,-1,-1,-1,-1,
	5,0,1,5,4,0,7,6,11,-1,-1,-1,-1,-1,-1,-1,
	11,7,6,8,3,4,3,5,4,3,1,5,-1,-1,-1,-1,
	9,5,4,10,1,2,7,6,11,-1,-1,-1,-1,-1,-1,-1,
	6,11,7,1,2,10,0,8,3,4,9,5,-1,-1,-1,-1,
	7,6,11,5,4,10,4,2,10,4,0,2,-1,-1,-1,-1,
	3,4,8,3,5,4,3,2,5,10,5,2,11,7,6,-1,
	7,2,3,7,6,2,5,4,9,-1,-1,-1,-1,-1,-1,-1,
	9,5,4,0,8,6,0,6,2,6,8,7,-1,-1,-1,-1,
	3,6,2,3,7,6,1,5,0,5,4,0,-1,-1,-1,-1,
	6,2,8,6,8,7,2,1,8,4,8,5,1,5,8,-1,
	9,5,4,10,1,6,1,7,6,1,3,7,-1,-1,-1,-1,
	1,6,10,1,7,6,1,0,7,8,7,0,9,5,4,-1,
	4,0,10,4,10,5,0,3,10,6,10,7,3,7,10,-1,
	7,6,10,7,10,8,5,4,10,4,8,10,-1,-1,-1,-1,
	6,9,5,6,11,9,11,8,9,-1,-1,-1,-1,-1,-1,-1,
	3,6,11,0,6,3,0,5,6,0,9,5,-1,-1,-1,-1,
	0,11,8,0,5,11,0,1,5,5,6,11,-1,-1,-1,-1,
	6,11,3,6,3,5,5,3,1,-1,-1,-1,-1,-1,-1,-1,
	1,2,10,9,5,11,9,11,8,11,5,6,-1,-1,-1,-1,
	0,11,3,0,6,11,0,9,6,5,6,9,1,2,10,-1,
	11,8,5,11,5,6,8,0,5,10,5,2,0,2,5,-1,
	6,11,3,6,3,5,2,10,3,10,5,3,-1,-1,-1,-1,
	5,8,9,5,2,8,5,6,2,3,8,2,-1,-1,-1,-1,
	9,5,6,9,6,0,0,6,2,-1,-1,-1,-1,-1,-1,-1,
	1,5,8,1,8,0,5,6,8,3,8,2,6,2,8,-1,
	1,5,6,2,1,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	1,3,6,1,6,10,3,8,6,5,6,9,8,9,6,-1,
	10,1,0,10,0,6,9,5,0,5,6,0,-1,-1,-1,-1,
	0,3,8,5,6,10,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	10,5,6,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	11,5,10,7,5,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	11,5,10,11,7,5,8,3,0,-1,-1,-1,-1,-1,-1,-1,
	5,11,7,5,10,11,1,9,0,-1,-1,-1,-1,-1,-1,-1,
	10,7,5,10,11,7,9,8,1,8,3,1,-1,-1,-1,-1,
	11,1,2,11,7,1,7,5,1,-1,-1,-1,-1,-1,-1,-1,
	0,8,3,1,2,7,1,7,5,7,2,11,-1,-1,-1,-1,
	9,7,5,9,2,7,9,0,2,2,11,7,-1,-1,-1,-1,
	7,5,2,7,2,11,5,9,2,3,2,8,9,8,2,-1,
	2,5,10,2,3,5,3,7,5,-1,-1,-1,-1,-1,-1,-1,
	8,2,0,8,5,2,8,7,5,10,2,5,-1,-1,-1,-1,
	9,0,1,5,10,3,5,3,7,3,10,2,-1,-1,-1,-1,
	9,8,2,9,2,1,8,7,2,10,2,5,7,5,2,-1,
	1,3,5,3,7,5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,8,7,0,7,1,1,7,5,-1,-1,-1,-1,-1,-1,-1,
	9,0,3,9,3,5,5,3,7,-1,-1,-1,-1,-1,-1,-1,
	9,8,7,5,9,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	5,8,4,5,10,8,10,11,8,-1,-1,-1,-1,-1,-1,-1,
	5,0,4,5,11,0,5,10,11,11,3,0,-1,-1,-1,-1,
	0,1,9,8,4,10,8,10,11,10,4,5,-1,-1,-1,-1,
	10,11,4,10,4,5,11,3,4,9,4,1,3,1,4,-1,
	2,5,1,2,8,5,2,11,8,4,5,8,-1,-1,-1,-1,
	0,4,11,0,11,3,4,5,11,2,11,1,5,1,11,-1,
	0,2,5,0,5,9,2,11,5,4,5,8,11,8,5,-1,
	9,4,5,2,11,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	2,5,10,3,5,2,3,4,5,3,8,4,-1,-1,-1,-1,
	5,10,2,5,2,4,4,2,0,-1,-1,-1,-1,-1,-1,-1,
	3,10,2,3,5,10,3,8,5,4,5,8,0,1,9,-1,
	5,10,2,5,2,4,1,9,2,9,4,2,-1,-1,-1,-1,
	8,4,5,8,5,3,3,5,1,-1,-1,-1,-1,-1,-1,-1,
	0,4,5,1,0,5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	8,4,5,8,5,3,9,0,5,0,3,5,-1,-1,-1,-1,
	9,4,5,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	4,11,7,4,9,11,9,10,11,-1,-1,-1,-1,-1,-1,-1,
	0,8,3,4,9,7,9,11,7,9,10,11,-1,-1,-1,-1,
	1,10,11,1,11,4,1,4,0,7,4,11,-1,-1,-1,-1,
	3,1,4,3,4,8,1,10,4,7,4,11,10,11,4,-1,
	4,11,7,9,11,4,9,2,11,9,1,2,-1,-1,-1,-1,
	9,7,4,9,11,7,9,1,11,2,11,1,0,8,3,-1,
	11,7,4,11,4,2,2,4,0,-1,-1,-1,-1,-1,-1,-1,
	11,7,4,11,4,2,8,3,4,3,2,4,-1,-1,-1,-1,
	2,9,10,2,7,9,2,3,7,7,4,9,-1,-1,-1,-1,
	9,10,7,9,7,4,10,2,7,8,7,0,2,0,7,-1,
	3,7,10,3,10,2,7,4,10,1,10,0,4,0,10,-1,
	1,10,2,8,7,4,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	4,9,1,4,1,7,7,1,3,-1,-1,-1,-1,-1,-1,-1,
	4,9,1,4,1,7,0,8,1,8,7,1,-1,-1,-1,-1,
	4,0,3,7,4,3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	4,8,7,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	9,10,8,10,11,8,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	3,0,9,3,9,11,11,9,10,-1,-1,-1,-1,-1,-1,-1,
	0,1,10,0,10,8,8,10,11,-1,-1,-1,-1,-1,-1,-1,
	3,1,10,11,3,10,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	1,2,11,1,11,9,9,11,8,-1,-1,-1,-1,-1,-1,-1,
	3,0,9,3,9,11,1,2,9,2,11,9,-1,-1,-1,-1,
	0,2,11,8,0,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	3,2,11,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	2,3,8,2,8,10,10,8,9,-1,-1,-1,-1,-1,-1,-1,
	9,10,2,0,9,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	2,3,8,2,8,10,0,1,8,1,10,8,-1,-1,-1,-1,
	1,10,2,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	1,3,8,9,1,8,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,9,1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	0,3,8,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
	-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
]

# Edge vertex pairs: edge i connects corner _EDGE_CORNERS[i][0] to [i][1]
const EDGE_CORNERS := [
	[0,1],[1,2],[2,3],[3,0],  # bottom face edges
	[4,5],[5,6],[6,7],[7,4],  # top face edges
	[0,4],[1,5],[2,6],[3,7],  # vertical edges
]
# Corner offsets from chunk origin (ix,iy,iz = cell lower corner)
const CORNER_OFFSETS := [
	Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,0,1),Vector3i(0,0,1),
	Vector3i(0,1,0),Vector3i(1,1,0),Vector3i(1,1,1),Vector3i(0,1,1),
]

# ── Noise ────────────────────────────────────────────────────────────────────
var _noise2: FastNoiseLite  # detail layer

func _setup_noise():
	_noise = FastNoiseLite.new()
	_noise.noise_type     = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type   = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 5
	_noise.frequency      = 0.0006
	_noise.seed           = 42

	_noise2 = FastNoiseLite.new()
	_noise2.noise_type    = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise2.fractal_type  = FastNoiseLite.FRACTAL_FBM
	_noise2.fractal_octaves = 3
	_noise2.frequency     = 0.003
	_noise2.seed          = 99

func _sample(wx: float, wy: float, wz: float) -> float:
	# Vertical falloff to keep clouds in layer
	var rel_y = (wy - CUMULUS_BASE) / CHUNK_Y          # 0..1 inside layer
	var vfall = 1.0 - pow(abs(rel_y * 2.0 - 1.0), 2.0)  # peaks at centre
	var base  = _noise.get_noise_3d(wx, wy * 0.4, wz)
	var detail = _noise2.get_noise_3d(wx, wy * 0.4, wz) * 0.25
	return (base + detail) * vfall

# ── Material ─────────────────────────────────────────────────────────────────
func _setup_material():
	var shader = load("res://cloud_shader.gdshader") as Shader
	if not shader:
		push_error("CloudSystem: cloud_shader.gdshader not found")
		return
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("cloud_base", CUMULUS_BASE)
	_mat.set_shader_parameter("cloud_top",  CUMULUS_TOP)
	_billboard_shader = load("res://cloud_billboard_shader.gdshader") as Shader
	if not _billboard_shader:
		push_error("CloudSystem: cloud_billboard_shader.gdshader not found")

# ── Lifecycle ────────────────────────────────────────────────────────────────
var _diag_chunks_spawned: int = 0

func _ready():
	_setup_noise()
	_setup_material()
	_rebuild_layers()
	print("CloudSystem: ready, mat=", _mat != null)

func _unhandled_input(event):
	if not debug_active: return
	if not (event is InputEventKey and event.pressed and not event.echo): return
	match event.keycode:
		KEY_V: show_mc = not show_mc; _apply_visibility(); print("CloudSystem: MC ", "on" if show_mc else "off")
		KEY_B: show_billboard = not show_billboard; _apply_visibility(); print("CloudSystem: billboard ", "on" if show_billboard else "off")
		KEY_Z: show_layers = not show_layers; _apply_visibility(); print("CloudSystem: layers ", "on" if show_layers else "off")
		KEY_1: layer_count = 1; _rebuild_layers(); print("CloudSystem: 1 layer")
		KEY_2: layer_count = 2; _rebuild_layers(); print("CloudSystem: 2 layers")
		KEY_3: layer_count = 3; _rebuild_layers(); print("CloudSystem: 3 layers")
		KEY_4: preset_density = 0; _apply_layer_presets(); print("CloudSystem: wispy")
		KEY_5: preset_density = 1; _apply_layer_presets(); print("CloudSystem: normal density")
		KEY_6: preset_density = 2; _apply_layer_presets(); print("CloudSystem: heavy")
		KEY_7: preset_speed = 0; _apply_layer_presets(); print("CloudSystem: slow")
		KEY_8: preset_speed = 1; _apply_layer_presets(); print("CloudSystem: normal speed")
		KEY_9: preset_speed = 2; _apply_layer_presets(); print("CloudSystem: fast")
		KEY_0:
			preset_dir = (preset_dir + 1) % DIR_PRESETS.size()
			_apply_layer_presets()
			print("CloudSystem: dir ", DIR_NAMES[preset_dir])

func _apply_visibility():
	for lm in _layers:
		lm.visible = show_layers
	for coord in _chunks:
		var is_bb = _chunks[coord].get("type", 0) == 1
		_chunks[coord]["mi"].visible = show_billboard if is_bb else show_mc

func _rebuild_layers():
	for lm in _layers:
		lm.queue_free()
	_layers.clear()
	_build_layers()
	_apply_layer_presets()
	_apply_visibility()

func _apply_layer_presets():
	var dp = DENSITY_PRESETS[preset_density]
	var sp = SPEED_PRESETS[preset_speed]
	var base_dir = DIR_PRESETS[preset_dir]
	for i in _layers.size():
		var mat = _layers[i].material_override as ShaderMaterial
		if not mat: continue
		mat.set_shader_parameter("coverage", dp[0])
		mat.set_shader_parameter("softness", dp[1])
		var angle = deg_to_rad(LAYER_DIR_OFFSETS[i])
		var c = cos(angle); var s = sin(angle)
		var dir = Vector2(base_dir.x * c - base_dir.y * s, base_dir.x * s + base_dir.y * c)
		mat.set_shader_parameter("wind_dir",   dir)
		mat.set_shader_parameter("wind_speed", sp * LAYER_SPEED_MULT[i])

func _build_layers():
	var shader = load("res://cloud_layer_shader.gdshader") as Shader
	if not shader:
		push_error("CloudSystem: cloud_layer_shader.gdshader not found")
		return
	var half = PLANE_SIZE * 0.5
	for i in layer_count:
		var t  = 0.5 if layer_count <= 1 else float(i) / float(layer_count - 1)
		var y  = CIRRUS_BASE + t * (CIRRUS_TOP - CIRRUS_BASE)
		var verts = PackedVector3Array([
			Vector3(-half, 0.0, -half),
			Vector3( half, 0.0, -half),
			Vector3(-half, 0.0,  half),
			Vector3( half, 0.0,  half),
		])
		var normals = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
		var indices = PackedInt32Array([0, 1, 2, 1, 3, 2])
		var arr = Array(); arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = normals
		arr[Mesh.ARRAY_INDEX]  = indices
		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("cloud_base",      CIRRUS_BASE)
		mat.set_shader_parameter("cloud_top",       CIRRUS_TOP)
		mat.set_shader_parameter("layer_t",         t)
		mat.set_shader_parameter("plane_half_size", half)
		var mi = MeshInstance3D.new()
		mi.mesh             = mesh
		mi.material_override = mat
		mi.cast_shadow      = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode          = GeometryInstance3D.GI_MODE_DISABLED
		mi.position         = Vector3(0.0, y, 0.0)
		add_child(mi)
		_layers.append(mi)

func _process(_delta):
	if not _camera:
		_camera = get_viewport().get_camera_3d()
		if _camera:
			print("CloudSystem: camera found at ", _camera.global_position)
		else:
			return

	# Layer planes always track camera XZ
	for lm in _layers:
		lm.global_position.x = _camera.global_position.x
		lm.global_position.z = _camera.global_position.z

	# Cull all chunks when both MC and billboard are disabled
	if not show_mc and not show_billboard:
		for coord in _chunks.keys():
			_chunks[coord]["mi"].queue_free()
		_chunks.clear()
		return

	var cp   = _camera.global_position
	var ccx  = int(floor(cp.x / CHUNK_XZ))
	var ccz  = int(floor(cp.z / CHUNK_XZ))

	var desired: Dictionary = {}
	for dz in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
		for dx in range(-VIEW_RADIUS, VIEW_RADIUS + 1):
			var coord = Vector2i(ccx + dx, ccz + dz)
			var wx = (coord.x + 0.5) * CHUNK_XZ
			var wz = (coord.y + 0.5) * CHUNK_XZ
			var dist3d = Vector3(cp.x - wx, cp.y - (CUMULUS_BASE + CUMULUS_TOP) * 0.5, cp.z - wz).length()
			var lod = _lod_for_dist(dist3d)
			if lod >= 0:
				desired[coord] = lod

	# Remove out-of-range chunks
	for coord in _chunks.keys():
		if not desired.has(coord):
			_chunks[coord]["mi"].queue_free()
			_chunks.erase(coord)

	# Spawn / update chunks
	for coord in desired.keys():
		var lod = desired[coord]
		if _chunks.has(coord):
			if _chunks[coord]["lod"] == lod:
				continue
			_chunks[coord]["mi"].queue_free()
			_chunks.erase(coord)
		_spawn_chunk(coord, lod)

func _lod_for_dist(d: float) -> int:
	for i in LODS.size():
		if d < LODS[i][0]:
			return i
	return -1

# ── Chunk generation ─────────────────────────────────────────────────────────
func _spawn_chunk(coord: Vector2i, lod: int):
	if LODS[lod][1] == 1:
		_spawn_chunk_billboard(coord, lod)
		return
	var gxz: int = LODS[lod][2]
	var gy:  int = LODS[lod][3]
	var ox = coord.x * CHUNK_XZ
	var oz = coord.y * CHUNK_XZ
	var oy = CUMULUS_BASE
	var sx = CHUNK_XZ / gxz
	var sy = CHUNK_Y  / gy
	var sz = CHUNK_XZ / gxz

	# Sample density grid (gxz+1)^2 × (gy+1)
	var nx = gxz + 1
	var ny = gy  + 1
	var nz = gxz + 1
	var grid = PackedFloat32Array()
	grid.resize(nx * ny * nz)
	for iy in ny:
		for iz in nz:
			for ix in nx:
				grid[iy * nz * nx + iz * nx + ix] = \
					_sample(ox + ix * sx, oy + iy * sy, oz + iz * sz)

	var mesh = _marching_cubes(grid, nx, ny, nz, ox, oy, oz, sx, sy, sz)
	if not mesh:
		if _diag_chunks_spawned == 0:
			print("CloudSystem: chunk ", coord, " is empty (no geometry)")
		return

	_diag_chunks_spawned += 1
	if _diag_chunks_spawned <= 3:
		print("CloudSystem: spawned chunk ", coord, " lod=", lod, " verts=", mesh.get_surface_count())

	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode     = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)
	_chunks[coord] = {"mi": mi, "lod": lod, "type": 0}

func _spawn_chunk_billboard(coord: Vector2i, lod: int):
	if not _billboard_shader:
		return
	var quad = QuadMesh.new()
	quad.size = Vector2(CHUNK_XZ, CHUNK_XZ)
	quad.orientation = PlaneMesh.FACE_Z
	var mi = MeshInstance3D.new()
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode     = GeometryInstance3D.GI_MODE_DISABLED
	mi.position    = Vector3(
		(coord.x + 0.5) * CHUNK_XZ,
		ALTOCUM_Y,
		(coord.y + 0.5) * CHUNK_XZ)
	var mat = ShaderMaterial.new()
	mat.shader = _billboard_shader
	mi.material_override = mat
	add_child(mi)
	_chunks[coord] = {"mi": mi, "lod": lod, "type": 1}

# ── Marching cubes ────────────────────────────────────────────────────────────
func _marching_cubes(grid: PackedFloat32Array,
		nx: int, ny: int, nz: int,
		ox: float, oy: float, oz: float,
		sx: float, sy: float, sz: float) -> ArrayMesh:

	var verts  = PackedVector3Array()
	var normals = PackedVector3Array()

	for iy in (ny - 1):
		for iz in (nz - 1):
			for ix in (nx - 1):
				# 8 corner densities
				var d = PackedFloat32Array()
				d.resize(8)
				for c in 8:
					var co = CORNER_OFFSETS[c]
					d[c] = grid[(iy + co.y) * nz * nx + (iz + co.z) * nx + (ix + co.x)]

				# Build vertex config index
				var cfg = 0
				for c in 8:
					if d[c] > ISO:
						cfg |= (1 << c)
				if cfg == 0 or cfg == 255:
					continue

				var et = EDGE_TABLE[cfg]
				if et == 0:
					continue

				# Interpolate edge vertices
				var ev: Array = []
				ev.resize(12)
				for e in 12:
					if et & (1 << e):
						var c0 = EDGE_CORNERS[e][0]
						var c1 = EDGE_CORNERS[e][1]
						var co0 = CORNER_OFFSETS[c0]
						var co1 = CORNER_OFFSETS[c1]
						var p0 = Vector3(
							ox + (ix + co0.x) * sx,
							oy + (iy + co0.y) * sy,
							oz + (iz + co0.z) * sz)
						var p1 = Vector3(
							ox + (ix + co1.x) * sx,
							oy + (iy + co1.y) * sy,
							oz + (iz + co1.z) * sz)
						var t = 0.5
						var denom = d[c1] - d[c0]
						if abs(denom) > 0.00001:
							t = (ISO - d[c0]) / denom
						ev[e] = p0.lerp(p1, t)
					else:
						ev[e] = Vector3.ZERO

				# Emit triangles
				var tri_base = cfg * 16
				var ti = 0
				while ti < 15:
					var e0 = TRI_TABLE[tri_base + ti]
					if e0 == -1: break
					var e1 = TRI_TABLE[tri_base + ti + 1]
					var e2 = TRI_TABLE[tri_base + ti + 2]
					var v0: Vector3 = ev[e0]
					var v1: Vector3 = ev[e1]
					var v2: Vector3 = ev[e2]
					var n = (v1 - v0).cross(v2 - v0).normalized()
					verts.append(v0); normals.append(n)
					verts.append(v1); normals.append(n)
					verts.append(v2); normals.append(n)
					ti += 3

	if verts.is_empty():
		return null

	var arr = Array()
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
