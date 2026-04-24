---
status: resolved
phase: 1012-live-event-markers-and-click-to-details-on-fastsense-and-fastsensewidget
source: [1012-VERIFICATION.md]
started: 2026-04-24T10:05:00Z
updated: 2026-04-24T11:00:00Z
resolved: 2026-04-24T11:00:00Z
resolved_by: user (interactive run of example_event_markers.m; all four scenarios confirmed green)
---

## Current Test

[awaiting human testing]

## Tests

### 1. Click-details uipanel anchors near clicked marker without off-screen clipping
expected: uipanel appears adjacent to the marker and fully within the figure boundary on both 1440×900 and 2560×1440 figures
result: passed
how: Run `example_event_markers.m`, wait until an event marker appears, click it. Verify the details panel opens next to the marker and is fully inside the figure. Repeat once on a small figure and once on a large figure.

### 2. Click-outside-dismiss works correctly while axes zoom mode is active
expected: Click outside the details panel closes the panel even when MATLAB zoom toolbar is engaged
result: passed
how: Open the example, click the zoom button in the axes toolbar, then click a marker, then click anywhere else in the figure. Panel must close; zoom mode must remain active (cursor stays as magnifier).

### 3. Open-to-closed visual transition on live demo (hollow-to-filled marker)
expected: Running `example_event_markers.m` produces a visible hollow circle marker that becomes a filled circle after the falling edge of the event
result: passed
how: Run the example with live-mode enabled (or the intentionally-long simulated threshold violation in the script). Observe the marker appears hollow during the open window, then re-renders as filled when the event closes.

### 4. Multi-widget Octave scenario with two FastSenseWidgets sharing one EventStore
expected: Both widgets refresh independently without cross-contamination of `LastEventIds_` cache; clicking a marker in widget A does not open a panel in widget B
result: passed
how: In an interactive Octave session, build a `DashboardEngine` with two `FastSenseWidget` instances pointing at different Tags but sharing a single `EventStore`. Trigger events on both Tags. Click a marker in widget A, verify panel opens in widget A only; dismiss; click a marker in widget B, verify the same.

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None — user confirmed all four manual scenarios during interactive UAT.
Post-verification polish (17 commits in the same session) also shipped:

- Example runtime fixes (`DashboardEngine` positional arg, `SensorTag.updateData`
  vs `MonitorTag.appendData`, Y-axis autoscale)
- Event details popup refit:
  `uipanel` → separate `figure` (OS-native drag/close); light theme + standard
  font; editable Notes persisted to `Event.Notes` + `EventStore.save()` on disk
- Section-grouped `uitable` field listing with resize-aware column widths
- Two-sensor example (pump sustained + motor multi-spike) sharing one EventStore
- TrendMiner-style markers: white badge, soft drop shadow, `!` glyph,
  severity-based color (green/orange/red); widget-level severity diff so
  late severity mutations trigger a re-render
- Event-marker z-order hardened against loupe overwrite + zoom interception
- Event marker Y positioned via `tag.valueAt(startTime)` (not `interp1`)
