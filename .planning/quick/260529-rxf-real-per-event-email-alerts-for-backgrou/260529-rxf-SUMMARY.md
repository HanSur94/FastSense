---
phase: 260529-rxf
plan: "01"
subsystem: EventDetection
tags: [email, notifications, smtp, cooldown, live-pipeline]
dependency-graph:
  requires: []
  provides: [real-smtp-send, per-event-cooldown, live-sensordata-notifications]
  affects: [LibsEventDetection, TestsEventDetection, ExamplesEvents]
tech-stack:
  added: [EmailTransport]
  patterns: [DI-seam, injectable-transport, hidden-test-seam, Octave-guard]
key-files:
  created:
    - libs/EventDetection/EmailTransport.m
    - tests/test_email_transport.m
    - tests/suite/TestEmailTransport.m
    - tests/suite/MockEmailTransport.m
    - examples/05-events/smoke_email_send.m
  modified:
    - libs/EventDetection/NotificationService.m
    - libs/EventDetection/LiveEventPipeline.m
    - examples/05-events/example_live_pipeline.m
decisions:
  - "EmailTransport owns all SMTP mechanics (props + sendmail call); NotificationService delegates via injectable Transport property"
  - "CooldownMinutes default=5; cooldown suppresses both real-send and dry-run; stamping is post-guard so disabled/no-rule paths never stamp"
  - "Hidden setLastSentForTesting_ seam follows STATE.md DI-seam pattern for deterministic cooldown expiry tests"
  - "LiveEventPipeline default NotificationService('DryRun',true) preserved unchanged for backward-compat"
metrics:
  duration: "~7 minutes"
  completed: "2026-05-29"
  tasks: 3
  files_changed: 8
---

# Phase 260529-rxf Plan 01: Real Per-Event Email Alerts Summary

Real SMTP email delivery via injected EmailTransport in NotificationService, with per-(sensor,threshold) cooldown and live sensorData forwarding in LiveEventPipeline.

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Create EmailTransport with pure buildMailProps + Octave guard + unit tests | `203da7a6` | `EmailTransport.m`, `test_email_transport.m`, `TestEmailTransport.m` |
| 2 | Delegate NotificationService.sendEmail to EmailTransport; add cooldown + mock transport tests | `2ac68876` | `NotificationService.m`, `MockEmailTransport.m`, `test_notification_service.m` |
| 3 | Wire real sensorData through LiveEventPipeline live ticks; update example; add smoke script | `341bab24` | `LiveEventPipeline.m`, `example_live_pipeline.m`, `smoke_email_send.m` |

## What Was Built

### Task 1 — EmailTransport

`libs/EventDetection/EmailTransport.m` — new `handle` class:

- **Public NV-pair config:** `Server`/`Port`(587)/`User`/`Password`/`PasswordEnv`/`SecurityMode`('starttls')/`From`
- **PURE static `buildMailProps(mode, port)`:** returns `containers.Map` of `mail.smtp.*` properties for `none`/`starttls`/`ssl` without any side-effects (key CI testability seam)
- **`send(recipients, subject, body, attachments)`:** Octave guard (`exist('sendmail','file')==0` → log + return, never error); resolves password from `PasswordEnv` env-var; sets MATLAB Internet prefs; applies JVM props for TLS/SSL; delegates to MATLAB `sendmail`
- **`EmailTransport:invalidSecurityMode`** on unrecognised mode
- Full CLAUDE.md header comments, namespaced error IDs, ≤160-char lines

Tests:
- `tests/test_email_transport.m`: function-based (prop-map none/starttls/ssl, invalid-mode error, octave-guard no-throw)
- `tests/suite/TestEmailTransport.m`: class-based mirror with `verifyEqual`/`verifyError`/`verifyFalse`

### Task 2 — NotificationService

`libs/EventDetection/NotificationService.m` surgical additions:

- **New constructor NV-pairs wired:** `SmtpPort`(587), `SmtpUser`, `SmtpPassword`, `PasswordEnv`, `SecurityMode`('starttls'), `CooldownMinutes`(5), `Transport`([])
- **New public properties:** `PasswordEnv`, `SecurityMode`, `CooldownMinutes`, `Transport`, `SuppressedCount`
- **`sendEmail_` delegates to `Transport.send(...)`:** lazily builds real `EmailTransport` when `Transport` is empty; DI seam accepts injected mock via constructor `'Transport'` NV-pair
- **Per-(SensorName|ThresholdLabel) cooldown in `notify()`:** suppresses both real-send and dry-run within window; `SuppressedCount++` on suppress; stamps AFTER Enabled+rule guards; `lastSentByKey_` is a `containers.Map` char→double initialised in constructor
- **Hidden `setLastSentForTesting_(event, datenumVal)` seam** following STATE.md "1028 DI-seam pattern" for deterministic expiry testing
- All existing tests (test_constructor/test_add_rule/test_rule_matching_priority/test_notify_dry_run/test_default_rule/test_disabled/test_snapshot_generation) preserved unchanged

New tests in `tests/test_notification_service.m`:
- `test_transport_delegation`: verifies recipients/subject/body forwarded to `MockEmailTransport.send`
- `test_cooldown_suppresses_within_window`: back-to-back notify of same (sensor,threshold) → second suppressed; mock.Calls==1, SuppressedCount==1, NotificationCount==1
- `test_cooldown_allows_after_expiry`: uses `setLastSentForTesting_` to back-date stamp 10 min; second notify goes through; mock.Calls==2

`tests/suite/MockEmailTransport.m`: new test double with `Calls` cell array recording `{recipients, subject, body, attachments}`.

### Task 3 — LiveEventPipeline + Examples

`libs/EventDetection/LiveEventPipeline.m`:
- `processMonitorTag_` gains 3rd return value `sensorData` (struct `X`/`Y`/`thresholdValue`/`thresholdDirection`); initialised as empty well-formed struct at top (all early-return paths yield valid output)
- `sensorData` built from `fullX`/`fullY` (same accumulated grid used for `parent.updateData`) and then populated with `newEvents(1).ThresholdValue`/`Direction` after event harvest
- `runCycle` accumulates `allSensorData` cell array (one entry per event) via `repmat({sensorData}, 1, numel(newEvents))`; notification loop passes `allSensorData{i}` as `sd` to `notify(ev, sd)` instead of `struct()`
- `NotificationService('DryRun', true)` constructor default on line ~106 is **unchanged** (backward-compat)

`examples/05-events/example_live_pipeline.m`:
- Runnable path stays dry-run; added clearly-commented real-send config block showing `SmtpServer`/`SmtpPort`/`PasswordEnv`/`SecurityMode`/`CooldownMinutes` wiring

`examples/05-events/smoke_email_send.m`:
- Manual one-shot SMTP smoke test; reads `FASTSENSE_SMTP_SERVER`/`USER`/`FROM`/`TO` from env; `FASTSENSE_SMTP_PASSWORD` resolved at send time via `PasswordEnv`; prints clear instructions and returns when vars unset; Octave-safe comment

## Deviations from Plan

None — plan executed exactly as written.

## Verification Handoff

MATLAB test execution is **deferred to the orchestrator** (no `mcp__matlab__*` access in executor). The orchestrator must run the following and confirm all pass:

1. **`tests/test_email_transport.m`** — expects: `test_email_transport: ALL PASSED` (5 sub-tests)
2. **`tests/suite/TestEmailTransport.m`** — expects: 5/5 tests passed
3. **`tests/test_notification_service.m`** — expects: `test_notification_service: ALL PASSED` (10 sub-tests: 7 original + 3 new)
4. **`tests/test_live_event_pipeline_tag.m`** — expects: `All 3 live_event_pipeline_tag tests passed.` (no regression from 3-output `processMonitorTag_`)

### Notes for orchestrator verification focus

- **test_notify_dry_run** and **test_snapshot_generation**: these construct `NotificationService()` with default `CooldownMinutes=5` and only call `notify` ONCE, so the cooldown window is never triggered — should be green.
- **test_disabled**: `~Enabled` guard fires before cooldown; `NotificationCount` stays 0, `SuppressedCount` stays 0.
- **test_cooldown_allows_after_expiry**: uses `setLastSentForTesting_` (Hidden method) — verify MATLAB does not block Hidden method calls from test scripts (it shouldn't; Hidden is only advisory in function-based test files, not enforced like private).
- **`processMonitorTag_` 3-output**: MATLAB tolerates requesting 2 outputs from a function that returns 3 (caller requests fewer than declared nargout). The `test_live_event_pipeline_tag.m` file calls it only indirectly via `runCycle`, so no direct-call concern.

### Manual-only verification (not CI)

Run `examples/05-events/smoke_email_send.m` with `FASTSENSE_SMTP_*` env vars set against a real SMTP server (STARTTLS:587) to confirm end-to-end real email delivery.

## Known Stubs

None. All feature paths are fully wired:
- `EmailTransport.buildMailProps` returns real JVM property maps (not placeholders)
- `NotificationService.sendEmail_` lazily constructs a real `EmailTransport` when none injected
- `LiveEventPipeline.runCycle` passes real `sensorData` from `processMonitorTag_` to `notify`

## Self-Check: PASSED

All 9 files verified present. All 3 task commits verified in git log.

| Item | Status |
|------|--------|
| libs/EventDetection/EmailTransport.m | FOUND |
| libs/EventDetection/NotificationService.m | FOUND |
| libs/EventDetection/LiveEventPipeline.m | FOUND |
| tests/test_email_transport.m | FOUND |
| tests/suite/TestEmailTransport.m | FOUND |
| tests/suite/MockEmailTransport.m | FOUND |
| tests/test_notification_service.m | FOUND |
| examples/05-events/smoke_email_send.m | FOUND |
| examples/05-events/example_live_pipeline.m | FOUND |
| Commit 203da7a6 (Task 1) | FOUND |
| Commit 2ac68876 (Task 2) | FOUND |
| Commit 341bab24 (Task 3) | FOUND |
