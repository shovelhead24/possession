extends Node3D
class_name TerrainManager

const BiomeDefs = preload("res://biome_definitions.gd")

@export_group("Chunk Settings")
@export var chunk_size: float = 100.0  # 4x larger — same polygon count, 4x render distance per chunk
@export var view_distance: int = 100   # 100 * 100m = 10km
@export var unload_distance: int = 110  # Must be > view_distance

@export_group("LOD Settings")
@export var lod_distances: Array[float] = [3.0, 8.0, 20.0, 50.0, 100.0]  # LOD0=300m LOD1=800m LOD2=2km LOD3=5km LOD4=10km
@export var lod_hysteresis: float = 1.0  # Buffer to prevent rapid LOD switching

@export_group("Terrain Generation")
@export var world_seed: int = 12345
@export var use_heightmap: bool = false
@export var heightmap_path: String = "res://Rugged Terrain with Rocky Peaks Height Map EXR.exr"
@export var terrain_width: float = 1000.0  # World size of the heightmap
@export var terrain_depth: float = 1000.0
@export var terrain_height: float = 400.0  # Max terrain height in world units (increased for rolling hills)
@export var use_custom_terrain: bool = false  # Use handcrafted terrain (two hills, canyon, river)

@export_group("Ring Dimensions")
@export var ring_width: float = 10000.0  # Edge-to-edge width in world units (10km)
@export var ring_length: float = 100000.0  # Length along ring (essentially infinite for now)
@export var wall_thickness: float = 20.0  # Thickness of boundary walls
@export var wall_height: float = 300.0  # Height of boundary walls (visible barrier) - must be above water
@export var edge_mountain_zone: float = 500.0  # Distance from edge where mountains are forced
@export var use_continental_coastline: bool = false  # Use FBM for consistent coastlines (experimental)

@export_group("Structured Terrain")
@export var use_structured_terrain: bool = true
@export var plains_radius: float = 2000.0       # Flat grassland within this dist from origin
@export var foothills_radius: float = 4000.0    # Rolling hills transition zone outer edge
@export var plains_base_height: float = 50.0    # Base plains elevation (above 32m biome water)
@export var plains_variation: float = 8.0       # Gentle noise amplitude on plains
@export var mountain_boost: float = 1.55        # Push mountain peaks into snow zone (300m+)

@export_group("Biome Settings")
@export_enum("Ring Edge Mountains", "Rolling Plains", "Dense Forest", "Highland Plateau", "River Valley", "Rocky Badlands", "Coastal Lowlands") var biome_type: int = 1
@export var water_level: float = 0.06  # Global water level (0-1 fraction of terrain_height) - water at ~48m
@export var use_global_water: bool = true  # Use single water level for all biomes
@export var enable_biome_blending: bool = false  # Blend between biomes based on position
@export var biome_blend_scale: float = 0.0003  # How large biome regions are (smaller = larger regions)
@export var biome_blend_width: float = 0.15  # Width of transition zones (0-0.5)

# Biome traits (loaded from BiomeDefinitions)
var current_biome_traits: BiomeDefs.NoiseTraits
var biome_colors: Dictionary

# Biome blending
var biome_noise: FastNoiseLite  # Noise for biome distribution
var all_biome_traits: Array = []  # Cache all biome traits
var all_biome_colors: Array = []  # Cache all biome colors

# Ring boundaries
var boundary_walls: Array = []  # Boundary wall meshes
var coastline_noise: FastNoiseLite  # Noise for consistent coastline (matches sky shader)

var chunks: Dictionary = {}
var player: Node3D
var noise: FastNoiseLite
var heightmap_image: Image
var last_player_chunk: Vector2i = Vector2i(-999, -999)

# Object pool for trees/props
var prop_pool: Node = null

# Global water plane (single height across entire world)
var water_plane: MeshInstance3D = null
var water_shader: Shader = null
var absolute_water_height: float = 0.0  # Calculated from water_level * terrain_height

# Chunk loading queue - prevents frame hitches by spreading load over time
var chunk_load_queue: Array = []  # Array of {coord: Vector2i, lod: int, distance: float}
var is_initial_load: bool = true  # True during first load, processes more chunks
var chunks_per_frame_initial: int = 8  # Bulk load at start (kept low to avoid frame tank)
var chunks_per_frame_normal: int = 6  # Chunks per frame during gameplay (LOD3+ are cheap)
var chunk_log_counter: int = 0  # Counter for FPS logging

# Chunk unloading queue - spreads unloading across frames like loading
var chunk_unload_queue: Array = []  # Array of chunk coords to unload
var unloads_per_frame: int = 2  # Max chunks to unload per frame
var unload_check_interval: int = 5  # Only check for unloads every N chunk moves
var chunk_move_counter: int = 0  # Count chunk moves since last unload check

# LOD update queue - spreads LOD changes across frames to prevent hitching
var lod_update_queue: Array = []  # Array of {coord: Vector2i, target_lod: int}
var lod_queued_set: Dictionary = {}  # O(1) lookup for LOD queue membership
var lod_updates_per_frame_lod0: int = 1  # LOD0 updates per frame (full shader rebuild - expensive)
var lod_updates_per_frame_distant: int = 50  # LOD1+ updates per frame (vertex color swap - cheap)

# Props generation limiter - only allow 1 chunk to generate props per frame
var props_generated_this_frame: bool = false

# Adaptive quality system - adjusts fidelity based on frame budget
@export_group("Performance Budget")
@export var target_fps: float = 60.0  # Target framerate
@export var chunk_budget_ms: float = 8.0  # Max ms per frame for chunk work
@export var enable_adaptive_quality: bool = true

# Adaptive quality state
var frame_chunk_time_ms: float = 0.0  # Time spent on chunks this frame
var avg_chunk_time_ms: float = 6.0  # Rolling average of chunk generation time
var quality_multiplier: float = 1.0  # 0.0-1.0, affects tree count, detail
var quality_trend: float = 0.0  # Positive = improving, negative = degrading

# Quality thresholds
const QUALITY_MIN: float = 0.3  # Minimum quality (30%)
const QUALITY_MAX: float = 1.0  # Maximum quality (100%)
const QUALITY_ADJUST_SPEED: float = 0.1  # How fast quality changes

const TerrainChunk = preload("res://terrain_chunk.gd")
const PropPoolClass = preload("res://prop_pool.gd")

func _ready():
	# Create prop pool for efficient tree/decorator management
	prop_pool = PropPoolClass.new()
	prop_pool.name = "PropPool"
	add_child(prop_pool)

	# Setup terrain generation method
	if use_heightmap and not heightmap_path.is_empty():
		if not load_heightmap():
			setup_noise_generator()
	else:
		setup_noise_generator()

	# Create global water plane
	create_global_water()

	# Find player
	find_or_create_player()

	# Initial chunk load
	call_deferred("update_chunks")

func setup_noise_generator():
	noise = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0  # Frequency scaling is done per-biome in get_noise_height_at_position

	# Setup biome blending noise (different seed for variety)
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = world_seed + 999
	biome_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	biome_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	biome_noise.frequency = biome_blend_scale

	# Setup coastline noise to match sky shader FBM pattern
	coastline_noise = FastNoiseLite.new()
	coastline_noise.seed = world_seed + 12345  # Same seed as skybox would use
	coastline_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	coastline_noise.frequency = 1.0  # We'll scale manually like the sky shader

	# Cache all biome traits and colors for blending
	all_biome_traits.clear()
	all_biome_colors.clear()
	for i in range(7):  # 7 biome types
		var biome_enum = i as BiomeDefs.BiomeType
		all_biome_traits.append(BiomeDefs.get_biome_traits(biome_enum))
		all_biome_colors.append(BiomeDefs.get_biome_colors(biome_enum))

	# Load current biome traits (used when blending disabled)
	var biome_enum = biome_type as BiomeDefs.BiomeType
	current_biome_traits = BiomeDefs.get_biome_traits(biome_enum)
	biome_colors = BiomeDefs.get_biome_colors(biome_enum)

	# Override water level from biome if specified
	if current_biome_traits.water_level >= 0:
		water_level = current_biome_traits.water_level

	var biome_name = BiomeDefs.get_biome_name(biome_enum)

	# Generate boundary walls
	generate_boundary_walls()

# FBM (Fractal Brownian Motion) for terrain - matches sky shader pattern
# Returns 0-1 range (normalized from -1..1 noise)
func terrain_fbm(pos: Vector2, octaves: int = 6) -> float:
	var value = 0.0
	var amplitude = 0.5
	var frequency = 1.0
	var total_amp = 0.0

	for i in range(octaves):
		# Normalize each noise sample to 0-1
		var n = (coastline_noise.get_noise_2d(pos.x * frequency, pos.y * frequency) + 1.0) * 0.5
		value += amplitude * n
		total_amp += amplitude
		amplitude *= 0.5
		frequency *= 2.0

	return value / total_amp

# Domain warping for organic coastline shapes - matches sky shader
func warp_domain(pos: Vector2, strength: float) -> Vector2:
	var warp_x = terrain_fbm(pos, 4) - 0.5  # Center around 0 for warping
	var warp_y = terrain_fbm(pos + Vector2(5.2, 1.3), 4) - 0.5
	return pos + Vector2(warp_x, warp_y) * strength

# High-detail FBM for coastlines - matches sky shader
# Returns 0-1 range
func coastline_fbm_value(pos: Vector2) -> float:
	var value = 0.0
	var amplitude = 0.5
	var frequency = 1.0
	var total_amp = 0.0

	# 8 octaves for detailed coastlines (same as sky shader)
	for i in range(8):
		var n = (coastline_noise.get_noise_2d(pos.x * frequency, pos.y * frequency) + 1.0) * 0.5
		value += amplitude * n
		total_amp += amplitude
		amplitude *= 0.5
		frequency *= 2.1  # Slightly non-integer for less repetition

	return value / total_amp

# Get continental mass value at position (matches sky shader land/water distribution)
# Returns 0-1 where values > 0.42 are land (matching sky shader water_threshold)
func get_continental_value(world_pos: Vector3) -> float:
	# Map world coordinates to ring UV space (matching sky shader)
	# ring_u = position along ring (X axis in world)
	# ring_v = position across ring width (Z axis in world)
	var ring_u = world_pos.x * 0.0001 * 15.0  # Scale to match sky shader ring_u
	var ring_v = (world_pos.z / (ring_width / 2.0)) * 3.0  # Scale to match sky shader ring_v

	var base_uv = Vector2(ring_u, ring_v)

	# Apply domain warping for organic continent shapes
	var warped_uv = warp_domain(base_uv * 0.5, 2.0)

	# Generate continental mass using high-detail FBM
	var continental = coastline_fbm_value(warped_uv * 1.5)

	# Add medium-scale terrain variation
	var terrain_mid = terrain_fbm(warped_uv * 4.0 + Vector2(100.0, 0.0), 5)

	# Fine detail for coastline complexity
	var coastline_detail = coastline_fbm_value(base_uv * 8.0 + warped_uv * 2.0)

	# Combine for land/water threshold with detailed coastlines
	var land_mass = continental * 0.6 + terrain_mid * 0.3 + coastline_detail * 0.1

	return clamp(land_mass, 0.0, 1.0)

func load_heightmap() -> bool:
	if heightmap_path.ends_with(".exr"):
		heightmap_image = Image.load_from_file(heightmap_path)
	else:
		var texture = load(heightmap_path) as Texture2D
		if texture:
			heightmap_image = texture.get_image()
	
	if not heightmap_image:
		push_error("Failed to load heightmap: " + heightmap_path)
		return false
	
	return true

func find_or_create_player():
	player = get_node_or_null("../Player")
	if not player:
		player = get_node_or_null("/root/World/Player")
	if not player:
		player = get_tree().get_first_node_in_group("player")

	if not player:
		push_warning("TerrainManager: No player found! Creating debug player at origin")
		player = Node3D.new()
		player.name = "DebugPlayer"
		player.position = Vector3.ZERO
		get_parent().add_child(player)

	if player:
		# Spawn location depends on terrain mode
		var spawn_x = 0.0
		var spawn_z = 0.0

		if use_custom_terrain:
			# Spawn on hill 1 (the left hill)
			spawn_x = -80.0
			spawn_z = 0.0
		# else: default spawn at center

		# Disable player physics while terrain loads (prevents falling)
		if player is CharacterBody3D:
			player.set_physics_process(false)

		# Put player high up temporarily while terrain loads
		player.global_position = Vector3(spawn_x, 200, spawn_z)

		# Calculate spawn chunk coords
		var spawn_chunk_coords = get_chunk_coords(Vector3(spawn_x, 0, spawn_z))

		# Force create the spawn chunk immediately if it doesn't exist
		if not spawn_chunk_coords in chunks:
			create_chunk(spawn_chunk_coords, 0)  # LOD 0 for best collision

		# Now wait until the chunk's collision is actually ready
		# The chunk should exist, but collision shape might need a physics frame to register
		var spawn_chunk = chunks[spawn_chunk_coords]

		# Wait for collision body to be in the scene tree and have a valid shape
		while not spawn_chunk.collision_body or not spawn_chunk.collision_body.is_inside_tree():
			await get_tree().process_frame
			player.global_position = Vector3(spawn_x, 200, spawn_z)  # Keep stable

		# Give physics engine 2 frames to register the collision
		for i in range(2):
			await get_tree().physics_frame
			player.global_position = Vector3(spawn_x, 200, spawn_z)

		# Now spawn on terrain
		var spawn_height = get_height_at_position(Vector3(spawn_x, 0, spawn_z)) + 2.0
		player.global_position = Vector3(spawn_x, spawn_height, spawn_z)

		# Re-enable physics and reset velocity
		if player is CharacterBody3D:
			player.velocity = Vector3.ZERO  # Critical: reset velocity before enabling physics
			player.set_physics_process(true)

func _process(delta):
	# Reset per-frame counters
	props_generated_this_frame = false
	frame_chunk_time_ms = 0.0

	# Update adaptive quality based on last frame's performance
	if enable_adaptive_quality:
		update_adaptive_quality(delta)

	if not player:
		return

	# Update water plane position to follow player (creates infinite water illusion)
	if water_plane and is_instance_valid(water_plane):
		water_plane.global_position.x = player.global_position.x
		water_plane.global_position.z = player.global_position.z
		# Keep Y at absolute water height
		water_plane.global_position.y = absolute_water_height

	var player_chunk = get_chunk_coords(player.global_position)

	# Queue new chunks when player moves to a new chunk
	if player_chunk != last_player_chunk:
		last_player_chunk = player_chunk
		queue_chunks_around_player()

	# Process queued chunks (spread load across frames)
	process_chunk_queue()

	# Process LOD update queue (spread LOD changes across frames)
	process_lod_queue()

	# Process unload queue (spread unloads across frames)
	process_unload_queue()

# Adaptive quality system - adjusts fidelity based on frame budget
func update_adaptive_quality(delta: float):
	var current_fps = Performance.get_monitor(Performance.TIME_FPS)
	var frame_time_ms = delta * 1000.0

	# Calculate how much headroom we have
	var target_frame_ms = 1000.0 / target_fps
	var headroom = target_frame_ms - frame_time_ms

	# Adjust quality based on headroom
	if headroom < -2.0:  # More than 2ms over budget - reduce quality
		quality_multiplier = clamp(quality_multiplier - QUALITY_ADJUST_SPEED * delta * 2.0, QUALITY_MIN, QUALITY_MAX)
		quality_trend = -1.0
	elif headroom > 4.0:  # More than 4ms under budget - can increase quality
		quality_multiplier = clamp(quality_multiplier + QUALITY_ADJUST_SPEED * delta * 0.5, QUALITY_MIN, QUALITY_MAX)
		quality_trend = 1.0
	else:
		quality_trend = 0.0

# Add time to frame chunk budget (called by chunks after generation)
func add_chunk_time(time_ms: float):
	frame_chunk_time_ms += time_ms
	# Update rolling average
	avg_chunk_time_ms = lerp(avg_chunk_time_ms, time_ms, 0.1)

# Get current quality-adjusted tree count for a chunk
func get_quality_tree_count(base_count: int) -> int:
	return int(base_count * quality_multiplier)

# Check if we have budget remaining for more chunk work this frame
func has_chunk_budget() -> bool:
	return frame_chunk_time_ms < chunk_budget_ms

# Get quality info for debugging/display
func get_quality_info() -> Dictionary:
	return {
		"multiplier": quality_multiplier,
		"trend": quality_trend,
		"frame_chunk_ms": frame_chunk_time_ms,
		"avg_chunk_ms": avg_chunk_time_ms,
		"budget_ms": chunk_budget_ms
	}

func get_chunk_coords(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)

func switch_biome(new_biome: int):
	if new_biome < 0 or new_biome > 6:
		return

	biome_type = new_biome

	# Reload biome traits
	var biome_enum = biome_type as BiomeDefs.BiomeType
	current_biome_traits = BiomeDefs.get_biome_traits(biome_enum)
	biome_colors = BiomeDefs.get_biome_colors(biome_enum)

	# Override water level from biome if specified
	if current_biome_traits.water_level >= 0:
		water_level = current_biome_traits.water_level

	# Clear all existing chunks
	for coord in chunks.keys():
		var chunk = chunks[coord]
		chunk.queue_free()
	chunks.clear()

	# Reset last player chunk to force regeneration
	last_player_chunk = Vector2i(-999, -999)

	# Regenerate chunks around player
	update_chunks()

# Generate boundary walls at ring edges
func generate_boundary_walls():
	# Clear existing walls
	for wall in boundary_walls:
		if is_instance_valid(wall):
			wall.queue_free()
	boundary_walls.clear()

	# Create wall material - massive grey metal
	var wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.35, 0.38, 0.42)  # Dark metallic grey
	wall_material.metallic = 0.6
	wall_material.roughness = 0.4
	wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	var half_width = ring_width / 2.0
	var half_length = ring_length / 2.0

	# Create walls on both Z edges (across the ring width)
	for side in [-1, 1]:
		var wall_mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(ring_length, wall_height, wall_thickness)
		wall_mesh.mesh = box
		wall_mesh.material_override = wall_material

		# Position at ring edge
		wall_mesh.position = Vector3(0, wall_height / 2.0, side * (half_width + wall_thickness / 2.0))

		add_child(wall_mesh)
		boundary_walls.append(wall_mesh)

		# Add collision for the wall
		var wall_body = StaticBody3D.new()
		wall_body.position = wall_mesh.position
		var collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = box.size
		collision_shape.shape = box_shape
		wall_body.add_child(collision_shape)
		add_child(wall_body)
		boundary_walls.append(wall_body)

# Create a single global water plane at absolute height
func create_global_water():
	# Calculate absolute water height
	absolute_water_height = water_level * terrain_height

	# Remove existing water plane if any
	if water_plane and is_instance_valid(water_plane):
		water_plane.queue_free()

	# Create large water plane that covers visible area
	# It will follow the player to create infinite water illusion
	water_plane = MeshInstance3D.new()
	water_plane.name = "GlobalWater"

	var plane_mesh = PlaneMesh.new()
	# Size water plane to cover actual water features, not the entire world
	var water_size: float
	water_size = 500.0  # Small plane follows player — only renders water nearby
	plane_mesh.size = Vector2(water_size, water_size)
	plane_mesh.subdivide_width = 64  # Subdivisions for wave animation
	plane_mesh.subdivide_depth = 64
	water_plane.mesh = plane_mesh

	# Set water height
	water_plane.position.y = absolute_water_height

	# Load and apply water shader
	var shader = load("res://water_shader.gdshader")
	if shader:
		var water_material = ShaderMaterial.new()
		water_material.shader = shader
		# Set shader parameters for nice ocean look
		water_material.set_shader_parameter("shallow_color", Color(0.15, 0.55, 0.65, 0.85))
		water_material.set_shader_parameter("deep_color", Color(0.02, 0.12, 0.25, 0.95))
		water_material.set_shader_parameter("wave_speed", 0.25)
		water_material.set_shader_parameter("wave_height", 1.2)
		water_material.set_shader_parameter("specular_intensity", 2.5)
		water_material.set_shader_parameter("glitter_intensity", 1.8)
		water_plane.material_override = water_material
	else:
		# Fallback material if shader not found
		var fallback_mat = StandardMaterial3D.new()
		fallback_mat.albedo_color = Color(0.15, 0.4, 0.55, 0.8)
		fallback_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fallback_mat.metallic = 0.3
		fallback_mat.roughness = 0.1
		water_plane.material_override = fallback_mat
		push_warning("Water shader not found, using fallback material")

	# Disable shadow casting for water
	water_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(water_plane)

# Check if a world position is within the ring boundaries
func is_within_ring_bounds(world_pos: Vector3) -> bool:
	var half_width = ring_width / 2.0
	var half_length = ring_length / 2.0
	return abs(world_pos.z) <= half_width and abs(world_pos.x) <= half_length

# Check if a chunk coordinate is within ring boundaries
func is_chunk_within_bounds(chunk_coord: Vector2i) -> bool:
	# Get chunk center position
	var chunk_center_x = (chunk_coord.x + 0.5) * chunk_size
	var chunk_center_z = (chunk_coord.y + 0.5) * chunk_size
	var half_width = ring_width / 2.0
	var half_length = ring_length / 2.0

	# Allow chunks that are partially within bounds
	var chunk_half = chunk_size / 2.0
	return abs(chunk_center_z) <= half_width + chunk_half and abs(chunk_center_x) <= half_length + chunk_half

# Get distance to nearest ring edge (positive = inside, negative = outside)
func get_distance_to_edge(world_pos: Vector3) -> float:
	var half_width = ring_width / 2.0
	var dist_to_z_edge = half_width - abs(world_pos.z)
	return dist_to_z_edge

# Get biome weights at a world position (returns array of [biome_index, weight] pairs)
func get_biome_weights_at(world_pos: Vector3) -> Array:
	# Force Ring Edge Mountains near ring boundaries
	var edge_dist = get_distance_to_edge(world_pos)
	if edge_dist <= edge_mountain_zone:
		# Within edge zone - blend to mountains based on proximity
		var mountain_weight = 1.0 - (edge_dist / edge_mountain_zone)
		mountain_weight = clamp(mountain_weight, 0.0, 1.0)
		# Square for smoother transition
		mountain_weight = mountain_weight * mountain_weight

		if mountain_weight > 0.95:
			# Pure mountains at edge
			return [[BiomeDefs.BiomeType.RING_EDGE_MOUNTAINS, 1.0]]
		elif not enable_biome_blending:
			# Blend mountains with selected biome
			return [[BiomeDefs.BiomeType.RING_EDGE_MOUNTAINS, mountain_weight], [biome_type, 1.0 - mountain_weight]]

	if not enable_biome_blending:
		return [[biome_type, 1.0]]

	var x = world_pos.x
	var z = world_pos.z

	# Sample cellular noise to get primary biome
	var cell_value = biome_noise.get_noise_2d(x, z)
	# Map -1 to 1 range to 1-6 biome indices (skip 0 = mountains, reserved for edges)
	var primary_biome = int((cell_value + 1.0) * 0.5 * 5.99) + 1
	primary_biome = clampi(primary_biome, 1, 6)

	# Sample nearby to find adjacent biomes for blending
	var sample_dist = 1.0 / biome_blend_scale * 0.3  # Sample at ~30% of cell size
	var neighbors = [
		Vector2(x + sample_dist, z),
		Vector2(x - sample_dist, z),
		Vector2(x, z + sample_dist),
		Vector2(x, z - sample_dist),
	]

	# Count biome occurrences
	var biome_counts = {}
	biome_counts[primary_biome] = 2.0  # Primary gets extra weight

	for neighbor in neighbors:
		var n_value = biome_noise.get_noise_2d(neighbor.x, neighbor.y)
		# Skip mountains (biome 0) - reserved for edges
		var n_biome = int((n_value + 1.0) * 0.5 * 5.99) + 1
		n_biome = clampi(n_biome, 1, 6)
		biome_counts[n_biome] = biome_counts.get(n_biome, 0.0) + 1.0

	# Normalize weights
	var total = 0.0
	for count in biome_counts.values():
		total += count

	var weights = []
	for biome_idx in biome_counts:
		var weight = biome_counts[biome_idx] / total
		if weight > 0.05:  # Only include significant weights
			weights.append([biome_idx, weight])

	# Add edge mountain blending if we're in the transition zone
	if edge_dist <= edge_mountain_zone and edge_dist > 0:
		var mountain_weight = 1.0 - (edge_dist / edge_mountain_zone)
		mountain_weight = clamp(mountain_weight * mountain_weight, 0.0, 0.95)
		if mountain_weight > 0.05:
			# Scale down other biome weights to make room for mountains
			var scale = 1.0 - mountain_weight
			for i in range(weights.size()):
				weights[i][1] *= scale
			weights.append([BiomeDefs.BiomeType.RING_EDGE_MOUNTAINS, mountain_weight])

	return weights

# Blend a float value from multiple biomes
func blend_float(weights: Array, getter: Callable) -> float:
	var result = 0.0
	for w in weights:
		var biome_idx = w[0]
		var weight = w[1]
		result += getter.call(all_biome_traits[biome_idx]) * weight
	return result

# Get blended biome traits at a position
func get_blended_traits_at(world_pos: Vector3) -> Dictionary:
	var weights = get_biome_weights_at(world_pos)

	if weights.size() == 1:
		# Single biome, no blending needed
		var idx = weights[0][0]
		return {"traits": all_biome_traits[idx], "colors": all_biome_colors[idx], "weights": weights}

	# Blend numeric traits
	var blended = BiomeDefs.NoiseTraits.new()

	blended.continental_freq = blend_float(weights, func(t): return t.continental_freq)
	blended.mountain_freq = blend_float(weights, func(t): return t.mountain_freq)
	blended.hill_freq = blend_float(weights, func(t): return t.hill_freq)
	blended.detail_freq = blend_float(weights, func(t): return t.detail_freq)

	blended.continental_weight = blend_float(weights, func(t): return t.continental_weight)
	blended.mountain_weight = blend_float(weights, func(t): return t.mountain_weight)
	blended.hill_weight = blend_float(weights, func(t): return t.hill_weight)
	blended.detail_weight = blend_float(weights, func(t): return t.detail_weight)

	blended.height_multiplier = blend_float(weights, func(t): return t.height_multiplier)
	blended.base_elevation = blend_float(weights, func(t): return t.base_elevation)

	blended.warp_strength = blend_float(weights, func(t): return t.warp_strength)
	blended.warp_frequency = blend_float(weights, func(t): return t.warp_frequency)
	blended.ridge_power = blend_float(weights, func(t): return t.ridge_power)

	blended.micro_freq = blend_float(weights, func(t): return t.micro_freq)
	blended.micro_weight = blend_float(weights, func(t): return t.micro_weight)
	blended.micro_warp_strength = blend_float(weights, func(t): return t.micro_warp_strength)
	blended.micro_warp_freq = blend_float(weights, func(t): return t.micro_warp_freq)

	blended.tree_density = blend_float(weights, func(t): return t.tree_density)
	blended.tree_min_height = blend_float(weights, func(t): return t.tree_min_height)
	blended.tree_max_height = blend_float(weights, func(t): return t.tree_max_height)

	# Water level: use max of weighted levels (avoid dry biomes canceling water)
	var max_water = -1.0
	for w in weights:
		var wl = all_biome_traits[w[0]].water_level
		if wl >= 0:
			max_water = max(max_water, wl * w[1] + blended.base_elevation)
	blended.water_level = max_water

	# Blend colors
	var blended_colors = {}
	var color_keys = ["deep_water", "shallow_water", "beach", "grass", "dark_grass", "forest", "rock", "snow"]
	for key in color_keys:
		var blended_color = Color(0, 0, 0, 0)
		for w in weights:
			var c = all_biome_colors[w[0]].get(key, Color.WHITE)
			blended_color += Color(c.r * w[1], c.g * w[1], c.b * w[1], 1.0)
		blended_colors[key] = blended_color

	return {"traits": blended, "colors": blended_colors, "weights": weights}

func get_lod_for_distance(distance: float, current_lod: int = -1) -> int:
	for i in range(lod_distances.size()):
		var threshold = lod_distances[i]
		# Apply hysteresis - only switch if we've moved past threshold by buffer amount
		if current_lod >= 0 and current_lod == i:
			threshold += lod_hysteresis  # Need to move further to switch away
		if distance <= threshold:
			return i
	return lod_distances.size() - 1  # Max LOD for very distant chunks

# Build ring-based LOD lookup table: ring_lod[int_distance] = LOD level
# Precomputed once per queue rebuild — O(view_distance) instead of O(chunks)
func _build_ring_lod_table() -> PackedInt32Array:
	var height_chunks = abs(player.global_position.y) / chunk_size
	var height_sq = height_chunks * height_chunks
	var table = PackedInt32Array()
	table.resize(view_distance + 2)
	for d in range(view_distance + 2):
		# Effective 3D distance for this ring, using squared comparison
		var effective_dist = sqrt(float(d * d) + height_sq)
		table[d] = get_lod_for_distance(effective_dist, -1)
	return table

# Queue chunks around player sorted by distance (ring pattern - closest first)
func queue_chunks_around_player():
	var player_chunk = get_chunk_coords(player.global_position)

	# Precompute LOD for each distance ring — one lookup per ring, not per chunk
	var ring_lod = _build_ring_lod_table()

	# Build set of already-queued coords for O(1) lookup instead of O(n) scan
	var queued_set := {}
	for item in chunk_load_queue:
		queued_set[item.coord] = true

	var needed_chunks: Array = []
	var vd_sq = view_distance * view_distance

	# Iterate only within the circular radius — skip square corners entirely
	for x in range(-view_distance, view_distance + 1):
		var x_sq = x * x
		# Max z for this row: sqrt(vd² - x²)
		var z_max = int(sqrt(float(vd_sq - x_sq)))

		for z in range(-z_max, z_max + 1):
			var chunk_coord = player_chunk + Vector2i(x, z)

			# Skip chunks outside ring boundaries
			if not is_chunk_within_bounds(chunk_coord):
				continue

			var dist_sq = x_sq + z * z
			var dist_int = mini(int(sqrt(float(dist_sq))), view_distance + 1)

			# Skip already loaded chunks (but queue LOD update if needed)
			if chunk_coord in chunks:
				var chunk = chunks[chunk_coord]
				var current_lod = chunk.current_lod if "current_lod" in chunk else 0
				var target_lod = ring_lod[dist_int]
				if target_lod != current_lod:
					if chunk_coord not in lod_queued_set:
						lod_update_queue.append({"coord": chunk_coord, "target_lod": target_lod})
						lod_queued_set[chunk_coord] = true
				continue

			# Skip if already in queue (O(1) dict lookup)
			if chunk_coord in queued_set:
				continue

			needed_chunks.append({
				"coord": chunk_coord,
				"lod": ring_lod[dist_int],
				"distance": sqrt(float(dist_sq))
			})

	# Sort by distance descending — pop_back() grabs closest first
	needed_chunks.sort_custom(func(a, b): return a.distance > b.distance)
	chunk_load_queue.append_array(needed_chunks)

	chunk_move_counter += 1
	if chunk_move_counter >= unload_check_interval:
		chunk_move_counter = 0
		queue_distant_chunks_for_unload()

# Process chunk loading queue - spread across frames to prevent hitching
func process_chunk_queue():
	if chunk_load_queue.is_empty():
		if is_initial_load:
			is_initial_load = false
		return

	var player_chunk = get_chunk_coords(player.global_position)

	# Queue is sorted by distance when built in queue_chunks_around_player()
	# No per-frame re-sort needed — queue rebuilds every time player crosses a chunk boundary

	# Budget: LOD 0 is expensive (full shader), everything else is cheap (vertex colors)
	var close_budget = chunks_per_frame_initial if is_initial_load else chunks_per_frame_normal
	var distant_budget = 50  # LOD 1+ = vertex colors + few verts, very cheap
	var close_processed = 0
	var distant_processed = 0

	while not chunk_load_queue.is_empty():
		if close_processed >= close_budget and distant_processed >= distant_budget:
			break

		var item = chunk_load_queue.pop_back()
		var coord = item.coord

		# Skip if chunk was already created
		if coord in chunks:
			continue

		# Skip if now out of range (player moved)
		var current_distance = (coord - player_chunk).length()
		if current_distance > view_distance:
			continue

		# Use the LOD from the queue item (set by ring table at queue time)
		var lod = item.lod

		# Enforce per-LOD budget
		if lod == 0:
			if close_processed >= close_budget:
				chunk_load_queue.push_back(item)
				break
			close_processed += 1
		else:
			if distant_processed >= distant_budget:
				chunk_load_queue.push_back(item)  # Put it back! Don't drain the queue
				break
			distant_processed += 1

		create_chunk(coord, lod)

# Process LOD update queue - spread LOD changes across frames
func process_lod_queue():
	if lod_update_queue.is_empty():
		return

	# No budget gate here! LOD updates must flow or distant terrain never transitions.
	# Split budget: LOD0 is expensive (full shader rebuild), LOD1+ is cheap (vertex color swap)
	var lod0_updated = 0
	var distant_updated = 0

	while not lod_update_queue.is_empty():
		if lod0_updated >= lod_updates_per_frame_lod0 and distant_updated >= lod_updates_per_frame_distant:
			break

		var item = lod_update_queue.pop_back()  # O(1) instead of pop_front O(n)
		var coord = item.coord
		var target_lod = item.target_lod
		lod_queued_set.erase(coord)

		# Skip if chunk no longer exists
		if not coord in chunks:
			continue

		var chunk = chunks[coord]
		# Safety check - chunk may have been freed
		if not is_instance_valid(chunk):
			chunks.erase(coord)
			continue

		var current_lod = chunk.current_lod if "current_lod" in chunk else 0

		# Skip if LOD already matches (player may have moved back)
		if current_lod == target_lod:
			continue

		# Enforce per-LOD budget
		if target_lod == 0:
			if lod0_updated >= lod_updates_per_frame_lod0:
				lod_update_queue.push_back(item)
				lod_queued_set[coord] = true
				break
			lod0_updated += 1
		else:
			if distant_updated >= lod_updates_per_frame_distant:
				lod_update_queue.push_back(item)
				lod_queued_set[coord] = true
				break
			distant_updated += 1

		# Apply the LOD change
		if chunk.has_method("set_lod"):
			chunk.set_lod(target_lod)

# Queue distant chunks for unloading (doesn't unload immediately)
func queue_distant_chunks_for_unload():
	var player_chunk = get_chunk_coords(player.global_position)

	for coord in chunks:
		# Skip if already queued for unload
		if coord in chunk_unload_queue:
			continue

		var distance = (coord - player_chunk).length()
		if distance > unload_distance:
			chunk_unload_queue.append(coord)

# Process chunk unload queue - spread unloads across frames
func process_unload_queue():
	if chunk_unload_queue.is_empty():
		return

	var unloaded = 0
	var player_chunk = get_chunk_coords(player.global_position)

	while not chunk_unload_queue.is_empty() and unloaded < unloads_per_frame:
		var coord = chunk_unload_queue.pop_back()  # O(1) instead of pop_front O(n)

		# Skip if chunk no longer exists
		if not coord in chunks:
			continue

		var chunk = chunks[coord]
		# Safety check - chunk may have been freed already
		if not is_instance_valid(chunk):
			chunks.erase(coord)
			continue

		# Double-check still out of range (player may have moved back)
		var distance = (coord - player_chunk).length()
		if distance <= unload_distance:
			continue

		# Chunk's _exit_tree will return trees to pool automatically
		chunk.queue_free()
		chunks.erase(coord)
		unloaded += 1

# Legacy function - now redirects to queue system
func update_chunks():
	queue_chunks_around_player()

func create_chunk(coords: Vector2i, lod: int = 0):
	var chunk = TerrainChunk.new()
	chunk.name = "Chunk_" + str(coords.x) + "_" + str(coords.y)

	chunk.chunk_size = chunk_size
	chunk.height_scale = terrain_height  # Always use terrain_height

	add_child(chunk)

	# Pass the terrain manager reference so chunk can query heights
	chunk.terrain_manager = self
	chunk.initialize(coords, noise, lod)

	chunks[coords] = chunk

# Unified height function that works with both heightmap and noise
func get_height_at_position(world_pos: Vector3) -> float:
	if use_custom_terrain:
		return get_custom_terrain_height(world_pos)
	elif use_heightmap and heightmap_image:
		return get_heightmap_height_at_position(world_pos)
	else:
		return get_noise_height_at_position(world_pos)

# Custom terrain: Two hills with a canyon and river between them
# Layout: Hill1 at (-80, 0), Hill2 at (80, 0), Canyon/River along X=0
func get_custom_terrain_height(world_pos: Vector3) -> float:
	var x = world_pos.x
	var z = world_pos.z

	# Hill parameters
	var hill1_center = Vector2(-80, 0)
	var hill2_center = Vector2(80, 0)
	var hill_radius = 100.0  # How wide the hills are
	var hill_height = 40.0   # Max hill height above base

	# Canyon/river parameters
	var canyon_width = 30.0  # Width of canyon at top
	var canyon_depth = 15.0  # How deep the canyon is
	var river_level = 8.0    # Water level in the river

	# Base terrain height
	var base_height = 20.0

	# Calculate distance from each hill center
	var pos2d = Vector2(x, z)
	var dist_to_hill1 = pos2d.distance_to(hill1_center)
	var dist_to_hill2 = pos2d.distance_to(hill2_center)

	# Hill 1 contribution (smooth falloff)
	var hill1_factor = 1.0 - clamp(dist_to_hill1 / hill_radius, 0.0, 1.0)
	hill1_factor = hill1_factor * hill1_factor * (3.0 - 2.0 * hill1_factor)  # Smoothstep
	var hill1_height_contrib = hill1_factor * hill_height

	# Hill 2 contribution
	var hill2_factor = 1.0 - clamp(dist_to_hill2 / hill_radius, 0.0, 1.0)
	hill2_factor = hill2_factor * hill2_factor * (3.0 - 2.0 * hill2_factor)
	var hill2_height_contrib = hill2_factor * hill_height

	# Canyon: carve down near x=0
	var canyon_factor = 1.0 - clamp(abs(x) / canyon_width, 0.0, 1.0)
	canyon_factor = canyon_factor * canyon_factor  # Steeper canyon walls
	var canyon_carve = canyon_factor * canyon_depth

	# Combine: base + hills - canyon
	var height = base_height + hill1_height_contrib + hill2_height_contrib - canyon_carve

	# Add subtle noise for natural look
	if noise:
		var detail = noise.get_noise_2d(x * 0.05, z * 0.05) * 3.0
		height += detail

	# River bottom (flatten the canyon floor)
	if canyon_factor > 0.7:
		height = max(height, river_level - 2.0)  # Canyon floor just below water

	return max(height, 0.0)

func get_heightmap_height_at_position(world_pos: Vector3) -> float:
	# Convert world position to UV coordinates (0-1 range)
	var uv_x = (world_pos.x + terrain_width / 2.0) / terrain_width
	var uv_z = (world_pos.z + terrain_depth / 2.0) / terrain_depth

	# Clamp to valid range
	uv_x = clamp(uv_x, 0.0, 1.0)
	uv_z = clamp(uv_z, 0.0, 1.0)

	# Convert to image pixel coordinates (floating point for interpolation)
	var img_width = heightmap_image.get_width()
	var img_height = heightmap_image.get_height()
	var img_x_f = uv_x * (img_width - 1)
	var img_z_f = uv_z * (img_height - 1)

	# Bilinear interpolation for smooth terrain
	var x0 = int(floor(img_x_f))
	var z0 = int(floor(img_z_f))
	var x1 = min(x0 + 1, img_width - 1)
	var z1 = min(z0 + 1, img_height - 1)

	var x_frac = img_x_f - x0
	var z_frac = img_z_f - z0

	# Sample four neighboring pixels
	var h00 = heightmap_image.get_pixel(x0, z0).r
	var h10 = heightmap_image.get_pixel(x1, z0).r
	var h01 = heightmap_image.get_pixel(x0, z1).r
	var h11 = heightmap_image.get_pixel(x1, z1).r

	# Bilinear interpolation
	var h0 = lerp(h00, h10, x_frac)
	var h1 = lerp(h01, h11, x_frac)
	var height_value = lerp(h0, h1, z_frac)

	# Scale to world height
	return height_value * terrain_height

func get_noise_height_at_position(world_pos: Vector3) -> float:
	if not noise:
		push_error("Noise not initialized!")
		return 0.0

	# Get traits - either blended or single biome
	var traits: BiomeDefs.NoiseTraits
	if enable_biome_blending and all_biome_traits.size() > 0:
		var blended = get_blended_traits_at(world_pos)
		traits = blended.traits
	else:
		if not current_biome_traits:
			push_error("Biome traits not loaded!")
			return 0.0
		traits = current_biome_traits

	var x = world_pos.x
	var z = world_pos.z

	# Apply domain warping for weathered, ridge-like terrain
	# Use separate noise samples to warp the input coordinates
	if traits.warp_strength > 0:
		var warp_x = noise.get_noise_2d(x * traits.warp_frequency, z * traits.warp_frequency) * traits.warp_strength
		var warp_z = noise.get_noise_2d(x * traits.warp_frequency + 100.0, z * traits.warp_frequency + 100.0) * traits.warp_strength
		x += warp_x
		z += warp_z

	# Multi-octave terrain using biome-specific frequencies and weights
	var height = 0.0

	# Continental scale
	height += (noise.get_noise_2d(x * traits.continental_freq, z * traits.continental_freq) + 1.0) * 0.5 * traits.continental_weight

	# Mountain/large feature scale
	height += (noise.get_noise_2d(x * traits.mountain_freq, z * traits.mountain_freq) + 1.0) * 0.5 * traits.mountain_weight

	# Hill scale
	height += (noise.get_noise_2d(x * traits.hill_freq, z * traits.hill_freq) + 1.0) * 0.5 * traits.hill_weight

	# Detail scale
	height += (noise.get_noise_2d(x * traits.detail_freq, z * traits.detail_freq) + 1.0) * 0.5 * traits.detail_weight

	# Micro-detail scale with its own domain warping for close-range rocky features
	var micro_x = x
	var micro_z = z
	if traits.micro_warp_strength > 0:
		var mwarp_x = noise.get_noise_2d(x * traits.micro_warp_freq + 200.0, z * traits.micro_warp_freq) * traits.micro_warp_strength
		var mwarp_z = noise.get_noise_2d(x * traits.micro_warp_freq, z * traits.micro_warp_freq + 200.0) * traits.micro_warp_strength
		micro_x += mwarp_x
		micro_z += mwarp_z

	# Add micro detail (creates rocky outcrops and small terrain features)
	var micro_noise = (noise.get_noise_2d(micro_x * traits.micro_freq, micro_z * traits.micro_freq) + 1.0) * 0.5
	# Apply a power curve to make the micro features more pronounced in some spots
	micro_noise = pow(micro_noise, 1.5) * traits.micro_weight
	height += micro_noise

	# Optional: Apply continental influence for consistent coastlines with skybox
	if use_continental_coastline and coastline_noise:
		var continental_value = get_continental_value(world_pos)
		var water_threshold = 0.40  # ~40% land
		var land_factor = smoothstep_gd(water_threshold - 0.08, water_threshold + 0.08, continental_value)
		var ocean_floor = 0.05
		height = lerp(ocean_floor, height, land_factor)

	# height is now 0-1 range, apply base elevation offset
	height = clamp(height + traits.base_elevation, 0.0, 1.0)

	# Apply ridge power for sharper features (values > 1 create sharper ridges)
	if traits.ridge_power != 1.0:
		height = pow(height, traits.ridge_power)

	# Coastal erosion effect: flatten terrain near water level
	# Simulates wave action smoothing coastal areas
	var coastal_erosion_range = 0.15  # How far above water level erosion affects (normalized)
	var water_norm = water_level  # Water level as fraction of terrain (0-1)

	# Calculate how far above water this point is (normalized)
	var height_above_water = height - water_norm

	if height_above_water > 0.0 and height_above_water < coastal_erosion_range:
		# Erosion strength: strongest at water level, fades with height
		var erosion_factor = 1.0 - (height_above_water / coastal_erosion_range)
		erosion_factor = erosion_factor * erosion_factor  # Quadratic falloff

		# Flatten toward a gentle slope above water
		var target_height = water_norm + height_above_water * 0.3  # Flatten to 30% of original steepness
		height = lerp(height, target_height, erosion_factor * 0.7)  # 70% max erosion

	# Scale to world height with biome height multiplier
	var final_height = height * terrain_height * traits.height_multiplier

	# --- Structured terrain: radial zone shaping + river carving ---
	if use_structured_terrain:
		var wx = world_pos.x
		var wz = world_pos.z
		var dist = sqrt(wx * wx + wz * wz)

		# Zone factor: 0.0 = pure plains, 1.0 = full mountains
		var zone_factor: float
		if dist < plains_radius:
			zone_factor = 0.0
		elif dist < foothills_radius:
			zone_factor = smoothstep_gd(plains_radius, foothills_radius, dist)
		else:
			zone_factor = 1.0

		# Plains target: gentle undulation above water level
		var plains_noise = (noise.get_noise_2d(x * 0.003, z * 0.003) + 1.0) * 0.5
		var plains_target = plains_base_height + plains_noise * plains_variation

		# Mountain target: boost noise height to push peaks into snow zone (300m+)
		var mountain_target = final_height * mountain_boost

		# Blend between plains and mountains
		final_height = lerp(plains_target, mountain_target, zone_factor)

		# River carving — suppress in mountain zone where water plane looks wrong
		var river_suppress = smoothstep_gd(foothills_radius - 500.0, foothills_radius + 200.0, dist)
		if river_suppress < 1.0:
			var river_center_z = get_river_center_z(wx)
			var river_dist = abs(wz - river_center_z)

			# Width tapers: wide gentle river in plains → narrow gorge in foothills
			var active_half_width = lerp(25.0, 8.0, zone_factor)
			var active_bank_width = lerp(30.0, 12.0, zone_factor)

			var river_factor = smoothstep_gd(
				active_half_width + active_bank_width,
				active_half_width,
				river_dist)
			river_factor *= (1.0 - river_suppress)

			# River bottom sits below water plane so it fills with water
			var river_bottom = absolute_water_height - 2.0
			final_height = lerp(final_height, river_bottom, river_factor)

	return final_height

# GDScript smoothstep helper
func smoothstep_gd(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

# Returns the Z centerline of the river at a given world X position.
# Three overlapping sine waves produce natural, non-repeating bends
# staying within ~380m of Z=0 — well inside the 2km plains radius.
func get_river_center_z(world_x: float) -> float:
	return (200.0 * sin(world_x * 0.0008)
		  + 120.0 * sin(world_x * 0.002 + 1.5)
		  +  60.0 * sin(world_x * 0.005 + 3.0))

# --- Phase 2: Height Brush API ---
enum BrushFalloff { GAUSSIAN = 0, LINEAR = 1, HARD = 2 }

# Apply an additive height delta over a circular area. Mutates affected chunks'
# height_offsets arrays in place but does NOT rebuild meshes (caller does that).
# Returns an Array of Vector2i chunk coords that were modified (dirty set).
func apply_height_brush(world_pos: Vector3, radius: float, strength: float, falloff: int = BrushFalloff.GAUSSIAN) -> Array:
	var dirty: Array = []
	if radius <= 0.0 or absf(strength) < 0.0001:
		return dirty
	# Chunks are centered on coords*chunk_size, but get_chunk_coords uses floor division
	# which treats them as left-aligned. Expand the search box by half a chunk on each
	# side so we never miss a chunk whose vertices fall inside the brush radius.
	var half_cs: float = chunk_size * 0.5
	var min_coord: Vector2i = get_chunk_coords(Vector3(world_pos.x - radius - half_cs, 0.0, world_pos.z - radius - half_cs))
	var max_coord: Vector2i = get_chunk_coords(Vector3(world_pos.x + radius + half_cs, 0.0, world_pos.z + radius + half_cs))
	for cz in range(min_coord.y, max_coord.y + 1):
		for cx in range(min_coord.x, max_coord.x + 1):
			var coord: Vector2i = Vector2i(cx, cz)
			if not chunks.has(coord):
				continue
			var chunk = chunks[coord]
			if chunk == null or not "height_offsets" in chunk:
				continue
			if chunk.height_offsets.is_empty():
				chunk._ensure_offsets_sized()
			var res: int = chunk.resolution
			var stride: int = res + 1
			var cs: float = chunk.chunk_size
			var half: float = cs / 2.0
			var touched: bool = false
			for z in range(res + 1):
				for x in range(res + 1):
					var local_x: float = (float(x) / float(res)) * cs - half
					var local_z: float = (float(z) / float(res)) * cs - half
					var wx: float = chunk.position.x + local_x
					var wz: float = chunk.position.z + local_z
					var dx: float = wx - world_pos.x
					var dz: float = wz - world_pos.z
					var dist_sq: float = dx * dx + dz * dz
					var r_sq: float = radius * radius
					if dist_sq > r_sq:
						continue
					var dist: float = sqrt(dist_sq)
					var weight: float = 0.0
					match falloff:
						BrushFalloff.GAUSSIAN:
							var sigma: float = radius * 0.5
							weight = exp(-dist_sq / (2.0 * sigma * sigma))
						BrushFalloff.LINEAR:
							weight = 1.0 - (dist / radius)
						BrushFalloff.HARD:
							weight = 1.0
						_:
							weight = 1.0
					chunk.height_offsets[z * stride + x] += strength * weight
					touched = true
			if touched and not dirty.has(coord):
				dirty.append(coord)
	return dirty

# Smooth brush: nudge height offsets toward a Gaussian-weighted local average.
# Continuous — caller fires every frame while LMB held.
# strength: how strongly to pull toward average per call (lerp weight, caller passes delta-scaled value).
# Returns dirty Array[Vector2i].
func apply_smooth_brush(world_pos: Vector3, radius: float, strength: float) -> Array:
	var dirty: Array = []
	if radius <= 0.0 or absf(strength) < 0.0001:
		return dirty

	var half_cs: float = chunk_size * 0.5
	var min_coord: Vector2i = get_chunk_coords(Vector3(world_pos.x - radius - half_cs, 0.0, world_pos.z - radius - half_cs))
	var max_coord: Vector2i = get_chunk_coords(Vector3(world_pos.x + radius + half_cs, 0.0, world_pos.z + radius + half_cs))

	var sigma: float = radius * 0.5

	# Pass 1: Compute the Gaussian-weighted average offset across all in-range vertices.
	var weighted_sum: float = 0.0
	var weight_total: float = 0.0
	for cz in range(min_coord.y, max_coord.y + 1):
		for cx in range(min_coord.x, max_coord.x + 1):
			var coord: Vector2i = Vector2i(cx, cz)
			if not chunks.has(coord):
				continue
			var chunk = chunks[coord]
			if chunk == null or not "height_offsets" in chunk:
				continue
			if chunk.height_offsets.is_empty():
				chunk._ensure_offsets_sized()
			var res: int = chunk.resolution
			var cs: float = chunk.chunk_size
			var half: float = cs / 2.0
			for z in range(res + 1):
				for x in range(res + 1):
					var local_x: float = (float(x) / float(res)) * cs - half
					var local_z: float = (float(z) / float(res)) * cs - half
					var wx: float = chunk.position.x + local_x
					var wz: float = chunk.position.z + local_z
					var dx: float = wx - world_pos.x
					var dz: float = wz - world_pos.z
					var dist_sq: float = dx * dx + dz * dz
					if dist_sq > radius * radius:
						continue
					var w: float = exp(-dist_sq / (2.0 * sigma * sigma))
					weighted_sum += chunk.height_offsets[z * (res + 1) + x] * w
					weight_total += w

	if weight_total < 0.0001:
		return dirty

	var avg_offset: float = weighted_sum / weight_total

	# Pass 2: Nudge each in-range vertex toward avg_offset, weighted by Gaussian.
	for cz in range(min_coord.y, max_coord.y + 1):
		for cx in range(min_coord.x, max_coord.x + 1):
			var coord: Vector2i = Vector2i(cx, cz)
			if not chunks.has(coord):
				continue
			var chunk = chunks[coord]
			if chunk == null or not "height_offsets" in chunk:
				continue
			if chunk.height_offsets.is_empty():
				chunk._ensure_offsets_sized()
			var res: int = chunk.resolution
			var stride: int = res + 1
			var cs: float = chunk.chunk_size
			var half: float = cs / 2.0
			var touched: bool = false
			for z in range(res + 1):
				for x in range(res + 1):
					var local_x: float = (float(x) / float(res)) * cs - half
					var local_z: float = (float(z) / float(res)) * cs - half
					var wx: float = chunk.position.x + local_x
					var wz: float = chunk.position.z + local_z
					var dx: float = wx - world_pos.x
					var dz: float = wz - world_pos.z
					var dist_sq: float = dx * dx + dz * dz
					if dist_sq > radius * radius:
						continue
					var w: float = exp(-dist_sq / (2.0 * sigma * sigma))
					var idx: int = z * stride + x
					chunk.height_offsets[idx] = lerp(chunk.height_offsets[idx], avg_offset, strength * w)
					touched = true
			if touched and not dirty.has(coord):
				dirty.append(coord)

	return dirty

# Sample the current height offset at a world position (for flatten target capture).
# Returns the bilinear-interpolated height_offset at world_pos, or 0.0 if no chunk.
# Sample the full world Y at a position (base noise + brush offset).
# Used by flatten to capture the target height on first LMB press.
func sample_world_height(world_pos: Vector3) -> float:
	var coord: Vector2i = Vector2i(
		int(round(world_pos.x / chunk_size)),
		int(round(world_pos.z / chunk_size))
	)
	if not chunks.has(coord):
		return 0.0
	var chunk = chunks[coord]
	if chunk == null:
		return 0.0
	return chunk.get_height_at_world_pos(world_pos.x, world_pos.z)

# Flatten brush: drive each vertex to target_world_y by adjusting its height_offset.
# target_world_y: world Y sampled at first LMB press (noise base + offset at cursor).
# For each vertex: required_offset = target_world_y - base_noise(vertex).
# strength: per-frame lerp weight.
# Returns dirty Array[Vector2i].
func apply_flatten_brush(world_pos: Vector3, radius: float, target_world_y: float, strength: float) -> Array:
	var dirty: Array = []
	if radius <= 0.0 or absf(strength) < 0.0001:
		return dirty

	var half_cs: float = chunk_size * 0.5
	var min_coord: Vector2i = get_chunk_coords(Vector3(world_pos.x - radius - half_cs, 0.0, world_pos.z - radius - half_cs))
	var max_coord: Vector2i = get_chunk_coords(Vector3(world_pos.x + radius + half_cs, 0.0, world_pos.z + radius + half_cs))

	var sigma: float = radius * 0.5

	for cz in range(min_coord.y, max_coord.y + 1):
		for cx in range(min_coord.x, max_coord.x + 1):
			var coord: Vector2i = Vector2i(cx, cz)
			if not chunks.has(coord):
				continue
			var chunk = chunks[coord]
			if chunk == null or not "height_offsets" in chunk:
				continue
			if chunk.height_offsets.is_empty():
				chunk._ensure_offsets_sized()
			var res: int = chunk.resolution
			var stride: int = res + 1
			var cs: float = chunk.chunk_size
			var half: float = cs / 2.0
			var touched: bool = false
			for z in range(res + 1):
				for x in range(res + 1):
					var local_x: float = (float(x) / float(res)) * cs - half
					var local_z: float = (float(z) / float(res)) * cs - half
					var wx: float = chunk.position.x + local_x
					var wz: float = chunk.position.z + local_z
					var dx: float = wx - world_pos.x
					var dz: float = wz - world_pos.z
					var dist_sq: float = dx * dx + dz * dz
					if dist_sq > radius * radius:
						continue
					var w: float = exp(-dist_sq / (2.0 * sigma * sigma))
					var idx: int = z * stride + x
					var base_y: float = get_height_at_position(Vector3(wx, 0.0, wz))
					var target_off: float = target_world_y - base_y
					chunk.height_offsets[idx] = lerp(chunk.height_offsets[idx], target_off, strength * w)
					touched = true
			if touched and not dirty.has(coord):
				dirty.append(coord)

	return dirty

func apply_grass_brush(world_pos: Vector3, radius: float, strength: float, erase: bool = false) -> Array:
	var dirty: Array = []
	if radius <= 0.0:
		return dirty
	var half_cs: float = chunk_size * 0.5
	var min_coord := get_chunk_coords(Vector3(world_pos.x - radius - half_cs, 0.0, world_pos.z - radius - half_cs))
	var max_coord := get_chunk_coords(Vector3(world_pos.x + radius + half_cs, 0.0, world_pos.z + radius + half_cs))
	for cz in range(min_coord.y, max_coord.y + 1):
		for cx in range(min_coord.x, max_coord.x + 1):
			var coord := Vector2i(cx, cz)
			if not chunks.has(coord):
				continue
			var chunk = chunks[coord]
			if chunk == null:
				continue
			chunk._ensure_offsets_sized()
			var res: int = chunk.resolution
			var stride: int = res + 1
			var cs: float = chunk.chunk_size
			var half: float = cs / 2.0
			var touched: bool = false
			for z in range(res + 1):
				for x in range(res + 1):
					var wx: float = chunk.position.x + (float(x) / float(res)) * cs - half
					var wz: float = chunk.position.z + (float(z) / float(res)) * cs - half
					var dist_sq: float = (wx - world_pos.x) * (wx - world_pos.x) + (wz - world_pos.z) * (wz - world_pos.z)
					if dist_sq > radius * radius:
						continue
					var w: float = exp(-dist_sq / (2.0 * (radius * 0.5) * (radius * 0.5)))
					var idx: int = z * stride + x
					var delta: float = strength * w * (-1.0 if erase else 1.0)
					chunk.grass_weights[idx] = clamp(chunk.grass_weights[idx] + delta, 0.0, 1.0)
					touched = true
			if touched and not dirty.has(coord):
				dirty.append(coord)
	return dirty
