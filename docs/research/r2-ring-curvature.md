# R2 — Ring Curvature Rendering Precedents (2026-07-19)

**Question:** vertex-bend shader vs actual curved geometry vs skybox illusion — what do precedents cost, and what does "geometrically honest" actually require given D2's 2,000 km circumference? Informs D4 / issue #2.

## Findings

**Halo cheated, and that's not available to us.** Bungie's ring horizon is a painted skybox eyeballed from ground level — the playable terrain itself stays flat, no real curve geometry or bend math involved. This directly violates the moment docs (`ring_curve.md`, `night_sky.md`): the brief already ruled out this exact shortcut once it became clear a player flying toward the "far side" would break the illusion (the 20,000 km → 2,000 km supersession in `.decisions/world.md` was decided for this reason). Halo precedent is useful as a *warning*, not a technique to borrow.

**Vertex-bend shaders (Animal Crossing / "Curved World" asset / endless-runner rolling-log effect) are screen-space tricks, not honest geometry.** They displace vertex Y by a function of camera-relative Z distance, purely for a visual bend within view distance — the actual mesh, collision, and world position are untouched and unbent. This is cosmetically similar to what we want for terrain 20–50 km out, **but it's a camera-relative illusion that resets outside view distance and carries no positional truth** (an object "bent" at 40 km isn't actually 4 km higher in the coordinate system, so physics, occlusion, and inter-object distance checks all disagree with what's on screen). Fine for arcade curvature (Subway Surfers scale); not sufficient on its own for "if you can see it you can reach it" at ring scale.

**Real planetary-curvature engines (Kerbal Space Program, Outerra-style) solve a different, harder problem than ours.** KSP spherifies six quadtrees into a cube-sphere (hexsphere) so LOD subdivision has no polar distortion — full 3D curvature in every direction, because a planet curves on two axes. **Our ring only curves on one axis** (the cross-ring/spinward direction; along the ring's width axis it's flat, and along its length the curve is a simple circle, not a sphere). A full quadtree-cube-sphere solution is solving for a problem we don't have — the honest ring curve is one circular arc, not a hexsphere, and importing that machinery would be pure overkill against the potato-hardware budget.

**The resolution the brief already gestures at is the right one: honest arc geometry near the player, mathematical circle further out.** Concretely, three techniques compose instead of one silver bullet:
1. **Actual curved terrain mesh near the player** (say out to the ~20–50 km "money shot" distances the ring-vibe mocks use) — vertices genuinely positioned along the ring's circular cross-section via `y_offset = R - sqrt(R² - x²)` (or the equivalent in local floating-origin space), not a camera-relative bend. This is real geometry, real collision, real occlusion — expensive only in that it needs the terrain data model to think in ring-arc coordinates instead of a flat plane (ties directly to D3/substrate.md's coordinate spec).
2. **A distant impostor/painted layer beyond the realized terrain horizon** for the far side and deep background — this is where a Halo-style painted or billboarded representation is legitimate, *because* the moment docs' "reachable" requirement is satisfied by (1): the player is never asked to fly to something in (2) without it first becoming realized terrain as they approach (matches the Tier 0/Tier 1 static-signal rule from `.decisions/design-laws.md`'s interaction-fidelity ratification — distant skyline is explicitly allowed to be a low-fidelity promise).
3. **Vertex-bend-style displacement is the wrong tool for the transition seam** between (1) and (2) — it doesn't carry positional truth, and the April clipping bug (manifold errors reading as z-fighting) came from exactly this kind of two-layer boundary mismatch. The seam needs an explicit fade/dissolve or fog occlusion (haze system, already built per `docs/rendering.md`), not a shader bend pretending to be geometry.

**GL Compatibility has no bearing on any of this — vertex displacement is core, not compute.** All three techniques above use ordinary vertex shader position output, which is fully supported in Godot's Compatibility (OpenGL ES 3.0-class) renderer; nothing here needs compute shaders. The GL Compat constraint list (no compute, limited MRT) doesn't touch vertex-stage math. This removes one worry going into D4 — the renderer tier isn't a blocker for honest arc geometry.

**Floating origin interacts with arc math, not just with distance.** R1 established floating origin is mandatory past ~2–4 km. The arc curvature formula above must be evaluated in the *local floating-origin frame*, re-deriving `R` (ring radius) relative to the current origin's ring-position, not in a naive fixed world frame — otherwise every origin shift will visibly kink the curve. This is the same class of bug R1 already flagged for the skybox/manifold lesson; it now applies to terrain geometry too, not just sky.

## Consequences for open decisions

- **D4 (curvature rendering approach):** answer is composite, not single-technique — (1) real arc-displaced terrain mesh near-field, (2) painted/impostor far-field honoring the interaction-fidelity Tier 0 rule, (3) haze-based seam, no vertex-bend shader at the transition. This should be the shape of the issue #2 prototype.
- **D3/substrate.md:** the coordinate substrate needs to expose ring-arc position (angle around circumference, offset across width) as first-class, since the terrain mesh generator needs it to compute real curvature — confirms this was already the right direction in the substrate v0 spec, not a new requirement.
- **Issue #2 prototype:** should explicitly re-test the April manifold/z-fighting lesson at the near-field/far-field seam, since that's precisely the boundary this resolution introduces.
- **Performance (D6/issue #8):** real arc geometry costs more than a flat plane or a bend shader (more mesh complexity to keep consistent with collision at range) — needs to be in the benchmark scene once one exists, not assumed free.

## Sources

- [What are halo rings and how can you deal with them? — 405th forums thread on Halo's faked skybox horizon](https://www.405th.com/forums/threads/what-would-halo-look-like-in-the-sky.26638/)
- [Curved World — vertex-displacement bend shader docs](https://amazing-assets.gitbook.io/curved-world)
- [World Bending Effect — Unity Tutorial, NotSlot](https://notslot.com/tutorials/2020/04/world-bending-effect)
- [Curved or rolling horizon shader discussion — bevyengine/bevy #10062](https://github.com/bevyengine/bevy/discussions/10062)
- [Kerbal Space Dev — On Quadtrees and why they are awesome](https://kerbalspace.tumblr.com/post/9056986834/on-quadtrees-and-why-they-are-awesome)
- [Planetary Scale LOD Terrain Generation — Leif Node](https://leifnode.com/2014/04/planetary-scale-lod-terrain-generation/)
- [GDC Vault — Continuous World Generation in No Man's Sky](https://www.gdcvault.com/play/1024265/Continuous-World-Generation-in-No)
