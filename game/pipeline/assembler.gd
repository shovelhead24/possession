class_name CharacterAssembler
extends RefCounted

# Kitbash assembler. A part's socket is a Node3D found by name in the template;
# a Skeleton3D bone is one implementation of a socket, resolved via a
# BoneAttachment3D. No skeleton is required — vehicles/buildings socket to nodes.

const TEMPLATE_DIR := "res://pipeline/templates/"

static func assemble(recipe: Recipe) -> Node3D:
	var template_path := TEMPLATE_DIR + recipe.body_plan + ".tscn"
	var template := load(template_path) as PackedScene
	if not template:
		push_error("CharacterAssembler: no template for body plan '%s'" % recipe.body_plan)
		return null

	var root := template.instantiate() as Node3D
	if not root:
		push_error("CharacterAssembler: template '%s' has no Node3D root" % recipe.body_plan)
		return null

	for slot: String in recipe.parts:
		var part_def: PartDef = recipe.parts[slot]
		if not part_def or not part_def.mesh:
			continue
		var mat: Material = recipe.material_overrides.get(slot, null)
		_attach_part(root, part_def, mat)

	return root

static func _attach_part(root: Node3D, part: PartDef, mat: Material) -> void:
	var parent := _resolve_socket(root, part.socket)
	if not parent:
		push_warning("CharacterAssembler: socket '%s' not found for slot '%s'" % [part.socket, part.slot])
		return

	var mi := MeshInstance3D.new()
	mi.mesh = part.mesh
	mi.name = part.slot
	mi.position = part.offset_position
	mi.rotation_degrees = part.offset_rotation_degrees
	mi.scale = part.offset_scale
	if mat:
		mi.material_override = mat
	parent.add_child(mi)

# Resolve a socket name to the Node3D a part should hang under.
# A Node3D by that name wins; otherwise a Skeleton3D bone of that name is
# routed through a (reused) BoneAttachment3D. Empty socket means the root.
static func _resolve_socket(root: Node3D, socket: String) -> Node3D:
	if socket == "":
		return root
	var node := root.find_child(socket, true, false)
	if node is Node3D:
		return node as Node3D
	var skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton and skeleton.find_bone(socket) >= 0:
		return _bone_socket(skeleton, socket)
	return null

static func _bone_socket(skeleton: Skeleton3D, bone: String) -> BoneAttachment3D:
	for c in skeleton.get_children():
		if c is BoneAttachment3D and (c as BoneAttachment3D).bone_name == bone:
			return c as BoneAttachment3D
	var attach := BoneAttachment3D.new()
	attach.bone_name = bone
	attach.name = "Attach_" + bone
	skeleton.add_child(attach)
	return attach

# Convenience: build a recipe from a flat dict and assemble in one call.
# parts_dict: { slot_name: PartDef, ... }
static func quick_assemble(body_plan: String, parts_dict: Dictionary) -> Node3D:
	var recipe := Recipe.new()
	recipe.body_plan = body_plan
	recipe.parts = parts_dict
	return assemble(recipe)
