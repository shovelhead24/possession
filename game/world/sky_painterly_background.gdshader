shader_type sky;
uniform vec3 local_up=vec3(0,1,0);
void sky(){float up=dot(normalize(EYEDIR),normalize(local_up));COLOR=mix(vec3(0.62,0.74,0.86),vec3(0.24,0.28,0.43),smoothstep(-0.03,0.9,up));}
