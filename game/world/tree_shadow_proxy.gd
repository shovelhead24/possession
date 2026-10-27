extends Node3D
## Opaque, shadow-only silhouettes; visible foliage keeps its original materials/LODs.
var meshes: Array[ArrayMesh]=[]
var batches := {}
var uploaded := {}
var tree_count := 0
var update_ms := 0.0
var last_state: Array=[]
func origin_shifted(_delta: Vector3):
	last_state.clear();uploaded.clear()

func setup(patch: Node3D) -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	for species in patch.names:
		var bounds: AABB=patch.variants[species][0].get_aabb()
		meshes.append(make_canopy(maxf(bounds.size.x,bounds.size.z)*0.44))

static func make_canopy(radius: float) -> ArrayMesh:
	var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Three overlapping closed cones, eight sides each: 48 triangles total.
	for tier in range(3):
		var bottom := 0.15+tier*0.23
		var top := minf(1.0,bottom+0.46)
		var width := radius*(1.0-tier*0.28)
		for side in range(8):
			var a := Vector3(cos(side*TAU/8)*width,bottom,sin(side*TAU/8)*width)
			var b := Vector3(cos((side+1)*TAU/8)*width,bottom,sin((side+1)*TAU/8)*width)
			for vertex in [a,Vector3(0,top,0),b,b,Vector3(0,bottom,0),a]: surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new();material.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0,material)
	return mesh

func refresh(arena: Node3D, active: bool) -> void:
	var started := Time.get_ticks_usec()
	visible=active
	if not active:
		tree_count=0;last_state.clear();return
	var state := [arena.trees.shadow_revision,arena.painted_trees.shadow_revision,arena.trees.enabled,arena.painted_trees.enabled]
	if state==last_state: update_ms=0.0;return
	last_state=state;tree_count=0
	var groups := {}
	for patch in [arena.trees,arena.painted_trees]:
		if not patch.enabled: continue
		for index in patch.count_limit:
			var item: Dictionary=patch.candidates[index]
			if not item.valid: continue
			if arena.get("edited_render_lods") and arena.edited_render_lods.is_edit_hidden(Vector2i((item.point/200.0).floor())): continue
			# Conservative margin includes tall trees whose shadows reach into view.
			# Keep 650 m of support for low sun and steep edited ground; renderer
			# shadow-frustum culling then rejects irrelevant spatial cells.
			if item.transform.origin.distance_to(arena.camera.global_position)>650.0: continue
			var cell := Vector2i((item.point/96.0).floor())
			var key := Vector3i(cell.x,cell.y,item.variant)
			if not groups.has(key): groups[key]=[]
			groups[key].append(item.transform);tree_count+=1
	for key in batches.keys():
		if not groups.has(key):
			batches[key].queue_free();batches.erase(key);uploaded.erase(key)
	for key in groups:
		if not batches.has(key):
			var node := MultiMeshInstance3D.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
			node.multimesh.mesh=meshes[key.z];add_child(node);batches[key]=node
		if uploaded.get(key,[])==groups[key]: continue
		batches[key].position=Vector3.ZERO
		uploaded[key]=groups[key]
		var mm: MultiMesh=batches[key].multimesh;mm.instance_count=groups[key].size()
		for index in groups[key].size(): mm.set_instance_transform(index,groups[key][index])
	update_ms=(Time.get_ticks_usec()-started)/1000.0
