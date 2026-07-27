shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Soft foliage lighting for the fir cards + billboard impostors. The billboard is a CROSS of flat
// planes; the up-facing one catches full sun (normal = straight up) and blows out while the vertical
// planes go dark — hence the harsh contrast. Wrapped (half-Lambert) diffuse compresses that: nothing
// fully bright or fully black, so the cards read as one soft canopy mass. Engine ambient still fills.
uniform sampler2D tex : source_color;
uniform float cut = 0.5;          // alpha cutout
uniform float wrap = 0.55;        // 0 = plain lambert (harsh), 1 = flat; 0.55 = soft canopy
uniform float sun_gain = 0.85;    // tame the peak so the horizontal cap doesn't over-expose

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < cut) {
		discard;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float w = clamp(ndl * (1.0 - wrap) + wrap, 0.0, 1.0);   // wrapped diffuse
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * w * sun_gain;
}
