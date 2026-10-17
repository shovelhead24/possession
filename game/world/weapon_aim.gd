extends RefCounted
const Ring=preload("res://world/terrain_drive_ring.gd")
# Tuned for this demo's mixed arsenal, not claimed original CE tag values.
const RANGES=[85.0,140.0,45.0,40.0,45.0,100.0]
const ANGLES=[2.0,1.0,3.0,3.5,3.0,1.0]
var friction := .4
var adhesion := .35
var tracked: Node3D
var tracked_local := Vector3.ZERO
var tracked_direction := Vector3.ZERO
var strength := .35
var angle_degrees := 4.0
var settings_path := "user://Rebuild Demo/aim-assist.cfg"
func load_settings() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--aim-settings-file="): settings_path=arg.trim_prefix("--aim-settings-file=")
	var config=ConfigFile.new()
	if config.load(settings_path)==OK:
		var value=config.get_value("aim","strength",.35);var angle=config.get_value("aim","angle",4.0)
		if (value is float or value is int) and is_finite(float(value)): strength=clampf(value,0,1)
		if (angle is float or angle is int) and is_finite(float(angle)): angle_degrees=clampf(angle,1,10)
		friction=read_fraction(config,"friction",.4);adhesion=read_fraction(config,"adhesion",.35)
func read_fraction(config: ConfigFile, key: String, fallback: float) -> float:
	var value=config.get_value("aim",key,fallback)
	return clampf(value,0,1) if (value is float or value is int) and is_finite(float(value)) else fallback
func save_settings() -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(settings_path).get_base_dir())
	var config=ConfigFile.new();config.set_value("aim","strength",strength);config.set_value("aim","angle",angle_degrees)
	config.set_value("aim","friction",friction);config.set_value("aim","adhesion",adhesion)
	return config.save(settings_path)
func enemy(collider: Object, arena: Node) -> Node3D:
	var target=collider as Node
	while is_instance_valid(target) and target!=arena:
		if target is Node3D and target.has_method("take_hit") and target.get("health")!=null and float(target.health)>0 and target.get("dead")!=true: return target
		target=target.get_parent()
	return null
func cone(index: int) -> float: return ANGLES[index]*angle_degrees/4.0
func clamp_shape(point: Vector3, shape: Shape3D) -> Vector3:
	# A slight inset avoids tangent rays missing the collider through precision loss.
	if shape is BoxShape3D:
		var half=shape.size*.5-Vector3.ONE*.015
		return point.clamp(-half,half)
	if shape is SphereShape3D: return point.limit_length(maxf(.01,shape.radius-.015))
	if shape is CapsuleShape3D:
		var axis=Vector3(0,clampf(point.y,-shape.height*.5+shape.radius,shape.height*.5-shape.radius),0)
		return axis+(point-axis).limit_length(maxf(.01,shape.radius-.015))
	return Vector3.ZERO
func nearest_point(collision: CollisionShape3D, origin: Vector3, forward: Vector3, reach: float) -> Vector3:
	var inverse=collision.global_transform.affine_inverse();var start=inverse*origin;var direction=inverse.basis*forward
	var low=0.0;var high=reach
	# Distance to these convex shapes along a ray is convex; minimize in local space.
	for iteration in 22:
		var a=lerpf(low,high,1.0/3);var b=lerpf(low,high,2.0/3)
		var pa=start+direction*a;var pb=start+direction*b
		if pa.distance_squared_to(clamp_shape(pa,collision.shape))<pb.distance_squared_to(clamp_shape(pb,collision.shape)): high=b
		else: low=a
	return collision.global_transform*clamp_shape(start+direction*((low+high)*.5),collision.shape)
func solve(weapon: Node) -> Dictionary:
	var arena=weapon.arena;var origin: Vector3=arena.camera.global_position;var forward: Vector3=-arena.camera.global_basis.z
	var reach: float=weapon.REACH[weapon.selected];var direction=forward
	var hit=weapon.trace_segment(origin,origin+forward*reach)
	var direct=enemy(hit.get("collider"),arena);var chosen: Node3D;var point=origin+forward*reach;var chosen_angle=0.0
	if direct and origin.distance_to(hit.position)<=RANGES[weapon.selected]: chosen=direct;point=hit.position
	else:
		var candidates=[];var nodes=[]
		if arena.get("aliens"): nodes.append_array(arena.aliens.enemies)
		nodes.append_array(arena.get_tree().get_nodes_in_group("tyrants"))
		for node in nodes:
			if not is_instance_valid(node) or enemy(node,arena)!=node or not node.is_visible_in_tree() or node.has_meta("trex_held"): continue
			for child in node.get_children():
				if not child is CollisionShape3D or child.disabled or not child.shape: continue
				if not (child.shape is BoxShape3D or child.shape is SphereShape3D or child.shape is CapsuleShape3D): continue
				var nearest=nearest_point(child,origin,forward,minf(reach,RANGES[weapon.selected]))
				var offset=nearest-origin;var distance=offset.length()
				if distance<.2 or distance>minf(reach,RANGES[weapon.selected]): continue
				var angle=forward.angle_to(offset.normalized())
				if angle>deg_to_rad(cone(weapon.selected)): continue
				candidates.append({"node":node,"point":nearest,"angle":angle})
		candidates.sort_custom(func(a,b): return a.angle<b.angle)
		for candidate in candidates.slice(0,6):
			var sight=weapon.trace_segment(origin,candidate.point)
			if enemy(sight.get("collider"),arena)!=candidate.node: continue
			chosen=candidate.node;point=candidate.point;chosen_angle=candidate.angle;break
	var eligible=is_instance_valid(chosen)
	if eligible and chosen!=direct and strength>0: direction=forward.slerp((point-origin).normalized(),strength).normalized()
	return {"direction":direction,"point":point,"hit":hit,"on_enemy":eligible,"assisted":eligible and chosen!=direct and strength>0,"target":chosen,"angle":chosen_angle,"range":RANGES[weapon.selected]}
func reset_tracking() -> void:
	tracked=null;tracked_direction=Vector3.ZERO
func controller_filter(weapon: Node, move: Vector2, look: Vector2, delta: float) -> Dictionary:
	var result={"scale":1.0,"rotation":Vector2.ZERO}
	var state: Dictionary=weapon.aim_state;var target=state.get("target")
	if not state.get("on_enemy",false) or not is_instance_valid(target) or enemy(target,weapon.arena)==null:
		reset_tracking();return result
	var forward: Vector3=-weapon.arena.camera.global_basis.z
	var origin: Vector3=weapon.arena.camera.global_position
	if target!=tracked:
		tracked=target;tracked_local=target.to_local(state.point);tracked_direction=(target.to_global(tracked_local)-origin).normalized()
	var direction: Vector3=(tracked.to_global(tracked_local)-origin).normalized()
	var weight=1.0-smoothstep(0.0,deg_to_rad(cone(weapon.selected)),float(state.get("angle",0)))
	if look.length()>.001: result.scale=1.0-friction*weight
	# No camera adhesion with neutral sticks. Track angular motion, not centering error.
	if move.length()>.001 or look.length()>.001:
		var up=Ring.up_at(origin);var old_flat=tracked_direction.slide(up).normalized();var flat=direction.slide(up).normalized()
		var yaw_change=old_flat.signed_angle_to(flat,up)
		var pitch_change=asin(clampf(direction.dot(up),-1,1))-asin(clampf(tracked_direction.dot(up),-1,1))
		result.rotation=Vector2(yaw_change,pitch_change)*adhesion*weight
		result.rotation=result.rotation.limit_length(deg_to_rad(12)*delta)
	tracked_direction=direction
	return result
