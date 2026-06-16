---
phase: 1045-cross-machine-comparison-view
plan: "05"
subsystem: companion-ui
tags: [toolbar, singleton-dialog, theme-propagation, class-suite, cmp]
requirements: [CMP-01, CMP-02, CMP-03, CMP-05, CMP-06]

dependency_graph:
  requires: ["1045-04"]
  provides:
    - "Fleet-only Compare toolbar button ([1 11]->[1 12]); legacy [1 10] byte-identical"
    - "CompareBuilderDlg_ friend property + openCompareBuilder_ singleton + close() teardown"
    - "applyTheme -> CompareBuilderDlg_.applyTheme_ propagation"
    - "7 CMP class-suite tests (toolbar fleet-only, singleton, close, open-overlay, CMP-03 skip, CMP-05 cache, promote)"
  affects:
    - libs/FastSenseCompanion/FastSenseCompanion.m
    - tests/suite/TestFastSenseCompanion.m

tech_stack:
  added: []
  patterns:
    - "openSettings focus-or-create singleton + SettingsDlg_ friend-class teardown (mirrored for CompareBuilderDlg_)"
    - "MACH fleet fixture + struct(app)/struct(dlg) private-state seam + widget-closure callback invocation"
    - "closeSpawnedFigs_ close()-based overlay teardown (fires engine stopLive)"

key_files:
  created: []
  modified:
    - libs/FastSenseCompanion/FastSenseCompanion.m
    - tests/suite/TestFastSenseCompanion.m

decisions:
  - "Added applyTheme -> CompareBuilderDlg_.applyTheme_ propagation (guarded, mirrors the WikiBrowser hook). The UI-SPEC requires the open builder to repaint on a companion theme switch; no Plan 04/05 task spelled out the wiring, so it lands here with the rest of the companion integration."
  - "CMP-05 tick test forces a deterministic engine tick via the spawned figure's CloseRequestFcn closure workspace (functions().workspace{1}.engine -> onLiveTick), falling back to a pause when unreachable. Asserts ResolvedTags_ handle-identity + an order-independent canonical-map signature unchanged — no profiler (per VALIDATION)."
  - "Overlay teardown uses close() (closeSpawnedFigs_), not delete(), so the engine's CloseRequestFcn fires stopLive — delete() bypasses it and leaks the live timer (the documented root cause of the suite's PerTag/ADHOC05 flake)."

metrics:
  commit: 98a65465
  tests: "TestFastSenseCompanion.m 91/0/0 (7 new CMP green; both pre-existing PerTag/ADHOC05 flakes green this run, above the 82/84 baseline; 243 s); test_compare_resolution.m 7/7; check_matlab_code clean (pre-existing patterns only) on FastSenseCompanion.m + TestFastSenseCompanion.m. Invariants: TagRegistry.register in libs/Fleet=0; UI primitives in libs/Fleet only in pre-existing CanonicalMapEditor.m; contains( in CanonicalMapper.m=0."
---

# Plan 1045-05 Summary

The comparison builder is reachable and proven. The fleet-mode toolbar carries a fleet-only **Compare** button (`CompanionCompareBtn`, col 9, 80 px); the flex spacer, active-machine label, and gear shift to cols 10/11/12, so fleet mode grows `[1 11]`→`[1 12]` while legacy stays `[1 10]` byte-identical. `openCompareBuilder_` is a focus-or-create singleton (mirroring `openSettings`); `close()` tears down `CompareBuilderDlg_`; and a companion theme switch now repaints an open builder via `CompareBuilderDlg_.applyTheme_`. Seven CMP class-suite tests cover the fleet-only button (with the MACH-05 10-col legacy assertion intact), the singleton lifecycle, companion-close teardown, the tracked-overlay launch, the CMP-03 graceful skip, the CMP-05 resolve-once invariant (cache handle-identity + canonical-map signature unchanged across an engine tick), and the CMP-06 in-memory promote.

**Verification (live MATLAB, worktree on path):** `TestFastSenseCompanion.m` ran **91/0/0** — all 7 new CMP tests green, and both pre-existing load-dependent flakes (`testPerTagModeSpawnsNFigures`, `testADHOC05_noOrphanTimersAfterPlotAndClose`) passed this run, above the documented 82/84 baseline. `test_compare_resolution.m` is **7/7**. `check_matlab_code` is clean (pre-existing patterns only) on both modified files. The milestone invariants hold: zero `TagRegistry.register` in `libs/Fleet/`, UI primitives in `libs/Fleet/` only in the pre-existing `CanonicalMapEditor.m`, zero `contains(` in `CanonicalMapper.m`.

**Deviations:**
1. **Theme propagation wiring added here.** `applyTheme` now calls `CompareBuilderDlg_.applyTheme_` (guarded). The UI-SPEC requires it; no earlier task spelled out the call site, so it lands with the companion integration.
2. **CMP-05 deterministic tick** is forced by extracting the engine from the spawned figure's `CloseRequestFcn` closure workspace and calling `onLiveTick`, with a `pause`-based fallback. Documented as a no-profiler proof per VALIDATION.

**Remaining:** Plan 05 Task 3 is a **blocking human-verify checkpoint** (visual polish of the builder + overlay legend/colors, theme repaint) — the two Manual-Only Verification rows in VALIDATION.md that headless tests cannot assert. Awaiting user "approved".
