shader_type spatial;
#include "res://world/performance_ring_light.gdshaderinc"
varying vec3 regional_tint;
render_mode unshaded,cull_disabled,shadows_disabled,blend_mix,depth_draw_never;
uniform sampler2D cloud_map:filter_linear_mipmap,repeat_enable;
uniform float cloud_brightness=1.0;
uniform float weather_opacity=1.0;
uniform float weather_fill=0.0;
uniform float altitude=6000.0;
uniform float coverage_variation=0.8;
uniform float weather_darkness=1.0;
uniform vec3 cloud_tint=vec3(1.0);
uniform float cloud_time=0.0;
uniform bool drift_enabled=false;
uniform bool evolution_enabled=false;
varying vec2 cloud_uv;
varying vec2 evolution;
void vertex(){
 float radius=477464.8293;float theta=UV.x/radius;float rr=radius-altitude;
 VERTEX=vec3(rr*sin(theta),altitude+2.0*rr*pow(sin(theta*0.5),2.0),UV.y);
 regional_tint=ring_cycle_enabled?ring_cloud_light(dot(vec3(-sin(theta),cos(theta),0.0),normalize(cycle_sun))):cloud_tint;
 evolution=evolution_enabled?vec2(sin(cloud_time*0.009),cos(cloud_time*0.007))*0.025:vec2(0.0);
 cloud_uv=UV/62500.0; // 48 exact repeats around the 3,000 km ring: no seam.
}
void fragment(){
 float tick=drift_enabled?cloud_time:TIME;
 vec4 tex=texture(cloud_map,cloud_uv+vec2(tick*0.00015,tick*0.000035)+evolution);
 // Broad weather systems survive minification at the opposite side of the ring.
 // Both arc frequencies divide 48 exactly, keeping the seam continuous.
 float broad=texture(cloud_map,cloud_uv/8.0+vec2(0.31,0.19)).a;
 float regional=texture(cloud_map,cloud_uv/24.0+vec2(0.67,0.43)).a;
 float weather=smoothstep(0.10,0.65,broad*0.65+regional*0.35);
 tex.a*=mix(1.0,weather,coverage_variation);
 tex.rgb*=mix(1.0,mix(0.78,1.08,weather),coverage_variation);
 tex.a=clamp(mix(tex.a,max(tex.a,0.92),weather_fill)*weather_opacity,0.0,1.0);
 if(tex.a<0.008){discard;}
 ALBEDO=tex.rgb*cloud_brightness*regional_tint*weather_darkness;ALPHA=tex.a;
}
