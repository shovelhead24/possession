extends Node3D
class_name EnemySpawner

# Squads placed along the ring at fixed X positions between start and objective
const SQUAD_POSITIONS: Array = [400.0, 800.0, 1200.0, 1700.0, 2200.0]
const SQUAD_SIZE: int = 3
const SPREAD: float = 12.0  # Soldiers scatter within this radius of squad centre

const EnemySoldierScene = preload("res://enemy_soldier.tscn")

var _terrain_manager: Node = null

func _ready():
	_terrain_manager = get_node_or_null("/root/World/TerrainManager")
	call_deferred("_spawn_all")

func _spawn_all():
	# Wait two frames so terrain heights are settled
	await get_tree().process_frame
	await get_tree().process_frame

	for squad_x in SQUAD_POSITIONS:
		for i in range(SQUAD_SIZE):
			var angle = (i / float(SQUAD_SIZE)) * TAU
			var offset = Vector3(cos(angle) * SPREAD * randf_range(0.4, 1.0),
								 0.0,
								 sin(angle) * SPREAD * randf_range(0.4, 1.0))
			var pos = Vector3(squad_x + randf_range(-8.0, 8.0), 0.0, offset.z)
			pos.y = _get_height(pos)
			var soldier = EnemySoldierScene.instantiate()
			get_parent().add_child(soldier)
			soldier.global_position = pos

	print("EnemySpawner: spawned %d soldiers in %d squads" % [SQUAD_POSITIONS.size() * SQUAD_SIZE, SQUAD_POSITIONS.size()])

func _get_height(pos: Vector3) -> float:
	if _terrain_manager and _terrain_manager.has_method("get_height_at_position"):
		return _terrain_manager.get_height_at_position(pos) + 0.1
	return 55.0
