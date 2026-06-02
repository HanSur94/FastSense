---
phase: 1039-background-monitoring-with-email-notifications
plan: 04
subsystem: testing
tags: [matlab, octave, regression-test, notification, live-event-pipeline, headless-runner, mock]

# Dependency graph
requires:
  - phase: 1039-01
    provides: "LiveEventPipeline.runCycle sensorData fix (sensorDataForEvent_) + 'NotificationService' NV-pair"
  - phase: 1039-02
    provides: "runBackgroundMonitoring headless runner + 4 documented error IDs + onCleanup stop guarantee"
provides:
  - "tests/CaptureNotificationService.m — NotificationService mock that captures notify() (event, sensorData) args"
  - "tests/test_live_event_pipeline_notif_sensor_data.m — 2 sub-tests guarding Plan 01's sensorData=struct() fix via real runCycle"
  - "tests/test_run_background_monitoring.m — 5 sub-tests guarding Plan 02's runner lifecycle + error IDs"
affects: [future LiveEventPipeline refactors, future runBackgroundMonitoring changes, notification snapshot pipeline]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Capture-mock subclass: subclass NotificationService, override notify() to stash args into public cell arrays, skip super (no email)"
    - "Duck-typed headless-runner lifecycle test: real LiveEventPipeline lifecycle assertions are MATLAB-only (Octave lacks timer); error-ID assertions are runtime-agnostic"

key-files:
  created:
    - tests/CaptureNotificationService.m
    - tests/test_live_event_pipeline_notif_sensor_data.m
    - tests/test_run_background_monitoring.m
  modified: []

key-decisions:
  - "Capture mock lives in its own file tests/CaptureNotificationService.m (classdef cannot be local to a function file); mirrors StubDataSource idiom"
  - "Reused MakePhase1009Fixtures.makeEventStoreTmp() for the EventStore temp path instead of a local tempname_short_ clone (suite consistency)"
  - "sensorData test exercises the real runCycle notify path (not sensorDataForEvent_ in isolation) so it guards the exact struct() regression site"

patterns-established:
  - "Pattern: regression tests for the LiveEventPipeline notify path drive runCycle() directly (no timer) so they run on Octave AND MATLAB"
  - "Pattern: runner lifecycle proof uses MATLAB (timer-backed start()); error-ID/validation proof runs on both runtimes"

requirements-completed: []

# Metrics
duration: 18min
completed: 2026-05-29
---

# Phase 1039 Plan 04: Regression Tests for Notify-Path sensorData Fix + Headless Runner Lifecycle Summary

**Two function-based regression tests plus a capture mock that lock down Plan 01's runCycle `sensorData` fix (non-empty `.X`/`.Y`/`.thresholdValue`/`.thresholdDirection` proven through the real notify path) and Plan 02's `runBackgroundMonitoring` lifecycle (MaxRuntimeSec timeout → `Status='stopped'`) plus all three documented error IDs.**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-05-29T17:44Z
- **Completed:** 2026-05-29T18:02Z
- **Tasks:** 2
- **Files created:** 3 (1 helper class + 2 test files)

## Accomplishments
- `tests/CaptureNotificationService.m` — a `NotificationService` subclass whose `notify(obj, event, sensorData)` override stashes both arguments into public `CapturedEvents` / `CapturedSensorData` cell arrays (with `LastEvent` / `LastSensorData` accessors), without invoking rule resolution, snapshot generation, or `sendmail`.
- `tests/test_live_event_pipeline_notif_sensor_data.m` — 2 sub-tests that build a `SensorTag`+`MonitorTag` (threshold `y > 15`), wire the capture mock via the Plan 01 `'NotificationService'` NV-pair, fire a violation, run `pipeline.runCycle()`, and assert the captured `sensorData` has non-empty `.X`/`.Y` of equal length plus `.thresholdValue`/`.thresholdDirection`. This is the regression guard for Plan 01's `sensorData = struct()` bug.
- `tests/test_run_background_monitoring.m` — 5 sub-tests: the two lifecycle proofs (`MaxRuntimeSec=2` returns in `[2,5)s`; returned `pipeline.Status == 'stopped'`) and the three error-ID validations (`invalidSetupFcn`, `setupFcnBadReturn`, `invalidOption`).
- Reused the existing `MakePhase1009Fixtures.makeEventStoreTmp()` helper for the EventStore temp path (no local `tempname_short_` clone) — verified by grep (1 match / 0 matches).

## Task Commits

Each task was committed atomically:

1. **Task 1: CaptureNotificationService.m + test_live_event_pipeline_notif_sensor_data.m** - `9374fa88` (test)
2. **Task 2: test_run_background_monitoring.m** - `85773a78` (test)

**Plan metadata:** (this commit) (docs: complete plan)

## Files Created/Modified
- `tests/CaptureNotificationService.m` - `NotificationService` subclass that captures `notify()` arguments instead of emailing; used to assert `runCycle` hands `notify` a populated `sensorData`.
- `tests/test_live_event_pipeline_notif_sensor_data.m` - 2 sub-tests proving the Plan 01 `sensorData` fix through the real `runCycle` notify path.
- `tests/test_run_background_monitoring.m` - 5 sub-tests proving Plan 02 runner lifecycle (timeout exit + stopped status) and all three error IDs.
- `.planning/phases/1039-background-monitoring-with-email-notifications/deferred-items.md` - logged one out-of-scope Octave-only environmental flake (see below).

## Test Counts & Run-Time Evidence

| Test file | Sub-tests | Octave | MATLAB R2025b |
| --------- | --------- | ------ | ------------- |
| `test_live_event_pipeline_notif_sensor_data.m` | 2 | **2/2 PASS** | **2/2 PASS** |
| `test_run_background_monitoring.m` | 5 | 3/3 error-ID PASS (2 lifecycle = MATLAB-only) | **5/5 PASS** (exits 2.21s, `Status='stopped'`) |

Existing-tests regression sweep (must stay green):

| Test file | Octave | MATLAB |
| --------- | ------ | ------ |
| `test_live_event_pipeline_tag.m` | **3/3 PASS** (Plan 01 did not regress it) | — |
| `test_notification_service.m` | 6/7 (snapshot env flake — see Deferred) | **7/7 PASS** |

- 7 new sub-tests total (2 + 5). Combined wall clock well under the 20s budget (the runner test is the slow one at ~4.5s of `pause()`; the sensorData test is sub-second).
- Static analysis: `mh_lint` + `mh_style` report "everything seems fine" on all 3 new files.
- Greps: `MakePhase1009Fixtures.makeEventStoreTmp()` = 1 match, `tempname_short_` = 0 matches; `assert(~isempty(sd.X)` / `assert(~isempty(sd.Y)` = 1 each; `'NotificationService', cap` = 1; all three `EventDetection:*` error IDs present.

## Decisions Made
- **Capture mock as a standalone file:** MATLAB does not allow a `classdef` local to a function file, so the mock ships as `tests/CaptureNotificationService.m` (the locked Plan-04 decision), mirroring the existing `StubDataSource` test-helper idiom.
- **Reuse `makeEventStoreTmp()` over a local clone:** keeps EventStore temp-path construction consistent with `test_live_event_pipeline_tag.m` and the rest of the suite (Plan-04 revision 1).
- **sensorData test drives the real `runCycle`:** asserting against `sensorDataForEvent_` in isolation would not guard the actual regression site (the `notify(ev, struct())` line). Driving `runCycle()` end-to-end means the test fails loudly if a future refactor reintroduces `struct()`.

## Deviations from Plan

None — both tasks executed exactly as written (verbatim file contents from the plan). No Rule 1/2/3 auto-fixes were needed; the underlying Plan 01/02 code under test was already correct (both new tests pass against it without modification).

## Issues Encountered

- **MATLAB MCP tools unavailable this session.** The `mcp__matlab__*` tool namespace was not loaded, so the plan's `<verify>` `matlab -batch` blocks and `mcp__matlab__run_matlab_test_file` could not be invoked through the MCP. Resolved per the sequential-executor runtime note's documented fallback: ran function-based tests under the Octave CLI (`FASTSENSE_SKIP_BUILD=1`) plus MISS_HIT `mh_lint`/`mh_style`, and additionally drove a separate headless `matlab -batch` process (the on-PATH MATLAB launcher) to obtain the timer-dependent lifecycle proof. The headless MATLAB run did not disturb the user's live session.
- **Octave lacks `timer` (expected, documented).** `exist('timer')==0` on Octave and `LiveEventPipeline.start()` throws `Octave:undefined-function` ("'timer' ... not yet implemented in Octave"). Therefore the two lifecycle sub-tests in `test_run_background_monitoring.m` (which use a real `LiveEventPipeline` whose `start()` creates a timer) are **MATLAB-only**; they were proven 5/5 under MATLAB R2025b (exit 2.21s, `Status='stopped'`). The three error-ID sub-tests do not reach `start()` and pass on both runtimes.

## Deferred Issues

- **Octave-only `test_snapshot_generation` flake** (out of scope, logged in `deferred-items.md`): under headless Octave (FLTK toolkit) the existing `test_notification_service / test_snapshot_generation` PNG-rendering assertion fails. It is NOT caused by Plan 04 (Plan 04 added only test files; `NotificationService.m`/`generateEventSnapshot.m` untouched) and passes 7/7 under MATLAB. Environmental rendering dependency only.

## Known Stubs

None — the two test files contain real assertions wired to live fixtures (no placeholder/empty-data stubs). The capture mock intentionally returns `struct()` from `LastSensorData()` only when nothing has been captured yet; in the test path it always returns the real captured struct.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 1039 is now complete (4/4 plans). The notify-path sensorData fix (Plan 01) and the headless runner (Plan 02) both have regression guards; the demo + README (Plan 03) ship the user-facing entry point.
- Note for retro: these two tests double as regression guards for ANY future `LiveEventPipeline` refactor that touches the notify path or the runner lifecycle — they will fail loudly if `runCycle` regresses to `notify(ev, struct())` or if the runner's error IDs / stopped-on-exit contract changes.

## Self-Check: PASSED

- Files verified on disk: `tests/CaptureNotificationService.m`, `tests/test_live_event_pipeline_notif_sensor_data.m`, `tests/test_run_background_monitoring.m`, `1039-04-SUMMARY.md`, `deferred-items.md` — all FOUND.
- Commits verified: `9374fa88` (Task 1), `85773a78` (Task 2) — both FOUND.

---
*Phase: 1039-background-monitoring-with-email-notifications*
*Completed: 2026-05-29*
