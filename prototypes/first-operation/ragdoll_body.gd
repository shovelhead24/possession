extends PhysicalBone3D
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Bound solver spikes without accumulating a new force on every frame.
	state.linear_velocity=state.linear_velocity.limit_length(18)
	state.angular_velocity=state.angular_velocity.limit_length(12)
