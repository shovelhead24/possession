shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Water colors
uniform vec4 shallow_color : source_color = vec4(0.1, 0.6, 0.7, 0.8);
uniform vec4 deep_color : source_color = vec4(0.02, 0.15, 0.3, 0.95);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);

// Underwater view colors
uniform vec4 underwater_surface_color : source_color = vec4(0.05, 0.15, 0.25, 0.85);
uniform vec4 light_shaft_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);

// Wave parameters
uniform float wave_speed : hint_range(0.0, 2.0) = 0.3;
uniform float wave_scale : hint_range(0.001, 0.1) = 0.02;
uniform float wave_height : hint_range(0.0, 5.0) = 0.8;
uniform float small_wave_scale : hint_range(0.01, 0.5) = 0.08;
uniform float small_wave_height : hint_range(0.0, 1.0) = 0.15;

// Reflection/refraction
uniform float fresnel_power : hint_range(0.5, 10.0) = 4.0;
uniform float specular_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float specular_power : hint_range(1.0, 256.0) = 64.0;

// Depth fade
uniform float depth_fade_distance : hint_range(1.0, 100.0) = 20.0;
uniform float edge_fade_distance : hint_range(0.1, 10.0) = 2.0;

// Sun glitter
uniform float glitter_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float glitter_threshold : hint_range(0.0, 1.0) = 0.85;

// God rays (underwater view) - subtle on surface, main effect is on terrain
uniform float god_ray_intensity : hint_range(0.0, 3.0) = 0.8;
uniform float god_ray_scale : hint_range(0.01, 0.2) = 0.05;
uniform float god_ray_speed : hint_range(0.0, 2.0) = 0.15;
uniform float caustic_highlight_intensity : hint_range(0.0, 5.0) = 2.5;
uniform float caustic_highlight_threshold : hint_range(0.0, 1.0) = 0.5;

// Sun direction — updated by DayNightCycle each frame
uniform vec3 sun_direction = vec3(0.3, 0.9, 0.2);

// Noise for waves
varying vec3 world_pos;
varying float wave_offset;

// Simple hash function
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

// Fractal noise for waves
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

// Caustic pattern - matches terrain shader exactly
float caustic_pattern(vec2 uv, float time) {
	float c1 = fbm(uv + vec2(time * 0.7, time * 0.3));
	float c2 = fbm(uv * 1.3 - vec2(time * 0.5, time * 0.8));
	float caustic = abs(c1 - c2);
	caustic = pow(caustic, 0.6);
	return caustic;
}

// God rays - volumetric light shafts coming down from surface
float god_rays(vec2 uv, vec3 view_dir, vec3 normal, float time) {
	vec3 sun_dir = normalize(sun_direction);

	// When looking toward sun, rays should be more visible
	float sun_alignment = max(dot(view_dir, sun_dir), 0.0);

	// Create multiple overlapping ray patterns for volumetric look
	float rays = 0.0;

	// Layer 1: Wide rays (main shafts)
	vec2 ray_uv1 = uv + vec2(time * 0.05, time * 0.02);
	float angle1 = atan(ray_uv1.y, ray_uv1.x);
	float ray1 = sin(angle1 * 6.0) * 0.5 + 0.5;
	ray1 = smoothstep(0.3, 0.6, ray1);
	ray1 *= noise(ray_uv1 * 0.3 + time * 0.1) * 0.5 + 0.7;

	// Layer 2: Medium rays
	vec2 ray_uv2 = uv * 1.3 + vec2(-time * 0.03, time * 0.04);
	float angle2 = atan(ray_uv2.y + 1.0, ray_uv2.x + 0.5);
	float ray2 = sin(angle2 * 10.0 + 0.5) * 0.5 + 0.5;
	ray2 = smoothstep(0.35, 0.55, ray2);
	ray2 *= noise(ray_uv2 * 0.4) * 0.4 + 0.6;

	// Layer 3: Fine rays (detail)
	vec2 ray_uv3 = uv * 0.7 + vec2(time * 0.02, -time * 0.03);
	float angle3 = atan(ray_uv3.y - 0.5, ray_uv3.x + 1.0);
	float ray3 = sin(angle3 * 14.0 + 1.0) * 0.5 + 0.5;
	ray3 = smoothstep(0.4, 0.55, ray3);
	ray3 *= noise(ray_uv3 * 0.5 + 0.5) * 0.3 + 0.7;

	// Combine ray layers
	rays = ray1 * 0.5 + ray2 * 0.3 + ray3 * 0.2;

	// Add bright central glow toward sun direction
	float center_glow = pow(sun_alignment, 1.5) * 0.6;

	// Add noise-based variation for organic look
	float noise_break = fbm(uv * 0.15 + time * 0.05);
	rays *= 0.6 + noise_break * 0.6;

	// Enhance rays near sun direction
	rays = rays * (0.5 + sun_alignment * 0.8) + center_glow;

	return clamp(rays, 0.0, 1.0);
}

// God ray spots pattern - bright concentrated light areas (same as terrain)
float god_ray_spots(vec2 uv, float time) {
	// Use caustic-like pattern but extract the brightest peaks as spots
	float c1 = fbm(uv + vec2(time * 0.7, time * 0.3));
	float c2 = fbm(uv * 1.3 - vec2(time * 0.5, time * 0.8));
	float caustic = abs(c1 - c2);

	// Extract only the brightest peaks
	float spots = smoothstep(0.4, 0.7, caustic);

	// Second layer at different scale
	float c3 = fbm(uv * 0.7 + vec2(time * 0.5, -time * 0.4));
	float c4 = fbm(uv * 0.9 - vec2(time * 0.6, time * 0.3));
	float caustic2 = abs(c3 - c4);
	float spots2 = smoothstep(0.45, 0.75, caustic2);

	// Combine and boost
	float combined = max(spots, spots2 * 0.8);
	combined = pow(combined, 0.7) * 1.5;

	return clamp(combined, 0.0, 1.0);
}

// Bright specular highlights on caustics - much more frequent
float caustic_specular(vec2 uv, float time) {
	// Use same caustic pattern as terrain
	float caustic = caustic_pattern(uv, time);

	// Primary highlights - very frequent (low threshold)
	float primary = smoothstep(0.30, 0.50, caustic);

	// Secondary brighter highlights - medium frequency
	float bright = smoothstep(0.50, 0.70, caustic) * 1.5;

	// Tertiary super-bright highlights - sparser
	float super_bright = smoothstep(0.70, 0.85, caustic) * 2.5;

	// Add sparkle variation
	float sparkle = noise(uv * 8.0 + time * 3.0);
	float sparkle2 = noise(uv * 12.0 - time * 2.0);
	float sparkle3 = noise(uv * 6.0 + time * 1.5);

	// Combine for varied highlight sizes - more layers, more density
	float highlights = primary * (0.5 + sparkle * 0.5) + bright * (0.6 + sparkle2 * 0.4) + super_bright * (0.7 + sparkle3 * 0.3);

	return highlights;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Large rolling waves
	float time = TIME * wave_speed;
	vec2 wave_uv = world_pos.xz * wave_scale;

	float wave1 = sin(wave_uv.x * 1.0 + time * 0.7) * cos(wave_uv.y * 0.8 + time * 0.5);
	float wave2 = sin(wave_uv.x * 0.6 - time * 0.4 + wave_uv.y * 0.7) * 0.7;
	float wave3 = fbm(wave_uv * 2.0 + time * 0.3) * 0.5;

	float large_wave = (wave1 + wave2 + wave3) * wave_height;

	// Small choppy waves
	vec2 small_uv = world_pos.xz * small_wave_scale;
	float small_wave = fbm(small_uv + time * 2.0) * small_wave_height;

	wave_offset = large_wave + small_wave;
	VERTEX.y += wave_offset;

	// Calculate normals from wave derivatives
	float delta = 0.5;
	float h_dx = sin((wave_uv.x + delta) * 1.0 + time * 0.7) * wave_height - large_wave;
	float h_dz = sin((wave_uv.y + delta) * 0.8 + time * 0.5) * wave_height - large_wave;

	vec3 wave_normal = normalize(vec3(-h_dx * 0.5, 1.0, -h_dz * 0.5));
	NORMAL = wave_normal;
}

void fragment() {
	// Detect if viewing from underwater (back face = looking up from below)
	bool is_underwater_view = !FRONT_FACING;

	// Get view direction for fresnel
	vec3 view_dir = normalize(VIEW);
	vec3 normal = NORMAL;

	// Flip normal for underwater view
	if (is_underwater_view) {
		normal = -normal;
	}

	float time = TIME * wave_speed;

	if (is_underwater_view) {
		// === UNDERWATER VIEW (looking up at surface from below) ===

		// God rays - radial light shafts from sun direction (multiple scales for depth)
		vec2 ray_uv = world_pos.xz * god_ray_scale;
		float rays = god_rays(ray_uv, view_dir, normal, TIME * god_ray_speed);

		// Second layer of god rays at different scale for more coverage
		float rays2 = god_rays(ray_uv * 0.6, view_dir, normal, TIME * god_ray_speed * 0.7);
		rays = max(rays, rays2 * 0.8);

		// Caustic pattern on the underside (matches seafloor caustics exactly)
		vec2 caustic_uv = world_pos.xz * 0.08;  // Same scale as terrain caustics
		float caustic = caustic_pattern(caustic_uv, TIME * 0.4);

		// Bright specular highlights - more of them
		float spec_highlights = caustic_specular(caustic_uv, TIME * 0.4);

		// Add a second caustic layer at slightly different scale
		float spec_highlights2 = caustic_specular(caustic_uv * 1.3 + vec2(5.0, 3.0), TIME * 0.35);
		spec_highlights = max(spec_highlights, spec_highlights2 * 0.7);

		// Fresnel for underwater - more opaque at edges
		float fresnel = pow(1.0 - max(dot(normal, view_dir), 0.0), 2.0);

		// Dark base underwater surface color (more opaque)
		vec3 base_color = underwater_surface_color.rgb;

		// God rays contribution - subtle hint on surface (main rays are volumetric on terrain)
		vec3 ray_contribution = light_shaft_color.rgb * rays * god_ray_intensity;

		// Caustic pattern (softer, background)
		vec3 caustic_contribution = light_shaft_color.rgb * caustic * 0.3;

		// Bright specular highlights (frequent, intense) - pure cool white
		vec3 highlight_contribution = vec3(0.9, 0.95, 1.0) * spec_highlights * caustic_highlight_intensity;

		// Brighter center where sun would be
		float center_bright = pow(max(dot(normal, view_dir), 0.0), 3.0);
		vec3 sun_glow = vec3(0.5, 0.6, 0.7) * center_bright;

		// Combine all lighting
		vec3 final_color = base_color;
		final_color += ray_contribution;
		final_color += caustic_contribution;
		final_color += highlight_contribution;
		final_color += sun_glow;

		ALBEDO = final_color;
		METALLIC = 0.0;
		ROUGHNESS = 0.12;
		SPECULAR = 0.5;

		// More opaque underwater surface
		float alpha = mix(0.70, 0.92, fresnel);
		// Rays make it slightly more transparent where light comes through
		alpha -= rays * 0.1;
		ALPHA = clamp(alpha, 0.55, 0.92);

		// Subtle emission for surface highlights
		EMISSION = ray_contribution * 0.5 + highlight_contribution * 1.0;

	} else {
		// === ABOVE WATER VIEW (normal surface rendering) ===

		// Add small-scale normal perturbation for micro-waves
		vec2 micro_uv = world_pos.xz * 0.5;
		float micro_noise = fbm(micro_uv + time * 1.5);
		normal = normalize(normal + vec3(micro_noise * 0.1 - 0.05, 0.0, micro_noise * 0.1 - 0.05));

		// Fresnel effect - more reflection at grazing angles
		float fresnel = pow(1.0 - max(dot(normal, view_dir), 0.0), fresnel_power);
		fresnel = clamp(fresnel, 0.1, 0.95);

		// Water color blend (no depth buffer in GL Compat — use fresnel as depth proxy)
		float depth_approx = fresnel * 0.7;
		vec3 water_color = mix(shallow_color.rgb, deep_color.rgb, depth_approx);

		// Sky reflection approximation
		vec3 sky_color = vec3(0.6, 0.75, 0.9);
		vec3 reflected = mix(water_color, sky_color, fresnel * 0.6);

		// Sun glitter - sparkling highlights
		vec2 glitter_uv = world_pos.xz * 0.3 + time * 0.5;
		float glitter_noise = fbm(glitter_uv * 5.0);
		float glitter = smoothstep(glitter_threshold, 1.0, glitter_noise);

		// Specular highlight (sun reflection)
		vec3 sun_dir = normalize(sun_direction);
		vec3 half_vec = normalize(sun_dir + view_dir);
		float spec = pow(max(dot(normal, half_vec), 0.0), specular_power);
		spec *= specular_intensity;

		// Combine sun glitter with specular
		float total_glitter = (glitter * glitter_intensity + spec) * (1.0 - fresnel * 0.3);

		// Final color
		ALBEDO = reflected + vec3(total_glitter);

		// Metallic and roughness for PBR
		METALLIC = 0.0;
		ROUGHNESS = 0.05 + (1.0 - fresnel) * 0.1;
		SPECULAR = 0.8;

		// Transparency
		float alpha = mix(shallow_color.a, deep_color.a, fresnel * 0.5);
		alpha = clamp(alpha + total_glitter * 0.3, 0.0, 1.0);
		ALPHA = alpha;

		// Rim glow effect
		float rim = 1.0 - max(dot(normal, view_dir), 0.0);
		rim = pow(rim, 3.0) * 0.3;
		EMISSION = vec3(rim * 0.5, rim * 0.6, rim * 0.7) + vec3(total_glitter * 0.5);
	}
}
