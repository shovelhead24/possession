extends Node3D
## Small implicit-field authoring proof. No world-map or source-asset loading.
const ORIGIN := Vector3(-24,-4,-20)
const CELLS := Vector3i(48,22,40)
const CORNERS := [Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,1,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(1,1,1),Vector3i(0,1,1)]
const TETS := [[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
var tunnel_radius := 3.2
var roughness := 0.35
var worker: Thread
var terrain := MeshInstance3D.new()
var collision := CollisionShape3D.new()
var camera := Camera3D.new()
var player := CharacterBody3D.new()
var hud := Label.new()
var look := Vector2(-0.45,-0.16)
var walking := false
var generation_ms := 0
var triangles := 0
var ready_frames := 0
var frame_times: Array[float] = []
var test_done := false
var auto_walk := false

static func box(p: Vector3, half_size: Vector3) -> float:
	var q := p.abs()-half_size
	return q.max(Vector3.ZERO).length()+minf(maxf(q.x,maxf(q.y,q.z)),0)

static func field(p: Vector3, radius: float, rough: float) -> float:
	var ground := box(p-Vector3(0,-2,0),Vector3(23,2,19))
	# Scaled ellipsoid is a distance estimate, not an exact SDF. Meshing needs
	# its zero surface; this demo does not assume safe ray-marching steps.
	var rock := ((p-Vector3(0,3,1))/Vector3(16,10,6)).length()-1.0
	rock *= 6.0
	rock += rough*sin(p.x*0.8)*sin(p.y*1.1)*cos(p.z*0.7)
	var tunnel := Vector2(p.x,p.y-2.8).length()-radius
	rock = maxf(rock,-tunnel)
	var alcove := box(p-Vector3(9,2.4,-4),Vector3(3.3,2.4,4))
	rock = maxf(rock,-alcove)
	var platform := box(p-Vector3(9,0.25,-5),Vector3(3.5,0.25,3.5))
	return minf(minf(ground,rock),platform)

static func normal_at(p: Vector3, radius: float, rough: float) -> Vector3:
	var e := 0.03
	return Vector3(field(p+Vector3(e,0,0),radius,rough)-field(p-Vector3(e,0,0),radius,rough),
		field(p+Vector3(0,e,0),radius,rough)-field(p-Vector3(0,e,0),radius,rough),
		field(p+Vector3(0,0,e),radius,rough)-field(p-Vector3(0,0,e),radius,rough)).normalized()

func generate(radius: float, rough: float) -> Dictionary:
	var started := Time.get_ticks_msec()
	var nx := CELLS.x+1
	var ny := CELLS.y+1
	var values := PackedFloat32Array()
	values.resize(nx*ny*(CELLS.z+1))
	for z in CELLS.z+1:
		for y in ny:
			for x in nx:
				values[(z*ny+y)*nx+x] = field(ORIGIN+Vector3(x,y,z),radius,rough)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for z in CELLS.z:
		for y in CELLS.y:
			for x in CELLS.x:
				var points: Array[Vector3] = []
				var distances: Array[float] = []
				var negative := 0
				for corner in CORNERS:
					var c: Vector3i = Vector3i(x,y,z)+corner
					points.append(ORIGIN+Vector3(c))
					var d := values[(c.z*ny+c.y)*nx+c.x]
					distances.append(d)
					if d < 0: negative += 1
				if negative == 0 or negative == 8: continue
				for tet in TETS:
					var inside: Array[int] = []
					var outside: Array[int] = []
					for i in tet:
						if distances[i] < 0: inside.append(i)
						else: outside.append(i)
					if inside.is_empty() or outside.is_empty(): continue
					var edges: Array = []
					if inside.size() == 1:
						for b in outside: edges.append([inside[0],b])
					elif outside.size() == 1:
						for a in inside: edges.append([a,outside[0]])
					else:
						edges = [[inside[0],outside[0]],[inside[0],outside[1]],[inside[1],outside[1]],[inside[1],outside[0]]]
					var polygon: Array[Vector3] = []
					for edge in edges:
						var a: int = edge[0]
						var b: int = edge[1]
						polygon.append(points[a].lerp(points[b],distances[a]/(distances[a]-distances[b])))
					for i in range(1,polygon.size()-1):
						var a := polygon[0]
						var b := polygon[i]
						var c := polygon[i+1]
						var cross := (b-a).cross(c-a)
						if cross.length_squared() < 0.00000001: continue
						# Godot front faces are clockwise.
						# Orient using the tetrahedron's inside/outside direction,
						# which stays reliable at sharp CSG seams and thin wedges.
						var outward := points[outside[0]]-points[inside[0]]
						if cross.dot(outward) > 0:
							var swap := b
							b = c
							c = swap
						for p in [a,b,c]:
							vertices.append(p)
							normals.append(normal_at(p,radius,rough))
	return {"vertices":vertices,"normals":normals,"ms":Time.get_ticks_msec()-started}

func rebuild() -> void:
	if worker != null: return
	worker = Thread.new()
	var error := worker.start(generate.bind(tunnel_radius,roughness))
	if error != OK:
		worker = null
		push_error("SDF worker could not start")

func _ready() -> void:
	DisplayServer.window_set_title("SDF terrain / standalone feasibility demo")
	add_child(terrain)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48,0.55,0.40)
	material.roughness = 0.95
	terrain.material_override = material
	var body := StaticBody3D.new()
	add_child(body)
	body.add_child(collision)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,145,0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36,0.52,0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65,0.73,0.83)
	env.ambient_light_energy = 0.6
	environment.environment = env
	add_child(environment)
	add_child(player)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var player_shape := CollisionShape3D.new()
	player_shape.shape = capsule
	player_shape.position.y = 0.9
	player.add_child(player_shape)
	player.floor_snap_length = 0.3
	add_child(camera)
	camera.position = Vector3(19,12,-29)
	camera.far = 160
	camera.look_at(Vector3(0,3,0))
	look = Vector2(camera.rotation.y,camera.rotation.x)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(hud)
	hud.position = Vector2(14,14)
	hud.add_theme_font_size_override("font_size",18)
	for spec in [["SDF RIDGE + CARVED TUNNEL",Vector3(0,12,0)],["INSET PLATFORM",Vector3(9,5,-7)]]:
		var label := Label3D.new()
		label.text = spec[0]
		label.position = spec[1]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.012
		add_child(label)
	rebuild()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look.x -= event.relative.x*0.003
		look.y = clampf(look.y-event.relative.y*0.003,-1.5,1.5)
		camera.rotation = Vector3(look.y,look.x,0)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
				if worker == null:
					tunnel_radius = clampf(tunnel_radius+(-0.4 if event.keycode == KEY_BRACKETLEFT else 0.4),1.6,5.2)
					rebuild()
			KEY_R:
				if worker == null:
					roughness = 0.0 if roughness > 0 else 0.35
					rebuild()
			KEY_F:
				if collision.shape == null: return
				walking = not walking
				if walking:
					player.position = Vector3(0,0.1,-12)
					player.velocity = Vector3.ZERO
					look = Vector2(PI,0)
					camera.rotation = Vector3(0,PI,0)

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): direction -= camera.basis.z
	if Input.is_key_pressed(KEY_S): direction += camera.basis.z
	if Input.is_key_pressed(KEY_A): direction -= camera.basis.x
	if Input.is_key_pressed(KEY_D): direction += camera.basis.x
	if auto_walk: direction = Vector3(0,0,1)
	if walking:
		direction.y = 0
		direction = direction.normalized()*5
		player.velocity.x = direction.x
		player.velocity.z = direction.z
		player.velocity.y -= 20*delta
		if player.is_on_floor() and Input.is_key_pressed(KEY_SPACE): player.velocity.y = 6
		player.move_and_slide()
		camera.position = player.position+Vector3(0,1.6,0)
	else:
		if Input.is_key_pressed(KEY_SPACE): direction.y += 1
		if Input.is_key_pressed(KEY_CTRL): direction.y -= 1
		camera.position += direction.normalized()*delta*(22 if Input.is_key_pressed(KEY_SHIFT) else 10)

func _process(delta: float) -> void:
	if worker != null and not worker.is_alive():
		var result: Dictionary = worker.wait_to_finish()
		worker = null
		var started := Time.get_ticks_msec()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = result.vertices
		arrays[Mesh.ARRAY_NORMAL] = result.normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		terrain.mesh = mesh
		collision.shape = mesh.create_trimesh_shape()
		if walking:
			player.position = Vector3(0,0.1,-12)
			player.velocity = Vector3.ZERO
		generation_ms = result.ms
		triangles = result.vertices.size()/3
		print("SDF_READY generation_ms=",generation_ms," mesh_collision_ms=",Time.get_ticks_msec()-started," triangles=",triangles)
	hud.text = "SDF authoring proof / %s\nWASD move | mouse click/look | Esc release | Space/Ctrl rise/lower\nF walk/fly (walk starts at tunnel) | [ ] tunnel radius %.1fm | R rock detail\n%s | %d triangles | last generation %dms | %.0f FPS" % [
		"WALK" if walking else "FLY",tunnel_radius,"GENERATING" if worker != null else "READY",triangles,generation_ms,Engine.get_frames_per_second()]
	if terrain.mesh != null and worker == null:
		ready_frames += 1
		if OS.get_cmdline_user_args().has("--sdf-check") and not test_done:
			test_done = true
			check_demo.call_deferred()
		if OS.get_cmdline_user_args().has("--sdf-capture"):
			if ready_frames > 30: frame_times.append(delta)
			if ready_frames == 150: capture.call_deferred()

func check_demo() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(triangles > 100 and triangles < 150000)
	assert(field(Vector3(0,2.8,0),tunnel_radius,roughness) > 0)
	assert(field(Vector3(0,9,1),tunnel_radius,roughness) < 0)
	var space := get_world_3d().direct_space_state
	var through := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,2,-12),Vector3(0,2,12)))
	assert(through.is_empty())
	var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,2,0),Vector3(0,15,0)))
	assert(not roof.is_empty())
	var floor_query := PhysicsRayQueryParameters3D.create(Vector3(0,2,0),Vector3(0,-3,0))
	floor_query.exclude = [player.get_rid()]
	var floor_hit := space.intersect_ray(floor_query)
	assert(not floor_hit.is_empty() and absf(floor_hit.position.y) < 0.05)
	print("PASS: open tunnel, solid roof, collision floor, bounded mesh count")
	if OS.get_cmdline_user_args().has("--sdf-edit-check"):
		var original_triangles := triangles
		tunnel_radius = 4.4
		roughness = 0.0
		rebuild()
		while worker != null: await get_tree().process_frame
		assert(triangles != original_triangles)
		assert(field(Vector3(4,2.8,0),tunnel_radius,roughness) > 0)
		player.position = Vector3(0,0.1,-10)
		player.velocity = Vector3.ZERO
		walking = true
		auto_walk = true
		for frame in 240: await get_tree().physics_frame
		auto_walk = false
		walking = false
		assert(player.position.z > 8 and absf(player.position.y) < 0.15)
		print("PASS: parameter edit regenerates mesh/collision; capsule walks through tunnel: ",player.position)
	if not OS.get_cmdline_user_args().has("--sdf-capture"): get_tree().quit()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var path := "user://sdf-demo.png"
	assert(get_viewport().get_texture().get_image().save_png(path) == OK)
	var total := 0.0
	for value in frame_times: total += value
	print("SDF_CAPTURE ",ProjectSettings.globalize_path(path)," sampled_fps=",frame_times.size()/maxf(total,0.001))
	get_tree().quit()

func _exit_tree() -> void:
	if worker != null: worker.wait_to_finish()
