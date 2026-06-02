---
phase: 1040-companion-notification-center
plan: 01
subsystem: testing
tags: [matlab, notification-center, eventstore, test-double, pure-logic, tdd]

requires:
  - phase: 1032-ack-events
    provides: EventStore.acknowledgeEvent + Event.AckedAt (unacked filter key)
provides:
  - StubEventStore test double (getEvents/numEvents/acknowledgeEvent + ThrowOnGet_/ThrowOnAck_)
  - NotificationCenterPane class shell + 7 static pure-logic helpers (filter/sort/diff/badge)
  - Flat headless test pinning all helper + stub semantics
affects: [1040-02-notification-pane, 1040-03-companion-integration, 1040-04-companion-tests-verify]

tech-stack:
  added: []
  patterns:
    - "Interface-first TDD: static pure-logic helpers as the contract before any UI"
    - "Stub-with-failure-switches test double (ThrowOnGet_/ThrowOnAck_) modeled on CaptureNotificationService"

key-files:
  created:
    - tests/StubEventStore.m
    - libs/FastSenseCompanion/NotificationCenterPane.m
    - tests/test_notification_center_pane.m
  modified: []

key-decisions:
  - "Event fixtures use the real 6-arg constructor Event(start,end,sensor,label,thresholdValue,direction); the planning docs' 4-arg shorthand does not construct (direction is required + validated against {'upper','lower'})"
  - "filterUnacked_ treats both empty AND all-NaN AckedAt as unacked, mirroring Event.computeDisplayState"
  - "diffIds_ is order-insensitive via sort(ids(:)) with {} guards so identical sets in any order report no change (no badge flicker)"

patterns-established:
  - "NotificationCenterPane.<helper> static call surface — the pane's pure logic is callable + testable without a uifigure"

requirements-completed: []

duration: ~15 min
completed: 2026-06-02
---

# Phase 1040 Plan 01: Test Foundation Summary

**StubEventStore test double + the NotificationCenterPane pure-logic core (7 static helpers: unacked filter incl. NaN, newest-first sort, order-insensitive id-diff, severity/badge mapping), pinned by an 18-assertion headless flat test.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-06-02
- **Tasks:** 3
- **Files modified:** 3 (all created)

## Accomplishments
- `tests/StubEventStore.m` — fake EventStore handle with `ThrowOnGet_`/`ThrowOnAck_` switches that drive the stale-read and ack-race paths later plans need.
- `libs/FastSenseCompanion/NotificationCenterPane.m` — class shell (events block + full private property declaration) plus 7 pure static helpers; no UI primitives instantiated.
- `tests/test_notification_center_pane.m` — 18 headless assertions covering the stub round-trip + ack-race throw and all 7 helpers; runs green in milliseconds.

## Task Commits

1. **Task 1: StubEventStore test double** — `2b51ac88` (test)
2. **Task 2: NotificationCenterPane static pure-logic helpers** — `3a05c8c6` (feat)
3. **Task 3: flat pure-logic test** — `bd19fb85` (test)

## Files Created/Modified
- `tests/StubEventStore.m` — `classdef StubEventStore < handle`; getEvents/numEvents/acknowledgeEvent; records acked ids + mutates AckedAt.
- `libs/FastSenseCompanion/NotificationCenterPane.m` — shell + filterUnacked_/sortNewestFirst_/maxSeverity_/idsOf_/diffIds_/badgeText_/badgeColor_.
- `tests/test_notification_center_pane.m` — flat function test (`add_companion_path` + local `check`), prints "All 18 tests passed."

## Decisions Made
- See key-decisions frontmatter. The Event 6-arg constructor correction is the most consequential — Plans 02/04 build Event fixtures and must use the full signature.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Event constructor requires 6 args, not the 4 shown in the plan**
- **Found during:** Task 3 (writing the flat test)
- **Issue:** The plan's `<interfaces>` block and Task 3 examples construct `Event(startTime, endTime, sensorName, thresholdLabel)` (4 args). The real `Event` constructor is `Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)` and throws if `direction` is missing/not in `{'upper','lower'}` — the 4-arg form cannot construct.
- **Fix:** Built all test fixtures with the full 6-arg signature (e.g. `Event(30, NaN, 'P-101', 'HighPressure', 100, 'upper')`).
- **Files modified:** tests/test_notification_center_pane.m
- **Verification:** Test runs green (18/18).
- **Committed in:** bd19fb85

---

**Total deviations:** 1 auto-fixed (1 blocking).
**Impact on plan:** No scope change — only the fixture construction syntax. Carries forward to Plans 02 + 04 (their Event fixtures need the same 6-arg form).

## Issues Encountered
None. (Note: the plan's strict "no UI primitives" grep matches doc-comment mentions of `uifigure`/`uitable` in the property block, but a call-syntax grep confirms **zero** actual UI primitive calls — pure logic only.)

## Next Phase Readiness
- Plan 02 can extend `NotificationCenterPane` with the attach/detach/refresh/ack lifecycle on top of the static helpers; `StubEventStore` is ready to drive the headless suite.
- No blockers.

---
*Phase: 1040-companion-notification-center*
*Completed: 2026-06-02*
