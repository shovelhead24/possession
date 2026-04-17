extends Node3D
class_name TerrainChunk

@export var chunk_size: float = 50.0
@export var resolution: int = 10
@export var height_scale: float = 20.0

var chunk_coords: Vector2i
var is_loaded: bool = false
var mesh_instance: MeshInstance3D
var collision_body: StaticBody3D
var noise: FastNoiseLite
var terrain_manager: Node  # Reference to TerrainManager

# LOD system
var current_lod: int = 0  # 0 = highest detail, higher = lower detail
var lod_resolutions: Array = [16, 6, 3, 2, 1]  # LOD0=fine LOD1=medium LOD2=coarse LOD3=minimal LOD4=silhouette

# Phase 2: Per-vertex height offsets for height brush editing
var height_offsets: PackedFloat32Array = PackedFloat32Array()
var grass_weights: PackedFloat32Array = PackedFloat32Array()
var has_collision: bool = true  # Only LOD 0-1 have collision
var sector_scale: int = 1  # Megatile size (1=100m, 2=200m, 4=400m, 8=800m per axis)

# Track if we have borrowed trees/grass from the pool
var has_borrowed_trees: bool = false
var has_borrowed_grass: bool = false
var grass_multimesh: MultiMeshInstance3D = null
var has_structure: bool = false

# Deferred prop generation to prevent hitching
var props_pending: bool = false  # True if we need to generate props
var props_generated: bool = false  # True if props have been generated
var physics_ready: bool = false  # True after physics has registered collision


func _ready():
	# Start with processing disabled — enable only when needed
	set_process(false)
	set_physics_process(false)

func _physics_process(_delta):
	# Mark physics as ready after first physics frame (collision is now registered)
	if not physics_ready and collision_body and collision_body.is_inside_tree():
		physics_ready = true
		set_physics_process(false)  # Done — never need this again

var last_tree_lod: int = -1  # Track last tree LOD to avoid redundant updates

func _process(_delta):
	# Deferred prop generation - spreads work across frames
	# Only 1 chunk generates props per frame to prevent hitching
	# IMPORTANT: Wait for physics_ready so raycast can hit terrain collision
	if props_pending and not props_generated and physics_ready:
		# Check if another chunk already generated props this frame
		if terrain_manager and "props_generated_this_frame" in terrain_manager:
			if terrain_manager.props_generated_this_frame:
				return  # Wait until next frame
			terrain_manager.props_generated_this_frame = true
		props_pending = false
		props_generated = true
		generate_props()
		# Set initial tree LOD based on chunk LOD
		update_tree_lods()
		set_process(false)  # Props done — no more per-frame work needed

	# Tree LOD updates are now handled directly in set_lod(), not here

# Update tree LODs based on current chunk LOD level
func update_tree_lods():
	if last_tree_lod == current_lod:
		return
	last_tree_lod = current_lod

	var props_node = get_node_or_null("Props")
	if not props_node:
		return

	var prop_pool = get_node_or_null("/root/World/TerrainManager/PropPool")
	if not prop_pool or not prop_pool.has_method("set_tree_lod"):
		return

	# Map chunk LOD to tree LOD
	# Chunk LOD 0-1 = Tree LOD 0 (high detail)
	# Chunk LOD 2 = Tree LOD 1 (medium)
	# Chunk LOD 3 = Tree LOD 2 (low)
	# Chunk LOD 4+ = Tree LOD 3 (billboard)
	var tree_lod: int
	match current_lod:
		0, 1: tree_lod = 0  # High detail mesh
		2: tree_lod = 1     # Medium detail mesh
		3: tree_lod = 2     # Low detail mesh
		_: tree_lod = 3     # Billboard

	# Update all trees in this chunk
	for prop in props_node.get_children():
		if prop.has_meta("tree_type"):
			prop_pool.set_tree_lod(prop, tree_lod)

func _exit_tree():
	# Return borrowed trees to pool when chunk is freed
	return_trees_to_pool()

func initialize(coords: Vector2i, world_noise: FastNoiseLite, lod: int = 0):
	chunk_coords = coords
	noise = world_noise
	current_lod = clampi(lod, 0, lod_resolutions.size() - 1)
	resolution = lod_resolutions[current_lod]
	_ensure_offsets_sized()
	position = Vector3(
		coords.x * chunk_size + (sector_scale - 1) * chunk_size * 0.5,
		0,
		coords.y * chunk_size + (sector_scale - 1) * chunk_size * 0.5
	)
	generate_terrain()

func set_lod(new_lod: int):
	new_lod = clampi(new_lod, 0, lod_resolutions.size() - 1)
	if new_lod == current_lod:
		return

	var old_res := resolution
	current_lod = new_lod
	resolution = lod_resolutions[current_lod]

	# Remove old mesh and collision
	if mesh_instance:
		mesh_instance.queue_free()
		mesh_instance = null
	if collision_body:
		collision_body.queue_free()
		collision_body = null

	# Return trees to pool before removing props node
	return_trees_to_pool()
	props_generated = false
	props_pending = false
	last_tree_lod = -1  # Reset tree LOD tracker

	# Remove props, water, and structures
	for child in get_children():
		if child.name == "Props" or child.name == "WaterPlane":
			child.queue_free()
	has_structure = false

	# Resample height offsets to new resolution before regenerating
	_resample_offsets(old_res)

	# Regenerate at new LOD
	generate_terrain()

	# Update tree LODs if props exist (e.g., LOD0→LOD1 transition keeps props)
	if props_generated and last_tree_lod != current_lod:
		update_tree_lods()

# Use terrain manager's height function if available, otherwise use noise
func get_height_at_world_pos(world_x: float, world_z: float) -> float:
	var base: float = 0.0
	if terrain_manager and terrain_manager.has_method("get_height_at_position"):
		base = terrain_manager.get_height_at_position(Vector3(world_x, 0, world_z))
	else:
		# Fallback to original noise-based height
		if not noise:
			return 0.0
		base = noise.get_noise_2d(world_x, world_z) * height_scale
		base += noise.get_noise_2d(world_x * 2, world_z * 2) * height_scale * 0.5
		base += noise.get_noise_2d(world_x * 4, world_z * 4) * height_scale * 0.25
	# Apply per-vertex height offset (Phase 2 height brush)
	var local_x: float = world_x - position.x
	var local_z: float = world_z - position.z
	base += _sample_offset(local_x, local_z)
	return base

# Ensure height_offsets and grass_weights are sized to match current resolution grid.
func _ensure_offsets_sized() -> void:
	var expected: int = (resolution + 1) * (resolution + 1)
	if height_offsets.size() != expected:
		height_offsets.resize(expected)
		height_offsets.fill(0.0)
	if grass_weights.size() != expected:
		grass_weights.resize(expected)
		grass_weights.fill(0.0)

# Bilinear sample of the height_offsets grid at local chunk coordinates.
# local_x, local_z are in [-chunk_size/2, +chunk_size/2].
func _sample_offset(local_x: float, local_z: float) -> float:
	if height_offsets.is_empty():
		return 0.0
	var half: float = chunk_size / 2.0
	# Convert local [-half, +half] to grid [0, resolution]
	var gx: float = (local_x + half) / chunk_size * float(resolution)
	var gz: float = (local_z + half) / chunk_size * float(resolution)
	if gx < 0.0 or gz < 0.0 or gx > float(resolution) or gz > float(resolution):
		return 0.0
	var x0: int = int(floor(gx))
	var z0: int = int(floor(gz))
	var x1: int = min(x0 + 1, resolution)
	var z1: int = min(z0 + 1, resolution)
	var fx: float = gx - float(x0)
	var fz: float = gz - float(z0)
	var stride: int = resolution + 1
	var h00: float = height_offsets[z0 * stride + x0]
	var h10: float = height_offsets[z0 * stride + x1]
	var h01: float = height_offsets[z1 * stride + x0]
	var h11: float = height_offsets[z1 * stride + x1]
	var h0: float = lerp(h00, h10, fx)
	var h1: float = lerp(h01, h11, fx)
	return lerp(h0, h1, fz)

# Resample height_offsets from old_resolution grid to current resolution grid.
# Called by set_lod() when resolution changes, so brush edits survive LOD transitions.
func _resample_offsets(old_resolution: int) -> void:
	if height_offsets.is_empty() or old_resolution == resolution:
		_ensure_offsets_sized()
		return
	var old_stride: int = old_resolution + 1
	var old_data: PackedFloat32Array = height_offsets.duplicate()
	var new_size: int = (resolution + 1) * (resolution + 1)
	var new_data: PackedFloat32Array = PackedFloat32Array()
	new_data.resize(new_size)
	for z in range(resolution + 1):
		for x in range(resolution + 1):
			var u: float = float(x) / float(resolution) * float(old_resolution)
			var v: float = float(z) / float(resolution) * float(old_resolution)
			var x0: int = int(floor(u)); var z0: int = int(floor(v))
			var x1: int = min(x0 + 1, old_resolution); var z1: int = min(z0 + 1, old_resolution)
			var fx: float = u - float(x0); var fz: float = v - float(z0)
			var h00: float = old_data[z0 * old_stride + x0]
			var h10: float = old_data[z0 * old_stride + x1]
			var h01: float = old_data[z1 * old_stride + x0]
			var h11: float = old_data[z1 * old_stride + x1]
			new_data[z * (resolution + 1) + x] = lerp(lerp(h00, h10, fx), lerp(h01, h11, fx), fz)
	height_offsets = new_data

# Public rebuild used by the height brush. Tears down the previous mesh/collision
# (mirroring set_lod() teardown) and re-runs generate_terrain() which re-applies
# all shader params (D-10). Props are deliberately NOT touched — brush rebuilds
# happen too frequently; prop repositioning is a Phase 3+ concern.
func rebuild_mesh() -> void:
	# Remove stale mesh instance created by previous generate_terrain()
	if mesh_instance and is_instance_valid(mesh_instance):
		mesh_instance.queue_free()
		mesh_instance = null
	# Remove stale collision body (generate_terrain recreates it for LOD0-1)
	if collision_body and is_instance_valid(collision_body):
		collision_body.queue_free()
		collision_body = null
	# Rebuild (generate_terrain recreates mesh, collision for LOD0-1, shader params)
	generate_terrain()

func generate_terrain():
	var start_time = Time.get_ticks_msec()
	_ensure_offsets_sized()

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
	var colors = PackedColorArray()

	# Megatile: mesh covers sector_scale × chunk_size per axis, same vertex density
	var mesh_size: float = chunk_size * float(sector_scale)
	var mesh_res: int = resolution * sector_scale

	# Adaptive resolution: probe a 5×5 grid, reduce mesh_res on flat chunks.
	# Only LOD0 single-scale chunks — that's where collision cost matters.
	if sector_scale == 1 and current_lod == 0:
		var probe_min: float = 1e9
		var probe_max: float = -1e9
		for pz in range(5):
			for px in range(5):
				var lx: float = (float(px) / 4.0) * chunk_size - chunk_size * 0.5
				var lz: float = (float(pz) / 4.0) * chunk_size - chunk_size * 0.5
				var h: float = get_height_at_world_pos(position.x + lx, position.z + lz)
				if h < probe_min: probe_min = h
				if h > probe_max: probe_max = h
		var height_range: float = probe_max - probe_min
		if height_range < ADAPTIVE_FLAT_THRESH:
			mesh_res = ADAPTIVE_FLAT_RES
		elif height_range < ADAPTIVE_ROLL_THRESH:
			mesh_res = ADAPTIVE_ROLL_RES
		else:
			mesh_res = ADAPTIVE_HILL_RES

	for z in range(mesh_res + 1):
		for x in range(mesh_res + 1):
			var local_x = (float(x) / float(mesh_res)) * mesh_size - mesh_size * 0.5
			var local_z = (float(z) / float(mesh_res)) * mesh_size - mesh_size * 0.5
			var world_x = position.x + local_x
			var world_z = position.z + local_z
			var height: float
			if sector_scale > 1:
				height = terrain_manager.get_height_at_position(Vector3(world_x, 0.0, world_z)) if terrain_manager else 0.0
			else:
				height = get_height_at_world_pos(world_x, world_z)
			vertices.push_back(Vector3(local_x, height, local_z))
			uvs.push_back(Vector2(float(x) / float(mesh_res), float(z) / float(mesh_res)))
			colors.push_back(Color.WHITE)

	var indices = PackedInt32Array()
	for z in range(mesh_res):
		for x in range(mesh_res):
			var idx = z * (mesh_res + 1) + x
			indices.push_back(idx)
			indices.push_back(idx + 1)
			indices.push_back(idx + mesh_res + 1)
			indices.push_back(idx + 1)
			indices.push_back(idx + mesh_res + 2)
			indices.push_back(idx + mesh_res + 1)

	# Calculate normals
	for i in range(vertices.size()):
		normals.push_back(Vector3.ZERO)

	for i in range(0, indices.size(), 3):
		var i0 = indices[i]
		var i1 = indices[i + 1]
		var i2 = indices[i + 2]

		var v0 = vertices[i0]
		var v1 = vertices[i1]
		var v2 = vertices[i2]

		var face_normal = (v1 - v0).cross(v2 - v0).normalized()

		normals[i0] += face_normal
		normals[i1] += face_normal
		normals[i2] += face_normal

	for i in range(normals.size()):
		normals[i] = normals[i].normalized()

	# Get biome traits for coloring - use blended traits at chunk center
	var water_level_raw = 0.25
	var base_elevation = 0.0
	var biome_height_mult = 1.0
	var biome_colors = {}
	var use_global_water = true

	# Get sector center in world space for biome sampling (position is already the center)
	var chunk_center = Vector3(position.x, 0.0, position.z)

	if terrain_manager:
		# Check if using global water level
		if "use_global_water" in terrain_manager:
			use_global_water = terrain_manager.use_global_water

		# Try to get blended traits if biome blending is enabled
		if terrain_manager.has_method("get_blended_traits_at") and terrain_manager.enable_biome_blending:
			var blended = terrain_manager.get_blended_traits_at(chunk_center)
			var traits = blended.traits
			biome_height_mult = traits.height_multiplier
			base_elevation = traits.base_elevation
			# Use global water level if enabled, otherwise use per-biome
			if use_global_water:
				water_level_raw = terrain_manager.water_level
			else:
				water_level_raw = traits.water_level if traits.water_level >= 0 else 0.1
			biome_colors = blended.colors
		else:
			# Fall back to current biome traits
			if "water_level" in terrain_manager:
				water_level_raw = terrain_manager.water_level
			if "current_biome_traits" in terrain_manager and terrain_manager.current_biome_traits:
				var traits = terrain_manager.current_biome_traits
				biome_height_mult = traits.height_multiplier
				base_elevation = traits.base_elevation
			if "biome_colors" in terrain_manager and terrain_manager.biome_colors.size() > 0:
				biome_colors = terrain_manager.biome_colors

	# Default fallback colors if not set
	if biome_colors.is_empty():
		biome_colors["deep_water"] = Color(0.1, 0.2, 0.4)
		biome_colors["shallow_water"] = Color(0.2, 0.4, 0.5)
		biome_colors["beach"] = Color(0.85, 0.80, 0.65)
		biome_colors["grass"] = Color(0.25, 0.50, 0.2)
		biome_colors["dark_grass"] = Color(0.15, 0.38, 0.12)
		biome_colors["forest"] = Color(0.12, 0.30, 0.10)
		biome_colors["rock"] = Color(0.50, 0.48, 0.45)
		biome_colors["snow"] = Color(0.95, 0.95, 0.98)

	# Water level calculation:
	# Global water = absolute fraction of terrain_height
	# Per-biome water = offset above base_elevation
	# We need to convert to normalized height space (accounting for biome height multiplier)
	var water_level = water_level_raw if use_global_water else (base_elevation + water_level_raw)
	# Convert water_level to match normalized_height scale (which uses biome-adjusted heights)
	if biome_height_mult > 0:
		water_level = water_level / biome_height_mult

	# Recalculate colors using slope and water level
	for i in range(vertices.size()):
		var vert = vertices[i]
		var normal = normals[i]

		# Slope factor: 1.0 = flat, 0.0 = vertical cliff
		var slope = normal.dot(Vector3.UP)
		slope = clamp(slope, 0.0, 1.0)

		# Height factor (0-1 normalized) - scale by biome multiplier so colors span full range
		var effective_height_scale = height_scale * biome_height_mult
		var normalized_height: float = vert.y / effective_height_scale if effective_height_scale > 0 else 0.0
		normalized_height = clamp(normalized_height, 0.0, 1.0)

		var deep_water = biome_colors.get("deep_water", Color(0.1, 0.2, 0.4))
		var shallow_water = biome_colors.get("shallow_water", Color(0.2, 0.4, 0.5))
		var beach_color = biome_colors.get("beach", Color(0.85, 0.80, 0.65))
		var grass_color = biome_colors.get("grass", Color(0.25, 0.50, 0.2))
		var dark_grass = biome_colors.get("dark_grass", Color(0.15, 0.38, 0.12))
		var forest_color = biome_colors.get("forest", Color(0.12, 0.30, 0.10))
		var rock_color = biome_colors.get("rock", Color(0.50, 0.48, 0.45))
		var snow_color = biome_colors.get("snow", Color(0.95, 0.95, 0.98))

		var color: Color

		# Water zones
		var beach_start = water_level + 0.02
		var beach_end = water_level + 0.08

		if normalized_height < water_level:
			# Underwater - blend from deep to shallow
			var depth = (water_level - normalized_height) / water_level
			color = shallow_water.lerp(deep_water, clamp(depth * 2.0, 0.0, 1.0))
		elif normalized_height < beach_start:
			# Shoreline - wet sand
			color = beach_color.darkened(0.1)
		elif normalized_height < beach_end:
			# Beach transition to grass
			var t = (normalized_height - beach_start) / (beach_end - beach_start)
			color = beach_color.lerp(grass_color, t)
		elif slope < 0.45:
			# Very steep slopes - rocky (slope < 0.45 = ~63+ degree angle)
			var rock_blend = (0.45 - slope) / 0.25
			rock_blend = clamp(rock_blend, 0.0, 1.0)

			var base_color: Color
			if normalized_height < 0.35:
				base_color = grass_color.lerp(dark_grass, (normalized_height - beach_end) / (0.35 - beach_end))
			elif normalized_height < 0.55:
				base_color = forest_color
			elif normalized_height < 0.75:
				base_color = rock_color
			else:
				base_color = snow_color

			color = base_color.lerp(rock_color, rock_blend)
		else:
			# Flat areas - height-based biomes (snow at ~75% = 600m with 800m terrain_height)
			if normalized_height < 0.25:
				var t = (normalized_height - beach_end) / (0.25 - beach_end)
				color = grass_color.lerp(dark_grass, clamp(t, 0.0, 1.0))
			elif normalized_height < 0.45:
				var t = (normalized_height - 0.25) / 0.2
				color = dark_grass.lerp(forest_color, t)
			elif normalized_height < 0.65:
				var t = (normalized_height - 0.45) / 0.2
				color = forest_color.lerp(rock_color, t)
			elif normalized_height < 0.75:
				var t = (normalized_height - 0.65) / 0.1
				color = rock_color
			else:
				# Snow above 75% (600m with 800m max)
				var t = (normalized_height - 0.75) / 0.25
				color = rock_color.lerp(snow_color, clamp(t, 0.0, 1.0))

		color.a = grass_weights[i] if grass_weights.size() > i else 0.0
		colors[i] = color
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_COLOR] = colors

	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = array_mesh

	# Add textured material with shader
	var material = create_terrain_material()
	mesh_instance.material_override = material

	# Distance culling — Godot skips rendering entirely for chunks beyond this range.
	# Matches fog_depth_end (9000m) so we don't render invisible geometry.
	mesh_instance.visibility_range_end = 9000.0
	mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

	# Shadow casting: only LOD0 has smooth enough geometry for correct shadows.
	# LOD1+ coarse normals cause banding seams at chunk edges at low sun angles.
	if current_lod >= 1:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Only create collision for LOD 0-1 (close chunks)
	has_collision = current_lod <= 1
	if has_collision:
		collision_body = StaticBody3D.new()
		add_child(collision_body)

		var collision_shape = CollisionShape3D.new()
		collision_body.add_child(collision_shape)

		var trimesh = mesh_instance.mesh.create_trimesh_shape()
		collision_shape.shape = trimesh

	var total_time = Time.get_ticks_msec() - start_time
	print("CHUNK ", chunk_coords, " LOD", current_lod, " scale=", sector_scale, " res=", resolution, " verts=", vertices.size(), " total=", total_time, "ms")

	# Report timing to terrain manager for adaptive quality
	if terrain_manager and terrain_manager.has_method("add_chunk_time"):
		terrain_manager.add_chunk_time(total_time)


	# Water is now handled by TerrainManager as a single global plane

	# Structures spawn at every LOD so they're visible at max range
	maybe_spawn_structure()

	# Only generate props for LOD 0-1 (close chunks)
	# Defer prop generation to next frame to prevent hitching
	if current_lod <= 1:
		props_pending = true
		props_generated = false
		# Enable processing for prop generation and physics readiness
		set_process(true)
		if has_collision:
			set_physics_process(true)

# Per-LOD debug colours: LOD0=white, LOD1=blue, LOD2=green, LOD3=red
static var _structure_mats: Array = []

static func _ensure_structure_mats() -> void:
	if not _structure_mats.is_empty():
		return
	var colors = [
		Color(0.95, 0.93, 0.90),  # LOD0: white/cream
		Color(0.25, 0.45, 0.95),  # LOD1: blue
		Color(0.20, 0.82, 0.30),  # LOD2: green
		Color(0.92, 0.22, 0.22),  # LOD3: red
	]
	for c in colors:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = c
		mat.roughness = 0.85
		_structure_mats.append(mat)

func maybe_spawn_structure() -> void:
	# Only LOD0-2 — LOD3 chunks are tiny silhouettes at 1400m+, not worth nodes
	if current_lod >= 2:
		return
	if has_structure:
		return

	# ~2% of chunks get a structure — deterministic, no StaticBody3D (pure visual)
	var rng = RandomNumberGenerator.new()
	rng.seed = (chunk_coords.x * 73856093) ^ (chunk_coords.y * 19349663) ^ 0xBEEFCAFE
	if rng.randf() > 0.02:
		return

	# Don't place at world origin (hand-placed gateway lives there)
	if chunk_coords.x == 0 and chunk_coords.y == 0:
		return

	var half = chunk_size / 2.0
	var local_x = rng.randf_range(-half * 0.7, half * 0.7)
	var local_z = rng.randf_range(-half * 0.7, half * 0.7)
	var world_x = position.x + local_x
	var world_z = position.z + local_z
	var ground_y = get_height_at_world_pos(world_x, world_z)

	var abs_water = 0.0
	if terrain_manager and "absolute_water_height" in terrain_manager:
		abs_water = terrain_manager.absolute_water_height
	if ground_y < abs_water + 8.0:
		return

	_ensure_structure_mats()
	var mat = _structure_mats[clamp(current_lod, 0, _structure_mats.size() - 1)]

	# Uniform size so scale is consistent across LOD rings
	const MONO_W = 30.0
	const MONO_H = 120.0
	const MONO_D = 30.0
	const GAP    = 60.0

	var rot_y = rng.randf() * TAU
	var half_span = (GAP + MONO_W) * 0.5
	var center_y  = ground_y - 30.0 + MONO_H * 0.5  # Sink 30m into ground

	for side in [-1.0, 1.0]:
		var offset = Vector3(side * half_span, 0.0, 0.0).rotated(Vector3.UP, rot_y)
		# Plain Node3D — no physics body, no collision (pure visual, zero physics overhead)
		var anchor = Node3D.new()
		anchor.position = Vector3(local_x + offset.x, center_y, local_z + offset.z)

		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(MONO_W, MONO_H, MONO_D)
		mi.mesh = bm
		mi.material_override = mat
		anchor.add_child(mi)
		add_child(anchor)
	has_structure = true

func generate_props():
	var props_start = Time.get_ticks_msec()

	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_coords)

	var props_node = Node3D.new()
	props_node.name = "Props"
	add_child(props_node)

	# Get biome traits for tree placement
	var tree_density = 0.5
	var biome_height_mult = 1.0

	# Get chunk center for biome sampling
	var chunk_center = Vector3(
		position.x + chunk_size / 2.0,
		0,
		position.z + chunk_size / 2.0
	)

	# Only spawn trees within a limited distance from player (performance optimization)
	var tree_spawn_distance: float = 8.0  # Spawn trees within 8 chunks (200m) to reduce pop-in
	if terrain_manager and "player" in terrain_manager and terrain_manager.player:
		var player_pos = terrain_manager.player.global_position
		var dist_to_player = Vector2(chunk_center.x - player_pos.x, chunk_center.z - player_pos.z).length()
		if dist_to_player > tree_spawn_distance * chunk_size:
			return  # Skip tree generation for distant chunks

	if terrain_manager:
		if terrain_manager.has_method("get_blended_traits_at") and terrain_manager.enable_biome_blending:
			var blended = terrain_manager.get_blended_traits_at(chunk_center)
			var traits = blended.traits
			tree_density = traits.tree_density
			biome_height_mult = traits.height_multiplier
		else:
			if "current_biome_traits" in terrain_manager and terrain_manager.current_biome_traits:
				var traits = terrain_manager.current_biome_traits
				tree_density = traits.tree_density
				biome_height_mult = traits.height_multiplier

	# Get absolute water height from terrain manager (the actual Y level of water)
	var absolute_water_height = 0.0
	if terrain_manager and "absolute_water_height" in terrain_manager:
		absolute_water_height = terrain_manager.absolute_water_height

	# Forest noise for clustering - creates woods, thickets, tree lines
	var forest_noise = FastNoiseLite.new()
	forest_noise.seed = 54321  # Fixed seed for consistent forests across chunks
	forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	forest_noise.frequency = 0.008  # Large clusters ~125m

	# Secondary noise for thickets/clearings within forests
	var thicket_noise = FastNoiseLite.new()
	thicket_noise.seed = 98765
	thicket_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	thicket_noise.frequency = 0.025  # Medium scale ~40m thickets

	# Calculate max trees based on density - higher density = more potential trees
	var base_tree_count = int(tree_density * 200)  # Max ~200 trees per chunk

	# Apply quality multiplier from adaptive quality system
	var max_tree_count = base_tree_count
	if terrain_manager and terrain_manager.has_method("get_quality_tree_count"):
		max_tree_count = terrain_manager.get_quality_tree_count(base_tree_count)

	# Try to use prop pool if available
	var prop_pool = null
	if terrain_manager and "prop_pool" in terrain_manager:
		prop_pool = terrain_manager.prop_pool

	if prop_pool and prop_pool.has_method("borrow_trees"):
		# Use object pool for better performance
		var borrowed_trees = prop_pool.borrow_trees(chunk_coords, max_tree_count, props_node)
		has_borrowed_trees = true

		# Position borrowed trees using clustering
		# NOTE: Terrain mesh uses local coords [-chunk_size/2, +chunk_size/2]
		# World coords = position + local (NO offset!)
		var tree_index = 0
		var half_size = chunk_size / 2.0
		for tree in borrowed_trees:
			# Generate deterministic position based on chunk and tree index
			rng.seed = hash(chunk_coords) + tree_index
			# Local coords match terrain mesh: [-chunk_size/2, +chunk_size/2]
			var local_x = rng.randf_range(-half_size + 2, half_size - 2)
			var local_z = rng.randf_range(-half_size + 2, half_size - 2)

			# World coords match terrain mesh calculation (no offset!)
			var world_x = position.x + local_x
			var world_z = position.z + local_z
			# Use mesh surface height (raycast/interpolated) to match visual terrain
			var y = get_mesh_surface_height(world_x, world_z)

			# Sample forest noise at this position for clustering
			var forest_value = (forest_noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5  # 0-1
			var thicket_value = (thicket_noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5  # 0-1

			# Combined forest density - creates clusters with internal variation
			var local_density = forest_value * 0.7 + thicket_value * 0.3

			# Tree placement threshold - higher density biomes need lower threshold
			var placement_threshold = 1.0 - tree_density * 0.8  # 0.2 to 1.0

			# Check if this position should have a tree
			var should_place = local_density > placement_threshold

			# Height checks: must be above water with margin
			var min_height_above_water = absolute_water_height + 3.0  # 3m above water
			var max_tree_height = height_scale * biome_height_mult * 0.7  # 70% of max terrain height

			# Calculate slope at position for steep slope rejection
			# Use mesh surface heights for consistency with prop placement
			var slope_ok = true
			var delta = 1.0
			var h_center = y
			var h_dx = get_mesh_surface_height(world_x + delta, world_z)
			var h_dz = get_mesh_surface_height(world_x, world_z + delta)
			var slope_x = abs(h_dx - h_center) / delta
			var slope_z = abs(h_dz - h_center) / delta
			var max_slope = max(slope_x, slope_z)
			if max_slope > 1.5:  # Reject slopes steeper than ~56 degrees
				slope_ok = false

			# Final placement decision
			if should_place and y > min_height_above_water and y < max_tree_height and slope_ok:
				# Use per-model pivot offset from prop pool metadata
				var pivot_offset = tree.get_meta("pivot_offset", 0.0) if tree.has_meta("pivot_offset") else 0.0

				tree.position = Vector3(local_x, y + pivot_offset, local_z)  # Use local coords matching terrain mesh
				tree.rotation.y = rng.randf() * TAU
				# Size variation based on forest density (denser = taller trees competing for light)
				# Multiply existing scale to preserve base scale from prop pool
				var size_mult = rng.randf_range(0.7, 1.0) + local_density * 0.3
				tree.scale *= size_mult
				tree.visible = true

				# Debug: log first few tree placements per chunk
				if tree_index < 3:
					var tree_world_y = position.y + tree.position.y
					var expected_terrain = get_height_at_world_pos(world_x, world_z)
					# Also check global position after placement
					var global_pos = tree.global_position if tree.is_inside_tree() else Vector3.ZERO
					pass  # Debug logging disabled
			else:
				tree.visible = false

			tree_index += 1

		# Spawn grass as MultiMesh (one draw call per chunk, 400+ density)
		if prop_pool.has_method("get_grass_mesh"):
			_spawn_grass_multimesh(prop_pool, rng, forest_noise, half_size, absolute_water_height, tree_density, biome_height_mult, props_node)
	else:
		# Fallback: create trees directly (less efficient)
		var half_size_fb = chunk_size / 2.0
		for i in range(max_tree_count):
			rng.seed = hash(chunk_coords) + i
			# Local coords match terrain mesh: [-chunk_size/2, +chunk_size/2]
			var local_x = rng.randf_range(-half_size_fb + 2, half_size_fb - 2)
			var local_z = rng.randf_range(-half_size_fb + 2, half_size_fb - 2)

			# World coords match terrain mesh calculation (no offset!)
			var world_x = position.x + local_x
			var world_z = position.z + local_z
			# Use mesh surface height (raycast/interpolated) to match visual terrain
			var y = get_mesh_surface_height(world_x, world_z)

			# Sample forest noise
			var forest_value = (forest_noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5
			var thicket_value = (thicket_noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5
			var local_density = forest_value * 0.7 + thicket_value * 0.3
			var placement_threshold = 1.0 - tree_density * 0.8

			var should_place = local_density > placement_threshold
			var min_height_above_water = absolute_water_height + 3.0
			var max_tree_height = height_scale * biome_height_mult * 0.7

			if should_place and y > min_height_above_water and y < max_tree_height:
				var tree = create_simple_tree()
				tree.position = Vector3(local_x, y, local_z)  # Use local coords matching terrain mesh
				tree.rotate_y(rng.randf() * TAU)
				var size_mult = rng.randf_range(0.7, 1.0) + local_density * 0.3
				tree.scale *= size_mult
				props_node.add_child(tree)

	var _props_time = Time.get_ticks_msec() - props_start

func _spawn_grass_multimesh(prop_pool, rng: RandomNumberGenerator, forest_noise: FastNoiseLite, half_size: float, absolute_water_height: float, tree_density: float, biome_height_mult: float, props_node: Node3D):
	var base_count = int(tree_density * 2000)
	if terrain_manager and terrain_manager.has_method("get_quality_tree_count"):
		base_count = terrain_manager.get_quality_tree_count(base_count)
	if base_count == 0:
		return

	var grass_mesh: Mesh = prop_pool.get_grass_mesh(1)  # medium variant
	if grass_mesh == null:
		return

	var transforms: Array[Transform3D] = []
	var max_water = absolute_water_height + 1.0
	var max_h = height_scale * biome_height_mult * 0.6

	for i in range(base_count):
		rng.seed = hash(chunk_coords) + 10000 + i
		var lx := rng.randf_range(-half_size + 1.0, half_size - 1.0)
		var lz := rng.randf_range(-half_size + 1.0, half_size - 1.0)
		var y := get_mesh_surface_height(position.x + lx, position.z + lz)
		if y <= max_water or y >= max_h:
			continue
		var gd := (forest_noise.get_noise_2d((position.x + lx) * 0.5, (position.z + lz) * 0.5) + 1.0) * 0.5
		if gd <= 0.15:
			continue
		var s := rng.randf_range(0.7, 1.3)
		transforms.append(Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
			Vector3(lx, y - 0.15, lz)
		))

	if transforms.is_empty():
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = grass_mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])

	grass_multimesh = MultiMeshInstance3D.new()
	grass_multimesh.multimesh = mm
	grass_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props_node.add_child(grass_multimesh)
	has_borrowed_grass = true

func return_trees_to_pool():
	# Return borrowed trees and grass to the prop pool
	if not terrain_manager or not "prop_pool" in terrain_manager:
		return

	var prop_pool = terrain_manager.prop_pool

	# Return trees
	if has_borrowed_trees:
		if prop_pool and prop_pool.has_method("return_trees"):
			prop_pool.return_trees(chunk_coords)
			has_borrowed_trees = false

	# Free grass MultiMesh (owned by chunk, not pooled)
	if has_borrowed_grass:
		if is_instance_valid(grass_multimesh):
			grass_multimesh.queue_free()
		grass_multimesh = null
		has_borrowed_grass = false

func create_simple_tree() -> Node3D:
	var tree = Node3D.new()
	var rng = RandomNumberGenerator.new()
	rng.seed = randi()

	# Randomize tree type
	var tree_type = rng.randi_range(0, 2)

	# Trunk - slightly varied
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	var trunk_height = rng.randf_range(3.0, 6.0)
	trunk_mesh.height = trunk_height
	trunk_mesh.top_radius = rng.randf_range(0.12, 0.2)
	trunk_mesh.bottom_radius = rng.randf_range(0.25, 0.4)
	trunk_mesh.radial_segments = 6
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_height / 2.0

	var trunk_material = StandardMaterial3D.new()
	trunk_material.albedo_color = Color(
		rng.randf_range(0.25, 0.4),
		rng.randf_range(0.2, 0.3),
		rng.randf_range(0.1, 0.2)
	)
	trunk_material.roughness = 1.0
	trunk.material_override = trunk_material
	tree.add_child(trunk)

	var leaves_material = StandardMaterial3D.new()
	leaves_material.albedo_color = Color(
		rng.randf_range(0.1, 0.25),
		rng.randf_range(0.35, 0.55),
		rng.randf_range(0.1, 0.2)
	)
	leaves_material.roughness = 0.9

	if tree_type == 0:
		# Conifer - stacked cones
		var num_layers = rng.randi_range(3, 5)
		for i in range(num_layers):
			var cone = MeshInstance3D.new()
			var cone_mesh = CylinderMesh.new()
			var layer_height = 1.5 - (i * 0.15)
			var layer_radius = 1.8 - (i * 0.3)
			cone_mesh.height = layer_height
			cone_mesh.top_radius = 0.1
			cone_mesh.bottom_radius = layer_radius
			cone_mesh.radial_segments = 6
			cone.mesh = cone_mesh
			cone.position.y = trunk_height + (i * 1.0) + 0.5
			cone.material_override = leaves_material
			tree.add_child(cone)
	elif tree_type == 1:
		# Round deciduous
		var leaves = MeshInstance3D.new()
		var leaves_mesh = SphereMesh.new()
		leaves_mesh.radial_segments = 8
		leaves_mesh.rings = 6
		leaves_mesh.height = rng.randf_range(2.5, 4.0)
		leaves_mesh.radius = rng.randf_range(1.8, 2.8)
		leaves.mesh = leaves_mesh
		leaves.position.y = trunk_height + 1.5
		leaves.material_override = leaves_material
		tree.add_child(leaves)
	else:
		# Tall pine - single elongated cone
		var cone = MeshInstance3D.new()
		var cone_mesh = CylinderMesh.new()
		cone_mesh.height = rng.randf_range(4.0, 6.0)
		cone_mesh.top_radius = 0.05
		cone_mesh.bottom_radius = rng.randf_range(1.2, 2.0)
		cone_mesh.radial_segments = 6
		cone.mesh = cone_mesh
		cone.position.y = trunk_height + cone_mesh.height / 2.0
		cone.material_override = leaves_material
		tree.add_child(cone)

	return tree

# Textures loaded once and shared across all chunks
static var _tex_grass:  ImageTexture = null
static var _tex_snow:   ImageTexture = null
static var _tex_stone:  ImageTexture = null
static var _tex_sand:   ImageTexture = null
static var _tex_shader: Shader       = null
static var _textures_loaded: bool    = false
static var _tex_grass_normal: ImageTexture = null
static var _tex_stone_normal: ImageTexture = null
static var _tex_snow_normal: ImageTexture  = null

static func _load_tex(path: String) -> ImageTexture:
	var img = Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null

static func _ensure_textures_loaded() -> void:
	if _textures_loaded:
		return
	_textures_loaded = true
	_tex_grass  = _load_tex("res://grass.jpeg")
	_tex_snow   = _load_tex("res://snow.jpeg")
	_tex_stone  = _load_tex("res://stone.jpg")
	_tex_sand   = _load_tex("res://sand.jpg")
	_tex_grass_normal = _load_tex("res://grass_normal.jpg")
	_tex_stone_normal = _load_tex("res://stone_normal.jpg")
	_tex_snow_normal  = _load_tex("res://snow_normal.jpg")  # optional — added later
	if ResourceLoader.exists("res://terrain_shader.gdshader"):
		_tex_shader = load("res://terrain_shader.gdshader")

# Shared material for distant LODs — vertex colors only, zero texture samples
static var _distant_material: StandardMaterial3D = null

static func _get_distant_material() -> StandardMaterial3D:
	if _distant_material:
		return _distant_material
	_distant_material = StandardMaterial3D.new()
	_distant_material.vertex_color_use_as_albedo = true
	_distant_material.roughness = 0.9
	_distant_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return _distant_material

# Adaptive resolution: probe 5×5 grid before mesh gen, reduce res on flat chunks.
# Conservative preset: range<20m→res12, range<60m→res14, else→res16
const ADAPTIVE_FLAT_THRESH: float = 20.0
const ADAPTIVE_ROLL_THRESH: float = 60.0
const ADAPTIVE_FLAT_RES: int = 12
const ADAPTIVE_ROLL_RES: int = 14
const ADAPTIVE_HILL_RES: int = 16

# Per-LOD debug materials (F4 to toggle) — tints chunks by LOD so you can see transitions
static var _debug_materials: Array = []
static var debug_lod_active: bool = false

static func _get_debug_material(lod: int) -> StandardMaterial3D:
	while _debug_materials.size() <= lod:
		_debug_materials.append(null)
	if _debug_materials[lod]:
		return _debug_materials[lod]
	var colors = [Color(1,1,1), Color(0.3,0.5,1), Color(0.2,0.8,0.2), Color(1,0.3,0.3), Color(1,0.8,0.1)]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = colors[clampi(lod, 0, colors.size()-1)]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_materials[lod] = mat
	return mat

func create_terrain_material() -> Material:
	if debug_lod_active:
		return _get_debug_material(current_lod)
	# LOD1+: lit vertex colors, no texture samples
	if current_lod >= 1:
		return _get_distant_material()

	_ensure_textures_loaded()
	var shader    = _tex_shader
	var grass_tex = _tex_grass
	var snow_tex  = _tex_snow
	var stone_tex = _tex_stone
	var sand_tex  = _tex_sand
	if shader and grass_tex and snow_tex:
		# Use shader material with textures
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("grass_texture", grass_tex)
		mat.set_shader_parameter("snow_texture", snow_tex)
		mat.set_shader_parameter("stone_texture", stone_tex if stone_tex else grass_tex)
		if sand_tex:
			mat.set_shader_parameter("sand_texture", sand_tex)

		# Normal maps — fallback chain so missing textures don't break the shader
		var gnorm = _tex_grass_normal
		var snorm = _tex_stone_normal if _tex_stone_normal else gnorm
		var wsnorm = _tex_snow_normal if _tex_snow_normal else snorm
		if gnorm:
			mat.set_shader_parameter("grass_normal", gnorm)
			mat.set_shader_parameter("sand_normal", gnorm)
		if snorm:
			mat.set_shader_parameter("stone_normal", snorm)
		mat.set_shader_parameter("snow_normal", wsnorm if wsnorm else gnorm)

		mat.set_shader_parameter("texture_scale", 0.05)
		mat.set_shader_parameter("cliff_texture_scale", 0.08)

		# Height-based texture thresholds (absolute world Y coordinates)
		mat.set_shader_parameter("snow_start_height", 300.0)  # Snow starts at 75% of terrain_height
		mat.set_shader_parameter("snow_full_height", 360.0)   # Full snow at 90%
		mat.set_shader_parameter("stone_blend_range", 100.0)  # Stone zone 100m below snow

		# Slope thresholds - less aggressive cliff detection for more grass
		mat.set_shader_parameter("slope_snow_threshold", 0.5)
		mat.set_shader_parameter("cliff_slope_start", 0.55)  # Cliffs only on steeper slopes (~55 degrees)
		mat.set_shader_parameter("cliff_slope_full", 0.35)   # Full cliff at ~70 degrees

		# Beach settings
		mat.set_shader_parameter("beach_height_max", 15.0)
		mat.set_shader_parameter("beach_slope_min", 0.85)

		mat.set_shader_parameter("use_vertex_color_tint", true)
		mat.set_shader_parameter("vertex_color_strength", 0.08)  # Low — chunk seams amplify tiny height diffs

		# Pass terrain height info
		if terrain_manager:
			if "terrain_height" in terrain_manager:
				mat.set_shader_parameter("max_terrain_height", terrain_manager.terrain_height)

			# Pass water height for underwater caustics and beach detection
			# Also set grass_min_height to water_height + 3 meters
			if "absolute_water_height" in terrain_manager:
				var water_h = terrain_manager.absolute_water_height
				mat.set_shader_parameter("water_height", water_h)
				mat.set_shader_parameter("grass_min_height", water_h + 3.0)  # Grass starts 3m above sea level

		return mat
	else:
		# Fallback to simple vertex color material
		var mat = StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.9
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		return mat

func load_chunk():
	if not is_loaded:
		visible = true
		is_loaded = true

func unload_chunk():
	if is_loaded:
		visible = false
		is_loaded = false

func get_height_at_position(world_pos: Vector3) -> float:
	return get_height_at_world_pos(world_pos.x, world_pos.z)

# Debug: track raycast statistics
var _raycast_hits: int = 0
var _raycast_misses: int = 0
var _last_raycast_log_time: int = 0

# Get actual mesh surface height using raycast (matches visual terrain exactly)
func get_mesh_surface_height(world_x: float, world_z: float) -> float:
	# Convert to local coords for this chunk
	var local_x = world_x - position.x
	var local_z = world_z - position.z

	# Check if within this chunk's bounds
	var half_size = chunk_size / 2.0
	if abs(local_x) > half_size or abs(local_z) > half_size:
		# Out of bounds, fall back to noise height
		return get_height_at_world_pos(world_x, world_z)

	# Use raycast if we have collision body
	if collision_body and collision_body.is_inside_tree():
		var space_state = get_world_3d().direct_space_state
		if space_state:
			# Raycast from high above down to find terrain surface
			# Must start above max possible terrain (height_scale * 2 to account for biome multipliers)
			var ray_start = Vector3(world_x, height_scale * 2 + 200, world_z)
			var ray_end = Vector3(world_x, -100, world_z)

			var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			query.collide_with_areas = false
			query.collide_with_bodies = true

			var result = space_state.intersect_ray(query)
			if result and result.size() > 0:
				_raycast_hits += 1
				return result.position.y
			else:
				_raycast_misses += 1
				# Log miss details (throttled)
				var now = Time.get_ticks_msec()
				if now - _last_raycast_log_time > 1000:  # Log at most once per second
					_last_raycast_log_time = now
					pass  # Debug logging disabled

	# Fallback: manually interpolate from mesh vertices
	# Find which grid cell we're in
	var grid_x = (local_x + half_size) / chunk_size * resolution
	var grid_z = (local_z + half_size) / chunk_size * resolution

	var x0 = int(floor(grid_x))
	var z0 = int(floor(grid_z))
	var x1 = mini(x0 + 1, resolution)
	var z1 = mini(z0 + 1, resolution)

	# Get fractional position within cell
	var fx = grid_x - x0
	var fz = grid_z - z0

	# Get heights at the 4 corners of the grid cell
	var h00 = get_vertex_height(x0, z0)
	var h10 = get_vertex_height(x1, z0)
	var h01 = get_vertex_height(x0, z1)
	var h11 = get_vertex_height(x1, z1)

	# Bilinear interpolation (matches how the mesh renders)
	var h0 = lerp(h00, h10, fx)
	var h1 = lerp(h01, h11, fx)
	return lerp(h0, h1, fz)

# Get height at a specific vertex grid position
func get_vertex_height(grid_x: int, grid_z: int) -> float:
	grid_x = clampi(grid_x, 0, resolution)
	grid_z = clampi(grid_z, 0, resolution)

	# Calculate the world position this vertex corresponds to
	var local_x = (float(grid_x) / float(resolution)) * chunk_size - chunk_size / 2.0
	var local_z = (float(grid_z) / float(resolution)) * chunk_size - chunk_size / 2.0
	var world_x = position.x + local_x
	var world_z = position.z + local_z

	return get_height_at_world_pos(world_x, world_z)
