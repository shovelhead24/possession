extends Node3D
const FUSE_SECONDS := 2.0
const THROW_SPEED := 16.0
const LIFT_SPEED := 3.0
const GRAVITY := 9.8
const CRATER_RADIUS := 2.0

static func preparation_reach(inherited_speed: float) -> float:
	# Triangle-inequality bound covers every aim direction, drop, inherited
	# vehicle velocity and a margin for the launch offset, crater and mesh seams.
	return (THROW_SPEED+LIFT_SPEED+inherited_speed)*FUSE_SECONDS+0.5*GRAVITY*FUSE_SECONDS*FUSE_SECONDS+8.0
## Small prototype grenade; swept collision rays, two-second fuse, terrain cut.
## Rebuild movable crates receive blast impulse; terrain behavior is unchanged.
var arena: Node3D
var radial_gravity := false
var excluded_bodies: Array[RID]=[]

func up_direction() -> Vector3:
	return preload("res://world/terrain_drive_ring.gd").up_at(global_position) if radial_gravity else Vector3.UP
var velocity := Vector3.ZERO
var remaining := FUSE_SECONDS
var detonated := false
var resting := false
var impacts := 0
var settled_at := -1.0

static func impact_velocity(incoming: Vector3, normal: Vector3) -> Vector3:
	var normal_speed := incoming.dot(normal)
	var sideways := incoming-normal*normal_speed
	return sideways*.18-normal*minf(normal_speed,0)*.12

func _ready() -> void:
	# Elite enemies use this shared group to dodge live explosive threats.
	add_to_group("dive_grenades")
	var visual := MeshInstance3D.new();var sphere := SphereMesh.new()
	sphere.radius=.12;sphere.height=.24;visual.mesh=sphere
	var material := StandardMaterial3D.new();material.albedo_color=Color(.3,.4,.08)
	visual.material_override=material;add_child(visual)

func _physics_process(delta: float) -> void:
	if detonated: return
	remaining-=delta
	var up := up_direction()
	if resting:
		var support := PhysicsRayQueryParameters3D.create(position+up*.02,position-up*.25,3)
		support.exclude=excluded_bodies
		if not radial_gravity: support.exclude=[arena.player.get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(support).is_empty(): resting=false
	if not resting:
		velocity-=up*GRAVITY*delta
		var next := position+velocity*delta
		var query := PhysicsRayQueryParameters3D.create(position,next,3)
		query.exclude=excluded_bodies
		if not radial_gravity: query.exclude=[arena.player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			position=hit.position+hit.normal*.13
			velocity=impact_velocity(velocity,hit.normal);impacts+=1
			if hit.normal.dot(up)>.45 and velocity.length()<1.2:
				velocity=Vector3.ZERO;resting=true;settled_at=FUSE_SECONDS-remaining
		else: position=next
	if remaining<=0:
		detonated=true
		preload("res://world/prop_blast.gd").apply(self,global_position)
		# Place the subtractive sphere slightly above the grenade: shallow crater.
		var accepted: bool=arena.request_crater(position+up*.8,CRATER_RADIUS)
		if not accepted: push_warning("Grenade crater not accepted: terrain/volume boundary or edit queue limit")
		var flash := MeshInstance3D.new();var sphere := SphereMesh.new();sphere.radius=1;sphere.height=2;flash.mesh=sphere
		var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(1,.65,.15)
		if arena.has_method("performance_features"): material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color.a=.65
		flash.material_override=material;arena.add_child(flash);flash.position=position
		get_tree().create_timer(.08).timeout.connect(flash.queue_free)
		queue_free()
