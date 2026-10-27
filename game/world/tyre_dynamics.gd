extends RefCounted
# Independent wheel inertia, combined friction limit and brake torque.
static func step(omega: float, speed: float, lateral: float, radius: float, load: float, grip: float, drive: float, brake: float, dt: float) -> Dictionary:
	var force :=Vector2.ZERO;var h :=dt/12.0;var inertia :=12.0
	for i in range(12):
		var slip :=omega*radius-speed
		var tyre :=Vector2(-lateral*1200,slip*1800).limit_length(maxf(load,0)*grip)
		omega+=(drive-tyre.y*radius)*h/inertia
		omega=move_toward(omega,0,(brake+4.0)*h/inertia)
		force+=tyre/12.0
	return {"omega":omega,"force":force,"slip":clampf(Vector2(omega*radius-speed,lateral).length()/maxf(absf(speed),2),0,1)}
