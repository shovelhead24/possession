shader_type spatial;

// Textures
uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_texture : source_color, filter_linear_mipmap, repeat_enable;


// Texture tiling
uniform float texture_scale : hint_range(0.01, 1.0) = 0.05;
uniform float cliff_texture_scale : hint_range(0.01, 1.0) = 0.08;

// Terrain height info (passed from terrain_chunk)
uniform float max_terrain_height : hint_range(100.0, 1000.0) = 800.0;
uniform float biome_height_mult : hint_range(0.1, 1.5) = 1.0;

// Height-based blending thresholds (absolute world Y coordinates)
uniform float snow_start_height : hint_range(0.0, 1000.0) = 600.0;  // Snow starts at 600m
uniform float snow_full_height : hint_range(0.0, 1000.0) = 650.0;   // Full snow at 650m
uniform float grass_min_height : hint_range(-100.0, 500.0) = 11.0;  // Grass starts at water + 3m
uniform float stone_blend_range : hint_range(10.0, 200.0) = 50.0;   // How wide the stone transition zone is

// Beach/sand zone
uniform float beach_height_max : hint_range(0.0, 100.0) = 15.0;  // Max height above water for beach
uniform float beach_slope_min : hint_range(0.0, 1.0) = 0.85;  // Min slope for beach (flatter = more beach)

// Slope-based thresholds
uniform float slope_snow_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float cliff_slope_start : hint_range(0.0, 1.0) = 0.7;  // Below this = cliff
uniform float cliff_slope_full : hint_range(0.0, 1.0) = 0.5;   // Full cliff texture

// Use vertex colors for base tinting
uniform bool use_vertex_color_tint = true;
uniform float vertex_color_strength : hint_range(0.0, 1.0) = 0.4;

// Underwater caustics
uniform float water_height : hint_range(-100.0, 500.0) = 48.0;
uniform float caustic_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float caustic_scale : hint_range(0.01, 0.2) = 0.08;
uniform float caustic_speed : hint_range(0.0, 2.0) = 0.4;
uniform vec4 underwater_tint : source_color = vec4(0.15, 0.25, 0.35, 1.0);  // Darker underwater
uniform float underwater_darkening : hint_range(0.0, 1.0) = 0.6;  // How much to darken underwater
uniform float max_caustic_depth : hint_range(5.0, 100.0) = 30.0;

// Volumetric god rays (underwater)
uniform float god_ray_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float god_ray_scale : hint_range(0.001, 0.05) = 0.012;
uniform float god_ray_speed : hint_range(0.0, 1.0) = 0.15;
uniform float god_ray_fade_depth : hint_range(10.0, 100.0) = 50.0;

varying float vertex_height;
varying vec3 world_normal;
varying vec3 world_position;

// Hash function for caustic noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal noise for caustics
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

// Caustic pattern - creates light refraction effect
float caustics(vec2 uv, float time) {
	// Two layers of animated noise for caustic interference
	float c1 = fbm(uv + vec2(time * 0.7, time * 0.3));
	float c2 = fbm(uv * 1.3 - vec2(time * 0.5, time * 0.8));
	// Interference creates bright caustic lines
	float caustic = abs(c1 - c2);
	caustic = pow(caustic, 0.6);  // Sharpen the pattern
	return caustic;
}

// God ray spots - bright concentrated light areas from caustic peaks
float god_ray_spots(vec2 uv, float time) {
	// Use same caustic pattern but extract the brightest peaks as "god ray" spots
	float c1 = fbm(uv + vec2(time * 0.7, time * 0.3));
	float c2 = fbm(uv * 1.3 - vec2(time * 0.5, time * 0.8));
	float caustic = abs(c1 - c2);

	// Extract only the brightest peaks as god ray spots
	float spots = smoothstep(0.4, 0.7, caustic);

	// Add a second layer at different scale for variation
	float c3 = fbm(uv * 0.7 + vec2(time * 0.5, -time * 0.4));
	float c4 = fbm(uv * 0.9 - vec2(time * 0.6, time * 0.3));
	float caustic2 = abs(c3 - c4);
	float spots2 = smoothstep(0.45, 0.75, caustic2);

	// Combine for varied spot sizes
	float combined = max(spots, spots2 * 0.8);

	// Boost the brightest areas significantly
	combined = pow(combined, 0.7) * 1.5;

	return clamp(combined, 0.0, 1.0);
}

void vertex() {
	// Pass height and position to fragment shader
	vec4 world_vert = MODEL_MATRIX * vec4(VERTEX, 1.0);
	vertex_height = world_vert.y;
	world_position = world_vert.xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	// Sample textures with world-space UVs for seamless tiling across chunks
	vec2 tex_uv = world_position.xz * texture_scale;
	vec2 cliff_uv = world_position.xz * cliff_texture_scale;

	// Triplanar mapping for cliffs (better on steep surfaces)
	vec3 blend_weights = abs(normalize(world_normal));
	blend_weights = pow(blend_weights, vec3(4.0));
	blend_weights /= (blend_weights.x + blend_weights.y + blend_weights.z);

	// Hash-based regional brightness variation — breaks tiling perception with
	// zero extra texture fetches. Each cell is ~80 world units wide.
	vec2 region_cell = floor(world_position.xz * 0.012);
	float rv = hash(region_cell) * 0.28 + 0.86;  // 0.86–1.14 range

	// Sub-region hash at a different frequency adds a second layer of variation
	vec2 sub_cell = floor(world_position.xz * 0.035);
	float sv2 = hash(sub_cell + vec2(7.3, 2.9)) * 0.12 + 0.94;  // 0.94–1.06 range

	float var = rv * sv2;  // Combined variation multiplier

	// Sample base textures (single fetch each — no extra samples)
	vec3 grass = clamp(texture(grass_texture, tex_uv).rgb * var, 0.0, 1.0);
	vec3 snow  = texture(snow_texture, tex_uv).rgb;
	vec3 sand  = clamp(texture(sand_texture, tex_uv).rgb * var, 0.0, 1.0);

	// Triplanar stone sampling for cliffs
	vec3 stone_x = texture(stone_texture, world_position.zy * cliff_texture_scale).rgb;
	vec3 stone_y = texture(stone_texture, cliff_uv).rgb;
	vec3 stone_z = texture(stone_texture, world_position.xy * cliff_texture_scale).rgb;
	vec3 stone = clamp((stone_x * blend_weights.x + stone_y * blend_weights.y + stone_z * blend_weights.z) * var, 0.0, 1.0);
	vec3 chalk = stone * vec3(1.1, 1.08, 1.0);  // Warmer tint for high-altitude rock

	// Calculate slope (1.0 = flat, 0.0 = vertical)
	float slope = dot(normalize(world_normal), vec3(0.0, 1.0, 0.0));
	slope = clamp(slope, 0.0, 1.0);

	// Height above water for beach calculation
	float height_above_water = vertex_height - water_height;

	// Beach detection: flat areas near water level
	// Use noise for natural variation in beach boundaries
	float beach_noise = noise(world_position.xz * 0.01) * 0.5 + 0.5;  // 0.5-1.0 range
	float beach_threshold = beach_height_max * beach_noise;

	// Beach blend: 1.0 = full beach, 0.0 = no beach
	float beach_blend = 0.0;
	if (height_above_water > 0.0 && height_above_water < beach_threshold) {
		// Only on gentle slopes
		float slope_factor = smoothstep(beach_slope_min - 0.1, beach_slope_min, slope);
		// Fade out as we go higher
		float height_factor = 1.0 - smoothstep(0.0, beach_threshold, height_above_water);
		beach_blend = slope_factor * height_factor;
	}

	// Cliff blend based on slope (steep = more cliff texture)
	float cliff_blend = 1.0 - smoothstep(cliff_slope_full, cliff_slope_start, slope);

	// === ABSOLUTE HEIGHT-BASED TEXTURE BLENDING ===
	// Snow: y >= 600 (with transition zone)
	float height_snow_blend = smoothstep(snow_start_height, snow_full_height, vertex_height);

	// Stone zone: between grass_min_height and snow_start_height
	// Stone starts appearing stone_blend_range meters below snow
	float stone_start = snow_start_height - stone_blend_range;
	float stone_end = snow_start_height;
	float stone_blend = smoothstep(grass_min_height + 20.0, stone_start, vertex_height) * (1.0 - height_snow_blend);

	// Choose between stone (lower) and chalk (higher altitude cliffs)
	float cliff_height_factor = smoothstep(stone_start, snow_start_height, vertex_height);
	vec3 cliff_color = mix(stone, chalk, cliff_height_factor);

	// Reduce snow on steep slopes
	float slope_factor = smoothstep(slope_snow_threshold, slope_snow_threshold + 0.3, slope);
	float final_snow_blend = height_snow_blend * slope_factor;

	// Build terrain color: sand (beach) / grass -> stone zone -> snow, with cliff overlay
	vec3 base_color = grass;

	// Apply beach sand on flat areas near water
	base_color = mix(base_color, sand, beach_blend);

	// Blend to stone at mid/high elevations (between grass and snow)
	base_color = mix(base_color, stone * 0.9, stone_blend);

	// Blend to snow at high altitudes (>= 600m)
	base_color = mix(base_color, snow, final_snow_blend);

	// Apply cliff texture on steep slopes
	vec3 terrain_color = mix(base_color, cliff_color, cliff_blend);

	// Apply vertex color tinting for biome variation
	if (use_vertex_color_tint) {
		terrain_color = mix(terrain_color, terrain_color * COLOR.rgb * 2.0, vertex_color_strength);
	}

	// Underwater caustics and god rays effect
	float depth_below_water = water_height - vertex_height;
	if (depth_below_water > 0.0) {
		// Calculate depth factor for effects
		float depth_factor = clamp(depth_below_water / max_caustic_depth, 0.0, 1.0);

		// God ray strength - fades with depth but extends further than caustics
		float god_ray_depth_factor = clamp(depth_below_water / god_ray_fade_depth, 0.0, 1.0);
		float god_ray_strength = (1.0 - god_ray_depth_factor * god_ray_depth_factor) * god_ray_intensity;

		// Use sand texture for seafloor base, darken with depth
		float brightness = mix(0.4, 0.25, depth_factor);  // Brighter in shallows, darker deep
		vec3 base_underwater = sand * brightness;

		// Apply cool underwater tint
		base_underwater = mix(base_underwater, base_underwater * underwater_tint.rgb, 0.5 + depth_factor * 0.3);

		// Generate god ray spots
		vec2 caustic_uv = world_position.xz * caustic_scale;
		float ray_spots = god_ray_spots(caustic_uv, TIME * caustic_speed);

		// God ray contribution - bright spots of light on the dark seafloor (cool blue-white only)
		vec3 god_ray_color = vec3(0.85, 0.92, 1.0) * ray_spots * god_ray_strength * 1.5;

		// Combine base color with god rays
		vec3 underwater_final = base_underwater + god_ray_color;

		// Use EMISSION instead of ALBEDO to prevent sun from illuminating underwater terrain
		// Set ALBEDO to near-black so direct lighting has minimal effect
		ALBEDO = vec3(0.02, 0.03, 0.04);  // Very dark, minimal sun contribution
		EMISSION = underwater_final;  // Our shader controls all underwater lighting
		ROUGHNESS = 0.95;
		METALLIC = 0.0;
		SPECULAR = 0.0;  // No specular from sun
	} else {
		// Above water - normal terrain rendering
		ALBEDO = terrain_color;
		ROUGHNESS = mix(0.85, 0.95, max(final_snow_blend, cliff_blend * 0.3));
		METALLIC = 0.0;
	}
}
