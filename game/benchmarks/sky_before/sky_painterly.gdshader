shader_type sky;
uniform vec3 local_up=vec3(0,1,0);
uniform float time_seconds=0.0;
uniform float cloud_brightness=1.0;
uniform vec3 horizon:source_color=vec3(0.62,0.74,0.86);
float hash3(vec3 p){p=fract(p*0.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float noise3(vec3 p){
 vec3 i=floor(p),f=fract(p);f=f*f*f*(f*(f*6.0-15.0)+10.0);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float fbm(vec3 p){float sum=0.0,a=0.54;for(int i=0;i<5;i++){sum+=noise3(p)*a;p=mat3(vec3(0,0.8,0.6),vec3(-0.8,0.36,-0.48),vec3(-0.6,-0.48,0.64))*p*2.03+vec3(13.1,5.7,9.2);a*=0.48;}return sum;}
void sky(){
 vec3 ray=normalize(EYEDIR);float up=dot(ray,normalize(local_up));
 vec3 col=mix(horizon,vec3(0.24,0.28,0.43),smoothstep(-0.03,0.9,up));
 // Continuous 3D direction sampling avoids folds from projecting d.xz.
 vec3 p=ray*4.8+vec3(time_seconds*0.0015,0,0);
 vec3 warp=vec3(noise3(p+17.1),noise3(p+43.8),noise3(p+91.3))-0.5;
 float mass=fbm(p+warp*1.3);
 float cloud=smoothstep(0.34,0.67,mass)*smoothstep(-0.01,0.19,up);
 vec3 tint=mix(vec3(0.45,0.46,0.56),vec3(0.86,0.82,0.81),smoothstep(0.33,0.72,mass));
 COLOR=mix(col,tint*cloud_brightness,cloud*0.85);
}
