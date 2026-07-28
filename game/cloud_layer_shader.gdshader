shader_type spatial;
render_mode cull_disabled, shadows_disabled, blend_mix, depth_draw_never, unshaded;

uniform vec3  color_top    : source_color = vec3(1.0,  1.0,  1.0);
uniform vec3  color_bottom : source_color = vec3(0.58, 0.64, 0.72);
uniform float cloud_brightness : hint_range(0.0, 1.0) = 0.5;
uniform float coverage     : hint_range(0.0, 1.0) = 0.52;
uniform float softness     : hint_range(0.05, 0.5) = 0.18;
uniform float noise_scale  : hint_range(0.00005, 0.001) = 0.00018;
uniform vec2  noise_stretch = vec2(1.0, 1.0);
uniform float cloud_base   : hint_range(0.0, 5000.0) = 1500.0;
uniform float cloud_top    : hint_range(0.0, 5000.0) = 2000.0;
uniform float layer_t      : hint_range(0.0, 1.0) = 0.5;
uniform vec2  wind_dir     = vec2(1.0, 0.0);
uniform float wind_speed       : hint_range(0.0, 0.05) = 0.008;
uniform float plane_half_size  : hint_range(1000.0, 200000.0) = 14000.0;
uniform float fade_start       : hint_range(0.05, 0.95) = 0.45;   // where the horizon fade begins
uniform vec2  sun_dir_xz   = vec2(0.0, -1.0);
uniform vec3  sun_tint     : source_color = vec3(1.0, 0.6, 0.3);
uniform float scatter      : hint_range(0.0, 1.0) = 0.0;
// added 2026-07-28 for ring_vibes' 5-layer stack. Defaults reproduce the original 3-layer
// behaviour exactly, so the older cloud_system.gd usage is unaffected.
uniform float layer_alpha    : hint_range(0.0, 1.0) = 1.0;   // per-layer transparency (stacked layers compound)
uniform float self_shadow_amt: hint_range(0.0, 1.0) = 0.72;  // lower = flatter/less dark in thick overcast
// Underside lighting. The top-lit diffuse model above is only right when you're ABOVE the layer;
// from below (the normal case, standing on the ground) a real cloud base isn't lit by direct sun at
// all -- it's lit by light TRANSMITTED through the cloud, so thin cloud glows and thick cloud goes
// flat grey. Without this the underside just showed the unlit side and read as muddy/too dark.
uniform float under_ambient  : hint_range(0.0, 1.0) = 0.55;  // sky-bounce floor on the cloud base
uniform float under_transmit : hint_range(0.0, 2.0) = 0.75;  // how much sun bleeds through thin cloud
uniform float transmit_k     : hint_range(0.5, 8.0) = 2.5;   // higher = thickness kills transmission faster

// --- shape/animation variety (added 2026-07-28) ------------------------------------------------
// Everything below defaults to a no-op, so the original cloud_system.gd look is unchanged.
// DOMAIN WARP: Noise(x + Noise(x)) -- the single biggest win for variety. Plain fbm + linear
// scroll reads as a flat sheet sliding past; warping the sample coordinate by a second noise gives
// wind shear, wispy tails and curl. Because the warp field itself drifts (warp_speed) the clouds
// CHURN and morph as they travel instead of rigidly translating.
uniform float warp_amount : hint_range(0.0, 4.0) = 0.0;   // warp strength, in noise-space units
uniform float warp_freq   : hint_range(0.1, 4.0) = 0.6;   // warp noise scale rel. to the main fbm
uniform float warp_speed  : hint_range(0.0, 1.0) = 0.05;  // how fast the warp field itself evolves
// EVOLUTION: slowly slides the noise field on a second axis so shapes are born/die in place rather
// than being a fixed pattern conveyor-belted past the camera.
uniform float evolve_speed : hint_range(0.0, 0.5) = 0.0;
// SHAPE: pow() pinches low values and sharpens peaks -> dense fluffy centres, fast-fading edges.
uniform float density_pow : hint_range(0.5, 4.0) = 1.0;
// MACRO MODULATION: Density = N1 * N2, where a low-frequency N2 carves broad cloudy/clear regions
// so coverage isn't uniform to the horizon (real skies have weather-scale structure).
uniform float macro_amount : hint_range(0.0, 1.0) = 0.0;
uniform float macro_scale  : hint_range(0.02, 1.0) = 0.15;

// RING BEND (added 2026-07-29). Flat cloud planes cannot reach the horizon on a ringworld: at 30km
// the ring floor has already risen ~940m (R=477km), above the low cloud deck, and by 60km it has
// risen 3.8km -- above every layer. So a flat sheet sinks into the terrain long before it gets low
// enough on-screen to meet the horizon (at 14km a 1000m cloud is still 4.1 deg up, which is the
// visible gap). Bending the sheet onto the ring cylinder -- the same transform the terrain uses --
// lets it run to any distance at constant altitude, curving up with the land as it should.
// ring_radius = 0 keeps the original flat behaviour for the older cloud_system.gd scenes.
uniform float ring_radius = 0.0;
uniform vec2  plane_origin = vec2(0.0);   // (arc, lat) of the plane centre
uniform float altitude     = 1000.0;      // layer height above the ring floor
// rim-wall shadow on the cloud deck -- same analytic test the terrain uses (see cdlod_ring.gdshader).
// Cloud layers sit at 800-3200m and the walls top out at 4000m, so the walls really do fall across
// the underside of the deck near the ring edges.
uniform float ring_half_width = 25000.0;
uniform float wall_top        = 4000.0;
uniform float wall_shadow_soft = 400.0;
// real 3D sun direction. sun3d below fakes elevation as a constant 0.4, which is fine for the
// diffuse term it was written for but useless for a shadow test -- that needs true elevation.
uniform vec3 sun_world = vec3(0.0, 1.0, 0.0);

varying vec3 world_pos;
varying vec2 _plane_offset;
varying vec2 ring_uv;      // (arc, lat) -- noise must be sampled here, not world.xz, which wraps

float hash2(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float vnoise2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
	           mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	vec2  s = vec2(1.7, 9.2);
	for (int i = 0; i < 6; i++) {
		v += a * vnoise2(p);
		p  = p * 2.07 + s;
		a *= 0.5;
		s  = s.yx * 1.3;
	}
	return v;
}

// cheap 2-octave fbm for the warp/macro fields -- they only need broad shape, and this keeps the
// added cost small (the 6-octave fbm is already called 3x per fragment for density + normals).
float fbm2(vec2 p) {
	return 0.65 * vnoise2(p) + 0.35 * vnoise2(p * 2.13 + vec2(4.1, 1.7));
}

void vertex() {
	_plane_offset = VERTEX.xz;
	if (ring_radius > 0.0) {
		// (arc, lat) are ring-surface coords; bend them onto the cylinder interior at `altitude`
		float arc = plane_origin.x + VERTEX.x;
		float lat = plane_origin.y + VERTEX.z;
		ring_uv = vec2(arc, lat);
		float theta = arc / ring_radius;
		float rr = ring_radius - altitude;
		world_pos = vec3(rr * sin(theta), ring_radius - rr * cos(theta), lat);
		VERTEX = world_pos;   // identity model transform, so VERTEX is the world position
	} else {
		world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		ring_uv = world_pos.xz;
	}
}

void fragment() {
	// noise_stretch elongates cirrus into streaks (x=6 for top layer)
	vec2 uv = ring_uv * (noise_scale * noise_stretch) + wind_dir * TIME * wind_speed;
	// slow evolution: shifts the field on a second axis so shapes form and dissolve in place
	uv += vec2(0.0, TIME * evolve_speed);
	// domain warp: sample offset by a drifting noise field -> shear, curl and wispy tails, and the
	// cloud churns as it drifts rather than sliding rigidly. Computed once and reused by the
	// normal-gradient samples below (their offset is tiny, so the warp is effectively identical).
	vec2 warp = vec2(0.0);
	if (warp_amount > 0.001) {
		vec2 wuv = uv * warp_freq + vec2(TIME * warp_speed, TIME * warp_speed * 0.7);
		warp = vec2(fbm2(wuv), fbm2(wuv + vec2(5.2, 1.3))) - 0.5;
		warp *= warp_amount;
	}
	float raw = fbm(uv + warp);
	float base_raw = raw;   // pre-modulation copy: the normal gradient below must compare like-for-like
	// macro modulation (Density = N1 * N2): broad cloudy/clear regions so coverage isn't uniform
	if (macro_amount > 0.001) {
		float macro = fbm2(uv * macro_scale + vec2(11.3, 7.9));
		raw *= mix(1.0, clamp(macro * 1.8, 0.0, 1.0), macro_amount);
	}
	// pow() pinches lows / sharpens peaks -> dense centres with fast-fading edges
	if (density_pow != 1.0) {
		raw = pow(clamp(raw, 0.0, 1.0), density_pow);
	}
	float threshold = 1.0 - coverage;
	float d = smoothstep(threshold - softness, threshold + softness, raw);
	d *= mix(1.0, 0.8, layer_t);

	// Horizon fade. On the ring this keys off ARC distance only -- the lat extent is bounded by the
	// habitat walls (which occlude that direction anyway), so fading it too would just cut the deck
	// short overhead. Flat mode keeps the original radial fade.
	float dist    = (ring_radius > 0.0) ? abs(_plane_offset.x) : length(_plane_offset);
	float horizon = 1.0 - smoothstep(plane_half_size * fade_start, plane_half_size, dist);

	// Base cloud colour
	vec3 base_color = mix(color_bottom, color_top, layer_t + d * 0.15);

	// Fake surface normal from FBM density gradient (2 extra samples)
	// Gives each cloud puff a lit dome on top and shadowed sides.
	// NOTE: must sample the WARPED field (uv + warp), matching `raw` above -- sampling the unwarped
	// field here would light a different shape than the one actually being drawn.
	float e = 0.5;
	float ndx = fbm(uv + warp + vec2(e, 0.0)) - base_raw;
	float ndz = fbm(uv + warp + vec2(0.0, e)) - base_raw;
	vec3 fake_normal = normalize(vec3(-ndx * 10.0, 1.0, -ndz * 10.0));

	// Sun direction with slight upward component (approximate elevation)
	vec3 sun3d = normalize(vec3(sun_dir_xz.x, 0.4, sun_dir_xz.y));
	float diffuse = max(0.0, dot(fake_normal, sun3d));
	// rim-wall shadow across the deck (ring mode only): march toward the sun and see whether we
	// cross the wall's lat while still below its top.
	float wall_lit = 1.0;
	if (ring_radius > 0.0 && sun_world.y > 0.001 && abs(sun_world.z) > 0.0001) {
		float wall_lat = (sun_world.z > 0.0) ? ring_half_width : -ring_half_width;
		float d_lat = wall_lat - ring_uv.y;
		if (d_lat * sun_world.z > 0.0) {
			float h_at_wall = altitude + (d_lat / sun_world.z) * sun_world.y;
			wall_lit = smoothstep(wall_top - wall_shadow_soft, wall_top + wall_shadow_soft, h_at_wall);
		}
	}
	diffuse *= wall_lit;

	// Self-shadow: denser cloud interior is darker (simulates depth/thickness)
	float self_shadow = 1.0 - raw * self_shadow_amt;

	// Top-lit (viewer above the layer): direct sun on the fake normal + self-shadow by thickness.
	float lighting_top = (0.20 + diffuse * 0.80) * self_shadow;
	lighting_top = smoothstep(0.0, 1.0, lighting_top);   // contrast: darks darker, lights lighter
	// Under-lit (viewer below the layer -- the usual case): transmitted light, not direct sun.
	// exp(-thickness) so thin cloud glows and dense cloud settles to a flat grey, never black.
	float transmit = exp(-raw * transmit_k);
	float lighting_bottom = under_ambient + transmit * under_transmit * max(0.0, sun3d.y);
	float viewing_top = step(world_pos.y, CAMERA_POSITION_WORLD.y);   // 1 = camera above the layer
	float lighting = mix(lighting_bottom, lighting_top, viewing_top);
	base_color *= lighting;

	// Sunset/sunrise: global warm tint on all cloud fragments + directional boost
	if (scatter > 0.01) {
		base_color = mix(base_color, sun_tint, scatter * 0.5);
		if (dist > 1.0) {
			vec2 frag_dir  = _plane_offset / dist;
			float sun_face = max(0.0, dot(frag_dir, sun_dir_xz));
			sun_face = pow(sun_face, 1.5) * scatter;
			base_color = mix(base_color, sun_tint, sun_face * 0.9);
		}
	}

	ALBEDO = base_color * cloud_brightness;
	ALPHA  = d * horizon * layer_alpha;
}
