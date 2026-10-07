extends SceneTree
func _initialize():
	var solver=preload("res://tyre_dynamics.gd")
	var omega=20.0;var result: Dictionary
	for i in range(60):
		result=solver.step(omega,10,0,.5,2000,1,0,2000,1.0/60);omega=result.omega
	assert(absf(omega)<.01 and result.force.y<0 and result.slip>.9,"Locked tyre must slide while chassis moves")
	var car=preload("res://wishbone_vehicle.gd").new()
	for i in range(4): car.corners.append({"omega":12.0})
	car.driver_controls(false,true,false,0)
	assert(car.balanced_braking and car.throttle==0 and not car.reverse_engaged)
	for c in car.corners: c.omega=0
	car.driver_controls(false,true,false,0)
	assert(car.reverse_engaged and car.throttle==-1 and not car.balanced_braking)
	car.driver_controls(true,false,true,0);assert(car.braking and not car.balanced_braking and not car.reverse_engaged)
	car.free();print("PASS: wheel lock while sliding, S balanced brake to reverse, Space biased brake");quit()
