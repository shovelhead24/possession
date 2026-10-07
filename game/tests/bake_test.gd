extends SceneTree
const MeshBaker = preload("res://pipeline/mesh_baker.gd")

# Headless check of the post-assembly bake (game/pipeline/mesh_baker.gd): static parts merge into
# one ArrayMesh with one surface per material, dynamic (no_bake) parts survive, geometry is kept.
# Run: godot --headless --path game -s res://tests/bake_test.gd

func _initialize() -> void:
	var fails := 0
	var mat_a := StandardMaterial3D.new()
	var mat_b := StandardMaterial3D.new()

	# A kitbash: three static boxes (two share mat_a, one uses mat_b) + one dynamic "wheel".
	var root := Node3D.new()
	root.add_child(_box(Vector3(0, 0, 0), mat_a))
	root.add_child(_box(Vector3(3, 0, 0), mat_a))
	root.add_child(_box(Vector3(0, 3, 0), mat_b))
	var wheel := _box(Vector3(0, 0, 5), null)
	wheel.name = "Wheel"
	wheel.add_to_group(MeshBaker.SKIP_GROUP)
	root.add_child(wheel)

	var tris_in := 0
	for c in root.get_children():
		tris_in += (c as MeshInstance3D).mesh.get_faces().size() / 3
	var tris_static := tris_in - wheel.mesh.get_faces().size() / 3

	var baked := MeshBaker.bake(root)

	fails += _true("baked node returned", baked != null)
	fails += _true("baked has mesh", baked != null and baked.mesh != null)
	# 3 static boxes across 2 materials -> 2 surfaces.
	fails += _num("surface per material", float(baked.mesh.get_surface_count()), 2.0)
	fails += _true("surface mats are A and B",
		_has_mat(baked.mesh, mat_a) and _has_mat(baked.mesh, mat_b))
	# geometry preserved: baked triangles == the three static boxes, wheel excluded.
	fails += _num("triangles preserved", float(baked.mesh.get_faces().size() / 3), float(tris_static))
	# nodes discarded: only the surviving wheel + the new Baked node remain.
	fails += _num("root child count", float(root.get_child_count()), 2.0)
	fails += _true("wheel survived", is_instance_valid(wheel) and wheel.get_parent() == root)

	# Nothing static -> no baked node, nothing touched.
	var empty := Node3D.new()
	var only_wheel := _box(Vector3.ZERO, null)
	only_wheel.add_to_group(MeshBaker.SKIP_GROUP)
	empty.add_child(only_wheel)
	fails += _true("no-op when all dynamic", MeshBaker.bake(empty) == null)
	fails += _num("dynamic-only untouched", float(empty.get_child_count()), 1.0)

	if fails == 0:
		print("BAKE SELFTEST: PASS")
	else:
		print("BAKE SELFTEST: FAIL (", fails, " failed)")
	quit(1 if fails > 0 else 0)

func _box(pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.position = pos
	if mat:
		mi.material_override = mat
	return mi

func _has_mat(mesh: ArrayMesh, mat: Material) -> bool:
	for s in mesh.get_surface_count():
		if mesh.surface_get_material(s) == mat:
			return true
	return false

func _num(label: String, got: float, want: float) -> int:
	if abs(got - want) < 0.001:
		print("  ok  ", label, " = ", got)
		return 0
	print("  BAD ", label, " got ", got, " want ", want)
	return 1

func _true(label: String, cond: bool) -> int:
	if cond:
		print("  ok  ", label)
		return 0
	print("  BAD ", label)
	return 1
