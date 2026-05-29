---
quick_id: 260430-enj
description: add example scripts for DerivedTag so users can see how to use it
date: 2026-04-30
status: complete
---

# SUMMARY — 260430-enj

## What shipped

Three runnable DerivedTag examples under `examples/02-sensors/`,
plus one drive-by integration fix in `libs/FastSense/FastSense.m`.

| File | Story it tells |
|---|---|
| `examples/02-sensors/example_derived_basic.m`        | Two SensorTags → DerivedTag = outlet - inlet. getXY, valueAt, parent-driven recompute. |
| `examples/02-sensors/example_derived_state_gated.m`  | SensorTag + StateTag → gated signal (NaN outside the measuring window). Cascade through both parent kinds. |
| `examples/02-sensors/example_derived_chain.m`        | Full chain: SensorTags → DerivedTag → MonitorTag → CompositeTag('or'). Root SensorTag updates cascade through every node. |

## Drive-by fix

`libs/FastSense/FastSense.m:962` — `addTag` switched on `getKind()` but
the dispatch table only listed `sensor / state / monitor / composite`.
Adding `case 'derived'` was needed for `fp.addTag(derivedTag)` in the
new examples. This was a real integration gap I missed in the original
DerivedTag landing audit (the broader `isa(t, 'Tag')` checks were fine,
but FastSense's explicit-kind switch was not).

The new case mirrors the `sensor` path: `[x, y] = tag.getXY(); addLine(...)`.

## Verification

- `example_derived_basic.m` — runs in Octave 11.1 headless; prints
  6000 samples, mean=2.5 bar, valueAt scalar+vector samples, and
  recompute count goes 1→2 after `outlet.updateData()`.
- `example_derived_state_gated.m` — prints 41.7% measuring coverage
  (250 / 600 samples), then 75% (450 / 600) after widening the state
  window via `machineState.updateData()`, then a fresh gated mean
  after a `chamberTemp.updateData()` call.
- `example_derived_chain.m` — prints initial 11% alarm fraction, then
  3% after a root-level `flow_out.updateData()` "fixes the leak";
  recompute counts on `flow_imbalance` and `imbalance_alarm` step
  from 1 → 2 demonstrating the listener cascade.
- Regression suites green on Octave 11.1: `test_derivedtag`,
  `test_compositetag` (30/30), `test_monitortag`, `test_fastsense_addtag`.
- MISS_HIT `mh_style` and `mh_lint` clean on all 4 touched files.

## Patterns the examples teach

1. **Function-handle compute** that takes the parents cell and returns
   `[X, Y]` — the simplest form.
2. **Mixed-kind parents** — DerivedTag doesn't care whether parents are
   SensorTag, StateTag, MonitorTag, or another DerivedTag, as long as
   they implement the Tag contract.
3. **Listener cascade** — the user never has to "rebuild" or
   "re-evaluate" the chain. `parent.updateData(...)` is the only
   mutation entry point and propagates automatically.
4. **DerivedTag as MonitorTag parent** — making it clear that derived
   signals are first-class for thresholding, not a second-tier "view".

## Files

- `examples/02-sensors/example_derived_basic.m`         (new)
- `examples/02-sensors/example_derived_state_gated.m`   (new)
- `examples/02-sensors/example_derived_chain.m`         (new)
- `libs/FastSense/FastSense.m`                          (modified — added 'derived' case to addTag)
- `.planning/quick/260430-enj-add-example-scripts-for-derivedtag-so-us/260430-enj-PLAN.md`     (new)
- `.planning/quick/260430-enj-add-example-scripts-for-derivedtag-so-us/260430-enj-SUMMARY.md` (new)

## Out of scope (deferred, intentional)

- A fourth example showing serializable object-form ComputeFn for
  DerivedTag (the test stub `ComputeAddStubForDerivedTagTests` already
  proves the path; an example is nice-to-have, not blocker).
- Wiki page generation. The existing docstring header on
  `DerivedTag.m` is comprehensive; a wiki page is a separate task.
- Adding DerivedTag-aware widgets to `libs/Dashboard/`. Existing
  widgets accept any `Tag` so they already work transparently.
