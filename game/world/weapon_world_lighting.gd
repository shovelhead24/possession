extends RefCounted
## Mirror the world lights into the isolated, cached first-person viewport.
var environment: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var clock=0.0
var signature=""
func setup(view: SubViewport, env: Environment, key: DirectionalLight3D) -> void:
	environment=env;sun=key
	moon=DirectionalLight3D.new();moon.shadow_enabled=false;view.add_child(moon)
func sync(arena: Node3D, delta: float, force=false) -> bool:
	clock-=delta
	if clock>0 and not force:return false
	clock=.1
	var daylight=arena.get("daylight")
	if not daylight or not daylight.sun or not daylight.environment:return false
	var camera_basis: Basis=arena.camera.global_basis.orthonormalized().inverse()
	var sun_basis: Basis=camera_basis*daylight.sun.global_basis.orthonormalized()
	var env: Environment=daylight.environment
	var moon_basis=Basis.IDENTITY
	var moon_colour=Color(.52,.66,1.0)
	var moon_energy=0.0
	var fill=0.0
	var review=arena.get("cloud_review")
	if review and is_instance_valid(review.moonlight):
		moon_basis=camera_basis*review.moonlight.global_basis.orthonormalized()
		moon_colour=review.moonlight.light_color;moon_energy=review.moonlight.light_energy
		if is_instance_valid(review.moon_fill):fill=review.moon_fill.light_energy*.25
	var values=[sun_basis.get_rotation_quaternion(),daylight.sun.light_color,daylight.sun.light_energy,
		env.ambient_light_color,env.ambient_light_energy,moon_basis.get_rotation_quaternion(),moon_colour,moon_energy,fill]
	var next=""
	for value in values:
		if value is Quaternion:
			for v in [value.x,value.y,value.z,value.w]:next+=str(roundf(v*100))+","
		elif value is Color:
			for v in [value.r,value.g,value.b]:next+=str(roundf(v*200))+","
		else:next+=str(roundf(float(value)*200))+","
	if next==signature and not force:return false
	signature=next
	sun.basis=sun_basis;sun.light_color=daylight.sun.light_color;sun.light_energy=daylight.sun.light_energy
	moon.basis=moon_basis;moon.light_color=moon_colour;moon.light_energy=moon_energy
	environment.ambient_light_color=env.ambient_light_color
	environment.ambient_light_energy=env.ambient_light_energy+fill
	return true
