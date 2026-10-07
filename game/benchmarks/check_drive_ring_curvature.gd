extends SceneTree
const Source = preload("res://world/terrain_baseline_source.gd")
const Ring = preload("res://world/terrain_drive_ring.gd")

func _initialize() -> void:
	run.call_deferred()

func require(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)

func run() -> void:
	var source := Source.new()
	source.curve_to_ring=true
	require(source.initialize(),"Curved DEM source did not initialise")
	# 40 km is far enough that flat close terrain would be about 1.7 km below
	# the ring, while remaining inside this source's native DEM bounds.
	var key := Vector2i(200,0)
	var result: Dictionary=source.build_tile(key)
	require(not result.vertices.is_empty(),"Curved terrain tile has no surface")
	var expected_lift := Ring.point(40000,0,0).y
	var min_world_height := INF
	var min_normal_dot := 1.0
	var height_error := 0.0
	for i in result.vertices.size():
		var world: Vector3=result.vertices[i]
		var ring_position := Ring.coordinates(world)
		min_world_height=minf(min_world_height,world.y)
		min_normal_dot=minf(min_normal_dot,result.normals[i].dot(Ring.up_at(world)))
		height_error=maxf(height_error,absf(ring_position.y-source.surface_height(Vector2(ring_position.x,ring_position.z))))
	require(min_world_height>expected_lift-250,"Far close terrain did not rise with the ring")
	require(min_normal_dot>.25,"Curved terrain normals face away from the playable surface")
	require(height_error<.1,"Curved terrain ring coordinates no longer match the DEM height")
	print("DRIVE_RING_CURVATURE_PASS lift_m=",expected_lift," min_y=",min_world_height," normal_dot=",min_normal_dot," height_error=",height_error)
	quit()
