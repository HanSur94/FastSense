---
status: partial
phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
source: [1041-VERIFICATION.md, 1041-MANUAL-VERIFY.md]
started: 2026-06-02
updated: 2026-06-02
---

## Current Test

[awaiting human testing — deferred by user decision ("finalize now, defer visual"); run the steps below in a live MATLAB session via `/gsd:verify-work 1041`]

## Tests

### 1. Default range button label + color
expected: Toolbar range button (left of the gear) reads "Last 7 days" with the inactive WidgetBorderColor background (no Accent — no filter set yet).
result: [pending]

### 2. Picker opens; three tabs; Quick active
expected: Clicking the button opens a 400x280 "Time Range" popup with Quick/Relative/Absolute tabs; Quick active; six presets listed; "Last 7 days" preset highlighted; Apply hidden in Quick; non-modal.
result: [pending]

### 3. One-click quick apply + label update + re-query
expected: Clicking "Last 30 days" closes the popup immediately, button text → "Last 30 days", background → Accent, and any open dashboard/ad-hoc plot re-queries to the last 30 days.
result: [pending]

### 4. Relative builder: live preview + Apply
expected: Relative tab shows spinner (N) + unit dropdown + live preview label that updates as N/unit change; Apply closes popup and updates the button label (e.g. "Last 14 weeks") and re-queries open views.
result: [pending]

### 5. Absolute tab: validation + valid apply
expected: Two date pickers; Start > End disables Apply and shows "Invalid: start must be before end" in red; a valid range enables Apply and sets a date-string button label (e.g. "2026-06-02 to 2026-06-04").
result: [pending]

### 6. Empty-state widget for data outside the window
expected: Opening an ad-hoc plot for a tag whose data does not overlap the active window shows a centered bold "No data in selected range" label (no axes, no crash).
result: [pending]

### 7. Relative window slides on live tick; absolute stays fixed
expected: With a "Last 7 days" relative range and live mode on, the right edge tracks wall-clock "now" each tick with no flicker and the label stays "Last 7 days"; switching to an Absolute window keeps the window fixed across live ticks.
result: [pending]

### 8. Theme restyle of the range button (and popup)
expected: Switching theme via Settings restyles the range button (and the popup if open) to the new theme colors.
result: [pending]

### 9. Persistence across reopen
expected: After setting a non-default range and reopening the companion, the button reads the last-used range (Accent) and currentTimeWindow() returns the restored span — loaded from companionPrefs.
result: [pending]

## Summary

total: 9
passed: 0
issues: 0
pending: 9
skipped: 0
blocked: 0

## Gaps
