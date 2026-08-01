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
	"Ardvane": {"key": "tolls", "desc": "Ardvane will always choose the option that keeps the ford open. Threaten the toll and it folds."},
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
# what an action leaves behind, readable off the ground a day later ("walk")
const TRACE := {
	"lift": "hoofprints going out and more coming back",
	"reprisal": "a gate mended in a hurry, and badly",
	"fine": "a driven herd, moving the wrong way for grazing",
	"refuse": "a party turned back at the boundary stone",
	"market": "cart ruts, and straw all over the road",
	"herds_down": "everything walked in tight and kept there",
	"feast": "ashes, and bones nobody buried",
	"moot": "many feet, all going to one place and back",
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
var _purse := 6                # head you are driving. Everything costs; nothing was free before.
var _standing := {}            # how each place regards you, -1..1
var _frozen := {}              # cycles a place is sitting on its hands (omen)
var _ended := false            # run finished; notes still accepted, nothing else
var _auto := false             # autoplay harness: never writes Khaibit
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
		_standing[p] = 0.0
		_frozen[p] = 0
	_build_ui()
	_say("[b]CHAIN[/b] — three settlements, thirty cycles, no missions.\n")
	if not _khaibit.is_empty():
		_say("[i]Something remembers the last time. Some places will be less patient.[/i]\n")
	_say("You are driving six head of cattle and nobody sent you. Type [b]help[/b] for what you can do.")
	_say("[color=#b9a0d9]Thinking out loud is free: [b];[/b] followed by whatever you are thinking.[/color]\n")
	_arrive()
	if "--autoplay" in OS.get_cmdline_user_args():
		_auto = true
		_autoplay()

func _autoplay() -> void:
	# Drives a whole run with random verbs so content changes can be smoke-tested without a human
	# at the keyboard. It is NOT a substitute for playing -- it proves the paths execute and lets
	# the prose be read in bulk. Whether any of it reads is still the meat model's call.
	var verbs := ["watch", "listen", "count", "walk", "ask", "ask about Corrin", "drink",
		"trade", "gift", "incite", "mediate", "lie Slievan", "swear Corrin", "purse",
		"know", "look", "think", "wait", "stay", "toll", "omen", "hostage",
		"go Ardvane", "go Corrin", "go Slievan", "warn Corrin", "warn Slievan",
		"; autoplay note, checking the channel", "note the other form of the same"]
	while _cycle < RUN_CYCLES and not _ended:
		_do(verbs[_rng.randi() % verbs.size()])
	if not _ended:
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
		if int(_frozen.get(p, 0)) > 0:
			_frozen[p] = int(_frozen[p]) - 1
			continue
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
			var carrier: String = ["a drover coming the other way", "a boat that put in at dawn",
				"two women on the ford road", "a smith's lad repeating what he heard",
				"a man who would not give his name"][_rng.randi() % 5]
			_say("[color=#d9a86f]%s. You had it from %s.[/color]" % [nw, carrier])
	# only events in your bubble reach you (R4): here, your place and its neighbours
	for e in events:
		var vis := false
		for p in [_here] + NEIGHBOURS[_here]:
			if e.begins_with(p):
				vis = true
		if vis:
			_say("[color=#c8b48f]· %s[/color]" % e)

func _routines(place: String, budget: int = 99) -> void:
	var intent := _commit(place, _cycle + 1)     # LEADING indicator: preparation for next cycle
	var rr := RandomNumberGenerator.new()
	rr.seed = hash("%s:%d" % [place, _cycle])
	var shown := 0
	for routine in MOD:
		if shown >= budget:
			break
		shown += 1
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

# Asking one place about another. What they will tell you is gated on what they think of you --
# standing is the difference between a fact and a shrug.
func _talk_about(place: String, other: String) -> String:
	var who: String = NAMES[place][_rng.randi() % NAMES[place].size()]
	var st := float(_standing[place])
	if st < -0.3:
		return "%s says they would not know, in a tone that ends it." % who
	if not (other in NEIGHBOURS[place]):
		return "%s has not been as far as %s in years, and says so like it is a boast." % [who, other]
	var os: Dictionary = _st[other]
	var g := float(_st[place]["grievance"].get(other, 0.0))
	if g > 0.6:
		return "%s will talk about %s all night, and none of it fit to repeat." % [who, other]
	if st < 0.1:
		return "%s allows that %s is having a time of it, and leaves it there." % [who, other]
	if int(os["cattle"]) <= 15:
		return "%s says %s is down to nothing — %d head — and that people are walking out of it." % [who, other, int(os["cattle"])]
	if float(os["pressure"]) > 0.7:
		return "%s says %s has the gates shut and men on them, and has had for days." % [who, other]
	if float(os["pressure"]) < 0.2:
		return "%s says %s is fat and easy and sleeping with the door open." % [who, other]
	return "%s says %s is much as it ever is, which is not saying much." % [who, other]

func _talk(place: String) -> String:
	var who: String = NAMES[place][_rng.randi() % NAMES[place].size()]
	var s: Dictionary = _st[place]
	var pr := float(s["pressure"])
	var c := int(s["cattle"])
	if float(_standing[place]) < -0.4:
		return "Nobody here has anything to say to you. That is itself an answer."
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

# --- notes: the third channel ---------------------------------------------------------------
# The transcript records what happened, #STATE records what was actually underneath, and a note
# records what the player BELIEVED at that moment. Readability is the gap between the last two,
# and there is no way to measure it except by asking someone to say what they think while they
# think it. Free, and deliberately side-effect-free: taking a note must never cost a day or move
# the world, or it stops being an observation and becomes a move.
func _note(txt: String) -> void:
	if txt.strip_edges() == "":
		_say("[i]Say what you are thinking. (note <whatever>, or just ; <whatever>)[/i]")
		return
	_say("[color=#b9a0d9]  ✎ %s[/color]" % txt)
	if not _transcript:
		return
	var row := {"cycle": _cycle, "here": _here, "purse": _purse, "note": txt,
		"about_to": {}, "places": {}}
	for p in PLACES:
		# the distribution each place is sitting on for NEXT cycle -- the thing the modulated
		# routines are supposed to telegraph. Pure: no RNG is touched, so notes cannot alter the run.
		row["about_to"][p] = _intent_probs(p, _cycle + 1)
		row["places"][p] = {
			"pressure": snappedf(float(_st[p]["pressure"]), 0.01),
			"cattle": int(_st[p]["cattle"]),
			"last": _st[p]["last"],
			"standing": snappedf(float(_standing[p]), 0.01),
			"activity": int(_activity[p]),
			"known": bool(_known[p]),
		}
	_transcript.store_line("#NOTE " + JSON.stringify(row))
	_transcript.flush()

func _intent_probs(place: String, cycle: int) -> Dictionary:
	# same softmax as _commit, but deterministic and unsampled -- reports the landscape, not a roll
	var w := _disposition(place, cycle)
	var temp := 0.45
	var total := 0.0
	var exps := {}
	for k in w:
		var e: float = exp(maxf(float(w[k]), 0.0) / temp)
		exps[k] = e
		total += e
	var out := {}
	for k in exps:
		var pr: float = snappedf(float(exps[k]) / maxf(total, 0.0001), 0.01)
		if pr >= 0.05:
			out[k] = pr
	return out

func _do(raw: String) -> void:
	var rawt := raw.strip_edges()
	if rawt.begins_with(";"):
		_note(rawt.substr(1).strip_edges())
		return
	var parts := raw.strip_edges().to_lower().split(" ", false)
	if parts.is_empty():
		return
	var cmd: String = parts[0]
	if cmd == "note" or cmd == "n":
		_note(rawt.substr(cmd.length()).strip_edges())
		return
	if _ended:
		_say("[i]That run is done. You can still leave a note.[/i]")
		return
	var arg: String = " ".join(Array(parts).slice(1)).capitalize() if parts.size() > 1 else ""
	if parts.size() > 2 and parts[1] == "about":          # "ask about corrin"
		arg = " ".join(Array(parts).slice(2)).capitalize()
	var where: String = arg if arg in PLACES else _here   # place-verbs default to here
	_say("")
	match cmd:
		# --- free. Looking costs no day; you are standing there anyway. -------------------
		"look", "l":
			for line in _condition(_here):
				_say(line)
			for line in _horizon(_here):
				_say("[color=#8f9bb3]%s[/color]" % line)
		"purse", "me":
			_say("You are driving %d head." % _purse)
			for p in PLACES:
				_say("[color=#8f9bb3]%s: %s[/color]" % [p, _standing_line(p)])
		"know", "journal", "j":
			_journal()
		"help", "?", "verbs":
			_help()
		"think", "t":
			_reflect()

		# --- a day each, and each buys a different kind of knowing -----------------------
		"watch", "w":
			_activity[_here] = int(_activity[_here]) + 1
			_say("You watch %s for a day." % _here)
			_routines(_here)
			_advance()
		"listen":
			# cheaper than watching: one line, no context. Enough to notice, not to read.
			_activity[_here] = int(_activity[_here]) + 1
			_say("You keep your mouth shut and your ears open.")
			_routines(_here, 1)
			_advance()
		"count":
			# the herds are the one thing these people count themselves, so you can too
			_activity[_here] = int(_activity[_here]) + 1
			_say("You walk the pens and count, which nobody stops you doing.")
			_say("    %s: %d head" % [_here, int(_st[_here]["cattle"])])
			for q in NEIGHBOURS[_here]:
				if float(_standing[_here]) > 0.1:
					_say("    they say %s is running about %d" % [q, int(_st[q]["cattle"])])
				else:
					_say("    nobody here will tell you what %s is running" % q)
			_advance()
		"walk":
			# traces: what a place DID last is written on the ground
			_activity[_here] = int(_activity[_here]) + 1
			_say("You walk the road out and back.")
			for q in [_here] + NEIGHBOURS[_here]:
				var la: String = str(_st[q]["last"])
				if la == "":
					_say("    nothing lately out of %s" % q)
				else:
					_say("    %s: %s" % [q, TRACE.get(la, "hard to read")])
			_advance()
		"ask", "a":
			_activity[_here] = int(_activity[_here]) + 1
			if arg in PLACES and arg != _here:
				_say(_talk_about(_here, arg))
			else:
				_say(_talk(_here))
			_advance()
		"drink":
			if _purse < 1:
				_say("[i]You have nothing to stand a round with.[/i]")
			else:
				_purse -= 1
				_activity[_here] = int(_activity[_here]) + 2
				_standing[_here] = minf(float(_standing[_here]) + 0.15, 1.0)
				_say("You stand a round. It costs you a beast and buys you an evening.")
				_say(_talk(_here))
				_routines(_here, 1)
				_advance()

		# --- doing things to people ------------------------------------------------------
		"trade":
			if int(_st[_here]["cattle"]) < 30:
				_say("[i]%s has nothing spare, and would take it badly if you asked.[/i]" % _here)
			else:
				_st[_here]["cattle"] = int(_st[_here]["cattle"]) - 3
				_purse += 3
				_standing[_here] = minf(float(_standing[_here]) + 0.1, 1.0)
				_st[_here]["pressure"] = maxf(float(_st[_here]["pressure"]) - 0.05, 0.0)
				_say("You trade. Three head come your way and %s is glad of the custom." % _here)
				_advance()
		"gift":
			if _purse < 4:
				_say("[i]A gift worth the name is four head. You have %d.[/i]" % _purse)
			else:
				_purse -= 4
				_activity[_here] = int(_activity[_here]) + 2
				_standing[_here] = minf(float(_standing[_here]) + 0.25, 1.0)
				_st[_here]["cattle"] = int(_st[_here]["cattle"]) + 4
				_st[_here]["pressure"] = maxf(float(_st[_here]["pressure"]) - 0.3, 0.0)
				_say("Four head, given openly, in front of people who will remember it.")
				_say("[color=#8f9bb3]Whatever %s was bracing for, it stops bracing quite so hard.[/color]" % _here)
				_advance()
		"warn":
			if arg in PLACES:
				_activity[arg] = int(_activity[arg]) + 2
				_st[arg]["pressure"] = minf(float(_st[arg]["pressure"]) + 0.25, 1.0)
				_standing[arg] = minf(float(_standing[arg]) + 0.1, 1.0)
				_say("You tell %s what you have seen. They take it badly, and seriously." % arg)
				_say("[color=#8f9bb3]By evening %s has more men on the gate than the gate needs.[/color]" % arg)
				_advance()
			else:
				_say("[i]Warn whom?[/i]")
		"incite":
			_activity[_here] = int(_activity[_here]) + 2
			var t := _target(_here)
			_st[_here]["grievance"][t] = minf(float(_st[_here]["grievance"][t]) + 0.35, 1.0)
			_standing[_here] = maxf(float(_standing[_here]) - 0.1, -1.0)
			_say("You say the thing that was already being thought, only louder.")
			_say("[color=#8f9bb3]By dark, %s is a name people here say without lowering their voice.[/color]" % t)
			_advance()
		"lie":
			# big swing, real risk. The less they trust you the likelier it comes apart.
			if not (arg in PLACES) or arg == _here:
				_say("[i]Lie to them about whom?[/i]")
			else:
				_activity[_here] = int(_activity[_here]) + 2
				var risk: float = 0.4 - float(_standing[_here]) * 0.3
				if _rng.randf() < risk:
					_standing[_here] = maxf(float(_standing[_here]) - 0.5, -1.0)
					_say("You tell them what %s is supposed to have said. Somebody here knows better." % arg)
					_say("[color=#d97f7f]It is around by morning. They look at you differently now.[/color]")
				else:
					_st[_here]["grievance"][arg] = minf(float(_st[_here]["grievance"][arg]) + 0.6, 1.0)
					_say("You tell them what %s is supposed to have said. It lands." % arg)
					_say("[color=#8f9bb3]Nobody asks how you came to know it.[/color]")
				_advance()
		"mediate":
			if float(_standing[_here]) < 0.3:
				_say("[i]You are not enough to them yet for that to be anything but cheek.[/i]")
			else:
				var t2 := _target(_here)
				_st[_here]["grievance"][t2] = maxf(float(_st[_here]["grievance"][t2]) - 0.4, 0.0)
				_st[t2]["grievance"][_here] = maxf(float(_st[t2]["grievance"][_here]) - 0.4, 0.0)
				_st[_here]["pressure"] = maxf(float(_st[_here]["pressure"]) - 0.1, 0.0)
				_activity[_here] = int(_activity[_here]) + 2
				_activity[t2] = int(_activity[t2]) + 1
				_say("You carry words between %s and %s until both are sick of you." % [_here, t2])
				_say("[color=#8f9bb3]Nothing is settled. It is quieter, though.[/color]")
				_advance()
		"swear":
			# pick a side, in public. Cheap to say, expensive everywhere else.
			_standing[where] = minf(float(_standing[where]) + 0.4, 1.0)
			for q in PLACES:
				if q != where:
					_standing[q] = maxf(float(_standing[q]) - 0.2, -1.0)
			_activity[where] = int(_activity[where]) + 2
			_say("You say, where it will be repeated, that you are for %s." % where)
			_say("[color=#8f9bb3]It will be repeated.[/color]")
			_advance()

		# --- earned levers. Locked until you have read the place. -------------------------
		"toll":
			if not _lever_ok(where, "tolls"):
				return
			_st[where]["pressure"] = maxf(float(_st[where]["pressure"]) - 0.5, 0.0)
			for q in PLACES:
				if q != where:
					_st[where]["grievance"][q] = 0.0
			_purse += 5
			_standing[where] = maxf(float(_standing[where]) - 0.2, -1.0)
			_say("You let it be known the ford could close. You do not say by whose hand.")
			_say("[color=#8fd9c4]%s folds. It always folds. Five head to make you go away.[/color]" % where)
			_advance()
		"omen":
			if not _lever_ok(where, "taboo"):
				return
			_frozen[where] = 2
			_standing[where] = maxf(float(_standing[where]) - 0.1, -1.0)
			_say("You mention what you saw over the ridge, and let them make of it what they will.")
			_say("[color=#8fd9c4]%s will not stir for two days now. Nobody will say why.[/color]" % where)
			_advance()
		"hostage":
			if not _lever_ok(where, "kin"):
				return
			var take: int = mini(8, int(_st[where]["cattle"]))
			_st[where]["cattle"] = int(_st[where]["cattle"]) - take
			_purse += take
			_standing[where] = maxf(float(_standing[where]) - 0.6, -1.0)
			_st[where]["pressure"] = minf(float(_st[where]["pressure"]) + 0.3, 1.0)
			_say("You take somebody's brother. You are careful about which brother.")
			_say("[color=#8fd9c4]%s pays %d head it cannot spare, and pays it fast.[/color]" % [where, take])
			_advance()

		# --- moving and ending -------------------------------------------------------------
		"go", "g":
			if arg in PLACES and arg != _here:
				_here = arg
				_say("You travel to %s." % arg)
				_advance()
				_arrive()
			else:
				_say("[i]Not somewhere you can walk to from here.[/i]")
		"stay":
			_say("You stay put and let the days go over you.")
			_activity[_here] = int(_activity[_here]) + 2
			for i in 3:
				if _entry.editable:
					_advance()
		"wait", "z":
			_advance()
		"leave":
			_ending()
		_:
			_say("[i]Nothing you know how to do. Try [b]help[/b].[/i]")

func _lever_ok(place: String, key: String) -> bool:
	# The whole point of earning a read is being able to USE it. Before this, discovering a bias
	# was the reward AND the dead end -- no verb was attached to any of them.
	if not bool(_known[place]):
		_say("[i]You do not know %s well enough for that to mean anything.[/i]" % place)
		return false
	if str(BIAS[place]["key"]) != key:
		_say("[i]That is not where %s is soft.[/i]" % place)
		return false
	return true

func _standing_line(place: String) -> String:
	var v := float(_standing[place])
	if v > 0.5:
		return "they would put you up for the winter"
	if v > 0.15:
		return "they are glad enough to see you"
	if v < -0.5:
		return "they would not spit on you if you were burning"
	if v < -0.15:
		return "they watch you the way you watch a dog you do not know"
	return "a stranger who keeps turning up"

func _journal() -> void:
	_say("[b]What you have on them[/b]")
	var any := false
	for p in PLACES:
		if bool(_known[p]):
			_say("[color=#8fd9c4]  %s — %s[/color]" % [p, BIAS[p]["desc"]])
			any = true
		elif int(_activity[p]) >= 4:
			_say("[color=#d9c48f]  %s — you have seen enough of them. Go there and think.[/color]" % p)
		else:
			_say("[color=#8f9bb3]  %s — %d days spent on them. Not enough.[/color]" % [p, int(_activity[p])])
	if any:
		_say("[i]There is a verb for each thing you know. You will have to guess which.[/i]")

func _help() -> void:
	_say("[b]look[/b] · [b]purse[/b] · [b]know[/b] · [b]think[/b] · [b]note <text>[/b] [i](or ; <text>)[/i] — free")
	_say("[b]watch[/b] · [b]listen[/b] · [b]count[/b] · [b]walk[/b] · [b]ask[/b] [i](or: ask about <place>)[/i] · [b]drink[/b] — a day, for knowing")
	_say("[b]trade[/b] · [b]gift[/b] · [b]warn <place>[/b] · [b]incite[/b] · [b]lie <place>[/b] · [b]mediate[/b] · [b]swear <place>[/b] — a day, for doing")
	_say("[b]go <place>[/b] · [b]stay[/b] · [b]wait[/b] · [b]leave[/b]")
	_say("[i]Some places have a way in. You will not be told what it is, or what to type.[/i]")
	_say("[color=#b9a0d9][i]Notes cost nothing and change nothing. Say what you think is going on, even when you turn out to be wrong — especially then.[/i][/color]")

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
	if _purse > 12:
		_say("You leave driving %d head that were not yours when you came." % _purse)
	elif _purse <= 0:
		_say("You leave with nothing, having arrived with six.")
	var friend := ""
	var fv := 0.0
	var enemy := ""
	var ev := 0.0
	for p in PLACES:
		if float(_standing[p]) > fv:
			fv = float(_standing[p])
			friend = p
		if float(_standing[p]) < ev:
			ev = float(_standing[p])
			enemy = p
	if friend != "":
		_say("%s would have you back." % friend)
	if enemy != "" and ev < -0.4:
		_say("%s will tell the story of you for a while, and not kindly." % enemy)
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
	# The most valuable note is the one written straight after the ending, so the run stays open
	# for notes only. The transcript closes on exit instead, which also catches quitting mid-run.
	_ended = true
	_say("[color=#b9a0d9]The run is over, but notes still work. Say what you made of it.[/color]")

func _exit_tree() -> void:
	if _transcript:
		_transcript.close()
		_transcript = null


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
	# autoplay is a test harness -- it must not write into real cross-run memory. Fourteen
	# smoke runs had already pinned every place at the 0.45 ceiling before this was noticed.
	if _auto:
		return
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
	_entry.placeholder_text = "help for verbs   ·   ; to note what you are thinking"
	_entry.custom_minimum_size = Vector2(0, 40)
	_entry.text_submitted.connect(func(t: String):
		_say("[color=#7f9fd9]> %s[/color]" % t)
		_entry.clear()
		_do(t)
		# deferred: grabbing focus inline is undone by Godot's own input pass afterwards
		_entry.call_deferred("grab_focus"))
	root.add_child(_entry)
	_entry.grab_focus()
