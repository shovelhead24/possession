class_name CharacterRecipe
extends Resource

@export var label: String = ""
@export var body_plan: String = "biped"
# slot_name -> PartDef
@export var parts: Dictionary = {}
# slot_name -> Material (optional overrides)
@export var material_overrides: Dictionary = {}
