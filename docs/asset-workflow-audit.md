# Asset workflow audit — 2026-09-12

The catalogue worker is stopped. It produced five weapon prototype directories, no FOB or holographic map. At interruption its state recorded one approved spear, a blade blocked after six failures and a club in progress. Existing outputs and logs are preserved in the isolated asset-production checkout.

## Confirmed shared defect

The exported blade GLB contains distinct PBR values: rubber base colour approximately (0.010, 0.014, 0.012), steel (0.120, 0.155, 0.175), separate dark fittings and brighter cutting edge. Re-rendering that same file without modifying geometry or materials, while changing only the three review light powers to one-tenth, restored visible dark grip and material separation. The original review preview washed the surfaces toward pale grey.

This proves the review lighting contributed to the repeated material-read failures. It does not establish that every art rejection was wrong or that one-tenth is the final calibrated lighting standard. Shape and construction issues were also recorded. The earlier oversized cartoon blade was a real art-direction problem.

The reviewer explicitly identified the evidence-render path in a later blade rejection. The builder was restricted to model-workshop/, while the supervisor's renderer was installed outside that scope. The loop therefore sent a shared-pipeline problem back to an asset builder that could not fix it. Increasing the retry cap amplified the waste.

## Why attempts differ

- The failure counter combines build/tool failures, geometry/import failures and visual rejection. It is not an effort or quality metric.
- Style correction reset selected counters and reopened previous approvals; counts do not cover the complete history.
- Each model is independently authored; there is no mandatory shared, calibrated material library or accepted reference scene.
- Reviews are independent qualitative judgments. Earlier feedback included unjustified reach-to-length assumptions, and instructions could reinforce them through the README.
- A spear's simple longitudinal silhouette poses different representation problems from a blade's thin edge, manufactured planes and contrasting grip, despite both being melee weapons.
- Every repair pays for fresh model context, export, rendering and another review; a second approval now adds another call. Successful infrastructure-only reruns and model revisions are not distinguished.

## Before resuming art automation

1. Calibrate a fixed reference scene containing dark rubber, steel, paint and a known scale object; inspect both clean GLB renders and Godot appearance. Verify material values/assignments, not just counts.
2. Use that tested library and lighting for commissioned assets. Keep a stable accepted reference and compare successive outputs under identical conditions.
3. Classify failures by build, export, render, integration and art. A repeated shared failure pauses the pipeline instead of spending another asset revision.
4. Allow specific infrastructure defects to reach a separate repair step; do not ask the asset builder to compensate through geometry or albedo.
5. Separate visual revision counts, technical retries and review calls; preserve stage progress and content hashes to avoid unnecessary rebuild/render work.
6. Require meaningful improvement between art rounds. Two reviews alone do not guarantee good direction or convergence.
7. Commission assets for tested interactions. FOB maps/holograms need runtime functionality before a static mesh can be approved as sufficient.

Diagnostic evidence is local to the conversation workspace at work/asset-audit/; original evidence remains under the blade asset and worker runtime. The diagnostic did not overwrite the rejected asset or re-enable the worker.
