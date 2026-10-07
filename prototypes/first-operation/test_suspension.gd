extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world=Node3D.new();root.add_child(world)
	var floor_body=StaticBody3D.new();var floor_shape=CollisionShape3D.new();var floor_box=BoxShape3D.new();floor_box.size=Vector3(500,1,500);floor_shape.shape=floor_box;floor_body.position.y=-.5;floor_body.add_child(floor_shape);world.add_child(floor_body)
	var car=preload("res://wishbone_vehicle.gd").new()
	var chassis=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(1.8,.7,3);chassis.shape=box;chassis.position.y=1;car.add_child(chassis)
	var model=Node3D.new();car.add_child(model)
	for x in [-1.3,1.3]:
		for z in [-1.7,1.7]:
			var wheel=MeshInstance3D.new();wheel.name="Wheel"+str(model.get_child_count());var mesh=CylinderMesh.new();mesh.top_radius=.55;mesh.bottom_radius=.55;mesh.height=.35;wheel.mesh=mesh;wheel.rotation.z=PI*.5;wheel.position=Vector3(x,.55,z);model.add_child(wheel)
	car.position.y=2;world.add_child(car)
	var helper=preload("res://arena_kit.gd").new();car.setup(model,Callable(helper,"bounds"))
	await create_timer(.15).timeout
	assert(car.grounded_count==0,"Suspension reaches ground while clearly airborne")
	await create_timer(5.0).timeout
	print("SETTLED y=",car.position.y," speed=",car.linear_velocity.length()," grounded=",car.grounded_count," compression=",car.max_compression)
	assert(car.grounded_count==4 and car.linear_velocity.length()<.3,"Parked chassis does not settle")
	var bump=StaticBody3D.new();var bump_shape=CollisionShape3D.new();var bump_box=BoxShape3D.new();bump_box.size=Vector3(.8,.22,.8);bump_shape.shape=bump_box;bump.add_child(bump_shape);bump.position=Vector3(-1.3,.11,-1.7);world.add_child(bump)
	await create_timer(1.5).timeout
	var smallest:=100.0;var largest:=0.0
	for corner in car.corners:
		smallest=minf(smallest,corner.compression);largest=maxf(largest,corner.compression)
	print("ARTICULATION compression difference=",largest-smallest)
	assert(largest-smallest>.015,"Independent wheel bump does not articulate suspension")
	bump.queue_free();await create_timer(2.0).timeout
	var start=car.position;car.controlled=true;car.set_controls(1,0,false)
	await create_timer(3.0).timeout
	assert(car.position.distance_to(start)>8,"Drive forces do not move chassis")
	var initial=car.global_basis.z;car.set_controls(.5,.7,false)
	await create_timer(1.0).timeout
	assert(initial.angle_to(car.global_basis.z)>.05,"Steering forces do not turn chassis")
	car.set_controls(0,0,true)
	await create_timer(3.0).timeout
	assert(car.linear_velocity.length()<1,"Braking does not stop vehicle")
	car.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,2.5,0));car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO;car.controlled=false
	await create_timer(5.0).timeout
	assert(car.grounded_count==4 and car.linear_velocity.length()<.4,"Landing does not settle")
	helper.free()
	print("PASS: four wheels; airborne droop; static sag; acceleration; steering; braking; landing settles")
	quit()
