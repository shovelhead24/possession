extends Node
# M3 — BLIND READABILITY PROBE (docs/grammars.md). Open this scene, F6.
#
# The question: can a human predict what a faction does next from DIEGETIC SIGNAL ALONE -- no UI,
# no internal state, no labels? This is the assumption the whole mid-game rests on
# (docs/consumers.md, "inference not transmission") and the one four comparable projects got wrong
# (STALKER A-Life, Dwarf Fortress, Kenshi, Radiant AI all shipped simulation players could not read).
#
# Design notes that matter for the result being meaningful:
#  - You never see pressures, weights, temperature or the committed intention until after you guess.
#  - Observations are deliberately AMBIGUOUS: several intentions share lines, some lines are noise,
#    some are stale (last cycle's). A probe where the signal maps 1:1 to intent proves nothing.
#  - Factions differ in TEMPERATURE (the decoherence dial). If the dial works, the cold faction
#    should be measurably more predictable than the hot one -- that is a second hypothesis this
#    mock tests for free.
#  - Confidence is recorded per guess. The success criterion is NOT raw accuracy: it is whether
#    confidence tracks correctness. If high-confidence guesses are right and low-confidence ones
#    are not, inference works. If confidence is uncorrelated with accuracy, the player is seeing
#    noise and believing it -- the worst outcome, and invisible without measuring it.
#  - Two baselines are reported, because "better than chance" is the wrong bar: uniform guessing
#    (1/N) is easy to beat by learning base rates alone. The real bar is BASE RATE -- always
#    guessing that faction's most common action. Beating base rate is the only evidence that the
#    player is reading the SIGNAL rather than the statistics.

const REPERTOIRE := ["trade", "raid", "fortify", "feast", "muster"]
const CYCLES_SHOWN := 6        # how much history is visible when predicting
const SEED := 20260729

# Each faction: a baked, time-varying disposition (its "song") + a temperature (legibility).
# disposition[intent] = array of 8 phase weights -- the score says what is LIKELY at each bar.
const FACTIONS := [
	{
		"name": "Ford-town",
		"temp": 0.40,                       # cold: sharp commits, should be readable
		"disposition": {
			"trade":   [0.9, 0.3, 0.2, 0.2, 0.9, 0.3, 0.2, 0.2],   # market every 4 cycles
			"raid":    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
			"fortify": [0.1, 0.2, 0.4, 0.5, 0.1, 0.2, 0.4, 0.5],
			"feast":   [0.3, 0.1, 0.0, 0.0, 0.3, 0.1, 0.0, 0.0],
			"muster":  [0.0, 0.1, 0.2, 0.2, 0.0, 0.1, 0.2, 0.2],
		},
	},
	{
		"name": "Highland hold",
		"temp": 0.75,                       # medium: a raiding season, blurred at the edges
		"disposition": {
			"trade":   [0.2, 0.2, 0.1, 0.1, 0.1, 0.2, 0.3, 0.3],
			"raid":    [0.1, 0.3, 0.7, 0.9, 0.8, 0.4, 0.1, 0.0],   # season, phases 2-5
			"fortify": [0.3, 0.2, 0.1, 0.1, 0.2, 0.4, 0.5, 0.4],
			"feast":   [0.3, 0.1, 0.0, 0.0, 0.0, 0.1, 0.3, 0.4],
			"muster":  [0.2, 0.5, 0.4, 0.2, 0.2, 0.3, 0.2, 0.1],
		},
	},
	{
		"name": "Delta camp",
		"temp": 1.60,                       # hot: decohered, should be genuinely hard
		"disposition": {
			"trade":   [0.4, 0.4, 0.3, 0.4, 0.4, 0.3, 0.4, 0.4],
			"raid":    [0.2, 0.3, 0.3, 0.2, 0.3, 0.3, 0.2, 0.3],
			"fortify": [0.3, 0.3, 0.4, 0.3, 0.3, 0.4, 0.3, 0.3],
			"feast":   [0.3, 0.2, 0.3, 0.3, 0.2, 0.3, 0.3, 0.2],
			"muster":  [0.2, 0.3, 0.3, 0.3, 0.3, 0.2, 0.3, 0.3],
		},
	},
]

# Observation pools. OVERLAP IS THE POINT -- if each line implied one intent this would be a lookup
# table, not a readability test. Lines marked shared appear under several intents.
const OBS := {
	"trade": [
		"a caravan came in off the spinward road",
		"the market ran past dusk",
		"scales and weights out on the square",
		"strangers drinking, nobody minding them",
	],
	"raid": [
		"riders went out before light and have not come back",
		"someone was counting horses",
		"a smith worked all night",
		"the north road is empty in a way it usually is not",
	],
	"fortify": [
		"timber going up the hill, not down",
		"the gate shut early",
		"a smith worked all night",
		"they have started digging along the ditch line",
	],
	"feast": [
		"smoke from more fires than there are households",
		"singing after dark",
		"strangers drinking, nobody minding them",
		"someone slaughtered more than they can eat",
	],
	"muster": [
		"men stood in the square long enough to be counted",
		"someone was counting horses",
		"the gate shut early",
		"boys carrying their fathers' gear",
	],
}
# Pure noise -- unrelated to intent. Present so that not every line means something.
const NOISE := [
	"it rained hard and the ford is up",
	"a dog barked at nothing for an hour",
	"two women argued about a fence",
	"the miller is ill",
	"birds went up off the treeline, no reason given",
]

var _rng := RandomNumberGenerator.new()
var _cycle := 0
var _f := 0                       # faction under observation this round
var _pending := ""                # the intention being predicted (hidden until reveal)
var _history: Array[String] = []
var _pick := ""                   # player's currently selected intention
var _results: Array = []          # {faction, temp, actual, guess, confidence}
var _counts := {}                 # per-faction intent tallies, for the base-rate baseline

var _log: RichTextLabel
var _status: Label
var _pick_row: HBoxContainer
var _conf_row: HBoxContainer


func _ready() -> void:
	_rng.seed = SEED
	for f in FACTIONS:
		_counts[f["name"]] = {}
		for r in REPERTOIRE:
			_counts[f["name"]][r] = 0
	_build_ui()
	_next_round()


# --- simulation -------------------------------------------------------------------------------

func _weights(fi: int, cycle: int) -> Array:
	# baked disposition sampled at this phase = the score at this bar
	var d: Dictionary = FACTIONS[fi]["disposition"]
	var phase: int = cycle % 8
	var w := []
	for r in REPERTOIRE:
		w.append(float(d[r][phase]))
	return w

func _commit(fi: int, cycle: int) -> String:
	# seeded softmax over the baked bias -- same machinery as realization, pointed at intention.
	# temperature is the decoherence dial: cold = sharp commit, hot = flat/straying.
	var w := _weights(fi, cycle)
	var t: float = FACTIONS[fi]["temp"]
	var exps := []
	var total := 0.0
	for x in w:
		var e: float = exp(float(x) / t)
		exps.append(e)
		total += e
	# deterministic per (faction, cycle): observation must never reroll it
	var r := _det_rand(fi, cycle) * total
	var acc := 0.0
	for i in exps.size():
		acc += exps[i]
		if r <= acc:
			return REPERTOIRE[i]
	return REPERTOIRE[REPERTOIRE.size() - 1]

func _det_rand(fi: int, cycle: int) -> float:
	var h := hash("%d:%d:%d" % [SEED, fi, cycle])
	return float(absi(h) % 100000) / 100000.0

func _observe(fi: int, cycle: int, intent: String) -> Array[String]:
	# emit 2-3 diegetic lines: mostly from the intent's pool, sometimes noise, sometimes STALE
	# (last cycle's intent) -- staleness is real in the design (K4), so it belongs in the probe.
	var out: Array[String] = []
	var rr := RandomNumberGenerator.new()
	rr.seed = hash("%d:obs:%d:%d" % [SEED, fi, cycle])
	var pool: Array = OBS[intent].duplicate()
	pool.shuffle()
	out.append(pool[0])
	if rr.randf() < 0.65:
		out.append(pool[1])
	if rr.randf() < 0.30:
		out.append(NOISE[rr.randi() % NOISE.size()])
	if rr.randf() < 0.20 and cycle > 0:
		var prev := _commit(fi, cycle - 1)
		var ppool: Array = OBS[prev]
		out.append(ppool[rr.randi() % ppool.size()])   # stale observation
	out.shuffle()
	return out


# --- rounds -----------------------------------------------------------------------------------

func _next_round() -> void:
	_f = _rng.randi() % FACTIONS.size()
	_cycle += 1
	_history.clear()
	# show recent history for this faction, then ask about the NEXT cycle
	var start: int = maxi(0, _cycle - CYCLES_SHOWN)
	for c in range(start, _cycle):
		var intent := _commit(_f, c)
		_counts[FACTIONS[_f]["name"]][intent] += 1
		var lines := _observe(_f, c, intent)
		_history.append("[b]cycle %d[/b]" % c)
		for l in lines:
			_history.append("    " + l)
	_pending = _commit(_f, _cycle)
	_pick = ""
	_render()

func _render() -> void:
	_log.clear()
	_log.append_text("[b]%s[/b]  —  observations only\n\n" % FACTIONS[_f]["name"])
	for h in _history:
		_log.append_text(h + "\n")
	_log.append_text("\n[i]What do they do in cycle %d?[/i]\n" % _cycle)
	_status.text = "round %d    selected: %s" % [_results.size() + 1, _pick if _pick != "" else "—"]
	_conf_row.visible = _pick != ""

func _on_pick(intent: String) -> void:
	_pick = intent
	_render()

func _on_confidence(conf: String) -> void:
	if _pick == "":
		return
	var correct := _pick == _pending
	_results.append({
		"faction": FACTIONS[_f]["name"], "temp": FACTIONS[_f]["temp"],
		"actual": _pending, "guess": _pick, "confidence": conf, "correct": correct,
	})
	_log.append_text("\n[color=%s]%s — they chose: %s (you said %s, %s confidence)[/color]\n" % [
		"#7fdc7f" if correct else "#dc7f7f",
		"RIGHT" if correct else "WRONG", _pending, _pick, conf])
	await get_tree().create_timer(1.6).timeout
	if _results.size() >= 24:
		_report()
	else:
		_next_round()

func _report() -> void:
	# Two baselines, because "better than chance" is the wrong bar. Uniform (1/N) is beatable by
	# learning base rates alone; BASE RATE (always guess the faction's commonest action) is the
	# only bar whose passing implies the player read the signal rather than the statistics.
	var by_f := {}
	for r in _results:
		if not by_f.has(r["faction"]):
			by_f[r["faction"]] = {"n": 0, "ok": 0, "temp": r["temp"]}
		by_f[r["faction"]]["n"] += 1
		if r["correct"]:
			by_f[r["faction"]]["ok"] += 1
	var hi := {"n": 0, "ok": 0}
	var lo := {"n": 0, "ok": 0}
	for r in _results:
		var b: Dictionary = hi if r["confidence"] == "high" else (lo if r["confidence"] == "low" else {})
		if not b.is_empty():
			b["n"] += 1
			if r["correct"]:
				b["ok"] += 1

	var s := "[b]M3 — BLIND READABILITY PROBE: RESULTS[/b]\n\n"
	var tot := 0
	var tok := 0
	for r in _results:
		tot += 1
		if r["correct"]:
			tok += 1
	s += "overall: %d/%d = %.0f%%\n" % [tok, tot, 100.0 * tok / maxi(tot, 1)]
	s += "uniform-guess baseline: %.0f%%\n" % (100.0 / REPERTOIRE.size())
	# base rate: for each faction, the share of its most common action
	var br_num := 0.0
	var br_den := 0.0
	for fname in _counts:
		var best := 0
		var sum := 0
		for r in _counts[fname]:
			sum += _counts[fname][r]
			best = maxi(best, _counts[fname][r])
		br_num += float(best)
		br_den += float(sum)
	s += "[b]base-rate baseline: %.0f%%[/b]  <- the bar that matters\n\n" % (100.0 * br_num / maxf(br_den, 1.0))
	s += "[b]by faction (does the temperature dial work?)[/b]\n"
	for fname in by_f:
		var d: Dictionary = by_f[fname]
		s += "  %-16s temp %.2f   %d/%d = %.0f%%\n" % [
			fname, d["temp"], d["ok"], d["n"], 100.0 * d["ok"] / maxi(d["n"], 1)]
	s += "\n[b]does confidence track correctness?[/b]  <- the real success criterion\n"
	s += "  high confidence: %d/%d = %.0f%%\n" % [hi["ok"], hi["n"], 100.0 * hi["ok"] / maxi(hi["n"], 1)]
	s += "  low  confidence: %d/%d = %.0f%%\n" % [lo["ok"], lo["n"], 100.0 * lo["ok"] / maxi(lo["n"], 1)]
	s += "\n[i]Reading it: beating BASE RATE means the signal is readable. Cold faction scoring\n"
	s += "above the hot one means the temperature dial does what it claims. High-confidence\n"
	s += "beating low-confidence means you can tell when you know -- which is the whole bet.\n"
	s += "Confidence uncorrelated with accuracy is the bad outcome: reading noise and believing it.[/i]\n"
	_log.clear()
	_log.append_text(s)
	print(s.replace("[b]", "").replace("[/b]", "").replace("[i]", "").replace("[/i]", ""))
	_pick_row.visible = false
	_conf_row.visible = false
	_status.text = "done — %d rounds" % _results.size()


# --- ui ---------------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24; root.offset_top = 24
	root.offset_right = -24; root.offset_bottom = -24
	root.add_theme_constant_override("separation", 10)
	layer.add_child(root)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 17)
	root.add_child(_log)

	_status = Label.new()
	root.add_child(_status)

	_pick_row = HBoxContainer.new()
	root.add_child(_pick_row)
	for r in REPERTOIRE:
		var b := Button.new()
		b.text = r
		b.custom_minimum_size = Vector2(120, 36)
		b.pressed.connect(_on_pick.bind(r))
		_pick_row.add_child(b)

	_conf_row = HBoxContainer.new()
	_conf_row.visible = false
	root.add_child(_conf_row)
	var lbl := Label.new()
	lbl.text = "how sure?  "
	_conf_row.add_child(lbl)
	for c in ["low", "medium", "high"]:
		var b := Button.new()
		b.text = c
		b.custom_minimum_size = Vector2(110, 32)
		b.pressed.connect(_on_confidence.bind(c))
		_conf_row.add_child(b)
