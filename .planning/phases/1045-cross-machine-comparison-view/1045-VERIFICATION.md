---
phase: 1045-cross-machine-comparison-view
verified: 2026-06-16T00:00:00Z
status: passed
score: 5/5 success criteria verified
overrides_applied: 0
---

# Phase 1045: Cross-Machine Comparison View — Verification Report

**Phase Goal:** The user can build a machine-first comparison (select machines, set each machine's data, open an overlay figure) with confidence-gated auto-resolution; resolved tags are cached at open time so live ticks do not degrade refresh rate.
**Verified:** 2026-06-16 (live MATLAB session, R2025b, macOS ARM64, worktree on path)
**Status:** passed

---

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth (SC) | Status | Evidence |
|---|-----------|--------|----------|
| SC1 | Open a machine-first compare-builder (modeless, own overlay via `openAdHocPlot` Overlay; no changes to the 3 panes / `setProject`); select machines; set each machine's data via shared-sensor quick-fill or a per-machine tag | VERIFIED | `CompareBuilderDialog` is modeless (no `WindowStyle`), built on the `CompanionSettingsDialog` lifecycle; quick-fill `hSensorDD_` from `CanonicalMapper` keys + per-row override `uidropdown`. Reachable via the fleet-only Compare toolbar button → `openCompareBuilder_` singleton. `testCompareButtonFleetOnly`, `testCompareBuilderSingleton`, `testOpenComparisonLaunchesOverlay` GREEN; Plan-03 smoke 10/10. The 3 panes and `setProject` are untouched. |
| SC2 | Each machine's series gets a distinct color **stable per machine** (not per selection order) + legend `[machineName]: [sensorDisplayName]` | VERIFIED | `compareSeriesColor_` maps fleet **insertion index** mod palette length (CMP-02) — independent of the selected subset; `onOpenComparison_` builds `seriesLabels = [machine.Name ': ' tagName]`. Plan-03 smoke confirmed the overlay line `DisplayName`s `Press Line 3: Temp 1` / `Compressor A: Temp 3`; `testOpenComparisonLaunchesOverlay` asserts 2 resolved tags → 1 tracked overlay. |
| SC3 | A machine lacking the sensor shows `— none —`, is skipped gracefully with a surfaced warning; the comparison opens with the rest — no crash, no silent wrong-data | VERIFIED | `buildCompareResolution_` returns state `none` for an absent mapping; `warnSkippedMachines_` raises a consolidated non-blocking `uialert` + an events-log entry; `onOpenComparison_` excludes `none` rows from `ResolvedTags_`. `testCMP03_SkipGraceful` GREEN (M03 = `none`; `ResolvedTags_` holds exactly the 2 mapped machines; a tracked overlay still opens). |
| SC4 | Refuse to auto-include LOW/unreviewed matches (surface + require per-machine confirm); unit mismatch on a manual substitution warns; `CanonicalMapper.resolve` absent from the steady-state tick (resolved once at open, cached) | VERIFIED | The confidence gate lives in `buildCompareResolution_`: `AUTO`+`LOW` → `confirm_needed`, **unchecked by default** (invariant #4). `detectRowUnitMismatch_` + `warnUnitMismatches_` raise a non-blocking unit-mismatch warning. `onOpenComparison_` populates a resolve-once `ResolvedTags_` cache and never calls `CanonicalMapper` afterward. `testCMP05_NoResolveInTick` GREEN — across one engine `onLiveTick` the cache handles are eq-identical and the canonical-map signature is unchanged (no profiler). |
| SC5 | In the builder: accept auto, confirm a low-confidence match, pick a different local tag per machine, skip a machine, and optionally promote a manual override into the canonical map | VERIFIED | Row state machine: `auto` (accept), `onConfirm_` (confirm LOW → override+included), `onRowDropdownChanged_` (pick a different tag → override), checkbox/`— none —` (skip), `onPromote_`→`onPromoteConfirmed_` (in-memory `CanonicalMapper.override`, never `Fleet.save`). `testPromoteUpdatesMapper` GREEN (`mapper.resolve(...).status == 'OVERRIDDEN'`); Plan-04 smoke 9/9. |

### Critical Invariants (milestone gate)

| # | Invariant | Result |
|---|-----------|--------|
| 1 | `grep -rn "TagRegistry.register" libs/Fleet/` = 0 | PASS (0) |
| 2 | No UI primitives in the Fleet data model | PASS — `libs/Fleet/` UI hits only in `CanonicalMapEditor.m` (the deliberate Phase-1041 uifigure deliverable); `Fleet.m`/`Machine.m`/`CanonicalMapper.m` clean. Phase 1045 added no UI to `libs/Fleet/`. |
| 3 | `contains(` absent from `CanonicalMapper.m` | PASS (0); new filter/resolution code uses `strcmp`/`strcmpi`/`strfind(lower())` |
| 4 | LOW+AUTO never auto-included | PASS — `confirm_needed` unchecked by default; `testCMP05`/`testPromoteUpdatesMapper` exercise it |
| 5 | Resolve-once-at-open (no `CanonicalMapper` in the tick) | PASS — `ResolvedTags_` cache; `testCMP05_NoResolveInTick` asserts cache identity + map immutability across a tick |

## Test Evidence

- `tests/suite/TestFastSenseCompanion.m`: **91/0/0** (243 s) — all 7 new CMP tests GREEN; the MACH/legacy regressions (incl. `testLegacyConstruction_Unchanged` 10-col assertion) GREEN; both pre-existing load-dependent flakes (`testPerTagModeSpawnsNFigures`, `testADHOC05_noOrphanTimersAfterPlotAndClose`) GREEN this run — above the documented 82/84 baseline.
- `tests/test_compare_resolution.m`: **7/7** (flat Octave-safe — `CanonicalMapper.resolve` + `buildCompareResolution_`).
- `check_matlab_code`: clean (pre-existing-pattern warnings only) on `CompareBuilderDialog.m` (0 issues), `FastSenseCompanion.m`, `TestFastSenseCompanion.m`.
- Per-plan smokes: Plan 03 10/10, Plan 04 9/9, Plan 05 Task 1 11/11 — each with timers returning to 0 after teardown.
- Full-repo `run_all_tests.m` deliberately not run (CLAUDE.md: full passes only on user request — the MATLAB desktop is live on the user's screen). Affected-suite + flat coverage stand in.

## Human Verification (Plan 05 Task 3 checkpoint — APPROVED)

The blocking human-verify checkpoint covered the two Manual-Only Verification rows in VALIDATION.md (builder visual polish; overlay legend / per-machine color readability; theme repaint) that headless tests cannot assert. The user drove a 4-machine demo fleet (M01/M02 auto, M03 confirm, M04 none) through the builder + overlay and **approved** on 2026-06-16.

## Commits

`4f6f6a39` (01) · `c77d181d` (02) · `7d2fcf91` (03) · `e9261de2` (04) · `98a65465` (05)

## Known Follow-ups (out of phase scope)

- Pre-existing `PerTag`/`ADHOC05` orphan-debounce-timer flake under full-suite graphics load (DashboardEngine resize-debounce lifecycle on force-deleted figures) — green this run; candidate for its own investigation. The new CMP overlay teardown uses `close()` (fires `stopLive`), avoiding the leak.
