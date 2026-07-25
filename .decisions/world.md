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

### ring-width-50km — Ring width set at 50 km (closes D2b)
**Date:** 2026-07-25
**Status:** active
**Decision:** Width 50 km — the widest of the original 10/32.768/50 km candidate band. Closes brief D2b.
**Why:** Settled by repeated hands-on testing in the `ring_vibes` mock (real DEM terrain, honest curvature, multiple flight/drive/walk sessions) rather than a single formal vibe-check pass — the width consistently read well across sessions, and the user chose to promote it rather than hold for a separate dedicated verdict. Widest option also maximizes the width-driven opportunities catalogued in world.md (cross-ring biome variety, lostness, walls-as-destinations, a sea worth a boat).
**Open tension, not yet resolved:** `docs/terrain/substrate.md`'s D9 proposal wants power-of-two dimensions (C = 2²¹ m ≈ 2,097 km, W = 2¹⁵ m ≈ 32.768 km) for clean tile addressing — this decision keeps the plain 2,000 km / 50 km numbers instead, chosen from real testing rather than math convenience. D9 needs to either accept non-power-of-two dimensions (losing the clean-tiling property) or the substrate tiling scheme needs to be designed to tolerate it (e.g., a tile size that doesn't need to evenly divide the full circumference). Flagged for whoever picks up substrate v1 freeze.

### atmosphere-density-falloff — Deep-cross-section atmosphere, density concentrated near the surface
**Date:** 2026-07-25
**Status:** active
**Decision:** The ring's atmosphere fills a deep cross-section of the tube's interior — not a thin Earth-like shell hugging the surface. Density is not uniform through that depth: it falls off with height above the surface (barometric-style profile, re-tuned to ring geometry), concentrated near the ground, with most of the open middle volume relatively clear/transparent.
**Why:** Reconciles two needs that first looked like a conflict. A thin shell would make the far side *clearer* than the ground in front of you (looking "up" crosses almost no atmosphere; looking along the surface at the horizon crosses a lot) — backwards from knowledge.md's "the air is the horizon" law, which wants the far side genuinely softened. But uniform full-volume fog would erase the dramatic threshold of entering the atmosphere when arriving from open space (moments/landing.md). Surface-concentrated falloff gives both: a real boundary layer to punch through on arrival, a mostly-clear middle volume (bonus: keeps the mid-game armada's ships — moments/armada.md — reading stark against open sky rather than hazed out), and a far side that's still naturally softened because a sightline toward its surface detail grazes back down into *that* surface's own boundary layer.
**Deliberately deferred:** exact boundary-layer height and haze extinction distances are tuning values, not set here — every haze/height number used in the `ring_vibes` mock so far was picked ad hoc against whichever terrain happened to be loaded; the real DEM terrain has never had a dedicated height-calibration pass. Needs one before these numbers are trustworthy.

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
