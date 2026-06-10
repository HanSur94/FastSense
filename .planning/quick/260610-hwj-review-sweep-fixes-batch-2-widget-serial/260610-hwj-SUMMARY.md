---
quick_id: 260610-hwj
status: complete
date: 2026-06-10
---

# Summary: Review-sweep fixes batch 2

All five fixes landed in one commit (18387785) on claude/review-fixes-batch2.
See PLAN.md for the fix list. Notable: the gauge fix surfaced a second latent bug
(allValues() crash on MonitorTag-bound gauge construction since the v2.0 migration);
both fixed. Octave gates: themeOverride test gated (Octave feval cannot resolve
dotted static methods — pre-existing registry-dispatch limitation).

Verification (live R2025b + local Octave 11.1): batch2 tests 4/4 / 3/3+gate,
event_markers 9/9, SerializerRoundTrip 15/15, Serializer 12/12, toolbar 19/19.
