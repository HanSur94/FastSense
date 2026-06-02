---
phase: 1040-companion-notification-center
plan: 02
subsystem: ui
tags: [matlab, uifigure, notification-center, eventstore, acknowledge, uitable, headless-tests]

requires:
  - phase: 1040-01-test-foundation
    provides: StubEventStore + NotificationCenterPane static helpers
provides:
  - Full detachable NotificationCenterPane (attach/detach/applyTheme/refresh/ack/bulk-ack)
  - Stale-on-read-error guard (keep last-good + inline (stale) marker)
  - TestNotificationCenterPane headless suite (12 tests)
  - Hidden test seams + StubEventStore.getEventStore/save
affects: [1040-03-companion-integration, 1040-04-companion-tests-verify]

tech-stack:
  added: []
  patterns:
    - "Pane mirrors EventsLogPane contract (attach/detach/applyTheme/DetachRequested/setCompanion/delete)"
    - "Companion-resolved store: ackOne_ calls Companion_.getEventStore() so the stub can double as resolver in tests"
    - "Hidden test seams over loosened property access (Phase 1028 pattern)"

key-files:
  created:
    - tests/suite/TestNotificationCenterPane.m
  modified:
    - libs/FastSenseCompanion/NotificationCenterPane.m
    - tests/StubEventStore.m

key-decisions:
  - "uitable cell-selection property is CellSelectionCallback (matches EventViewer.m), NOT the planning docs' CellSelectionChangedFcn — the latter does not exist on matlab.ui.control.Table"
  - "Row-click -> Event Viewer is guarded best-effort: FastSenseCompanion.openEventViewer_ is private today, so the call is wrapped to never alert; activates once a public entry exists"
  - "refresh diffs by Id and returns early on no-change (no flicker, no forced redraw — Pitfall 4)"
  - "Encapsulation kept: UI handles stay private; tests read state via Hidden seams rather than public properties"

patterns-established:
  - "Stale guard: read error -> IsStale_ + (stale) label suffix in StatusWarnColor, last-good list retained, no uialert"

requirements-completed: []

duration: ~35 min
completed: 2026-06-02
---

# Phase 1040 Plan 02: Notification Pane Summary

**Full detachable `NotificationCenterPane` inbox — header + severity filter + bulk-ack + inbox uitable, `refresh(eventStore)` (unacked → diff-by-Id → newest-first → render, capped 200), one-click / commented / bulk acknowledge routed to `EventStore.acknowledgeEvent`, a stale-on-read-error guard, and a 12-test headless suite (all green).**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-06-02
- **Tasks:** 3 (Tasks 1 & 2 committed together — see below)
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- Complete pane lifecycle (attach/detach/applyTheme) mirroring `EventsLogPane`, with `[3 1]` root (header `[1 6]` + bulk button + inbox `uitable`) and filter selection preserved across detach/reattach.
- `refresh` loop: unacked filter → diff-by-Id (no flicker) → newest-first → render (200-row cap); EventStore read failure keeps the last-good list and shows an inline `(stale)` marker (no uialert).
- Acknowledge actions: one-click `Ack`, `Ack with comment…` (inputdlg), and `Acknowledge all visible`; `EventStore:unknownEventId` race is a silent no-op; post-ack `save()` is non-fatal on failure.
- `TestNotificationCenterPane` — 12 headless tests, all green; Plan 01 flat test still 18/18.

## Task Commits

1. **Task 1 (lifecycle) + Task 2 (refresh/ack/render)** — `21874225` (feat) — committed together: Task 2 fills the private methods declared by Task 1's lifecycle in the same file; the intermediate stub-only state is not independently meaningful. Verified by the attach/detach smoke (Task 1 gate) and the full suite (Task 2 gate).
2. **Task 3: TestNotificationCenterPane suite + Hidden seams + StubEventStore.getEventStore/save** — `92ba4dbd` (test)

**Plan metadata:** (this SUMMARY commit)

## Files Created/Modified
- `libs/FastSenseCompanion/NotificationCenterPane.m` — full pane (lifecycle + refresh + ack callbacks + stale guard + applyTheme + Hidden test seams).
- `tests/suite/TestNotificationCenterPane.m` — 12-test headless class suite.
- `tests/StubEventStore.m` — added `getEventStore()`→self and no-op `save()`.

## Decisions Made
See key-decisions frontmatter. Most consequential: the `CellSelectionCallback` property correction and the best-effort row-click→viewer (private `openEventViewer_`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] uitable property is CellSelectionCallback, not CellSelectionChangedFcn**
- **Found during:** Task 1 (attach smoke)
- **Issue:** The plan + UI-SPEC specify `hTable_.CellSelectionChangedFcn`, which does not exist on `matlab.ui.control.Table` (runtime error "Unrecognized property 'CellSelectionChangedFcn'").
- **Fix:** Used `CellSelectionCallback` (the actual uifigure-table property, matching `EventViewer.m:213`); the `event.Indices` dispatch (col 7 ack / 8 comment / else viewer) is unchanged.
- **Verification:** attach/detach smoke + full suite green.
- **Committed in:** 21874225

**2. [Rule 3 - Blocking] Row-click → Event Viewer made best-effort (openEventViewer_ is private)**
- **Found during:** Task 2 (onCellSelected_)
- **Issue:** The plan calls `obj.Companion_.openEventViewer_()`, but that method is `Access = private` on `FastSenseCompanion` (line 1821, past the private boundary at 1371) — an external class cannot call it.
- **Fix:** Wrapped the row-click→viewer branch in its own guarded try/catch so a benign row-click never alerts; it activates automatically if a public entry point is added. Ack paths (cols 7/8) are unaffected. Not a Plan 02 key_link; not exercised by Plan 04's human test.
- **Files modified:** libs/FastSenseCompanion/NotificationCenterPane.m
- **Verification:** suite green; row-click path is a safe no-op today.
- **Committed in:** 21874225

**3. [Rule 1 - Cleanliness] Test fixture uses a literal acked datenum + addPaths(~)**
- **Found during:** Task 3 (Code Analyzer pass)
- **Issue:** `now` in the fixture triggers a deprecation info and is non-deterministic; `addPaths(testCase) %#ok<INUSD>` tripped an unused-arg warning + a stale-suppression info.
- **Fix:** `e3.AckedAt = 737000;` (deterministic non-empty datenum) and `addPaths(~)`.
- **Verification:** suite green; pane Code Analyzer clean.
- **Committed in:** 92ba4dbd

---

**Total deviations:** 3 auto-fixed (2 blocking, 1 cleanliness).
**Impact on plan:** No scope change. The `CellSelectionCallback` fix is essential (the planned property does not exist). Row→viewer is a documented best-effort limitation pending a public Companion entry point.

## Issues Encountered
- The pane's `refresh` no-diff path originally contained the literal word "drawnow" in a comment, tripping the Pitfall-4 `grep -c drawnow == 0` check; reworded to "no forced redraw". No actual `drawnow` exists in the pane.

## Next Phase Readiness
- Plan 03 can instantiate + attach `NotificationCenterPane` in `FastSenseCompanion`, add the bell + 4th column, and wire `onLiveTick_` refresh. The pane's public contract (`setCompanion`, `attach`, `detach`, `refresh`, `applyTheme`, `requestDetach`, `DetachRequested`, `IsAttached`) + static badge helpers are ready.
- **Carry-forward for Plan 04:** if row-click→viewer is desired, Plan 03 could expose a public Companion shim for `openEventViewer_`.

---
*Phase: 1040-companion-notification-center*
*Completed: 2026-06-02*
