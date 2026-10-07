extends Node3D
# Small generated placeholder loops; no external audio dependencies.
var engine: AudioStreamPlayer3D
var gravel: AudioStreamPlayer3D
var bump: AudioStreamPlayer3D
var skid: AudioStreamPlayer3D
var previous_contacts := 0
var last_vertical := 0.0
var cooldown := 0.0

func sound(kind: int) -> AudioStreamWAV:
	var rate=22050;var count=rate if kind!=2 else int(rate*.25)
	var bytes=PackedByteArray();bytes.resize(count*2)
	var rng=RandomNumberGenerator.new();rng.seed=17+kind
	var filtered=0.0
	for i in range(count):
		var t=float(i)/rate
		filtered=lerpf(filtered,rng.randf_range(-1,1),.12)
		var value=(sin(TAU*40*t)*.5+sin(TAU*80*t)*.23+sin(TAU*120*t)*.12) if kind==0 else filtered
		if kind==2: value=(sin(TAU*65*t)*.55+filtered)*exp(-t*22)*minf(t*180,1)
		if kind==3: value=filtered*.8+sin(TAU*260*t+sin(TAU*9*t)*2)*.13
		bytes.encode_s16(i*2,int(clampf(value,-1,1)*22000))
	var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=rate;wav.data=bytes
	if kind!=2: wav.loop_mode=AudioStreamWAV.LOOP_FORWARD;wav.loop_end=count
	return wav

func player(kind: int) -> AudioStreamPlayer3D:
	var p=AudioStreamPlayer3D.new();p.stream=sound(kind);p.unit_size=5;p.max_distance=55;p.volume_db=-18;add_child(p);return p

func _ready() -> void:
	name="DrivingAudio"
	engine=player(0);gravel=player(1);bump=player(2)
	skid=player(3)

func _process(delta: float) -> void:
	var car=get_parent();var speed=car.linear_velocity.length()
	var slipping=0.0
	for c in car.corners:
		if c.get("grounded",false): slipping+=maxf(0,c.get("slip",0.0)-.12)
	if slipping>.02:
		if not skid.playing: skid.play()
		var volume=-18+linear_to_db(clampf(sqrt(slipping/4.0),.01,1))
		skid.volume_db=lerpf(skid.volume_db,volume,1-exp(-delta*12))
	else: skid.stop()
	if car.controlled:
		if not engine.playing: engine.play()
		engine.pitch_scale=lerpf(engine.pitch_scale,.8+minf(speed/14,1.8)+absf(car.throttle)*.35,1-exp(-delta*5))
		engine.volume_db=-23+absf(car.throttle)*7
	else: engine.stop()
	if car.grounded_count>0 and speed>1:
		if not gravel.playing: gravel.play()
		gravel.volume_db=clampf(-35+speed*.6,-35,-19);gravel.pitch_scale=.8+minf(speed/30,1)
	else: gravel.stop()
	cooldown=maxf(0,cooldown-delta)
	if car.grounded_count>0 and previous_contacts==0 and last_vertical < -1.5 and cooldown==0:
		bump.volume_db=clampf(-22+absf(last_vertical),-22,-10);bump.play();cooldown=.3
	previous_contacts=car.grounded_count;last_vertical=car.linear_velocity.y

