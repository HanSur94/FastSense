---
phase: 1044
slug: companion-machine-dimension
audited: 2026-06-10
platform: MATLAB uifigure (pure code audit — no dev server, no screenshots)
baseline: 1044-UI-SPEC.md (approved design contract)
overall_score: 57/60
status: advisory
---

# Phase 1044 — UI Review: Companion Machine Dimension

**Audited:** 2026-06-10
**Baseline:** 1044-UI-SPEC.md
**Screenshots:** Not captured (MATLAB uifigure — code-only audit per orchestrator directive)

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Layout Fidelity | 10/10 | Grid dims {170,220,'1x',360}, [1 11] toolbar, [5 1] pane all exact |
| 2. Spacing | 10/10 | All padding/spacing values match spec scale precisely |
| 3. Typography | 9/10 | All font sizes and weights correct; one minor deviation in spec usage of `Period` vs `StartDelay` comment clarified in code |
| 4. Color / Theme | 9/10 | Token usage correct; one pre-existing Accent misuse (Close All button) not introduced by this phase |
| 5. Copywriting | 10/10 | All locked strings match spec verbatim including ASCII fallback and tooltip format |
| 6. Interaction Contract | 9/10 | Switch sequence correct; minor gap: `selectById` fires event but listener not yet wired at that construction point — works by design (documented) but creates non-obvious ordering dependency |

**Overall: 57/60**

---

## Top 3 Priority Fixes

1. **Accent used on Close All button background** (`FastSenseCompanion.m:467`) — 60/30/10 contract reserves Accent for interactive selection signals only; using it as a background on a destructive button conflates signal meaning. This predates Phase 1044 but is visible in the same toolbar as the new active-machine indicator. Change `hCloseAllBtn_.BackgroundColor` to `theme.WidgetBorderColor` and use `FontColor` or a dedicated destructive token if one is added. WARNING.

2. **`selectById` fires `onMachineSelected_` before `MachineSelectionChanged` listener is wired** (`FastSenseCompanion.m:651-656`) — construction calls `selectById(ids{1})` then immediately calls `updateActiveMachineIndicator_` on line 652, then wires the listener on 654. The `onMachineSelected_` inside `selectById` fires `notify(MachineSelectionChanged)` at line 288 of MachineSelectorPane.m, but the orchestrator's `addlistener` on line 654 doesn't exist yet — so the event fires into a void during construction. The indicator is updated manually on line 652, so the UI result is correct. However, the `onMachineSelected_` path from line 651 triggers `setProject` inside `MachineSelectorPane.onMachineSelected_`... no wait: the Companion's `onMachineSelected_` is not connected yet, so `setProject` is NOT called from that path during construction. Context was already set at Step 6 (lines 278-299). This is the documented accepted deviation. The gap is that the code comment at line 648 says "selectById fires the pane event, but the MachineSelectionChanged listener is wired AFTER this block" — a future reader editing construction order could break this silently. Recommend adding an `assert`-style guard or a named helper to make the ordering constraint self-documenting. WARNING.

3. **`MachineSelectorPane.setTheme` uses warning ID `FastSenseCompanion:setThemeFailed`** (`MachineSelectorPane.m:188`) — error namespace contract in UI-SPEC specifies `MachineSelectorPane:*` for errors from this class. Using the parent class's namespace for a warning emitted from `MachineSelectorPane` violates the namespacing contract and misleads diagnostics. Change to `MachineSelectorPane:setThemeFailed`. WARNING.

---

## Detailed Findings

### Pillar 1: Layout Fidelity (10/10)

All `uigridlayout` structures match the UI-SPEC Component Layout Contract exactly.

**MachineSelectorPane root grid** (`MachineSelectorPane.m:77-82`):
- `[5 1]` grid: PASS
- `RowHeight = {28, 8, '1x', 4, 24}`: PASS (exact spec match)
- `ColumnWidth = {'1x'}`: PASS
- `Padding = [16 16 16 16]`: PASS
- `RowSpacing = 0`: PASS
- `BackgroundColor = theme.WidgetBackground`: PASS

**Search sub-grid** (`MachineSelectorPane.m:85-92`):
- `[1 2]` grid, `ColumnWidth = {'1x', 24}`: PASS
- `Padding = [0 0 0 0]`: PASS
- `ColumnSpacing = 4`: PASS

**Companion root grid** (`FastSenseCompanion.m:347-353`):
- Fleet mode: `[3 4]`, `ColumnWidth = {170, 220, '1x', 360}`: PASS
- Legacy mode: `[3 3]`, `ColumnWidth = {220, '1x', 360}`: PASS

**Toolbar grid** (`FastSenseCompanion.m:384-389`):
- Fleet mode: `[1 11]`, `ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, '1x', 'fit', 36}`: PASS
- Legacy mode: `[1 10]`, `ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, '1x', 36}`: PASS

**Panel Layout.Column assignments** (`FastSenseCompanion.m:541-554`):
- `hMachineSelectorPanel_`: Row=2, Column=1: PASS
- `hLeftPanel_` (Tags): Row=2, Column=2 (fleet): PASS
- `hMidPanel_` (Dashboards): Row=2, Column=3 (fleet): PASS
- `hRightPanel_` (Inspector): Row=2, Column=4 (fleet): PASS
- `hToolbarPanel_`: Row=1, Column=[1 4] (fleet): PASS (line 364)
- `hLogPanel_`: Row=3, Column=[1 4] (fleet): PASS (line 554)

**Active-machine label** (`FastSenseCompanion.m:507-518`):
- `Layout.Column = 10`: PASS (new 'fit' column)
- Gear shifted to column 11 via `gearColumn = 11`: PASS

### Pillar 2: Spacing (10/10)

All spacing values match the declared scale.

- `hLayout_.Padding = [24 24 24 24]` (lg=24): PASS (`FastSenseCompanion.m:355`)
- `hLayout_.RowHeight = {32, '1x', 360}` (xl=32 for toolbar): PASS (`FastSenseCompanion.m:354`)
- `hToolbarGrid.ColumnSpacing = 8` (sm=8): PASS (`FastSenseCompanion.m:393`)
- `MachineSelectorPane Padding [16 16 16 16]` (md=16): PASS (`MachineSelectorPane.m:80`)
- `hSearchGrid.ColumnSpacing = 4` (xs=4): PASS (`MachineSelectorPane.m:91`)
- Listbox row heights `{28, 8, '1x', 4, 24}`: all match spec (28px search, 8px spacer, flex listbox, 4px spacer, 24px badge): PASS
- No arbitrary `[Npx]` or `[Nrem]` values found in new code.

Touch target minimums met: 24px count badge, 28px search field row.

### Pillar 3: Typography (9/10)

All font sizes and weights for new Phase 1044 elements are correct.

**MachineSelectorPane** (`MachineSelectorPane.m:99,109,119,128`):
- Search field: `FontSize = 11`, no explicit weight (inherits normal): PASS
- Clear button: `FontSize = 11`: PASS
- Listbox: `FontSize = 11`: PASS
- Count label: `FontSize = 11`: PASS

**Active-machine indicator** (`FastSenseCompanion.m:511-512`):
- `FontSize = 11`: PASS
- `FontWeight = 'bold'`: PASS (spec: bold, to stand out)

**Minor deviation (not a defect — clarification):** The UI-SPEC Interaction Contract code sample uses `obj.DebounceTimer_.Period = 0.150` but the implementation correctly uses `StartDelay = 0.150` (`MachineSelectorPane.m:250`). `Period` only applies to repeating execution modes; `StartDelay` is the correct property for `singleShot`. The inline comment at line 248-249 explains this. The implementation is more correct than the spec sample. Score deduction withheld; this is a spec typo, not an implementation error. Noted for spec errata.

### Pillar 4: Color / Theme (9/10)

**Phase 1044 new elements — all correct:**

- `MachineSelectorPane` backgrounds: `WidgetBackground` throughout (listbox, search field, search grid, root grid, count label): PASS
- Clear button `FontColor = ToolbarFontColor`: PASS (`MachineSelectorPane.m:110`)
- Count label `FontColor = PlaceholderTextColor`: PASS (`MachineSelectorPane.m:129`)
- Active-machine indicator `FontColor = theme.Accent`: PASS (`FastSenseCompanion.m:514`)
- Theme switch re-asserts `hActiveMachineLabel_.FontColor = theme.Accent` after walker: PASS (`FastSenseCompanion.m:1149`)
- `MachineSelectorPane.setTheme` post-walk overrides: `hSearchClear_.FontColor = t.ToolbarFontColor` and `hCountLabel_.FontColor = t.PlaceholderTextColor`: PASS (`MachineSelectorPane.m:182-185`)
- `applyTheme` calls `MachineSelectorPane_.setTheme(obj.Theme_)`: PASS (`FastSenseCompanion.m:1146`)

**Pre-existing Accent misuse (not introduced by Phase 1044):**
- `hCloseAllBtn_.BackgroundColor = obj.Theme_.Accent` (`FastSenseCompanion.m:468`): WARNING — Accent is reserved in the 60/30/10 contract for interactive selection signals (active machine indicator, listbox native highlight). Using it as a button background color for a destructive action expands Accent beyond its contracted role. This was present before Phase 1044 and is NOT a regression of this phase. Score deduction is -1 because the audit surface now includes the expanded toolbar where the new indicator and the Close All button both use Accent, making the contract violation more visible.

### Pillar 5: Copywriting (10/10)

All locked copy strings match the UI-SPEC Copywriting Contract exactly.

| Element | Spec | Implementation | Result |
|---------|------|----------------|--------|
| Search placeholder | `['Search machines' char(8230)]` | `['Search machines', char(8230)]` (`MachineSelectorPane.m:98`) | PASS |
| Clear button text | `char(215)` | `char(215)` (`MachineSelectorPane.m:107`) | PASS |
| Clear button tooltip | `'Clear search'` | `'Clear search'` (`MachineSelectorPane.m:108`) | PASS |
| Count badge format | `'N machines'` via `sprintf('%d machines', n)` | `sprintf('%d machines', n)` (`MachineSelectorPane.m:233`) | PASS |
| Zero-match placeholder | `'No machines match'` | `'No machines match'` (`MachineSelectorPane.m:231`) | PASS |
| Active indicator text | `[char(9658) ' Name [Id]']` | `[prefix ' ' machine.Name ' [' machine.Id ']']` (`FastSenseCompanion.m:2012-2013`) | PASS |
| Active indicator tooltip | `'Active machine: Name (Id: Id)'` | `['Active machine: ' machine.Name ' (Id: ' machine.Id ')']` (`FastSenseCompanion.m:2014-2015`) | PASS |
| ASCII fallback | `'>'` when `~usejava('desktop')` | `prefix = '>'` when `~usejava('desktop')` (`FastSenseCompanion.m:2008-2010`) | PASS |
| Active label Tag | `'CompanionActiveMachineLabel'` | `'CompanionActiveMachineLabel'` (`FastSenseCompanion.m:518`) | PASS |
| Error on switch failure | `uialert(hFig_, ME.message, 'Machine Switch Failed', 'Icon', 'error')` | Exact match (`FastSenseCompanion.m:1994`) | PASS |

Item format rules:
- `'Name (Group)'` when group non-empty (`MachineSelectorPane.m:208`): PASS
- `'Name'` when group empty (`MachineSelectorPane.m:210`): PASS
- `ItemsData` carries `machine.Id` for selection recovery without string parsing (`MachineSelectorPane.m:212`): PASS

R2021a+ placeholder wrapped in try/catch (`MachineSelectorPane.m:98`): PASS

### Pillar 6: Interaction Contract (9/10)

**Debounce timer (150 ms):**
- `ExecutionMode = 'singleShot'`: PASS (`MachineSelectorPane.m:247`)
- `StartDelay = 0.150` (correct property for singleShot): PASS (`MachineSelectorPane.m:250`)
- `BusyMode = 'drop'`: PASS (`MachineSelectorPane.m:251`)
- Lazy-create on first keystroke: PASS (`MachineSelectorPane.m:245`)
- Stop before restart on each keystroke: PASS (`MachineSelectorPane.m:255-258`)
- Stop + delete in detach (stop before delete): PASS (`MachineSelectorPane.m:141-144`)

**Machine switch sequence** (`FastSenseCompanion.m:1980-1998`):
1. `wasLive = obj.IsLive`: PASS (line 1982)
2. `obj.stopLiveMode()` if was live: PASS (line 1984)
3. `obj.Fleet_.getMachine(selectedId)`: PASS (line 1986)
4. `obj.setProject(newMachine.Dashboards, newMachine)`: PASS (line 1987)
5. `obj.updateActiveMachineIndicator_(newMachine)`: PASS (line 1988)
6. `obj.startLiveMode()` if was live: PASS (line 1990)
- `uialert` with title `'Machine Switch Failed'` in catch: PASS (line 1994)

**Auto-select first machine** (`FastSenseCompanion.m:278-299, 649-657`):
- Step 6 pre-sets `Engines_`/`Registry_` to first machine's data: PASS (lines 294-298)
- `selectById(ids{1})` called before `MachineSelectionChanged` listener wired: PASS/accepted deviation (documented at line 648)
- `updateActiveMachineIndicator_` called explicitly at line 652 to populate label: PASS
- Active context never empty when Fleet present: PASS

**Selection re-assert after filter** (`MachineSelectorPane.m:223-227`):
- Re-asserts `hListbox_.Value = obj.ActiveId_` if still visible after filter: PASS
- Clears selection (`{}`) if active machine filtered out: PASS
- No ValueChangedFcn fired by either assignment (silent re-assert): PASS

**Legacy mode** (`FastSenseCompanion.m:347-354, 384-389, 541-545`):
- `[3 3]` grid unchanged: PASS
- `[1 10]` toolbar unchanged: PASS
- `hMachineSelectorPanel_` never created: PASS
- `hActiveMachineLabel_` never created (`gearColumn = 10`): PASS

**Listener re-wire after setProject** (`FastSenseCompanion.m:934-939`):
- `MachineSelectionChanged` listener re-wired in `setProject` after clear-all: PASS
- Without this re-wire, left rail would go dead after first machine switch: correctly handled.

**Warning namespace deviation** (`MachineSelectorPane.m:188`):
- `warning('FastSenseCompanion:setThemeFailed', ...)` emitted from `MachineSelectorPane.setTheme` uses parent class namespace. Spec mandates `MachineSelectorPane:*` for warnings from this class. WARNING. Impact: diagnostic filtering by namespace yields false parent attribution.

---

## Registry Safety

N/A — MATLAB uifigure, no component registry. No shadcn, no npm, no third-party component blocks.
Registry audit: skipped (not applicable to MATLAB uifigure platform).

---

## Files Audited

- `/libs/FastSenseCompanion/MachineSelectorPane.m` (full, 300 lines)
- `/libs/FastSenseCompanion/private/filterMachines.m` (full, 38 lines)
- `/libs/FastSenseCompanion/FastSenseCompanion.m` (partial: constructor, setProject, applyTheme, onMachineSelected_, updateActiveMachineIndicator_ — lines 1-678, 856-954, 1091-1169, 1971-2016)
- `.planning/phases/1044-companion-machine-dimension/1044-UI-SPEC.md` (full)
