shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 base_color : source_color = vec3(0.25,0.34,0.25);
uniform vec3 sky_color : source_color = vec3(0.62,0.74,0.86);
uniform float haze_density = 0.00001;
uniform vec3 to_sun = vec3(-0.4,0.7,0.2);
varying highp vec3 world_position;
varying vec3 world_normal;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
}
void fragment(){
 float diffuse=max(dot(normalize(world_normal),normalize(to_sun)),0.0);
 vec3 lit=base_color*(0.20+0.80*diffuse);
 float distance_m=length(world_position-CAMERA_POSITION_WORLD);
 // Exact exponential extinction expression and default density from ring_vibes.gdshader.
 float fog=1.0-exp(-haze_density*distance_m);
 ALBEDO=mix(lit,sky_color,fog);
}
