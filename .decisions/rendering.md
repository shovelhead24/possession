# Rendering / Art Direction

### texture-fidelity-baseline — Early-Xbox-era coarse baseline; modern budget spent on scale, not texels
**Date:** 2026-07-23
**Status:** active
**Decision:** The global texture/material fidelity baseline is deliberately ~2001 (Halo CE class): coarse-but-readable albedo, strong silhouettes, clean material identities, low texel density accepted everywhere. The modern rendering budget goes exclusively to what that era could not do — draw distance, honest ring-scale geometry, the terminator/haze atmosphere — never to texture resolution. Frutiger-Aero accents (glossy optimism, clean teals/whites) reserved for high-importance objects (ancient tech, UI surfaces) per the interaction-fidelity tiers.
**Why:** Same scoped-resolution logic as the simulation, applied to pixels: (1) potato budget — Intel UHD gets its frames back from texel thrift; (2) the Fern Rule / interaction-fidelity matching — coarse visuals make an honest promise about what's interactive, AAA texture density on a low-sim world would lie; (3) owned aesthetic identity (the beloved 2000s look) beats losing an unwinnable fidelity race. The mock's shader detail is written to this bar on purpose — hash-noise micro-detail, flat material colors, real color from satellite data rather than texture density.


### e3-sky-haze-direction — E3 2000 memory and current haze govern look development
**Date:** 2026-09-12
**Status:** active
**Decision:** The user's E3 2000 Halo reference, purple accents and dramatic sky define the current direction. Preserve the current build's haze as a key source of scale. Explore a painterly large sky composition with limited motion; retain spatially correct reachable ring geometry. Crude-realistic near objects remain required. The earlier retail-Level-2-exclusive palette and generic teal/white high-importance accents yield to the new brief where they conflict; coarse fidelity and hardware constraints remain. This is no authorisation to alter existing haze tuning.
**Why:** A shared world look and complete per-job brief must precede individual production assets. Neutral inspection and in-world approval serve different purposes; the review-render lighting defect does not invalidate the current world haze. See docs/art-production-brief.md for references, deliverables, boundaries and production gates.