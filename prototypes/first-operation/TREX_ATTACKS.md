# Tyrant attack cycle

Successful grabs advance a repeating sequence: up, left, right, then
downward slam / stomp / eat. The counter resets when the Tyrant respawns.

Normal throws lift/clamp at 0.45–0.60 seconds, wind up at 0.60–0.85,
throw at 0.85–1.20, and recover over 0.40 seconds. Launch velocities are
relative to the Tyrant: upward (14 m/s up, 5 forward), left or right
(16 m/s sideways, 3 up). No random launch direction remains.

The fourth grab clamps on the same timing, slams down at 1.20–1.55,
raises the right foot and stomps at 1.95, holds through 2.40, then
picks up the victim and chews. Consumption at 3.40 is lethal to the player
and aliens; props are removed. It finishes at 4.00 seconds. The finisher's
victim trajectory is scripted, not a free ragdoll bounce, to preserve the
stomp contact and pickup alignment. No gore assets are added.

Smooth additive spine/neck/jaw poses and foot targets are applied through
the post-animation grounding modifier. The original GLB is untouched.
The normal walk timeline pauses for the attack and resumes afterward.
Stopped feet ease toward a planted stance over 0.35 seconds.

Grip uses the tongue-tip direction in the animated, terrain-corrected jaw
rig and aligns a victim's collision centre. Victim physics/collision are
temporarily suspended and restored on release or interrupted holds.
Alien death ragdolls are deferred until a normal throw, and hidden consumed
aliens do not spawn invisible ragdolls. Footstep players are now -6 dB
(6 dB louder than the previous setting).

Tests: `test_trex_attack_cycle.gd`, `test_trex_grip_settle.gd`,
`test_trex_behavior.gd`, `test_trex_audio.gd`, `test_trex_grounding.gd`.
Use `--preview-cycle` with the first test to render attack pose previews.
