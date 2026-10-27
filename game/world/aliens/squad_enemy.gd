extends CharacterBody3D
const Ring=preload("res://world/terrain_drive_ring.gd")
var impact_ready_at := 0
var motion_usec := 0
var path_usec := 0
var sense_usec := 0
var capsule_changes := 0
var physics_usec := 0
var physics_ticks := 0
var capsule_height := -1.0
var capsule_prone := false
var elite := false
var dead := false
var health := 50.0
var manager: Node
var arena: Node
var squad: Node
var lizard: Node3D
var shape: CollisionShape3D
var label: Label3D
var audio: AudioStreamPlayer3D
var routed := false
var crouch_order := false
var crouched := false
var destination := Vector3.ZERO
func origin_shifted(delta: Vector3):
	destination-=delta;last_position-=delta
	for i in path.size():path[i]-=delta
var pace := 1.25
var gait := "Walk"
var tactical_role := ""
var tactical_partner: Node
var route_variation := 0
var path: Array[Vector3]=[]
var repath := 0.0
var cooldown := 1.0
var charge := 0.0
var aim := Vector3.ZERO
var dive_time := 0.0
var dive_direction := Vector3.ZERO
var dive_launched := false
var dive_cooldown := 0.0
var jump_cooldown := 0.0
var idle_time := 0.0
var idle_clip := "Idle"
var idle_partner: Node3D
var distance_moved := 0.0
var last_position := Vector3.ZERO
var combat_target: Node3D
var trex_toss_velocity := Vector3.ZERO
var trex_toss_time := 0.0
var sight_timer := 0.0
var cached_visible := false
var cached_target: Node3D
func toss_from_trex(impulse: Vector3,source: PhysicsBody3D) -> void:
	trex_toss_velocity=impulse;trex_toss_time=.8;velocity=impulse
	if dead:
		lizard.die(impulse,Vector3.ZERO)
		if lizard.ragdoll:
			for bone in lizard.ragdoll.get_children():
				if bone is PhysicsBody3D: bone.add_collision_exception_with(source)
	else: lizard.toss(Vector3.ZERO,impulse,source)
func finish_trex_hold() -> void:
	if dead: lizard.die()
func _ready() -> void:
	# Squadmates are not moving platforms. Overlap recovery must never become
	# inherited upward launch velocity when several bodies meet on a slope.
	platform_floor_layers=0;platform_wall_layers=0
	collision_layer=2;collision_mask=7;up_direction=Ring.up_at(global_position)
	health=175 if elite else 50;floor_snap_length=.6;floor_max_angle=deg_to_rad(48)
	shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.4 if elite else .28;capsule.height=1.95 if elite else 1.3;shape.shape=capsule;shape.position.y=capsule.height*.5;add_child(shape)
	lizard=preload("res://world/aliens/lizard_actor.gd").new();lizard.elite=elite;lizard.scale=Vector3.ONE*(1.5 if elite else 1.0);add_child(lizard)
	label=Label3D.new();label.text="ELITE / CAPTAIN" if elite else "GRUNT";label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=22;label.pixel_size=.003;label.position.y=capsule.height+.3;label.visibility_range_end=45;add_child(label)
	audio=AudioStreamPlayer3D.new();audio.stream=manager.gun_sound;audio.volume_db=-19;audio.unit_size=8;add_child(audio)
	route_variation=1+int(get_meta("actor_id",1))*17+int(get_meta("slot",0))*101
	destination=position;last_position=position;repath=randf();cooldown=randf_range(.5,2)
func order(point: Vector3,speed: float,animation: String) -> void:
	var ground=manager.ground(point)
	if ground.is_empty(): return
	point=ground.position
	if destination.distance_to(point)>3: repath=0
	destination=point;pace=speed;gait=animation
func take_hit(damage: float,source: Vector3,_point: Vector3) -> String:
	if dead: return "DOWN"
	squad.report_contact(source);manager.active=true;health-=damage
	if health<=0:
		dead=true;collision_layer=0;collision_mask=0;label.hide()
		if not has_meta("trex_held"): lizard.die(velocity,(global_position-source).normalized()*3)
		manager.register_corpse(self)
		if elite: squad.issue_orders()
		return "CAPTAIN DOWN / GRUNTS ROUTED" if elite else "GRUNT DOWN"
	return "%s / %d HP" % ["ELITE" if elite else "GRUNT",int(health)]
func sees_player() -> bool:
	var began=Time.get_ticks_usec()
	var result=check_sight()
	sense_usec+=Time.get_ticks_usec()-began
	return result
func check_sight() -> bool:
	if squad.authored_mode==2: combat_target=null;cached_visible=false;return false
	combat_target=manager.enemy_target(self)
	if not is_instance_valid(combat_target): cached_visible=false;return false
	if combat_target==cached_target and sight_timer>0: return cached_visible
	cached_target=combat_target;sight_timer=.25
	var range=50.0 if elite else 42.0;var fov=70.0 if elite else 58.0
	var target=combat_target.global_position+up_direction*1.0
	var planar=(target-global_position).slide(up_direction)
	if planar.length()>range: cached_visible=false;return false
	if planar.length()>.01 and (-global_basis.z).dot(planar.normalized())<cos(deg_to_rad(fov*.5)): cached_visible=false;return false
	var origin=global_position+up_direction*(1.7 if elite else 1.05)
	var ray=PhysicsRayQueryParameters3D.create(origin,target,7);ray.exclude=friendly_rids()
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	cached_visible=not hit.is_empty() and (hit.collider==combat_target or manager.is_target(hit.collider))
	return cached_visible
func friendly_rids() -> Array[RID]:
	var ids: Array[RID]=[]
	for member in squad.members: ids.append(member.get_rid())
	return ids
func begin_dive(threat: Vector3) -> bool:
	if not elite or dive_cooldown>0 or dead: return false
	var away=(global_position-threat).slide(up_direction)
	if away.length()<.1: away=global_basis.x
	var best=Vector3.ZERO;var score=-INF
	for angle in [0.0,.7,-.7,1.4,-1.4]:
		var direction=away.normalized().rotated(up_direction,angle)
		var ray=PhysicsRayQueryParameters3D.create(global_position+up_direction*.7,global_position+direction*5+up_direction*.7);ray.exclude=friendly_rids()
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		var safety=(global_position+direction*5).distance_to(threat)
		if safety>score: best=direction;score=safety
	if best==Vector3.ZERO: return false
	dive_direction=best;dive_time=2.0;dive_launched=false;dive_cooldown=2.7;charge=0;face(best,1.0);lizard.play("Dive");return true
func _physics_process(delta: float) -> void:
	var began=Time.get_ticks_usec()
	step_actor(delta)
	physics_usec+=Time.get_ticks_usec()-began;physics_ticks+=1
func step_actor(delta: float) -> void:
	if dead or manager.paused(): return
	up_direction=Ring.up_at(global_position)
	if not manager.resident(global_position): velocity=Vector3.ZERO;lizard.play("Idle");return
	sight_timer=maxf(0.0,sight_timer-delta)
	if trex_toss_time>0:
		trex_toss_time-=delta;velocity=trex_toss_velocity.slide(up_direction)+up_direction*velocity.dot(up_direction);trex_toss_velocity=trex_toss_velocity.move_toward(Vector3.ZERO,delta*8)
		if not is_on_floor(): velocity-=up_direction*20*delta
		move_body();return
	cooldown-=delta;dive_cooldown-=delta;jump_cooldown-=delta;repath-=delta;idle_time-=delta
	if elite and dive_cooldown<=0:
		for grenade in get_tree().get_nodes_in_group("dive_grenades"):
			var throw_velocity: Vector3=grenade.linear_velocity if grenade is RigidBody3D else grenade.velocity
			if global_position.distance_to(grenade.global_position+throw_velocity*.25)<11:
				var ray=PhysicsRayQueryParameters3D.create(global_position+up_direction,grenade.global_position);ray.exclude=friendly_rids()
				var hit=get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or hit.collider==grenade: begin_dive(grenade.global_position);break
	var movement=Vector3.ZERO
	if dive_time>0:
		dive_time-=delta
		if not dive_launched and dive_time<=1.85: velocity=velocity.slide(up_direction)+up_direction*4.3;dive_launched=true
		movement=dive_direction*(7.5 if dive_time>1.35 else (2.5 if dive_time>.3 else .5)) if dive_launched else Vector3.ZERO
		if dive_launched and dive_time>.35:
			set_capsule(1.95,true)
		else:
			set_capsule(1.95,false)
		lizard.play("Dive")
	else:
		if shape.rotation.x!=0:
			var ground=manager.ground(global_position)
			if not ground.is_empty() and (global_position-ground.position).dot(up_direction)<.03: global_position=ground.position+up_direction*.03
		if repath<=0:
			repath=1.3
			var path_began=Time.get_ticks_usec();path=manager.navigation.path(global_position,destination,route_variation);path_usec+=Time.get_ticks_usec()-path_began
		while not path.is_empty() and (path[0]-global_position).slide(up_direction).length()<1.25: path.pop_front()
		var target=path[0] if not path.is_empty() else global_position
		var difference=(target-global_position).slide(up_direction)
		if global_position.distance_to(destination)>1.4 and pace>0: movement=difference.normalized()*pace
		# Short collision feelers handle tree trunks and other cover between grid cells.
		if movement.length()>.1:
			var ray=PhysicsRayQueryParameters3D.create(position+up_direction*.6,position+up_direction*.6+movement.normalized()*1.5);ray.exclude=friendly_rids()
			var obstacle=get_world_3d().direct_space_state.intersect_ray(ray)
			if not obstacle.is_empty():
				var high=PhysicsRayQueryParameters3D.create(position+up_direction*1.4,position+up_direction*1.4+movement.normalized()*1.5);high.exclude=friendly_rids()
				if is_on_floor() and jump_cooldown<=0 and get_world_3d().direct_space_state.intersect_ray(high).is_empty(): velocity=velocity.slide(up_direction)+up_direction*5;jump_cooldown=2
				else: movement=movement.slide(obstacle.normal).normalized()*pace
		for other in squad.members:
			if other==self or other.dead: continue
			var apart=(global_position-other.global_position).slide(up_direction)
			if apart.length()<1.2 and apart.length()>.01: movement+=apart.normalized()*(1.2-apart.length())*2
		crouched=crouch_order and movement.length()<.2 and fmod(squad.clock,4.0)>1.3
		set_capsule((1.5 if elite else 1.0) if crouched else (1.95 if elite else 1.3),false)
		var facing=(movement if routed or squad.mode==squad.Mode.PATROL else squad.last_known-global_position).slide(up_direction)
		if facing.length()>.1: face(facing,minf(1,delta*9))
		var clip=gait
		if routed: clip="Flee"
		elif not is_on_floor() and absf(velocity.dot(up_direction))>1: clip="Jump"
		elif crouched: clip="Crouch"
		elif movement.length()>.2:
			if squad.mode!=squad.Mode.PATROL and absf(movement.normalized().dot(global_basis.x))>.65: clip="Strafe"
		else:
			if idle_time<=0:
				idle_time=3.5;idle_partner=null;idle_clip=["Idle","Check","Scratch","Look"][randi()%4]
				for other in squad.members:
					if other!=self and not other.dead and position.distance_to(other.position)<3.5 and other.velocity.length()<.3:
						idle_clip="Talk";idle_partner=other;other.idle_clip="Talk";other.idle_partner=self;other.idle_time=3.5;break
			clip=idle_clip if squad.mode==squad.Mode.PATROL else "Idle"
			if clip=="Talk" and is_instance_valid(idle_partner):
				var partner_direction=idle_partner.global_position-global_position
				face(partner_direction,minf(1,delta*5))
		lizard.set_fleeing(routed);lizard.animate_state(clip,delta)
	velocity=movement.slide(up_direction)+up_direction*velocity.dot(up_direction)
	if not is_on_floor(): velocity-=up_direction*20*delta
	move_body()
	if dive_time<=0 and not routed and not crouched and squad.mode==squad.Mode.COMBAT: attack(delta)
	else: charge=0
func face(direction: Vector3, weight: float) -> void:
	var flat=direction.slide(up_direction)
	if flat.length_squared()<.001: return
	var desired=Basis.looking_at(flat.normalized(),up_direction)
	global_basis=global_basis.orthonormalized().slerp(desired,weight).orthonormalized()
func attack(delta: float) -> void:
	if charge>0:
		charge-=delta
		if charge<=0:
			var start=lizard.muzzle_position()
			var ray=PhysicsRayQueryParameters3D.create(global_position+up_direction*.8,start,7);ray.exclude=friendly_rids()
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): cooldown=.4;return
			if manager.fire_bolt(self,start,aim-start,12 if elite else 8,Color(1,.07,.035) if elite else Color(.12,1,.65)):
				lizard.fire();audio.play();cooldown=.4 if elite else 1.9
	elif cooldown<=0 and sees_player(): aim=combat_target.global_position+Ring.up_at(combat_target.global_position)*1.0;charge=.2 if elite else .65

func set_capsule(height: float, prone: bool) -> void:
	if capsule_height==height and capsule_prone==prone: return
	capsule_changes+=1
	capsule_height=height;capsule_prone=prone
	shape.shape.height=height
	shape.rotation=Vector3(PI/2,0,0) if prone else Vector3.ZERO
	shape.position=Vector3(0,.5,-.7) if prone else Vector3(0,height*.5,0)

func move_body() -> void:
	var began=Time.get_ticks_usec()
	move_and_slide()
	motion_usec+=Time.get_ticks_usec()-began

func vehicle_impact(source: RigidBody3D, point: Vector3, relative: Vector3, normal: Vector3) -> void:
	if dead or manager.paused() or has_meta("trex_held"): return
	var now=Time.get_ticks_msec()
	if now<impact_ready_at: return
	# Normal points out of the vehicle; approach speed excludes grazing motion.
	var closing=maxf(0.0,-relative.dot(normal.normalized()))
	var threshold=float(source.get("impact_min_speed"))
	if closing<=threshold: return
	impact_ready_at=now+700
	var up=Ring.up_at(global_position)
	var kick=(relative.slide(up)*float(source.get("impact_forward"))).limit_length(48.0)+up*clampf(2.0+closing*.35,4.5,8.0)*float(source.get("impact_lift"))
	velocity=kick
	take_hit((closing-threshold)*float(source.get("impact_damage")),source.global_position,point)
	# Gunshot ragdolls use a lower generic cap. A vehicle punt keeps its bounded
	# horizontal/upward launch separately so high-speed hits do not flatten it.
	if dead and is_instance_valid(lizard.ragdoll):
		for bone in lizard.ragdoll.get_children():
			if bone is PhysicalBone3D: bone.linear_velocity=kick
	if not dead:
		trex_toss_velocity=kick;trex_toss_time=.55
