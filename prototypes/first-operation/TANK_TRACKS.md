# Animated tank tracks and traction

The Altay uses its original 62 links per side, instanced around the original closed track paths. Road wheels, idlers and sprockets rotate with their side's belt speed. Left and right belts run independently, including opposite directions for stationary pivot turns. W/S drive forwards/backwards, A/D steer, Space brakes.

Seven vertical ground rays per side align with the road wheels. Their contact positions make a left/right and front/rear support plane for pitch and roll, avoiding feedback from the previous hull tilt. Contact fraction controls each side's contribution to propulsion and yaw; unsupported tracks can spin but cannot propel or steer the hull. A broad physical hull collider meets terrain, ridges and walls; the rays provide traction and a stable orientation target. Motion is hull-relative: W/S drive along the hull, A/D changes the two track speeds, and collision impulses are damped sideways. This is a contact-based arcade drivetrain, not articulated track-link physics or individual wheel suspension. Links follow their fixed model path rather than deforming around terrain.

`test_tank_tracks.gd` checks both sets of links, forward/reverse motion, brakes, opposed-track pivots, loss of propulsion and steering in the air, and independent contact on a narrow platform. Run with `-- --pictures` for rendered inspection captures.
