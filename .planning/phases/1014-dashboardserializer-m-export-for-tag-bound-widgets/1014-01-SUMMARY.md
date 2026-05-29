---
phase: 1014-dashboardserializer-m-export-for-tag-bound-widgets
plan: 01
subsystem: serialization
tags: [matlab, dashboard, tag, serializer, export, .m, round-trip]

# Dependency graph
requires:
  - phase: 1009-consumer-migration
    provides: FastSenseWidget.toStruct emits source.type='tag' with key field
  - phase: 1011
    provides: TagRegistry public API (get/register/clear); legacy Sensor classes deleted
  - phase: 1013
    provides: DEAD-04 fastsense source.type='sensor' emit path now safe to delete (no remaining callers)
provides:
  - "case 'tag' branch in DashboardSerializer.save() inline switch with try/catch guard around TagRegistry.get(key)"
  - "case 'tag' branch in DashboardSerializer.linesForWidget() helper (shared by exportScript single-page and exportScriptPages multi-page)"
  - "Deletion of legacy case 'sensor' emitter from BOTH switches (in-memory widgets only emit source.type='tag' post-v2.0)"
  - "Public observable error ID DashboardSerializer:tagNotRegistered preserved (mechanism switched from non-existent ~TagRegistry.has guard to try/catch around TagRegistry.get)"
  - "tests/suite/TestDashboardSerializerTagExport.m — 4-method round-trip suite (single-page save, single-page exportScript helper, multi-page exportScriptPages, unregistered-tag-fails-loudly)"
affects: [1015-test-suite-cleanup, 1016-examples-05-events-rewrite, 1017-tag-system-event-auto-wiring]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Serializer try/catch guard pattern: emit try; tag_<key> = TagRegistry.get('<key>'); catch; error('Class:errorId', ...); end — used in lieu of a non-existent .has() check"
    - "One-direction migration: emitter writes only the new format (source.type='tag'); reader (FastSenseWidget.fromStruct) keeps both 'tag' and 'sensor' branches for legacy JSON backward compat"
    - "Deterministic temp .m filename helper for round-trip tests: fullfile(tempdir, 'tag_export_<HHMMSSFFF>_<counter>.m') — guarantees a valid MATLAB function name on every platform (avoids macOS Octave tempname() hyphen problem)"

key-files:
  created:
    - tests/suite/TestDashboardSerializerTagExport.m
  modified:
    - libs/Dashboard/DashboardSerializer.m

key-decisions:
  - "Try/catch around TagRegistry.get is the canonical guard for emitted .m scripts (TagRegistry.has does not exist on the public API)"
  - "case 'sensor' emitter deleted from BOTH save() inline switch AND linesForWidget helper; FastSenseWidget.fromStruct legacy 'sensor' reader retained for backward-compat with on-disk JSON"
  - "tempname() rejected for round-trip test temp paths — macOS Octave inserts hyphens that break feval/load; deterministic alphanumeric+underscore name in tempdir used instead"
  - "Test 2 (singlePageTagWidgetRoundTripsViaExportScript) calls DashboardSerializer.exportScript directly to cover the linesForWidget helper path — d.save() on single-page goes through the inline switch only"

patterns-established:
  - "Serializer error rethrow with own namespace: TagRegistry:unknownKey is caught by emitted scripts and rethrown as DashboardSerializer:tagNotRegistered so the public observable error ID remains stable across implementation changes"
  - "Suite-test pattern for Tag round-trips: TestClassSetup addPaths + install(); TestMethodSetup TagRegistry.clear(); MakePhase1009Fixtures factory for tag setup"

requirements-completed: [MEXP-01, MEXP-02, MEXP-03, MEXP-04, MEXP-05]

# Metrics
duration: 11min
completed: 2026-04-28
---

# Phase 1014 Plan 01: DashboardSerializer .m export for Tag-bound widgets Summary

**Tag-bound dashboard widgets now round-trip through `.m` export with a try/catch-guarded `TagRegistry.get('key')` lookup; legacy `case 'sensor'` emitter deleted from both switches in DashboardSerializer.m.**

## Performance

- **Duration:** 11 min (665 s)
- **Started:** 2026-04-28T11:45:11Z
- **Completed:** 2026-04-28T11:56:16Z
- **Tasks:** 3
- **Files modified:** 1 (DashboardSerializer.m)
- **Files created:** 1 (TestDashboardSerializerTagExport.m)

## Accomplishments

- Added `case 'tag'` to BOTH switch statements in `DashboardSerializer.m`:
  - `save()` inline switch (~line 39) — single-page `.m` save path
  - `linesForWidget()` helper (~line 599) — shared by `exportScript` (single-page) and `exportScriptPages` (multi-page)
- Both branches emit a try/catch guard around `TagRegistry.get('<key>')` with rethrow as the public observable `DashboardSerializer:tagNotRegistered` error ID. Local var `tag_<key>` keeps the addWidget call readable.
- Deleted the legacy `case 'sensor'` emitter branch from both switches. In-memory v2.0 widgets only emit `source.type='tag'`. `FastSenseWidget.fromStruct` retains its `'sensor'` reader for backward-compat with on-disk JSON dashboards.
- Shipped `tests/suite/TestDashboardSerializerTagExport.m` with 4 methods covering all paths:
  - `singlePageTagWidgetRoundTripsViaSave` — exercises the save() inline switch
  - `singlePageTagWidgetRoundTripsViaExportScript` — exercises the linesForWidget helper on the single-page path (closes plan-checker iter-1 blocker #2)
  - `multiPageTagWidgetsRoundTripViaM` — exercises exportScriptPages
  - `unregisteredTagFailsLoudly` — verifies the emitted try/catch fires `DashboardSerializer:tagNotRegistered` (NOT the underlying `TagRegistry:unknownKey`)

## Task Commits

1. **Task 1:** `7902a9d` — `feat(1014-01): add case 'tag' to linesForWidget, drop case 'sensor' (MEXP-01..05)`
2. **Task 2:** `2487233` — `feat(1014-01): add case 'tag' to save() inline switch, drop case 'sensor' (MEXP-01..05)`
3. **Task 3:** `e91b538` — `test(1014-01): add TestDashboardSerializerTagExport suite (4 methods, MEXP-04)`

## Files Created/Modified

- `libs/Dashboard/DashboardSerializer.m` — +20/-4 LOC; both switches now emit Tag-bound widgets via `TagRegistry.get` with a try/catch guard rethrowing `DashboardSerializer:tagNotRegistered`
- `tests/suite/TestDashboardSerializerTagExport.m` (new, 174 LOC) — 4-method matlab.unittest round-trip suite + iMakeTempMPath/iSafeDelete local helpers

## Verification Gates

- **Gate A — scope:** PASS. Only `libs/Dashboard/DashboardSerializer.m` and `tests/suite/TestDashboardSerializerTagExport.m` modified. Net +194/-4 LOC (DashboardSerializer.m alone +16 net; test file 174 LOC).
- **Gate B — golden untouched:** PASS. `git diff -- tests/suite/TestGoldenIntegration.m tests/test_golden_integration.m` returns 0 lines.
- **Gate C — dead-code grep:** PASS.
  - `grep -rE '(EventDetector|IncrementalEventDetector|EventConfig)' libs/ benchmarks/ install.m` = 0 hits (Phase 1013 regression check)
  - `grep -c "case 'sensor'" libs/Dashboard/DashboardSerializer.m` = 0 (sensor emitter deleted)
  - `grep -c "case 'sensor'" libs/Dashboard/FastSenseWidget.m` = 1 (legacy reader retained)
  - `grep -c "TagRegistry\.has" libs/Dashboard/DashboardSerializer.m` = 0 (no references to non-existent guard method)
  - `grep -c "case 'tag'" libs/Dashboard/DashboardSerializer.m` = 2
  - `grep -c "DashboardSerializer:tagNotRegistered" libs/Dashboard/DashboardSerializer.m` = 2
- **Gate D — Octave smoke:** PASS. `test_dashboard_engine_event_markers` + `test_dashboard_multipage_render` green (6/6 tests passed; OCTAVE_SMOKE_OK printed). Additional ad-hoc Octave smoke run exercised all 4 Phase 1014 test scenarios end-to-end (save inline path, exportScript helper path, multi-page exportScriptPages, unregistered-tag-fails-loudly): all 4 PASS on Octave 7+.
- **Gate E — MATLAB CI:** DEFERRED. Local environment has no MATLAB binary; verification belongs to CI / verifier agent. Octave smoke (Gate D) gives high confidence: all 4 emitter paths produce syntactically valid scripts that load via `DashboardEngine.load`.

## Decisions Made

- **Try/catch over `~TagRegistry.has` guard:** `TagRegistry.has(key)` does not exist on the public API of `libs/SensorThreshold/TagRegistry.m` (only `get/register/unregister/clear/find/findByLabel/findByKind/list/printTable/viewer/loadFromStructs/instantiateByKind`). The natural pattern is `try; TagRegistry.get(key); catch; error('DashboardSerializer:tagNotRegistered', ...); end`. The public observable error ID is unchanged; only the underlying mechanism changed.
- **`case 'sensor'` deletion in BOTH switches:** Decision locked from CONTEXT (Open Question #3). One-direction migration: in-memory widgets always emit `source.type='tag'` post-v2.0; old JSON files on disk read via `FastSenseWidget.fromStruct`'s `'sensor'` legacy branch and migrate to Tag-bound state at load.
- **Local var `tag_<key>` over inline `TagRegistry.get(...)`:** Captures the registry handle once so the addWidget call stays readable. `<key>` suffix scopes the variable per-widget so multi-widget pages don't collide on a single name.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Replaced `tempname()` with deterministic alphanumeric tempdir filename in test helper**
- **Found during:** Task 3 (Octave smoke validation of the test scenarios)
- **Issue:** Plan recommended `[tempname(), '.m']` for round-trip test temp paths. On macOS Octave, `tempname()` returns paths like `/tmp/oct-xeyIRg`, which produce filenames `oct-xeyIRg.m`. The hyphen is invalid in a MATLAB function identifier, so `feval(funcname)` (used by `DashboardEngine.load(.m)` and the Test 4 verifyError path) fails with `function not found`. Plan's R2020b version-skew note (lines 354-356) anticipated this risk and pre-authorized the fallback.
- **Fix:** `iMakeTempMPath()` now uses `fullfile(tempdir, ['tag_export_', datestr(now,'HHMMSSFFF'), '_', num2str(counter), '.m'])` with a persistent counter for same-tick uniqueness. Guarantees a valid MATLAB function name on every platform.
- **Files modified:** tests/suite/TestDashboardSerializerTagExport.m (helper function only)
- **Verification:** Octave smoke run of all 4 scenarios PASS after the change (vs. error before). MATLAB R2020b will accept this filename shape unconditionally.
- **Committed in:** `e91b538` (Task 3 commit)

**2. [Rule 3 — Plan gate adjustment] `ws.source.name` count gate adjusted**
- **Found during:** Task 1 verification
- **Issue:** Plan's Task 1+2 gates expected `grep -c "ws.source.name" libs/Dashboard/DashboardSerializer.m` to drop to 0 after both tasks. The actual baseline on `main` was 4 hits: 1 in save() emitter (deleted by Task 2), 1 in linesForWidget emitter (deleted by Task 1), and 2 in `configToWidgets` resolver path (lines 291 and 294 — `widgets{i}.Sensor = resolver(ws.source.name)` and the warning message).
- **Fix:** No code change. The 2 `configToWidgets` hits are unrelated to the emitter switches; they reference an obsolete `widgets{i}.Sensor` setter that no longer exists on FastSenseWidget post-Phase-1011 — dead code that runs only when a `resolver` arg is passed to `configToWidgets`. Cleaning them is out of Phase 1014 scope (Pitfall 1 — different code path; Phase 1015 owns test suite cleanup; the resolver path itself is a candidate for a future cleanup phase).
- **Verification:** Final state — `grep -c "ws.source.name" libs/Dashboard/DashboardSerializer.m` = 2 (down from 4). The 2 emitter hits are gone; the 2 resolver hits remain. The plan's emitter-scope intent is satisfied.
- **Documented as:** Logged in this SUMMARY (no separate deferred-items entry needed; explicitly documented Pitfall 1 boundary).

---

**Total deviations:** 2 (1 blocking-fix in test helper; 1 gate-criteria refinement)
**Impact on plan:** Both deviations are scope-preserving. The plan's intent (Tag-bound emitter with try/catch guard, legacy sensor emitter deleted, 4-method round-trip suite) is fully realized.

## Issues Encountered

- **macOS Octave `tempname()` collision with MATLAB function name rules:** documented above as Deviation #1.
- **Mid-execution branch switch:** during Octave full-suite regression test, an external process (auto-managed `.claude/scheduled_tasks.lock`) appears to have switched HEAD from `main` to `fix/release-multiplatform`. Recovered by `git checkout main`. All 3 Phase 1014 commits (`7902a9d`, `2487233`, `e91b538`) are on `main` as planned. The `fix/release-multiplatform` branch is unrelated to this phase and was unaffected.
- **Pre-existing Octave failures (not caused by this phase):** `test_event_detector_tag` (file missing locally), `test_mex_prebuilt` (MEX-binary detection), `test_toolbar` (Octave PostSet listener limitation, abort trap). None touch DashboardSerializer; verified by `grep DashboardSerializer` against each test file (0 hits).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **Phase 1015 hand-off:** `TestDashboardSerializerTagExport` is auto-discovered by `tests/run_all_tests.m` via `TestSuite.fromFolder` and adds **4 rows** to the MATLAB suite test count baseline (relevant for TEST-11 inventory).
- **Phase 1016 hand-off:** No impact — example scripts don't go through the serializer .m export path.
- **Phase 1017 hand-off:** TagRegistry-default `EventStore` work in 1017 will not interact with the serializer changes here (events are runtime-only, not serialized).
- **Pitfall 1 recheck:** zero unrelated files modified. Only `DashboardSerializer.m` and the new test file.
- **`ws.source.name` clean-up backlog:** 2 references remain in `DashboardSerializer.configToWidgets` (lines 291/294) reading from a legacy `resolver` parameter and writing to an obsolete `widgets{i}.Sensor` setter. Out of Phase 1014 scope. Could be considered for a future generic-cleanup quick-task or Phase 1015's test cleanup if the resolver path shows up in any test.

## Self-Check: PASSED

Verification of claims:

- Files exist:
  - `libs/Dashboard/DashboardSerializer.m`: FOUND
  - `tests/suite/TestDashboardSerializerTagExport.m`: FOUND
- Commits exist on `main`:
  - `7902a9d` Task 1 (linesForWidget): FOUND
  - `2487233` Task 2 (save inline): FOUND
  - `e91b538` Task 3 (test suite): FOUND
- Grep gates green (DashboardSerializer.m): `case 'tag'` = 2, `case 'sensor'` = 0, `tagNotRegistered` = 2, `TagRegistry.has` = 0, `TagRegistry.get(` = 2
- FastSenseWidget legacy reader: `case 'sensor'` = 1 (retained for JSON backward compat)
- Octave smoke (Gate D): PASS — 6/6 tests + ad-hoc 4-scenario emitter run PASS

---
*Phase: 1014-dashboardserializer-m-export-for-tag-bound-widgets*
*Completed: 2026-04-28*
