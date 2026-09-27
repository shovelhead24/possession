extends Resource
const FILE := "res://baked/arena.res"
const EDITED_FILE := "res://baked/arena_edited.res"
const MINIMUM := Vector2(-810,-2650)
const SIZE := Vector2(2160,2760)
const STEP := 3.0
const WIDTH := 721
const DEPTH := 921
const MEETING_POINTS := [Vector3(270,0,-1270),Vector3(-320,0,-740),Vector3(820,0,-1840)]
const HABITATS := ["Western forest","FOB rolling valley","Broad valley","Depressions","Forested hills","High hills","Mini canyon west","Treeline meadow","Deep forest","Bowl country","Hill chains","Wooded valley","Open meadow","Mini canyon east","Forest ridges","Rolling hills"]
@export var version := 1
@export var heights := PackedFloat32Array()
@export var terrain: PackedScene
@export var rock_scene: PackedScene
@export var outposts: PackedScene
@export var trees: Array[Dictionary]=[]
@export var tree_meshes: Array[Mesh]=[]
@export var rocks: Array[Dictionary]=[]
@export var slots: Array[Vector3]=[]
@export var homes: Array[Vector3]=[]
@export var sector_counts: Array[Dictionary]=[]
@export var blocked := PackedVector2Array()
@export var tree_cells := PackedVector2Array()

func height_at(x: float,z: float) -> float:
	var gx=clampf((x-MINIMUM.x)/STEP,0,WIDTH-1.001)
	var gz=clampf((z-MINIMUM.y)/STEP,0,DEPTH-1.001)
	var ix=int(gx);var iz=int(gz);var fx=gx-ix;var fz=gz-iz
	# Match the terrain mesh's diagonal exactly, rather than bilinear smoothing.
	var a=heights[iz*WIDTH+ix];var b=heights[iz*WIDTH+ix+1]
	var c=heights[(iz+1)*WIDTH+ix+1];var d=heights[(iz+1)*WIDTH+ix]
	return a+(b-a)*fx+(c-b)*fz if fx>=fz else a+(c-d)*fx+(d-a)*fz

static func sector_origin(column: int,row: int) -> Vector3:
	return Vector3((column-1)*540,0,-row*690)

static func patrol_route(index: int) -> Array[Vector3]:
	var route: Array[Vector3]=[]
	for row in 4:
		for col in 4:
			var column=col if row%2==0 else 3-col
			route.append(sector_origin(column,row)+Vector3(-40,0,-160))
	if index%2==1: route.reverse()
	# Outer-corner approaches leave time to reach a vantage point; all four
	# still deliberately converge, then revisit the same three clearings.
	var spawn=[Vector3(-650,0,-100),Vector3(1190,0,-100),Vector3(1190,0,-2440),Vector3(-650,0,-2440)][index%4]
	var shifted: Array[Vector3]=[spawn,MEETING_POINTS[0]]
	for i in route.size():
		shifted.append(route[(i+index*4)%route.size()])
		if i%4==3: shifted.append(MEETING_POINTS[(i/4+1)%3])
	return shifted

static func is_meeting(point: Vector3) -> bool:
	for center in MEETING_POINTS:
		if Vector2(point.x-center.x,point.z-center.z).length()<1: return true
	return false
