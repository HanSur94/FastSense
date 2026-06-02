---
phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
plan: "05"
subsystem: tests
tags: [matlab, octave, companion, time-range, uifigure, tests, verification, gap-closure]

# Dependency graph
requires:
  - phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
    provides: Tag.getXYRange windowed contract (Plan 01)
  - phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
    provides: CompanionTimeRange (Plan 02)
  - phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
    provides: DashboardEngine.setTimeWindow + FastSenseWidget windowed pull (Plan 03)
  - phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
    provides: CompanionTimeBar + companion wiring (Plan 04)
provides:
  - TestCompanionTimeBar.m — 8 MATLAB-only UI smoke tests for the picker
  - SpyTimeWindowEngine.m — setTimeWindow-recording DashboardEngine double
  - TestFastSenseCompanion.m — 5 new global-time-range integration tests
  - 1041-MANUAL-VERIFY.md — 9-step human visual checklist (deferred to live session)
affects:
  - phase verification (this plan locks the feature behind automated tests + a human checklist)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Handle-type event counter (containers.Map mutated by a local helper) — anonymous listener callbacks cannot assign into the test workspace"
    - "Prefs isolation in tests: armCleanDefaultPrefs_ (backup+delete+restore) for default-asserting tests; backupAndArmRestore_ for range-firing tests"
    - "Test doubles that pass an isa() gate must subclass the real type (SpyTimeWindowEngine < DashboardEngine), not plain handle"

key-files:
  created:
    - tests/suite/TestCompanionTimeBar.m
    - tests/SpyTimeWindowEngine.m
    - .planning/phases/1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading/1041-MANUAL-VERIFY.md
  modified:
    - tests/suite/TestFastSenseCompanion.m
    - tests/test_dashboard_time_window.m
    - libs/SensorThreshold/Tag.m
    - libs/SensorThreshold/SensorTag.m
    - libs/Dashboard/DashboardEngine.m

key-decisions:
  - "Orchestrator ran the suites via the matlab/octave CLI (live-MATLAB MCP unavailable); the run surfaced 6 real bugs the executors could not catch without execution, all fixed and re-verified green"
  - "Visual checklist deferred per user decision (finalize now, defer visual) — items persist in 1041-MANUAL-VERIFY.md and a HUMAN-UAT file"
  - "Pre-existing testPerTagModeSpawnsNFigures orphan-timer leak (exposed, not caused, by the correct empty-state behavior) routed to a separate /gsd:debug task rather than touching sensitive teardown machinery in a feature phase"

patterns-established:
  - "When executors author MATLAB tests they cannot run, the orchestrator runs them via matlab -batch / octave CLI to catch real defects before phase verification"

requirements-completed: []

# Metrics
completed: 2026-06-02
---

# Phase 1041 Plan 05: Verification Suite + Human Checklist Summary

**Automated UI/integration tests + a human visual checklist that lock the global time-range feature; running the suites surfaced and fixed 6 real defects (2 in feature source, 4 in the new tests), leaving every 1041 test green.**

## Accomplishments

- **Test artifacts written (Tasks 1–3):**
  - `tests/suite/TestCompanionTimeBar.m` — 8 MATLAB-only UI smoke tests (button existence/column/label, singleton popup, preset fires `RangeChanged` + closes, All-data, Accent color, theme switch).
  - `tests/SpyTimeWindowEngine.m` — a `setTimeWindow`-recording test double.
  - `tests/suite/TestFastSenseCompanion.m` — 5 new integration tests (default label, managed-engine re-query, ad-hoc-figure re-query, open-site seam, teardown).
  - `1041-MANUAL-VERIFY.md` — 9-step visual checklist.
- **Human-verify checkpoint (Task 4):** the orchestrator executed the automated suites via the `matlab -batch` CLI (the live-MATLAB MCP was not connected). The visual portion was deferred per the user's decision.

## Verification Results (orchestrator-run, MATLAB R2025a CLI)

| Suite | Result |
|-------|--------|
| `test_sensor_tag_range` | ✅ 7/7 |
| `test_companion_time_range` | ✅ 10/10 |
| `test_dashboard_time_window` | ✅ 8/8 |
| `TestCompanionTimeBar` | ✅ 8/8 |
| `TestFastSenseCompanion` | 83/85 — all 1041 tests pass; the 2 non-passing are unrelated/pre-existing (see below) |

## 6 Defects Found by Running the Tests (all fixed + re-verified)

**Source bugs in the 1041 feature:**
1. **`getXYRange` out-of-extent** (`Tag.m`, `SensorTag.m`) — one-point padding pulled in a boundary sample when the window lay entirely outside the data extent; added an extent guard so a non-overlapping window returns empty. Commit `e8f40262`.
2. **`DashboardEngine.setTimeWindow` unrendered crash** (`DashboardEngine.m`) — `rerenderWidgets()` indexed an empty figure Position in `ensureViewport` when the engine had no figure; guard the rerender on a valid `hFigure`. Commit `2a3480b9`.

**Bugs in the new tests:**
3. **Spy type gate** — `SpyTimeWindowEngine` must subclass `DashboardEngine` (the managed-engine path type-checks at the `addDashboard` gate). Commit `52d89cdc`.
4. **Broken event counter** — `TestCompanionTimeBar` used `assignin('caller',...)`, which never updated the test's counter; switched to a handle-type counter. Commit `06a1d839`.
5. **Prefs pollution + grid depth** — `onRangeChanged_` persists ranges to the real prefs file, so range-firing tests made later default-assert tests resolve a 14-day window; added prefs isolation. Also fixed a `findall('-depth',2)` that missed the depth-3 toolbar grid. Commit `ea91404d`.
6. **`Lines` indexing** — `test_dashboard_time_window` brace-indexed a struct array (`Lines{1}.XData`); switched to `Lines(1).NumPoints` (downsample/disk-immune). Commit `f1e465f6`.

## Deferred / Out of Scope

- **Visual checklist (9 steps)** — picker visuals + relative-window-slides-on-live-tick. Cannot be headlessly asserted; persisted in `1041-MANUAL-VERIFY.md` and the phase HUMAN-UAT for the user's live session. **Deferred per user decision.**
- **`testPerTagModeSpawnsNFigures`** — a PRE-EXISTING PerTag lifecycle test (quick task 260526-r9x), not a 1041 test. It leaks 2 FastSense deferred timers (`StartDelay 0.01`) because deleting a *figure* (not the engine) doesn't fire `FastSenseWidget.delete()` to clean those timers. The correct new empty-state behavior (the PerTag fixture tags use integer X-values `1:3`, so the default datenum window is out-of-extent) shifted the render timing and exposed this. **Routed to a separate `/gsd:debug` task** (a fix touches the delicate, segfault-historied teardown machinery).
- **`testOpenWikiOpensWikiBrowser`** — pre-existing headless "filtered by assumption" incomplete; unrelated to 1041.

## Static Analysis

MISS_HIT `mh_style` + `mh_lint` clean on all touched files (the 6 fix files + the 3 test artifacts).

## Self-Check

```
[ -f tests/suite/TestCompanionTimeBar.m ] → FOUND
[ -f tests/SpyTimeWindowEngine.m ] → FOUND
[ -f .../1041-MANUAL-VERIFY.md ] → FOUND
git log --oneline | grep 1041-05 → 3 artifact commits (0a5e88c9, 8bba5e38, d3404eeb)
6 gap-closure fix commits → e8f40262, 2a3480b9, 52d89cdc, 06a1d839, ea91404d, f1e465f6
```

## Self-Check: PASSED

---

*Phase: 1041-global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading*
*Completed: 2026-06-02*
