---
status: partial
phase: 1012-live-event-markers-and-click-to-details-on-fastsense-and-fastsensewidget
source: [1012-VERIFICATION.md]
started: 2026-04-24T10:05:00Z
updated: 2026-04-24T10:05:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Click-details uipanel anchors near clicked marker without off-screen clipping
expected: uipanel appears adjacent to the marker and fully within the figure boundary on both 1440×900 and 2560×1440 figures
result: [pending]
how: Run `example_event_markers.m`, wait until an event marker appears, click it. Verify the details panel opens next to the marker and is fully inside the figure. Repeat once on a small figure and once on a large figure.

### 2. Click-outside-dismiss works correctly while axes zoom mode is active
expected: Click outside the details panel closes the panel even when MATLAB zoom toolbar is engaged
result: [pending]
how: Open the example, click the zoom button in the axes toolbar, then click a marker, then click anywhere else in the figure. Panel must close; zoom mode must remain active (cursor stays as magnifier).

### 3. Open-to-closed visual transition on live demo (hollow-to-filled marker)
expected: Running `example_event_markers.m` produces a visible hollow circle marker that becomes a filled circle after the falling edge of the event
result: [pending]
how: Run the example with live-mode enabled (or the intentionally-long simulated threshold violation in the script). Observe the marker appears hollow during the open window, then re-renders as filled when the event closes.

### 4. Multi-widget Octave scenario with two FastSenseWidgets sharing one EventStore
expected: Both widgets refresh independently without cross-contamination of `LastEventIds_` cache; clicking a marker in widget A does not open a panel in widget B
result: [pending]
how: In an interactive Octave session, build a `DashboardEngine` with two `FastSenseWidget` instances pointing at different Tags but sharing a single `EventStore`. Trigger events on both Tags. Click a marker in widget A, verify panel opens in widget A only; dismiss; click a marker in widget B, verify the same.

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
