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

# --- terminal -----------------------------------------------------------------------------------
@export var damage := 34.0         # per hit against the standard target
@export var pellets := 1           # >1 = a spread of projectiles per shot (shot, flechette)
