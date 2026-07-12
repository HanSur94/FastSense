---
phase: quick-260629-tgy
plan: "01"
subsystem: SensorThreshold
tags: [tag, integral, trapezoid, sensor-math, issue-327]
dependency_graph:
  requires: [Tag.getXY, Tag.getXYRange]
  provides: [Tag.cumulativeIntegral]
  affects: [all Tag subclasses]
tech_stack:
  added: []
  patterns: [cumsum-based gap-robust trapezoidal accumulation]
key_files:
  created: []
  modified:
    - libs/SensorThreshold/Tag.m
    - tests/suite/TestTag.m
decisions:
  - "Gap-robust via zero-out of non-finite segment areas (not cumtrapz directly) so interior NaN does not poison the running tail"
  - "Empty series returns scalar 0 in 1-out form (integrates to 0); [] in 2-out form"
  - "Single-sample series: cum=0 (no interval bounds any area)"
  - "Warn Tag:integralOnDiscrete for StateTag kind but still return value — warn, not error"
  - "Method is CONCRETE (no Tag:notImplemented string) — abstract stub count stays at 6"
metrics:
  duration: "~10 minutes"
  completed: "2026-06-29"
  tasks_completed: 2
  files_changed: 2
---

# Phase quick-260629-tgy Plan 01: Tag.cumulativeIntegral Trapezoidal Total Summary

**One-liner:** Gap-robust trapezoidal integrator on the Tag base class using per-segment cumsum with NaN zeroing, inherited by all subclasses (SensorTag, StateTag, MonitorTag, CompositeTag, DerivedTag, MockTag).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Implement Tag.cumulativeIntegral | acbd504a | libs/SensorThreshold/Tag.m |
| 2 | Add cumulativeIntegral unit tests to TestTag | fee2892b | tests/suite/TestTag.m |

## What Was Built

### Tag.cumulativeIntegral (libs/SensorThreshold/Tag.m)

Concrete public method added immediately after `getXYRange` in the public methods block. Signature: `function varargout = cumulativeIntegral(obj, varargin)`.

Key behaviors:
- **Option parsing**: single `'Range',[t0 t1]` name-value pair via inline switch (mirrors Tag constructor style); unknown keys raise `Tag:unknownOption`
- **Data fetch**: `getXYRange(t0,t1)` when Range provided, else `getXY()`
- **Discrete warning**: emits `Tag:integralOnDiscrete` when `getKind()=='state'`; still returns a value
- **Row coercion**: X and Y forced to row vectors for consistent output shape
- **Empty guard**: 1-out returns `0`, 2-out returns `[],[]`
- **Single-sample guard**: cum=0 (no interval = no area)
- **Gap-robust algorithm**: `dt = diff(X); area = 0.5.*dt.*(Y(1:end-1)+Y(2:end)); area(~isfinite(area))=0; cum=[0,cumsum(area)]` — equivalent to cumtrapz(X,Y) when no NaNs present
- **Output dispatch**: `nargout<=1` → scalar `cum(end)`; `nargout==2` → `[X, cum]`
- **Abstract stub count**: unchanged at exactly 6 occurrences of `Tag:notImplemented`

### TestTag.m additions (8 new test methods)

1. `testCumulativeIntegralUniformRamp` — constant Y=2, X=0:4, expects cum=[0 2 4 6 8]
2. `testCumulativeIntegralNonUniform` — X=[0 1 3 7], Y=[1 3 3 1], hand-verified total=16
3. `testCumulativeIntegralRangeWindow` — 'Range' option; expected derived from actual getXYRange return (accounts for one-point boundary padding)
4. `testCumulativeIntegralScalarForm` — 1-out scalar equals 2-out cum(end)
5. `testCumulativeIntegralEmptyData` — MockTag; 1-out=0, 2-out empty, no error
6. `testCumulativeIntegralNaNGap` — Y=[1 1 NaN 1 1]; all cum values finite, cum(end)>0
7. `testCumulativeIntegralDiscreteWarns` — StateTag triggers Tag:integralOnDiscrete; still returns numeric
8. `testCumulativeIntegralUnknownOption` — bogus key throws Tag:unknownOption

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

- `grep -c "Tag:notImplemented" libs/SensorThreshold/Tag.m` = **6** (abstract-stub gate intact)
- `grep -c "function varargout = cumulativeIntegral" libs/SensorThreshold/Tag.m` = **1**
- `grep -c "function testCumulativeIntegral" tests/suite/TestTag.m` = **8** (>= 7 required)
- All lines <= 160 chars in both modified files
- No tabs; 4-space indent throughout
- No toolbox calls; no MEX; pure MATLAB/Octave

MATLAB suite run deferred to orchestrator warm session per constraints.

## Known Stubs

None — all behaviors are fully implemented.

## Threat Flags

None — this is a pure computational utility with no network, file, auth, or schema surface.

## Self-Check: PASSED

- `libs/SensorThreshold/Tag.m` modified and committed at acbd504a
- `tests/suite/TestTag.m` modified and committed at fee2892b
- Both commits present in git log
- Abstract stub count verified at 6 (unchanged)
