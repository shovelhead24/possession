// Independent of camera-local light energy; origin is supplied by the review.
uniform bool ring_cycle_enabled=false;
uniform vec3 cycle_origin=vec3(0.0);
uniform float cycle_radius=477464.8293;
uniform vec3 cycle_moon=vec3(0,1,0);
uniform float cycle_moon_gain=0.0;
uniform vec3 cycle_sun=vec3(0,1,0);
uniform float cycle_sun_gain=1.0;
uniform float cycle_ambient_gain=1.0;
float ring_sun_height(vec3 position) {
 vec3 p=position+cycle_origin;
 return dot(normalize(vec3(-p.x,cycle_radius-p.y,0.0)),normalize(cycle_sun));
}
vec3 ring_cloud_light(float height) {
 float daylight=smoothstep(-0.12,0.30,height);
 float warm=(1.0-smoothstep(0.02,0.42,abs(height)))*smoothstep(-0.18,0.0,height);
 return mix(mix(vec3(0.12,0.16,0.27),vec3(1.0),daylight),vec3(1.0,0.53,0.30),warm*0.65);
}
vec3 ring_surface_light(vec3 albedo, vec3 normal, vec3 position, float fog, vec3 local_haze, float distance_to_camera) {
 float height=ring_sun_height(position);
 float daylight=smoothstep(-0.12,0.30,height);
 float warm=(1.0-smoothstep(0.02,0.42,abs(height)))*smoothstep(-0.18,0.0,height);
 vec3 sunlight=mix(vec3(1.0,0.96,0.90),vec3(1.0,0.39,0.15),warm);
 vec3 ambient=mix(vec3(0.018,0.025,0.045),vec3(0.20),daylight)*cycle_ambient_gain;
 vec3 lit=albedo*(ambient+0.8*max(dot(normal,normalize(cycle_sun)),0.0)*sunlight*cycle_sun_gain);
 vec3 absolute_position=position+cycle_origin;
 vec3 radial_up=normalize(vec3(-absolute_position.x,cycle_radius-absolute_position.y,0.0));
 float moon_above=smoothstep(-0.05,0.20,dot(radial_up,cycle_moon));
 lit+=albedo*vec3(.52,.66,1.0)*max(dot(normal,cycle_moon),0.0)*cycle_moon_gain*(1.0-daylight)*moon_above;
 vec3 regional_haze=mix(vec3(0.018,0.028,0.055),vec3(0.62,0.74,0.86),daylight);
 // Retain local haze at the horizon; remote atmosphere follows its own sun.
 vec3 haze=mix(local_haze,regional_haze,smoothstep(20000.0,120000.0,distance_to_camera));
 float far_weight=smoothstep(20000.0,120000.0,distance_to_camera);
 return mix(lit,haze,min(fog,mix(0.82,0.55,far_weight)));
}
