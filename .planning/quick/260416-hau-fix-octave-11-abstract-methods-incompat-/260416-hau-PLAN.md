---
quick_id: 260416-hau
description: Fix Octave 11 abstract methods incompat in DashboardWidget.m
mode: quick
date: 2026-04-16
---

# Quick Task 260416-hau: Octave 11 Abstract Methods Fix

## Objective

Restore Octave 11.x compatibility for the entire Dashboard subsystem by replacing the `methods (Abstract)` block in `libs/Dashboard/DashboardWidget.m` with a regular `methods` block of error-throwing stubs.

## Background

Octave 11.1.0 has a parser regression that rejects abstract method signatures outside of `@`-class folders. Reproduces with the minimal case:

```matlab
classdef Foo < handle
    methods (Abstract)
        doThing(obj)
    end
end
```

→ `error: external methods are only allowed in @-folders`

This blocks the entire Dashboard subsystem (every test that constructs `DashboardEngine` fails to load `DashboardWidget`). MATLAB and Octave 7–10 are unaffected.

The codebase has exactly one file with `methods (Abstract)` — `libs/Dashboard/DashboardWidget.m:144-148`.

All ~20 subclasses already implement `render`, `refresh`, and `getType`, so the runtime behavior is preserved — the trade-off is losing MATLAB's compile-time abstract enforcement (subclass that forgets to override would error at first call rather than at construction).

## Task 1: Convert abstract methods to error-throwing concrete stubs

### read_first
- libs/Dashboard/DashboardWidget.m (current state of abstract methods block)

### action

Replace lines 144–148 of `libs/Dashboard/DashboardWidget.m`:

```matlab
    methods (Abstract)
        render(obj, parentPanel)
        refresh(obj)
        t = getType(obj)
    end
```

with:

```matlab
    % NOTE: Conceptually abstract — every subclass MUST override these methods.
    % We declare concrete error-throwing stubs instead of `methods (Abstract)`
    % because Octave 11.1.0 has a parser regression that rejects abstract
    % method signatures outside of @-class folders ("external methods are
    % only allowed in @-folders"). MATLAB and Octave 7–10 accept the
    % abstract form; the workaround below is universally compatible.
    % Trade-off: subclass that forgets to override now errors at first call
    % instead of at construction. All current subclasses implement these
    % methods so runtime behavior is preserved for valid usage.
    methods
        function render(~, ~)
            error('DashboardWidget:notImplemented', ...
                'render(obj, parentPanel) must be overridden by subclass.');
        end

        function refresh(~)
            error('DashboardWidget:notImplemented', ...
                'refresh(obj) must be overridden by subclass.');
        end

        function t = getType(~) %#ok<STOUT>
            error('DashboardWidget:notImplemented', ...
                'getType(obj) must be overridden by subclass.');
        end
    end
```

### acceptance_criteria

1. `grep -c 'methods (Abstract)' libs/Dashboard/DashboardWidget.m` returns 0 (block removed).
2. `grep -c 'DashboardWidget:notImplemented' libs/Dashboard/DashboardWidget.m` returns ≥3 (one per stub).
3. `grep -c 'function render(~, ~)' libs/Dashboard/DashboardWidget.m` returns 1.
4. `grep -c 'function refresh(~)' libs/Dashboard/DashboardWidget.m` returns 1.
5. `grep -c 'function t = getType(~)' libs/Dashboard/DashboardWidget.m` returns 1.
6. `octave --eval "addpath('libs/Dashboard'); mc = meta.class.fromName('DashboardWidget'); fprintf('ok: %s\n', mc.Name)"` prints `ok: DashboardWidget` with no error.
7. `octave --eval "addpath(pwd); install(); cd tests; test_dashboard_toolbar_image_export()"` runs the phase 1004 Octave test suite (previously blocked by this parser bug). Exit status 0 with all 4 Octave-safe tests passing.
8. The DashboardWidget.m line count grows by ~17–20 (added stub bodies + comment block).

## Must-haves

- All 9 phase 1004 Octave tests can now load DashboardEngine successfully (no parser error)
- `DashboardWidget:notImplemented` error ID exists and is raised by all three stubs
- Behavior preserved for valid subclasses (every subclass already implements these methods, so their normal usage is unchanged)
- Octave 7+, Octave 11+, and MATLAB R2020b+ all parse the file without error

## Task 2 (followup): Fix phase 1004 test property-name bug

### Background

While verifying Task 1 on Octave, the phase 1004 test suites surfaced a separate bug introduced during phase 1004 execution: both test files use `'Value', N` when constructing NumberWidget, but NumberWidget has no `Value` property — its name-value constructor accepts `'StaticValue'` (fixed value) or `'ValueFcn'` (callable). MATLAB and Octave both reject unknown property assignments on handle classes, so this would have failed on either runtime.

### read_first
- libs/Dashboard/NumberWidget.m (confirms property names: ValueFcn, Units, Format, StaticValue)
- tests/suite/TestDashboardToolbarImageExport.m (uses `'Value'` 8 times — needs replacement)
- tests/test_dashboard_toolbar_image_export.m (uses `'Value'` 4 times — needs replacement)

### action

In both test files, replace every occurrence of `'Value', N` (in NumberWidget addWidget calls) with `'StaticValue', N`.

### acceptance_criteria

1. `grep -c "'Value'" tests/suite/TestDashboardToolbarImageExport.m` returns 0.
2. `grep -c "'Value'" tests/test_dashboard_toolbar_image_export.m` returns 0.
3. `grep -c "'StaticValue'" tests/suite/TestDashboardToolbarImageExport.m` returns 8.
4. `grep -c "'StaticValue'" tests/test_dashboard_toolbar_image_export.m` returns 4.
5. Octave runs the flat suite end-to-end with 4/4 tests passing: `octave --eval "addpath(pwd); install(); cd tests; test_dashboard_toolbar_image_export()"` exits 0 with `4 passed, 0 failed`.

## Verification commands

```bash
# 1. Octave 11 can load the class
octave --eval "addpath('libs/Dashboard'); mc = meta.class.fromName('DashboardWidget'); fprintf('CLASS_OK: %s\n', mc.Name)" 2>&1 | grep CLASS_OK

# 2. Phase 1004 Octave tests run
octave --eval "addpath(pwd); install(); cd tests; test_dashboard_toolbar_image_export()" 2>&1 | tail -5

# 3. Existing widget creation still works (smoke test for runtime behavior)
octave --eval "addpath(pwd); install(); w = NumberWidget('Title','Test','Position',[1 1 6 2],'Value',42); fprintf('TYPE: %s\n', w.getType())"
```
