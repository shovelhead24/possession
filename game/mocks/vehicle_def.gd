class_name VehicleDef
extends Resource

# One vehicle's handling parameters. A row here (later a .tres) plus a mesh is a whole new vehicle:
# the movement code reads these and hardcodes nothing, so the 40-vehicle programme is data rows, not
# forty movement models. `loco` names which Locomotion implementation drives it -- see _drive_tick's
# dispatch. Anything a class does not use (a wheeled car ignores buoyancy/lift) simply sits at 0.

@export var loco := "wheeled"      # which movement model: wheeled | tracked | hover | legged | boat | air ...

# Census discipline (see TASKS.md): a row states what the vehicle is FOR, not just what it is. Two
# wheeled cars with different numbers is not variety unless each earns its place -- this line is where
# that argument gets made, and it is what the HUD shows when you cycle onto the vehicle.
@export_multiline var purpose := ""

# Placeholder body, used when no bespoke mesh is present (the warthog GLTF is gitignored, and every
# class below the wheeled ones has no art yet). Mechanics first: a distinctly sized and tinted box is
# enough to drive and compare the handling. A real mesh, when it lands, overrides this entirely.
@export var length := 4.2          # nose-to-tail metres -- sizes the placeholder box and its wheelbase
@export var tint := Color(0.33, 0.36, 0.30)  # placeholder body colour, so cycling reads as a change

# mass / buoyancy / lift are carried for the classes below (hover, boat, air) that will read them.
# The wheeled model does not touch them yet -- the handling physics is under a no-change gate, so
# they are a data contract here, not a behaviour change.
@export var mass := 1200.0         # kg -- heavier resists accel and settles lower on its springs
@export var buoyancy := 0.0        # >0 floats (boats, amphibians); 0 sinks
@export var lift := 0.0            # >0 flies (rotary, fixed-wing); 0 stays on the ground

@export var power := 9.0           # forward accel
@export var brake := 12.0
@export var top := 22.0            # top speed, m/s
@export var reverse := -6.0
@export var drag := 0.35           # on-road velocity damping
@export var offroad_drag := 0.55   # extra damping when fully off the tarmac
@export var turn := 1.5            # steering bite on-road
@export var offroad_turn := 0.45   # bite lost off the tarmac
@export var grip_speed := 12.0     # speed at which steering reaches full authority
@export var ride := 0.40           # body height above the contact point, m
@export var wheel_r := 0.45        # wheel radius -- roll rate is circumference-correct off this

# legged only (the _loco_legged class): a walker steps over roughness and climbs onto features that
# stop a wheel dead. Non-legged classes never read these, so they sit at their defaults.
@export var step_height := 0.0     # roughness/obstacle height the gait absorbs; the body feels only above it
@export var gait := 2.4            # stride length in metres -- shorter strides bob quicker per metre travelled

# Mount behaviours (TASKS.md "Horses"): a living mount tires and spooks where a mech or elephant does
# not. Both default off (stamina 0, spooks false), so every existing row and every non-legged class is
# unchanged -- a data contract, like buoyancy/lift, that only the horse row switches on.
@export var stamina := 0.0         # seconds of hard gallop before winded; 0 = tireless (never read)
@export var winded_top := 0.0      # top speed once stamina is spent; effective top lerps down to this
@export var spooks := false        # bolts and shies when a threat closes (_threat_active); mechs don't

# Trample (TASKS.md "Elephants"): crush radius in metres. >0 flattens small trees and hedgerows the body
# walks over -- the reason those systems are destructible at all. 0 = leaves everything standing (default;
# every other row and class). A data contract like stamina/lift: only the elephant switches it on.
@export var trample := 0.0

# Powered suit (TASKS.md "Powered suits"): the player IS the vehicle, so it does two things nothing else in
# the roster does -- it JUMPS and it SPRINTS. Both default off (jump 0 can't leave the ground; sprint 1 = no
# burst), unread by every other row and class, so this is a data contract like stamina/trample/lift and only
# the suit row switches it on.
@export var jump := 0.0            # peak jump height in metres; 0 = grounded (launch v = sqrt(2 g jump))
@export var sprint := 1.0          # top-speed multiplier while the sprint input is held; 1 = no sprint

@export var susp_travel := 0.34    # spring travel, extension limit to bump stop
@export var susp_stiff := 34.0
@export var susp_damp := 6.0
@export var susp_sag := 0.55        # where it sits parked, as a fraction of travel
