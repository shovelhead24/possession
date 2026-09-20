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

func probe_traction() -> void:
	contact_counts=Vector2i.ZERO;ground_normal=Vector3.UP
	var space=get_world_3d().direct_space_state
	var side_points: Array=[[],[]];var front_points: Array=[];var rear_points: Array=[]
	var middle=tracks.probe_z[tracks.probe_z.size()/2]
	for side in range(2):
		for z in tracks.probe_z:
			# Support is measured vertically in the world. Casting along the old hull
			# normal feeds a previous tilt back into the next frame on broken ground.
			var origin=to_global(Vector3(-tracks.half_width if side==0 else tracks.half_width,.8,z))+Vector3.UP*.65
			var ray=PhysicsRayQueryParameters3D.create(origin,origin+Vector3.DOWN*2.4);ray.exclude=[get_rid(),kit.arena.walker.get_rid()];ray.collision_mask=1
			var hit=space.intersect_ray(ray)
			if not hit.is_empty() and not hit.collider is CharacterBody3D and hit.normal.dot(Vector3.UP)>.57:
				contact_counts[side]+=1;side_points[side].append(hit.position)
				if z<middle: front_points.append(hit.position)
				else: rear_points.append(hit.position)
	traction=Vector2(contact_counts)/float(tracks.probe_z.size())
	# Four averaged support lines give a stable chassis plane. The physics hull
	# still blocks and climbs terrain; this only supplies its intended orientation.
	if not side_points[0].is_empty() and not side_points[1].is_empty() and not front_points.is_empty() and not rear_points.is_empty():
		var left=average_point(side_points[0]);var right=average_point(side_points[1])
		var front=average_point(front_points);var rear=average_point(rear_points)
		var normal=(rear-front).cross(right-left).normalized()
		if normal.dot(Vector3.UP)<0: normal=-normal
		if normal.dot(Vector3.UP)>.57: ground_normal=normal

func average_point(points: Array) -> Vector3:
	var total=Vector3.ZERO
	for point in points: total+=point
	return total/points.size()

func drive_step(delta: float, throttle: float, steer: float, braking: bool) -> void:
	probe_traction()
	var target=throttle*(max_speed if throttle>=0 else reverse_speed)
	var turn_speed=steer*turn_rate*tracks.half_width
	var desired=Vector2(target-turn_speed,target+turn_speed) if not braking else Vector2.ZERO
	for i in range(2): track_speeds[i]=move_toward(track_speeds[i],desired[i],delta*(brake_strength if braking else acceleration))
	var support=(traction.x+traction.y)*.5
	var effective=track_speeds*traction
	var forward_speed=(effective.x+effective.y)*.5
	var yaw_speed=(effective.y-effective.x)/(tracks.half_width*2)
	if support>.01:
		heading+=yaw_speed*delta
		var forward=Vector3(-sin(heading),0,-cos(heading)).slide(ground_normal).normalized()
		var right=forward.cross(ground_normal).normalized();var wanted=Basis(right,ground_normal,-forward)
		global_basis=global_basis.orthonormalized().slerp(wanted,1-exp(-5*delta)).orthonormalized()
		# Locomotion lives in the hull's frame, never in the camera's frame. A
		# tracked vehicle has very high lateral grip: collision impulses may nudge
		# it, but cannot turn A/D into an accidental side-slide.
		var hull_forward=Vector3(-sin(heading),0,-cos(heading))
		var hull_right=Vector3(cos(heading),0,-sin(heading))
		var response=(brake_strength if braking else acceleration)*support*delta
		var planar=Vector3(velocity.x,0,velocity.z)
		var current_forward=planar.dot(hull_forward);var current_lateral=planar.dot(hull_right)
		var settled_forward=move_toward(current_forward,forward_speed,response)
		var settled_lateral=move_toward(current_lateral,0,delta*(brake_strength if braking else acceleration*5.0)*support)
		planar=hull_forward*settled_forward+hull_right*settled_lateral
		velocity.x=planar.x;velocity.z=planar.z
	velocity.y-=22*delta;move_and_slide()
	tracks.animate(delta,track_speeds.x,track_speeds.y)
	if position.y< -35: position=Vector3(-29,1,9);velocity=Vector3.ZERO;track_speeds=Vector2.ZERO

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
