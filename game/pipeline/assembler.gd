class_name CharacterAssembler
extends RefCounted

const TEMPLATE_DIR := "res://pipeline/templates/"

static func assemble(recipe: CharacterRecipe) -> Node3D:
	var template_path := TEMPLATE_DIR + recipe.body_plan + ".tscn"
	var template := load(template_path) as PackedScene
	if not template:
		push_error("CharacterAssembler: no template for body plan '%s'" % recipe.body_plan)
		return null

	var root := template.instantiate() as Node3D
	var skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		push_error("CharacterAssembler: template has no Skeleton3D")
		root.queue_free()
		return null

	for slot: String in recipe.parts:
		var part_def: PartDef = recipe.parts[slot]
		if not part_def or not part_def.mesh:
			continue
		var mat: Material = recipe.material_overrides.get(slot, null)
		_attach_part(skeleton, part_def, mat)

	return root

static func _attach_part(skeleton: Skeleton3D, part: PartDef, mat: Material) -> void:
	var bone_idx := skeleton.find_bone(part.bone_name)
	if bone_idx < 0:
		push_warning("CharacterAssembler: bone '%s' not found for slot '%s'" % [part.bone_name, part.slot])
		return

	var attach := BoneAttachment3D.new()
	attach.bone_name = part.bone_name
	attach.name = "Attach_" + part.slot
	skeleton.add_child(attach)

	var mi := MeshInstance3D.new()
	mi.mesh = part.mesh
	mi.name = part.slot
	mi.position = part.offset_position
	mi.rotation_degrees = part.offset_rotation_degrees
	mi.scale = part.offset_scale
	if mat:
		mi.material_override = mat
	attach.add_child(mi)

# Convenience: build a recipe from a flat dict and assemble in one call.
# parts_dict: { slot_name: PartDef, ... }
static func quick_assemble(body_plan: String, parts_dict: Dictionary) -> Node3D:
	var recipe := CharacterRecipe.new()
	recipe.body_plan = body_plan
	recipe.parts = parts_dict
	return assemble(recipe)
