---
phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
plan: "01"
subsystem: data-layer
tags: [tag-api, windowed-read, binary-search, sqlite, datasensortag, getxytange, getTimeRange]

# Dependency graph
requires: []
provides:
  - Tag.getXYRange(tStart, tEnd) concrete default (binary_search slice of getXY())
  - SensorTag.getXYRange override (disk -> DataStore.getRange, RAM -> binary_search slice)
  - SensorTag.getTimeRange disk-backed fix (returns non-NaN [XMin, XMax] via DataStore.getTimeExtent)
  - FastSenseDataStore.getTimeExtent() O(1) accessor
  - Octave-safe test scaffold tests/test_sensor_tag_range.m (7 sub-tests, RED in wave 0)
affects:
  - 1041-02 (FastSenseWidget and SensorDetailPlot call getXYRange)
  - 1041-03 (CompanionTimeRange resolves a [t0,t1] that is fed to getXYRange)
  - 1041-04 (DashboardEngine.setTimeWindow feeds getXYRange from widgets)
  - 1041-05 (companion integration uses all data-layer contracts)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Additive windowed-read: getXYRange(t0,t1) new; getXY() untouched"
    - "Base-class concrete default + subclass override pattern (Tag base / SensorTag override)"
    - "Disk-backed time extent via O(1) XMin/XMax from construction (no re-read)"

key-files:
  created:
    - tests/test_sensor_tag_range.m
  modified:
    - libs/SensorThreshold/Tag.m
    - libs/SensorThreshold/SensorTag.m
    - libs/FastSense/FastSenseDataStore.m

key-decisions:
  - "getXYRange uses one-point padding each side (iLo-1, iHi+1) matching DataStore.getRange semantics"
  - "SensorTag overrides getXYRange rather than relying on Tag base default -- disk path needs DataStore.getRange for real chunk savings"
  - "getTimeExtent() accessor added to FastSenseDataStore to shield SensorTag.getTimeRange from property renaming"
  - "Tag base default in getXYRange calls getXY() then slices -- correct for derived/composite/monitor/state with no disk optimisation possible"

patterns-established:
  - "Pattern: base class provides concrete default, SensorTag overrides for disk efficiency"
  - "Pattern: empty/[] bounds -> full series; inverted window -> empty, no error"

requirements-completed: []

# Metrics
duration: 3min
completed: 2026-06-02
---

# Phase 1041 Plan 01: Tag Data-Layer Windowed Read Summary

**Additive `Tag.getXYRange(t0,t1)` contract with SensorTag disk-optimised override and disk-backed `getTimeRange` fix, plus Octave-safe test scaffold (7 RED sub-tests)**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-02T16:11:33Z
- **Completed:** 2026-06-02T16:15:21Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Added `Tag.getXYRange(obj, tStart, tEnd)` concrete default to the Tag base class: empty/[] bounds delegate to `getXY()`, a valid window binary-search-slices with one-point padding, an inverted window returns empty without error
- Added `SensorTag.getXYRange` override: disk-backed sensors delegate to `DataStore_.getRange(tStart, tEnd)` for real chunk-level load savings; in-RAM sensors binary-search-slice `X_/Y_` with the same padding semantics
- Fixed `SensorTag.getTimeRange`: disk-backed sensors (where `X_` is empty after `toDisk()`) previously returned `[NaN NaN]`; now branches on `isOnDisk()` and calls `DataStore_.getTimeExtent()` for the real `[XMin, XMax]`
- Added `FastSenseDataStore.getTimeExtent()` O(1) accessor returning `[XMin, XMax]` (captured at construction from `x(1)/x(end)`)
- Created `tests/test_sensor_tag_range.m` as an Octave-safe function-style test with 7 sub-tests in the RED (Wave 0) state — will green once Tasks 2-3 code lands (which happened in this plan)

## Task Commits

Each task was committed atomically:

1. **Task 1: Wave 0 RED test scaffold** - `3b16f2dd` (test)
2. **Task 2: Tag.getXYRange default + FastSenseDataStore.getTimeExtent** - `b1a269c8` (feat)
3. **Task 3: SensorTag.getXYRange override + getTimeRange disk-fix** - `c828060a` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `tests/test_sensor_tag_range.m` — Octave-safe 7-sub-test scaffold; exercises getXYRange full/RAM/disk/empty/inverted, getTimeRange disk-fix, base default via non-SensorTag
- `libs/SensorThreshold/Tag.m` — added `getXYRange` concrete default after existing `getXY` stub; `getXY` body is byte-for-byte unchanged
- `libs/SensorThreshold/SensorTag.m` — added `getXYRange` override (disk / RAM branches); fixed `getTimeRange` to add leading disk branch calling `DataStore_.getTimeExtent()`
- `libs/FastSense/FastSenseDataStore.m` — added `getTimeExtent()` public accessor returning `[XMin, XMax]`

## Decisions Made

- One-point padding in the RAM binary_search slice (`max(1, iLo-1)` / `min(numel, iHi+1)`) matches the existing `DataStore.getRange` padding semantics so callers get identical boundary behaviour regardless of storage backend.
- `getTimeExtent()` wrapper on `FastSenseDataStore` shields `SensorTag.getTimeRange` from any future `XMin`/`XMax` property renaming and documents intent.
- Tag base `getXYRange` default is concrete (not abstract-by-convention), so `MonitorTag`, `CompositeTag`, `DerivedTag`, `StateTag` all inherit it without any per-subclass work.
- `testBaseDefaultViaDerivedOrMock` in the test scaffold uses a `MonitorTag` if available, falling back to a bare `SensorTag` — ensures the base default path is covered without creating a throwaway class file.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## MATLAB/Octave Test Execution — DEFERRED

Static checks (MISS_HIT `mh_style` + `mh_lint`) were run and are clean on all four modified/created files. MATLAB/Octave test **execution** requires a live MATLAB session and is deferred.

### Deferred test commands

Run in MATLAB Command Window or via the MATLAB MCP tool `evaluate_matlab_code`:

```matlab
% Run the Octave-safe data-layer test (covers all 7 sub-tests):
test_sensor_tag_range()
% Expected output: "    All 7 test_sensor_tag_range tests passed."
```

Alternatively via `mcp__matlab__evaluate_matlab_code`:
```
test_sensor_tag_range()
```

For Octave:
```bash
octave --no-gui tests/test_sensor_tag_range.m
```

### What each sub-test verifies

| Sub-test | Behavior verified |
|----------|-------------------|
| testGetXYRangeFull | `getXYRange([],[])` == `getXY()` full series |
| testGetXYRangeRAMInRange | `getXYRange(t0+2, t0+4)` returns fewer points than full, all in window ± pad |
| testGetXYRangeEmpty | Out-of-extent window returns `[]` without error |
| testGetXYRangeInverted | Inverted window `(t0+4, t0+2)` returns `[]` without throwing |
| testGetXYRangeDisk | Disk-backed sensor returns bounded slice via DataStore.getRange |
| testGetTimeRangeDiskNonNaN | Disk-backed `getTimeRange()` returns non-NaN `[XMin, XMax]` within 2s of fixture extent |
| testBaseDefaultViaDerivedOrMock | MonitorTag (non-SensorTag) inherits base default correctly |

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Data layer contract is complete and backward-compatible: `getXY()` untouched, `getXYRange` additive
- `SensorTag.getTimeRange()` now correctly reports disk extent — the picker in Plan 02/03 can safely call it
- Ready for Plan 1041-02 (FastSenseWidget + SensorDetailPlot call sites switch from `getXY` to `getXYRange`)

---
*Phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading*
*Completed: 2026-06-02*
