# Art direction: crude realism

> Production authority: docs/art-production-brief.md. E3 2000 purple accents, dramatic painterly sky and the current scale-giving haze are required context. Crude realism describes object construction, not a uniformly grey palette. The catalogue worker is disabled; this older object-only brief is insufficient to resume production. Capture and validate the shared world/reference scene and issue per-job contracts first.


The user's correction is authoritative: crudely realistic, not cartoonish. Halo CE refers to economical early-2000s real-time representation of believable objects, not toy proportions or a decorative faceted style. Low polygon count is a production constraint, not the subject of the design.

Use plausible manufactured or natural forms: thin cutting edges with credible spines, human-sized grips, modest guards, believable fasteners and joints, functional weight distribution, practical vehicle proportions, and natural animal anatomy. Keep broad surfaces where the real object has them. Avoid swollen silhouettes, chunky gold guards, bead-like grips, oversized bevels, candy colours, decorative spikes and gratuitous sci-fi assemblies. Primitive objects should remain simple, recognizable objects.

Materials must read as steel, rubber, leather, wood, paint or stone. Use restrained roughness and colour variation, local wear where contact would happen, and modest texture detail when it improves the object. Facets alone do not convey material. Do not wash everything into pale plastic or hide bad proportions behind grunge. Render evidence must show material separation under neutral light.

Scale: gameplay reach includes the user's body/arm and attack motion. It is NOT mesh length. Damage, reach and recoil values are gameplay data, not direct geometry dimensions. For a quick one-handed blade choose a physically plausible knife/short cutting tool: approximately 0.30–0.50 m overall with a 0.11–0.14 m grip, modest guard and plausible blade thickness. This is the direction for the rejected blade, not a universal dimension for all melee weapons. Actual catalogue vehicle length and wheel radius are physical dimensions and should be respected. Record physical dimensions separately from gameplay reach.

## Review and revision loop

First appraise the actual images without reading the asset README's aesthetic claims. State what the object looks like, whether its proportions and construction are credible, and the strongest evidence that it misses the target. Then compare the README and measured data. The global target and visible evidence outrank the asset author's description.

When README guidance caused a bad design, explicitly prescribe a README correction as well as mesh/material changes. The next builder rewrites the misleading intent/proportion/material guidance BEFORE rebuilding, records why the direction changed, and updates measured facts AFTER exporting. Do not merely rename a toy-like object as realistic or rewrite the target to excuse the existing result. Earlier reviewers can be wrong; do not inherit their approval or demands uncritically.

Every review round is saved with its rendered evidence and README snapshot. Revisions should identify which defects they corrected and any regressions. Two independent image reviews must approve the final exported version before completion. A fourth unsuccessful attempt stops the entire worker and writes runtime/RETRY_REVIEW_REQUIRED.json plus runtime/PAUSE. No later item is attempted. The flag records the asset, failure stage, reason and evidence location. Usage-limit waits do not consume attempts. Diagnose the object and shared pipeline, record the correction, and explicitly clear both flags before restarting; removing PAUSE alone cannot bypass the review stop. Reset the affected item only after diagnosis while the worker is stopped. This is a bounded improvement process, not endless polishing.

The existing blade is the explicit negative reference: oversized bronze/gold guard, thick broad blade, segmented toy-like grip, and a 1.3 m mesh justified by attack reach. Redesign it as a believable, utilitarian cutting tool. Spear, club, improvised weapon and rock also require reappraisal under this corrected standard; preserve useful work but disregard earlier aesthetic approval.
