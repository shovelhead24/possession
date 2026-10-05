# Vehicle streaming refinement

The recorded Warthog hitch included repeated binary streaming brakes, not sampled
ground-height changes. Maintain vehicle top speed: supply terrain earlier rather
than use a lower cap as the performance fix.

The workshop predicts the driven vehicle's corridor from intended top speed as
well as current speed, with a stopping-distance term plus loading lead. Nearby
driver chunks get queue priority and a wider corridor allows modest steering.
The immediate collision runway is queued before speculative outer shoulders;
radial ordering alone spent worker time on dense roadside features before supply
ahead. The steering shoulders remain wanted and existing safeguards remain.
This preference applies only with small steering input and yaw rate. During
turns, broad radial priority is retained: unconditional runway preference failed
the sustained-turn check at 34.54 m/s with 436 brake ticks. That failed result
was retained and caused the conditional correction, not an assertion change.
Recently wanted, current-revision resident
chunks get a bounded grace period (no extra generation for retired demand and no
disk deletion). This reduces reload churn on small direction/corridor changes.

The supply speed ceiling is separate from vehicle top speed. It drops immediately
when supply shrinks, holds before recovering, and recovers gradually. Power tapers
before the ceiling and brakes use a proportional, rate-limited demand, instead of
full-force on/off pulses. A near-empty runway applies immediate braking; the
existing missing-neighbourhood freeze and finite-arena containment remain.
These are prototype safeguards, not a proof of stopping distance on every slope.

F8 also logs continuous brake amount and drive scale. Unit tests cover recovery,
full-speed supply and emergency demand; the rendered driving test checks speed
and deliberate starvation/recovery. Performance runs must be the only Godot
instance. A straight route does not establish turning performance or cold-cache
behaviour; use the interactive marked run for the reported route.

2026-10-05 resumed stress validation: the initial 18-second mixed-cache route
peaked at 27.78 m/s with 394 brake ticks and no freezes. An extended 75-second
run reached z=-386 m at 32.09 m/s peak, with 2809 brake ticks. Runway priority's
75-second run reached z=-578 m, peak 41.31 m/s, 2479 brake ticks, no freezes.
These are different cache states, not a controlled improvement comparison.
The last run installed 130 chunks (104 cached, 26 newly generated), with maximum
generation 9268.6 ms, install 25.2 ms, collision creation 23.8 ms and upload API
call 1.8 ms. Maximum observed physics wall gap was 63.9 ms; this is not a GPU
timer or complete frame percentile measurement. Tier 3 remained heavily supply
limited. Dense cold generation is not solved by proportional braking.

The drive harness now records route endpoints, minimum Z, per-tier continuous
brake/power statistics and optional `--terrain-profile` installation records.
Stress runs stop at z=-620 m or 75 seconds and report safeguard success separately
from performance. Failures exit with nonzero status, and startup has a bounded
600-second timeout. Earlier short tests did not establish full course traversal.

Subsequent cached-course traversal reached z=-620.02 m in 937 physics samples,
peak 44.41 m/s, zero streaming brakes, power limiting and freezes. All three
tiers were reached; deliberate starvation and recovery passed. Some speculative
outer shoulders still generated, so this is a cached driving runway rather than
an entirely cache-only workload. Physical geometry checks passed all 12 stations
and 12 curved bores. Generated tier snapshots still show the existing coarse/fine
visual approximation while distant chunks load; they are not seamless LOD proof.

Final conditional-policy sustained-turn test: 35 seconds, peak 44.51 m/s,
zero brake/freeze ticks, 102 power-limited ticks out of 2101, minimum drive
scale 0.75. Deliberate starvation/recovery passed. This replaces neither the
failed unconditional-priority result nor the historical wide-turn assertion
failure; each used the policy/assertions recorded with its own log.

Final conditional-policy cached stress rerun also completed: z=-620.63 m,
938 physics samples, peak 44.40 m/s, zero brakes/power limiting/freezes,
starvation/recovery passed. This is the final source iteration's course result.

Airborne travel needs a speed/load-latency prediction volume, turn/climb envelopes
and separate visual/collision priorities. The current finite ground corridor is
not an aircraft streaming solution. Do not just lower aircraft speed or multiply
fine collision residency across the entire view distance.
