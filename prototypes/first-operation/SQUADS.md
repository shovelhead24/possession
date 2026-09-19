# Reptile squad sandbox

Four squads occupy separate positions across the valley. Each has one purple elite and four green grunts. Elites are 1.95 m tall (exactly 1.5 times a grunt's 1.3 m) with 175 HP versus 50. The elite shader recolours the existing skin texture using its luminance and preserves its normal map, rather than replacing the skin with a flat colour. Elites fire red plasma, with a 0.2 s aim wind-up and 0.4 s cooldown; grunts use green plasma with 0.65 s wind-up and 1.9 s cooldown. F3 still adjusts projectile travel speeds.

## Controls

- G throws a frag grenade on foot. Practice grenades are unlimited with a short throw cooldown.
- A frag detonates only after one continuous second of supported rest. Rolling, bouncing or renewed spin resets that second. There is no timer from the throw, and no midair detonation at the apex. Elites react to visible grenades inside roughly 11 m and physically dive along a checked escape direction.
- Frags have a 9 m blast radius with damage falloff. Solid cover blocks blast damage, including damage to the player. Grenades can hurt the thrower after leaving their hand.
- E at the existing practice console resets all squads, grenades and plasma bolts.

## Squad behaviour

Sight is checked against world collision; nearby weapon reports also supply a last known position. Squads do not read the player's new position while searching without contact. While the captain lives, grunts press toward the threat and elites seek cover near their defensive position. A player within 17 m of that position can provoke an elite rush. Members choose distinct covered destinations where possible.

After two seconds without contact a squad holds and watches its last known position. After 30 seconds it hunts toward that position, alternating moving and covering groups every 4.5 seconds at walking pace. After 300 seconds without sight, shots or hits it returns to a local patrol circuit. Captainless squads panic and scatter with hands up when engaged; they stop shooting and hide their rifles. After five quiet minutes they can patrol again, but renewed contact still routes them because their captain is dead.

Navigation uses a terrain-height grid, boulder/tree exclusions and short collision feelers. Cover is chosen with actual occlusion rays. This is basic prototype navigation: it does not plan elaborate flanks through building interiors, and grid paths may be cautious around closely packed obstacles. The original compound is excluded from squad path planning.

## Animation and arena

The skinned rig has fourteen clips: Idle, Run, Walk, Strafe, Jump, Crouch, Dive, Flee, Fire, Death, Check, Scratch, Look and Talk. The old Death clip is retained in the source but combat deaths now use a 19-body physics ragdoll, with constrained joints and collision against terrain. Impact direction and current movement influence the fall. Weapons are hidden on death pending a separate dropped-weapon system.

Flee raises both hands; crouching plants the feet using a two-bone solve in the authored pose. The dive has a short crouched launch, forward body/arm extension, airborne movement, a prone collision shape and landing/recovery. It lasts about 1.3 seconds. Social idles are selected at patrol stops; nearby stationary squadmates turn toward one another and talk. Jumping is used for low obstacles when the upper path is clear. These remain authored prototype loops, without dynamic foot IK or a full animation blend tree.

The local terrain spans 540 by 690 m, with rolling outer hills, broad grass colour variation, 41 colliding boulders and 230 trees. The original FOB, relay route and suspension course remain in place. All twenty characters share imported mesh and animation resources; only elite skin materials differ.

Tests cover squad composition, size and health differences, animation import, morale, exact memory thresholds, alternate hunting teams, grenade fuse reset, physical resting detonation, blast occlusion, navigation, live target acquisition, red shots and automatic evasive movement. Visual captures review scale, purple skin, hands-up flight, crouching and dives.
