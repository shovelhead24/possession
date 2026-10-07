# Warthog wishbone prototype

Open the normal **Possession Sandbox** shortcut. **E** enters/exits; WASD drives and Space brakes. **H** hides/restores Warthog bodywork to inspect the wheel rig. **J** resets the Warthog at the suspension lane and, when on foot, places the player beside it. The lane is west of the FOB: staggered bumps, articulation ramp, side slope and a jump. Its underlying terrain is flattened with a blended local edit so obstacles are not buried.

## What moves

The four original tyres/hubs are detached from their static source struts and attached to independent assemblies. Source binary art is unchanged. Each assembly has fixed-length upper and lower wishbones, a fixed-length upright, hub travel with camber change, front steering about the upright axis, tyre spin and a compressing coil/damper visual. H exposes these moving parts. The old static struts are hidden rather than animated alongside the replacement.

The linkage is solved geometrically: lower-arm rotation plus intersection of the upper-arm and upright constraints. It drives the visible hub position; contact height is inverted through that same linkage. It is not a hand-authored wheel-bobbing animation. Steering does not stretch the control arms.

## What generates the ride

A rigid chassis receives separate spring/damping and friction-limited tyre forces at four ground contacts. Static sag, independent travel, airborne droop, load transfer and landing recovery follow those forces. Steering is smoothed and reduced with speed. The tank retains its previous placeholder handling.

Sources inspected: `game/warthog_controller.gd` (VehicleBody3D, mass/steering/braking and wheel suspension, history including 88c457d); `game/mocks/ring_vibes.gd` `_susp_update` (per-wheel travel, static sag, damping, pitch/roll and airborne distinction). The new implementation carries those behaviours into the arena but is not a drop-in copy of either controller: the wishbone constraint solver and per-contact rigid-body forces are new.

## Important limits

This is a constrained kinematic suspension with ray-based tyres, not a full multibody engineering simulation. The ray contact uses the preceding hub's lateral position before updating the linkage; tyre-volume collision against vertical edges is not solved. Chassis collision provides the solid body. Effective wheel-rate/damping values are tuned directly; spring motion-ratio forces, unsprung mass, tyre deformation, driveshafts, steering tie-rod geometry/Ackermann, anti-roll bars and breakage are not modelled. Front wheels share a steering angle. The spring coil is a lightweight line mesh for inspection, not production art. Handling still requires the user's playtest.

## Verification

- `test_wishbone.gd`: 101 travel samples retain both arm lengths and upright length, with continuous hub height and a matching inverse solve.
- `test_suspension.gd`: four-wheel settling/static sag, airborne droop, one-wheel bump articulation, acceleration, steering, braking and landing recovery on a controlled fixture.
- `test_kit.gd`: source imports, both vehicle drive/exit paths, weapon obstruction, one-press relay and strike impacts. Tests move both player and camera when exercising location-based interactions.
- Exposed straight/steered rig captures inspect the original wheel placement and replacement linkage. These checks establish a functioning prototype, not final handling quality.

Use the existing Godot console with `--headless --path` pointing to this directory and `--script res://test_wishbone.gd` (or either other test). Normal Godot user-cache access is required. The autonomous asset worker remains paused.

## Vehicle setup menu

F2 opens four tabs for live Warthog suspension, steering, engine and camera tuning. Sliders use bounded ranges; travel remains within the linkage solver's valid geometry. Values persist in Godot's user data as vehicle_tuning.cfg. Reset defaults restores the baseline. Opening the menu releases the pointer, blocks walking/interactions and applies vehicle brakes; the world continues simulating. F2, Escape or Return to game resumes captured input.

Camera options include chase distance/height/response, field of view and a driver-seat view with mouse look (Home centres it). Chase camera checks scenery obstruction. The player collision body follows the seat while driving and returns to a checked exit on E. The existing soldier FBX supplies a baked seated reference body, visible in chase view and hidden in driver view to prevent head clipping. It is a fixed seated pose, without steering-hand or pedal animation yet. build_driver.py reproduces the GLB using Blender, reducing textures to 1024 pixels; the source FBX is unchanged.

The tuning menu targets the Warthog; tank engine/suspension tuning is not implemented. test_vehicle_setup.gd checks live property changes, settings reload, blocked throttle/braking and both camera modes. Optional --pictures captures the driver and menu.

## Scale, contact and feedback pass

C switches chase/driver-seat view while driving; Q cycles weapons. Camera settings also have explicit Chase and Driver seat buttons. Inspection flight rises with Space (Z lowers) so Q has no movement conflict.

Warthog source length is now 4.8 m rather than 6 m, with a correspondingly reduced chassis collider and relocated seat/centre of mass; the human reference retains its original size. Each suspension anchor moves 0.18 m outward, so contact rays and visible wheels share the wider stance. This is an arena proportion choice, not a claim of canonical dimensions.

Local terrain and path materials now receive real light and cast-object shadows, with restrained world-space ground variation; the distant ring keeps its existing haze material. Generated placeholder engine, rolling-gravel and landing sounds follow throttle/speed/contact. These are functional audio cues, not finished recordings.

## Warthog finish and lower stance

The source's legacy specular/gloss materials are overridden locally with separate olive paint, rough non-metallic rubber, painted rims, exposed steel, glass and purple lamps. Rubber receives a restrained generated grain normal. Source art remains unchanged. The rear gun assembly is reduced to 75% around the bottom of its bounds. Suspension mounts rise 0.14 m relative to the chassis, lowering the body between the wheels without changing spring stiffness or available travel.

See [vehicle effects and tank controls](VEHICLE_EFFECTS.md) for axle power/brake splits, wheel dirt, reload sound and the tank's independent tuning/turret/cannon pass.
