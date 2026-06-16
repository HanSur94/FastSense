---
phase: 1045-cross-machine-comparison-view
plan: "01"
subsystem: fleet-model
tags: [canonical-mapper, pure-helpers, octave-safe, resolve-seam]
requirements: [CMP-02, CMP-03, CMP-04, CMP-05]

dependency_graph:
  requires: []
  provides:
    - "CanonicalMapper.resolve(logicalId, machineId) -> entry struct | [] (no side effects; CMP-05 seam)"
    - "Fleet.mapper() public accessor (mirrors machineIds())"
    - "buildCompareResolution_ per-machine row assembly + LOW gate + unit-mismatch"
    - "compareSeriesColor_ stable per-machine color by fleet insertion index (CMP-02)"
  affects:
    - libs/Fleet/CanonicalMapper.m
    - libs/Fleet/Fleet.m
    - libs/FastSenseCompanion/private/buildCompareResolution_.m
    - libs/FastSenseCompanion/private/compareSeriesColor_.m
    - libs/FastSenseCompanion/runCompareResolutionTests.m
    - tests/test_compare_resolution.m

tech_stack:
  added: []
  patterns:
    - "containers.Map bucket-scan resolve mirroring isResolvable (read-only)"
    - "Octave-safe pure helper shape (filterMachines analog): no isa/contains/validateattributes"

key_files:
  created:
    - libs/FastSenseCompanion/private/buildCompareResolution_.m
    - libs/FastSenseCompanion/private/compareSeriesColor_.m
    - libs/FastSenseCompanion/runCompareResolutionTests.m
    - tests/test_compare_resolution.m
  modified:
    - libs/Fleet/CanonicalMapper.m
    - libs/Fleet/Fleet.m

decisions:
  - "The confidence gate (LOW+AUTO -> excluded by default) lives in buildCompareResolution_, NOT in CanonicalMapper.resolve — resolve is a pure read seam so the dialog/helper layer owns policy (invariant #4)."
  - "Fleet.mapper() added as a documented public accessor so callers reach the embedded CanonicalMapper without touching the private Mapper_ field."

metrics:
  commit: 4f6f6a39
  tests: "tests/test_compare_resolution.m 7/7 (resolve hit/miss; mapper accessor; auto/confirm_needed/none states; unit-mismatch; theme-color; per-machine color stability)"
---

# Plan 1045-01 Summary

The pure-logic foundation for the cross-machine comparison. `CanonicalMapper.resolve(logicalId, machineId)` returns the matched entry struct (or `[]`) with no side effects — the read seam Phase 1045 resolves once at compare-open time. `Fleet.mapper()` exposes the embedded mapper through a documented accessor (mirroring `machineIds()`). `buildCompareResolution_` assembles a per-machine row struct array, applying the LOW-confidence gate (`AUTO`+`LOW` → `confirm_needed`, excluded by default — invariant #4) and unit-mismatch detection, with an optional 3-arg theme path that populates each row's swatch color via `compareSeriesColor_` (stable per fleet insertion index, modulo the palette — CMP-02). All Octave-safe (no `isa`/`contains`/`validateattributes`).

**Verification:** `tests/test_compare_resolution.m` 7/7 (resolve hit/miss, mapper accessor, the three states, unit-mismatch, theme-color, per-machine color stability).

**Deviations:** none. (Summary backfilled during Phase 1045 closeout — the original Wave-1 commit landed without a SUMMARY when the execution agent terminated early; code + tests were already committed and green.)
