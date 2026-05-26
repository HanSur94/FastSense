---
phase: 260508-kau-slider-preview-aggregates-all-pages-widg
plan: 01
subsystem: ui
tags: [matlab, dashboard, time-slider, multi-page, regression-test]

# Dependency graph
requires:
  - phase: 260508-das-implement-backlog-999-3-dashboard-time-s
    provides: dashboard time-slider preview lines + event markers infrastructure (computePreviewEnvelope, computeEventMarkers)
  - phase: 260508-edd-color-slider-preview-event-markers-per-e
    provides: per-severity coloring for slider preview event markers
provides:
  - Slider preview lines aggregate widgets from ALL pages (KAU-01)
  - Slider event markers aggregate events from ALL pages (KAU-01)
  - Page switching no longer drops or re-scopes preview content
affects: [DashboardEngine, multi-page dashboards, industrial_plant demo]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two engine call-sites converted from activePageWidgets() to allPageWidgets() so the slider stays page-agnostic; single-page dashboards unaffected because allPageWidgets() returns obj.Widgets when Pages is empty"

key-files:
  created: []
  modified:
    - libs/Dashboard/DashboardEngine.m
    - tests/test_dashboard_engine_event_markers.m
    - tests/suite/TestDashboardEngineEventMarkers.m
    - tests/test_dashboard_preview_overlay.m

key-decisions:
  - "Reuse existing allPageWidgets() helper rather than refactoring or introducing a new previewWidgets() abstraction — minimal blast radius, matches the 260508-das contract surface."
  - "Keep the recompute call at switchPage even though output is now page-agnostic: keeps the contract uniform across all 4 hook sites and is harmless because both pages produce the same envelope."
  - "Do not modify bucketing/normalization/dedup math; the all-pages aggregation operates on whatever widget set is passed in, so existing single-page tests stay valid."

patterns-established:
  - "TDD RED-then-GREEN verified on the new regression case: temporarily reverted the engine fix locally, confirmed the new case fails on the inactive-page assertion (`expected >=1 preview line in [200,210]`), then restored the fix and confirmed all 9 cases pass."

requirements-completed:
  - KAU-01

# Metrics
duration: ~25 min
completed: 2026-05-08
---

# Quick Task 260508-kau: Slider preview aggregates all pages Summary

**Multi-page dashboard time-slider preview lines + event markers now aggregate every page's widgets, fixing the cross-tab visibility regression on the 6-page industrial-plant demo.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-05-08T12:21:40Z
- **Completed:** 2026-05-08T12:47:09Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- `DashboardEngine.computePreviewEnvelopeReturning_` now iterates `allPageWidgets()` so the faint slider preview lines fold in widgets from every page (KAU-01).
- `DashboardEngine.computeEventMarkers` now iterates `allPageWidgets()` so the slider's event markers reflect every page's events (KAU-01).
- DOC headers for both methods updated to describe the all-pages contract; comments cite KAU-01 inline at the iteration sites for future readers.
- Two existing switchPage tests (function-based + class-based suite) updated from active-page-only assertions to the sorted-union-of-all-pages contract.
- New regression case `case_multipage_preview_aggregates_all_pages` in `test_dashboard_preview_overlay.m` builds a 2-page dashboard with disjoint X ranges (`[0,10]` vs `[200,210]`) and asserts BOTH pages' widgets contribute preview lines, both at initial render and after `switchPage(2)`.

## Task Commits

1. **Task 1: Switch preview iteration to all-pages and update existing switchPage tests** — `a098be2` (fix)
2. **Task 2: Add multi-page preview-aggregation regression test (TDD)** — `70c3c4c` (test)

## Files Created/Modified

- `libs/Dashboard/DashboardEngine.m` — two `activePageWidgets()` -> `allPageWidgets()` switches at L1922 and L2033, plus DOC-header rewrites at L1880-1889 (`computePreviewEnvelope`) and L1986-1991 (`computeEventMarkers`). No bucketing/normalization/dedup math touched.
- `tests/test_dashboard_engine_event_markers.m` — `case_switch_page` now asserts the sorted union `[5 15 100 200 300]` for initial render plus both `switchPage(2)` and `switchPage(1)`.
- `tests/suite/TestDashboardEngineEventMarkers.m` — `testEventMarkersUpdateOnSwitchPage` mirrors the same union-of-all-pages assertions.
- `tests/test_dashboard_preview_overlay.m` — new `case_multipage_preview_aggregates_all_pages` registered in the runCase dispatch list (count grew 8 -> 9); classifies each preview line by X-range and asserts >=1 line in P1's range AND >=1 in P2's range, both before and after `switchPage(2)`.

## Decisions Made

- Reused the existing `allPageWidgets()` helper (L1717-1728) verbatim rather than introducing a new `previewWidgets()` API. Single-page parity is automatic because the helper returns `obj.Widgets` when `Pages` is empty.
- Did NOT remove the `switchPage` recompute call. The fix makes that recompute output page-agnostic, but keeping the call preserves uniform contract across all four hook sites (render, switchPage, updateGlobalTimeRange, onLiveTick) at zero cost.
- Did NOT change any other `activePageWidgets()` call site. Layout, panel allocation, refresh, and reflow correctly continue to operate on the active page only — the all-pages contract is specific to the slider preview.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Both tasks landed cleanly; the new regression case was verified RED before commit by temporarily reverting the engine fix to HEAD~1, observing the assertion failure (`KAU-01: expected >=1 preview line in [200,210] (P2 widget, inactive page), got 0`), then restoring the fix and observing all 9 cases pass.

## Test Results

| Test | Before | After | Status |
| ---- | ------ | ----- | ------ |
| `test_dashboard_preview_envelope` | 2/2 | 2/2 | All passed |
| `test_dashboard_preview_overlay` | 8/8 | **9/9** (+1 new case) | All passed |
| `test_dashboard_engine_event_markers` | 8/8 | 8/8 (1 case rewritten) | All passed |
| `TestDashboardEngineEventMarkers` (class suite) | 8/8 | 8/8 (1 method rewritten) | All passed |

Verification command:
```bash
matlab -batch "addpath(pwd); install(); test_dashboard_preview_envelope; test_dashboard_preview_overlay; test_dashboard_engine_event_markers; addpath('tests/suite'); r = runtests('TestDashboardEngineEventMarkers'); fails = sum([r.Failed]);"
```

## Self-Check: PASSED

- DashboardEngine.m line 1922 reads `ws = obj.allPageWidgets();` (was `activePageWidgets`).
- DashboardEngine.m line 2033 reads `ws = obj.allPageWidgets();` (was `activePageWidgets`).
- DOC headers for `computePreviewEnvelope` and `computeEventMarkers` reference "ALL widgets on EVERY page" with KAU-01 attribution.
- Commits exist: `a098be2` (Task 1, fix), `70c3c4c` (Task 2, test).
- Multi-page regression case proven to fail without the fix (RED) and pass with the fix (GREEN).

## Next Phase Readiness

- Multi-page dashboards (e.g. `demo/industrial_plant/run_demo.m`) now display the full cross-page envelope and marker set in the bottom slider regardless of which tab is active.
- No follow-up work needed for KAU-01.

---
*Phase: 260508-kau-slider-preview-aggregates-all-pages-widg*
*Completed: 2026-05-08*
