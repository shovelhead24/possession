extends Node
# CHAIN — a text-adventure vertical slice of the whole design. Open this scene, F6.
#
# What it is testing, in order of importance:
#   1. PERTURBATION READS. You cannot stop things; you can tilt them. Does tilting feel meaningful
#      and legible? (simulation.md: fixed in outcome, negotiable in tempo.)
#   2. SECOND-ORDER CONSEQUENCE. Acting on one settlement should surface somewhere else, through
#      the chain, without being scripted. Per draws.md these ARE the mid-game's pull.
#   3. EARNED WEAKNESS. Each settlement has an exploitable bias that is inferred, never offered --
#      and shallow play must still work (seven-souls.md).
#   4. CROSS-RUN LOCAL PRESSURE. Regions you were active in start hotter next run. Khaibit writes
#      syncopations: it perturbs inputs, never scripts outcomes (operators.md).
#
# Deliberately inherited from M3 (mocks/M3-READABILITY-FINDINGS.md):
#   - settlements emit MODULATED ROUTINES, never announcements. Signal lives in deviation.
#   - no modulation string is unique to one intent. Uniqueness of phrasing IS a tell, whatever the
#     phrasing describes -- that bug survived two redesigns before playtest caught it.
#   - no missions. Nobody assigns you anything. There is no win condition, only a run and an ending.

const SAVE := "user://chain_khaibit.json"
const RUN_CYCLES := 30

# --- the chain (factions.md: at most two arc-neighbours each) ------------------------------------
const PLACES := ["Ardvane", "Corrin", "Slievan"]
const NEIGHBOURS := {
	"Ardvane": ["Corrin"],
	"Corrin":  ["Ardvane", "Slievan"],
	"Slievan": ["Corrin"],
}
const FLAVOUR := {
	"Ardvane": "a ford town, wide and muddy, everything passing through it",
	"Corrin":  "a hold above the treeline, stone and wind, watching both ways",
	"Slievan": "a coast settlement, boats drawn up, salt in everything",
}
# Hidden biases -- EARNED, never offered. Discovered by watching, then usable.
const BIAS := {
	"Ardvane": {"key": "tolls", "desc": "Ardvane will always choose the option that keeps the ford open. Threaten trade and it folds."},
	"Corrin":  {"key": "taboo", "desc": "Corrin will not act on a day it considers ill-omened. Give it an omen and it waits."},
	"Slievan": {"key": "kin",   "desc": "Slievan counts kin above cattle. It will pay a fine it cannot afford to get a hostage back."},
}

# People, so the prose has somebody in it. A flat pool, not characters -- they carry no state.
const NAMES := {
	"Ardvane": ["Ferran", "the Boru woman", "old Mael", "the ferryman"],
	"Corrin":  ["Sgian", "the reeve", "Nass of the upper house", "a woman with a broken hand"],
	"Slievan": ["Tolm", "Bride Cathan", "the boatwright", "a boy minding nets"],
}

const ACTIONS := ["lift", "reprisal", "fine", "refuse", "market", "herds_down", "feast", "moot"]
const ACTION_TEXT := {
	"lift": "lifted cattle from", "reprisal": "rode in reprisal against",
	"fine": "offered a fine in cattle to", "refuse": "refused the fine from",
	"market": "held market", "herds_down": "brought the herds in early",
	"feast": "held a feast", "moot": "held a moot",
}

# routine -> intent -> line. SHARED phrasings across intents are mandatory, not decorative.
const MOD := {
	"herds": {
		"lift": "the horses are not in the low field", "reprisal": "the horses are not in the low field",
		"fine": "stock being sorted out of the main herd", "refuse": "the herds came in close, tighter than grazing needs",
		"market": "stock moved down to the pens", "herds_down": "the herds came in close, tighter than grazing needs",
		"feast": "someone slaughtered more than they can eat", "moot": "the herds went out late",
	},
	"forge": {
		"lift": "the forge ran past dark", "reprisal": "the forge ran past dark",
		"fine": "the forge was cold by afternoon", "refuse": "the forge ran past dark",
		"market": "the forge was cold by afternoon", "herds_down": "the forge turning out hinges and brackets",
		"feast": "the forge was cold; the smith was drinking", "moot": "the forge was cold by afternoon",
	},
	"gate": {
		"lift": "the gate unbarred at an odd hour", "reprisal": "the gate unbarred at an odd hour",
		"fine": "the gate stood open into the evening", "refuse": "more men on the gate than it needs",
		"market": "the gate stood open into the evening", "herds_down": "the gate shut early, and stayed shut",
		"feast": "the gate stood open and nobody watching it", "moot": "more men on the gate than it needs",
	},
	"hearth": {
		"lift": "people ate early and without much talk", "reprisal": "people ate early and without much talk",
		"fine": "the stores were counted twice", "refuse": "the stores were counted twice",
		"market": "strangers drinking, nobody minding them", "herds_down": "the stores were counted twice",
		"feast": "the long tables are out in the yard", "moot": "families eating together who normally do not",
	},
}
const FLAT := {
	"herds": "the herds went out and came back",
	"forge": "the forge ran, about as usual",
	"gate": "the gate opened and shut at the usual hours",
	"hearth": "people ate and went to bed",
}

var _cycle := 0
var _here := "Ardvane"
var _st := {}                  # per-place live state
var _khaibit := {}             # cross-run: extra pressure per place
var _activity := {}            # this run: where the player spent effort
var _known := {}               # biases the player has inferred
var _log_lines: Array[String] = []
var _out: RichTextLabel
var _entry: LineEdit
var _rng := RandomNumberGenerator.new()
var _transcript: FileAccess = null
const TRANSCRIPT := "user://chain_transcript.txt"


func _ready() -> void:
	_rng.randomize()
	# append, never truncate -- runs must be comparable, since Khaibit only shows up across them
	_transcript = FileAccess.open(TRANSCRIPT, FileAccess.READ_WRITE)
	if _transcript == null:
		_transcript = FileAccess.open(TRANSCRIPT, FileAccess.WRITE)
	else:
		_transcript.seek_end()
	if _transcript:
		_transcript.store_line("\n#RUN %s" % Time.get_datetime_string_from_system())
	_load_khaibit()
	if _transcript:
		_transcript.store_line("#KHAIBIT-IN " + JSON.stringify(_khaibit))
	for p in PLACES:
		_st[p] = {
			"pressure": 0.15 + float(_khaibit.get(p, 0.0)),   # <- Khaibit: hotter where you worked
			"grievance": {}, "cattle": 40 + _rng.randi() % 20,
			"last": "", "phase_off": _rng.randi() % 8,
		}
		for q in PLACES:
			if q != p:
				_st[p]["grievance"][q] = 0.0
		_activity[p] = 0
		_known[p] = false
	_build_ui()
	_say("[b]CHAIN[/b] — three settlements, thirty cycles, no missions.\n")
	if not _khaibit.is_empty():
		_say("[i]Something remembers the last time. Some places will be less patient.[/i]\n")
	_say("Commands: [b]watch[/b]  [b]go <place>[/b]  [b]ask[/b]  [b]warn <place>[/b]  [b]incite[/b]  [b]gift[/b]  [b]wait[/b]  [b]think[/b]  [b]leave[/b]\n")
	_arrive()
	if "--autoplay" in OS.get_cmdline_user_args():
		_autoplay()

func _autoplay() -> void:
	# Drives a whole run with random verbs so content changes can be smoke-tested without a human
	# at the keyboard. It is NOT a substitute for playing -- it proves the paths execute and lets
	# the prose be read in bulk. Whether any of it reads is still the meat model's call.
	var verbs := ["watch", "watch", "ask", "ask", "wait", "think", "gift", "incite",
		"go Ardvane", "go Corrin", "go Slievan", "warn Corrin", "warn Slievan"]
	while _cycle < RUN_CYCLES and _entry.editable:
		_do(verbs[_rng.randi() % verbs.size()])
	if _entry.editable:
		_do("leave")
	get_tree().quit()


# --- simulation ----------------------------------------------------------------------------------

func _disposition(place: String, cycle: int) -> Dictionary:
	# baked, time-varying prior over the repertoire, perturbed by live pressure and grievance.
	# pressure/grievance BIAS the distribution -- they never select an outcome.
	var s: Dictionary = _st[place]
	var phase: int = (cycle + int(s["phase_off"])) % 8
	var pr: float = clampf(float(s["pressure"]), 0.0, 1.0)
	var top_g := 0.0
	for q in s["grievance"]:
		top_g = maxf(top_g, float(s["grievance"][q]))
	var w := {
		"market":     0.7 - 0.4 * pr + (0.3 if phase in [0, 4] else 0.0),
		"feast":      0.4 - 0.4 * pr + (0.3 if phase == 2 else 0.0),
		"moot":       0.3 + 0.3 * top_g,
		"herds_down": 0.1 + 0.9 * pr,
		"lift":       0.05 + 0.7 * pr + (0.3 if phase in [3, 7] else 0.0),
		"reprisal":   0.9 * top_g,
		"fine":       0.5 * top_g * (1.0 - pr),
		"refuse":     0.6 * top_g * pr,
	}
	return w

func _commit(place: String, cycle: int) -> String:
	var w := _disposition(place, cycle)
	var temp := 0.45
	var total := 0.0
	var exps := {}
	for k in w:
		var e: float = exp(maxf(float(w[k]), 0.0) / temp)
		exps[k] = e
		total += e
	var roll := _rng.randf() * total
	var acc := 0.0
	for k in exps:
		acc += exps[k]
		if roll <= acc:
			return k
	return "market"

func _target(place: String) -> String:
	var best := ""
	var bg := -1.0
	for q in NEIGHBOURS[place]:
		var g: float = float(_st[place]["grievance"].get(q, 0.0))
		if g > bg:
			bg = g
			best = q
	return best if best != "" else NEIGHBOURS[place][0]

func _tick() -> void:
	# every settlement commits and acts. Nothing waits for the player; witnessing is passive.
	_cycle += 1
	var events: Array[String] = []
	var news: Array[String] = []
	_log_state("tick")
	# snapshot, so threshold CROSSINGS can be reported. Run 2 lost 80% of Corrin's herd and never
	# said so once -- the state was simulated to the head and never reached a player. consumer-audit.
	var before := {}
	for p in PLACES:
		before[p] = {"cattle": int(_st[p]["cattle"]), "pressure": float(_st[p]["pressure"])}
	for p in PLACES:
		var act := _commit(p, _cycle)
		var s: Dictionary = _st[p]
		s["last"] = act
		var tgt := _target(p)
		match act:
			"lift":
				# you can only take what is there. Unclamped this drove Corrin to -54 head, and nobody
				# could tell, because the number was never shown to anyone.
				var n: int = mini(4 + _rng.randi() % 6, int(_st[tgt]["cattle"]))
				if n <= 0:
					s["pressure"] = minf(float(s["pressure"]) + 0.1, 1.0)
					events.append("%s rode on %s and found the pens already bare" % [p, tgt])
				else:
					_st[tgt]["cattle"] = int(_st[tgt]["cattle"]) - n
					s["cattle"] = int(s["cattle"]) + n
					_st[tgt]["grievance"][p] = minf(float(_st[tgt]["grievance"][p]) + 0.45, 1.0)
					_st[tgt]["pressure"] = minf(float(_st[tgt]["pressure"]) + 0.15, 1.0)
					events.append("%s lifted %d head from %s" % [p, n, tgt])
			"reprisal":
				var n2: int = mini(3 + _rng.randi() % 5, int(_st[tgt]["cattle"]))
				_st[tgt]["cattle"] = int(_st[tgt]["cattle"]) - n2
				s["grievance"][tgt] = maxf(float(s["grievance"][tgt]) - 0.35, 0.0)
				_st[tgt]["pressure"] = minf(float(_st[tgt]["pressure"]) + 0.2, 1.0)
				if n2 <= 0:
					events.append("%s rode against %s. There was nothing left to take" % [p, tgt])
				else:
					events.append("%s rode in reprisal against %s and left %d head short" % [p, tgt, n2])
			"fine":
				var n3: int = mini(3 + _rng.randi() % 4, int(s["cattle"]))
				if n3 <= 0:
					events.append("%s has nothing left to settle with, and says so" % p)
				else:
					s["cattle"] = int(s["cattle"]) - n3
					_st[tgt]["cattle"] = int(_st[tgt]["cattle"]) + n3
					_st[tgt]["grievance"][p] = maxf(float(_st[tgt]["grievance"][p]) - 0.5, 0.0)
					events.append("%s paid %d head to %s to settle it" % [p, n3, tgt])
			"refuse":
				_st[tgt]["grievance"][p] = minf(float(_st[tgt]["grievance"][p]) + 0.3, 1.0)
				s["pressure"] = minf(float(s["pressure"]) + 0.1, 1.0)
				events.append("%s refused to settle with %s" % [p, tgt])
			"herds_down":
				s["pressure"] = minf(float(s["pressure"]) + 0.05, 1.0)
			"market", "feast":
				s["pressure"] = maxf(float(s["pressure"]) - 0.12, 0.0)
			"moot":
				s["pressure"] = maxf(float(s["pressure"]) - 0.05, 0.0)
		s["pressure"] = maxf(float(s["pressure"]) - 0.01, 0.0)   # slow decay
	# second-order: a neighbour's turmoil raises your own pressure, unprompted
	for p in PLACES:
		for q in NEIGHBOURS[p]:
			if float(_st[q]["pressure"]) > 0.6:
				_st[p]["pressure"] = minf(float(_st[p]["pressure"]) + 0.03, 1.0)
	# CROSSINGS become news. Events are bubble-limited; a settlement going under is not -- it is
	# heard three links away as hearsay, and that hearsay is the draw that moves the player.
	for p in PLACES:
		var c0: int = int(before[p]["cattle"])
		var c1: int = int(_st[p]["cattle"])
		var r0: float = float(before[p]["pressure"])
		var r1: float = float(_st[p]["pressure"])
		if c0 > 25 and c1 <= 25:
			news.append("%s is thinning out, %d head where there were half again as many" % [p, c1])
		if c0 > 12 and c1 <= 12:
			news.append("%s is down to %d head. That is not a herd, that is seed stock" % [p, c1])
		if r0 <= 0.75 and r1 > 0.75:
			news.append("%s has put men on the wall and left them there" % p)
		if r0 >= 0.25 and r1 < 0.25:
			news.append("%s has stood down. Gates open, herds out wide" % p)
	for nw in news:
		if nw.begins_with(_here):
			_say("[color=#d9a86f]· %s[/color]" % nw)
		else:
			var carrier: String = ["Word up the road", "A trader has it", "It gets here by evening",
				"Somebody came through with it"][_rng.randi() % 4]
			_say("[color=#d9a86f]%s — %s.[/color]" % [carrier, nw])
	# only events in your bubble reach you (R4): here, your place and its neighbours
	for e in events:
		var vis := false
		for p in [_here] + NEIGHBOURS[_here]:
			if e.begins_with(p):
				vis = true
		if vis:
			_say("[color=#c8b48f]· %s[/color]" % e)

func _routines(place: String) -> void:
	var intent := _commit(place, _cycle + 1)     # LEADING indicator: preparation for next cycle
	var rr := RandomNumberGenerator.new()
	rr.seed = hash("%s:%d" % [place, _cycle])
	for routine in MOD:
		var roll := rr.randf()
		if roll < 0.60:
			_say("    " + MOD[routine][intent])
		elif roll < 0.80:
			_say("    " + FLAT[routine])
		else:
			_say("    " + MOD[routine][ACTIONS[rr.randi() % ACTIONS.size()]])


# --- commands ------------------------------------------------------------------------------------

# CONDITION is observable; INTENTION is inferred. M3's lesson was about predicting what a place
# will DO -- that stays behind modulated routines. What state a place is IN is visible to anyone
# who walks in, and hiding it just starved the prose of anything to be made of.
func _condition(place: String) -> Array:
	var s: Dictionary = _st[place]
	var c := int(s["cattle"])
	var pr := float(s["pressure"])
	var out: Array = []
	if c <= 12:
		out.append("The pens are all but empty. %d head, and people counting them again." % c)
	elif c <= 25:
		out.append("Thin herds — %d head, where the ground would carry twice that." % c)
	elif c >= 62:
		out.append("Cattle everywhere, %d head, more than the grazing wants." % c)
	else:
		out.append("%d head in the pens, about what the ground carries." % c)
	if pr > 0.8:
		out.append("Men on the wall who should be at work. Nobody is pretending otherwise.")
	elif pr > 0.55:
		out.append("The gate is watched. Nobody goes out alone.")
	elif pr < 0.15:
		out.append("Doors open, children out past the ditch.")
	return out

# The draw. What you can see from here of somewhere else -- indirect, never a marker.
func _horizon(place: String) -> Array:
	var out: Array = []
	for q in NEIGHBOURS[place]:
		var qs: Dictionary = _st[q]
		var qp := float(qs["pressure"])
		var qc := int(qs["cattle"])
		if qc <= 12:
			out.append("Nothing moves on the %s road but people leaving it." % q)
		elif qp > 0.75:
			out.append("Smoke over %s, more of it than cooking accounts for." % q)
		elif qp > 0.55:
			out.append("Riders came down from %s and did not stop to talk." % q)
		elif qc >= 62:
			out.append("They are driving cattle somewhere up by %s, and taking their time about it." % q)
	return out

func _talk(place: String) -> String:
	var who: String = NAMES[place][_rng.randi() % NAMES[place].size()]
	var s: Dictionary = _st[place]
	var pr := float(s["pressure"])
	var c := int(s["cattle"])
	if pr > 0.75:
		return "%s will not stop to talk, and nor will anyone. They are watching the road." % who
	var worst := ""
	var wg := 0.0
	for q in s["grievance"]:
		if float(s["grievance"][q]) > wg:
			wg = float(s["grievance"][q])
			worst = q
	if wg > 0.5:
		return "%s talks about %s, and what is owed, and how long it has been owed." % [who, worst]
	if c <= 15:
		return "%s does the sum out loud — %d head — and then does it again." % [who, c]
	var n: String = NEIGHBOURS[place][_rng.randi() % NEIGHBOURS[place].size()]
	var ns: Dictionary = _st[n]
	if float(ns["pressure"]) > 0.7:
		return "%s says nobody has come down from %s in days. Not even to trade." % [who, n]
	if int(ns["cattle"]) <= 20:
		return "%s heard %s is selling things %s should not be selling." % [who, n, n]
	if int(ns["cattle"]) > c + 15:
		return "%s mentions how well %s is doing, in the tone people keep for that." % [who, n]
	return "%s talks about weather, and the ford, and a boat that never came back." % who

func _arrive() -> void:
	_say("\n[b]%s[/b] — %s" % [_here, FLAVOUR[_here]])
	_say("[i]cycle %d of %d[/i]" % [_cycle, RUN_CYCLES])
	for line in _condition(_here):
		_say(line)
	for line in _horizon(_here):
		_say("[color=#8f9bb3]%s[/color]" % line)

func _do(raw: String) -> void:
	var parts := raw.strip_edges().to_lower().split(" ", false)
	if parts.is_empty():
		return
	var cmd: String = parts[0]
	var arg: String = " ".join(Array(parts).slice(1)).capitalize() if parts.size() > 1 else ""
	_say("")
	match cmd:
		"watch", "look":
			_activity[_here] = int(_activity[_here]) + 1
			_say("You watch %s for a day." % _here)
			_routines(_here)
			_advance()
		"go":
			if arg in PLACES and arg != _here:
				_here = arg
				_say("You travel to %s." % arg)
				_advance()
				_arrive()
			else:
				_say("[i]Not somewhere you can walk to from here.[/i]")
		"ask":
			_activity[_here] = int(_activity[_here]) + 1
			_say(_talk(_here))
			_advance()
		"warn":
			if arg in PLACES:
				_activity[arg] = int(_activity[arg]) + 2
				_st[arg]["pressure"] = minf(float(_st[arg]["pressure"]) + 0.25, 1.0)
				_say("You tell %s what you have seen. They take it badly, and seriously." % arg)
				_say("[color=#8f9bb3]By evening %s has more men on the gate than the gate needs.[/color]" % arg)
				_advance()
			else:
				_say("[i]Warn whom?[/i]")
		"incite":
			_activity[_here] = int(_activity[_here]) + 2
			var t := _target(_here)
			_st[_here]["grievance"][t] = minf(float(_st[_here]["grievance"][t]) + 0.35, 1.0)
			_say("You say the thing that was already being thought, only louder.")
			_say("[color=#8f9bb3]By dark, %s is a name people here say without lowering their voice.[/color]" % t)
			_advance()
		"gift":
			_activity[_here] = int(_activity[_here]) + 2
			_st[_here]["pressure"] = maxf(float(_st[_here]["pressure"]) - 0.3, 0.0)
			_say("You give away something you will want later. They notice.")
			_say("[color=#8f9bb3]Whatever %s was bracing for, it stops bracing quite so hard.[/color]" % _here)
			_advance()
		"think":
			_reflect()
		"wait":
			_advance()
		"leave":
			_ending()
		_:
			_say("[i]No.[/i]")

func _reflect() -> void:
	# the bias becomes KNOWN only after enough attention -- earned, never offered
	if int(_activity[_here]) >= 4 and not bool(_known[_here]):
		_known[_here] = true
		_say("[color=#8fd9c4]You have watched %s long enough to see it: %s[/color]" % [_here, BIAS[_here]["desc"]])
	elif bool(_known[_here]):
		_say("[color=#8fd9c4]%s[/color]" % BIAS[_here]["desc"])
	else:
		_say("[i]You do not know this place well enough yet.[/i]")

func _advance() -> void:
	_tick()
	if _cycle >= RUN_CYCLES:
		_ending()

func _ending() -> void:
	# ending.md: assembled from what actually happened, and a MIRROR -- it reflects the run you had.
	# It must never enumerate what you missed (seven-souls.md, corrected 2026-07-30).
	_say("\n[b]— you leave the ring —[/b]\n")
	var hottest := ""
	var hp := -1.0
	for p in PLACES:
		if float(_st[p]["pressure"]) > hp:
			hp = float(_st[p]["pressure"])
			hottest = p
	var most := ""
	var mv := -1
	for p in PLACES:
		if int(_activity[p]) > mv:
			mv = int(_activity[p])
			most = p
	if mv <= 1:
		_say("You were here, and it went on without you. That is most of what happened.")
	else:
		_say("You spent your time in %s. They will remember a stranger who kept turning up." % most)
	for p in PLACES:
		if int(_st[p]["cattle"]) <= 15:
			if int(_activity[p]) == 0:
				_say("%s is down to %d head. You never went there." % [p, int(_st[p]["cattle"])])
			else:
				_say("%s is down to %d head, and you watched some of it happen." % [p, int(_st[p]["cattle"])])
	if hp > 0.65:
		_say("%s was still bracing for something when you left." % hottest)
	elif hp < 0.3:
		_say("You leave the chain quieter than you found it. Nobody will say it was you.")
	var known_n := 0
	for p in PLACES:
		if bool(_known[p]):
			known_n += 1
	if known_n > 0:
		_say("You understood %d of the three well enough to have used them." % known_n)
	_save_khaibit()
	_say("\n[i]Khaibit remembers. Run it again.[/i]")
	_log_state("end")
	if _transcript:
		_transcript.close()
		_transcript = null
	_entry.editable = false


# --- cross-run persistence (Khaibit) -------------------------------------------------------------

func _load_khaibit() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if d is Dictionary:
		_khaibit = d

func _save_khaibit() -> void:
	# Khaibit writes SYNCOPATIONS: it raises local pressure where the player was active, perturbing
	# inputs to next run. It never scripts an outcome and never touches anywhere you ignored.
	var out := {}
	for p in PLACES:
		var prev: float = float(_khaibit.get(p, 0.0))
		var add: float = minf(float(_activity[p]) * 0.03, 0.20)
		out[p] = snappedf(minf(prev + add, 0.45), 0.001)
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	if _transcript:
		_transcript.store_line("#KHAIBIT-OUT " + JSON.stringify(out))


# --- ui --------------------------------------------------------------------------------------

func _say(s: String) -> void:
	_out.append_text(s + "\n")
	_out.scroll_to_line(_out.get_line_count() - 1)
	# Mirror to stdout AND to a transcript file. Run 1 of this mock produced NO record at all --
	# _say only wrote to the label -- so a played session left nothing to analyse but the Khaibit
	# save. For a probe whose whole purpose is evidence, that is the probe failing, not the player.
	var plain := s
	for tag in ["[b]", "[/b]", "[i]", "[/i]", "[/color]"]:
		plain = plain.replace(tag, "")
	while plain.find("[color=") != -1:
		var a := plain.find("[color=")
		var b := plain.find("]", a)
		if b == -1:
			break
		plain = plain.substr(0, a) + plain.substr(b + 1)
	print(plain)
	if _transcript:
		_transcript.store_line(plain)
		_transcript.flush()

func _log_state(tag: String) -> void:
	# structured per-cycle dump: the qualitative transcript says what it FELT like, this says what
	# actually happened underneath, so the two can be compared afterwards.
	if not _transcript:
		return
	var row := {"cycle": _cycle, "tag": tag, "here": _here, "places": {}}
	for p in PLACES:
		row["places"][p] = {
			"pressure": snappedf(float(_st[p]["pressure"]), 0.01),
			"cattle": int(_st[p]["cattle"]),
			"last": _st[p]["last"],
			"grievance": _st[p]["grievance"],
			"activity": int(_activity[p]),
			"known": bool(_known[p]),
		}
	_transcript.store_line("#STATE " + JSON.stringify(row))
	_transcript.flush()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 30; root.offset_top = 24
	root.offset_right = -30; root.offset_bottom = -24
	layer.add_child(root)
	_out = RichTextLabel.new()
	_out.bbcode_enabled = true
	_out.scroll_following = true
	_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_out.add_theme_font_size_override("normal_font_size", 17)
	root.add_child(_out)
	_entry = LineEdit.new()
	_entry.placeholder_text = "watch / go <place> / ask / warn <place> / incite / gift / think / wait / leave"
	_entry.custom_minimum_size = Vector2(0, 40)
	_entry.text_submitted.connect(func(t: String):
		_say("[color=#7f9fd9]> %s[/color]" % t)
		_entry.clear()
		_do(t)
		# keep the caret in the box -- submitting should never cost you a click
		if _entry.editable:
			_entry.grab_focus())
	root.add_child(_entry)
	_entry.grab_focus()
