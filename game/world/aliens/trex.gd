extends CharacterBody3D
const Ring=preload("res://world/terrain_drive_ring.gd")
var animation_elapsed := 0.0
var screen_size_animation := false
var animation_schedule := 0.0
var physics_usec := 0
var pose_usec := 0
var runtime_active := false
var shadow_enabled := true
var suspension_reason := "loading"
var movement_blocked := ""
var detour_direction := Vector3.ZERO
var detour_remaining := 0.0
var escape_retry := 0.0
var recovery_count := 0
var foliage_blocks := 0
var foliage_depth := 0.0
var motion_probe := KinematicCollision3D.new()
var arena: Node
var manager: Node
var model: Node3D
const MAX_HEALTH := 4000.0
const SIGHT_RANGE := 90.0
const SIGHT_FOV := 110.0
var health := MAX_HEALTH
const SCALE_HEIGHT := 24.0
# Keep the enlarged version explicitly, rather than depending on posed bounds.
const SIZE_MULTIPLIER := 3.6061933
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
var debug_indicators := false
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
func origin_shifted(delta: Vector3):
	bite_lift_origin-=delta;path_goal-=delta;progress_position-=delta;motion_previous-=delta
	stomp_point-=delta;slam_origin-=delta
	for i in patrol.size():patrol[i]-=delta
	for i in path.size():path[i]-=delta
	if authored_route:authored_route.origin_shifted(delta)
var path: Array[Vector3]=[]
var tree_exception_timer := 0.0
const WALK_PLAYBACK_RATE := 1.0 # Previous patrol rate .8, increased by 25%.
const MOTION_SAMPLE_RATE := 30.0
const WALK_FIRST_FRAME := 312
const WALK_LAST_FRAME := 413
const WALK_CLIP := "RexWalk"
const EMOTE_CLIP := "RexClearRoar"
var emote_time := 0.0
var emote_cooldown := 0.0
var clear_pending := 0.0
var clear_quiet := 0.0
var locomotion_profile: PackedFloat32Array=[]
var grounding: SkeletonModifier3D
var progress_position := Vector3.ZERO
var progress_time := 0.0
var last_blocker := ""
var sounds: Node3D
var hold_state: Dictionary={}
var grip_offset := Vector3.ZERO
var motion_previous := Vector3.ZERO
var attack_kind := 0 # Repeating up / left / right / down-stomp-eat.
var attack_duration := 1.2
var attack_recovery := 0.0
var stomp_point := Vector3.ZERO
var slam_origin := Vector3.ZERO
var slam_started := false
var stomp_applied := false
var consumed := false
var authored_route: RefCounted
var walk_speed := 9.0
var behavior_mode := 0 # Auto, patrol, hunt, hold, manual.
var manual_move := Vector3.ZERO
var manual_bite := false
var preview_mode := 0 # Live, full take, walk excerpt, rest, four attack previews.
var preview_clock := 0.0
static var cached_model: PackedScene
var rival: Node3D
var rival_time := 0.0
var rival_hit := false
var rival_hits_given := 0
var meeting_wait := 0.0
var meeting_arrived := -1

func set_preview(mode: int) -> void:
	rival_time=0;rival=null
	release_hold();bite_target=null;bite_time=0;attack_recovery=0;bite_grabbed=false
	if bite_debug: bite_debug.hide()
	preview_mode=mode;preview_clock=0;manual_move=Vector3.ZERO
	emote_time=0;clear_pending=0;clear_quiet=0
	if mode>=4:
		stomp_point=grounding.last_feet[0] if grounding and grounding.last_feet.size()==2 else to_global(Vector3(1.4,0,4))
		stomp_point=surface_point(stomp_point,.3)
	if animator:
		animator.play(WALK_CLIP if mode==0 or mode==2 else "CINEMA_4D_Main",.2)
		animator.speed_scale=1.0;animator.seek(0.0,true)

func diagnostic_animation() -> String:
	if rival_time>0: return "Tyrant versus Tyrant / bite"
	if preview_mode>0: return ["","Full imported take","Walk excerpt","Rest pose","Toss up preview","Toss left preview","Toss right preview","Slam / stomp / eat preview"][preview_mode]
	if bite_time>0 or attack_recovery>0: return ["Toss up","Toss left","Toss right","Slam / stomp / eat"][attack_kind]
	return "Threats cleared / roar" if emote_time>0 else "Walk (source 312–413)"

func diagnostic_frame() -> int:
	if preview_mode>=4: return int(preview_clock*30)
	if bite_time>0 or attack_recovery>0: return int(attack_elapsed()*30)
	return int(animator.current_animation_position*30)+(WALK_FIRST_FRAME if animator.current_animation==WALK_CLIP else 0) if animator else 0

func attack_elapsed() -> float:
	return attack_duration-maxf(0.0,bite_time)

func attack_pose() -> Vector3:
	if rival_time>0:
		var t=1.1-rival_time
		return Vector3(deg_to_rad(-12)*sin(t*PI/1.1),0,.3*sin(t*PI/1.1))
	# X = neck pitch, Y = neck yaw, Z = jaw opening. Smooth keys are an
	# additive animation layer, independent of the imported walking timeline.
	if bite_time<=0 and attack_recovery<=0: return Vector3.ZERO
	var t=attack_elapsed()
	var wind=smoothstep(.60,.85,t)
	var throw=smoothstep(.85,1.2,t)
	var follow=attack_recovery/.4 if bite_time<=0 else 1.0
	if attack_kind==0: return Vector3(deg_to_rad(-12)*wind+deg_to_rad(46)*throw,0,.15)*follow
	if attack_kind==1: return Vector3(0,deg_to_rad(-18)*wind+deg_to_rad(60)*throw,.15)*follow
	if attack_kind==2: return Vector3(0,deg_to_rad(18)*wind-deg_to_rad(60)*throw,.15)*follow
	var eat=smoothstep(2.4,2.8,t)-smoothstep(3.1,3.4,t)
	var dip=smoothstep(.85,1.2,t)*(1.0-smoothstep(1.55,1.9,t))
	var chew=(.5+.5*sin((t-3.15)*22.0))*.25 if t>3.15 and t<3.75 else .1
	return Vector3(deg_to_rad(-28)*dip+deg_to_rad(-24)*eat,0,chew+eat*.25)

func stomp_lift() -> float:
	if attack_kind!=3 or bite_time<=0: return 0.0
	var t=attack_elapsed()
	return 1.6*smoothstep(1.25,1.65,t)*(1.0-smoothstep(1.65,1.95,t))

func update_attack_attachment() -> void:
	if not is_instance_valid(bite_target) or consumed: return
	var t=attack_elapsed()
	if attack_kind==3 and slam_started:
		var roll=smoothstep(1.2,1.55,t)*(1.0-smoothstep(2.4,3.15,t))
		bite_target.global_basis=Basis(global_basis.x,roll*PI*.5)*hold_state.basis
		grip_offset=bite_target.global_basis*hold_state.grip_local
		var point=slam_origin.lerp(stomp_point,smoothstep(1.2,1.55,t))
		if t>=2.4: point=stomp_point.lerp(mouth_point(),smoothstep(2.4,3.15,t))
		bite_target.global_position=point-grip_offset
	elif bite_grabbed: clamp_to_mouth(bite_target)

func consume_victim() -> void:
	if consumed or not is_instance_valid(bite_target): return
	consumed=true
	clear_pending=8.0;clear_quiet=0
	var victim=bite_target
	if victim==manager.target():
		release_hold();manager.hurt(10000)
	elif victim.has_method("take_hit"):
		victim.take_hit(10000,global_position,mouth_point());victim.hide();release_hold(true)
		victim.set_physics_process(false)
	else:
		release_hold();victim.queue_free()
	bite_grabbed=false;bite_target=null
	if sounds: sounds.bite()
	bite_event("EAT #%d" % bite_number)

func update_settle(delta: float) -> void:
	var distance=(position-motion_previous).slide(Ring.up_at(position)).length()
	motion_previous=position
	if grounding:
		grounding.settle_weight=move_toward(grounding.settle_weight,1.0 if distance<.005 or bite_time>0 else 0.0,delta/(.35 if distance<.005 or bite_time>0 else .18))

func release_hold(launch: bool=false) -> void:
	if is_instance_valid(bite_target) and not hold_state.is_empty():
		bite_target.global_basis=hold_state.basis
		bite_target.set_physics_process(hold_state.physics)
		bite_target.remove_meta("trex_held")
		if bite_target is PhysicsBody3D:
			# A killed alien must keep its death collision state.
			if not (bite_target.get("dead") == true):
				bite_target.collision_layer=hold_state.layer;bite_target.collision_mask=hold_state.mask
		if bite_target is RigidBody3D: bite_target.freeze=hold_state.freeze
		if not launch and bite_target.has_method("finish_trex_hold"): bite_target.finish_trex_hold()
	hold_state.clear()

func _exit_tree() -> void:
	release_hold()

func prepare_animation() -> void:
	# Keep the source asset untouched. Its single take contains stationary poses
	# as well as strides; root travel is the authored signal for that distinction.
	var clip=animator.get_animation("CINEMA_4D_Main").duplicate() as Animation
	var library=animator.get_animation_library("").duplicate(true)
	animator.remove_animation_library("");animator.add_animation_library("",library)
	library.remove_animation("CINEMA_4D_Main")
	library.add_animation("CINEMA_4D_Main",clip)
	clip.loop_mode=Animation.LOOP_LINEAR
	for track in clip.get_track_count():
		if clip.track_get_type(track)!=Animation.TYPE_POSITION_3D: continue
		if String(clip.track_get_path(track)).get_slice(":",1)!="ScarfaceGiant_01": continue
		var speeds: Array[float]=[]
		var peak=0.0
		for sample in range(ceili(clip.length*MOTION_SAMPLE_RATE)+1):
			var time=minf(sample/MOTION_SAMPLE_RATE,clip.length)
			# One-sided at the loop boundary: the root resets there, it does not
			# teleport across the scene. A short window filters exporter key noise.
			var start=maxf(0.0,time-.05);var finish=minf(clip.length,time+.05)
			var travel=clip.position_track_interpolate(track,finish)-clip.position_track_interpolate(track,start)
			travel.y=0
			var speed=travel.length()/maxf(finish-start,.001)
			speeds.append(speed);peak=maxf(peak,speed)
		for speed in speeds:
			# Suppress small planted-pose sway, ease into/out of the moving phases.
			locomotion_profile.append(smoothstep(peak*.12,peak*.55,speed))
		# Keep a constant track: disabling it lets AnimationMixer restore the
		# imported rest/default translation when seeking or blending.
		for key in range(clip.track_get_key_count(track)-1,-1,-1):
			clip.track_remove_key(track,key)
		clip.position_track_insert_key(track,0.0,Vector3.ZERO)
		if skeleton and root_bone>=0: skeleton.set_bone_pose_position(root_bone,Vector3.ZERO)
		break
	animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	library.add_animation(WALK_CLIP,extract_clip(clip,WALK_FIRST_FRAME,WALK_LAST_FRAME,true))
	library.add_animation(EMOTE_CLIP,extract_clip(clip,0,50,false))
	animator.play(WALK_CLIP)
	animator.speed_scale=WALK_PLAYBACK_RATE

func extract_clip(source: Animation,first: int,last: int,loop: bool) -> Animation:
	# Resample only skeletal transform tracks. Blend the final eight frames back
	# to the SAME leg phase, not to the opposite foot's stance. Keep the GLB intact.
	var result=Animation.new();result.length=(last-first)/30.0
	result.loop_mode=Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for track in source.get_track_count():
		var type=source.track_get_type(track)
		if type not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]: continue
		if not String(source.track_get_path(track)).contains(":"): continue
		var dest=result.add_track(type);result.track_set_path(dest,source.track_get_path(track))
		var start=sample_transform(source,track,first/30.0,type)
		for frame in range(first,last+1):
			var value=sample_transform(source,track,frame/30.0,type)
			var blend=smoothstep(float(last-8),float(last),float(frame)) if loop else 0.0
			value=value.slerp(start,blend) if type==Animation.TYPE_ROTATION_3D else value.lerp(start,blend)
			result.track_insert_key(dest,(frame-first)/30.0,value)
	return result

func sample_transform(clip: Animation,track: int,time: float,type: int) -> Variant:
	if type==Animation.TYPE_ROTATION_3D: return clip.rotation_track_interpolate(track,time)
	if type==Animation.TYPE_SCALE_3D: return clip.scale_track_interpolate(track,time)
	return clip.position_track_interpolate(track,time)

func ensure_walk() -> void:
	if animator.current_animation!=WALK_CLIP: animator.play(WALK_CLIP,.25)

func ground_sample(point: Vector3, allow_steep: bool=false) -> Dictionary:
	if not manager.resident(point): return {}
	var up=Ring.up_at(point)
	var query=PhysicsRayQueryParameters3D.create(point+up*18,point-up*30,1)
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (not allow_steep and hit.normal.dot(up)<cos(floor_max_angle)): return {}
	return hit

func surface_point(point: Vector3, clearance: float=0.05) -> Vector3:
	var hit=ground_sample(point)
	return hit.position+Ring.up_at(point)*clearance if not hit.is_empty() else point

func snap_ground() -> void:
	global_position=surface_point(global_position)

func move_walk(direction: Vector3,delta: float) -> void:
	var up=Ring.up_at(global_position);direction=direction.slide(up)
	movement_blocked="";last_blocker=""
	ensure_walk()
	if direction.length()<.01: animator.speed_scale=0;return
	escape_retry=maxf(0,escape_retry-delta)
	if escape_retry>0: movement_blocked="escape_wait";animator.speed_scale=0;return
	detour_remaining=maxf(0,detour_remaining-delta)
	var heading=detour_direction.slide(up).normalized() if detour_remaining>0 else direction.normalized()
	var current=ground_sample(global_position,true)
	var escaping_slope=not current.is_empty() and current.normal.dot(up)<cos(floor_max_angle)
	# Look beyond a single physics step, and retain the chosen side long enough
	# to get around a slope instead of retrying the same uphill direction each tick.
	for angle in [0.0,.55,-.55,1.1,-1.1,1.65,-1.65,2.2,-2.2,PI]:
		var candidate=heading.rotated(up,angle)
		var support=ground_sample(global_position+candidate*walk_speed*delta,true)
		var ahead=ground_sample(global_position+candidate*1.8,true)
		if support.is_empty() or ahead.is_empty(): movement_blocked="terrain_support";continue
		var step=support.position+up*.05-global_position
		var descent=step.dot(up)<.01 and (ahead.position-global_position).dot(up)<0
		var recovering=escaping_slope and descent
		if (support.normal.dot(up)<cos(floor_max_angle) or ahead.normal.dot(up)<cos(floor_max_angle)) and not recovering:
			movement_blocked="steep_terrain";continue
		var grade=3.0 if recovering else 1.05
		if absf(step.dot(up))>step.slide(up).length()*grade+.15 or absf((ahead.position-global_position).dot(up))>1.8*grade+.15:
			movement_blocked="slope";continue
		var desired=Basis.looking_at(candidate,up)
		var proposed=global_transform
		proposed.basis=global_basis.orthonormalized().slerp(desired,minf(1.0,delta*5)).orthonormalized()
		if test_move(proposed,step,motion_probe):
			movement_blocked="collision"
			var obstacle=motion_probe.get_collider()
			last_blocker=str(obstacle.get_path()) if is_instance_valid(obstacle) else "unknown"
			continue
		if absf(angle)>.01:
			detour_direction=candidate;detour_remaining=1.5;recovery_count+=1
		global_basis=proposed.basis
		move_and_collide(step);animator.speed_scale=WALK_PLAYBACK_RATE;velocity=Vector3.ZERO;movement_blocked="";last_blocker="";return
	escape_retry=.3;detour_remaining=0;animator.speed_scale=0;velocity=Vector3.ZERO

func front_threat_alive() -> bool:
	# Do not confuse target exclusion after a toss or losing lock with a kill.
	if manager.health>0 and can_see(manager.target()): return true
	for enemy in manager.enemies:
		if is_instance_valid(enemy) and not enemy.dead and can_see(enemy): return true
	for other in get_tree().get_nodes_in_group("tyrants"):
		if other!=self and other.health>0 and can_see(other): return true
	return false

func update_clear_emote(delta: float) -> bool:
	emote_cooldown=maxf(0,emote_cooldown-delta)
	if emote_time<=0 and clear_pending<=0: return false
	var unsafe=behavior_mode!=0 or front_threat_alive()
	if emote_time>0:
		emote_time=maxf(0,emote_time-delta)
		if unsafe or emote_time<=0:
			emote_time=0;ensure_walk();return false
		animator.speed_scale=1;velocity=Vector3.ZERO;return true
	clear_pending=maxf(0,clear_pending-delta)
	clear_quiet=0.0 if unsafe else clear_quiet+delta
	if clear_quiet>=2.0 and emote_cooldown<=0:
		clear_pending=0;clear_quiet=0;emote_cooldown=45
		emote_time=50.0/30.0;animator.play(EMOTE_CLIP,.25);animator.speed_scale=1
		if sounds: sounds.alert()
		velocity=Vector3.ZERO;return true
	return false

func locomotion_weight(time: float) -> float:
	if locomotion_profile.is_empty(): return 1.0
	var sample=clampf(time*MOTION_SAMPLE_RATE,0.0,locomotion_profile.size()-1.0)
	var index=floori(sample)
	return lerpf(locomotion_profile[index],locomotion_profile[mini(index+1,locomotion_profile.size()-1)],sample-index)
func _ready():
	add_to_group("tyrants")
	floor_snap_length=.9;floor_max_angle=deg_to_rad(48);collision_layer=2;collision_mask=2|4;platform_floor_layers=0;platform_wall_layers=0
	if not cached_model:
		var document=GLTFDocument.new();var state=GLTFState.new()
		assert(document.append_from_file(ProjectSettings.globalize_path("res://../assets/rigged-t-rex-fabulous/source/rigged_t-rex_fabulous.glb"),state)==OK,"T. rex asset unavailable")
		var source=document.generate_scene(state)
		cached_model=PackedScene.new();cached_model.pack(source);source.free()
	model=cached_model.instantiate();add_child(model)
	for mesh in model.find_children("*","MeshInstance3D",true,false): mesh.visibility_range_end=400
	var importer=preload("res://world/arena_live_content.gd").new()
	var raw_importer=preload("res://world/content_gallery.gd").new()
	var reference=raw_importer.model_bounds(model)
	model.scale*=SCALE_HEIGHT/maxf(reference.size.y,.01)*SIZE_MULTIPLIER
	raw_importer.contact_debug.free();raw_importer.free()
	var a=importer.model_bounds(model);model.position.x-=a.get_center().x;model.position.z-=a.get_center().z
	importer.contact_debug.free();importer.free()
	# The asset faces +Z; gameplay movement and the bite point face -Z.
	model.rotate_y(PI)
	animator=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	skeleton=model.find_child("Skeleton3D",true,false) as Skeleton3D
	if skeleton:
		root_bone=skeleton.find_bone("ScarfaceGiant_01")
		head_bone=skeleton.find_bone("jt_Head_C_08")
	if animator:
		prepare_animation()
	if skeleton:
		grounding=preload("res://world/aliens/trex_grounding.gd").new()
		skeleton.add_child(grounding);grounding.setup(self)
	vision_frame=Transform3D(global_basis,to_global(Vector3(-.25,4.5,-4.5)))
	# A single huge capsule trapped actors under an invisible belly. These simple
	# overlapping volumes follow the torso and skull without claiming empty space.
	add_collision_shape(CapsuleShape3D.new(),Vector3(0,2.6,0),2.15,5.2)
	add_collision_shape(SphereShape3D.new(),Vector3(.1,2.4,2.0),1.85)
	add_collision_shape(SphereShape3D.new(),Vector3(-.25,3.5,-4.5),1.15)
	# Terrain is sampled explicitly. Restore the original Tyrant-only trunk exceptions.
	refresh_tree_exceptions()
	get_tree().node_added.connect(register_passable_tree)
	bite_debug=MeshInstance3D.new();var bite_box=BoxMesh.new();bite_box.size=Vector3(5,3,5);bite_debug.mesh=bite_box;bite_debug.position=Vector3(-.25,3.6,-4.8);bite_debug.material_override=debug_material(Color(1,.3,.03,.18));bite_debug.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;bite_debug.hide();add_child(bite_debug)
	sight=preload("res://world/aliens/rex_vision.gd").new();sight.setup(SIGHT_RANGE,SIGHT_FOV,Color(1,.22,.04),0);add_child(sight);sight.visible=debug_indicators
	health_label=Label3D.new();health_label.position.y=20;health_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;health_label.pixel_size=.01;add_child(health_label);update_health_label()
	position=patrol[0];snap_ground();global_basis=Ring.tangent_basis(position,0)
	progress_position=position
	motion_previous=position
	sounds=preload("res://world/aliens/trex_audio.gd").new();add_child(sounds)
	# Position is assigned after the model is built; refresh the fallback frame so
	# the first physics tick does not cast sight from the world origin.
	vision_frame=Transform3D(global_basis.orthonormalized(),to_global(Vector3(-.25,4.5,-4.5)))

func register_passable_tree(node: Node) -> void:
	if node is PhysicsBody3D and node.is_in_group("trex_passable_tree"):
		add_collision_exception_with(node)

func refresh_tree_exceptions() -> void:
	for tree in get_tree().get_nodes_in_group("trex_passable_tree"):
		if tree is PhysicsBody3D: add_collision_exception_with(tree)
func take_hit(damage: float,_source: Vector3,_point: Vector3) -> String:
	health-=damage
	if sounds and health>0: sounds.hurt()
	update_health_label()
	if health<=0: manager.rex_defeated=not has_meta("actor_id");release_hold();queue_free();return "TYRANT DOWN"
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
	var origin=vision_origin();var offset=(candidate.global_position-origin).slide(Ring.up_at(position))
	if offset.length()>SIGHT_RANGE: return false
	# A 110 degree cone makes the large predator alert, without the old 360-degree sight.
	# The GLB's head bone has a nonstandard forward axis. Its transform is safe
	# for positioning the debug aid, while the actor's facing remains the stable
	# basis for the actual sensing cone.
	if offset.length()>.01 and (-global_basis.z).dot(offset.normalized())<cos(deg_to_rad(SIGHT_FOV*.5)): return false
	# A tall creature can see a standing target over shallow cover: check the head
	# first, then its torso. Solid cover must block both rays.
	for height in [1.6, .7]:
		var endpoint=candidate.global_position+Ring.up_at(candidate.global_position)*height
		foliage_depth=preload("res://world/aliens/forest_sight.gd").depth(arena.get("painted_trees"),origin,endpoint)
		if origin.distance_to(endpoint)>maxf(6.0,SIGHT_RANGE*exp(-foliage_depth)):
			foliage_blocks+=1;continue
		var ray=PhysicsRayQueryParameters3D.create(origin,endpoint);ray.exclude=[get_rid()]
		var hit=get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.collider==candidate: return true
	return false
func target() -> Node3D:
	# Target acquisition used to run two physics rays against every lizard on
	# every tick. A predator can make a decisive choice four times a second.
	if target_scan_timer>0 and is_instance_valid(cached_prey) and cached_prey.get("dead")!=true and (cached_prey!=manager.target() or manager.health>0): return cached_prey
	target_scan_timer=.25;cached_prey=null
	var best: Node3D
	var best_distance=INF
	if behavior_mode!=4 and manager.health>0 and manager.target()!=excluded_target and can_see(manager.target()): best=manager.target();best_distance=position.distance_to(best.position)
	for enemy in manager.enemies:
		if enemy!=excluded_target and not enemy.dead and can_see(enemy) and position.distance_to(enemy.position)<best_distance: best=enemy;best_distance=position.distance_to(enemy.position)
	for other in get_tree().get_nodes_in_group("tyrants"):
		if other!=self and other.health>0 and can_see(other):
			# Another Tyrant is a territorial rival, even when an alien is nearer.
			if not best or not best.is_in_group("tyrants") or position.distance_to(other.position)<best_distance: best=other;best_distance=position.distance_to(other.position)
	
	cached_prey=best
	return cached_prey
func begin_bite(prey: Node3D) -> void:
	if prey.is_in_group("tyrants"):
		rival=prey;rival_time=1.1;rival_hit=false;cooldown=2.4
		return # Never suspend, lift, eat or throw another full-sized Tyrant.
	# Lock one victim for a short attack.  Chasing while the timeline is playing
	# made the mouth appear to clamp on indefinitely, and let target selection
	# silently swap victims before damage was delivered.
	bite_number+=1;attack_kind=(bite_number-1)%4;attack_duration=4.0 if attack_kind==3 else 1.2
	bite_target=prey;bite_time=attack_duration;bite_applied=false;bite_grabbed=false;bite_damage=randf_range(20.0,80.0);cooldown=attack_duration+1.0
	slam_started=false;stomp_applied=false;consumed=false;attack_recovery=0
	stomp_point=grounding.last_feet[0] if grounding and grounding.last_feet.size()==2 else to_global(Vector3(1.4,0,4))
	stomp_point=surface_point(stomp_point,.3)
	bite_debug.visible=debug_indicators
	bite_event("START #%d target=%s distance=%.2f" % [bite_number,prey.name,position.distance_to(prey.position)])
	# Keep the current walk phase for the attack's planted base pose.
	bite_lift_origin=prey.global_position
	grip_offset=Vector3.ZERO
	for child in prey.get_children():
		if child is CollisionShape3D and not child.disabled:
			grip_offset=prey.global_basis*child.position;break
	hold_state={"physics":prey.is_physics_processing(),"basis":prey.global_basis,"grip_local":prey.global_basis.inverse()*grip_offset}
	prey.set_physics_process(false);prey.set_meta("trex_held",self)
	if prey is PhysicsBody3D:
		hold_state.layer=prey.collision_layer;hold_state.mask=prey.collision_mask
		prey.collision_layer=0;prey.collision_mask=0
	if prey is RigidBody3D:
		hold_state.freeze=prey.freeze;prey.freeze=true
func mouth_point() -> Vector3:
	# Tongue markers define the interior of the actual animated jaws, including
	# the post-animation terrain correction. No fixed world-space grab point.
	if grounding and grounding.has_pose and not grounding.mouth_bones.has(-1): return grounding.last_mouth
	if skeleton:
		var a=skeleton.find_bone("jt_Tongue1_C_010");var b=skeleton.find_bone("jt_Tongue2_C_011")
		if a>=0 and b>=0:
			var base=skeleton.to_global(skeleton.get_bone_global_pose(a).origin);var tip=skeleton.to_global(skeleton.get_bone_global_pose(b).origin)
			return tip+(tip-base).normalized()*.35
	return vision_origin()
func bite_can_reach(prey: Node3D) -> bool:
	if prey.is_in_group("tyrants"): return global_position.distance_to(prey.global_position)<13
	var mouth=mouth_point();var delta=(prey.global_position-mouth).slide(Ring.up_at(position))
	return delta.length()<4.0
func clamp_to_mouth(victim: Node3D) -> void:
	if not is_instance_valid(victim): return
	victim.global_position=mouth_point()-grip_offset
	if victim is CharacterBody3D: victim.velocity=Vector3.ZERO
func toss(victim: Node3D) -> void:
	if not is_instance_valid(victim): return
	clamp_to_mouth(victim)
	release_hold(true)
	var impulse=-global_basis.z*5.0+Ring.up_at(global_position)*14.0
	if attack_kind==1: impulse=-global_basis.x*16.0+Ring.up_at(global_position)*3.0
	elif attack_kind==2: impulse=global_basis.x*16.0+Ring.up_at(global_position)*3.0
	elif attack_kind==3: impulse=-Ring.up_at(global_position)*15.0
	if victim is PhysicsBody3D:
		add_collision_exception_with(victim);victim.add_collision_exception_with(self)
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(victim):
				remove_collision_exception_with(victim);victim.remove_collision_exception_with(self))
	if victim==arena.on_foot:
		arena.on_foot.toss_from_trex(impulse,self)
	elif victim.has_method("toss_from_trex"):
		victim.toss_from_trex(impulse,self)
	elif victim is CharacterBody3D:
		victim.velocity=impulse
	elif victim is RigidBody3D:
		victim.linear_velocity=impulse
	bite_event("TOSS #%d victim=%s point=%s impulse=%s" % [bite_number,victim.name,victim.global_position,impulse])
	excluded_target=victim;exclude_target_time=12.0
func apply_bite(victim: Node3D) -> void:
	if not is_instance_valid(victim):
		bite_event("MISS #%d invalid target" % bite_number);return
	if sounds: sounds.bite()
	# The player has no take_hit method: its health lives on PracticeRange.
	# Check it first so a player seated in a vehicle still takes the bite.
	if victim==manager.target():
		bite_event("HIT #%d player=%s health_before=%s" % [bite_number,victim.name,str(manager.health)])
		manager.hurt(bite_damage)
		if manager.health<=0: clear_pending=8.0;clear_quiet=0
		bite_event("DONE #%d player health_after=%s" % [bite_number,str(manager.health)])
	elif victim.has_method("take_hit"):
		bite_event("HIT #%d enemy=%s" % [bite_number,victim.name])
		var result=victim.take_hit(bite_damage,position,victim.position+Ring.up_at(global_position))
		if victim.get("dead")==true: clear_pending=8.0;clear_quiet=0
		bite_event("DONE #%d enemy result=%s health_after=%s dead=%s" % [bite_number,result,str(victim.get("health")),str(victim.get("dead"))])
	else:
		bite_event("MISS #%d target=%s has no damage route" % [bite_number,victim.name])
func _physics_process(delta):
	var began=Time.get_ticks_usec()
	var paused=manager.paused()
	var resident=manager.resident(global_position)
	var near=global_position.distance_to(arena.camera.global_position)<300
	var finishing=bite_time>0 or attack_recovery>0 or not hold_state.is_empty()
	# An attack already holding a victim must complete before distance/stream suspension.
	runtime_active=not paused and (finishing or (resident and near))
	suspension_reason="" if runtime_active else ("paused" if paused else ("terrain" if not resident else "distance"))
	if not runtime_active:
		if manager.defeated and not hold_state.is_empty(): release_hold();bite_time=0;bite_target=null
		physics_usec=0;return
	step_behavior(delta)
	physics_usec=Time.get_ticks_usec()-began

func step_behavior(delta):
	update_settle(delta)
	if preview_mode>0:
		preview_clock+=delta
		if preview_mode>=4:
			attack_kind=preview_mode-4;attack_duration=4.0 if attack_kind==3 else 1.2
			preview_clock=fmod(preview_clock,attack_duration+.4)
			bite_time=maxf(0.0,attack_duration-preview_clock)
			attack_recovery=maxf(0.0,attack_duration+.4-preview_clock) if bite_time<=0 else 0.0
			animator.speed_scale=0;grounding.settle_weight=1.0
		elif preview_mode==3: animator.speed_scale=0;grounding.settle_weight=1.0
		else:
			animator.speed_scale=WALK_PLAYBACK_RATE
		return
	cooldown-=delta;exclude_target_time-=delta
	target_scan_timer=maxf(0.0,target_scan_timer-delta);path_timer=maxf(0.0,path_timer-delta)
	
	if exclude_target_time<=0: excluded_target=null
	if rival_time>0:
		animator.speed_scale=0;rival_time=maxf(0,rival_time-delta);velocity=Vector3.ZERO
		if not rival_hit and rival_time<=.55:
			rival_hit=true
			if is_instance_valid(rival) and global_position.distance_to(rival.global_position)<16:
				rival_hits_given+=1
				rival.take_hit(145,global_position,rival.global_position+Ring.up_at(global_position)*4)
				if sounds: sounds.bite()
		return
	if attack_recovery>0:
		attack_recovery=maxf(0.0,attack_recovery-delta);velocity=Vector3.ZERO;return
	if bite_time>0:
		if not is_instance_valid(bite_target) and not consumed:
			release_hold();bite_time=0; bite_grabbed=false;bite_debug.hide();return
		if animator: animator.speed_scale=0.0
		bite_time-=delta
		var elapsed=attack_elapsed()
		# Lift during the short lead-in, then clamp and damage at the bite midpoint.
		# This makes the grab visible instead of teleporting a victim into the air.
		if not bite_applied and elapsed>=.45:
			var lift=clampf((elapsed-.45)/.15,0.0,1.0)
			bite_target.global_position=bite_lift_origin.lerp(mouth_point()-grip_offset,lift)
		if not bite_applied and elapsed>=.6:
			bite_grabbed=true;clamp_to_mouth(bite_target);bite_event("CLAMP #%d victim=%s point=%s" % [bite_number,bite_target.name,bite_target.global_position]);bite_applied=true;apply_bite(bite_target)
		if attack_kind==3:
			if elapsed>=1.2 and not slam_started:
				slam_started=true;bite_grabbed=false;slam_origin=mouth_point();bite_event("SLAM #%d" % bite_number)
			if elapsed>=1.95 and not stomp_applied:
				stomp_applied=true
				if sounds: sounds.stomp(stomp_point)
				bite_event("STOMP #%d" % bite_number)
			if elapsed>=3.4 and not consumed: consume_victim()
		update_attack_attachment()
		if bite_time<=0:
			if attack_kind!=3: toss(bite_target)
			bite_event("RELEASE #%d applied=%s" % [bite_number,str(bite_applied)]);bite_target=null;bite_grabbed=false;bite_debug.hide();attack_recovery=.4
		snap_ground()
		velocity=Vector3.ZERO
		return
	if update_clear_emote(delta): return
	ensure_walk()
	if behavior_mode==3:
		cached_prey=null;manual_move=Vector3.ZERO;animator.speed_scale=0;return
	var prey=target() if behavior_mode!=1 else null
	if behavior_mode==1: cached_prey=null
	if behavior_mode==4:
		move_walk(manual_move,delta)
		if manual_bite and prey and bite_can_reach(prey) and cooldown<=0: begin_bite(prey)
		manual_bite=false;return
	if behavior_mode==2 and not prey: animator.speed_scale=0;return
	var target_point=prey.position if prey else patrol[waypoint]
	if not prey and authored_route:
		target_point=authored_route.step(global_position,delta,8.0)
		if authored_route.holding(): animator.speed_scale=0;velocity=Vector3.ZERO;return
	var move=(target_point-position).slide(Ring.up_at(position))
	if move.length()<8 and not prey and not authored_route:
		waypoint=(waypoint+1)%patrol.size();path_timer=0
		meeting_arrived=-1
		target_point=patrol[waypoint];move=(target_point-position).slide(Ring.up_at(position))
	move_walk(move.normalized() if move.length()>.1 else Vector3.ZERO,delta)
	if move.length()>.1:
		progress_time+=delta
		if (position-progress_position).slide(Ring.up_at(position)).length()>2.0:
			progress_position=position;progress_time=0.0
		elif progress_time>2.0:
			path.clear();path_timer=0.0;progress_time=0.0
			if not movement_blocked.is_empty():
				detour_remaining=0;escape_retry=0
				if prey:
					# Briefly give up an inaccessible victim instead of locking onto
					# its live position forever at the foot of a cliff.
					excluded_target=prey;exclude_target_time=4.0;cached_prey=null;target_scan_timer=0
			if not prey and not authored_route: waypoint=(waypoint+1)%patrol.size()
	else:
		velocity=Vector3.ZERO
		stalled_time=0.0
	# The arena terrain is a height field. Pin the predator's root to it after
	# horizontal movement so an animation or a missed floor frame cannot leave
	# the whole creature suspended above the ground.
	snap_ground()
	velocity=Vector3.ZERO
	if prey and bite_can_reach(prey) and cooldown<=0:
		begin_bite(prey)

func _process(delta):
	if health_label: health_label.visible=not arena.collision_debug.hud_hidden and not (arena.get("ai_debug") and arena.ai_debug.enabled)
	var distance=global_position.distance_to(arena.camera.global_position)
	var cast=distance<180 if not shadow_enabled else distance<200
	if cast!=shadow_enabled:
		shadow_enabled=cast
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not runtime_active: return
	animation_elapsed+=delta
	# Close combat stays at 60 Hz. Distant walking poses advance at 30/15 Hz.
	var interval=1.0/(60.0 if bite_time>0 or distance<35 else (30.0 if distance<110 else 15.0))
	if screen_size_animation:
		var focal=arena.camera.get_viewport().get_visible_rect().size.y/(2*tan(deg_to_rad(arena.camera.fov)*.5))
		var pixels=SCALE_HEIGHT*focal/maxf(distance,1)
		interval=1.0/(60.0 if bite_time>0 or pixels>80 else (30.0 if pixels>24 else 15.0))
		animation_schedule+=delta
		if animation_schedule<interval: return
		animation_schedule=fmod(animation_schedule,interval)
	elif animation_elapsed<interval: return
	var began=Time.get_ticks_usec()
	animator.advance(animation_elapsed);animation_elapsed=0
	pose_usec=Time.get_ticks_usec()-began
	# Root translation is disabled on the runtime clip, rather than overwritten
	# after rendering (which raced the animation player and caused visible snaps).
	if grounding and grounding.has_pose:
		vision_frame=Transform3D(global_basis.orthonormalized(),grounding.last_head)
	elif skeleton and head_bone>=0:
		# The displayed cone must use the same horizontal heading as can_see.
		# The asset's head-bone axes do not represent its optical forward axis.
		var head_pose=skeleton.get_bone_global_pose(head_bone)
		vision_frame=Transform3D(global_basis.orthonormalized(),skeleton.to_global(head_pose.origin))
	else:
		vision_frame=Transform3D(global_basis.orthonormalized(),to_global(Vector3(-.25,4.5,-4.5)))
	if sight:
		sight.global_transform=vision_frame

func bite_event(message: String) -> void:
	if OS.get_cmdline_user_args().has("--rex-debug"): print("REX ",message)

func telemetry() -> Dictionary:
	var victim=bite_target if is_instance_valid(bite_target) else cached_prey
	return {"position":[global_position.x,global_position.y,global_position.z],"health":health,"active":runtime_active,"suspension":suspension_reason,"bite_number":bite_number,"attack_kind":attack_kind,"bite_remaining":maxf(0,bite_time),"recovery_remaining":attack_recovery,"holding":not hold_state.is_empty(),"grabbed":bite_grabbed,"consumed":consumed,"target":str(victim.get_path()) if is_instance_valid(victim) else "","mouth_distance":(mouth_point()-victim.global_position).slide(Ring.up_at(global_position)).length() if is_instance_valid(victim) else -1,"animation":str(animator.current_animation),"animation_time":animator.current_animation_position,"animation_speed":animator.speed_scale,"movement_blocked":movement_blocked,"detour_remaining":detour_remaining,"recoveries":recovery_count,"escape_retry":escape_retry,"foliage_blocks":foliage_blocks,"foliage_depth":foliage_depth,"blocker":last_blocker,"physics_usec":physics_usec,"pose_usec":pose_usec,"size_multiplier":SIZE_MULTIPLIER}
