shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,blend_mix,depth_draw_never;
uniform sampler2D cloud_map:filter_linear_mipmap,repeat_enable;
uniform float cloud_brightness=1.0;
uniform float altitude=6000.0;
uniform float coverage_variation=0.8;
varying vec2 cloud_uv;
void vertex(){
 float radius=477464.8293;float theta=UV.x/radius;float rr=radius-altitude;
 VERTEX=vec3(rr*sin(theta),altitude+2.0*rr*pow(sin(theta*0.5),2.0),UV.y);
 cloud_uv=UV/62500.0; // 48 exact repeats around the 3,000 km ring: no seam.
}
void fragment(){
 vec4 tex=texture(cloud_map,cloud_uv+vec2(TIME*0.00015,TIME*0.000035));
 // Broad weather systems survive minification at the opposite side of the ring.
 // Both arc frequencies divide 48 exactly, keeping the seam continuous.
 float broad=texture(cloud_map,cloud_uv/8.0+vec2(0.31,0.19)).a;
 float regional=texture(cloud_map,cloud_uv/24.0+vec2(0.67,0.43)).a;
 float weather=smoothstep(0.10,0.65,broad*0.65+regional*0.35);
 tex.a*=mix(1.0,weather,coverage_variation);
 tex.rgb*=mix(1.0,mix(0.78,1.08,weather),coverage_variation);
 if(tex.a<0.008){discard;}
 ALBEDO=tex.rgb*cloud_brightness;ALPHA=tex.a;
}
