extends Node
var kit: Node
var previous_velocity := Vector3.ZERO
var cooldowns := {}

func overlaps_sweep(enemy: Node3D, movement: Vector3) -> bool:
	var vehicle=get_parent()
	var point=vehicle.to_local(enemy.global_position+Vector3.UP*.65)
	var relative=vehicle.global_basis.inverse()*movement
	# Sweep the hull across the victim's torso instead of relying on post-impact speed.
	for child in vehicle.get_children():
		if child is CollisionShape3D and not child.disabled:
			var bounds: AABB=child.transform*child.shape.get_debug_mesh().get_aabb()
			bounds=bounds.grow(.32)
			if bounds.has_point(point) or bounds.intersects_segment(point,point-relative)!=null: return true
	# Wheel envelopes extend outside the chassis; the actual suspension remains ray based.
	if vehicle.get("corners")!=null:
		for corner in vehicle.corners:
			var center: Vector3=corner.hub.position
			var wheel=AABB(center-Vector3(.22,corner.radius,corner.radius),Vector3(.44,corner.radius*2,corner.radius*2)).grow(.25)
			if wheel.has_point(point) or wheel.intersects_segment(point,point-relative)!=null: return true
	return false

func _physics_process(delta: float) -> void:
	if not kit or kit.menu.opened: return
	var manager=kit.arena.get_node_or_null("PracticeRange")
	if not manager: return
	var vehicle=get_parent();var movement: Vector3=vehicle.velocity
	var impact_velocity=movement if movement.length()>previous_velocity.length() else previous_velocity
	previous_velocity=movement
	impact_velocity.y=0
	if impact_velocity.length()<3: return
	for enemy in manager.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var id=enemy.get_instance_id();var now=Time.get_ticks_msec()
		if now<int(cooldowns.get(id,0)): continue
		if enemy.global_position.distance_to(vehicle.global_position)>8: continue
		var toward=enemy.global_position-vehicle.global_position;toward.y=0
		if impact_velocity.dot(toward)<-.5: continue
		var relative=impact_velocity-enemy.velocity;relative.y=0
		if relative.length()<3 or not overlaps_sweep(enemy,relative*delta): continue
		cooldowns[id]=now+750
		var speed=relative.length()
		enemy.velocity=impact_velocity*.65+Vector3.UP*minf(3,speed*.16)
		var damage=250.0 if speed>=5 else speed*speed*9
		enemy.take_hit(damage,enemy.global_position-impact_velocity.normalized()*2,enemy.global_position+Vector3.UP*.7)
