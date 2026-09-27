extends Node3D
const Data=preload("res://arena_bake_data.gd")
var enabled := false
var radius := 18.0
var strength := 2.0
var dirty := false
var arena: Node3D
var marker: MeshInstance3D
var status: Label
var elapsed := 0.0
var aim := Vector3.INF
var save_path := Data.EDITED_FILE

func _ready() -> void:
	arena=get_parent();name="TerrainEditor"
	var box=arena.rex_menu.panel.get_child(0).get_child(0)
	var toggle=CheckButton.new();toggle.text="Terrain brush (flying mode only)";box.add_child(toggle)
	toggle.toggled.connect(func(value): enabled=value)
	status=Label.new();status.text="V: fly · Page Up/Down: raise/lower\nCtrl+S: save terrain · Original bake preserved";box.add_child(status)
	arena.rex_menu.add_slider(box,"Brush radius (m)",6,60,1,radius,func(value): radius=value)
	arena.rex_menu.add_slider(box,"Height per stroke (m)",.25,5,.25,strength,func(value): strength=value)
	var save=Button.new();save.text="Save terrain to disk";box.add_child(save);save.pressed.connect(save_terrain)
	marker=MeshInstance3D.new();add_child(marker);marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color.YELLOW;marker.material_override=mat

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode==KEY_S and enabled:
		save_terrain();get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	marker.visible=enabled and arena.flying and not arena.rex_menu.controlled
	if not marker.visible or arena.rex_menu.opened: return
	var from=arena.camera.global_position;var direction=-arena.camera.global_basis.z
	aim=Vector3.INF
	# Heightfield intersection deliberately ignores trees, characters and buildings.
	for step in range(1,1001):
		var p=from+direction*step*2.0
		if p.x<Data.MINIMUM.x or p.x>1350 or p.z<Data.MINIMUM.y or p.z>110: continue
		if p.y<=arena.height_at(p.x,p.z): aim=Vector3(p.x,arena.height_at(p.x,p.z),p.z);break
	if not aim.is_finite(): marker.hide();return
	var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 64:
		for angle in [i*TAU/64,(i+1)*TAU/64]:
			var p=aim+Vector3(cos(angle),0,sin(angle))*radius;p.y=arena.height_at(p.x,p.z)+.3;mesh.surface_add_vertex(p)
	mesh.surface_end();marker.mesh=mesh
	elapsed-=delta
	if elapsed>0 or Input.is_physical_key_pressed(KEY_CTRL): return
	var direction_height=int(Input.is_physical_key_pressed(KEY_PAGEUP))-int(Input.is_physical_key_pressed(KEY_PAGEDOWN))
	if direction_height!=0: sculpt(aim,radius,strength*direction_height);elapsed=.4

func protected_point(p: Vector2) -> bool:
	var origin=Data.sector_origin(clampi(int(floor((p.x+810)/540)),0,3),clampi(int(floor((110-p.y)/690)),0,3))
	var local=p-Vector2(origin.x,origin.z)
	if absf(local.x)<60 and local.y> -355 and local.y< -255: return true
	if p.x> -85 and p.x<65 and p.y> -265: return true # FOB, track, suspension course.
	for rock in arena.world_data.rocks:
		if p.distance_squared_to(Vector2(rock.position.x,rock.position.z))<pow(rock.radius+3,2): return true
	return false

func sculpt(center: Vector3,brush_radius: float,amount: float) -> void:
	var data=arena.world_data;var sectors={}
	for z in range(maxi(0,floori((center.z-brush_radius-Data.MINIMUM.y)/3)),mini(Data.DEPTH,ceili((center.z+brush_radius-Data.MINIMUM.y)/3)+1)):
		for x in range(maxi(0,floori((center.x-brush_radius-Data.MINIMUM.x)/3)),mini(Data.WIDTH,ceili((center.x+brush_radius-Data.MINIMUM.x)/3)+1)):
			var p=Data.MINIMUM+Vector2(x,z)*3;var distance_to_center=p.distance_to(Vector2(center.x,center.z))
			if distance_to_center>=brush_radius or protected_point(p): continue
			data.heights[z*Data.WIDTH+x]=clampf(data.heights[z*Data.WIDTH+x]+amount*(1.0-smoothstep(0,brush_radius,distance_to_center)),-30,100)
			# Shared border vertices belong to both neighbouring sector meshes.
			for row in 4:
				for col in 4:
					var origin=Data.sector_origin(col,row)
					if p.x>=origin.x-270 and p.x<=origin.x+270 and p.y>=origin.z-580 and p.y<=origin.z+110: sectors[row*4+col]=true
	if sectors.is_empty(): return
	for sector in sectors: rebuild_sector(sector)
	var trees=arena.get_node("ArenaTrees");var bodies=[]
	for child in trees.get_children():
		if child is StaticBody3D: bodies.append(child)
	for i in data.trees.size():
		var tree=data.trees[i];tree.position.y=data.height_at(tree.position.x,tree.position.z)-.12;tree.transform.origin=tree.position
		bodies[i].position=tree.position
	trees.update_lods();rebuild_navigation()
	dirty=true;status.text="Unsaved terrain changes · Ctrl+S to save\nProtected: structures, course, track, rock bases"

func rebuild_sector(index: int) -> void:
	var node=arena.get_node("TacticalGround/Sector_%02d" % index)
	var arrays=node.mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size(): vertices[i].y=arena.height_at(vertices[i].x,vertices[i].z)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var raw=ArrayMesh.new();raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var surface=SurfaceTool.new();surface.create_from(raw,0);surface.generate_normals();var mesh=surface.commit()
	var importer=ImporterMesh.new();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0));importer.generate_lods(25,60,[])
	node.mesh=importer.get_mesh()
	for shape in node.find_children("*","CollisionShape3D",true,false): shape.shape=node.mesh.create_trimesh_shape()

func rebuild_navigation() -> void:
	var data=arena.world_data;var blocked={}
	for x in range(-101,169):
		for z in range(-331,14):
			var p=Vector2(x*8,z*8);var h=data.height_at(p.x,p.y)
			var solid=absf(data.height_at(p.x+4,p.y)-h)>3.2 or absf(data.height_at(p.x,p.y+4)-h)>3.2
			var origin=Data.sector_origin(clampi(int(floor((p.x+810)/540)),0,3),clampi(int(floor((110-p.y)/690)),0,3));p-=Vector2(origin.x,origin.z)
			if absf(p.x)<40 and p.y< -276 and p.y> -340:
				solid=solid or (absf(p.y+280)<5 and absf(p.x)>5) or absf(p.x+36)<4 or absf(p.y+333)<4 or (absf(p.x-36)<4 and absf(p.y+306)>6)
				for b in [Vector2(-19,-309),Vector2(18,-315)]: solid=solid or (absf(p.x-b.x)<8 and absf(p.y-b.y)<9)
			if solid: blocked[Vector2(x,z)]=true
	for rock in data.rocks: blocked[Vector2(roundi(rock.position.x/8),roundi(rock.position.z/8))]=true
	data.blocked=PackedVector2Array(blocked.keys())
	var manager=arena.get_node("PracticeRange");manager.navigation.setup(arena,manager.navigation.cover)
	for actor in get_tree().get_nodes_in_group("tyrants"): actor.path.clear();actor.path_timer=0

func save_terrain() -> void:
	if not dirty: status.text="No unsaved terrain changes.";return
	var packed=PackedScene.new();var error=packed.pack(arena.get_node("TacticalGround"))
	if error!=OK: status.text="Terrain pack failed: "+str(error);return
	arena.world_data.terrain=packed
	var temporary=save_path.get_basename()+"_pending.res"
	error=ResourceSaver.save(arena.world_data,temporary,ResourceSaver.FLAG_COMPRESS)
	if error!=OK: status.text="Save failed: "+str(error);return
	if FileAccess.file_exists(save_path):
		error=DirAccess.copy_absolute(save_path,save_path+".backup")
		if error!=OK: status.text="Backup failed: "+str(error);return
	error=DirAccess.rename_absolute(temporary,save_path)
	if error!=OK: status.text="Install save failed: "+str(error);return
	dirty=false;status.text="Saved arena_edited.res — loaded next launch.\nOriginal arena.res preserved; previous save backed up."
	print("TERRAIN_SAVED ",ProjectSettings.globalize_path(save_path))
