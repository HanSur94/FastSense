# Phase 1039: Background monitoring with email notifications - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous variant)

<domain>
## Phase Boundary

Wire `NotificationService` into `LiveEventPipeline` as a first-class collaborator, fix the broken `sensorData=struct()` bug in `runCycle`'s notify path, and ship a headless entry function (`runBackgroundMonitoring`) plus a runnable example + README so users can run unattended monitoring with email alerts under launchd/systemd/cron.

**In scope:**
- `LiveEventPipeline` constructor accepts `'NotificationService'` NV-pair (default `[]`).
- `LiveEventPipeline.runCycle` passes real per-event sensor data to `notify()` (resolved from `MonitorTargets`).
- New `libs/EventDetection/runBackgroundMonitoring.m` entry function — takes a setup function handle, starts the pipeline, blocks until stop signal or `MaxRuntimeSec` cap.
- New example `examples/05-events/example_background_email_monitor.m` and accompanying README with SMTP + launchd/systemd/cron snippets.
- Tests covering snapshot-data integrity and the runner entry's start/stop lifecycle.

**Out of scope:**
- Cluster-mode "only lock-holder emails" gating (Phase 1032's single-source guarantee already de-duplicates events at the source; cluster-mode notification gating deferred to a future phase if needed).
- Auto-restart watchdog inside the runner (launchd/systemd/cron handle process supervision).
- Shell-script wrappers per OS (matlab -batch invocation is documented in the README instead).
- New SMTP transport implementation (rely on MATLAB's built-in `sendmail` + `setpref('Internet', ...)`).

</domain>

<decisions>
## Implementation Decisions

### Constructor wiring
- `LiveEventPipeline` constructor gains `'NotificationService'` NV-pair, default `[]`.
- The current default `NotificationService('DryRun', true)` is removed — silent default is consistent with `OnEventStart` (which defaults to `[]`). Downstream `runCycle` already guards with `~isempty(obj.NotificationService)`, so the change is safe.
- Public property remains assignable post-construction for back-compat with existing examples.

### `runCycle` sensorData fix
- New private helper `sensorDataForEvent_(ev)` resolves `MonitorTargets(ev.Sensor)` → `monitor.Parent.getXY()` → slice to event window with padding from the matching rule's `ContextHours` (fallback to a default if no rule).
- Returns `struct('time', x, 'value', y)` matching the contract `generateEventSnapshot` expects.
- Defensive: if sensor key is not in `MonitorTargets` (shouldn't happen for events emitted by the pipeline), fall back to empty `struct()` and log a warning.

### Headless entry function
- `libs/EventDetection/runBackgroundMonitoring.m`: `runBackgroundMonitoring(setupFcn, varargin)`
  - `setupFcn` is a `function_handle` returning a configured `LiveEventPipeline`.
  - NV-pairs:
    - `'PollSec'` (default 60) — heartbeat interval to stdout (`[BG] tick OK, N events stored, M emails sent`).
    - `'MaxRuntimeSec'` (default 0 = infinite) — hard cap; enables deterministic testing.
  - Lifecycle: calls `pipeline.start()`, enters `while` loop printing heartbeats, calls `pipeline.stop()` on Ctrl-C / timeout / error.
- Designed for `matlab -batch "runBackgroundMonitoring(@my_setup_fcn)"` under launchd/systemd/cron supervision.

### Demo + README
- `examples/05-events/example_background_email_monitor.m`: setup function returning a configured pipeline.
  - 2 sensors (temperature + pressure) with simple H/L thresholds — tighter than `example_live_pipeline.m` so SMTP config is the focus, not the sensor setup.
  - `MockDataSource` for backlog + live cycles; same pattern as existing examples.
  - `NotificationService` constructed with `'DryRun', true` by default; comments show the SMTP-enabled config path (`SmtpServer`, `FromAddress`, `setpref('Internet', 'SMTP_Username', ...)` etc.).
  - One `NotificationRule` (default rule, catches everything) — simple and explainable.
- `examples/05-events/README_background_email.md`:
  - How to invoke via `matlab -batch`.
  - Launchd `.plist` snippet for macOS.
  - Systemd `.service` snippet for Linux.
  - Cron snippet (fallback).
  - SMTP config — env vars, MATLAB `setpref('Internet', ...)`, credential-handling notes (don't commit secrets).
  - How to toggle from dry-run to real email.

### Tests
- `tests/test_live_event_pipeline_notif_sensor_data.m` (function-based):
  - Builds a pipeline with a `MonitorTag` that fires a violation.
  - Wires a custom `NotificationService` subclass that captures `sensorData` arguments instead of sending email.
  - Asserts captured `sensorData.time` and `sensorData.value` are non-empty and cover the event window.
- `tests/test_run_background_monitoring.m`:
  - Builds a trivial pipeline with `MaxRuntimeSec=2`.
  - Calls `runBackgroundMonitoring(@setup)`; asserts it returns within 2.5s with `pipeline.Status == 'stopped'`.
- Optional suite-class equivalents (`tests/suite/TestLiveEventPipelineNotificationSensorData.m`, `TestRunBackgroundMonitoring.m`) following existing convention.

### Cluster-mode interaction
- No new gating. Phase 1032's per-tag `FileLock` already enforces single-source emission — exactly one event per violation lands in the event log regardless of how many Companions run. So exactly one `notify()` call fires per event.
- README notes the implication for users running multiple Companions: each Companion will email independently for events it observes. Operators wanting one alert per violation should run the background monitor on a single host (the natural use case).

</decisions>

<code_context>
## Existing Code Insights

### Reusable assets
- `libs/EventDetection/NotificationService.m` — already implements rule matching, snapshot generation, `sendmail()`, dry-run logging. No contract changes needed.
- `libs/EventDetection/NotificationRule.m` — already has `IncludeSnapshot`, `ContextHours`, `SnapshotSize`, `SnapshotPadding`, recipient/subject/message templating.
- `libs/EventDetection/generateEventSnapshot.m` — produces detail + context PNG attachments; takes `sensorData` struct with `.time` and `.value`.
- `libs/EventDetection/LiveEventPipeline.m` — already runs a MATLAB timer (`start()`/`stop()`), maintains `MonitorTargets`, calls `notify()` per event in `runCycle`.
- `libs/SensorThreshold/MonitorTag.m` — `Parent.getXY()` resolves sensor data; works transparently for sensor/composite/derived tags.

### Established patterns
- Examples under `examples/NN-topic/` with self-contained scripts that call `install.m` first.
- Tests use both function-based (`tests/test_*.m`) and class-based (`tests/suite/Test*.m`) styles; both are accepted.
- NV-pair option parsing via the local `parseOpts(defaults, varargin)` private helper.
- Stdout logging prefix `[ClassName]` or `[PIPELINE]` etc.
- Atomic-write via temp+rename for any shared writes (Phase 1029 contract).

### Integration points
- `LiveEventPipeline.runCycle` line 228 (post-EventStore-write, pre-tick-end) — sensor-data resolution + notify loop hooks here.
- `LiveEventPipeline` constructor defaults block (line 70-80) — add `defaults.NotificationService = []`.
- `LiveEventPipeline` constructor assignment (line ~106) — replace auto-DryRun creation with `obj.NotificationService = opts.NotificationService`.
- `examples/05-events/` — drop the new example + README alongside `example_live_pipeline.m`.

</code_context>

<specifics>
## Specific Ideas

- Heartbeat format: `[BG] HH:MM:SS  events=N  emails=M  uptime=Ts` — single line, easy to grep in launchd/systemd journal.
- The runner returns the pipeline handle on graceful exit so callers (and tests) can introspect final state.
- SMTP config in the README emphasizes env-var-driven config (`FASTSENSE_SMTP_SERVER`, `FASTSENSE_SMTP_USER`, etc.) read in the setup function — keeps secrets out of the .m script.
- Demo's `setup` function reads env vars and falls back to `DryRun=true` if `FASTSENSE_SMTP_SERVER` is unset — clearly explains the toggle.

</specifics>

<deferred>
## Deferred Ideas

- Cluster-mode "only lock-holder emails" gating — defer to a follow-up phase if multi-Companion deployments find duplicate alerting in practice (Phase 1032's single-source guarantee makes this unlikely).
- Auto-restart watchdog inside the runner — out of scope; OS-level supervisors (launchd/systemd/cron) handle this better.
- Shell-script wrappers per OS — documented via README rather than shipped scripts to avoid OS-specific maintenance burden.
- Templating extensions for `NotificationRule` (e.g. Slack/webhook senders) — extension point exists via subclassing, no scope here.
- Email rate limiting / suppression — `NotificationRule.MaxCallsPerEvent` already exists; the demo uses defaults. Deeper rate-limit work deferred.

</deferred>
