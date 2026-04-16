# Possession Codebase Audit: Lighting, Rendering & Shader Inconsistencies

---

## CRITICAL Issues

### 1. Water Level Unit Disaster (3 incompatible scales)

`world.tscn` sets `water_level = 40.0`, but `terrain_manager.gd` treats it as a 0-1 fraction:
```gdscript
absolute_water_height = water_level * terrain_height  # 40.0 * 400 = 16,000m
```
The water plane is at **16 kilometres altitude**. The biome default of `0.06` would give 24m (reasonable). The shader default `water_height = 48.0` is yet another value. All underwater rendering (caustics, god rays, seafloor) is broken.

**Files:** world.tscn, terrain_manager.gd, terrain_chunk.gd, terrain_shader.gdshader, biome_definitions.gd

### 2. `hint_depth_texture` Not Available in GL Compatibility

`water_shader.gdshader` line 46:
```glsl
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
```
GL Compatibility does not support reading the depth buffer. The volumetric god rays (lines 306-323) depend entirely on this. They produce garbage or black on the target hardware.

**File:** water_shader.gdshader

### 3. PropPool Path Wrong - Tree LOD System Completely Non-Functional

`terrain_chunk.gd` line 75:
```gdscript
var prop_pool = get_node_or_null("/root/World/PropPool")
```
Actual path is `/root/World/TerrainManager/PropPool` (terrain_manager adds it as its own child). `update_tree_lods()` always fails to find the pool and exits early. **Tree LODs never update.**

**File:** terrain_chunk.gd

### 4. Snow Never Appears

Terrain shader: `snow_start_height = 600.0` (absolute metres).
Terrain height: `terrain_height = 400.0` (world.tscn).
Terrain never reaches 600m, so **the shader never shows snow textures**.

Meanwhile the vertex color system uses `normalized_height > 0.75` which with Rolling Plains `height_multiplier = 0.3` gives snow at **90m** -- completely mismatched.

**Files:** terrain_chunk.gd, terrain_shader.gdshader, world.tscn

### 5. Structures Accumulate Across LOD Transitions

`maybe_spawn_structure()` in terrain_chunk.gd has no existence check. Every time a chunk transitions LOD (via `set_lod()` -> `generate_terrain()` -> `maybe_spawn_structure()`), new structures are spawned on top of existing ones. The teardown in `set_lod()` only removes `mesh_instance`, `collision_body`, and `Props`/`WaterPlane` nodes -- not structure nodes.

**File:** terrain_chunk.gd

---

## HIGH Issues

### 6. Shadow Distance 2000m on Potato Hardware

`world.tscn` line 134: `shadow_max_distance = 2000.0`

The shadow map stretches over 2km. On GL Compatibility with integrated graphics, this is extremely expensive. The project explicitly targets "low-spec/potato hardware." Should be ~300-500m.

**File:** world.tscn

### 7. day_night_cycle.gd Immediately Overrides Sun Energy to 1.0

`world.tscn` sets `light_energy = 1.4`. Then `day_night_cycle.gd` `_ready()` line 45:
```gdscript
sun_light.light_energy = 1.0
```
The scene value of 1.4 never has any effect during gameplay. The max sun_intensity in `update_lighting()` is also 1.0, so the sun is always weaker than intended.

**Files:** world.tscn, day_night_cycle.gd

### 8. Hardcoded Sun Direction in Water Shader

`water_shader.gdshader` has TWO different hardcoded sun directions (inconsistent with each other!):
- Line 95: `vec3 sun_dir = normalize(vec3(0.3, 0.9, 0.2));`
- Line 339: `vec3 sun_dir = normalize(vec3(0.3, 0.8, 0.2));`

Neither matches the actual sun direction from `day_night_cycle.gd`, which rotates dynamically. Water specular and god rays always point the wrong way at dawn/dusk/night.

**Files:** water_shader.gdshader, day_night_cycle.gd

### 9. Fog Uses Forward+ Features, Never Updates for Night

`world.tscn` sets `fog_enabled = true` with `fog_depth_begin/end` -- these are Forward+ volumetric fog params. GL Compatibility only supports exponential fog.

Additionally, `day_night_cycle.gd` never updates fog color for time of day. Fog stays daytime blue at night.

**Files:** world.tscn, day_night_cycle.gd

### 10. Boundary Walls and Monoliths Cast Shadows

`prop_pool.gd` correctly disables shadows on trees via `disable_shadows_recursive()`. But boundary walls (100,000m long boxes in `terrain_manager.gd`) and monolith structures never set `cast_shadow = SHADOW_CASTING_SETTING_OFF`. These participate in the already-expensive 2000m shadow system.

**Files:** terrain_manager.gd, terrain_chunk.gd, ancient_structures.gd

### 11. `diffuse_burley` / `specular_schlick_ggx` Not GL Compat

`water_shader.gdshader` line 2:
```glsl
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
```
These PBR render modes silently fall back in GL Compatibility. The intended PBR water is not achievable on the target platform.

**File:** water_shader.gdshader

---

## MEDIUM Issues

### 12. world.tscn Values Overwritten by day_night_cycle.gd (Misleading Inspector)

`world.tscn` ambient: `Color(0.38, 0.42, 0.52)` energy `0.4`
`day_night_cycle.gd` setup_environment(): `Color(0.5, 0.6, 0.7)` energy `0.3`

The .tscn values are replaced immediately at runtime. The Godot inspector shows the wrong values.

### 13. Weapon Viewport Ambient Never Updates for Night

`WeaponWorldEnvironment` in world.tscn has static ambient `Color(0.55, 0.57, 0.62)` energy `0.5`. `DayNightCycle` never touches it. At night, the main world goes dark but weapons remain brightly lit.

**Files:** world.tscn, day_night_cycle.gd

### 14. get_stats() Key Mismatch - HUD Pool Display Always 0

`prop_pool.gd` `get_stats()` returns keys `"available_trees"`, `"borrowed_trees"`, `"total_trees"`.
`player.gd` reads `stats.get("available", 0)`, `stats.get("borrowed", 0)`, `stats.get("total", 0)`.
Keys don't match. Debug HUD pool stats are permanently zero.

**Files:** prop_pool.gd, player.gd

### 15. Grass Weights Lost on LOD Transitions

`terrain_chunk.gd` `_resample_offsets()` resamples `height_offsets` when LOD changes but does NOT resample `grass_weights`. When a chunk transitions from LOD0 to LOD1 and back, `grass_weights` is reset to all zeros via `_ensure_offsets_sized()`. Painted grass is permanently lost.

**File:** terrain_chunk.gd

### 16. Duplicate Structure Spawning Systems

Two independent systems spawn monolith structures:
1. `ancient_structures.gd` -- fixed gateway at (0, 0, -120), with collision, 38x180x38m
2. `terrain_chunk.gd` `maybe_spawn_structure()` -- procedural 2% of chunks, no collision, 30x120x30m

The procedural system only skips chunk (0,0), but the hand-placed gateway is at chunk (0,-1) or (0,-2). They can overlap. One has collision, the other doesn't.

### 17. Continental Coastline Can Never Match Sky Shader

`terrain_manager.gd` uses `coastline_noise` seeded with `world_seed + 12345`. The sky shader uses its own internal `hash()` function with no external seed. Comment says "Same seed as skybox would use" but they can never match.

**Files:** terrain_manager.gd, sky_shader.gdshader

### 18. Chunk Center Offset Wrong for Biome Queries

`terrain_chunk.gd` calculates chunk center as `position + chunk_size/2`, but chunk meshes span `[-chunk_size/2, +chunk_size/2]` around position. The "center" used for biome queries is actually the positive corner.

**File:** terrain_chunk.gd

### 19. sample_world_height() Uses round() Instead of floor()

`terrain_manager.gd` line 1257 uses `round()` for chunk coordinate lookup. All other chunk lookups use `floor()`. At chunk boundaries, this returns the wrong chunk and produces wrong heights (affects flatten brush).

**File:** terrain_manager.gd

---

## LOW Issues

### 20. sky_shader.gdshader Is Entirely Dead Code

800+ lines of shader code (gas giant, constellations, clouds, ring world surface) that cannot render in GL Compatibility. Never loaded by any scene or script.

### 21. `biome_height_mult` Uniform Declared but Never Used in Terrain Shader

`terrain_shader.gdshader` line 23: declared, never read in fragment/vertex, never set by code.

### 22. `grow_grass_pool_sync()` Dead Duplicate

`prop_pool.gd` has two nearly identical functions: `grow_grass_pool_sync()` (line 269, never called) and `grow_grass_sync()` (line 415, called from _ready). Dead code.

### 23. `check_sun_visibility()` Collision Mask Hits Boundary Walls

`day_night_cycle.gd` raycast uses `collision_mask = 1` (terrain layer). Boundary walls are also on layer 1. Sun may incorrectly "set" when approaching a boundary wall.

### 24. WeaponLight Cull Mask Not Restricted

`WeaponLight` in world.tscn has no `light_cull_mask` set (defaults to all layers). It should be restricted to layer 2 (weapon layer) since the SubViewport has `own_world_3d = true` and only contains layer-2 objects anyway. Not a visible bug currently but not intentional.
