extends CharacterBody3D
var max_speed := 16.0
var reverse_speed := 7.0
var acceleration := 5.0
var brake_strength := 35.0
var turn_rate := 1.0
var turret_rate := 45.0
var reload_time := 2.5
var cannon_damage := 100.0
var turret: Node3D
var barrel: Node3D
var muzzle: Node3D
var kit: Node
var cooldown := 0.0
var cannon_audio: AudioStreamPlayer3D
var tracks: Node3D
var track_speeds := Vector2.ZERO
var traction := Vector2.ZERO
var contact_counts := Vector2i.ZERO
var ground_normal := Vector3.UP
var heading := 0.0
var suspension_rest_length := 1.65
var suspension_spring := 130.0
var suspension_damping := 18.0
var suspension_force := 0.0
var suspension_contacts := 0
var support_points: Array=[]
var patch_loads: Array=[]
var road_turn_rate_30kph := deg_to_rad(15.0)
var road_turn_speed := 30.0/3.6
var telemetry_clock := 0.0
var stall_clock := 0.0
var stuck_reported := false
var last_input := Vector2.ZERO

func probe_traction() -> void:
	contact_counts=Vector2i.ZERO;ground_normal=Vector3.UP;support_points=[];patch_loads=[]
	var space=get_world_3d().direct_space_state
	var side_points: Array=[[],[]];var front_points: Array=[];var rear_points: Array=[];var patch_contacts: Array=[]
	var middle=tracks.probe_z[tracks.probe_z.size()/2]
	for side in range(2):
		for index in range(tracks.probe_z.size()):
			var patch=tracks.probe_patch(index);var z=float(patch.center)
			# Five rays form a short, track-width contact patch. Select the
			# highest hit: a belt segment rides a ramp lip instead of threading
			# through the gap to a lower surface.
			var samples=[Vector2(0,z),Vector2(-.24,float(patch.from)),Vector2(.24,float(patch.from)),Vector2(-.24,float(patch.to)),Vector2(.24,float(patch.to))]
			var best: Dictionary={}
			for sample in samples:
			# Support is measured vertically in the world. Casting along the old hull
			# normal feeds a previous tilt back into the next frame on broken ground.
				var origin=to_global(Vector3((-tracks.half_width if side==0 else tracks.half_width)+sample.x,.8,sample.y))+Vector3.UP*.65
				var ray=PhysicsRayQueryParameters3D.create(origin,origin+Vector3.DOWN*2.4);ray.exclude=[get_rid(),kit.arena.walker.get_rid()];ray.collision_mask=1
				var hit=space.intersect_ray(ray)
				if not hit.is_empty() and not hit.collider is CharacterBody3D and hit.normal.dot(Vector3.UP)>.57 and (best.is_empty() or hit.position.y>best.point.y):
					best={"point":hit.position,"origin":origin}
			if not best.is_empty():
				contact_counts[side]+=1;side_points[side].append(best.point)
				support_points.append(best.point)
				patch_contacts.append({"side":side,"z":z,"origin":best.origin,"point":best.point})
				if z<middle: front_points.append(best.point)
				else: rear_points.append(best.point)
	# Four averaged support lines give a stable chassis plane. The physics hull
	# still blocks and climbs terrain; this only supplies its intended orientation.
	if not side_points[0].is_empty() and not side_points[1].is_empty() and not front_points.is_empty() and not rear_points.is_empty():
		var left=average_point(side_points[0]);var right=average_point(side_points[1])
		var front=average_point(front_points);var rear=average_point(rear_points)
		var normal=(rear-front).cross(right-left).normalized()
		if normal.dot(Vector3.UP)<0: normal=-normal
		if normal.dot(Vector3.UP)>.57: ground_normal=normal
	traction=Vector2(contact_counts)/float(tracks.probe_z.size())
	suspension_contacts=contact_counts.x+contact_counts.y
	patch_loads=distribute_patch_loads(patch_contacts,ground_normal)
	var spring_total=0.0
	for load in patch_loads:
		var compression=maxf(0,suspension_rest_length-load.origin.distance_to(load.point))
		spring_total+=maxf(0,compression*suspension_spring-velocity.y*suspension_damping)*load.weight
	# Do not divide by the number that happened to touch. With four contacts,
	# each needs more compression to carry the chassis than with sixteen.
	suspension_force=spring_total/float(tracks.probe_z.size()*2)

func distribute_patch_loads(contacts: Array, normal: Vector3) -> Array:
	if contacts.is_empty(): return []
	var forward=Vector3(-sin(heading),0,-cos(heading));var right=Vector3(cos(heading),0,-sin(heading))
	var downhill=Vector3.DOWN.slide(normal)
	var uphill=clampf(-downhill.dot(forward),-.8,.8)
	var side_slope=clampf(downhill.dot(right),-.8,.8)
	var z_min=tracks.probe_z[0];var z_max=tracks.probe_z[-1];var raw: Array=[];var total=0.0
	for contact in contacts:
		var along=remap(float(contact.z),z_min,z_max,-1,1)
		var side=-1.0 if int(contact.side)==0 else 1.0
		# Uphill adds rear load; downhill adds front load. Cross-slope load
		# transfers to the downhill side. Keep every valid patch contributing.
		var weight=maxf(.15,1.0+along*uphill*1.4+side*side_slope*.8)
		raw.append(weight);total+=weight
	var result: Array=[]
	for index in range(contacts.size()):
		var loaded=contacts[index].duplicate();loaded.weight=raw[index]*contacts.size()/total;result.append(loaded)
	return result

func average_point(points: Array) -> Vector3:
	var total=Vector3.ZERO
	for point in points: total+=point
	return total/points.size()

func drive_step(delta: float, throttle: float, turn: float, braking: bool) -> void:
	last_input=Vector2(throttle,turn)
	probe_traction()
	var hull_forward=Vector3(-sin(heading),0,-cos(heading))
	var speed=absf(Vector3(velocity.x,0,velocity.z).dot(hull_forward))
	var rate=road_turn_limit(speed)
	var difference=rate*tracks.half_width*2.0*absf(turn)
	var desired=Vector2.ZERO
	if absf(throttle)<.01:
		# A/D alone is the full opposing-track pivot.
		desired=Vector2(-turn*reverse_speed,turn*reverse_speed)
	elif throttle>0:
		# Under W, slow only the inside track; the outside remains at drive speed.
		desired=Vector2(max_speed,max_speed)
		if turn>0: desired.x=maxf(0,desired.x-difference)
		elif turn<0: desired.y=maxf(0,desired.y-difference)
	else:
		desired=Vector2(-reverse_speed,-reverse_speed)
		if turn>0: desired.y=minf(0,desired.y+difference)
		elif turn<0: desired.x=minf(0,desired.x+difference)
	# Combined steering is tank-relative. At 30 km/h the differential gives
	# 15 degrees/s; at rest A/D remains a full pivot.
	var stopping=braking or (absf(throttle)<.01 and absf(turn)<.01)
	track_speeds=Vector2.ZERO if stopping else desired
	var support=(traction.x+traction.y)*.5
	var effective=track_speeds*traction
	var forward_speed=(effective.x+effective.y)*.5
	var yaw_speed=clampf((effective.y-effective.x)/(tracks.half_width*2),-turn_rate,turn_rate)
	if support>.01:
		heading+=yaw_speed*delta
		var forward=Vector3(-sin(heading),0,-cos(heading)).slide(ground_normal).normalized()
		var right=forward.cross(ground_normal).normalized();var wanted=Basis(right,ground_normal,-forward)
		global_basis=global_basis.orthonormalized().slerp(wanted,1-exp(-5*delta)).orthonormalized()
		# Locomotion lives in the hull's frame, never in the camera's frame. A
		# tracked vehicle has very high lateral grip: collision impulses may nudge
		# it, but cannot turn A/D into an accidental side-slide.
		hull_forward=Vector3(-sin(heading),0,-cos(heading))
		var hull_right=Vector3(cos(heading),0,-sin(heading))
		var planar=Vector3(velocity.x,0,velocity.z)
		var current_forward=planar.dot(hull_forward);var current_lateral=planar.dot(hull_right)
		var skid=clampf((absf(current_forward)-max_speed*.55)/(max_speed*.45),0,1)
		var forward_grip=lerpf(24,7,skid)*support*delta
		var lateral_grip=lerpf(60,5,skid)*support*delta
		var settled_forward=0.0 if stopping else move_toward(current_forward,forward_speed,forward_grip)
		var settled_lateral=0.0 if stopping else move_toward(current_lateral,0,lateral_grip)
		planar=hull_forward*settled_forward+hull_right*settled_lateral
		velocity.x=planar.x;velocity.z=planar.z
	if stopping: velocity.x=0;velocity.z=0
	# The box hull is the hard, physical resting constraint. Springs catch the
	# falling chassis but never keep a floor-supported hull hovering above it.
	var lift=0.0 if is_on_floor() else suspension_force
	velocity.y+=(lift-22.0)*delta;move_and_slide()
	record_telemetry(delta,throttle,turn,braking)
	tracks.animate(delta,track_speeds.x,track_speeds.y)
	if position.y< -35: position=Vector3(-29,1,9);velocity=Vector3.ZERO;track_speeds=Vector2.ZERO

func road_turn_limit(speed: float) -> float:
	if speed<=road_turn_speed:
		return lerpf(turn_rate,road_turn_rate_30kph,speed/road_turn_speed)
	return road_turn_rate_30kph*road_turn_speed/speed

func record_telemetry(delta: float, throttle: float, turn: float, braking: bool) -> void:
	telemetry_clock-=delta
	var planar=Vector2(velocity.x,velocity.z).length()
	var commanded=not braking and (absf(throttle)>.01 or absf(turn)>.01)
	if commanded and traction.length()>.15 and planar<.35: stall_clock+=delta
	else: stall_clock=0;stuck_reported=false
	if stall_clock>1.0 and not stuck_reported:
		stuck_reported=true;append_telemetry("STUCK")
		if kit and kit.get("status"): kit.status.text="ALTAY STUCK / telemetry saved / F2 setup"
	if telemetry_clock<=0:
		telemetry_clock=.5;append_telemetry("STATE")

func append_telemetry(tag: String) -> void:
	var file=FileAccess.open("user://tank-diagnostics.log",FileAccess.READ_WRITE)
	if not file: return
	file.seek_end()
	file.store_line("%s pos=%s vel=%s input=%s tracks=%s contacts=%s force=%.2f floor=%s slides=%d normal=%s supports=%s" % [tag,global_position,velocity,last_input,track_speeds,contact_counts,suspension_force,is_on_floor(),get_slide_collision_count(),ground_normal,support_points])

func setup(model: Node3D, owner_kit: Node) -> void:
	kit=owner_kit
	preload("res://tank_finish.gd").apply(model)
	turret=Node3D.new();turret.name="TurretYaw";add_child(turret);turret.position=Vector3(0,1.5,1.1)
	barrel=Node3D.new();turret.add_child(barrel);barrel.position=Vector3(0,.247,-2)
	muzzle=Node3D.new();barrel.add_child(muzzle);muzzle.position=Vector3(0,0,-3.6)
	var meshes=[];var stack=[model]
	while not stack.is_empty():
		var node=stack.pop_back()
		if node is MeshInstance3D: meshes.append(node)
		for child in node.get_children(): stack.append(child)
	var count=0
	for node in meshes:
		var box: AABB=global_transform.affine_inverse()*node.global_transform*node.mesh.get_aabb()
		var label=String(node.name)
		if label.begins_with("gun_1_") or label.begins_with("gun_2_") or label.begins_with("gun_support_"):
			node.reparent(barrel,true);count+=1
		elif box.get_center().y>1.65 and box.get_center().z<3.4 and absf(box.get_center().x)<1.5:
			node.reparent(turret,true);count+=1
	cannon_audio=AudioStreamPlayer3D.new();cannon_audio.stream=preload("res://mechanical_audio.gd").make_sound(true);cannon_audio.volume_db=-12;cannon_audio.unit_size=12;add_child(cannon_audio)
	print("TANK_RIG_READY: ",count," turret/barrel meshes")
	tracks=preload("res://tank_tracks.gd").new();add_child(tracks);tracks.setup(model,self);heading=rotation.y

func _process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	if not kit or kit.driving!=self or kit.menu.opened: return
	turret.rotation.y=rotate_toward(turret.rotation.y,kit.driver_look.x,deg_to_rad(turret_rate)*delta)
	barrel.rotation.x=move_toward(barrel.rotation.x,clampf(kit.driver_look.y,deg_to_rad(-8),deg_to_rad(22)),deg_to_rad(turret_rate*.6)*delta)

func fire_cannon() -> bool:
	if cooldown>0 or kit.menu.opened: return false
	cooldown=reload_time;cannon_audio.play()
	# Start at the breech so a barrel poking through a wall cannot shoot through it.
	var start=barrel.global_position
	var end=muzzle.global_position-muzzle.global_basis.z*450
	var ray=PhysicsRayQueryParameters3D.create(start,end);ray.exclude=[get_rid(),kit.arena.walker.get_rid()]
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	var point: Vector3=hit.position if not hit.is_empty() else end
	kit.arena.get_node("PracticeRange").tracer(start,point)
	if not hit.is_empty():
		var impact=AudioStreamPlayer3D.new();impact.stream=cannon_audio.stream;impact.pitch_scale=.7;impact.volume_db=-8;impact.unit_size=20;impact.max_distance=300;kit.arena.add_child(impact);impact.global_position=point;impact.finished.connect(impact.queue_free);impact.play()
		if hit.collider.has_method("take_hit"): hit.collider.take_hit(cannon_damage,start,point)
		elif hit.collider.has_meta("target_hits"): hit.collider.set_meta("target_hits",int(hit.collider.get_meta("target_hits"))+1)
		var blast=kit.arena.box(point,Vector3.ONE*.7,kit.arena.material(Color(1,.5,.1),0,.5,true))
		var tween=create_tween();tween.tween_property(blast,"scale",Vector3.ONE*2,.12);tween.tween_property(blast,"scale",Vector3.ONE*.01,.22);tween.tween_callback(blast.queue_free)
	kit.status.text="ALTAY / CANNON FIRED / %.1f s reload" % reload_time
	return true
