extends SceneTree
const Data=preload("res://arena_bake_data.gd")
var data=Data.new()
var source: Node
func _initialize(): call_deferred("run")

func authored(x: float,z: float) -> float:
	var col=clampi(int(floor((x+810)/540)),0,3);var row=clampi(int(floor((110-z)/690)),0,3)
	var origin=Data.sector_origin(col,row);var lx=x-origin.x;var lz=z-origin.z;var index=row*4+col
	var edge=minf(minf(lx+270,270-lx),minf(lz+580,110-lz))
	var blend=smoothstep(0,45,edge)
	var h=source.authored_height(lx,lz)
	if index!=1:
		h*=.35
		var hills=25*exp(-pow((lx+110)/78,2)-pow((lz+170)/100,2))+19*exp(-pow((lx-130)/65,2)-pow((lz+420)/92,2))
		var valley_axis=30+55*sin((lz+80)*.008+index*.3)
		var valley=-14*exp(-pow((lx-valley_axis)/48,2))
		var bowls=-16*exp(-pow((lx+90)/67,2)-pow((lz+180)/82,2))-11*exp(-pow((lx-125)/53,2)-pow((lz+440)/68,2))
		match index:
			0,4,8,14: h+=hills*.7+4*sin(lx*.014)*cos(lz*.019)
			2,11: h+=hills+valley
			3,9: h+=bowls+5*sin(lx*.021)*cos(lz*.012)
			5,10,15: h+=hills+7*sin(lx*.021+lz*.013)
			6,13:
				var axis=35*sin((lz+90)*.011)+(35 if index==6 else -25)
				var mouth=smoothstep(-535,-465,lz)*(1-smoothstep(-90,-30,lz))
				var crossing=1-.65*exp(-pow((lz+245)/30,2))
				h+=7-24*(1-smoothstep(12,42,absf(lx-axis)))*mouth*crossing
			_: h+=3*sin(lx*.016)*cos(lz*.018)
	var pad=(1-smoothstep(42,55,absf(lx)))*smoothstep(-350,-339,lz)*(1-smoothstep(-274,-262,lz))
	h=lerpf(h,0,pad)
	var result=lerpf(3+2*sin(x*.009)*cos(z*.008),h,blend)
	for center in Data.MEETING_POINTS:
		var distance=Vector2(x-center.x,z-center.z).length()
		result=lerpf(3.0,result,smoothstep(55,95,distance))
	return result

func tree_density(index: int,x: float,z: float) -> float:
	var woods=exp(-pow((x+120)/100,2)-pow((z+180)/130,2))+exp(-pow((x-115)/95,2)-pow((z+425)/125,2))
	var line=1-smoothstep(6,17,absf(x-65*sin(z*.013+index)))
	if index in [0,4,8,11,14]: return clampf(woods*1.5,.025,.98)
	if index in [6,13]: return clampf(woods*.4+line*.15,.01,.65)
	return clampf(woods*.35+line*.9,.015,.95)

func in_meeting_clearing(point: Vector3) -> bool:
	for center in Data.MEETING_POINTS:
		if Vector2(point.x-center.x,point.z-center.z).length()<65: return true
	return false

func own_children(node: Node,owner: Node) -> void:
	for child in node.get_children(): child.owner=owner;own_children(child,owner)

func pack(node: Node) -> PackedScene:
	own_children(node,node)
	var scene=PackedScene.new();assert(scene.pack(node)==OK);return scene

func run():
	source=preload("res://tactical.gd").new()
	data.heights.resize(Data.WIDTH*Data.DEPTH)
	for z in Data.DEPTH:
		for x in Data.WIDTH: data.heights[z*Data.WIDTH+x]=authored(Data.MINIMUM.x+x*3,Data.MINIMUM.y+z*3)
	print("BAKE: heightfield complete")
	var terrain=Node3D.new();terrain.name="TacticalGround"
	var material=source.local_ground(Color(.30,.37,.25))
	for row in 4:
		for col in 4:
			var origin=Data.sector_origin(col,row);var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for iz in 230:
				for ix in 180:
					var x=origin.x-270+ix*3;var z=origin.z-580+iz*3
					for p in [Vector2(x,z),Vector2(x+3,z),Vector2(x+3,z+3),Vector2(x,z),Vector2(x+3,z+3),Vector2(x,z+3)]:
						st.add_vertex(Vector3(p.x,data.height_at(p.x,p.y),p.y))
			st.index();st.generate_normals()
			var mesh=st.commit();var imported=ImporterMesh.new();imported.add_surface(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0));imported.generate_lods(25,60,[])
			var node=MeshInstance3D.new();node.mesh=imported.get_mesh();node.material_override=material;node.name="Sector_%02d" % (row*4+col);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;terrain.add_child(node);node.create_trimesh_collision()
			print("BAKE: terrain sector ",row*4+col)
	data.terrain=pack(terrain);terrain.free()
	# Repeat the original enemy compound shell, not the friendly spawn FOB.
	var outposts=Node3D.new();outposts.name="SectorOutposts"
	var stone=source.material(Color(.34,.35,.30));var metal=source.material(Color(.16,.20,.22),.4)
	for row in 4:
		for col in 4:
			if row==0 and col==1: continue # Original interactive relay is retained.
			var origin=Data.sector_origin(col,row)
			for x in [-20.0,20.0]: source.solid(origin+Vector3(x,1.4,-281),Vector3(32,2.8,.7),stone)
			source.solid(origin+Vector3(-36,1.4,-307),Vector3(.7,2.8,52),stone)
			source.solid(origin+Vector3(0,1.4,-333),Vector3(72,2.8,.7),stone)
			for z in [-291.0,-320.0]: source.solid(origin+Vector3(36,1.4,z),Vector3(.7,2.8,20),stone)
			source.building(origin+Vector3(-19,0,-309),stone,metal);source.building(origin+Vector3(18,0,-315),stone,metal)
	for child in source.get_children(): child.reparent(outposts,false)
	data.outposts=pack(outposts);outposts.free()
	# Cache normalized tree meshes once, not glTF parsing at every launch.
	var kit=preload("res://arena_kit.gd").new()
	var tree_source=kit.imported(kit.GAME+"realistic_fir_trees_pack_lods_gameready/scene.gltf")
	assert(tree_source!=null)
	var helper=preload("res://tree_mesh_tools.gd").new();var regex=RegEx.new();regex.compile("(?i)^(.+?)_LOD(\\d)")
	var variants={};helper._walk_lod_meshes(tree_source,tree_source,regex,variants)
	var keys=variants.keys();keys.sort()
	for key in keys.slice(0,3):
		for lod in 4: data.tree_meshes.append(helper._normalize_mesh(variants[key].get(mini(lod,2))))
	tree_source.free();kit.free()
	var rocks_root=Node3D.new();rocks_root.name="BakedRocks"
	var rng=RandomNumberGenerator.new()
	for row in 4:
		for col in 4:
			var index=row*4+col;var origin=Data.sector_origin(col,row);rng.seed=852+index*971
			var count=440 if index in [0,4,8,11,14] else (140 if index in [6,13] else 230)
			var placed: Array[Vector3]=[]
			for attempt in count*35:
				if placed.size()>=count: break
				var x=rng.randf_range(-230,230);var z=rng.randf_range(-525,-42)
				if index==1 and (absf(x+65)<13 or absf(x-25)<10 or absf(x)<12): continue
				if rng.randf()>tree_density(index,x,z): continue
				if absf(x)<44 and z< -270 and z> -345: continue
				var p=origin+Vector3(x,0,z);p.y=data.height_at(p.x,p.z)-.12
				if in_meeting_clearing(p): continue
				if absf(data.height_at(p.x+3,p.z)-p.y)>1.8 or absf(data.height_at(p.x,p.z+3)-p.y)>1.8: continue
				var crowded=false
				for other in placed:
					if other.distance_squared_to(p)<49: crowded=true;break
				if crowded: continue
				placed.append(p);var height=rng.randf_range(7,12)
				data.trees.append({"position":p,"transform":Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*height),p),"variant":rng.randi_range(0,2),"height":height})
			var squads=2+index%4
			for i in squads:
				var home=origin+Vector3([-135,100,-100,155,45][i],0,-100-i*85+rng.randf_range(-25,25));home.y=data.height_at(home.x,home.z);data.homes.append(home)
				if i==0 and index!=1: data.homes[-1]=origin+Vector3(0,0,-297)
			data.sector_counts.append({"sector":index,"habitat":Data.HABITATS[index],"trees":placed.size(),"squads":squads})
			for i in 26:
				var p=origin+Vector3(rng.randf_range(-215,215),0,rng.randf_range(-520,-65))
				if in_meeting_clearing(p): continue
				if absf(p.x-origin.x)<48 and p.z-origin.z< -270 and p.z-origin.z> -345: continue
				p.y=data.height_at(p.x,p.z)
				var radius=rng.randf_range(1.5,3);var h=rng.randf_range(1.2,3.3)
				var mesh=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=9;mesh.rings=5
				var node=MeshInstance3D.new();node.mesh=mesh;node.position=p+Vector3.UP*h*.35;node.scale=Vector3(radius,h*.6,radius);node.material_override=source.material(Color(.28,.30,.26),0,.94);rocks_root.add_child(node);node.create_convex_collision()
				data.rocks.append({"position":p,"radius":radius,"height":h})
				for side in 8:
					var slot=p+Vector3(cos(side*PI/4),0,sin(side*PI/4))*(radius+1.5);slot.y=data.height_at(slot.x,slot.z);data.slots.append(slot)
	# Heavy garrison belongs to the distant relay, never the player's FOB.
	for p in [Vector3(-24,0,-291),Vector3(23,0,-291),Vector3(0,0,-307),Vector3(-25,0,-325),Vector3(24,0,-326),Vector3(47,0,-309)]: data.homes.append(p)
	data.rock_scene=pack(rocks_root);rocks_root.free()
	print("BAKE: placements ",data.trees.size()," trees / ",data.homes.size()," squads")
	# Navigation masks are authored once; runtime only loads grid connectivity.
	var blocked={};var tree_cells={}
	for x in range(-101,169):
		for z in range(-331,14):
			var p=Vector2(x*8,z*8);var h=data.height_at(p.x,p.y)
			var solid=absf(data.height_at(p.x+4,p.y)-h)>3.2 or absf(data.height_at(p.x,p.y+4)-h)>3.2
			var origin=Data.sector_origin(clampi(int(floor((p.x+810)/540)),0,3),clampi(int(floor((110-p.y)/690)),0,3));p-=Vector2(origin.x,origin.z)
			# Relay perimeter with front/east gates and actual building footprints.
			if absf(p.x)<40 and p.y< -276 and p.y> -340:
				solid=solid or (absf(p.y+280)<5 and absf(p.x)>5) or absf(p.x+36)<4 or absf(p.y+333)<4 or (absf(p.x-36)<4 and absf(p.y+306)>6)
				for b in [Vector2(-19,-309),Vector2(18,-315)]: solid=solid or (absf(p.x-b.x)<8 and absf(p.y-b.y)<9)
			if solid: blocked[Vector2(x,z)]=true
	for rock in data.rocks:
		var c=Vector2(roundi(rock.position.x/8),roundi(rock.position.z/8));blocked[c]=true
	for tree in data.trees: tree_cells[Vector2(roundi(tree.position.x/8),roundi(tree.position.z/8))]=true
	for cell in blocked: data.blocked.append(cell)
	for cell in tree_cells: data.tree_cells.append(cell)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://baked"))
	assert(ResourceSaver.save(data,Data.FILE,ResourceSaver.FLAG_COMPRESS)==OK,"Bake save failed")
	print("BAKE COMPLETE: ",Data.FILE," / 2160 x 2760 metres / 16 sectors")
	source.free();quit()
