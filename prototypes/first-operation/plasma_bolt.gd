extends Node3D
var velocity := Vector3.ZERO
var damage := 25.0
var source := Vector3.ZERO
var excluded: Array[RID] = []
var enemy_shot := false
var manager: Node
var remaining := 250.0
var spent := false

func _ready() -> void:
	add_to_group("plasma_bolts")
	var color=Color(.12,1,.65) if enemy_shot else Color(.5,.25,1)
	for outer in [true,false]:
		var mesh=MeshInstance3D.new();var capsule=CapsuleMesh.new();capsule.radius=.05 if outer else .018;capsule.height=.38 if outer else .28;capsule.radial_segments=8;capsule.rings=3;mesh.mesh=capsule;mesh.rotation.x=PI/2;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=color if outer else Color(.9,1,.95);mat.emission_enabled=true;mat.emission=mat.albedo_color;mat.emission_energy_multiplier=2
		if outer: mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD;mat.albedo_color.a=.3
		mesh.material_override=mat;add_child(mesh)
	if velocity.length()>0: look_at(global_position+velocity,Vector3.UP)

func _physics_process(delta: float) -> void:
	if spent: return
	if is_instance_valid(manager) and manager.arena.kit.menu.opened: return
	var step=velocity*delta
	if step.length()>remaining: step=step.normalized()*remaining
	var ray=PhysicsRayQueryParameters3D.create(global_position,global_position+step);ray.exclude=excluded
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		spent=true;global_position=hit.position
		if enemy_shot:
			if is_instance_valid(manager) and hit.collider==manager.arena.walker: manager.hurt(int(damage))
		elif hit.collider.has_method("take_hit"):
			var result=hit.collider.take_hit(damage,source,hit.position)
			if is_instance_valid(manager): manager.arena.kit.status.text="PLASMA / "+result
		elif hit.collider.has_meta("target_hits"): hit.collider.set_meta("target_hits",int(hit.collider.get_meta("target_hits"))+1)
		var tween=create_tween();tween.tween_property(self,"scale",Vector3.ONE*2,.06);tween.tween_property(self,"scale",Vector3.ZERO,.1);tween.tween_callback(queue_free)
		return
	global_position+=step;remaining-=step.length()
	if remaining<=0: queue_free()
