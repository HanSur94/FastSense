---
phase: 1039-background-monitoring-with-email-notifications
plan: 02
subsystem: api
tags: [event-detection, headless, launchd, systemd, cron, matlab-batch, octave]

# Dependency graph
requires:
  - phase: 1039-01
    provides: "LiveEventPipeline 'NotificationService' NV-pair + sensorDataForEvent_ + runCycle notify fix (the pipeline this runner drives)"
provides:
  - "libs/EventDetection/runBackgroundMonitoring.m — headless entry function pipeline = runBackgroundMonitoring(setupFcn, varargin) for matlab -batch use under launchd/systemd/cron"
  - "Single tested entry point: write a setupFcn returning a configured LiveEventPipeline, start()/heartbeat/stop() loop handled by the runner"
affects: [1039-03, 1039-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Headless runner with onCleanup-guaranteed teardown for matlab -batch supervisor jobs"
    - "Duck-typed handle validation gated behind isobject() for Octave/MATLAB ismethod portability"

key-files:
  created:
    - libs/EventDetection/runBackgroundMonitoring.m
  modified: []

key-decisions:
  - "Runner validates setupFcn return via isobject() + per-name cellfun(ismethod) instead of the spec's cell-array ismethod, so the validation path works on the CLAUDE.md-mandated Octave runtime (Octave ismethod rejects cell-arrays and errors on non-objects)"
  - "safeStop_ calls isvalid() only when it exists as a builtin (MATLAB), falling back to isobject/ismethod on Octave, so the pipeline.stop()-on-every-exit-path guarantee actually holds under Octave (isvalid is unimplemented there)"
  - "Catch block is a single fprintf fall-through to onCleanup (revision-1 simple form) — no dead conditional, no MATLAB:catenate:dimensionMismatch reference"

patterns-established:
  - "Octave-portability guard for duck-typed handle checks: isobject(h) && all(cellfun(@(nm) ismethod(h,nm), names))"
  - "Feature-detect MATLAB-only builtins with exist('fn','builtin')==5 before calling, fall back on Octave"

requirements-completed: []

# Metrics
duration: 6min
completed: 2026-05-29
---

# Phase 1039 Plan 02: runBackgroundMonitoring Headless Entry Summary

**Headless `runBackgroundMonitoring(setupFcn, 'PollSec', S, 'MaxRuntimeSec', T)` entry for `matlab -batch` supervisor jobs — starts a user-built LiveEventPipeline, prints grep-friendly `[BG]` heartbeats, and guarantees `pipeline.stop()` on every exit path via onCleanup.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-05-29T17:27:48Z
- **Completed:** 2026-05-29T17:33:28Z
- **Tasks:** 1
- **Files modified:** 1 (created)

## Accomplishments
- New `libs/EventDetection/runBackgroundMonitoring.m` — `pipeline = runBackgroundMonitoring(setupFcn, varargin)`, designed for `matlab -batch "runBackgroundMonitoring(@my_setup_fcn)"` under launchd/systemd/cron.
- NV-pairs `'PollSec'` (default 60, must be >= 1) and `'MaxRuntimeSec'` (default 0 = infinite, must be >= 0), parsed via the co-located `private/parseOpts.m`.
- Four documented namespaced error IDs: `EventDetection:invalidSetupFcn`, `EventDetection:invalidOption`, `EventDetection:setupFcnFailed`, `EventDetection:setupFcnBadReturn`.
- Lifecycle: validate → `pipeline = setupFcn()` → duck-type validate return → `pipeline.start()` → `onCleanup(@() safeStop_(pipeline))` → heartbeat loop → returns the pipeline handle on graceful exit.
- Heartbeat single-line format printed every `PollSec`: `[BG] HH:MM:SS  events=N  emails=M  uptime=Ts` (events from `EventStore.numEvents()`, emails from `NotificationService.NotificationCount`, both defensively guarded).
- Catch block is the revision-1 simple form: a single `fprintf` that falls through to onCleanup (no dead-code conditional, no `MATLAB:catenate:dimensionMismatch`).

## Task Commits

Each task was committed atomically:

1. **Task 1: Create libs/EventDetection/runBackgroundMonitoring.m** - `f423fd6c` (feat)

**Plan metadata:** (final docs commit — see below)

## Files Created/Modified
- `libs/EventDetection/runBackgroundMonitoring.m` - Headless entry function for unattended LiveEventPipeline monitoring under matlab -batch.

## Decisions Made
- **Validation path made Octave-portable.** The plan's verbatim `~all(ismethod(pipeline, {'start','stop'}))` is MATLAB-only — Octave's `ismethod` rejects a cell-array of method names ("METHOD must be a string") and errors on any non-object argument ("first argument must be object or class name"). Replaced with `isobject(pipeline) && all(cellfun(@(nm) ismethod(pipeline, nm), {'start','stop'}))`, which is semantically identical on MATLAB and correct on Octave (cleanly returns `setupFcnBadReturn` for `[]`, structs, and numerics rather than crashing).
- **`safeStop_` made Octave-portable.** `isvalid()` is a MATLAB builtin (protects against `.Status` access on a deleted handle) but is **not implemented in Octave** — the verbatim `safeStop_` swallowed an "isvalid undefined" error and never stopped the pipeline. Now `isvalid` is called only when `exist('isvalid','builtin')==5` (MATLAB), with an `isobject`/`ismethod` fallback on Octave, so the stop-on-every-exit-path guarantee holds on both runtimes.
- **Catch block kept simple (revision 1).** Single `fprintf` then fall-through to onCleanup; no `if ~strcmp(ME.identifier, ...)` conditional and no `MATLAB:catenate:dimensionMismatch` copy-paste, per the plan's explicit revision note.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Octave-incompatible `ismethod` cell-array call in return-shape validation**
- **Found during:** Task 1 (smoke test under Octave)
- **Issue:** The verbatim spec used `~all(ismethod(pipeline, {'start','stop'}))`. Octave's `ismethod` does not accept a cell-array of names (`ismethod: METHOD must be a string`) and additionally errors on non-object inputs like `[]`/struct/numeric (`first argument must be object or class name`). Under the CLAUDE.md-mandated Octave runtime this throws an uncaught error during validation instead of the documented `EventDetection:setupFcnBadReturn`, and Plan 04's CI test (`tests/test_run_background_monitoring.m`) runs on Octave.
- **Fix:** Replaced with `hasLifecycle = isobject(pipeline) && all(cellfun(@(nm) ismethod(pipeline, nm), {'start','stop'}))` and reordered so `isobject` short-circuits before `ismethod` is ever evaluated. Semantically identical on MATLAB; correct on Octave (`setupFcnBadReturn` for `[]`/struct/numeric, accept for real handle shape).
- **Files modified:** libs/EventDetection/runBackgroundMonitoring.m
- **Verification:** Octave smoke suite S3/S3b/S3c (`@() []`, `@() struct('a',1)`, `@() 42`) all throw `EventDetection:setupFcnBadReturn`; real-pipeline path accepted (S7/S8). `mh_lint`/`mh_style` clean.
- **Committed in:** f423fd6c (Task 1 commit)

**2. [Rule 1 - Bug] `safeStop_` never stopped the pipeline on Octave (`isvalid` unimplemented)**
- **Found during:** Task 1 (lifecycle smoke test under Octave)
- **Issue:** The verbatim `safeStop_` calls `isvalid(pipeline)`. `isvalid` is not implemented in Octave (`exist('isvalid')==0`); the call threw, was swallowed by `safeStop_`'s try/catch, and `pipeline.stop()` was never invoked — leaving `Status='running'` after a graceful exit. This defeats the locked success criterion "pipeline.stop() runs on every exit path" and the test contract "returns within 2.5s with Status 'stopped'".
- **Fix:** `safeStop_` now early-returns on `isempty/~isobject/~ismethod(pipeline,'stop')`, calls `isvalid` only when `exist('isvalid','builtin')==5` (MATLAB — preserves deleted-handle protection), and otherwise stops when `Status=='running'`. Octave-safe; MATLAB behavior preserved.
- **Files modified:** libs/EventDetection/runBackgroundMonitoring.m
- **Verification:** Octave smoke S7 lifecycle (`MaxRuntimeSec=2`, `PollSec=1`) returns in 2.02s with `p.Status == 'stopped'`; S8 notif-branch returns `Status == 'stopped'` and heartbeat shows `emails=7`. `mh_lint`/`mh_style` clean.
- **Committed in:** f423fd6c (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking Octave incompatibility, 1 Octave stop-guarantee bug)
**Impact on plan:** Both fixes are confined to two small portability guards (return-shape validation and `safeStop_`). The public signature, NV-pairs, the four error IDs, the heartbeat format string, the onCleanup wiring, the single-`fprintf` catch block, and all naming/error-ID conventions are exactly as specified. MATLAB behavior is byte-equivalent to the verbatim spec; the changes only add a portable fallback so the function also works under the project's first-class Octave runtime (CI + Plan 04 tests). No scope creep; no behavioral change on MATLAB.

## Issues Encountered
- The MATLAB MCP tools (`mcp__matlab__check_matlab_code` / `evaluate_matlab_code`) were not available in this sequential-executor session. Per the runtime note, fell back to the project's CI static checker (MISS_HIT `mh_lint` + `mh_style`, both report "everything seems fine") and Octave (`FASTSENSE_SKIP_BUILD=1`) for smoke testing. All 11 smoke assertions pass under Octave; lint/style clean.

## User Setup Required
None - no external service configuration required. (SMTP configuration is documented in Plan 03's README; this plan only ships the runner.)

## Next Phase Readiness
- **Plan 03/04:** The runner is callable as `runBackgroundMonitoring(@setup_fn, 'PollSec', S, 'MaxRuntimeSec', T)`. `setup_fn` must return a configured `LiveEventPipeline` (or any handle with `start`/`stop` methods + a `Status` property). On graceful exit it returns the pipeline handle so Plan 04's `tests/test_run_background_monitoring.m` can assert `pipeline.Status == 'stopped'` after `MaxRuntimeSec`.
- **Heartbeat contract for tests/ops:** stdout lines match `^\[BG\] \d\d:\d\d:\d\d  events=\d+  emails=\d+  uptime=[\d.]+s$`, plus a start line and an exit line — grep-friendly in the systemd/launchd journal.
- No blockers.

## Self-Check: PASSED

- `libs/EventDetection/runBackgroundMonitoring.m` — FOUND
- `.planning/phases/1039-background-monitoring-with-email-notifications/1039-02-SUMMARY.md` — FOUND
- Task commit `f423fd6c` — FOUND (file tracked, 166 insertions)

---
*Phase: 1039-background-monitoring-with-email-notifications*
*Completed: 2026-05-29*
