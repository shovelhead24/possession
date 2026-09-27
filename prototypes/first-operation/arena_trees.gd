extends Node3D
var trees: Array[Dictionary]=[]
var buckets: Array=[]
var elapsed := 0.0
var arena: Node3D

func _ready() -> void:
	arena=get_parent()
	if arena.get("world_data"):
		load_baked(arena.world_data);return
	var source=arena.kit.imported(arena.kit.GAME+"realistic_fir_trees_pack_lods_gameready/scene.gltf")
	if not source: return
	var helper=preload("res://tree_mesh_tools.gd").new()
	var regex=RegEx.new();regex.compile("(?i)^(.+?)_LOD(\\d)")
	var variants={};helper._walk_lod_meshes(source,source,regex,variants)
	source.free()
	var keys=variants.keys();keys.sort()
	for key in keys.slice(0,3):
		var levels=[]
		for lod in range(4):
			# The pack's billboard atlas needs its original UV layout. Replacing it with
			# generic quads displays a grid of floating trees. This bounded arena keeps
			# the cheap LOD2 geometry in the far band instead.
			var mesh=helper._normalize_mesh(variants[key].get(mini(lod,2)))
			var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh
			# Only trees close enough to affect immediate cover/readability cast.
			var instance=MultiMeshInstance3D.new();instance.multimesh=mm;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod==0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(instance);levels.append(instance)
		buckets.append(levels)
	assert(not buckets.is_empty(),"Tree pack has no usable LODs")
	var rng=RandomNumberGenerator.new();rng.seed=852
	for attempt in range(1800):
		if trees.size()>=230: break
		var x=rng.randf_range(-230,230);var z=rng.randf_range(-500,-42)
		if absf(x+65)<13 or absf(x-25)<10 or absf(x)<10: continue
		if x>10 and x<55 and z>-95: continue
		if absf(sin(x*.04)+cos(z*.045))<.55: continue
		var pos=Vector3(x,arena.height_at(x,z)-.12,z)
		var crowded=false
		for t in trees:
			if t.position.distance_to(pos)<7: crowded=true;break
		if crowded: continue
		var height=rng.randf_range(7,12)
		var basis=Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*height)
		trees.append({"position":pos,"transform":Transform3D(basis,pos),"variant":rng.randi_range(0,buckets.size()-1)})
		var body=StaticBody3D.new();body.add_to_group("trex_passable_tree");body.position=pos;var collision=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=height*.023;shape.height=height*.55;collision.shape=shape;collision.position.y=shape.height*.5;body.add_child(collision);add_child(body)
	update_lods();print("TREES_READY: ",trees.size()," trees / ",buckets.size()," variants / four LODs")

func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed>.5: elapsed=0;update_lods()

func load_baked(data: Resource) -> void:
	for variant in 3:
		var levels=[]
		for lod in 4:
			var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=data.tree_meshes[variant*4+lod]
			var node=MultiMeshInstance3D.new();node.multimesh=mm;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod==0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);levels.append(node)
		buckets.append(levels)
	trees=data.trees
	for tree in trees:
		var body=StaticBody3D.new();body.add_to_group("trex_passable_tree");body.position=tree.position
		var collision=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=tree.height*.023;shape.height=tree.height*.55;collision.shape=shape;collision.position.y=shape.height*.5;body.add_child(collision);add_child(body)
	update_lods();print("TREES_BAKED_READY: ",trees.size())

func update_lods() -> void:
	var lists=[]
	for variant in buckets: lists.append([[],[],[],[]])
	for tree in trees:
		var distance=arena.camera.global_position.distance_to(tree.position)
		if arena.get("world_data") and distance>380: continue
		var lod=0 if distance<35 else (1 if distance<90 else (2 if distance<180 else 3))
		lists[tree.variant][lod].append(tree.transform)
	for v in range(buckets.size()):
		for l in range(4):
			var mm=buckets[v][l].multimesh;mm.instance_count=lists[v][l].size()
			for i in range(mm.instance_count): mm.set_instance_transform(i,lists[v][l][i])

