extends Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var muzzle: BoneAttachment3D
var clips := {}
var firing := 0.0
var dying := false
func _ready() -> void:
	var doc=GLTFDocument.new();var state=GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path("res://lizard_rig.glb"),state)!=OK: push_error("Lizard model unavailable");return
	var model=doc.generate_scene(state);model.rotation.y=PI;add_child(model)
	var stack=[model]
	while not stack.is_empty():
		var n=stack.pop_back()
		if n is AnimationPlayer: player=n
		if n is Skeleton3D: skeleton=n
		for child in n.get_children(): stack.append(child)
	if player:
		for key in player.get_animation_list():
			for name in ["Idle","Run","Fire","Death"]:
				if name.to_lower() in key.to_lower():
					clips[name]=key
					if name in ["Idle","Run"]: player.get_animation(key).loop_mode=Animation.LOOP_LINEAR
		play("Idle")
	if skeleton:
		muzzle=BoneAttachment3D.new();muzzle.bone_name="Muzzle";skeleton.add_child(muzzle)
func play(clip: String) -> void:
	if player and clips.has(clip) and player.current_animation!=clips[clip]: player.play(clips[clip],.1)
func animate(speed: float,delta: float) -> void:
	if dying: return
	firing=maxf(0,firing-delta)
	play("Fire" if firing>0 else ("Run" if speed>.15 else "Idle"))
func fire() -> void:
	firing=.4
	if player and clips.has("Fire"): player.stop();play("Fire")
func die() -> void:
	dying=true;play("Death")
func muzzle_position() -> Vector3:
	return muzzle.global_position if muzzle else global_position+Vector3.UP*.8
