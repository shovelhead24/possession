# World / Ring Scale

### ring-circumference-20000km — Ring circumference set at 20,000 km
**Date:** 2026-07-18
**Status:** active
**Decision:** The ring's circumference is 20,000 km (radius ~3,183 km). Width stays at the proposed ~10 km (not yet locked). Playable surface ≈ 200,000 km² (≈ Great Britain).
**Why:** Scale chosen from the traversal point of view, not physics: the ring must *not* be casually walkable (walking 360° = ~23 days nonstop at the current 10 m/s), so that transport modes are integral to the game and each progression tier changes the player's relationship to distance (walk → horse → vehicle/boat → flyer → ancient rim transit). Smaller rings (100–1,000 km) made honest physics prettier but collapsed the transport ladder.

### cosmology-cheated — Day/night and far-side visibility are cheated, not simulated
**Date:** 2026-07-18
**Status:** active
**Decision:** Day/night length and the far side's visual size in the night sky are set by design, not derived from spin physics. At 20,000 km the honest numbers (≈1-hour spin-days; far side a 0.09° hairline) are wrong for the game, so we take artistic license: day length is a tuning value; the night-sky far side is rendered deliberately oversized so it reads as terrain, ocean, and city lights.
**Why:** Honest spin-gravity physics at any circumference the moments allow produced minutes-scale days and either an invisible or sky-dominating far side. Gravity, day length, and scale are independently tuned design values; the fiction (ancient megastructure) absorbs the inconsistency. This consciously amends the "geometrically honest, not a skybox trick" language in moments/ring_curve.md and moments/night_sky.md — the *near-field* curve the player walks on stays real; the far-side painting is stylized.
