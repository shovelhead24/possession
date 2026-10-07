# Warthog mounted turret

Stand behind the Warthog and press E to use its turret. Side entry still selects the driver. Mouse aims, held left mouse fires, C switches close/chase views, and E exits using the existing clear-ground exit checks. Driving inputs are disabled while operating the turret.

Yaw is unrestricted through 360 degrees; elevation and depression are both 30 degrees. The pedestal stays planted while the upper gun elevates. A skinned gunner samples the GunnerCrouch animation continuously forward or backward with elevation, with planted feet and authored two-bone arm poses tracking the grips. The first-person eye remains behind the receiver, independently positioned to avoid passing through the gun, with the gunner body hidden only in that view.

The first-person eye is centred on the barrel axis, above and behind the receiver, and follows barrel elevation. It no longer uses a sideways camera offset.

Both mounted roles remain visible to squad perception and retain player damage. Enemy plasma striking the occupied vehicle also damages the player; separate armour and vehicle health are not implemented here. Mounted defeat restores the on-foot state before respawning.

The cold mechanism spins for one second before the first round. Fire rate then rises from 300 to 900 RPM over 1.5 seconds and stays there indefinitely: no overheating or ammunition limit in this sandbox. Releasing the trigger spins down at 1.5 spool units per second, allowing warm bursts to restart faster. Motor and firing audio, tracers and muzzle flashes provide feedback.

Spread starts at a 0.2 degree half-angle and increases with each shot to a maximum 2 degrees from the aim direction. Released-trigger recovery takes 1.25 seconds from maximum spread. Sampling is uniform over the cone's solid angle. Rounds deal 14 damage, with world collision checked from the breech so a barrel poking through cover cannot shoot through it.

`test_warthog_turret.gd` checks cold delay, rising and steady fire rate, no overheat during sustained fire, cone limits and recovery, actual shot spread growth, rear/side entry, disabled driving, turret aim, hit registration and exit. Run with `-- --pictures` for mounted and close/chase camera captures.
