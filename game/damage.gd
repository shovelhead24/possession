extends RefCounted

# NO class_name. A class_name only resolves once the Godot EDITOR has registered it in the global
# class cache, and this project runs headless -- consumers preload this file into a const instead.
# Exactly the failure VehicleDef caused on 2026-08-15, which left the project unparseable and
# silently stalled three queue ticks.

# Shared locational damage model. One zone table, one resolver, one classifier — so a
# headshot means the same thing whether it lands on the player, an enemy_controller grunt,
# an enemy_soldier or a creature. Consumers keep their own health pool but route the
# number through here, instead of each re-inventing "how much does a hit hurt".
#
# Locality is two steps: classify() turns a hit's height on the body into a zone name,
# resolve() turns (raw amount, zone) into scaled damage. take_damage(amount, zone) on each
# consumer calls resolve(); the shooter that knows WHERE it hit calls classify() first.

const ZONES := {
	"head": 2.5,
	"torso": 1.0,
	"limb": 0.65,
}
const DEFAULT_ZONE := "torso"

# Fraction-of-height thresholds for classify(). Top slice is head, bottom slice is limbs.
const HEAD_FRAC := 0.82
const LIMB_FRAC := 0.45

static func zone_mult(zone: String) -> float:
	return ZONES.get(zone, ZONES[DEFAULT_ZONE])

static func resolve(amount: float, zone: String) -> float:
	return amount * zone_mult(zone)

# rel_height: hit point height above the body's feet (world metres).
# stand_height: the body's standing height (world metres). Returns a zone name.
static func classify(rel_height: float, stand_height: float) -> String:
	if stand_height <= 0.0:
		return DEFAULT_ZONE
	var frac := rel_height / stand_height
	if frac >= HEAD_FRAC:
		return "head"
	if frac <= LIMB_FRAC:
		return "limb"
	return "torso"
