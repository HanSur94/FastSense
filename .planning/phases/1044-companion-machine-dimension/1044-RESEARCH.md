# Phase 1044: Companion Machine Dimension — Research

**Researched:** 2026-06-08
**Domain:** MATLAB uifigure — FastSenseCompanion layout extension + Fleet/Machine integration
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Placement:** Dedicated left-rail column. Root grid extends from `[3 3]` to `[3 4]` when a Fleet is supplied; legacy stays `[3 3]`.
- **Control form:** `uilistbox` + `uieditfield` with ~150ms debounce — copy `TagCatalogPane` idiom verbatim.
- **Active-machine indicator:** Persistent toolbar label (bold, accent color) + list-selection highlight.
- **Legacy (no-Fleet) appearance:** Hide selector entirely. Legacy window is byte-identical to today.
- **Search:** Substring over Name + Id, `strfind(lower(...))`, never `contains`.
- **List order:** Fleet insertion order.
- **Per-row label:** `'Name (Group)'` when Group non-empty; `'Name'` otherwise. Id in ItemsData.
- **Zero-match placeholder:** `'No machines match'`.
- **Machine switch:** Preserve live on/off. Stop-before-start. `setProject(machine.Dashboards, machine)`.
- **Tag/inspector reset on switch:** Reset to welcome state (setProject already does this).
- **Opened dashboard figures:** Leave open on switch.
- **Initial active machine:** Auto-select first machine in fleet on construction.
- **Fleet NV pair:** `'Fleet', fleetObj` on constructor. Legacy `'Registry'`/`'Dashboards'` wrapped in implicit Machine.
- **Four call-site redirect:** `TagCatalogPane.m:60`, `:205`; `FastSenseCompanion.m:1616`, `:1618` — redirect to `obj.Registry_.find(...)` where `Registry_` is the active Machine.
- **`setProject` as switch mechanism** — accepts Machine as duck-typed registry.
- **Construction API:** `Fleet` NV pair added; legacy unchanged; planner may refine property names, error-ID spelling, debounce constant, and left-rail width.

### Claude's Discretion

- Exact private property names (`ActiveMachine_` vs reusing `Registry_`, etc.)
- Error-ID spelling (`FastSenseCompanion:*`)
- Debounce constant (locked at 150 ms from CONTEXT.md but implementation detail)
- Left-rail column width (locked at 170 px from UI-SPEC, planners may keep or adjust)

### Deferred Ideas (OUT OF SCOPE)

- Per-machine health/status badge (requires fleet-wide background monitoring)
- Grouped machine list (flat insertion-order v1; grouping is a later nicety)
- Cross-machine comparison / overlay — Phase 1045
- Per-machine dashboard clone/remap — Phase 1046

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MACH-01 | User can browse and free-text-search the fleet's machines in the companion at fleet scale (20+, lazy-populated) | `MachineSelectorPane` uilistbox + debounced search over `fleet.machineCount()` + `fleet.getMachine(id)` iteration |
| MACH-02 | Selecting a machine makes it the active context — tag catalog and dashboard list show that machine's tags and dashboards | `setProject(machine.Dashboards, machine)` call in `onMachineSelected_`; four `TagRegistry.find` call sites redirected to active machine |
| MACH-03 | The companion always indicates which machine is the active context | Toolbar label `hActiveMachineLabel_` with accent color + the listbox selection highlight |
| MACH-04 | Switching machines stops the previously-active live timer before starting the new one — timer count stable across repeated switches | Stop-before-start sequence in `onMachineSelected_`; `timerfindall` invariant test |
| MACH-05 | Existing companion construction (`'Registry'`/`'Dashboards'` args, no Fleet) continues to work unchanged | Legacy path wraps into implicit Machine; grid and toolbar unchanged in legacy mode |

</phase_requirements>

---

## Summary

Phase 1044 adds a machine-selection dimension to the `FastSenseCompanion` three-pane uifigure. The primary change is a `MachineSelectorPane` — a new left-rail column present only when a `Fleet` is supplied — that is a nearly verbatim copy of the existing `TagCatalogPane` idiom (uilistbox + debounced `uieditfield`, `strfind(lower(...))` filtering, `ItemsData` for identity). The Fleet and Machine classes are fully implemented from Phase 1042; `Machine.find/get/keys` are already duck-type equivalents of `TagRegistry` static calls, so the four static `TagRegistry.find` call sites in `TagCatalogPane` and `FastSenseCompanion` redirect with minimal friction.

The most structurally important change is the conditional root-grid construction: when a Fleet is supplied the grid becomes `[3 4]` with a 170 px left-rail column and the toolbar inner grid expands from `[1 10]` to `[1 11]` to host the active-machine label. When no Fleet is supplied the layout is byte-identical to today. One pre-flight prerequisite from Phase 1042 is outstanding: `Fleet.MachineIds_` is private (`Access = private`) with no public iteration accessor — the planner must add `Fleet.machineIds()` returning `obj.MachineIds_` as a one-line public method before `MachineSelectorPane` can iterate in insertion order.

The `setProject(obj, dashboards, registry)` method at `FastSenseCompanion.m:725-799` already covers the full machine-switch behavior (detach+reattach panes, reset selection state, clear+rewire listeners with no accumulation). The machine-switch path in `onMachineSelected_` simply adds stop-before-start live-timer handling around that existing call. The backward-compat legacy path wraps the supplied `Registry`/`Dashboards` in an implicit `Machine` object so the active-context code is uniform — importantly the implicit Machine does not register tags into global `TagRegistry`, it merely holds a reference to the caller-supplied registry/dashboards.

**Primary recommendation:** Implement in five waves in dependency order: (1) `Fleet.machineIds()` accessor + implicit-Machine construction seam in `FastSenseCompanion`, (2) `MachineSelectorPane` pane class, (3) root-grid / toolbar conditional extension, (4) four call-site redirect + `onMachineSelected_` machine-switch wiring, (5) tests.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Machine list data + filtering | `MachineSelectorPane` | `Fleet` (data source) | Pane owns UI state (filter term, listbox Items); Fleet owns ordered catalog |
| Active-context state | `FastSenseCompanion` | `MachineSelectorPane` (notifies) | Companion is the orchestrator; pane fires selection, companion acts |
| Tag-catalog re-point on switch | `FastSenseCompanion.setProject` | `TagCatalogPane.attach` | setProject already wires registry reference into catalog |
| Dashboard-list re-point on switch | `FastSenseCompanion.setProject` | `DashboardListPane.attach` | Same setProject path |
| Live-timer stop/start on switch | `FastSenseCompanion.onMachineSelected_` | `startLiveMode` / `stopLiveMode` | Companion owns the timer; pane just fires ValueChanged |
| Active-machine indicator | `FastSenseCompanion` (toolbar label) | `MachineSelectorPane` (listbox highlight) | Toolbar label survives list scrolling (SC2) |
| Grid layout extension | `FastSenseCompanion` constructor | — | Conditional `[3 3]` vs `[3 4]` at construction time |
| Implicit-machine wrapping (legacy) | `FastSenseCompanion` constructor | `Machine` class | Wraps Registry/Dashboards so downstream code is uniform |
| Tag safety invariant (no global reg) | `Machine.addTag` + constructors | CI grep gate | Already enforced in Machine; implicit Machine is a holder not a registrar |

---

## Standard Stack

No new external dependencies. All work is pure MATLAB using existing project classes.

### Core

| Class / File | Location | Purpose | Phase Status |
|---|---|---|---|
| `MachineSelectorPane` | `libs/FastSenseCompanion/MachineSelectorPane.m` | NEW — left-rail uilistbox + debounced search + count badge | New file this phase |
| `FastSenseCompanion` | `libs/FastSenseCompanion/FastSenseCompanion.m` | Extended — Fleet NV pair, conditional grid, toolbar label, implicit-Machine construction, call-site redirect, `onMachineSelected_` | Extend existing |
| `Fleet` | `libs/Fleet/Fleet.m` | Extended — add `machineIds()` public accessor | One method addition |
| `Machine` | `libs/Fleet/Machine.m` | Unchanged — duck-type API `get/find/findByKind/findByLabel/keys` already present | No changes |
| `CompanionTheme` | `libs/FastSenseCompanion/CompanionTheme.m` | Unchanged — `Accent` token drives indicator color | No changes |
| `applyThemeToChildren_` | `libs/FastSenseCompanion/private/applyThemeToChildren_.m` | Unchanged — already covers ListBox/EditField/Label | No changes |

### Reusable Patterns (copy verbatim from existing code)

| Source | What to copy | Target |
|---|---|---|
| `TagCatalogPane.m:69-199` | uilistbox + search + debounce + count badge layout | `MachineSelectorPane.attach()` |
| `TagCatalogPane.m:343-386` | `onSearchChanged_` debounce idiom, `onClearSearch_` | `MachineSelectorPane.onSearchChanged_`, `onClearSearch_` |
| `TagCatalogPane.m:190-199` | `detach` listener iteration pattern | `MachineSelectorPane.detach` |
| `FastSenseCompanion.m:725-799` | `setProject` listener-clear pattern | `onMachineSelected_` wraps this call |
| `FastSenseCompanion.m:588-599` | `stop(t); delete(t)` timer teardown order | Machine-switch timer stop sequence |

**Installation:** No `npm install` or `pip install` — pure MATLAB code changes.

---

## Package Legitimacy Audit

N/A — this phase installs no external packages. All dependencies are existing project classes or MATLAB built-ins.

---

## Architecture Patterns

### System Architecture Diagram

```
FastSenseCompanion constructor
  |
  +-- [Fleet supplied?] ---YES---> build [3 4] grid + [1 11] toolbar
  |                                  |
  |                                  +-> create MachineSelectorPane (col 1)
  |                                  +-> create hActiveMachineLabel_ (toolbar col 10)
  |                                  +-> auto-select first machine
  |                                  +-> setProject(firstMachine.Dashboards, firstMachine)
  |
  +------ NO ---------> build [3 3] grid + [1 10] toolbar (byte-identical to today)
                         |
                         +-> wrap Registry/Dashboards in implicit Machine
                         +-> setProject(dashboards, implicitMachine)

User clicks different machine in MachineSelectorPane
  |
  +-> onMachineSelected_(selectedId)
        |
        +-> wasLive = obj.IsLiveMode_
        +-> [wasLive] stopLiveMode()        stop(t); delete(t) in that order
        +-> newMachine = fleet.getMachine(selectedId)
        +-> setProject(newMachine.Dashboards, newMachine)
              |
              +-> TagCatalogPane.attach(panel, fig, newMachine, theme)
              |     -> AllTags_ = newMachine.find(@(t) true)    [MACH-02: redirected call]
              +-> DashboardListPane.attach(...)
              +-> InspectorPane.attach(...)
              +-> re-wire Listeners_
        +-> updateActiveMachineIndicator_(newMachine)
        +-> [wasLive] startLiveMode()       fresh timer for new machine

onLiveTick_ (FastSenseCompanion.m:1614-1618)
  |
  +-> obj.Registry_.find(...)   [redirected: Registry_ IS the active Machine]
```

### Recommended Project Structure

```
libs/FastSenseCompanion/
├── FastSenseCompanion.m         (extend: Fleet NV, conditional grid, call-site redirect)
├── MachineSelectorPane.m        (NEW: left-rail machine list pane)
├── TagCatalogPane.m             (extend: line 60, 205 redirect to registry_.find)
├── DashboardListPane.m          (unchanged)
├── InspectorPane.m              (unchanged)
└── private/
    └── filterMachines_.m        (optional helper, or inline in MachineSelectorPane)

libs/Fleet/
└── Fleet.m                      (add Fleet.machineIds() public accessor — one line)

tests/suite/
└── TestFastSenseCompanion.m     (add machine-selector + switch + legacy tests)

tests/
└── test_machine_selector_pane.m (NEW: Octave-flat tests for pure-logic helpers)
```

### Pattern 1: MachineSelectorPane — TagCatalogPane Copy

**What:** The MachineSelectorPane is structurally identical to TagCatalogPane: a `[5 1]` root grid, row 1 = search strip (nested `[1 2]` sub-grid with editfield + clear button), row 2 = 8 px spacer, row 3 = uilistbox, row 4 = 4 px spacer, row 5 = count badge label.

**When to use:** Copy verbatim for all layout, debounce timer, and `strfind` filter logic. Diverge only where machines differ from tags (no pill filters, no grouping, simpler per-item format).

```matlab
% Source: TagCatalogPane.m:69-84 (verbatim structure)
hGrid = uigridlayout(obj.hPanel_, [5 1]);
hGrid.RowHeight     = {28, 8, '1x', 4, 24};
hGrid.ColumnWidth   = {'1x'};
hGrid.Padding       = [16 16 16 16];
hGrid.RowSpacing    = 0;
hGrid.BackgroundColor = theme.WidgetBackground;
```

### Pattern 2: Conditional Grid Construction

**What:** Constructor branches on `~isempty(userFleet)` to build either a `[3 4]` or `[3 3]` grid. All panel column assignments are set inside the branch.

**When to use:** At the start of "Step 8 — Root grid" in the constructor. The branch determines everything: grid dimensions, ColumnWidth, panel Layout.Column assignments, toolbar column count, and whether `MachineSelectorPane` and `hActiveMachineLabel_` are created.

```matlab
% Source: FastSenseCompanion.m:301-307 (to be extended)
% LEGACY (no Fleet):
obj.hLayout_ = uigridlayout(obj.hFig_, [3 3]);
obj.hLayout_.ColumnWidth = {220, '1x', 360};

% FLEET MODE:
obj.hLayout_ = uigridlayout(obj.hFig_, [3 4]);
obj.hLayout_.ColumnWidth = {170, 220, '1x', 360};
```

### Pattern 3: Machine-Switch Live-Timer Sequence

**What:** Capture live state, stop timer, call setProject, update indicator, conditionally restart. Wraps the entire body in try/catch; surface failures via `uialert` (non-blocking).

```matlab
% Source: UI-SPEC.md Interaction Contract > Machine Selection (Switch)
function onMachineSelected_(obj, selectedId)
    try
        wasLive = obj.IsLive;
        if wasLive
            obj.stopLiveMode();
        end
        newMachine = obj.Fleet_.getMachine(selectedId);
        obj.setProject(newMachine.Dashboards, newMachine);
        obj.updateActiveMachineIndicator_(newMachine);
        if wasLive
            obj.startLiveMode();
        end
    catch ME
        uialert(obj.hFig_, ME.message, 'Machine Switch Failed', 'Icon', 'error');
    end
end
```

### Pattern 4: Implicit-Machine Construction (Legacy Compat)

**What:** In the legacy path (no Fleet), wrap supplied Registry + Dashboards in a throw-away `Machine` shell so all downstream code (`setProject`, `onLiveTick_` call sites) reaches `Registry_.find(...)` uniformly.

```matlab
% Legacy path — wrapping for uniform downstream access
implicitMachine = Machine('Id', '__implicit__');
% Do NOT addTag — the implicit machine is a holder, not a registrar.
% Override find/get/keys by subclassing or adding a passthrough property.
% Simpler approach: store registry as obj.Registry_ directly;
% the redirect at call sites uses obj.Registry_.find(...) or
% (isempty(obj.Fleet_) ? TagRegistry.find(...) : obj.Registry_.find(...))
```

**Implementation note:** The simplest backward-compat approach is a conditional at the four redirect sites rather than a full Machine wrapper. Use `obj.Registry_` (which is already the TagRegistry in legacy mode) and change the four static `TagRegistry.find(pred)` calls to `obj.Registry_.find(pred)`. This works because `Machine.find(pred)` is already a duck-type equivalent, and in legacy mode `obj.Registry_` continues to be the TagRegistry handle (which has a static `find` callable as `obj.Registry_.find` via handle reference). The planner should pick the simplest form that satisfies the backward-compat invariant. [ASSUMED — verify that `TagRegistry.find` is callable as an instance method via a handle reference in MATLAB; if not, a thin conditional `if isempty(obj.Fleet_); TagRegistry.find(pred); else; obj.Registry_.find(pred); end` is the safe fallback.]

### Pattern 5: Fleet.machineIds() Accessor

**What:** One-line addition to Fleet's public methods. Required before MachineSelectorPane can iterate in insertion order.

```matlab
% Add to Fleet.m public methods block
function ids = machineIds(obj)
%MACHINEIDS Return insertion-ordered cell array of machine Ids.
%   ids = fleet.machineIds()
    ids = obj.MachineIds_;
end
```

**Verification:** `MachineIds_` is confirmed `Access = private` in `Fleet.m:55` with no existing public accessor. [VERIFIED: direct read of libs/Fleet/Fleet.m]

### Anti-Patterns to Avoid

- **Static TagRegistry.find call remaining after redirect:** Each of the four sites must be audited individually. A grep `grep -n "TagRegistry.find" libs/FastSenseCompanion/` should return 0 after implementation.
- **Listener accumulation on repeated `setProject` calls:** `setProject` already clears `obj.Listeners_` before re-wiring (`:773-799`). The machine-switch path calls `setProject` — do not add extra listener wiring outside of it.
- **Timer accumulation:** `stopLiveMode` stops but does NOT delete the timer (it keeps it for reuse). `startLiveMode` re-starts the same timer. On machine switch, stop before setProject, start after. The stop-before-start sequence ensures `timerfindall` count is stable.
- **Machine selector panel column assignment off by one:** In fleet mode, existing panels shift right by one column. `hLeftPanel_` moves from col 1 to col 2, `hMidPanel_` from col 2 to col 3, `hRightPanel_` from col 3 to col 4. Toolbar and log-strip span from `[1 3]` to `[1 4]`. Verify each Layout.Column assignment in the fleet branch.
- **Implicit machine registering tags into global TagRegistry:** The implicit machine must be a holder only. Never call `TagRegistry.register` from within the implicit Machine or during legacy construction. Critical invariant #1 from STATE.md.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Debounced search filter | Custom timer loop | Copy `TagCatalogPane.onSearchChanged_` verbatim | Already battle-tested with stop-before-restart, singleShot, BusyMode drop |
| Octave-safe substring match | `contains()` or regex | `strfind(lower(str), lower(term))` from `filterTags.m` / `filterDashboards.m` | `contains` is MATLAB-only; the existing pattern is proven across 4 files |
| Theme propagation to new controls | Manual color assignment | `applyThemeToChildren_(pane.hRoot_, theme)` | Walker already covers ListBox/EditField/Label/GridLayout; no walker extension needed |
| Machine switch state management | Custom state tracking | `setProject(machine.Dashboards, machine)` + existing selection reset | setProject already resets SelectedTagKeys_, SelectedDashboardIdx_, clears listeners |
| Insertion-order machine iteration | Custom sort or map iteration | `fleet.machineIds()` (new) + `fleet.getMachine(id)` | Fleet already stores insertion order in `MachineIds_`; just expose it |

**Key insight:** The MachineSelectorPane is intentionally a reduced TagCatalogPane — no pill filters, no groups, simpler per-item format. Resist adding complexity; the idiom is already proven at scale.

---

## Common Pitfalls

### Pitfall 1: Listener Accumulation via Repeated setProject

**What goes wrong:** Each `setProject` call adds listeners to `obj.Listeners_`. If machine switch calls `setProject` and does NOT clear first, every switch doubles the handler count.

**Why it happens:** `setProject` at `:773-779` does clear `obj.Listeners_` before re-wiring — but only if called correctly. If the machine-switch callback adds extra listeners outside of `setProject`, those accumulate.

**How to avoid:** Route all listener registration through `setProject`. Never call `addlistener` in `onMachineSelected_` directly.

**Warning signs:** `numel(obj.Listeners_)` growing with each machine switch in a test.

### Pitfall 2: Timer Count Drift Across Machine Switches

**What goes wrong:** Each machine switch that starts a new live timer without stopping the old one leaves an orphaned timer. `timerfindall` count grows with N switches.

**Why it happens:** `startLiveMode` is idempotent on its own (it checks `obj.IsLive` and returns early). But if the timer was stopped during switch and `obj.IsLive` was set false, calling `startLiveMode` again creates or re-starts correctly. The risk is the debounce timer in `MachineSelectorPane` — if `detach()` is not called before panel teardown, the DebounceTimer_ lingers.

**How to avoid:** (a) Ensure `MachineSelectorPane.detach()` stops and deletes `DebounceTimer_` (mirror TagCatalogPane detach which calls `detach_` on the debounce timer). (b) Companion `close()` teardown must include `MachineSelectorPane.detach()` in its cleanup sequence.

**Warning signs:** `timerfindall` count after N machine switches is not equal to count before switches.

### Pitfall 3: TagRegistry.find Called as Instance Method on TagRegistry Handle

**What goes wrong:** The four redirect sites change `TagRegistry.find(pred)` to `obj.Registry_.find(pred)`. In legacy mode `obj.Registry_` is a `TagRegistry` object. `TagRegistry.find` is a static method. Calling a static method via an instance handle may work in MATLAB (it does in R2020b+) but produces a style warning in MISS_HIT and is not officially supported idiom.

**Why it happens:** `TagRegistry` was designed as a static-method singleton (Approach ① from STATE.md). Its `find` method is `methods(Static)`.

**How to avoid:** Use a conditional at each redirect site: `if isempty(obj.Fleet_); tags = TagRegistry.find(pred); else; tags = obj.Registry_.find(pred); end`. This is explicit and warning-free.

**Warning signs:** MISS_HIT `mh_lint` warning about calling static method via instance handle.

### Pitfall 4: Panel Column Assignments Not Updated in Fleet Branch

**What goes wrong:** In fleet mode the root grid has 4 columns. If `hLeftPanel_`, `hMidPanel_`, `hRightPanel_` are assigned cols 1/2/3 (legacy values), they overlap with the new machine-selector panel in col 1.

**Why it happens:** The constructor builds panels sequentially; the column assignments at `:452-459` use hardcoded values that need to shift right by 1 in fleet mode.

**How to avoid:** Wrap panel Layout.Column assignments inside the same branch that sets `hMachineSelectorPanel_`. Explicitly assign: machine=1, tags=2, dashboards=3, inspector=4.

**Warning signs:** MachineSelectorPane renders on top of the tag catalog; or tag catalog is invisible.

### Pitfall 5: Toolbar Column Count Mismatch

**What goes wrong:** The toolbar inner grid is `[1 10]`. In fleet mode it must be `[1 11]`. If the gear button stays at col 10 and the indicator label is added at col 10, they overlap.

**Why it happens:** The toolbar is built once with hardcoded column count. The branch must set a different `ColumnWidth` and shift the gear button to col 11.

**How to avoid:** Build the toolbar grid inside the same conditional branch as the root grid, or post-construction reconfigure `ColumnWidth` and `hSettingsBtn_.Layout.Column`. The planner should pick the cleaner of the two.

**Warning signs:** Gear button invisible or overlapping active-machine label.

### Pitfall 6: usejava('desktop') Check for ASCII Fallback

**What goes wrong:** The active-machine indicator prefix uses `char(9658)` (▶). On Octave or headless runs `usejava('desktop')` returns false and the glyph may not render.

**Why it happens:** Octave does not have Java; headless MATLAB CI may not have a display.

**How to avoid:** `prefix = char(9658); if ~usejava('desktop'); prefix = '>'; end` before setting the label text. This is already documented in the UI-SPEC.

**Warning signs:** Garbled or empty label prefix in CI test output.

### Pitfall 7: MachineSelectorPane Detach Not Hoisted into close() Sequence

**What goes wrong:** `FastSenseCompanion.close()` at `:624-627` iterates through pane detach calls. If `MachineSelectorPane` is not included, its debounce timer and panel children are not cleaned up, leaving orphaned timers.

**How to avoid:** Add `if ~isempty(obj.MachineSelectorPane_) && isvalid(obj.MachineSelectorPane_); obj.MachineSelectorPane_.detach(); end` in the close() teardown sequence, alongside the existing CatalogPane/ListPane/InspectorPane detach calls.

---

## Runtime State Inventory

> Section applies to this phase? No — this is a greenfield UI extension (new pane, grid extension). No rename/refactor/migration of stored data is involved. Machine identity (`Fleet`, `Machine.Id`) is set by user construction scripts and does not change.

Not applicable — no rename, no stored data migration.

---

## Implementation Sequencing

The natural dependency order for the plan waves:

### Wave 0 — Pre-flight Prerequisite (no existing tests to green first)
- Add `Fleet.machineIds()` public accessor (one method, one test)
- Add `test_fleet_machine_ids.m` (Octave-flat, pure-logic)

### Wave 1 — MachineSelectorPane (new file, isolated)
- `libs/FastSenseCompanion/MachineSelectorPane.m` — copy TagCatalogPane structure, strip pills/groups, add `filterMachines_` private helper
- `tests/test_machine_selector_pane.m` — test `filterMachines_` logic headless (Octave-flat)

### Wave 2 — Conditional Grid / Toolbar Extension in FastSenseCompanion
- Constructor: `'Fleet'` NV pair parsing + validation
- Conditional grid `[3 3]` vs `[3 4]`, panel column assignments, toolbar `[1 10]` vs `[1 11]`
- `hActiveMachineLabel_` creation in fleet mode
- Implicit-Machine construction seam in legacy path
- `close()` teardown: add `MachineSelectorPane.detach()` call

### Wave 3 — Four Call-Site Redirect + Machine Switch Wiring
- `TagCatalogPane.m:60` and `:205` — redirect `TagRegistry.find` to `obj.Registry_.find` (with conditional for legacy)
- `FastSenseCompanion.m:1616` and `:1618` — redirect `TagRegistry.find` to `obj.Registry_.find` (with conditional)
- `onMachineSelected_(obj, selectedId)` — stop-live, setProject, update indicator, restart-live
- `updateActiveMachineIndicator_(obj, machine)` — update label text + tooltip

### Wave 4 — Tests
- `TestFastSenseCompanion.m` additions: fleet construction, legacy unchanged, machine switch timer stability (MACH-04), active-machine indicator label, setProject-call-site re-point

This sequence keeps each wave independently testable and prevents the common pitfall of wiring before the pane class exists.

---

## Backward-Compat Test Strategy

The following checks assert MACH-05 (legacy unchanged):

1. **Grid dimensions:** `struct(app).hLayout_.ColumnWidth` is `{220, '1x', 360}` (legacy) vs `{170, 220, '1x', 360}` (fleet).
2. **Panel handles:** In legacy mode, `hMachineSelectorPanel_` field is empty or absent; `hActiveMachineLabel_` is empty or absent.
3. **Toolbar grid:** In legacy mode, toolbar inner grid has 10 columns; in fleet mode, 11.
4. **setProject with TagRegistry:** `app.setProject({d}, TagRegistry)` must not throw in legacy mode — existing test `testSetProjectReplacesState` covers this.
5. **timerfindall invariant (MACH-04):** `timersBefore = numel(timerfindall); app = FastSenseCompanion('Dashboards', {...}); app.close(); assertEqual(numel(timerfindall), timersBefore)` — the existing `testCloseCleanup` already asserts this pattern; extend it to fleet construction.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | MATLAB `matlab.unittest.TestCase` (class suites) + Octave function-based (flat tests) |
| Config file | `tests/run_all_tests.m` (test discovery) |
| Quick run command | `mcp__matlab__run_matlab_test_file('tests/suite/TestFastSenseCompanion.m')` |
| Full suite command | `mcp__matlab__run_matlab_file('tests/run_all_tests.m')` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MACH-01 | `filterMachines_` pure logic: empty term = all, term matches Name, term matches Id, no match = empty | Unit | `mcp__matlab__run_matlab_file('tests/test_machine_selector_pane.m')` | ❌ Wave 1 |
| MACH-01 | Fleet.machineIds() returns insertion-order cell | Unit | `mcp__matlab__run_matlab_file('tests/test_fleet.m')` | ✅ extend |
| MACH-02 | Machine switch calls setProject; TagCatalogPane snapshot is from new machine (not global registry) | Integration (class suite) | `mcp__matlab__run_matlab_test_file('tests/suite/TestFastSenseCompanion.m')` | ❌ Wave 4 |
| MACH-03 | `hActiveMachineLabel_` has correct text `char(9658) + ' Name [Id]'` after switch | Integration (class suite) | same | ❌ Wave 4 |
| MACH-04 | `timerfindall` count stable across 5 machine switches with live mode on | Integration (class suite) | same | ❌ Wave 4 |
| MACH-05 | Legacy construction (`Registry`/`Dashboards`, no Fleet): grid is `[3 3]`, `hMachineSelectorPanel_` absent, toolbar has 10 cols | Integration (class suite) | same | ❌ Wave 4 (extend existing) |

### Headless vs. Needs-uifigure Split

| Test category | Headless (Octave-flat, no uifigure) | Needs MATLAB + uifigure (class suite) |
|---|---|---|
| `filterMachines_` logic | YES — `test_machine_selector_pane.m` | — |
| `Fleet.machineIds()` | YES — `test_fleet.m` extension | — |
| Implicit-Machine construction | YES — pure logic, no UI | — |
| MachineSelectorPane construction | NO — requires uifigure | TestFastSenseCompanion |
| Machine switch timer invariant (MACH-04) | NO | TestFastSenseCompanion |
| Active-machine label content | NO | TestFastSenseCompanion |
| Legacy grid byte-identical | NO | TestFastSenseCompanion |

The class suite `TestFastSenseCompanion` already has `gateHeadlessLinux` (skips on headless Linux) and `skipOnOctave` guards. New tests for this phase follow the same pattern.

### Timer-Accumulation Invariant Test (highest-value assertion)

```matlab
% To add to TestFastSenseCompanion.m
function testMachineSwitch_TimerStable(testCase)
%TESTMACHINESWITCH_TIMERSTABLE MACH-04: timerfindall count stable across N switches.
    fleet = Fleet();
    fleet.addMachine('Id', 'M01', 'Name', 'Machine 1');
    fleet.addMachine('Id', 'M02', 'Name', 'Machine 2');
    fleet.addMachine('Id', 'M03', 'Name', 'Machine 3');
    app = FastSenseCompanion('Fleet', fleet);
    testCase.addTeardown(@() app.close());
    app.startLiveMode();
    timersBefore = numel(timerfindall);
    % Simulate 5 machine switches
    s = struct(app);
    for i = 1:5
        id = fleet.machineIds(){mod(i,2)+1};   % alternate M01/M02
        s.MachineSelectorPane_.selectMachineById(id);   % or direct call
    end
    timersAfter = numel(timerfindall);
    testCase.verifyEqual(timersAfter, timersBefore, ...
        'MACH-04: timerfindall count must be stable across machine switches');
end
```

Note: The exact invocation of the switch (via `selectMachineById` vs. direct `onMachineSelected_` call) is a planner decision; the test shape is fixed.

### Sampling Rate

- **Per task commit:** Run `TestFastSenseCompanion.m` (class suite) on MATLAB
- **Per wave merge:** `test_fleet.m` + `test_machine_selector_pane.m` + `TestFastSenseCompanion.m`
- **Phase gate:** Full suite (`run_all_tests.m`) green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `tests/test_machine_selector_pane.m` — covers MACH-01 (filterMachines_ pure logic)
- [ ] `tests/suite/TestFastSenseCompanion.m` — extend with MACH-02, MACH-03, MACH-04, MACH-05 tests (4 new test methods minimum)

---

## Security Domain

No security-relevant changes: no authentication, no session management, no external input parsing beyond MATLAB uifigure callback values. The `Fleet` NV pair validation follows the same pattern as existing constructor option validation (class check + error on wrong type). No ASVS categories apply.

---

## Environment Availability

> Step 2.6 result.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| MATLAB R2020b+ | `uifigure`, `uilistbox`, `uieditfield` | ✓ (dev machine) | macOS ARM64 | — |
| Octave 7+ | Flat tests only | ✓ | CI | — |
| `Machine` class | MachineSelectorPane data source | ✓ | Phase 1042 complete | — |
| `Fleet` class | Constructor Fleet NV pair | ✓ | Phase 1042 complete | — |
| `Fleet.machineIds()` | MachineSelectorPane iteration | ✗ (not yet public) | — | Iterate via `machineCount()+getMachine(id)` using `fleet.machineIds()` once added |

**Missing dependencies with no fallback:**
- `Fleet.machineIds()` — must be added as Wave 0. Without it, `MachineSelectorPane` cannot iterate in insertion order. Workaround if deferred: use `fleet.filterByName('')` which returns all machines in insertion order (confirmed in Fleet.m:114-131 — it iterates `obj.MachineIds_`).

**Missing dependencies with fallback:**
- `Fleet.machineIds()` fallback: `fleet.filterByName('')` returns all machines in insertion order (leverages the same `MachineIds_` iteration internally). This is an acceptable temporary workaround but adding the explicit accessor is cleaner and was flagged in UI-SPEC.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Static `TagRegistry.find(pred)` at four call sites | `obj.Registry_.find(pred)` (instance call, duck-typed) | This phase | Enables per-machine catalog; existing legacy path continues via same handle (TagRegistry) |
| No Fleet support in constructor | `'Fleet', fleetObj` NV pair | This phase | Additive; no breaking change |
| `[3 3]` root grid always | `[3 3]` legacy / `[3 4]` fleet | This phase | Conditional construction; legacy byte-identical |
| `[1 10]` toolbar always | `[1 10]` legacy / `[1 11]` fleet | This phase | Same conditional |

**Deprecated/outdated:**
- Nothing deprecated — this is purely additive. The static `TagRegistry.find` calls remain valid in legacy mode; only redirected in the four sites.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `TagRegistry.find` is callable via an instance handle (`obj.Registry_.find(pred)`) in MATLAB R2020b+ without error | Pattern 3 / Pitfall 3 | Must use conditional `if isempty(Fleet_); TagRegistry.find(pred); else; obj.Registry_.find(pred); end` — low effort to fix, plan should use the conditional form to be safe |
| A2 | `MachineSelectorPane.detach()` will be structured to stop + delete `DebounceTimer_` (mirror TagCatalogPane) | Pitfall 2 | If not done, debounce timer leaks on close; caught by `timerfindall` test |
| A3 | `stopLiveMode()` stops but keeps the timer (for reuse); `startLiveMode()` re-starts the same timer | Pattern 3, implementation note | Confirmed by reading `FastSenseCompanion.m:892-905`: `stopLiveMode` calls `stop(obj.LiveTimer_)` but does NOT delete it. `startLiveMode` at `:871-879` creates only if empty/invalid, then starts. Stop-before-start on machine switch is therefore: `stopLiveMode()` (stops), `setProject(...)`, `startLiveMode()` (restarts existing timer). No accumulation. [VERIFIED: direct read] |
| A4 | `close()` timer teardown at `:588-599` deletes the timer (`delete(obj.LiveTimer_)`) — this is distinct from `stopLiveMode` which does not delete | Pitfall 2 | [VERIFIED: direct read] Close teardown calls `stop` + `delete`; stopLiveMode calls only `stop`. The distinction is intentional and correct. |

**If this table is empty:** N/A — A1 should be confirmed by the executor; A2–A4 are noted for completeness but A3/A4 are already verified.

---

## Open Questions (RESOLVED)

> Both questions are resolved: the plan adopts the explicit-conditional redirect form (Q1) and the `MachineSelectorPane.selectById(id)` public test seam (Q2).

1. **`TagRegistry.find` via instance handle (A1)** — RESOLVED: explicit conditional form adopted at all four sites (Plan 1044-04).
   - What we know: `Machine.find(pred)` is an instance method that mirrors `TagRegistry.find`. In legacy mode `obj.Registry_` is a `TagRegistry` object. MATLAB allows calling static methods via instance handles with a warning.
   - What's unclear: Whether MISS_HIT `mh_lint` will flag `obj.Registry_.find(pred)` when `obj.Registry_` is a `TagRegistry` (static-method class).
   - Recommendation: Use the explicit conditional form at all four sites. Two lines per site, zero ambiguity, no linter surprises.

2. **`selectMachineById` vs direct callback in test**
   - What we know: Tests need to trigger machine switch programmatically without a real UI click.
   - What's unclear: Whether the planner will add a public `selectMachineById(id)` method to `MachineSelectorPane` or expose `onMachineSelected_` through the companion.
   - Recommendation: Add `MachineSelectorPane.selectById(id)` as a `(Access = public)` test seam that updates listbox Value and fires the switch sequence. Follows the existing `getSelectedKeys` public test-seam pattern in TagCatalogPane.

---

## Sources

### Primary (HIGH confidence)

- Direct read: `libs/FastSenseCompanion/FastSenseCompanion.m` — constructor structure `:170-307`, setProject `:725-799`, close() `:570-715`, startLiveMode/stopLiveMode `:867-915`, onLiveTick_ `:1614-1618`
- Direct read: `libs/FastSenseCompanion/TagCatalogPane.m` — layout `:69-199`, detach `:190-199`, onSearchChanged_ `:342-362`, applyFilter_ `:300-340`, attach `:45-84`
- Direct read: `libs/Fleet/Fleet.m` — `MachineIds_` private `:55`, `getMachine` `:95-106`, `machineCount` `:108-112`, `filterByName` `:114-131`
- Direct read: `libs/Fleet/Machine.m` — duck-type API `find/get/keys` `:171-200`, `Dashboards` property `:68`
- Direct read: `libs/FastSenseCompanion/private/applyThemeToChildren_.m` — covered widget classes `:15-24`
- Direct read: `tests/suite/TestFastSenseCompanion.m` — `timerfindall` test pattern `:137-143`, headless guards `:9-30`, `struct(app)` private-field access pattern `:123`
- Direct read: `.planning/phases/1044-companion-machine-dimension/1044-UI-SPEC.md` — grid/toolbar dimensions, copywriting contract, debounce pattern, filter logic
- Direct read: `.planning/phases/1044-companion-machine-dimension/1044-CONTEXT.md` — all locked decisions
- Direct read: `.planning/STATE.md` — critical invariants, cross-cutting engineering constraints

### Secondary (MEDIUM confidence)

- `tests/suite/TestFleet.m`, `tests/test_fleet.m` — confirm Fleet test infrastructure exists; can extend for `machineIds()` test

### Tertiary (LOW confidence)

- None — all claims verified by direct codebase read.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all classes verified by direct read; no external dependencies
- Architecture: HIGH — grid coordinates, method signatures, and call sites all directly read and cross-referenced with UI-SPEC
- Pitfalls: HIGH — derived from direct inspection of setProject, close(), timer teardown, and existing test patterns
- Backward-compat strategy: HIGH — setProject and legacy constructor path directly read

**Research date:** 2026-06-08
**Valid until:** 2026-07-08 (stable internal codebase; no external dependencies)
