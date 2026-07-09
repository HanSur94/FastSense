---
phase: 260709-gp9
verifier: human-orchestrator (live MATLAB via matlab MCP)
date: 2026-07-09
status: passed
---

# Quick Task 260709-gp9 — Verification

Live MATLAB verification of the custom-drawn dashboard toolbar. The gsd-executor
has no MATLAB MCP tools (project convention), so all runtime checks below were
performed by the orchestrator.

## must_have coverage

| id | description | result |
|----|-------------|--------|
| D1 | Custom axes+patch toolbar layer replaces native look in light mode | **PASS** |
| D2 | 14 native handles valid but `Visible='off'`; readers keep working | **PASS** |
| D3 | Toggle click flips hidden Value + calls existing handler; active repaint | **PASS** |

## Evidence

**Live render** — `example_dashboard_all_widgets` `Theme='light'`, `exportapp` screenshots:
- `DashboardToolbarAxes` present (`CUSTOM_AXES_PRESENT=1`).
- Toolbar shows brand (accent square + bold dark name) at left; grouped flat
  bordered buttons Info · Sync · Redraw · Config · Image · Export, then toggles
  Live · Follow · Events; right-aligned "Last update" — matches redline **d** of
  `docs/design/fastsense-light-1to1-design-spec.md` §4.2.
- `setLiveActiveIndicator(true)` repaints the **green Live pill** (`StatusOkColor`);
  Events shows the blue active pill (`InfoColor`). Confirmed in the second screenshot.

**Handle contract** — `hLiveBtn` valid, `Visible=off`; `hConfigBtn`/`hImageBtn`/
`hExportBtn` all valid handles.

**Must-pass suites (8):**

| suite | result |
|-------|--------|
| TestDashboardInfo | 19 passed / 0 failed |
| TestDashboardEventsToggle | 22 passed / 0 failed |
| TestDashboardToolbarImageExport | 9 passed / 0 failed (button position-order assertion held) |
| test_dashboard_toolbar_buttons | 7 passed / 0 failed |
| test_dashboard_toolbar_image_export | 4 passed / 0 failed |
| test_dashboard_events_toggle | 22 passed / 0 failed |
| test_dashboard_stale_banner | 9 passed / 0 failed |
| test_dashboard_config_dialog | 8 passed / **1 failed** (see below) |

**Static:** `mh_style` + `mh_lint` clean (executor); no hardcoded colors; no
`delete(obj.h*)`.

## Pre-existing failure (NOT a regression)

`test_dashboard_config_dialog :: testAllControlsHaveTooltips` — "control 7
(EventMarkersVisible) missing tooltip". Proven pre-existing by A/B: reverting
`DashboardToolbar.m` to base `95e1d00a` (no gp9 change) reproduces the identical
failure. The config dialog sources each control's tooltip from its own `spec.tip`,
independent of the toolbar. Filed as a separate task; not in scope for gp9.

## Verdict

**PASSED.** Redline (d) is implemented and matches the mock within the cheap-render
budget. All handle-contract suites green; the single failure is a confirmed
pre-existing config-dialog bug unrelated to this change.
