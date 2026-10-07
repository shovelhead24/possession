class_name MeshBaker
extends RefCounted

# Bake after assembly. Kitbashing a building from 12 PartDefs leaves 12 MeshInstance3D nodes =
# 12 draw calls; a 200-building settlement is 2,400 on a GL Compatibility Intel UHD target. This
# merges every STATIC MeshInstance3D descendant of `root` into a single MeshInstance3D -- one
# ArrayMesh, one surface per material -- and discards the merged part nodes.
#
# THE RULE (TASKS.md): what must move independently stays a node; what is static relative to its
# parent gets merged. A node put in the SKIP_GROUP group (or given meta "bake" = false), and its
# whole subtree, is left untouched -- a vehicle's wheels steer and roll, a character's parts follow
# bones, so they survive while the chassis bakes. The assembler is correct FOR CHARACTERS precisely
# because its parts are bone-driven; call this only on the static kitbash (buildings, chassis, guns).

const SKIP_GROUP := "no_bake"
const BAKED_NAME := "Baked"

# Merge static MeshInstance3D descendants of `root` into one MeshInstance3D added under `root`.
# Returns the baked node, or null if there was nothing static to merge.
static func bake(root: Node3D) -> MeshInstance3D:
	if root == null:
		return null
	var buckets: Dictionary = {}      # Material (or null) -> SurfaceTool, accumulating one surface each
	var order: Array = []             # keys in first-seen order, so surfaces come out deterministically
	var merged: Array[MeshInstance3D] = []
	_gather(root, root, buckets, order, merged)
	if merged.is_empty():
		return null

	var out := ArrayMesh.new()
	for mat in order:
		var st: SurfaceTool = buckets[mat]
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mat)

	# Discard the parts we baked in. Reverse order = children before parents, so a merged parent
	# whose children were all merged becomes a leaf and is freed too; one still holding a surviving
	# (dynamic) child keeps its mesh cleared but stays as a container.
	merged.reverse()
	for mi in merged:
		if not is_instance_valid(mi):
			continue
		mi.mesh = null
		if mi.get_child_count() == 0:
			mi.free()

	var baked := MeshInstance3D.new()
	baked.name = BAKED_NAME
	baked.mesh = out
	root.add_child(baked)
	if root.owner:
		baked.owner = root.owner
	return baked

static func _gather(node: Node, root: Node3D, buckets: Dictionary, order: Array, merged: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is Node3D and _is_dynamic(child):
			continue   # dynamic subtree: leave it and everything under it alone
		if child is MeshInstance3D and child.mesh:
			_append(child, root, buckets, order)
			merged.append(child)
		_gather(child, root, buckets, order, merged)

static func _append(mi: MeshInstance3D, root: Node3D, buckets: Dictionary, order: Array) -> void:
	var xf := _xform_to_root(mi, root)
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		var mat := _effective_material(mi, s)
		if not buckets.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			buckets[mat] = st
			order.append(mat)
		_merge_surface(buckets[mat], mesh, s, xf)

# Re-add every vertex of one source surface into `st`, transformed by `xf` and normalised to a single
# (position, normal, uv) format. Do NOT use SurfaceTool.append_from here: it silently DROPS a surface
# whose vertex format differs from what the bucket already holds, so a SurfaceTool-built roof (no UVs)
# vanishes the moment it shares a material with a BoxMesh part (UVs) -- which is exactly the meru,
# whose joglo roof and veranda are both roof_j. Rebuilding by hand with a fixed format is immune.
static func _merge_surface(st: SurfaceTool, mesh: Mesh, s: int, xf: Transform3D) -> void:
	var arr := mesh.surface_get_arrays(s)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return
	var norms := PackedVector3Array()
	if arr[Mesh.ARRAY_NORMAL] != null:
		norms = arr[Mesh.ARRAY_NORMAL]
	var uvs := PackedVector2Array()
	if arr[Mesh.ARRAY_TEX_UV] != null:
		uvs = arr[Mesh.ARRAY_TEX_UV]
	var idx := PackedInt32Array()
	if arr[Mesh.ARRAY_INDEX] != null:
		idx = arr[Mesh.ARRAY_INDEX]
	var nbasis := xf.basis
	var emit := func(vi: int) -> void:
		st.set_normal((nbasis * norms[vi]).normalized() if vi < norms.size() else Vector3.UP)
		st.set_uv(uvs[vi] if vi < uvs.size() else Vector2.ZERO)
		st.add_vertex(xf * verts[vi])
	if idx.size() > 0:
		for i in idx:
			emit.call(i)
	else:
		for i in verts.size():
			emit.call(i)

# material_override beats a per-surface override beats the mesh's own surface material (Godot order).
static func _effective_material(mi: MeshInstance3D, s: int) -> Material:
	if mi.material_override:
		return mi.material_override
	var so := mi.get_surface_override_material(s)
	if so:
		return so
	return mi.mesh.surface_get_material(s)

static func _is_dynamic(node: Node) -> bool:
	if node.is_in_group(SKIP_GROUP):
		return true
	return node.has_meta("bake") and node.get_meta("bake") == false

# Transform of `node` expressed in `root`'s space, by walking the parent chain -- works whether or
# not the tree is inside a SceneTree (matches ring_vibes._rel_xform).
static func _xform_to_root(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
