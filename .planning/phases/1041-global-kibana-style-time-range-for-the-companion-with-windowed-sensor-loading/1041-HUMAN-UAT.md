---
status: partial
phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
source: [1041-VERIFICATION.md, 1041-MANUAL-VERIFY.md]
started: 2026-06-02
updated: 2026-06-03
---

## Current Test

[Design-change gap RESOLVED. The separate-window picker was replaced by an inline
toolbar control: a preset dropdown (applies instantly) plus a 'Custom…' item that
reveals an in-window relative/absolute editor strip under the toolbar — no separate
figure is ever created. User verified the inline control live on 2026-06-03 ("much
better"), including a follow-up fix to the Custom-strip spacing (overlapping mode
panels). Remaining deep manual checks (empty-state, live-slide, persistence) are
covered by automated tests; the visual checklist in 1041-MANUAL-VERIFY.md was
updated to the inline design and can be re-run as desired.]

## Tests

### 1. Default range control label + color
expected: Toolbar range dropdown (col 9, left of the gear) reads "Last 7 days" with the inactive WidgetBorderColor background when no filter is set.
result: passed

### 2. Dropdown lists presets + Custom…
expected: Opening the dropdown shows six presets (24h / 7d / 30d / 90d / 1y / All data) plus a trailing "Custom…" item. No separate window opens.
result: passed

### 3. Preset applies instantly + label/accent update + re-query
expected: Selecting a preset (e.g. "Last 30 days") applies immediately; dropdown Value updates, background → Accent, and any open dashboard / ad-hoc plot re-queries.
result: passed

### 4. Custom… reveals an inline strip (no separate window)
expected: Selecting "Custom…" reveals an overlay strip under the toolbar INSIDE the companion window (no 'Time Range' figure; figure count unchanged). Relative/Absolute toggle + Apply/Cancel.
result: passed

### 5. Absolute date entry: pickers + validation + apply
expected: Absolute tab shows Start/End date pickers; Start ≥ End disables Apply with red "Invalid: start must be before end"; a valid range applies, closes the strip, and sets a date-string label (e.g. "2026-05-27 to 2026-06-03", Accent).
result: passed

### 6. Relative builder: spinner + unit + apply
expected: Relative tab shows an N spinner + unit dropdown + live preview; Apply commits e.g. "Last 14 days".
result: passed

### 7. Empty-state widget for data outside the window
expected: Opening a tag whose data does not overlap the active window shows a centered "No data in selected range" label (no axes, no crash).
result: pending
note: covered by automated out-of-extent getXYRange tests (test_sensor_tag_range); manual visual optional.

### 8. Relative window slides on live tick; absolute stays fixed
expected: With a relative range + live mode, the right edge tracks wall-clock "now" each tick (label unchanged); switching to an Absolute window keeps it fixed.
result: pending
note: manual-only (requires live ticks); RangeChanged → setTimeWindow re-query covered by TestFastSenseCompanion.

### 9. Theme restyle + persistence across reopen
expected: Switching theme restyles the dropdown (and open strip); reopening the companion restores the last-used range from companionPrefs.
result: pending
note: theme restyle covered by TestCompanionTimeBar; persistence by automated companion tests.

## Summary

total: 9
passed: 6
issues: 0
pending: 3
skipped: 0

## Gaps

- truth: "Time-range selection is integrated into the companion's top toolbar (no separate window)"
  status: resolved
  reason: "User: the picker opened a separate modal window via the 'Last 7 days' button; wanted it integrated in the top bar, not a new window. Follow-up: also wanted a date picker / edit field for direct date entry."
  severity: major
  test: 2
  artifacts: [libs/FastSenseCompanion/CompanionTimeBar.m, tests/suite/TestCompanionTimeBar.m, tests/suite/TestFastSenseCompanion.m]
  resolution: "Reworked CompanionTimeBar from a separate uifigure popup to an inline toolbar uidropdown (six presets, apply-on-select) plus a 'Custom…' item that reveals an in-window overlay strip under the toolbar with a Relative (N + unit) tab and an Absolute (Start/End date pickers) tab, Apply/Cancel. The strip parents to the companion figure (derived via ancestor of the dropdown) — no separate window. Fixed a layout bug where the two mode panels stacked and clipped (now overlap in one host cell). TestCompanionTimeBar rewritten for the dropdown + strip (12/12); TestFastSenseCompanion default-label assertion updated from btn.Text to btn.Value (5/5 range subset). User-verified live 2026-06-03."
