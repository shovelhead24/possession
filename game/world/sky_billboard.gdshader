shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, depth_draw_never;
uniform float shape_seed=0.0;
uniform float cloud_brightness=1.0;
uniform bool instance_seed=false;
uniform bool use_stable_right=false;
uniform vec3 stable_right=vec3(1,0,0);
uniform vec4 distance_fade=vec4(0.0,0.0,0.0,0.0);
varying float cloud_seed;
varying float range_alpha;
float hash(vec2 p){vec3 q=fract(vec3(p.xyx)*0.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float noise2(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*f*(f*(f*6.0-15.0)+10.0);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.0),f.x),f.y);}
float fbm(vec2 p){float sum=0.0,a=0.55;for(int i=0;i<5;i++){sum+=a*noise2(p);p=mat2(vec2(0.8,0.6),vec2(-0.6,0.8))*p*2.07+vec2(7.1,13.7);a*=0.48;}return sum;}
void vertex(){
 // Keep width aligned with the local horizon. Near cards retain orientation
 // through zenith using a position-driven frame maintained by the streamer.
 vec3 local_up=normalize(MODEL_MATRIX[1].xyz);
 vec3 delta=CAMERA_POSITION_WORLD-MODEL_MATRIX[3].xyz;
 float distance=length(delta);
 vec3 front=distance>0.01 ? delta/distance : -local_up;
 vec3 right=use_stable_right ? stable_right : cross(local_up,front);
 if(length(right)<0.001){right=normalize(MODEL_MATRIX[0].xyz);}
 right=normalize(right-front*dot(right,front));
 vec3 up=normalize(cross(front,right));
 MODELVIEW_MATRIX[0]=VIEW_MATRIX*vec4(right*length(MODEL_MATRIX[0].xyz),0);
 MODELVIEW_MATRIX[1]=VIEW_MATRIX*vec4(up*length(MODEL_MATRIX[1].xyz),0);
 MODELVIEW_MATRIX[2]=VIEW_MATRIX*vec4(front,0);
 cloud_seed=instance_seed ? INSTANCE_CUSTOM.x*500.0 : shape_seed;
 range_alpha=1.0;
 if(distance_fade.y>distance_fade.x){range_alpha*=smoothstep(distance_fade.x,distance_fade.y,distance);}
 if(distance_fade.w>distance_fade.z){range_alpha*=1.0-smoothstep(distance_fade.z,distance_fade.w,distance);}
}
void fragment(){
 vec2 p=(UV-0.5)*vec2(2.7,2.1);vec2 seed=vec2(cloud_seed,cloud_seed*0.731);
 float broad=fbm(p*1.1+seed);float detail=fbm(p*3.1+seed+vec2(TIME*0.001,0));
 float envelope=1.0-smoothstep(0.35,1.1,length((UV-0.5)*vec2(1.85,2.0)));
 float density=smoothstep(0.32,0.63,broad*0.72+detail*0.28)*envelope;
 float edge=1.0-smoothstep(0.78,0.99,max(abs(UV.x-0.5),abs(UV.y-0.5))*2.0);
 float light=mix(0.62,1.0,smoothstep(0.2,0.9,1.0-UV.y))*mix(0.84,1.0,detail);
 ALBEDO=vec3(0.94,0.96,1.0)*light*cloud_brightness;ALPHA=density*edge*0.9*range_alpha;
}
