class_name Deployables
extends RefCounted

# see .decisions/ -- the vehicle/building/weapon/structure recipe framing (TASKS.md), applied to
# player-PLACED objects. A deployable is a kitbash like the dock port: a base socket with a few tinted
# box|cyl parts hung on it, assembled through the SHARED CharacterAssembler (the fifth consumer of the
# Skeleton3D-unlock) and baked to one node via MeshBaker. Mines, sensors and a tripod turret are three
# recipes, not three bespoke models -- the same argument as the 40 vehicles.
#
# THE NEW PART is not the mesh, it is "Placed, then persistent": a placement is a ring coordinate
# (arc, lat, yaw) + a recipe key, and the set survives a run via save()/load() to a JSON file. This
# module stays engine-agnostic on placement -- it builds the mesh and serialises the list; the caller
# owns the ring math (where local +Y is ring-up), exactly as the dock port is built here and oriented
# by ring_vibes.

# Recipe = list of parts. Each part: a tinted box|cyl on a named socket at an offset. `tripod` is the
# one computed directive (like structure's `ring`): it splays `count` legs from a foot ring out on the
# ground up to an apex, so a turret reads as three-legged rather than a box on a stick.
const RECIPES := {
	# MINE -- squat and wide, sitting on the ground: a low drum, a hazard band, a stub trigger prong.
	# The silhouette to hit is "low disc", the opposite of the tall sensor/turret so the three never
	# confuse at a glance.
	"mine": [
		{"slot": "drum",  "socket": "base", "kind": "cyl", "size": Vector3(0.70, 0.14, 0.70), "pos": Vector3(0.0, 0.07, 0.0), "tint": Color(0.18, 0.19, 0.21)},
		{"slot": "band",  "socket": "base", "kind": "cyl", "size": Vector3(0.52, 0.07, 0.52), "pos": Vector3(0.0, 0.17, 0.0), "tint": Color(0.85, 0.62, 0.10)},
		{"slot": "prong", "socket": "base", "kind": "cyl", "size": Vector3(0.05, 0.30, 0.05), "pos": Vector3(0.0, 0.33, 0.0), "tint": Color(0.12, 0.12, 0.13)},
	],
	# SENSOR -- tall and thin: a ground stake, a mast, a housing, and an emissive panel canted skyward.
	# The panel glows so a placed sensor reads as "on" and is distinct from the (dark) turret mast.
	"sensor": [
		{"slot": "stake", "socket": "base", "kind": "cyl", "size": Vector3(0.10, 0.40, 0.10), "pos": Vector3(0.0, 0.20, 0.0), "tint": Color(0.14, 0.14, 0.15)},
		{"slot": "mast",  "socket": "base", "kind": "cyl", "size": Vector3(0.07, 1.50, 0.07), "pos": Vector3(0.0, 1.15, 0.0), "tint": Color(0.42, 0.44, 0.47)},
		{"slot": "head",  "socket": "base", "kind": "box", "size": Vector3(0.34, 0.22, 0.16), "pos": Vector3(0.0, 1.95, 0.0), "tint": Color(0.32, 0.34, 0.37)},
		{"slot": "dish",  "socket": "base", "kind": "box", "size": Vector3(0.46, 0.46, 0.04), "pos": Vector3(0.0, 2.06, 0.06), "rot": Vector3(-35.0, 0.0, 0.0), "tint": Color(0.15, 0.55, 0.70), "emit": true},
	],
	# TURRET -- a tripod: three splayed legs to an apex hub, a body, and a barrel out the front (-Z).
	# The legs ARE the read; a body on a single post would be the sensor again.
	"turret": [
		{"slot": "leg", "socket": "base", "kind": "cyl", "size": Vector3(0.06, 1.0, 0.06), "tint": Color(0.20, 0.21, 0.23), "tripod": {"count": 3, "spread": 0.62, "apex": 0.80}},
		{"slot": "hub",    "socket": "base", "kind": "cyl", "size": Vector3(0.34, 0.20, 0.34), "pos": Vector3(0.0, 0.82, 0.0), "tint": Color(0.30, 0.31, 0.34)},
		{"slot": "body",   "socket": "base", "kind": "box", "size": Vector3(0.42, 0.30, 0.52), "pos": Vector3(0.0, 1.02, 0.0), "tint": Color(0.34, 0.36, 0.39)},
		{"slot": "barrel", "socket": "base", "kind": "cyl", "size": Vector3(0.09, 0.90, 0.09), "pos": Vector3(0.0, 1.06, -0.52), "rot": Vector3(90.0, 0.0, 0.0), "tint": Color(0.12, 0.12, 0.13)},
	],
}

# Build a deployable from its recipe: base socket, tinted parts via the SHARED assembler, then bake the
# static kitbash to one node. Returns the root; the CALLER positions/orients it (local +Y is ring-up).
# Detached-tree safe (no SceneTree needed), like the character/structure builds.
static func build(key: String) -> Node3D:
	var root := Node3D.new()
	root.name = "deployable_" + key
	var base := Node3D.new()
	base.name = "base"
	root.add_child(base)
	var recipe := Recipe.new()
	recipe.body_plan = "deployable"
	for spec: Dictionary in RECIPES.get(key, []):
		var tripod: Dictionary = spec.get("tripod", {})
		if tripod.is_empty():
			_add_part(recipe, spec["slot"], spec, spec.get("pos", Vector3.ZERO), spec.get("rot", Vector3.ZERO))
			continue
		# Splay `count` legs from a foot ring (radius `spread`, on the ground) to an apex on the axis,
		# each stretched to bridge the gap and aimed along it -- a tripod computed from data, the same
		# way structure's `ring` is computed rather than authored leg by leg.
		var count: int = tripod.get("count", 3)
		var spread: float = tripod.get("spread", 0.6)
		var apex := Vector3(0.0, tripod.get("apex", 0.8), 0.0)
		for i in count:
			var a := TAU * float(i) / float(count)
			var foot := Vector3(sin(a) * spread, 0.02, cos(a) * spread)
			var mid := (foot + apex) * 0.5
			var d := (apex - foot)
			var leg_len: float = maxf(d.length(), 0.01)
			var leg_spec := spec.duplicate()
			var s: Vector3 = spec.get("size", Vector3.ONE)
			leg_spec["size"] = Vector3(s.x, leg_len, s.z)   # stretch the leg to reach the apex
			_add_part(recipe, "%s_%d" % [spec["slot"], i], leg_spec, mid, _dir_to_euler(d / leg_len))
	CharacterAssembler.apply(root, recipe)
	MeshBaker.bake(root)
	return root

static func _add_part(recipe: Recipe, slot: String, spec: Dictionary, pos: Vector3, rot: Vector3) -> void:
	var pd := PartDef.new()
	pd.slot = slot
	pd.socket = spec.get("socket", "base")
	pd.mesh = _part_mesh(spec)
	pd.offset_position = pos
	pd.offset_rotation_degrees = rot
	recipe.parts[slot] = pd

# tinted box | 12-segment cylinder, the same generator shape the vehicle/weapon/structure parts use.
# A unique material per part means one surface per part after the bake -- fine for a handful of parts.
static func _part_mesh(spec: Dictionary) -> Mesh:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = spec.get("tint", Color(0.3, 0.3, 0.3))
	if spec.get("emit", false):
		mat.emission_enabled = true
		mat.emission = spec.get("tint", Color(0.3, 0.3, 0.3))
		mat.emission_energy_multiplier = 1.2
	var size: Vector3 = spec.get("size", Vector3.ONE)
	if spec.get("kind", "box") == "cyl":
		var cm := CylinderMesh.new()
		cm.radial_segments = 12
		cm.rings = 1
		cm.height = size.y
		cm.top_radius = size.x * 0.5
		cm.bottom_radius = size.x * 0.5
		cm.material = mat
		return cm
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	return bm

# Euler (degrees, YXZ -- Node3D's default order) that aligns a part's local +Y to direction `d`. Used
# to lay a leg (a Y-long cylinder) along an arbitrary splay vector.
static func _dir_to_euler(d: Vector3) -> Vector3:
	var yb := d.normalized()
	var ref := Vector3.RIGHT if absf(yb.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var zb := ref.cross(yb).normalized()
	var xb := yb.cross(zb).normalized()
	var e := Basis(xb, yb, zb).get_euler()
	return Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z))


# --- placement + persistence -------------------------------------------------------------------
# A placement is a plain dict {key, arc, lat, yaw}. The set is the player's placed deployables; it is
# saved to and restored from a JSON file so a run's placements survive into the next -- the "then
# persistent" half of the item. Kept as data (not built nodes) so save/load needs no scene.

const SAVE_PATH := "user://deployables.json"

static func make_placement(key: String, arc: float, lat: float, yaw: float = 0.0) -> Dictionary:
	return {"key": key, "arc": arc, "lat": lat, "yaw": yaw}

# Write the placement list to `path`. Only known recipe keys are persisted, so a typo never resurrects
# as an unbuildable ghost on the next load.
static func save(placements: Array, path: String = SAVE_PATH) -> bool:
	var out: Array = []
	for p in placements:
		if p is Dictionary and RECIPES.has(str(p.get("key", ""))):
			out.append({
				"key": str(p["key"]),
				"arc": float(p.get("arc", 0.0)),
				"lat": float(p.get("lat", 0.0)),
				"yaw": float(p.get("yaw", 0.0)),
			})
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Deployables.save: cannot open %s" % path)
		return false
	f.store_string(JSON.stringify(out))
	f.close()
	return true

static func load(path: String = SAVE_PATH) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Array):
		return []
	var out: Array = []
	for p in parsed:
		if p is Dictionary and RECIPES.has(str(p.get("key", ""))):
			out.append(make_placement(str(p["key"]), float(p.get("arc", 0.0)),
				float(p.get("lat", 0.0)), float(p.get("yaw", 0.0))))
	return out
