extends CharacterBody3D
var arena: Node
var manager: Node
var model: Node3D
const MAX_HEALTH := 1000.0
const SIGHT_RANGE := 90.0
const SIGHT_FOV := 110.0
var health := MAX_HEALTH
const SCALE_HEIGHT := 24.0
const BITE_REACH := 16.0
var patrol=[Vector3(-40,0,-60),Vector3(90,0,-130),Vector3(120,0,-290),Vector3(-100,0,-250)]
var waypoint := 0
var stalled_time := 0.0
var cooldown := 0.0
var bite_target: Node3D
var bite_time := 0.0
var bite_applied := false
var bite_grabbed := false
var bite_damage := 0.0
var bite_lift_origin := Vector3.ZERO
var bite_number := 0
var excluded_target: Node3D
var exclude_target_time := 0.0
var health_label: Label3D
var bite_debug: MeshInstance3D
var sight: MeshInstance3D
var animator: AnimationPlayer
var skeleton: Skeleton3D
var root_bone := -1
var head_bone := -1
var vision_frame := Transform3D.IDENTITY
var target_scan_timer := 0.0
var cached_prey: Node3D
var path_timer := 0.0
var path_goal := Vector3.INF
var path: Array[Vector3]=[]
func _ready():
	floor_snap_length=.9;floor_max_angle=deg_to_rad(48)
	model=arena.kit.imported("C:/Games/possession/assets/rigged-t-rex-fabulous/source/rigged_t-rex_fabulous.glb");add_child(model)
	var a=arena.kit.bounds(model);model.scale*=SCALE_HEIGHT/maxf(a.size.y,.01);a=arena.kit.bounds(model);model.position.x-=a.get_center().x;model.position.z-=a.get_center().z
	# The asset faces +Z; gameplay movement and the bite point face -Z.
	model.rotate_y(PI)
	animator=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	skeleton=model.find_child("Skeleton3D",true,false) as Skeleton3D
	if skeleton:
		root_bone=skeleton.find_bone("ScarfaceGiant_01")
		head_bone=skeleton.find_bone("jt_Head_C_08")
	if animator:
		animator.get_animation("CINEMA_4D_Main").loop_mode=Animation.LOOP_LINEAR
		animator.play("CINEMA_4D_Main")
	vision_frame=Transform3D(global_basis,to_global(Vector3(-.25,4.5,-4.5)))
	# A single huge capsule trapped actors under an invisible belly. These simple
	# overlapping volumes follow the torso and skull without claiming empty space.
	add_collision_shape(CapsuleShape3D.new(),Vector3(0,2.6,0),2.15,5.2)
	add_collision_shape(SphereShape3D.new(),Vector3(.1,2.4,2.0),1.85)
	add_collision_shape(SphereShape3D.new(),Vector3(-.25,3.5,-4.5),1.15)
	for tree in get_tree().get_nodes_in_group("trex_passable_tree"): add_collision_exception_with(tree)
	for rock in get_tree().get_nodes_in_group("trex_passable_rock"): add_collision_exception_with(rock)
	bite_debug=MeshInstance3D.new();var bite_box=BoxMesh.new();bite_box.size=Vector3(5,3,5);bite_debug.mesh=bite_box;bite_debug.position=Vector3(-.25,3.6,-4.8);bite_debug.material_override=debug_material(Color(1,.3,.03,.18));bite_debug.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;bite_debug.hide();add_child(bite_debug)
	sight=preload("res://vision_debug.gd").new();sight.setup(SIGHT_RANGE,SIGHT_FOV,Color(1,.22,.04),0);add_child(sight)
	health_label=Label3D.new();health_label.position.y=20;health_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;health_label.pixel_size=.01;add_child(health_label);update_health_label()
	position=patrol[0];position.y=arena.height_at(position.x,position.z)+.1
	# Position is assigned after the model is built; refresh the fallback frame so
	# the first physics tick does not cast sight from the world origin.
	vision_frame=Transform3D(global_basis.orthonormalized(),to_global(Vector3(-.25,4.5,-4.5)))
func take_hit(damage: float,_source: Vector3,_point: Vector3) -> String:
	health-=damage
	update_health_label()
	if health<=0: queue_free();return "TYRANT DOWN"
	return "TYRANT / %d HP" % health
func update_health_label() -> void:
	if not health_label: return
	var filled=roundi(clampf(health/MAX_HEALTH,0.0,1.0)*10.0)
	health_label.text="TYRANT  %d / %d HP\n[%s%s]" % [maxi(0,int(health)),int(MAX_HEALTH),"█".repeat(filled),"·".repeat(10-filled)]
func debug_material(tint: Color) -> StandardMaterial3D:
	var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=tint;material.emission_enabled=true;material.emission=tint;material.emission_energy_multiplier=.5;material.cull_mode=BaseMaterial3D.CULL_DISABLED;return material
func add_collision_shape(shape: Shape3D,offset: Vector3,radius: float=0.0,height: float=0.0) -> void:
	if shape is CapsuleShape3D: shape.radius=radius;shape.height=height
	elif shape is SphereShape3D: shape.radius=radius
	var collision=CollisionShape3D.new();collision.shape=shape;collision.position=offset;add_child(collision)
func vision_origin() -> Vector3:
	# The skeleton's animated head is the real origin, rather than an arbitrary
	# point over the capsule. This keeps both sensing and its debug outline honest.
	return vision_frame.origin
func can_see(candidate: Node3D) -> bool:
	if not is_instance_valid(candidate): return false
	var origin=vision_origin();var offset=candidate.global_position-origin;offset.y=0
	if offset.length()>SIGHT_RANGE: return false
	# A 110 degree cone makes the large predator alert, without the old 360-degree sight.
	# The GLB's head bone has a nonstandard forward axis. Its transform is safe
	# for positioning the debug aid, while the actor's facing remains the stable
	# basis for the actual sensing cone.
	if offset.length()>.01 and (-global_basis.z).dot(offset.normalized())<cos(deg_to_rad(SIGHT_FOV*.5)): return false
	# A tall creature can see a standing target over shallow cover: check the head
	# first, then its torso. Solid cover must block both rays.
	for height in [1.6, .7]:
		var ray=PhysicsRayQueryParameters3D.create(origin,candidate.global_position+Vector3.UP*height);ray.exclude=[get_rid()]
		var hit=get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.collider==candidate or hit.collider==arena.kit.driving: return true
	return false
func target() -> Node3D:
	# Target acquisition used to run two physics rays against every lizard on
	# every tick. A predator can make a decisive choice four times a second.
	if target_scan_timer>0 and is_instance_valid(cached_prey): return cached_prey
	target_scan_timer=.25;cached_prey=null
	var best: Node3D
	var best_distance=INF
	if arena.walker!=excluded_target and can_see(arena.walker): best=arena.walker;best_distance=position.distance_to(best.position)
	for enemy in manager.enemies:
		if enemy!=excluded_target and not enemy.dead and can_see(enemy) and position.distance_to(enemy.position)<best_distance: best=enemy;best_distance=position.distance_to(enemy.position)
	cached_prey=best
	return cached_prey
func begin_bite(prey: Node3D) -> void:
	# Lock one victim for a short attack.  Chasing while the timeline is playing
	# made the mouth appear to clamp on indefinitely, and let target selection
	# silently swap victims before damage was delivered.
	bite_number+=1;bite_target=prey;bite_time=1.2;bite_applied=false;bite_grabbed=false;bite_damage=randf_range(20.0,80.0);cooldown=2.0
	bite_debug.show()
	bite_event("START #%d target=%s distance=%.2f" % [bite_number,prey.name,position.distance_to(prey.position)])
	# Leave the imported animation running continuously. The attack timing is
	# gameplay state only; restarting the one available timeline looked like a stutter.
	bite_lift_origin=prey.global_position
func mouth_point() -> Vector3:
	# Keep the held actor beyond the capsule's rounded upper hull. The earlier
	# point was too close to the body, letting the solver perch victims on top.
	return global_position-global_basis.z*9.0+Vector3.UP*12.0
func bite_can_reach(prey: Node3D) -> bool:
	var mouth=mouth_point();var delta=prey.global_position-mouth;delta.y=0
	return delta.length()<4.0
func clamp_to_mouth(victim: Node3D) -> void:
	if not is_instance_valid(victim): return
	victim.global_position=mouth_point()
	if victim is CharacterBody3D: victim.velocity=Vector3.ZERO
func toss(victim: Node3D) -> void:
	if not is_instance_valid(victim): return
	var direction=victim.global_position-global_position;direction.y=0
	if direction.length()<.1: direction=-global_basis.z
	direction=(direction.normalized()+global_basis.x*randf_range(-.35,.35)).normalized()
	var vertical=randf_range(.8,2.6) if randf()>.30 else randf_range(6.0,9.0)
	var impulse=direction*randf_range(13.0,18.0)+Vector3.UP*vertical
	if victim is PhysicsBody3D:
		add_collision_exception_with(victim);victim.add_collision_exception_with(self)
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(victim):
				remove_collision_exception_with(victim);victim.remove_collision_exception_with(self))
	if victim==arena.walker and arena.has_method("toss_player"):
		arena.toss_player(impulse)
	elif victim.has_method("toss_from_trex"):
		victim.toss_from_trex(impulse,self)
	elif victim is CharacterBody3D:
		victim.velocity=impulse
	bite_event("TOSS #%d victim=%s point=%s impulse=%s" % [bite_number,victim.name,victim.global_position,impulse])
	excluded_target=victim;exclude_target_time=12.0
func apply_bite(victim: Node3D) -> void:
	if not is_instance_valid(victim):
		bite_event("MISS #%d invalid target" % bite_number);return
	# The player has no take_hit method: its health lives on PracticeRange.
	# Check it first so a player seated in a vehicle still takes the bite.
	if victim==arena.walker:
		bite_event("HIT #%d player=%s health_before=%s" % [bite_number,victim.name,str(manager.health)])
		manager.hurt(int(bite_damage),"T-REX BITE")
		bite_event("DONE #%d player health_after=%s" % [bite_number,str(manager.health)])
	elif victim.has_method("take_hit"):
		bite_event("HIT #%d enemy=%s" % [bite_number,victim.name])
		var result=victim.take_hit(bite_damage,position,victim.position+Vector3.UP)
		bite_event("DONE #%d enemy result=%s health_after=%s dead=%s" % [bite_number,result,str(victim.get("health")),str(victim.get("dead"))])
	else:
		bite_event("MISS #%d target=%s has no damage route" % [bite_number,victim.name])
func _physics_process(delta):
	cooldown-=delta;exclude_target_time-=delta
	target_scan_timer=maxf(0.0,target_scan_timer-delta);path_timer=maxf(0.0,path_timer-delta)
	if exclude_target_time<=0: excluded_target=null
	if bite_time>0:
		bite_time-=delta
		# Lift during the short lead-in, then clamp and damage at the bite midpoint.
		# This makes the grab visible instead of teleporting a victim into the air.
		if not bite_grabbed and bite_time<=.75:
			var lift=clampf((.75-bite_time)/.15,0.0,1.0)
			bite_target.global_position=bite_lift_origin.lerp(mouth_point(),lift)
		if not bite_grabbed and bite_time<=.6:
			bite_grabbed=true;clamp_to_mouth(bite_target);bite_event("CLAMP #%d victim=%s point=%s" % [bite_number,bite_target.name,bite_target.global_position]);bite_applied=true;apply_bite(bite_target)
		if bite_grabbed: clamp_to_mouth(bite_target)
		if bite_time<=0:
			toss(bite_target);bite_event("RELEASE #%d applied=%s" % [bite_number,str(bite_applied)]);bite_target=null;bite_grabbed=false;bite_debug.hide()
		position.y=arena.height_at(position.x,position.z)+.05
		velocity=Vector3.ZERO
		return
	var prey=target();var target_point=prey.position if prey else patrol[waypoint]
	var move=target_point-position;move.y=0
	if move.length()<8 and not prey:
		waypoint=(waypoint+1)%patrol.size();path_timer=0
	# The compound and steep terrain are already represented in the squad grid.
	# Follow its coarse path instead of steering a huge collision body directly
	# into a wall, while still retaining physical contact against real geometry.
	var navigation=manager.get("navigation")
	if navigation and (path_timer<=0 or path_goal.distance_to(target_point)>6):
		path_timer=.75;path_goal=target_point;path=navigation.path(global_position,target_point)
	while not path.is_empty() and Vector2(path[0].x-position.x,path[0].z-position.z).length()<4.0: path.pop_front()
	if not path.is_empty():
		target_point=path[0];move=target_point-position;move.y=0
	if move.length()>.1:
		rotation.y=lerp_angle(rotation.y,atan2(-move.x,-move.z),minf(1,delta*4))
		# Keep patrol independent of the large collision capsule; the terrain
		# height field supplies grounding, so trees and ramp seams cannot freeze it.
		var step=move.normalized()*9.0*delta
		var contact=move_and_collide(step)
		if contact:
			# A large capsule must glide past cover rather than continually pressing
			# into it. If it still cannot move, abandon this patrol leg.
			var slide=step.slide(contact.get_normal())
			if slide.length()>.01: move_and_collide(slide)
			if slide.length()<step.length()*.15:
				# A trunk hit head-on has almost no slide component. Step sideways
				# around its circumference, retaining a real collision body.
				var tangent=Vector3(-contact.get_normal().z,0,contact.get_normal().x).normalized()
				if tangent.dot(global_basis.x)<0: tangent=-tangent
				move_and_collide(tangent*6.0*delta)
				stalled_time+=delta
				if stalled_time>.75 and not prey: waypoint=(waypoint+1)%patrol.size();stalled_time=0
			else: stalled_time=0
		else: stalled_time=0
		if animator: animator.speed_scale=1.35 if prey else .8
	else:
		velocity=Vector3.ZERO
		# This imported asset has no separate idle clip. Do not leave its walk
		# animation running against a stationary collision body.
		if animator and not prey: animator.speed_scale=0
	# The arena terrain is a height field. Pin the predator's root to it after
	# horizontal movement so an animation or a missed floor frame cannot leave
	# the whole creature suspended above the ground.
	position.y=arena.height_at(position.x,position.z)+.05
	velocity=Vector3.ZERO
	if prey and bite_can_reach(prey) and cooldown<=0:
		begin_bite(prey)

func _process(_delta):
	# The single imported timeline contains root-bone lift. Keep its limb work
	# but remove that vertical root motion, because world position is terrain-led.
	if skeleton and root_bone>=0:
		# The imported timeline contains metres of root translation that reads as
		# recoil and snapping. Keep limb animation but pin the root in place.
		skeleton.set_bone_pose_position(root_bone,Vector3.ZERO)
	if skeleton and head_bone>=0:
		# Preserve the animated head's position *and orientation*, but remove the
		# imported model scale so the debug frustum remains its requested size.
		var head_pose=skeleton.get_bone_global_pose(head_bone)
		# This GLB exports the head bone with its forward axis reversed.
		vision_frame=Transform3D(((skeleton.global_transform.basis*head_pose.basis)*Basis(Vector3.UP,PI)).orthonormalized(),skeleton.to_global(head_pose.origin))
	else:
		vision_frame=Transform3D(global_basis.orthonormalized(),to_global(Vector3(-.25,4.5,-4.5)))
	if sight:
		sight.global_transform=vision_frame
	# Run after the animation player: terrain owns the actor root, while the
	# mesh stays at its native vertical origin instead of inheriting a 3.8m lift.
	global_position.y=arena.height_at(global_position.x,global_position.z)+.05
func bite_event(message: String) -> void:
	var file=FileAccess.open("user://trex-bite.log",FileAccess.READ_WRITE if FileAccess.file_exists("user://trex-bite.log") else FileAccess.WRITE_READ)
	if not file: return
	file.seek_end();file.store_line("%.3f %s" % [Time.get_ticks_msec()*.001,message])
	file.flush()
