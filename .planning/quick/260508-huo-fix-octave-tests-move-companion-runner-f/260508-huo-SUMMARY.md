---
phase: quick-260508-huo
plan: 01
subsystem: FastSenseCompanion / Dashboard
tags: [ci-fix, octave, matlab, headless, private-folder, segfault]
dependency_graph:
  requires: []
  provides:
    - libs/FastSenseCompanion/runFilterDashboardsTests.m (Octave-reachable runner)
    - libs/FastSenseCompanion/runInspectorResolveStateTests.m (Octave-reachable runner)
    - libs/FastSenseCompanion/runOpenAdHocPlotTests.m (Octave-reachable runner)
    - libs/Dashboard/DashboardEngine.m (web() guarded behind interactive-session check)
  affects:
    - Octave CI (tests/test_companion_filter_dashboards.m)
    - Octave CI (tests/test_companion_inspector_resolve_state.m)
    - Octave CI (tests/test_companion_open_ad_hoc_plot.m)
    - MATLAB CI (TestDashboardInfo suite)
tech_stack:
  added: []
  patterns:
    - Inline isInteractiveSession guard (usejava + batchStartupOptionUsed) mirroring DashboardProgress
    - git mv for history-preserving file relocation
key_files:
  created: []
  modified:
    - libs/FastSenseCompanion/runFilterDashboardsTests.m (moved from private/)
    - libs/FastSenseCompanion/runInspectorResolveStateTests.m (moved from private/)
    - libs/FastSenseCompanion/runOpenAdHocPlotTests.m (moved from private/)
    - libs/Dashboard/DashboardEngine.m (web() guarded)
decisions:
  - "Inline guard in DashboardEngine.writeAndOpenInfoHtml rather than extracting shared utility — keeps change tight and independently revertable"
  - "git mv used for runner relocation — preserves git history through the rename"
  - "No content changes to runner files — private/ helper resolution works from parent folder automatically"
metrics:
  duration: ~10m
  completed: 2026-05-08
  tasks: 3
  files: 4
---

# Quick Task 260508-huo: Fix Octave Tests + Move Companion Runner Helpers — Summary

Two surgical CI fixes to unblock the red Octave Tests and MATLAB Tests jobs on Linux runners (failed run id: 25550691546).

## What Was Done

### Task 1 — Hoist companion test-runner helpers out of private/

Three runner files were moved (via `git mv`) from `libs/FastSenseCompanion/private/` to `libs/FastSenseCompanion/`:

- `runFilterDashboardsTests.m`
- `runInspectorResolveStateTests.m`
- `runOpenAdHocPlotTests.m`

Root cause: MATLAB's `private/` folder rule makes functions inside `private/` callable only from functions in the parent folder — not from `tests/`. The Octave CI test files (`test_companion_filter_dashboards.m`, `test_companion_inspector_resolve_state.m`, `test_companion_open_ad_hoc_plot.m`) called these runner functions by name after `install()` added `libs/FastSenseCompanion/` to the path. With the runners inside `private/`, they were invisible from `tests/`.

Fix: moved the runners to `libs/FastSenseCompanion/` (the parent of `private/`), mirroring the already-working sibling `runFilterTagsTests.m`. The private helpers (`filterDashboards`, `inspectorResolveState`, `openAdHocPlot`) remain in `private/` and are still reachable from the runners because the runners now sit in the parent of `private/`. No content changes to any runner file.

**Commit:** `6807f57`

### Task 2 — Guard web() in DashboardEngine.writeAndOpenInfoHtml

Added an inline `isInteractiveSession` check in `libs/Dashboard/DashboardEngine.m` around the `web(obj.InfoTempFile, '-new')` call.

Root cause: Under `-batch -nodisplay` on the Linux MATLAB CI runner, calling `web()` destabilised the JVM/MEX loader. The crash dump showed `dlclose -> utUnloadLibrary -> mdClearFunctionsByTimestamp` triggered by JVM bootstrapping inside a headless session.

Fix: The `web()` call is now guarded by:
```matlab
interactive = usejava('desktop');
if interactive && exist('batchStartupOptionUsed', 'builtin') && ...
        batchStartupOptionUsed()
    interactive = false;
end
if interactive
    web(obj.InfoTempFile, '-new');
end
```

This mirrors the existing `DashboardProgress.isInteractiveSession` pattern. The temp HTML file is still written unconditionally (required by `TestDashboardInfo`'s `exist(d.InfoTempFile, 'file') == 2` assertion); only the browser launch is gated.

**Commit:** `62b99ab`

### Task 3 — PR opened against main

Branch pushed to origin and PR opened: https://github.com/HanSur94/FastSense/pull/113

## Deviations from Plan

None — plan executed exactly as written.

## Confirmation: No Local Test Execution

No MATLAB or Octave tests were run locally. Verification was limited to MISS_HIT static checks (`mh_style`, `mh_lint`, `mh_metric --ci`) on both `libs/FastSenseCompanion/` and `libs/Dashboard/`, all of which passed clean.

## Note for Human Reviewer

Verify both CI jobs go green on the PR before merging:

- Octave Tests (Linux): `test_companion_filter_dashboards`, `test_companion_inspector_resolve_state`, `test_companion_open_ad_hoc_plot`
- MATLAB Tests (Linux): `TestDashboardInfo` no longer segfaults
- MATLAB Tests (macOS/interactive): `TestDashboardInfo` still passes (web() not gated on interactive sessions)

## Self-Check: PASSED

- `libs/FastSenseCompanion/runFilterDashboardsTests.m` — exists at parent level
- `libs/FastSenseCompanion/runInspectorResolveStateTests.m` — exists at parent level
- `libs/FastSenseCompanion/runOpenAdHocPlotTests.m` — exists at parent level
- `libs/Dashboard/DashboardEngine.m` — contains `usejava('desktop')` and `batchStartupOptionUsed` guards
- Commit `6807f57` — on branch
- Commit `62b99ab` — on branch
- PR `https://github.com/HanSur94/FastSense/pull/113` — OPEN, non-draft, base: main
