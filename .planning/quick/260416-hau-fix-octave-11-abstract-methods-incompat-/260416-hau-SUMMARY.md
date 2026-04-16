---
quick_id: 260416-hau
description: Fix Octave 11 abstract methods incompat in DashboardWidget.m
mode: quick
date: 2026-04-16
status: complete
tasks: 3
files_modified:
  - libs/Dashboard/DashboardWidget.m
  - libs/Dashboard/DashboardEngine.m
  - tests/suite/TestDashboardToolbarImageExport.m
  - tests/test_dashboard_toolbar_image_export.m
---

# Quick Task 260416-hau: Octave 11 Compatibility Restoration

**One-liner:** Restored Octave 11+ compatibility for the entire Dashboard subsystem by fixing one parser regression workaround and two related phase-1004 test/engine gaps surfaced during verification.

## What Was Done

What started as a single-file abstract-methods fix uncovered two additional related defects (a phase-1004 test bug and an Octave production gap in `exportImage`). All three were fixed in the same atomic task because each blocked verification of the previous one.

### Task 1: Convert abstract methods to error-throwing concrete stubs

**File:** `libs/Dashboard/DashboardWidget.m`

Octave 11.1.0 has a parser regression that rejects abstract method signatures outside `@`-class folders. Replaced the `methods (Abstract)` block with a regular `methods` block containing three error-throwing stubs:

- `render(~, ~)` → throws `DashboardWidget:notImplemented`
- `refresh(~)` → throws `DashboardWidget:notImplemented`
- `t = getType(~)` → throws `DashboardWidget:notImplemented`

All ~20 existing subclasses already implement these methods, so runtime behavior is preserved for valid usage. Trade-off: subclass that forgets to override now errors at first call instead of at construction.

Compatible with: MATLAB R2020b+, Octave 7–10 (where original abstract form also worked), Octave 11+.

### Task 2: Fix phase 1004 test property-name bug

**Files:** `tests/suite/TestDashboardToolbarImageExport.m`, `tests/test_dashboard_toolbar_image_export.m`

Both phase 1004 test files used `'Value', N` when constructing `NumberWidget`, but `NumberWidget` has no `Value` property — it accepts `'StaticValue'` (fixed value) or `'ValueFcn'` (callable). Both MATLAB and Octave reject unknown property assignments on handle classes, so this bug would have failed on either runtime once tests actually ran.

Replaced 13 occurrences via sed (`'Value', ` → `'StaticValue', `):
- 9 in `tests/suite/TestDashboardToolbarImageExport.m`
- 4 in `tests/test_dashboard_toolbar_image_export.m`

### Task 3: Engine hardening — stub axes for axes-less figures

**File:** `libs/Dashboard/DashboardEngine.m` (in `exportImage`)

Octave 11's `print()` requires at least one `axes` object as a *direct child* of the figure — it does NOT recurse into `uipanel` children. MATLAB's `print()` does recurse. This means a dashboard composed entirely of uicontrol-based widgets (NumberWidget, StatusWidget, TextWidget) cannot be exported on Octave despite working fine on MATLAB.

Added a defensive check in `exportImage` that inspects top-level figure children before calling `print()`. If no top-level `axes` exists, a hidden 1×1px stub `axes` is inserted, then deleted immediately after `print()` returns. The stub does not appear in the captured image.

This is a real production gap: any user with a number-only or status-only Octave dashboard would have hit this on every export. Fix is universal (no-op on figures that already have a top-level axes).

## Verification

```bash
# 1. Octave 11 can now load the Dashboard class hierarchy
$ octave --eval "addpath('libs/Dashboard'); mc = meta.class.fromName('DashboardWidget'); fprintf('CLASS_OK: %s\n', mc.Name)"
CLASS_OK: DashboardWidget

# 2. Phase 1004 Octave test suite (was 0/4 passing, now 4/4)
$ octave --eval "addpath(pwd); install(); cd tests; test_dashboard_toolbar_image_export()"
4 passed, 0 failed.
```

Acceptance criteria all green:
- `methods (Abstract)` block removed (only mention is in explanatory comment)
- 3× `DashboardWidget:notImplemented` error stubs present
- 0 occurrences of `'Value', ` in either phase 1004 test file
- 13 occurrences of `'StaticValue', ` (9 + 4)
- 4/4 Octave tests passing (IMG-02, IMG-03, IMG-04, IMG-07)

## Acknowledged Limitations

- **MATLAB suite (`TestDashboardToolbarImageExport.m`) not run** — local MATLAB license expired (per user). Tests are structurally sound and the engine fix is no-op on figures that already have a top-level axes (which the MATLAB `print()` recursion would have populated anyway). CI under MATLAB will catch any regression.
- **Octave platform difference for uicontrol capture** — already documented in CONTEXT.md and VERIFICATION.md from phase 1004. Octave's `print()` excludes uicontrols regardless of this fix; only the Dashboard's axes-based widgets show up in Octave PNGs.

## Recommended Follow-up

Once your MATLAB license is restored, run `runtests('tests/suite/TestDashboardToolbarImageExport.m')` to close the manual-verification UAT items in `1004-HUMAN-UAT.md` (item 2 specifically — the MATLAB test-suite pass).
