---
phase: 1040-companion-notification-center
plan: 04
subsystem: testing
tags: [matlab, notification-center, event-viewer, integration-tests, human-verify, design-pivot]

requires:
  - phase: 1040-03-companion-integration
    provides: bell + onLiveTick badge update (post-pivot); NotificationCenterPane host
provides:
  - Updated toolbar-column assertions (gear col 10)
  - Notification integration tests retargeted to the Event-Viewer architecture
  - Human-verified live behavior (placement + horizontal resize)
affects: []

tech-stack:
  added: []
  patterns:
    - "Human-verify checkpoint can pivot architecture mid-phase; tests + code re-targeted accordingly"

key-files:
  created: []
  modified:
    - tests/suite/TestFastSenseCompanion.m
    - tests/suite/TestCompanionEventViewer.m
    - libs/FastSenseCompanion/FastSenseCompanion.m
    - libs/FastSenseCompanion/CompanionEventViewer.m

key-decisions:
  - "DESIGN PIVOT (user, at the human-verify checkpoint): the notification center moves OUT of the main companion (4th column) and INTO the Event Viewer as a horizontally-resizable right panel; the companion keeps the bell as an unacked indicator that OPENS the viewer"
  - "Horizontal resize = a draggable col-3 divider driving a public NotifPaneWidth setter; chained WindowButton{Down,Motion,Up}Fcn preserves the Gantt crosshair (mirrors TimeRangeSelector)"
  - "verify_phase_goal done inline (not via gsd-verifier subagent): subagents lack the matlab MCP tools, and the pivot made the plans' original must_haves (4th-column wording) stale — a grep-only verifier would report false gaps"

patterns-established:
  - "Notification placement: NotificationCenterPane is host-agnostic; the host (companion vs Event Viewer) is a wiring choice"

requirements-completed: []

duration: ~90 min (incl. the checkpoint pivot + rework)
completed: 2026-06-02
---

# Phase 1040 Plan 04: Companion Tests + Verify Summary

**Locked the integration with tests + a human visual check — which triggered a design pivot: the notification inbox was relocated from the companion's 4th column into the Event Viewer as a horizontally-resizable right panel (draggable divider); the companion keeps the bell as an unacked indicator that opens the viewer. Re-targeted all tests; human-approved the reworked live behavior.**

## Performance

- **Duration:** ~90 min (Tasks 1–3 + the checkpoint-driven rework)
- **Completed:** 2026-06-02
- **Tasks:** 4 (Task 4 = human-verify checkpoint → pivot)

## Accomplishments
- Task 1: `testToolbarGearMovedToColumn8` now asserts col 10 (name preserved); `testToolbarHasWikiButton` stays col 7.
- Task 2: notification integration tests (initially 9 companion-side for the 4th-column design).
- Task 3: green gate across the phase suites.
- **Task 4 (human-verify):** user rejected the 4th-column placement → **pivot** to the Event Viewer (resizable right panel). Reworked code + tests, then the user **approved** the live demo (placement + horizontal divider-drag resize).

## Task Commits
1. **Tasks 1+2 (toolbar fix + 9 integration tests, original 4th-column design)** — `1b33bc14` (test)
2. **Rework code: relocate notification center to the Event Viewer** — `04fe7c8e` (refactor)
3. **Retarget notification tests to the Event-Viewer architecture** — `4787e87d` (test)
4. **Viewer root-layout test updated for the [1 4] notification column** — `052e2d97` (test)

**Plan metadata:** (this SUMMARY commit)

## Files Created/Modified
- `libs/FastSenseCompanion/FastSenseCompanion.m` — reverted the 4th-column/pane wiring; bell stays (col 8) and now opens the Event Viewer; `updateBellBadge_` on construction/onLiveTick/applyTheme.
- `libs/FastSenseCompanion/CompanionEventViewer.m` — `[1 4]` root grid hosting `NotificationCenterPane` (col 4) with a draggable col-3 divider + public `NotifPaneWidth`; refresh off the redraw/auto-tick; DetachRequested pop-out/re-dock; close teardown.
- `tests/suite/TestFastSenseCompanion.m` — companion-side bell tests (col 8, opens viewer, enable/disable, badge count+color+tick).
- `tests/suite/TestCompanionEventViewer.m` — viewer-side notif tests (hosted inbox lists unacked, [1 4] grid, NotifPaneWidth resize, detach/re-dock) + updated root-layout test.

## Decisions Made
See key-decisions frontmatter — the placement pivot is the headline.

## Deviations from Plan

**[Rule 4 - Architectural / user-directed] Notification center relocated to the Event Viewer**
- **Found during:** Task 4 (human-verify checkpoint)
- **Issue:** The user judged the companion 4th-column placement wrong; wants the inbox in the Event Viewer as a resizable right panel.
- **Fix:** Reverted Plan 03's companion 4th-column integration (kept the bell, repurposed to open the viewer); hosted `NotificationCenterPane` in `CompanionEventViewer` with a draggable horizontal divider; re-targeted all Plan 04 tests; recorded the decision in the `notification-center-lives-in-event-viewer` memory.
- **Verification:** 57/57 `TestCompanionEventViewer`; companion bell tests green; flat 18/18; pane suite 12/12; human approved the live demo.
- **Committed in:** 04fe7c8e, 4787e87d, 052e2d97

## Verification (inline)
- `test_notification_center_pane` (flat) — 18/18.
- `TestNotificationCenterPane` — 12/12.
- `TestCompanionEventViewer` — 57/57 (incl. 4 new notif tests + updated [1 4] layout test).
- `TestFastSenseCompanion` — all bell/integration tests pass; only the 2 pre-existing environmental orphan-timer flakes (`testADHOC05_noOrphanTimersAfterPlotAndClose`, `testPerTagModeSpawnsNFigures`) remain (confirmed identical on pre-1040 code; see known-env-test-failures memory).
- **Human-approved** the reworked live behavior on the industrial-plant demo (placement, divider-drag resize, ack flow, bell-opens-viewer).

## Issues Encountered
- The full cross-suite regression run caught one stale test (`testRootLayoutIs1x2WithLeftAndRightColumns`) that asserted the old `[1 2]` viewer grid — updated to `[1 4]`. (Worth the full run.)
- Harmless test noise: `delete(storePath)` teardown warnings (store file never written) and class-reload "delete not defined" destructor warnings — both pre-existing-style, non-failing.

## Next Phase Readiness
- Phase goal achieved (acknowledgeable inbox + bell badge), placement per the user's pivot. No outstanding gaps.

---
*Phase: 1040-companion-notification-center*
*Completed: 2026-06-02*
