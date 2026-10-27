shader_type sky;
#include "res://world/performance_planet.gdshaderinc"
#include "res://world/performance_stars.gdshaderinc"
uniform vec3 local_up=vec3(0,1,0);
void sky(){float up=dot(normalize(EYEDIR),normalize(local_up));COLOR=mix(vec3(0.62,0.74,0.86),vec3(0.24,0.28,0.43),smoothstep(-0.03,0.9,up));COLOR+=ring_stars(normalize(EYEDIR),up); COLOR=planet_sky(COLOR,normalize(EYEDIR),day,0.0);
}
