# Lizard scout and travelling plasma

The current encounter uses four elite-led squads; see SQUADS.md for morale, grenades, search behaviour and the expanded fourteen-clip animation set. The original standalone scout/guard/heavy arrangement described below has been superseded.

F3 opens combat setup. Player and enemy projectile speeds have separate persistent sliders (5–150 m/s); defaults are 45 and 22 m/s. Changes affect new shots. F3 or Escape closes it; F2 still opens vehicle tuning. Q retains weapon cycling. The existing player Carbine is now the plasma rifle mechanically; Railgun retains instant-hit behavior.

Plasma bolts visibly travel and sweep a collision ray over each movement step so they cannot tunnel through thin walls at high speeds. Each bolt deals damage once, on impact, and expires after 250 metres. Player bolts deal 25 damage, scout bolts 8. The scout retains 50 HP, so two plasma hits kill it. Resetting practice clears projectiles and respawns the targets.

The weak scout uses the downloaded lizard, normalized to 1.3 m tall. Its 22-joint skinned rig includes torso, neck/head, articulated limbs, three tail segments, rifle and muzzle joints. Idle, Run, Fire and Death are exported animation clips. A purple rifle with luminous coils is attached to the rig; shots originate at its animated muzzle. The weapon and motion are prototype art, with approximate skin weights and grouped fingers, rather than a finished hand grip or foot-placement solver. The source skin textures are preserved. Rigging source and editable Blender scene are in game/enemy/alien_reptile.

The scout keeps the existing practice activation: shooting an enemy starts the encounter. It strafes, flashes the muzzle while charging, and fires at the player's previously sampled position, allowing time to dodge. Guard and heavy remain their existing stand-ins. The enemy rifle has positional shot audio using the existing plasma sample.

Validation: test_plasma.gd checks skin/clip import, muzzle socket, travel time, thin cover at maximum speed, one-hit-only behavior, enemy damage, menu keys and reset cleanup. test_kit.gd now waits for actual projectile arrival. Animation and menu captures accompany the integration test.
