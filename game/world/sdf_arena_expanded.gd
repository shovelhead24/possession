extends "res://world/sdf_arena.gd"
## Streamed local terrain; complementary dither blends detail and distant coverage.
const EXTENT := 768.0
const GRID_LIMIT := 24
const COARSE_STEP := 16.0
const MID_EXTENT := 384.0
const FADE_SECONDS := 0.8
const MAX_DETAIL := 160
const SPARE_CAP := 24
const SPARE_BYTES := 32*1024*1024
const FOB := Vector3(-30,2,180)
const RELAY := Vector3(65,5,-195)
var coarse_worker: Thread
var coarse := MeshInstance3D.new()
var coarse_mid := MeshInstance3D.new()
var coarse_stage := 0
var coarse_ready := false
var detail_image: Image
var detail_texture: ImageTexture
var mask_signature := 0
var coverage: Dictionary = {}
var retiring: Dictionary = {}
var spares: Dictionary = {}
var spare_order: Array[Vector2i] = []
var spare_bytes := 0
var cold_chunk_seconds := 1.0
var cache_hits := 0
var spare_hits := 0

func stream_worker_limit() -> int:
	return 2 # Reserve the other physical cores for rendering/main-thread work.

func chunk_generated(result: Dictionary) -> void:
	if result.get("cached",false): cache_hits+=1
	elif result.ms>0: cold_chunk_seconds=lerpf(cold_chunk_seconds,result.ms/1000.0,.2)
var compounds: Array[Node3D] = []
var expanded_frames := 0
var expanded_checked := false
var expanded_passed := false
var expanded_capture_requested := false
var geometry_cache_tag := ""
const CACHE_FOLDER := "user://sdf-expanded-geometry/"

static func pad_weight(p: Vector2, center: Vector2, half_size: Vector2) -> float:
	var q := (p-center).abs()-half_size
	return 1.0-smoothstep(0.0,14.0,maxf(q.x,q.y))

static func expanded_height(p: Vector2) -> float:
	var broad := smoothstep(70.0,125.0,p.length())
	var h := 0.35*sin(p.x*0.04)*cos(p.y*0.05)
	h += broad*(2.5*sin(p.x*0.014)*cos(p.y*0.017)
		+ 36.0*exp(-Vector2((p.x-145)/72.0,(p.y+140)/78.0).length_squared())
		+ 34.0*exp(-Vector2((p.x+245)/75.0,(p.y-145)/82.0).length_squared())
		+ 22.0*exp(-Vector2((p.x-220)/90.0,(p.y-230)/65.0).length_squared()))
	h += 46.0*exp(-Vector2((p.x-450)/115.0,(p.y-430)/105.0).length_squared())
	h += 50.0*exp(-Vector2((p.x+500)/125.0,(p.y+430)/95.0).length_squared())
	h -= 15.0*(1.0-smoothstep(12.0,35.0,absf(p.x-440.0-20.0*sin(p.y*.009))))*smoothstep(170.0,260.0,p.y)*(1.0-smoothstep(610.0,680.0,p.y))
	var canyon_x := -140.0+18.0*sin(p.y*0.012)
	var canyon := 18.0*(1.0-smoothstep(9.0,24.0,absf(p.x-canyon_x)))
	canyon *= smoothstep(-300.0,-265.0,p.y)*(1.0-smoothstep(255.0,300.0,p.y))
	h -= canyon
	# Graded shoulders meet the overpass at its ten-metre deck level.
	var ramps := (1.0-smoothstep(12.0,20.0,absf(p.y+80.0)))
	ramps *= (1.0-smoothstep(42.0,80.0,absf(p.x+154.0)))*smoothstep(22.0,34.0,absf(p.x+154.0))
	h = lerpf(h,10.0,ramps)
	h = lerpf(h,FOB.y,pad_weight(p,Vector2(FOB.x,FOB.z),Vector2(32,30)))
	h = lerpf(h,RELAY.y,pad_weight(p,Vector2(RELAY.x,RELAY.z),Vector2(43,34)))
	for portal in [Vector2(-363,145),Vector2(-127,145),Vector2(145,-250),Vector2(145,-30)]:
		h = lerpf(h,1.5,pad_weight(p,portal,Vector2(10,10)))
	return h*(1.0-smoothstep(EXTENT-80.0,EXTENT-2.0,maxf(absf(p.x),absf(p.y))))

static func expanded_field(p: Vector3, radius: float, detail: float) -> float:
	var ground := p.y-expanded_height(Vector2(p.x,p.z))
	# Two true bored passages through the terrain volume, with separate roofs.
	var west := maxf(Vector2(p.y-8.0,p.z-145.0).length()-7.0,absf(p.x+245.0)-120.0)
	var east := maxf(Vector2(p.x-145.0,p.y-8.0).length()-6.0,absf(p.z+140.0)-110.0)
	ground = maxf(ground,maxf(-west,-east))
	var ridge := (((p-Vector3(-10,2,14))/Vector3(19,10,8)).length()-1)*8
	ridge += detail*sin(p.x*0.65)*sin(p.y*0.8)*cos(p.z*0.5)
	ridge = maxf(ridge,-(Vector2(p.x+10,p.y-3).length()-radius))
	var cover := (((p-Vector3(25,1,8))/Vector3(8,5,6)).length()-1)*5
	var ledge := box(p-Vector3(-39,1.5,33),Vector3(10,1.5,8))
	var overpass := box(p-Vector3(-154,8,-80),Vector3(42,2,10))
	for x in [-186.0,-122.0]:
		overpass = minf(overpass,box(p-Vector3(x,-5,-80),Vector3(3,15,10)))
	return minf(ground,minf(overpass,minf(ridge,minf(cover,ledge))))

static func far_linear(p: Vector3, radius: float, detail: float) -> float:
	var grid := Vector3(p.x,p.y+24.0,p.z)/COARSE_STEP
	var cell := Vector3(floorf(grid.x),floorf(grid.y),floorf(grid.z))
	var f := grid-cell
	var axes := [0,1,2]
	if f[axes[0]]<f[axes[1]]:
		var swap: int=axes[0];axes[0]=axes[1];axes[1]=swap
	if f[axes[1]]<f[axes[2]]:
		var swap: int=axes[1];axes[1]=axes[2];axes[2]=swap
	if f[axes[0]]<f[axes[1]]:
		var swap: int=axes[0];axes[0]=axes[1];axes[1]=swap
	var a := cell;a[axes[0]]+=1
	var b := a;b[axes[1]]+=1
	var shift := Vector3(0,-24,0)
	return (1-f[axes[0]])*expanded_field(cell*COARSE_STEP+shift,radius,detail)+(f[axes[0]]-f[axes[1]])*expanded_field(a*COARSE_STEP+shift,radius,detail)+(f[axes[1]]-f[axes[2]])*expanded_field(b*COARSE_STEP+shift,radius,detail)+f[axes[2]]*expanded_field((cell+Vector3.ONE)*COARSE_STEP+shift,radius,detail)

static func mid_field(p: Vector3, radius: float, detail: float) -> float:
	# Preserve the previous 8 m landmark silhouette; match 16 m far planes at
	# the regional boundary instead of forcing small tunnels/decks onto that grid.
	var edge := maxf(absf(p.x),absf(p.z))
	if edge<=MID_EXTENT-32: return expanded_field(p,radius,detail)
	return lerpf(expanded_field(p,radius,detail),far_linear(p,radius,detail),smoothstep(MID_EXTENT-32,MID_EXTENT,edge))

static func coarse_linear(p: Vector3, origin: Vector3, values: PackedFloat32Array, nx: int, ny: int, step: float) -> float:
	# Same six tetrahedra as the coarse mesher, evaluated as a piecewise-linear
	# scalar field. The 2 m lattice refines these planes exactly at chunk borders.
	var grid := (p-origin)/step
	var cell := Vector3i(floori(grid.x),floori(grid.y),floori(grid.z))
	var f := grid-Vector3(cell)
	var axes := [0,1,2]
	if f[axes[0]] < f[axes[1]]:
		var swap: int = axes[0]; axes[0] = axes[1]; axes[1] = swap
	if f[axes[1]] < f[axes[2]]:
		var swap: int = axes[1]; axes[1] = axes[2]; axes[2] = swap
	if f[axes[0]] < f[axes[1]]:
		var swap: int = axes[0]; axes[0] = axes[1]; axes[1] = swap
	var a := cell
	a[axes[0]] += 1
	var b := a
	b[axes[1]] += 1
	var c := cell+Vector3i.ONE
	var v0 := values[(cell.z*ny+cell.y)*nx+cell.x]
	var v1 := values[(a.z*ny+a.y)*nx+a.x]
	var v2 := values[(b.z*ny+b.y)*nx+b.x]
	var v3 := values[(c.z*ny+c.y)*nx+c.x]
	return (1-f[axes[0]])*v0+(f[axes[0]]-f[axes[1]])*v1+(f[axes[1]]-f[axes[2]])*v2+f[axes[2]]*v3

static func border_field(p: Vector3, radius: float, detail: float, chunk_origin: Vector3, coarse_origin: Vector3, values: PackedFloat32Array, nx: int, ny: int, step: float) -> float:
	var local := p-chunk_origin
	var edge := minf(minf(local.x,32.0-local.x),minf(local.z,32.0-local.z))
	if edge >= 8.0: return expanded_field(p,radius,detail)
	var coarse_value := coarse_linear(p,coarse_origin,values,nx,ny,step)
	if edge <= 0.0: return coarse_value
	return lerpf(coarse_value,expanded_field(p,radius,detail),smoothstep(0,8,edge))

func chunk_sampler() -> Callable:
	return expanded_field

func chunk_layout() -> Dictionary:
	return {"bottom":-24.0,"cells":Vector3i(16,44,16),"spacing":2.0}

func movement_limit() -> float:
	return EXTENT-6.0

func desired() -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	# Keep the original actors/forest on detailed terrain. Other detail follows
	# the camera; the full arena remains visible through the coarse field mesh.
	for z in range(-3,3):
		for x in range(-3,3): keys.append(Vector2i(x,z))
	if content_started:
		var center := key_at(camera.position)
		for z in range(-2,3):
			for x in range(-2,3):
				var key := center+Vector2i(x,z)
				if not valid_key(key): continue
				if key not in keys: keys.append(key)
	# Protect physical supports independently of observer/chase-camera position.
	if is_instance_valid(arena_content) and arena_content.get("kit"):
		var system: Node=arena_content.kit.vehicle_system
		for body in system.vehicles:
			append_neighborhood(keys,key_at(body.position),1)
			if body==system.driving or body.controlled:
				var speed: float=maxf(14,body.linear_velocity.length())
				var direction: Vector3=body.linear_velocity.normalized() if body.linear_velocity.length()>2 else -body.basis.z
				var horizon: float=clampf(2.0+cold_chunk_seconds*3.0/stream_worker_limit(),4.0,8.0)
				var distance: float=minf(320,maxf(speed*horizon,speed*speed/7.0+64.0))
				for step in range(0,ceili(distance/CHUNK)+1):
					append_neighborhood(keys,key_at(body.position+direction*step*CHUNK),1)
	var center := key_at(camera.position)
	var priorities := {}
	for key in keys: priorities[key]=10000+(key-center).length_squared()
	if is_instance_valid(arena_content) and arena_content.get("kit"):
		for body in arena_content.kit.vehicle_system.vehicles:
			var origin := key_at(body.position)
			for key in keys:
				var d := key-origin
				if maxi(absi(d.x),absi(d.y))<=1: priorities[key]=-10000+d.length_squared()
				elif body==arena_content.kit.vehicle_system.driving or body.controlled: priorities[key]=minf(priorities[key],d.length_squared())
	keys.sort_custom(func(a: Vector2i,b: Vector2i): return priorities[a]<priorities[b])
	return keys

func valid_key(key: Vector2i) -> bool:
	return key.x >= -GRID_LIMIT and key.x < GRID_LIMIT and key.y >= -GRID_LIMIT and key.y < GRID_LIMIT

func append_neighborhood(keys: Array[Vector2i], center: Vector2i, radius: int) -> void:
	for z in range(-radius,radius+1):
		for x in range(-radius,radius+1):
			var key := center+Vector2i(x,z)
			if valid_key(key) and key not in keys: keys.append(key)

func neighborhood_ready(p: Vector3) -> bool:
	var center := key_at(p)
	for z in range(-1,2):
		for x in range(-1,2):
			var key := center+Vector2i(x,z)
			if not valid_key(key): continue
			if not chunks.has(key) or chunks[key].revision != revision: return false
	return true

func _ready() -> void:
	# Generated arrays are disposable. Source recipe, mesher and engine version
	# identify the cache; edits select new entries rather than altering old data.
	geometry_cache_tag = (FileAccess.get_file_as_string("res://world/sdf_arena_expanded.gd").get_slice("func chunk_sampler()",0)+FileAccess.get_file_as_string("res://world/sdf_demo.gd")+FileAccess.get_file_as_string("res://world/tetra_mesher.gd")+str(OS.get_cmdline_user_args().has("--mesher-legacy"))+str(Engine.get_version_info())).sha256_text()
	DirAccess.make_dir_recursive_absolute(CACHE_FOLDER)
	super._ready()
	DisplayServer.window_set_title("SDF arena / canyon, tunnels and two compounds")
	ring_background.arena_extent = EXTENT # Before its deferred setup.
	terrain.material_override.set_shader_parameter("overpass_enabled",true)
	terrain.material_override.set_shader_parameter("compound_floors",true)
	detail_image = Image.create(GRID_LIMIT*2,GRID_LIMIT*2,false,Image.FORMAT_R8)
	detail_image.fill(Color.BLACK)
	detail_texture = ImageTexture.create_from_image(detail_image)
	terrain.material_override.set_shader_parameter("detail_surface",true)
	terrain.material_override.set_shader_parameter("detail_mask",detail_texture)
	terrain.material_override.set_shader_parameter("local_extent",EXTENT)
	add_child(coarse)
	coarse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coarse.material_override = terrain.material_override.duplicate()
	coarse.material_override.set_shader_parameter("coarse_surface",true)
	coarse.material_override.set_shader_parameter("detail_surface",false)
	coarse.material_override.set_shader_parameter("detail_mask",detail_texture)
	coarse.material_override.set_shader_parameter("local_extent",EXTENT)
	add_child(coarse_mid);coarse_mid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coarse_mid.material_override=coarse.material_override.duplicate()
	coarse_worker = Thread.new()
	var error := coarse_worker.start(generate.bind(tunnel_radius,roughness,Vector3(-EXTENT,-24,-EXTENT),Vector3i(96,6,96),COARSE_STEP,expanded_field))
	assert(error == OK,"Could not start coarse arena worker")
	var builder := preload("res://world/arena_compounds.gd").new()
	var fob: Node3D = builder.fob()
	var relay: Node3D = builder.relay()
	for pair in [[fob,FOB],[relay,RELAY]]:
		add_child(pair[0])
		pair[0].position = pair[1]
		compounds.append(pair[0])
	for landmark in [["CANYON / OVERPASS",Vector3(-154,16,-80)],["WEST TUNNEL",Vector3(-245,42,145)],["EAST TUNNEL",Vector3(145,45,-140)]]:
		builder.label(self,landmark[0],landmark[1],500)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expanded-view="): focus_site(int(arg.get_slice("=",1)))
	# Warm-up starts near the original actors. A distant overview follows only
	# after the initial source models have collision to ground against.

func cache_folder_for(_spacing: float) -> String:
	return CACHE_FOLDER

func generate(radius: float, detail: float, origin := ORIGIN, cells := CELLS, spacing := 1.0, sampler := Callable()) -> Dictionary:
	# Only primitive arrays/file I/O on workers; GPU resources stay main-thread.
	var cache_started := Time.get_ticks_usec()
	var key := "%s/%s/%s/%.3f/%.3f/%.3f" % [geometry_cache_tag,str(origin),str(cells),spacing,radius,detail]
	var folder := cache_folder_for(spacing)
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder+key.sha256_text()+".bin"
	if FileAccess.file_exists(path):
		var reader := FileAccess.open(path,FileAccess.READ)
		if reader != null:
			var cached: Variant = reader.get_var(false)
			reader.close()
			if cached is Dictionary and cached.get("vertices") is PackedVector3Array and cached.get("normals") is PackedVector3Array:
				var indexed: bool=cached.get("indices") is PackedInt32Array
				if cached.get("schema",0)==2 and cached.vertices.size()==cached.normals.size() and ((indexed and cached.indices.size()%3==0) or (not indexed and cached.vertices.size()%3==0)):
					cached.ms=0;cached.cached=true
					cached.profile={"cache_read_ms":(Time.get_ticks_usec()-cache_started)/1000.0}
					return cached
	var setup_started := Time.get_ticks_usec()
	var effective_sampler := sampler
	if is_equal_approx(spacing,2.0):
		var in_mid := origin.x>=-MID_EXTENT and origin.x<MID_EXTENT and origin.z>=-MID_EXTENT and origin.z<MID_EXTENT
		var step := 8.0 if in_mid else COARSE_STEP
		var coarse_origin := origin-Vector3.ONE*step
		var nx := 7 if in_mid else 5
		var ny := 14 if in_mid else 9
		var values := PackedFloat32Array()
		values.resize(nx*ny*nx)
		for z in nx:
			for y in ny:
				for x in nx:
					var p := coarse_origin+Vector3(x,y,z)*step
					values[(z*ny+y)*nx+x] = mid_field(p,radius,detail) if in_mid else expanded_field(p,radius,detail)
		effective_sampler = border_field.bind(origin,coarse_origin,values,nx,ny,step)
	var setup_ms := (Time.get_ticks_usec()-setup_started)/1000.0
	var result := super.generate(radius,detail,origin,cells,spacing,effective_sampler)
	result.profile.boundary_setup_ms=setup_ms
	result.ms+=setup_ms
	var write_started := Time.get_ticks_usec()
	var writer := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if writer != null:
		var saved := {"schema":2,"vertices":result.vertices,"normals":result.normals}
		if result.has("indices"): saved.indices=result.indices
		writer.store_var(saved,false)
		writer.close()
		DirAccess.rename_absolute(path+".tmp",path)
	result.profile.cache_write_ms=(Time.get_ticks_usec()-write_started)/1000.0
	result.profile.job_wall_ms=(Time.get_ticks_usec()-cache_started)/1000.0
	return result

func focus_site(index: int) -> void:
	var positions := [Vector3(-560,240,620),Vector3(-45,11,205),Vector3(65,13,-146),Vector3(-110,20,-40),Vector3(-355,9,145),Vector3(124,13,-264),Vector3(540,90,590)]
	var targets := [Vector3(-40,5,-55),FOB+Vector3.UP*2,RELAY+Vector3.UP*2,Vector3(-154,-7,-80),Vector3(-240,8,145),Vector3(145,8,-140),Vector3(440,30,430)]
	if index < 0 or index >= positions.size(): return
	walking = false
	camera.position = positions[index]
	camera.look_at(targets[index])
	look = Vector2(camera.rotation.y,camera.rotation.x)

func _input(event: InputEvent) -> void:
	if OS.get_cmdline_user_args().has("--expanded-capture"): return
	if is_instance_valid(arena_content) and arena_content.get("kit") and arena_content.kit.handle_input(event): return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_T:
				super._input(event)
				coarse.material_override.set_shader_parameter("textured",textured)
				return
			KEY_F:
				if walking:
					walking = false
					return
				if not neighborhood_ready(camera.position): return
				var query := PhysicsRayQueryParameters3D.create(camera.position+Vector3.UP*0.5,Vector3(camera.position.x,-24,camera.position.z))
				query.exclude = [player.get_rid()]
				var hit := get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty():
					player.position = hit.position+Vector3.UP*0.1
					player.velocity = Vector3.ZERO
					walking = true
				return
			KEY_0: focus_site(0); return
			KEY_5: focus_site(1); return
			KEY_6: focus_site(2); return
			KEY_7: focus_site(3); return
			KEY_8: focus_site(4); return
			KEY_9: focus_site(5); return
			KEY_MINUS: focus_site(6); return
	super._input(event)

func _physics_process(delta: float) -> void:
	if OS.get_cmdline_user_args().has("--expanded-capture"): return
	if is_instance_valid(arena_content) and arena_content.get("kit") and arena_content.kit.own_movement(): return
	# The larger terrain includes canyon floors below the small demo's rescue
	# threshold. Use its movement integrator with a lower rescue threshold.
	if walking and not neighborhood_ready(player.position):
		player.velocity = Vector3.ZERO
		return
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): direction -= camera.basis.z
	if Input.is_key_pressed(KEY_S): direction += camera.basis.z
	if Input.is_key_pressed(KEY_A): direction -= camera.basis.x
	if Input.is_key_pressed(KEY_D): direction += camera.basis.x
	if walking:
		direction.y = 0
		direction = direction.normalized()*(9 if Input.is_key_pressed(KEY_SHIFT) else 5)
		player.velocity.x = direction.x
		player.velocity.z = direction.z
		player.velocity.y -= 20*delta
		if player.is_on_floor() and Input.is_key_pressed(KEY_SPACE): player.velocity.y = 6
		player.move_and_slide()
		player.position.x = clampf(player.position.x,-movement_limit(),movement_limit())
		player.position.z = clampf(player.position.z,-movement_limit(),movement_limit())
		camera.position = player.position+Vector3(0,1.6,0)
	else:
		if Input.is_key_pressed(KEY_SPACE): direction.y += 1
		if Input.is_key_pressed(KEY_CTRL): direction.y -= 1
		camera.position += direction.normalized()*delta*(65 if Input.is_key_pressed(KEY_SHIFT) else 20)
	camera.position.x = clampf(camera.position.x,-movement_limit(),movement_limit())
	camera.position.z = clampf(camera.position.z,-movement_limit(),movement_limit())
	if camera.position.y < -23:
		walking = false
		camera.position.y = 20

func retire_chunk(key: Vector2i) -> void:
	# Keep the visual and collision during fade-out; support pinning keeps
	# occupied neighborhoods out of this retirement path.
	retiring[key]=chunks[key];chunks.erase(key)

func set_chunk_enabled(entry: Dictionary, enabled: bool) -> void:
	entry.node.visible=enabled
	for node in entry.node.get_children():
		if node is StaticBody3D: node.collision_layer=1 if enabled else 0

func store_spare(key: Vector2i, entry: Dictionary) -> void:
	set_chunk_enabled(entry,false)
	# Conservative accounting estimate; count cap also bounds opaque engine data.
	entry.bytes=entry.triangles*240+16384
	spares[key]=entry;spare_order.append(key);spare_bytes+=entry.bytes
	while spare_order.size()>SPARE_CAP or spare_bytes>SPARE_BYTES:
		var oldest: Vector2i=spare_order.pop_front()
		spare_bytes-=spares[oldest].bytes;spares[oldest].node.queue_free();spares.erase(oldest)

func install(key: Vector2i, result: Dictionary) -> void:
	var replacing := chunks.has(key)
	super.install(key,result)
	if not replacing: coverage[key]=0.0

func update_coverage(delta: float) -> void:
	detail_image.fill(Color.BLACK)
	for key in chunks:
		coverage[key]=move_toward(float(coverage.get(key,0.0)),1.0,delta/FADE_SECONDS)
		detail_image.set_pixel(key.x+GRID_LIMIT,key.y+GRID_LIMIT,Color(coverage[key],0,0))
	for key in retiring.keys():
		coverage[key]=move_toward(float(coverage.get(key,1.0)),0.0,delta/FADE_SECONDS)
		if coverage[key]<=0:
			store_spare(key,retiring[key]);retiring.erase(key);coverage.erase(key)
		else: detail_image.set_pixel(key.x+GRID_LIMIT,key.y+GRID_LIMIT,Color(coverage[key],0,0))
	detail_texture.update(detail_image)

func _process(delta: float) -> void:
	# Reuse still-fading entries when reversing direction; no collision rebuild.
	var wanted := desired()
	for key in retiring.keys():
		if key in wanted:
			chunks[key]=retiring[key];retiring.erase(key)
	for key in wanted:
		if spares.has(key):
			var entry: Dictionary=spares[key]
			spares.erase(key);spare_order.erase(key);spare_bytes-=entry.bytes
			if entry.revision==revision:
				chunks[key]=entry;coverage[key]=0.0;set_chunk_enabled(entry,true);spare_hits+=1
			else: entry.node.queue_free()
	super._process(delta)
	if coarse_worker != null and not coarse_worker.is_alive():
		var result: Dictionary = coarse_worker.wait_to_finish()
		coarse_worker = null
		var arrays := mesh_arrays(result)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		if coarse_stage==0:
			coarse.mesh=mesh;coarse_stage=1
			coarse_worker=Thread.new()
			coarse_worker.start(generate.bind(tunnel_radius,roughness,Vector3(-MID_EXTENT,-24,-MID_EXTENT),Vector3i(96,11,96),8.0,mid_field))
		else:
			coarse_mid.mesh=mesh;coarse_ready=true
			coarse.material_override.set_shader_parameter("coarse_inner_extent",MID_EXTENT)
		print("ARENA_COARSE stage=",coarse_stage," generation_ms=",result.ms," triangles=",triangle_count(result))
	update_coverage(delta)
	hud.text = "SDF ARENA / 1536 x 1536m / hills, canyons, tunnels, overpass\n1-4 actors | 0 overview | 5 FOB | 6 relay | 7 canyon | 8-9 tunnels | - outer hills\nWASD + mouse | F walk/fly | Shift faster | Space/Ctrl | T textures | C clouds\n%s | detail %d/%d | distant %s | 2 compounds | ring %d/%d | %.0f FPS" % [
		"WALK" if walking else "FLY",chunks.size(),desired().size(),"ready" if coarse_ready else "generating",ring_background.previews_loaded,ring_background.preview_total,Engine.get_frames_per_second()]
	hud.text+=" | spare %d/%d | cache %d + RAM %d" % [spares.size(),SPARE_CAP,cache_hits,spare_hits]
	var complete: bool = coarse_ready and ready_frames > 2 and is_instance_valid(arena_content) and arena_content.finished and ring_background.previews_loaded == ring_background.preview_total
	if complete:
		expanded_frames += 1
		if OS.get_cmdline_user_args().has("--expanded-check") and not expanded_checked:
			expanded_checked = true
			check_expanded.call_deferred()
		if OS.get_cmdline_user_args().has("--expanded-capture") and expanded_frames >= 90 and not expanded_capture_requested and (not OS.get_cmdline_user_args().has("--expanded-check") or expanded_passed):
			expanded_capture_requested = true
			capture_expanded.call_deferred()

func make_arena_content() -> Node:
	# Automated terrain captures retain static references; interactive scene is live.
	if OS.get_cmdline_user_args().has("--expanded-check") or OS.get_cmdline_user_args().has("--expanded-capture"):
		return super.make_arena_content()
	return preload("res://world/arena_live_content.gd").new()

func check_expanded() -> void:
	await get_tree().physics_frame
	var original_camera := camera.transform
	assert(compounds.size() == 2 and arena_content.entries.size() == 5)
	assert(chunks.size() <= MAX_DETAIL and coarse.mesh != null)
	assert(is_equal_approx(expanded_height(Vector2(FOB.x,FOB.z)),FOB.y))
	assert(is_equal_approx(expanded_height(Vector2(RELAY.x,RELAY.z)),RELAY.y))
	assert(expanded_field(Vector3(-245,8,145),tunnel_radius,roughness) > 0)
	assert(expanded_field(Vector3(-245,23,145),tunnel_radius,roughness) < 0)
	assert(expanded_field(Vector3(145,8,-140),tunnel_radius,roughness) > 0)
	assert(expanded_field(Vector3(-154,-5,-80),tunnel_radius,roughness) > 0)
	assert(expanded_field(Vector3(-154,8,-80),tunnel_radius,roughness) < 0)
	# Gate and both original doorways are open; adjacent walls block a torso ray.
	var space := get_world_3d().direct_space_state
	for x in [0.0,-19.0,18.0]:
		var front := 27.0 if x == 0 else (6.0 if x == -19 else 0.0)
		var query := PhysicsRayQueryParameters3D.create(RELAY+Vector3(x,1.5,front+2),RELAY+Vector3(x,1.5,front-2),2)
		assert(space.intersect_ray(query).is_empty(),"Compound opening blocked")
	var wall_query := PhysicsRayQueryParameters3D.create(RELAY+Vector3(10,1.5,28),RELAY+Vector3(10,1.5,24),2)
	assert(not space.intersect_ray(wall_query).is_empty())
	for compound in compounds:
		camera.position = compound.position+Vector3.UP*20
		while not neighborhood_ready(camera.position): await get_tree().process_frame
		await get_tree().physics_frame
		var terrain_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(compound.position+Vector3.UP*30,compound.position-Vector3.UP*5,1))
		assert(not terrain_hit.is_empty() and absf(terrain_hit.position.y-compound.position.y)<0.05)
	for centre in [Vector3(-245,8,145),Vector3(145,8,-140)]:
		camera.position = centre
		while not neighborhood_ready(centre): await get_tree().process_frame
		await get_tree().physics_frame
		var axis := Vector3.RIGHT if centre.x < 0 else Vector3.BACK
		var passage := PhysicsRayQueryParameters3D.create(centre-axis*30,centre+axis*30,1)
		assert(space.intersect_ray(passage).is_empty(),"Bored passage blocked by generated collision")
		var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(centre,centre+Vector3.UP*40,1))
		assert(not roof.is_empty() and roof.position.y > centre.y)
	# Move detail to the canyon/overpass, check actual deck/floor collision and
	# bounded eviction rather than relying only on the analytic field.
	camera.position = Vector3(-154,20,-80)
	while not neighborhood_ready(camera.position): await get_tree().process_frame
	await get_tree().physics_frame
	var deck := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-154,30,-80),Vector3(-154,5,-80),1))
	assert(not deck.is_empty() and absf(deck.position.y-10.0)<0.1)
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-154,4,-80),Vector3(-154,-24,-80),1))
	assert(not floor_hit.is_empty() and floor_hit.position.y < -10.0)
	assert(chunks.size() <= MAX_DETAIL)
	camera.transform = original_camera
	look = Vector2(camera.rotation.y,camera.rotation.x)
	while not neighborhood_ready(camera.position): await get_tree().process_frame
	expanded_passed = true
	print("PASS: actual tunnel passages/roofs, canyon/overpass collision, both compound terrain pads/gate/doorways, bounded streaming")
	if not OS.get_cmdline_user_args().has("--expanded-capture"): get_tree().quit()

func capture_expanded() -> void:
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png("user://sdf-arena-expanded.png") == OK)
	print("EXPANDED_CAPTURE fps=",Engine.get_frames_per_second()," resident_detail=",chunks.size()," compounds=",compounds.size())
	get_tree().quit()

func _exit_tree() -> void:
	if coarse_worker != null: coarse_worker.wait_to_finish()
	super._exit_tree()
