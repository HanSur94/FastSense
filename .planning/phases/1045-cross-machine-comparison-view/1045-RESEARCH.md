# Phase 1045: Cross-Machine Comparison View — Research

**Researched:** 2026-06-10
**Domain:** MATLAB uifigure dialog (R2020b+), CanonicalMapper API, openAdHocPlot extension, per-machine color assignment
**Confidence:** HIGH — all findings sourced from direct codebase reads

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Entry point:** fleet-mode toolbar "Compare" button only. Legacy (no-Fleet) toolbar stays byte-identical.
- **Dialog pattern:** Singleton modeless second uifigure (`CompareBuilderDlg_` on companion), `CompanionSettingsDialog` lifecycle exactly.
- **Machine list:** One row-grid per fleet machine — checkbox + machine name + per-row resolution dropdown + status badge. Not uilistbox.
- **Data selection:** Top quick-fill `uidropdown` (logical IDs from `CanonicalMapper`) + per-row override dropdowns.
- **Color scheme:** Fleet-insertion-index → `CompanionTheme.LineColors` palette (modulo). Deterministic per machine.
- **Injection API:** Additive optional NV args on `openAdHocPlot`: `'SeriesColors'` (cell of RGB triples) + `'SeriesLabels'` (cellstr). Legacy calls unchanged.
- **Legend label:** `[machineName]: [sensorDisplayName]`
- **LOW-confidence gate:** Per-row inline — excluded-by-default, "needs confirm" badge. No batch modal.
- **Unit mismatch:** Inline row warning badge + consolidated non-blocking `uialert` at Open. Never blocks.
- **Promotion:** Per-row "Promote" action calls `CanonicalMapper.override(logicalId, machineId, localKey)`. In-memory only.
- **Missing sensor:** `— none —`, machine excluded. Consolidated skip alert + events-log entry at Open.
- **Caching (CMP-05):** All tags resolved once at Open. Overlay live path calls `updateData` only. `CanonicalMapper.resolve` absent from tick profile.
- **setProject:** NOT to be touched. Locked.

### Claude's Discretion

Planner may refine: exact dialog grid dims/labels (pinned in UI-SPEC), badge glyphs/copy (pinned in UI-SPEC), error IDs (`FastSenseCompanion:*` / `CompareBuilderDialog:*`), dropdown population helpers, test file naming.

### Deferred Ideas (OUT OF SCOPE)

- Auto `Fleet.save` after promote.
- Linestyle variation on palette exhaustion.
- Comparison presets / saved comparisons.
- Time-period layer comparison (TrendMiner-style).
- Per-machine dashboard clone/remap (Phase 1046).

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CMP-01 | User builds comparison via quick-fill or per-machine tag; overlays on one axes | UI-SPEC dialog + openAdHocPlot Overlay path; `Fleet.resolveLogical` provides pairs |
| CMP-02 | Stable per-machine colors and machine-qualified legend labels | `CompanionTheme.LineColors` + `Fleet.machineIds()` insertion index; new NV args on `openAdHocPlot` |
| CMP-03 | Machine lacking sensor shows `— none —`, skipped gracefully with warning | Row state machine in UI-SPEC; `Fleet.resolveLogical` returns only resolvable pairs; manual skip alert |
| CMP-04 | LOW-confidence / unreviewed matches excluded; unit mismatch warned | `CanonicalMapper.isResolvable` + entry confidence/status check (see below for exact API) |
| CMP-05 | Tags resolved once at open; `CanonicalMapper.resolve` absent from tick profile | Resolve-at-open cache in `CompareBuilderDialog.onOpenComparison_`; UI-SPEC Step 6 |
| CMP-06 | Per-row data independent: accept auto, confirm low, pick override, skip, promote | UI-SPEC row state machine (auto/confirm_needed/override/none) + promote path |

</phase_requirements>

---

## Summary

Phase 1045 adds a `CompareBuilderDialog` modeless second uifigure and wires it into the fleet-mode companion toolbar. The entire resolution and color-assignment flow is pre-resolvable at dialog-open time, making the steady-state live tick free of `CanonicalMapper` calls (invariant #5).

The most important finding from the codebase read is that **`CanonicalMapper` has NO `resolve()` method**. The UI-SPEC references `CanonicalMapper.resolve(logicalId, machineId)` in its state-transition rules, but the real API uses `isResolvable(logicalId, machineId)` (returns bool) to gate the confidence check, and direct bucket access via `Entries_(logicalId)` to extract the `localKey` and `confidence`. The compound lookup the dialog needs is: for a given `(logicalId, machineId)`, read the entry struct to get `localKey`, `confidence`, and `status`. This is a two-step lookup that the dialog helper must implement internally — or a new `resolve()` method must be added to `CanonicalMapper` as part of this phase. The plan should include adding `CanonicalMapper.resolve(logicalId, machineId)` → `struct (localKey, confidence, status, unitMismatch)` as Plan 01's first task.

The `openAdHocPlot` extension is clean: the function currently accepts `(tags, mode, themePreset)` with `plotOverlay_` using MATLAB's `ColorOrder` auto-assignment. Adding optional `'SeriesColors'` / `'SeriesLabels'` NV args after `themePreset` via `inputParser` is straightforward; all legacy callers pass exactly 3 positional args and are unaffected.

**Primary recommendation:** Implement `CanonicalMapper.resolve` first (Plan 01), extend `openAdHocPlot` NV args second (Plan 02), build `CompareBuilderDialog` third (Plans 03–04), wire toolbar + companion close in Plan 05.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dialog UI (machine rows, dropdowns, badges) | FastSenseCompanion layer (CompareBuilderDialog) | — | Second uifigure owned by companion; pure UI, no data model |
| Confidence gate + row state | CompareBuilderDialog (dialog logic) | CanonicalMapper (data) | Dialog reads `isResolvable` + entry bucket; CanonicalMapper owns data |
| Per-machine color assignment | CompareBuilderDialog helper | CompanionTheme.LineColors | Color is a UI concern keyed by fleet insertion index |
| Resolution assembly (logicalId → tag cell) | Fleet.resolveLogical + new CanonicalMapper.resolve | CompareBuilderDialog | Data layer owns resolution; dialog consumes it |
| Overlay rendering | DashboardEngine / RawAxesWidget (via openAdHocPlot) | — | Existing rendering path unchanged except for explicit color/label injection |
| Promotion (override → CanonicalMapper) | CanonicalMapper.override (existing) | CompareBuilderDialog (caller) | CanonicalMapper already has override(); dialog just calls it |
| Fleet-mode toolbar button | FastSenseCompanion (toolbar construction) | — | Conditional on `~isempty(obj.Fleet_)`; same pattern as 1044 active-machine label |
| Resolve-once caching | CompareBuilderDialog.onOpenComparison_ | — | Cache is local to the dialog, populated at Open, never re-called during ticks |

---

## Standard Stack

### Core (all existing — no new packages)

| Component | Version/Location | Purpose | Status |
|-----------|----------------|---------|--------|
| `CanonicalMapper` | `libs/Fleet/CanonicalMapper.m` | Entry lookup, confidence gate, override | Exists; needs `resolve()` added |
| `Fleet.resolveLogical` | `libs/Fleet/Fleet.m:158` | logicalId → Nx2 {Machine, Tag} pairs | Exists, used as-is |
| `Fleet.machineIds()` | `libs/Fleet/Fleet.m:114` | Insertion-order machine ID cell | Exists (1044) |
| `CompanionSettingsDialog` | `libs/FastSenseCompanion/CompanionSettingsDialog.m` | Lifecycle/pattern to copy | Exists |
| `openAdHocPlot` | `libs/FastSenseCompanion/private/openAdHocPlot.m` | Overlay render + live engine | Exists; gains NV args |
| `CompanionTheme.LineColors` | `libs/FastSenseCompanion/CompanionTheme.m:60` | `num2cell(LineColorOrder, 2)'` → cell of 1×3 row vectors | Exists |
| `DashboardListPane` row-grid pattern | `libs/Dashboard/DashboardListPane.m:246` | Per-row `uigridlayout` nested in scrollable `uipanel` | Reference pattern only |
| `applyThemeToChildren_` | companion private helper | Recursive theme walker | Exists; no new widget types for this phase |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `Machine.get(localKey)` | Retrieve Tag by local key from machine catalog | Used by CompareBuilderDialog to populate per-row dropdown items |
| `Machine.keys()` | All local keys in machine catalog | Populate per-row override dropdown |
| `CanonicalMapper.keys()` / `Entries_` | All logical IDs with mappings | Populate quick-fill sensor dropdown |
| `uiconfirm` | Promote confirmation dialog | R2020b-safe; use `CloseFcn` callback pattern (async) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Additive NV args on `openAdHocPlot` | Struct-array input | NV args are additive, legacy-safe; struct-array would break existing callers |
| Fleet-insertion-index modulo palette | Id-hash palette | Insertion index gives stable, user-predictable ordering; hash is less obvious |

**Installation:** No new packages. Pure MATLAB, no npm, no pip, no mex.

---

## Package Legitimacy Audit

Not applicable — this phase installs no external packages. All dependencies are existing in-repo code.

---

## Architecture Patterns

### System Architecture Diagram

```
User clicks Compare (fleet toolbar, col 9)
    │
    ▼
FastSenseCompanion.openCompareBuilder_()
    │
    ├─ isvalid(CompareBuilderDlg_.hFig_)?
    │      YES → figure(hFig_)  [bring to front]
    │      NO  → CompareBuilderDialog(obj)
    │
    ▼
CompareBuilderDialog (modeless uifigure, 600×480)
    │
    ├─ Quick-fill uidropdown ─── CanonicalMapper.keys()
    │       ValueChanged ──► resolveAllRows_()
    │                              │
    │                    Fleet.resolveLogical(logicalId) → Nx2 pairs
    │                    CanonicalMapper.resolve(logId, machId) → entry struct
    │                              │
    │                    per-row state: auto | confirm_needed | override | none
    │
    ├─ Per-row checkbox, dropdown, badge, action button
    │   ValueChanged ──► onRowCheckChanged_ / onRowDropdownChanged_
    │                              │
    │                    rebuildRows_() (in-place widget update)
    │
    └─ "Open Comparison" pressed
            │
            ├─ unit-mismatch uialert (non-blocking, if any)
            ├─ skipped uialert + addLogEntry (non-blocking, if any)
            ├─ resolve-once cache: ResolvedTags_{i} = tag handle
            ├─ build SeriesColors cell + SeriesLabels cellstr
            │
            ▼
        openAdHocPlot(tags, 'Overlay', themePreset,
                      'SeriesColors', seriesColors,
                      'SeriesLabels', seriesLabels)
            │
            └─ plotOverlay_: sets axes ColorOrder → plots each tag with
                             explicit DisplayName → legend
            │
            └─ engine.startLive()  ← only updateData() in tick; no resolve
            │
            └─ App_.trackOpenedFigure_(hFig)
```

### Recommended Project Structure

```
libs/Fleet/
├── CanonicalMapper.m          # gains resolve() method (Plan 01)
libs/FastSenseCompanion/
├── CompareBuilderDialog.m     # new (Plan 03–04)
├── private/
│   └── openAdHocPlot.m        # gains SeriesColors/SeriesLabels NV args (Plan 02)
│   └── buildCompareResolution_.m  # optional: pure-logic resolution helper (Plan 01)
tests/
├── test_compare_resolution.m  # flat Octave-safe test for resolution assembly (Plan 01)
├── test_open_ad_hoc_plot_series_colors.m  # flat MATLAB-only test for NV args (Plan 02)
tests/suite/
└── TestFastSenseCompanion.m   # CMP-01..06 class-suite tests appended (Plan 05)
```

### Pattern 1: CanonicalMapper Entry Lookup (Exact API — CRITICAL)

`CanonicalMapper` has **no `resolve()` method**. The existing API for the dialog's needs:

```matlab
% EXISTING API (CanonicalMapper.m lines 292-310) [VERIFIED: direct read]
% isResolvable(logicalId, machineId) → logical
%   Returns false for LOW+AUTO entries and unconfirmed unit mismatches.
ok = mapper.isResolvable(logicalId, machineId);

% EXISTING API: direct Entries_ bucket access (CanonicalMapper.m line 53)
% mapper.Entries_ is containers.Map: logicalId -> cell of entry structs
% Each entry struct has fields:
%   logicalId, machineId, localKey, localName, localUnits,
%   similarity, confidence, status, unitMismatch
% confidence: 'HIGH' | 'MEDIUM' | 'LOW'
% status: 'AUTO' | 'CONFIRMED' | 'OVERRIDDEN' | 'PENDING'
if isKey(mapper.Entries_, logicalId)
    bucket = mapper.Entries_(logicalId);   % cell of entry structs
    for i = 1:numel(bucket)
        if strcmp(bucket{i}.machineId, machineId)
            e = bucket{i};   % e.localKey, e.confidence, e.status, e.unitMismatch
            break;
        end
    end
end

% EXISTING API: override() (CanonicalMapper.m lines 215-248) [VERIFIED: direct read]
% override(logicalId, machineId, localKey)
%   Creates OVERRIDDEN, HIGH-confidence entry. Uses LastTagInfos_ to populate
%   localName and localUnits — LastTagInfos_ must be populated (suggest() called).
mapper.override(logicalId, machineId, localKey);

% NEEDED: add resolve() to CanonicalMapper (Plan 01)
% resolve(logicalId, machineId) → entry struct or []
%   Returns the entry struct for (logicalId, machineId) or [] if none.
%   No side effects. Replaces the inline bucket-scan in dialog code.
```

**Plan 01 task:** Add `resolve(obj, logicalId, machineId)` to `CanonicalMapper` — returns the entry struct (or `[]`). This is the method referenced by UI-SPEC and CMP-05 (absent from tick profile = this method must never be called from the live tick).

### Pattern 2: openAdHocPlot NV Extension

```matlab
% CURRENT SIGNATURE (openAdHocPlot.m:1) [VERIFIED: direct read]
function [hFig, skippedNames] = openAdHocPlot(tags, mode, themePreset)

% plotOverlay_ (openAdHocPlot.m:142-157) — current color assignment:
% MATLAB ColorOrder auto-cycles; DisplayName = char(names{k})
plot(ax, tv, y, 'DisplayName', char(names{k}), 'LineWidth', 1.2);

% EXTENDED SIGNATURE (Plan 02):
function [hFig, skippedNames] = openAdHocPlot(tags, mode, themePreset, varargin)
% Parse varargin with inputParser:
%   'SeriesColors' — 1×N cell of [1×3 RGB]; numel must match numel(tags) or be absent
%   'SeriesLabels' — 1×N cellstr; legend labels; numel must match numel(tags) or be absent
% Validation error: openAdHocPlot:seriesColorsMismatch (if numel ~= numel(tags))

% In Overlay branch, when SeriesColors present:
%   ax.ColorOrder = cell2mat(seriesColors);   % set before hold/plot
%   ax.ColorOrderIndex = 1;                   % reset cycle
%   plot(..., 'Color', seriesColors{k}, 'DisplayName', seriesLabels{k}, ...)
% When absent: existing ColorOrder auto-assignment unchanged.

% Legacy callers: openAdHocPlot(tags, mode, themePreset) — 3 positional args,
% no varargin elements, inputParser defaults kick in, behavior unchanged.
```

**Key detail:** `ax.ColorOrder = cell2mat(seriesColors)` sets the axes color cycle before `hold on` + plotting loop. Each `plot(...)` call then uses the cycle in order — OR pass `'Color', seriesColors{k}` explicitly per series for determinism. Explicit per-series `'Color'` is cleaner and immune to `ColorOrderIndex` state.

### Pattern 3: CompareBuilderDialog Lifecycle (CompanionSettingsDialog exact copy)

```matlab
% In FastSenseCompanion: (mirrors openSettings_, FastSenseCompanion.m:1216-1226)
function openCompareBuilder_(obj)
    if ~isempty(obj.CompareBuilderDlg_) && isvalid(obj.CompareBuilderDlg_) && ...
            ~isempty(obj.CompareBuilderDlg_.hFig_) && ...
            isvalid(obj.CompareBuilderDlg_.hFig_)
        figure(obj.CompareBuilderDlg_.hFig_);   % bring to front
        return;
    end
    obj.CompareBuilderDlg_ = CompareBuilderDialog(obj);
end

% In FastSenseCompanion.close() (mirrors SettingsDlg_ teardown, line 836-843):
try
    if ~isempty(obj.CompareBuilderDlg_) && isvalid(obj.CompareBuilderDlg_)
        delete(obj.CompareBuilderDlg_);
    end
catch err
    fprintf(2, '[FastSenseCompanion] CompareBuilderDlg cleanup failed: %s\n', err.message);
end
obj.CompareBuilderDlg_ = [];

% Property declaration (friend-class pattern, mirrors SettingsDlg_ line 64-65):
properties (GetAccess = public, SetAccess = ?CompareBuilderDialog)
    CompareBuilderDlg_ = []
end

% In CompareBuilderDialog.close():
obj.App_.CompareBuilderDlg_ = [];   % write via friend-class SetAccess
delete(obj.hFig_);
obj.hFig_ = [];
```

### Pattern 4: Toolbar Column Extension (Fleet-Mode Only)

```matlab
% CURRENT fleet-mode toolbar (FastSenseCompanion.m:385-386): [VERIFIED: direct read]
hToolbarGrid = uigridlayout(obj.hToolbarPanel_, [1 11]);
hToolbarGrid.ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, '1x', 'fit', 36};
%  col 9  = '1x' spacer
%  col 10 = 'fit' active-machine label
%  col 11 = 36px Gear

% PHASE 1045: [1 12] fleet-mode toolbar:
hToolbarGrid = uigridlayout(obj.hToolbarPanel_, [1 12]);
hToolbarGrid.ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, 80, '1x', 'fit', 36};
%  col 9  = 80px Compare button (NEW)
%  col 10 = '1x' spacer (shifted)
%  col 11 = 'fit' active-machine label (shifted)
%  col 12 = 36px Gear (shifted)

% hActiveMachineLabel_.Layout.Column: 10 → 11
% hSettingsBtn_.Layout.Column: 11 → 12

% Legacy (no Fleet): [1 10] toolbar unchanged — byte-identical.
```

**Important:** The active-machine label column assignment (`gearColumn` logic, line 519) and gear column must both shift. The existing code uses `gearColumn = 11` in fleet mode — this becomes `12` in Phase 1045.

### Pattern 5: Row State Machine — Resolution Assembly

```matlab
% For each machine at quick-fill sensor selection:
function rowState = resolveRowState_(mapper, fleet, logicalId, machineId)
    % Step 1: Does this machine have any entry for this logicalId?
    e = mapper.resolve(logicalId, machineId);  % new method (Plan 01)
    if isempty(e)
        % No mapping at all — check if Fleet.resolveLogical has a pair
        % (it uses Entries_ directly, no confidence gate)
        rowState.state    = 'none';
        rowState.localKey = '';
        rowState.confidence = '';
        return;
    end
    % Step 2: Confidence gate
    isBlocked = (strcmp(e.status, 'AUTO') && strcmp(e.confidence, 'LOW'));
    if isBlocked
        rowState.state    = 'confirm_needed';
    else
        rowState.state    = 'auto';
    end
    rowState.localKey   = e.localKey;
    rowState.confidence = e.confidence;
    rowState.unitMismatch = e.unitMismatch;
end
% Note: MEDIUM-confidence AUTO entries are NOT blocked (isResolvable is true for MEDIUM).
% Only LOW+AUTO is blocked. CONFIRMED and OVERRIDDEN are never blocked.
```

### Pattern 6: CMP-05 Resolve-Once Cache (Invariant #5)

```matlab
% In CompareBuilderDialog.onOpenComparison_():
% Step 6 — resolve-once-at-open cache (UI-SPEC step 6)
obj.ResolvedTags_ = cell(1, nIncluded);
for k = 1:nIncluded
    machineIdx = includedMachineIndices(k);
    localKey   = obj.RowStates_{machineIdx}.localKey;
    machine    = fleet.getMachine(machineId);
    try
        obj.ResolvedTags_{k} = machine.get(localKey);
    catch ME
        error('CompareBuilderDialog:resolutionError', ...
            'Failed to resolve tag for machine "%s": %s', machine.Name, ME.message);
    end
end
% From this point: openAdHocPlot is called with obj.ResolvedTags_ as the tags cell.
% The live tick inside the spawned DashboardEngine NEVER calls CanonicalMapper.resolve.
% CanonicalMapper.resolve is absent from the steady-state tick profile. ✓
```

### Anti-Patterns to Avoid

- **Calling `CanonicalMapper.resolve` (or any mapper method) in the live tick.** All resolution happens once at Open. The tick path is `updateData()` only.
- **Using `uitable` for machine rows.** Per-row `uigridlayout` in scrollable `uipanel` is the established pattern (DashboardListPane). `uitable` checkbox columns require R2022a+ for explicit column types; uitable theming is severely limited in R2020b.
- **Setting `WindowStyle='modal'` on the dialog.** Must be non-modal (modeless). `WindowStyle` must NOT be set.
- **Rebuilding the entire row grid on every checkbox change.** `rebuildRows_()` is expensive. For checkbox/state changes, update widgets in-place via stored per-row handles. Full `rebuildRows_()` only on quick-fill sensor selection change.
- **Putting `CanonicalMapper.Entries_` inside the `isKey` check in a loop.** Use the new `resolve()` method — it encapsulates the bucket scan cleanly and is the "absent-from-tick" seam.
- **Shifting toolbar columns without updating `hActiveMachineLabel_.Layout.Column`.** The label is assigned column 10 in Phase 1044. Phase 1045 must shift it to 11 (and gear from 11 to 12).
- **Auto-calling `Fleet.save()` after Promote.** Deferred. In-memory only.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Confidence gate | Custom confidence logic | `CanonicalMapper.isResolvable()` + new `resolve()` | Existing logic handles LOW+AUTO + unit-mismatch + status interactions |
| Theme application | Manual per-widget color loops | `applyThemeToChildren_(hFig_, theme)` | Existing walker covers all widget types used in this phase |
| Figure tracking | Manual `OpenedFigures_` management | `App_.trackOpenedFigure_(hFig)` | Existing dedup + prune logic |
| Overlay rendering | Custom axes management | `openAdHocPlot(tags,'Overlay',...)` | Existing RawAxesWidget + DashboardEngine live cycle |
| Singleton dialog focus | Custom `figure()` / `drawnow` | `figure(obj.CompareBuilderDlg_.hFig_)` | Brings existing non-modal uifigure to front in R2020b |

---

## Common Pitfalls

### Pitfall 1: CanonicalMapper has no `resolve()` method

**What goes wrong:** The UI-SPEC and CONTEXT.md reference `CanonicalMapper.resolve(logicalId, machineId)` — this method does not exist as of Phase 1044. Code that calls it will throw `'No appropriate method, property, or field 'resolve' for class 'CanonicalMapper'.'`

**Why it happens:** The method was specified in the design but not implemented in earlier phases (CanonicalMapper only has `isResolvable`, not a full struct-returning `resolve`).

**How to avoid:** Plan 01 MUST add `resolve(obj, logicalId, machineId)` to `CanonicalMapper.m` returning the entry struct or `[]`. This is the first task before any dialog work.

**Warning signs:** Test or runtime errors mentioning `'resolve'` on `CanonicalMapper`.

### Pitfall 2: Toolbar column shift — hActiveMachineLabel_ Layout.Column must update

**What goes wrong:** Adding col 9 (Compare button) in fleet-mode toolbar shifts the active-machine label from col 10 → 11 and gear from col 11 → 12. If only the `ColumnWidth` cell is updated but `hActiveMachineLabel_.Layout.Column` stays at 10, the label overlaps the new Compare button.

**Why it happens:** MATLAB `uigridlayout` does not auto-shift child layout positions when `ColumnWidth` is resized by adding an element.

**How to avoid:** In the toolbar construction block (FastSenseCompanion.m:384-534), change the fleet-mode grid to `[1 12]`, shift `hActiveMachineLabel_.Layout.Column = 11`, and `gearColumn = 12`. The existing `gearColumn` variable already abstracts this — just change fleet-mode value from 11 to 12.

**Warning signs:** Active-machine label text appears in col 9 position (on top of Compare button), or gear appears at wrong position.

### Pitfall 3: `CanonicalMapper.override()` requires `LastTagInfos_` populated

**What goes wrong:** `CanonicalMapper.override()` (line 215) loops over `obj.LastTagInfos_` to populate `localName` and `localUnits` for the new entry. If `suggest()` was never called (empty fleet or freshly deserialized mapper where `LastTagInfos_` stays `{}`), the override entry gets empty `localName`/`localUnits`.

**Why it happens:** `override()` tries to look up metadata from the most recent `suggest()` call. On a mapper loaded from JSON, `LastTagInfos_` is `{}` (not serialized).

**How to avoid:** Before calling `mapper.override(...)` from the Promote action, populate the `localName` from `machine.get(localKey).Name` and `localUnits` from `machine.get(localKey).Units` and pass them through — OR accept that the OVERRIDDEN entry will have empty name/units (functionally fine, visually acceptable in the CanonicalMapEditor review table).

**Warning signs:** `CanonicalMapEditor` shows blank Name/Units for a promoted entry.

### Pitfall 4: `uiconfirm` CloseFcn async pattern on R2020b

**What goes wrong:** The Promote confirm dialog uses `uiconfirm`. On R2020b, `uiconfirm` is non-blocking — execution continues past it immediately. If the code after `uiconfirm(...)` directly calls `mapper.override()`, it fires before the user responds.

**Why it happens:** R2020b `uiconfirm` in uifigure context is async (callback-based), unlike R2022b+ where it can be `await`-ed via `uiconfirm` with `CloseFcn`.

**How to avoid:** Pass all promotion logic into the `CloseFcn` callback of `uiconfirm`. Pattern from UI-SPEC (confirmed R2020b-safe):
```matlab
uiconfirm(obj.hFig_, message, title, ...
    'Options', {'Promote', 'Cancel'}, ...
    'DefaultOption', 2, 'CancelOption', 2, ...
    'CloseFcn', @(~, event) obj.onPromoteConfirmed_(machineIdx, event));
```
Then `onPromoteConfirmed_` checks `event.SelectedOption` equals `'Promote'` before calling `mapper.override()`.

**Warning signs:** Promote fires immediately without waiting for user response.

### Pitfall 5: MACH-05 regression — legacy toolbar column count test

**What goes wrong:** `TestFastSenseCompanion.testLegacyConstruction_Unchanged` (line 1745) asserts `numel(tbGrid(1).ColumnWidth) == 10`. If the Phase 1045 toolbar change accidentally touches the legacy (no-Fleet) branch, this test fails.

**Why it happens:** The fleet/legacy branch is an `if ~isempty(obj.Fleet_)` conditional. Any edit to toolbar construction that touches both branches will break legacy.

**How to avoid:** The Compare button addition is FLEET-MODE ONLY. Legacy branch stays `[1 10]` exactly. The `MACH-05: legacy toolbar must keep 10 columns` assertion is the gate.

**Warning signs:** `testLegacyConstruction_Unchanged` fails with column count mismatch.

### Pitfall 6: `rebuildRows_` vs in-place widget update

**What goes wrong:** Calling `rebuildRows_()` (full row grid teardown + rebuild) on every checkbox toggle creates flicker and degrades performance at 8+ machines.

**Why it happens:** Full rebuild is the safe "start fresh" approach but unnecessary for state changes that only affect badge text and action button visibility.

**How to avoid:** Only call `rebuildRows_()` when the set of rows changes (sensor dropdown change, dialog open). For per-row checkbox/dropdown changes, update `RowStates_` and refresh the specific row's badge label text + action button enable/text in-place via stored handles (`RowHandles_{i}.hBadge_`, `RowHandles_{i}.hActionBtn_`). Update `hCountLabel_` and `hOpenBtn_.Enable` after any state change.

### Pitfall 7: Units availability for mismatch detection

**What goes wrong:** The unit-mismatch warning requires comparing the selected tag's `Units` against the canonical sensor's `Units`. `Tag.Units` is a property of `Tag` base class (confirmed: `libs/SensorThreshold/Tag.m:54`). However, for machine-scoped tags loaded from a `Machine`, `Units` may be empty string if the tag was constructed without explicit `'Units'` argument.

**Why it happens:** `Tag.Units = ''` is the default. Many test fixtures omit units.

**How to avoid:** Treat empty units as "unit unknown — no mismatch detectable." Only flag a mismatch when BOTH the canonical entry's `localUnits` (from CanonicalMapper entry struct) AND the resolved tag's `Units` are non-empty and differ (case-insensitive). Guard with `~isempty(canonicalUnits) && ~isempty(tag.Units)`.

---

## Critical API Reference (Verified by Direct Read)

### CanonicalMapper — Exact Method Signatures

```matlab
% All lines verified in libs/Fleet/CanonicalMapper.m

% isResolvable (line 292): boolean gate
ok = mapper.isResolvable(logicalId, machineId)
% Returns false for: AUTO + LOW confidence; OR unitMismatch + not CONFIRMED/OVERRIDDEN
% Returns true for: HIGH/MEDIUM AUTO; CONFIRMED; OVERRIDDEN

% override (line 215): force OVERRIDDEN HIGH entry
mapper.override(logicalId, machineId, localKey)
% Side effects: upserts entry; preserves across re-suggest()
% Caveat: populates localName/localUnits from LastTagInfos_ — may be empty

% confirm (line 250): endorse AUTO entry (status -> CONFIRMED, confidence kept)
mapper.confirm(logicalId, machineId)

% keys() — all logical IDs in Entries_:
logIds = keys(mapper.Entries_)   % containers.Map method

% Entry struct fields (line 37):
%   logicalId, machineId, localKey, localName, localUnits,
%   similarity, confidence ('HIGH'|'MEDIUM'|'LOW'), 
%   status ('AUTO'|'CONFIRMED'|'OVERRIDDEN'|'PENDING'),
%   unitMismatch (logical)

% MISSING — needs to be added in Plan 01:
% resolve(logicalId, machineId) -> entry struct or []
```

### Fleet — Exact Method Signatures

```matlab
% All lines verified in libs/Fleet/Fleet.m

% resolveLogical (line 158): Nx2 cell {Machine, Tag}
pairs = fleet.resolveLogical(logicalId)
% Iterates Mapper_.Entries_(logicalId) bucket
% Returns only pairs where (1) machine in fleet, (2) localKey in machine catalog
% NO confidence gate — returns all entries regardless of confidence/status
% NOTE: The confidence gate lives in CompareBuilderDialog, not here

% machineIds (line 114): insertion-order cell of char IDs
ids = fleet.machineIds()

% getMachine (line 95): Machine handle by ID
m = fleet.getMachine(id)   % throws Fleet:unknownMachineId on miss
```

### Machine — Exact Method Signatures

```matlab
% libs/Fleet/Machine.m

% get (line 157): Tag by local key
tag = machine.get(localKey)   % throws Machine:unknownKey on miss

% keys (line 208): all local keys in catalog
ks = machine.keys()   % returns cell of char

% Properties accessed in dialog:
%   machine.Name (char)
%   machine.Id (char)
%   machine.Dashboards (cell)
```

### Tag — Relevant Properties

```matlab
% libs/SensorThreshold/Tag.m:54 — confirmed property
tag.Units   % char, default ''
tag.Name    % char
tag.Key     % char (the local key)
```

### openAdHocPlot — Current Signature

```matlab
% libs/FastSenseCompanion/private/openAdHocPlot.m:1 [VERIFIED: direct read]
function [hFig, skippedNames] = openAdHocPlot(tags, mode, themePreset)
% plotOverlay_ at line 142: uses MATLAB ColorOrder auto-cycle; DisplayName = names{k}
% No color/label injection today
% 3 positional args only — no varargin
```

### CompanionTheme.LineColors

```matlab
% libs/FastSenseCompanion/CompanionTheme.m:60 [VERIFIED: direct read]
theme.LineColors = num2cell(theme.LineColorOrder, 2)';
% Returns cell of 1×3 row vectors; dark uses 'vibrant' 8-color palette
% Access: theme.LineColors{insertionIdx}  % 1-based; modulo 8 for >8 machines
% insertionIdx = find(strcmp(fleet.machineIds(), machineId), 1)
```

---

## Implementation Sequencing

Proposed wave/plan breakdown:

### Wave 1 — Pure Logic Foundation (Octave-safe + flat tests)

**Plan 01: `CanonicalMapper.resolve()` + resolution helper + flat tests**
- Add `resolve(obj, logicalId, machineId)` to `CanonicalMapper.m` — returns entry struct or `[]`
- Add `buildCompareResolution_.m` (private helper): given fleet + logicalId → returns cell of `{machineId, localKey, confidence, status, unitMismatch}` per machine, with `none` state for unresolvable machines
- Tests in `test_compare_resolution.m` (flat, Octave-safe):
  - T1: `resolve()` returns entry struct for known (logicalId, machineId)
  - T2: `resolve()` returns `[]` for unknown pair
  - T3: Resolution assembly: HIGH entry → `auto` state; LOW+AUTO → `confirm_needed`; missing → `none`
  - T4: Unit-mismatch detection: both units non-empty + differ → mismatch warning

**Plan 02: `openAdHocPlot` NV args + flat MATLAB test**
- Extend `openAdHocPlot` with `'SeriesColors'` / `'SeriesLabels'` NV args via `inputParser`
- `plotOverlay_` passes explicit `'Color'` per series when `SeriesColors` present
- Validation: `openAdHocPlot:seriesColorsMismatch` if `numel(SeriesColors) ~= numel(tags)`
- Extend `tests/test_companion_open_ad_hoc_plot.m` (or new file) with:
  - T-NV1: SeriesColors/SeriesLabels absent → existing behavior unchanged (legacy)
  - T-NV2: SeriesColors present → figure spawns; first axes line has expected Color
  - T-NV3: SeriesColors wrong count → `openAdHocPlot:seriesColorsMismatch`

### Wave 2 — CompareBuilderDialog Class

**Plan 03: CompareBuilderDialog construction + row grid + row states**
- New `libs/FastSenseCompanion/CompareBuilderDialog.m` (~200-250 lines)
- Constructor: uifigure 600×480, outer `[5 1]` grid (UI-SPEC contract)
- `buildRows_()` / `rebuildRows_()`: scrollable panel, per-machine 1×6 row grids
- Row state machine: `auto` / `confirm_needed` / `override` / `none`
- Quick-fill sensor dropdown → `resolveAllRows_()` + `rebuildRows_()`
- Per-row checkbox, dropdown, badge label, action button (in-place update)
- `onOpenComparison_()`: resolve-once cache + mismatch/skip alerts + call `openAdHocPlot`

**Plan 04: Promote action + uiconfirm + theme propagation**
- Promote via `uiconfirm` CloseFcn async pattern
- `mapper.override()` call; badge update to `promoted`
- Theme propagation: `applyThemeToChildren_` + post-walk overrides for badge FontColors + OpenBtn BackgroundColor
- `CompareBuilderDialog.close()` → `App_.CompareBuilderDlg_ = []` (friend-class write)

### Wave 3 — Toolbar + Companion Wiring

**Plan 05: Fleet toolbar extension + companion integration + class-suite tests**
- `FastSenseCompanion.m`: fleet-mode toolbar `[1 12]`, Compare button at col 9, col shifts
- `CompareBuilderDlg_` property (friend-class `SetAccess = ?CompareBuilderDialog`)
- `openCompareBuilder_()` method + `close()` teardown
- `TestFastSenseCompanion.m` CMP test block appended after MACH block:
  - `testCompareButtonFleetOnly`: fleet mode → Compare button at col 9 exists; legacy mode → no Compare button, toolbar still [1 10]
  - `testCompareBuilderSingleton`: two calls to `openCompareBuilder_()` → `CompareBuilderDlg_` is same instance; `figure()` called to front
  - `testCompareBuilderClosesWithCompanion`: `app.close()` → `CompareBuilderDlg_` deleted
  - `testOpenComparisonLaunchesOverlay`: build dialog with 2-machine fleet + mock tags → click Open → figure tracked in `OpenedFigures_`
  - `testCMP05_NoResolveInTick`: cache invariant — see CMP-05 test shape below

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | MATLAB test suite (class-based `matlab.unittest.TestCase`) + Octave flat function tests |
| Config file | `tests/run_all_tests.m` (discovers both) |
| Quick run command | `mcp__matlab__run_matlab_test_file` on individual test file |
| Full suite command | `mcp__matlab__run_matlab_file` on `tests/run_all_tests.m` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CMP-01 | Quick-fill resolves per machine; overlay opens | class-suite | `TestFastSenseCompanion.testOpenComparisonLaunchesOverlay` | ❌ Wave 1 |
| CMP-02 | Stable per-machine colors; machine-qualified labels | unit (flat) | `test_compare_resolution.m::T-color-index` | ❌ Wave 1 |
| CMP-03 | Missing sensor → `none` state; graceful skip | unit (flat) | `test_compare_resolution.m::T3` | ❌ Wave 1 |
| CMP-04 | LOW-confidence excluded by default; unit mismatch warned | unit (flat) | `test_compare_resolution.m::T-confidence-gate` | ❌ Wave 1 |
| CMP-05 | Resolve-once cache; mapper absent from tick | class-suite | `TestFastSenseCompanion.testCMP05_NoResolveInTick` | ❌ Wave 3 |
| CMP-06 | Per-row states + promote | class-suite | `TestFastSenseCompanion.testPromoteUpdatesMapper` | ❌ Wave 3 |
| openAdHocPlot NV args (CMP-02) | SeriesColors/Labels injected; legacy unchanged | unit (flat, MATLAB-only) | `test_companion_open_ad_hoc_plot_series_colors.m` | ❌ Wave 1 |
| Toolbar (CMP-01) | Fleet-only Compare button; legacy 10 cols | class-suite | `TestFastSenseCompanion.testCompareButtonFleetOnly` | ❌ Wave 3 |

### CMP-05 Cache Invariant Test Shape

CMP-05 ("resolve absent from tick profile") cannot use a literal MATLAB profiler in a test (profiler overhead + non-deterministic). The recommended test seam:

```matlab
% Approach: spy counter via CanonicalMapper subclass override (test-only)
% OR: count calls to mapper.resolve() by temporarily replacing the method
% with a counting wrapper using a property on a TestableCanonicalMapper subclass.

% Simplest approach for the class-suite test:
% 1. Build a 2-machine fleet with mock tags.
% 2. Open the dialog, select sensor, click Open Comparison → figure spawns.
% 3. Store `mapper.resolve` call count before the first live tick (by injecting
%    a spy into the dialog's RowStates_ — the cached state must not change across ticks).
% 4. Let the live engine tick once (drawnow after delay or mock tick).
% 5. Assert that RowStates_ is unchanged after tick (indirectly proves no re-resolve).

% Concrete assertable mechanism:
% After Open: `dialog.ResolvedTags_` must be non-empty (cache populated).
% After one tick: `dialog.ResolvedTags_` must be identical (cache not invalidated).
% Assert that `CanonicalMapper.Entries_` was NOT mutated between Open and tick
%   (it should be immutable in the tick path — the timer only calls updateData).

% This proves the invariant without needing a real profiler.
```

The planner should produce `testCMP05_NoResolveInTick` as a test that:
1. Opens the comparison (caches tags).
2. Simulates one live tick on the spawned DashboardEngine.
3. Asserts `dialog.ResolvedTags_` still equals the same tag handles (no new resolve called).

If `CompareBuilderDialog.ResolvedTags_` is declared `(Access = {?TestFastSenseCompanion, ?CompareBuilderDialog})` or a test-access getter exists, this is straightforward.

### Sampling Rate

- **Per task commit:** run the new flat test file(s) + `test_companion_open_ad_hoc_plot.m`
- **Per wave merge:** run `TestFastSenseCompanion.m` (fleet + CMP methods)
- **Phase gate:** full `run_all_tests.m` green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `tests/test_compare_resolution.m` — covers CMP-03, CMP-04 (resolution assembly, confidence gate, unit mismatch)
- [ ] `tests/test_companion_open_ad_hoc_plot_series_colors.m` (or extend existing) — covers CMP-02 NV args
- [ ] `libs/Fleet/CanonicalMapper.m` — add `resolve()` method (covers CMP-05 seam)
- [ ] `libs/FastSenseCompanion/CompareBuilderDialog.m` — new file

---

## Security Domain

This phase has no meaningful security surface.

- All data is local MATLAB in-memory; no network calls, no authentication, no credentials.
- The unit-mismatch warning prevents silent wrong-data comparisons (data integrity protection), but this is a data-quality concern, not a security concern.
- Input validation: `openAdHocPlot:seriesColorsMismatch` validates that `numel(SeriesColors) == numel(tags)`.
- Error IDs are namespaced per CLAUDE.md conventions (`CompareBuilderDialog:*`, `FastSenseCompanion:*`).

| ASVS Category | Applies | Notes |
|---------------|---------|-------|
| V5 Input Validation | Minimal | NV arg count validation in `openAdHocPlot`; constructor guard in `CompareBuilderDialog` |
| All others | No | No auth, no sessions, no crypto, no persistence via this phase |

---

## Environment Availability

This phase is purely MATLAB uifigure code. No external tools required beyond the existing development environment.

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| MATLAB R2020b+ | All uifigure code | ✓ | macOS ARM64 primary dev |
| `uiconfirm` | Promote dialog | ✓ R2020b | Non-blocking CloseFcn pattern (see Pitfall 4) |
| `uidropdown.Placeholder` | Quick-fill dropdown | R2021a+ | Wrapped in `try/catch` per codebase idiom |
| `uidropdown.Searchable` | Quick-fill dropdown | R2021a+ | Wrapped in `try/catch` per codebase idiom |
| `uicheckbox` in uifigure | Machine row include toggle | ✓ R2020b | Confirmed in CMP-UX-MATLAB-RESEARCH caveat #3 |
| MEX kernels | `openAdHocPlot` → `FastSense` | ✓ (compiled at install) | Flat tests use `MockPlottableTag` to avoid MEX; class-suite tests run MATLAB-only |

**No missing dependencies.**

---

## Open Questions (RESOLVED)

**Q1: Does `CanonicalMapper` have a `resolve()` method?**
Resolved: NO. Direct read of `CanonicalMapper.m` confirms: existing methods are `suggest`, `override`, `confirm`, `reviewPending`, `isResolvable`, `unmapped`, `toStruct`, `fromStruct`, `save`, `load`. There is no `resolve()`. Plan 01 must add it.

**Q2: What is the exact confidence gate logic for LOW exclusion?**
Resolved: `isResolvable()` (line 292) returns false for `(status == 'AUTO' && confidence == 'LOW')` OR `(unitMismatch && status not CONFIRMED/OVERRIDDEN)`. MEDIUM-confidence AUTO entries ARE resolvable. Only LOW+AUTO is the confidence gate. CONFIRMED and OVERRIDDEN entries are always resolvable regardless of confidence.

**Q3: Does `Tag.Units` exist on all Tag types?**
Resolved: YES. `Tag.Units = ''` is a base class property (Tag.m:54). All subclasses (`SensorTag`, `MonitorTag`, `DerivedTag`, etc.) inherit it. May be empty string if not set.

**Q4: How does `openAdHocPlot` assign colors today — and where exactly to inject SeriesColors?**
Resolved: `plotOverlay_` (line 142) uses `hold(ax, 'on')` then `plot(ax, tv, y, 'DisplayName', ...)` with no explicit `'Color'`. MATLAB `ColorOrder` auto-cycles. Injection point: pass explicit `'Color', seriesColors{k}` per `plot()` call when NV args are present. No need to manipulate `ax.ColorOrder`.

**Q5: Does `Fleet.resolveLogical` apply a confidence gate?**
Resolved: NO. `Fleet.resolveLogical` (line 158) iterates `Mapper_.Entries_(logicalId)` and returns all pairs where the machine is in the fleet and `localKey` is in the machine catalog. There is no confidence filter. The confidence gate lives entirely in `CompareBuilderDialog` — it calls `resolve()` / `isResolvable()` per row to determine the row state. This is correct: `resolveLogical` gives the full set; the dialog applies the gate.

**Q6: Where does the CMP-05 test seam live — how to assert `resolve` absent from tick?**
Resolved: Use `dialog.ResolvedTags_` cache state comparison before and after a simulated live tick. Cache populated at Open, not re-populated during ticks (timer only calls `updateData`). If `ResolvedTags_` is unchanged after tick, invariant #5 holds. A test-access property or `(Access = {?TestFastSenseCompanion, ?CompareBuilderDialog})` attribute enables this check.

**Q7: Should `CanonicalMapper.override()` be called from the dialog with localKey from the machine catalog, or from the entry bucket?**
Resolved: From the machine catalog. The Promote action fires on an `override`-state row where the user picked a `localKey` from the per-row dropdown (populated from `machine.keys()`). Call `mapper.override(logicalId, machine.Id, selectedLocalKey)`. The `override()` method looks up `localName`/`localUnits` from `LastTagInfos_` — if empty (freshly-deserialized mapper), the entry will have blank name/units, which is acceptable (functionally correct).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `uiconfirm` with `CloseFcn` is the correct R2020b-safe async pattern for the Promote confirmation | Pitfall 4 | If R2020b `uiconfirm` behaves differently, use `inputdlg` as fallback (blocking, simpler) |
| A2 | Adding `resolve()` to `CanonicalMapper` does not require changes to `TestCanonicalMapper.m` wave-0 gap (new method, not a change) | Validation Architecture | Wave 0 must add tests for the new `resolve()` method |

---

## Sources

### Primary (HIGH confidence — direct codebase reads)

- `libs/Fleet/CanonicalMapper.m` (full read, lines 1-479) — exact method signatures, entry struct fields, isResolvable logic, override behavior
- `libs/Fleet/Fleet.m` (lines 1-310) — resolveLogical signature, machineIds, getMachine, Mapper_ access
- `libs/FastSenseCompanion/private/openAdHocPlot.m` (full read, lines 1-234) — exact signature, plotOverlay_ color assignment, NV extension point
- `libs/FastSenseCompanion/CompanionSettingsDialog.m` (full read, lines 1-187) — singleton lifecycle pattern to copy exactly
- `libs/FastSenseCompanion/FastSenseCompanion.m` (lines 380-540, 830-854, 1216-1226, 2323-2342) — toolbar construction, close() teardown, openSettings_ singleton pattern, trackOpenedFigure_
- `libs/FastSenseCompanion/CompanionTheme.m` (full read) — LineColors derivation (`num2cell(LineColorOrder, 2)'`)
- `libs/SensorThreshold/Tag.m` (line 54) — Units property confirmed on base class
- `tests/suite/TestFastSenseCompanion.m` (lines 1646-1747) — existing MACH test block structure, fleet toolbar column assertions
- `tests/suite/MockPlottableTag.m` (full read) — mock fixture for openAdHocPlot tests
- `libs/FastSenseCompanion/runOpenAdHocPlotTests.m` (full read) — existing test coverage for openAdHocPlot

### Secondary (HIGH confidence — prior phase research docs)

- `.planning/phases/1045-cross-machine-comparison-view/1045-CONTEXT.md` — locked decisions
- `.planning/phases/1045-cross-machine-comparison-view/1045-UI-SPEC.md` — grid dims, copy, states (all pinned; not duplicated here)
- `.planning/research/CMP-UX-MATLAB-RESEARCH.md` — R2020b caveats, Pattern 5 feasibility
- `.planning/STATE.md` — critical invariants #4 and #5

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all from direct codebase reads
- Architecture: HIGH — patterns copied from existing working code (CompanionSettingsDialog, DashboardListPane)
- Pitfalls: HIGH — all grounded in specific codebase line references or documented R2020b behaviors
- API reference: HIGH — verified by direct file reads; noted where method is MISSING

**Research date:** 2026-06-10
**Valid until:** 2026-07-10 (30 days; stable MATLAB codebase, no external dependencies)
