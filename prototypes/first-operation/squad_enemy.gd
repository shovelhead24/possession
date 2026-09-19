extends CharacterBody3D
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
var pace := 1.25
var gait := "Walk"
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
func _ready() -> void:
	health=175 if elite else 50;floor_snap_length=.6;floor_max_angle=deg_to_rad(48)
	shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.4 if elite else .28;capsule.height=1.95 if elite else 1.3;shape.shape=capsule;shape.position.y=capsule.height*.5;add_child(shape)
	lizard=preload("res://lizard_actor.gd").new();lizard.elite=elite;lizard.scale=Vector3.ONE*(1.5 if elite else 1.0);add_child(lizard)
	label=Label3D.new();label.text="ELITE / CAPTAIN" if elite else "GRUNT";label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=22;label.pixel_size=.003;label.position.y=capsule.height+.3;label.visibility_range_end=45;add_child(label)
	audio=AudioStreamPlayer3D.new();audio.stream=arena.kit.gun_sounds.Carbine;audio.volume_db=-19;audio.unit_size=8;add_child(audio)
	destination=position;last_position=position;repath=randf();cooldown=randf_range(.5,2)
func order(point: Vector3,speed: float,animation: String) -> void:
	point.x=clampf(point.x,-245,245);point.z=clampf(point.z,-545,30);point.y=arena.height_at(point.x,point.z)
	if destination.distance_to(point)>3: repath=0
	destination=point;pace=speed;gait=animation
func take_hit(damage: float,source: Vector3,_point: Vector3) -> String:
	if dead: return "DOWN"
	squad.report_contact(source);manager.active=true;health-=damage
	if health<=0:
		dead=true;collision_layer=0;collision_mask=0;label.hide();lizard.die(velocity,(global_position-source).normalized()*3)
		if elite: squad.issue_orders()
		return "CAPTAIN DOWN / GRUNTS ROUTED" if elite else "GRUNT DOWN"
	return "%s / %d HP" % ["ELITE" if elite else "GRUNT",int(health)]
func sees_player() -> bool:
	var target=arena.walker.global_position+Vector3.UP
	if global_position.distance_to(target)>85: return false
	var origin=global_position+Vector3.UP*(1.7 if elite else 1.05)
	var ray=PhysicsRayQueryParameters3D.create(origin,target);ray.exclude=friendly_rids()
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and (hit.collider==arena.walker or hit.collider==arena.kit.driving)
func friendly_rids() -> Array[RID]:
	var ids: Array[RID]=[]
	for member in squad.members: ids.append(member.get_rid())
	return ids
func begin_dive(threat: Vector3) -> bool:
	if not elite or dive_cooldown>0 or dead: return false
	var away=global_position-threat;away.y=0
	if away.length()<.1: away=global_basis.x
	var best=Vector3.ZERO;var score=-INF
	for angle in [0.0,.7,-.7,1.4,-1.4]:
		var direction=away.normalized().rotated(Vector3.UP,angle)
		var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.7,global_position+direction*5+Vector3.UP*.7);ray.exclude=friendly_rids()
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		var safety=(global_position+direction*5).distance_to(threat)
		if safety>score: best=direction;score=safety
	if best==Vector3.ZERO: return false
	dive_direction=best;dive_time=2.0;dive_launched=false;dive_cooldown=2.7;charge=0;rotation.y=atan2(-best.x,-best.z);lizard.play("Dive");return true
func _physics_process(delta: float) -> void:
	if dead or arena.kit.menu.opened: return
	cooldown-=delta;dive_cooldown-=delta;jump_cooldown-=delta;repath-=delta;idle_time-=delta
	if elite and dive_cooldown<=0:
		for grenade in get_tree().get_nodes_in_group("frag_grenades"):
			if global_position.distance_to(grenade.global_position+grenade.linear_velocity*.25)<11:
				var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,grenade.global_position);ray.exclude=friendly_rids()
				var hit=get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or hit.collider==grenade: begin_dive(grenade.global_position);break
	var movement=Vector3.ZERO
	if dive_time>0:
		dive_time-=delta
		if not dive_launched and dive_time<=1.85: velocity.y=4.3;dive_launched=true
		movement=dive_direction*(7.5 if dive_time>1.35 else (2.5 if dive_time>.3 else .5)) if dive_launched else Vector3.ZERO
		if dive_launched and dive_time>.35:
			shape.rotation.x=PI/2;shape.shape.height=1.95;shape.position=Vector3(0,.5,-.7)
		else:
			shape.rotation=Vector3.ZERO;shape.position=Vector3(0,.975,0);shape.shape.height=1.95
		lizard.play("Dive")
	else:
		if shape.rotation.x!=0: position.y=maxf(position.y,arena.height_at(position.x,position.z)+.03)
		shape.rotation=Vector3.ZERO;shape.position.z=0
		if repath<=0:
			repath=1.3;path=manager.navigation.path(global_position,destination)
		while not path.is_empty() and Vector2(path[0].x-position.x,path[0].z-position.z).length()<1.25: path.pop_front()
		var target=path[0] if not path.is_empty() else destination
		var difference=target-global_position;difference.y=0
		if global_position.distance_to(destination)>1.4 and pace>0: movement=difference.normalized()*pace
		# Short collision feelers handle tree trunks and other cover between grid cells.
		if movement.length()>.1:
			var ray=PhysicsRayQueryParameters3D.create(position+Vector3.UP*.6,position+Vector3.UP*.6+movement.normalized()*1.5);ray.exclude=friendly_rids()
			var obstacle=get_world_3d().direct_space_state.intersect_ray(ray)
			if not obstacle.is_empty():
				var high=PhysicsRayQueryParameters3D.create(position+Vector3.UP*1.4,position+Vector3.UP*1.4+movement.normalized()*1.5);high.exclude=friendly_rids()
				if is_on_floor() and jump_cooldown<=0 and get_world_3d().direct_space_state.intersect_ray(high).is_empty(): velocity.y=5;jump_cooldown=2
				else: movement=movement.slide(obstacle.normal).normalized()*pace
		for other in squad.members:
			if other==self or other.dead: continue
			var apart=global_position-other.global_position;apart.y=0
			if apart.length()<1.2 and apart.length()>.01: movement+=apart.normalized()*(1.2-apart.length())*2
		crouched=crouch_order and movement.length()<.2 and fmod(squad.clock,4.0)>1.3
		shape.shape.height=(1.5 if elite else 1.0) if crouched else (1.95 if elite else 1.3);shape.position.y=shape.shape.height*.5
		var facing=movement if routed or squad.mode==squad.Mode.PATROL else squad.last_known-global_position;facing.y=0
		if facing.length()>.1: rotation.y=lerp_angle(rotation.y,atan2(-facing.x,-facing.z),minf(1,delta*9))
		var clip=gait
		if routed: clip="Flee"
		elif not is_on_floor() and absf(velocity.y)>1: clip="Jump"
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
				rotation.y=lerp_angle(rotation.y,atan2(-partner_direction.x,-partner_direction.z),minf(1,delta*5))
		lizard.set_fleeing(routed);lizard.animate_state(clip,delta)
	velocity.x=movement.x;velocity.z=movement.z
	if not is_on_floor(): velocity.y-=20*delta
	move_and_slide()
	if dive_time<=0 and not routed and not crouched and squad.mode==squad.Mode.COMBAT: attack(delta)
func attack(delta: float) -> void:
	if charge>0:
		charge-=delta
		if charge<=0:
			var start=lizard.muzzle_position();var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.8,start);ray.exclude=friendly_rids()
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): cooldown=.4;return
			var bolt=manager.plasma(start,aim-start,12 if elite else 8,true,get_rid(),Color(1,.07,.035) if elite else Color(.12,1,.65));bolt.excluded=friendly_rids();lizard.fire();audio.play();cooldown=.4 if elite else 1.9
	elif cooldown<=0 and sees_player(): aim=arena.walker.global_position+Vector3.UP;charge=.2 if elite else .65
