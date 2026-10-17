extends AStarGrid2D
# Stable spatial noise changes preferences, never walkability. Cost spread is 18%.
var noise := FastNoiseLite.new()
var variation := 0
func set_variation(value: int) -> void:
	variation=value;noise.seed=value;noise.frequency=.19
func _compute_cost(from_id: Vector2i, to_id: Vector2i) -> float:
	var preference=0.0 if variation==0 else clampf((noise.get_noise_2d(to_id.x,to_id.y)+1.0)*.5,0,1)*.18
	return Vector2(from_id).distance_to(Vector2(to_id))*(1.0+preference)
