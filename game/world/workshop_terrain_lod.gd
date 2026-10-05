extends Node3D
## Exterior DEM/SDF tiles. Old complete coverage stays live until replacements exist.
const Recipe=preload("res://world/sdf_recipe.gd")
const Mesher=preload("res://world/tetra_mesher.gd")
const TILE := 256
const EXTENT := 2048
const NORMAL_RES := 33
const FOLDER := "user://sdf-authoring-meshes/unified-lod/"
var arena: Node
var tiles := {}
var wanted := {}
var pending: Array=[]
var worker: Thread
var job := {}
var resident := {}
var staged := {}
var last_view := Vector3.INF
var last_revision := -1
var countdown := 0.0
var source_tag := ""
var mask: Image
var mask_texture: ImageTexture
var mask_signature := ""
var cache_hits := 0
var builds := 0

func setup(owner_arena: Node) -> void:
	arena=owner_arena
	DirAccess.make_dir_recursive_absolute(FOLDER)
	source_tag=FileAccess.get_file_as_string("res://world/workshop_terrain_lod.gd").sha256_text()
	mask=Image.create(128,128,false,Image.FORMAT_R8);mask.fill(Color.BLACK)
	mask_texture=ImageTexture.create_from_image(mask)

func _exit_tree() -> void:
	if worker: worker.wait_to_finish();worker=null

func finished() -> bool:
	return tiles.size()==220 and not wanted.is_empty() and pending.is_empty() and worker==null and staged.is_empty() and resident.is_empty()

static func tile_distance(key: Vector2i, camera: Vector3) -> float:
	var centre := Vector2(key)*TILE+Vector2.ONE*TILE*.5
	var delta := (Vector2(camera.x,camera.z)-centre).abs()-Vector2.ONE*TILE*.5
	return maxf(1,Vector2(maxf(0,delta.x),maxf(0,delta.y)).length())

func select_steps() -> Dictionary:
	var selected := {}
	var focal: float=arena.get_viewport().get_visible_rect().size.y/(2*tan(deg_to_rad(arena.camera.fov)*.5))
	var near_tiles := {}
	for key in arena.chunks:
		var tile := Vector2i(floori(key.x/8.0),floori(key.y/8.0))
		if absi(tile.x)>=3 or absi(tile.y)>=3: near_tiles[tile]=true
	for z in range(-8,8):
		for x in range(-8,8):
			if x>=-3 and x<3 and z>=-3 and z<3: continue
			var key := Vector2i(x,z)
			var height: float=tiles[key].get("height",0.0) if tiles.has(key) else 0.0
			var distance := maxf(tile_distance(key,arena.camera.position),absf(arena.camera.position.y-height))
			var step := 2
			while step<128 and float(step*2)*focal/maxf(1,distance)<10: step*=2
			if near_tiles.has(key): step=2 # Match the fine collision lattice at its coverage edge.
			selected[key]=step
	return selected

func _process(delta: float) -> void:
	if not arena or not arena.terrain_source: return
	var keys: Array=arena.chunks.keys();keys.sort()
	var signature := str(keys)
	if signature!=mask_signature:
		mask_signature=signature;mask.fill(Color.BLACK)
		for key in keys:
			if key.x>=-64 and key.x<64 and key.y>=-64 and key.y<64: mask.set_pixel(key.x+64,key.y+64,Color.WHITE)
		mask_texture.update(mask)
	if worker and not worker.is_alive():
		var result: Dictionary=worker.wait_to_finish();worker=null
		if result.get("cached",false): cache_hits+=1
		else: builds+=1
		if not result.is_empty() and wanted.has(job.key) and wanted[job.key].id==job.id: resident[job.id]=result
		print("TERRAIN_LOD_TILE key=",job.key," step=",job.step," cached=",result.get("cached",false)," build_ms=",result.get("build_ms",0))
	countdown-=delta
	var view: Vector3 = (arena.camera.position/64.0).floor()
	if countdown<=0 and (view!=last_view or last_revision!=arena.revision or signature!=get_meta("planned_mask","")):
		countdown=.5;last_view=view;last_revision=arena.revision;set_meta("planned_mask",signature)
		plan()
	# Upload one replacement per frame, retaining the previous visible layout.
	for spec in wanted.values():
		if resident.has(spec.id) and not staged.has(spec.id):
			staged[spec.id]=prepare(spec,resident[spec.id])
			resident.erase(spec.id)
			break
	var complete := not wanted.is_empty()
	for spec in wanted.values():
		if not staged.has(spec.id) and (not tiles.has(spec.key) or tiles[spec.key].id!=spec.id): complete=false;break
	if complete:
		for spec in wanted.values():
			if tiles.has(spec.key) and tiles[spec.key].id==spec.id: continue
			if tiles.has(spec.key): tiles[spec.key].node.queue_free()
			tiles[spec.key]=staged[spec.id]
			tiles[spec.key].node.show()
		staged.clear()
	if worker==null and not pending.is_empty() and arena.stream_jobs.size()<2 and arena.far_terrain.finished() and (not arena.satellite_stream or not arena.satellite_stream.worker) and not arena.brushing and not arena.brush_dirty:
		job=pending.pop_front()
		worker=Thread.new()
		if worker.start(build.bind(job,arena.terrain_source,arena.tunnel_radius,arena.roughness))!=OK:
			worker=null;pending.push_front(job);push_error("Exterior terrain worker could not start")

func plan() -> void:
	var steps := select_steps()
	wanted.clear();pending.clear()
	for key in steps:
		var local := Recipe.relevant(arena.features,Rect2(Vector2(key)*TILE,Vector2.ONE*TILE).grow(130))
		var neighbors := {}
		for z in range(-1,2):
			for x in range(-1,2):
				var neighbor: Vector2i=key+Vector2i(x,z)
				neighbors[neighbor]=steps.get(neighbor,128 if absi(neighbor.x)>=8 or absi(neighbor.y)>=8 else 16)
		var id: String = (source_tag+arena.terrain_source.base_hash+str(key)+str(neighbors)+JSON.stringify(local)+str(arena.tunnel_radius)+str(arena.roughness)).sha256_text()
		var spec := {"key":key,"step":steps[key],"neighbors":neighbors,"features":local,"id":id}
		wanted[key]=spec
		if (tiles.has(key) and tiles[key].id==id) or staged.has(id) or resident.has(id) or (worker and job.id==id): continue
		pending.append(spec)
	var keep := {}
	for spec in wanted.values(): keep[spec.id]=true
	for id in resident.keys():
		if not keep.has(id): resident.erase(id)
	for id in staged.keys():
		if not keep.has(id): staged[id].node.queue_free();staged.erase(id)
	pending.sort_custom(func(a,b): return tile_distance(a.key,arena.camera.position)<tile_distance(b.key,arena.camera.position))

static func sample_height(source: RefCounted, point: Vector2, stride: int) -> float:
	return source.surface_height(point,float(stride))

static func vertex_height(source: RefCounted, point: Vector2, spec: Dictionary) -> float:
	var local: Vector2=point-Vector2(spec.key)*TILE
	var on_x := is_zero_approx(local.x) or is_equal_approx(local.x,TILE)
	var on_z := is_zero_approx(local.y) or is_equal_approx(local.y,TILE)
	if not on_x and not on_z: return sample_height(source,point,spec.step)
	var stride: int=spec.step
	var adjacent: Vector2i=spec.key+Vector2i(-1 if local.x==0 else 1,0) if on_x else spec.key+Vector2i(0,-1 if local.y==0 else 1)
	stride=maxi(stride,int(spec.neighbors.get(adjacent,128)))
	if on_x and on_z:
		for dz in [-1,0]:
			for dx in [-1,0]:
				stride=maxi(stride,int(spec.neighbors.get(Vector2i(roundi(point.x/TILE)+dx,roundi(point.y/TILE)+dz),128)))
		return sample_height(source,point,stride)
	var coordinate := point.y if on_x else point.x
	var lo := floorf(coordinate/stride)*stride
	var a := Vector2(point.x,lo) if on_x else Vector2(lo,point.y)
	var b := a+(Vector2(0,stride) if on_x else Vector2(stride,0))
	# Shared endpoints use the maximum footprint of every tile meeting there.
	var ha := sample_height(source,a,stride);var hb := sample_height(source,b,stride)
	if is_zero_approx(fposmod(lo,TILE)): ha=corner_height(source,a,spec.neighbors,stride)
	if is_zero_approx(fposmod(lo+stride,TILE)): hb=corner_height(source,b,spec.neighbors,stride)
	return lerpf(ha,hb,(coordinate-lo)/stride)

static func corner_height(source: RefCounted, point: Vector2, neighbors: Dictionary, stride: int) -> float:
	for z in [-1,0]:
		for x in [-1,0]: stride=maxi(stride,int(neighbors.get(Vector2i(roundi(point.x/TILE)+x,roundi(point.y/TILE)+z),128)))
	return sample_height(source,point,stride)

func build(spec: Dictionary, source: RefCounted, radius: float, rough: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	var path: String = FOLDER+spec.id+".bin"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path,FileAccess.READ)
		var cached: Variant=file.get_var(false) if file else null
		if cached is Dictionary and cached.get("id")==spec.id and cached.get("vertices") is PackedVector3Array and cached.get("normals") is PackedVector3Array and cached.get("indices") is PackedInt32Array:
			cached.cached=true;return cached
	var result := {}
	var actual := Recipe.relevant(spec.features,Rect2(Vector2(spec.key)*TILE,Vector2.ONE*TILE).grow(2))
	if not actual.is_empty():
		# Authored exterior volumes retain a 3D extractor, including undersides.
		var origin := Vector3(spec.key.x*TILE,-24,spec.key.y*TILE)
		var top := 64.0
		for p in [Vector2.ZERO,Vector2(TILE,0),Vector2(0,TILE),Vector2.ONE*TILE,Vector2.ONE*TILE*.5]: top=maxf(top,source.surface_height(Vector2(spec.key)*TILE+p)+32)
		for f in actual: top=maxf(top,float(f.y)+float(f.height)+float(f.radius))
		var step: int=maxi(8,spec.step)
		result=Mesher.build(Recipe.field.bind(radius,rough,actual,source),origin,Vector3i(TILE/step,ceili((top+24)/step),TILE/step),step)
		result.normal_data=PackedByteArray()
	else:
		var vertices := PackedVector3Array();var normals := PackedVector3Array();var indices := PackedInt32Array()
		var count: int=TILE/spec.step+1
		for z in count:
			for x in count:
				var p: Vector2=Vector2(spec.key)*TILE+Vector2(x,z)*spec.step
				vertices.append(Vector3(p.x,vertex_height(source,p,spec),p.y));normals.append(source.surface_normal(p,maxf(2,spec.step/8.0)))
		for z in count-1:
			for x in count-1:
				var a := z*count+x
				indices.append_array(PackedInt32Array([a,a+1,a+count,a+1,a+count+1,a+count]))
		var normal_map := Image.create(NORMAL_RES,NORMAL_RES,false,Image.FORMAT_RGB8)
		for z in NORMAL_RES:
			for x in NORMAL_RES:
				var p: Vector2=Vector2(spec.key)*TILE+Vector2(x,z)*(float(TILE)/(NORMAL_RES-1))
				var n: Vector3=source.surface_normal(p,maxf(2,spec.step/8.0))
				normal_map.set_pixel(x,z,Color(n.x*.5+.5,n.y*.5+.5,n.z*.5+.5))
		result={"vertices":vertices,"normals":normals,"indices":indices,"normal_data":normal_map.get_data()}
	result.id=spec.id;result.cached=false;result.build_ms=(Time.get_ticks_usec()-started)/1000.0
	result.height=source.surface_height(Vector2(spec.key)*TILE+Vector2.ONE*TILE*.5)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file: file.store_var(result,false);file.close();DirAccess.rename_absolute(path+".tmp",path)
	return result

func prepare(spec: Dictionary, result: Dictionary) -> Dictionary:
	var mesh := ArrayMesh.new()
	if not result.vertices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arena.mesh_arrays(result))
	var node := MeshInstance3D.new();node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: ShaderMaterial=arena.terrain.material_override.duplicate()
	material.set_shader_parameter("coarse_surface",true);material.set_shader_parameter("local_extent",float(EXTENT));material.set_shader_parameter("detail_mask",mask_texture)
	material.set_shader_parameter("surface_normal_rect",Vector4(spec.key.x*TILE,spec.key.y*TILE,TILE,TILE))
	if not result.normal_data.is_empty():
		var img := Image.create_from_data(NORMAL_RES,NORMAL_RES,false,Image.FORMAT_RGB8,result.normal_data)
		img.generate_mipmaps()
		material.set_shader_parameter("surface_normal_texture",ImageTexture.create_from_image(img));material.set_shader_parameter("cached_surface_normals",true)
	node.material_override=material;node.hide();add_child(node)
	if arena.satellite_stream: arena.satellite_stream.bind_material(material)
	return {"node":node,"id":spec.id,"step":spec.step,"height":result.height}
