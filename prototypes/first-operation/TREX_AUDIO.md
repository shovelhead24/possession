# Tyrant sound integration

Source recordings remain untouched in `C:/Games/possession/assets/trex sounds/`.
They were supplied by the user as royalty-free; filenames retain the source creator identifiers.

`trex_audio.gd` loads seven recordings once per session, decoding them to mono
for positional playback. The two breathing downloads are byte-identical;
only `550277` is used. The car-engine recording and alternate unused recordings
remain available but are not assigned to the creature.

- Footsteps: first 0.82 seconds of `dragon-studio-colossal-footsteps-467495`,
  with short attack/release fades. Triggered when an animated foot lands and
  the body is actually moving; no timed walking loop or stationary shuffling sound.
- Acquisition: one of the `550368` and `444199` roars; 18-second cooldown.
- Ambient: `550277` breathing, or `550365` growling while hunting; spaced
  18–30 seconds apart, without overlapping other vocals.
- Bite impact: `550366` grunt at the existing damage/clamp event.
- Surviving injury: `550364` groan, rate-limited to once per 2.5 seconds.

Three spatial players are reused: one voice and one per foot. Voice follows
the grounded head; impacts originate at the corrected feet. Quiet distance
attenuation limits footsteps to 80 metres and vocals to 150 metres.
The single voice channel prioritizes attacks/pain/alert over ambience.

Run `test_trex_audio.gd` for loading, mono conversion, trim duration, landing
events, stationary silence, cooldowns, bite priority, and real-animation tests.
