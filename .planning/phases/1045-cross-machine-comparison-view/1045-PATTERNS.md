# Phase 1045: Cross-Machine Comparison View — Pattern Map

**Mapped:** 2026-06-10
**Files analyzed:** 7 (5 new, 2 modified)
**Analogs found:** 7 / 7

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `libs/FastSenseCompanion/CompareBuilderDialog.m` | dialog (second uifigure) | request-response | `libs/FastSenseCompanion/CompanionSettingsDialog.m` | exact (same lifecycle pattern) |
| `libs/Fleet/CanonicalMapper.m` (modify: add `resolve`) | model | CRUD | its own `isResolvable` + bucket-scan pattern (lines 292–310) | self-analog |
| `libs/FastSenseCompanion/private/openAdHocPlot.m` (modify: NV args) | utility | request-response | its own `inputParser` / existing 3-arg signature (lines 1–56) | self-analog |
| `libs/FastSenseCompanion/private/buildCompareResolution_.m` | utility (pure logic) | transform | `libs/FastSenseCompanion/private/filterMachines.m` | role-match (pure-logic helper shape) |
| `libs/FastSenseCompanion/FastSenseCompanion.m` (modify: toolbar + `CompareBuilderDlg_` + `openCompareBuilder_`) | orchestrator | request-response | its own 1044 fleet-toolbar block (lines 384–522) + `openSettings` singleton pattern (lines 1216–1227) | self-analog |
| `tests/test_compare_resolution.m` | test (flat Octave-safe) | — | `tests/test_machine_selector_pane.m` / `libs/FastSenseCompanion/runFilterMachinesTests.m` | role-match |
| `tests/suite/TestFastSenseCompanion.m` (extend: CMP block) | test (class-suite) | — | its own MACH block (lines 1646–1747) | exact (same fleet-fixture + `struct(app)` access pattern) |

---

## Pattern Assignments

---

### `libs/FastSenseCompanion/CompareBuilderDialog.m` (new, dialog, request-response)

**Primary analog:** `libs/FastSenseCompanion/CompanionSettingsDialog.m` (full file, 187 lines)

**Class header + property declaration pattern** (CompanionSettingsDialog.m lines 1–37):
```matlab
classdef CompanionSettingsDialog < handle
%COMPANIONSETTINGSDIALOG Non-modal settings popup for FastSenseCompanion.
%   ...
%   Note: this class deliberately writes `app.SettingsDlg_ = []` on
%   close. FastSenseCompanion declares that property with
%   `SetAccess = ?CompanionSettingsDialog` precisely to allow this.

    properties (SetAccess = private)
        App   = []   % FastSenseCompanion handle (parent)
        hFig_ = []   % owned uifigure handle (or [] after close)
    end

    properties (Access = private)
        hThemeDD_       = []
        % ... per-dialog widget handles ...
    end
```
Copy this structure for `CompareBuilderDialog`: `App_` instead of `App`, plus `hSensorDD_`, `hScrollPanel_`, `hOpenBtn_`, `hCloseBtn_`, `hCountLabel_`, `RowHandles_`, `RowStates_`, `ResolvedTags_`.

**Constructor pattern** (CompanionSettingsDialog.m lines 41–102):
```matlab
function obj = CompanionSettingsDialog(app)
    if ~isa(app, 'FastSenseCompanion')
        error('CompanionSettingsDialog:invalidApp', ...
            'CompanionSettingsDialog requires a FastSenseCompanion handle.');
    end
    obj.App = app;
    t = CompanionTheme.get(app.Theme);

    obj.hFig_ = uifigure( ...
        'Name',                'Companion Settings', ...
        'Position',            [200 200 360 200], ...
        'Resize',              'off', ...
        'AutoResizeChildren',  'off', ...
        'Color',               t.DashboardBackground);
    % Non-modal — explicitly do NOT set WindowStyle='modal'.

    g = uigridlayout(obj.hFig_, [3 2]);
    g.RowHeight     = {32, 32, 40};
    g.ColumnWidth   = {120, '1x'};
    g.Padding       = [16 16 16 16];
    g.RowSpacing    = 12;
    g.ColumnSpacing = 12;
    g.BackgroundColor = t.DashboardBackground;

    % ... widget construction ...

    applyThemeToChildren_(obj.hFig_, t);
    obj.hFig_.CloseRequestFcn = @(~,~) obj.close();
end
```
For `CompareBuilderDialog`: change `Position` to `[100 100 600 480]`, `Resize = 'on'`, grid to `[5 1]`, `RowHeight = {32, 8, '1x', 8, 40}`.

**`close()` method with friend-class write-back** (CompanionSettingsDialog.m lines 104–123):
```matlab
function close(obj)
    if isempty(obj.hFig_) || ~isvalid(obj.hFig_)
        obj.hFig_ = [];
        return;
    end
    try
        if ~isempty(obj.App) && isvalid(obj.App)
            obj.App.SettingsDlg_ = [];   % friend-class write
        end
    catch
    end
    try
        delete(obj.hFig_);
    catch
    end
    obj.hFig_ = [];
end

function delete(obj)
    obj.close();
end
```
For `CompareBuilderDialog`: replace `obj.App.SettingsDlg_ = []` with `obj.App_.CompareBuilderDlg_ = []`.

**Callback try/catch + uialert error handling pattern** (CompanionSettingsDialog.m lines 134–148):
```matlab
function onThemeChanged_(obj, ~, evt)
    try
        obj.App.applyTheme(evt.Value);
        % ...
    catch err
        if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
            uialert(obj.hFig_, err.message, 'Companion Settings');
        end
    end
end
```
Every private callback in `CompareBuilderDialog` must follow this exact try/catch + non-blocking `uialert` shape. The alert title should be `'Compare Builder'` for generic errors.

**`applyThemeToChildren_` call** (CompanionSettingsDialog.m line 99):
```matlab
applyThemeToChildren_(obj.hFig_, t);
```
Call after constructing all widgets. Post-walk overrides needed for `CompareBuilderDialog`: `hOpenBtn_.BackgroundColor` (recompute from `includedCount`) and per-row badge `FontColor` (recompute per state).

---

### `libs/Fleet/CanonicalMapper.m` (modify: add `resolve` method)

**Self-analog — bucket scan pattern** (CanonicalMapper.m lines 292–310):
```matlab
function ok = isResolvable(obj, logicalId, machineId)
    ok = false;
    if ~isKey(obj.Entries_, logicalId)
        return;
    end
    bucket = obj.Entries_(logicalId);
    for i = 1:numel(bucket)
        e = bucket{i};
        if strcmp(e.machineId, machineId)
            isBlocked = (strcmp(e.status, 'AUTO') && strcmp(e.confidence, 'LOW')) ...
                || (e.unitMismatch && ~strcmp(e.status, 'CONFIRMED') ...
                    && ~strcmp(e.status, 'OVERRIDDEN'));
            ok = ~isBlocked;
            return;
        end
    end
end
```
New `resolve(obj, logicalId, machineId)` copies the `isKey` / bucket loop skeleton exactly, but returns the matched `e` struct instead of a boolean. Return `[]` if `~isKey` or no matching `machineId` found. No side effects. Place immediately before `isResolvable` in the file.

**`override` method as placement reference** (CanonicalMapper.m lines 215–248): new `resolve` method goes between `confirm` (line 250) and `isResolvable` (line 292), or just before `isResolvable`.

---

### `libs/FastSenseCompanion/private/openAdHocPlot.m` (modify: add NV args)

**Self-analog — current signature and validation block** (openAdHocPlot.m lines 1–56):
```matlab
function [hFig, skippedNames] = openAdHocPlot(tags, mode, themePreset)
    validModes = {'Overlay', 'LinkedGrid'};
    if ~ischar(mode) || ~any(strcmp(mode, validModes))
        error('FastSenseCompanion:invalidPlotMode', ...
            'openAdHocPlot: mode must be one of: %s. Got: ''%s''.', ...
            strjoin(validModes, ', '), char(mode));
    end
    if ~iscell(tags) || numel(tags) < 1
        error('FastSenseCompanion:invalidPlotMode', ...
            'openAdHocPlot: requires a cell of >= 1 tag. Got %d.', numel(tags));
    end
```
Change signature to `function [hFig, skippedNames] = openAdHocPlot(tags, mode, themePreset, varargin)`. Add `inputParser` block after existing positional validation:
```matlab
p = inputParser();
p.addParameter('SeriesColors', {});
p.addParameter('SeriesLabels', {});
p.parse(varargin{:});
seriesColors = p.Results.SeriesColors;
seriesLabels = p.Results.SeriesLabels;
if ~isempty(seriesColors) && numel(seriesColors) ~= numel(tags)
    error('openAdHocPlot:seriesColorsMismatch', ...
        'SeriesColors must have the same number of elements as tags (%d). Got %d.', ...
        numel(tags), numel(seriesColors));
end
```

**`plotOverlay_` — current color/label assignment** (openAdHocPlot.m lines 142–157):
```matlab
function plotOverlay_(ax, tags, names)
    hold(ax, 'on');
    for k = 1:numel(tags)
        try
            [tv, y] = tags{k}.getXY();
            if isempty(tv); continue; end
            plot(ax, tv, y, 'DisplayName', char(names{k}), 'LineWidth', 1.2);
        catch
        end
    end
    hold(ax, 'off');
    try; legend(ax, 'show', 'Location', 'best'); catch; end
    grid(ax, 'on');
    xlabel(ax, 'Time');
end
```
The extended version passes `seriesColors` and `seriesLabels` into `plotOverlay_` and conditionally adds `'Color', seriesColors{k}` to the `plot()` call per series. Use explicit per-series `'Color'` rather than manipulating `ax.ColorOrder` — immune to `ColorOrderIndex` state. The `Overlay` engine `addWidget` call passes the extended `PlotFcn` closure:
```matlab
engine.addWidget('rawaxes', ...
    'Title',    figName, ...
    'PlotFcn',  @(ax) plotOverlay_(ax, validTags, validNames, seriesColors, seriesLabels), ...
    'Position', [1 1 24 12]);
```

---

### `libs/FastSenseCompanion/private/buildCompareResolution_.m` (new, pure-logic utility)

**Primary analog:** `libs/FastSenseCompanion/private/filterMachines.m` (full file, 38 lines)

**Pure-logic helper shape** (filterMachines.m lines 1–38):
```matlab
function matches = filterMachines(machinesCell, searchTerm)
%FILTERMACHINES Pure Octave-safe substring filter over Machine Name + Id.
%   matches = filterMachines(machinesCell, searchTerm)
%
%   Inputs:
%     machinesCell - 1xN cell of Machine handles (full fleet, insertion order)
%     searchTerm   - char; empty string means no filter (returns all)
%
%   Output:
%     matches - cell of Machine handles in insertion order ...
%
%   Octave-safe: uses strfind(lower(...)), never the MATLAB-only 'contains'.

    if isempty(machinesCell)
        matches = {};
        return;
    end
    % ... pure for-loop body ...
end
```
`buildCompareResolution_` follows exactly this shape: function file in `private/`, no handle-class, Octave-safe pure logic (no `isa`, no `contains`, no `validateattributes`). Signature: `rowStructs = buildCompareResolution_(fleet, mapper, logicalId)` — iterates `fleet.machineIds()`, calls `mapper.resolve(logicalId, machineId)` per machine, applies the confidence gate, returns 1×N struct array (fields: `machineId`, `localKey`, `confidence`, `status`, `unitMismatch`, `state` ['auto'|'confirm_needed'|'none']).

---

### `libs/FastSenseCompanion/FastSenseCompanion.m` (modify: toolbar + property + method)

**Modification 1 — fleet-mode toolbar column expansion**
**Self-analog:** lines 384–522 (Phase 1044 fleet toolbar block)

Phase 1044 fleet-mode toolbar as it stands (lines 384–390):
```matlab
if ~isempty(obj.Fleet_)
    hToolbarGrid = uigridlayout(obj.hToolbarPanel_, [1 11]);
    hToolbarGrid.ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, '1x', 'fit', 36};
else
    hToolbarGrid = uigridlayout(obj.hToolbarPanel_, [1 10]);
    hToolbarGrid.ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, '1x', 36};
end
```
Phase 1045 change (fleet branch only — legacy `[1 10]` stays byte-identical):
```matlab
if ~isempty(obj.Fleet_)
    hToolbarGrid = uigridlayout(obj.hToolbarPanel_, [1 12]);
    hToolbarGrid.ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, 80, '1x', 'fit', 36};
    %  col 9  = 80 px — Compare button (NEW)
    %  col 10 = '1x'  — spacer (shifted)
    %  col 11 = 'fit' — active-machine label (shifted)
    %  col 12 = 36 px — Gear (shifted)
```
After the Compare button is created at col 9, the active-machine label construction block (currently lines 507–519) must change `Layout.Column = 10` → `11`, and `gearColumn = 11` → `12`.

Compare button construction (mirrors `hBellBtn_` at lines 490–501 and `hSettingsBtn_` at lines 526–529):
```matlab
obj.hCompareBtn_ = uibutton(hToolbarGrid, 'push');
obj.hCompareBtn_.Layout.Row    = 1;
obj.hCompareBtn_.Layout.Column = 9;
obj.hCompareBtn_.Text          = 'Compare';
obj.hCompareBtn_.FontSize      = 11;
obj.hCompareBtn_.Tag           = 'CompanionCompareBtn';
obj.hCompareBtn_.Tooltip       = 'Open cross-machine comparison builder';
obj.hCompareBtn_.ButtonPushedFcn = @(~,~) obj.openCompareBuilder_();
```

**Modification 2 — `CompareBuilderDlg_` property declaration**
**Self-analog:** lines 64–66 (`SettingsDlg_` friend-class property):
```matlab
properties (GetAccess = public, SetAccess = ?CompanionSettingsDialog)
    SettingsDlg_ = []     % CompanionSettingsDialog handle (or empty)
end
```
Add immediately after (or in same block):
```matlab
properties (GetAccess = public, SetAccess = ?CompareBuilderDialog)
    CompareBuilderDlg_ = []   % CompareBuilderDialog singleton handle (or [] when closed)
end
```
Also add `hCompareBtn_ = []` to the `properties (Access = private)` block alongside `hSettingsBtn_`.

**Modification 3 — `openCompareBuilder_` method and `close()` teardown**
**Self-analog:** `openSettings` (lines 1216–1227) and close/teardown (lines 835–843):

`openSettings` singleton pattern to copy exactly:
```matlab
function openSettings(obj)
    if ~isempty(obj.SettingsDlg_) && isvalid(obj.SettingsDlg_) && ...
            ~isempty(obj.SettingsDlg_.hFig_) && ...
            isvalid(obj.SettingsDlg_.hFig_)
        figure(obj.SettingsDlg_.hFig_);
        return;
    end
    obj.SettingsDlg_ = CompanionSettingsDialog(obj);
end
```
`openCompareBuilder_` copies this verbatim substituting `CompareBuilderDlg_` and `CompareBuilderDialog`.

Settings teardown in `close()` (lines 835–843):
```matlab
try
    if ~isempty(obj.SettingsDlg_) && isvalid(obj.SettingsDlg_)
        delete(obj.SettingsDlg_);
    end
catch err
    fprintf(2, '[FastSenseCompanion] SettingsDlg cleanup failed: %s\n', err.message);
end
obj.SettingsDlg_ = [];
```
Copy block immediately after this with `CompareBuilderDlg_` substituted.

---

### `tests/test_compare_resolution.m` (new, flat Octave-safe)

**Primary analog:** `libs/FastSenseCompanion/runFilterMachinesTests.m` and `tests/test_machine_selector_pane.m`

**Flat test function shape** (filterMachines.m serves as structural mirror):
```matlab
function test_compare_resolution()
%TEST_COMPARE_RESOLUTION Flat Octave-safe tests for CanonicalMapper.resolve + buildCompareResolution_.
    install();
    nPassed = 0;
    nFailed = 0;

    % ---- T1: resolve returns entry struct for known pair ----
    try
        mapper = CanonicalMapper();
        % ... setup suggest ...
        e = mapper.resolve('temp', 'M01');
        assert(isstruct(e) && strcmp(e.machineId, 'M01'));
        nPassed = nPassed + 1;
    catch ME
        fprintf('FAIL T1: %s\n', ME.message);
        nFailed = nFailed + 1;
    end

    % ---- T2: resolve returns [] for unknown pair ----
    % ---- T3: buildCompareResolution_ states (auto / confirm_needed / none) ----
    % ---- T4: unit-mismatch detection ----

    fprintf('    %d of %d tests passed.\n', nPassed, nPassed + nFailed);
    if nFailed > 0
        error('test_compare_resolution:failures', '%d test(s) failed.', nFailed);
    end
end
```
Key points: `install()` at top, `try/catch` per test block, `fprintf` progress, `error` on any failure (so CI catches it). Octave-safe: no `matlab.unittest`, no `contains`, no `isa(x, 'matlab.unittest.*')`.

---

### `tests/suite/TestFastSenseCompanion.m` (extend: CMP block)

**Primary analog:** MACH block (TestFastSenseCompanion.m lines 1646–1747)

**Fleet fixture + `struct(app)` access pattern** (lines 1652–1660):
```matlab
fleet = Fleet();
m1 = fleet.addMachine('Id', 'M01', 'Name', 'Press Line 3');
m2 = fleet.addMachine('Id', 'M02', 'Name', 'Pump Station 1');
m1.addTag(SensorTag('temp_a', 'Name', 'Temp A', 'X', 0:9, 'Y', 0:9));
app = FastSenseCompanion('Fleet', fleet);
testCase.addTeardown(@() closeIfOpen_(app));
s = struct(app);
```
Every CMP test method follows this exact fixture: `Fleet()` + `addMachine` + `addTag(SensorTag(...))` + `FastSenseCompanion('Fleet', fleet)` + `addTeardown(@() closeIfOpen_(app))` + `s = struct(app)`.

**Column-count assertion pattern** (lines 1743–1746):
```matlab
tbGrid = s.hToolbarPanel_.Children;
tbGrid = tbGrid(arrayfun(@(h) isa(h, 'matlab.ui.container.GridLayout'), tbGrid));
testCase.verifyEqual(numel(tbGrid(1).ColumnWidth), 10, ...
    'MACH-05: legacy toolbar inner grid must keep 10 columns');
```
CMP toolbar test `testCompareButtonFleetOnly` will assert `numel(tbGrid(1).ColumnWidth) == 12` for fleet mode and verify `tbGrid(1).ColumnWidth{9}` equals `80` (Compare button column). Legacy assertion `== 10` stays in `testLegacyConstruction_Unchanged` (must NOT be modified).

**`closeIfOpen_` teardown helper** (defined at file bottom — copy pattern verbatim, do not inline):
```matlab
function closeIfOpen_(app)
    if ~isempty(app) && isvalid(app) && app.IsOpen
        app.close();
    end
end
```

---

## Shared Patterns

### Friend-Class Property + Singleton Dialog Lifecycle
**Source:** `libs/FastSenseCompanion/FastSenseCompanion.m` lines 64–66 + `libs/FastSenseCompanion/CompanionSettingsDialog.m` lines 104–123
**Apply to:** `CompareBuilderDialog.close()` + `FastSenseCompanion` property block + `openCompareBuilder_` method + `close()` teardown

The complete cycle:
1. FastSenseCompanion declares `properties (GetAccess=public, SetAccess=?CompareBuilderDialog) CompareBuilderDlg_ = []`
2. `openCompareBuilder_()`: `isvalid` + `isvalid(hFig_)` → `figure(hFig_)` OR `CompareBuilderDialog(obj)`
3. `CompareBuilderDialog.close()`: writes `obj.App_.CompareBuilderDlg_ = []` then `delete(obj.hFig_)`
4. `FastSenseCompanion.close()`: `try delete(CompareBuilderDlg_) catch ... end; CompareBuilderDlg_ = []`

### Callback Error Handling
**Source:** `libs/FastSenseCompanion/CompanionSettingsDialog.m` lines 134–148
**Apply to:** All `on*_` private methods in `CompareBuilderDialog`

Pattern: every callback wrapped in `try/catch err`, error surfaced via `uialert(obj.hFig_, err.message, 'Compare Builder')` — never rethrown. Guard `isvalid(obj.hFig_)` before `uialert`.

### uiconfirm Async Pattern (R2020b-safe)
**Source:** RESEARCH.md Pitfall 4
**Apply to:** `CompareBuilderDialog.onPromote_` (per-row Promote action)

```matlab
uiconfirm(obj.hFig_, message, 'Promote Override to Canonical Map', ...
    'Options', {'Promote', 'Cancel'}, ...
    'DefaultOption', 2, 'CancelOption', 2, ...
    'CloseFcn', @(~, event) obj.onPromoteConfirmed_(machineIdx, event));
```
All `mapper.override(...)` logic lives inside `onPromoteConfirmed_`, which checks `event.SelectedOption` first.

### R2021a+ Guard Pattern
**Source:** Codebase convention (CompanionSettingsDialog, MachineSelectorPane)
**Apply to:** `hSensorDD_` construction in `CompareBuilderDialog`

```matlab
try
    obj.hSensorDD_.Searchable = true;
catch
end
try
    obj.hSensorDD_.Placeholder = 'Select a sensor...';
catch
end
```

### Flat-Test Structure
**Source:** `libs/FastSenseCompanion/private/filterMachines.m` + `runFilterMachinesTests.m` shape
**Apply to:** `tests/test_compare_resolution.m`

install() → per-test try/catch → nPassed/nFailed counters → final fprintf + error on failure.

---

## No Analog Found

No files are completely without analog. All 7 files have strong analogs in the codebase.

---

## Metadata

**Analog search scope:** `libs/FastSenseCompanion/`, `libs/Fleet/`, `tests/`, `tests/suite/`
**Files read:** 8 source files (CompanionSettingsDialog.m, openAdHocPlot.m, CanonicalMapper.m lines 1–320, filterMachines.m, FastSenseCompanion.m lines 55–90 + 375–535 + 820–855 + 1205–1230, TestFastSenseCompanion.m lines 1640–1748)
**Pattern extraction date:** 2026-06-10
