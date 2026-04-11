shader_type sky;

uniform vec3 day_sky_top : source_color = vec3(0.3, 0.5, 0.9);
uniform vec3 day_sky_horizon : source_color = vec3(0.6, 0.7, 0.9);
uniform vec3 night_sky_top : source_color = vec3(0.005, 0.005, 0.015);
uniform vec3 night_sky_horizon : source_color = vec3(0.01, 0.01, 0.03);
uniform vec3 sunset_color : source_color = vec3(1.0, 0.4, 0.2);

uniform float sun_elevation : hint_range(-90.0, 90.0) = 45.0;
uniform float sun_azimuth : hint_range(0.0, 360.0) = 180.0;
uniform float sun_size : hint_range(0.0, 0.1) = 0.02;
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);

uniform float star_density : hint_range(0.0, 1.0) = 0.5;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;

// Gas giant planet settings
uniform float planet_elevation : hint_range(-90.0, 90.0) = -15.0;  // Low, only top visible
uniform float planet_azimuth : hint_range(0.0, 360.0) = 180.0;    // 90 degrees west
uniform float planet_size : hint_range(0.0, 1.5) = 0.5;           // Original size
uniform float planet_brightness : hint_range(0.0, 2.0) = 0.8;
uniform sampler2D planet_texture : hint_default_white;

// Halo ring horizon settings
uniform float ring_visual_width : hint_range(0.001, 0.1) = 0.006;
uniform float ring_fade_distance : hint_range(0.5, 5.0) = 2.5;
uniform float ring_brightness : hint_range(0.0, 2.0) = 0.7;
uniform vec3 ring_near_color : source_color = vec3(0.30, 0.45, 0.25);
uniform vec3 ring_far_color : source_color = vec3(0.50, 0.58, 0.68);
uniform float ring_azimuth_offset : hint_range(0.0, 360.0) = 0.0; // Rotate ring orientation

// Cloud settings
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.65;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.7;
uniform float cloud_speed : hint_range(0.0, 0.02) = 0.003;

// Hash function for procedural star generation
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Generate background procedural stars (dim, twinkling)
float procedural_stars(vec3 dir) {
	vec2 uv = vec2(atan(dir.x, dir.z), asin(dir.y));
	uv *= 80.0;

	vec2 grid = floor(uv);
	vec2 f = fract(uv);

	float star = 0.0;

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 cell = grid + neighbor;

			vec2 star_pos = vec2(hash(cell), hash(cell + vec2(1.0, 0.0)));
			float d = length(f - neighbor - star_pos);

			float brightness = hash(cell + vec2(0.0, 1.0));
			if (brightness > 0.85) {
				float twinkle = sin(TIME * (2.0 + hash(cell) * 3.0)) * 0.3 + 0.7;
				star += smoothstep(0.04, 0.0, d) * brightness * twinkle * 0.5;
			}
		}
	}

	return star * star_brightness;
}

// Convert RA/Dec to direction vector (simplified for game use)
// RA: 0-24 hours, Dec: -90 to +90 degrees
vec3 celestial_to_dir(float ra_hours, float dec_deg) {
	float ra = ra_hours * (3.14159265 / 12.0); // Convert hours to radians
	float dec = radians(dec_deg);

	return vec3(
		cos(dec) * sin(ra),
		sin(dec),
		cos(dec) * cos(ra)
	);
}

// Draw a single star at a position with given brightness and color
float draw_star(vec3 dir, vec3 star_dir, float magnitude, float twinkle_speed) {
	float d = distance(dir, star_dir);

	// Size based on magnitude (brighter = larger) - reduced 10x
	float size = 0.0008 * (1.0 + (3.0 - magnitude) * 0.3);

	// Core and glow - reduced brightness by ~2x
	float core = smoothstep(size, size * 0.2, d) * 0.6;
	float glow = smoothstep(size * 5.0, size * 0.5, d) * 0.15;

	// Subtle twinkle for bright stars
	float twinkle = sin(TIME * twinkle_speed) * 0.1 + 0.9;

	return (core + glow) * twinkle;
}

// Real constellation stars visible from Western Europe (~50°N latitude)
// Returns star brightness and color tint
vec3 constellation_stars(vec3 dir) {
	vec3 total = vec3(0.0);

	// === ORION ===
	// Betelgeuse (Alpha Orionis) - red supergiant, mag 0.5
	vec3 betelgeuse_dir = celestial_to_dir(5.92, 7.41);
	total += vec3(1.0, 0.6, 0.4) * draw_star(dir, betelgeuse_dir, 0.5, 2.1);

	// Rigel (Beta Orionis) - blue supergiant, mag 0.13
	vec3 rigel_dir = celestial_to_dir(5.24, -8.2);
	total += vec3(0.7, 0.8, 1.0) * draw_star(dir, rigel_dir, 0.1, 1.8);

	// Bellatrix (Gamma Orionis) - mag 1.64
	vec3 bellatrix_dir = celestial_to_dir(5.42, 6.35);
	total += vec3(0.8, 0.85, 1.0) * draw_star(dir, bellatrix_dir, 1.6, 2.3);

	// Orion's Belt: Alnitak, Alnilam, Mintaka
	vec3 alnitak_dir = celestial_to_dir(5.68, -1.94);
	total += vec3(0.8, 0.9, 1.0) * draw_star(dir, alnitak_dir, 1.7, 2.0);

	vec3 alnilam_dir = celestial_to_dir(5.60, -1.20);
	total += vec3(0.8, 0.9, 1.0) * draw_star(dir, alnilam_dir, 1.7, 2.2);

	vec3 mintaka_dir = celestial_to_dir(5.53, -0.30);
	total += vec3(0.8, 0.9, 1.0) * draw_star(dir, mintaka_dir, 2.2, 1.9);

	// Saiph (Kappa Orionis) - mag 2.06
	vec3 saiph_dir = celestial_to_dir(5.80, -9.67);
	total += vec3(0.8, 0.85, 1.0) * draw_star(dir, saiph_dir, 2.0, 2.4);

	// === URSA MAJOR (Big Dipper) ===
	// Dubhe (Alpha UMa) - mag 1.79
	vec3 dubhe_dir = celestial_to_dir(11.06, 61.75);
	total += vec3(1.0, 0.9, 0.7) * draw_star(dir, dubhe_dir, 1.8, 1.7);

	// Merak (Beta UMa) - mag 2.37
	vec3 merak_dir = celestial_to_dir(11.03, 56.38);
	total += vec3(0.9, 0.95, 1.0) * draw_star(dir, merak_dir, 2.4, 2.1);

	// Phecda (Gamma UMa) - mag 2.44
	vec3 phecda_dir = celestial_to_dir(11.90, 53.69);
	total += vec3(0.9, 0.95, 1.0) * draw_star(dir, phecda_dir, 2.4, 1.9);

	// Megrez (Delta UMa) - mag 3.31
	vec3 megrez_dir = celestial_to_dir(12.26, 57.03);
	total += vec3(0.95, 0.95, 1.0) * draw_star(dir, megrez_dir, 3.3, 2.3);

	// Alioth (Epsilon UMa) - mag 1.77
	vec3 alioth_dir = celestial_to_dir(12.90, 55.96);
	total += vec3(0.95, 0.95, 1.0) * draw_star(dir, alioth_dir, 1.8, 2.0);

	// Mizar (Zeta UMa) - mag 2.27
	vec3 mizar_dir = celestial_to_dir(13.40, 54.93);
	total += vec3(0.95, 0.95, 1.0) * draw_star(dir, mizar_dir, 2.3, 1.8);

	// Alkaid (Eta UMa) - mag 1.86
	vec3 alkaid_dir = celestial_to_dir(13.79, 49.31);
	total += vec3(0.8, 0.85, 1.0) * draw_star(dir, alkaid_dir, 1.9, 2.2);

	// === URSA MINOR (Little Dipper) ===
	// Polaris (Alpha UMi) - North Star, mag 1.98
	vec3 polaris_dir = celestial_to_dir(2.53, 89.26);
	total += vec3(1.0, 1.0, 0.9) * draw_star(dir, polaris_dir, 2.0, 0.5); // Slow twinkle

	// Kochab (Beta UMi) - mag 2.08
	vec3 kochab_dir = celestial_to_dir(14.85, 74.16);
	total += vec3(1.0, 0.85, 0.7) * draw_star(dir, kochab_dir, 2.1, 1.9);

	// === CASSIOPEIA ===
	// Schedar (Alpha Cas) - mag 2.24
	vec3 schedar_dir = celestial_to_dir(0.68, 56.54);
	total += vec3(1.0, 0.85, 0.7) * draw_star(dir, schedar_dir, 2.2, 2.1);

	// Caph (Beta Cas) - mag 2.28
	vec3 caph_dir = celestial_to_dir(0.15, 59.15);
	total += vec3(0.95, 0.95, 1.0) * draw_star(dir, caph_dir, 2.3, 1.8);

	// Gamma Cassiopeiae - mag 2.47
	vec3 gamma_cas_dir = celestial_to_dir(0.95, 60.72);
	total += vec3(0.8, 0.85, 1.0) * draw_star(dir, gamma_cas_dir, 2.5, 2.4);

	// Ruchbah (Delta Cas) - mag 2.68
	vec3 ruchbah_dir = celestial_to_dir(1.43, 60.24);
	total += vec3(0.95, 0.95, 1.0) * draw_star(dir, ruchbah_dir, 2.7, 2.0);

	// Segin (Epsilon Cas) - mag 3.37
	vec3 segin_dir = celestial_to_dir(1.91, 63.67);
	total += vec3(0.85, 0.9, 1.0) * draw_star(dir, segin_dir, 3.4, 2.2);

	// === CYGNUS (Northern Cross) ===
	// Deneb (Alpha Cyg) - mag 1.25
	vec3 deneb_dir = celestial_to_dir(20.69, 45.28);
	total += vec3(0.95, 0.95, 1.0) * draw_star(dir, deneb_dir, 1.3, 1.6);

	// Sadr (Gamma Cyg) - mag 2.23
	vec3 sadr_dir = celestial_to_dir(20.37, 40.26);
	total += vec3(1.0, 0.95, 0.8) * draw_star(dir, sadr_dir, 2.2, 2.1);

	// Albireo (Beta Cyg) - mag 3.18 (famous double star)
	vec3 albireo_dir = celestial_to_dir(19.51, 27.96);
	total += vec3(1.0, 0.8, 0.5) * draw_star(dir, albireo_dir, 3.2, 1.9);

	// === LYRA ===
	// Vega (Alpha Lyrae) - mag 0.03, one of the brightest
	vec3 vega_dir = celestial_to_dir(18.62, 38.78);
	total += vec3(0.9, 0.95, 1.0) * draw_star(dir, vega_dir, 0.0, 1.5);

	// === AQUILA ===
	// Altair (Alpha Aquilae) - mag 0.77
	vec3 altair_dir = celestial_to_dir(19.85, 8.87);
	total += vec3(0.95, 0.95, 1.0) * draw_star(dir, altair_dir, 0.8, 1.7);

	// === TAURUS ===
	// Aldebaran (Alpha Tauri) - red giant, mag 0.85
	vec3 aldebaran_dir = celestial_to_dir(4.60, 16.51);
	total += vec3(1.0, 0.7, 0.4) * draw_star(dir, aldebaran_dir, 0.9, 2.0);

	// === GEMINI ===
	// Castor (Alpha Gem) - mag 1.58
	vec3 castor_dir = celestial_to_dir(7.58, 31.89);
	total += vec3(0.95, 0.95, 1.0) * draw_star(dir, castor_dir, 1.6, 2.1);

	// Pollux (Beta Gem) - mag 1.14
	vec3 pollux_dir = celestial_to_dir(7.76, 28.03);
	total += vec3(1.0, 0.9, 0.7) * draw_star(dir, pollux_dir, 1.1, 1.8);

	// === LEO ===
	// Regulus (Alpha Leo) - mag 1.35
	vec3 regulus_dir = celestial_to_dir(10.14, 11.97);
	total += vec3(0.85, 0.9, 1.0) * draw_star(dir, regulus_dir, 1.4, 1.9);

	// === CANIS MAJOR ===
	// Sirius (Alpha CMa) - brightest star in night sky, mag -1.46
	vec3 sirius_dir = celestial_to_dir(6.75, -16.72);
	total += vec3(0.9, 0.95, 1.0) * draw_star(dir, sirius_dir, -1.5, 1.4);

	// === SCORPIUS (partially visible from Europe) ===
	// Antares (Alpha Sco) - red supergiant, mag 1.09
	vec3 antares_dir = celestial_to_dir(16.49, -26.43);
	total += vec3(1.0, 0.5, 0.3) * draw_star(dir, antares_dir, 1.1, 2.3);

	// === BOOTES ===
	// Arcturus (Alpha Boo) - mag -0.05, orange giant
	vec3 arcturus_dir = celestial_to_dir(14.26, 19.18);
	total += vec3(1.0, 0.8, 0.5) * draw_star(dir, arcturus_dir, 0.0, 1.6);

	// === VIRGO ===
	// Spica (Alpha Vir) - mag 0.97
	vec3 spica_dir = celestial_to_dir(13.42, -11.16);
	total += vec3(0.85, 0.9, 1.0) * draw_star(dir, spica_dir, 1.0, 1.8);

	return total;
}

// Draw gas giant planet with texture
vec3 draw_gas_giant(vec3 dir) {
	// Calculate planet direction
	float planet_elev_rad = radians(planet_elevation);
	float planet_azim_rad = radians(planet_azimuth);
	vec3 planet_dir = vec3(
		cos(planet_elev_rad) * sin(planet_azim_rad),
		sin(planet_elev_rad),
		cos(planet_elev_rad) * cos(planet_azim_rad)
	);

	float dist = distance(dir, planet_dir);

	// Outside planet disc
	if (dist > planet_size) {
		return vec3(0.0);
	}

	// Calculate local coordinates on planet face
	vec3 local_dir = dir - planet_dir;

	// Create coordinate system on planet face
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, planet_dir));
	vec3 local_up = normalize(cross(planet_dir, right));

	float local_x = dot(local_dir, right) / planet_size;
	float local_y = dot(local_dir, local_up) / planet_size;

	// Check if inside planet disc
	float r = sqrt(local_x * local_x + local_y * local_y);
	if (r > 1.0) {
		return vec3(0.0);
	}

	// Convert to UV coordinates for texture sampling
	// The texture is a front-facing view, so we map directly
	vec2 uv = vec2(local_x, -local_y) * 0.5 + 0.5;

	// Sample the planet texture
	vec3 planet_col = texture(planet_texture, uv).rgb;

	// Soft edge antialiasing
	float edge = smoothstep(1.0, 0.98, r);

	return planet_col * edge * planet_brightness;
}

// Value noise for biome generation
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep interpolation
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM (Fractal Brownian Motion) for natural terrain patterns
float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	float total_amp = 0.0;

	for (int i = 0; i < octaves; i++) {
		value += amplitude * vnoise(p * frequency);
		total_amp += amplitude;
		amplitude *= 0.5;
		frequency *= 2.0;
	}
	return value / total_amp;
}

// Domain warping for organic coastline shapes
vec2 warp_domain(vec2 p, float strength) {
	float warp_x = fbm(p + vec2(0.0, 0.0), 4);
	float warp_y = fbm(p + vec2(5.2, 1.3), 4);
	return p + vec2(warp_x, warp_y) * strength;
}

// High detail FBM for coastlines
float coastline_fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;

	// 8 octaves for detailed coastlines
	for (int i = 0; i < 8; i++) {
		value += amplitude * vnoise(p * frequency);
		amplitude *= 0.5;
		frequency *= 2.1; // Slightly non-integer for less repetition
	}
	return value;
}

// Simple procedural clouds with perspective stretching
vec4 draw_clouds(vec3 dir, float sun_elev, float time) {
	// Only above horizon
	if (dir.y < 0.0) return vec4(0.0);

	// Elevation and perspective
	float elev = asin(clamp(dir.y, 0.0, 1.0));
	float sin_e = max(sin(elev), 0.05);
	float stretch = 1.0 / sin_e;

	// Use 3D direction for seamless noise (no azimuth seam)
	// Project onto xz plane and normalize for consistent sampling
	vec2 horiz = normalize(dir.xz + vec2(0.001));

	// Base UV from horizontal direction + elevation
	// Add time for animation (clouds drift)
	vec2 uv1 = horiz * 4.0 + vec2(time * cloud_speed * 5.0, 0.0);
	vec2 uv2 = horiz * 8.0 + vec2(0.0, time * cloud_speed * 3.0);

	// Add elevation-based offset to create horizontal layering
	uv1.y += elev * 6.0;
	uv2.y += elev * 10.0;

	// Domain warping to break up uniformity
	vec2 warp = vec2(fbm(uv1 * 0.5, 3), fbm(uv1 * 0.5 + vec2(50.0, 0.0), 3));
	uv1 += warp * 1.5;
	uv2 += warp * 0.8;

	// Multi-octave noise for cloud shape
	float n = fbm(uv1, 5) * 0.6;
	n += fbm(uv2 + vec2(100.0, 0.0), 4) * 0.4;

	// Coverage threshold
	float thresh = 1.0 - cloud_coverage;
	float shape = smoothstep(thresh, thresh + 0.25, n);

	// Fade near horizon and high up
	float horizon_fade = smoothstep(0.0, 0.08, elev);
	float top_fade = smoothstep(1.2, 0.3, elev);
	shape *= horizon_fade * top_fade;

	// Fade out near ring
	float ring_rad = radians(ring_azimuth_offset);
	vec3 rot_dir = vec3(
		dir.x * cos(ring_rad) - dir.z * sin(ring_rad),
		dir.y,
		dir.x * sin(ring_rad) + dir.z * cos(ring_rad)
	);
	float ring_dist = abs(rot_dir.z);
	float ring_w = ring_visual_width / sin_e;
	float ring_fade = smoothstep(ring_w * 0.5, ring_w * 2.0, ring_dist);
	shape *= ring_fade;

	// Cloud color based on time of day
	float day = smoothstep(-10.0, 20.0, sun_elev);
	float sunset = smoothstep(-10.0, 5.0, sun_elev) * smoothstep(25.0, 5.0, sun_elev);
	vec3 col = mix(vec3(0.15, 0.17, 0.22), vec3(0.95, 0.95, 0.93), day);
	col = mix(col, vec3(1.0, 0.65, 0.45), sunset * 0.6);

	// Final alpha
	float alpha = shape * cloud_density;
	alpha = clamp(alpha, 0.0, 0.85);

	return vec4(col, alpha);
}

// Draw the Halo ring horizon - the iconic band across the sky
// The ring appears as a great circle: from horizon, through zenith, to opposite horizon
vec4 draw_ring_horizon_rgba(vec3 dir) {
	// Apply azimuth offset to rotate the ring orientation
	float offset_rad = radians(ring_azimuth_offset);
	vec3 rotated_dir = vec3(
		dir.x * cos(offset_rad) - dir.z * sin(offset_rad),
		dir.y,
		dir.x * sin(offset_rad) + dir.z * cos(offset_rad)
	);

	// The ring extends along the Z axis (after rotation)
	float dist_to_ring = abs(rotated_dir.z);

	// Elevation for perspective calculation
	float elevation = asin(clamp(rotated_dir.y, -1.0, 1.0));
	float elev_deg = degrees(elevation);

	// === PHYSICS-BASED PERSPECTIVE ===
	// On a ring world, distance to opposite wall = 2R * sin(elevation)
	// Angular width of ring = W / distance = W / (2R * sin(elevation))
	// Therefore width_mult = 1 / sin(elevation)
	// Ring specs: R = 5000 km, W = 10 km, diameter = 10000 km

	// Clamp elevation to avoid division by zero at horizon
	// At 1.1 degrees, sin = 0.02, giving 50x multiplier (our max)
	// This lets the ring extend very close to the horizon
	float min_sin = 0.02;  // Caps at 50x multiplier
	float sin_elev = max(sin(elevation), min_sin);

	// Physics-accurate perspective: 1/sin(elevation)
	float width_mult = 1.0 / sin_elev;

	// Apply perspective to ring width
	float effective_width = ring_visual_width * width_mult;

	// Total ring width including walls
	float wall_thickness = effective_width * 0.04;  // Walls are 4% of ring width each

	// Walls overlap slightly with terrain edge to avoid gaps
	float inner_edge = effective_width * 0.92;  // Start wall inside terrain edge
	float outer_edge = effective_width + wall_thickness;
	bool in_wall = dist_to_ring > inner_edge && dist_to_ring < outer_edge;

	// Ring band intensity (terrain area only)
	float ring_intensity = smoothstep(effective_width, effective_width * 0.05, dist_to_ring);

	// Terrain fades toward horizon (but walls will extend further)
	float horizon_fade = smoothstep(-0.02, 0.20, elevation);

	// Distance factor - near zenith = close, near horizon = far
	float distance_factor = 1.0 - elevation / 1.5708;
	distance_factor = clamp(distance_factor, 0.0, 1.0);

	// UV coordinates on the ring surface
	// ring_u = position along the ring circumference
	// ring_v = position across the ring width (signed to break symmetry)
	float ring_u = atan(rotated_dir.y, rotated_dir.x) * 15.0; // Scale for continent frequency
	float ring_v = (rotated_dir.z / effective_width) * 3.0;  // Signed - no symmetry

	// Apply domain warping for organic continent shapes
	vec2 base_uv = vec2(ring_u, ring_v);
	vec2 warped_uv = warp_domain(base_uv * 0.5, 2.0);

	// Generate continental mass using high-detail FBM
	float continental = coastline_fbm(warped_uv * 1.5);

	// Add medium-scale terrain variation
	float terrain_mid = fbm(warped_uv * 4.0 + vec2(100.0, 0.0), 5);

	// Fine detail for coastline complexity
	float coastline_detail = coastline_fbm(base_uv * 8.0 + warped_uv * 2.0);

	// Combine for land/water threshold with detailed coastlines
	float land_mass = continental * 0.6 + terrain_mid * 0.3 + coastline_detail * 0.1;

	// Define biome colors
	vec3 deep_ocean = vec3(0.08, 0.20, 0.42);       // Deep ocean blue
	vec3 ocean = vec3(0.12, 0.32, 0.52);            // Ocean blue
	vec3 shallow = vec3(0.18, 0.45, 0.55);          // Shallow/coastal water
	vec3 beach = vec3(0.72, 0.68, 0.55);            // Sandy beach
	vec3 lowland = vec3(0.28, 0.52, 0.25);          // Coastal lowland green
	vec3 forest = vec3(0.15, 0.38, 0.18);           // Dense forest
	vec3 highland = vec3(0.22, 0.32, 0.20);         // Highland/darker forest
	vec3 mountain = vec3(0.45, 0.42, 0.38);         // Mountain rock
	vec3 snow = vec3(0.90, 0.92, 0.95);             // Snow caps

	// Additional noise for within-biome variation
	float biome_var = fbm(base_uv * 12.0, 4);
	float fine_var = vnoise(base_uv * 40.0);

	// Create detailed biome distribution
	vec3 ring_color;
	float water_threshold = 0.42; // Adjust for land/water ratio

	if (land_mass < water_threshold - 0.08) {
		// Deep ocean
		float depth = smoothstep(water_threshold - 0.25, water_threshold - 0.08, land_mass);
		ring_color = mix(deep_ocean, ocean, depth);
		// Add subtle wave/current texture
		ring_color += vec3(0.02) * vnoise(base_uv * 60.0);
	} else if (land_mass < water_threshold) {
		// Shallow water / coastal
		float t = (land_mass - (water_threshold - 0.08)) / 0.08;
		ring_color = mix(ocean, shallow, t);
		// Turquoise variation
		ring_color.g += 0.05 * fine_var;
	} else if (land_mass < water_threshold + 0.03) {
		// Beach / coastline
		float t = (land_mass - water_threshold) / 0.03;
		ring_color = mix(shallow, beach, t);
	} else if (land_mass < water_threshold + 0.08) {
		// Coastal lowlands
		float t = (land_mass - (water_threshold + 0.03)) / 0.05;
		ring_color = mix(beach, lowland, t);
		ring_color = mix(ring_color, forest, biome_var * 0.3);
	} else if (land_mass < water_threshold + 0.20) {
		// Forest / plains mix
		float t = (land_mass - (water_threshold + 0.08)) / 0.12;
		ring_color = mix(lowland, forest, t * 0.5 + biome_var * 0.5);
		// Add clearings
		ring_color = mix(ring_color, lowland, step(0.7, fine_var) * 0.4);
	} else if (land_mass < water_threshold + 0.32) {
		// Highland transition
		float t = (land_mass - (water_threshold + 0.20)) / 0.12;
		ring_color = mix(forest, highland, t);
		ring_color = mix(ring_color, mountain, biome_var * 0.3);
	} else if (land_mass < water_threshold + 0.42) {
		// Mountains
		float t = (land_mass - (water_threshold + 0.32)) / 0.10;
		ring_color = mix(highland, mountain, t);
		// Rocky texture
		ring_color *= 0.9 + fine_var * 0.2;
	} else {
		// Snow caps
		float t = (land_mass - (water_threshold + 0.42)) / 0.15;
		t = clamp(t, 0.0, 1.0);
		ring_color = mix(mountain, snow, t);
		// Patchy snow
		ring_color = mix(ring_color, mountain, (1.0 - fine_var) * 0.3 * (1.0 - t));
	}

	// Add micro-detail texture
	float micro = vnoise(base_uv * 100.0);
	ring_color *= 0.92 + micro * 0.12;

	// Atmospheric haze - increases with distance
	vec3 haze_color = vec3(0.55, 0.62, 0.75);
	float atmosphere = exp(-distance_factor * ring_fade_distance * 0.35);
	ring_color = mix(haze_color, ring_color, atmosphere);

	// === ILLUMINATION / SHADOW based on sun position ===
	// Calculate sun direction
	float sun_elev_rad = radians(sun_elevation);
	float sun_azim_rad = radians(sun_azimuth);
	vec3 sun_dir = vec3(
		cos(sun_elev_rad) * sin(sun_azim_rad),
		sin(sun_elev_rad),
		cos(sun_elev_rad) * cos(sun_azim_rad)
	);

	// Position angle on the ring (where we're looking along the ring arc)
	float ring_position_angle = atan(rotated_dir.y, rotated_dir.x);

	// Sun's angle relative to ring orientation
	float sun_ring_angle = atan(sun_dir.x, sun_dir.z) - offset_rad;

	// Illumination: parts of ring facing sun are lit, opposite side in shadow
	float angle_diff = cos(ring_position_angle - sun_ring_angle);

	// Sun elevation affects how much the ring is lit
	float sun_up = smoothstep(-10.0, 20.0, sun_elevation);

	// Illumination ranges from 0.6 (shadow) to 1.2 (bright lit side)
	// This is gentler than before - shadow isn't too dark
	float illumination = mix(0.6, 1.2, (angle_diff * 0.5 + 0.5));

	// At night, flatten the illumination (no harsh shadows, just ambient)
	illumination = mix(0.85, illumination, sun_up);

	// Apply illumination
	ring_color *= illumination;

	// Add emissive glow so ring is always visible
	// Brighter at night (gas giant illumination), subtle during day
	float night_factor = 1.0 - sun_up;
	vec3 night_glow = vec3(0.12, 0.14, 0.20) * night_factor * 0.5;
	vec3 day_sheen = vec3(0.05, 0.05, 0.04) * sun_up;
	ring_color += night_glow + day_sheen;

	// Subtle edge shading for terrain
	float edge_shade = smoothstep(effective_width * 0.05, effective_width * 0.4, dist_to_ring);
	ring_color *= 0.85 + (1.0 - edge_shade) * 0.15;

	// Calculate opacity for terrain - FULLY SOLID in center, sharp edges
	float inner_region = smoothstep(inner_edge, inner_edge * 0.7, dist_to_ring);
	float opacity = inner_region * horizon_fade;
	opacity = clamp(opacity * 1.5, 0.0, 1.0); // Solid with sharp falloff

	// === CONTAINING WALLS ===
	// Draw solid gray walls on both edges of the ring
	if (in_wall) {
		// Wall colors - metallic gray with some variation
		vec3 wall_dark = vec3(0.22, 0.24, 0.28);      // Shadow side
		vec3 wall_light = vec3(0.50, 0.52, 0.55);     // Lit side

		// Distance into wall from inner edge (0 = inner edge, 1 = outer edge)
		float wall_depth = (dist_to_ring - inner_edge) / (outer_edge - inner_edge);

		// Determine which wall we're on (positive or negative Z side)
		float wall_side = sign(rotated_dir.z);  // +1 or -1

		// Sun direction relative to ring - which side is the sun on?
		float sun_side = sign(sun_dir.z * cos(offset_rad) + sun_dir.x * sin(offset_rad));

		// Wall facing sun is lit, opposite wall is in shadow
		float facing_sun = (wall_side == sun_side) ? 1.0 : 0.0;

		// Blend based on sun elevation (at night, both walls similar)
		float wall_illumination = mix(0.5, mix(0.3, 1.0, facing_sun), sun_up);

		// Wall shading - inner part is slightly lighter
		float wall_shade = 1.0 - wall_depth * 0.3;

		// Calculate wall color
		vec3 wall_color = mix(wall_light, wall_dark, wall_depth * 0.5);
		wall_color *= wall_shade * wall_illumination;

		// Add subtle panel lines / texture
		float panel_lines = vnoise(base_uv * vec2(50.0, 200.0));
		wall_color *= 0.95 + panel_lines * 0.05;

		// Atmospheric haze on walls too
		wall_color = mix(haze_color * 0.6, wall_color, atmosphere);

		// Add night glow to walls
		wall_color += night_glow * 0.3 + day_sheen * 0.2;

		// Wall opacity - extends all the way to horizon (only fades below 0 degrees)
		float wall_horizon_fade = smoothstep(-0.05, 0.02, elevation);
		float wall_opacity = wall_horizon_fade;

		return vec4(wall_color, wall_opacity);
	}

	return vec4(ring_color, opacity);
}

void sky() {
	vec3 dir = EYEDIR;

	// Calculate sun direction from elevation and azimuth
	float sun_elev_rad = radians(sun_elevation);
	float sun_azim_rad = radians(sun_azimuth);
	vec3 sun_dir = vec3(
		cos(sun_elev_rad) * sin(sun_azim_rad),
		sin(sun_elev_rad),
		cos(sun_elev_rad) * cos(sun_azim_rad)
	);

	// Day/night factor (0 = night, 1 = day)
	float day_factor = smoothstep(-10.0, 20.0, sun_elevation);

	// Sunset factor
	float sunset_factor = smoothstep(-10.0, 5.0, sun_elevation) * smoothstep(25.0, 5.0, sun_elevation);

	// Sky gradient
	float horizon_factor = 1.0 - abs(dir.y);
	horizon_factor = pow(horizon_factor, 0.8);

	// Blend sky colors
	vec3 sky_top = mix(night_sky_top, day_sky_top, day_factor);
	vec3 sky_horizon = mix(night_sky_horizon, day_sky_horizon, day_factor);
	sky_horizon = mix(sky_horizon, sunset_color, sunset_factor * 0.7);

	vec3 sky_color = mix(sky_top, sky_horizon, horizon_factor);

	// Check if sun is behind the ring (to occlude it)
	float offset_rad = radians(ring_azimuth_offset);
	vec3 sun_rotated = vec3(
		sun_dir.x * cos(offset_rad) - sun_dir.z * sin(offset_rad),
		sun_dir.y,
		sun_dir.x * sin(offset_rad) + sun_dir.z * cos(offset_rad)
	);

	// Calculate sun's effective ring width (physics: 1/sin(elevation), capped at 50x)
	float sun_elev = asin(clamp(sun_rotated.y, -1.0, 1.0));
	float sun_sin_elev = max(sin(sun_elev), 0.02);
	float sun_effective_width = ring_visual_width / sun_sin_elev;

	float sun_dist_to_ring = abs(sun_rotated.z);
	float sun_behind_ring = smoothstep(sun_effective_width * 0.8, sun_effective_width * 1.1, sun_dist_to_ring);

	// Add sun (occluded by ring)
	float sun_dist = distance(dir, sun_dir);
	float sun_disc = smoothstep(sun_size, sun_size * 0.5, sun_dist);
	float sun_glow = smoothstep(sun_size * 8.0, sun_size, sun_dist) * 0.3;
	float sun_visible = smoothstep(-5.0, 5.0, sun_elevation);
	sky_color += sun_color * (sun_disc + sun_glow) * sun_visible * sun_behind_ring;

	// Check if current view direction is in the ring area (for occlusion)
	// This needs to come BEFORE stars and planet so we can occlude them
	vec3 dir_rotated = vec3(
		dir.x * cos(offset_rad) - dir.z * sin(offset_rad),
		dir.y,
		dir.x * sin(offset_rad) + dir.z * cos(offset_rad)
	);

	// Calculate view direction's effective ring width (physics: 1/sin(elevation), capped at 50x)
	float dir_elev = asin(clamp(dir_rotated.y, -1.0, 1.0));
	float dir_sin_elev = max(sin(dir_elev), 0.02);
	float dir_effective_width = ring_visual_width / dir_sin_elev;

	float dir_dist_to_ring = abs(dir_rotated.z);
	// in_ring_area = 1 when inside ring band, 0 when outside
	float in_ring_area = smoothstep(dir_effective_width * 1.1, dir_effective_width * 0.5, dir_dist_to_ring);
	// above_horizon = fade in the occlusion as we look up
	float above_horizon = smoothstep(-0.05, 0.15, dir.y);
	// Combined ring occlusion factor: 0 = fully occluded, 1 = visible
	float ring_occlusion = 1.0 - (in_ring_area * above_horizon);

	// Add stars at night (occluded by ring)
	float star_visibility = 1.0 - day_factor;
	if (dir.y > -0.1 && star_visibility > 0.01) {
		// Procedural background stars (dim, many)
		float bg_stars = procedural_stars(dir);
		sky_color += vec3(bg_stars) * star_visibility * 0.6 * ring_occlusion;

		// Real constellation stars (bright, defined)
		vec3 constellation = constellation_stars(dir);
		sky_color += constellation * star_visibility * ring_occlusion;
	}

	// Add gas giant planet (occluded by ring)
	vec3 planet = draw_gas_giant(dir);
	float planet_night_boost = mix(1.0, 1.5, 1.0 - day_factor);
	sky_color += planet * planet_night_boost * ring_occlusion;

	// Planet glow at night (also occluded by ring)
	if (star_visibility > 0.1) {
		float planet_elev_rad = radians(planet_elevation);
		float planet_azim_rad = radians(planet_azimuth);
		vec3 planet_dir = vec3(
			cos(planet_elev_rad) * sin(planet_azim_rad),
			sin(planet_elev_rad),
			cos(planet_elev_rad) * cos(planet_azim_rad)
		);
		float glow_dist = distance(dir, planet_dir);
		float planet_glow = smoothstep(planet_size * 3.0, planet_size, glow_dist) * 0.1;
		sky_color += vec3(0.9, 0.85, 0.7) * planet_glow * star_visibility * ring_occlusion;
	}

	// Add clouds (between us and the ring)
	vec4 cloud_rgba = draw_clouds(dir, sun_elevation, TIME);
	vec3 cloud_col = cloud_rgba.rgb;
	float cloud_alpha = cloud_rgba.a;
	cloud_alpha *= ring_occlusion;
	sky_color = mix(sky_color, cloud_col, cloud_alpha);

	// Add Halo ring horizon (the opposite side of the ring curving overhead)
	vec4 ring_rgba = draw_ring_horizon_rgba(dir);
	vec3 ring_color = ring_rgba.rgb;
	float ring_alpha = ring_rgba.a;
	// Ring is visible day and night, slightly brighter at night
	float ring_night_boost = mix(1.0, 1.2, 1.0 - day_factor);
	// Slightly reduce ring visibility during sunset for atmosphere blending
	float ring_sunset_dim = 1.0 - sunset_factor * 0.2;
	// Blend ring with sky using alpha - make it solid
	ring_alpha = min(ring_alpha * 2.5, 1.0);
	// Apply brightness adjustments to ring color, not alpha
	ring_color *= ring_night_boost * ring_sunset_dim;
	sky_color = mix(sky_color, ring_color, ring_alpha);

	COLOR = sky_color;
}
