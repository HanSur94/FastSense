---
phase: 260609-v5p
plan: "01"
subsystem: dashboard
tags: [perf, dashboard, live-refresh, fastsense-widget]
dependency_graph:
  requires: []
  provides: [data-unchanged-fast-path, vectorized-event-marker-hot-paths]
  affects: [libs/Dashboard/FastSenseWidget.m, libs/Dashboard/DashboardEngine.m]
tech_stack:
  added: []
  patterns: [fingerprint-cache, optional-arg-single-pull, isequal-diff, sortrows-dedup]
key_files:
  created:
    - benchmarks/bench_dashboard_live.m
  modified:
    - libs/Dashboard/FastSenseWidget.m
    - libs/Dashboard/DashboardEngine.m
    - tests/test_dashboard_perf_fixes.m
decisions:
  - "Fingerprint is [n, x(1), x(end), y(end)] — valid only under append-only assumption shared with PreviewCacheKey_; reset in setTimeWindow and rebuildForTag_ to force a full update when context changes"
  - "refreshEventMarkers_ uses conservative order-sensitive isequal comparison (reorder triggers one redundant redraw; a real change is never missed)"
  - "computeEventMarkers sortrows-based dedup: sort [idx, sev] ascending so last row in each group has max severity, same tiebreaker as previous O(U*N) loop"
  - "Test B uses two FastSenseWidget(inline) + StubEventStore rather than a custom class file; addWidget accepts pre-constructed DashboardWidget objects"
  - "Benchmark uses EventStore('') (in-memory) with real Event objects to make computeEventMarkers do non-trivial work without test infrastructure"
metrics:
  duration: "~25 min"
  completed: "2026-06-09"
  tasks_completed: 3
  files_modified: 4
---

# Phase 260609-v5p Plan 01: Speed Up DashboardEngine Live-Refresh Hot Path — Summary

**One-liner:** Data-unchanged fast path in FastSenseWidget (fingerprint cache + skip) + single Tag.getXY() pull + O(nE) marker diff + vectorized getEventMarkers/computeEventMarkers/formatTimeAxis_.

## What Was Built

### Task 1 — Widget hot-path fixes (commit `8cd6443f`)

**FastSenseWidget.m — six changes:**

1. **Data-unchanged fast path (`LastDataFingerprint_`):** Both `update()` and `refresh()` fast branches compute a 4-element fingerprint `[n, x(1), x(end), y(end)]` immediately after `pullData_()`. If the fingerprint matches `LastDataFingerprint_` and the widget is in a renderable state, the tick sets `LastTickSkipped_ = true`, calls `refreshEventMarkers_()` (event state changes independently of sample data), and returns — skipping `updateData`, `updateTimeRangeCache`, `invalidatePreviewCache_`, and `formatTimeAxis_`. On changed data: store the new fingerprint, set `LastTickSkipped_ = false`, and run the existing full path.

2. **Single pull (`updateTimeRangeCache(x)`):** Added optional `x` argument (additive, no breaking change). Full-path callers in `update()` and `refresh()` now pass the already-pulled `x`, eliminating a redundant `Tag.getXY()` call. All other callers (e.g. `rebuildForTag_`, `fromStruct`) call without the argument and get the original behavior unchanged.

3. **O(nE) marker diff (`refreshEventMarkers_`):** Replaced the O(nE^2) nested `strcmp`/`find` loop with a single conservative `isequal` comparison: `changed = ~isequal(ids, obj.LastEventIds_) || ~isequal(openFlags, obj.LastEventOpen_) || ~isequal(sevs, obj.LastEventSeverity_)`. Order-sensitive: a pure reorder may trigger one extra redraw, but a real change is never missed.

4. **Fingerprint resets:** `LastDataFingerprint_` is reset to `[]` in `setTimeWindow` (window change = different pullData_ result) and at the top of `rebuildForTag_` (full rebuild forces full update on next tick). Fresh widgets and `fromStruct` pre-render path start with `[]` naturally.

5. **Preallocation in `getEventMarkers`:** Replaced per-element AGROW struct growth with preallocated `tArr`/`sevArr` numeric arrays, filled in the existing loop (all defensive `isstruct`/`isprop` branches preserved). After the loop: mask non-finite times, compute colors once per unique severity (via `unique(sevArr)` + lookup), then build the struct array in one shot with `struct('Time', num2cell(...), 'Severity', ..., 'Color', ...)`.

6. **Vectorized `formatTimeAxis_`:** Replaced the per-tick `datestr` loop with `cellstr(datestr(xt(:) ./ 86400, fmt))` — a single vectorized call. Equivalent output on MATLAB R2020b+ and Octave 7+.

**DashboardEngine.m — Change 4 (computeEventMarkers):**

- **Vectorized accumulation for `getEventMarkers` path:** Replaced per-element AGROW with whole-array extraction (`[ms.Time]`, `[ms.Severity]`) + color matrix construction. Defensive per-element fallback if vector shapes mismatch.
- **Vectorized accumulation for legacy `getEventTimes` path:** `allTimes = [allTimes, tVec]` + `allSev = [allSev, ones(1, nLeg)]` + `allColors = [allColors; repmat(okColor, nLeg, 1)]`.
- **Sort-based dedup:** Replaced O(U*N) `find(idx == k)` loop with `sortrows([idx(:), allSev(:)])` so within each idx group the max-severity row sorts last. `grpEnd = [find(diff(idx(order)) ~= 0); numel(order)]` picks the last row of each group. Same max-severity-wins tiebreaker as before, now O(nE log nE).

### Task 2 — Regression tests (commit `c29be759`)

Extended `tests/test_dashboard_perf_fixes.m` with two new try/catch blocks:

- **TEST A:** Creates a 50-pt SensorTag-bound FastSenseWidget, renders, warms up with one `update()`, calls `update()` a second time with no data change, asserts `LastTickSkipped_ == true`. Appends 10 samples, calls `update()` again, asserts `LastTickSkipped_ == false` and (where the line handle is reachable) that `numel(XData)` grew.

- **TEST B:** Two `FastSenseWidget(inline)` instances with StubEventStore events at the same `StartTime=100` and Severity 1 vs 3. After `DashboardEngine.computeEventMarkers()`, asserts exactly one deduped marker at t=100 colored by severity-3. Skipped gracefully when `TimeRangeSelector` is unavailable (headless CI).

### Task 3 — Live-tick benchmark (commit `cbd66937`)

New `benchmarks/bench_dashboard_live.m`: 8 SensorTag-bound FastSenseWidgets (50k pts each), EventStore with 200 events (severity 1/2/3 cycle) wired to widget 0, rendered, then timed over:
- **Scenario A (idle):** 10 `onLiveTick()` calls with no data change. Fast path makes these near-free.
- **Scenario B (active):** 10 `onLiveTick()` calls each preceded by `updateData` appending 100 pts per tag. Full update path with single pull.

Prints `avg idle onLiveTick: X.XX ms` and `avg active onLiveTick: X.XX ms`.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes.

## Self-Check: PASSED

- `libs/Dashboard/FastSenseWidget.m` — exists and contains `LastDataFingerprint_`, `LastTickSkipped_`, `updateTimeRangeCache(x)`, `cellstr(datestr`
- `libs/Dashboard/DashboardEngine.m` — exists and contains `sortrows(\[idx`
- `tests/test_dashboard_perf_fixes.m` — exists and contains `LastTickSkipped_`, `FastSenseWidget('Tag'`
- `benchmarks/bench_dashboard_live.m` — exists and contains `onLiveTick`, `SensorTag`, `install()`
- Commits `8cd6443f`, `c29be759`, `cbd66937` verified in `git log`
- No lines exceed 160 chars across all four files
- No `arguments` blocks in MATLAB files
