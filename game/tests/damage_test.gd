extends SceneTree
const Damage = preload("res://damage.gd")

# Headless check of the shared locational damage model (game/damage.gd) and one real
# consumer routing through it (Creature). Run:
#   godot --headless --path game -s res://tests/damage_test.gd

func _initialize() -> void:
	var fails := 0
	fails += _num("head mult",       Damage.zone_mult("head"),  2.5)
	fails += _num("torso mult",      Damage.zone_mult("torso"), 1.0)
	fails += _num("limb mult",       Damage.zone_mult("limb"),  0.65)
	fails += _num("unknown->torso",  Damage.zone_mult(""),      1.0)
	fails += _num("resolve head",    Damage.resolve(10.0, "head"), 25.0)
	fails += _num("resolve default", Damage.resolve(10.0, ""),     10.0)
	fails += _zone("classify crown", Damage.classify(1.7, 1.8), "head")
	fails += _zone("classify chest", Damage.classify(1.2, 1.8), "torso")
	fails += _zone("classify shin",  Damage.classify(0.4, 1.8), "limb")
	fails += _zone("classify zero-h", Damage.classify(1.0, 0.0), "torso")

	# Real consumer: a creature (which had no health at all) now routes through the model.
	var c := Creature.new()
	c.max_health = 40.0
	c.health = 40.0
	var died := [false]
	c.died.connect(func(): died[0] = true)
	c.take_damage(10.0, "head")            # 25 -> 15
	fails += _num("creature head hit", c.health, 15.0)
	c.take_damage(10.0, "head")            # another 25 -> dead
	fails += _num("creature dead flag", 1.0 if c.dead else 0.0, 1.0)
	fails += _num("creature died signal", 1.0 if died[0] else 0.0, 1.0)

	if fails == 0:
		print("DAMAGE SELFTEST: PASS")
	else:
		print("DAMAGE SELFTEST: FAIL (", fails, " failed)")
	quit(1 if fails > 0 else 0)

func _num(label: String, got: float, want: float) -> int:
	if abs(got - want) < 0.001:
		print("  ok  ", label, " = ", got)
		return 0
	print("  BAD ", label, " got ", got, " want ", want)
	return 1

func _zone(label: String, got: String, want: String) -> int:
	if got == want:
		print("  ok  ", label, " = ", got)
		return 0
	print("  BAD ", label, " got '", got, "' want '", want, "'")
	return 1
