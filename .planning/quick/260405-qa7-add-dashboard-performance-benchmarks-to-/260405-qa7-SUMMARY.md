---
phase: quick
plan: 260405-qa7
subsystem: benchmarks
tags: [benchmarks, dashboard, ci, performance]
dependency_graph:
  requires: []
  provides: [dashboard-ci-benchmarks]
  affects: [scripts/run_ci_benchmark.m]
tech_stack:
  added: []
  patterns: [benchmark-section, helper-function]
key_files:
  modified:
    - scripts/run_ci_benchmark.m
decisions:
  - "Used ' mean' suffix on all four dashboard metric names to match existing add_result std-name trimming logic (name(1:end-5) trims ' mean')"
  - "Inlined dashboard construction in build_bench_dashboard_() rather than calling bench_dashboard.m directly for clean function-file scoping"
  - "Used guarded install() — only called if DashboardEngine is not already on the MATLAB class path"
metrics:
  duration: "5min"
  completed: "2026-04-05"
  tasks: 1
  files: 1
---

# Quick Task 260405-qa7: Add Dashboard Performance Benchmarks to CI Summary

**One-liner:** Added 4 dashboard CI benchmark metrics (create+render, live tick, page switch, broadcastTimeRange) to `scripts/run_ci_benchmark.m` with a `build_bench_dashboard_()` helper building a 20-widget 2-page representative dashboard.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Add dashboard benchmark section to run_ci_benchmark.m | 298984d | scripts/run_ci_benchmark.m |

## What Was Built

Added a dashboard benchmark section to `scripts/run_ci_benchmark.m` that:

1. **Guarded `install()` call** at the top of `run_ci_benchmark()` — only fires if `DashboardEngine` is not already on the class path, ensuring Dashboard classes are available without double-initializing.

2. **Four dashboard metrics** with `N_INIT = 3` iterations each:
   - `Dashboard create+render mean` — builds a fresh 20-widget dashboard and times `render()` + `drawnow`
   - `Dashboard live tick mean` — times `onLiveTick()` after 2 warmup iterations
   - `Dashboard page switch mean` — times `switchPage(2)` + `switchPage(1)` round-trip (divided by 2 for per-switch time)
   - `Dashboard broadcastTimeRange mean` — times `broadcastTimeRange()` with random time windows

3. **`build_bench_dashboard_()` helper function** at the bottom of the file encapsulating: 100K-point sinusoidal data, `DashboardEngine('CIBench')`, 6 fastsense widgets (rows 1-3), 4 number widgets (row 4), 4 status widgets (row 5), 2 text widgets (row 6), 1 barchart (row 7), plus page 2 with one number widget for page switch benchmark.

4. **Metric name convention** — all four names end with ` mean` to match the existing `add_result` std-name trimming logic (`name(1:end-5)` trims ` mean`, `name(end-3:end)` appends ` mean` to std entries).

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- `scripts/run_ci_benchmark.m` exists and contains all 4 metric names and `build_bench_dashboard_` definition
- Commit 298984d verified in git log
