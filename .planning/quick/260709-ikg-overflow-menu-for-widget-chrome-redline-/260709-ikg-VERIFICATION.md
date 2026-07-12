---
phase: 260709-ikg
verifier: human-orchestrator (live MATLAB via matlab MCP)
date: 2026-07-09
status: passed
---

# Quick Task 260709-ikg — Verification

Live verification of the widget-chrome overflow ("…") menu. Executor has no MATLAB
MCP tools (project convention); all runtime checks below run by the orchestrator.

## must_have coverage

| id | description | result |
|----|-------------|--------|
| D1 | X/V/A/L/+ folded (Visible='off', alive) behind a single "…" button | **PASS** |
| D2 | "…" click posts a uicontextmenu routing to the same actions | **PASS** |
| D3 | reflowChrome_ anchors "…"; Info + Detach stay visible | **PASS** |

## Evidence

**Live render** — `example_dashboard_all_widgets` Theme='light':
- On a FastSenseWidget bar: `OverflowMenuButton` present + `Visible='on'`, String = U+2026 ("…").
- All 5 folded buttons present but `Visible='off'`: `CrosshairLinkButton`,
  `YLimitVisibleBtn`, `YLimitAllBtn`, `PlantLogToggleButton`, `CreateEventButton`.
- `DetachButton` `Visible='on'`. Firing the "…" callback built + posted the
  uicontextmenu with no error.
- Isolated toggle repro (plant-log on→off): bar + all buttons survive; "…" persists.

**Suites (run live):**

| suite | result |
|-------|--------|
| TestDashboardDetach | 11/11 |
| TestDashboardWidget | 13/13 |
| TestInfoTooltip | 13/13 |
| test_dashboard_widget_button_bar | 5/5 |
| test_dashboard_layout_plant_log_toggle (isolated) | 13/13 |
| TestDashboardLayoutPlantLogToggle (isolated) | 13/13 |

**Static:** `mh_style` + `mh_lint` clean (executor); theme tokens only; no folded-button deletes.

## Two failures — both cleared of this change (rigorous A/B)

1. **`TestDashboardLayoutPlantLogToggle/testInfoIconSurvivesToggleOnOff`** — fails
   only when run *after several other dashboard suites in one MATLAB session*
   (bar deleted mid-test, "Invalid or deleted object"). Proven **environmental
   test-ordering contamination, NOT a regression**:
   - ikg, isolated: 13/13 PASS.
   - Isolated toggle repro on ikg: bar + buttons survive.
   - **Base (pre-ikg), same 5-suite sequence: the IDENTICAL failure reproduces**
     (plus the flat variant) — so the flake predates this change.
   Matches the known leftover-figure/session-churn flake pattern.

2. **`TestIndustrialPlantDemoCompanion/testCOMPDEMO03_tagCatalogReflectsRegistry`** —
   "no plant tag has an `area:*` Labels entry". A tag-registry precondition,
   unrelated to widget chrome. **Fails identically on base** → pre-existing.

(The trailing StatusWidget `relayout_` / content-resize errors seen during the
render pass are the known pre-existing StatusWidget resize fragility tickled by
`exportapp`'s internal resize — not in the ishandle-guarded code this task added.)

## Verdict

**PASSED.** Redline (e) implemented within the cheap-render budget: X/V/A/L/+ folded
behind a working "…" overflow menu, Info/Detach preserved, all handle-contract
suites green in isolation. Both observed failures are proven pre-existing /
environmental via A/B against base.
