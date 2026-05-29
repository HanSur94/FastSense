---
status: resolved
trigger: "On a FastSenseWidget, clicking the 'L' (PlantLog) toggle button on, then off, makes the 'i' (info icon) button disappear from the WidgetButtonBar."
created: 2026-05-26T00:00:00Z
updated: 2026-05-26T19:39:00Z
---

## Current Focus

hypothesis: addPlantLogToggle (DashboardLayout.m:661) uses HARDCODED 3-button-cluster x-position (xPL = barW - 84) instead of the post-reflow 4-button-cluster position (barW - 112). After a toggle callback, the new L sits at barW - 84 which is also where InfoIconButton lives post-reflow → L visually covers Info. Info is NOT deleted; it is hidden by overlap.
test: Probed via /tmp/test_bug_repro2.m. After toggle ON+OFF cycle with LiveTimer running, dumped bar children. PlantLogToggleButton at Position=[686 2 24 24]. InfoIconButton at Position=[686 2 24 24]. CONFIRMED.
expecting: PlantLog ends at barW - 84, same as Info post-reflow. They overlap. Info still in handle hierarchy but covered.
next_action: Fix addPlantLogToggle to either (a) compute xPL based on hasCreate, or (b) call reflowChrome_ at the end so the bar's positions reach the canonical state. Approach (b) is more robust because reflowChrome_ is the authoritative layout for all four button positions.

## Symptoms

expected: After toggling L on and off, the WidgetButtonBar should still show the i (InfoIconButton), the L (PlantLogToggleButton), and the detach button. The info icon should survive any number of L on/off cycles.

actual: After a single L-on -> L-off cycle, the InfoIconButton uicontrol is gone from the bar. The L button itself is still there (it gets rebuilt by the callback), and the detach button is still there, but the i is missing.

errors: No MATLAB errors or warnings observed — the bug is purely a missing uicontrol.

reproduction:
1. Demo already running via `ctx = run_demo()` on the user's machine.
2. Pick a FastSenseWidget on the Overview tab with plant log enabled.
3. Drive PlantLogToggleButton.Callback once (enable), then again (disable).
4. findobj(bar, 'Tag', 'InfoIconButton', '-depth', 1) is empty.

started: Just now during hands-on bug finding on main (commit e63c023). Plant log feature is new in recent Phase 1031-1033 work — presumed regression.

## Eliminated

(none yet)

## Evidence

- timestamp: 2026-05-26 (initial read pass)
  checked: setShowPlantLog(false) path (FastSenseWidget:478-514) — only deletes XLim listener, calls engine.detachPlantLogWidgetHover_, and obj.setPlantLogMarkers([], []).
  found: setPlantLogMarkers only deletes WidgetPlantLogMarker xlines on the FastSense axes. detachPlantLogWidgetHover_ only edits engine.WidgetHovers_ and deletes a figure-level uipanel. Neither touches the WidgetButtonBar children.
  implication: The direct disable path does NOT obviously delete InfoIconButton. The bug must come from a side-effect, refresh, or live-tick interaction.

- timestamp: 2026-05-26
  checked: addPlantLogToggle position math (DashboardLayout:661) — xPL = barW - 84.
  found: After realizeWidget + reflowChrome_, the layout has 4-button right cluster: Detach @ barW-28, Create @ barW-56, Info @ barW-84, PlantLog @ barW-112. When the callback runs addPlantLogToggle again, the new L button is placed at barW-84 — OVERLAPPING the Info icon.
  implication: This is a positioning bug (L overlaps Info visually) but does not delete the Info uicontrol — uicontrols can overlap fine.

- timestamp: 2026-05-26
  checked: Wrote a regression test (testInfoIconSurvivesToggleOnOff) in TestDashboardLayoutPlantLogToggle.m that drives the callback twice (on, then off), then asserts all three buttons survive.
  found: Test PASSED under matlab -batch. 13/13 tests in suite pass.
  implication: The bug does NOT reproduce in a clean batch test that drives the callback directly. So the bug must be triggered by something live-only — most likely the DashboardEngine LiveTimer (onLiveTick) firing between or after the toggle clicks, which calls w.update() → falls through to refresh() → falls through to rebuildForTag_() and the rebuild path of FastSenseObj may interact badly with the bar children.

## New Hypothesis

The live DashboardEngine LiveTimer runs on each tick. In live demos, the timer fires every LiveInterval seconds. When the user clicks L (on), the callback runs. Between the click and the next user action, the timer may fire one or more onLiveTick passes. On each tick, FastSenseWidget.update() is called. If update() falls through to refresh() and then to rebuildForTag_(), it deletes obj.FastSenseObj. **The PlantLogXLimListener_ is bound to the OLD axes**. When the old axes is destroyed during rebuildForTag_, the listener fires its callback (or is itself destroyed)... but the listener is the engine's `addlistener(ax, 'XLim', 'PostSet', ...)` which calls `obj.refreshPlantLogOverlayForWidget_(widget)`. If the listener's PostSet fires on axes destruction with stale state, refreshPlantLogOverlayForWidget_ may trip something.

Actually, more likely path: When rebuildForTag_ is called WHILE ShowPlantLog=true (we toggled it ON), the rebuild deletes the axes, but the PlantLogXLimListener_ is bound to the destroyed axes. The widget property still holds the listener handle. When rebuildForTag_ creates new axes, the listener is NOT re-attached. So on the SECOND click (toggle OFF), `setShowPlantLog(false)` calls `delete(obj.PlantLogXLimListener_)` — but it's already invalidated by axes destruction. No-op.

But none of this explains Info deletion.

## Revised Hypothesis (more focused)

Look at addPlantLogToggle line 661: xPL = barPos(3) - 24 - 4 - 24 - 4 - 24 - 4 = barW - 84. This is hardcoded for a 3-button cluster (Info+Detach+PlantLog with no Create). For the typical dashboard widget WITH Create, Info is also at barW - 84 (after reflowChrome_). So the new L button at barW - 84 OVERLAYS Info.

If MATLAB processes a click event on the L button BUT the click also bubbles to controls underneath (Info), or if there's any double-callback dispatch, Info's callback could fire — opening info popup. But opening a popup doesn't delete Info.

Need to actually probe the live state.

## Resolution

root_cause: DashboardLayout.addPlantLogToggle (libs/Dashboard/DashboardLayout.m:661) computes the L button's x-position as `xPL = barPos(3) - 24 - 4 - 24 - 4 - 24 - 4 = barW - 84`. This is hardcoded for a 3-button right cluster (Detach + Info + PlantLog). For FastSenseWidgets that ALSO have a CreateEventButton (always wired via DashboardEngine.render's CreateEventCallback — see DashboardLayout:1772-1773), the post-reflow 4-button cluster is Detach@barW-28, Create@barW-56, Info@barW-84, PlantLog@barW-112. The initial call to addPlantLogToggle (from realizeWidget) is rescued by reflowChrome_ which runs immediately after and moves L to barW-112. But the **callback re-invocation** of addPlantLogToggle (after a click) does NOT call reflowChrome_, so the new L button is placed at barW-84 — exactly where the InfoIconButton sits — visually covering Info. The InfoIconButton is NOT deleted; it is hidden by z-order overlap.

Probe evidence (/tmp/test_bug_repro2.m, with LiveTimer running):
  After toggle ON+OFF cycle:
    [1] PlantLogToggleButton Position=[686 2 24 24]
    [6] InfoIconButton       Position=[686 2 24 24]   <- same x as L
  Both still present in the handle hierarchy; PlantLog created later sits on top of Info.

fix: Call DashboardLayout.reflowChrome_ at the end of addPlantLogToggle so the canonical 4-button layout is re-applied after each rebuild. reflowChrome_ already knows the correct math (lines 1078-1130) for all button clusters (Info+Detach, Info+Create+Detach, Info+PlantLog+Detach, Info+Create+PlantLog+Detach, plus the V/A YLimit cluster on the left). Using reflowChrome_ keeps the position truth in one place. Wrapped in try/catch so a reflow failure cannot break the toggle.

verification: Verified via:
  1. /tmp/test_bug_repro2.m (live timer running, store attached, toggle ON+OFF cycle): InfoIconButton at [685 2 24 24], PlantLogToggleButton at [657 2 24 24] — distinct positions, no overlap.
  2. New regression test testInfoIconSurvivesToggleOnOff in TestDashboardLayoutPlantLogToggle.m (class-based) — fails on unfixed code with three position mismatches (Detach@barW-28, Info@barW-84, PlantLog@barW-112), passes with fix.
  3. New regression sub-test test_info_icon_survives_toggle_on_off in test_dashboard_layout_plant_log_toggle.m (function-style) — same assertions.
  4. Wider regression sweep (TestDashboardLayoutPlantLogToggle, TestDashboardWidget, TestInfoTooltip, TestFastSenseWidgetPlantLog, TestDashboardLayout): 65/65 PASS.
  5. Pre-existing stale function-style tests test_initial_position_leftmost_of_three and test_reflow_chrome_three_buttons updated to the post-v3.1↔v4.0-merge 4-button-cluster positions (they were already failing before this fix).
  6. The 1 pre-existing flaky test TestDashboardEngine/testTimerContinuesAfterError was confirmed to fail on stashed/unmodified code — unrelated to this fix.

files_changed:
  - libs/Dashboard/DashboardLayout.m  (addPlantLogToggle: call reflowChrome_ after L placement)
  - tests/suite/TestDashboardLayoutPlantLogToggle.m  (add testInfoIconSurvivesToggleOnOff regression test)
  - tests/test_dashboard_layout_plant_log_toggle.m  (add test_info_icon_survives_toggle_on_off; fix two stale tests to use 4-button-cluster math)
