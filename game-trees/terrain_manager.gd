extends Node3D
class_name TerrainManager

@export var chunk_size: float = 50.0
@export var view_distance: int = 3
@export var unload_distance: int = 4
@export var world_seed: int = 12345

var TerrainChunkScene = preload("res://terrain_chunk.tscn")
var chunks: Dictionary = {}
var player: Node3D
var noise: FastNoiseLite
var last_player_chunk: Vector2i

func _ready():
	# Setup noise for terrain generation
	noise = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.001
	noise.fractal_octaves = 4
	
	# Find player
	player = get_node_or_null("../Player")
	if not player:
		push_warning("No player found! Terrain streaming disabled.")
		return
	
	# Initial chunk load
	update_chunks()

func _process(_delta):
	if not player:
		return
	
	var player_chunk = get_chunk_coords(player.global_position)
	
	# Only update if player moved to new chunk
	if player_chunk != last_player_chunk:
		last_player_chunk = player_chunk
		update_chunks()

func get_chunk_coords(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)

func update_chunks():
	var player_chunk = get_chunk_coords(player.global_position)
	
	# Load chunks within view distance
	for x in range(-view_distance, view_distance + 1):
		for z in range(-view_distance, view_distance + 1):
			var chunk_coord = player_chunk + Vector2i(x, z)
			
			if not chunk_coord in chunks:
				create_chunk(chunk_coord)
			
			var chunk = chunks[chunk_coord]
			var distance = Vector2(x, z).length()
			
			if distance <= view_distance:
				chunk.load_chunk()
	
	# Unload distant chunks
	for coord in chunks:
		var distance = (coord - player_chunk).length()
		if distance > unload_distance:
			chunks[coord].unload_chunk()

func create_chunk(coords: Vector2i):
	# Create chunk directly from script instead of scene
	var chunk = Node3D.new()
	chunk.set_script(preload("res://terrain_chunk.gd"))
	chunk.chunk_size = chunk_size
	chunk.initialize(coords, noise)
	add_child(chunk)
	chunks[coords] = chunk

func get_height_at_position(world_pos: Vector3) -> float:
	return noise.get_noise_2d(world_pos.x * 0.01, world_pos.z * 0.01) * 5.0
