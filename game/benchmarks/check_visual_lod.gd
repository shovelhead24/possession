extends SceneTree
const MeshLOD=preload("res://world/runtime_mesh_lod.gd")
const Content=preload("res://world/arena_content.gd")

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("Visual LOD test timeout");quit(1))
	run.call_deferred()

func run() -> void:
	var sphere := SphereMesh.new();sphere.radial_segments=64;sphere.rings=32
	var arrays := sphere.surface_get_arrays(0)
	var material := StandardMaterial3D.new()
	var state := GLTFState.new();var entry := GLTFMesh.new();entry.mesh=ImporterMesh.new()
	entry.mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},material,"test surface")
	state.set_meshes([entry])
	MeshLOD.prepare(state,"res://benchmarks/check_visual_lod.gd")
	var first: ImporterMesh=state.get_meshes()[0].mesh
	assert(first.get_surface_lod_count(0)>0,"No generated LODs")
	var levels := {}
	for i in first.get_surface_lod_count(0): levels[first.get_surface_lod_size(0,i)]=first.get_surface_lod_indices(0,i)
	entry=GLTFMesh.new();entry.mesh=ImporterMesh.new()
	entry.mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},material,"test surface")
	state.set_meshes([entry]);MeshLOD.prepare(state,"res://benchmarks/check_visual_lod.gd")
	var warm: ImporterMesh=state.get_meshes()[0].mesh
	assert(warm.get_surface_arrays(0)==arrays,"Cached LOD changed full-detail attributes")
	assert(warm.get_surface_material(0)==material and warm.get_surface_name(0)=="test surface")
	assert(warm.get_surface_lod_count(0)==levels.size())
	for i in warm.get_surface_lod_count(0):
		assert(warm.get_surface_lod_indices(0,i)==levels[warm.get_surface_lod_size(0,i)])
	var ring=load("res://mocks/ring_vibes.gd").new()
	var billboard: ArrayMesh=ring._billboard_from(sphere)
	assert(billboard.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==12,"Billboard must have four triangles")
	assert(is_equal_approx(billboard.get_aabb().size.y,1.0),"Billboard height changed")
	ring.free()
	for pair in [[0,0],[21.9,0],[22,1],[64.9,1],[65,2],[109.9,2],[110,3],[500,3]]:
		assert(Content.tree_lod(pair[0])==pair[1],"Tree LOD selection")
	var world := Node3D.new();root.add_child(world)
	var camera := Camera3D.new();world.add_child(camera)
	var mesh := MeshInstance3D.new();mesh.mesh=sphere;world.add_child(mesh)
	var shadows=load("res://world/vehicle_shadow_lod.gd").new();world.add_child(shadows)
	camera.position.z=1000;shadows.setup(world,camera)
	assert(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	camera.position.z=2;shadows.update_shadows()
	assert(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"Near shadow did not recover")
	var batcher=load("res://world/rigid_mesh_batch.gd")
	for attempt in 2:
		var assembly := Node3D.new();world.add_child(assembly)
		var originals := []
		for x in [-2.0,2.0]:
			var part := MeshInstance3D.new();part.name="Left" if x<0 else "Right"
			part.mesh=first.get_mesh();part.material_override=material;assembly.add_child(part);part.position.x=x;originals.append(part)
		var pivot := Node3D.new();pivot.name="MovingPivot";assembly.add_child(pivot)
		var separate := MeshInstance3D.new();separate.mesh=sphere;pivot.add_child(separate)
		batcher.combine(assembly,[pivot],"unit-batch"+FileAccess.get_sha256("res://benchmarks/check_visual_lod.gd"))
		assert(originals[0].layers==0 and originals[1].layers==0 and separate.layers==1,"Rigid batching changed an excluded rig")
		var combined: MeshInstance3D=assembly.get_node("RigidMaterialBatch0")
		assert(combined.mesh.get_aabb().size.x>4.9 and combined.mesh.get_aabb().size.x<5.1,"Rigid transforms changed")
		pivot.rotation.y=.4
		assert(combined.get_parent()==assembly and separate.get_parent()==pivot)
		assembly.free()
	print("VISUAL_LOD_PASS cached indices, full-detail attributes, billboard geometry, tree bands, shadow recovery")
	quit()
