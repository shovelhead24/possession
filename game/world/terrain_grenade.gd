extends Node3D
## Small prototype grenade; swept collision rays, two-second fuse, terrain cut.
## No blast impulse: keep terrain-contact behaviour measurable independently.
var arena: Node3D
var velocity := Vector3.ZERO
var remaining := 2.0
var detonated := false
var resting := false
var impacts := 0
var settled_at := -1.0

static func impact_velocity(incoming: Vector3, normal: Vector3) -> Vector3:
	var normal_speed := incoming.dot(normal)
	var sideways := incoming-normal*normal_speed
	return sideways*.18-normal*minf(normal_speed,0)*.12

func _ready() -> void:
	var visual := MeshInstance3D.new();var sphere := SphereMesh.new()
	sphere.radius=.12;sphere.height=.24;visual.mesh=sphere
	var material := StandardMaterial3D.new();material.albedo_color=Color(.3,.4,.08)
	visual.material_override=material;add_child(visual)

func _physics_process(delta: float) -> void:
	if detonated: return
	remaining-=delta
	if resting:
		var support := PhysicsRayQueryParameters3D.create(position+Vector3.UP*.02,position-Vector3.UP*.25,3)
		support.exclude=[arena.player.get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(support).is_empty(): resting=false
	if not resting:
		velocity.y-=9.8*delta
		var next := position+velocity*delta
		var query := PhysicsRayQueryParameters3D.create(position,next,3)
		query.exclude=[arena.player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			position=hit.position+hit.normal*.13
			velocity=impact_velocity(velocity,hit.normal);impacts+=1
			if hit.normal.y>.45 and velocity.length()<1.2:
				velocity=Vector3.ZERO;resting=true;settled_at=2.0-remaining
		else: position=next
	if remaining<=0:
		detonated=true
		# Place the subtractive sphere slightly above the grenade: shallow crater.
		var accepted: bool=arena.request_crater(position+Vector3.UP*.8,2.0)
		if not accepted: push_warning("Grenade crater not accepted: terrain/volume boundary or edit queue limit")
		var flash := MeshInstance3D.new();var sphere := SphereMesh.new();sphere.radius=1;sphere.height=2;flash.mesh=sphere
		var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(1,.65,.15)
		flash.material_override=material;arena.add_child(flash);flash.position=position
		get_tree().create_timer(.08).timeout.connect(flash.queue_free)
		queue_free()
