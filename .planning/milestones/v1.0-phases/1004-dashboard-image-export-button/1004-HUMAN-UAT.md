---
status: partial
phase: 1004-dashboard-image-export-button
source: [1004-VERIFICATION.md]
started: 2026-04-15T00:00:00Z
updated: 2026-04-15T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Visual quality of MATLAB PNG export
expected: Exported image visually matches the dashboard — correct theme colors, widget text readable, no clipping or blank regions. Anti-aliasing acceptable at 150 DPI.
result: [pending]
how_to_test: Open a rendered dashboard in MATLAB, click the Image button, save as PNG, open the file in an image viewer.

### 2. MATLAB test-suite pass
expected: `matlab -batch "cd tests; runtests('suite/TestDashboardToolbarImageExport.m')"` reports 9/9 tests green. Octave 11.1.0 suite cannot run locally due to pre-existing DashboardWidget abstract-method incompat (unrelated to Phase 1004).
result: [pending]
how_to_test: Run the command on a machine with MATLAB R2020b+ installed, or wait for CI to run the full suite under the supported Octave 7+ version.

### 3. Octave platform difference acknowledgment
expected: Octave `print()` excludes uicontrols from the PNG output — toolbar buttons are NOT captured. MATLAB includes them. This documented platform difference is acceptable per CONTEXT.md (capture "whole figure" accepting platform variance). `hImageBtn` is still created in both runtimes — only the visual output differs.
result: [pending]
how_to_test: On a machine with working Octave 7+ (not 11 locally due to preexisting incompat), render a dashboard, confirm the toolbar includes the Image button, click Save as image, and note that the PNG omits the toolbar — this is expected.

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
