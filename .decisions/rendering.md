# Rendering / Art Direction

### texture-fidelity-baseline — Early-Xbox-era coarse baseline; modern budget spent on scale, not texels
**Date:** 2026-07-23
**Status:** active
**Decision:** The global texture/material fidelity baseline is deliberately ~2001 (Halo CE class): coarse-but-readable albedo, strong silhouettes, clean material identities, low texel density accepted everywhere. The modern rendering budget goes exclusively to what that era could not do — draw distance, honest ring-scale geometry, the terminator/haze atmosphere — never to texture resolution. Frutiger-Aero accents (glossy optimism, clean teals/whites) reserved for high-importance objects (ancient tech, UI surfaces) per the interaction-fidelity tiers.
**Why:** Same scoped-resolution logic as the simulation, applied to pixels: (1) potato budget — Intel UHD gets its frames back from texel thrift; (2) the Fern Rule / interaction-fidelity matching — coarse visuals make an honest promise about what's interactive, AAA texture density on a low-sim world would lie; (3) owned aesthetic identity (the beloved 2000s look) beats losing an unwinnable fidelity race. The mock's shader detail is written to this bar on purpose — hash-noise micro-detail, flat material colors, real color from satellite data rather than texture density.
