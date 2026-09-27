extends Node3D
var elapsed := 0.0
var lines: MeshInstance3D
func _ready() -> void:
	name="PatrolDiagnostics"
	lines=MeshInstance3D.new();lines.add_to_group("combat_viewcones");add_child(lines)
	lines.visible=get_parent().rex_menu.indicators_visible
	lines.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true
	lines.material_override=mat
func _process(delta: float) -> void:
	if not lines.visible: return
	elapsed-=delta
	if elapsed>0: return
	elapsed=1.0
	var actors=get_tree().get_nodes_in_group("tyrants")
	if actors.is_empty(): lines.mesh=null;return
	var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var colors=[Color.CYAN,Color.ORANGE,Color.MAGENTA,Color.GREEN]
	var index=0
	for actor in actors:
		for i in actor.patrol.size():
			segment(mesh,actor.patrol[i],actor.patrol[(i+1)%actor.patrol.size()],colors[index%4]*.65)
		var previous=actor.global_position
		for point in actor.path:
			segment(mesh,previous,point,colors[index%4]);previous=point
		index+=1
	mesh.surface_end();lines.mesh=mesh
func segment(mesh: ImmediateMesh,a: Vector3,b: Vector3,color: Color) -> void:
	var count=maxi(1,ceili(a.distance_to(b)/10.0))
	for i in count:
		for t in [float(i)/count,float(i+1)/count]:
			var p=a.lerp(b,t);p.y=get_parent().height_at(p.x,p.z)+1.0
			mesh.surface_set_color(color);mesh.surface_add_vertex(p)
