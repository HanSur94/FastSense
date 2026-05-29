---
phase: 1039-background-monitoring-with-email-notifications
plan: 01
subsystem: api
tags: [matlab, event-detection, notifications, live-pipeline, snapshots, email]

# Dependency graph
requires:
  - phase: 1032-single-source-events
    provides: "MonitorTag.emitEvent_ single-emission seam + Event.SensorName carrier (Parent.Key)"
provides:
  - "LiveEventPipeline constructor 'NotificationService' NV-pair (default [])"
  - "Private helper sensorDataForEvent_(ev) resolving real per-event sensor data from MonitorTargets(ev.SensorName).Parent.getXY()"
  - "runCycle notify loop passes populated sensorData (.X/.Y/.thresholdValue/.thresholdDirection) instead of struct()"
  - "Public API surface: pipeline = LiveEventPipeline(..., 'NotificationService', notif) AND pipeline.NotificationService = notif (both work)"
affects: [1039-02-runBackgroundMonitoring, 1039-03-example-readme, 1039-04-tests]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Silent-default NV-pair (default []) consistent with OnEventStart; downstream ~isempty guard makes [] safe"
    - "Defensive private resolver: warn-and-return-empty rather than throw, since the caller is try/catch-wrapped"
    - "Field-name contract reconciliation: code contract (.X/.Y/.thresholdValue/.thresholdDirection) wins over informal CONTEXT.md wording (.time/.value)"

key-files:
  created: []
  modified:
    - "libs/EventDetection/LiveEventPipeline.m"

key-decisions:
  - "Used real generateEventSnapshot contract field names .X/.Y/.thresholdValue/.thresholdDirection (per plan <rationale>), NOT CONTEXT.md's informal .time/.value"
  - "Keyed MonitorTargets lookup by ev.SensorName (== Parent.Key per Event.m), NOT a nonexistent ev.Sensor"
  - "ctxHours/padFrac resolved from best-matching NotificationRule via findBestRule(ev); fallback 2.0h / 0.1 when no service or no rule matches"
  - "Open events (EndTime=NaN) use X(end) as evEnd for the slice window"

patterns-established:
  - "Snapshot-data resolver pattern: slice parent.getXY() to [evStart - ctxHours/24 - pad, evEnd + pad] keyed by SensorName"

requirements-completed: []

# Metrics
duration: 5min
completed: 2026-05-29
---

# Phase 1039 Plan 01: LiveEventPipeline NotificationService wiring + sensorData fix Summary

**LiveEventPipeline now accepts a 'NotificationService' NV-pair (default []) and feeds real per-event sensor data (.X/.Y/.thresholdValue/.thresholdDirection sliced from the monitor's parent) to notify(), fixing the empty-snapshot bug caused by notify(ev, struct()).**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-29T17:19:10Z
- **Completed:** 2026-05-29T17:23:54Z
- **Tasks:** 3
- **Files modified:** 1 (`libs/EventDetection/LiveEventPipeline.m`)

## Accomplishments
- Added `defaults.NotificationService = []` and replaced the auto-created `NotificationService('DryRun', true)` with `obj.NotificationService = opts.NotificationService` (D-01). Public property stays assignable post-construction.
- Added the private helper `sensorDataForEvent_(ev)` (D-03) that resolves real sensor data from `MonitorTargets(ev.SensorName).Parent.getXY()`, slices it to the event window with `ContextHours`/`SnapshotPadding` padding from the best-matching `NotificationRule`, and produces the exact `.X/.Y/.thresholdValue/.thresholdDirection` struct `generateEventSnapshot` consumes.
- Fixed the `runCycle` notify loop to call `notify(ev, sd)` with the resolved data instead of `notify(ev, struct())` (D-02). Verified end-to-end: notify received a 211-point populated `sensorData` covering the event window.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add NotificationService NV-pair to constructor and remove auto-DryRun fallback** - `0bca97ce` (feat)
2. **Task 2: Add sensorDataForEvent_ private helper** - `c0f99483` (feat)
3. **Task 3: Replace struct() with sensorDataForEvent_(ev) in runCycle notify loop** - `f215fc1b` (fix)

## Files Created/Modified
- `libs/EventDetection/LiveEventPipeline.m` - Three edits: (1) `defaults.NotificationService = []` in the constructor defaults block (line 78); (2) replaced auto-DryRun assignment with `obj.NotificationService = opts.NotificationService` (line ~110); (3) new private `sensorDataForEvent_` helper at the top of the `methods (Access = private)` block (line 251); (4) runCycle notify loop now computes `sd = obj.sensorDataForEvent_(ev)` and calls `notify(ev, sd)` (line ~232).

## Decisions Made
- **Field-name contract (D-03 reconciliation):** Implemented the REAL contract `.X/.Y/.thresholdValue/.thresholdDirection` keyed by `ev.SensorName` (per `generateEventSnapshot.m` and `Event.m`), per the plan's `<rationale>` block. CONTEXT.md's informal `.time/.value`/`ev.Sensor` wording was deliberately NOT followed — doing so would re-break the snapshot pipeline.
- **Silent default (D-01):** `NotificationService` defaults to `[]` (no auto-DryRun), consistent with `OnEventStart`. The pre-existing `~isempty(obj.NotificationService)` guard above the notify loop makes `[]` safe; the existing `examples/05-events/example_live_pipeline.m:175` assigns its own service post-construction, so back-compat is preserved.
- **ctxHours/padding source:** Resolved from `obj.NotificationService.findBestRule(ev)` when available (`ContextHours`/`SnapshotPadding`), falling back to `2.0` hours / `0.1` padding (NotificationRule defaults) when no service is wired or no rule matches.

## Deviations from Plan

None - plan executed exactly as written. The three edits (defaults line, assignment line, helper, runCycle call) match the plan's `<action>` blocks verbatim.

## Issues Encountered

- **MATLAB MCP tools unavailable this session:** The `mcp__matlab__*` tools described in CLAUDE.md were not exposed in this session. Static analysis and smoke-tests were instead run via the project's MISS_HIT linter (`mh_lint`/`mh_style`, both "everything seems fine") and via the **Octave 7+** CLI (`octave --no-gui`, the project's fully-supported alternative runtime) with `FASTSENSE_SKIP_BUILD=1`. This is a verification-tooling substitution, not a code change; `mh_lint`/`mh_style` are exactly the static checkers the project's CI uses.
- **Octave handle-equality (`==`) in the plan's Task 1 verify command:** Octave's handle classes do not define `eq`, so the plan's literal `p2.NotificationService == ns` assertion errored. Verification was re-expressed Octave-portably via shared-state handle mutation (mutate `ns.Enabled`, observe through `p2.NotificationService`) — a stricter check that proves the SAME handle was stored, not merely an equal one. Production code was not affected.
- **Private-method access from a test subclass:** Octave (matching MATLAB `private` semantics) blocks subclass access to `Access = private` methods, so `sensorDataForEvent_` could not be probed via a subclass. This confirms the method is correctly private. Its functional behavior was instead proven end-to-end through the real `runCycle` notify path (Task 3 capture harness), which is the more faithful integration test.

## Verification Results

- **MISS_HIT static analysis** on `libs/EventDetection/LiveEventPipeline.m`: `mh_lint` and `mh_style` both report "everything seems fine".
- **Frontmatter contract greps:** `defaults.NotificationService` → 1; `obj.NotificationService = opts.NotificationService` → 1; `NotificationService('DryRun', true)` → 0; `function sd = sensorDataForEvent_` → 1; `sd = obj.sensorDataForEvent_(ev)` → 1; `notify(ev, struct())` → 0; `sd.time`/`sd.value` → 0.
- **Regression tests (Octave):** `tests/test_live_event_pipeline_tag.m` → 3/3 PASS; `tests/test_notification_service.m` → 7/7 PASS.
- **End-to-end bug-fix proof (Octave):** Built a deterministic sensor with a single closed threshold violation, wired a capturing `NotificationService` subclass, ran one `runCycle`. The notify callback received a populated `sensorData` (211 points, X-window covering the event span) with all four contract fields — directly demonstrating the `struct()` bug is fixed.

## Next Phase Readiness

- **Plan 02** (`runBackgroundMonitoring.m`) and downstream plans can rely on the API surface: `pipeline = LiveEventPipeline(..., 'NotificationService', notif)` and `pipeline.NotificationService = notif` (both work). With no NV-pair, `pipeline.NotificationService` is `[]` (no emails, no auto-DryRun).
- **Plan 04** (tests) can reproduce the end-to-end capture pattern used here (custom `NotificationService` subclass overriding `notify` to capture `sensorData`) for `tests/test_live_event_pipeline_notif_sensor_data.m`.
- **Note for verifier / Plan 04:** A pre-existing Octave limitation (`save` cannot serialize classdef objects, surfaced in `EventStore.save()` during the live tick) emits a warning under Octave but does not affect event flow or notification. This is out of scope for Plan 01 (pre-existing, not caused by these edits) and is logged here for awareness; it does not appear under MATLAB.

## Self-Check: PASSED

- FOUND: `libs/EventDetection/LiveEventPipeline.m`
- FOUND: `.planning/phases/1039-background-monitoring-with-email-notifications/1039-01-SUMMARY.md`
- FOUND commit: `0bca97ce` (Task 1)
- FOUND commit: `c0f99483` (Task 2)
- FOUND commit: `f215fc1b` (Task 3)

---
*Phase: 1039-background-monitoring-with-email-notifications*
*Completed: 2026-05-29*
