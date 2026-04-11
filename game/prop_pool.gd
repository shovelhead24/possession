extends Node
class_name PropPool

# Object pool for trees and decorators to avoid constant instantiation/destruction
# Trees are borrowed when chunks load and returned when they unload

# Tree model scenes (loaded from GLTF)
var tree_scenes: Array[PackedScene] = []
var tree_scales: Array[float] = []  # Scale multiplier for each tree type
var tree_names: Array[String] = []

# Grass model scenes (loaded from GLTF)
var grass_scene: PackedScene = null
var grass_variant_names: Array[String] = []  # Names of grass variants in the scene
var grass_pivot_offsets: Dictionary = {}  # Per-variant Y offset to compensate for pivot position

# Tree pivot offsets (per tree_name) - will be calculated from mesh bounds
var tree_pivot_offsets: Dictionary = {
	"Fir1": 0.0,
	"Fir2": 0.0,
	"Fir3": 0.0,
	"Procedural": 0.0
}

# Track if we've calculated the actual mesh-based offsets
var offsets_calculated: bool = false

# Material cache - prevents creating thousands of duplicate materials (causes RID limit crash)
var _material_cache: Dictionary = {}  # original_material_rid -> fixed_material

# Pool of available trees (not currently in use)
var available_trees: Array = []

# Pool of available grass (not currently in use)
var available_grass: Array = []

# Trees currently borrowed by chunks (chunk_coords -> Array of trees)
var borrowed_trees: Dictionary = {}

# Grass currently borrowed by chunks (chunk_coords -> Array of grass)
var borrowed_grass: Dictionary = {}

# Pool configuration - Trees
@export var initial_pool_size: int = 4000  # Pre-allocate for 200 trees/chunk with multiple chunks
@export var pool_grow_size: int = 100  # Grow in larger batches to keep up with chunk loading
@export var max_pool_size: int = 10000  # Support up to ~50 chunks with trees (200 each)

# Pool configuration - Grass
@export var initial_grass_pool_size: int = 5000  # More grass than trees
@export var grass_grow_size: int = 100  # Grow grass in larger batches
@export var max_grass_pool_size: int = 10000  # Max grass instances to match tree count

var total_trees_created: int = 0
var total_grass_created: int = 0

# Async pool growth - spread tree creation across frames
var pending_grow_count: int = 0
var pending_grass_grow_count: int = 0
var trees_per_frame: int = 5  # Create max 5 trees per frame when growing
var grass_per_frame: int = 20  # Create max 20 grass per frame (they're simpler)

func _ready():
	print("PropPool: _ready() START")
	load_tree_models()
	print("PropPool: load_tree_models() DONE - ", tree_scenes.size(), " scenes loaded")
	load_grass_models()
	print("PropPool: load_grass_models() DONE - grass_scene=", grass_scene != null)
	# Calculate actual mesh-based pivot offsets before creating pool
	print("PropPool: Starting calculate_tree_pivot_offsets()...")
	calculate_tree_pivot_offsets()
	print("PropPool: calculate_tree_pivot_offsets() DONE")
	# Create initial pool synchronously at startup (loading screen anyway)
	print("PropPool: Starting grow_pool_sync(", initial_pool_size, ")...")
	grow_pool_sync(initial_pool_size)
	print("PropPool: grow_pool_sync() DONE - created ", total_trees_created, " trees")
	print("PropPool: Starting grow_grass_pool_sync(", initial_grass_pool_size, ")...")
	grow_grass_pool_sync(initial_grass_pool_size)
	print("PropPool: grow_grass_pool_sync() DONE - created ", total_grass_created, " grass")
	print("PropPool: Initialized with ", initial_pool_size, " trees and ", initial_grass_pool_size, " grass")

func _process(_delta):
	# Async tree pool growth - create a few trees per frame if needed
	if pending_grow_count > 0 and total_trees_created < max_pool_size:
		var to_create = mini(trees_per_frame, pending_grow_count)
		to_create = mini(to_create, max_pool_size - total_trees_created)
		for i in range(to_create):
			var tree: Node3D
			if tree_scenes.is_empty():
				tree = create_procedural_tree(total_trees_created % 3)
			else:
				tree = create_model_tree(total_trees_created % tree_scenes.size())
			tree.visible = false
			add_child(tree)
			available_trees.append(tree)
			total_trees_created += 1
			pending_grow_count -= 1

	# Async grass pool growth - create grass per frame if needed
	if pending_grass_grow_count > 0 and total_grass_created < max_grass_pool_size:
		if grass_variant_names.is_empty():
			pending_grass_grow_count = 0
			return
		var to_create = mini(grass_per_frame, pending_grass_grow_count)
		to_create = mini(to_create, max_grass_pool_size - total_grass_created)
		for i in range(to_create):
			var grass = create_grass_instance(total_grass_created % grass_variant_names.size())
			grass.visible = false
			add_child(grass)
			available_grass.append(grass)
			total_grass_created += 1
			pending_grass_grow_count -= 1

func load_tree_models():
	# Load the realistic fir trees pack (has 3 tree variants with proper alpha)
	var fir_pack_path = "res://realistic_fir_trees_pack_lods_gameready/scene.gltf"
	if ResourceLoader.exists(fir_pack_path):
		var fir_pack = load(fir_pack_path) as PackedScene
		if fir_pack:
			# This pack contains 3 tree variants, each with LOD levels
			# We'll use LOD0 (highest detail) for each variant
			tree_scenes.append(fir_pack)
			tree_scales.append(1.2)  # Scale up slightly
			tree_names.append("Fir1")

			tree_scenes.append(fir_pack)
			tree_scales.append(1.0)
			tree_names.append("Fir2")

			tree_scenes.append(fir_pack)
			tree_scales.append(0.9)
			tree_names.append("Fir3")

			print("PropPool: Loaded Realistic Fir Trees pack (3 variants)")

	# Fallback: if no models loaded, we'll create procedural trees
	if tree_scenes.is_empty():
		print("PropPool: WARNING - No tree models found, using procedural fallback")

func load_grass_models():
	# Load the grass pack (has 9 variants - 3 large, 3 medium, 3 small)
	var grass_pack_path = "res://grass_pack_of_9_vars_lowpoly_game_ready/scene.gltf"
	if ResourceLoader.exists(grass_pack_path):
		grass_scene = load(grass_pack_path) as PackedScene
		if grass_scene:
			# Define the grass variants we want to use
			# Pivot offsets: negative = push into ground (model pivot is above ground level)
			# These values need tuning based on actual model pivot positions
			grass_variant_names = [
				"Grass large 1",
				"Grass large 2",
				"Grass large 3",
				"Grass medium 1",
				"Grass medium 2",
				"Grass medium 3",
				"Grass small 1",
				"Grass small 2",
				"Grass small 3"
			]
			# Per-variant pivot offsets (tune these based on visual inspection)
			grass_pivot_offsets = {
				"Grass large 1": -0.3,
				"Grass large 2": -0.3,
				"Grass large 3": -0.3,
				"Grass medium 1": -0.2,
				"Grass medium 2": -0.2,
				"Grass medium 3": -0.2,
				"Grass small 1": -0.1,
				"Grass small 2": -0.1,
				"Grass small 3": -0.1
			}
			print("PropPool: Loaded Grass pack (9 variants with pivot offsets)")

	if grass_scene == null:
		print("PropPool: WARNING - No grass models found")

# Calculate actual mesh bounds to determine pivot offsets
# This is called once at startup to measure where the visible mesh geometry sits
func calculate_tree_pivot_offsets():
	if offsets_calculated or tree_scenes.is_empty():
		return

	print("PropPool: Calculating tree pivot offsets from mesh bounds...")

	for i in range(tree_scenes.size()):
		var tree_name = tree_names[i]
		var tree_instance = tree_scenes[i].instantiate()

		# Determine which LOD0 node to measure
		var show_pattern = ""
		match tree_name:
			"Fir1": show_pattern = "Christmas tree_LOD0"
			"Fir2": show_pattern = "Christmas tree_2_LOD0"
			"Fir3": show_pattern = "Christmas tree_3_LOD0"

		# Hide other variants so we only measure the one we care about
		hide_except_pattern(tree_instance, show_pattern)

		# Calculate combined AABB of all visible MeshInstance3D nodes
		var bounds = calculate_visible_mesh_bounds(tree_instance, Transform3D.IDENTITY, INF, -INF)
		var min_y = bounds[0]
		var max_y = bounds[1]

		if min_y != INF and max_y != -INF:
			# The pivot offset should lower the tree so its bottom sits at Y=0
			# If min_y > 0, tree is floating and needs negative offset
			# If min_y < 0, tree is sinking and needs positive offset
			var offset = -min_y

			# EXPERIMENTAL: Apply additional offset to compensate for visual floating
			# The mesh bounds show trees at Y=0, but they appear to float
			# This suggests internal GLTF transforms are causing visual offset
			# Try -3.0 to push trees down into terrain
			var visual_correction = -3.0
			offset += visual_correction

			tree_pivot_offsets[tree_name] = offset
			print("PropPool: ", tree_name, " mesh Y range: ", min_y, " to ", max_y, " -> pivot_offset = ", offset, " (includes ", visual_correction, " visual correction)")
		else:
			print("PropPool: ", tree_name, " - no visible mesh bounds found")

		tree_instance.queue_free()

	offsets_calculated = true

# Iteratively calculate min/max Y of visible mesh geometry
func calculate_visible_mesh_bounds(root_node: Node, initial_transform: Transform3D, initial_min_y: float, initial_max_y: float) -> Array:
	var min_y = initial_min_y
	var max_y = initial_max_y

	# Queue stores [node, accumulated_transform] pairs
	var queue: Array = [[root_node, initial_transform]]

	while queue.size() > 0:
		var item = queue.pop_back()
		var node = item[0]
		var parent_transform = item[1]

		if not node or not is_instance_valid(node):
			continue
		if not node is Node3D:
			continue

		var node3d = node as Node3D
		if not node3d.visible:
			continue

		# Combine parent transform with this node's transform
		var current_transform = parent_transform * node3d.transform

		if node is MeshInstance3D:
			var mesh_instance = node as MeshInstance3D
			if mesh_instance.mesh:
				var aabb = mesh_instance.mesh.get_aabb()
				# Transform AABB corners to world space
				var corners = [
					Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
					Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z),
					Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z + aabb.size.z),
					Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z)
				]
				for corner in corners:
					var world_pos = current_transform * corner
					if world_pos.y < min_y:
						min_y = world_pos.y
					if world_pos.y > max_y:
						max_y = world_pos.y

		# Add children to queue with accumulated transform
		for child in node.get_children():
			queue.push_back([child, current_transform])

	return [min_y, max_y]

# Synchronous grass pool growth - only used at startup
func grow_grass_pool_sync(count: int):
	if grass_scene == null or grass_variant_names.is_empty():
		return
	if total_grass_created >= max_grass_pool_size:
		return

	var to_create = mini(count, max_grass_pool_size - total_grass_created)

	for i in range(to_create):
		var grass = create_grass_instance(i % grass_variant_names.size())
		grass.visible = false
		add_child(grass)
		available_grass.append(grass)
		total_grass_created += 1

# Async grass pool growth
func grow_grass_pool_async(count: int):
	pending_grass_grow_count += count

func create_grass_instance(variant_index: int) -> Node3D:
	# Create a container node for proper scaling and rotation
	var container = Node3D.new()

	# Instance the grass scene
	var grass_instance = grass_scene.instantiate()
	container.add_child(grass_instance)

	# Show only the specific variant we want
	var target_variant = grass_variant_names[variant_index]
	hide_grass_except(grass_instance, target_variant)

	# Fix transparency on grass materials
	fix_grass_materials(grass_instance)

	# Scale based on variant type (small grass smaller, large grass bigger)
	var base_scale = 1.0
	if "small" in target_variant:
		base_scale = 0.6
	elif "medium" in target_variant:
		base_scale = 0.8
	elif "large" in target_variant:
		base_scale = 1.0
	container.scale = Vector3(base_scale, base_scale, base_scale)

	# Store type and pivot offset for later reference
	container.set_meta("grass_type", target_variant)
	var pivot_offset = grass_pivot_offsets.get(target_variant, -0.15)
	container.set_meta("pivot_offset", pivot_offset)

	return container

func hide_grass_except(root_node: Node, target_variant: String):
	# Iteratively hide grass nodes that don't match the target variant
	var queue: Array = [root_node]

	while queue.size() > 0:
		var node = queue.pop_back()
		if not node or not is_instance_valid(node):
			continue

		for child in node.get_children():
			if not child is Node3D:
				continue

			var child_name = child.name as String
			# Check if this is a grass variant node
			if child_name.begins_with("Grass "):
				# Show only if it matches our target variant
				child.visible = (child_name == target_variant)
			else:
				# Add to queue for processing
				queue.push_back(child)

func fix_grass_materials(root_node: Node):
	# Iteratively fix materials on all MeshInstance3D descendants
	# Uses material cache to avoid creating thousands of duplicate materials (RID limit)
	var queue: Array = [root_node]

	while queue.size() > 0:
		var node = queue.pop_back()
		if not node or not is_instance_valid(node):
			continue

		if node is MeshInstance3D:
			var mesh_instance = node as MeshInstance3D

			if mesh_instance.mesh:
				for surface_idx in range(mesh_instance.mesh.get_surface_count()):
					var mat = mesh_instance.get_active_material(surface_idx)
					if mat == null:
						mat = mesh_instance.mesh.surface_get_material(surface_idx)
					if mat == null:
						continue

					if mat is BaseMaterial3D:
						var base_mat = mat as BaseMaterial3D
						if base_mat.albedo_texture:
							# Check if we already have a cached version of this material
							var mat_rid = base_mat.get_rid()
							if mat_rid in _material_cache:
								# Reuse cached material
								mesh_instance.set_surface_override_material(surface_idx, _material_cache[mat_rid])
							else:
								# Create and cache new fixed material
								var new_mat = base_mat.duplicate() as BaseMaterial3D
								new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
								new_mat.alpha_scissor_threshold = 0.5
								new_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
								_material_cache[mat_rid] = new_mat
								mesh_instance.set_surface_override_material(surface_idx, new_mat)

		# Add children to queue
		for child in node.get_children():
			queue.push_back(child)

# Synchronous pool growth - only used at startup
func grow_pool_sync(count: int):
	if total_trees_created >= max_pool_size:
		return

	var to_create = mini(count, max_pool_size - total_trees_created)
	print("PropPool: grow_pool_sync creating ", to_create, " trees...")

	for i in range(to_create):
		# Log progress every 100 trees
		if i % 100 == 0:
			print("PropPool: Creating tree ", i, "/", to_create)

		var tree: Node3D
		if tree_scenes.is_empty():
			tree = create_procedural_tree(i % 3)
		else:
			tree = create_model_tree(i % tree_scenes.size())

		if not tree:
			push_warning("PropPool: create_model_tree returned null at index ", i)
			continue

		tree.visible = false
		add_child(tree)
		available_trees.append(tree)
		total_trees_created += 1

	print("PropPool: grow_pool_sync finished, total_trees_created=", total_trees_created)

# Async pool growth - queue trees to be created over multiple frames
func grow_pool_async(count: int):
	pending_grow_count += count

var _debug_tree_count: int = 0  # Debug counter

func create_model_tree(type_index: int) -> Node3D:
	_debug_tree_count += 1
	var debug_id = _debug_tree_count

	# Only log first few and then every 500
	var should_log = debug_id <= 3 or debug_id % 500 == 0

	if should_log:
		print("PropPool: create_model_tree #", debug_id, " type_index=", type_index)

	# Create a container node for proper scaling and rotation
	var container = Node3D.new()

	# Store type and pivot offset
	var tree_name = tree_names[type_index]
	container.set_meta("tree_type", tree_name)
	container.set_meta("current_lod", 0)  # Track current LOD level
	var pivot_offset = tree_pivot_offsets.get(tree_name, 0.0)
	container.set_meta("pivot_offset", pivot_offset)

	if should_log:
		print("  - Instantiating tree scene...")

	# Instance the tree scene
	var tree_instance = tree_scenes[type_index].instantiate()
	if not tree_instance:
		push_warning("PropPool: Failed to instantiate tree scene for " + tree_name)
		return container

	if should_log:
		print("  - Adding child...")
	container.add_child(tree_instance)

	# For the realistic fir pack, set up LOD switching
	if tree_name in ["Fir1", "Fir2", "Fir3"]:
		if should_log:
			print("  - Setting up LODs for ", tree_name)
		# Get the LOD pattern prefix for this tree variant
		var lod_prefix = ""
		match tree_name:
			"Fir1": lod_prefix = "Christmas tree_LOD"
			"Fir2": lod_prefix = "Christmas tree_2_LOD"
			"Fir3": lod_prefix = "Christmas tree_3_LOD"

		# Set up LOD nodes - show only our variant, hide others
		setup_tree_lods(tree_instance, tree_name, lod_prefix)
		if should_log:
			print("  - LOD setup done")

	if should_log:
		print("  - Fixing materials...")
	# Fix transparency on leaf materials (for branches)
	fix_tree_materials(tree_instance)

	if should_log:
		print("  - Creating billboard...")
	# Create billboard for very distant viewing
	var billboard = create_tree_billboard(tree_name)
	billboard.name = "Billboard"
	billboard.visible = false  # Start hidden, show at far distance
	container.add_child(billboard)
	container.set_meta("billboard", billboard)

	if should_log:
		print("  - Tree #", debug_id, " complete")

	# Apply base scale
	var base_scale = tree_scales[type_index]
	container.scale = Vector3(base_scale, base_scale, base_scale)

	return container

# Set up LOD nodes for a tree - hide other variants, keep all LODs of our variant
# Uses iterative approach with a queue to avoid deep recursion
func setup_tree_lods(tree_instance: Node, tree_name: String, lod_prefix: String):
	# Get the container (parent of tree_instance) where we'll store LOD references
	var container = tree_instance.get_parent()
	if not container:
		print("  WARNING: setup_tree_lods - no container parent!")
		return

	# Use a queue for iterative traversal instead of recursion
	var queue: Array = [tree_instance]
	var iterations = 0
	var max_iterations = 10000  # Safety limit

	while queue.size() > 0 and iterations < max_iterations:
		iterations += 1
		var node = queue.pop_back()
		if not node or not is_instance_valid(node):
			continue

		for child in node.get_children():
			if not child is Node3D:
				continue

			var child_name = child.name as String

			if child_name.begins_with("Christmas tree"):
				# Check if this node belongs to our tree variant
				var is_our_variant = false
				if tree_name == "Fir1":
					# Fir1: matches "Christmas tree_LOD" but NOT "_2_" or "_3_"
					is_our_variant = child_name.begins_with("Christmas tree_LOD")
				else:
					is_our_variant = child_name.begins_with(lod_prefix)

				if is_our_variant:
					# This is our variant - show LOD0, hide LOD1/LOD2 initially
					if "LOD0" in child_name:
						child.visible = true
						container.set_meta("lod0_node", child)
					elif "LOD1" in child_name:
						child.visible = false
						container.set_meta("lod1_node", child)
					elif "LOD2" in child_name:
						child.visible = false
						container.set_meta("lod2_node", child)
					else:
						child.visible = false
				else:
					# Different variant - hide completely
					child.visible = false
			else:
				# Add non-tree nodes to queue for processing
				queue.push_back(child)

	if iterations >= max_iterations:
		push_warning("PropPool: setup_tree_lods hit max iterations for ", tree_name)

# Create a billboard quad for distant tree rendering
func create_tree_billboard(tree_name: String) -> MeshInstance3D:
	var billboard = MeshInstance3D.new()

	# Create a simple quad mesh sized for realistic trees (5-12m tall)
	var quad = QuadMesh.new()
	quad.size = Vector2(6, 10)  # Width x Height in meters
	billboard.mesh = quad

	# Position at tree center height (half the billboard height)
	billboard.position.y = 5.0

	# Create billboard material
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED  # Face camera
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX  # Some shading for depth

	# Dark green tree silhouette color
	mat.albedo_color = Color(0.12, 0.28, 0.10, 1.0)

	billboard.material_override = mat

	return billboard

# Switch tree LOD based on distance (called from terrain_chunk)
func set_tree_lod(tree: Node3D, lod_level: int):
	if not tree.has_meta("tree_type"):
		return

	var current_lod = tree.get_meta("current_lod", 0) as int
	if current_lod == lod_level:
		return  # Already at this LOD

	tree.set_meta("current_lod", lod_level)

	# Get LOD nodes from stored metadata (set during setup_tree_lods)
	var lod0 = tree.get_meta("lod0_node", null) as Node3D
	var lod1 = tree.get_meta("lod1_node", null) as Node3D
	var lod2 = tree.get_meta("lod2_node", null) as Node3D
	var billboard = tree.get_meta("billboard", null) as Node3D

	# Switch visibility based on LOD level
	match lod_level:
		0:  # Close - full detail
			if lod0: lod0.visible = true
			if lod1: lod1.visible = false
			if lod2: lod2.visible = false
			if billboard: billboard.visible = false
		1:  # Medium - LOD1
			if lod0: lod0.visible = false
			if lod1: lod1.visible = true
			if lod2: lod2.visible = false
			if billboard: billboard.visible = false
		2:  # Far - LOD2
			if lod0: lod0.visible = false
			if lod1: lod1.visible = false
			if lod2: lod2.visible = true
			if billboard: billboard.visible = false
		_:  # Very far - billboard only
			if lod0: lod0.visible = false
			if lod1: lod1.visible = false
			if lod2: lod2.visible = false
			if billboard: billboard.visible = true

# Find a LOD node within a tree instance (iterative)
func find_lod_node(root_node: Node, lod_suffix: String) -> Node3D:
	var queue: Array = [root_node]

	while queue.size() > 0:
		var node = queue.pop_back()
		if not node or not is_instance_valid(node):
			continue

		for child in node.get_children():
			if not child is Node3D:
				continue

			var child_name = child.name as String
			# Match Christmas tree nodes that contain the LOD suffix (regardless of visibility)
			if child_name.begins_with("Christmas tree") and lod_suffix in child_name:
				return child
			# Add to queue for further search
			queue.push_back(child)

	return null

func hide_except_pattern(root_node: Node, show_pattern: String):
	# Iteratively hide nodes that don't match the pattern
	# Show only the specific tree LOD0 we want
	# show_pattern is like "Christmas tree_LOD0" or "Christmas tree_2_LOD0"

	# Determine which tree variant we want based on show_pattern
	# Tree 1: "Christmas tree_LOD" (no number between "tree" and "LOD")
	# Tree 2: "Christmas tree_2_LOD"
	# Tree 3: "Christmas tree_3_LOD"
	var variant_prefix: String
	if "tree_2_" in show_pattern:
		variant_prefix = "Christmas tree_2_"
	elif "tree_3_" in show_pattern:
		variant_prefix = "Christmas tree_3_"
	else:
		# Tree 1 - match "Christmas tree_LOD" but NOT "Christmas tree_2_" or "Christmas tree_3_"
		variant_prefix = "Christmas tree_LOD"  # Special case: include LOD in prefix

	var queue: Array = [root_node]

	while queue.size() > 0:
		var node = queue.pop_back()
		if not node or not is_instance_valid(node):
			continue

		for child in node.get_children():
			if not child is Node3D:
				continue

			var child_name = child.name as String
			# Check if this is a Christmas tree node (any variant/LOD)
			if child_name.begins_with("Christmas tree"):
				# For tree variant 1, check it starts with "Christmas tree_LOD" (no number)
				# For variants 2 and 3, check the full prefix
				var is_our_variant = false
				if variant_prefix == "Christmas tree_LOD":
					# Special handling: must start with "Christmas tree_LOD" but NOT "Christmas tree_2" or "Christmas tree_3"
					is_our_variant = child_name.begins_with("Christmas tree_LOD")
				else:
					is_our_variant = child_name.begins_with(variant_prefix)

				# Show only if it's our variant AND is LOD0
				child.visible = is_our_variant and "LOD0" in child_name
			else:
				# Add non-tree nodes to queue for processing
				queue.push_back(child)

func fix_tree_materials(root_node: Node):
	# Iteratively fix materials on all MeshInstance3D descendants
	# Uses material cache to avoid creating thousands of duplicate materials (RID limit)
	var queue: Array = [root_node]

	while queue.size() > 0:
		var node = queue.pop_back()
		if not node or not is_instance_valid(node):
			continue

		if node is MeshInstance3D:
			var mesh_instance = node as MeshInstance3D

			# Check surface materials
			if mesh_instance.mesh:
				for surface_idx in range(mesh_instance.mesh.get_surface_count()):
					# Try to get the active material (could be override or from mesh)
					var mat = mesh_instance.get_active_material(surface_idx)

					# If no override exists, try getting from mesh directly
					if mat == null:
						mat = mesh_instance.mesh.surface_get_material(surface_idx)

					if mat == null:
						continue

					# Apply alpha scissor to all BaseMaterial3D with textures
					if mat is BaseMaterial3D:
						var base_mat = mat as BaseMaterial3D
						# Only process materials that have an albedo texture
						if base_mat.albedo_texture:
							# Check if we already have a cached version of this material
							var mat_rid = base_mat.get_rid()
							if mat_rid in _material_cache:
								# Reuse cached material
								mesh_instance.set_surface_override_material(surface_idx, _material_cache[mat_rid])
							else:
								# Create and cache new fixed material
								var new_mat = base_mat.duplicate() as BaseMaterial3D
								new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
								new_mat.alpha_scissor_threshold = 0.5
								new_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
								_material_cache[mat_rid] = new_mat
								mesh_instance.set_surface_override_material(surface_idx, new_mat)

		# Add children to queue
		for child in node.get_children():
			queue.push_back(child)

func create_procedural_tree(tree_type: int) -> Node3D:
	# Fallback procedural trees (simple shapes)
	var tree = Node3D.new()

	# Create trunk
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.height = 4.5
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.radial_segments = 6

	var trunk = MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_mesh.height / 2.0

	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.32, 0.25, 0.15)
	trunk_mat.roughness = 1.0
	trunk.material_override = trunk_mat
	tree.add_child(trunk)

	# Create foliage
	var leaves_mat = StandardMaterial3D.new()
	leaves_mat.albedo_color = Color(0.15, 0.45, 0.15)
	leaves_mat.roughness = 0.9

	match tree_type:
		0:  # Conifer
			for j in range(4):
				var cone = CylinderMesh.new()
				cone.height = 1.5 - (j * 0.15)
				cone.top_radius = 0.1
				cone.bottom_radius = 1.8 - (j * 0.3)
				cone.radial_segments = 6

				var cone_mesh = MeshInstance3D.new()
				cone_mesh.mesh = cone
				cone_mesh.position.y = trunk_mesh.height + (j * 1.0) + 0.5
				cone_mesh.material_override = leaves_mat
				tree.add_child(cone_mesh)
		1:  # Deciduous
			var leaves = SphereMesh.new()
			leaves.radial_segments = 8
			leaves.rings = 6
			leaves.height = 3.2
			leaves.radius = 2.3

			var leaves_mesh = MeshInstance3D.new()
			leaves_mesh.mesh = leaves
			leaves_mesh.position.y = trunk_mesh.height + 1.5
			leaves_mesh.material_override = leaves_mat
			tree.add_child(leaves_mesh)
		2:  # Pine
			var pine = CylinderMesh.new()
			pine.height = 5.0
			pine.top_radius = 0.05
			pine.bottom_radius = 1.6
			pine.radial_segments = 6

			var pine_mesh = MeshInstance3D.new()
			pine_mesh.mesh = pine
			pine_mesh.position.y = trunk_mesh.height + 2.5
			pine_mesh.material_override = leaves_mat
			tree.add_child(pine_mesh)

	tree.set_meta("tree_type", "Procedural")
	return tree

# Borrow trees for a chunk
func borrow_trees(chunk_coords: Vector2i, count: int, parent: Node3D) -> Array:
	# If we need more trees, schedule async growth (don't block!)
	if available_trees.size() < count and total_trees_created < max_pool_size:
		var needed = count - available_trees.size()
		grow_pool_async(needed + pool_grow_size)  # Grow extra for future requests

	var borrowed = []
	var to_borrow = mini(count, available_trees.size())

	for i in range(to_borrow):
		var tree = available_trees.pop_back()
		if not is_instance_valid(tree):
			continue
		tree.visible = true

		# Reparent to chunk's props node (with null check)
		var old_parent = tree.get_parent()
		if old_parent:
			old_parent.remove_child(tree)
		parent.add_child(tree)

		borrowed.append(tree)

	borrowed_trees[chunk_coords] = borrowed

	return borrowed

# Return trees from a chunk
func return_trees(chunk_coords: Vector2i):
	if not chunk_coords in borrowed_trees:
		return

	var trees = borrowed_trees[chunk_coords]
	for tree in trees:
		if not is_instance_valid(tree):
			continue

		# Reset transform
		tree.transform = Transform3D.IDENTITY

		# Re-apply the base scale for model trees
		if tree.has_meta("tree_type"):
			var tree_type = tree.get_meta("tree_type")
			for i in range(tree_names.size()):
				if tree_names[i] == tree_type:
					var base_scale = tree_scales[i]
					tree.scale = Vector3(base_scale, base_scale, base_scale)
					break

		tree.visible = false

		# Reparent back to pool (with null check)
		var parent = tree.get_parent()
		if parent:
			parent.remove_child(tree)
		add_child(tree)

		available_trees.append(tree)

	borrowed_trees.erase(chunk_coords)

# Borrow grass for a chunk
func borrow_grass(chunk_coords: Vector2i, count: int, parent: Node3D) -> Array:
	# If we need more grass, schedule async growth (don't block!)
	if available_grass.size() < count and total_grass_created < max_grass_pool_size:
		var needed = count - available_grass.size()
		grow_grass_pool_async(needed + grass_grow_size)

	var borrowed = []
	var to_borrow = mini(count, available_grass.size())

	for i in range(to_borrow):
		var grass = available_grass.pop_back()
		if not is_instance_valid(grass):
			continue
		grass.visible = true

		# Reparent to chunk's props node (with null check)
		var old_parent = grass.get_parent()
		if old_parent:
			old_parent.remove_child(grass)
		parent.add_child(grass)

		borrowed.append(grass)

	borrowed_grass[chunk_coords] = borrowed

	return borrowed

# Return grass from a chunk
func return_grass(chunk_coords: Vector2i):
	if not chunk_coords in borrowed_grass:
		return

	var grasses = borrowed_grass[chunk_coords]
	for grass in grasses:
		if not is_instance_valid(grass):
			continue

		# Reset transform
		grass.transform = Transform3D.IDENTITY

		# Re-apply the base scale
		if grass.has_meta("grass_type"):
			var grass_type = grass.get_meta("grass_type")
			var base_scale = 1.0
			if "small" in grass_type:
				base_scale = 0.6
			elif "medium" in grass_type:
				base_scale = 0.8
			else:
				base_scale = 1.0
			grass.scale = Vector3(base_scale, base_scale, base_scale)

		grass.visible = false

		# Reparent back to pool (with null check)
		var parent = grass.get_parent()
		if parent:
			parent.remove_child(grass)
		add_child(grass)
		available_grass.append(grass)

	borrowed_grass.erase(chunk_coords)

# Get pool statistics
func get_stats() -> Dictionary:
	return {
		"available_trees": available_trees.size(),
		"borrowed_trees": borrowed_trees.size(),
		"total_trees": total_trees_created,
		"max_trees": max_pool_size,
		"available_grass": available_grass.size(),
		"borrowed_grass": borrowed_grass.size(),
		"total_grass": total_grass_created,
		"max_grass": max_grass_pool_size
	}
