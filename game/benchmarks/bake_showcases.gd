extends SceneTree
## Offline only. Writes baked meshes, collision and placements; never player saves.
const Ring=preload("res://world/terrain_drive_ring.gd")
const OUT="res://assets/showcases/"
const HALF=2400.0
const STEP=25.0
const N=192
var arena
var noise=FastNoiseLite.new()
var fine_noise=FastNoiseLite.new()
var rng=RandomNumberGenerator.new()
var site: Dictionary
var heights=PackedFloat32Array()
var root_node: Node3D
var anchor: Vector3
var terrain_material: ShaderMaterial
var tree_mesh: ArrayMesh
var grass_mesh: ArrayMesh
var water_material: ShaderMaterial
var stone_mesh: SphereMesh
func _initialize():run.call_deferred()
func run():
	arena=load("res://world/performance_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter:await process_frame
	assert("sky-test" in arena.destruction.save_path and "sky-test" in arena.actors.store.path)
	arena.floating_origin.enabled=false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	noise.seed=441;noise.frequency=.0017;noise.fractal_octaves=4
	fine_noise.seed=746;fine_noise.frequency=.014;fine_noise.fractal_octaves=3
	terrain_material=ShaderMaterial.new();terrain_material.shader=load("res://world/showcase_terrain.gdshader")
	for item in [["grass","res://assets/terrain/grass-study/grass.png"],["rock","res://world/materials/nature/rock_boulder_dry_diffuse.jpg"]]:
		var image=Image.load_from_file(item[1]);image.generate_mipmaps();terrain_material.set_shader_parameter(item[0],ImageTexture.create_from_image(image))
	ResourceSaver.save(terrain_material,OUT+"terrain.res")
	water_material=ShaderMaterial.new();water_material.shader=load("res://world/performance_water.gdshader")
	water_material.set_shader_parameter("shallow_color",Color(.16,.29,.28,.9));water_material.set_shader_parameter("deep_color",Color(.025,.085,.12,.95))
	water_material.set_shader_parameter("wave_height",.22);water_material.set_shader_parameter("highlight_strength",.5)
	ResourceSaver.save(water_material,OUT+"water.res")
	tree_mesh=make_pine();grass_mesh=make_grass()
	ResourceSaver.save(tree_mesh,OUT+"pine.res");ResourceSaver.save(grass_mesh,OUT+"grass.res")
	stone_mesh=SphereMesh.new();stone_mesh.radial_segments=7;stone_mesh.rings=3
	var stone_mat=StandardMaterial3D.new();stone_mat.albedo_color=Color(.27,.29,.28);stone_mat.roughness=1;stone_mesh.material=stone_mat
	var sites=[
		{"id":"autumn","name":"Wilderness / Autumn forest and lakes","arc":10000.0,"lateral":10000.0,"kind":0},
		{"id":"alpine","name":"Wilderness / Alpine braided river","arc":16000.0,"lateral":10000.0,"kind":1},
		{"id":"pass","name":"Wilderness / Rocky mountain pass","arc":22000.0,"lateral":10000.0,"kind":2},
		{"id":"lake","name":"Wilderness / Highland lake","arc":28000.0,"lateral":10000.0,"kind":3}]
	for s in sites:
		site=s;rng.seed=1600+site.kind
		bake_site();print("SHOWCASE_BAKED ",site.name)
		await process_frame
	var file=FileAccess.open(OUT+"manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(sites,"\t"));file.close()
	print("SHOWCASE_BAKE_PASS");quit()
func raw_height(x: float,z: float) -> float:
	var broad=noise.get_noise_2d(x+site.kind*4000,z)
	var rough=fine_noise.get_noise_2d(x,z)
	var mountain=0.0
	# Authored peaks frame the forward (+lateral) view; gaps remain traversable.
	var peaks=[Vector3(-1450,1000,1200),Vector3(1050,1250,1500),Vector3(-350,850,1850),Vector3(1900,700,650)]
	if site.kind==0:peaks=[Vector3(-1650,850,1550),Vector3(1200,1000,1800),Vector3(-400,700,2050),Vector3(1900,450,500)]
	if site.kind==2:peaks=[Vector3(-1000,1000,650),Vector3(850,1100,1350),Vector3(-550,800,2000),Vector3(1500,700,200)]
	if site.kind==3:peaks=[Vector3(-1500,750,1400),Vector3(1350,1150,900),Vector3(800,900,1550),Vector3(-500,600,1800)]
	for peak in peaks:
		var radius=Vector2(x-peak.x,z-peak.z).length()
		mountain=maxf(mountain,peak.y*pow(maxf(0,1-radius/1350.0),1.35))
	var h=75.0+broad*70.0+rough*9.0
	match site.kind:
		0:
			h+=mountain*(.85+.3*broad)
			var basin=exp(-pow(x/1000.0,4)-pow((z-250)/660.0,4))
			h-=basin*100.0
			h+=90*exp(-pow((z+1100)/500.0,2))
		1:
			h+=mountain*1.3
			var valley=exp(-pow(x/850.0,4))
			h=lerpf(h,54.0+rough*6.0,valley)
			for lane in [-1.0,0.0,1.0]:
				var centre=lane*230+sin(z*.003+lane*2)*100+sin(z*.008+lane)*35
				h-=20*exp(-pow((x-centre)/(38.0+20*(lane+1)),2))*valley
		2:
			var path=sin(z*.0018)*230
			var side=absf(x-path)
			h=60+220*smoothstep(80.0,750.0,side)+mountain*1.4+absf(broad)*280*smoothstep(70.0,300.0,side)
			h+=rough*35*smoothstep(100.0,550.0,side)
		3:
			h+=mountain*1.05
			var basin=exp(-pow(x/1200.0,4)-pow((z+150)/1000.0,4))
			h-=basin*110
			h+=130*exp(-pow((z-1150)/300.0,2))*smoothstep(0.0,1300.0,x)
	return h
func sampled(x: float,z: float) -> float:
	var ix=clampf((x+HALF)/STEP,0,N-.001);var iz=clampf((z+HALF)/STEP,0,N-.001)
	var a=int(ix);var b=int(iz);var fx=ix-a;var fz=iz-b
	return lerpf(lerpf(heights[b*(N+1)+a],heights[b*(N+1)+a+1],fx),lerpf(heights[(b+1)*(N+1)+a],heights[(b+1)*(N+1)+a+1],fx),fz)
func slope_at(x: float,z: float) -> float:return Vector2(sampled(x+12,z)-sampled(x-12,z),sampled(x,z+12)-sampled(x,z-12)).length()/24.0
func point(x: float,h: float,z: float) -> Vector3:return Ring.point(site.arc+x,site.base+h,site.lateral+z)-anchor
func owned(node: Node,parent: Node):parent.add_child(node);node.owner=root_node
func bake_site():
	var background_max=-10000.0
	for z in range(-2400,2401,200):
		for x in range(-2400,2401,200):background_max=maxf(background_max,arena.backdrop._far_terrain_h(site.arc+x,site.lateral+z))
	site.base=maxf(100.0,background_max+140)
	anchor=Ring.point(site.arc,site.base,site.lateral)
	heights.resize((N+1)*(N+1))
	for iz in N+1:
		for ix in N+1:
			var x=ix*STEP-HALF;var z=iz*STEP-HALF
			var edge=smoothstep(1850.0,2400.0,maxf(absf(x),absf(z)))
			var bg=arena.backdrop._far_terrain_h(site.arc+x,site.lateral+z)-site.base
			heights[iz*(N+1)+ix]=lerpf(raw_height(x,z),bg,edge)
	root_node=Node3D.new();root_node.name=site.id.capitalize()
	for cz in 8:
		for cx in 8:bake_chunk(cx,cz)
	bake_water()
	var eye=Vector2(0,-850)
	if site.kind==1:eye=Vector2(-700,-1250)
	if site.kind==2:eye=Vector2(0,-1500)
	if site.kind==3:eye=Vector2(350,-1500)
	site.eye=[eye.x,sampled(eye.x,eye.y)+4.0,eye.y]
	site.target=[0,160,600]
	site.landing=[eye.x,sampled(eye.x,eye.y),eye.y]
	bake_foliage(eye)
	var packed=PackedScene.new();assert(packed.pack(root_node)==OK)
	assert(ResourceSaver.save(packed,OUT+site.id+".scn",ResourceSaver.FLAG_COMPRESS)==OK)
	root_node.free()
func bake_chunk(cx: int,cz: int):
	var vertices=PackedVector3Array();var uvs=PackedVector2Array();var colors=PackedColorArray();var indices=PackedInt32Array()
	for j in 25:
		for i in 25:
			var x=(cx*24+i)*STEP-HALF;var z=(cz*24+j)*STEP-HALF;var h=heights[(cz*24+j)*(N+1)+cx*24+i]
			vertices.append(point(x,h,z));uvs.append(Vector2(x,z))
			var variation=fine_noise.get_noise_2d(x,z)*.5+.5
			var slope=slope_at(x,z)
			var rock=smoothstep(.45,1.15,slope+(variation-.5)*.3)
			if site.kind==2:rock=maxf(rock,smoothstep(130.0,420.0,h)*.75)
			var snow=smoothstep(650.0,820.0,h+(variation-.5)*180)*(1.0-smoothstep(1.0,2.5,slope))
			var dry=clampf(.76+noise.get_noise_2d(x,z)*.4,0,1) if site.kind==0 else clampf(.25+variation*.3,0,1)
			colors.append(Color(dry,rock,snow,variation))
	for j in 24:
		for i in 24:
			var a=j*25+i
			indices.append_array(PackedInt32Array([a,a+1,a+25,a+1,a+26,a+25]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var tool=SurfaceTool.new();tool.create_from(mesh,0);tool.generate_normals();mesh=tool.commit();mesh.surface_set_material(0,terrain_material)
	assert(mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][312].dot(Ring.up_at(anchor+vertices[312]))>0.0,"Terrain winding must face ring up")
	var visual=MeshInstance3D.new();visual.mesh=mesh;owned(visual,root_node)
	var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;owned(body,root_node)
	var shape=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();owned(shape,body)
func bake_water():
	if site.kind==2:return
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in N:
		for i in N:
			var x=i*STEP-HALF;var z=j*STEP-HALF
			if maxf(absf(x),absf(z))>1750:continue
			var corners=[Vector2(x,z),Vector2(x+STEP,z),Vector2(x,z+STEP),Vector2(x+STEP,z+STEP)]
			var low=10000.0
			for p in corners:low=minf(low,sampled(p.x,p.y))
			if low>49:continue
			for idx in [0,1,2,1,3,2]:
				var p=corners[idx];st.set_color(Color(clampf((47.0-sampled(p.x,p.y))/12.0,.01,1),0,0));st.set_uv(Vector2(.5,.5));st.set_normal(Ring.up_at(anchor+point(p.x,47,p.y)));st.add_vertex(point(p.x,47,p.y))
	var water=MeshInstance3D.new();water.mesh=st.commit();water.material_override=water_material;water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;owned(water,root_node)
func make_pine() -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in 7:
		var bottom=1.4+tier*1.1;var radius=2.8*(1.0-tier/8.0)
		for k in 7:
			var a=k*TAU/7;var b=(k+1)*TAU/7
			var color=Color(.035+tier*.004,.085+tier*.006,.038+tier*.003)
			for v in [Vector3(cos(a)*radius,bottom,sin(a)*radius),Vector3(0,bottom+3.4,0),Vector3(cos(b)*radius,bottom,sin(b)*radius)]:st.set_color(color);st.set_uv(Vector2.ZERO);st.add_vertex(v)
	for k in 6:
		var a=k*TAU/6;var b=(k+1)*TAU/6
		for v in [Vector3(cos(a)*.18,0,sin(a)*.18),Vector3(cos(a)*.12,5,sin(a)*.12),Vector3(cos(b)*.18,0,sin(b)*.18),Vector3(cos(b)*.18,0,sin(b)*.18),Vector3(cos(a)*.12,5,sin(a)*.12),Vector3(cos(b)*.12,5,sin(b)*.12)]:st.set_color(Color(.11,.075,.045));st.set_uv(Vector2.ZERO);st.add_vertex(v)
	st.generate_normals();var mesh=st.commit();var mat=ShaderMaterial.new();mat.shader=load("res://world/showcase_foliage.gdshader");mesh.surface_set_material(0,mat);return mesh
func make_grass() -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 8:
		var angle=k*2.4;var base=Vector3(cos(angle)*.25,0,sin(angle)*.25);var side=Vector3(cos(angle)*.055,0,sin(angle)*.055)
		for v in [base-side,base+Vector3(sin(angle)*.22,.7+(k%3)*.18,cos(angle)*.22),base+side]:
			st.set_color(Color(.36,.255,.10) if v.y>.1 else Color(.15,.13,.045));st.set_uv(Vector2(0,v.y));st.add_vertex(v)
	st.generate_normals();var mesh=st.commit();var mat=ShaderMaterial.new();mat.shader=load("res://world/showcase_foliage.gdshader");mat.set_shader_parameter("sway",.12);mesh.surface_set_material(0,mat);return mesh
func scatter(mesh: Mesh,records: Array,limit: float,shadows: bool):
	if records.is_empty():return
	var centre=Vector3.ZERO
	for record in records:centre+=record.origin
	centre/=records.size()
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=records.size()
	for i in records.size():
		var transform: Transform3D=records[i];transform.origin-=centre
		mm.set_instance_transform(i,transform);mm.set_instance_custom_data(i,Color(rng.randf(),0,0))
	var visual=MultiMeshInstance3D.new();visual.multimesh=mm;visual.visibility_range_end=limit
	visual.position=centre
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owned(visual,root_node)
	if mesh==tree_mesh or mesh==stone_mesh:
		var body=StaticBody3D.new();body.collision_layer=2;body.collision_mask=2;owned(body,root_node)
		var shape: Shape3D
		if mesh==tree_mesh:
			var trunk=CylinderShape3D.new();trunk.radius=.18;trunk.height=5.0;shape=trunk;body.add_to_group("trex_passable_tree",true)
		else:
			var sphere=SphereShape3D.new();sphere.radius=.5;shape=sphere
		for record in records:
			var collision=CollisionShape3D.new();collision.shape=shape;collision.transform=record
			if mesh==tree_mesh:collision.position+=record.basis*Vector3(0,2.5,0)
			owned(collision,body)
func placement(x: float,z: float,scale: Vector3) -> Transform3D:
	var p=point(x,sampled(x,z),z);var up=Ring.up_at(p+anchor);var spin=Ring.spinward_at(p+anchor)
	return Transform3D(Basis(up,rng.randf()*TAU)*Basis(spin,up,Vector3.BACK).scaled(scale),p)
func bake_foliage(eye: Vector2):
	# Spatial batches preserve useful culling; sparse clearings connect the landing to water.
	var total=0
	for bz in 12:
		for bx in 12:
			var trees=[];var rocks=[]
			for attempt in (200 if site.kind==0 else 65):
				var x=-1800+bx*300+rng.randf()*300;var z=-1800+bz*300+rng.randf()*300
				var h=sampled(x,z);var slope=slope_at(x,z)
				if h<51 or h>620 or slope>.7:continue
				if Vector2(x,z).distance_to(eye)<45:continue
				var density=.72 if site.kind==0 else (.3 if site.kind==1 else .08)
				if site.kind==2:density=.025
				if absf(x)<50 and z<0:continue
				if rng.randf()<density and noise.get_noise_2d(x*2,z*2)>-.25:
					var scale=rng.randf_range(1.3,2.4);trees.append(placement(x,z,Vector3(scale,scale*rng.randf_range(.85,1.2),scale)));total+=1
				elif rng.randf()<.08:rocks.append(placement(x,z,Vector3(rng.randf_range(2,7),rng.randf_range(2,5),rng.randf_range(2,6))))
			scatter(tree_mesh,trees,6500,true);scatter(stone_mesh,rocks,2500,true)
	for bz in 8:
		for bx in 8:
			var grass=[]
			for attempt in 180:
				var x=eye.x-120+bx*30+rng.randf()*30;var z=eye.y-80+bz*30+rng.randf()*30
				if sampled(x,z)<50 or slope_at(x,z)>.65:continue
				var s=rng.randf_range(.7,1.4);grass.append(placement(x,z,Vector3(s,s,s)))
			scatter(grass_mesh,grass,180,false)
	site.tree_count=total
