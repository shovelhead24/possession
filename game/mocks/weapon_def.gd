extends Resource

# One weapon's parameters. Same argument as VehicleDef: a tech tree from a sharpened stick to a
# backpack MLRS is not forty weapon models, it is ~7 mechanics classes each parameterised, with
# placeholder shapes over the top. `cls` names which mechanics class fires it -- see the --range
# dispatch. Anything a class does not use simply sits at its default.
#
# NOTE: no `class_name`. A class_name only resolves once the Godot EDITOR has registered it in the
# global class cache, and this project runs headless -- which is exactly how VehicleDef took the
# whole script down for three queue ticks. Preloaded into a const instead.

@export var cls := "chemical"      # melee | thrown | tensioned | chemical | energy | guided

# Census discipline, as with vehicles: a row states what the weapon is FOR, not just what it is.
@export_multiline var purpose := ""

# --- projectile ---------------------------------------------------------------------------------
@export var muzzle := 900.0        # m/s at the muzzle. 0 = no projectile (melee)
@export var drag_k := 0.0004       # velocity loss per metre per (m/s); crude but monotonic
@export var mass_g := 8.0          # projectile mass, grams -- carried for damage falloff later

# --- fire control -------------------------------------------------------------------------------
@export var rpm := 600.0           # cyclic rate, rounds/min; 0 = single action paced by cycle_s
@export var cycle_s := 0.0         # forced time between shots (bolt, draw, wind-up) on top of rpm
@export var mag := 30              # rounds before a reload
@export var reload_s := 2.4

# --- accuracy -----------------------------------------------------------------------------------
# Spread is in MILLIRADIANS, which is the only sane unit here: it makes group size scale with range
# for free (1 mrad = 1cm at 10m = 1m at 1km) and it is how real dispersion is quoted.
@export var spread_mrad := 0.8     # inherent dispersion, unavoidable
@export var bloom_mrad := 1.6      # added per shot while firing, up to bloom_max
@export var bloom_max := 9.0
@export var settle_s := 0.55       # seconds to bleed accumulated bloom back to zero

# --- recoil -------------------------------------------------------------------------------------
@export var recoil := 3.0          # mrad of muzzle rise per shot
@export var recover_s := 0.30      # seconds for the muzzle to come back down

# --- melee (the `melee` class only) ---------------------------------------------------------------
# Reach, wind-up and COMMITMENT are the whole class. A melee weapon is not a gun with range 2: the
# decision you make is whether to start a swing you cannot take back, so the interesting parameter is
# the window during which you are helpless, not the damage.
@export var reach := 0.0           # metres the swing covers; 0 = not a melee weapon
@export var windup_s := 0.0        # from input to the hit landing -- telegraph the opponent can read
@export var commit_s := 0.0        # helpless window AFTER the swing, whether or not it connected
@export var arc_deg := 60.0        # sweep width; a club catches several, a spear catches one

# --- thrown (the `thrown` class only) --------------------------------------------------------------
# Arc, weight and fuse. Weight is already `muzzle` (how fast you can get it moving) and `mass_g`; the
# fuse is what makes the class interesting, because a timed charge is a decision about WHEN as well
# as where, and a ringworld's long flight times make that decision much sharper than on a planet.
@export var fuse_s := 0.0          # seconds from release to detonation; 0 = detonates on impact
@export var blast_r := 0.0         # effective blast radius, m; 0 = point impact only
@export var lob_mrad := 785.0      # preferred throw elevation (785 mrad = 45 deg)

# --- tensioned (the `tensioned` class only) --------------------------------------------------------
# Draw, hold, drop. The class trait is that the SHOT COSTS TIME BEFORE IT HAPPENS, and that holding
# the drawn weapon costs you accuracy -- so unlike a firearm you cannot sit at the ready indefinitely.
# The drop falls out of the ballistics for free: these are 30-90 m/s weapons, so gravity has whole
# fractions of a second to work.
@export var draw_s := 0.0          # seconds to reach full draw; 0 = not a tensioned weapon
@export var hold_s := 0.0          # seconds at full draw before the shake sets in
@export var hold_mrad := 0.0       # added dispersion per second held beyond hold_s

# --- heat (chemical and energy classes) ------------------------------------------------------------
# The upper bound on sustained fire that is not the magazine. A belt-fed gun does not stop because it
# is empty, it stops because the barrel is glowing -- so heat is what separates an LMG from a carbine
# with a bigger magazine, and it is the only brake a directed-energy weapon has at all.
@export var heat_per_shot := 0.0   # 0 = never overheats (every row that predates this)
@export var heat_max := 100.0
@export var cool_rate := 25.0      # units shed per second when not firing
@export var overheat_lock_s := 0.0 # forced cooling pause once heat_max is reached

# --- directed energy (the `energy` class only) -------------------------------------------------------
# The class has to feel unlike the others rather than being a rifle with a beam, and on a ringworld it
# already does: it is the ONLY weapon with no time of flight, so it is the only one that ignores drop
# and the spinward/antispinward asymmetry that governs everything else here. What it pays instead is
# that it cannot be fired in anger for long -- charge before, heat after.
@export var beam := false          # true = continuous while held (damage is per SECOND, not per shot)
@export var charge_s := 0.0        # spin-up before the shot leaves; a commitment, like a melee windup
@export var falloff_m := 0.0       # range beyond which the beam bleeds power; 0 = no falloff

# --- guided / indirect (the `guided` class only) ------------------------------------------------------
# Fire-and-forget against steered, a minimum arming range, and a real reason not to carry it
# everywhere. The last is a parameter too: `bulk` is what it costs you to have it on your back at all.
@export var steered := false       # true = you fly it in; false = you aim it and live with the result
@export var arm_m := 0.0           # metres before the warhead arms -- fire it closer and it just hits
@export var bulk := 0.0            # 0 = pocketable; high = this is the only thing you are carrying
@export var salvo := 1             # rockets per trigger pull
@export var salvo_gap_s := 0.0     # spacing within a salvo

# --- terminal -----------------------------------------------------------------------------------
@export var damage := 34.0         # per hit against the standard target
@export var pellets := 1           # >1 = a spread of projectiles per shot (shot, flechette)
