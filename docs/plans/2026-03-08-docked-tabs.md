# FastPlotDock Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a `FastPlotDock` class that docks multiple `FastPlotFigure` dashboards into a single tabbed window with instant tab switching.

**Architecture:** A new `FastPlotDock` class owns one `figure()` window. Multiple `FastPlotFigure` instances render their tile axes into this shared figure. A row of toggle buttons at the top acts as the tab bar. Tab switching shows/hides all axes and toolbar controls for the active tab. `FastPlotFigure` gets a `ParentFigure` option to skip creating its own window, and a `ContentOffset` to position tiles below the tab bar.

**Tech Stack:** Pure MATLAB 2020b+, `uicontrol('style','togglebutton')` for tab buttons, classic `figure()` and `axes()`.

**Design doc:** `docs/plans/2026-03-08-docked-tabs-design.md`

---

## Task 1: Add ParentFigure Support to FastPlotFigure

**Files:**
- Modify: `FastPlotFigure.m:6-75` (properties + constructor)
- Test: `tests/test_figure_layout.m`

**Step 1: Write the failing test**

Add to the end of `tests/test_figure_layout.m`, before the final `fprintf`:

```matlab
% testParentFigure
hParent = figure('Visible', 'off');
fig = FastPlotFigure(2, 1, 'ParentFigure', hParent);
assert(fig.hFigure == hParent, 'testParentFigure: should use parent figure');
fp = fig.tile(1);
fp.addLine(1:50, rand(1,50));
fp.render();
assert(get(fp.hAxes, 'Parent') == hParent, 'testParentFigure: axes in parent');
close(hParent);
```

Update the test count in the final fprintf from 13 to 14.

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_figure_layout"`
Expected: FAIL — FastPlotFigure doesn't recognize 'ParentFigure' option.

**Step 3: Implement ParentFigure support**

In `FastPlotFigure.m`, add a new public property after line 9:

```matlab
ParentFigure = []     % external figure handle (skip figure creation)
```

In the constructor (lines 54-74), add a case in the switch block:

```matlab
case 'parentfigure'
    obj.ParentFigure = varargin{k+1};
```

Replace the figure creation at lines 72-74 with:

```matlab
if ~isempty(obj.ParentFigure)
    obj.hFigure = obj.ParentFigure;
else
    obj.hFigure = figure('Visible', 'off', ...
        'Color', obj.Theme.Background, figOpts{:});
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_figure_layout"`
Expected: All 14 tests pass.

**Step 5: Commit**

```bash
git add FastPlotFigure.m tests/test_figure_layout.m
git commit -m "feat: add ParentFigure option to FastPlotFigure for headless mode"
```

---

## Task 2: Add ContentOffset Support to FastPlotFigure

**Files:**
- Modify: `FastPlotFigure.m:6-9` (properties) and `FastPlotFigure.m:393-425` (computeTilePosition)
- Test: `tests/test_figure_layout.m`

**Step 1: Write the failing test**

Add to `tests/test_figure_layout.m` before the final `fprintf`:

```matlab
% testContentOffset
fig = FastPlotFigure(1, 1);
fig.ContentOffset = [0.05 0.05 0.9 0.85];
fp = fig.tile(1);
fp.addLine(1:50, rand(1,50));
fp.render();
pos = get(fp.hAxes, 'Position');
% Tile should be within the content offset region
assert(pos(2) >= 0.04, sprintf('testContentOffset: bottom %.3f >= 0.04', pos(2)));
assert(pos(2) + pos(4) <= 0.95, sprintf('testContentOffset: top %.3f <= 0.95', pos(2)+pos(4)));
close(fig.hFigure);
```

Update the test count in the final fprintf from 14 to 15.

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_figure_layout"`
Expected: FAIL — ContentOffset property does not exist.

**Step 3: Implement ContentOffset**

Add a new public property in `FastPlotFigure.m` after the ParentFigure property:

```matlab
ContentOffset = [0 0 1 1]  % [left bottom width height] normalized content area
```

Modify `computeTilePosition` to map tile positions into the content area. Replace the method body:

```matlab
function pos = computeTilePosition(obj, n)
    rows = obj.Grid(1);
    cols = obj.Grid(2);
    span = obj.TileSpans{n};
    rowSpan = span(1);
    colSpan = span(2);

    % Convert tile index to row, col (1-based, top-left origin)
    row = ceil(n / cols);
    col = mod(n - 1, cols) + 1;

    pad = obj.PADDING;
    gapH = obj.GAP_H;
    gapV = obj.GAP_V;

    % Content area
    co = obj.ContentOffset;
    coLeft = co(1); coBottom = co(2); coWidth = co(3); coHeight = co(4);

    % Available space after padding (within content area)
    totalW = coWidth - 2*pad;
    totalH = coHeight - 2*pad;

    % Cell dimensions
    cellW = (totalW - (cols-1)*gapH) / cols;
    cellH = (totalH - (rows-1)*gapV) / rows;

    % Position (bottom-left origin for MATLAB), offset by content area
    x = coLeft + pad + (col-1) * (cellW + gapH);
    y = coBottom + coHeight - pad - row * cellH - (row-1) * gapV;

    % Apply span
    w = colSpan * cellW + (colSpan-1) * gapH;
    h = rowSpan * cellH + (rowSpan-1) * gapV;

    pos = [x, y, w, h];
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_figure_layout"`
Expected: All 15 tests pass.

**Step 5: Commit**

```bash
git add FastPlotFigure.m tests/test_figure_layout.m
git commit -m "feat: add ContentOffset property for positioning tiles within a sub-region"
```

---

## Task 3: Create FastPlotDock Skeleton

**Files:**
- Create: `FastPlotDock.m`
- Create: `tests/test_dock.m`

**Step 1: Write the failing test**

Create `tests/test_dock.m`:

```matlab
function test_dock()
%TEST_DOCK Tests for FastPlotDock tabbed container.

    add_private_path();
    close all force;
    drawnow;

    % testConstruction
    dock = FastPlotDock('Theme', 'dark', 'Name', 'Test Dock');
    assert(~isempty(dock.hFigure), 'testConstruction: hFigure');
    assert(ishandle(dock.hFigure), 'testConstruction: hFigure valid');
    assert(strcmp(get(dock.hFigure, 'Name'), 'Test Dock'), 'testConstruction: Name');
    close(dock.hFigure);

    % testDefaultTheme
    dock = FastPlotDock();
    assert(~isempty(dock.Theme), 'testDefaultTheme: should have theme');
    close(dock.hFigure);

    fprintf('    All 2 dock tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: FAIL — FastPlotDock class not found.

**Step 3: Create FastPlotDock.m skeleton**

Create `FastPlotDock.m`:

```matlab
classdef FastPlotDock < handle
    %FASTPLOTDOCK Tabbed container for multiple FastPlotFigure dashboards.
    %   dock = FastPlotDock()
    %   dock = FastPlotDock('Theme', 'dark', 'Name', 'My Dock')

    properties (Access = public)
        Theme     = []         % FastPlotTheme struct
        hFigure   = []         % shared figure handle
    end

    properties (SetAccess = private)
        Tabs      = struct('Name', {}, 'Figure', {}, 'Toolbar', {})
        ActiveTab = 0          % index of currently visible tab
        hTabButtons = {}       % cell array of uicontrol handles
    end

    properties (Constant, Access = private)
        TAB_BAR_HEIGHT = 0.04  % normalized height for tab bar
    end

    methods (Access = public)
        function obj = FastPlotDock(varargin)
            figOpts = {};
            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'theme'
                        val = varargin{k+1};
                        if ischar(val) || isstruct(val)
                            obj.Theme = FastPlotTheme(val);
                        else
                            obj.Theme = val;
                        end
                    otherwise
                        figOpts{end+1} = varargin{k};   %#ok<AGROW>
                        figOpts{end+1} = varargin{k+1};  %#ok<AGROW>
                end
            end

            if isempty(obj.Theme)
                obj.Theme = FastPlotTheme('default');
            end

            obj.hFigure = figure('Visible', 'off', ...
                'Color', obj.Theme.Background, figOpts{:});
        end

        function delete(obj)
            % Stop all live timers before closing
            for i = 1:numel(obj.Tabs)
                if ~isempty(obj.Tabs(i).Figure)
                    try obj.Tabs(i).Figure.stopLive(); catch; end
                end
            end
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                delete(obj.hFigure);
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: All 2 tests pass.

**Step 5: Commit**

```bash
git add FastPlotDock.m tests/test_dock.m
git commit -m "feat: add FastPlotDock skeleton with constructor and cleanup"
```

---

## Task 4: Implement addTab

**Files:**
- Modify: `FastPlotDock.m` (add `addTab` method)
- Modify: `tests/test_dock.m`

**Step 1: Write the failing test**

Add to `tests/test_dock.m` before the final `fprintf`:

```matlab
% testAddTab
dock = FastPlotDock('Theme', 'dark');
fig1 = FastPlotFigure(2, 1, 'ParentFigure', dock.hFigure);
fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
fp = fig1.tile(2); fp.addLine(1:50, rand(1,50));
dock.addTab(fig1, 'Dashboard 1');
assert(numel(dock.Tabs) == 1, 'testAddTab: 1 tab');
assert(strcmp(dock.Tabs(1).Name, 'Dashboard 1'), 'testAddTab: name');

fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
dock.addTab(fig2, 'Dashboard 2');
assert(numel(dock.Tabs) == 2, 'testAddTab: 2 tabs');
close(dock.hFigure);
```

Update test count from 2 to 3.

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: FAIL — no addTab method.

**Step 3: Implement addTab**

Add to the public methods section of `FastPlotDock.m`:

```matlab
function addTab(obj, fig, name)
    %ADDTAB Register a FastPlotFigure as a tab.
    %   dock.addTab(fig, 'Tab Name')
    %
    %   The figure must be created with 'ParentFigure' set to dock.hFigure,
    %   or it will be reassigned automatically.

    % Ensure the figure renders into our window
    if isempty(fig.ParentFigure) || fig.ParentFigure ~= obj.hFigure
        fig.ParentFigure = obj.hFigure;
        fig.hFigure = obj.hFigure;
    end

    % Set content offset to leave room for tab bar
    tabH = obj.TAB_BAR_HEIGHT;
    fig.ContentOffset = [0, 0, 1, 1 - tabH];

    % Append to tabs
    idx = numel(obj.Tabs) + 1;
    obj.Tabs(idx).Name = name;
    obj.Tabs(idx).Figure = fig;
    obj.Tabs(idx).Toolbar = [];
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: All 3 tests pass.

**Step 5: Commit**

```bash
git add FastPlotDock.m tests/test_dock.m
git commit -m "feat: add addTab method to FastPlotDock"
```

---

## Task 5: Implement render and Tab Bar

**Files:**
- Modify: `FastPlotDock.m` (add `render`, `createTabBar`, `onTabClick` methods)
- Modify: `tests/test_dock.m`

**Step 1: Write the failing test**

Add to `tests/test_dock.m` before the final `fprintf`:

```matlab
% testRender
dock = FastPlotDock('Theme', 'dark');
fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
dock.addTab(fig1, 'Tab A');

fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
dock.addTab(fig2, 'Tab B');

dock.render();
assert(dock.ActiveTab == 1, 'testRender: first tab active');
assert(strcmp(get(dock.hFigure, 'Visible'), 'on'), 'testRender: figure visible');
assert(numel(dock.hTabButtons) == 2, 'testRender: 2 tab buttons');
% Tab A tiles should be visible
assert(strcmp(get(fig1.tile(1).hAxes, 'Visible'), 'on'), 'testRender: tab A visible');
% Tab B tiles should be hidden
assert(strcmp(get(fig2.tile(1).hAxes, 'Visible'), 'off'), 'testRender: tab B hidden');
close(dock.hFigure);
```

Update test count from 3 to 4.

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: FAIL — no render method.

**Step 3: Implement render and tab bar**

Add these methods to the public section of `FastPlotDock.m`:

```matlab
function render(obj)
    %RENDER Render all tabs, create tab bar, show first tab.
    if isempty(obj.Tabs)
        set(obj.hFigure, 'Visible', 'on');
        return;
    end

    % Render all figures (all axes created but deferred draw)
    for i = 1:numel(obj.Tabs)
        obj.Tabs(i).Figure.renderAll();
        % Create toolbar for each tab
        obj.Tabs(i).Toolbar = FastPlotToolbar(obj.Tabs(i).Figure);
    end

    % Create the tab bar buttons
    obj.createTabBar();

    % Hide all tabs, then show the first one
    for i = 1:numel(obj.Tabs)
        obj.setTabVisible(i, false);
    end
    obj.selectTab(1);

    set(obj.hFigure, 'Visible', 'on');
    drawnow;
end

function selectTab(obj, n)
    %SELECTTAB Switch to tab n.
    if n < 1 || n > numel(obj.Tabs)
        error('FastPlotDock:outOfBounds', ...
            'Tab %d is out of range (1-%d).', n, numel(obj.Tabs));
    end

    % Hide current tab
    if obj.ActiveTab >= 1 && obj.ActiveTab <= numel(obj.Tabs)
        obj.setTabVisible(obj.ActiveTab, false);
        obj.styleTabButton(obj.ActiveTab, false);
    end

    % Show new tab
    obj.setTabVisible(n, true);
    obj.styleTabButton(n, true);
    obj.ActiveTab = n;
end
```

Add these methods to a new private methods section:

```matlab
methods (Access = private)
    function createTabBar(obj)
        nTabs = numel(obj.Tabs);
        tabH = obj.TAB_BAR_HEIGHT;
        btnWidth = min(0.15, 0.95 / nTabs);  % cap button width
        startX = 0.025;

        obj.hTabButtons = cell(1, nTabs);
        for i = 1:nTabs
            obj.hTabButtons{i} = uicontrol(obj.hFigure, ...
                'Style', 'togglebutton', ...
                'String', obj.Tabs(i).Name, ...
                'Units', 'normalized', ...
                'Position', [startX + (i-1)*btnWidth, 1 - tabH, btnWidth, tabH], ...
                'FontSize', 9, ...
                'Callback', @(s,e) obj.onTabClick(i));
        end
    end

    function onTabClick(obj, idx)
        obj.selectTab(idx);
    end

    function setTabVisible(obj, idx, visible)
        fig = obj.Tabs(idx).Figure;
        visStr = 'off';
        if visible; visStr = 'on'; end

        % Toggle all tile axes
        for i = 1:numel(fig.TileAxes)
            if ~isempty(fig.TileAxes{i}) && ishandle(fig.TileAxes{i})
                set(fig.TileAxes{i}, 'Visible', visStr);
                % Toggle all children (lines, patches, text)
                ch = get(fig.TileAxes{i}, 'Children');
                for j = 1:numel(ch)
                    if ishandle(ch(j))
                        set(ch(j), 'Visible', visStr);
                    end
                end
                % Toggle title and labels
                set(get(fig.TileAxes{i}, 'Title'), 'Visible', visStr);
                set(get(fig.TileAxes{i}, 'XLabel'), 'Visible', visStr);
                set(get(fig.TileAxes{i}, 'YLabel'), 'Visible', visStr);
            end
        end

        % Toggle toolbar
        tb = obj.Tabs(idx).Toolbar;
        if ~isempty(tb) && ~isempty(tb.hToolbar) && ishandle(tb.hToolbar)
            set(tb.hToolbar, 'Visible', visStr);
        end
    end

    function styleTabButton(obj, idx, active)
        if idx < 1 || idx > numel(obj.hTabButtons); return; end
        btn = obj.hTabButtons{idx};
        if ~ishandle(btn); return; end
        if active
            set(btn, 'Value', 1, ...
                'BackgroundColor', obj.Theme.Background * 0.8 + [0.05 0.1 0.2], ...
                'ForegroundColor', obj.Theme.ForegroundColor, ...
                'FontWeight', 'bold');
        else
            set(btn, 'Value', 0, ...
                'BackgroundColor', obj.Theme.Background, ...
                'ForegroundColor', obj.Theme.ForegroundColor * 0.7, ...
                'FontWeight', 'normal');
        end
    end
end
```

**Important:** `TileAxes` is `SetAccess = private` on `FastPlotFigure`. Change it to `SetAccess = private, GetAccess = public` — but actually, MATLAB default `GetAccess` is `public` when only `SetAccess = private` is specified, so it already is accessible. The Toolbar property on `Tabs` struct is what we store; the actual `FastPlotToolbar.hToolbar` has `GetAccess = public` already. No access changes needed.

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: All 4 tests pass.

**Step 5: Commit**

```bash
git add FastPlotDock.m tests/test_dock.m
git commit -m "feat: implement render, selectTab, and tab bar in FastPlotDock"
```

---

## Task 6: Implement Tab Switching

**Files:**
- Modify: `tests/test_dock.m`

**Step 1: Write the failing test**

Add to `tests/test_dock.m` before the final `fprintf`:

```matlab
% testSelectTab
dock = FastPlotDock('Theme', 'dark');
fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
dock.addTab(fig1, 'Tab A');

fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
dock.addTab(fig2, 'Tab B');
dock.render();

% Switch to tab 2
dock.selectTab(2);
assert(dock.ActiveTab == 2, 'testSelectTab: active is 2');
assert(strcmp(get(fig1.tile(1).hAxes, 'Visible'), 'off'), 'testSelectTab: tab A hidden');
assert(strcmp(get(fig2.tile(1).hAxes, 'Visible'), 'on'), 'testSelectTab: tab B visible');

% Switch back to tab 1
dock.selectTab(1);
assert(dock.ActiveTab == 1, 'testSelectTab: active is 1');
assert(strcmp(get(fig1.tile(1).hAxes, 'Visible'), 'on'), 'testSelectTab: tab A visible again');
assert(strcmp(get(fig2.tile(1).hAxes, 'Visible'), 'off'), 'testSelectTab: tab B hidden again');
close(dock.hFigure);

% testSelectTabOutOfBounds
dock = FastPlotDock();
fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
dock.addTab(fig1, 'Only Tab');
dock.render();
threw = false;
try
    dock.selectTab(5);
catch
    threw = true;
end
assert(threw, 'testSelectTabOutOfBounds: should error');
close(dock.hFigure);
```

Update test count from 4 to 6.

**Step 2: Run test to verify it passes**

These tests should already pass since `selectTab` was implemented in Task 5. Run to confirm:

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: All 6 tests pass.

**Step 3: Commit**

```bash
git add tests/test_dock.m
git commit -m "test: add tab switching tests for FastPlotDock"
```

---

## Task 7: Handle Figure Resize

**Files:**
- Modify: `FastPlotDock.m` (add resize callback)
- Modify: `tests/test_dock.m`

**Step 1: Write the failing test**

Add to `tests/test_dock.m` before the final `fprintf`:

```matlab
% testResize
dock = FastPlotDock('Theme', 'dark');
fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
dock.addTab(fig1, 'Tab A');
dock.render();
posBefore = get(fig1.tile(1).hAxes, 'Position');
% Simulate resize by calling the recompute method
dock.recomputeLayout();
posAfter = get(fig1.tile(1).hAxes, 'Position');
% Positions should remain consistent (no crash)
assert(abs(posBefore(1) - posAfter(1)) < 0.01, 'testResize: x stable');
assert(abs(posBefore(2) - posAfter(2)) < 0.01, 'testResize: y stable');
close(dock.hFigure);
```

Update test count from 6 to 7.

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: FAIL — no recomputeLayout method.

**Step 3: Implement resize handling**

Add to public methods in `FastPlotDock.m`:

```matlab
function recomputeLayout(obj)
    %RECOMPUTELAYOUT Recalculate all tile positions for all tabs.
    for i = 1:numel(obj.Tabs)
        fig = obj.Tabs(i).Figure;
        for j = 1:numel(fig.TileAxes)
            if ~isempty(fig.TileAxes{j}) && ishandle(fig.TileAxes{j})
                pos = fig.computeTilePosition(j);
                set(fig.TileAxes{j}, 'Position', pos);
            end
        end
    end

    % Reposition tab buttons
    if ~isempty(obj.hTabButtons)
        nTabs = numel(obj.hTabButtons);
        tabH = obj.TAB_BAR_HEIGHT;
        btnWidth = min(0.15, 0.95 / nTabs);
        startX = 0.025;
        for i = 1:nTabs
            if ishandle(obj.hTabButtons{i})
                set(obj.hTabButtons{i}, 'Position', ...
                    [startX + (i-1)*btnWidth, 1 - tabH, btnWidth, tabH]);
            end
        end
    end
end
```

In the constructor, after creating the figure, add the resize callback:

```matlab
set(obj.hFigure, 'SizeChangedFcn', @(s,e) obj.recomputeLayout());
```

**Important:** `computeTilePosition` is currently `Access = private` on `FastPlotFigure`. Change it to a new `methods (Access = {?FastPlotDock, ?FastPlotFigure})` block, or simpler: move it to `Access = public` (it's a read-only computation, no harm). Alternatively, use a `friend` pattern — but MATLAB doesn't support that cleanly. The simplest approach: change `computeTilePosition` from `private` to a new protected-like block. Actually, the cleanest MATLAB pattern is to add `Access = ?FastPlotDock` to the private methods. But this requires splitting the private methods block. Instead, just make `computeTilePosition` public — it's a pure computation with no side effects.

In `FastPlotFigure.m`, move `computeTilePosition` from the `methods (Access = private)` block to a new block:

```matlab
methods (Access = public, Hidden = true)
    function pos = computeTilePosition(obj, n)
        % ... existing code unchanged ...
    end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: All 7 tests pass.

**Step 5: Commit**

```bash
git add FastPlotDock.m FastPlotFigure.m tests/test_dock.m
git commit -m "feat: add resize handling to FastPlotDock"
```

---

## Task 8: Handle Figure Close with Live Timers

**Files:**
- Modify: `FastPlotDock.m` (add CloseRequestFcn)
- Modify: `tests/test_dock.m`

**Step 1: Write the failing test**

Add to `tests/test_dock.m` before the final `fprintf`:

```matlab
% testCloseStopsLive
dock = FastPlotDock('Theme', 'dark');
fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fp = fig1.tile(1); fp.addLine(1:100, zeros(1,100));
dock.addTab(fig1, 'Live Tab');
dock.render();

tmpFile = [tempname, '.mat'];
s.x = 1:100; s.y = rand(1,100);
save(tmpFile, '-struct', 's');
fig1.startLive(tmpFile, @(f,d) f.tile(1).updateData(1, d.x, d.y), 'Interval', 1.0);
assert(fig1.LiveIsActive, 'testCloseStopsLive: live active before close');

close(dock.hFigure);
assert(~fig1.LiveIsActive, 'testCloseStopsLive: live stopped after close');
delete(tmpFile);
```

Update test count from 7 to 8.

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: FAIL — closing figure doesn't stop live timers.

**Step 3: Implement CloseRequestFcn**

In the `FastPlotDock` constructor, after creating the figure, add:

```matlab
set(obj.hFigure, 'CloseRequestFcn', @(s,e) obj.onClose());
```

Add to the private methods section:

```matlab
function onClose(obj)
    for i = 1:numel(obj.Tabs)
        if ~isempty(obj.Tabs(i).Figure)
            try obj.Tabs(i).Figure.stopLive(); catch; end
        end
    end
    if ishandle(obj.hFigure)
        delete(obj.hFigure);
    end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: All 8 tests pass.

**Step 5: Commit**

```bash
git add FastPlotDock.m tests/test_dock.m
git commit -m "feat: stop all live timers when dock window is closed"
```

---

## Task 9: Add Tab After Render

**Files:**
- Modify: `FastPlotDock.m` (update `addTab` to handle post-render case)
- Modify: `tests/test_dock.m`

**Step 1: Write the failing test**

Add to `tests/test_dock.m` before the final `fprintf`:

```matlab
% testAddTabAfterRender
dock = FastPlotDock('Theme', 'dark');
fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
dock.addTab(fig1, 'Tab A');
dock.render();

fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
dock.addTab(fig2, 'Tab B');

assert(numel(dock.Tabs) == 2, 'testAddTabAfterRender: 2 tabs');
assert(numel(dock.hTabButtons) == 2, 'testAddTabAfterRender: 2 buttons');
% New tab should be hidden (first tab still active)
assert(strcmp(get(fig2.tile(1).hAxes, 'Visible'), 'off'), 'testAddTabAfterRender: new tab hidden');
% Switch to it
dock.selectTab(2);
assert(strcmp(get(fig2.tile(1).hAxes, 'Visible'), 'on'), 'testAddTabAfterRender: new tab visible');
close(dock.hFigure);
```

Update test count from 8 to 9.

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: FAIL — addTab doesn't render or create tab button when called after render.

**Step 3: Implement post-render addTab**

Update the `addTab` method in `FastPlotDock.m`. After appending to `obj.Tabs`, add:

```matlab
% If already rendered, render this tab immediately
if obj.ActiveTab >= 1
    fig.renderAll();
    obj.Tabs(idx).Toolbar = FastPlotToolbar(fig);
    obj.setTabVisible(idx, false);
    obj.addTabButton(idx);
end
```

Extract tab button creation from `createTabBar` into a helper. Replace `createTabBar`:

```matlab
function createTabBar(obj)
    obj.hTabButtons = {};
    for i = 1:numel(obj.Tabs)
        obj.addTabButton(i);
    end
end

function addTabButton(obj, idx)
    nTabs = numel(obj.Tabs);
    tabH = obj.TAB_BAR_HEIGHT;
    btnWidth = min(0.15, 0.95 / nTabs);
    startX = 0.025;

    btn = uicontrol(obj.hFigure, ...
        'Style', 'togglebutton', ...
        'String', obj.Tabs(idx).Name, ...
        'Units', 'normalized', ...
        'Position', [startX + (idx-1)*btnWidth, 1 - tabH, btnWidth, tabH], ...
        'FontSize', 9, ...
        'Callback', @(s,e) obj.onTabClick(idx));
    obj.hTabButtons{idx} = btn;

    % Reposition all buttons to account for new count
    for i = 1:numel(obj.hTabButtons)
        if ishandle(obj.hTabButtons{i})
            set(obj.hTabButtons{i}, 'Position', ...
                [startX + (i-1)*btnWidth, 1 - tabH, btnWidth, tabH]);
        end
    end

    % Style active/inactive
    obj.styleTabButton(idx, idx == obj.ActiveTab);
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_dock"`
Expected: All 9 tests pass.

**Step 5: Commit**

```bash
git add FastPlotDock.m tests/test_dock.m
git commit -m "feat: support adding tabs after dock.render()"
```

---

## Task 10: Create Example Script

**Files:**
- Create: `examples/example_dock.m`

**Step 1: Create the example**

Create `examples/example_dock.m`:

```matlab
%% FastPlotDock — Tabbed Dashboard Example
% Two dashboards docked in a single window with tab switching.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

fprintf('Docked Tabs: 2 dashboards in 1 window...\n');
tic;

% =========================================================================
% Dashboard 1: Temperature Monitoring (2x2)
% =========================================================================
dock = FastPlotDock('Theme', 'dark', 'Name', 'Control Room', ...
    'Position', [50 50 1400 800]);

fig1 = FastPlotFigure(2, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

fp = fig1.tile(1);
n = 2e6;
x = linspace(0, 3600, n);
fp.addLine(x, 72 + 6*sin(x*2*pi/600) + 1.5*randn(1,n), 'DisplayName', 'Sensor A');
fp.addLine(x, 68 + 5*sin(x*2*pi/600 + 0.5) + 1.2*randn(1,n), 'DisplayName', 'Sensor B');
fp.addThreshold(82, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');

fp = fig1.tile(2);
n = 1e6;
x = linspace(0, 3600, n);
fp.addLine(x, 45 + 8*sin(x*2*pi/900) + 3*randn(1,n), 'DisplayName', 'Coolant Flow');
fp.addThreshold(55, 'Direction', 'upper', 'ShowViolations', true);
fp.addThreshold(35, 'Direction', 'lower', 'ShowViolations', true);

fp = fig1.tile(3);
n = 500000;
x = linspace(0, 3600, n);
fp.addLine(x, 101 + 12*sin(x*2*pi/1200) + 3*randn(1,n), 'DisplayName', 'Pressure');
fp.addBand(90, 115, 'FaceColor', [0.3 0.7 1], 'FaceAlpha', 0.12);

fp = fig1.tile(4);
n = 800000;
x = linspace(0, 3600, n);
y = 0.4*randn(1,n);
y(round(n*0.3):round(n*0.32)) = y(round(n*0.3):round(n*0.32)) + 2.5;
fp.addLine(x, y, 'DisplayName', 'Vibration');
fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', true);

dock.addTab(fig1, 'Temperature');

% =========================================================================
% Dashboard 2: Power Systems (1x2)
% =========================================================================
fig2 = FastPlotFigure(1, 2, 'ParentFigure', dock.hFigure, 'Theme', 'dark');

fp = fig2.tile(1);
n = 3e6;
x = linspace(0, 3600, n);
fp.addLine(x, abs(3*sin(x*2*pi/400) .* (1 + 0.2*randn(1,n))), 'DisplayName', 'Motor Current');
fp.addFill(x, abs(3*sin(x*2*pi/400) .* (1 + 0.2*randn(1,n))), ...
    'FaceColor', [0.9 0.6 0.1], 'FaceAlpha', 0.2);

fp = fig2.tile(2);
n = 1e6;
x = linspace(0, 3600, n);
fp.addLine(x, 1500 + 300*sin(x*2*pi/900) + 50*randn(1,n), ...
    'DisplayName', 'RPM', 'DownsampleMethod', 'lttb');

dock.addTab(fig2, 'Power Systems');

% =========================================================================
% Render and label
% =========================================================================
dock.render();

fig1.tileTitle(1, 'Temperature (2M pts)');
fig1.tileTitle(2, 'Coolant Flow (1M pts)');
fig1.tileTitle(3, 'Reactor Pressure (500K pts)');
fig1.tileTitle(4, 'Vibration (800K pts)');

fig2.tileTitle(1, 'Motor Current (3M pts)');
fig2.tileTitle(2, 'RPM — LTTB (1M pts)');

elapsed = toc;
fprintf('Docked tabs rendered in %.2f seconds.\n', elapsed);
fprintf('Click tabs at top to switch between dashboards.\n');
```

**Step 2: Run example to verify it works**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('examples'); example_dock"`
Expected: Window opens with two tabs. Click to switch.

**Step 3: Commit**

```bash
git add examples/example_dock.m
git commit -m "feat: add docked tabs example with two dashboards"
```

---

## Task 11: Register test_dock in run_all_tests

**Files:**
- Modify: `tests/run_all_tests.m`

**Step 1: Check current run_all_tests.m**

Read the file and add `test_dock` to the test runner in the same pattern as existing tests.

**Step 2: Add test_dock**

Add `test_dock();` call after the existing test calls.

**Step 3: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); run_all_tests"`
Expected: All tests pass including the new dock tests.

**Step 4: Commit**

```bash
git add tests/run_all_tests.m
git commit -m "test: register test_dock in run_all_tests"
```
