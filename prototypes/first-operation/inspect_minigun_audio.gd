extends SceneTree
func _initialize():
	for file in ["yodguard-machine-gun-5-402783.mp3","freesound_community-050649_minigunmp3-44779.mp3"]:
		var stream=AudioStreamMP3.new();stream.data=FileAccess.get_file_as_bytes("C:/Games/possession/assets/minigun sounds/"+file)
		var playback=stream.instantiate_playback();playback.start()
		var rate=AudioServer.get_mix_rate();var samples=playback.mix_audio(1.0,int(stream.get_length()*rate))
		print(file," duration=",stream.get_length())
		for start in range(0,samples.size(),int(rate*.1)):
			var energy=0.0;var peak=0.0;var differences=0.0;var previous=0.0
			for i in range(start,mini(samples.size(),start+int(rate*.1))):
				var v=(samples[i].x+samples[i].y)*.5;energy+=v*v;peak=maxf(peak,absf(v));differences+=absf(v-previous);previous=v
			print("%.1f rms=%.3f peak=%.3f delta=%.3f" % [start/rate,sqrt(energy/(rate*.1)),peak,differences/(rate*.1)])
	quit()
