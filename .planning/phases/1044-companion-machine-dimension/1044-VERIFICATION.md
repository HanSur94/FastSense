---
phase: 1044-companion-machine-dimension
verified: 2026-06-10T12:00:00Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
---

# Phase 1044: Companion Machine Dimension — Verification Report

**Phase Goal:** The Companion shows a machine selector; selecting a machine makes it the active context for tag catalog and dashboard list; legacy single-machine construction continues to work; machine switches are clean (no timer accumulation).
**Verified:** 2026-06-10 (live MATLAB session, R2025b, macOS ARM64)
**Status:** passed

---

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth (SC) | Status | Evidence |
|---|-----------|--------|----------|
| SC1 | User can browse and free-text search the fleet's machines at fleet scale (lazy-populated list) | VERIFIED | `MachineSelectorPane` (uilistbox + 150ms debounced search over Name+Id, insertion order via `Fleet.machineIds()`); `test_machine_selector_pane.m` 5/5 (filterMachines: empty term = all, Name match, Id match, no match = empty + placeholder); `test_fleet.m` 6/6 |
| SC2 | Selecting a machine makes it the active context — the four static `TagRegistry.find` sites re-pointed; Companion always shows the active machine | VERIFIED | Four sites redirected (`TagCatalogPane.m:63/213` attach+refresh; `FastSenseCompanion.m` onLiveTick_ pair) with legacy static branch intact. `testMachineSwitch_ActiveContext` GREEN (catalog = exactly M01's tags after construction, exactly M02's after switch). `testActiveMachineLabel` GREEN (`▶ Press Line 3 [M01]` → `▶ Pump Station 1 [M02]`). Live smoke confirmed the same interactively. |
| SC3 | Switching machines stops the previous live timer before starting the new one; `timerfindall` stable across repeated switches | VERIFIED | `onMachineSelected_` stop-live → `setProject(machine.Dashboards, machine)` → indicator → restart-live; `stopLiveMode` stops-not-deletes, `startLiveMode` reuses the timer. `testMachineSwitch_TimerStable` GREEN (5 alternating live-mode switches, count flat, IsLive preserved). Smoke: live-on=6 → after-5-switches=6; after close back to baseline. |
| SC4 | Legacy `'Registry'`/`'Dashboards'` construction (no Fleet) works unchanged as a single implicit machine | VERIFIED | Conditional construction: legacy = byte-identical `[3 3]` grid `{220,'1x',360}`, `[1 10]` toolbar, no selector panel/label; legacy registry reads use the original static `TagRegistry.find`. `testLegacyConstruction_Unchanged` GREEN; all pre-existing legacy structural tests (ConstructorNoArgs, ThreePanelsExist, CloseCleanup, SetProjectReplacesState) GREEN. |

### Critical Invariants (milestone gate)

| # | Invariant | Result |
|---|-----------|--------|
| 1 | `grep -rn "TagRegistry.register" libs/Fleet/` = 0 | PASS (0) |
| 2 | No UI code in Fleet data model | PASS — 0 hits in `Fleet.m`/`Machine.m`/`CanonicalMapper.m`. 8 pre-existing hits all in `CanonicalMapEditor.m`, a deliberate Phase-1041 uifigure deliverable (introduced `78067f78`, accepted at the 1041 gate); Phase 1044 added only the 6-line `machineIds()` accessor to `libs/Fleet/`. |
| 3 | `contains(` absent from `CanonicalMapper.m` | PASS (0); all new filter code uses `strfind(lower())` |

## Test Evidence

- `tests/suite/TestFastSenseCompanion.m`: **82/84** — all 4 new Phase-1044 tests GREEN.
  - The 2 failures (`testPerTagModeSpawnsNFigures`, `testADHOC05_noOrphanTimersAfterPlotAndClose`) are a **pre-existing load-dependent flake pair**: each passes in isolation (PerTag: isolation-pass on baseline AND with phase changes; ADHOC05: isolation-pass immediately after its in-suite failure); they alternate across full runs (ADHOC05 was green in the 80-test run 30 min earlier); both exercise the ad-hoc plot force-delete path (DashboardEngine singleShot debounce timers orphaned under graphics load, amid `SceneTree: Could not find node` R2025b renderer noise); neither constructs a Fleet. Not a 1044 regression.
- `tests/test_fleet.m`: 6/6. `tests/test_machine_selector_pane.m`: 5/5.
- `check_matlab_code`: clean (pre-existing-pattern warnings only) on `FastSenseCompanion.m`, `TagCatalogPane.m`, `MachineSelectorPane.m`, `TestFastSenseCompanion.m`.
- Live interactive smoke (7/7): construction auto-select, per-machine catalog scoping, indicator updates, 5 live switches timer-flat, clean teardown.
- Full-repo `run_all_tests.m` deliberately not run (CLAUDE.md: full passes only on user request — MATLAB desktop is live on the user's screen). Affected-suite coverage + flake isolation evidence stand in.

## Human Verification (optional, non-blocking)

| Behavior | Why human | Instructions |
|----------|-----------|--------------|
| Left-rail visual polish (Machines ▸ Tags ▸ Dashboards ▸ Inspector hierarchy reads cleanly; 170px rail proportions) | On-screen aesthetics | `fleet`+2 machines → `FastSenseCompanion('Fleet', fleet)`; eyeball the left rail + toolbar label |
| Dark/light theme on the new selector controls | Visual color check | Toggle theme in Settings; selector + label should recolor via the existing walker |

## Commits

`8018da16` (01) · `13a87fb9` (02) · `7b9d0e63` (03) · `de07e98a` (04) · `48ea44ad` (05)

## Known Follow-ups (out of phase scope)

- Pre-existing PerTag/ADHOC05 orphan-debounce-timer flake under full-suite graphics load — candidate for its own investigation (DashboardEngine resize-debounce lifecycle on force-deleted figures).
