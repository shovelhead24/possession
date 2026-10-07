extends SceneTree

func _initialize() -> void:
	var control=load("res://world/stream_speed_control.gd").new()
	control.step(45,60,640,1.0/60)
	assert(control.drive==1 and control.brake==0,"Healthy supply must allow full speed")
	control.step(45,30,160,1.0/60)
	assert(control.limit==30 and control.drive==0 and control.brake<.04)
	for i in 30: control.step(29,60,640,1.0/60)
	assert(control.limit==30,"Recovery must not chase every chunk arrival")
	for i in 120: control.step(29,60,640,1.0/60)
	assert(control.limit>30 and control.limit<37)
	control.step(20,0,0,1.0/60)
	assert(control.brake==1 and control.drive==0 and control.limit==0)
	control.reset();assert(control.drive==1 and control.brake==0 and is_inf(control.limit))
	print("STREAM_SPEED_PASS");quit()
