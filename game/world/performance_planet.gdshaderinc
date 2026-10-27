// Source photograph is sampled directly; no generated replacement artwork.
uniform sampler2D planet_image : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 planet_direction=vec3(0.65,-0.7,0.3);
uniform float planet_radius=0.174532925; // 20 degree diameter: twice the preceding version.
vec3 planet_sky(vec3 background, vec3 view, float daylight, float overcast) {
 vec3 centre=normalize(planet_direction);
 float facing=dot(view,centre);
 if(facing<cos(planet_radius*1.08)) return background;
 vec3 right=normalize(cross(centre,vec3(0,0,1)));
 vec3 top=normalize(cross(right,centre));
 vec2 disc=vec2(dot(view,right),-dot(view,top))/sin(planet_radius);
 float radius=length(disc);
 // The supplied planet occupies this circular region of the original image.
 vec2 uv=vec2(0.3125,0.49)+disc*vec2(0.244,0.434);
 vec3 surface=texture(planet_image,uv).rgb;
 float edge=1.0-smoothstep(0.985,1.015,radius);
 float visibility=1.0-overcast;
 // Daytime atmosphere veils the disc while its silhouette masks the stars.
 vec3 colour=mix(surface,background,daylight*0.35);
 return mix(background,colour,edge*visibility);
}
