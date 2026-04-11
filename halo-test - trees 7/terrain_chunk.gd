extends Node3D
class_name TerrainChunk

@export var chunk_size: float = 50.0
@export var resolution: int = 10
@export var height_scale: float = 5.0

var chunk_coords: Vector2i
var is_loaded: bool = false
var mesh_instance: MeshInstance3D
var collision_body: StaticBody3D
var noise: FastNoiseLite

func _ready():
	# Initialize will be called after this
	pass

func initialize(coords: Vector2i, world_noise: FastNoiseLite):
	chunk_coords = coords
	noise = world_noise
	position = Vector3(
		coords.x * chunk_size,
		0,
		coords.y * chunk_size
	)

func load_chunk():
	if is_loaded:
		return
	
	is_loaded = true
	visible = true
	
	if not mesh_instance:
		generate_terrain()
	
	set_physics_process(true)

func unload_chunk():
	if not is_loaded:
		return
	
	is_loaded = false
	visible = false
	set_physics_process(false)

func generate_terrain():
	# Create mesh instance
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	# Generate mesh
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	
	# Generate vertices
	var step = chunk_size / resolution
	for z in range(resolution + 1):
		for x in range(resolution + 1):
			var local_x = x * step - chunk_size / 2
			var local_z = z * step - chunk_size / 2
			
			var world_x = local_x + position.x
			var world_z = local_z + position.z
			
			var height = noise.get_noise_2d(world_x * 0.01, world_z * 0.01) * height_scale
			
			vertices.push_back(Vector3(local_x, height, local_z))
			uvs.push_back(Vector2(float(x) / resolution, float(z) / resolution))
	
	# Calculate normals and create triangles
	var indices = PackedInt32Array()
	
	for z in range(resolution):
		for x in range(resolution):
			var idx = z * (resolution + 1) + x
			
			# Triangle 1
			indices.push_back(idx)
			indices.push_back(idx + resolution + 1)
			indices.push_back(idx + 1)
			
			# Triangle 2  
			indices.push_back(idx + 1)
			indices.push_back(idx + resolution + 1)
			indices.push_back(idx + resolution + 2)
	
	# Calculate normals
	for i in range(vertices.size()):
		normals.push_back(Vector3.UP)
	
	# Recalculate normals based on triangles
	for i in range(0, indices.size(), 3):
		var i0 = indices[i]
		var i1 = indices[i + 1]
		var i2 = indices[i + 2]
		
		var v0 = vertices[i0]
		var v1 = vertices[i1]
		var v2 = vertices[i2]
		
		var normal = (v1 - v0).cross(v2 - v0).normalized()
		
		normals[i0] = normals[i0].lerp(normal, 0.5).normalized()
		normals[i1] = normals[i1].lerp(normal, 0.5).normalized()
		normals[i2] = normals[i2].lerp(normal, 0.5).normalized()
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh
	
	# Add material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.6, 0.2)
	material.roughness = 0.9
	mesh_instance.material_override = material
	
	# Create collision
	collision_body = StaticBody3D.new()
	add_child(collision_body)
	
	var collision_shape = CollisionShape3D.new()
	collision_body.add_child(collision_shape)
	
	# Create collision shape from mesh
	var trimesh = mesh_instance.mesh.create_trimesh_shape()
	collision_shape.shape = trimesh
	
	# Add some props
	generate_props()

func generate_props():
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_coords)
	
	var props_node = Node3D.new()
	props_node.name = "Props"
	add_child(props_node)
	
	# Add trees
	for i in range(rng.randi_range(2, 8)):
		var tree = create_simple_tree()
		var x = rng.randf_range(-chunk_size/2 + 2, chunk_size/2 - 2)
		var z = rng.randf_range(-chunk_size/2 + 2, chunk_size/2 - 2)
		var world_x = x + position.x
		var world_z = z + position.z
		var y = noise.get_noise_2d(world_x * 0.01, world_z * 0.01) * height_scale
		
		tree.position = Vector3(x, y, z)
		tree.rotate_y(rng.randf() * TAU)
		tree.scale *= rng.randf_range(0.8, 1.2)
		props_node.add_child(tree)

func create_simple_tree() -> Node3D:
	var tree = Node3D.new()
	
	# Trunk
	var trunk = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.height = 3
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.2
	trunk.mesh = cylinder
	trunk.position.y = 1.5
	
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.25, 0.1)
	trunk.material_override = trunk_mat
	
	tree.add_child(trunk)
	
	# Leaves
	var leaves = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3
	sphere.radial_segments = 8
	sphere.rings = 4
	leaves.mesh = sphere
	leaves.position.y = 3.5
	
	var leaves_mat = StandardMaterial3D.new()
	leaves_mat.albedo_color = Color(0.1, 0.4, 0.1)
	leaves.material_override = leaves_mat
	
	tree.add_child(leaves)
	
	return tree
