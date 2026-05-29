---
phase: quick
plan: 260405-wol
subsystem: SensorThreshold / benchmarks / docs
tags: [threshold-api, migration, cleanup]
dependency_graph:
  requires: [Phase 1001 Threshold entity implementation]
  provides: [zero addThresholdRule calls outside Sensor.m deprecated compat layer]
  affects: [install.m, benchmarks, docs/generate_readme_images.m, ThresholdRule.m]
tech_stack:
  added: []
  patterns: [Threshold+addCondition+addThreshold first-class entity pattern]
key_files:
  modified:
    - install.m
    - benchmarks/benchmark_resolve_stress.m
    - benchmarks/benchmark_resolve.m
    - benchmarks/benchmark_memory.m
    - docs/generate_readme_images.m
    - libs/SensorThreshold/ThresholdRule.m
decisions: []
metrics:
  duration: "~5 min"
  completed: "2026-04-05T21:37:00Z"
  tasks: 2
  files: 6
---

# Quick Task 260405-wol: Migrate Remaining addThresholdRule Calls Summary

**One-liner:** Replaced all remaining `sensor.addThresholdRule()` calls in install.m, 3 benchmark files, and docs with the first-class `Threshold('key') + addCondition(state, value) + sensor.addThreshold(t)` pattern introduced in Phase 1001; fixed stale See-also comment in ThresholdRule.m.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Migrate addThresholdRule in install.m and 3 benchmark files | 2a49455 | install.m, benchmark_resolve_stress.m, benchmark_resolve.m, benchmark_memory.m |
| 2 | Migrate docs/generate_readme_images.m and fix ThresholdRule.m comment | 9736ef9 | docs/generate_readme_images.m, ThresholdRule.m |

## Changes Made

**install.m (JIT warmup):** 4 `addThresholdRule` calls replaced with 4 `Threshold` objects using `upper_N`/`lower_N` key convention (no labels in warmup code).

**benchmark_resolve_stress.m:** 12 `addThresholdRule` calls across 3 sections (initial sensor setup, JIT warmup sensor, timing loop sensor) replaced with Threshold objects. 2 `numel(s.ThresholdRules)` references replaced with `numel(s.Thresholds)`.

**benchmark_resolve.m:** 4 `addThresholdRule` calls in the timing loop replaced with Threshold objects (Warn Hi, Warn Lo, Alarm Hi, Alarm Lo).

**benchmark_memory.m:** 3 `addThresholdRule` calls (one per sensor `s`, `s2`, `s3`) replaced with separate Threshold objects (`tHH`, `tHH2`, `tHH3`) to avoid handle sharing across sensors.

**docs/generate_readme_images.m:** 3 `addThresholdRule` calls replaced with Run HI, Boost HI, Run LO Threshold objects.

**libs/SensorThreshold/ThresholdRule.m:** See-also comment updated from `Sensor.addThresholdRule` to `Sensor.addThreshold`.

## Verification

```
grep -rn 'addThresholdRule' --include='*.m' install.m benchmarks/ docs/ libs/ examples/ tests/ | grep -v 'Sensor.m' | grep -v 'test_' | grep -v 'Test'
# EXIT:1 (zero hits)

grep -rn 'ThresholdRules' --include='*.m' benchmarks/
# EXIT:1 (zero hits)
```

All remaining `ThresholdRules` occurrences in the codebase are in MATLAB comments only (not property access code) in example widget documentation headers.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- install.m: modified and committed (2a49455) — verified no addThresholdRule
- benchmark_resolve_stress.m: modified and committed (2a49455) — verified no addThresholdRule, no ThresholdRules
- benchmark_resolve.m: modified and committed (2a49455) — verified no addThresholdRule
- benchmark_memory.m: modified and committed (2a49455) — verified no addThresholdRule
- docs/generate_readme_images.m: modified and committed (9736ef9) — verified no addThresholdRule
- libs/SensorThreshold/ThresholdRule.m: comment updated and committed (9736ef9) — contains "Sensor.addThreshold"
