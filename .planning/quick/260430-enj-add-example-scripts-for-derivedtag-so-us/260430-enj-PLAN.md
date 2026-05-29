---
quick_id: 260430-enj
description: add example scripts for DerivedTag so users can see how to use it
created: 2026-04-30
mode: quick
must_haves:
  truths:
    - DerivedTag was added in commit 583b510 (libs/SensorThreshold/DerivedTag.m).
    - Existing examples live under examples/NN-topic/ with cell-based sections,
      a top header listing what each example demonstrates, and a `run(install.m)`
      bootstrap line.
    - DerivedTag accepts function-handle OR object-form compute. Tests pass on
      Octave 11.1 + MATLAB-shaped class suite.
    - A DerivedTag can act as parent for a MonitorTag (verified by
      test_derivedtag tests). It cannot be a CompositeTag child.
  artifacts:
    - examples/02-sensors/example_derived_basic.m
    - examples/02-sensors/example_derived_state_gated.m
    - examples/02-sensors/example_derived_chain.m
  key_links:
    - libs/SensorThreshold/DerivedTag.m
    - examples/02-sensors/example_sensor_registry.m  (style reference)
    - examples/02-sensors/example_sensor_threshold.m (style reference)
---

# PLAN: DerivedTag examples

## Goal

Ship three runnable example scripts that demonstrate DerivedTag from the
"open this and learn it in 5 minutes" angle. Each example lives in
`examples/02-sensors/` (alongside SensorTag/StateTag/MonitorTag examples)
and follows the existing cell-based style.

## Tasks

### Task 1 — examples/02-sensors/example_derived_basic.m

Files: `examples/02-sensors/example_derived_basic.m`

Action:
- Create two SensorTag inputs (e.g. `pump_inlet`, `pump_outlet`) with
  synthetic pressure data on a shared time grid.
- Build a DerivedTag `differential_pressure` whose ComputeFn subtracts
  the inlet from the outlet.
- Demonstrate:
  - getXY() lazy compute
  - valueAt() ZOH lookup
  - Auto-invalidation: after `pump_outlet.updateData(...)`, getXY()
    returns fresh data without manually rebuilding the DerivedTag.
- Render with FastSense; print a one-liner summary so the script is
  useful headless.

Verify:
- Script runs in Octave (`octave --no-gui --eval "run(...)"`) without error.
- Final printed line confirms differential range matches expectation.

Done when: file exists, runs cleanly, demonstrates the three bullets above.

### Task 2 — examples/02-sensors/example_derived_state_gated.m

Files: `examples/02-sensors/example_derived_state_gated.m`

Action:
- Create a SensorTag `chamber_temp` (continuous) and a StateTag
  `machine_state` (discrete: 0=idle, 1=measuring, 2=cooling).
- Build a DerivedTag `temp_during_measuring` whose ComputeFn returns
  the temperature samples ONLY while state == 1, NaN otherwise.
- Demonstrate combining a SensorTag and a StateTag as parents and the
  recompute-on-parent-update behavior for both kinds of parent.
- Render with FastSense to show the gated signal.

Verify:
- Script runs in Octave without error.
- Number of non-NaN gated samples matches measured-state coverage.

Done when: file exists, runs cleanly, prints the non-NaN ratio.

### Task 3 — examples/02-sensors/example_derived_chain.m

Files: `examples/02-sensors/example_derived_chain.m`

Action:
- Build a four-level chain to show DerivedTag is a first-class Tag in
  the registry:
  1. Two SensorTag leaves (`flow_in`, `flow_out`)
  2. DerivedTag `flow_imbalance` = flow_in - flow_out
  3. MonitorTag `imbalance_alarm` over the DerivedTag (threshold |y| > k)
  4. CompositeTag aggregating the alarm with another MonitorTag using
     'or' semantics.
- Print the open-event count to demonstrate that updates to a SensorTag
  cascade through DerivedTag -> MonitorTag -> CompositeTag without any
  manual recompute.

Verify:
- Script runs in Octave without error.
- Console output shows ≥1 alarm fires after the initial getXY() call.

Done when: file exists, runs cleanly, prints alarm count.

## Out of scope

- Persistence (DerivedTag has no v1 persistence).
- Web-bridge / browser dashboard wiring (separate examples/06-webbridge area).
- Tests — covered already by tests/test_derivedtag.m and TestDerivedTag.m.
- Wiki page for DerivedTag (deferred; examples are the primary doc here).

## Acceptance

All three example files exist under examples/02-sensors/, each runs
cleanly under Octave 11.1 headless (no figures opened with
`--no-gui`), and each prints at least one informative line so the
script is useful even without a display.
