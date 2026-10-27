extends Node3D
## Swept impact projectile. Terrain edits never suspend flight or blast props.
const Ring=preload("res://world/terrain_drive_ring.gd")
const SPEED := 55.0
const BLAST_RADIUS := 10.0
const CRATER_RADIUS := 3.0
static var launch_sound: AudioStreamWAV
static var explosion_sound: AudioStreamWAV
var weapon: Node
var velocity := Vector3.ZERO
var origin := Vector3.ZERO
func origin_shifted(delta: Vector3):origin-=delta
var remaining := 350.0
var damage := 220.0
var first_sweep := true
var detonated := false

func _ready() -> void:
	add_to_group("explosive_rockets")
	var visual=MeshInstance3D.new();var mesh=CapsuleMesh.new();mesh.radius=.07;mesh.height=.5;mesh.radial_segments=8;mesh.rings=2;visual.mesh=mesh
	var mat=StandardMaterial3D.new();mat.albedo_color=Color(.23,.25,.18);visual.material_override=mat
	visual.rotation.x=PI*.5;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual)
	var flame=MeshInstance3D.new();var ball=SphereMesh.new();ball.radius=.10;ball.height=.5;ball.radial_segments=8;ball.rings=4;flame.mesh=ball
	var glow=StandardMaterial3D.new();glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;glow.albedo_color=Color(1,.55,.08);flame.material_override=glow
	flame.rotation.x=PI*.5;flame.position.z=.35;flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(flame)

func _physics_process(delta: float) -> void:
	if detonated: return
	if not is_instance_valid(weapon): queue_free();return
	var travel=minf(SPEED*delta,remaining)
	var direction=velocity.normalized();var next=global_position+direction*travel
	# Include camera-to-muzzle space so a nearby wall cannot be fired through.
	var hit: Dictionary=weapon.trace_segment(origin if first_sweep else global_position,next)
	first_sweep=false
	if not hit.is_empty():
		global_position=hit.position;detonate(hit);return
	global_position=next;remaining-=travel
	var up=Ring.up_at(global_position)
	if absf(direction.dot(up))>.99: up=Vector3.RIGHT if absf(direction.x)<.9 else Vector3.FORWARD
	global_basis=Basis.looking_at(direction,up)
	if remaining<=0: queue_free()

func detonate(hit: Dictionary) -> void:
	if detonated: return
	detonated=true
	var arena: Node3D=weapon.arena
	var up=Ring.up_at(global_position)
	var normal: Vector3=hit.get("normal",up)
	var blast_point=global_position+normal*.2
	var direct: Node3D
	if arena.has_method("performance_features"):
		direct=preload("res://world/weapon_aim.gd").new().enemy(hit.get("collider"),arena)
		if direct: direct.take_hit(damage,origin,global_position)
	preload("res://world/prop_blast.gd").apply(self,blast_point,BLAST_RADIUS,3200.0)
	if arena.get("aliens"):
		var manager: Node=arena.aliens
		var targets: Array=manager.enemies.duplicate()
		for rex in get_tree().get_nodes_in_group("tyrants"): targets.append(rex)
		if manager.target(): targets.append(manager.target())
		for unit in targets:
			if not is_instance_valid(unit) or unit==direct: continue
			var point: Vector3=unit.global_position+Ring.up_at(unit.global_position)*.6
			var distance=point.distance_to(blast_point)
			if distance>=BLAST_RADIUS: continue
			var ray=PhysicsRayQueryParameters3D.create(blast_point,point,7)
			var obstruction=get_world_3d().direct_space_state.intersect_ray(ray)
			if not obstruction.is_empty() and obstruction.collider!=unit: continue
			var amount=damage*(1-distance/BLAST_RADIUS)
			if manager.is_target(unit): manager.hurt(amount)
			elif unit.has_method("take_hit") and unit.get("dead")!=true: unit.take_hit(amount,origin,point)
		manager.alert_shot(blast_point)
	weapon.last_hit=hit
	if not arena.request_crater(global_position+normal*.6,CRATER_RADIUS):
		weapon.notice="Blast hit; crater unavailable outside loaded terrain or while queue is full";weapon.notice_time=2
	var flash=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.4;sphere.height=.8;sphere.radial_segments=12;sphere.rings=6;flash.mesh=sphere
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(1,.5,.08);flash.material_override=mat
	if arena.has_method("performance_features"): mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.albedo_color.a=.65
	flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;arena.add_child(flash);flash.global_position=blast_point
	var tween=flash.create_tween();tween.tween_property(flash,"scale",Vector3.ONE*7,.09);tween.tween_property(flash,"scale",Vector3.ZERO,.3);tween.tween_callback(flash.queue_free)
	var audio=AudioStreamPlayer3D.new();audio.stream=sound(true);audio.volume_db=-10;audio.unit_size=15;audio.max_distance=180;arena.add_child(audio);audio.global_position=blast_point
	audio.finished.connect(audio.queue_free)
	audio.play();queue_free()

static func sound(explosion: bool) -> AudioStreamWAV:
	if explosion and explosion_sound: return explosion_sound
	if not explosion and launch_sound: return launch_sound
	var stream=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=16000
	var duration=.55 if explosion else .2
	var data=PackedByteArray();var count=int(duration*stream.mix_rate);data.resize(count*2)
	var rng=RandomNumberGenerator.new();rng.seed=187
	var smooth=0.0
	for i in count:
		var t=float(i)/count;var time=float(i)/stream.mix_rate
		smooth=lerpf(smooth,rng.randf_range(-1,1),.25)
		var sample=(smooth*.7+sin(TAU*(65*time-20*time*time))*.3)*pow(1-t,2)*minf(time*250,1)
		data.encode_u16(i*2,int(clampf(sample,-1,1)*24000)&65535)
	stream.data=data
	if explosion: explosion_sound=stream
	else: launch_sound=stream
	return stream
