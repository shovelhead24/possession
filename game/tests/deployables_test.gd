extends SceneTree
const Deployables = preload("res://pipeline/deployables.gd")

# Headless check of the deployable system (game/pipeline/deployables.gd): every recipe builds to a
# single baked mesh, and a placement list survives a save/load round-trip -- the "placed, then
# persistent" pair. Run: godot --headless --path game -s res://tests/deployables_test.gd

func _initialize() -> void:
	var fails := 0

	# Every recipe builds, kitbash bakes to one Baked mesh with real geometry.
	for key in Deployables.RECIPES.keys():
		var node := Deployables.build(str(key))
		fails += _true("%s builds a node" % key, node != null)
		var baked: MeshInstance3D = node.get_node_or_null(MeshBaker.BAKED_NAME) if node else null
		fails += _true("%s baked to one mesh" % key, baked != null and baked.mesh != null)
		fails += _true("%s has geometry" % key,
			baked != null and baked.mesh != null and baked.mesh.get_faces().size() > 0)
		if node:
			node.free()

	# Persistence: a placement list saved out and read back is identical (key + ring coords).
	var path := "user://deployables_test.json"
	var placed := [
		Deployables.make_placement("mine", 120.0, -8.0, 0.0),
		Deployables.make_placement("sensor", 145.5, 3.25, 1.57),
		Deployables.make_placement("turret", 90.0, 12.0, -0.5),
	]
	fails += _true("save succeeds", Deployables.save(placed, path))
	var loaded: Array = Deployables.load(path)
	fails += _num("round-trip count", float(loaded.size()), float(placed.size()))
	for i in mini(loaded.size(), placed.size()):
		fails += _true("placement %d key" % i, str(loaded[i]["key"]) == str(placed[i]["key"]))
		fails += _true("placement %d arc" % i, abs(float(loaded[i]["arc"]) - float(placed[i]["arc"])) < 0.01)
		fails += _true("placement %d lat" % i, abs(float(loaded[i]["lat"]) - float(placed[i]["lat"])) < 0.01)
		fails += _true("placement %d yaw" % i, abs(float(loaded[i]["yaw"]) - float(placed[i]["yaw"])) < 0.01)

	# A bad key never persists as an unbuildable ghost.
	Deployables.save([Deployables.make_placement("not_a_real_deployable", 0.0, 0.0)], path)
	fails += _num("bad key filtered", float(Deployables.load(path).size()), 0.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	if fails == 0:
		print("DEPLOYABLES SELFTEST: PASS")
	else:
		print("DEPLOYABLES SELFTEST: FAIL (", fails, " failed)")
	quit(1 if fails > 0 else 0)

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
