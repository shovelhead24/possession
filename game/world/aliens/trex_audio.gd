extends Node3D

const FOLDER := "res://../assets/trex sounds/"
const FILES := {
	"breath":"cartoon_music-t-rex-breathing-550277.mp3",
	"pain":"cartoon_music-t-rex-groan-550364.mp3",
	"growl":"cartoon_music-t-rex-growling-550365.mp3",
	"bite":"cartoon_music-t-rex-grunt-550366.mp3",
	"roar":"cartoon_music-t-rex-roar-550368.mp3",
	"roar_alt":"pwlpl-epic-t-rex-roaring-sound-effect-powerful-dinosaur-444199.mp3",
	"step":"dragon-studio-colossal-footsteps-467495.mp3",
}
static var bank: Dictionary={}
var actor: Node3D
var voice: AudioStreamPlayer3D
var feet: Array[AudioStreamPlayer3D]=[]
var airborne := [false,false]
var foot_cooldown := [0.0,0.0]
var previous_position := Vector3.ZERO
func origin_shifted(delta: Vector3):previous_position-=delta
var roar_cooldown := 0.0
var pain_cooldown := 0.0
var ambient_timer := 8.0
var had_target := false
var events: Dictionary={}

static func load_bank() -> void:
	if not bank.is_empty(): return
	for key in FILES:
		var path=FOLDER+FILES[key]
		if not FileAccess.file_exists(path):
			push_warning("Tyrant sound missing: "+path);continue
		var mp3=AudioStreamMP3.new();mp3.data=FileAccess.get_file_as_bytes(path)
		# Decode once per game session to mono for proper positional playback.
		# First impact only: never restart the eight-second footsteps sequence.
		var duration=minf(.82,mp3.get_length()) if key=="step" else mp3.get_length()
		var rate=AudioServer.get_mix_rate()
		var playback=mp3.instantiate_playback();playback.start()
		var samples=playback.mix_audio(1.0,int(duration*rate))
		var pcm=PackedByteArray();pcm.resize(samples.size()*2)
		for i in samples.size():
			var fade=minf(1.0,i/(rate*.008))*minf(1.0,(samples.size()-1-i)/(rate*(.12 if key=="step" else .025)))
			pcm.encode_s16(i*2,roundi(clampf((samples[i].x+samples[i].y)*.5*fade,-1.0,1.0)*32767))
		var wav=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=rate;wav.stereo=false;wav.data=pcm
		bank[key]=wav

func player(volume: float,reach: float,unit: float) -> AudioStreamPlayer3D:
	var node=AudioStreamPlayer3D.new();node.volume_db=volume;node.max_db=0.0;node.max_distance=reach;node.unit_size=unit
	node.max_polyphony=1;add_child(node);return node

func _ready() -> void:
	actor=get_parent();load_bank()
	voice=player(-10.0,150.0,18.0)
	for side in 2: feet.append(player(1.0,110.0,14.0))
	previous_position=actor.global_position
	ambient_timer=randf_range(8.0,14.0)
	print("TREX_AUDIO_READY: ",bank.size()," cached mono clips / landing-triggered footsteps")

func vocal(key: String,interrupt: bool=false) -> bool:
	if not bank.has(key) or (voice.playing and not interrupt): return false
	voice.stop();voice.stream=bank[key];voice.pitch_scale=randf_range(.94,1.04)
	voice.volume_db=-20.0 if key=="breath" else (-14.0 if key=="growl" else -10.0)
	voice.play();events[key]=events.get(key,0)+1
	return true

func alert() -> void:
	if roar_cooldown>0.0 or actor.bite_time>0.0: return
	if vocal("roar" if randf()<.5 else "roar_alt",true):
		roar_cooldown=18.0;ambient_timer=randf_range(18.0,30.0)

func bite() -> void:
	vocal("bite",true);ambient_timer=12.0

func stomp(point: Vector3) -> void:
	if not bank.has("step"): return
	feet[0].global_position=point;feet[0].stream=bank.step;feet[0].pitch_scale=.8;feet[0].play()
	events["stomp"]=events.get("stomp",0)+1

func hurt() -> void:
	if pain_cooldown>0.0: return
	pain_cooldown=2.5;vocal("pain",true)

func sample_feet(delta: float,heights: Array,positions: Array,moving: bool) -> void:
	for side in 2:
		foot_cooldown[side]=maxf(0.0,foot_cooldown[side]-delta)
		if heights[side]>.95: airborne[side]=true
		elif heights[side]<.80:
			if airborne[side] and moving and foot_cooldown[side]<=0.0 and bank.has("step"):
				feet[side].global_position=positions[side]
				feet[side].stream=bank.step;feet[side].pitch_scale=randf_range(.92,1.06);feet[side].play()
				foot_cooldown[side]=.4;events["step"]=events.get("step",0)+1
			airborne[side]=false

func _process(delta: float) -> void:
	if not actor.runtime_active: return
	roar_cooldown=maxf(0.0,roar_cooldown-delta);pain_cooldown=maxf(0.0,pain_cooldown-delta)
	ambient_timer-=delta
	voice.global_position=actor.vision_origin()
	var travel=actor.global_position-previous_position;travel.y=0.0;previous_position=actor.global_position
	var ground=actor.grounding
	if ground and ground.source_foot_heights.size()==2 and ground.last_feet.size()==2:
		sample_feet(delta,ground.source_foot_heights,ground.last_feet,travel.length()>.005 and actor.bite_time<=0.0)
	var has_target=is_instance_valid(actor.cached_prey)
	if has_target and not had_target: alert()
	had_target=has_target
	if ambient_timer<=0.0 and not voice.playing and actor.bite_time<=0.0:
		vocal("growl" if has_target else "breath")
		ambient_timer=randf_range(18.0,30.0)
