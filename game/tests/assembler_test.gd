extends SceneTree
const Assembler = preload("res://pipeline/assembler.gd")

# Headless check that the assembler sockets to a Node3D by NAME, with a Skeleton3D
# bone as just one implementation -- no skeleton required (game/pipeline/assembler.gd).
# Run: godot --headless --path game -s res://tests/assembler_test.gd

func _initialize() -> void:
	var fails := 0

	# 1. Node3D socket by name, no skeleton in sight (the vehicle/building case).
	var veh := Node3D.new()
	var hub := Node3D.new()
	hub.name = "wheel_fl"
	veh.add_child(hub)
	fails += _true("node socket resolves to the named node",
		Assembler._resolve_socket(veh, "wheel_fl") == hub)
	fails += _true("empty socket resolves to root",
		Assembler._resolve_socket(veh, "") == veh)
	fails += _true("unknown socket resolves to null",
		Assembler._resolve_socket(veh, "nope") == null)

	# 2. A Skeleton3D bone is one implementation of a socket.
	var rig := Node3D.new()
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	skel.add_bone("spine")
	rig.add_child(skel)
	var s1 := Assembler._resolve_socket(rig, "spine")
	fails += _true("bone socket makes a BoneAttachment3D", s1 is BoneAttachment3D)
	fails += _true("attachment names the bone",
		s1 is BoneAttachment3D and (s1 as BoneAttachment3D).bone_name == "spine")
	# A second part on the same bone reuses the attachment, not a duplicate.
	var s2 := Assembler._resolve_socket(rig, "spine")
	fails += _true("bone attachment reused", s1 == s2)
	fails += _num("one attachment under skeleton", float(skel.get_child_count()), 1.0)

	# 3. A node beats a same-named bone (node path is tried first).
	var mix := Node3D.new()
	var mskel := Skeleton3D.new()
	mskel.name = "Skeleton3D"
	mskel.add_bone("head")
	mix.add_child(mskel)
	var named := Node3D.new()
	named.name = "head"
	mix.add_child(named)
	fails += _true("node beats bone of the same name",
		Assembler._resolve_socket(mix, "head") == named)

	# 4. Full attach: a part's mesh lands under its socket node.
	var part := PartDef.new()
	part.slot = "body"
	part.socket = "wheel_fl"
	part.mesh = BoxMesh.new()
	Assembler._attach_part(veh, part, null)
	fails += _true("mesh attached under socket", hub.get_node_or_null("body") is MeshInstance3D)

	if fails == 0:
		print("ASSEMBLER SELFTEST: PASS")
	else:
		print("ASSEMBLER SELFTEST: FAIL (", fails, " failed)")
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
