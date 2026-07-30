extends Node
# M3 — BLIND READABILITY PROBE, run 2 (docs/grammars.md, mocks/M3-READABILITY-FINDINGS.md)
#
# Question: can a human predict what a faction does next from DIEGETIC SIGNAL ALONE?
# This is the assumption the mid-game rests on (docs/consumers.md, inference-not-transmission) and
# the one four comparable projects got wrong.
#
# RUN 1 FAILED (42% vs a 57% base rate) and the probe was largely to blame. Three defects, all fixed:
#
#  1. Observations described the PAST intent, so predicting the future meant extrapolating a hidden
#     period from too short a window. Now observations are LEADING INDICATORS -- preparation for what
#     comes next. You read what they are getting ready to do, which is how tells work in life.
#  2. Signals were either pure fog (shared lines) or would have been pure lookup (one tell per
#     intent). Neither is inference. Now every line carries a WEIGHT VECTOR over intents, and lines
#     that "rhyme" -- share a semantic field -- pull together. You infer from CONVERGENT WEAK
#     EVIDENCE: three lines about departure outweigh one about grain.
#  3. Learning the pattern reduced to counting cycles, which is arithmetic, not reading. The period
#     is still there as bias, but it is no longer the readable channel and the cycle number is gone.
#
# Design notes:
#  - One faction per session, with a TRAINING phase (reveal, unscored) before scoring -- you are
#    meant to be reading a neighbour you have watched, not cold-reading a stranger.
#  - The answer key is printed at the end. A probe that never reveals its mechanism teaches nothing,
#    which was a real failure of run 1.
#  - Base rate is reported alongside accuracy, because beating 1-in-5 is trivial and meaningless.

# More specific than trade/raid/fortify: an outcome you can picture is both better to predict and
# legible later as a consequence. Keys stay short; LABEL is what the player reads.
const REPERTOIRE := ["caravan", "ride", "dig_in", "feast", "callup"]
const LABEL := {
	"caravan": "send a caravan spinward",
	"ride":    "ride out against the hill farms",
	"dig_in":  "close the walls and dig in",
	"feast":   "hold a feast",
	"callup":  "call up fighting men",
}
const PERIOD := 8
const TRAIN_ROUNDS := 12
const SCORED_ROUNDS := 24
const SEED := 20260729

# --- the faction's baked song: a time-varying prior over the repertoire (simulation.md) -----------
# Deliberately flattened vs run 1 so no single action dominates -- if base rate is high, reading is
# pointless. Structure is real (market peaks, a raid window, defensive phases) but nothing is free.
const DISPOSITION := {
	"caravan": [0.9, 0.2, 0.7, 0.1, 0.8, 0.2, 0.6, 0.1],
	"ride":    [0.0, 0.1, 0.1, 0.7, 0.0, 0.2, 0.2, 0.8],
	"dig_in":  [0.2, 0.7, 0.2, 0.5, 0.2, 0.8, 0.2, 0.4],
	"feast":   [0.6, 0.1, 0.3, 0.0, 0.6, 0.1, 0.4, 0.0],
	"callup":  [0.1, 0.6, 0.1, 0.7, 0.1, 0.5, 0.2, 0.7],
}
const TEMP := 0.55

# --- ROUTINES, MODULATED (run 2b) ---------------------------------------------------------------
# Superseded the "tell" approach: a line like "they took the dogs in, which they only do before they
# go out" is an on-the-nose synthesised phrase that ANNOUNCES the answer. Nothing in a real place
# announces itself.
#
# Instead: the settlement runs the SAME routine events every cycle -- market, forge, gate, herds,
# hearth, road. That routine is the Pulse (factions.md). Intent does not add special lines; it
# MODULATES the routine: the market runs thin, the forge runs late, the gate shuts early. The player
# learns the baseline during training, then reads DEVIATION. Several deviations coalescing is the
# signal, and no single one is decisive because modulations are shared between intents.
#
# Consequences: one event vocabulary regardless of intent (cheap), the signal lives in deviation
# rather than content (unannounceable), and it requires knowing the place (which is the fiction).
const ROUTINES := ["market", "forge", "gate", "herds", "hearth", "road"]

# routine -> intent -> how that routine looks when this is coming. Shared phrasings across intents
# are deliberate ambiguity.
const MODULATION := {
	"market": {
		"caravan": "the market ran late and the square stayed full",
		"ride":    "the market was thin — half the stalls never opened",
		"dig_in":  "the market packed up early, everyone watching the road",
		"feast":   "the market sold out of everything before midday",
		"callup":  "the market was quiet, and mostly women",
	},
	"forge": {
		"caravan": "the forge was cold by afternoon",
		"ride":    "the forge ran past dark",
		"dig_in":  "the forge has been turning out hinges and brackets",
		"feast":   "the forge was cold; the smith was drinking",
		"callup":  "the forge ran past dark",
	},
	"gate": {
		"caravan": "the gate stood open into the evening",
		"ride":    "the gate was unbarred at an odd hour",
		"dig_in":  "the gate shut early, and stayed shut",
		"feast":   "the gate stood open and nobody was watching it",
		"callup":  "there were more men on the gate than it needs",
	},
	"herds": {
		"caravan": "stock moved down to the pens for sorting",
		"ride":    "the horses are not in the low field where they usually are",
		"dig_in":  "the herds came in close, tighter than the grazing needs",
		"feast":   "someone slaughtered more than they can eat",
		"callup":  "boys are doing the herding, which is not their work",
	},
	"hearth": {
		"caravan": "strangers drinking, nobody minding them",
		"ride":    "people ate early and without much talk",
		"dig_in":  "the stores were counted twice",
		"feast":   "the long tables are out in the yard",
		"callup":  "families eating together who normally do not",
	},
	"road": {
		"caravan": "wheel ruts, fresh, heading spinward",
		"ride":    "the north road is empty in a way it usually is not",
		"dig_in":  "nobody has gone further than the ditch line in days",
		"feast":   "people arriving who do not live here",
		"callup":  "the same riders going out and coming back, all week",
	},
}
# Pure noise -- routine that carries nothing this cycle.
const FLAT := {
	"market": "the market ran, about as usual",
	"forge":  "the forge ran, about as usual",
	"gate":   "the gate opened and shut at the usual hours",
	"herds":  "the herds went out and came back",
	"hearth": "people ate and went to bed",
	"road":   "the road was as busy as it ever is",
}


var _cycle := 0
var _pending := ""
var _pick := ""
var _round := 0
var _scored: Array = []
var _counts := {}
var _log: RichTextLabel
var _status: Label
var _pick_row: HBoxContainer


func _ready() -> void:
	for r in REPERTOIRE:
		_counts[r] = 0
	_build_ui()
	_next_round()


# --- simulation ---------------------------------------------------------------------------------

func _commit(cycle: int) -> String:
	# seeded softmax over the baked bias -- the realization machinery pointed at intention.
	# deterministic per cycle: observation must never reroll it.
	var phase: int = cycle % PERIOD
	var exps := []
	var total := 0.0
	for r in REPERTOIRE:
		var e: float = exp(float(DISPOSITION[r][phase]) / TEMP)
		exps.append(e)
		total += e
	var h := hash("%d:commit:%d" % [SEED, cycle])
	var roll := (float(absi(h) % 100000) / 100000.0) * total
	var acc := 0.0
	for i in exps.size():
		acc += exps[i]
		if roll <= acc:
			return REPERTOIRE[i]
	return REPERTOIRE[REPERTOIRE.size() - 1]

func _signals_for(cycle: int) -> Array[String]:
	# Report the SAME routines every cycle -- the settlement's ordinary life. What varies is how each
	# one is running. Most routines are modulated by the coming intent; some run flat (carrying
	# nothing); one is occasionally modulated by a DIFFERENT intent, which is the honest ambiguity
	# that stops any single line being decisive. Presenting all six every time is deliberate: the
	# player must learn the baseline before deviation means anything, and an absent routine would
	# itself be a tell.
	var intent := _commit(cycle)
	var rr := RandomNumberGenerator.new()
	rr.seed = hash("%d:sig2:%d" % [SEED, cycle])
	var out: Array[String] = []
	var order := ROUTINES.duplicate()
	order.shuffle()
	for routine in order:
		var roll := rr.randf()
		if roll < 0.58:
			out.append(MODULATION[routine][intent])          # signal
		elif roll < 0.78:
			out.append(FLAT[routine])                        # carries nothing
		else:
			var other: String = REPERTOIRE[rr.randi() % REPERTOIRE.size()]
			out.append(MODULATION[routine][other])           # misleading
	return out


# --- rounds -------------------------------------------------------------------------------------

func _is_training() -> bool:
	return _round < TRAIN_ROUNDS

func _next_round() -> void:
	_round += 1
	_cycle += 1
	_pending = _commit(_cycle)
	_counts[_pending] += 1
	_pick = ""
	_log.clear()
	var phase_txt := "[color=#8fb3d9]TRAINING %d/%d — you will be shown the answer[/color]" % [_round, TRAIN_ROUNDS] \
		if _is_training() else "[color=#d9c48f]SCORED %d/%d[/color]" % [_round - TRAIN_ROUNDS, SCORED_ROUNDS]
	_log.append_text("%s\n\n[b]Ford-town[/b] — what people have noticed lately:\n\n" % phase_txt)
	for s in _signals_for(_cycle):
		_log.append_text("    • %s\n" % s)
	_log.append_text("\n[i]What are they about to do?[/i]\n")
	_status.text = "selected: —"

func _on_pick(intent: String) -> void:
	_pick = intent
	var correct := _pick == _pending
	if not _is_training():
		_scored.append({"actual": _pending, "guess": _pick, "correct": correct})
	_log.append_text("\n[color=%s]%s — they %s[/color]\n" % [
		"#7fdc7f" if correct else "#dc7f7f",
		"RIGHT" if correct else "WRONG (you said: %s)" % LABEL[_pick], LABEL[_pending]])
	_status.text = "…"
	await get_tree().create_timer(1.3).timeout
	if _round >= TRAIN_ROUNDS + SCORED_ROUNDS:
		_report()
	else:
		_next_round()

func _report() -> void:
	var ok := 0
	for r in _scored:
		if r["correct"]:
			ok += 1
	var n: int = maxi(_scored.size(), 1)
	# base rate over the WHOLE session -- the bar that matters, since always guessing the commonest
	# action beats 1-in-5 without reading anything
	var best := 0
	var tot := 0
	for r in _counts:
		tot += _counts[r]
		best = maxi(best, _counts[r])
	var s := "[b]M3 RUN 2 — RESULTS[/b]\n\n"
	s += "scored accuracy:      %d/%d = %.0f%%\n" % [ok, n, 100.0 * ok / n]
	s += "uniform baseline:     %.0f%%\n" % (100.0 / REPERTOIRE.size())
	s += "[b]base-rate baseline:   %.0f%%[/b]  <- the bar\n\n" % (100.0 * best / maxi(tot, 1))
	s += "[b]ANSWER KEY — how it actually worked[/b]\n\n"
	s += "Every line you saw carried a hidden weight toward one or more actions. Lines in the same\n"
	s += "'field' rhyme, and several of them together are the signal:\n\n"
	s += "  DEPARTURE (dogs in, empty road, horses counted)  -> raid\n"
	s += "  IRON      (smith, whetstones, arrowheads)        -> raid / muster / fortify\n"
	s += "  EARTH     (timber, ditch, gate shut)             -> fortify\n"
	s += "  PLENTY    (tables out, slaughter, singing)       -> feast\n"
	s += "  EXCHANGE  (toll-keeper, scales, caravan)         -> trade\n"
	s += "  COUNTING  (square, spear, a list read out)       -> muster\n"
	s += "  NOISE     (rain, dog, fence, miller)             -> nothing\n\n"
	s += "Each round also planted ~45%% of the time one line pointing the WRONG way, and often a\n"
	s += "noise line. So no single line was decisive -- you were meant to weigh several.\n\n"
	s += "Underneath, the faction has a baked 8-phase disposition (a market rhythm, a raid window\n"
	s += "late in the cycle, defensive phases between) sampled by seeded softmax at temperature\n"
	s += "%.2f. The cycle number was deliberately hidden this run: counting is arithmetic, not\n" % TEMP
	s += "reading, and it should not be the way to win.\n"
	_log.clear()
	_log.append_text(s)
	print(s.replace("[b]", "").replace("[/b]", ""))
	_pick_row.visible = false
	_status.text = "done"


# --- ui -----------------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 28; root.offset_top = 24
	root.offset_right = -28; root.offset_bottom = -24
	root.add_theme_constant_override("separation", 12)
	layer.add_child(root)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 18)
	root.add_child(_log)
	_status = Label.new()
	root.add_child(_status)
	_pick_row = HBoxContainer.new()
	root.add_child(_pick_row)
	for r in REPERTOIRE:
		var b := Button.new()
		b.text = LABEL[r]
		b.custom_minimum_size = Vector2(200, 44)
		b.pressed.connect(_on_pick.bind(r))
		_pick_row.add_child(b)
