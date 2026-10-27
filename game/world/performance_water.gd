extends MeshInstance3D
## Session-only visual lake. No collision, buoyancy or terrain/save edits.
const Ring=preload("res://world/terrain_drive_ring.gd")
const CELLS=40
var radius=85.0
var highlights=1.0
var shallow=Color(.15,.55,.65,.85)
var deep=Color(.02,.12,.25,.95)
var match_distant=true
var shallow_picker: ColorPickerButton
var deep_picker: ColorPickerButton
var palette_picker: OptionButton
const PALETTES=["Original cyan","Atlantic blue-green","Peat lake","Slate blue"]
const SHALLOWS=[Color(.15,.55,.65),Color(.16,.32,.30),Color(.28,.24,.13),Color(.25,.34,.43)]
const DEEPS=[Color(.02,.12,.25),Color(.025,.10,.13),Color(.055,.045,.025),Color(.055,.085,.14)]
var arena: Node3D
var material: ShaderMaterial
var centre=Vector2(350,350)
var base_level=0.0
var level_offset=0.0
var floor_heights=PackedFloat32Array()
var toggle: CheckBox
var level_control: SpinBox
var location_label: Label
func setup(owner_arena: Node3D, column: VBoxContainer):
	arena=owner_arena;physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new();material.shader=preload("res://world/performance_water.gdshader");material_override=material
	material.set_shader_parameter("shallow_color",Color(.15,.55,.65,.85))
	material.set_shader_parameter("deep_color",Color(.02,.12,.25,.95))
	material.set_shader_parameter("wave_speed",.25)
	material.set_shader_parameter("wave_height",1.2)
	material.set_shader_parameter("specular_intensity",2.5)
	material.set_shader_parameter("glitter_intensity",1.8)
	extra_cull_margin=3.0
	choose_basin()
	setup_distant_palette()
	toggle=CheckBox.new();toggle.text="Preview lake";column.add_child(toggle);toggle.toggled.connect(set_enabled)
	var row=HBoxContainer.new();column.add_child(row)
	var label=Label.new();label.text="Water level adjustment";row.add_child(label)
	level_control=SpinBox.new();level_control.min_value=-8;level_control.max_value=8;level_control.step=.25;level_control.suffix="m";row.add_child(level_control)
	level_control.value_changed.connect(func(value):level_offset=value;if_mesh_rebuild())
	row=HBoxContainer.new();column.add_child(row)
	label=Label.new();label.text="Pool diameter";row.add_child(label)
	var size_control=SpinBox.new();size_control.min_value=20;size_control.max_value=1000;size_control.step=10;size_control.value=170;size_control.suffix="m";row.add_child(size_control)
	var apply_size=Button.new();apply_size.text="Apply size";row.add_child(apply_size)
	apply_size.pressed.connect(func():set_diameter(size_control.value))
	row=HBoxContainer.new();column.add_child(row)
	label=Label.new();label.text="Highlight strength";row.add_child(label)
	var strength=SpinBox.new();strength.min_value=0;strength.max_value=3;strength.step=.1;strength.value=1;row.add_child(strength);strength.value_changed.connect(set_highlights)
	palette_picker=OptionButton.new();column.add_child(palette_picker)
	for palette in PALETTES:palette_picker.add_item(palette)
	palette_picker.add_item("Custom");palette_picker.item_selected.connect(set_palette)
	row=HBoxContainer.new();column.add_child(row)
	label=Label.new();label.text="Shallow";row.add_child(label)
	shallow_picker=ColorPickerButton.new();shallow_picker.custom_minimum_size=Vector2(100,28);shallow_picker.edit_alpha=false;shallow_picker.color=shallow;row.add_child(shallow_picker)
	label=Label.new();label.text="Deep";row.add_child(label)
	deep_picker=ColorPickerButton.new();deep_picker.custom_minimum_size=Vector2(100,28);deep_picker.edit_alpha=false;deep_picker.color=deep;row.add_child(deep_picker)
	shallow_picker.color_changed.connect(func(color):shallow=Color(color,.85);palette_picker.select(4);apply_palette())
	deep_picker.color_changed.connect(func(color):deep=Color(color,.95);palette_picker.select(4);apply_palette())
	var distant=CheckBox.new();distant.text="Match distant water palette";distant.button_pressed=true;column.add_child(distant)
	distant.toggled.connect(func(value):match_distant=value;apply_palette())
	apply_palette()
	var place=Button.new();place.text="Place trial pool 100 m ahead";column.add_child(place);place.pressed.connect(place_ahead)
	location_label=Label.new();column.add_child(location_label);update_label()
	label=Label.new();label.text="Visual preview only: no swimming or buoyancy.\nRipples, sky tint and sun glint; terrain hides the submerged surface.\nSettings reset on restart. Water level does not alter terrain.";column.add_child(label)
	hide();set_process(false)
func choose_basin():
	var best=-INF
	for x in range(-400,701,100):
		for z in range(-400,701,100):
			var point=Vector2(x,z)
			if point.distance_to(Vector2(120,145))<150:continue
			var floor_height: float=arena.source.surface_height(point)
			var rim=INF
			for i in 12:
				var border=point+Vector2.from_angle(i*TAU/12.0)*radius
				rim=minf(rim,arena.source.surface_height(border))
			var score=rim-floor_height-point.distance_to(Vector2(120,145))*.001
			if score>best:
				best=score;centre=point;base_level=floor_height+clampf((rim-floor_height)*.65,1.2,5.0)
func set_enabled(value: bool):
	if value and floor_heights.is_empty():sample_floor();rebuild()
	visible=value;set_process(value)
	if toggle:toggle.set_pressed_no_signal(value)
func sample_floor():
	floor_heights.clear()
	var space=get_world_3d().direct_space_state
	for z in CELLS+1:
		for x in CELLS+1:
			var point=centre+Vector2(float(x)/CELLS-.5,float(z)/CELLS-.5)*radius*2.0
			var h: float=arena.source.surface_height(point)
			var ray=PhysicsRayQueryParameters3D.create(Ring.point(point.x,h+150,point.y),Ring.point(point.x,h-150,point.y),1)
			var hit=space.intersect_ray(ray)
			if not hit.is_empty():h=Ring.coordinates(hit.position).y
			floor_heights.append(h)
func if_mesh_rebuild():
	if not floor_heights.is_empty():rebuild()
	update_label()
func rebuild():
	position=Vector3.ZERO
	var vertices=PackedVector3Array();var normals=PackedVector3Array();var uvs=PackedVector2Array();var colors=PackedColorArray();var indices=PackedInt32Array()
	for z in CELLS+1:
		for x in CELLS+1:
			var uv=Vector2(float(x)/CELLS,float(z)/CELLS)
			var point=centre+(uv-Vector2(.5,.5))*radius*2.0
			var position=Ring.point(point.x,base_level+level_offset,point.y)
			vertices.append(position);normals.append(Ring.up_at(position));uvs.append(uv)
			colors.append(Color(clampf((base_level+level_offset-floor_heights[z*(CELLS+1)+x])/12.0,0,1),0,0,1))
	for z in CELLS:
		for x in CELLS:
			var a=z*(CELLS+1)+x;var b=a+1;var c=a+CELLS+1;var d=c+1
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh=result
func place_ahead():
	var position: Vector3=arena.camera.global_position-arena.camera.global_basis.z*100.0
	var coords=Ring.coordinates(position);centre=Vector2(coords.x,coords.z)
	base_level=arena.source.surface_height(centre)+2.0;level_offset=0;level_control.set_value_no_signal(0)
	floor_heights.clear();sample_floor();rebuild();set_enabled(true);update_label()
func update_label():
	if location_label:location_label.text="Centre: %.0f, %.0f m | level: %.1f m | diameter: %.0f m" % [centre.x,centre.y,base_level+level_offset,radius*2]
func set_diameter(value: float):
	radius=clampf(value*.5,10,500);floor_heights.clear()
	if visible:sample_floor();rebuild()
	update_label()
func set_highlights(value: float):
	highlights=clampf(value,0,3)
	material.set_shader_parameter("highlight_strength",highlights)
	material.set_shader_parameter("specular_intensity",2.5*highlights)
	material.set_shader_parameter("glitter_intensity",1.8*highlights)
	material.set_shader_parameter("volumetric_ray_intensity",1.5*highlights)
func set_palette(index: int):
	if index>=PALETTES.size():return
	shallow=Color(SHALLOWS[index],.85);deep=Color(DEEPS[index],.95)
	palette_picker.select(index);shallow_picker.color=shallow;deep_picker.color=deep;apply_palette()
func apply_palette():
	material.set_shader_parameter("shallow_color",shallow);material.set_shader_parameter("deep_color",deep)
	var far_material: ShaderMaterial=arena.backdrop._mat
	far_material.set_shader_parameter("water_palette_enabled",match_distant)
	far_material.set_shader_parameter("water_shallow_palette",shallow)
	far_material.set_shader_parameter("water_deep_palette",deep)
func setup_distant_palette():
	# Adapt only this scene's shader. Colour the existing coastal-height mask
	# before lighting/haze; never tint final atmospheric pixels or wall materials.
	var far_material: ShaderMaterial=arena.backdrop._mat
	var source: String=far_material.shader.code
	var uniforms="uniform bool water_palette_enabled=false;\nuniform vec4 water_shallow_palette : source_color=vec4(.15,.55,.65,1.0);\nuniform vec4 water_deep_palette : source_color=vec4(.02,.12,.25,1.0);\nuniform sampler2DArray water_height_tex : filter_linear;\nuniform float water_patch_offsets[40];\nuniform float water_dem_scale=1.0;\n"
	source=source.replace("uniform vec3 to_sun",uniforms+"uniform vec3 to_sun")
	var recolor="if(water_palette_enabled && pi>=0){\n float bed=(texture(water_height_tex,vec3(puv,float(pi))).r+water_patch_offsets[pi])*water_dem_scale;\n float water_mask=1.0-smoothstep(0.0,0.5,bed);\n vec3 water_base=mix(water_deep_palette.rgb,water_shallow_palette.rgb,0.5);\n albedo=mix(albedo,water_base,water_mask);\n}\n\t"
	source=source.replace("vec3 lit = albedo *",recolor+"vec3 lit = albedo *")
	var shader=Shader.new();shader.code=source;far_material.shader=shader
	far_material.set_shader_parameter("water_height_tex",arena.backdrop._patch_tex)
	far_material.set_shader_parameter("water_patch_offsets",arena.backdrop._patch_offset)
	far_material.set_shader_parameter("water_dem_scale",arena.backdrop.dem_scale)
func _process(_delta: float):
	material.set_shader_parameter("sun_direction",arena.daylight.sun.global_basis.z)
	var sun: Color=arena.daylight.sun.light_color
	material.set_shader_parameter("sun_color",Vector3(sun.r,sun.g,sun.b)*arena.daylight.sun.light_energy)
	var tint: Color=arena.cloud_review.day_cycle.sky_tint if arena.cloud_review.day_cycle.enabled else Color.WHITE
	material.set_shader_parameter("light_tint",Vector3(tint.r,tint.g,tint.b))
