---
phase: 260529-rxf
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/EventDetection/EmailTransport.m
  - libs/EventDetection/NotificationService.m
  - libs/EventDetection/LiveEventPipeline.m
  - examples/05-events/example_live_pipeline.m
  - examples/05-events/smoke_email_send.m
  - tests/test_email_transport.m
  - tests/suite/TestEmailTransport.m
  - tests/test_notification_service.m
autonomous: true
requirements: [RXF-01]

must_haves:
  truths:
    - "A non-dry-run NotificationService injected into LiveEventPipeline sends a real email per matched event via JavaMail sendmail"
    - "On Octave (no sendmail) the send path logs-and-skips and NEVER errors"
    - "SMTP STARTTLS auth on port 587 is the default and verified-manual case; 'none' and 'ssl' modes set the documented mail.smtp.* property map"
    - "Per-(sensor,threshold) cooldown (default 5 min, 0 disables) suppresses repeat sends/dry-run-logs within the window and allows them after expiry"
    - "Live pipeline ticks pass real sensorData (X/Y + thresholdValue + thresholdDirection) so IncludeSnapshot rules attach PNGs in live mode"
    - "LiveEventPipeline still defaults to NotificationService('DryRun', true) — existing scripts behave identically"
  artifacts:
    - path: "libs/EventDetection/EmailTransport.m"
      provides: "SMTP mechanics + pure buildMailProps mapping + Octave guard"
      contains: "classdef EmailTransport"
    - path: "libs/EventDetection/NotificationService.m"
      provides: "Transport delegation + cooldown + SuppressedCount"
      contains: "CooldownMinutes"
    - path: "libs/EventDetection/LiveEventPipeline.m"
      provides: "real sensorData built in processMonitorTag_ and passed to notify"
      contains: "thresholdDirection"
    - path: "examples/05-events/smoke_email_send.m"
      provides: "Manual one-shot real-send smoke test using env-var creds"
      contains: "FASTSENSE_SMTP_PASSWORD"
    - path: "tests/test_email_transport.m"
      provides: "Function-based unit tests for prop-map mapping + Octave-guard no-throw"
      contains: "buildMailProps"
  key_links:
    - from: "libs/EventDetection/NotificationService.m"
      to: "libs/EventDetection/EmailTransport.m"
      via: "sendEmail delegates to transport.send(...)"
      pattern: "\\.send\\("
    - from: "libs/EventDetection/LiveEventPipeline.m"
      to: "libs/EventDetection/NotificationService.m"
      via: "runCycle passes real sensorData to notify(ev, sensorData)"
      pattern: "notify\\(ev,"
---

<objective>
Finish and wire the existing event-notification stack so `LiveEventPipeline` sends REAL per-event emails during background monitoring, while staying byte-for-byte backward compatible (default still dry-run) and Octave-safe (log-and-skip, never error).

The plumbing already exists end-to-end EXCEPT three gaps: (1) `NotificationService.sendEmail` only sets `SMTP_Server`+`E_mail` prefs — no port/auth/TLS; (2) there is no send cooldown, so a flapping threshold would email on every tick; (3) the live path calls `notify(ev, struct())` with empty sensorData, so `IncludeSnapshot` rules never attach PNGs in live mode.

Approach B (LOCKED, pre-approved — DO NOT re-discuss): extract a dedicated `EmailTransport` unit that owns SMTP mechanics and exposes a PURE `buildMailProps` mapping for CI; `NotificationService` delegates to it (mockable for tests) and gains a per-(sensor,threshold) cooldown; `LiveEventPipeline` builds and forwards real `sensorData`.

Purpose: Engineers running background `LiveEventPipeline` monitoring get actual alert emails (with snapshot PNGs) instead of console-only dry-run output, without touching any existing dry-run-by-default behavior.
Output: New `EmailTransport.m` + `smoke_email_send.m`; edited `NotificationService.m`, `LiveEventPipeline.m`, `example_live_pipeline.m`; new `test_email_transport.m` / `TestEmailTransport.m`; extended `test_notification_service.m`. All affected tests green.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/STATE.md

# Files being edited / patterns to mirror
@libs/EventDetection/NotificationService.m
@libs/EventDetection/NotificationRule.m
@libs/EventDetection/LiveEventPipeline.m
@libs/EventDetection/generateEventSnapshot.m
@libs/EventDetection/Event.m
@tests/test_notification_service.m
@tests/test_live_event_pipeline_tag.m
@examples/05-events/example_live_pipeline.m

<interfaces>
<!-- Confirmed contracts the executor needs — DO NOT re-explore the codebase to rediscover these. -->

generateEventSnapshot sensorData contract (libs/EventDetection/generateEventSnapshot.m:34-37):
  sensorData = struct('X', <vector>, 'Y', <vector>, ...
                      'thresholdValue', <numeric>, ...
                      'thresholdDirection', <'upper'|'lower'>)
  (thresholdDirection is compared via strcmp(thDir,'upper') — must be 'upper' or 'lower'.)

Event fields (libs/EventDetection/Event.m, SetAccess=private):
  SensorName (char), ThresholdLabel (char), ThresholdValue (numeric),
  Direction ('upper'|'lower'), PeakValue, StartTime, EndTime, Duration, ...

LiveEventPipeline carrier semantics (proven by tests/test_live_event_pipeline_tag.m:60-62):
  In the MonitorTag path, emitted event.SensorName == parent.Key and
  event.ThresholdLabel == monitor.Key. So the cooldown key
  'SensorName|ThresholdLabel' is stable per (parent,monitor) pair.

processMonitorTag_ ALREADY snapshots the parent grid (LiveEventPipeline.m:347-352):
  if ismethod(monitor.Parent, 'getXY'); [oldX, oldY] = monitor.Parent.getXY(); end
  newX = result.X; newY = result.Y;
  fullX = [oldX(:).', newX(:).']; fullY = [oldY(:).', newY(:).'];
  -> reuse fullX/fullY for sensorData.X/.Y.

NotificationService.notify current control flow (libs/EventDetection/NotificationService.m:67-107):
  guard ~Enabled -> return (no count, no stamp)
  rule = findBestRule(event); if empty -> return (no count, no stamp)
  build subject/message; generate snapshots if rule.IncludeSnapshot;
  if ~DryRun -> sendEmail(...) else -> fprintf dry-run line;
  NotificationCount++ at the very end.

NotificationService public props ALREADY declared but NOT wired through inputParser
  (lines 4-17): SmtpPort=25, SmtpUser='', SmtpPassword='' exist as properties but
  the constructor's inputParser only parses Enabled/DryRun/SnapshotDir/SmtpServer/FromAddress.

Existing tests construct a FRESH NotificationService per test, so cooldown maps start
  empty and the FIRST notify in each test always passes the window. test_disabled asserts
  NotificationCount==0; test_default_rule expects empty rule. Cooldown stamping MUST occur
  only AFTER the Enabled + non-empty-rule guards so these stay green.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create EmailTransport with pure buildMailProps + Octave guard, and its unit tests</name>
  <files>libs/EventDetection/EmailTransport.m, tests/test_email_transport.m, tests/suite/TestEmailTransport.m</files>
  <action>
Create `libs/EventDetection/EmailTransport.m` — a `handle` class with single responsibility: SMTP mechanics. Follow CLAUDE.md conventions (full class header comment with description/usage/properties/methods/See-also; `%METHODNAME` header on every public method; PascalCase properties; namespaced `EmailTransport:*` error IDs; <=160-char lines; 4-space tabs).

Public properties (with inline defaults), all settable via constructor NV-pairs through an inputParser:
  - `Server` (char, default '')
  - `Port` (numeric, default 587)
  - `User` (char, default '')
  - `Password` (char, default '')
  - `PasswordEnv` (char, default '') — env-var NAME (e.g. 'FASTSENSE_SMTP_PASSWORD'); when `Password` is empty and `PasswordEnv` is non-empty, resolve via `getenv(PasswordEnv)` at send time
  - `SecurityMode` (char, default 'starttls') — validate ∈ {'none','starttls','ssl'}; on invalid value throw `error('EmailTransport:invalidSecurityMode', ...)` listing the valid set
  - `From` (char, default 'fastsense@noreply.com')

Methods:
  1. Constructor `EmailTransport(varargin)` — inputParser parses all the above; validate SecurityMode (case-insensitive, store lower-cased). Throw `EmailTransport:invalidSecurityMode` on bad mode.
  2. PURE static method `props = buildMailProps(securityMode, port)` — returns a `containers.Map('KeyType','char','ValueType','char')` of the JavaMail `mail.smtp.*` properties for the given mode WITHOUT touching prefs or sending. This is the key CI testability seam. Mapping (all values stored as char):
       - common to every mode: `'mail.smtp.port'` -> `num2str(port)`
       - 'none'    : port only, NO auth keys.
       - 'starttls': add `'mail.smtp.auth'`='true', `'mail.smtp.starttls.enable'`='true'.
       - 'ssl'     : add `'mail.smtp.auth'`='true',
                     `'mail.smtp.socketFactory.class'`='javax.net.ssl.SSLSocketFactory',
                     `'mail.smtp.socketFactory.port'`=`num2str(port)`.
     Validate securityMode here too (reuse the same valid set / error id) so the pure mapping is self-defending.
  3. `send(obj, recipients, subject, body, attachments)` — performs the actual send:
       - OCTAVE GUARD FIRST: `if exist('sendmail','file') == 0` then
         `fprintf('[EmailTransport] sendmail unavailable (Octave?) — skipping send to %d recipient(s)\n', numel(cellstr(recipients)));`
         and `return;` (NO error). Use a robust recipient count that tolerates char or cellstr.
       - Resolve effective password: `pw = obj.Password; if isempty(pw) && ~isempty(obj.PasswordEnv); pw = getenv(obj.PasswordEnv); end`
       - Set prefs: `setpref('Internet','SMTP_Server', obj.Server)`, `setpref('Internet','E_mail', obj.From)`. For auth modes (starttls/ssl) also `setpref('Internet','SMTP_Username', obj.User)` and `setpref('Internet','SMTP_Password', pw)`.
       - Apply mail.smtp.* props onto the live JVM: `props = java.lang.System.getProperties;` then iterate `EmailTransport.buildMailProps(obj.SecurityMode, obj.Port)` keys and `props.setProperty(k, v)`.
       - Send: `if isempty(attachments); sendmail(recipients, subject, body); else; sendmail(recipients, subject, body, attachments); end`
     Wrap the JVM-props block so a missing/odd JVM doesn't hard-crash beyond MATLAB's own sendmail behavior — but do NOT swallow real send errors (NotificationService already try/catches sendEmail).

Add brief inline comments documenting WHY each prop is set (auth/STARTTLS/SSL semantics) per the CLAUDE.md comment convention.

Then create the tests (both styles, per repo convention — function-based `test_` + class-based `Test`):

`tests/test_email_transport.m` (function-based, mirror the structure of tests/test_notification_service.m — local `add_event_path()` helper that addpath's repoRoot + libs/EventDetection + libs/SensorThreshold + libs/FastSense then calls `install()`; a top driver that calls each sub-test and prints `test_email_transport: ALL PASSED`). Sub-tests (all PURE — no real send):
  - test_props_none: `m = EmailTransport.buildMailProps('none', 587);` assert `m('mail.smtp.port')` == '587' and `~isKey(m, 'mail.smtp.auth')` and `~isKey(m, 'mail.smtp.starttls.enable')`.
  - test_props_starttls: `m = EmailTransport.buildMailProps('starttls', 587);` assert `m('mail.smtp.auth')`=='true', `m('mail.smtp.starttls.enable')`=='true', `m('mail.smtp.port')`=='587', and `~isKey(m,'mail.smtp.socketFactory.class')`.
  - test_props_ssl: `m = EmailTransport.buildMailProps('ssl', 465);` assert `m('mail.smtp.auth')`=='true', `m('mail.smtp.socketFactory.class')`=='javax.net.ssl.SSLSocketFactory', `m('mail.smtp.socketFactory.port')`=='465', `m('mail.smtp.port')`=='465'.
  - test_invalid_mode: assert `EmailTransport('SecurityMode','bogus')` throws with identifier `EmailTransport:invalidSecurityMode` (use try/catch + check ME.identifier).
  - test_octave_guard_no_throw: construct `t = EmailTransport('Server','localhost','SecurityMode','none');` then call `t.send({'a@b.com'}, 'subj', 'body', {});` inside try/catch and assert NO error was raised (on MATLAB with sendmail present this may attempt a connection — to keep it deterministic in CI, scope the assertion to "does not throw a MATLAB error from our guard logic"; if a network/sendmail error surfaces, accept identifiers NOT starting with 'EmailTransport:' as environmental and still pass the no-throw-from-our-code intent). Prefer asserting the guard branch directly: this test's PRIMARY guarantee is that when `exist('sendmail','file')==0` the function returns cleanly — document that in a comment.

`tests/suite/TestEmailTransport.m` (class-based `matlab.unittest.TestCase`, mirror tests/suite/TestLiveEventPipelineTag.m header + `TestClassSetup`/`addPaths` calling addpath(repo)+install()+addpath suite). Test methods mirror the function-based assertions using `testCase.verifyEqual` / `testCase.verifyError(@() EmailTransport('SecurityMode','bogus'), 'EmailTransport:invalidSecurityMode')` / `verifyFalse(isKey(...))`. Keep it focused (the prop-map mapping for all three modes + invalid-mode error + a no-throw guard check).

Honor CLAUDE.md MATLAB-MCP note: use `mcp__matlab__check_matlab_code` on each new .m file before running, then `mcp__matlab__run_matlab_test_file` to verify.
  </action>
  <verify>
    <automated>mcp__matlab__check_matlab_code on libs/EventDetection/EmailTransport.m (no errors), then mcp__matlab__run_matlab_test_file tests/test_email_transport.m → "test_email_transport: ALL PASSED"</automated>
  </verify>
  <done>
EmailTransport.m exists with PascalCase NV-pair props (Server/Port/User/Password/PasswordEnv/SecurityMode/From), a PURE static `buildMailProps(securityMode, port)` returning the documented mail.smtp.* containers.Map per mode, a `send(...)` with the Octave `exist('sendmail','file')==0` log-and-skip-no-error guard, and namespaced `EmailTransport:*` errors with full header comments. `tests/test_email_transport.m` and `tests/suite/TestEmailTransport.m` assert the none/starttls/ssl prop mapping, invalid-mode error, and the guard no-throw path — all green.
  </done>
</task>

<task type="auto">
  <name>Task 2: Delegate NotificationService.sendEmail to EmailTransport, add SecurityMode wiring + per-(sensor,threshold) cooldown, extend tests with a mock transport</name>
  <files>libs/EventDetection/NotificationService.m, tests/test_notification_service.m</files>
  <action>
Edit `libs/EventDetection/NotificationService.m` (preserve all existing behavior; surgical additions). Maintain CLAUDE.md conventions.

(a) Wire real SMTP + new properties through the constructor inputParser. Add NV-pairs for the already-declared-but-unwired props plus the new ones:
    - `SmtpPort` (default 587 — note: bump the property default from 25 to 587 to match the STARTTLS-default decision; keep the property declared)
    - `SmtpUser` (default '')
    - `SmtpPassword` (default '')
    - `PasswordEnv` (NEW property, char, default '')
    - `SecurityMode` (NEW property, char, default 'starttls')
    - `CooldownMinutes` (NEW property, numeric, default 5; 0 disables cooldown)
    - `Transport` (NEW property, default []) — injectable EmailTransport (or mock) for DI/testing; constructor NV-pair `'Transport'` lets tests pass a mock. When empty, the real transport is lazily built on first real send.
    Add `SuppressedCount` (NEW public property, default 0) to mirror `NotificationCount`.
    Parse each new NV-pair with appropriate validators (e.g. `@isnumeric` for SmtpPort/CooldownMinutes, `@ischar` for char fields; `Transport` no validator or accept any). Assign Results to properties. Keep the existing SnapshotDir tempdir fallback.

(b) Add a private cooldown map: in the `properties (Access = private)` block add `lastSentByKey_ = []` (lazily initialized to `containers.Map('KeyType','char','ValueType','double')` in the constructor or on first use). Add a small private helper `key = cooldownKey_(~, event)` returning `sprintf('%s|%s', event.SensorName, event.ThresholdLabel)`.

(c) Cooldown logic in `notify(obj, event, sensorData)` — insert AFTER the `~Enabled` guard and AFTER `rule = findBestRule(event); if isempty(rule); return; end` (so disabled / no-rule paths do NOT stamp and stay count-0, keeping test_disabled + test_default_rule green), and BEFORE building subject/snapshots:
    - If `obj.CooldownMinutes > 0`:
        `k = obj.cooldownKey_(event);`
        `nowDatenum = now;`  %#ok<TNOW1>  (datenum; convert minutes via /1440)
        if `isKey(obj.lastSentByKey_, k)` and `(nowDatenum - obj.lastSentByKey_(k)) * 1440 < obj.CooldownMinutes`:
            `obj.SuppressedCount = obj.SuppressedCount + 1; return;`  % suppress BOTH real send AND dry-run log
    - This means cooldown is checked before snapshot generation (don't waste work on a suppressed event) and applies identically to DryRun and real-send paths (LOCKED requirement: dry-run honors cooldown).
    - After a successful proceed (i.e., reaching the send/dry-run block), stamp `obj.lastSentByKey_(k) = nowDatenum;` (stamp on the proceed path, regardless of DryRun). Keep `NotificationCount` incrementing only on the proceed path exactly as today.

(d) Replace the private `sendEmail` body to DELEGATE to the transport instead of calling `sendmail` + setting only two prefs:
    - Lazily build the transport if `isempty(obj.Transport)`:
        `obj.Transport = EmailTransport('Server', obj.SmtpServer, 'Port', obj.SmtpPort, 'User', obj.SmtpUser, 'Password', obj.SmtpPassword, 'PasswordEnv', obj.PasswordEnv, 'SecurityMode', obj.SecurityMode, 'From', obj.FromAddress);`
    - Then `obj.Transport.send(recipients, subject, message, attachments);`
    - Remove the now-obsolete `smtpConfigured_`/setpref-only logic (EmailTransport owns prefs now). The DI seam: because `Transport` is settable via constructor NV-pair, tests inject a mock object whose `send(...)` records its args.

(e) Extend `tests/test_notification_service.m` (KEEP all existing sub-tests passing; add new ones + register them in the top driver). Add a local mock transport. Since this is a function-based test file (no separate classdef allowed cleanly inline in Octave function files), implement the mock as a tiny `classdef` in `tests/suite/` named `MockEmailTransport.m` (a `handle` with public props `Calls = {}` capturing `{recipients, subject, body, attachments}` and a `send(obj, r, s, b, a)` that appends to `Calls`). Add it to the suite dir and addpath it in `add_event_path()` (append `addpath(fullfile(repoRoot,'tests','suite'))`). New sub-tests:
    - test_transport_delegation: build `mock = MockEmailTransport();` `ns = NotificationService('Transport', mock, 'CooldownMinutes', 0);` set a default rule with IncludeSnapshot=false and Recipients {{'a@b.com'}}, subject template; `notify(ev, sd)`; assert `numel(mock.Calls)==1` and the recorded recipients/subject/body match what the rule produced (recipients forwarded, subject == filled template). This proves recipients/subject/body forwarded correctly to the transport.
    - test_cooldown_suppresses_within_window: `ns = NotificationService('Transport', mock2, 'CooldownMinutes', 5)` with IncludeSnapshot=false; notify the SAME (sensor,threshold) twice back-to-back; assert second is suppressed: `mock2.Calls` length stays 1, `ns.SuppressedCount==1`, `ns.NotificationCount==1`.
    - test_cooldown_allows_after_expiry: with `CooldownMinutes`, simulate expiry by directly back-dating the stamp. Easiest deterministic approach: set `CooldownMinutes` to a tiny value AND manipulate the private map is not accessible — instead expose via behavior: construct with `CooldownMinutes`, do first notify, then to simulate elapsed time, construct a SECOND service is not it. PREFERRED deterministic method: add the back-date by making the cooldown comparison use `now`; in the test, set a very small `CooldownMinutes` (e.g. 1/600 ≈ 0.1s) — NO, timing-flaky. Instead: assert expiry semantics by setting `CooldownMinutes = 0`-equivalent boundary is disable, not expiry. To test EXPIRY deterministically WITHOUT a private setter, add a Hidden test-only setter following the repo's DI-seam precedent (STATE.md "1028 DI-seam pattern"): add `methods (Hidden) function setLastSentForTesting_(obj, event, datenumVal)` that writes `obj.lastSentByKey_(obj.cooldownKey_(event)) = datenumVal;`. Then test: notify once (Calls==1), back-date the stamp via `ns.setLastSentForTesting_(ev, now - 10/1440)` (10 min ago, > 5 min window), notify again, assert second send went through (`mock.Calls`==2, `SuppressedCount` unchanged from before this second notify). Document this Hidden setter as a test seam in its header comment.
    - test_suppressed_count_increments: covered by the within-window test; ensure an explicit assert on `SuppressedCount`.
    Keep the existing tests (test_constructor/test_add_rule/test_rule_matching_priority/test_notify_dry_run/test_default_rule/test_disabled/test_snapshot_generation) UNCHANGED and still called. Note: existing dry-run/snapshot tests construct fresh services with default `CooldownMinutes=5` but only notify ONCE each, so the first notify always proceeds — they stay green.

Run via MATLAB MCP: `mcp__matlab__check_matlab_code` on edited NotificationService.m + new MockEmailTransport.m, then `mcp__matlab__run_matlab_test_file tests/test_notification_service.m`.
  </action>
  <verify>
    <automated>mcp__matlab__check_matlab_code on libs/EventDetection/NotificationService.m + tests/suite/MockEmailTransport.m (no errors), then mcp__matlab__run_matlab_test_file tests/test_notification_service.m → "test_notification_service: ALL PASSED" (all original + new sub-tests)</automated>
  </verify>
  <done>
NotificationService wires SmtpPort(default 587)/SmtpUser/SmtpPassword/PasswordEnv/SecurityMode(default 'starttls')/CooldownMinutes(default 5)/Transport through the constructor; `sendEmail` delegates to `Transport.send(...)` (lazily building a real EmailTransport when none injected); `notify` enforces per-`'SensorName|ThresholdLabel'` cooldown (suppressing both real-send AND dry-run within the window, incrementing public `SuppressedCount`, stamping on proceed) placed AFTER the Enabled+rule guards. test_notification_service.m extended with a `MockEmailTransport` DI seam asserting recipients/subject/body forwarding, within-window suppression + `SuppressedCount`, and post-expiry allowance (via a Hidden `setLastSentForTesting_` seam) — all original + new sub-tests green.
  </done>
</task>

<task type="auto">
  <name>Task 3: Wire real sensorData through LiveEventPipeline live ticks; add guarded real-send example block + manual smoke script</name>
  <files>libs/EventDetection/LiveEventPipeline.m, examples/05-events/example_live_pipeline.m, examples/05-events/smoke_email_send.m</files>
  <action>
(a) Edit `libs/EventDetection/LiveEventPipeline.m` so live ticks pass REAL sensorData to notifications (so IncludeSnapshot rules attach PNGs in live mode). Keep the `NotificationService('DryRun', true)` default in the constructor (line ~106) UNTOUCHED — backward-compat is LOCKED.

  - Change `processMonitorTag_` signature to also RETURN the per-tick sensorData keyed by event, alongside `newEvents`/`gotData`. Simplest robust shape: `[newEvents, gotData, sensorData] = processMonitorTag_(obj, key)` where `sensorData` is a struct built from the SAME `fullX`/`fullY` already computed at lines ~347-356, plus the monitor's threshold value/direction. Build it right after `fullX/fullY` are formed and the events are harvested:
        `sensorData = struct('X', fullX, 'Y', fullY, 'thresholdValue', NaN, 'thresholdDirection', 'upper');`
    Then, when `newEvents` is non-empty, populate `thresholdValue`/`thresholdDirection` from the FIRST new event (they share the monitor): `sensorData.thresholdValue = newEvents(1).ThresholdValue; sensorData.thresholdDirection = newEvents(1).Direction;`. This matches the `generateEventSnapshot` contract exactly (`X`,`Y`,`thresholdValue`,`thresholdDirection` with direction ∈ {'upper','lower'}). When there are no new events, `sensorData` is harmless and unused.
    NOTE: there are TWO early `return;` statements in `processMonitorTag_` (no-datasource and no-change) plus the cluster-mode contention `return;`. Initialize `sensorData = struct('X', [], 'Y', [], 'thresholdValue', NaN, 'thresholdDirection', 'upper');` at the TOP alongside `newEvents = []; gotData = false;` so every return path yields a well-formed struct. Preserve the Pitfall Y ordering and the cluster-mode lock block exactly as-is.

  - In `runCycle`, change the per-monitor call site (line ~199) to capture sensorData and stash it so it can be paired with the events for that monitor. Because `allNewEvents` is a flat concatenation across monitors, the cleanest correct wiring is: pair events with their sensorData as they are produced. Implement by accumulating into a parallel cell array — e.g. maintain `allSensorData = {}` and, for each monitor that returns N new events, append N copies of that monitor's `sensorData` (or store one struct per monitor and an index). Concretely:
        `[newEvents, gotData, sensorData] = obj.processMonitorTag_(key);`
        `... existing allNewEvents concatenation ...`
        if `~isempty(newEvents)`, append `repmat({sensorData}, 1, numel(newEvents))` to `allSensorData`.
    Then in the notifications loop (lines ~228-237) replace `obj.NotificationService.notify(ev, struct())` with the paired data:
        `sd = struct(); if numel(allSensorData) >= i; sd = allSensorData{i}; end`
        `obj.NotificationService.notify(ev, sd);`
    This guarantees each event is notified with ITS monitor's real X/Y/threshold, so IncludeSnapshot rules render correct PNGs. Default dry-run service ignores the richer struct harmlessly (it only generates snapshots when a rule sets IncludeSnapshot=true, which the default pipeline service never has rules for).
    Keep all existing `try/catch` + `fprintf` diagnostics. Update the `processMonitorTag_` docstring to note the third return value.

  - IMPORTANT regression guard: `tests/test_live_event_pipeline_tag.m` calls `processMonitorTag_` only indirectly via `runCycle`, but its sibling suite `TestLiveEventPipelineTag.m` may call patterns that assume the 2-output signature. Search for direct `processMonitorTag_(` call sites (`grep -rn "processMonitorTag_" libs tests`) and confirm only `runCycle` calls it; if any test calls it directly with two outputs, MATLAB tolerates requesting fewer outputs than returned, so a 3rd output is backward-safe. Do NOT change the existing test files in this task.

(b) Edit `examples/05-events/example_live_pipeline.m` — KEEP the runnable demo in dry-run (the existing `notif = NotificationService('DryRun', true, ...)` at line ~144 stays as the active path). Add a clearly COMMENTED real-send config block (so the offline demo still runs without sending) showing how to enable real emails, e.g. immediately after the dry-run construction, a commented block:
        `% --- REAL EMAIL SENDING (commented out — uncomment + fill in your SMTP details) ---`
        `% notif = NotificationService( ...`
        `%     'DryRun', false, 'SnapshotDir', snapshotDir, ...`
        `%     'SmtpServer', 'smtp.example.com', 'SmtpPort', 587, ...`
        `%     'SmtpUser', 'alerts@example.com', 'PasswordEnv', 'FASTSENSE_SMTP_PASSWORD', ...`
        `%     'SecurityMode', 'starttls', 'FromAddress', 'alerts@example.com', ...`
        `%     'CooldownMinutes', 5);`
        `% (then add your rules with IncludeSnapshot=true and set pipeline.NotificationService = notif;)`
    Add a one-line note that the runnable demo stays dry-run on purpose so the example never sends mail in CI / offline. Do not change any executable line of the demo's behavior.

(c) Create `examples/05-events/smoke_email_send.m` — a documented MANUAL smoke test (NOT run in CI). Header comment must state: "MANUAL smoke test — sends ONE real email. Requires a reachable SMTP server and the FASTSENSE_SMTP_PASSWORD env var. NOT part of the automated suite; run by hand: `run('examples/05-events/smoke_email_send.m')`." The script:
    - `run(fullfile(...,'install.m'))` to set the path (mirror example_live_pipeline.m's projectRoot pattern).
    - Read config from env with sensible documented fallbacks: `server = getenv('FASTSENSE_SMTP_SERVER');`, `user = getenv('FASTSENSE_SMTP_USER');`, `from = getenv('FASTSENSE_SMTP_FROM');`, `to = getenv('FASTSENSE_SMTP_TO');` and `pwEnv = 'FASTSENSE_SMTP_PASSWORD';`. If `server`/`user`/`to` are empty, print a clear instruction block listing the required env vars and `return` (don't error).
    - Build a transport directly: `t = EmailTransport('Server', server, 'Port', 587, 'User', user, 'PasswordEnv', pwEnv, 'SecurityMode', 'starttls', 'From', from);`
    - Send one mail: `t.send({to}, '[FastSense] smoke test', sprintf('EmailTransport smoke test sent %s', datestr(now)), {});`  %#ok<TNOW1,DATST>
    - `fprintf('[smoke_email_send] Sent to %s via %s:587 (starttls). Check the inbox.\n', to, server);`
    Comment that on Octave this will log-and-skip (EmailTransport's guard) rather than send.

Run via MATLAB MCP: `mcp__matlab__check_matlab_code` on edited LiveEventPipeline.m + new smoke_email_send.m, then run the three affected test files to confirm the pipeline still detects/notifies correctly and nothing regressed.
  </action>
  <verify>
    <automated>mcp__matlab__check_matlab_code on libs/EventDetection/LiveEventPipeline.m + examples/05-events/smoke_email_send.m (no errors), then mcp__matlab__run_matlab_test_file on each of tests/test_email_transport.m, tests/test_notification_service.m, tests/test_live_event_pipeline_tag.m → all three report ALL PASSED / all tests passed</automated>
  </verify>
  <done>
`processMonitorTag_` returns a well-formed `sensorData` struct (`X`,`Y`,`thresholdValue`,`thresholdDirection`) on every return path, built from the existing fullX/fullY and the first new event's ThresholdValue/Direction; `runCycle` pairs each event with its monitor's sensorData and calls `notify(ev, sd)` (no more `struct()`), so IncludeSnapshot rules attach PNGs in live mode. The `NotificationService('DryRun', true)` constructor default is unchanged (backward-compat preserved). `example_live_pipeline.m` keeps its runnable dry-run path and gains a commented real-send config block. `examples/05-events/smoke_email_send.m` exists as a documented MANUAL one-shot real-send using env-var creds (FASTSENSE_SMTP_* ; STARTTLS:587), gracefully instructing-and-returning when env vars are unset. tests/test_email_transport.m, tests/test_notification_service.m, and tests/test_live_event_pipeline_tag.m all pass.
  </done>
</task>

</tasks>

<verification>
Affected automated tests (run via MATLAB MCP `run_matlab_test_file` — the live session routes to local MATLAB):
- `tests/test_email_transport.m` — prop-map mapping (none/starttls/ssl) + invalid-mode error + Octave-guard no-throw.
- `tests/suite/TestEmailTransport.m` — class-based mirror of the above.
- `tests/test_notification_service.m` — all original sub-tests STILL green + new transport-delegation, cooldown-suppress, cooldown-expiry, SuppressedCount sub-tests.
- `tests/test_live_event_pipeline_tag.m` — MonitorTag path still emits events and honors Pitfall Y ordering with the new 3-output `processMonitorTag_`.

Static analysis: `mcp__matlab__check_matlab_code` clean on every new/edited .m file (proxy for MISS_HIT). Honor CLAUDE.md style: <=160-char lines, 4-space tabs, namespaced `EmailTransport:*` error IDs, full class/method header comments.

Manual-only (NOT CI): real SMTP delivery verified by running `examples/05-events/smoke_email_send.m` with FASTSENSE_SMTP_* env vars set against the user's own server (STARTTLS:587). This is the single human verification step; everything else is automated.

Backward-compat checks (implicit in the above): LiveEventPipeline constructor still creates `NotificationService('DryRun', true)`; existing notification + pipeline tests unchanged and green.
</verification>

<success_criteria>
- `libs/EventDetection/EmailTransport.m` exists: NV-pair config (Server/Port=587/User/Password/PasswordEnv/SecurityMode='starttls'/From), PURE static `buildMailProps(securityMode, port)` returning the documented mail.smtp.* map per mode, `send(...)` with Octave `exist('sendmail','file')==0` log-and-skip-never-error guard, namespaced `EmailTransport:*` errors, full header comments.
- `NotificationService` delegates `sendEmail` to `EmailTransport.send`, accepts an injected `Transport` (mock seam), wires SmtpPort/SmtpUser/SmtpPassword/PasswordEnv/SecurityMode, and enforces per-(sensor,threshold) `CooldownMinutes` (default 5; 0 disables) suppressing BOTH real-send and dry-run within the window with a public `SuppressedCount`.
- `LiveEventPipeline.runCycle` passes REAL per-event sensorData (X/Y/thresholdValue/thresholdDirection) to `notify`, and still defaults to `NotificationService('DryRun', true)`.
- `example_live_pipeline.m` stays runnable in dry-run with an added commented real-send block; `smoke_email_send.m` exists as a documented manual real-send.
- All three affected test files pass; `check_matlab_code` clean on all touched files. Manual SMTP delivery confirmed via smoke script (out of CI).
</success_criteria>

<output>
After completion, create `.planning/quick/260529-rxf-real-per-event-email-alerts-for-backgrou/260529-rxf-SUMMARY.md`
</output>
