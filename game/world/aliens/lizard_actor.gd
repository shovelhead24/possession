extends Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var muzzle: BoneAttachment3D
var clips := {}
var firing := 0.0
var dying := false
var death_at := 0
var elite := false
var ragdoll: PhysicalBoneSimulator3D
var weapons: Array[MeshInstance3D]=[]
var body_mesh: MeshInstance3D
var fleeing := false
var shadow_enabled := true
var animation_usec := 0
var animation_updates := 0
var animation_elapsed := 0.0
static var cached_scenes: Dictionary={}
func _ready() -> void:
	var size_factor=scale.x
	if not cached_scenes.has(size_factor):
		var doc=GLTFDocument.new();var state=GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path("res://../prototypes/first-operation/lizard_rig.glb"),state)!=OK: push_error("Lizard model unavailable");return
		var source=doc.generate_scene(state);preload("res://world/aliens/rig_scale_bake.gd").apply(source,size_factor)
		preload("res://world/aliens/batch_rifle.gd").apply(source)
		var packed=PackedScene.new();packed.pack(source);cached_scenes[size_factor]=packed;source.free()
	var model=cached_scenes[size_factor].instantiate();model.rotation.y=PI;model.scale=Vector3.ONE/size_factor;add_child(model)
	var stack=[model]
	while not stack.is_empty():
		var n=stack.pop_back()
		if n is AnimationPlayer: player=n
		if n is Skeleton3D: skeleton=n
		if n is MeshInstance3D:
			n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.visibility_range_end=190
			if "LizardSkin" in String(n.name):
				body_mesh=n;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				if elite:
					var original=n.mesh.surface_get_material(0)
					var mat=ShaderMaterial.new();mat.shader=preload("res://world/aliens/elite_skin.gdshader");mat.set_shader_parameter("skin_texture",original.albedo_texture);mat.set_shader_parameter("skin_normal",original.normal_texture);n.material_override=mat
			else: weapons.append(n)
		for child in n.get_children(): stack.append(child)
	if player:
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		animation_elapsed=randf()*.04 # Spread distant pose updates across frames.
		for key in player.get_animation_list():
			for name in ["Idle","Run","Fire","Death","Flee","Walk","Strafe","Jump","Crouch","Dive","Check","Scratch","Look","Talk"]:
				if name.to_lower()==String(key).get_slice("/",String(key).get_slice_count("/")-1).to_lower():
					clips[name]=key
					if name not in ["Fire","Death","Dive","Jump"]: player.get_animation(key).loop_mode=Animation.LOOP_LINEAR
		play("Idle")
	if skeleton:
		muzzle=BoneAttachment3D.new();muzzle.bone_name="Muzzle";skeleton.add_child(muzzle)

func _process(delta: float) -> void:
	if dying or not visible or not player or not player.is_playing(): return
	if get_parent().get("manager") and get_parent().manager.paused(): return
	animation_elapsed+=delta
	var camera=get_viewport().get_camera_3d()
	var distance=camera.global_position.distance_to(global_position) if camera else 0.0
	var interval=1.0/(60.0 if distance<18 else (30.0 if distance<45 else (15.0 if distance<110 else 8.0)))
	if animation_elapsed>=interval:
		var began=Time.get_ticks_usec()
		player.advance(animation_elapsed);animation_elapsed=0.0
		animation_usec+=Time.get_ticks_usec()-began;animation_updates+=1
func play(clip: String) -> void:
	if player and clips.has(clip) and player.current_animation!=clips[clip]: player.play(clips[clip],.1)
func animate(speed: float,delta: float) -> void:
	if dying: return
	firing=maxf(0,firing-delta)
	play("Fire" if firing>0 else ("Run" if speed>.15 else "Idle"))
func animate_state(clip: String,delta: float) -> void:
	if dying: return
	firing=maxf(0,firing-delta);play("Fire" if firing>0 and clip not in ["Flee","Dive","Jump"] else clip)
func set_fleeing(value: bool) -> void:
	if value==fleeing: return
	fleeing=value
	for weapon in weapons: weapon.visible=not value
func fire() -> void:
	firing=.4
	if player and clips.has("Fire"): player.stop();play("Fire")
func die(velocity: Vector3=Vector3.ZERO,impulse: Vector3=Vector3.FORWARD*2) -> void:
	if dying: return
	dying=true;death_at=Time.get_ticks_msec()
	if player: player.pause()
	set_fleeing(true)
	if skeleton: ragdoll=preload("res://world/aliens/lizard_ragdoll.gd").start(skeleton,velocity,impulse)
func toss(velocity: Vector3,impulse: Vector3,ignored_body: PhysicsBody3D=null) -> void:
	if dying or not skeleton: return
	dying=true;death_at=Time.get_ticks_msec()
	if player: player.pause()
	ragdoll=preload("res://world/aliens/lizard_ragdoll.gd").start(skeleton,velocity,impulse)
	if ignored_body:
		for bone in ragdoll.get_children():
			if bone is PhysicsBody3D: bone.add_collision_exception_with(ignored_body);ignored_body.add_collision_exception_with(bone)
	get_tree().create_timer(.8).timeout.connect(recover_from_toss)
func recover_from_toss() -> void:
	if not is_instance_valid(self) or not ragdoll: return
	ragdoll.physical_bones_stop_simulation();ragdoll.queue_free();ragdoll=null
	for node in skeleton.get_children():
		if node.name=="RagdollProportions": node.queue_free()
	skeleton.reset_bone_poses();dying=false
	if player: player.play(clips.get("Idle","") as String)
func muzzle_position() -> Vector3:
	return muzzle.global_position if muzzle else global_position+Vector3.UP*.8

func settle_ragdoll() -> void:
	if not is_instance_valid(ragdoll): return
	# Modifier poses are temporary. Capture physical bone transforms instead of
	# the animation pose that Skeleton3D restores after its modifier pass.
	var globals: Dictionary={}
	for bone in ragdoll.get_children():
		var index=skeleton.find_bone(bone.bone_name)
		globals[index]=skeleton.global_transform.affine_inverse()*bone.global_transform*bone.body_offset.affine_inverse()
	var poses: Array=[]
	for i in skeleton.get_bone_count():
		var pose=skeleton.get_bone_pose(i)
		if globals.has(i):
			var parent=skeleton.get_bone_parent(i)
			var parent_pose=globals.get(parent,skeleton.get_bone_global_pose(parent)) if parent>=0 else Transform3D.IDENTITY
			pose=parent_pose.affine_inverse()*globals[i]
			pose.basis=pose.basis.orthonormalized()
			if String(skeleton.get_bone_name(i)) not in ["Root","Pelvis"]: pose.origin=skeleton.get_bone_rest(i).origin
		poses.append(pose)
	ragdoll.physical_bones_stop_simulation();ragdoll.queue_free();ragdoll=null
	for node in skeleton.get_children():
		if node.name=="RagdollProportions": node.active=false;node.queue_free()
	for i in skeleton.get_bone_count(): skeleton.set_bone_pose(i,poses[i])
	# A simultaneous burst can exceed the physics cap before an older body falls.
	# Use the authored death pose in that case, avoiding upright frozen corpses.
	if Time.get_ticks_msec()-death_at<400 and player and clips.has("Death"):
		player.play(clips["Death"]);player.advance(player.get_animation(clips["Death"]).length);player.pause()
	set_process(false)

func update_shadow(camera_position: Vector3) -> void:
	# Hysteresis avoids toggling a caster repeatedly at the distance threshold.
	var distance=global_position.distance_squared_to(camera_position)
	var wanted=distance<(75.0*75.0 if shadow_enabled else 65.0*65.0)
	if wanted==shadow_enabled: return
	shadow_enabled=wanted
	if body_mesh: body_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if wanted else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
