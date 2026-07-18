# World / Ring Scale

### ring-circumference-2000km — Ring circumference set at 2,000 km
**Date:** 2026-07-18
**Status:** active
**Decision:** Circumference 2,000 km (radius ~318 km). Width still open — widened candidates (10–50 km) now in play, see brief. Pending vibe-check via skybox mock demos at 1,500 / 2,000 / 3,000 km configs (issue #9) — the number may tune within that band, but the *scale class* (small honest ring, not 20,000 km megastructure) is decided.
**Why:** At this radius everything the sky moments promise is geometrically honest — far side ~0.9° overhead (about two moons, wider if the ring widens), terrain 50 km ahead visibly risen ~4 km — and direct interior flight (potential spaceflight options) stays consistent, since an oversized-far-side cheat cannot survive a player approaching it. Walking 360° is still ~2.3 days nonstop (a month of real sessions), so the transport ladder survives. The 20,000 km version required stylizing both signature sky moments and banned free spaceflight forever.

### ring-circumference-20000km — Ring circumference set at 20,000 km
**Date:** 2026-07-18
**Status:** SUPERSEDED 2026-07-18 by ring-circumference-2000km
**Decision:** The ring's circumference is 20,000 km (radius ~3,183 km). Width stays at the proposed ~10 km (not yet locked). Playable surface ≈ 200,000 km² (≈ Great Britain).
**Why:** Scale chosen from the traversal point of view, not physics: the ring must *not* be casually walkable (walking 360° = ~23 days nonstop at the current 10 m/s), so that transport modes are integral to the game and each progression tier changes the player's relationship to distance (walk → horse → vehicle/boat → flyer → ancient rim transit). Smaller rings (100–1,000 km) made honest physics prettier but collapsed the transport ladder.

### cosmology-honest-sky-cheated-day — Sky geometry honest; day length remains a design value
**Date:** 2026-07-18
**Status:** active
**Decision:** At 2,000 km circumference the far side and the upward curve render *honestly* — no size cheat, restoring the "not a skybox trick" language in moments/ring_curve.md and moments/night_sky.md. Day/night length remains a designed tuning value, decoupled from spin physics (honest spin-days at this radius would be ~19 minutes); the fiction can carry shadow squares or leave it unexplained.
**Why:** The circumference was chosen partly *so that* sky geometry could be honest (see ring-circumference-2000km). Day length has no such geometric witness — nothing in the game can catch the lie — so it stays a free pacing parameter.

### cosmology-cheated — Day/night and far-side visibility are cheated, not simulated
**Date:** 2026-07-18
**Status:** SUPERSEDED 2026-07-18 by cosmology-honest-sky-cheated-day
**Decision:** Day/night length and the far side's visual size in the night sky are set by design, not derived from spin physics. At 20,000 km the honest numbers (≈1-hour spin-days; far side a 0.09° hairline) are wrong for the game, so we take artistic license: day length is a tuning value; the night-sky far side is rendered deliberately oversized so it reads as terrain, ocean, and city lights.
**Why:** Honest spin-gravity physics at any circumference the moments allow produced minutes-scale days and either an invisible or sky-dominating far side. Gravity, day length, and scale are independently tuned design values; the fiction (ancient megastructure) absorbs the inconsistency. This consciously amends the "geometrically honest, not a skybox trick" language in moments/ring_curve.md and moments/night_sky.md — the *near-field* curve the player walks on stays real; the far-side painting is stylized.
