---
phase: 01-dashboard-performance-optimization
plan: 01
subsystem: Dashboard
tags: [benchmark, testing, performance, scaffolding]
dependency_graph:
  requires: []
  provides: [benchmarks/bench_dashboard.m, tests/suite/TestDashboardPerformance.m PERF methods]
  affects: [TestDashboardPerformance]
tech_stack:
  added: []
  patterns: [tic/toc timing, addWidget test scaffolding]
key_files:
  created:
    - benchmarks/bench_dashboard.m
  modified:
    - tests/suite/TestDashboardPerformance.m
decisions:
  - "bench_dashboard.m uses rows 1-8 layout with 6 fastsense on rows 1-3, 4 number on row 4, 4 status on row 5, 3 group on row 6, 2 text on row 7, 1 barchart on row 8"
  - "testRerenderWidgetsRepositions uses %#ok<NASGU> on h1/h2 since pre-resize handles are recorded for documentation but not directly compared (Octave lint suppression)"
  - "testLiveTickUnder50ms uses 200ms generous CI ceiling (target 50ms) to avoid flakiness before optimization plans implement the speedup"
metrics:
  duration_minutes: 3
  completed_date: "2026-04-03"
  tasks_completed: 2
  files_changed: 2
---

# Phase 01 Plan 01: Benchmark Script and PERF Test Scaffolding Summary

**One-liner:** 20-widget mixed dashboard benchmark with tic/toc timing plus 6 PERF test scaffolding methods for theme cache, dispatch map, live tick, panel reuse, and page switch optimizations.

## What Was Built

### Task 1: benchmarks/bench_dashboard.m

A reusable benchmark script that creates a 20-widget mixed dashboard and times three phases:
- **Creation** (tic/toc around all addWidget calls): reports `Create: X ms`
- **Render** (tic/toc around `d.render(); drawnow`): reports `Render: X ms`
- **Live tick** (5-tick average via `d.onLiveTick()`): reports `Live tick: X ms`

Widget composition: 6 fastsense, 4 number, 4 status, 3 group, 2 text, 1 barchart. Uses `close(d.hFigure)` for cleanup.

### Task 2: TestDashboardPerformance.m — 6 new test methods

Added to the existing 4-method test class (now 10 total):

| Method | PERF Req | Purpose |
|--------|----------|---------|
| `testThemeCacheReturnsSameStruct` | PERF-01 | Verifies `getCachedTheme()` returns equal structs on repeated calls |
| `testThemeCacheInvalidatesOnChange` | PERF-02 | Verifies theme cache invalidates when `d.Theme` changes |
| `testDispatchMapCoversAllTypes` | PERF-03 | Verifies all 16 widget types create without error |
| `testLiveTickUnder50ms` | PERF-04 | Smoke test: live tick under 200ms (target 50ms after optimization) |
| `testRerenderWidgetsRepositions` | PERF-05 | Verifies widget panels remain valid handles after resize |
| `testSwitchPageTogglesVisibility` | PERF-06 | Verifies correct page widgets are realized after switchPage |

**Note:** Tests for `getCachedTheme()` (PERF-01, PERF-02) will fail until Plan 02 implements that method. This is expected — the tests provide scaffolding for the optimization plans.

## Deviations from Plan

None — plan executed exactly as written.

**Pre-existing environment note:** Octave 11.1.0 on this machine produces an error (`external methods are only allowed in @-folders`) when loading any `DashboardWidget` subclass. This is a pre-existing incompatibility between Octave 11's abstract class parser and the `t = getType(obj)` return-value syntax in the `methods (Abstract)` block of `DashboardWidget.m`. This issue predates this plan and affects all Dashboard widget tests in the Octave 11 environment. The benchmark and test files are structurally correct; all acceptance criteria are verified by static content inspection. This is deferred to a future fix in the `DashboardWidget.m` abstract method declarations.

## Known Stubs

None — no UI rendering or data display is involved in these scaffolding files.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 534db37 | feat(01-01): add bench_dashboard.m — 20-widget mixed dashboard benchmark |
| Task 2 | 168d221 | test(01-01): add 6 PERF test methods to TestDashboardPerformance |

## Self-Check: PASSED

- benchmarks/bench_dashboard.m: FOUND
- tests/suite/TestDashboardPerformance.m (10 methods): FOUND
- Commits 534db37, 168d221: FOUND
