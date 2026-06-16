---
phase: 1045-cross-machine-comparison-view
plan: "02"
subsystem: companion-adhoc
tags: [openadhocplot, nv-args, overlay, series-color, legacy-compat]
requirements: [CMP-02]

dependency_graph:
  requires: []
  provides:
    - "openAdHocPlot 'SeriesColors'/'SeriesLabels' optional NV args (additive)"
    - "per-series explicit Color injection in plotOverlay_ (immune to ColorOrderIndex)"
    - "index-aligned color/label carry-through of the no-data tag filter"
  affects:
    - libs/FastSenseCompanion/private/openAdHocPlot.m
    - libs/FastSenseCompanion/runOpenAdHocPlotTests.m

tech_stack:
  added: []
  patterns:
    - "inputParser additive NV args with arity validation BEFORE figure spawn"
    - "explicit per-line 'Color' instead of axes ColorOrder manipulation"

key_files:
  created: []
  modified:
    - libs/FastSenseCompanion/private/openAdHocPlot.m
    - libs/FastSenseCompanion/runOpenAdHocPlotTests.m

decisions:
  - "Arity mismatch throws openAdHocPlot:seriesColorsMismatch BEFORE any DashboardEngine spawns, so a bad call never leaks a window."
  - "Colors/labels are carried through the tags-with-data filter index-aligned, so a dropped (no-data) tag drops its color/label too — series stay paired."
  - "Legacy 3-positional-arg calls are byte-unchanged: absent NV args keep the ColorOrder auto-assign + tag-Name DisplayName path."

metrics:
  commit: c77d181d
  tests: "runOpenAdHocPlotTests 12/12 via the flat wrapper — incl. T-NV1 (legacy byte-compat), T-NV2 (color+label injection), T-NV3 (mismatch error, no figure spawned)"
---

# Plan 1045-02 Summary

`openAdHocPlot` gains two additive optional name-value args so the cross-machine overlay can inject per-machine **stable colors** and **machine-qualified legend labels** (CMP-02). `inputParser` parses `'SeriesColors'` (cell of 1×3 RGB) and `'SeriesLabels'` (cellstr); an arity mismatch throws `openAdHocPlot:seriesColorsMismatch` before any figure spawns. The tags-with-data filter carries colors/labels through index-aligned (a dropped no-data tag drops its color/label), and `plotOverlay_` draws each line with an explicit per-series `'Color'` (immune to `ColorOrderIndex` state) plus the supplied `DisplayName`. Legacy 3-arg calls are byte-unchanged (`ColorOrder` auto-assign + tag-`Name` `DisplayName`).

**Verification:** `runOpenAdHocPlotTests` 12/12 via the flat wrapper — T-NV1 legacy byte-compat, T-NV2 color+label injection, T-NV3 mismatch-error-no-figure.

**Deviations:** none. (Summary backfilled during Phase 1045 closeout — the original Wave-1 commit landed without a SUMMARY when the execution agent terminated early; code + tests were already committed and green.)
