extends Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var muzzle: BoneAttachment3D
var clips := {}
var firing := 0.0
var dying := false
var elite := false
var ragdoll: PhysicalBoneSimulator3D
var weapons: Array[MeshInstance3D]=[]
static var cached_scenes: Dictionary={}
func _ready() -> void:
	var size_factor=scale.x
	if not cached_scenes.has(size_factor):
		var doc=GLTFDocument.new();var state=GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path("res://lizard_rig.glb"),state)!=OK: push_error("Lizard model unavailable");return
		var source=doc.generate_scene(state);preload("res://rig_scale_bake.gd").apply(source,size_factor)
		var packed=PackedScene.new();packed.pack(source);cached_scenes[size_factor]=packed;source.free()
	var model=cached_scenes[size_factor].instantiate();model.rotation.y=PI;model.scale=Vector3.ONE/size_factor;add_child(model)
	var stack=[model]
	while not stack.is_empty():
		var n=stack.pop_back()
		if n is AnimationPlayer: player=n
		if n is Skeleton3D: skeleton=n
		if n is MeshInstance3D:
			if "LizardSkin" in String(n.name):
				if elite:
					var original=n.mesh.surface_get_material(0)
					var mat=ShaderMaterial.new();mat.shader=preload("res://elite_skin.gdshader");mat.set_shader_parameter("skin_texture",original.albedo_texture);mat.set_shader_parameter("skin_normal",original.normal_texture);n.material_override=mat
			else: weapons.append(n)
		for child in n.get_children(): stack.append(child)
	if player:
		for key in player.get_animation_list():
			for name in ["Idle","Run","Fire","Death","Flee","Walk","Strafe","Jump","Crouch","Dive","Check","Scratch","Look","Talk"]:
				if name.to_lower()==String(key).get_slice("/",String(key).get_slice_count("/")-1).to_lower():
					clips[name]=key
					if name not in ["Fire","Death","Dive","Jump"]: player.get_animation(key).loop_mode=Animation.LOOP_LINEAR
		play("Idle")
	if skeleton:
		muzzle=BoneAttachment3D.new();muzzle.bone_name="Muzzle";skeleton.add_child(muzzle)
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
	for weapon in weapons: weapon.visible=not value
func fire() -> void:
	firing=.4
	if player and clips.has("Fire"): player.stop();play("Fire")
func die(velocity: Vector3=Vector3.ZERO,impulse: Vector3=Vector3.FORWARD*2) -> void:
	if dying: return
	dying=true
	if player: player.pause()
	set_fleeing(true)
	if skeleton: ragdoll=preload("res://lizard_ragdoll.gd").start(skeleton,velocity,impulse)
func muzzle_position() -> Vector3:
	return muzzle.global_position if muzzle else global_position+Vector3.UP*.8
