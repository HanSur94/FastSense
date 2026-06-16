---
phase: 1045-cross-machine-comparison-view
plan: "04"
subsystem: companion-ui
tags: [uifigure, dialog, cmp-06, uiconfirm-async, theme, in-memory-override]
requirements: [CMP-06]

dependency_graph:
  requires: ["1045-03"]
  provides:
    - "onConfirm_ (include a LOW/unreviewed row -> override, checked)"
    - "onPromote_ (R2020b-safe async uiconfirm) + onPromoteConfirmed_ (in-memory CanonicalMapper.override)"
    - "applyTheme_ (repaint + post-walk overrides; swatch series colors preserved)"
    - "onRowAction_ dispatch by state"
  affects:
    - libs/FastSenseCompanion/CompareBuilderDialog.m

tech_stack:
  added: []
  patterns:
    - "uiconfirm CloseFcn async pattern (override applied in CloseFcn, never inline)"
    - "public underscore-suffixed test seams (mirror getOpenedFiguresForTest_)"
    - "single-source badge/swatch re-assertion shared by rebuild + in-place + applyTheme_"

key_files:
  created: []
  modified:
    - libs/FastSenseCompanion/CompareBuilderDialog.m

decisions:
  - "onConfirm_/onPromoteConfirmed_/applyTheme_ are PUBLIC underscore-suffixed methods so the Plan 05 class-suite drives CMP-06 + theme directly (the codebase already ships public _-seams getOpenedFiguresForTest_/trackOpenedFigureForTest_). onPromote_ (the uiconfirm trigger) stays private — fired only by the Promote button."
  - "override is called through the public mapper() accessor: obj.App_.fleet().mapper().override(...). The plan's verify grep 'Mapper_.override(' is a stale literal predating the Fleet.mapper() seam — override is proven behaviorally (mapper.resolve -> OVERRIDDEN), not by that grep."
  - "The only '.save(' in the file is the LOCKED instructional copy string 'Call Fleet.save() to persist.' (line ~530), not a call. The plan's '! grep .save(' gate is over-broad against that string; the in-memory-only requirement (zero save CALLS) holds."

metrics:
  commit: e9261de2
  tests: "check_matlab_code clean; live smoke 9/9 — Confirm -> override+'Promote' button; onPromoteConfirmed_('Promote') -> mapper.resolve status OVERRIDDEN + '✓ promoted' badge + button removed; Cancel no-op (M01 stays AUTO); applyTheme_('light') repaints figure + auto-badge to light tokens with swatch color preserved; timers 0 after teardown"
---

# Plan 1045-04 Summary

The builder's per-machine interaction surface is complete. A `confirm_needed` row's **Confirm** action includes it (state → override, checkbox forced checked, action → **Promote**); the **Promote** action shows an R2020b-safe async `uiconfirm` (Cancel is the safe default) whose `CloseFcn` — never inline code — applies `CanonicalMapper.override` **in memory only** (the dialog never calls `Fleet.save`; persistence stays the user's explicit choice). A promoted row shows a `✓ promoted` (Accent) badge and drops its Promote button. `applyTheme_` repaints the figure and re-walks the children, then re-asserts the post-walk overrides — Open-button background by `includedCount`, per-row badge `FontColor` by state, and the per-machine swatch **series** colors (not theme tokens, so they survive a dark↔light switch).

**Verification (live MATLAB, worktree on path):** `check_matlab_code` clean; a 9/9 smoke on a 3-machine fleet with a LOW `temp` entry — `onConfirm_(2)` flipped the row to override+checked with a `Promote` button; `onPromoteConfirmed_(2, struct('SelectedOption','Promote'))` made `mapper.resolve('temperature','M02').status == 'OVERRIDDEN'`, set the `✓ promoted` badge, and replaced the button with an empty slot; a `Cancel` event left M01's entry `AUTO`; `applyTheme_('light')` repainted `hFig_.Color` to the light `DashboardBackground` and the auto badge to the light `ToolbarFontColor` while the row-1 swatch color stayed byte-identical. Timers returned to 0 (no overlay spawned this plan).

**Deviations:**
1. **Public `_`-seams for CMP-06 + theme.** `onConfirm_`, `onPromoteConfirmed_`, and `applyTheme_` are public (underscore-named) so the class-suite invokes them directly without the async `uiconfirm` — consistent with the existing public `getOpenedFiguresForTest_`/`trackOpenedFigureForTest_` seams. `onPromote_` stays private.
2. **`override` via the `mapper()` accessor.** The call is `obj.App_.fleet().mapper().override(...)`; the plan's `grep "Mapper_.override("` literal is stale (pre-`mapper()`). Proven behaviorally instead.
3. **`! grep .save(` is over-broad.** The single `.save(` match is the locked copy string instructing the user to call `Fleet.save()`; there is no save **call**. In-memory-only requirement satisfied.
