---
phase: 1040-companion-notification-center
plan: 04
type: execute
wave: 4
depends_on: ["03"]
autonomous: false
files_modified:
  - tests/suite/TestFastSenseCompanion.m
requirements: []
must_haves:
  truths:
    - "TestFastSenseCompanion asserts the bell sits at toolbar col 8 and the gear moved to col 10"
    - "TestFastSenseCompanion asserts the bell toggles the 4th root column (320 ↔ 0)"
    - "TestFastSenseCompanion asserts the bell is disabled with no EventStore and reflects the unacked count when a store is present"
    - "TestFastSenseCompanion asserts onLiveTick_ refreshes the notification pane / updates the badge"
    - "The full suite is green and a human confirms the live pop-in + badge color under a real violation stream"
  artifacts:
    - path: "tests/suite/TestFastSenseCompanion.m"
      provides: "Updated toolbar-column assertions + new notification-center integration tests"
      contains: "CompanionBellBtn"
  key_links:
    - from: "tests/suite/TestFastSenseCompanion.m"
      to: "FastSenseCompanion bell + 4th column + onLiveTick_"
      via: "findall Tag CompanionBellBtn + getRootColumnWidthForTest_ + onLiveTickForTest_"
      pattern: "CompanionBellBtn"
---

<objective>
Lock the Companion integration with tests and a human visual check. Update the two existing
toolbar-column assertions that the bell shifts (Wiki stays col 7; gear moves col 9 → 10), add
integration tests for the bell + 4th-column toggle + enable/disable + badge + onLiveTick_ refresh,
run the full suite green, then pause for a human to confirm the live pop-in + badge color under a
real violation stream (the one manual-only item in 1040-VALIDATION.md).

Purpose: Prove the integration end-to-end and close the phase's validation contract.
Output: Updated `tests/suite/TestFastSenseCompanion.m` + a human-verified live demo.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/1040-companion-notification-center/1040-CONTEXT.md
@.planning/phases/1040-companion-notification-center/1040-RESEARCH.md
@.planning/phases/1040-companion-notification-center/1040-UI-SPEC.md
@.planning/phases/1040-companion-notification-center/1040-VALIDATION.md

<interfaces>
<!-- Verified against the live codebase 2026-06-02. -->

EXISTING toolbar-column assertions to UPDATE (tests/suite/TestFastSenseCompanion.m):
```matlab
% line 1252-1262 testToolbarHasWikiButton:
%   btn = findall(app.getFigForTest_(), 'Tag', 'CompanionWikiBtn');
%   verifyEqual(btn(1).Layout.Column, 7, ...)   ← Wiki STAYS at col 7 (bell goes to col 8). LEAVE 7.
% line 1265-1281 testToolbarGearMovedToColumn8:
%   loops toolbar buttons; verifyEqual(btns(k).Layout.Column, 9, ...)  ← gear NOW col 10.
%   CHANGE the literal 9 → 10 and update the diagnostic string. KEEP the method NAME
%   'testToolbarGearMovedToColumn8' (mis-named on purpose per STATE.md / RESEARCH Pitfall 1).
```

Companion test idioms (TestFastSenseCompanion.m):
  app = FastSenseCompanion();                         % no store → bell disabled
  es  = EventStore(storePath); app = FastSenseCompanion('EventStore', es);  % store → bell enabled
  app.getFigForTest_()                                 % the uifigure (line 1330)
  app.getRootColumnWidthForTest_()                     % {220,'1x',360,0|320} (added Plan 03 Task 1)
  app.onLiveTickForTest_()                             % drives onLiveTick_ without the timer (added Plan 03 Task 1)
  app.getEventStore()                                  % resolved store
  app.toggleNotificationCenter_()                      % show/hide col 4 (public-ish; callable in tests)
Headless guard: the suite already has the standard skip idiom for no-desktop runs — reuse it.

Event for fixtures: Event(startTime, endTime, sensorName, thresholdLabel); set .Severity/.IsOpen;
  es.append(ev). storePath via [tempname '.mat'].
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Update the two toolbar-column assertions for the bell shift</name>
  <read_first>
    - tests/suite/TestFastSenseCompanion.m lines 1250-1282 (testToolbarHasWikiButton + testToolbarGearMovedToColumn8 — the exact verifyEqual literals + diagnostic strings)
    - .planning/phases/1040-companion-notification-center/1040-RESEARCH.md Pitfall 1 (column-count mismatch; keep the method name, change only the literal)
    - .planning/STATE.md quick-task 260526-tcf entry (why the method name testToolbarGearMovedToColumn8 is intentionally kept)
  </read_first>
  <files>tests/suite/TestFastSenseCompanion.m</files>
  <action>
    `testToolbarHasWikiButton` (line ~1252-1262): LEAVE the Wiki column assertion at 7 (Wiki is
    unchanged; the bell takes the NEW col 8). Do NOT modify this test except, optionally, a one-word
    comment noting the bell now follows at col 8.

    `testToolbarGearMovedToColumn8` (line ~1265-1281): the gear moved from col 9 to col 10 (bell
    inserted at col 8 shifted spacer→9, gear→10). Change the `verifyEqual(btns(k).Layout.Column, 9, ...)`
    literal `9` → `10`, and update the diagnostic message string to read
    `'testToolbarGearMovedToColumn8: gear button should now sit in column 10'`. KEEP the method NAME
    `testToolbarGearMovedToColumn8` unchanged (intentionally mis-named per STATE.md 260526-tcf /
    RESEARCH Pitfall 1 — renaming is a separate task). MISS_HIT clean.
  </action>
  <verify>
    <automated>mcp__matlab__run_matlab_test_file: tests/suite/TestFastSenseCompanion.m (testToolbarHasWikiButton + testToolbarGearMovedToColumn8 both PASS; no other regressions)</automated>
  </verify>
  <acceptance_criteria>
    - `grep -n "testToolbarGearMovedToColumn8: gear button should now sit in column 10" tests/suite/TestFastSenseCompanion.m` matches
    - `grep -nE "verifyEqual\(btns\(k\).Layout.Column, 10," tests/suite/TestFastSenseCompanion.m` matches (gear now col 10)
    - `grep -n "testToolbarGearMovedToColumn8" tests/suite/TestFastSenseCompanion.m` still matches (method name preserved)
    - `grep -nE "verifyEqual\(btn\(1\).Layout.Column, 7," tests/suite/TestFastSenseCompanion.m` still matches (Wiki stays col 7)
    - `mcp__matlab__run_matlab_test_file` shows testToolbarHasWikiButton + testToolbarGearMovedToColumn8 PASS
    - `mh_style` + `mh_lint` clean on the file
  </acceptance_criteria>
  <done>Gear assertion updated 9→10 with matching diagnostic; Wiki assertion left at 7; method name preserved. Both toolbar tests pass. MISS_HIT clean.</done>
</task>

<task type="auto">
  <name>Task 2: Add notification-center integration tests to TestFastSenseCompanion</name>
  <read_first>
    - tests/suite/TestFastSenseCompanion.m lines 1086-1161 (EventStore DI tests: how a store is built + passed + getEventStore asserted) and lines 1250-1282 (toolbar findall idiom) and the suite's headless-guard idiom near the top
    - libs/FastSenseCompanion/FastSenseCompanion.m (Plan 03: hBellBtn_ 'CompanionBellBtn', getRootColumnWidthForTest_, onLiveTickForTest_, toggleNotificationCenter_, updateBellBadge_, NotifPane_)
    - .planning/phases/1040-companion-notification-center/1040-VALIDATION.md "Phase Requirements → Test Map" rows mapped to TestFastSenseCompanion
  </read_first>
  <files>tests/suite/TestFastSenseCompanion.m</files>
  <action>
    Add a new test section (comment header `% ---- Phase 1040: Notification Center integration ----`)
    with these `function test...(testCase)` methods. Use the suite's existing store-building +
    headless-guard idioms; build a store via `es = EventStore([tempname '.mat']);` and a Companion
    via `FastSenseCompanion('EventStore', es)` (or `FastSenseCompanion()` for the no-store case).
    Fixture events: `e = Event(now-0.01, NaN, 'P-101', 'HighPressure'); e.Severity = 3; e.IsOpen = true; e2 = Event(now-0.02, now-0.015, 'T-200', 'Overtemp'); e2.Severity = 2;` then `es.append([e e2]);`

    1. `testBellButtonAtColumn8` — `app = FastSenseCompanion('EventStore', es);` find `CompanionBellBtn`
       on `app.getFigForTest_()`; assert exactly one and `Layout.Column == 8`. Teardown closes app.
    2. `testRootGridHasFourColumns` — assert `numel(app.getRootColumnWidthForTest_()) == 4` and the
       4th is `0` initially (hidden).
    3. `testBellTogglesFourthColumn` — `app.toggleNotificationCenter_(); drawnow;` assert
       `getRootColumnWidthForTest_(){4} == 320`; toggle again; assert `{4} == 0`.
    4. `testBellDisabledWithoutEventStore` — `app = FastSenseCompanion();` (no store) find
       `CompanionBellBtn`; assert `strcmp(btn.Enable,'off')` and Tooltip is 'No EventStore registered'.
    5. `testBellEnabledWithEventStore` — with the store, assert `strcmp(btn.Enable,'on')`.
    6. `testBellBadgeReflectsUnackedCount` — with `es` holding the 2 unacked events above, call
       `app.toggleNotificationCenter_(); app.onLiveTickForTest_(); drawnow;` then assert the bell Text
       contains '(2)' (badge count). Then acknowledge one via `es.acknowledgeEvent(e2.Id, struct('comment',''));`
       call `app.onLiveTickForTest_(); drawnow;` and assert the bell Text contains '(1)'.
    7. `testBellBadgeSeverityColor` — with a sev-3 unacked present, after a tick assert
       `isequal(btn.BackgroundColor, CompanionTheme.get(<app theme name>).StatusAlarmColor)` (resolve
       the app's theme via the same accessor TestFastSenseCompanion uses elsewhere, or default 'dark').
    8. `testOnLiveTickRefreshesNotifPane` — append a NEW unacked event after construction, toggle the
       pane open, call `app.onLiveTickForTest_(); drawnow;` and assert the badge now reflects the added
       event (Text count increments). (Proves the onLiveTick_ hook calls refresh + updateBellBadge_.)
    9. `testNotifPaneDetachReinline` — toggle open; call the detach entry the way the listener does:
       `app` exposes `setNotifDetached_` (private) — drive it via a Hidden test accessor if needed, OR
       fire the pane's DetachRequested: `notify(app.notifPaneForTest_(), 'DetachRequested');` (add a
       Hidden `notifPaneForTest_()` accessor returning `obj.NotifPane_` to FastSenseCompanion in this
       task). After detach assert a uifigure named 'Notification Center — FastSenseCompanion' exists
       (`findall(groot,'Type','figure','Name','Notification Center — FastSenseCompanion')` non-empty),
       then `app.close()` and assert it is gone.

    Each test: build app in the method, `testCase.addTeardown(@() app.close());` (guard double-close).
    Reuse the suite's headless guard so no-desktop CI skips rather than hard-fails. If a Hidden
    accessor is missing (`notifPaneForTest_`), add it to FastSenseCompanion's *ForTest_ methods block.
    MISS_HIT clean (≤160 cols).
  </action>
  <verify>
    <automated>mcp__matlab__run_matlab_test_file: tests/suite/TestFastSenseCompanion.m (all Phase 1040 tests + the full suite PASS; skips only via headless guard)</automated>
  </verify>
  <acceptance_criteria>
    - `grep -cE "function test(BellButtonAtColumn8|RootGridHasFourColumns|BellTogglesFourthColumn|BellDisabledWithoutEventStore|BellEnabledWithEventStore|BellBadgeReflectsUnackedCount|BellBadgeSeverityColor|OnLiveTickRefreshesNotifPane|NotifPaneDetachReinline)" tests/suite/TestFastSenseCompanion.m` returns 9
    - `grep -n "CompanionBellBtn" tests/suite/TestFastSenseCompanion.m` matches
    - `grep -n "getRootColumnWidthForTest_" tests/suite/TestFastSenseCompanion.m` matches AND `grep -n "onLiveTickForTest_" tests/suite/TestFastSenseCompanion.m` matches
    - `grep -n "Notification Center" tests/suite/TestFastSenseCompanion.m` matches (detach test)
    - `mcp__matlab__run_matlab_test_file tests/suite/TestFastSenseCompanion.m` → 0 failures (skips only via headless guard)
    - `mh_style` + `mh_lint` clean on the file
  </acceptance_criteria>
  <done>Nine notification-center integration tests added covering bell col 8, 4-column grid, toggle, enable/disable, badge count + severity color, onLiveTick refresh, and detach/re-inline. Full TestFastSenseCompanion suite green. MISS_HIT clean.</done>
</task>

<task type="auto">
  <name>Task 3: Full-suite green gate</name>
  <read_first>
    - .planning/phases/1040-companion-notification-center/1040-VALIDATION.md "Sampling Rate" (full suite before verify-work)
    - tests/run_all_tests.m (the discovery runner)
  </read_first>
  <files>tests/suite/TestFastSenseCompanion.m</files>
  <action>
    Run the three phase-relevant suites and confirm green, then the full discovery suite:
    1. `tests/test_notification_center_pane.m` (flat — via evaluate_matlab_code) — Plan 01 logic.
    2. `tests/suite/TestNotificationCenterPane.m` — Plan 02 pane suite.
    3. `tests/suite/TestFastSenseCompanion.m` — this plan's integration tests + the updated toolbar
       assertions + all prior Companion tests (no regression).
    4. `tests/run_all_tests.m` — full suite (via run_matlab_file) must be green (skips permitted only
       for pre-existing documented headless/Octave skips; NO new failures).
    If any failure surfaces, fix it in the test or (if a genuine integration bug) note it for a Plan 03
    follow-up — but the expectation is green. This task makes no production edits unless a test-only
    fix is required; record any such fix in the SUMMARY. MISS_HIT must remain clean on touched files.
  </action>
  <verify>
    <automated>mcp__matlab__run_matlab_file: tests/run_all_tests.m (full suite green; no NEW failures vs. the pre-phase baseline; pre-existing documented skips allowed)</automated>
  </verify>
  <acceptance_criteria>
    - `tests/test_notification_center_pane` prints "All N tests passed." (via evaluate_matlab_code)
    - `mcp__matlab__run_matlab_test_file tests/suite/TestNotificationCenterPane.m` → 0 failures
    - `mcp__matlab__run_matlab_test_file tests/suite/TestFastSenseCompanion.m` → 0 failures
    - `mcp__matlab__run_matlab_file tests/run_all_tests.m` → no NEW failures vs. baseline (capture the pass/fail/skip tallies in the SUMMARY)
    - `mh_style` + `mh_lint` clean on every file touched in Plans 01-04
  </acceptance_criteria>
  <done>All three phase suites green and the full discovery suite shows no new failures; tallies recorded. MISS_HIT clean across the phase's files.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 4: Human verify — live pop-in + badge color under a real violation stream</name>
  <what-built>
    A toolbar bell (col 8) with an unacked-count badge that opens a collapsible 4th-column
    NotificationCenterPane in FastSenseCompanion. The pane live-lists unacked EventStore events
    (newest-first), supports one-click Ack / Ack-with-comment / "Acknowledge all visible", shows a
    'LIVE' tag on open violations and a 'No unacknowledged events' empty state, is detachable to its
    own window, and refreshes on the existing onLiveTick_ loop (no new timer). This is the one
    manual-only item in 1040-VALIDATION.md (live visual rendering + badge color).
  </what-built>
  <how-to-verify>
    In the running MATLAB session (figures are visible on the user's screen), via the matlab MCP:
    1. `install();` then build a Companion with an EventStore + a mock LiveEventPipeline that produces
       threshold violations — the simplest path is the industrial plant demo
       (`demo/industrial_plant/run_demo.m` or the companion entry it uses) which already wires a
       MonitorTag + EventStore + live pipeline. Start it and enable the companion's "Live" button.
    2. Confirm the toolbar shows a BELL at column 8 (to the LEFT of the gear), gear at the far right.
    3. Trigger / wait for a threshold violation. CONFIRM:
       - the bell badge increments and shows a count, e.g. bell + ' (1)';
       - the badge BACKGROUND color matches the highest unacked severity (alarm = red
         StatusAlarmColor, warn = orange StatusWarnColor, info = teal Accent);
       - clicking the bell opens the right-hand pane and the new event appears NEWEST-FIRST with a
         'LIVE' tag while the violation is still open.
    4. Click 'Ack' on a row → the row leaves the inbox on the next tick and the badge decrements.
       Try 'Ack with comment…' (the '...' cell) → enter a comment → confirm it acknowledges.
    5. Click 'Acknowledge all visible' → inbox empties to 'No unacknowledged events' and the badge
       returns to the plain bell glyph.
    6. Click the pop-out icon → the pane detaches into a window titled
       'Notification Center — FastSenseCompanion'; close it → it re-inlines.
    7. Toggle the companion Settings theme (dark ↔ light) → pane + badge recolor cleanly.
    Acceptable: the bell glyph may render as the ASCII '[!]' fallback on some platforms — that is by
    design (RESEARCH Open Question 2).
  </how-to-verify>
  <resume-signal>Type "approved" if all steps pass, or describe what looked wrong (badge color, ordering, ack not clearing, flicker, detach/theme issue) so it can be fixed.</resume-signal>
</task>

</tasks>

<verification>
- Tasks 1-3 automated: the two toolbar assertions updated + 9 integration tests + full suite green.
- Task 4 manual: human confirms live pop-in, badge count + severity color, ack-clears, bulk-ack empty
  state, detach/re-inline, and theme recolor on a real violation stream.
- `mh_style` + `mh_lint` clean on every file touched across Plans 01-04.
</verification>

<success_criteria>
- testToolbarGearMovedToColumn8 asserts col 10 (name preserved); testToolbarHasWikiButton stays col 7.
- 9 notification-center integration tests pass: bell col 8, 4-column grid, toggle, enable/disable,
  badge count + severity color, onLiveTick refresh, detach/re-inline.
- Full discovery suite green (no new failures vs. baseline; tallies recorded in SUMMARY).
- Human approves the live demo (pop-in, badge color, ack-clears, bulk-ack, detach, theme).
- Phase honors 1040-CONTEXT.md deferred items end-to-end (no NotificationService linkage, sounds,
  snooze, grouping, per-user seen-state anywhere in the delivered surface).
</success_criteria>

<output>
After completion, create `.planning/phases/1040-companion-notification-center/1040-04-SUMMARY.md`.
</output>
