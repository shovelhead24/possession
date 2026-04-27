extends Node3D
class_name StressSpawner

const EnemySoldierScene = preload("res://enemy_soldier.tscn")

const SAMPLE_INTERVAL: float = 0.5
const SAMPLE_WINDOW: int = 20        # 20 × 0.5s = 10-second rolling average
const FPS_FLOOR: float = 15.0
const WAVE_SIZE: int = 4
const WAVE_INTERVAL: float = 3.0
const SPAWN_RADIUS_MIN: float = 15.0
const SPAWN_RADIUS_MAX: float = 50.0

var _fps_samples: Array = []
var _sample_timer: float = 0.0
var _wave_timer: float = 2.0         # first wave after 2s
var _stopped: bool = false
var _total_spawned: int = 0

func _process(delta: float):
	if _stopped:
		return

	_sample_timer += delta
	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer = 0.0
		_fps_samples.append(Engine.get_frames_per_second())
		if _fps_samples.size() > SAMPLE_WINDOW:
			_fps_samples.pop_front()
		if _fps_samples.size() == SAMPLE_WINDOW:
			var avg: float = 0.0
			for s in _fps_samples:
				avg += s
			avg /= SAMPLE_WINDOW
			print("StressSpawner: avg=%.1f fps | enemies=%d" % [avg, _total_spawned])
			if avg <= FPS_FLOOR:
				_stopped = true
				print("StressSpawner: STOPPED — FPS limit reached with %d enemies on screen" % _total_spawned)
				return

	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = WAVE_INTERVAL
		_spawn_wave()

func _spawn_wave():
	for i in range(WAVE_SIZE):
		var angle = randf() * TAU
		var r = randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
		var pos = Vector3(cos(angle) * r, 1.0, sin(angle) * r)
		var soldier = EnemySoldierScene.instantiate()
		soldier.faction = randi() % 2
		get_parent().add_child(soldier)
		soldier.global_position = pos
		_total_spawned += 1
	print("StressSpawner: wave spawned — total enemies now %d" % _total_spawned)
