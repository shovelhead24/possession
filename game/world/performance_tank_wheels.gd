extends Node3D
## The supplied asset has smooth continuous belts; animate its visible road wheels.
var half_width := 1.235
var wheels: Array=[]
func animate(delta: float, left_speed: float, right_speed: float) -> void:
	for wheel in wheels:
		wheel.pivot.rotate_x(-(left_speed if wheel.side<0 else right_speed)*delta/wheel.radius)
