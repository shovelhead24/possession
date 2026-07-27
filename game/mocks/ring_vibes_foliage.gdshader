shader_type spatial;
render_mode unshaded, cull_back, depth_prepass_alpha;
// Tree foliage/bark: the leaf atlas is leaves-on-black with no usable alpha, so alpha_scissor
// can't cut it. Key transparency off LUMINANCE instead — discard near-black background texels.
// cull_back (not disabled) + depth_prepass halve the fragment/overdraw cost that tanked UHD to 8fps
// with ~1000 discard-foliage trees on screen (discard breaks early-Z; double-sided doubled it).

uniform sampler2D albedo_tex : source_color;
uniform float key_threshold = 0.09;   // discard texels darker than this (the black background)

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	float luma = max(c.r, max(c.g, c.b));
	if (luma < key_threshold) {
		discard;
	}
	ALBEDO = c.rgb;
}
