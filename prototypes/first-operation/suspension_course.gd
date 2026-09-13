extends Node3D
func _ready() -> void:
	var arena=get_parent()
	var concrete=arena.material(Color(.4,.4,.35))
	for i in range(6):
		var x=-65.0+(-1.2 if i%2==0 else 1.2)
		arena.solid(Vector3(x,.12+i*.025,-20-i*6),Vector3(1.4,.24+i*.05,1.8),concrete)
	ramp(Vector3(-67,0,-70),4,10,1.3,false,concrete)
	ramp(Vector3(-70,0,-94),10,10,1.5,true,concrete)
	ramp(Vector3(-69,0,-122),8,12,2,false,concrete)
	arena.label3("SUSPENSION TEST / STAGGERED BUMPS",Vector3(-65,3,-14),45)
	arena.label3("ARTICULATION RAMP",Vector3(-65,3,-65),40)
	arena.label3("SIDE SLOPE",Vector3(-65,4,-88),40)
	arena.label3("JUMP",Vector3(-65,4,-116),40)

func ramp(origin: Vector3, width: float, length_m: float, rise: float, sideways: bool, mat: Material) -> void:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a=origin
	var b=origin+Vector3(width,rise if sideways else 0,0)
	var c=origin+Vector3(width,rise,-length_m)
	var d=origin+Vector3(0,0 if sideways else rise,-length_m)
	for p in [a,c,b,a,d,c]: st.add_vertex(p)
	st.generate_normals()
	var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=mat;add_child(mesh);mesh.create_trimesh_collision()
