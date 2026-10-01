extends CharacterBody3D
## Live arena adapter: source rigs and clips stay intact; routes use collision.
var arena: Node3D
var kit: Node
var kind := "Alien"
var model: Node3D
var animator: AnimationPlayer
var skeleton: Skeleton3D
var clips := {}
var route: Array[Vector3] = []
var waypoint := 0
var patrol_enabled := true
var controlled := false
var health := 100.0
var max_health := 100.0
var height := 2.2
var cooldown := 0.0
var action_time := 0.0
var muzzle: BoneAttachment3D
var home := Transform3D.IDENTITY
var label: Label3D
var stalled := 0.0
var previous := Vector3.ZERO
var visits := 0

func setup(scene: Node3D, source: Node3D, title: String, actor_height: float, points: Array[Vector3], owner_kit: Node) -> void:
	arena=scene;kit=owner_kit;model=source;kind=title;height=actor_height;route=points
	max_health=1200.0 if kind=="T-Rex" else 100.0;health=max_health
	collision_layer=2;collision_mask=3;floor_snap_length=1.2;floor_max_angle=deg_to_rad(48)
	add_child(model);model.process_mode=Node.PROCESS_MODE_INHERIT
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=1.1 if kind=="T-Rex" else .4
	capsule.height=3.0 if kind=="T-Rex" else 2.0
	shape.shape=capsule;shape.position.y=capsule.height*.5;add_child(shape)
	for node in model.find_children("*","AnimationPlayer",true,false): animator=node
	for node in model.find_children("*","Skeleton3D",true,false): skeleton=node
	if animator:
		# Each actor owns its clip resources; no shared mutation across clones.
		for library_name in animator.get_animation_library_list():
			var library := animator.get_animation_library(library_name).duplicate(true)
			animator.remove_animation_library(library_name);animator.add_animation_library(library_name,library)
		for key in animator.get_animation_list():
			var short_name := String(key).get_file().to_lower()
			clips[short_name]=key
			if short_name in ["idle","run","walk"]: animator.get_animation(key).loop_mode=Animation.LOOP_LINEAR
		animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		if kind=="T-Rex": prepare_rex_walk()
		play("idle")
	if skeleton and skeleton.find_bone("Muzzle")>=0:
		muzzle=BoneAttachment3D.new();muzzle.bone_name="Muzzle";skeleton.add_child(muzzle)
	label=Label3D.new();label.position.y=height+.8;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size=.01;label.visibility_range_end=90;add_child(label)
	home=transform;previous=position
	print("LIVE_ACTOR ",kind," clips=",clips.keys()," skinned=",skeleton!=null)

func prepare_rex_walk() -> void:
	if not animator.has_animation("CINEMA_4D_Main"): return
	# Reuse the proven 312–413 walk interval; remove root travel, not the rig.
	var source := animator.get_animation("CINEMA_4D_Main")
	var walk := Animation.new();walk.length=101.0/30.0;walk.loop_mode=Animation.LOOP_LINEAR
	for track in source.get_track_count():
		var type := source.track_get_type(track)
		if type not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]: continue
		var path := source.track_get_path(track)
		if not String(path).contains(":"): continue
		var dest := walk.add_track(type);walk.track_set_path(dest,path)
		for frame in range(312,414):
			var time := frame/30.0
			var start: Variant
			var value: Variant
			if type==Animation.TYPE_ROTATION_3D:
				start=source.rotation_track_interpolate(track,312.0/30.0);value=source.rotation_track_interpolate(track,time)
			elif type==Animation.TYPE_SCALE_3D:
				start=source.scale_track_interpolate(track,312.0/30.0);value=source.scale_track_interpolate(track,time)
			else:
				start=source.position_track_interpolate(track,312.0/30.0);value=source.position_track_interpolate(track,time)
				if String(path).get_slice(":",1)=="ScarfaceGiant_01": start=Vector3.ZERO;value=Vector3.ZERO
			var blend := smoothstep(405.0,413.0,float(frame))
			value=value.slerp(start,blend) if type==Animation.TYPE_ROTATION_3D else value.lerp(start,blend)
			walk.track_insert_key(dest,(frame-312)/30.0,value)
	animator.get_animation_library("").add_animation("ArenaWalk",walk)
	clips["walk"]="ArenaWalk"
	clips["idle"]="ArenaWalk"

func play(clip: String) -> void:
	if not animator or not clips.has(clip): return
	if animator.current_animation!=clips[clip] or not animator.is_playing(): animator.play(clips[clip],.15)
	animator.speed_scale=0.0 if kind=="T-Rex" and clip=="idle" else 1.0

func take_hit(damage: float, _source := Vector3.ZERO, _point := Vector3.ZERO) -> String:
	if health<=0: return "already down"
	health=maxf(0,health-damage)
	if health<=0:
		play("death");patrol_enabled=false;velocity=Vector3.ZERO
		if kind=="T-Rex" and animator: animator.pause()
	return "%s %.0f/%.0f" % [kind,health,max_health]

func reset_actor() -> void:
	transform=home;health=max_health;velocity=Vector3.ZERO;waypoint=0;patrol_enabled=true
	action_time=0;cooldown=0;stalled=0;play("idle")

func attack(target: Node3D=null) -> void:
	if cooldown>0 or health<=0: return
	cooldown=1.1 if kind=="T-Rex" else .45;action_time=.4
	if kind=="Alien":
		play("fire")
		var origin := muzzle.global_position if muzzle else global_position+Vector3.UP*1.5
		var direction: Vector3 = kit.aim_direction(origin,self) if controlled else ((target.global_position+Vector3.UP)-origin).normalized()
		kit.shoot(origin,direction,12,180,self,Color(.6,1,.3))
	else:
		# Additive neck/jaw attack; recovery resets the skeleton override below.
		for victim in kit.actors:
			if victim!=self and victim.health>0 and global_position.distance_to(victim.global_position)<11:
				var delta: Vector3=victim.global_position-global_position
				if (-global_basis.z).dot(delta.normalized())>.4: victim.take_hit(80,global_position,victim.global_position)
		kit.flash(global_position-global_basis.z*5+Vector3.UP*3,Color(1,.4,.1))

func _physics_process(delta: float) -> void:
	if not arena: return
	cooldown=maxf(0,cooldown-delta);action_time=maxf(0,action_time-delta)
	label.text="%s / %.0f HP / %s" % [kind,health,"CONTROL" if controlled else ("PATROL" if patrol_enabled else "HOLD")]
	if health<=0:
		if arena.neighborhood_ready(global_position): velocity.y-=20*delta;move_and_slide()
		return
	if not arena.neighborhood_ready(global_position): velocity=Vector3.ZERO;play("idle");return
	var direction := Vector3.ZERO
	if controlled:
		direction=kit.move_direction()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED: attack()
		if is_on_floor() and Input.is_key_pressed(KEY_SPACE): velocity.y=5
	elif patrol_enabled and not route.is_empty():
		var goal := route[waypoint];goal.y=global_position.y
		if global_position.distance_to(goal)<3:
			waypoint=(waypoint+1)%route.size();visits+=1;goal=route[waypoint];goal.y=global_position.y
		direction=(goal-global_position).normalized()
		# Keep AI demonstration peaceful in observer mode; combat starts on foot/control.
		var target: Node3D=kit.controlled_actor if kit.controlled_actor else (arena.player if arena.walking else null)
		if kind=="Alien" and target and target!=self and global_position.distance_to(target.global_position)<35:
			var sight := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.5,target.global_position+Vector3.UP,3)
			sight.exclude=[get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(sight)
			if hit.is_empty() or hit.collider==target: attack(target)
	var speed := (7.0 if kind=="T-Rex" else 4.0) if controlled and Input.is_key_pressed(KEY_SHIFT) else (4.0 if kind=="T-Rex" else 2.3)
	if direction.length_squared()>.01:
		rotation.y=lerp_angle(rotation.y,atan2(-direction.x,-direction.z),delta*4)
	velocity.x=direction.x*speed;velocity.z=direction.z*speed;velocity.y-=20*delta
	move_and_slide()
	position.x=clampf(position.x,-arena.movement_limit(),arena.movement_limit())
	position.z=clampf(position.z,-arena.movement_limit(),arena.movement_limit())
	if not controlled and direction.length_squared()>.01:
		stalled=stalled+delta if position.distance_to(previous)<.005 else 0.0
		if stalled>3: waypoint=(waypoint+1)%route.size();stalled=0
	previous=position
	if action_time<=0: play("walk" if kind=="T-Rex" and direction.length_squared()>.01 else ("run" if direction.length_squared()>.01 else "idle"))
	if kind=="T-Rex" and skeleton:
		var head := skeleton.find_bone("jt_Head_C_08")
		if head>=0:
			var pose := skeleton.get_bone_global_pose(head)
			pose.basis*=Basis(Vector3.RIGHT,sin(action_time/.4*PI)*-.35)
			skeleton.set_bone_global_pose_override(head,pose,1.0 if action_time>0 else 0.0,true)
	if position.y < -23: reset_actor()
