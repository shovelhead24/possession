extends SceneTree
const OUT="res://assets/showcases/"
const Ring=preload("res://world/terrain_drive_ring.gd")
func _initialize():run.call_deferred()
func run():
	if DisplayServer.get_name()=="headless":push_error("Refinement needs a rendering device for MultiMesh reads; run without --headless.");quit(1);return
	var terrain=load(OUT+"terrain.res") as ShaderMaterial
	# Bake broad colour variation once; no noise generation while playing.
	var noise=FastNoiseLite.new();noise.seed=8173;noise.frequency=1.0;noise.fractal_octaves=3
	var macro=Image.create(512,512,false,Image.FORMAT_RGB8)
	for y in 512:
		for x in 512:
			var p=Vector2(x,y)/511.0*4800.0-Vector2.ONE*2400.0
			macro.set_pixel(x,y,Color(noise.get_noise_2dv(p/90.0)*.5+.5,noise.get_noise_2dv(p/350.0+Vector2(73,19))*.5+.5,noise.get_noise_2dv(p/1100.0+Vector2(17,91))*.5+.5))
	macro.generate_mipmaps()
	terrain.set_shader_parameter("landscape_variation",ImageTexture.create_from_image(macro))
	var breakup=Image.create(512,512,false,Image.FORMAT_RGB8)
	for y in 512:
		for x in 512:
			var p=Vector2(x,y)
			breakup.set_pixel(x,y,Color(periodic_noise(noise,p,3.5),periodic_noise(noise,p,18.0),periodic_noise(noise,p,85.0)))
	breakup.generate_mipmaps()
	terrain.set_shader_parameter("ground_breakup",ImageTexture.create_from_image(breakup))
	# A saved visual track study beside the autumn landing, not live wheel simulation.
	var tracks=Image.create(512,1024,false,Image.FORMAT_R8)
	for y in 1024:
		for x in 512:
			var p=Vector2(-32.0+x/511.0*64.0,-900.0+y/1023.0*240.0)
			var centre=6.0+sin((p.y+850.0)/24.0)*4.0
			var wheel=absf(absf(p.x-centre)-.88)
			var edge=1.0-smoothstep(.13,.24,wheel)
			var ends=smoothstep(-865.0,-850.0,p.y)*(1.0-smoothstep(-705.0,-685.0,p.y))
			var tread=.72+.28*smoothstep(-.3,.4,sin(p.y*24.0+p.x*8.0))
			tracks.set_pixel(x,y,Color(edge*ends*tread,0,0))
	tracks.generate_mipmaps()
	var track_texture=ImageTexture.create_from_image(tracks)
	var height=Image.load_from_file("res://assets/terrain/grass-study/grass-height.png");height.generate_mipmaps()
	terrain.set_shader_parameter("grass_height",ImageTexture.create_from_image(height))
	for key in ["dry_straw","dry_tussocks"]:
		var image=Image.load_from_file("res://assets/terrain/grass-study/"+key.replace("_","-")+".png");image.generate_mipmaps()
		terrain.set_shader_parameter(key,ImageTexture.create_from_image(image))
	ResourceSaver.save(terrain,OUT+"terrain.res",ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)
	var water=load(OUT+"water.res") as ShaderMaterial
	water.set_shader_parameter("volumetric_ray_intensity",.08);water.set_shader_parameter("god_ray_intensity",.05)
	water.set_shader_parameter("caustic_highlight_intensity",.1);water.set_shader_parameter("glitter_intensity",.25)
	water.set_shader_parameter("highlight_strength",.3);water.set_shader_parameter("specular_intensity",.6)
	ResourceSaver.save(water,OUT+"water.res",ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)
	var grass=make_grass(terrain.get_shader_parameter("grass"))
	ResourceSaver.save(grass,OUT+"grass.res",ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)
	var cards=[make_cards("clump-a"),make_cards("clump-b"),make_cards("wheat")]
	for i in cards.size():ResourceSaver.save(cards[i],OUT+"grass-card-"+str(i)+".res",ResourceSaver.FLAG_COMPRESS)
	var sites=JSON.parse_string(FileAccess.get_file_as_string(OUT+"manifest.json"))
	for site in sites:
		var node=(load(OUT+site.id+".scn") as PackedScene).instantiate()
		var site_material=terrain.duplicate() as ShaderMaterial
		var character=bake_character(node,site)
		site_material.set_shader_parameter("landscape_character",ImageTexture.create_from_image(character))
		site_material.set_shader_parameter("track_mask",track_texture)
		site_material.set_shader_parameter("tracks_enabled",site.id=="autumn")
		var peak=0.0
		var anchor=Ring.point(site.arc,site.base,site.lateral)
		for child in node.get_children():
			if child is MeshInstance3D:
				if child.material_override:child.material_override=water
				else:
					var arrays=child.mesh.surface_get_arrays(0)
					var heights=PackedVector2Array()
					for vertex in arrays[Mesh.ARRAY_VERTEX]:
						var h=Ring.coordinates(anchor+vertex).y-site.base;peak=maxf(peak,h);heights.append(Vector2(h,0))
					arrays[Mesh.ARRAY_TEX_UV2]=heights
					var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,site_material);child.mesh=mesh
			elif child is MultiMeshInstance3D:
				var size=child.multimesh.mesh.get_aabb().size.y
				if size>1.05 and size<2:
					# Stable batch selection; no extra draw calls or scatter density.
					var choice=posmod(child.get_index(),4)
					child.multimesh.mesh=grass if choice==0 else cards[choice-1]
					if not child.has_meta("grass_scatter_source"):child.set_meta("grass_scatter_source",child.multimesh.duplicate())
					var source=child.get_meta("grass_scatter_source") as MultiMesh
					var transforms=[];var customs=[]
					for j in source.instance_count:
						var xf=source.get_instance_transform(j);var custom=source.get_instance_custom_data(j)
						var coord=Ring.coordinates(anchor+child.position+xf.origin)
						var uv=Vector2(coord.x-site.arc,coord.z-site.lateral)/4800.0+Vector2.ONE*.5
						var field=character.get_pixel(clampi(int(uv.x*511),0,511),clampi(int(uv.y*511),0,511))
						if fposmod(custom.r*7.173,1.0)>.2+field.a*.8:continue
						var spread=lerpf(.1,.55,field.a)
						xf.basis=xf.basis*Basis.from_scale(Vector3(1,lerpf(1.0-spread,1.0+spread,custom.r),1))
						transforms.append(xf);customs.append(Color(clampf(1.0-field.g+custom.r*.25-.125,0,1),0,0,1))
					var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=child.multimesh.mesh;mm.instance_count=transforms.size()
					for j in transforms.size():mm.set_instance_transform(j,transforms[j]);mm.set_instance_custom_data(j,customs[j])
					child.multimesh=mm
				elif size>5 and not child.has_meta("tree_visual_height_v2"):
					var mm=child.multimesh
					var body=node.get_child(child.get_index()+1) if child.get_index()+1<node.get_child_count() else null
					for j in mm.instance_count:
						var height_scale=lerpf(.65,1.35,mm.get_instance_custom_data(j).r)
						var scale_basis=Basis.from_scale(Vector3(pow(height_scale,.35),height_scale,pow(height_scale,.35)))
						var xf=mm.get_instance_transform(j);xf.basis=xf.basis*scale_basis;mm.set_instance_transform(j,xf)
						if body is StaticBody3D and body.is_in_group("trex_passable_tree") and j<body.get_child_count():
							var shape=body.get_child(j)
							var base=shape.position-shape.basis*Vector3(0,2.5,0)
							shape.basis=xf.basis;shape.position=base+shape.basis*Vector3(0,2.5,0)
					child.set_meta("height_variety_v1",true);child.set_meta("tree_visual_height_v2",true)
		site_material.set_shader_parameter("snow_start",peak*.86)
		site_material.set_shader_parameter("snow_full",peak*.96)
		assert(peak*.86>47.0+300.0,"Snow must remain well above lake level")
		print("SUMMIT_SNOW ",site.id," start=",peak*.86," full=",peak*.96," peak=",peak)
		var packed=PackedScene.new();assert(packed.pack(node)==OK)
		assert(ResourceSaver.save(packed,OUT+site.id+".scn",ResourceSaver.FLAG_COMPRESS)==OK);node.free()
		# Lift the initial reveal clear of foreground slopes; retain ground landing.
		site.eye[1]=site.landing[1]+([55.0,120.0,22.0,25.0][site.kind])
	var file=FileAccess.open(OUT+"manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(sites,"\t"));file.close()
	print("SHOWCASE_REFINEMENT_PASS");quit()
func periodic_noise(noise: FastNoiseLite,p: Vector2,scale: float) -> float:
	var t=p/512.0
	var a=lerpf(noise.get_noise_2dv(p/scale),noise.get_noise_2dv((p-Vector2(512,0))/scale),t.x)
	var b=lerpf(noise.get_noise_2dv((p-Vector2(0,512))/scale),noise.get_noise_2dv((p-Vector2(512,512))/scale),t.x)
	return clampf(lerpf(a,b,t.y)*.85+.5,0,1)
func make_grass(texture: Texture2D) -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 8:
		var angle=k*2.4;var base=Vector3(cos(angle)*.25,0,sin(angle)*.25);var side=Vector3(cos(angle)*.045,0,sin(angle)*.045)
		var bend=Vector3(sin(angle)*.18,0,cos(angle)*.18);var h=.75+(k%3)*.18
		var points=[base-side,base+side,base+Vector3.UP*h*.5+bend*.3-side*.6,base+Vector3.UP*h*.5+bend*.3+side*.6,base+Vector3.UP*h+bend]
		var uv=[Vector2(0,0),Vector2(1,0),Vector2(0,.5),Vector2(1,.5),Vector2(.5,1)]
		for i in [0,2,1,1,2,3,2,4,3]:st.set_uv(uv[i]);st.add_vertex(points[i])
	st.generate_normals();var mesh=st.commit();var mat=ShaderMaterial.new();mat.shader=load("res://world/showcase_foliage.gdshader")
	mat.set_shader_parameter("sway",.08);mat.set_shader_parameter("detail_tex",texture);mesh.surface_set_material(0,mat);return mesh

func make_cards(kind: String) -> ArrayMesh:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0,PI*.5]:
		var side=Vector3(cos(angle),0,sin(angle))*.62
		for band in 3:
			var y0=band*.4;var y1=(band+1)*.4
			var points=[-side+Vector3.UP*y0,side+Vector3.UP*y0,-side+Vector3.UP*y1,side+Vector3.UP*y1]
			var uv=[Vector2(0,1.0-y0/1.2),Vector2(1,1.0-y0/1.2),Vector2(0,1.0-y1/1.2),Vector2(1,1.0-y1/1.2)]
			# Wheat source is a blade atlas, even in the pack's clump-named file.
			# Select a small group of blades instead of displaying the entire row.
			if kind=="wheat":
				for j in uv.size():uv[j]=Vector2(uv[j].x*.24+(.04 if angle==0 else .53),.46+uv[j].y*.47)
			for i in [0,2,1,1,2,3]:st.set_uv(uv[i]);st.add_vertex(points[i])
	st.generate_normals();var mesh=st.commit()
	var mat=ShaderMaterial.new();mat.shader=load("res://world/showcase_grass_cards.gdshader")
	var image=Image.load_from_file("res://assets/terrain/grass-cards/"+kind+".png")
	image.fix_alpha_edges();image.generate_mipmaps()
	mat.set_shader_parameter("card_tex",ImageTexture.create_from_image(image));mesh.surface_set_material(0,mat)
	return mesh

func grid_height(grid: PackedFloat32Array,p: Vector2) -> float:
	var uv=(p/25.0+Vector2.ONE*96).clamp(Vector2.ZERO,Vector2.ONE*191.999)
	var x=int(uv.x);var y=int(uv.y);var fx=uv.x-x;var fy=uv.y-y
	return lerpf(lerpf(grid[y*193+x],grid[y*193+x+1],fx),lerpf(grid[(y+1)*193+x],grid[(y+1)*193+x+1],fx),fy)
func region(p: Vector2,centre: Vector2,radius: Vector2) -> float:
	return 1.0-smoothstep(.3,1.0,((p-centre)/radius).length())
func bake_character(node: Node3D,site: Dictionary) -> Image:
	var grid=PackedFloat32Array();grid.resize(193*193)
	var anchor=Ring.point(site.arc,site.base,site.lateral)
	for child in node.get_children():
		if not child is MeshInstance3D or child.material_override:continue
		var arrays=child.mesh.surface_get_arrays(0)
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			var uv=arrays[Mesh.ARRAY_TEX_UV][i]
			var x=clampi(roundi((uv.x+2400)/25),0,192);var y=clampi(roundi((uv.y+2400)/25),0,192)
			grid[y*193+x]=Ring.coordinates(anchor+arrays[Mesh.ARRAY_VERTEX][i]).y-site.base
	var n=FastNoiseLite.new();n.seed=1937+int(site.kind)*317;n.frequency=1.0;n.fractal_octaves=3
	var out=Image.create(512,512,false,Image.FORMAT_RGBA8)
	var west_green=0.0;var east_green=0.0
	for y in 512:
		for x in 512:
			var p=Vector2(x,y)/511.0*4800.0-Vector2.ONE*2400
			var h=grid_height(grid,p)
			var dx=grid_height(grid,p+Vector2(25,0))-grid_height(grid,p-Vector2(25,0))
			var dz=grid_height(grid,p+Vector2(0,25))-grid_height(grid,p-Vector2(0,25))
			var slope=Vector2(dx,dz).length()/50.0
			var average=(grid_height(grid,p+Vector2(100,0))+grid_height(grid,p-Vector2(100,0))+grid_height(grid,p+Vector2(0,100))+grid_height(grid,p-Vector2(0,100)))*.25
			var hollow=smoothstep(1.0,24.0,average-h);var bluff=smoothstep(4.0,32.0,h-average)
			var broad=n.get_noise_2dv(p/440.0);var middle=n.get_noise_2dv(p/85.0+Vector2(19,73))
			var warp=Vector2(n.get_noise_2dv(p/250.0),n.get_noise_2dv(p/310.0+Vector2(81,17)))*210.0
			var q=p+warp
			# Deliberate large natural districts, independent of DEM satellite imagery.
			var meadow=region(q,Vector2(-1100,-350),Vector2(1300,1800))
			var dry_rise=region(q,Vector2(1100,-300),Vector2(1250,1550))
			var wet_pocket=region(q,Vector2(-250,450),Vector2(900,1400))
			var upland=region(q,Vector2(500,1350),Vector2(1600,850))
			var gentle=1.0-smoothstep(.35,1.0,slope)
			var wet=clampf((1.0-smoothstep(49,115,h))*.75+hollow*.55+wet_pocket*.4+middle*.25-dry_rise*.35,0,1)*gentle
			var green=clampf(.25+meadow*.65+wet*.5+middle*.48+broad*.3-dry_rise*.4-upland*.15,0,1)
			var exposed=clampf(smoothstep(.38,1.0,slope)*.85+bluff*.45+upland*.15+middle*.2,0,1)
			var density=clampf(.18+green*.72+wet*.17-exposed*.8+middle*.2,0,1)
			out.set_pixel(x,y,Color(wet,green,exposed,density))
			if x<256:west_green+=green
			else:east_green+=green
	out.generate_mipmaps()
	print("LANDSCAPE_CHARACTER ",site.id," west/east green=",west_green/131072.0," / ",east_green/131072.0)
	return out
