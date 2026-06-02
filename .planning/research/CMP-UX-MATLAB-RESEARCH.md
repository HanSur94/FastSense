# Feasibility Research: Cross-Machine Comparison UX Patterns in FastSense Companion

**Domain:** MATLAB programmatic uifigure (R2020b+), existing FastSenseCompanion codebase
**Researched:** 2026-06-02
**Mode:** Feasibility
**Overall confidence:** HIGH (all claims grounded in codebase file:line + official MATLAB docs)

---

## Codebase Grounding: What the Companion Already Does

### TagCatalogPane (TagCatalogPane.m)

- **Multiselect uilistbox already exists.** Line 162: `obj.hListbox_.Multiselect = 'on'`. Items are loaded via `groupByLabel` (shows group-header rows with empty `ItemsData`). Selection stored in `SelectedKeys_` (lines 33, 418-449) — NOT raw `listbox.Value` — so it survives filter rebuilds. Header rows are explicitly rejected in `onListboxChanged_` (lines 418-449).
- **`getSelectedTags()` returns a cell of Tag handles** (lines 220-238), resolved from the catalog snapshot (`AllTags_`), not a registry round-trip. This is the natural entry point for passing tags to `openAdHocPlot`.
- **`getSelectedKeys()` returns a cellstr** (lines 213-218). Both methods are public.
- **Debounced search** via a 150 ms `timer` (lines 342-362). Same pattern in `DashboardListPane`.
- **Selection event is payload-less** `notify(obj, 'TagSelectionChanged')` (line 446). Orchestrator calls `getSelectedKeys()` on receipt (FastSenseCompanion.m line 1845).

### DashboardListPane (DashboardListPane.m)

- **Per-row layout** built from `uigridlayout` (rows x 1) inside a scrollable `uipanel` (Scrollable='on', line 108). Each row is a 1x4 nested grid: name button, count label, status dot, Open button (lines 246-323).
- **No checkboxes or multiselect.** Single-selection only (`SelectedIdx_` scalar, line 40). Row highlight via `BackgroundColor` on the name button (lines 269-273).
- **`buildRow_` pattern** (lines 246-323): fast to extend with an additional column (e.g., a checkbox `uicheckbox` or Compare button per row). The 1x4 column spec (`{'1x', 'fit', 16, 52}`) just needs another column entry.

### FastSenseCompanion — Toolbar, Events, Figure Tracking (FastSenseCompanion.m)

- **Toolbar** is a 1x10 `uigridlayout` (line 326-327). Currently 9 occupied columns; column 9 is `'1x'` spacer; column 10 is settings gear. Adding a "Compare..." button takes a new column or reuses the spacer slot.
- **Event/listener bus:** orchestrator wires `addlistener(pane, 'EventName', @callback)` (lines 538-547). Adding a new event (e.g., `CompareRequested`) fired from a new toolbar button or pane follows the same exact pattern.
- **`OpenedFigures_`** column vector (line 116), maintained by `trackOpenedFigure_` (lines 2099-2109), pruned by `pruneOpenedFigures_` (lines 2112-2118). Any comparison figure spawned via `openAdHocPlot` slots in here automatically for Tile/Close-all.
- **`onOpenAdHocPlotRequested_`** (lines 2150-2248) resolves `TagKeys` to Tag handles via the catalog snapshot, then calls `openAdHocPlot(tags, mode, obj.Theme)` with the cell of Tag handles. This is the production path to reuse.
- **`setProject`** (lines 725-801) tears down and reattaches all three panes cleanly. Any new comparison pane or machine-selector widget needs the same detach/reattach in `setProject`.

### openAdHocPlot (private/openAdHocPlot.m)

- **Signature:** `[hFig, skippedNames] = openAdHocPlot(tags, mode, themePreset)` (line 1).
- **`tags` is a `1xN cell` of Tag handles** (line 18). Already accepts N tags from any source — caller assembles the cell. There is no machine-binding or registry constraint in the function body.
- **`mode = 'Overlay'`** (line 9) overlays all N tags as lines on one `RawAxesWidget`. This is exactly the cross-machine comparison rendering needed: one tag per machine, all on the same axes.
- Coerces to `'LinkedGrid'` when `numel(tags) == 1` (line 53). Overlay is the natural cross-machine mode for N >= 2 machines.
- Spawns a `DashboardEngine`, calls `engine.render()` + `engine.startLive()`, sets `CloseRequestFcn` to stop live on close (lines 131-137).
- **No changes needed to `openAdHocPlot` itself** to support cross-machine comparison — the caller just needs to build the `tags` cell from multiple machines' catalogs.

---

## R2020b Caveats: Key Constraints

### 1. uicontextmenu on uilistbox / uitable items — NOT usable until R2023b (CONFIRMED)
`uicontextmenu` can be attached to the entire `uilistbox` component (`hListbox_.ContextMenu = cm`) but **per-item right-click awareness requires `ContextMenuOpeningFcn` + `InteractionInformation.Item`, which is R2023b+**. On R2020b, right-click opens the menu but the callback has no way to know which listbox row was clicked without a separate `SelectionChangedFcn` + `WindowButtonMotionFcn` cursor-position workaround. Given the companion's architecture already guards R2020b (see lines 89-90 in TagCatalogPane.m: `try, obj.hSearchField_.Placeholder = ...; catch, end`), a per-item context-menu approach would require an unreliable workaround. **This rules out per-row right-click as a first-class UX.**

### 2. Drag-and-drop between components — NOT supported in R2020b programmatic uifigure
There is no `DropFcn` / `DragFcn` property on `uilistbox`, `uitable`, or `uipanel` in R2020b (these don't exist in the uifigure component model). The `uihtml` workaround requires HTML5 drag events and is not straightforward in programmatic uifigure context. **This rules out drag-to-tray as a practical option.**

### 3. uitable in uifigure — checkbox columns require R2022a+
`uitable` in R2020b uifigure supports `ColumnEditable = true` with logical values rendered as checkboxes, but the `Style` property for explicit checkbox columns is R2022a+. Logical-column checkboxes work in R2020b but styling/theming them to match the companion's dark/light theme requires property manipulation that is unreliable in older versions (similar to `BorderColor`/`BorderWidth` panel properties that the companion already wraps in `try/catch` at line 469).

### 4. uieditfield Placeholder — R2021a+ (already handled)
The codebase already wraps this in `try/catch` (TagCatalogPane.m line 89, DashboardListPane.m line 87). Same pattern needed for any R2021a+ properties on new components.

### 5. uilistbox with Multiselect='on' — FULLY SUPPORTED in R2020b
This is used today in `TagCatalogPane` (line 162). Multiple items can be selected; `Value` is a cell. The companion's existing `SelectedKeys_` pattern handles multi-item selection robustly.

---

## Pattern-by-Pattern Feasibility Assessment

### Pattern 1: Machine-selector uilistbox with Multiselect='on' + context-sensitive Compare button

**What it is:** A new machine-selector uilistbox (Multiselect='on') appears above or replaces the project-selector concept. Single-click = set active machine (existing setProject behavior). 2+ items selected = "Compare" button appears/enables.

**MATLAB feasibility (R2020b):** HIGH.
- `uilistbox` with `Multiselect='on'` works in R2020b (same as TagCatalogPane.m line 162).
- A "Compare" button that toggles `Enable` based on `numel(Value) >= 2` in the listbox `ValueChangedFcn` is plain R2020b.
- The disambiguation between "1 selected = set active" and "2+ = compare" is a simple `if numel(selectedMachines) == 1` branch.
- Tags are already resolved per-machine via their respective TagRegistry catalogs; assembling `tags = {machineA.getTag(key), machineB.getTag(key)}` before calling `openAdHocPlot` is straightforward.

**Fit with codebase:**
- Composes with TagCatalogPane's existing Multiselect uilistbox: user first picks machines in a machine-selector (new), then picks a logical sensor key in TagCatalogPane (existing). The selected key is looked up in each machine's catalog.
- Does NOT change the single-active-machine architecture: the `setProject` path fires when exactly one machine is clicked. Comparison is a separate action.
- Reuses `openAdHocPlot(tags, 'Overlay', theme)` unchanged.
- New code footprint: ~1 new pane or embedded section in the left panel above TagCatalogPane. Alternatively, a machine-selector toolbar dropdown.

**Effort:** MEDIUM. New pane class (~100-150 lines) following TagCatalogPane/DashboardListPane patterns. One new toolbar button or listbox in the left panel. Orchestrator wires one new event.

**R2020b caveats:** None significant for this pattern.

---

### Pattern 2: Checkbox column in a uitable of machines

**What it is:** Machine list rendered as a uitable with a logical checkbox column + a "Compare checked" button.

**MATLAB feasibility (R2020b):** MEDIUM-LOW.
- `uitable` with `ColumnEditable = true` + logical column renders checkboxes in R2020b uifigure. `CellEditCallback` fires on toggle.
- BUT: styling uitable to match the companion's dark theme is extremely limited in R2020b. `BackgroundColor` sets alternating row colors (2-element array); individual row theming, font color, and border removal require Java hacks that do not work in uifigure at all. The companion's architecture explicitly avoids all Java hacks.
- Row height is fixed (not configurable per row in R2020b).
- Each row's checkbox reacts to `CellEditCallback(src, event)` where `event.Indices` gives the row/col clicked. This works for toggling a selection set.

**Fit with codebase:** Partial. The per-row uigridlayout pattern in DashboardListPane is more flexible and theme-compatible than uitable. The companion already chose per-row uigridlayout over uitable for the dashboard list. Going against that decision for machine rows creates an inconsistent UX.

**Effort:** MEDIUM. But produces a lower-quality result than Pattern 1 due to theme limitations.

**R2020b caveats:** Cannot reliably match the companion's theme. `ColumnWidth` and row height are inflexible. Avoid unless the machine list is expected to be large (100+ machines), where uitable's virtual scroll is an advantage.

---

### Pattern 3: Persistent "comparison tray" panel

**What it is:** A collapsible panel (e.g., below TagCatalogPane or as a fourth column) that accumulates (machine, logical-sensor) pairs. User picks a machine, picks a tag, clicks "Add to comparison"; tray shows accumulated items; "Open comparison" button fires `openAdHocPlot`.

**MATLAB feasibility (R2020b):** HIGH.
- A scrollable `uipanel` with per-item rows (each a 1x3 grid: machine label, tag label, Remove button) follows the exact `DashboardListPane.buildRow_` pattern (lines 246-323).
- "Add to comparison" button can be added to the InspectorPane (next to the existing "Plot / Overlay" button).
- Tray state is a cell array of `(machineKey, tagKey, tagHandle)` tuples, maintained by the orchestrator.
- "Open comparison" calls `openAdHocPlot({tag1, tag2, ...}, 'Overlay', theme)` where the tags come from different machines' catalogs.

**Fit with codebase:** GOOD but adds architectural complexity. The tray is a new piece of persistent state in the orchestrator. The single-active-machine architecture is not violated because the tray accumulates across machine-switches (each item remembers its origin machine).

**Effort:** HIGH. Tray panel (~150-200 lines), orchestrator state additions, Add/Remove plumbing. Requires InspectorPane changes to expose the "Add to comparison" action.

**R2020b caveats:** None. All required components are available in R2020b.

---

### Pattern 4: uicontextmenu / right-click "Add to comparison"

**What it is:** Right-clicking a machine row or tag row shows a context menu with "Add to comparison."

**MATLAB feasibility (R2020b):** LOW.
- `uicontextmenu` can be attached to a `uilistbox` or individual `uibutton` in R2020b. The menu opens on right-click.
- BUT: per-item awareness (which row was right-clicked) requires `ContextMenuOpeningFcn` + `InteractionInformation.Item` which is **R2023b only**. On R2020b, the callback fires without row identity.
- For the per-row uibutton layout in DashboardListPane, a `uicontextmenu` CAN be attached to each individual row `uibutton` (each button is a separate component). This works in R2020b because the button knows its own engineIdx from the closure (same as `ButtonPushedFcn`). Example: `btn.ContextMenu = cm` where `cm` has a menu item with `MenuSelectedFcn = @(~,~) addToComparison(engineIdx)`.

**Per-row uibutton context menu is R2020b-feasible** but is a secondary entry point, not a primary interaction. Users typically don't discover right-click actions. On a machine selector with explicit row buttons, a context menu works.

**Fit with codebase:** PARTIAL. Works on uibutton rows (DashboardListPane pattern), not on uilistbox items (TagCatalogPane pattern). Serves as a secondary UX complement to Pattern 1 or 3, not as a standalone primary mechanism.

**Effort:** LOW (add `ContextMenu` to each row button). But low discoverability means it should only supplement a primary explicit-button path.

**R2020b caveats:** Works on individual `uibutton` components; does NOT work per-item on `uilistbox` without R2023b.

---

### Pattern 5: Separate modal/modeless compare-builder dialog (uifigure)

**What it is:** A "Compare..." toolbar button opens a second uifigure dialog with a machine checklist (several `uicheckbox` components) + a logical-sensor dropdown (`uidropdown`) + "Open" button.

**MATLAB feasibility (R2020b):** HIGH.
- `uifigure`, `uicheckbox`, `uidropdown`, `uibutton` all work in R2020b.
- Modal behavior via `uifigure` + `waitfor` is supported. Modeless (non-blocking) is also fine following the existing `CompanionSettingsDialog` pattern (FastSenseCompanion.m lines 1049-1060).
- `uidropdown` for sensor key selection can be populated from the intersection of keys across all machines' catalogs.

**Fit with codebase:** EXCELLENT. The `CompanionSettingsDialog` (FastSenseCompanion.m line 1059) establishes the exact same pattern: a second `uifigure` dialog owned by the companion, opened via a toolbar button, tracked in a property (`SettingsDlg_`). A `CompareBuilderDialog` following this pattern is ~150-200 lines.

**Effort:** MEDIUM. Dialog class following `CompanionSettingsDialog` idiom. One new toolbar button (column 9 spacer or new column). Orchestrator tracks it like `SettingsDlg_`.

**R2020b caveats:** None. All components available.

---

### Pattern 6: Drag-and-drop to a tray

**What it is:** User drags a machine or tag row to a comparison tray.

**MATLAB feasibility (R2020b):** VERY LOW — DO NOT USE.
- No `DropFcn` / drag-source / drag-target properties exist on uifigure components in R2020b (or R2021a, R2022a, R2023a). As of R2025a, MathWorks still does not document component-level drag-drop for programmatic uifigure (source: official component docs + community).
- The only drag-drop in uifigure is via `uihtml` with HTML5 events, which requires bundling HTML/JS and conflicts with the pure-MATLAB constraint.
- Even in `uihtml`, `dragover` / `drop` events have known bugs on MATLAB desktop (work on MATLAB Online only per community reports).

**Effort:** PROHIBITIVE (requires uihtml + HTML5 workaround, violates pure-MATLAB constraint).

---

## Feasibility Ranking (Highest to Lowest)

| Rank | Pattern | R2020b OK | Fits Architecture | Effort | Notes |
|------|---------|-----------|------------------|--------|-------|
| 1 | **Pattern 5: Modal/modeless compare dialog** | YES | EXCELLENT | MEDIUM | Exact `CompanionSettingsDialog` precedent |
| 2 | **Pattern 1: Machine-selector uilistbox + Compare button** | YES | GOOD | MEDIUM | Natural extension of TagCatalogPane |
| 3 | **Pattern 3: Comparison tray/basket panel** | YES | GOOD | HIGH | More discoverable but most code |
| 4 | **Pattern 4: uicontextmenu on row buttons** | YES (buttons only) | PARTIAL | LOW | Good secondary complement; low discoverability |
| 5 | **Pattern 2: Checkbox uitable** | PARTIAL | POOR | MEDIUM | Theme mismatch; inconsistent with existing per-row pattern |
| 6 | **Pattern 6: Drag-and-drop** | NO | VIOLATES CONSTRAINTS | PROHIBITIVE | Do not use |

---

## Lowest-Friction Recommendation

**Pattern 5 (modeless compare-builder dialog) is the lowest-friction option.**

**Rationale:**
1. The `CompanionSettingsDialog` at FastSenseCompanion.m:1049-1060 is an identical precedent — a second `uifigure` opened by a toolbar button, singleton-managed, with a `close()` lifecycle.
2. No changes to TagCatalogPane, DashboardListPane, InspectorPane, or the single-active-machine architecture.
3. Dialog contains: (a) machine checklist (`uicheckbox` per Fleet machine, all available in R2020b), (b) logical-sensor `uidropdown` populated from key intersection across checked machines, (c) "Open Comparison" button that calls `openAdHocPlot` with the resolved tag cell.
4. `openAdHocPlot` accepts a `1xN cell` of Tag handles already (private/openAdHocPlot.m:18); mode `'Overlay'` overlays all tags on one axes. Zero changes needed there.
5. The spawned figure is tracked via `trackOpenedFigure_` (FastSenseCompanion.m:2099-2109) and participates in Tile/Close-all.
6. Toolbar integration: one new button in the existing 1x10 toolbar grid (FastSenseCompanion.m:326-327), reusing the `'1x'` spacer column 9 or shifting to column 11.

**Approximate implementation surface:**
- `CompareBuilderDialog.m` (~150-200 lines, follows `CompanionSettingsDialog` pattern)
- FastSenseCompanion.m: +1 toolbar button (~15 lines), +1 property (`CompareBuilderDlg_ = []`), +1 method `openCompareBuilder_` (~20 lines), +1 event listener at close time

**No changes needed to:** TagCatalogPane, DashboardListPane, InspectorPane, openAdHocPlot, DashboardEngine, or any existing event routing.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Machine catalog key intersection | Two machines may have tags with the same logical key but different Tag object types (SensorTag vs DerivedTag) | Filter intersection to only keys where both sides return `isvalid` from `getXY()` |
| Per-machine TagRegistry isolation | TagRegistry is a persistent singleton shared across the session; multi-machine requires per-machine registry isolation or a Fleet namespace | Confirm Fleet object design before building dialog; the dialog should receive pre-resolved Tag handles, not registry keys |
| `openAdHocPlot` Overlay with heterogeneous X axes | Tags from different machines may have non-overlapping time ranges | Accept silently; the overlay axes will show both lines at their true time extents — this is correct behavior for comparison |
| Toolbar column count | The 1x10 grid is already at 10 columns with column 9 as spacer | Either use the spacer slot or add a column 11 — uigridlayout accepts dynamic column addition |
| R2020b `uidropdown` search | `uidropdown` gained a `Searchable` property in R2021a | Wrap in `try/catch` like the existing `Placeholder` guard (TagCatalogPane.m:89) |

---

## Sources

- TagCatalogPane.m (full file, lines 1-470) — multiselect uilistbox, SelectedKeys\_ pattern, getSelectedTags
- DashboardListPane.m (full file, lines 1-452) — per-row uigridlayout, buildRow\_ pattern
- FastSenseCompanion.m (lines 1-2248) — toolbar layout, figure tracking, CompanionSettingsDialog precedent, event wiring, openAdHocPlot invocation
- private/openAdHocPlot.m (full file, lines 1-212) — tag cell input, Overlay mode, figure lifecycle
- MATLAB Answers: context menu per item — R2023b required for per-item identity: https://www.mathworks.com/matlabcentral/answers/1658625
- MATLAB Answers: drag-drop in uihtml limited on desktop: https://www.mathworks.com/matlabcentral/answers/545696
- MATLAB Answers: drag-drop in App Designer: https://www.mathworks.com/matlabcentral/answers/2067951
