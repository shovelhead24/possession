class_name VehicleDef
extends Resource

# One vehicle's handling parameters. A row here (later a .tres) plus a mesh is a whole new vehicle:
# the movement code reads these and hardcodes nothing, so the 40-vehicle programme is data rows, not
# forty movement models. `loco` names which Locomotion implementation drives it -- see _drive_tick's
# dispatch. Anything a class does not use (a wheeled car ignores buoyancy/lift) simply sits at 0.

@export var loco := "wheeled"      # which movement model: wheeled | tracked | hover | legged | boat | air ...

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

@export var susp_travel := 0.34    # spring travel, extension limit to bump stop
@export var susp_stiff := 34.0
@export var susp_damp := 6.0
@export var susp_sag := 0.55        # where it sits parked, as a fraction of travel
