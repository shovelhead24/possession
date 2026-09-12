# Art production brief — E3 2000 memory, ring-scale sky

2026-09-12. Authoritative written art direction for the current prototype. This supersedes generic “Halo CE low-poly” prompts and the old claim that the retail Level 2 overlook is the sole palette target. The worker remains paused: a validated reference scene and per-job specification are required before production resumes.

## 1. Reference hierarchy and intended impression

**User-directed primary reference:** the Halo E3 2000 demonstration, especially its purple presence, the remembered pronounced purple vehicle lights, and dramatic sky. These details are the user's desired aesthetic, not a claim that this document has independently analysed trailer frames. The [archived original trailer listing](https://halo.bungie.org/e3trailermirrors.html) identifies the 9:42 presentation and DVD-derived version. Avoid treating modern remasters, reconstructions or AI-upscaled footage as the original reference.

**Supporting existing direction:** [aesthetic.md](aesthetic.md), [rendering.md](rendering.md), [ring-curve moment](moments/ring_curve.md) and [night-sky moment](moments/night_sky.md). Keep their silhouette-first composition, atmospheric depth, negative space and emotionally important sky. Retail Halo's pastoral blue-green terrain is a supporting ingredient rather than a competing exclusive palette. The earlier Forge World reference concerns distant silhouette interest, not colour authority.

Desired impression: practical, weighty objects and broad, painterly landscape forms beneath a vast, dramatic sky; purple illumination and atmosphere give the technology and distance character. The near objects can be crudely realistic while the distant image is painterly. Low fidelity must feel deliberate. Avoid toy proportions, pastel miniature presentation, sterile catalogue renders and uniformly grey military realism.

## 2. Composition and colour

The sky is a primary art deliverable. The user's “roughly 50%” describes its importance and typical outdoor screen presence outside valleys, not a rule to force the camera upward or maintain a fixed pixel ratio. Approve outdoor assets in the landscape/sky composition where they will be used.

Proposed palette relationships to establish in the reference scene:

| Role | Direction | Guardrail |
|---|---|---|
| Sky masses and distance | Violet, indigo and purple-grey depth, pale cool openings, selective warm cloud light | Large composed masses and quiet areas; avoid uniform purple fog or high-frequency cloud noise. |
| Ground | Restrained blue-green/earth/stone families | Provide contrast with sky and technology without making every biome identical. |
| Practical hardware | Believable dark rubber, painted metal, steel and worn construction | Preserve material separation; no swollen gold guards or candy-like fittings. |
| Technology accents | Deliberate purple/violet light on projectors, relays and selected vehicle details | Purple is not automatically an enemy-team label. Exact placements and brightness are per-object decisions. |
| Holograms | Purple/violet luminous structure with clearly separated map content | Brightness must preserve routes/text/sector shapes and threats beyond the projection; avoid a solid glowing blob. |

No final numeric palette or emission strengths are ratified without the in-engine reference view. Use shape, position, pulse and sound alongside colour for gameplay state. “Restrained materials” must not erase the wanted purple accents.

## 3. Sky: mostly static, visibly alive

### Preserve the current build's haze

The user identifies the current in-game haze as a defining source of the ring's sense of scale. It is a primary visual reference, not a defect to remove or a temporary performance trick. Capture the current build from repeatable near/middle/far viewpoints before look-development changes. Preserve the depth separation, distance colour falloff and relationship between terrain, visible ring and sky that the user values. Test painterly sky layers through that existing treatment first; do not replace it with a generic preset or clear it away to expose more distant detail.

The desired balance is legible nearby action with distance progressively absorbed into atmosphere. The exact current implementation and tuning should be recorded from the build rather than guessed in this document. No fog-density change, new haze model or global colour grade is commissioned by this brief. The washed-out neutral asset-review renders were a separate lighting defect and must not be used as an argument to reduce the game haze.

**Adopted visual intent:** painterly appearance; economical, nearly static large composition with some motion. Exact implementation is proposed. The scene must hold as a still image before motion is added.

Separate three concerns:

- **Large painted composition:** broad cloud masses, gradients and distant atmospheric colour can use a small reusable set of painted textures or baked fields. Avoid building an entire ring's unique high-resolution sky artwork.
- **Spatially anchored ring:** reachable far-side terrain, city lights and landmarks remain located in ring coordinates. Reuse the established geometric/LOD representation with painterly shading or baked appearance. A camera-centred infinite panorama must not contain reachable geography. Camera translation, altitude changes and flight must preserve angular position, parallax, occlusion and the eventual transition to real terrain.
- **Limited movement/state:** a small number of slow cloud/wisp layers, restrained changes in illumination and occasional story-controlled light changes can keep the view alive. Wind motion belongs to clouds, not to mountains. Cloud shadows, day/night transitions and weather frequency are optional experiments; they do not settle campaign time or require full atmospheric simulation.

Recompute view-dependent projection as the player moves even when the artwork and lighting state are cached. “Nearly static” describes the atmosphere's visual evolution, not a frozen image that slides with the camera. Distant celestial backgrounds may use an effectively infinite sky; the visible ring cannot.

For ring-scale reuse, anchor a small family of broad atmosphere treatments to regions/states and blend transitions deliberately. Test a seam, a turn, an approach and an altitude change. Do not claim this scales based on a single stationary beauty shot. Existing GL Compatibility/Intel UHD and co-op constraints apply; measure texture memory, overdraw and frame time. Avoid assuming volumetric clouds, compute shaders or many real-time lights are affordable. Existing ring dimensions are unchanged.

## 4. Shapes and surfaces

Use real construction logic: plausible thickness, attachment, grip scale, joints and material behaviour. Simplify through broad forms and coarse readable textures. Do not add facets, bevels or small components merely to demonstrate modelling effort. Painterly distance does not licence toy-like near objects.

Human interaction gives scale to FOB doors, tables, consoles and vehicles. Weapon sizes are documented prototype choices; attack reach is not mesh length. Fine numeric budgets depend on the prototype's measured scene, not an arbitrary universal triangle count. Existing weapon/vehicle ceilings remain historical worker limits, not a budget for the entire FOB or sky.

## 5. First required art/interaction set

| Deliverable | Design job | Evidence required before production approval |
|---|---|---|
| Outdoor reference scene | Establish the sky/ground/structure/vehicle colour relationship, including purple accents | Fixed reference viewpoints plus a moving-camera/altitude test; neutral material comparison. |
| FOB planning table/projector | A physical place to plan; credible hardware supporting a readable luminous map | Player-height interaction, route selection and comms coverage under outdoor and sheltered lighting. |
| Relay and console | A distant landmark and a nearby operable network node | Hostile/offline/linking/operational states distinguishable through motion/form/sound, not colour alone. |
| Modular FOB shell | Recognisable new home/departure point with useful circulation | Movement from planning to rearm/deployment; entrances and important objects read against the sky. |
| Minimal vehicle/material pass | Establish the desired purple lighting on practical hardware using an existing vehicle first | Emissive details readable in day and dusk without tinting the entire vehicle or hiding its construction. |
| Optional portable hologram | Test the companion's stop-to-view local display proposal | Projection start/stop, readable local information and ability to notice surrounding danger; no full mobile mission-planning screen by assumption. |

A holographic map needs runtime geometry/shader/content/state/interaction work. A GLB or a raster mock-up alone cannot fulfil that job. No catalogue-wide weapons or creature production until the required gameplay objects and style reference are working.

## 6. Required brief for every worker job

Every assignment must supply: intended player use; in-world setting and reference-scene lighting; silhouettes and real construction references; palette/material roles; physical scale and axes; named interaction points and state changes; file/export/integration contract; scene-specific performance limits; required comparison shots and play tests; explicit exclusions; and a definition of done.

Workers must identify missing mandatory inputs as a specification gap. They must not infer combat requirements from catalogue statistics or silently invent story symbols, factions and capabilities. An approved shared material/lighting setup and a visual target accompany the written brief. The README records intent and measured facts, while reviews can correct misleading instructions without redefining the user's target to excuse a weak result.

## 7. Review and calibration

First calibrate dark rubber, steel, paint and emissive violet in a fixed reference scene and a clean GLB re-import. Check that material parameters and assignments survive export. The earlier blade audit proved that the shared review lighting washed out actual material differences; darker albedo and repeated mesh rebuilding were not an adequate remedy.

Use two complementary views: neutral inspection establishes construction and material correctness; the intended world composition establishes aesthetic fit. Keep exposure, camera and reference objects fixed between iterations. Inspect the sky in motion and holograms in use. A neutral studio render alone cannot approve the E3-inspired outdoor aesthetic.

Classify failures as specification, model, material/export, review-render, interaction or performance failures. Repeated infrastructure faults pause the shared pipeline and go to an appropriately scoped repair task. Track art revisions separately from technical retries. A second reviewer is useful after the evidence is trustworthy; repetition alone is not convergence.

## 8. Production gates still open

The written direction is now explicit. Before autonomous art production: assemble annotated original-reference frames; agree one in-engine sky/world look-development view; calibrate the neutral material comparison; validate the FOB/map/relay greybox interactions; then issue bounded job briefs. Exact palette values, sky texture sizes, motion rates, emission settings and per-object budgets emerge from those tests. The worker stays disabled until that work is done and its scope is updated deliberately.
