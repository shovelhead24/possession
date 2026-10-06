extends RefCounted
# Front-view four-bar linkage in metres. Both A-arm legs share a hinge axis along Z.
const LOWER := 0.75
const UPPER := 0.65
const UPRIGHT := 0.48
const UPPER_IN := Vector2(0.10,0.48)
const MIN_TRAVEL := -0.28
const MAX_TRAVEL := 0.28
const SEARCH_DEPTH := 18
static var height_search := PackedFloat32Array()

static func prepare_height_search() -> void:
	if not height_search.is_empty(): return
	var tag := FileAccess.get_file_as_string("res://world/wishbone.gd").sha256_text()
	var path := "user://wishbone-height-search-"+tag+".bin"
	var size := (1<<SEARCH_DEPTH)-1
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path,FileAccess.READ)
		if file:
			var data: Variant=file.get_var()
			if data is PackedFloat32Array and data.size()==size:
				height_search=data;return
	height_search.resize(size)
	# Breadth-first bisection tree. The searched geometry never depends on
	# vehicle position, speed, grip or spring tuning; only on these hardpoints.
	for depth in SEARCH_DEPTH:
		var count := 1<<depth
		for i in count:
			var mid := lerpf(MIN_TRAVEL,MAX_TRAVEL,(float(i)+.5)/count)
			height_search[count-1+i]=solve(mid).hub.y
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file: file.store_var(height_search)

static func solve(travel: float) -> Dictionary:
	var y := clampf(travel,MIN_TRAVEL,MAX_TRAVEL)
	var lower := Vector2(sqrt(LOWER*LOWER-y*y),y)
	var delta := lower-UPPER_IN
	var d := delta.length()
	var axis := delta/d
	var along := (UPPER*UPPER-UPRIGHT*UPRIGHT+d*d)/(2*d)
	var height := sqrt(maxf(0,UPPER*UPPER-along*along))
	var mid := UPPER_IN+axis*along
	var normal := Vector2(-axis.y,axis.x)
	var a := mid+normal*height
	var b := mid-normal*height
	var upper := a if a.y>b.y else b
	return {"lower":lower,"upper":upper,"hub":(lower+upper)*.5,"camber":atan2(upper.x-lower.x,upper.y-lower.y)}

static func at_height(height: float) -> Dictionary:
	prepare_height_search()
	var lo := MIN_TRAVEL
	var hi := MAX_TRAVEL
	var index := 0
	for i in SEARCH_DEPTH:
		var mid := (lo+hi)*.5
		if height_search[index] < height: lo=mid;index=index*2+2
		else: hi=mid;index=index*2+1
	return solve((lo+hi)*.5)
