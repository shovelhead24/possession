extends Node3D

const FOLDER := "res://../assets/minigun sounds/"
const FIRING := "yodguard-machine-gun-5-402783.mp3"
const WHINE := "freesound_community-050649_minigunmp3-44779.mp3"
static var bank: Dictionary={}
static var loaded := false
var firing: AudioStreamPlayer3D
var motor: AudioStreamPlayer3D
var was_held := false
var gain := 0.0
var starts := {"fire":0,"up":0,"down":0}

static func safe_load(path: String) -> AudioStream:
	if not FileAccess.file_exists(path): return null
	var file=FileAccess.open(path,FileAccess.READ)
	if not file or file.get_length()<16 or file.get_length()>20000000: return null
	var bytes=file.get_buffer(file.get_length());var stream: AudioStream
	match path.get_extension().to_lower():
		"mp3":
			var mp3=AudioStreamMP3.new();mp3.data=bytes;stream=mp3
		"wav":
			if bytes.slice(0,4).get_string_from_ascii()!="RIFF" or bytes.slice(8,12).get_string_from_ascii()!="WAVE": return null
			stream=AudioStreamWAV.load_from_buffer(bytes)
		_: return null
	if not stream or stream.get_length()<=0 or stream.get_length()>120: return null
	return stream

static func decode(stream: AudioStream) -> PackedVector2Array:
	if not stream: return PackedVector2Array()
	var playback=stream.instantiate_playback()
	if not playback: return PackedVector2Array()
	playback.start()
	return playback.mix_audio(1.0,int(stream.get_length()*AudioServer.get_mix_rate()))

static func splice(samples: PackedVector2Array,first: float,last: float,loop: bool=false) -> AudioStreamWAV:
	var rate=AudioServer.get_mix_rate();var begin=int(first*rate);var end=mini(samples.size(),int(last*rate))
	if begin<0 or end-begin<int(rate*.02): return null
	var count=end-begin;var cross=mini(int(rate*.03),count/4)
	var pcm=PackedByteArray();pcm.resize(count*2)
	for i in count:
		var sample=samples[begin+i];var value=(sample.x+sample.y)*.5
		if loop and i>=count-cross:
			var j=i-(count-cross);var other=samples[begin+j]
			value=lerpf(value,(other.x+other.y)*.5,float(j)/maxi(1,cross-1))
		elif not loop: value*=minf(1,i/(rate*.008))*minf(1,(count-1-i)/(rate*.025))
		pcm.encode_s16(i*2,roundi(clampf(value,-1,1)*32767))
	var wav=AudioStreamWAV.new();wav.mix_rate=rate;wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.stereo=false;wav.data=pcm
	if loop: wav.loop_mode=AudioStreamWAV.LOOP_FORWARD;wav.loop_begin=cross;wav.loop_end=count
	return wav

static func preload_bank() -> void:
	if loaded: return
	loaded=true # A missing file must not trigger disk access every frame/shot.
	var main=decode(safe_load(FOLDER+FIRING));var whine=decode(safe_load(FOLDER+WHINE))
	# The second Yodguard burst has a stable interior; omit its gaps and decay.
	bank.fire=splice(main,5.40,6.45,true)
	# 44779's firing section (about 1.8–5.1 s) is deliberately excluded.
	bank.up=splice(whine,.04,1.74)
	bank.down=splice(whine,5.15,8.35)
	for key in bank:
		if not bank[key]: push_warning("Turret audio unavailable: "+key+"; continuing silently")

func _ready() -> void:
	preload_bank()
	firing=AudioStreamPlayer3D.new();firing.stream=bank.fire;firing.unit_size=15;firing.max_distance=180;firing.max_polyphony=1;firing.volume_db=-80;add_child(firing)
	motor=AudioStreamPlayer3D.new();motor.unit_size=11;motor.max_distance=100;motor.max_polyphony=1;motor.volume_db=2;add_child(motor)
	print("TURRET_AUDIO_READY: Yodguard sustained loop / 44779 spool-only cuts")

func update(delta: float,held: bool,shooting: bool,spin: float,cold_delay: float=1.0) -> void:
	if held and not was_held:
		motor.stop()
		if spin<cold_delay and bank.up:
			motor.stream=bank.up;motor.pitch_scale=clampf(bank.up.get_length()/maxf(.15,cold_delay-spin),.5,4);motor.play();starts.up+=1
	elif not held and was_held:
		motor.stop()
		if spin>.01 and bank.down:
			motor.stream=bank.down;motor.pitch_scale=clampf(bank.down.get_length()/maxf(.15,spin/1.5),.5,4);motor.play();starts.down+=1
	was_held=held
	if shooting and firing.stream and not firing.playing:
		firing.pitch_scale=1.0;firing.play();starts.fire+=1
	gain=move_toward(gain,1.0 if shooting else 0.0,delta/(.015 if shooting else .06))
	firing.volume_db=-7.0+linear_to_db(maxf(.0001,gain))
	if gain<=0: firing.stop()

func silence() -> void:
	firing.stop();motor.stop();gain=0;was_held=false
