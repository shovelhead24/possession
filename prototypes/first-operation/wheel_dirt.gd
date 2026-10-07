extends Node3D
var emitters: Array[CPUParticles3D]=[]
func _ready() -> void:
	name="WheelDirt"
	var img=Image.create(32,32,false,Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var distance=Vector2(x-15.5,y-15.5).length()/15.5
			img.set_pixel(x,y,Color(1,1,1,pow(maxf(0,1-distance),2)))
	var mat=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(img);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;mat.vertex_color_use_as_albedo=true;mat.no_depth_test=false
	for corner in get_parent().corners:
		var p=CPUParticles3D.new();p.amount=24;p.lifetime=.65;p.local_coords=false;p.emitting=false;p.direction=Vector3.UP;p.spread=40;p.gravity=Vector3(0,-1,0);p.initial_velocity_min=.7;p.initial_velocity_max=1.6;p.scale_amount_min=.15;p.scale_amount_max=.4
		var mesh=QuadMesh.new();mesh.size=Vector2(.65,.65);mesh.material=mat;p.mesh=mesh
		var gradient=Gradient.new();gradient.set_color(0,Color(.38,.29,.17,.5));gradient.set_color(1,Color(.38,.29,.17,0));p.color_ramp=gradient
		add_child(p);emitters.append(p)

func _process(_delta: float) -> void:
	var car=get_parent();var speed=Vector2(car.linear_velocity.x,car.linear_velocity.z).length()
	for i in range(emitters.size()):
		var corner=car.corners[i];var p=emitters[i]
		p.emitting=corner.get("grounded",false) and (speed>2 or absf(corner.get("omega",0.0)*corner.radius)>2)
		if p.emitting:
			p.global_position=corner.contact+Vector3.UP*.08
			p.direction=car.global_basis.z*.5+Vector3.UP
			p.initial_velocity_max=minf(3,speed*.15+1)

