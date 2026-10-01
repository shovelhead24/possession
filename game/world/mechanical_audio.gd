extends RefCounted
static func make_sound(cannon: bool=false) -> AudioStreamWAV:
	var rate=22050;var count=int(rate*(.8 if cannon else 1.5));var data=PackedByteArray();data.resize(count*2)
	var rng=RandomNumberGenerator.new();rng.seed=75;var filtered=0.0
	for i in range(count):
		var t=float(i)/rate;var sample=0.0
		filtered=lerpf(filtered,rng.randf_range(-1,1),.2)
		if cannon: sample=(filtered*.8+sin(TAU*48*t)*.6)*exp(-t*7)*minf(t*400,1)
		else:
			for start in [.02,.35,1.15]:
				var age=t-start
				if age>=0: sample+=(filtered*.65+sin(TAU*650*age)*.15)*exp(-age*35)*minf(age*500,1)
		data.encode_s16(i*2,int(clampf(sample,-1,1)*26000))
	var sound=AudioStreamWAV.new();sound.format=AudioStreamWAV.FORMAT_16_BITS;sound.mix_rate=rate;sound.data=data;return sound
