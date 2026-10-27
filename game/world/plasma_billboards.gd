extends Node3D
## Bounded swept projectiles with batched billboard presentation.
const LIMIT := 32
var weapon: Node
var bolts: Array=[]
var bursts: Array=[]
var batch: MultiMeshInstance3D
var muzzle: Sprite2D
var material: ShaderMaterial
var flash := 0.0
func setup(owner_weapon: Node) -> void:
	weapon=owner_weapon
	material=ShaderMaterial.new();material.shader=load("res://effects/plasma/blob.gdshader")
	material.set_shader_parameter("plasma_texture",load("res://effects/plasma/plasma rifle contrail.png"))
	batch=MultiMeshInstance3D.new();batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.use_colors=true
	var quad := QuadMesh.new();quad.size=Vector2.ONE;batch.multimesh.mesh=quad;batch.multimesh.instance_count=LIMIT*4+24
	batch.multimesh.visible_instance_count=0;batch.material_override=material;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;add_child(batch)
	muzzle=Sprite2D.new();muzzle.texture=load("res://effects/plasma/plasma rifle contrail.png")
	var flash_material := ShaderMaterial.new();flash_material.shader=load("res://effects/plasma/muzzle.gdshader")
	muzzle.material=flash_material;weapon.container.get_parent().add_child(muzzle)
	muzzle.hide();set_process(false);set_physics_process(false)
func warmup() -> void:
	muzzle.show();muzzle.scale=Vector2.ONE*.001
	instance_at(0,weapon.arena.camera.global_position-weapon.arena.camera.global_basis.z*2,.001,.001)
	batch.multimesh.visible_instance_count=1;weapon.view.render_target_update_mode=SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	muzzle.hide();batch.multimesh.visible_instance_count=0
	weapon.view.render_target_update_mode=SubViewport.UPDATE_DISABLED
func launch(start: Vector3, direction: Vector3, distance: float, damage: float, origin: Vector3) -> bool:
	if bolts.size()>=LIMIT: return false
	bolts.append({"point":start,"previous":start,"start":start,"direction":direction,"remaining":distance,"damage":damage,"origin":origin,"spawn":true})
	flash=.085;set_process(true);set_physics_process(true)
	return true
func _physics_process(delta: float) -> void:
	var live := []
	for bolt in bolts:
		var travel: float=minf(85.0*delta,bolt.remaining)
		var end: Vector3=bolt.point+bolt.direction*travel
		# First sweep includes camera-to-muzzle space, preventing wall penetration at spawn.
		var start: Vector3=bolt.origin if bolt.spawn else bolt.point
		var hit: Dictionary=weapon.trace_segment(start,end)
		bolt.spawn=false;bolt.previous=bolt.point
		if not hit.is_empty():
			weapon.apply_hit(hit,bolt.damage,bolt.origin)
			bursts.append({"point":hit.position,"age":0.0})
			if bursts.size()>8: bursts.pop_front()
			continue
		bolt.point=end;bolt.remaining-=travel
		if bolt.remaining>0: live.append(bolt)
	bolts=live
	if bolts.is_empty(): set_physics_process(false)
func instance_at(index: int, point: Vector3, size: float, opacity: float) -> void:
	batch.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),batch.to_local(point)))
	batch.multimesh.set_instance_color(index,Color(1,1,1,opacity))
func _process(delta: float) -> void:
	flash=maxf(0,flash-delta)
	muzzle.visible=flash>0 and weapon.selected>=2 and weapon.view_active
	if muzzle.visible:
		var camera: Camera3D=weapon.holder.get_parent()
		muzzle.position=camera.unproject_position(weapon.holder.global_transform*Vector3(-.08,.07,-.32))+weapon.container.position
		var size: float=weapon.view.size.y*(.10+.07*flash/.085)
		muzzle.scale=Vector2(size/muzzle.texture.get_width(),size/muzzle.texture.get_height())
	for burst in bursts: burst.age+=delta
	bursts=bursts.filter(func(b): return b.age<.22)
	var count := 0
	for bolt in bolts:
		for trail in 4:
			var point: Vector3=bolt.previous.lerp(bolt.point,Engine.get_physics_interpolation_fraction())
			point-=bolt.direction*minf(trail*.35,maxf(0,(point-bolt.start).dot(bolt.direction)))
			instance_at(count,point,.24-trail*.035,1.0-trail*.2);count+=1
	for burst in bursts:
		var t: float=burst.age/.22
		instance_at(count,burst.point,.35+t*.65,(1-t)*.9);count+=1
		for i in 2:
			var offset: Vector3=weapon.arena.camera.global_basis.x*(float(i)*2-1)*t*.25+weapon.arena.camera.global_basis.y*t*.16
			instance_at(count,burst.point+offset,.15+t*.2,(1-t)*.6);count+=1
	batch.multimesh.visible_instance_count=count
	if bolts.is_empty() and bursts.is_empty() and flash<=0: set_process(false)
func _exit_tree() -> void:
	if is_instance_valid(muzzle): muzzle.queue_free()

func origin_shifted(delta: Vector3) -> void:
	for bolt in bolts:
		for key in ["point","previous","start","origin"]:bolt[key]-=delta
	for burst in bursts:burst.point-=delta
	# This is a world-coordinate batch, not an object anchored at its old location.
	batch.global_transform=Transform3D.IDENTITY
	_process(0.0)
