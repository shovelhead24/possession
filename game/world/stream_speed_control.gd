extends RefCounted
## A conservative ceiling: drops immediately, recovers slowly after stable supply.
var limit := INF
var recovery_wait := 0.0
var brake := 0.0
var drive := 1.0

func step(speed: float, safe_limit: float, available: float, delta: float) -> void:
	if not is_finite(limit): limit=safe_limit
	if safe_limit<limit:
		limit=safe_limit;recovery_wait=.75
	else:
		recovery_wait=maxf(0,recovery_wait-delta)
		if recovery_wait==0: limit=move_toward(limit,safe_limit,3.0*delta)
	# Ease off power before reaching the ceiling rather than alternating full
	# throttle and full brake. The zero-distance fallback remains immediate.
	drive=clampf((limit-speed)/4.0,0,1)
	var demand := clampf((speed-limit)/5.0,0,1)
	brake=move_toward(brake,demand,(2.0 if demand>brake else 1.0)*delta)
	if available<=24 and speed>1: brake=1.0;drive=0.0

func reset() -> void:
	limit=INF;recovery_wait=0.0;brake=0.0;drive=1.0
