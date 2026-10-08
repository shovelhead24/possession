extends Node3D
## Stage 1: bounded, fully cached terrain. No generation or collision swaps in play.
const Source = preload("res://world/terrain_baseline_source.gd")
const Loading = preload("res://world/workshop_loading.gd")
var source: RefCounted
var camera: Camera3D
var loading: CanvasLayer
var hud: Label
var ready_to_play := false
var tiles: Array=[]
var cache_hits := 0
var total_triangles := 0
var lod_triangles := 0
var loading_started := 0
var material: Material
var hud_clock := 0.0
var frame_times: Array[float]=[]
var last_frame := 0
var worker: Thread
var stress_course := false
var diagnostic := false
var brief_path := "res://world/terrain_baseline_brief.json"
var tile_entries := {}
var curve_to_ring := false

func _ready() -> void:
	diagnostic=OS.get_cmdline_user_args().has("--baseline-profile")
	# Tested 120 FPS pacing keeps delivery inside the 60 FPS budget on this laptop.
	Engine.max_fps=0 if diagnostic else 120
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_viewport().mesh_lod_threshold=2.0
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.42,.58,.72)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.75,.83,.92)
	environment.environment.ambient_light_energy=.65;add_child(environment)
	var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-30,0)
	sun.light_energy=1.0;sun.shadow_enabled=false;add_child(sun)
	var plain_material := StandardMaterial3D.new();plain_material.albedo_color=Color(.38,.46,.25)
	plain_material.roughness=1.0;material=plain_material
	camera=Camera3D.new();camera.far=6000;camera.near=.2;camera.fov=75;add_child(camera);camera.make_current()
	var layer := CanvasLayer.new();add_child(layer)
	hud=Label.new();hud.position=Vector2(16,12);hud.add_theme_color_override("font_shadow_color",Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x",1);hud.add_theme_constant_override("shadow_offset_y",1);layer.add_child(hud)
	loading=Loading.new();loading.brief_path=brief_path;add_child(loading)
	build.call_deferred()

func build() -> void:
	loading_started=Time.get_ticks_msec()
	await get_tree().process_frame
	source=Source.new()
	source.curve_to_ring=curve_to_ring
	if not source.initialize():
		push_error("Baseline DEM could not load");get_tree().quit(1);return
	prepare_source()
	loading.log_event("Preparing 3,200 m square: 256 terrain tiles, cached LODs and collision.")
	for z in range(-8,8):
		for x in range(-8,8):
			worker=Thread.new()
			var error := worker.start(build_tile.bind(Vector2i(x,z)))
			if error!=OK: push_error("Terrain worker failed");get_tree().quit(1);return
			while worker.is_alive(): await get_tree().process_frame
			var data: Dictionary=worker.wait_to_finish();worker=null
			install_tile(data,Vector2i(x,z))
			loading.bar.value=100.0*tiles.size()/256
			loading.status.text="Terrain %d / 256 tiles — %d reused from disk" % [tiles.size(),cache_hits]
			if tiles.size()%32==0: loading.log_event(loading.status.text)
			await get_tree().process_frame
	set_view(1)
	await prepare_content()
	ready_to_play=true
	print("BASELINE_READY ",JSON.stringify({"tiles":tiles.size(),"cache_hits":cache_hits,"full_triangles":total_triangles,"coarsest_triangles":lod_triangles,"loading_seconds":(Time.get_ticks_msec()-loading_started)/1000.0,"extent_m":3200,"source_spacing_m":source.metadata.m_per_px}))
	if diagnostic:
		loading.ready_to_enter=true;loading.close()
	else:
		loading.capture_ready()
	last_frame=Time.get_ticks_usec()

func prepare_content() -> void:
	pass

func prepare_source() -> void:
	pass

func build_tile(key: Vector2i) -> Dictionary:
	return source.build_tile(key)

func install_tile(data: Dictionary, key := Vector2i.ZERO) -> void:
	var arrays := [];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals;arrays[Mesh.ARRAY_INDEX]=data.indices
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],data.render_lods)
	var node := MeshInstance3D.new();node.mesh=mesh;node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
	# Collision uses exactly the full-detail rendered surface; LOD changes only distant indices.
	var body := StaticBody3D.new();var shape := CollisionShape3D.new()
	shape.shape=mesh.create_trimesh_shape();body.add_child(shape);add_child(body)
	tile_entries[key]={"visual":node,"body":body}
	tiles.append(node);cache_hits+=int(data.cached);total_triangles+=data.indices.size()/3
	var least: int=data.indices.size()
	for indices in data.render_lods.values(): least=mini(least,indices.size())
	lod_triangles+=least/3

func set_view(index: int) -> void:
	var target := Vector3(100,source.features[0].y-12,100)
	match index:
		1: camera.position=Vector3(220,target.y+35,240)
		2: camera.position=Vector3(100,source.surface_height(Vector2(100,100))+4,145);target=Vector3(100,camera.position.y,65)
		3: camera.position=Vector3(-15,source.features[2].y,-100);target=Vector3(180,camera.position.y,-100)
		4: camera.position=Vector3(1400,1200,1400);target=Vector3.ZERO
	camera.look_at(target)

func fly_bounds() -> Rect2:
	return Rect2(Vector2(-1600,-1600),Vector2(3200,3200))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F2: loading.reopen()
		if event.keycode==KEY_ENTER: loading.close()
		if event.keycode==KEY_ESCAPE: Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		if ready_to_play and event.keycode>=KEY_1 and event.keycode<=KEY_4: set_view(event.keycode-KEY_0)
	if not ready_to_play or not loading.dismissed: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		camera.rotation.y-=event.relative.x*.0025
		camera.rotation.x=clampf(camera.rotation.x-event.relative.y*.0025,-1.5,1.5)

func _process(delta: float) -> void:
	if not ready_to_play: return
	var now := Time.get_ticks_usec()
	if last_frame>0:
		frame_times.append((now-last_frame)/1000.0)
		if frame_times.size()>600: frame_times.pop_front()
	last_frame=now
	if not diagnostic and loading.dismissed:
		var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		direction=camera.basis*direction
		direction.y+=float(Input.is_physical_key_pressed(KEY_SPACE))-float(Input.is_physical_key_pressed(KEY_CTRL))
		camera.position+=direction.limit_length()*delta*(180 if Input.is_physical_key_pressed(KEY_SHIFT) else 45)
		var bounds := fly_bounds()
		camera.position.x=clampf(camera.position.x,bounds.position.x+2,bounds.end.x-2);camera.position.z=clampf(camera.position.z,bounds.position.y+2,bounds.end.y-2)
		camera.position.y=maxf(camera.position.y,source.surface_height(Vector2(camera.position.x,camera.position.z))+2)
	hud_clock+=delta
	if hud_clock<.25: return
	hud_clock=0
	var sorted := frame_times.duplicate();sorted.sort()
	var p95: float=sorted[mini(sorted.size()-1,int(sorted.size()*.95))] if not sorted.is_empty() else 0.0
	hud.text="TERRAIN / STAGE 1     3.2 km × 3.2 km\n%d FPS | frame p95 %.2f ms | budget 16.67 ms\nWASD fly · RMB look · Space/Ctrl vertical · Shift fast\n1 overview · 2 bridge · 3 tunnel · 4 whole area · F2 briefing\nPosition %.0f, %.0f, %.0f m" % [Engine.get_frames_per_second(),p95,camera.position.x,camera.position.y,camera.position.z]

func _exit_tree() -> void:
	if worker: worker.wait_to_finish()
