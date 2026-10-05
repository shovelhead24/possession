# Workshop vehicle capture

F8 begins a capture with the preceding five seconds, then ends it on the next
press. `vehicle_samples` batches share the editor trace and marker ID. Each
sample has its own monotonic `sample_usec` and physics-frame number; the outer
event time is serialization time, not measurement time.

Both vehicles record motion, control inputs, freeze state and streaming brakes/limits.
Wheel samples (four Warthog wheels, eight tank contacts) also record grounded state, contact, collider ID, normal,
travel/delta, compression, angular speed and slip. Null speed limit means unlimited;
null contact means not grounded. Frozen suspension values are stale, not fresh hits.
The previous contact is probed vertically (+1m to -2m), excluding the vehicle and
its suspension exclusions, to distinguish fixed-position surface changes from
movement over slopes. A missed probe is explicit, not a zero-height change.
These local probes cannot detect changes beyond their range or prove causality.

History is capped at 600 physics samples and filtered to five seconds at capture.
Only marked captures serialize to disk, in process callbacks, except immediate
marker/exit flushing. Active captures grow on disk until ended; no cache is purged.
`sampling_ms` measures recorder work, not serialization. Compare frame-stall logs
as well when assessing overhead. This instrumentation changes no handling rules.

`benchmarks/check_vehicle_trace.gd` runs the real workshop, checks pre-roll and
marked persistence, ordered timestamps, both vehicles and bounded history without
saving the terrain recipe.
