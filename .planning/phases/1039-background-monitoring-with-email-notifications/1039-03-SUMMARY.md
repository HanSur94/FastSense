---
phase: 1039-background-monitoring-with-email-notifications
plan: 03
subsystem: event-detection
tags: [background-monitoring, email, launchd, systemd, cron, matlab-batch, smtp, notification, demo, example]

# Dependency graph
requires:
  - phase: 1039-01
    provides: "LiveEventPipeline 'NotificationService' NV-pair + sensorDataForEvent_ open-event handling"
  - phase: 1039-02
    provides: "runBackgroundMonitoring(setupFcn, 'PollSec', S, 'MaxRuntimeSec', T) headless entry"
provides:
  - "example_background_email_monitor_setup.m — top-level, production-callable setup function returning a configured LiveEventPipeline (@-handle resolves across matlab -batch supervisor invocations)"
  - "example_background_email_monitor.m — thin bounded demo wrapper (MaxRuntimeSec=8) over the runner"
  - "README_background_email.md — operator doc with launchd/systemd/cron snippets, env-var SMTP config, dry-run toggle, troubleshooting"
  - "Open-event (NaN EndTime) hardening of NotificationRule.fillTemplate + generateEventSnapshot (notifications/snapshots no longer abort on open events)"
affects: [1039-04, background-monitoring, notification, event-detection]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Top-level function file (not in-script local) so a @-handle resolves from matlab -batch supervisor jobs"
    - "Thin wrapper script delegates ALL setup to a standalone function file = the production invocation IS the smoke test"
    - "Open-event NaN guard: clamp EndTime to last sample / render (open)+(ongoing) in templates (mirrors sensorDataForEvent_)"

key-files:
  created:
    - examples/05-events/example_background_email_monitor_setup.m
    - examples/05-events/example_background_email_monitor.m
    - examples/05-events/README_background_email.md
  modified:
    - libs/EventDetection/NotificationRule.m
    - libs/EventDetection/generateEventSnapshot.m

key-decisions:
  - "Split setup into a top-level function file so @example_background_email_monitor_setup resolves from launchd/systemd/cron matlab -batch invocations (local functions in a script are invisible to outside callers)"
  - "Wire each MonitorTag.EventStore to a shared EventStore (proven Tag-path pattern) so the pipeline harvests per-tick event deltas — without it zero events fire and the notify path is never exercised"
  - "Harden the notification path for open events (NaN EndTime) in NotificationRule.fillTemplate + generateEventSnapshot rather than tuning the demo to avoid open events — the bug aborts every open-event alert and the fix benefits all callers"

patterns-established:
  - "Supervisor-invokable MATLAB entry: top-level function file + @-handle + `install;` prefix in the matlab -batch command"
  - "Open-event-safe notification rendering: guard datestr(NaN) and xlim([NaN NaN]) at the template/snapshot boundary"

requirements-completed: []

# Metrics
duration: 13min
completed: 2026-05-29
---

# Phase 1039 Plan 03: Background Email Monitor Demo + README Summary

**Top-level `example_background_email_monitor_setup` function + thin `runBackgroundMonitoring` wrapper + operator README (launchd/systemd/cron, env-var SMTP, dry-run toggle), plus open-event NaN hardening of the notification/snapshot path so the demo runs warning-free and fires 36 alerts end-to-end.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-05-29T17:38:58Z
- **Completed:** 2026-05-29T17:52:12Z
- **Tasks:** 2
- **Files modified:** 5 (3 created, 2 modified)

## Accomplishments
- Shipped `example_background_email_monitor_setup.m` as a TOP-LEVEL function file — the critical structural fix (revision 1): `@example_background_email_monitor_setup` now resolves from `matlab -batch` supervisor invocations because the function lives in its own `.m` file on the path (local functions inside a script body are invisible to outside callers).
- Shipped `example_background_email_monitor.m` as a thin (3-line body) wrapper that delegates ALL setup to the standalone function and invokes `runBackgroundMonitoring(@example_background_email_monitor_setup, 'PollSec', 2, 'MaxRuntimeSec', 8)` — the same invocation pattern the README documents for production, so the demo double-serves as a smoke test of the supervisor path.
- Shipped `README_background_email.md` (245 lines): launchd `.plist`, systemd `.service`, and cron snippets (each invoking the `@`-handle), env-var SMTP config (`FASTSENSE_SMTP_SERVER`/`FROM_ADDR`/`RECIPIENT`) + optional `setpref('Internet', ...)` auth with a never-commit-secrets warning, a dry-run↔real-email toggle table, heartbeat grep/awk recipe, multi-Companion note, and troubleshooting.
- Hardened the notification path for open events (`EndTime=NaN`): `NotificationRule.fillTemplate` and `generateEventSnapshot` no longer throw, so live/background email alerts work on events that are still in violation.

## Task Commits

Each task was committed atomically:

1. **Open-event NaN-guard fixes (deviation, surfaced completing Task 1)** - `5266234b` (fix)
2. **Task 1: setup function + wrapper** - `d144b115` (feat)
3. **Task 2: operator README** - `f816be70` (docs)

## Files Created/Modified
- `examples/05-events/example_background_email_monitor_setup.m` — top-level function file: 2 sensors (temperature + pressure) with simple H thresholds, MockDataSources, one catch-all `NotificationRule`, `NotificationService` wired via the `'NotificationService'` NV-pair (Plan 01); `DryRun=true` unless `FASTSENSE_SMTP_SERVER` is set; binds a shared `EventStore` to both MonitorTags so the pipeline harvests event deltas.
- `examples/05-events/example_background_email_monitor.m` — thin wrapper script (no embedded setup-function def): bootstraps `install.m`, calls the runner with `MaxRuntimeSec=8`, prints a post-run summary (status / NotificationCount / DryRun).
- `examples/05-events/README_background_email.md` — operator-facing supervision + SMTP doc.
- `libs/EventDetection/NotificationRule.m` — `fillTemplate` now renders `{endTime}` as `(open)` and `{duration}` as `(ongoing)` for open events via the new private static `formatTimeOrOpen_`; closed-event formatting unchanged.
- `libs/EventDetection/generateEventSnapshot.m` — clamps open-event `EndTime` to the last sample (mirrors `LiveEventPipeline.sensorDataForEvent_`) and guards the `xlim` call against degenerate/non-increasing windows.

## Decisions Made
- **Top-level function file for the setup** (the revision-1 blocker fix): a `function_handle` passed across `matlab -batch` invocations requires the function to be a top-level `.m` file on the path. Verified: `which example_background_email_monitor_setup` resolves to the file and `@example_background_email_monitor_setup` creates a valid handle after `install`.
- **Shared `EventStore` wired into each `MonitorTag`** (deviation, see below): the proven Tag-path pipeline pattern (`tests/test_live_event_pipeline_tag.m:make_live_tag_fixture`) sets `monitor.EventStore` explicitly. `LiveEventPipeline.processMonitorTag_` reads `preStore = monitor.EventStore` to harvest the per-tick event delta; without this wiring the monitors have no sink, zero events are harvested, and the notify path never fires.
- **Fix the open-event bug in the library, not the demo:** rather than tuning the demo so events always close before notify, the NaN guards were added to `NotificationRule`/`generateEventSnapshot` because the bug aborts every open-event notification for all callers — a correctness defect in the feature this phase ships.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1/3 - Bug/Blocking] Wired a shared `EventStore` into each `MonitorTag`**
- **Found during:** Task 1 (setup function authoring + smoke test)
- **Issue:** The plan's verbatim setup content set only the pipeline's `'EventFile'`, never `monitor.EventStore`. `LiveEventPipeline.processMonitorTag_` harvests new events from `monitor.EventStore` (`preStore = monitor.EventStore`, line 409); with `monitor.EventStore = []` (falling back to an empty `TagRegistry.getEventStore()`), zero events are harvested, `allNewEvents` stays empty, and the notify path is never exercised — defeating the demo's purpose ("here's it working").
- **Fix:** Construct one `EventStore(storeFile)` and assign it to both `tempHi.EventStore` and `presHi.EventStore`, reusing the same `storeFile` as the pipeline's `'EventFile'`. Matches the proven Tag-path fixture.
- **Files modified:** examples/05-events/example_background_email_monitor_setup.m
- **Verification:** MATLAB run shows `[PIPELINE] Cycle 1: 35 new events` and `NotificationCount=36`; without the wiring the cycle reported 0 events.
- **Committed in:** `d144b115` (Task 1 commit)

**2. [Rule 1/2 - Bug/Missing Critical] Open events (NaN EndTime) aborted notifications + snapshots**
- **Found during:** Task 1 (full end-to-end demo run)
- **Issue:** A fast-firing pipeline (2s interval, 4s violation duration) produces events that are still open (`EndTime=NaN`) when `notify()` fires. (a) `NotificationRule.fillTemplate` called `datestr(NaN)` for `{endTime}` → threw "Date number out of range" (MATLAB) / "monthlength(nan)" (Octave), so `notify` logged `[PIPELINE WARNING] Notification failed` and skipped the alert. (b) `generateEventSnapshot` propagated NaN through `evDur → padAmount → xMin/xMax`, so `xlim([NaN NaN])` threw "Limits must be a 2-element vector of increasing numeric values" → `[NOTIFY WARNING] Snapshot failed`.
- **Fix:** (a) `fillTemplate` renders open `{endTime}` as `(open)` and NaN `{duration}` as `(ongoing)` via a new private static `formatTimeOrOpen_`. (b) `generateEventSnapshot` clamps open-event `EndTime` to `X(end)` (mirrors `sensorDataForEvent_`) and guards `xlim` against non-increasing/non-finite limits with a 1-minute fallback window.
- **Files modified:** libs/EventDetection/NotificationRule.m, libs/EventDetection/generateEventSnapshot.m
- **Verification:** Demo re-run is warning-free; `NotificationCount` rose 35→36 (the previously-failing open-event alert now succeeds); snapshot PNGs (detail + context) are written. Regression: `test_notification_rule` 5/5, `test_notification_service` 7/7, `test_event_snapshot` 5/5 PASS under Octave.
- **Committed in:** `5266234b` (separate fix commit, completed as part of Task 1)

---

**Total deviations:** 2 auto-fixed (1 blocking event-harvest wiring, 1 bug/missing-critical open-event handling)
**Impact on plan:** Both fixes are required for the demo to fulfil its stated purpose (prove the wiring with real events + emails) and for live/background email alerts to work on open events. The plan's file structure, the top-level-function split, the env-var contract, the `'NotificationService'` NV-pair usage, and the README content are exactly as specified. No scope creep — the library fixes are minimal NaN guards at the template/snapshot boundary.

## Issues Encountered
- **MATLAB MCP tools unavailable this session.** Per the runtime note, fell back to MISS_HIT `mh_lint`/`mh_style` (all touched files report "everything seems fine") and the MATLAB R2025b CLI (`matlab -batch`, the demo's documented runtime) for the end-to-end run, plus Octave (`FASTSENSE_SKIP_BUILD=1`) for the isolated NaN-guard checks and regression tests.
- **Octave cannot run the full demo:** `LiveEventPipeline.start()` uses `timer`, which Octave does not implement. This is an inherent constraint of the live pipeline (and the existing `example_live_pipeline.m`), not a defect in these files — the demo's runtime is MATLAB (where `timer` works), exactly as the plan's verification and README document. The runner and setup function are otherwise Octave-clean (lint passes; `which`/`@`-handle resolution and `fillTemplate`/snapshot fixes all verified under Octave).
- **Octave EventStore re-tick quirk:** under Octave, driving multiple manual `runCycle()` calls hit "can't perform indexing operations for object type" on the classdef-in-MAT save/load path — a pre-existing Octave-only `EventStore` serialization limitation, out of scope (does not occur on MATLAB; the MATLAB run harvested across cycles cleanly).

## Run-time Evidence (MATLAB R2025b, warning-free)

```
[SETUP] FASTSENSE_SMTP_SERVER not set -- using DryRun=true (no email sent).
[SETUP] Pipeline built with 2 monitors, store=/private/tmp/.../fastsense_background_email_demo_events.mat
[PIPELINE] Cycle 1: 35 new events
[PIPELINE] Started (interval=2s, cluster=0)
[BG] runBackgroundMonitoring started: PollSec=2  MaxRuntimeSec=8
[BG] 19:49:14  events=35  emails=35  uptime=2.0s
[PIPELINE] Cycle 3: 1 new events
[BG] 19:49:19  events=36  emails=36  uptime=6.6s
[BG] 19:49:21  events=36  emails=36  uptime=8.7s
[BG] MaxRuntimeSec reached -- exiting heartbeat loop.
[BG] runBackgroundMonitoring exit: status=running, runtime=8.7s
[PIPELINE] Stopped
=== Demo summary ===
Pipeline status:           stopped
Total events in store:     36
NotificationCount:         36
DryRun?                    1
```

`which example_background_email_monitor_setup` → resolves to `examples/05-events/example_background_email_monitor_setup.m` after `install`; `@example_background_email_monitor_setup` → `function_handle` (blocker-fix proof).

## User Setup Required
None for the dry-run demo. For real email: set `FASTSENSE_SMTP_SERVER` (+ optionally `FASTSENSE_FROM_ADDR`, `FASTSENSE_RECIPIENT`) and, if the relay needs auth, configure `setpref('Internet', ...)` — all documented in `examples/05-events/README_background_email.md`. Never commit SMTP credentials.

## Next Phase Readiness
- Plan 04 (tests: `tests/test_live_event_pipeline_notif_sensor_data.m` + `tests/test_run_background_monitoring.m`) is unblocked: the runner, the setup function, and the open-event-safe notification path are all in place and verified.
- The open-event NaN guards make the notification path robust for any live/background deployment, not just the demo.

## Self-Check: PASSED

- Created files verified present: `example_background_email_monitor_setup.m`, `example_background_email_monitor.m`, `README_background_email.md`, `1039-03-SUMMARY.md`.
- Commits verified in git log: `5266234b` (fix), `d144b115` (feat), `f816be70` (docs).

---
*Phase: 1039-background-monitoring-with-email-notifications*
*Completed: 2026-05-29*
