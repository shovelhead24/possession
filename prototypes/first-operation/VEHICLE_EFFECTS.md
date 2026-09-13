# Vehicle controls and effects

F2 opens settings for the driven vehicle, or the nearby vehicle on foot (Warthog otherwise). Each vehicle saves to its own user-data configuration. C still switches views. Tank controls: WASD moves/turns the hull, mouse aims the turret, left click fires, Space brakes and E exits. The tank can pivot while stationary.

The Warthog Axles tab exposes front power and front braking percentages; the rear receives the remainder. 50/50 retains the previous per-wheel allocation. Total commanded force stays constant when changing bias; tyre grip can still limit the force delivered. Unoccupied vehicles apply parking brakes to every wheel regardless of bias. This is force allocation, not a differential/ABS simulation.

Each Warthog wheel emits a small, capped dirt plume only while it has ground contact and the vehicle is moving. Existing airborne particles fade naturally. This first effect is not surface-material-aware. Reloads now play a generated mechanical sequence. The audio is placeholder sound design.

The tank's original upper meshes are reparented to a yaw pivot; the cannon and mantlet use a separate elevation pivot. This is a prototype rig assembled from the imported mesh parts. Hull drive/turn/brake, turret traverse, reload delay, direct-hit damage and camera settings are adjustable. The cannon uses an immediate collision ray from the breech, a tracer, hit flash and generated report. A barrel protruding through cover cannot bypass it. Ballistic flight, blast-radius damage, ammunition supply, animated tracks and full tracked suspension are not implemented.

test_vehicle_effects.gd checks extreme axle splits, dirt stopping while airborne, sound samples, turret movement, direct hits, reload blocking and nearby-cover obstruction. Visual captures check the tank articulation/menu and moving wheel dirt. Existing driving/exit checks remain in test_kit.gd.

The user-selected [enemy pulsed-plasma reference](PLASMA_REFERENCE.md) is recorded separately. Enemy character design awaits the user's next references.
