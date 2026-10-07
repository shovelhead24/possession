extends RefCounted

enum Relay { HOSTILE, SECURED_OFFLINE, LINKING, OPERATIONAL }
var relay: Relay = Relay.HOSTILE
var approach := "RIDGE"
var support_available := true
var report := "Frontier link unavailable."

func advance_relay() -> void:
	relay = mini(int(relay) + 1, int(Relay.OPERATIONAL)) as Relay
	report = ["Frontier hostile", "Site secured. Restore the link.", "Antenna acquiring backbone", "Relay online. Support acknowledges."][relay]

func connected() -> bool:
	return relay == Relay.OPERATIONAL

func select_approach(value: String) -> void:
	if value in ["RIDGE", "VALLEY"]:
		approach = value

func request_support() -> bool:
	if not connected():
		report = "NO COMMS / NO STRIKE"
		return false
	if not support_available:
		report = "LINK GOOD / SUPPORT UNAVAILABLE"
		return false
	report = "LINK GOOD / STRIKE ACKNOWLEDGED"
	return true

func interrupt_link() -> void:
	relay = Relay.SECURED_OFFLINE
	report = "LINK LOST / LOCAL MAP RETAINED"
