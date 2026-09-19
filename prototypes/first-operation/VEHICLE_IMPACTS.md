# Vehicle impacts and rigid ragdolls

Both the Warthog and tank damage living squad members on moving hull contact. Warthog tyre envelopes also register run-overs outside the chassis. Checks sweep the vehicle collision envelope over a physics step and retain the previous velocity so impact braking does not erase the hit. Stationary contact and speeds below 3 m/s do no damage; impacts at 5 m/s or above kill either enemy type. Slower impacts scale damage with squared relative speed. Captain deaths use the same morale path as weapon kills.

Victims inherit vehicle momentum before entering the existing jointed rigid-body ragdoll. Vehicle collision masks include ragdoll bodies. This is articulated body physics, not deformable soft-body simulation.

The Warthog chassis box now covers 92% of the model length and 82% of its original wheel-inclusive width, with a 0.76 m height centred at 0.85 m. The former box covered only 68% length and 60% width. Suspension and tyres retain their ray-based force model.

The previous rubbery deaths came from inherited skeleton scale being discarded by PhysicalBone3D: the grunt pelvis acquired an inverse scale of approximately 1.846 while child offsets shrank. Uniform import and character scale are now baked into mesh vertices, skin binds, joint offsets and animation translations. Cached resources remain shared within each size. Ragdoll collision dimensions scale with the character, twist limits are reduced, and a final skeleton modifier preserves limb lengths through transient physics solver errors.

Validation: `test_vehicle_impacts.gd` checks forward/reverse kills, captain morale, wheel hits, near misses, parked safety, inherited ragdoll momentum, tank impacts, suspension settling and driving. `test_ragdoll.gd` checks unit world scale, unchanged rendered limb lengths and scales, and settling for both enemy sizes. `test_squads.gd` covers the retained squad and grenade behaviour.

Knees and elbows use limited physical hinges, with a final one-way pose guard (140 degrees knee flexion, 150 degrees elbow flexion). Other joints retain stable cone/twist limits. Ragdolls use stronger linear/angular damping, a 12 m/s initial impact cap, and bounded solver velocities to suppress explosive impulses.

Vehicle entry temporarily excludes the player from vehicle contact. Exit flushes the capsule's new transform before restoring its collision layer, then restores player/vehicle contact after two physics frames. Suspension rays always exclude the player and ignore the mounted-player layer, so the occupant cannot become a false ground contact. Eight alternating driver/gunner exits passed with peak vertical speed below 0.49 m/s.
