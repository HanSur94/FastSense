---
phase: 1040-companion-notification-center
plan: 01
type: tdd
wave: 1
depends_on: []
files_modified:
  - tests/StubEventStore.m
  - libs/FastSenseCompanion/NotificationCenterPane.m
  - tests/test_notification_center_pane.m
autonomous: true
requirements: []
must_haves:
  truths:
    - "A StubEventStore handle can stand in for a real EventStore in tests (getEvents / numEvents / acknowledgeEvent)"
    - "Pure-logic helpers filter events to unacked, sort newest-first, diff by Id, and compute max severity + badge text — all without rendering any UI"
    - "The flat test test_notification_center_pane runs headlessly and passes"
  artifacts:
    - path: "tests/StubEventStore.m"
      provides: "Fake EventStore handle for pane tests (modeled on tests/CaptureNotificationService.m)"
      contains: "classdef StubEventStore < handle"
    - path: "libs/FastSenseCompanion/NotificationCenterPane.m"
      provides: "Pane class shell with static pure-logic helpers (no UI yet)"
      contains: "classdef NotificationCenterPane < handle"
    - path: "tests/test_notification_center_pane.m"
      provides: "Flat pure-logic test for unacked filter / sort / diff / badge"
      contains: "function test_notification_center_pane"
  key_links:
    - from: "tests/test_notification_center_pane.m"
      to: "NotificationCenterPane static helpers + StubEventStore"
      via: "direct function calls"
      pattern: "NotificationCenterPane\\.(filterUnacked_|maxSeverity_|diffIds_|badgeText_)"
---

<objective>
Lay the Wave-0 test foundation for the Companion Notification Center: a `StubEventStore`
test double and the *pure-logic* core of `NotificationCenterPane` (static helpers that
filter/sort/diff events and format the bell badge), covered by a flat headless test.

This is interface-first TDD: the pure logic is the contract every later task builds on.
No `uifigure` rendering happens in this plan — only data transforms that can be asserted
in milliseconds without a desktop.

Purpose: Unblock pane + integration verification (per 1040-VALIDATION.md Wave 0) and pin
the filtering/diffing/badge semantics with tests before any UI exists.
Output: `tests/StubEventStore.m`, the static-method shell of
`libs/FastSenseCompanion/NotificationCenterPane.m`, and `tests/test_notification_center_pane.m`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@.planning/phases/1040-companion-notification-center/1040-CONTEXT.md
@.planning/phases/1040-companion-notification-center/1040-RESEARCH.md
@.planning/phases/1040-companion-notification-center/1040-VALIDATION.md

<interfaces>
<!-- Verified against the live codebase 2026-06-02. Use these directly. -->

Event.m (libs/EventDetection/Event.m) — relevant public properties:
```matlab
ev.Id             % char: unique id (e.g. 'evt_3')
ev.SensorName     % char: tag/sensor key
ev.ThresholdLabel % char
ev.StartTime      % numeric datenum (sort key)
ev.EndTime        % numeric datenum (NaN if open)
ev.Severity       % numeric: 1=info, 2=warn, 3=alarm
ev.IsOpen         % logical: true while violation still active
ev.AckedAt        % numeric datenum; [] = UNACKED (the inbox filter key)
ev.AckedBy        % struct {user, host, epoch, comment}
ev.AckComment     % char
% Construct a test Event: Event(startTime, endTime, sensorName, thresholdLabel)
% Then set .Severity / .IsOpen / .Id / .AckedAt as needed (all public set).
% NOTE: ev.AckedAt may also be NaN in some persisted records; treat both
% isempty(AckedAt) and all(isnan(AckedAt)) as "unacked" (mirror Event.computeDisplayState L137).
```

EventStore.m public methods the stub must mimic (signatures verified):
```matlab
events = store.getEvents();                 % EventStore.m:97 — returns Event array
n      = store.numEvents();                  % EventStore.m:280
ack    = store.acknowledgeEvent(eventId, opts); % EventStore.m:337
%   opts struct, optional .comment (char); single-user throws
%   'EventStore:unknownEventId' if eventId not in events_.
%   In-memory effect: sets ev.AckedAt immediately on the matching Event handle.
```

tests/CaptureNotificationService.m — the established stub/double PATTERN to mirror
(subclass-of-handle, public capture props, methods that record args).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create StubEventStore test double</name>
  <read_first>
    - tests/CaptureNotificationService.m (the stub pattern to mirror — public capture props + recording methods)
    - libs/EventDetection/EventStore.m lines 97-103 (getEvents), 280-285 (numEvents), 337-438 (acknowledgeEvent in-memory mutation + unknownEventId throw)
    - libs/EventDetection/Event.m lines 35-66 (Severity/Id/IsOpen/AckedAt + constructor)
  </read_first>
  <files>tests/StubEventStore.m</files>
  <action>
    Create `tests/StubEventStore.m` — a `classdef StubEventStore < handle` test double that
    lets pane logic be tested without a real EventStore. Model the structure on
    `tests/CaptureNotificationService.m`. Required public surface:

    Properties (public, settable in tests):
    - `Events_      = Event.empty`  % configure in test setup
    - `AckedIds_    = {}`           % records each eventId passed to acknowledgeEvent (call order)
    - `ThrowOnAck_  = false`        % when true, acknowledgeEvent throws EventStore:unknownEventId
    - `ThrowOnGet_  = false`        % when true, getEvents throws (to exercise the stale path later)

    Methods:
    - `function evs = getEvents(obj)` — if `obj.ThrowOnGet_`, `error('EventStore:getEventsFailed','stub throw')`; else `evs = obj.Events_;`
    - `function n = numEvents(obj)` — `n = numel(obj.Events_);`
    - `function ack = acknowledgeEvent(obj, eventId, ~)` — if `obj.ThrowOnAck_`, `error('EventStore:unknownEventId','stub: not found')`. Otherwise record `obj.AckedIds_{end+1} = eventId;`, then mutate the matching in-memory Event (mirror real EventStore: loop `obj.Events_`, on `strcmp(obj.Events_(i).Id, eventId)` set `obj.Events_(i).AckedAt = now;` and `break`), and return `ack = struct('eventId', eventId, 'action', 'ack');`.

    Keep it Octave-tolerant in syntax (no MATLAB-only constructs) since flat tests may run on
    Octave; it only needs the `Event` class on path. Header comment block per CLAUDE.md
    (`%STUBEVENTSTORE ...` + usage example + `Phase 1040 Plan 01.`). MISS_HIT clean (≤160 cols, 4-space).
  </action>
  <verify>
    <automated>MISSING — verified together with Task 3 via test_notification_center_pane (this plan's Task 3 creates the test that constructs StubEventStore and asserts acknowledgeEvent records ids + mutates AckedAt)</automated>
  </verify>
  <acceptance_criteria>
    - `exist('tests/StubEventStore.m','file') == 2` (run from repo root)
    - `grep -n "classdef StubEventStore < handle" tests/StubEventStore.m` returns a match
    - `grep -nE "function (evs = getEvents|n = numEvents|ack = acknowledgeEvent)" tests/StubEventStore.m` returns exactly 3 matches
    - `grep -n "EventStore:unknownEventId" tests/StubEventStore.m` returns a match (the ThrowOnAck path)
    - `mh_style tests/StubEventStore.m` and `mh_lint tests/StubEventStore.m` report no findings
  </acceptance_criteria>
  <done>StubEventStore.m exists, subclasses handle, exposes getEvents/numEvents/acknowledgeEvent with configurable ThrowOnAck_/ThrowOnGet_, and mutates AckedAt on ack. MISS_HIT clean.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add NotificationCenterPane static pure-logic helpers (no UI)</name>
  <read_first>
    - libs/FastSenseCompanion/EventsLogPane.m (the sibling class layout to mirror — properties block, header doc, Listeners_ convention; you only add the classdef shell + static methods here)
    - libs/EventDetection/Event.m lines 125-151 (computeDisplayState — for the isempty(AckedAt) || all(isnan(AckedAt)) unacked test)
    - libs/FastSenseCompanion/EventGanttCanvas.m lines 285-298 (severityColor — referenced by name; do NOT duplicate the RGB)
    - .planning/phases/1040-companion-notification-center/1040-UI-SPEC.md "Interaction Contract" > "Bell Button States" (badge text + max-severity rules)
  </read_first>
  <behavior>
    - filterUnacked_([]) returns an empty Event array (no error).
    - Given 3 events with AckedAt = [], [], now: filterUnacked_ returns the 2 with empty AckedAt.
    - An event with AckedAt = NaN is treated as UNACKED (kept), matching Event.computeDisplayState L137.
    - sortNewestFirst_ on events with StartTime [10 30 20] returns them ordered [30 20 10].
    - maxSeverity_ over Severity [1 3 2] returns 3; over [] returns 0.
    - diffIds_({'a','b'}, {'a'}) returns true (new id 'b' appeared); diffIds_({'a'},{'a','b'}) returns true (set changed); diffIds_({'a','b'},{'b','a'}) returns false (same set, order-insensitive).
    - badgeText_(0, anyGlyph) returns the plain glyph; badgeText_(5, glyph) returns sprintf('%s (%d)', glyph, 5).
  </behavior>
  <files>libs/FastSenseCompanion/NotificationCenterPane.m</files>
  <action>
    Create `libs/FastSenseCompanion/NotificationCenterPane.m` with the class SHELL only —
    `classdef NotificationCenterPane < handle` mirroring `EventsLogPane.m`'s header/layout.
    In THIS task add ONLY the `events DetachRequested` block, the property block (declared
    but unused for now — copy the RESEARCH.md Pattern 2 property list: `IsAttached` SetAccess
    private logical=false; private `ThemeStruct_`, `hRoot_`, `hTable_`, `hSevDD_`, `hSearch_`,
    `hAckAllBtn_`, `hLastUpdateLbl_`, `hPopoutBtn_`, `Companion_`, `LastGoodEvents_ = Event.empty`,
    `LastIds_ = {}`, `Listeners_ = {}`, `IsStale_ = false`), and a `methods (Static)` block with
    these PURE helpers (no UI, no Event-store calls — operate on plain data so the flat test runs
    fast and Octave-tolerant):

    - `function evs = filterUnacked_(allEvents)` — guard `isempty(allEvents)` → `evs = Event.empty; return`. Build a logical mask: for each `ev`, unacked iff `isempty(ev.AckedAt) || (isnumeric(ev.AckedAt) && all(isnan(ev.AckedAt)))`. Return `allEvents(mask)`.
    - `function evs = sortNewestFirst_(events)` — if `numel(events) > 1`, `[~,ord] = sort([events.StartTime],'descend'); evs = events(ord);` else `evs = events`.
    - `function s = maxSeverity_(events)` — `if isempty(events); s = 0; else; s = max([events.Severity]); end`.
    - `function ids = idsOf_(events)` — `ids = arrayfun(@(e) e.Id, events, 'UniformOutput', false);` (cellstr); empty in → `{}`.
    - `function changed = diffIds_(newIds, oldIds)` — order-insensitive set compare: `changed = ~isequal(sort(newIds(:)), sort(oldIds(:)));` with cellstr guards so `{}` vs `{}` → false.
    - `function txt = badgeText_(count, glyph)` — `if count <= 0; txt = glyph; else; txt = sprintf('%s (%d)', glyph, count); end`.
    - `function rgb = badgeColor_(maxSev, theme)` — per UI-SPEC Bell Button States: `switch maxSev; case 3, rgb = theme.StatusAlarmColor; case 2, rgb = theme.StatusWarnColor; case {0,1}, rgb = theme.Accent; otherwise rgb = theme.Accent; end`. (Idle/zero-count recoloring to WidgetBorderColor is handled by the caller in Plan 03 — this helper returns the active-severity color.)

    Do NOT add `attach/detach/refresh/applyTheme` bodies yet — Plan 02 fills those. If MATLAB
    requires the abstract/public methods to exist for the classdef to parse, add empty stubs that
    `error('NotificationCenterPane:notYetImplemented', ...)` — but prefer leaving them out entirely
    so Plan 02 owns them cleanly. Header doc block + `See also EventsLogPane, EventStore, Event.`
    MISS_HIT clean.
  </action>
  <verify>
    <automated>MISSING — verified by Task 3's test_notification_center_pane (created next in this plan)</automated>
  </verify>
  <acceptance_criteria>
    - `exist('libs/FastSenseCompanion/NotificationCenterPane.m','file') == 2`
    - `grep -n "classdef NotificationCenterPane < handle" libs/FastSenseCompanion/NotificationCenterPane.m` matches
    - `grep -nE "function (evs = filterUnacked_|evs = sortNewestFirst_|s = maxSeverity_|ids = idsOf_|changed = diffIds_|txt = badgeText_|rgb = badgeColor_)" libs/FastSenseCompanion/NotificationCenterPane.m` returns exactly 7 matches
    - `grep -n "DetachRequested" libs/FastSenseCompanion/NotificationCenterPane.m` matches (events block present)
    - `mcp__matlab__check_matlab_code` on the file reports no errors
    - `mh_style` + `mh_lint` on the file report no findings
  </acceptance_criteria>
  <done>NotificationCenterPane.m parses with the events block, full property declaration, and 7 static pure-logic helpers. No UI code yet. Code Analyzer + MISS_HIT clean.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Write flat pure-logic test test_notification_center_pane</name>
  <read_first>
    - tests/test_companion_filter_tags.m (flat-test structure: function + local add_*_path() that calls install(); how a flat test asserts and prints)
    - tests/StubEventStore.m (created in Task 1)
    - libs/FastSenseCompanion/NotificationCenterPane.m (the static helpers from Task 2)
  </read_first>
  <behavior>
    - StubEventStore round-trip: configure 3 Events, acknowledgeEvent('evt_2') records 'evt_2' in AckedIds_ and sets that Event's AckedAt non-empty.
    - filterUnacked_ + sortNewestFirst_ pipeline returns unacked events newest-first.
    - diffIds_ returns false for a reordered identical set, true when an id is added or removed.
    - badgeText_ / badgeColor_ map count + max-severity to the documented label/color.
  </behavior>
  <files>tests/test_notification_center_pane.m</files>
  <action>
    Create `tests/test_notification_center_pane.m` as a flat function-based test (Octave-tolerant;
    pure logic only — NO uifigure). Follow `tests/test_companion_filter_tags.m`: top function
    `test_notification_center_pane()` that calls a local `add_companion_path()` (addpath repo root +
    `install()`), then runs assertions and prints `fprintf('    All %d tests passed.\n', n)` on success.

    Cover (use `Event` constructor `Event(startTime, endTime, sensorName, thresholdLabel)` then set
    `.Id`, `.Severity`, `.IsOpen`, `.AckedAt`):
    1. Build events e1(Id='evt_1',Sev=3,Start=30,AckedAt=[]), e2(Id='evt_2',Sev=2,Start=20,AckedAt=[]), e3(Id='evt_3',Sev=1,Start=10,AckedAt=now). `unacked = NotificationCenterPane.filterUnacked_([e1 e2 e3])` → assert numel==2 and ids are {'evt_1','evt_2'}.
    2. `sorted = NotificationCenterPane.sortNewestFirst_(unacked)` → assert `sorted(1).Id` is 'evt_1' (Start=30 newest).
    3. Make e4 with AckedAt = NaN → assert filterUnacked_ keeps it (NaN treated as unacked).
    4. `NotificationCenterPane.maxSeverity_([e1 e2])` == 3; `maxSeverity_(Event.empty)` == 0.
    5. `diffIds_({'a','b'},{'b','a'})` == false; `diffIds_({'a','b'},{'a'})` == true; `diffIds_({},{})` == false.
    6. `badgeText_(0,'B')` == 'B'; `badgeText_(5,'B')` == 'B (5)'.
    7. `theme = CompanionTheme.get('dark'); assert isequal(NotificationCenterPane.badgeColor_(3,theme), theme.StatusAlarmColor)` and `badgeColor_(2,theme)==theme.StatusWarnColor` and `badgeColor_(1,theme)==theme.Accent`.
    8. StubEventStore round-trip: `s = StubEventStore; s.Events_ = [e1 e2 e3]; s.acknowledgeEvent('evt_2', struct('comment',''));` → assert `isequal(s.AckedIds_,{'evt_2'})` and `~isempty(s.Events_(2).AckedAt)`. Then `s.ThrowOnAck_ = true;` and assert acknowledgeEvent now throws with identifier 'EventStore:unknownEventId' (wrap in try/catch + verify `ME.identifier`).

    Each assertion via a local `check(cond, msg)` that errors on false. Count tests; print pass line.
    MISS_HIT clean (≤160 cols).
  </action>
  <verify>
    <automated>mcp__matlab__evaluate_matlab_code: addpath(pwd); install(); test_notification_center_pane  (expect "All N tests passed." with no error)</automated>
  </verify>
  <acceptance_criteria>
    - `exist('tests/test_notification_center_pane.m','file') == 2`
    - `grep -n "function test_notification_center_pane" tests/test_notification_center_pane.m` matches
    - `grep -nE "NotificationCenterPane\.(filterUnacked_|sortNewestFirst_|maxSeverity_|diffIds_|badgeText_|badgeColor_)" tests/test_notification_center_pane.m` returns ≥ 6 matches
    - `grep -n "EventStore:unknownEventId" tests/test_notification_center_pane.m` matches (ack-throw assertion)
    - Running `test_notification_center_pane` via `mcp__matlab__evaluate_matlab_code` prints "All N tests passed." (N ≥ 8) and raises no error
    - `mh_style` + `mh_lint` clean on the file
  </acceptance_criteria>
  <done>test_notification_center_pane runs green headlessly, exercising StubEventStore round-trip + all 7 static helpers. MISS_HIT clean.</done>
</task>

</tasks>

<verification>
- Run via matlab MCP `evaluate_matlab_code`: `addpath(pwd); install(); test_notification_center_pane` → "All N tests passed."
- `mcp__matlab__check_matlab_code` clean on `libs/FastSenseCompanion/NotificationCenterPane.m`.
- `mh_style` + `mh_lint` clean on all three new files.
- Confirm NO uifigure/uitable/uibutton call appears in this plan's files (pure logic only):
  `grep -nE "uifigure|uitable|uibutton|uigridlayout|uidropdown" libs/FastSenseCompanion/NotificationCenterPane.m tests/test_notification_center_pane.m tests/StubEventStore.m` returns NO matches.
</verification>

<success_criteria>
- StubEventStore.m, NotificationCenterPane.m (shell + 7 static helpers), test_notification_center_pane.m all exist and MISS_HIT-clean.
- Flat test green; all helper semantics (unacked filter incl. NaN, newest-first sort, order-insensitive id diff, badge text/color) pinned by assertions.
- No UI primitives used anywhere in this plan (foundation is pure logic only).
- Honors 1040-CONTEXT.md deferred items (no NotificationService, sounds, snooze, grouping, per-user seen-state appear).
</success_criteria>

<output>
After completion, create `.planning/phases/1040-companion-notification-center/1040-01-SUMMARY.md`.
</output>
