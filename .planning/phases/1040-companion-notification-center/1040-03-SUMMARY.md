---
phase: 1040-companion-notification-center
plan: 03
subsystem: ui
tags: [matlab, uifigure, fastsensecompanion, notification-center, toolbar, bell-badge, onlivetick]

requires:
  - phase: 1040-02-notification-pane
    provides: NotificationCenterPane (attach/refresh/applyTheme/DetachRequested) + static badge helpers
provides:
  - Toolbar bell button (col 8) with unacked-count + severity-colored badge
  - Collapsible 4th root-grid column hosting the notification pane
  - onLiveTick_ refresh hook (no new timer); detach-to-uifigure; applyTheme + close wiring
affects: [1040-04-companion-tests-verify]

tech-stack:
  added: []
  patterns:
    - "Collapsible grid column via ColumnWidth{4} 0<->320 toggle (RESEARCH Pattern 3)"
    - "Badge driven by static NotificationCenterPane helpers on the Companion side"

key-files:
  created: []
  modified:
    - libs/FastSenseCompanion/FastSenseCompanion.m

key-decisions:
  - "toggleNotificationCenter_ is PUBLIC (name kept with trailing underscore per the plan's acceptance grep) so the bell callback, user scripts, and Plan 04 tests can drive it; setNotifDetached_/updateBellBadge_/bellGlyph_ stay private"
  - "Bell enable/disable is set only at construction from EventStore presence (the other hEventsBtn_.Enable sites are viewer-open-state, not store presence — not mirrored)"
  - "onLiveTick_ notif refresh is gated behind the existing IsLive guard (piggybacks the live loop; no new timer) — badge also updates on toggle-open, ack, and applyTheme"

patterns-established:
  - "Hidden Companion test seams: getRootColumnWidthForTest_, onLiveTickForTest_, notifPaneForTest_"

requirements-completed: []

duration: ~40 min
completed: 2026-06-02
---

# Phase 1040 Plan 03: Companion Integration Summary

**`NotificationCenterPane` wired into `FastSenseCompanion`: a toolbar bell (col 8) with an unacked-count + severity-colored badge toggles a collapsible 4th root-grid column hosting the pane; `onLiveTick_` refreshes it with no new timer; detach-to-uifigure, applyTheme, and close teardown all handled.**

## Performance

- **Duration:** ~40 min
- **Completed:** 2026-06-02
- **Tasks:** 3 (Tasks 1 & 2 committed together; Task 3 separate)
- **Files modified:** 1 (`FastSenseCompanion.m`)

## Accomplishments
- Root grid `[3 3]→[3 4]` (col 4 hidden at width 0); toolbar `[1 9]→[1 10]`; bell at col 8 (gear shifted 9→10); `hNotifPanel_` at Row 2 Col 4.
- Bell disabled with no EventStore (mirrors `hEventsBtn_`); `bellGlyph_` ASCII `[!]` fallback for headless/Windows.
- `toggleNotificationCenter_` (public) shows/hides col 4 with one `drawnow`; `setNotifDetached_` pops out to a 420×600 `'Notification Center — FastSenseCompanion'` uifigure and re-inlines on close; `updateBellBadge_` reflects count + max-severity color and tolerates read failure.
- `onLiveTick_` refreshes the pane + badge (after `scanLiveTagUpdates_`/`setLastUpdated`, before the cluster block), guarded so it never crashes the timer; **no new timer**.
- `applyTheme` propagates to the pane + recolors the badge; `close()` tears down the detached window + pane; `DetachRequested` listener registered in build + `setProject`.

## Task Commits

1. **Task 1 (grid/toolbar/bell/panel) + Task 2 (pane wiring/toggle/detach/badge/applyTheme/close)** — `2004e304` (feat) — committed together: both edit `FastSenseCompanion.m` and Task 2 fills behavior for Task 1's structure. Verified by the Task 1 + Task 2 smokes.
2. **Task 3: onLiveTick_ refresh + badge hook** — `7e543c32` (feat)

**Plan metadata:** (this SUMMARY commit)

## Files Created/Modified
- `libs/FastSenseCompanion/FastSenseCompanion.m` — bell + 4th column + pane instantiation/wiring + toggle/detach/badge + onLiveTick_ hook + 3 Hidden test seams.

## Decisions Made
See key-decisions frontmatter.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] toggleNotificationCenter_ had to be public**
- **Found during:** Task 2 smoke ("Cannot access method 'toggleNotificationCenter_'")
- **Issue:** The plan placed `toggleNotificationCenter_` as a private callback but its interfaces mark it "callable in tests" and Plan 04 calls `app.toggleNotificationCenter_()` directly (the acceptance grep also requires that exact name).
- **Fix:** Moved it to the public methods block, keeping the name (the bell callback + user scripts + tests all route here).
- **Verification:** Task 2 smoke passes (toggle shows 320 / hides 0).
- **Committed in:** 2004e304

---

**Total deviations:** 1 auto-fixed (1 blocking).
**Impact on plan:** No scope change — a method visibility correction.

## Issues Encountered
- **Pre-existing Code Analyzer lint (15 items):** the `hp` panel-styling loop, `now` usages, an `isscalar` suggestion, and an extra semicolon all live in code this plan did not touch. Confirmed against the HEAD version of the file (identical 15 issues, line-shifted) — **zero new** Code Analyzer issues from this plan.
- **Two pre-existing environmental test failures:** `testADHOC05_noOrphanTimersAfterPlotAndClose` and `testPerTagModeSpawnsNFigures` fail `verifyEmpty(timerfindall...)` (2 lingering `singleShot` DashboardEngine render timers in headless R2025b). **Confirmed pre-existing** — both fail identically against the pre-1040 bell-less `FastSenseCompanion.m`. Recorded in the known-env-test-failures memory.

## Regression Check (TestFastSenseCompanion, headless)
- **73 tests: 70 pass, 3 fail.** The only Plan-03-attributable failure is `testToolbarGearMovedToColumn8` (asserts gear col 9 — now 10), **expected** and fixed in Plan 04. The other two failures are the pre-existing environmental orphan-timer tests above. **No regressions introduced.**

## Next Phase Readiness
- Plan 04 updates the two toolbar-column assertions (Wiki stays 7; gear 9→10), adds 9 integration tests, runs the full suite, and does the human visual check.
- Hidden seams `getRootColumnWidthForTest_`, `onLiveTickForTest_`, `notifPaneForTest_` + the public `toggleNotificationCenter_` are ready for Plan 04's tests.
- **Note for Plan 04 tests:** the `onLiveTick_` notif hook only fires when the companion is live — tests must `startLiveMode()` (then `stopLiveMode()`/close) to exercise it; and clean orphan timers/figures between app create/close cycles.

---
*Phase: 1040-companion-notification-center*
*Completed: 2026-06-02*
