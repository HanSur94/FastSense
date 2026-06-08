# Phase 1044: Companion Machine Dimension — Pattern Map

**Mapped:** 2026-06-08
**Files analyzed:** 7 new/modified files
**Analogs found:** 7 / 7

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `libs/FastSenseCompanion/MachineSelectorPane.m` | component | request-response | `libs/FastSenseCompanion/TagCatalogPane.m` | exact (verbatim structural copy) |
| `libs/FastSenseCompanion/private/filterMachines.m` | utility | transform | `libs/FastSenseCompanion/private/filterTags.m` | exact |
| `libs/Fleet/Fleet.m` (add `machineIds()`) | service | request-response | `libs/Fleet/Fleet.m:108-112` (`machineCount`) | exact (same pattern, one-liner accessor) |
| `libs/FastSenseCompanion/FastSenseCompanion.m` (extend) | component | request-response | `libs/FastSenseCompanion/FastSenseCompanion.m:300-459,725-800,867-906` | self-analog |
| `libs/FastSenseCompanion/TagCatalogPane.m` (redirect lines 60, 205) | component | request-response | `libs/FastSenseCompanion/TagCatalogPane.m` | self-analog |
| `tests/test_machine_selector_pane.m` | test | transform | `libs/FastSenseCompanion/private/filterTags.m` + existing `tests/test_*.m` flat pattern | role-match |
| `tests/suite/TestFastSenseCompanion.m` (extend) | test | request-response | `tests/suite/TestFastSenseCompanion.m:1-30,132-155` | self-analog (extend) |

---

## Pattern Assignments

### `libs/FastSenseCompanion/MachineSelectorPane.m` (component, request-response)

**Analog:** `libs/FastSenseCompanion/TagCatalogPane.m`

**Class declaration + properties pattern** (TagCatalogPane.m:1-41):
```matlab
classdef MachineSelectorPane < handle
%MACHINESELECTORPANE Searchable machine selector for FastSenseCompanion.
    events
        MachineSelectionChanged
    end

    properties (Access = private)
        hPanel_        = []   % uipanel (set by attach)
        hFig_          = []   % uifigure handle (for uialert)
        hSearchField_  = []   % uieditfield (search)
        hSearchClear_  = []   % uibutton (× clear)
        hListbox_      = []   % uilistbox
        hCountLabel_   = []   % uilabel (count badge)
        Listeners_     = {}   % addlistener returns; deleted on detach
        AllMachines_   = {}   % snapshot cell of Machine handles (full fleet)
        SearchTerm_    = ''   % current search string
        DebounceTimer_ = []   % timer or []; nil until first keystroke
        Theme_         = []   % resolved CompanionTheme struct
        Fleet_         = []   % Fleet handle
    end
```

**attach() root grid layout pattern** (TagCatalogPane.m:69-84 — copy for MachineSelectorPane; row count is 5 not 9, no pill rows):
```matlab
% [5 1] grid: row 1=search strip, row 2=8px spacer, row 3=listbox, row 4=4px spacer, row 5=count badge
hGrid = uigridlayout(obj.hPanel_, [5 1]);
hGrid.RowHeight     = {28, 8, '1x', 4, 24};
hGrid.ColumnWidth   = {'1x'};
hGrid.Padding       = [16 16 16 16];
hGrid.RowSpacing    = 0;
hGrid.BackgroundColor = obj.Theme_.WidgetBackground;
```

**Search strip sub-grid pattern** (TagCatalogPane.m:77-108):
```matlab
hSearchGrid = uigridlayout(hGrid, [1 2]);
hSearchGrid.Layout.Row    = 1;
hSearchGrid.Layout.Column = 1;
hSearchGrid.ColumnWidth   = {'1x', 24};
hSearchGrid.RowHeight     = {'1x'};
hSearchGrid.Padding       = [0 0 0 0];
hSearchGrid.ColumnSpacing = 4;
hSearchGrid.BackgroundColor = obj.Theme_.WidgetBackground;

obj.hSearchField_ = uieditfield(hSearchGrid, 'text');
obj.hSearchField_.Layout.Row      = 1;
obj.hSearchField_.Layout.Column   = 1;
try, obj.hSearchField_.Placeholder = ['Search machines', char(8230)]; catch, end
obj.hSearchField_.FontSize        = 11;
obj.hSearchField_.FontColor       = obj.Theme_.ForegroundColor;
obj.hSearchField_.BackgroundColor = obj.Theme_.WidgetBackground;
obj.hSearchField_.ValueChangedFcn = @(~,~) obj.onSearchChanged_();

obj.hSearchClear_ = uibutton(hSearchGrid, 'push');
obj.hSearchClear_.Layout.Row      = 1;
obj.hSearchClear_.Layout.Column   = 2;
obj.hSearchClear_.Text            = char(215);
obj.hSearchClear_.Tooltip         = 'Clear search';
obj.hSearchClear_.FontSize        = 11;
obj.hSearchClear_.FontColor       = obj.Theme_.ToolbarFontColor;
obj.hSearchClear_.BackgroundColor = obj.Theme_.WidgetBackground;
obj.hSearchClear_.ButtonPushedFcn = @(~,~) obj.onClearSearch_();
```

**Listbox pattern** (TagCatalogPane.m:158-166 — Multiselect 'off' for single-machine selection):
```matlab
obj.hListbox_ = uilistbox(hGrid);
obj.hListbox_.Layout.Row      = 3;
obj.hListbox_.Layout.Column   = 1;
obj.hListbox_.Multiselect     = 'off';    % single-select: one active machine
obj.hListbox_.FontSize        = 11;
obj.hListbox_.FontColor       = obj.Theme_.ForegroundColor;
obj.hListbox_.BackgroundColor = obj.Theme_.WidgetBackground;
obj.hListbox_.ValueChangedFcn = @(src,~) obj.onMachineSelected_(src.Value);
```

**Count badge pattern** (TagCatalogPane.m:169-176):
```matlab
obj.hCountLabel_ = uilabel(hGrid);
obj.hCountLabel_.Layout.Row          = 5;
obj.hCountLabel_.Layout.Column       = 1;
obj.hCountLabel_.FontSize            = 11;
obj.hCountLabel_.FontColor           = obj.Theme_.PlaceholderTextColor;
obj.hCountLabel_.HorizontalAlignment = 'left';
obj.hCountLabel_.VerticalAlignment   = 'center';
obj.hCountLabel_.BackgroundColor     = obj.Theme_.WidgetBackground;
```

**detach() pattern** (TagCatalogPane.m:182-199 — copy verbatim):
```matlab
function detach(obj)
%DETACH Release listeners and debounce timer. Does not delete the panel.
    if ~isempty(obj.DebounceTimer_) && isvalid(obj.DebounceTimer_)
        stop(obj.DebounceTimer_);
        delete(obj.DebounceTimer_);
    end
    obj.DebounceTimer_ = [];
    for ii = 1:numel(obj.Listeners_)
        lh = obj.Listeners_{ii};
        if isobject(lh) && isvalid(lh)
            delete(lh);
        end
    end
    obj.Listeners_ = {};
end
```

**Debounced onSearchChanged_ pattern** (TagCatalogPane.m:342-362 — copy verbatim):
```matlab
function onSearchChanged_(obj)
%ONSEARCHCHANGED_ Handle search field value change — debounced.
    try
        obj.SearchTerm_ = obj.hSearchField_.Value;
        if isempty(obj.DebounceTimer_)
            obj.DebounceTimer_ = timer();
            obj.DebounceTimer_.ExecutionMode = 'singleShot';
            obj.DebounceTimer_.Period        = 0.150;
            obj.DebounceTimer_.BusyMode      = 'drop';
            obj.DebounceTimer_.TimerFcn      = @(~,~) obj.applyFilter_();
        end
        if strcmp(obj.DebounceTimer_.Running, 'on')
            stop(obj.DebounceTimer_);
        end
        start(obj.DebounceTimer_);
    catch err
        uialert(obj.hFig_, err.message, 'FastSense Companion');
    end
end
```

**onClearSearch_ pattern** (TagCatalogPane.m:377-386):
```matlab
function onClearSearch_(obj)
    try
        obj.hSearchField_.Value = '';
        obj.SearchTerm_ = '';
        obj.applyFilter_();
    catch err
        uialert(obj.hFig_, err.message, 'FastSense Companion');
    end
end
```

**applyFilter_ pattern for machines** (adapt from TagCatalogPane.m:300-340 — simpler: no group headers, Items = label strings, ItemsData = machine Ids):
```matlab
function applyFilter_(obj)
    try
        filtered = filterMachines(obj.AllMachines_, obj.SearchTerm_);
        items     = {};
        itemsData = {};
        for i = 1:numel(filtered)
            m = filtered{i};
            if ~isempty(m.Group)
                items{end+1} = [m.Name ' (' m.Group ')'];
            else
                items{end+1} = m.Name;
            end
            itemsData{end+1} = m.Id;
        end
        obj.hListbox_.Items     = items;
        obj.hListbox_.ItemsData = itemsData;
        n = numel(filtered);
        if n == 0
            obj.hCountLabel_.Text = 'No machines match';
        else
            obj.hCountLabel_.Text = sprintf('%d machines', n);
        end
    catch err
        uialert(obj.hFig_, err.message, 'FastSense Companion');
    end
end
```

**setTheme pattern** (TagCatalogPane.m:240-269 — walk + post-walk overrides):
```matlab
function setTheme(obj, t)
    if ~isstruct(t); return; end
    try
        obj.Theme_ = t;
        if ~isempty(obj.hPanel_) && isvalid(obj.hPanel_)
            applyThemeToChildren_(obj.hPanel_, t);
        end
        % Post-walk pane-specific overrides
        if ~isempty(obj.hSearchClear_) && isvalid(obj.hSearchClear_)
            obj.hSearchClear_.FontColor = t.ToolbarFontColor;
        end
        if ~isempty(obj.hCountLabel_) && isvalid(obj.hCountLabel_)
            obj.hCountLabel_.FontColor = t.PlaceholderTextColor;
        end
    catch err
        warning('FastSenseCompanion:setThemeFailed', ...
            'MachineSelectorPane.setTheme failed: %s', err.message);
    end
end
```

**Public test-seam selectById** (modeled on TagCatalogPane.getSelectedKeys — TagCatalogPane.m:213-218):
```matlab
function selectById(obj, id)
%SELECTBYID Programmatically select a machine by Id — public test seam.
    obj.hListbox_.Value = id;
    obj.onMachineSelected_(id);
end
```

---

### `libs/FastSenseCompanion/private/filterMachines.m` (utility, transform)

**Analog:** `libs/FastSenseCompanion/private/filterTags.m`

**Full function pattern** (filterTags.m:1-39 — strip kind/crit passes; search over Name + Id only):
```matlab
function matches = filterMachines(machinesCell, searchTerm)
%FILTERMACHINES Pure filter helper for MachineSelectorPane.
%   matches = filterMachines(machinesCell, searchTerm)
%
%   Inputs:
%     machinesCell - 1xN cell of Machine handles
%     searchTerm   - char; empty string means no search filter
%
%   Output:
%     matches - cell of Machine handles in insertion order that match term
%
%   Octave-safe: uses strfind(lower(...)), never 'contains'.
%   See also MachineSelectorPane, Fleet.

    if isempty(machinesCell)
        matches = {};
        return;
    end

    if isempty(searchTerm)
        matches = machinesCell;
        return;
    end

    needle = lower(searchTerm);
    keep = false(1, numel(machinesCell));
    for i = 1:numel(machinesCell)
        m = machinesCell{i};
        if ~isempty(strfind(lower(m.Name), needle)) || ...
           ~isempty(strfind(lower(m.Id),   needle))
            keep(i) = true;
        end
    end
    matches = machinesCell(keep);
end
```

---

### `libs/Fleet/Fleet.m` — add `machineIds()` (service, request-response)

**Analog:** `libs/Fleet/Fleet.m:108-112` (`machineCount` public accessor pattern)

**One-method addition pattern** (Fleet.m:108-112):
```matlab
% Existing machineCount() as the structural template:
function n = machineCount(obj)
    %MACHINECOUNT Return the number of machines in this fleet.
    n = numel(obj.MachineIds_);
end

% New accessor — same pattern, returns the private field directly:
function ids = machineIds(obj)
    %MACHINEIDS Return insertion-ordered cell array of machine Ids.
    %   ids = fleet.machineIds()
    ids = obj.MachineIds_;
end
```

Add immediately after `machineCount` in the `methods (Access = public)` block at Fleet.m:108.

---

### `libs/FastSenseCompanion/FastSenseCompanion.m` — constructor extension (component, request-response)

**Self-analog:** existing constructor at FastSenseCompanion.m:300-459

**Root grid conditional branch pattern** (FastSenseCompanion.m:301-307 — extend Step 8):
```matlab
% Step 8 — Root grid: conditional on Fleet presence
if ~isempty(obj.Fleet_)
    % FLEET MODE: [3 4] grid, 170 px left-rail column
    obj.hLayout_ = uigridlayout(obj.hFig_, [3 4]);
    obj.hLayout_.ColumnWidth   = {170, 220, '1x', 360};
else
    % LEGACY (no Fleet): byte-identical to today
    obj.hLayout_ = uigridlayout(obj.hFig_, [3 3]);
    obj.hLayout_.ColumnWidth   = {220, '1x', 360};
end
obj.hLayout_.RowHeight     = {32, '1x', 360};
obj.hLayout_.Padding       = [24 24 24 24];
obj.hLayout_.ColumnSpacing = 16;
obj.hLayout_.RowSpacing    = 12;
obj.hLayout_.BackgroundColor = obj.Theme_.DashboardBackground;
```

**Toolbar conditional extension pattern** (FastSenseCompanion.m:326-331 + 440-449 — extend Step 9a):
```matlab
% LEGACY: [1 10] grid — existing code, unchanged
hToolbarGrid = uigridlayout(obj.hToolbarPanel_, [1 10]);
hToolbarGrid.ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, '1x', 36};

% FLEET MODE: [1 11] grid — active-machine indicator at col 10, gear at col 11
hToolbarGrid = uigridlayout(obj.hToolbarPanel_, [1 11]);
hToolbarGrid.ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, '1x', 'fit', 36};
% NOTE: gear button Layout.Column must be set to 11 in fleet branch
```

**Active-machine indicator label pattern** (UI-SPEC.md):
```matlab
% Created only in fleet mode, col 10 of the [1 11] toolbar grid
obj.hActiveMachineLabel_ = uilabel(hToolbarGrid);
obj.hActiveMachineLabel_.Layout.Row         = 1;
obj.hActiveMachineLabel_.Layout.Column      = 10;
obj.hActiveMachineLabel_.FontSize           = 11;
obj.hActiveMachineLabel_.FontWeight         = 'bold';
obj.hActiveMachineLabel_.FontColor          = obj.Theme_.Accent;
obj.hActiveMachineLabel_.BackgroundColor    = obj.Theme_.WidgetBackground;
obj.hActiveMachineLabel_.HorizontalAlignment = 'left';
obj.hActiveMachineLabel_.VerticalAlignment   = 'center';
obj.hActiveMachineLabel_.Tag                = 'CompanionActiveMachineLabel';
```

**Panel column assignment pattern for fleet mode** (FastSenseCompanion.m:452-459 — extend Step 9b):
```matlab
% FLEET MODE panel column assignments (shift right by 1):
obj.hMachineSelectorPanel_ = uipanel(obj.hLayout_);
obj.hMachineSelectorPanel_.Layout.Row = 2; obj.hMachineSelectorPanel_.Layout.Column = 1;
obj.hLeftPanel_.Layout.Row = 2;  obj.hLeftPanel_.Layout.Column  = 2;  % was col 1
obj.hMidPanel_.Layout.Row  = 2;  obj.hMidPanel_.Layout.Column   = 3;  % was col 2
obj.hRightPanel_.Layout.Row = 2; obj.hRightPanel_.Layout.Column = 4;  % was col 3
obj.hToolbarPanel_.Layout.Column = [1 4];   % was [1 3]
obj.hLogPanel_.Layout.Column     = [1 4];   % was [1 3]
```

**onMachineSelected_ machine-switch handler pattern** (FastSenseCompanion.m:725-800 setProject + 867-906 live mode):
```matlab
function onMachineSelected_(obj, selectedId)
%ONMACHINESELECTED_ Handle machine selection change — stop live, switch context, restart.
    try
        wasLive = obj.IsLive;
        if wasLive
            obj.stopLiveMode();     % stops timer (does NOT delete); obj.IsLive = false
        end
        newMachine = obj.Fleet_.getMachine(selectedId);
        obj.setProject(newMachine.Dashboards, newMachine);
        obj.updateActiveMachineIndicator_(newMachine);
        if wasLive
            obj.startLiveMode();    % re-starts same timer; obj.IsLive = true
        end
    catch ME
        uialert(obj.hFig_, ME.message, 'Machine Switch Failed', 'Icon', 'error');
    end
end

function updateActiveMachineIndicator_(obj, machine)
%UPDATEACTIVEMACHINEINDICATOR_ Update toolbar label text and tooltip.
    if isempty(obj.hActiveMachineLabel_) || ~isvalid(obj.hActiveMachineLabel_); return; end
    if usejava('desktop')
        prefix = char(9658);   % ▶
    else
        prefix = '>';
    end
    obj.hActiveMachineLabel_.Text    = [prefix ' ' machine.Name ' [' machine.Id ']'];
    obj.hActiveMachineLabel_.Tooltip = ['Active machine: ' machine.Name ' (Id: ' machine.Id ')'];
end
```

**stopLiveMode / startLiveMode pattern** (FastSenseCompanion.m:867-906 — existing, copy order):
```matlab
% stopLiveMode stops but does NOT delete the timer (for reuse):
stop(obj.LiveTimer_);     % obj.IsLive = false after this
% startLiveMode re-starts the same timer object if still valid:
start(obj.LiveTimer_);    % obj.IsLive = true after this
% close() teardown DOES delete the timer:
stop(obj.LiveTimer_); delete(obj.LiveTimer_);   % FastSenseCompanion.m:590-594
```

**Four TagRegistry.find redirect pattern** (FastSenseCompanion.m:1614-1618 — safe conditional form per RESEARCH.md Pitfall 3):
```matlab
% BEFORE (at FastSenseCompanion.m:1616):
tags = TagRegistry.find(@(t) isa(t, 'Tag'));
% AFTER:
if isempty(obj.Fleet_)
    tags = TagRegistry.find(@(t) isa(t, 'Tag'));
else
    tags = obj.Registry_.find(@(t) isa(t, 'Tag'));
end

% BEFORE (at FastSenseCompanion.m:1618):
tags = TagRegistry.find(@(t) isa(t, 'SensorTag') || isa(t, 'StateTag'));
% AFTER:
if isempty(obj.Fleet_)
    tags = TagRegistry.find(@(t) isa(t, 'SensorTag') || isa(t, 'StateTag'));
else
    tags = obj.Registry_.find(@(t) isa(t, 'SensorTag') || isa(t, 'StateTag'));
end
```

**MachineSelectorPane detach in close() teardown pattern** (FastSenseCompanion.m:624-645 — mirror existing pane detach blocks):
```matlab
% Add after CatalogPane.detach() block (FastSenseCompanion.m:624):
try
    if ~isempty(obj.MachineSelectorPane_) && isvalid(obj.MachineSelectorPane_)
        obj.MachineSelectorPane_.detach();
    end
catch err
    fprintf(2, '[FastSenseCompanion] MachineSelectorPane.detach failed: %s\n', err.message);
end
```

---

### `libs/FastSenseCompanion/TagCatalogPane.m` — redirect lines 60, 205 (component, request-response)

**Self-analog:** TagCatalogPane.m lines 60 and 205.

**Line 60 redirect** (TagCatalogPane.m:60 — inside `attach()`):
```matlab
% BEFORE:
obj.AllTags_ = TagRegistry.find(@(t) true);
% AFTER (safe conditional — obj.Registry_ is either a Machine or TagRegistry handle):
if isa(obj.Registry_, 'TagRegistry')
    obj.AllTags_ = TagRegistry.find(@(t) true);
else
    obj.AllTags_ = obj.Registry_.find(@(t) true);
end
```

**Line 205 redirect** (TagCatalogPane.m:205 — inside `refresh()`):
```matlab
% BEFORE:
obj.AllTags_ = TagRegistry.find(@(t) true);
% AFTER (same conditional):
if isa(obj.Registry_, 'TagRegistry')
    obj.AllTags_ = TagRegistry.find(@(t) true);
else
    obj.AllTags_ = obj.Registry_.find(@(t) true);
end
```

Note: `Registry_` is already stored as a property (TagCatalogPane.m:40). The `attach()` call from `setProject` passes the Machine handle as `registry`, so `obj.Registry_` holds the Machine in fleet mode.

---

### `tests/test_machine_selector_pane.m` (test, transform — Octave-flat)

**Analog:** `tests/test_*.m` flat Octave pattern (e.g. `tests/test_add_line.m`) and `libs/FastSenseCompanion/private/filterTags.m` (tested pure logic)

**Flat test function pattern** (from existing test_*.m files):
```matlab
function test_machine_selector_pane()
%TEST_MACHINE_SELECTOR_PANE Octave-flat pure-logic tests for filterMachines helper.
%   Tests MACH-01: filterMachines(machines, term) logic.
%   No uifigure required — headless safe.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    nPassed = 0;
    nFailed = 0;

    % Test: empty term returns all machines
    % Test: term matches Name (case-insensitive)
    % Test: term matches Id (case-insensitive)
    % Test: no match returns empty
    % Test: empty machinesCell returns empty

    fprintf('    All %d tests passed.\n', nPassed);
end
```

**Machine stub construction for headless tests** (no uifigure; use Machine('Id','M01','Name','Pump 1') directly):
```matlab
% Build test machine stubs using the real Machine constructor (Octave-safe):
m1 = Machine('Id', 'M01', 'Name', 'Press Line 3', 'Group', 'Presses');
m2 = Machine('Id', 'M02', 'Name', 'Pump Station 1');
machines = {m1, m2};
```

---

### `tests/suite/TestFastSenseCompanion.m` — extend (test, request-response)

**Self-analog:** TestFastSenseCompanion.m:1-155

**TestClassSetup / headless guard pattern** (TestFastSenseCompanion.m:9-30 — copy guards verbatim into new methods):
```matlab
% Existing guards that new test methods inherit automatically:
% - gateModernMatlab: requires MATLAB R2021a+
% - gateHeadlessLinux: skips on headless Linux (usejava('desktop') == false)
% - skipOnOctave (TestMethodSetup): skips uifigure tests on Octave

% New test methods follow the same structure:
function testFleetConstructionGridIs3x4(testCase)
%TESTFLEETCONSTRUCTIONGRIDIS3X4 MACH-05: fleet mode builds [3 4] root grid.
    fleet = Fleet();
    fleet.addMachine('Id', 'M01', 'Name', 'Machine 1');
    app = FastSenseCompanion('Fleet', fleet);
    testCase.addTeardown(@() app.close());
    s = struct(app);
    testCase.verifyEqual(numel(s.hLayout_.ColumnWidth), 4, ...
        'MACH-05: fleet mode must produce a 4-column root grid');
end
```

**private-field access pattern** (TestFastSenseCompanion.m:123 — use `struct(app)` for private field inspection):
```matlab
s = struct(app);
% Access: s.hLeftPanel_, s.hMidPanel_, s.hRightPanel_, s.LiveTimer_, etc.
```

**timerfindall invariant pattern** (TestFastSenseCompanion.m:137-143 — extend for MACH-04):
```matlab
function testMachineSwitch_TimerStable(testCase)
%TESTMACHINESWITCH_TIMERSTABLE MACH-04: timerfindall count stable across N switches.
    fleet = Fleet();
    fleet.addMachine('Id', 'M01', 'Name', 'Machine 1');
    fleet.addMachine('Id', 'M02', 'Name', 'Machine 2');
    app = FastSenseCompanion('Fleet', fleet);
    testCase.addTeardown(@() app.close());
    app.startLiveMode();
    timersBefore = numel(timerfindall);
    s = struct(app);
    for i = 1:5
        ids = fleet.machineIds();
        id = ids{mod(i, 2) + 1};   % alternate M01/M02
        s.MachineSelectorPane_.selectById(id);
    end
    testCase.verifyEqual(numel(timerfindall), timersBefore, ...
        'MACH-04: timerfindall count must be stable across machine switches');
end
```

**addTeardown pattern** (TestFastSenseCompanion.m:48-50 — always used with app):
```matlab
app = FastSenseCompanion('Fleet', fleet);
testCase.addTeardown(@() app.close());
```

---

## Shared Patterns

### Error Handling (try/catch + uialert)
**Source:** `libs/FastSenseCompanion/TagCatalogPane.m:342-362` (onSearchChanged_) and `FastSenseCompanion.m` callbacks
**Apply to:** All `MachineSelectorPane` callbacks + `onMachineSelected_` in `FastSenseCompanion`
```matlab
try
    % ... callback body ...
catch err
    uialert(obj.hFig_, err.message, 'FastSense Companion');
end
```

### Theme Walker (no walker changes needed)
**Source:** `libs/FastSenseCompanion/private/applyThemeToChildren_.m`
**Apply to:** `MachineSelectorPane.setTheme()` — call `applyThemeToChildren_(obj.hPanel_, t)` then post-walk overrides for `hSearchClear_.FontColor` and `hCountLabel_.FontColor`.

### Timer Teardown Order
**Source:** `libs/FastSenseCompanion/FastSenseCompanion.m:588-599` (close teardown) and `TagCatalogPane.m:184-189` (detach)
**Apply to:** `MachineSelectorPane.detach()`, `onMachineSelected_` machine switch
**Invariant:** Always `stop(t)` before `delete(t)`. `stopLiveMode` stops but does NOT delete (timer reused). `close()` teardown stops AND deletes.

### Octave-safe Substring Filter
**Source:** `libs/FastSenseCompanion/private/filterTags.m:27-38` and `libs/Fleet/Fleet.m:123-131`
**Apply to:** `filterMachines.m`
```matlab
needle = lower(searchTerm);
% Use strfind(lower(str), needle) — NEVER contains()
~isempty(strfind(lower(field), needle))
```

### Listener Cleanup
**Source:** `libs/FastSenseCompanion/TagCatalogPane.m:192-198` (detach iteration)
**Apply to:** `MachineSelectorPane.detach()`
```matlab
% Never delete(cellArray) — MATLAB interprets as filename-delete.
% Iterate explicitly:
for ii = 1:numel(obj.Listeners_)
    lh = obj.Listeners_{ii};
    if isobject(lh) && isvalid(lh)
        delete(lh);
    end
end
obj.Listeners_ = {};
```

---

## No Analog Found

All files have strong analogs. No files require RESEARCH.md-only patterns.

---

## Metadata

**Analog search scope:** `libs/FastSenseCompanion/`, `libs/Fleet/`, `tests/suite/TestFastSenseCompanion.m`, `tests/test_*.m`
**Files scanned:** 7 primary analog files read in full
**Pattern extraction date:** 2026-06-08
