---
phase: 01-infrastructure-hardening
plan: 02
subsystem: Dashboard/GroupWidget/DashboardSerializer
tags: [refactor, normalization, jsondecode, infrastructure, helper-function]
dependency_graph:
  requires: []
  provides: [libs/Dashboard/private/normalizeToCell.m]
  affects:
    - libs/Dashboard/GroupWidget.m
    - libs/Dashboard/DashboardSerializer.m
    - tests/suite/TestDashboardSerializer.m
tech_stack:
  added: []
  patterns: [MATLAB private/ directory helper function, jsondecode struct-to-cell normalization]
key_files:
  created:
    - libs/Dashboard/private/normalizeToCell.m
  modified:
    - libs/Dashboard/GroupWidget.m
    - libs/Dashboard/DashboardSerializer.m
    - tests/suite/TestDashboardSerializer.m
decisions:
  - "normalizeToCell placed in libs/Dashboard/private/ per INFRA-03 spec; accessible to GroupWidget and DashboardSerializer via MATLAB private/ dir convention"
  - "testNormalizeToCellHelper tests normalizeToCell indirectly via DashboardSerializer.loadJSON because MATLAB private/ directories cannot be added to the path from external test files"
metrics:
  duration_seconds: 900
  completed_date: "2026-04-01"
  tasks_completed: 2
  files_modified: 3
requirements: [INFRA-03, COMPAT-02]
---

# Phase 01 Plan 02: normalizeToCell Shared Helper Summary

**One-liner:** Extracted jsondecode struct-array-to-cell normalization into `libs/Dashboard/private/normalizeToCell.m` and replaced three inline isstruct blocks in `GroupWidget.fromStruct` and one in `DashboardSerializer.loadJSON` with single-line calls.

## Tasks Completed

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1 | Create normalizeToCell private helper and write test | 1dbfc6a | Complete |
| 2 | Refactor GroupWidget.fromStruct and DashboardSerializer.loadJSON | e84126a | Complete |

**TDD commits:**
- `1dbfc6a` — `feat(01-02)`: normalizeToCell.m created + testNormalizeToCellHelper added (GREEN)
- `e84126a` — `refactor(01-02)`: inline isstruct blocks replaced with normalizeToCell calls

## What Was Built

### `libs/Dashboard/private/normalizeToCell.m` (new)

Shared helper that normalizes jsondecode output for consistent cell-array indexing:
- Empty input (`[]`) returns `{}`
- Struct array returns 1xN cell array of individual structs
- Cell array is returned unchanged (passthrough)

### `libs/Dashboard/GroupWidget.m` (refactored)

`fromStruct()` now calls `normalizeToCell` at all three nested array points:
- `ch = normalizeToCell(s.children)` — replaces 5-line inline block
- `tb = normalizeToCell(s.tabs)` — replaces 5-line inline block
- `wlist = normalizeToCell(ts.widgets)` — replaces 5-line inline block

### `libs/Dashboard/DashboardSerializer.m` (refactored)

`loadJSON()` now uses:
```matlab
config.widgets = normalizeToCell(config.widgets);
```
replacing a 6-line inline isstruct block.

### `tests/suite/TestDashboardSerializer.m` (updated)

New `testNormalizeToCellHelper` method validates normalizeToCell behavior indirectly through `DashboardSerializer.loadJSON`, testing that `widgets` is returned as a cell array for both single-widget and multi-widget JSON files.

## Test Results

- TestDashboardSerializer: 6/6 passed (including new `testNormalizeToCellHelper`)
- TestGroupWidget: 18/19 passed (1 pre-existing failure in `testFullDashboardIntegration` — JSON syntax error loading .m file as JSON, unrelated to this plan)
- TestDashboardSerializerRoundTrip: 2/3 passed (1 pre-existing failure — row/column vector shape mismatch from jsondecode, unrelated to this plan)

Pre-existing failures confirmed by baseline check: same 2 failures existed before any changes in this plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Adapted test due to MATLAB private/ directory restriction**
- **Found during:** Task 1 (TDD RED/GREEN phases)
- **Issue:** MATLAB explicitly prohibits adding `private/` directories to the path (`addpath` silently ignores them with a warning). The test as specified in the plan called `normalizeToCell([])` directly from `tests/suite/TestDashboardSerializer.m`, which is outside `libs/Dashboard/` and cannot access the private function.
- **Fix:** Rewrote `testNormalizeToCellHelper` to test the same normalization behavior indirectly through `DashboardSerializer.loadJSON`, which IS in `libs/Dashboard/` and can call the private function. The test verifies that `widgets` is returned as a `cell` array after round-tripping through JSON (exercising the exact struct-to-cell normalization path).
- **Files modified:** `tests/suite/TestDashboardSerializer.m`
- **Commit:** 1dbfc6a

## Known Stubs

None.

## Self-Check: PASSED

- `libs/Dashboard/private/normalizeToCell.m` — exists with `function c = normalizeToCell`
- `libs/Dashboard/GroupWidget.m` — contains 3 calls to `normalizeToCell`, no inline `isstruct(ch)`, `isstruct(tb)`, or `isstruct(wlist)` blocks
- `libs/Dashboard/DashboardSerializer.m` — contains 1 call to `normalizeToCell`, no inline isstruct block for config.widgets
- `tests/suite/TestDashboardSerializer.m` — contains `testNormalizeToCellHelper`
- Commits `1dbfc6a` and `e84126a` — verified in git log
- TestDashboardSerializer: 6/6 passed
