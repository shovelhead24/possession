shader_type spatial;
render_mode unshaded, cull_disabled;
// CDLOD terrain for the ring_vibes scene: same quadtree-morph vertex logic as cdlod.gdshader (see
// that file's header — this is the "found viable in cdlod.tscn, ported here" case), but UNSHADED +
// manual sun/haze lighting to match ring_vibes.gdshader / ring_vibes_wall.gdshader's established
// look (consistent day/night + haze across band+walls+terrain). Trade-off: unshaded materials can't
// receive Godot's shadow map, so unlike the standalone cdlod mock the car casts no shadow on the
// ground here — accepted for visual consistency with the already-validated ring look.

uniform sampler2D heightmap : repeat_enable;
uniform sampler2D dem_tex;
uniform vec2 dem_cam = vec2(0.0);
uniform float dem_mpp = 47.0;
uniform vec2 dem_size = vec2(1.0);
uniform bool use_dem = false;
uniform float dem_scale = 1.0;
uniform sampler2D sat_tex : source_color, filter_linear;
uniform bool has_sat = false;
uniform sampler2D road_tex : filter_linear;
uniform bool has_roads = false;
uniform float sat_gain = 1.35;
// Secondary splice patches placed around the arc (see ring_vibes.gd PATCHES). One Texture2DArray,
// one layer per patch, at reduced resolution -- these are travel scenery, not the play area, and
// full-res copies of all of them would be a large VRAM bill for detail nobody stands next to.
// The high-res home patch (dem_tex above) still wins wherever it covers.
uniform sampler2DArray patch_tex;
uniform int patch_count = 0;
uniform vec4 patch_rect[8];   // (arc_centre, lat_centre, half_arc, half_lat) in metres
uniform vec4 patch_tint[8];
uniform float ring_circumference = 3000000.0;
uniform float terrain_size = 4096.0;
uniform float feature = 3500.0;
uniform float disp = 300.0;
uniform float ring_radius = 0.0;
uniform float ring_width = 1.0e9;
uniform vec2 node_origin = vec2(0.0);
uniform float node_size = 128.0;
uniform float morph_start = 0.0;
uniform float morph_end = 1.0;
uniform vec3 cam_pos = vec3(0.0);
uniform float grid = 16.0;
uniform float lod_tint = 0.0;
uniform bool show_lod = false;
uniform bool morph_horizontal = true;
uniform float skirt = 0.15;
// ring look: same manual sun/haze system as ring_vibes.gdshader / ring_vibes_wall.gdshader
uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);
uniform float haze_density = 0.000012;
uniform vec3 sky_color = vec3(0.45, 0.62, 0.82);
// Rim-wall shadow, computed analytically. The terrain is unshaded/manually lit so it can't receive
// Godot's shadow map -- but the walls are a known simple shape (a fence at lat = +/-width/2 rising
// to wall_top), so we can just ask "does the ray from this point toward the sun cross the wall
// plane below the wall top?". Cheap, exact, no shadow map needed.
uniform float wall_top = 4000.0;
uniform float wall_shadow_soft = 220.0;   // metres of penumbra at the shadow edge

varying float v_h;
varying vec3 v_n;
varying vec2 v_demuv;
varying vec2 v_tile_uv;   // repeating drape UV for the beyond-DEM fallback (same imagery, tiled)
varying vec3 v_world_pos;
varying float v_height;   // metres above the ring floor (v_h is normalised, no good for shadowing)
varying vec2 v_ring;      // (arc, lat) -- needed in fragment for the splice-patch lookup

bool in_dem_bounds(vec2 uv) {
	return uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0;
}

// 1.0 = lit, 0.0 = fully in the wall's shadow. `lat` is the point's position across the ring width,
// `h` its height above the floor. Marching toward the sun, the lat coordinate changes at rate
// to_sun.z and height at rate to_sun.y; if the ray reaches the wall's lat while still below
// wall_top, the wall blocks it.
float wall_shadow(float lat, float h, float half_w) {
	if (to_sun.y <= 0.001) {
		return 1.0;   // sun at/below the local horizon -- night shading handles it
	}
	// which wall can shadow us: the one on the side the sun is coming from
	float wall_lat = (to_sun.z > 0.0) ? half_w : -half_w;
	float d_lat = wall_lat - lat;
	if (d_lat * to_sun.z <= 0.0) {
		return 1.0;   // ray travels away from that wall
	}
	float t = d_lat / to_sun.z;              // distance along the ray to the wall plane
	float h_at_wall = h + t * to_sun.y;      // height when it gets there
	// below the top => blocked. Soften over wall_shadow_soft metres for a penumbra.
	return smoothstep(wall_top - wall_shadow_soft, wall_top + wall_shadow_soft, h_at_wall);
}

// index of the splice patch containing this ring point, or -1. Arc is compared with wraparound so
// a patch sitting near the 0%/100% seam still matches from either side.
int patch_at(vec2 wxz) {
	for (int i = 0; i < 8; i++) {
		if (i >= patch_count) { break; }   // constant bound + break: dynamic loop bounds are unreliable on GLES3
		vec4 r = patch_rect[i];
		float half_c = ring_circumference * 0.5;
		float d_arc = wxz.x - r.x;
		d_arc -= ring_circumference * floor(d_arc / ring_circumference + 0.5);   // wrap to [-C/2, C/2]
		if (abs(d_arc) < r.z && abs(wxz.y - r.y) < r.w) {
			return i;
		}
	}
	return -1;
}

vec2 patch_uv(int i, vec2 wxz) {
	vec4 r = patch_rect[i];
	float d_arc = wxz.x - r.x;
	d_arc -= ring_circumference * floor(d_arc / ring_circumference + 0.5);
	return vec2(d_arc / (2.0 * r.z) + 0.5, 0.5 - (wxz.y - r.y) / (2.0 * r.w));
}

float sample_h(vec2 wxz) {
	// 1. high-res home patch wins wherever it covers
	if (use_dem) {
		vec2 uv = vec2(dem_cam.x + wxz.x / dem_mpp, dem_cam.y - wxz.y / dem_mpp) / dem_size;
		if (in_dem_bounds(uv)) {
			return texture(dem_tex, uv).r * dem_scale;
		}
	}
	// 2. secondary splices placed around the arc
	int pi = patch_at(wxz);
	if (pi >= 0) {
		return texture(patch_tex, vec3(patch_uv(pi, wxz), float(pi))).r * dem_scale;
	}
	// 3. procedural everywhere else -- most of 3000km of arc
	return texture(heightmap, wxz / feature).r * disp;
}

void vertex() {
	vec2 uv01 = vec2(VERTEX.x, VERTEX.z);
	vec2 wxz = node_origin + uv01 * node_size;
	float d = morph_horizontal ? distance(cam_pos.xz, wxz) : distance(cam_pos, vec3(wxz.x, 0.0, wxz.y));
	float morph = clamp((d - morph_start) / max(morph_end - morph_start, 0.001), 0.0, 1.0);
	vec2 g = uv01 * grid;
	vec2 g_coarse = g - mod(g, 2.0);
	vec2 uvm = mix(uv01, g_coarse / grid, morph);
	wxz = node_origin + uvm * node_size;
	v_demuv = vec2(dem_cam.x + wxz.x / dem_mpp, dem_cam.y - wxz.y / dem_mpp) / dem_size;
	v_tile_uv = vec2(wxz.x, -wxz.y) / (dem_mpp * dem_size);   // repeats every patch-width of arc/lat
	float h = sample_h(wxz);
	float e = max(node_size / grid, 2.0);
	float hl = sample_h(wxz + vec2(-e, 0.0));
	float hr = sample_h(wxz + vec2(e, 0.0));
	float hd = sample_h(wxz + vec2(0.0, -e));
	float hu = sample_h(wxz + vec2(0.0, e));
	v_n = normalize(vec3(hl - hr, 2.0 * e, hd - hu));
	v_h = h / max(disp, 1.0);
	v_height = h;
	v_ring = wxz;
	float y = (VERTEX.y < -0.5) ? h - node_size * skirt : h;
	vec3 world;
	if (ring_radius > 0.0) {
		float theta = wxz.x / ring_radius;
		float rr = ring_radius - y;
		float ct = cos(theta), stt = sin(theta);
		world = vec3(rr * stt, ring_radius - rr * ct, wxz.y);
		v_n = vec3(v_n.x * ct - v_n.y * stt, v_n.x * stt + v_n.y * ct, v_n.z);
	} else {
		world = vec3(wxz.x, y, wxz.y);
	}
	VERTEX = world;
	NORMAL = v_n;
	v_world_pos = world;   // instances never carry a transform (identity MODEL_MATRIX) -> VERTEX IS world pos
}

void fragment() {
	// beyond the walls' lat position -> never rendered at all (was a vertex-space sink before,
	// which folded into a visible "wall" of geometry at the tile straddling the boundary — clean
	// discard instead, per-fragment, no folded geometry).
	if (abs(v_world_pos.z) > ring_width * 0.5) {
		discard;
	}
	// hide the geometric underside. The first attempt at this (discard on !FRONT_FACING) had it
	// backwards — confirmed empirically: it discarded the wanted top surface and kept the underside
	// visible as a textured "ceiling". Flipped here: this mesh's wanted surface reports FRONT_FACING
	// == false for this winding, so the unwanted side is FRONT_FACING == true.
	if (FRONT_FACING) {
		discard;
	}
	vec3 base = mix(vec3(0.30, 0.40, 0.24), vec3(0.52, 0.52, 0.48), smoothstep(0.45, 0.85, v_h));
	// inside the mapped DEM patch: accurately-placed real imagery. Beyond it (but still within the
	// CDLOD bubble): the SAME imagery tiled, matching the far band's treatment — no more flat noise-
	// terrain gap between the real patch and the tiled band.
	bool in_dem = v_demuv.x > 0.0 && v_demuv.x < 1.0 && v_demuv.y > 0.0 && v_demuv.y < 1.0;
	if (has_sat) {
		vec2 uv = in_dem ? v_demuv : v_tile_uv;
		vec3 sat = texture(sat_tex, uv).rgb * sat_gain;
		base = mix(base, sat, smoothstep(0.015, 0.05, dot(sat, vec3(0.333))));
		if (has_roads) {
			float road = texture(road_tex, uv).r;
			base = mix(base, vec3(0.27, 0.27, 0.285), smoothstep(0.2, 0.75, road));
		}
	}
	// splice-patch tint: stands in for a per-patch satellite drape (fetching Sentinel-2 for every
	// patch is a separate, much heavier job). Only applied outside the home DEM, which has real
	// imagery. Edge-feathered so patches don't end on a hard colour line against the procedural.
	if (!in_dem) {
		int pi = patch_at(v_ring);
		if (pi >= 0) {
			vec4 r = patch_rect[pi];
			vec2 uv = patch_uv(pi, v_ring);
			vec2 edge = min(uv, 1.0 - uv);                       // 0 at patch border, 0.5 at centre
			float feather = smoothstep(0.0, 0.06, min(edge.x, edge.y));
			base = mix(base, patch_tint[pi].rgb, 0.85 * feather);
		}
	}
	if (show_lod) {
		vec3 lod_col = mix(vec3(0.1, 0.9, 0.2), vec3(0.95, 0.2, 0.1), lod_tint);
		base = mix(base, lod_col, 0.55);
	}
	// v_n comes from the height GRADIENT (hl-hr, 2e, hd-hu), not from triangle winding, so it always
	// points physically "up/outward" already — no FRONT_FACING flip needed (that was copy-pasted
	// from band/wall's winding-derived generate_normals() normals, where the flip IS correct; here
	// it was inverting an already-correct normal, which is what made day/night read backwards).
	vec3 n = normalize(v_n);
	float diffuse = max(dot(n, normalize(to_sun)), 0.0);
	diffuse *= wall_shadow(v_world_pos.z, v_height, ring_width * 0.5);   // rim wall casts onto the floor
	vec3 lit = base * (0.22 + 0.78 * diffuse);   // floor raised again (0.06->0.16->0.22); still read too dark
	float dist = length(v_world_pos - CAMERA_POSITION_WORLD);
	float fog = 1.0 - exp(-haze_density * dist);
	ALBEDO = mix(lit, sky_color, fog);
}
