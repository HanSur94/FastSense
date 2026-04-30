---
phase: "1023"
plan: "01"
subsystem: demo-integration
tags: [demo, companion, integration, teardown, lifecycle]
dependency_graph:
  requires: []
  provides: [buildCompanion, run_demo-companion-option, teardownDemo-companion-section, demoClose_-cascade]
  affects: [demo/industrial_plant/run_demo.m, demo/industrial_plant/teardownDemo.m, demo/industrial_plant/private/buildDashboard.m, demo/industrial_plant/private/buildCompanion.m]
tech_stack:
  added: []
  patterns: [ctx-struct-extension, best-effort-try-catch, varargin-switch-parser, isfield-isempty-isvalid-guard]
key_files:
  created:
    - demo/industrial_plant/private/buildCompanion.m
  modified:
    - demo/industrial_plant/run_demo.m
    - demo/industrial_plant/teardownDemo.m
    - demo/industrial_plant/private/buildDashboard.m
decisions:
  - "Theme hardcoded to 'dark' in buildCompanion; no parameterization ahead of need"
  - "ctx.companion = [] (not missing) when Companion=false so isfield guards work downstream"
  - "companion.close() called in demoClose_ BEFORE teardownDemo; teardownDemo section is belt-and-braces"
  - "No Registry passed explicitly — FastSenseCompanion defaults to TagRegistry singleton already populated by registerPlantTags"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-29"
  tasks_completed: 4
  tasks_total: 4
  files_created: 1
  files_modified: 3
---

# Phase 1023 Plan 01: Industrial Plant Demo Companion Integration Summary

Wire FastSenseCompanion v3.0 into the industrial plant demo as a milestone canary — `install(); ctx = run_demo()` now opens both the 6-page dashboard and a companion window side-by-side, and closing the dashboard closes both.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | buildCompanion.m — private helper | ffe7593 | demo/industrial_plant/private/buildCompanion.m (NEW) |
| 2 | run_demo.m — 'Companion' NV-pair + ctx.companion | 9fede5d | demo/industrial_plant/run_demo.m |
| 3 | teardownDemo.m — companion close section | f07869c | demo/industrial_plant/teardownDemo.m |
| 4 | buildDashboard.m — demoClose_ cascade | dfdcb55 | demo/industrial_plant/private/buildDashboard.m |

## What Was Built

### buildCompanion.m (NEW)

Private helper in `demo/industrial_plant/private/` mirroring the sibling `buildDashboard.m` pattern. Single-statement body: delegates to `FastSenseCompanion('Dashboards', {ctx.engine}, 'Theme', 'dark')`. Theme hardcoded to 'dark'; Registry defaulted to TagRegistry singleton (already populated by `registerPlantTags`). No error wrapping — FastSenseCompanion errors propagate cleanly.

### run_demo.m changes

- Signature changed from `function ctx = run_demo()` to `function ctx = run_demo(varargin)`
- Explicit `for k=1:2:numel(varargin)` switch parser (matches FastSenseCompanion's convention)
- `useCompanion = true` default — zero-arg `run_demo()` still works and now opens companion by default
- Throws `run_demo:unknownOption` on unknown keys (fast-fail before side-effect work)
- `ctx` struct gains `'companion', []` field initialized at construction
- `ctx.companion = buildCompanion(ctx)` after `buildDashboard` returns (ctx.engine is live at that point)
- `ctx.companion = []` when `Companion=false` (field present, not missing)
- Docstring updated with Options block, companion field in Returns, and suppress example

### teardownDemo.m changes

- New `% ---- Companion (Phase 1023) ----` section inserted between Dashboard engine cleanup and Final TagRegistry.clear
- `isfield(ctx, 'companion') && ~isempty(ctx.companion)` outer guard
- `isvalid(ctx.companion)` inner check before calling `close()`
- Wrapped in best-effort try/catch — idempotent (companion.close() is Phase 1018-locked idempotent)
- Docstring updated to list companion field

### buildDashboard.m demoClose_ changes

- Companion-close block inserted BEFORE existing `teardownDemo(ctx)` call
- `isfield(ctx, 'companion') && ~isempty(ctx.companion) && isvalid(ctx.companion)` three-step guard
- Best-effort try/catch around `ctx.companion.close()`
- Order: `companion.close()` → `teardownDemo(ctx)` → `delete(fig)`
- Main `buildDashboard` function unchanged; `engine.startLive()` preserved

## Lifecycle Design

**Dashboard close → companion close:** YES. `demoClose_` calls `ctx.companion.close()` via public API before `teardownDemo`. Teardown companion section is belt-and-braces.

**Companion close → dashboard close:** NO (by design). Companion close is independent; dashboard keeps running.

**Idempotency:** `companion.close()` can fire twice (demoClose_ + teardownDemo) safely — Phase 1018 locked this.

**`Companion=false`:** `ctx.companion = []` (field present, empty). `~isempty` guards in demoClose_ and teardownDemo skip the close call cleanly.

## Deviations from Plan

None — plan executed exactly as written. The `FastSenseCompanion('Dashboards'` grep in verification section uses a single-line pattern but the actual call spans two lines with `...` continuation (verbatim from plan's VERBATIM spec). Functionally correct and matches the plan's intent precisely.

## Known Stubs

None. All wiring is complete. ctx.companion is populated with a live handle (when Companion=true) or [] (when false). No placeholder data flows to UI rendering.

## Self-Check: PASSED

Files verified on disk:
- demo/industrial_plant/private/buildCompanion.m: FOUND
- demo/industrial_plant/run_demo.m: FOUND
- demo/industrial_plant/teardownDemo.m: FOUND
- demo/industrial_plant/private/buildDashboard.m: FOUND

Commits verified:
- ffe7593: FOUND (buildCompanion.m)
- 9fede5d: FOUND (run_demo.m)
- f07869c: FOUND (teardownDemo.m)
- dfdcb55: FOUND (buildDashboard.m)
