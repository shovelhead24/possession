extends MeshInstance3D
## One depth-aware pass; fixed world altitude rather than camera-following fog.
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var material: ShaderMaterial
var ceiling := 25.0
func setup(owner_arena: Node3D):
	arena=owner_arena
	ceiling=arena.source.surface_height(Vector2(120,145))+25.0
	mesh=QuadMesh.new();mesh.size=Vector2(2,2)
	material=ShaderMaterial.new();material.shader=preload("res://world/performance_valley_mist.gdshader")
	material.render_priority=90;material_override=material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin=1000000;physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	position=Vector3(0,0,-1);hide()
func _process(_delta: float):
	if not visible:return
	var camera_position: Vector3=arena.camera.global_position
	material.set_shader_parameter("camera_altitude",Ring.coordinates(camera_position).y)
	material.set_shader_parameter("local_up",Ring.up_at(camera_position))
	material.set_shader_parameter("mist_ceiling",ceiling)
