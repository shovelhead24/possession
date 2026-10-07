# Warthog turret samples

`turret_audio.gd` safely loads external WAV/MP3 files once per session, decodes
to mono for positional audio, and caches the trimmed streams. Missing files
warn once and leave that layer silent; firing gameplay is unaffected.

- Yodguard `402783`: 5.40–6.45 s sustained firing interior, 30 ms loop splice.
- Freesound `44779`: 0.04–1.74 s spool-up and 5.15–8.35 s spool-down only.
  The source's firing section is excluded. Whine playback rate follows the
  remaining mechanical spin time; the firing sample stays at pitch 1.0.
- One firing voice follows the trigger, with 15 ms attack / 60 ms release.
  Bullet traces and damage retain the existing cold delay and rate ramp.
- No procedural shot or motor sound remains in the turret.

`test_turret_audio.gd` checks loading, cache reuse, mono cuts, loop state,
release, and hot re-trigger. `test_warthog_turret.gd` covers mounted gameplay.

In the global **6** panel, **Hide combat indicators** hides enemy/Rexy viewcones,
Rexy's bite volume and target diamond together. **Show combat indicators**
restores them. This affects visuals only, works paused and applies to new cones.
