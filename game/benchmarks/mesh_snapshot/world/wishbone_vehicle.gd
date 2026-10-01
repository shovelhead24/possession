extends RigidBody3D
const Linkage=preload("res://benchmarks/mesh_snapshot/world/wishbone.gd")
var spring_rate := 28000.0
var damping := 2300.0
var travel_limit := .28
var grip := 1.15
var steer_max := 31.5127
var steer_fast := 11.4592
var steer_rate := 1.8
var engine_force := 1800.0
var top_speed := 24.0
var brake_strength := 950.0
var front_power_percent := 50.0
var front_brake_percent := 50.0
var controlled := false
var suspension_exclusions: Array[RID]=[]
var balanced_braking := false
var reverse_engaged := false
var streaming_suspended := false
var stream_velocity := Vector3.ZERO
var stream_angular := Vector3.ZERO
var forces_applied := 0
var stream_speed_limit := INF
var stream_braking := false

func set_stream_ready(value: bool) -> void:
	if streaming_suspended == not value: return
	streaming_suspended=not value
	if not value:
		stream_velocity=linear_velocity;stream_angular=angular_velocity
		freeze=true
	else:
		freeze=false;linear_velocity=stream_velocity;angular_velocity=stream_angular
		sleeping=false

func driver_controls(gas: bool, stop_reverse: bool, biased_stop: bool, steer: float) -> void:
	if gas: reverse_engaged=false
	if stop_reverse and not reverse_engaged:
		var stopped=true
		for c in corners:
			if absf(c.get("omega",0.0))>.2: stopped=false
		if stopped: reverse_engaged=true
	balanced_braking=stop_reverse and not reverse_engaged
	set_controls(1.0 if gas else (-1.0 if stop_reverse and reverse_engaged else 0.0),steer,biased_stop or balanced_braking)
var track_extension := 0.0
var wheel_mount_raise := 0.0
var throttle := 0.0
var turn := 0.0
var braking := false
var steering := 0.0
var corners: Array[Dictionary] = []
var shell: Node3D
var inspection := false
var grounded_count := 0
var max_compression := 0.0
var velocity: Vector3:
	get: return linear_velocity
	set(value): linear_velocity=value
var metal: StandardMaterial3D
var spring_mat: StandardMaterial3D
var rest_hub: Vector2=Linkage.solve(0).hub

func _ready() -> void:
	mass=800
	center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass=Vector3(0,.6,0)
	linear_damp=.08;angular_damp=.65
	continuous_cd=true
	can_sleep=false
	metal=StandardMaterial3D.new();metal.albedo_color=Color(.38,.4,.43);metal.metallic=.65;metal.roughness=.5
	spring_mat=StandardMaterial3D.new();spring_mat.albedo_color=Color(.58,.25,.85)

func setup(model: Node3D, source_bounds: Callable) -> void:
	shell=model
	# Reuse each original wheel once; outer Wheel1..Wheel4 nodes own the visible meshes.
	var stack: Array[Node]=[model]
	var candidates: Array[Node3D]=[]
	while not stack.is_empty():
		var node=stack.pop_back()
		var label=String(node.name).to_lower()
		var tyre_children := false
		for child in node.get_children():
			if child is MeshInstance3D and String(child.name).to_lower().begins_with("wheel"): tyre_children=true
		if label.begins_with("wheel") and node is Node3D and (node is MeshInstance3D or tyre_children):
			candidates.append(node);continue
		for child in node.get_children(): stack.append(child)
	for node in candidates:
		var local: AABB=source_bounds.call(node)
		# source_bounds includes node.transform; parent global transform completes the chain.
		var world: AABB=node.get_parent().global_transform*local
		var box: AABB=global_transform.affine_inverse()*world
		if box.size.length()<.1: continue
		var centre := box.get_center()
		var radius := maxf(box.size.y,box.size.z)*.5
		var side := signf(centre.x)
		var anchor := Vector3(centre.x-side*rest_hub.x,centre.y-rest_hub.y,centre.z)
		anchor.x+=side*track_extension
		anchor.y+=wheel_mount_raise
		var hub=Node3D.new();add_child(hub);hub.position=centre
		var spin=Node3D.new();hub.add_child(spin)
		var old_parent=node.get_parent()
		node.reparent(spin,true)
		if old_parent is Node3D and String(old_parent.name).to_lower().begins_with("wheel"):
			old_parent.hide() # original static struts are replaced by the articulated arms
		var links: Array[MeshInstance3D]=[]
		for i in range(7):
			var mesh=MeshInstance3D.new();var cylinder=CylinderMesh.new();cylinder.top_radius=.035 if i<5 else .055;cylinder.bottom_radius=cylinder.top_radius;cylinder.height=1;cylinder.radial_segments=8;mesh.mesh=cylinder;mesh.material_override=metal if i<5 else spring_mat;add_child(mesh);links.append(mesh)
		var coil=MeshInstance3D.new();var helix=ImmediateMesh.new();helix.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for k in range(121):
			var t=k/120.0;helix.surface_add_vertex(Vector3(cos(t*TAU*10)*.095,t-.5,sin(t*TAU*10)*.095))
		helix.surface_end();coil.mesh=helix;coil.material_override=spring_mat;add_child(coil);links.append(coil)
		corners.append({"anchor":anchor,"side":side,"radius":radius,"hub":hub,"spin":spin,"links":links,"front":centre.z<0,"travel":0.0,"compression":0.0})
		# Render a substantial chassis bracket and crossmember around the unchanged hardpoints.
		for pair in [[Vector3(0,anchor.y,anchor.z),anchor], [anchor,Vector3(side*.60,.8,anchor.z)]]:
			var brace=MeshInstance3D.new();var shape=CylinderMesh.new();shape.top_radius=.09;shape.bottom_radius=.09;shape.height=1;shape.radial_segments=6;brace.mesh=shape;brace.material_override=metal;add_child(brace);rod(brace,pair[0],pair[1])
		for i in range(4): links[i].mesh.top_radius=.075;links[i].mesh.bottom_radius=.075
		links[5].material_override=metal;links[6].material_override=metal
		coil.visible=inspection
	print("WISHBONE_READY: %d original wheels attached" % corners.size())
	assert(corners.size()==4,"Expected exactly four source wheel assemblies")

func set_controls(gas: float, steer: float, stop: bool) -> void:
	throttle=gas;turn=steer;braking=stop

func toggle_inspection() -> void:
	inspection=not inspection
	if shell: shell.visible=not inspection
	for c in corners: c.links[7].visible=inspection

func rod(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var delta=b-a
	mesh.position=(a+b)*.5
	mesh.basis=Basis(Quaternion(Vector3.UP,delta.normalized())).scaled(Vector3(1,delta.length(),1))

func point(anchor: Vector3, xy: Vector2, side: float) -> Vector3:
	return anchor+Vector3(xy.x*side,xy.y,0)

func _physics_process(dt: float) -> void:
	# Frozen bodies must not accumulate suspension/tyre forces while collision loads.
	if freeze or streaming_suspended: return
	if corners.is_empty(): return
	var up=global_basis.y.normalized()
	var steer_limit=deg_to_rad(lerpf(steer_max,minf(steer_fast,steer_max),clampf(linear_velocity.length()/25,0,1)))
	steering=move_toward(steering,turn*steer_limit,dt*steer_rate)
	grounded_count=0;max_compression=0
	var space=get_world_3d().direct_space_state
	for c in corners:
		var anchor: Vector3=c.anchor
		var side: float=c.side
		var radius: float=c.radius
		var droop: Dictionary=Linkage.solve(-travel_limit)
		var bump: Dictionary=Linkage.solve(travel_limit)
		var geom: Dictionary=Linkage.solve(c.travel)
		var origin=to_global(point(anchor,Vector2(geom.hub.x,bump.hub.y+.12),side))
		var ray=PhysicsRayQueryParameters3D.create(origin,origin-up*(bump.hub.y-droop.hub.y+radius+.18))
		ray.exclude=[get_rid()]
		ray.exclude+=suspension_exclusions
		ray.collision_mask=1|4
		var hit=space.intersect_ray(ray)
		c.grounded=false
		var compression:=0.0
		if not hit.is_empty() and hit.normal.dot(up)>.25:
			var target_y=to_local(hit.position+up*radius).y-anchor.y
			geom=Linkage.at_height(clampf(target_y,droop.hub.y,bump.hub.y))
			compression=maxf(0,geom.hub.y-droop.hub.y)
			var lever: Vector3=hit.position-global_position
			var contact_v=linear_velocity+angular_velocity.cross(lever-global_basis*center_of_mass)
			var load=clampf(compression*spring_rate-contact_v.dot(up)*damping,0,18000)
			if target_y>bump.hub.y: load+=minf((target_y-bump.hub.y)*60000,12000)
			apply_force(up*load,lever)
			forces_applied+=1
			var forward=-global_basis.z
			if c.front: forward=forward.rotated(up,steering)
			forward=forward.slide(hit.normal).normalized()
			var right=forward.cross(hit.normal).normalized()
			var drive=throttle*engine_force*2*(front_power_percent/100.0 if c.front else 1-front_power_percent/100.0) if controlled else 0.0
			if linear_velocity.length()>stream_speed_limit: drive=0.0
			if absf(c.get("omega",0.0)*radius)>top_speed and signf(drive)==signf(c.get("omega",0.0)): drive=0
			var brake=0.0
			if not controlled or balanced_braking: brake=brake_strength
			elif braking: brake=brake_strength*2*(front_brake_percent/100.0 if c.front else 1-front_brake_percent/100.0)
			if stream_braking: brake=maxf(brake,brake_strength)
			c.drive_allocation=drive;c.brake_allocation=brake
			var dynamics=preload("res://benchmarks/mesh_snapshot/world/tyre_dynamics.gd").step(c.get("omega",0.0),contact_v.dot(forward),contact_v.dot(right),radius,load,grip,drive*radius,brake,dt)
			c.omega=dynamics.omega;c.slip=dynamics.slip
			apply_force(right*dynamics.force.x+forward*dynamics.force.y,lever)
			grounded_count+=1;c.grounded=true;c.contact=hit.position
		else:
			geom=droop;c.slip=0.0
			var share=2*(front_power_percent/100.0 if c.front else 1-front_power_percent/100.0)
			var drive=throttle*engine_force*radius*share if controlled else 0.0
			var brake=brake_strength if not controlled or balanced_braking else (brake_strength*2*(front_brake_percent/100.0 if c.front else 1-front_brake_percent/100.0) if braking else 0.0)
			var dynamics=preload("res://benchmarks/mesh_snapshot/world/tyre_dynamics.gd").step(c.get("omega",0.0),0,0,radius,0,grip,drive,brake,dt)
			c.omega=dynamics.omega
		c.spin.rotate_x(-c.omega*dt)
		c.travel=geom.lower.y;c.compression=compression
		max_compression=maxf(max_compression,compression)
		var lower=point(anchor,geom.lower,side)
		var upper=point(anchor,geom.upper,side)
		var upper_in=anchor+Vector3(Linkage.UPPER_IN.x*side,Linkage.UPPER_IN.y,0)
		c.hub.position=(lower+upper)*.5
		c.hub.basis=Basis((upper-lower).normalized(),steering if c.front else 0.0)*Basis(Vector3.FORWARD,geom.camber*side)
		if c.links.is_empty(): continue
		rod(c.links[0],anchor+Vector3(0,0,-.27),lower)
		rod(c.links[1],anchor+Vector3(0,0,.27),lower)
		rod(c.links[2],upper_in+Vector3(0,0,-.22),upper)
		rod(c.links[3],upper_in+Vector3(0,0,.22),upper)
		rod(c.links[4],lower,upper)
		var mount=anchor+Vector3(-side*.06,.8,0)
		var seat=anchor.lerp(lower,.68)
		var middle=mount.lerp(seat,.5)
		rod(c.links[5],mount,middle);rod(c.links[6],middle,seat)
		rod(c.links[7],mount,seat)
	if global_position.y < -35:
		global_transform=Transform3D(Basis.IDENTITY,Vector3(-17,2,9));linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO
