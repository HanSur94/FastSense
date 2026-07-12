---
phase: 260709-gp9
plan: 01
subsystem: ui
tags: [matlab, dashboard, toolbar, light-mode, uicontrol-shim, axes-patch]

requires: []
provides:
  - "Custom-drawn (axes+patch) light-mode toolbar visual layer in DashboardToolbar, replacing the look of the native uicontrol chrome while every native handle stays alive and hidden"
  - "Compatibility shim pattern (hide-not-delete native controls + custom overlay routing clicks to existing handlers) reusable for future classical-figure chrome redesigns"
affects: [dashboard-ui-refresh, light-mode-design]

tech-stack:
  added: []
  patterns:
    - "Hide-not-delete compatibility shim: native uicontrol/uipanel handles set Visible='off' (never deleted) so external readers (DashboardEngine.applyTheme, DashboardConfigDialog, tests) keep working against the same handle contract"
    - "Custom-drawn cheap-render toolbar: one full-panel axes (Tag 'DashboardToolbarAxes') hosting patch rectangles + text labels, all colors/sizes sourced from the theme struct only"
    - "Toggle click wiring: custom pill click flips the hidden uicontrol's Value first, then calls the existing on*Toggle(hiddenHandle) method — keeps Engine.startLive/stopLive and the *ActiveIndicator methods in sync"

key-files:
  created: []
  modified:
    - libs/Dashboard/DashboardToolbar.m

key-decisions:
  - "Custom button reading order (Info, Sync, Redraw, Config, Image, Export, Live, Follow, Events, then last-update text right-aligned) differs from the native right-to-left creation order — explicitly allowed by the plan as an 'equivalent' visual layout matching the light-mode mock; native Positions/creation order are untouched so the handle contract and TestDashboardToolbarImageExport ordering assertion are unaffected"
  - "White ([1 1 1]) label color on an active toggle pill is the one explicit non-themed literal the design permits — the semantic 'on-fill foreground' against an accent-colored patch, not a themed surface color"
  - "Split the single-file change into two atomic commits mirroring the two plan tasks (visual layer + click wiring, then active-state repaint + dual-write) by temporarily reverting Task 2's additions, committing Task 1, then reapplying Task 2 — since both tasks land in the same class file with no independent hunks"

patterns-established:
  - "Compatibility-shim redesign for classical MATLAB figure chrome: keep every pre-existing handle valid+hidden, paint a new custom layer on top, route all interaction back to the original handlers"

requirements-completed: [GP9-TOOLBAR-LIGHT]

coverage:
  - id: D1
    description: "Custom-drawn axes+patch toolbar layer (brand square+name, 9 flat buttons/toggles, right-aligned last-update text) replaces native uicontrol look in light mode"
    requirement: "GP9-TOOLBAR-LIGHT"
    verification:
      - kind: manual_procedural
        ref: "Render example_dashboard_all_widgets Theme='light'; visually compare toolbar to redline d of docs/design/fastsense-light-1to1-design-spec.md"
        status: unknown
    human_judgment: true
    rationale: "Visual/pixel-level match to the Pencil mock requires a live MATLAB render + screenshot comparison; the executor has no MATLAB MCP tools available and cannot run or view a rendered figure."
  - id: D2
    description: "All 14 native toolbar handles remain valid (Visible='off', never deleted); DashboardEngine.applyTheme / DashboardConfigDialog / existing tests keep reading them unchanged"
    requirement: "GP9-TOOLBAR-LIGHT"
    verification:
      - kind: unit
        ref: "tests/suite/TestDashboardToolbarImageExport.m (asserts hConfigBtn.x < hImageBtn.x < hExportBtn.x from stored native Positions)"
        status: unknown
      - kind: unit
        ref: "tests/test_dashboard_toolbar_buttons.m, tests/test_dashboard_config_dialog.m, tests/test_dashboard_events_toggle.m, tests/suite/TestDashboardEventsToggle.m, tests/suite/TestDashboardInfo.m, tests/test_dashboard_toolbar_image_export.m, tests/test_dashboard_stale_banner.m"
        status: unknown
    human_judgment: true
    rationale: "Executor has no MATLAB MCP tools per project convention (memory: running-matlab-tests-via-mcp); the human orchestrator must run the 8 must-pass suites live and confirm all stay green."
  - id: D3
    description: "Custom toggle clicks flip the hidden control's Value then call the existing on*Toggle(hiddenHandle) method; active-state repaint (Live=green, Follow/Events=blue) while hidden *Panel HighlightColor / hEventsBtn String-Value behavior is preserved"
    requirement: "GP9-TOOLBAR-LIGHT"
    verification:
      - kind: unit
        ref: "grep/awk structural gates in the plan's <verify> blocks (all passed statically — see below)"
        status: pass
      - kind: manual_procedural
        ref: "Live click-through: toggle Live/Follow/Events on the rendered dashboard, confirm pill color + hidden-handle Value/HighlightColor stay in sync"
        status: unknown
    human_judgment: true
    rationale: "Structural/static gates pass, but functional click-through behavior in a live MATLAB figure can only be confirmed by the human orchestrator running the app."

duration: 25min
completed: 2026-07-09
status: complete
---

# Quick Task 260709-gp9: Custom-Drawn Dashboard Toolbar (Light Mode) Summary

**Compatibility-shim rewrite of `DashboardToolbar`: 14 native uicontrol/uipanel handles hidden (never deleted) behind a new custom axes+patch visual layer — brand square+bold name, 9 flat bordered buttons/toggles, right-aligned last-update text — with every click routed back to the existing `on*` handlers and the three toggle handlers dual-writing the hidden control's `Value` before calling the original method.**

## Performance

- **Duration:** ~25 min
- **Tasks:** 2 (both `type="auto"`, no checkpoints)
- **Files modified:** 1 (`libs/Dashboard/DashboardToolbar.m`)

## Accomplishments

- Native toolbar chrome (title/edit box, Info/Export/Image/Config/Sync/Redraw pushbuttons, Live/Follow/Events toggle+panel pairs, last-update label) is now hidden via a single `hideNativeControls_()` sweep — every handle stays valid, guarded by `isempty`/`ishandle` before `set(..., 'Visible', 'off')`.
- New custom-drawn layer (`buildCustomLayer_()`) paints one full-panel `axes` (Tag `'DashboardToolbarAxes'`) with:
  - Brand: a small `DragHandleColor` patch + bold `GroupHeaderFg` dashboard-name text at left, click-to-rename via `inputdlg` (`onNameClick_`) applying the rename exactly like `onNameEdit` (sets `Engine.Name` + figure `Name`) and dual-writing both the custom brand text and the hidden `hTitleText`.
  - 9 flat bordered "buttons" (patch + centered label, `WidgetBackground`/`WidgetBorderColor`/`ToolbarFontColor`) via a shared `addCustomButton_()` helper: Info, Sync, Redraw, Config, Image, Export, Live, Follow, Events.
  - A right-aligned last-update text using the same lightened-font-color blend as the original hidden label.
- Every button's patch AND label route `ButtonDownFcn` to the same existing handler (`onInfo`, `resetGlobalTime`, `onReset`, `onConfig`, `onImage`, `onExport`). The three toggles (`customLiveClick_`, `customFollowClick_`, `customEventsClick_`) flip the hidden uicontrol's `Value` first, then call `onLiveToggle`/`onFollowToggle`/`onEventsToggle` with the hidden handle — so `Engine.startLive`/`stopLive` and the existing indicator methods stay authoritative.
- `setLiveActiveIndicator`/`setFollowActiveIndicator`/`setEventsActiveIndicator` keep their exact original hidden-handle behavior (`hLivePanel`/`hFollowPanel`/`hEventsPanel` `HighlightColor`, plus `hEventsBtn` `String`/`Value` for Events) and additionally call a new `paintToggleActive_()` helper to repaint the matching custom pill (Live→`StatusOkColor`, Follow/Events→`InfoColor`, white label when active; `WidgetBackground`/`ToolbarFontColor` when inactive).
- `setLastUpdateTime` keeps its exact signature and hot-path `datevec` logic, now computing the timestamp string once and dual-writing both the hidden `hLastUpdate` and the new `hLastUpdateText_`.
- Constructor primes the three custom pills from the hidden controls' initial `Value` right after building the custom layer (Events starts active by default, matching the pre-existing `hEventsBtn` `Value=1` default).

## Task Commits

1. **Task 1: Hide native controls and build the custom-drawn visual layer with click wiring** - `4b95245f` (feat)
2. **Task 2: Active-state repaint of custom pills + dual-write last-update, preserving the hidden-handle contract** - `7a294af2` (feat)

_Note: the two commits split the same file along the plan's task boundaries — Task 2's active-state/dual-write additions were temporarily reverted, Task 1 committed, then Task 2's additions reapplied and committed, so each commit corresponds to exactly one plan task._

**Plan metadata:** (pending — orchestrator commits SUMMARY.md/STATE.md separately per workflow contract)

## Files Created/Modified

- `libs/Dashboard/DashboardToolbar.m` - Added 5 new private properties (`hAxes_`, `hBrandSquare_`, `hBrandText_`, `hLastUpdateText_`, `CustomBtns_`), 9 new private methods (`hideNativeControls_`, `buildCustomLayer_`, `addCustomButton_`, `paintToggleActive_`, `onNameClick_`, `customLiveClick_`, `customFollowClick_`, `customEventsClick_`), extended `setLiveActiveIndicator`/`setFollowActiveIndicator`/`setEventsActiveIndicator`/`setLastUpdateTime`, and 3 lines appended to the constructor. No existing native control creation, Position, or the `on*` callback bodies were touched.

## Decisions Made

- Custom button left-to-right reading order (Info, Sync, Redraw, Config, Image, Export, Live, Follow, Events, then last-update text) intentionally differs from the native right-to-left creation order — the plan explicitly permits this as an "equivalent" visual layout matching the light-mode mock, since native Positions/creation order (and the `TestDashboardToolbarImageExport` assertion that reads them) are left untouched.
- `[1 1 1]` white label color on an active pill is the one explicit non-themed literal the design permits (semantic "on-fill foreground"); every other color/size comes from `obj.Theme_`.
- Split the single-file change into two atomic git commits by temporarily reverting/reapplying Task 2's additions, since both tasks land in the same class with no independently stageable hunks.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' `<action>` and `<done>` criteria were implemented as specified; no Rule 1-4 auto-fixes were needed.

## Known Limitations (recorded per plan instruction, not fixed)

- **Theme-switch re-theming:** A live dark↔light theme toggle repaints only the hidden handles via `DashboardEngine.applyTheme`; the custom layer will not re-theme until the toolbar is reconstructed. Acceptable per plan — this change targets the light mock only, and fixing it would require editing `DashboardEngine.m` (forbidden file).
- **Config-dialog rename staleness:** `DashboardConfigDialog` rename updates the hidden `hTitleText` only; the visible custom brand label will not reflect that rename until the toolbar is rebuilt. Flagged per plan, not fixed by editing the dialog (forbidden file). Note: the NEW `onNameClick_` path added by this plan (clicking the custom brand text) DOES dual-write both the custom brand text and `hTitleText` correctly — only the pre-existing `DashboardConfigDialog` rename path is one-way.
- **No test files touched:** Per constraints, no test file was edited. If any of the 8 must-pass suites listed in the plan's `<verification>` section assert a now-invalid VISUAL (as opposed to the handle contract — `.Value`/`.HighlightColor`/`.TooltipString`/`.String`/`.Position`/`.BackgroundColor` on the native handles, all preserved), that would need to be flagged by the human orchestrator during the live MATLAB run; no such case was identified from static review of the test files' assertions during this session (all assertions inspected read handle properties, not rendered pixels).

## Issues Encountered

None.

## Verification Performed (executor, static only)

All grep/awk gates from the plan's per-task `<verify>` blocks were run against the final file state and passed:

- `DashboardToolbarAxes`, `hideNativeControls_`, `buildCustomLayer_`, `onNameClick_`, `CustomBtns_` all present → `VERIFY_OK`
- Zero `delete(obj.h...)` occurrences → `NO_DELETES_OK`
- Zero hex-color / decimal-RGB-triplet literals → `NO_HARDCODED_COLOR_OK`
- `paintToggleActive_` and `hLastUpdateText_` present → `HELPERS_OK`
- `setLiveActiveIndicator` retains `hLivePanel` AND calls `paintToggleActive_` → `LIVE_KEEPS_PANEL_AND_REPAINTS`
- `setLastUpdateTime` writes both `hLastUpdate` and `hLastUpdateText_` → `LASTUPDATE_DUAL_WRITE`
- `setEventsActiveIndicator` retains `hEventsPanel` + `hEventsBtn` AND calls `paintToggleActive_` → `EVENTS_CONTRACT_PRESERVED`
- Preserved-contract greps confirmed unchanged: `Height = 0.04`, `function contentArea = getContentArea`, `function obj = DashboardToolbar(engine, hFigure, theme)`

Additionally ran `mh_style` and `mh_lint` (MISS_HIT, available in this environment) on the final file — both report "everything seems fine" with zero findings.

**Not run by the executor (no MATLAB MCP tools available per project convention):** `check_matlab_code` static analysis, live rendering of `example_dashboard_all_widgets` with `Theme='light'`, visual comparison to the design spec, and the 8 must-pass test suites. These are the human orchestrator's responsibility per the plan's `<verification>` section.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `DashboardToolbar.m` is ready for the human orchestrator's live MATLAB verification pass: `check_matlab_code`, a light-mode render + screenshot comparison against redline **d** of `docs/design/fastsense-light-1to1-design-spec.md`, and the 8 must-pass suites (`TestDashboardInfo`, `TestDashboardEventsToggle`, `TestDashboardToolbarImageExport`, `test_dashboard_toolbar_buttons`, `test_dashboard_toolbar_image_export`, `test_dashboard_config_dialog`, `test_dashboard_events_toggle`, `test_dashboard_stale_banner`).
- No blockers identified from static review. If the live run surfaces a genuinely-invalid VISUAL assertion in a test (as opposed to a handle-contract read), that is expected per the plan and should be flagged rather than silently patched.

---
*Phase: 260709-gp9*
*Completed: 2026-07-09*

## Self-Check: PASSED

- FOUND: `libs/Dashboard/DashboardToolbar.m`
- FOUND: commit `4b95245f`
- FOUND: commit `7a294af2`
- FOUND: `.planning/quick/260709-gp9-custom-drawn-dashboard-toolbar-light-mod/260709-gp9-SUMMARY.md`
