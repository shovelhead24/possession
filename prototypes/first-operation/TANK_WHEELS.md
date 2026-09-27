# Eight-wheel tank

The tank inherits wishbone_vehicle.gd: the same ray suspension, tyre friction,
steering and brake-to-reverse controls as the Warthog. Eight invisible contacts
(four per side) span the track run. The hull is a rigid body with twice the
Warthog mass and an 11 m/s wheel-speed limit.

The original turret assembly, cannon, 62 visible links per side and road wheels
are retained. Belt animation uses average actual wheel angular speed per side.
The belts remain rigid paths around the hull rather than deforming independently.

W accelerates; S brakes before reversing; A/D steer; Space brakes.
This replaces the old differential pivot-turn controller described in TANK_TRACKS.md.
The F2 menu uses tank_wheel_tuning.cfg so old contact-spring settings do not migrate.

Run test_tank_wheels.gd (or the test_tank_tracks.gd compatibility entry point)
for an automated drive, steering, braking and track-animation check on arena terrain.
