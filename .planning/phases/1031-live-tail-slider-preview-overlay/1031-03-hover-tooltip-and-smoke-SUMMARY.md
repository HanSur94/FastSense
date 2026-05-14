---
phase: 1031-live-tail-slider-preview-overlay
plan: 03
subsystem: dashboard-overlay
tags: [matlab, plant-log, slider, hover, tooltip, chained-wbm, integration-smoke, end-to-end]

# Dependency graph
requires:
  - phase: 1029-plant-log-storage-foundation
    provides: PlantLogStore.getEntriesInRange (range-clipped lookup feeding hover tooltip closure)
  - phase: 1030-csv-xlsx-import-mapping-dialog
    provides: PlantLogReader.openInteractive (consumed by PlantLogLiveTail in the integration smoke)
  - phase: 1031-live-tail-slider-preview-overlay (Plan 01)
    provides: PlantLogLiveTail handle class + PlantLogTailTick event (lifecycle exercised by integration smoke)
  - phase: 1031-live-tail-slider-preview-overlay (Plan 02)
    provides: TimeRangeSelector.setPlantLogMarkers + DashboardEngine.computePlantLogMarkers + setPlantLogStoreForTest_/setPlantLogLiveTailForTest_/setTimeRangeSelectorForTest_ test seams (all extended/consumed by Plan 03)
provides:
  - PlantLogSliderHover handle class — chained-WindowButtonMotionFcn hover tooltip with 50ms debounce, ~3px proximity check, transient uipanel + uicontrol(text) tooltip, auto-hide after 2s of inactivity
  - DashboardEngine.PlantLogSliderHover_ private property + lazy-construct in setPlantLogStoreForTest_ + ALWAYS-teardown-on-store-change pattern
  - DashboardEngine.lookupPlantLogEntries_ — indirect store lookup helper (re-reads PlantLogStoreInternal_ at call time so swaps reflect immediately without rebuilding the closure)
  - DashboardEngine.teardownPlantLogSliderHover_ — idempotent hover destructor helper
  - DashboardEngine.delete() ordering: hover teardown moved BEFORE TimeRangeSelector_ teardown so hover restores selector's chained WBMFcn while selector is still alive
  - tests/test_plant_log_slider_hover.m + tests/suite/TestPlantLogSliderHover.m — 10 + 12 tests for the hover surface
  - tests/test_phase_1031_integration_smoke.m + tests/suite/TestPhase1031IntegrationSmoke.m — 6 + 7 end-to-end Phase 1031 closure tests (incl. real-timer round-trip)
affects:
  - 1032-per-widget-overlay (will reuse the PlantLogSliderHover pattern with metadata-rich tooltip variant for per-FastSenseWidget hover)
  - 1033-dashboard-companion-integration (will replace the _ForTest_ seams with attachPlantLog/detachPlantLog public API; PlantLogSliderHover_ teardown ordering already correct for that swap)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Chained-WindowButtonMotionFcn hover (mirrors libs/FastSense/HoverCrosshair.m): save prior on construct, install own as @(s,e) chain-call -> own logic, restore prior unconditionally on delete (since '' is a legal callback value)"
    - "Indirect store lookup via engine helper: hover closure goes through obj.lookupPlantLogEntries_(t0, t1) instead of capturing storeRef by-value, so subsequent store swaps are reflected immediately without rebuilding the closure"
    - "Always teardown-on-change for hover: every store change triggers teardown + (re-)build, ensuring stale closures cannot survive a store swap (defensive even though the indirect lookup above also handles this)"
    - "Auto-hide via cheap 0.5s sweep timer: hover never holds the figure busy; the timer just checks toc(LastShowAt_) > 2.0 and hides if true"
    - "Hidden test seam (methods (Hidden)) simulateHoverAt_(dataX) bypasses the WBMFcn pixel hit-test for deterministic per-coordinate assertions without driving real mouse motion"
    - "Teardown ordering in delete(engine): hover destructor MUST run BEFORE TimeRangeSelector destructor so the WBMFcn restore points at a still-alive TRS handler (not a deleted-handle closure)"

key-files:
  created:
    - libs/PlantLog/PlantLogSliderHover.m
    - tests/test_plant_log_slider_hover.m
    - tests/suite/TestPlantLogSliderHover.m
    - tests/test_phase_1031_integration_smoke.m
    - tests/suite/TestPhase1031IntegrationSmoke.m
  modified:
    - libs/Dashboard/DashboardEngine.m

key-decisions:
  - "DEVIATION D-PRIVATE-LOCATION: PlantLogSliderHover.m placed at libs/PlantLog/PlantLogSliderHover.m (NOT libs/PlantLog/private/) because MATLAB's private-folder semantics make the class invisible to the DashboardEngine consumer (different parent folder). install.m already adds libs/PlantLog/ to the path, so the public location is the cleanest fit. CONTEXT.md's 'private/' phrasing reflected the original design intent before the consumer location was finalized."
  - "DEVIATION (Rule 3 - blocking): teardownPlantLogSliderHover_ call moved from end-of-delete() to BEFORE the TimeRangeSelector_ teardown. Discovered during smoke-test verification: with the original order, TRS destruction would run first, leaving the figure with hover's restored callback handle pointing at a deleted TRS. Reordering ensures hover restores TRS's chained WBMFcn while TRS is still alive. The trailing teardown call is also kept (idempotent) so the plan's literal 'append at end of delete()' instruction is preserved as a no-op safety net."
  - "Hover closure goes through obj.lookupPlantLogEntries_(t0, t1) (NEW private helper) instead of capturing the store reference by-value. Re-reads PlantLogStoreInternal_ at call time so future store swaps are reflected without rebuilding the closure. Even though the engine ALWAYS rebuilds on store change (Rule 1 in CONTEXT.md), the indirect path means external code that bypasses setPlantLogStoreForTest_ still gets correct lookups."
  - "Auto-hide implemented as a cheap 0.5s fixedSpacing timer + a LastShowAt_ tic timestamp -- the timer fires every 0.5s, checks elapsed > 2s, and hides if so. Simpler than scheduling a singleShot timer per show (which would require cancellation logic and is fragile under rapid-fire motion events). Timer creation is wrapped in try/catch so uifigure contexts that reject timer creation degrade gracefully (tooltip stays visible until next motion or onLeave)."
  - "Tooltip flatten helper added in tests (flatten_tooltip_string_ / flattenString_): uicontrol(text)'s String for multi-line input may come back as a char matrix (rows = lines). Substring assertions in test_tooltip_text_format and testTooltipTextFormat join rows with spaces so the assertion works regardless of how MATLAB internally stores the multi-line input."
  - "Proximity test fixture hovers EXACTLY at marker timestamps (50, 75) + asserts midway-points (37.5) are empty. The 3-px tolerance in axes data units depends on axes pixel width (~600 px on offscreen figures = ~0.5 data units for XLim [0 100]); hovering 'near' a marker at e.g. 52 is OUTSIDE tolerance. Exact-coord hovering is more deterministic than near-miss approximation."
  - "Test counter literal in function-style suites (assert(nPassed == N) followed by literal 'All N ...' fprintf): matches Plan 01 + Plan 02 pattern -- assert preserves dynamic count, literal makes the static-grep acceptance check return exactly 1."

patterns-established:
  - "Chained-WBM hover lifecycle (PLOG-VIZ-06): the 4-component pattern from HoverCrosshair (save prior, install chained, throttle + re-entrancy guard + pixel hit-test, restore on delete) plus tooltip ownership (uipanel + uicontrol(text) parented to figure with auto-hide timer). Phase 1032 will copy this pattern with a metadata-rich tooltip variant for per-FastSenseWidget hover."
  - "Indirect lookup through engine helper: hover closures go through obj.lookupPlantLogEntries_ rather than capturing the store reference by-value. Lets engine swap stores without rebuilding hover closures."
  - "Always teardown-then-build on integration-point change: every store change (attach + detach + re-attach with different store) ALWAYS tears down + rebuilds the hover. Defensive against stale closures even though the indirect lookup above also covers store swaps."
  - "Teardown ordering: when an integration-point owns a child (hover) that captured a sibling's state (TRS callback), the child must be torn down BEFORE the sibling. delete(engine) order is now: PlantLogTickListener_ -> hover -> TRS -> widgets -> info modal -> trailing hover idempotency call."
  - "Hidden test seam pattern at the per-class level: simulateHoverAt_(dataX) on PlantLogSliderHover bypasses the WBMFcn pixel hit-test for deterministic tests. Mirrors PlantLogLiveTail.tick_() seam from Plan 01."

requirements-completed: [PLOG-VIZ-06]

# Metrics
duration: 27min
completed: 2026-05-14
---

# Phase 1031 Plan 03: Hover Tooltip + Integration Smoke Summary

**PlantLogSliderHover handle class (chained-WBM, 50ms debounce, transient uipanel tooltip with 2s auto-hide) + DashboardEngine integration (lazy construct in setPlantLogStoreForTest_, indirect store lookup via lookupPlantLogEntries_, always-teardown-on-change pattern, hover-before-selector destructor ordering) + 4 test files (10/12 hover unit tests + 6/7 end-to-end Phase 1031 closure tests, including a real-timer round-trip) — Phase 1031 closed with all 10 PLOG-* requirements proven through at least one passing runtime test path.**

## Performance

- **Duration:** 26 min 45 s
- **Started:** 2026-05-14T12:37:14Z
- **Completed:** 2026-05-14T13:03:59Z
- **Tasks:** 4
- **Files created:** 5 (1 production class + 4 test files)
- **Files modified:** 1 (libs/Dashboard/DashboardEngine.m, +85 lines, 0 deletions in Plan 03 cumulatively)

## Accomplishments

- Shipped PlantLogSliderHover (456 LOC) — chained-WindowButtonMotionFcn hover with 50ms debounce, transient uipanel + uicontrol(text) tooltip, ~3px proximity check, 2s auto-hide via 0.5s sweep timer, simulateHoverAt_ + getCurrentTooltipString_/Visible_ test seams
- Wired PlantLogSliderHover into DashboardEngine: PlantLogSliderHover_ private property + lazy-construct in setPlantLogStoreForTest_ + lookupPlantLogEntries_ indirect helper + teardownPlantLogSliderHover_ + delete() ordering fix (hover-before-selector teardown)
- 10 function-style hover sub-tests pass on MATLAB (clean Octave skip)
- 12 class-based hover suite tests pass on MATLAB
- 6 function-style Phase 1031 integration smoke sub-tests pass on MATLAB; tests 1 + 2 (path pickup + headless lifecycle) pass cross-runtime
- 7 class-based Phase 1031 integration suite tests pass on MATLAB, including testRealTimerTickRoundTrip (Interval=0.2s + StartImmediately=true + pause(0.6) — proves the real timer round-trip end-to-end)
- Phase 1029 (TestPlantLogStore + TestPlantLogEntry + TestPlantLogHash + TestPlantLogIntegrationSmoke) regression: 100% green
- Phase 1030 (TestPlantLogReader + TestPlantLogImportSmoke + TestPlantLogImportDialog) regression: 100% green
- Phase 1031 Plan 01 (TestPlantLogLiveTail) regression: 11/11 pass
- Phase 1031 Plan 02 (TestPlantLogSliderOverlay) regression: 10/10 pass
- Broader engine + event-marker regression: TestDashboardEngine 18/18, TestTimeRangeSelectorEventMarkers + TestDashboardEngineEventMarkers + TestFastSenseWidgetEventMarkers 32/32
- Zero NEW Code Analyzer Error- or Critical-level diagnostics on every modified/new file (only pre-existing warnings + 2 info-level NASGU on PlantLogSliderHover variable initialization + 1 info-level DATST/DATNM in tests for datestr/datenum usage matching project convention)

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement PlantLogSliderHover** — `007d94f` (feat)
2. **Task 2: Wire PlantLogSliderHover into DashboardEngine** — `443ad79` (feat)
3. **Task 3: Function-style + class-based tests for PlantLogSliderHover** — `75338a8` (test)
4. **Task 4: Phase 1031 end-to-end integration smoke (function + suite)** — `4c5abee` (test)

## Files Created/Modified

- `libs/PlantLog/PlantLogSliderHover.m` — 456-line handle class. Constructor (parentFig, sliderAxes, lookupFn) saves prior WBMFcn and installs chained handler. onFigureMove_ does throttle + re-entrancy guard + pixel hit-test + delegates to simulateHoverAt_. simulateHoverAt_(dataX) is the test seam: it does the lookup, picks the nearest entry, and shows the tooltip. createTooltipGraphics_ pre-creates a uipanel + uicontrol(text) with Visible='off'. positionTooltipNearCursor_ places the tooltip with 12px offset + edge-flip. checkAutoHide_ runs every 0.5s and hides the tooltip after 2s of inactivity. delete() restores prior WBMFcn UNCONDITIONALLY (mirrors HoverCrosshair line 207) and tears down all graphics + listeners + the auto-hide timer. Errors namespaced PlantLogSliderHover:invalidInput.

- `libs/Dashboard/DashboardEngine.m` — +85 lines, 0 deletions in Plan 03. Five additive blocks:
  - (a) PlantLogSliderHover_ private property in the same Phase 1031 properties block (line ~99)
  - (b) setPlantLogStoreForTest_ extension: ALWAYS teardown then rebuild on store change; closure goes through @(t0,t1) obj.lookupPlantLogEntries_(t0,t1) (line ~2226)
  - (c) NEW private helper lookupPlantLogEntries_(t0, t1) — re-reads PlantLogStoreInternal_ at call time, returns [] when absent or on throw (line ~3000)
  - (d) NEW private helper teardownPlantLogSliderHover_() — idempotent, delete()s hover and nils property (line ~3020)
  - (e) delete() ordering: hover teardown moved BEFORE TimeRangeSelector_ teardown (line ~2138 area, NEW comment block) plus a trailing teardownPlantLogSliderHover_() call at the end of the destructor (line ~2191) for idempotency safety.

- `tests/test_plant_log_slider_hover.m` — NEW 281-line function-style file. 10 sub-tests: 3 input-validation branches, 1 prior-WBM save check, 1 nearest-entry pick, 1 no-entry-in-range, 1 tooltip-visible-after-show, 1 tooltip-text-format, 1 delete-restores-WBM, 1 engine-lazy-construction, 1 engine-teardown-on-store-detach, 1 engine-teardown-on-delete (verifies WBMFcn does NOT contain hover's onFigureMove_ closure after engine.delete). Clean SKIP on Octave at the very top. Named try_delete_h / try_delete_obj cleanup helpers (no inline try in anonymous fns). Final print: `All 10 plant_log_slider_hover assertions passed.` after `assert(nPassed == 10)`. Tooltip flatten helper for char-matrix String values.

- `tests/suite/TestPlantLogSliderHover.m` — NEW 240-line class-based MATLAB suite. 12 Test methods: 3 split bad-arg constructor tests, plus mirrors of all 7 substantive function-style tests, plus 2 engine-integration tests. TestMethodTeardown walks Hovers / Engines / Handles cells with named try-loops. Path setup via install() only. Tooltip flattenString_ helper as a file-scope local function.

- `tests/test_phase_1031_integration_smoke.m` — NEW 246-line function-style end-to-end smoke. 6 sub-tests:
  - test_path_pickup (cross-runtime; install-only contract for all 6 plant-log/dashboard classes)
  - test_full_lifecycle (cross-runtime; CSV write -> store + reader + tail -> tick_() -> append -> tick_(); 3 -> 5 entries; PLOG-LT-01/02)
  - test_engine_slider_integration (MATLAB; selector.hPlantLogMarkers populated; engine.PlantLogSliderHover_ non-empty; PLOG-VIZ-01/02/06)
  - test_live_tail_refreshes_slider (MATLAB; tail.tick_() -> listener -> computePlantLogMarkers -> selector markers populated WITHOUT engine.render(); PLOG-VIZ-08)
  - test_hover_finds_entry (MATLAB; engine.PlantLogSliderHover_.simulateHoverAt_(ts2) returns the right entry; PLOG-VIZ-06)
  - test_full_pipeline_cleanup (MATLAB; delete(engine) + delete(tail) -> timerfindall <= baseline; WBMFcn does NOT reference hover's closure; PLOG-LT-04)
  Clean SKIP on Octave for tests 3-6 (uifigure-heavy).

- `tests/suite/TestPhase1031IntegrationSmoke.m` — NEW 287-line class-based mirror with 7 Test methods: mirrors all 6 function-style sub-tests + adds testRealTimerTickRoundTrip which constructs PlantLogLiveTail with Interval=0.2 + StartImmediately=true + pause(0.6) so the REAL timer fires + the listener round-trip is exercised end-to-end (proves the timer + addlistener + computePlantLogMarkers chain works in real wall-clock time, not just synchronous tick_() invocations).

## Decisions Made

- **DEVIATION D-PRIVATE-LOCATION (planned in Plan 03):** PlantLogSliderHover.m placed at `libs/PlantLog/PlantLogSliderHover.m` (NOT `libs/PlantLog/private/`). MATLAB's private-folder semantics make a class in `libs/PlantLog/private/` invisible to functions/classes in OTHER folders (only `libs/PlantLog/*.m` files can see `libs/PlantLog/private/*.m`). Since DashboardEngine.m lives at `libs/Dashboard/DashboardEngine.m`, it cannot see a `libs/PlantLog/private/PlantLogSliderHover.m`. The clean fix is to place the class alongside other libs/PlantLog/ classes (PlantLogStore, PlantLogReader, PlantLogLiveTail, PlantLogEntry, PlantLogTailEventData) where install.m's `addpath(fullfile(root, 'libs', 'PlantLog'))` already puts it on the path. CONTEXT.md's `private/` phrasing reflected the original design intent before the consumer location was finalized.

- **DEVIATION D-DELETE-ORDERING (Rule 3 - auto-fix blocking issue):** During Task 2 verification I discovered that calling `teardownPlantLogSliderHover_()` only at the END of `delete(engine)` (the plan's literal instruction) created a real bug: `delete(obj.TimeRangeSelector_)` runs FIRST (line 2139), TRS's destructor restores the figure's WindowButtonMotionFcn to whatever was before TRS installed its own (typically `''`), then my hover teardown tries to restore TRS's chained handler — but TRS is gone, so the restored callback handle points at a deleted TRS. The fix is to move the teardown call to BEFORE the TRS teardown so hover restores TRS's chained WBMFcn while TRS is still alive (the figure ends up with TRS's handler, then TRS destruction runs cleanly). The trailing teardown call at the end is kept as an idempotent no-op safety net (matches the plan's literal request and protects against future destructor-body extensions). Documented in commit message and as Decision Made above.

- **lookupPlantLogEntries_ helper (NEW private method, planned in Plan 03):** The hover's lookup closure goes through `@(t0, t1) obj.lookupPlantLogEntries_(t0, t1)` rather than `@(t0, t1) storeRef.getEntriesInRange(t0, t1)`. The indirect path means: (a) when the engine swaps stores via setPlantLogStoreForTest_(other), the hover closure picks up the new store at the next call (no rebuild needed); (b) if a store is detached without going through setPlantLogStoreForTest_, the lookup still returns [] cleanly instead of throwing on a deleted-handle reference. Even though the engine ALWAYS rebuilds the hover on store change (defensive), the indirect path is the belt-and-suspenders.

- **Always teardown-on-change for hover (planned in Plan 03):** Every call to setPlantLogStoreForTest_(store) — including setPlantLogStoreForTest_([]) and setPlantLogStoreForTest_(differentStore) — tears down any prior hover BEFORE checking whether to build a new one. This ensures the lifecycle is uniform and stale closures (capturing an old store handle in a more pessimistic implementation) cannot survive a swap. Combined with the indirect lookup helper above, this is doubly defensive.

- **Auto-hide via 0.5s sweep timer + LastShowAt_ tic (planned in Plan 03):** The simpler alternative — schedule a singleShot timer on every showTooltip_ — requires per-show cancellation logic that gets fragile under rapid-fire motion. The 0.5s sweep is cheap (one comparison + maybe a Visible='off' set) and self-cancels because the LastShowAt_ tic gets refreshed on every successful pick. Timer creation is wrapped in try/catch so contexts that reject timer creation degrade gracefully (tooltip stays visible until next motion or onLeave).

- **Tooltip flatten helper in tests (flatten_tooltip_string_ / flattenString_):** uicontrol(text)'s String for multi-line input may come back as a char matrix (rows = lines). MATLAB's `set('String', sprintf('a\nb'))` followed by `get('String')` returns a 2x3 char matrix on R2024b. `strfind` requires a row vector or a cell of row vectors, so multi-row char matrices throw "First argument must be text." Both test files include a flatten helper that joins rows with spaces so substring assertions work uniformly.

- **Proximity test fixture: hover EXACTLY at marker timestamps + assert midway-points are empty:** The 3-px tolerance in axes data units depends on the axes' pixel width. For an offscreen ~600 px axes with XLim [0 100], pxToData = 100/600 ≈ 0.166, so tol = ~0.5 data units. Hovering "near" a marker at e.g. 52 (when the marker is at 50) is OUTSIDE the 0.5 tolerance — the test would fail. Hovering exactly at 50 (and 75) is more deterministic + the midway-empty assertion at 37.5 proves the tolerance does NOT bridge the gap. This is the Plan 03 lesson: data-units tolerance scales with pixel width, so test fixtures must hover precisely (not approximately).

- **Test counter literal pattern (D-COUNTER, matches Plan 01 + 02):** Function-style files end with `assert(nPassed == N, ...); fprintf('All N <name> assertions passed.\n');` — the assert preserves the dynamic count check while the literal `'All N ...'` makes a static grep return exactly 1. On MATLAB the count is exact; on Octave the SKIP-and-still-increment pattern (`fprintf SKIP ...; n = 1; return;`) preserves the count.

## Deviations from Plan

Two structural deviations + several quality-of-life refinements. Substantive code matched the plan; the deviations document the two real adjustments needed for correctness.

### Auto-fixed Issues

**1. [Rule 3 - Blocking] teardownPlantLogSliderHover_ called BEFORE TimeRangeSelector_ teardown in delete(engine)**
- **Found during:** Task 2 (DashboardEngine wiring) — smoke verification phase
- **Issue:** The plan's literal instruction was "append teardownPlantLogSliderHover_() at the END of delete()". With that ordering, `delete(obj.TimeRangeSelector_)` runs FIRST (existing line 2139). TRS's destructor restores the figure's WindowButtonMotionFcn to whatever was before TRS installed its own handler (typically `''` for a fresh figure). Then the trailing teardownPlantLogSliderHover_() runs and the hover's destructor calls `set(parentFig, 'WindowButtonMotionFcn', obj.PrevWBMFcn_)` — but PrevWBMFcn_ holds TRS's chained handler, and TRS is now gone. The figure ends up with a callback handle pointing at a deleted TimeRangeSelector, which would crash on the next mouse motion.
- **Fix:** Moved teardownPlantLogSliderHover_() to BEFORE the TimeRangeSelector_ teardown (line ~2138 area). With this ordering: hover destructor restores TRS's chained handler while TRS is still alive (TRS handler is reinstated on the figure), then TRS destruction runs cleanly (TRS's own destructor restores its pre-WBM, leaving the figure in the correct end state). Kept the trailing teardownPlantLogSliderHover_() call (idempotent) so the plan's literal instruction is preserved as a no-op safety net for future destructor-body extensions.
- **Files modified:** libs/Dashboard/DashboardEngine.m (added new teardown call before TRS teardown, in addition to the trailing call)
- **Verification:** Task 2 smoke now passes with `isequal(priorWBM, afterWBM)` after attach->detach round-trip and `func2str(WBM)` after delete(e) showing the restored TRS handler (not a deleted-handle closure).
- **Committed in:** 443ad79 (Task 2 commit)

**2. [Documented Plan-time deviation] PlantLogSliderHover.m placed at libs/PlantLog/ NOT private/**
- **Found during:** Task 1 (was anticipated in Plan 03 as DECISION D-PRIVATE-LOCATION)
- **Issue:** CONTEXT.md (line 81) initially specified "Thin `private/PlantLogSliderHover.m` helper class". MATLAB's private-folder semantics make a class in `libs/PlantLog/private/` visible only to functions/classes in `libs/PlantLog/`. DashboardEngine.m lives at `libs/Dashboard/DashboardEngine.m`, so it cannot see a `libs/PlantLog/private/PlantLogSliderHover.m`. Two options: (1) place at `libs/PlantLog/` directly; (2) add a factory function. Plan 03's `<action>` block explicitly chose Option 1.
- **Fix:** Created at `libs/PlantLog/PlantLogSliderHover.m` (where install.m's `addpath(fullfile(root, 'libs', 'PlantLog'))` already adds it to path). No factory needed; matches the existing libs/PlantLog/* convention.
- **Files modified:** N/A (file created at intended location, just not the literal `private/` path in CONTEXT.md)
- **Verification:** `which('PlantLogSliderHover')` resolves correctly from any folder after install(); hover constructs cleanly from DashboardEngine.setPlantLogStoreForTest_.
- **Committed in:** 007d94f (Task 1 commit) — documented in commit message DEVIATION block

### Quality-of-life refinements (not deviations)

1. **Tooltip flatten helper added in both test files (flatten_tooltip_string_ / flattenString_):** uicontrol(text)'s String for multi-line input via `sprintf('%s\n%s', ts, msg)` may come back as a char matrix (rows = lines). The first run of test_tooltip_text_format threw "First argument must be text." on `strfind(str, expectedTs)` because str was a 2x21 char matrix. The flatten helper joins rows with spaces so substring assertions work regardless of how MATLAB stores multi-line input.

2. **Proximity test hovers EXACTLY at marker timestamps + asserts midway-empty:** The first run of test_simulate_hover_finds_nearest tried to hover "near 50" at coordinate 52 — outside the ~0.5 data-unit tolerance on a 600 px axes. Updated to hover at exactly 50 + 75 + assert 37.5 returns empty. Same fixture in the class-based suite. Documented as the Plan 03 proximity lesson.

3. **NASGU lints on PlantLogSliderHover variable initialization:** Two `entries = []` assignments before `try` blocks (lines 210, 378 in some draft) trigger NASGU info-level warnings. The pattern is intentional (initialize-before-try so the variable exists in the catch path); matches the engine's style. Info-level only, no functional impact.

These are quality-of-life refinements; no Rule 1-3 auto-fix triggers (no bugs, no missing critical functionality, no blocking issues).

## Issues Encountered

- **WBMFcn round-trip on engine.delete() initially failed** — investigated, diagnosed as TRS-before-hover ordering, fixed via Rule 3 deviation above. Detailed in commit 443ad79's message.
- **Multi-line tooltip String returns char matrix on R2024b** — investigated, added flatten helper. Detailed in commit 75338a8's message.
- **Proximity tolerance scales with pixel width** — investigated, updated test fixture to exact-coord hovering. Detailed in commit 75338a8's message.

No timer flakes, no test order dependencies, no regression triggers across the 132 prior plant-log + slider/event-marker + broader engine tests.

## Verification Summary

| Check | Result |
| --- | --- |
| `libs/PlantLog/PlantLogSliderHover.m` exists + parses clean | OK (2 info-level NASGU + 1 info-level DATST, no errors) |
| `libs/Dashboard/DashboardEngine.m` adds PlantLogSliderHover_ + lookupPlantLogEntries_ + teardownPlantLogSliderHover_ + 2 delete-ordering calls | OK (grep counts: PlantLogSliderHover_=11, teardownPlantLogSliderHover_=1 def, lookupPlantLogEntries_=1 def, PlantLogSliderHover( ctor=1, PLOG-VIZ-06=6) |
| `libs/Dashboard/DashboardEngine.m` PURE additive (85 insertions, 0 deletions in Plan 03) | OK |
| Plan 02 regression: TestPlantLogSliderOverlay (10/10 pass) | OK |
| Plan 02 function-style: test_plant_log_slider_overlay (9/9 pass) | OK |
| Plan 01 regression: TestPlantLogLiveTail (11/11 pass) | OK |
| Phase 1029 regression: TestPlantLogStore + TestPlantLogEntry + TestPlantLogHash + TestPlantLogIntegrationSmoke (100% green) | OK |
| Phase 1030 regression: TestPlantLogReader + TestPlantLogImportSmoke + TestPlantLogImportDialog (100% green) | OK |
| Engine surface regression: TestDashboardEngine (18/18 pass) | OK |
| Event marker regression: TestTimeRangeSelectorEventMarkers + TestDashboardEngineEventMarkers + TestFastSenseWidgetEventMarkers (32/32 pass) | OK |
| `tests/test_plant_log_slider_hover.m` runs and prints "All 10 plant_log_slider_hover assertions passed." | OK |
| `tests/suite/TestPlantLogSliderHover.m` runs with 0 failures (12/12 pass) | OK |
| `tests/test_phase_1031_integration_smoke.m` runs and prints "All 6 phase_1031_integration_smoke assertions passed." | OK |
| `tests/suite/TestPhase1031IntegrationSmoke.m` runs with 0 failures (7/7 pass, including testRealTimerTickRoundTrip) | OK |
| WBMFcn round-trip is provably clean: priorWBM = afterWBM after attach->detach | OK (verified in test_constructor_saves_prior_wbm, test_delete_restores_wbm, testDeleteRestoresWBM) |
| WBMFcn does NOT contain hover closure after engine.delete() | OK (verified in test_engine_teardown_on_delete, testEngineTeardownOnDelete, test_full_pipeline_cleanup) |
| timerfindall back to baseline after delete(engine) + delete(tail) | OK (verified in test_full_pipeline_cleanup, testFullPipelineCleanup) |
| Real timer end-to-end: tail.start() with Interval=0.2 -> pause(0.6) -> store + slider populated | OK (verified in testRealTimerTickRoundTrip) |
| `checkcode` reports no NEW Error-level diagnostics on every modified/new file | OK |
| Octave clean SKIP on uifigure-heavy tests | OK (4 SKIP messages in test_phase_1031_integration_smoke; 1 in test_plant_log_slider_hover) |

## Phase 1031 Closure: PLOG-* Coverage Cross-Reference

All 10 Phase 1031 requirement IDs are now proven through at least one passing runtime test path across the three plans:

| Requirement | Coverage |
| --- | --- |
| **PLOG-LT-01** (live tail re-reads + appends new rows) | Plan 01: `test_tick_appended_rows`, `test_tick_ingests_rows`, `testRealTimerSmokes`. Plan 03 smoke: `test_full_lifecycle` (3 -> 5 entries on tick after append), `testRealTimerTickRoundTrip` |
| **PLOG-LT-02** (no duplicates across re-reads) | Plan 01: `test_tick_dedup_silent`. Plan 03 smoke: `test_full_lifecycle` (re-tick on unchanged file = 3 entries unchanged) |
| **PLOG-LT-03** (configurable interval, default 5) | Plan 01: `test_constructor_defaults`, `test_constructor_custom_interval`, `test_setinterval_validates`, `test_setinterval_while_running_restarts` |
| **PLOG-LT-04** (clean stop, no orphan timers) | Plan 01: `test_start_stop_cleanup`, `testStartStopCleanup`. Plan 03 smoke: `test_full_pipeline_cleanup`, `testFullPipelineCleanup` (timerfindall <= baseline after delete(engine) + delete(tail)) |
| **PLOG-LT-05** (parse errors surface via warning + don't crash timer) | Plan 01: `test_tick_error_increments_count`; getErrorCount bumped on every failed tick |
| **PLOG-VIZ-01** (slider shows black lines for plant-log entries) | Plan 02: `testEngineSliderIntegrationViaTestSeam`, `testLiveTailRefreshTriggersComputePlantLogMarkers`, `test_selector_plant_log_independent`. Plan 03 smoke: `test_engine_slider_integration` (sel.hPlantLogMarkers populated after attach) |
| **PLOG-VIZ-02** (visually distinct from sev1/2/3 + independent storage) | Plan 02: `testSelectorPlantLogIndependentStorage`. Plan 03 smoke verifies independence indirectly (event markers not touched) |
| **PLOG-VIZ-06** (hover tooltip with timestamp + message) | Plan 03: `test_simulate_hover_finds_nearest`, `test_tooltip_text_format`, `test_tooltip_visible_after_show`, `test_engine_lazy_construction`, `testTooltipTextFormat`, `testSimulateHoverFindsNearest`, `testTooltipVisibleAfterShow`, `testEngineLazyConstruction`. Plan 03 smoke: `test_hover_finds_entry`, `testHoverFindsEntry` |
| **PLOG-VIZ-08** (live-tail refresh without full re-render) | Plan 02: `testLiveTailRefreshTriggersComputePlantLogMarkers`. Plan 03 smoke: `test_live_tail_refreshes_slider`, `testLiveTailRefreshesSlider`, `testRealTimerTickRoundTrip` (real timer + listener round-trip without engine.render()) |
| **PLOG-VIZ-09** (theme token MarkerPlantLog) | Plan 02: `test_theme_marker_plant_log_dark/light/override`, `test_theme_legacy_alias_includes_token`, `testThemeMarkerPlantLogDarkAndLight`, `testThemeMarkerPlantLogOverride`. Plan 03 smoke uses DashboardTheme('dark') so the token is exercised on every uifigure-heavy test |

**All 10 PLOG-* requirements have at least one passing runtime test path. Phase 1031 is closed.**

## User Setup Required

None — no external service configuration, no new dependencies, no CLI tools. All edits are pure MATLAB on the existing toolbox-free codebase. The only added timer (auto-hide sweep inside PlantLogSliderHover) is created with `try/catch` so contexts that reject timer creation degrade gracefully (tooltip stays visible until next motion or onLeave).

## Next Phase Readiness

**Ready for /gsd:verify-phase 1031.**

**Forward link to Phase 1032 (per-widget overlay):**
- The chained-WBM hover pattern established here (PlantLogSliderHover) is the template for Phase 1032's per-FastSenseWidget hover. Phase 1032 will add a metadata-rich tooltip variant (multi-line metadata columns instead of just timestamp + message) using the same lifecycle (chained-WBM, throttle, re-entrancy guard, pixel hit-test, restore on delete).
- The lazy-construct + always-teardown-on-change pattern carries forward to FastSenseWidget.attachPlantLogHover_ (Phase 1032 will introduce a similar setter).
- The `_ForTest_` seam pattern is ready for replacement: Phase 1033's attachPlantLog/detachPlantLog public API will internally invoke the same setters that PlantLogSliderHover_ teardown + rebuild logic depends on, so the hover lifecycle just-works without any further Phase 1031 touches.

**Forward link to Phase 1033 (DashboardEngine attachPlantLog public API):**
- `setPlantLogStoreForTest_(store)` -> replace with `attachPlantLog(filePath, opts)` that internally constructs the PlantLogReader + PlantLogStore + PlantLogLiveTail and calls all three setters (store + tail + selector). The hover lifecycle will continue to work because it hangs off the store-attach side.
- `setPlantLogLiveTailForTest_(tail)` -> replace with `detachPlantLog()` that tears down all three plus the hover.
- `setTimeRangeSelectorForTest_(sel)` -> may stay or be removed depending on whether `render()`-driven coverage replaces the test cases. Recommend: keep as a Hidden seam (rename to `setTimeRangeSelector_`) since render()-driven tests still need a way to swap the selector for unit-test isolation.
- The hover-before-selector destructor ordering (this plan's Rule 3 deviation) is already correct for the Phase 1033 public-API teardown path; no further teardown-ordering changes needed.

**Phase 1031 closed; ready for /gsd:verify-phase 1031.**

## Self-Check: PASSED

All claimed artifacts verified:

- `libs/PlantLog/PlantLogSliderHover.m` exists (FOUND)
- `libs/Dashboard/DashboardEngine.m` has PlantLogSliderHover_ + lookupPlantLogEntries_ + teardownPlantLogSliderHover_ (FOUND, all 3 grep checks pass)
- `tests/test_plant_log_slider_hover.m` exists (FOUND)
- `tests/suite/TestPlantLogSliderHover.m` exists (FOUND)
- `tests/test_phase_1031_integration_smoke.m` exists (FOUND)
- `tests/suite/TestPhase1031IntegrationSmoke.m` exists (FOUND)
- All 4 task commit hashes resolve in `git log` (007d94f, 443ad79, 75338a8, 4c5abee — FOUND)
- All 10 hover function-style sub-tests pass on MATLAB
- All 12 hover class-based suite tests pass on MATLAB
- All 6 Phase 1031 integration function-style sub-tests pass on MATLAB
- All 7 Phase 1031 integration class-based suite tests pass on MATLAB (including real-timer round-trip)
- Phase 1029 + 1030 + 1031 Plans 01 + 02 regression: 100% green (132/132 prior plant-log + slider tests + 18 engine tests + 32 event marker tests = 182/182 plus this plan's 35 NEW tests)

---
*Phase: 1031-live-tail-slider-preview-overlay*
*Completed: 2026-05-14*
