extends SceneTree
const Old=preload("res://benchmarks/performance_reference/wishbone_vehicle.gd")
const New=preload("res://world/wishbone_vehicle.gd")
func _initialize(): run.call_deferred()
func make_car(script: Script, x: float):
	var car=script.new();root.add_child(car);car.position=Vector3(x,.1,0);car.set_physics_process(false);car.trace_suspension=true
	for i in 4:
		var hub=Node3D.new();car.add_child(hub);var spin=Node3D.new();hub.add_child(spin)
		car.corners.append({"anchor":Vector3(-1 if i%2==0 else 1,0,-1 if i<2 else 1),"side":-1.0 if i%2==0 else 1.0,"radius":.4,"hub":hub,"spin":spin,"links":[],"front":i<2,"travel":0.0,"compression":0.0})
	return car
func run():
	var floor_body=StaticBody3D.new();root.add_child(floor_body);var collision=CollisionShape3D.new();collision.shape=BoxShape3D.new();collision.shape.size=Vector3(100,1,100);collision.position.y=-.5;floor_body.add_child(collision)
	var old=make_car(Old,-5);var fast=make_car(New,5)
	await physics_frame;await physics_frame
	for travel in [.28,.12,.24]:
		old.travel_limit=travel;fast.travel_limit=travel
		for steer in [-.8,0.0,.6]:
			old.set_controls(.5,steer,false);fast.set_controls(.5,steer,false)
			for i in 30:
				old._physics_process(1.0/60);fast._physics_process(1.0/60)
				for j in 4:
					for key in ["travel","compression","omega","slip","grounded"]:
						if old.corners[j].get(key)!=fast.corners[j].get(key): push_error("Suspension differs: "+key);quit(1);return
	for key in ["spring_force","damper_force","bump_force","load","target_y","bump_height","contact_up_speed"]:
		assert(old.corners[0].trace_forces.get(key)==fast.corners[0].trace_forces.get(key))
	var result={}
	for name in ["old","fast","old_repeat","fast_repeat"]:
		var car=old if name.begins_with("old") else fast;car.trace_suspension=false
		var start=Time.get_ticks_usec()
		for i in 2000: car._physics_process(1.0/60)
		result[name]=(Time.get_ticks_usec()-start)/1000.0
	print("PASS exact suspension states and forces across steering/travel changes ",JSON.stringify(result))
	old.free();fast.free();floor_body.free();quit()


