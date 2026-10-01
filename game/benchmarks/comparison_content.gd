extends "res://benchmarks/mesh_snapshot/world/arena_content.gd"
## Same original model positions, including the recovered tank; posed for A/B.
func source_specs() -> Array:
	var specs := super.source_specs()
	specs.append(["Altay","res://altay_main_battle_tank_fbx.glb",Vector2(-47,-34),9.0,false])
	return specs
