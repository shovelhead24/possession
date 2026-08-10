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
// Home-area detail: R/G are east/north height gradients baked at FULL DEM resolution (see
// tools/dem/export_to_game.py), so the terrain can be shaded with relief finer than the mesh
// actually carries. Only meaningful inside the home DEM footprint.
uniform sampler2D detail_tex : filter_linear;
uniform bool has_detail = false;
uniform float normal_strength = 1.0;
uniform float sat_gain = 1.35;
// Secondary splice patches placed around the arc (see ring_vibes.gd PATCHES). One Texture2DArray,
// one layer per patch, at reduced resolution -- these are travel scenery, not the play area, and
// full-res copies of all of them would be a large VRAM bill for detail nobody stands next to.
// The high-res home patch (dem_tex above) still wins wherever it covers.
uniform sampler2DArray patch_tex;                          // heights (RF)
uniform sampler2DArray patch_col_tex : source_color;       // Sentinel-2 imagery per patch
uniform int patch_count = 0;
uniform vec4 patch_rect[40];   // (arc_centre, lat_centre, half_arc, half_lat) in metres -- SAMPLING extent
// OWNERSHIP half-arc, which is not the same thing. Patches are ~97km wide but seated 84km apart, so
// their sampling extents overlap by ~13km. Ownership is clipped to half the gap so exactly one patch
// claims any given arc; sampling still uses the full extent, or the imagery would squash by 15%.
uniform float patch_own[40];
uniform float hires_own = 0.0;
uniform vec4 patch_tint[40];   // fallback colour for patches whose imagery hasn't been fetched
// Height re-basing, metres. Splices are real places at real elevations (altiplano 3562m, Camargue
// 1m), so butting them edge-to-edge produced 3.5km cliffs at patch boundaries. Patches well above
// sea level are shifted down to a common low floor; coastal patches get 0 so coastlines survive.
uniform float patch_offset[40];
uniform float ring_circumference = 3000000.0;
// Streamed high-res tier: the ONE patch the camera is currently inside, decoded on a worker thread
// and swapped in here. 512^2 over an 84km patch is 164 m/px -- fine for scenery you fly past, mush
// for ground you stand on. hires_valid stays false until a decode lands, so the array tier covers.
uniform sampler2D hires_tex;
uniform sampler2D hires_col_tex : source_color;
uniform vec4 hires_rect = vec4(0.0);   // (arc_centre, lat_centre, half_arc, half_lat)
uniform bool hires_valid = false;
uniform bool hires_has_col = false;
uniform sampler2D hires_detail_tex : filter_linear;   // gradient normals for the streamed patch
uniform bool hires_has_detail = false;
uniform float hires_offset = 0.0;   // same re-basing as patch_offset, for the streamed patch
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
// Ocean. Implemented by CLAMPING terrain to sea level rather than drawing a separate water plane:
// no second mesh, no z-fighting against the seabed, and the clamp makes the surface exactly flat
// with flat normals for free (the gradient samples clamp too). Terrarium already floors its data
// at 0m, so a hair above zero catches real coastline. Depth for colouring comes from the
// UNCLAMPED height, carried through as v_depth.
uniform bool ocean_enabled = true;
uniform float sea_level = 0.5;
uniform vec3 shallow_col : source_color = vec3(0.18, 0.42, 0.45);
uniform vec3 deep_col : source_color = vec3(0.04, 0.10, 0.20);
// SWELL. The clamp above made the sea exactly flat, which is why a boat meant nothing: there was no
// surface to ride. Rather than add a second water mesh (z-fighting against the seabed, a whole extra
// draw), the clamp becomes sea_level + wave_h() -- the ocean IS the terrain surface, still one mesh,
// and because sample_h's four gradient neighbours run through the same function the swell gets lit
// normals and sun glint for free.
//
// Three directional sines, wavelengths ~178m / ~140m / ~68m, summing to just over a metre of crest-
// to-trough. Vertical displacement only: no Gerstner horizontal pinch, because every metre of
// horizontal displacement is a metre the CPU twin has to reproduce exactly to keep a hull on the
// drawn surface, and this project has been bitten by CPU/GPU divergence enough times to not spend
// that risk on a subtlety you cannot see from a boat deck. _wave_h in ring_vibes.gd is the twin and
// MUST match this function line for line.
uniform float wave_time = 0.0;
uniform float wave_amp = 1.0;      // 0 kills the swell without touching the clamp (calm-sea toggle)
// Ring-space (arc, lat) centre of the swell bubble. Deliberately NOT cam_pos: _ring_pos rebases the
// world so theta=0 sits under the camera, so cam_pos.x is an offset from the LOD centre while wxz.x
// is an absolute arc. Comparing them is only valid near arc 0. (The existing morph term does exactly
// that -- logged in TASKS.md, not fixed here.) The CPU twin needs to agree with this to the metre,
// so it gets a coordinate that is unambiguous in both.
uniform vec2 wave_center = vec2(0.0);
// Waves are drawn near the camera only. The gradient neighbours are node_size/grid apart -- hundreds
// of metres on a distant node -- so evaluating a 68m wave out there samples noise and the ocean
// boils with aliased specular. Beyond FAR it fades to the old flat clamp, which is what a distant
// sea should look like anyway.
const float WAVE_NEAR = 400.0;
const float WAVE_FAR = 1200.0;

float wave_h(vec2 wxz, float t) {
	float w = sin(dot(wxz, vec2(0.031, 0.017)) + t * 0.90) * 0.55;
	w += sin(dot(wxz, vec2(-0.013, 0.043)) + t * 1.31) * 0.34;
	w += sin(dot(wxz, vec2(0.071, -0.059)) + t * 1.87) * 0.15;
	// short chop, ~22m. The three swells above are 68-178m, which from a 3m eye height is a surface
	// that heaves without ever looking like it has a texture. This is the term you actually see.
	w += sin(dot(wxz, vec2(0.21, 0.16)) + t * 3.10) * 0.09;
	return w;
}

// How much swell survives at this point: none right at the waterline, none far from the camera. The
// shoal term is what keeps coastlines intact -- a 1m wave against a 0.5m sea level would flood and
// drain the beach every few seconds and leave the shoreline crawling.
//
// SHOAL_D is 0.35m, not the 8m a real shoaling curve wants, because THERE IS NO BATHYMETRY. Terrarium
// floors its tiles at 0m, so 87% of a coastal patch is exactly 0.0 and the deepest water anywhere on
// the ring is the 0.5m between the seabed plate and sea_level. Fading over 8m of depth meant
// smoothstep(0,8,0.5) = 0.02, i.e. a 2cm swell nobody could see -- the waves were being drawn and
// were invisible. Over 0.35m the same term still feathers the last half-metre into the beach, which
// is the job it was actually there to do. If real bathymetry ever lands, this goes back to metres.
const float SHOAL_D = 0.35;

float wave_fade(vec2 wxz, float depth) {
	return smoothstep(0.0, SHOAL_D, depth)
		* (1.0 - smoothstep(WAVE_NEAR, WAVE_FAR, distance(wave_center, wxz)));
}

// The COLOUR fade is a separate, much longer one, and the difference matters. Geometry has to stop at
// WAVE_FAR because the gradient neighbours are node_size/grid apart out there and a 68m wave sampled
// every few hundred metres is noise. Colour has no such problem -- it is evaluated per fragment at
// screen resolution. Sharing the geometry fade meant the swell died 1.2km out, and from a 3m eye
// height the horizon is ~6km away, so 95% of the visible ocean was beyond it and rendered flat. This
// still falls off eventually, to keep the crest pattern from moireing at grazing angles.
float wave_tint_fade(vec2 wxz, float depth) {
	return smoothstep(0.0, SHOAL_D, depth)
		* (1.0 - smoothstep(3000.0, 9000.0, distance(wave_center, wxz)));
}
// CLOSE-RANGE DETAIL. The satellite drape is 4096^2 over a ~97km patch, i.e. 23.7 m per texel, and
// Sentinel-2 is only 10m natively -- so no fetch resolution we can afford puts real texture under
// your feet. Standing on it, one texel covers more ground than the car. The drape's job is the
// large-scale pattern (fields, woodland, roads); the close-up has to come from a tiled layer that
// MODULATES it rather than replacing it, so the satellite still decides what colour this ground is.
uniform float detail_scale = 3.5;      // metres per detail cell
uniform float detail_strength = 0.30;
uniform float detail_fade = 260.0;     // metres over which it fades out

varying float v_h;
varying vec3 v_n;
varying vec2 v_demuv;
varying vec2 v_tile_uv;   // repeating drape UV for the beyond-DEM fallback (same imagery, tiled)
varying vec3 v_world_pos;
varying float v_height;   // metres above the ring floor (v_h is normalised, no good for shadowing)
varying vec2 v_ring;      // (arc, lat) -- needed in fragment for the splice-patch lookup
varying float v_depth;    // metres below sea level (>0 = underwater); from the UNCLAMPED height

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// value noise with a smoothstep fade -- continuous, so it mottles instead of tiling into squares
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

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
	for (int i = 0; i < 40; i++) {
		if (i >= patch_count) { break; }   // constant bound + break: dynamic loop bounds are unreliable on GLES3
		vec4 r = patch_rect[i];
		float half_c = ring_circumference * 0.5;
		float d_arc = wxz.x - r.x;
		d_arc -= ring_circumference * floor(d_arc / ring_circumference + 0.5);   // wrap to [-C/2, C/2]
		if (abs(d_arc) < patch_own[i] && abs(wxz.y - r.y) < r.w) {
			return i;
		}
	}
	return -1;
}

vec2 rect_uv(vec4 r, vec2 wxz) {
	float d_arc = wxz.x - r.x;
	d_arc -= ring_circumference * floor(d_arc / ring_circumference + 0.5);
	return vec2(d_arc / (2.0 * r.z) + 0.5, 0.5 - (wxz.y - r.y) / (2.0 * r.w));
}

vec2 patch_uv(int i, vec2 wxz) {
	return rect_uv(patch_rect[i], wxz);
}

// is this point inside the streamed high-res patch?
bool in_hires(vec2 wxz) {
	// tested against the OWNERSHIP window, not the sampling extent -- otherwise the streamed patch
	// keeps claiming ground inside its neighbour's window while the CPU, which resolves ownership
	// differently, places objects on a surface this is not drawing.
	if (!hires_valid) { return false; }
	float half_c = ring_circumference * 0.5;
	float d_arc = wxz.x - hires_rect.x;
	d_arc -= ring_circumference * floor(d_arc / ring_circumference + 0.5);
	if (abs(d_arc) >= hires_own || abs(wxz.y - hires_rect.y) >= hires_rect.w) { return false; }
	vec2 uv = rect_uv(hires_rect, wxz);
	return uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0;
}

float sample_h_raw(vec2 wxz) {
	// 1. high-res home patch wins wherever it covers
	if (use_dem) {
		vec2 uv = vec2(dem_cam.x + wxz.x / dem_mpp, dem_cam.y - wxz.y / dem_mpp) / dem_size;
		if (in_dem_bounds(uv)) {
			return texture(dem_tex, uv).r * dem_scale;
		}
	}
	// 2. the streamed patch you're standing in (3x the array's resolution)
	if (in_hires(wxz)) {
		return (texture(hires_tex, rect_uv(hires_rect, wxz)).r + hires_offset) * dem_scale;
	}
	// 3. secondary splices placed around the arc
	int pi = patch_at(wxz);
	if (pi >= 0) {
		return (texture(patch_tex, vec3(patch_uv(pi, wxz), float(pi))).r + patch_offset[pi]) * dem_scale;
	}
	// 3. procedural everywhere else -- most of 3000km of arc
	return texture(heightmap, wxz / feature).r * disp;
}

// Mirror of ring_vibes.gd _proving_surface(). The calibrated bump strip is physics ground truth
// (added to _terrain_h in _susp_update/_drive_tick, unconditionally), so the mesh must draw the
// same displacement or the car bounces over geometry that isn't there -- the drawn-vs-driven
// mismatch this project keeps hitting. Constants MUST stay identical to the GDScript. Costs ~two
// compares to reject for 3,000km of arc that isn't the 700m strip. The 0-560m obstacles are exact
// between float64 (CPU) and float32 (GPU); the 560m+ potholes are a large-argument sin() hash, so a
// cell or two may differ by float precision -- cosmetic, and only where nobody drives outside --proving.
float proving_surface(vec2 wxz) {
	float d = wxz.x - 900000.0;                              // PROVE_STRIP_ARC
	if (d < 0.0 || d > 700.0 || abs(wxz.y) > 40.0) return 0.0;  // PROVE_STRIP_LEN, _LAT
	if (d < 150.0) return sin(d * 6.28318530718 / 2.5) * 0.08;
	if (d < 300.0) return sin(d * 6.28318530718 / 9.0) * 0.45;
	if (d < 420.0) return clamp(floor((d - 300.0) / 30.0), 0.0, 3.0) * 0.10 + 0.10;
	if (d < 560.0) { float r = (d - 420.0) / 140.0; return (r < 0.85) ? 2.2 * r : 0.0; }
	float px = floor((d - 560.0) / 12.0);
	float py = floor(wxz.y / 9.0);
	return (fract(sin(px * 91.7 + py * 47.3) * 4371.0) < 0.34) ? -0.55 : 0.0;
}

float sample_h(vec2 wxz) {
	float h = sample_h_raw(wxz);
	if (ocean_enabled && h < sea_level) {
		// the swell only costs its three sines where there is actually sea under the vertex
		h = sea_level + wave_h(wxz, wave_time) * wave_amp * wave_fade(wxz, sea_level - h);
	}
	return h + proving_surface(wxz);   // strip sits on top of clamped ground, matching the CPU path
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
	v_depth = sea_level - sample_h_raw(wxz);
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
			// VERGE first, then carriageway over it. The rasterised mask antialiases at its edges,
			// so the 0.03-0.25 band is already a strip a few metres wide either side of the road --
			// a free ditch/verge with no extra data. Darker and greener than the field it cuts
			// through, which is what an Irish roadside ditch actually looks like from a car.
			float verge = smoothstep(0.03, 0.22, road) * (1.0 - smoothstep(0.25, 0.55, road));
			base = mix(base, base * vec3(0.62, 0.78, 0.55), verge * 0.8);
			base = mix(base, vec3(0.27, 0.27, 0.285), smoothstep(0.35, 0.8, road));
		}
	}
	// splice-patch tint: stands in for a per-patch satellite drape (fetching Sentinel-2 for every
	// patch is a separate, much heavier job). Only applied outside the home DEM, which has real
	// imagery. Edge-feathered so patches don't end on a hard colour line against the procedural.
	if (!in_dem && hires_has_col && in_hires(v_ring)) {
		vec2 uv = rect_uv(hires_rect, v_ring);
		vec2 edge = min(uv, 1.0 - uv);
		float feather = smoothstep(0.0, 0.06, min(edge.x, edge.y));
		vec3 sat = texture(hires_col_tex, uv).rgb * sat_gain;
		base = mix(base, sat, 0.9 * feather * smoothstep(0.015, 0.05, dot(sat, vec3(0.333))));
	} else if (!in_dem) {
		int pi = patch_at(v_ring);
		if (pi >= 0) {
			vec2 uv = patch_uv(pi, v_ring);
			vec2 edge = min(uv, 1.0 - uv);                       // 0 at patch border, 0.5 at centre
			float feather = smoothstep(0.0, 0.06, min(edge.x, edge.y));
			vec3 sat = texture(patch_col_tex, vec3(uv, float(pi))).rgb * sat_gain;
			// fall back to the flat tint where the mosaic is nodata-dark (partial S2 coverage)
			vec3 pc = mix(patch_tint[pi].rgb, sat, smoothstep(0.015, 0.05, dot(sat, vec3(0.333))));
			base = mix(base, pc, 0.9 * feather);
		}
	}
	// tiled ground detail, faded in over the last few hundred metres. Two octaves off the ring
	// coordinate itself (metres), so it does not swim, tile visibly against the drape, or need UVs.
	float d_cam = distance(cam_pos, v_world_pos);
	float d_amt = detail_strength * (1.0 - smoothstep(0.0, detail_fade, d_cam));
	if (d_amt > 0.001) {
		// INTERPOLATED value noise, not floor()'d hash cells. The first version quantised to hard
		// square cells, which reads as pixelation rather than ground -- the artefact looks like a
		// resolution failure, which is precisely the impression this was meant to remove.
		vec2 dq = v_ring / detail_scale;
		float g = (vnoise(dq) - 0.5) * 0.70
			+ (vnoise(dq * 0.29 + 11.3) - 0.5) * 0.30
			+ (vnoise(dq * 3.10 + 41.7) - 0.5) * 0.18;
		// signed, mean-zero: this must not darken or brighten the ground overall, only break it up
		base *= 1.0 + g * d_amt;
	}

	// ocean: colour by depth over the (already flattened) surface. Shoreline is feathered over the
	// first couple of metres so coasts don't end on a hard line.
	bool is_water = ocean_enabled && v_depth > 0.0;
	if (is_water) {
		// Both of these terms used to be scaled in METRES OF DEPTH -- mix(shallow, deep, depth/60)
		// and a shoreline feather over smoothstep(0, 2, depth). There is no bathymetry (see wave_fade):
		// v_depth is 0.5 everywhere there is sea, so the feather evaluated to 0.156 and the ocean was
		// drawn as 84% raw satellite drape. That is why halong_bay's bay photographed as a white
		// salt flat rather than as water.
		//
		// Colour now comes from the SWELL instead of from depth: crests take shallow_col, troughs
		// deep_col. It uses data that exists, and it is what makes the waves legible at all -- a 1m
		// swell on a 68m wavelength is nearly invisible as silhouette from a 3m eye height, but it
		// reads immediately as moving light and dark across the surface.
		float wv = wave_h(v_ring, wave_time) * wave_amp * wave_tint_fade(v_ring, v_depth);
		vec3 water = mix(deep_col, shallow_col, clamp(wv * 0.6 + 0.5, 0.0, 1.0));
		base = mix(base, water, smoothstep(0.0, SHOAL_D, v_depth));
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
	// full-res relief inside the home DEM: perturb the (mesh-resolution) normal by the baked
	// gradients so the starting area reads crisp even where the LOD mesh is coarse. Applied in
	// world XZ, which is only strictly right near arc 0 -- fine, since this texture is home-only.
	// Full-res relief from the baked gradient normals (home patch or streamed splice -- same asset,
	// same treatment). The gradients are authored in FLAT ring space, so they must be rotated onto
	// the cylinder by the same bend the vertices got; otherwise the lighting detail is skewed
	// relative to the surface it sits on, by an angle that grows with arc distance. The home patch
	// spans +/-42km = +/-5deg, so it needs this too -- it was previously skipped there on the
	// grounds that arc 0 makes it identity, which is only true at the patch's exact centre.
	if (!is_water) {
		bool use_home = in_dem && has_detail;
		bool use_hires = !in_dem && hires_has_detail && in_hires(v_ring);
		if (use_home || use_hires) {
			vec4 d = use_home ? texture(detail_tex, v_demuv)
							  : texture(hires_detail_tex, rect_uv(hires_rect, v_ring));
			vec3 pert = vec3((d.r - 0.5) * 2.4, 0.0, (d.g - 0.5) * 2.4) * dem_scale * normal_strength;
			float th = v_ring.x / max(ring_radius, 1.0);
			float ct = cos(th), st = sin(th);
			pert = vec3(pert.x * ct - pert.y * st, pert.x * st + pert.y * ct, pert.z);
			n = normalize(n + pert);
		}
	}
	float diffuse = max(dot(n, normalize(to_sun)), 0.0);
	float wall_lit = wall_shadow(v_world_pos.z, v_height, ring_width * 0.5);   // rim wall onto the floor
	diffuse *= wall_lit;
	vec3 lit = base * (0.22 + 0.78 * diffuse);   // floor raised again (0.06->0.16->0.22); still read too dark
	// water sheen: a tight sun glint off the flat surface. Without it the ocean reads as flat blue
	// paint -- the specular is most of what says "liquid" at this distance.
	if (is_water) {
		vec3 V = normalize(CAMERA_POSITION_WORLD - v_world_pos);
		vec3 H = normalize(normalize(to_sun) + V);
		lit += vec3(1.0, 0.97, 0.90) * pow(max(dot(n, H), 0.0), 90.0) * 0.9 * wall_lit;
	}
	float dist = length(v_world_pos - CAMERA_POSITION_WORLD);
	float fog = 1.0 - exp(-haze_density * dist);
	ALBEDO = mix(lit, sky_color, fog);
}
