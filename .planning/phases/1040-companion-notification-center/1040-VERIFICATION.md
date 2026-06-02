---
status: passed
phase: 1040-companion-notification-center
verified: 2026-06-02
method: orchestrator-inline (subagents lack matlab MCP tools; mid-phase design pivot)
human_verified: true
---

# Phase 1040 — Verification: Companion Notification Center

## Goal

Add an acknowledgeable in-app notification "inbox" that live-lists *unacknowledged*
threshold-violation events from the shared `EventStore` and lets an operator acknowledge
them (shared, ISA-18.2-audited ack via `EventStore.acknowledgeEvent`), surfaced with an
unacked-count bell indicator — without degrading dashboard/companion refresh.

## Outcome: PASSED (with a user-directed placement pivot)

The goal is achieved. At the human-verify checkpoint the user redirected the **placement**:
the inbox lives in the **Event Viewer** as a horizontally-resizable right panel (not a 4th
column in the main companion). The companion keeps a **bell** (toolbar col 8) as an
unacked-count + severity indicator whose click **opens the Event Viewer**.

## Goal-backward checks

| Goal element | Delivered | Evidence |
|---|---|---|
| Acknowledgeable inbox of UNACKED events | `NotificationCenterPane` (filterUnacked_ → newest-first → diff-by-Id → render) | `TestNotificationCenterPane` 12/12; flat test 18/18 |
| Dismiss == shared audited acknowledge | per-item Ack / Ack-with-comment / Acknowledge-all → `EventStore.acknowledgeEvent`; unknownEventId race = no-op | pane suite (testAckRemovesOnNextRefresh, testAckRaceIsNoOp); human demo |
| Live refresh, no new timer | hosted-pane refresh off the Event Viewer's redraw/auto-tick; companion bell badge off `onLiveTick_` | `testOnLiveTickUpdatesBellBadge`; viewer auto-tick; grep: no new `timer(` |
| Unacked-count + severity bell | bell col 8, badge text `(N)`, color by max severity; disabled w/o store | companion bell tests (col 8, enable/disable, badge count+color); human demo |
| Inbox surfaced where events are investigated | `NotificationCenterPane` hosted in `CompanionEventViewer` right panel | `testNotifPaneHostedInViewer`, `testNotifRootGridHasFourColumns` |
| Horizontally resizable | draggable col-3 divider → `NotifPaneWidth` setter resizes col 4 | `testNotifPaneWidthResizesColumn`; human demo (divider drag) |
| Detachable | DetachRequested pops to its own window + re-docks | `testNotifPaneDetachReinline` |
| Backward compatible | companion root grid back to [3 3]; existing companion/viewer suites green | `TestCompanionEventViewer` 57/57; companion suite (bell tests pass) |
| Deferred items absent | no NotificationService/snooze/sound/grouping/seen in the pane | grep clean (Plan 02 verification) |

## Automated test results
- `tests/test_notification_center_pane.m` (flat) — **18/18**
- `tests/suite/TestNotificationCenterPane.m` — **12/12**
- `tests/suite/TestCompanionEventViewer.m` — **57/57** (incl. 4 new notif tests + updated [1 4] layout)
- `tests/suite/TestFastSenseCompanion.m` — all bell/integration tests pass; **2 pre-existing environmental orphan-timer failures only** (`testADHOC05_noOrphanTimersAfterPlotAndClose`, `testPerTagModeSpawnsNFigures` — confirmed identical on pre-1040 code; not regressions)
- MISS_HIT (`mh_style`/`mh_lint`) clean on all touched files; Code Analyzer clean on new code (only the pre-existing accepted `LeftPaneWidth`-style setter warning + pre-existing now/datestr/semicolon notes)

## Human verification
Approved on the industrial-plant demo: bell at col 8 (red `(N)` badge), bell opens the
Event Viewer, inbox is the resizable right panel (divider drag), ack/ack-with-comment/
acknowledge-all clear items + decrement the bell, pop-out detaches/re-docks.

## Notes / follow-ups
- The divider drag interaction itself is verified manually (headless tests can't simulate
  mouse drag); the `NotifPaneWidth` setter it drives is unit-tested.
- The 2 environmental orphan-timer test failures are tracked in the `known-env-test-failures`
  memory and are not caused by this phase.
