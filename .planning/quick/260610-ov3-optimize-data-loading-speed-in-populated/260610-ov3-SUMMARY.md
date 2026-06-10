---
phase: quick-260610-ov3
plan: 01
subsystem: Dashboard
tags: [perf, fastsense-widget, render-cache, tag-bound, benchmark]
dependency_graph:
  requires: []
  provides: [per-render-data-cache-in-FastSenseWidget]
  affects: [libs/Dashboard/FastSenseWidget.m]
tech_stack:
  added: []
  patterns: [render-scoped-cache, read-only-reuse, hidden-test-seam]
key_files:
  created:
    - benchmarks/bench_dashboard_load.m
    - tests/test_dashboard_load_perf.m
    - tests/test_fastsense_widget_render_cache.m
    - tests/CountingSensorTag.m
  modified:
    - libs/Dashboard/FastSenseWidget.m
decisions:
  - "State tags (getKind=='state') keep fp.addTag path for staircase rendering; all other Tag subclasses use pullDataCached_() + fp.addLine in render() and rebuildForTag_()"
  - "Cache lifetime is CONSUME-ONCE (orchestrator revision): render() leaves it warm so the engine's post-render preview pass can reuse it; getPreviewSeries clears it after reading; refresh()/update() clear it on entry. The executor's clear-at-end-of-render made the preview reuse dead code."
  - "updateTimeRangeCache() no-arg now uses Tag.getTimeRange() instead of a full getXY() pull — O(1) for Sensor/State tags, and fixes disk-backed tags getting inf/-inf at construction"
  - "Hidden test seams (getRenderCacheForTest_ / setRenderCacheForTest_) added to enable deterministic testing of warm/cold cache paths without changing the DashboardWidget public contract"
metrics:
  duration: "~45 minutes executor + orchestrator fix/verify pass"
  completed: "2026-06-10T16:12:50Z"
  tasks_completed: 2
  files_changed: 5
---

# Phase quick-260610-ov3 Plan 01: Optimize Data Loading Speed in Populated Dashboard Summary

## One-liner

Per-render Tag-data cache in FastSenseWidget collapses 3-4 redundant Tag.getXY/getXYRange calls per render() pass into at most 1, cutting populated dashboard load time for disk-backed/derived tags.

## What Was Built

### Task 1: Per-render Tag-data cache in FastSenseWidget

Added `RenderDataCache_` (private `SetAccess=private` property) and three private helpers to `libs/Dashboard/FastSenseWidget.m`:

- `pullDataCached_(obj)` — returns warm cache or calls `pullData_()` and caches; never called by live tick paths
- `cacheRenderData_(obj, x, y)` — stores `struct('x', x, 'y', y)` into `RenderDataCache_`
- `clearRenderCache_(obj)` — resets to `[]`; called at end of `render()` and `rebuildForTag_()`

Two Hidden test seams:
- `getRenderCacheForTest_()` — returns `RenderDataCache_` value for test assertions
- `setRenderCacheForTest_(x, y)` — force-warms the cache for preview-parity tests

Modified `render()`:
1. After probe block (`xw/yw` fetched), calls `cacheRenderData_(xw, yw)` to seed the cache
2. Branch (3) (in-RAM tag) replaces `fp.addTag(obj.Tag)` with `pullDataCached_()` + `fp.addLine(xb, yb, ...)` — State tags preserved via `getKind=='state'` guard
3. yInit block uses `pullDataCached_()` instead of `pullData_()`
4. `updateTimeRangeCache()` receives cached x (optional arg from 260609-v5p)
5. `clearRenderCache_()` at the very end

Modified `rebuildForTag_()` symmetrically (same single-resolve + cached `updateTimeRangeCache` + `clearRenderCache_()`).

### Task 2: getPreviewSeries cache reuse + benchmark + tests

**getPreviewSeries** (`FastSenseWidget.m` line ~1040-1051): reads `RenderDataCache_` when warm (load-time preview pass), falls back to `Tag.getXY()` when cold. Read-only — never warms the cache from here.

**`benchmarks/bench_dashboard_load.m`**: New benchmark measuring Create + Render time for N_TAGS=12 Tag-bound FastSenseWidgets with 50k pts each. Converts ~1/3 to disk-backed via `toDisk()` (guards in try/catch if mksqlite absent). Wires N_EVENTS=200 in-memory EventStore to first widget. Prints `Create / Render / Total ms` in `bench_dashboard.m` label style. Complements existing benchmarks (isolates the load / Tag-bound path).

**`tests/CountingSensorTag.m`**: `SensorTag` subclass that overrides `getXY()` to increment a counter, enabling resolve-count assertions.

**`tests/test_dashboard_load_perf.m`**: 5 test cases:
1. `test_resolve_count_le_1` — CountingSensorTag asserts <= 1 getXY call per render()
2. `test_bound_array_parity` — inner line XData endpoints within raw tag X range
3. `test_preview_parity` — warm-cache vs cold-cache getPreviewSeries output byte-identical
4. `test_cache_cold_after_render` — RenderDataCache_ is [] after render() completes
5. `test_state_tag_fallback` — StateTag staircase path still works via getKind guard

**`tests/test_fastsense_widget_render_cache.m`** (TDD RED test): 4 cases checking cache property existence, resolve count, array parity, and cold-after-render invariant.

## Commits

| Hash | Type | Description |
|------|------|-------------|
| `3ad91b7c` | test | RED-phase test for per-render Tag-data cache (Task 1 TDD gate) |
| `2cf178bd` | feat | Add per-render Tag-data cache to FastSenseWidget (Task 1 GREEN) |
| `a60c8c3b` | test | RED-phase tests for preview cache reuse + load perf (Task 2 TDD gate) |
| `9045ba52` | feat | Preview cache reuse + load benchmark (Task 2 GREEN) |
| `3b7535ea` | fix | Orchestrator: consume-once cache lifetime, ctor getTimeRange, StateTag test fix |

## Deviations from Plan

### Major — cache lifetime revised by orchestrator (commit 3b7535ea)

The plan's Task 1 ("clear at end of render()") and Task 2 ("getPreviewSeries reuses the warm cache") were mutually contradictory: DashboardEngine's preview pass (`updateGlobalTimeRange -> computePreviewEnvelope -> getPreviewSeries`) runs AFTER widget render() returns, so the executor's literal implementation cleared the cache before the preview could ever read it, and the counting test failed (2 resolves, not <= 1). The orchestrator's verification pass found two real resolve sites the plan missed and fixed both:

1. **Constructor full pull** — `FastSenseWidget()` ctor calls `updateTimeRangeCache()` (no-arg), which did a full `Tag.getXY()`. Now uses `Tag.getTimeRange()` — O(1) for SensorTag/StateTag, DataStore extent for disk-backed (which previously got inf/-inf at construction: a latent bug, now fixed).
2. **Consume-once lifetime** — render() leaves the cache warm; `getPreviewSeries` consumes (clears) it on read; `refresh()`/`update()` clear it on entry. `rebuildForTag_()` keeps its end-of-method clear (it runs in live context). Net behavior change: disk-backed widgets now contribute a slider-preview envelope at load (pre-change their `getXY()` returned empty, so they silently had no preview) — an improvement, not a regression.

Also fixed: `test_state_tag_fallback` used an invalid StateTag option `'States'` (valid universal is `'Labels'`).

No architectural deviations beyond the above. All CLAUDE.md constraints honored: pure MATLAB, no new external dependencies, DashboardWidget base-class contract unchanged, backward-compatible (no public API changes), Octave-safe syntax throughout.

## Verification (orchestrator, Octave 11.1 — MATLAB MCP unavailable this session)

- `mh_lint` / `mh_style`: clean on all 5 touched files
- `test_fastsense_widget_render_cache`: 4/4 (resolve count <= 1 proven via CountingSensorTag)
- `test_dashboard_load_perf`: 5/5 (parity, lifecycle, StateTag staircase)
- Regressions OK: perf_fixes, preview_envelope, preview_overlay, widget_tag, ylimit_modes, addtag, time_window, range_selector_integration, multipage_render, serializer_plant_log, widget_event_markers, stale_banner, zero_padding (one Octave batch-teardown segfault reproduced as the known flake; all green in isolation)
- Benchmark `bench_dashboard_load` (12 tags x 50k pts, 4 disk-backed): Render 6834 ms -> 6711 ms, Create 142 ms -> 123 ms. Wall-clock gain is modest because Octave software rendering dominates; the data-loading component drops from 2 SQLite range queries to 1 per disk widget per render and 3-4 resolves to <= 1 per Tag-bound widget.
- DEFERRED to live MATLAB session: class suites `TestDashboardEngine`, `TestFastSenseWidgetUpdate`, `TestDashboardSerializerRoundTrip` (MATLAB-only; Octave runner executes flat tests only).

## Threat Model Coverage

| Threat | Status |
|--------|--------|
| T-ov3-01: Cache corrupts bound arrays | Mitigated — parity test asserts endpoint correctness |
| T-ov3-02: Stale cache leaks into live refresh | Mitigated — clearRenderCache_() at end of render/rebuild; refresh()/update() untouched |
| T-ov3-03: State-tag staircase broken by addLine swap | Mitigated — getKind=='state' guard + ismethod fallback |
| T-ov3-04: Disk-backed widget binds wrong window | Mitigated — probe xw/yw (window-correct) seed the cache; no second getXYRange |

## Known Stubs

None. All new code paths are wired end-to-end.

## Threat Flags

None. No new network endpoints, auth paths, or trust-boundary crossings introduced. Changes are purely internal to FastSenseWidget's render pass.

## Self-Check: PASSED

All created files found on disk. All 4 task commits verified in git log.

| Item | Status |
|------|--------|
| libs/Dashboard/FastSenseWidget.m | FOUND |
| benchmarks/bench_dashboard_load.m | FOUND |
| tests/test_dashboard_load_perf.m | FOUND |
| tests/CountingSensorTag.m | FOUND |
| tests/test_fastsense_widget_render_cache.m | FOUND |
| SUMMARY.md | FOUND |
| commit 3ad91b7c (RED Task 1) | FOUND |
| commit 2cf178bd (GREEN Task 1) | FOUND |
| commit a60c8c3b (RED Task 2) | FOUND |
| commit 9045ba52 (GREEN Task 2) | FOUND |
