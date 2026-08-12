shader_type spatial;
// CONTAINMENT FIELD -- the thing that stops the atmosphere pouring over the rim.
//
// A ringworld has no gravity well. Spin holds the air down against the floor, but nothing holds it
// in at the edges, so a rim wall alone only works if it is as tall as the atmosphere is deep -- and
// a wall that tall dominates the horizon from anywhere on the ring. This carries the containment the
// rest of the way up while being nearly invisible, which is the whole point: you should be able to
// see the ceiling exists without the ceiling being a feature of every landscape shot.
//
// Read as a soap film, not a force wall: strongest at grazing angles, faint head-on, with slow
// interference banding drifting through it. That reads as "a surface is there" without ever
// competing with the terrain.
render_mode blend_add, cull_disabled, unshaded, depth_draw_never, shadows_disabled;

uniform vec3 field_col : source_color = vec3(0.42, 0.66, 0.95);
uniform float strength = 0.10;      // peak alpha at full grazing; deliberately tiny
uniform float band_scale = 3.0;     // interference bands up the curtain
uniform float drift = 0.035;        // how fast the banding creeps along the rim
uniform float fade_far = 90000.0;   // metres at which it stops being drawn at all

varying vec3 v_wpos;
varying vec2 v_uv;

void vertex() {
	v_uv = UV;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// FRESNEL. A film you look straight through is invisible; edge-on it stacks up. NORMAL and VIEW
	// are both in view space here, so this is just how obliquely the surface is being seen.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float fres = pow(1.0 - facing, 3.0);

	// Interference: two slow sines crossing, one up the curtain and one along the rim, so the pattern
	// never repeats visibly at the scale you fly through it.
	float up = v_uv.y;
	float along = v_uv.x;
	float bands = sin(up * band_scale * 6.2831 + TIME * 0.35)
				* sin(along * 2.0 + TIME * drift * 6.2831);
	bands = bands * 0.5 + 0.5;

	// Vertical shape: emerges out of the wall top rather than starting on a hard line, and thins out
	// at the very top so the ceiling feels like a limit being approached, not a lid.
	float base = smoothstep(0.0, 0.18, up);
	float top = 1.0 - smoothstep(0.72, 1.0, up);

	float dist = length(v_wpos - CAMERA_POSITION_WORLD);
	float far = 1.0 - smoothstep(fade_far * 0.5, fade_far, dist);

	float a = strength * fres * mix(0.55, 1.0, bands) * base * top * far;
	ALBEDO = field_col;
	ALPHA = clamp(a, 0.0, 1.0);
}
