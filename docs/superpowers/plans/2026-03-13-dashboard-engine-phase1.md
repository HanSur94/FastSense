# Dashboard Engine Phase 1: Core API — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the core dashboard engine — a 12-column grid layout with FastPlot widgets, Sensor/ThresholdRule integration, JSON serialization, and global live mode.

**Architecture:** Thin wrapper approach. `DashboardEngine` orchestrates a `DashboardLayout` (12-column grid of `uipanel` containers), `FastPlotWidget` instances (each wrapping a `FastPlot`), and a `DashboardSerializer` for JSON load/save. A `DashboardToolbar` provides global controls. `DashboardTheme` extends `FastPlotTheme`'s struct with dashboard-specific fields.

**Tech Stack:** Pure MATLAB (R2020b compatible), figure-based UI (`figure`, `uipanel`, `uicontrol`), `jsondecode`/`jsonencode` for JSON, existing FastPlot/Sensor/ThresholdRule/DataStore APIs.

**Spec:** `docs/superpowers/specs/2026-03-12-dashboard-engine-design.md`

---

## File Structure

| File | Responsibility |
|---|---|
| Create: `libs/Dashboard/DashboardWidget.m` | Abstract base class for all widgets |
| Create: `libs/Dashboard/FastPlotWidget.m` | Wraps FastPlot + Sensor + ThresholdRule |
| Create: `libs/Dashboard/DashboardLayout.m` | 12-column grid positioning with overlap handling |
| Create: `libs/Dashboard/DashboardTheme.m` | Struct-returning function extending FastPlotTheme |
| Create: `libs/Dashboard/DashboardSerializer.m` | JSON load/save |
| Create: `libs/Dashboard/DashboardToolbar.m` | Global toolbar (live, edit, save, export) |
| Create: `libs/Dashboard/DashboardEngine.m` | Top-level orchestrator |
| Create: `tests/suite/TestDashboardWidget.m` | Tests for DashboardWidget base class |
| Create: `tests/suite/TestFastPlotWidget.m` | Tests for FastPlotWidget |
| Create: `tests/suite/TestDashboardLayout.m` | Tests for DashboardLayout grid math |
| Create: `tests/suite/TestDashboardTheme.m` | Tests for DashboardTheme |
| Create: `tests/suite/TestDashboardSerializer.m` | Tests for JSON round-trip |
| Create: `tests/suite/TestDashboardEngine.m` | Tests for DashboardEngine orchestration |
| Create: `tests/suite/MockDashboardWidget.m` | Concrete mock subclass for testing DashboardWidget |
| Modify: `setup.m` | Add `libs/Dashboard` to path |

---

## Chunk 1: Foundation Classes

### Task 1: Project Setup — Add Dashboard Directory to Path

**Files:**
- Modify: `setup.m`
- Create: `libs/Dashboard/` (directory)

- [ ] **Step 1: Create the Dashboard directory**

```bash
mkdir -p libs/Dashboard
```

- [ ] **Step 2: Add libs/Dashboard to setup.m path**

Read `setup.m` and add the Dashboard path alongside existing path entries. Follow the existing pattern (look for `addpath` calls to `libs/FastPlot`, `libs/SensorThreshold`, etc.) and add:

```matlab
addpath(fullfile(root, 'libs', 'Dashboard'));
```

- [ ] **Step 3: Verify path setup**

Run in MATLAB:
```matlab
setup();
disp(contains(path, 'Dashboard'));
```
Expected: `1`

- [ ] **Step 4: Commit**

```bash
git add setup.m libs/Dashboard
git commit -m "chore: add libs/Dashboard directory to path"
```

---

### Task 2: DashboardTheme — Struct Extension Function

**Files:**
- Create: `libs/Dashboard/DashboardTheme.m`
- Create: `tests/suite/TestDashboardTheme.m`

- [ ] **Step 1: Write the failing test**

Create `tests/suite/TestDashboardTheme.m`:

```matlab
classdef TestDashboardTheme < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testDefaultReturnsStruct(testCase)
            theme = DashboardTheme();
            testCase.verifyTrue(isstruct(theme), ...
                'DashboardTheme should return a struct');
        end

        function testContainsFastPlotFields(testCase)
            theme = DashboardTheme();
            testCase.verifyTrue(isfield(theme, 'Background'), ...
                'Should contain FastPlotTheme fields');
            testCase.verifyTrue(isfield(theme, 'FontSize'), ...
                'Should contain FastPlotTheme FontSize field');
        end

        function testContainsDashboardFields(testCase)
            theme = DashboardTheme();
            testCase.verifyTrue(isfield(theme, 'DashboardBackground'), ...
                'Should contain DashboardBackground');
            testCase.verifyTrue(isfield(theme, 'WidgetBackground'), ...
                'Should contain WidgetBackground');
            testCase.verifyTrue(isfield(theme, 'WidgetBorderColor'), ...
                'Should contain WidgetBorderColor');
            testCase.verifyTrue(isfield(theme, 'ToolbarBackground'), ...
                'Should contain ToolbarBackground');
            testCase.verifyTrue(isfield(theme, 'StatusOkColor'), ...
                'Should contain StatusOkColor');
            testCase.verifyTrue(isfield(theme, 'StatusWarnColor'), ...
                'Should contain StatusWarnColor');
            testCase.verifyTrue(isfield(theme, 'StatusAlarmColor'), ...
                'Should contain StatusAlarmColor');
        end

        function testPresetInheritance(testCase)
            theme = DashboardTheme('dark');
            baseDark = FastPlotTheme('dark');
            testCase.verifyEqual(theme.Background, baseDark.Background, ...
                'Should inherit FastPlotTheme dark preset Background');
            testCase.verifyEqual(theme.FontSize, baseDark.FontSize, ...
                'Should inherit FastPlotTheme dark preset FontSize');
        end

        function testNameValueOverrides(testCase)
            theme = DashboardTheme('default', 'DashboardBackground', [1 0 0]);
            testCase.verifyEqual(theme.DashboardBackground, [1 0 0], ...
                'Should apply name-value override');
        end

        function testAllPresetsHaveDashboardFields(testCase)
            presets = {'default', 'dark', 'light', 'industrial', 'scientific', 'ocean'};
            for i = 1:numel(presets)
                theme = DashboardTheme(presets{i});
                testCase.verifyTrue(isfield(theme, 'DashboardBackground'), ...
                    sprintf('%s preset should have DashboardBackground', presets{i}));
                testCase.verifyTrue(isfield(theme, 'StatusAlarmColor'), ...
                    sprintf('%s preset should have StatusAlarmColor', presets{i}));
            end
        end
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

```matlab
results = runtests('TestDashboardTheme');
```
Expected: FAIL — `DashboardTheme` not found

- [ ] **Step 3: Implement DashboardTheme**

Create `libs/Dashboard/DashboardTheme.m`:

```matlab
function theme = DashboardTheme(preset, varargin)
%DASHBOARDTHEME Returns a theme struct with FastPlotTheme + dashboard fields.
%
%   theme = DashboardTheme()              % default preset
%   theme = DashboardTheme('dark')        % named preset
%   theme = DashboardTheme('dark', 'DashboardBackground', [0.1 0.1 0.2])
%
%   Returns a struct containing all FastPlotTheme fields plus dashboard-specific
%   fields: DashboardBackground, WidgetBackground, WidgetBorderColor,
%   WidgetBorderWidth, DragHandleColor, DropZoneColor, ToolbarBackground,
%   ToolbarFontColor, HeaderFontSize, WidgetTitleFontSize, StatusOkColor,
%   StatusWarnColor, StatusAlarmColor, GaugeArcWidth, KpiFontSize.

    if nargin == 0
        preset = 'default';
    end

    % Get base FastPlotTheme
    base = FastPlotTheme(preset);

    % Append dashboard-specific fields
    dash = getDashboardDefaults(preset);
    fnames = fieldnames(dash);
    for i = 1:numel(fnames)
        base.(fnames{i}) = dash.(fnames{i});
    end

    theme = base;

    % Apply name-value overrides
    for k = 1:2:numel(varargin)
        theme.(varargin{k}) = varargin{k+1};
    end
end

function d = getDashboardDefaults(preset)
    switch preset
        case 'dark'
            d.DashboardBackground = [0.10 0.10 0.18];
            d.WidgetBackground    = [0.09 0.13 0.24];
            d.WidgetBorderColor   = [0.16 0.23 0.37];
            d.ToolbarBackground   = [0.09 0.13 0.24];
            d.ToolbarFontColor    = [0.66 0.73 0.78];
            d.DragHandleColor     = [0.31 0.80 0.64];
            d.DropZoneColor       = [0.16 0.23 0.37];
        case 'light'
            d.DashboardBackground = [0.96 0.96 0.97];
            d.WidgetBackground    = [1.00 1.00 1.00];
            d.WidgetBorderColor   = [0.85 0.85 0.87];
            d.ToolbarBackground   = [0.94 0.94 0.95];
            d.ToolbarFontColor    = [0.20 0.20 0.25];
            d.DragHandleColor     = [0.20 0.60 0.86];
            d.DropZoneColor       = [0.85 0.85 0.87];
        case 'industrial'
            d.DashboardBackground = [0.15 0.15 0.16];
            d.WidgetBackground    = [0.20 0.20 0.21];
            d.WidgetBorderColor   = [0.30 0.30 0.31];
            d.ToolbarBackground   = [0.20 0.20 0.21];
            d.ToolbarFontColor    = [0.78 0.78 0.78];
            d.DragHandleColor     = [0.90 0.60 0.10];
            d.DropZoneColor       = [0.30 0.30 0.31];
        case 'scientific'
            d.DashboardBackground = [0.98 0.98 0.96];
            d.WidgetBackground    = [1.00 1.00 1.00];
            d.WidgetBorderColor   = [0.80 0.80 0.78];
            d.ToolbarBackground   = [0.94 0.94 0.92];
            d.ToolbarFontColor    = [0.15 0.15 0.20];
            d.DragHandleColor     = [0.00 0.45 0.74];
            d.DropZoneColor       = [0.80 0.80 0.78];
        case 'ocean'
            d.DashboardBackground = [0.05 0.12 0.18];
            d.WidgetBackground    = [0.07 0.16 0.24];
            d.WidgetBorderColor   = [0.12 0.25 0.35];
            d.ToolbarBackground   = [0.07 0.16 0.24];
            d.ToolbarFontColor    = [0.60 0.78 0.85];
            d.DragHandleColor     = [0.00 0.75 0.85];
            d.DropZoneColor       = [0.12 0.25 0.35];
        otherwise % 'default'
            d.DashboardBackground = [0.94 0.94 0.94];
            d.WidgetBackground    = [1.00 1.00 1.00];
            d.WidgetBorderColor   = [0.80 0.80 0.80];
            d.ToolbarBackground   = [0.90 0.90 0.90];
            d.ToolbarFontColor    = [0.20 0.20 0.20];
            d.DragHandleColor     = [0.20 0.60 0.40];
            d.DropZoneColor       = [0.80 0.80 0.80];
    end

    % Shared defaults across all presets
    d.WidgetBorderWidth    = 1;
    d.HeaderFontSize       = 14;
    d.WidgetTitleFontSize  = 11;
    d.StatusOkColor        = [0.31 0.80 0.64];
    d.StatusWarnColor      = [0.91 0.63 0.27];
    d.StatusAlarmColor     = [0.91 0.27 0.38];
    d.GaugeArcWidth        = 8;
    d.KpiFontSize          = 28;
end
```

- [ ] **Step 4: Run tests to verify they pass**

```matlab
results = runtests('TestDashboardTheme');
```
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardTheme.m tests/suite/TestDashboardTheme.m
git commit -m "feat: add DashboardTheme function with 6 preset variants"
```

---

### Task 3: DashboardWidget — Abstract Base Class

**Files:**
- Create: `libs/Dashboard/DashboardWidget.m`
- Create: `tests/suite/TestDashboardWidget.m`

- [ ] **Step 1: Write the failing test**

Create `tests/suite/TestDashboardWidget.m`:

```matlab
classdef TestDashboardWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testIsAbstract(testCase)
            testCase.verifyError(@() DashboardWidget(), ...
                'MATLAB:class:abstract', ...
                'DashboardWidget should be abstract');
        end

        function testToStructFromStructRoundTrip(testCase)
            % Use a concrete mock subclass for testing
            w = MockDashboardWidget();
            w.Title = 'Test Widget';
            w.Position = [1 2 4 3];

            s = w.toStruct();
            testCase.verifyEqual(s.title, 'Test Widget');
            testCase.verifyEqual(s.position, struct('col', 1, 'row', 2, 'width', 4, 'height', 3));

            w2 = MockDashboardWidget.fromStruct(s);
            testCase.verifyEqual(w2.Title, 'Test Widget');
            testCase.verifyEqual(w2.Position, [1 2 4 3]);
        end

        function testDefaultPosition(testCase)
            w = MockDashboardWidget();
            testCase.verifyEqual(w.Position, [1 1 3 2], ...
                'Default position should be [1 1 3 2]');
        end

        function testTypeProperty(testCase)
            w = MockDashboardWidget();
            testCase.verifyEqual(w.Type, 'mock', ...
                'Type should return widget type string');
        end
    end
end
```

We also need a concrete mock subclass for testing. Create `tests/suite/MockDashboardWidget.m`:

```matlab
classdef MockDashboardWidget < DashboardWidget
    methods
        function obj = MockDashboardWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
        end

        function render(obj, parentPanel)
            % Mock render: just store the parent
            obj.hPanel = parentPanel;
        end

        function refresh(obj)
            % No-op for mock
        end

        function configure(obj)
            % No-op for mock
        end

        function t = getType(obj)
            t = 'mock';
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = MockDashboardWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
        end
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

```matlab
results = runtests('TestDashboardWidget');
```
Expected: FAIL — `DashboardWidget` not found

- [ ] **Step 3: Implement DashboardWidget**

Create `libs/Dashboard/DashboardWidget.m`:

```matlab
classdef (Abstract) DashboardWidget < handle
%DASHBOARDWIDGET Abstract base class for all dashboard widgets.
%
%   Subclasses must implement:
%     render(parentPanel) — create graphics objects inside the panel
%     refresh()           — update data/display (called by live timer)
%     configure()         — open properties UI for edit mode
%     getType()           — return widget type string (e.g. 'fastplot')
%
%   Subclasses must also provide a static fromStruct(s) method.

    properties (Access = public)
        Title    = ''           % Widget title displayed in header
        Position = [1 1 3 2]    % [col, row, width, height] in grid units
        ThemeOverride = struct() % Per-widget theme overrides (merged on top of dashboard theme)
    end

    properties (SetAccess = protected)
        hPanel = []             % Handle to the uipanel this widget renders into
    end

    properties (Dependent)
        Type                    % Widget type string (from getType)
    end

    methods
        function obj = DashboardWidget(varargin)
            % Parse name-value pairs
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function t = get.Type(obj)
            t = obj.getType();
        end

        function s = toStruct(obj)
            s.type = obj.Type;
            s.title = obj.Title;
            s.position = struct('col', obj.Position(1), ...
                                'row', obj.Position(2), ...
                                'width', obj.Position(3), ...
                                'height', obj.Position(4));
            if ~isempty(fieldnames(obj.ThemeOverride))
                s.themeOverride = obj.ThemeOverride;
            end
        end

        function delete(obj)
            if ~isempty(obj.hPanel) && isvalid(obj.hPanel)
                delete(obj.hPanel);
            end
        end
    end

    methods (Abstract)
        render(obj, parentPanel)
        refresh(obj)
        configure(obj)
        t = getType(obj)
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```matlab
results = runtests('TestDashboardWidget');
```
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardWidget.m tests/suite/TestDashboardWidget.m tests/suite/MockDashboardWidget.m
git commit -m "feat: add DashboardWidget abstract base class"
```

---

### Task 4: DashboardLayout — 12-Column Grid Positioning

**Files:**
- Create: `libs/Dashboard/DashboardLayout.m`
- Create: `tests/suite/TestDashboardLayout.m`

- [ ] **Step 1: Write the failing test**

Create `tests/suite/TestDashboardLayout.m`:

```matlab
classdef TestDashboardLayout < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            layout = DashboardLayout();
            testCase.verifyEqual(layout.Columns, 12);
            testCase.verifyTrue(isempty(layout.Widgets));
        end

        function testComputePosition(testCase)
            layout = DashboardLayout();
            layout.ContentArea = [0 0 1 1]; % full figure

            % Widget at col=1, row=1, width=6, height=1
            pos = layout.computePosition([1 1 6 1]);

            % Position should be in normalized [x y w h] format
            testCase.verifyLength(pos, 4);
            testCase.verifyGreaterThan(pos(1), 0); % x > 0 (left padding)
            testCase.verifyGreaterThan(pos(2), 0); % y > 0 (bottom padding)
            testCase.verifyGreaterThan(pos(3), 0); % w > 0
            testCase.verifyGreaterThan(pos(4), 0); % h > 0
        end

        function testFullWidthWidget(testCase)
            layout = DashboardLayout();
            layout.ContentArea = [0 0 1 1];

            pos12 = layout.computePosition([1 1 12 1]);
            pos6  = layout.computePosition([1 1 6 1]);

            % 12-col widget should be wider than 6-col
            testCase.verifyGreaterThan(pos12(3), pos6(3));
        end

        function testAdjacentWidgetsNoOverlap(testCase)
            layout = DashboardLayout();
            layout.ContentArea = [0 0 1 1];

            pos1 = layout.computePosition([1 1 6 1]);
            pos2 = layout.computePosition([7 1 6 1]);

            % Right edge of widget 1 should be <= left edge of widget 2
            rightEdge1 = pos1(1) + pos1(3);
            leftEdge2 = pos2(1);
            testCase.verifyLessThanOrEqual(rightEdge1, leftEdge2 + 0.001);
        end

        function testRowStacking(testCase)
            layout = DashboardLayout();
            layout.ContentArea = [0 0 1 1];
            layout.TotalRows = 3;

            pos_r1 = layout.computePosition([1 1 12 1]);
            pos_r2 = layout.computePosition([1 2 12 1]);

            % Row 1 should be above row 2 (MATLAB coords: higher y = higher on screen)
            testCase.verifyGreaterThan(pos_r1(2), pos_r2(2));
        end

        function testMaxRowCalculation(testCase)
            layout = DashboardLayout();
            widgets = {MockDashboardWidget(), MockDashboardWidget()};
            widgets{1}.Position = [1 1 6 2];
            widgets{2}.Position = [1 3 6 3];

            maxRow = layout.calculateMaxRow(widgets);
            % Widget 2 occupies rows 3-5, so max row = 5
            testCase.verifyEqual(maxRow, 5);
        end

        function testOverlapDetection(testCase)
            layout = DashboardLayout();

            % Two widgets that overlap
            testCase.verifyTrue(layout.overlaps([1 1 6 2], [3 1 6 2]));

            % Two widgets that don't overlap
            testCase.verifyFalse(layout.overlaps([1 1 6 2], [7 1 6 2]));

            % Adjacent vertically — no overlap
            testCase.verifyFalse(layout.overlaps([1 1 6 1], [1 2 6 1]));
        end

        function testResolveOverlap(testCase)
            layout = DashboardLayout();

            existing = {[1 1 6 2]};  % occupies cols 1-6, rows 1-2
            newPos = [3 1 6 2];      % overlaps at cols 3-6

            resolved = layout.resolveOverlap(newPos, existing);
            % Should be pushed down to row 3
            testCase.verifyEqual(resolved(2), 3);
        end
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

```matlab
results = runtests('TestDashboardLayout');
```
Expected: FAIL — `DashboardLayout` not found

- [ ] **Step 3: Implement DashboardLayout**

Create `libs/Dashboard/DashboardLayout.m`:

```matlab
classdef DashboardLayout < handle
%DASHBOARDLAYOUT Manages 12-column responsive grid positioning.
%
%   Converts widget grid positions [col, row, width, height] to normalized
%   figure coordinates [x, y, w, h]. Handles overlap resolution and
%   row calculation.
%
%   Usage:
%     layout = DashboardLayout();
%     layout.ContentArea = [0.0 0.05 1.0 0.95]; % leave space for toolbar
%     layout.TotalRows = 4;
%     pos = layout.computePosition([1 1 6 2]); % [x y w h] normalized

    properties (Access = public)
        Columns     = 12
        TotalRows   = 4            % auto-calculated from widgets, or set manually
        ContentArea = [0 0 1 1]    % [x y w h] normalized area for widgets
        Padding     = [0.02 0.02 0.02 0.02]  % [left bottom right top] normalized within ContentArea
        GapH        = 0.008        % horizontal gap between columns (normalized)
        GapV        = 0.015        % vertical gap between rows (normalized)
        Widgets     = {}           % cell array of DashboardWidget objects
    end

    methods (Access = public)
        function obj = DashboardLayout(varargin)
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function pos = computePosition(obj, gridPos)
            %COMPUTEPOSITION Convert [col row width height] to [x y w h] normalized.
            %
            %   gridPos: [col, row, widthCols, heightRows] — 1-based grid coordinates
            %   pos:     [x, y, w, h] — normalized figure coordinates (bottom-left origin)

            col = gridPos(1);
            row = gridPos(2);
            wCols = gridPos(3);
            hRows = gridPos(4);

            ca = obj.ContentArea; % [x y w h]
            padL = obj.Padding(1);
            padB = obj.Padding(2);
            padR = obj.Padding(3);
            padT = obj.Padding(4);

            % Available space after padding
            totalW = ca(3) - padL - padR;
            totalH = ca(4) - padB - padT;

            % Cell dimensions
            cellW = (totalW - (obj.Columns - 1) * obj.GapH) / obj.Columns;
            cellH = (totalH - (obj.TotalRows - 1) * obj.GapV) / obj.TotalRows;

            % Position (bottom-left origin, row 1 at top)
            x = ca(1) + padL + (col - 1) * (cellW + obj.GapH);
            y = ca(2) + padB + (obj.TotalRows - row - hRows + 1) * (cellH + obj.GapV);

            % Size (span cells + gaps)
            w = wCols * cellW + (wCols - 1) * obj.GapH;
            h = hRows * cellH + (hRows - 1) * obj.GapV;

            pos = [x, y, w, h];
        end

        function maxRow = calculateMaxRow(obj, widgets)
            %CALCULATEMAXROW Find the maximum row occupied by any widget.
            maxRow = 1;
            for i = 1:numel(widgets)
                p = widgets{i}.Position;
                bottomRow = p(2) + p(4) - 1;
                if bottomRow > maxRow
                    maxRow = bottomRow;
                end
            end
        end

        function tf = overlaps(obj, posA, posB)
            %OVERLAPS Check if two grid positions [col row w h] overlap.
            aLeft   = posA(1);
            aRight  = posA(1) + posA(3) - 1;
            aTop    = posA(2);
            aBottom = posA(2) + posA(4) - 1;

            bLeft   = posB(1);
            bRight  = posB(1) + posB(3) - 1;
            bTop    = posB(2);
            bBottom = posB(2) + posB(4) - 1;

            hOverlap = aLeft <= bRight && aRight >= bLeft;
            vOverlap = aTop <= bBottom && aBottom >= bTop;
            tf = hOverlap && vOverlap;
        end

        function newPos = resolveOverlap(obj, pos, existingPositions)
            %RESOLVEOVERLAP Push pos down until it doesn't overlap any existing.
            newPos = pos;
            changed = true;
            while changed
                changed = false;
                for i = 1:numel(existingPositions)
                    if obj.overlaps(newPos, existingPositions{i})
                        ep = existingPositions{i};
                        newPos(2) = ep(2) + ep(4); % push below
                        changed = true;
                    end
                end
            end
        end

        function createPanels(obj, hFigure, widgets, theme)
            %CREATEPANELS Create uipanel containers for all widgets.
            obj.Widgets = widgets;
            obj.TotalRows = obj.calculateMaxRow(widgets);

            for i = 1:numel(widgets)
                w = widgets{i};
                pos = obj.computePosition(w.Position);
                hp = uipanel('Parent', hFigure, ...
                    'Units', 'normalized', ...
                    'Position', pos, ...
                    'BorderType', 'line', ...
                    'BorderWidth', theme.WidgetBorderWidth, ...
                    'HighlightColor', theme.WidgetBorderColor, ...
                    'BackgroundColor', theme.WidgetBackground);
                w.render(hp);
            end
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```matlab
results = runtests('TestDashboardLayout');
```
Expected: All 8 tests PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardLayout.m tests/suite/TestDashboardLayout.m
git commit -m "feat: add DashboardLayout 12-column grid positioning"
```

---

## Chunk 2: FastPlotWidget and Serialization

### Task 5: FastPlotWidget — Wraps FastPlot + Sensor

**Files:**
- Create: `libs/Dashboard/FastPlotWidget.m`
- Create: `tests/suite/TestFastPlotWidget.m`

- [ ] **Step 1: Write the failing test**

Create `tests/suite/TestFastPlotWidget.m`:

```matlab
classdef TestFastPlotWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testTypeIsFastplot(testCase)
            w = FastPlotWidget();
            testCase.verifyEqual(w.Type, 'fastplot');
        end

        function testDefaultPosition(testCase)
            w = FastPlotWidget();
            testCase.verifyEqual(w.Position, [1 1 6 3], ...
                'Default FastPlotWidget size should be 6x3');
        end

        function testSensorBinding(testCase)
            % Create a simple Sensor
            s = Sensor('T-401', 'Name', 'Temperature');
            s.X = 1:100;
            s.Y = rand(1,100);

            w = FastPlotWidget('Sensor', s);
            testCase.verifyEqual(w.SensorObj, s);
            testCase.verifyEqual(w.Title, 'Temperature', ...
                'Title should default to Sensor.Name');
        end

        function testDataStoreBinding(testCase)
            x = 1:1000;
            y = rand(1,1000);
            ds = FastPlotDataStore(x, y);
            testCase.addTeardown(@() ds.cleanup());
            w = FastPlotWidget('DataStore', ds);
            testCase.verifyEqual(w.DataStoreObj, ds);
        end

        function testRenderCreatesAxes(testCase)
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));

            hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            w = FastPlotWidget();
            % Add data inline for rendering
            w.XData = 1:100;
            w.YData = rand(1,100);
            w.render(hp);

            testCase.verifyNotEmpty(w.FastPlotObj, ...
                'Should create a FastPlot instance');
            testCase.verifyTrue(isa(w.FastPlotObj, 'FastPlot'));
        end

        function testRenderWithSensor(testCase)
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));

            hp = uipanel('Parent', hFig, 'Units', 'normalized', ...
                'Position', [0 0 1 1]);

            s = Sensor('T-401', 'Name', 'Temperature');
            s.X = 1:100;
            s.Y = rand(1,100);
            s.addThresholdRule(struct(), 80, 'Direction', 'upper', 'Label', 'Hi Alarm');
            s.resolve();

            w = FastPlotWidget('Sensor', s);
            w.render(hp);

            testCase.verifyNotEmpty(w.FastPlotObj);
            % FastPlot should have the sensor's line and thresholds
            testCase.verifyGreaterThanOrEqual(numel(w.FastPlotObj.Lines), 1);
        end

        function testToStructRoundTrip(testCase)
            w = FastPlotWidget('Title', 'My Plot', 'Position', [3 2 8 3]);
            w.XData = 1:10;
            w.YData = rand(1,10);

            s = w.toStruct();
            testCase.verifyEqual(s.type, 'fastplot');
            testCase.verifyEqual(s.title, 'My Plot');
            testCase.verifyEqual(s.position.col, 3);
        end

        function testToStructWithSensor(testCase)
            sensor = Sensor('P-201', 'Name', 'Pressure');
            sensor.X = 1:100;
            sensor.Y = rand(1,100);
            w = FastPlotWidget('Sensor', sensor);

            s = w.toStruct();
            testCase.verifyEqual(s.source.type, 'sensor');
            testCase.verifyEqual(s.source.name, 'P-201');
        end

        function testFromStructWithData(testCase)
            s = struct();
            s.type = 'fastplot';
            s.title = 'Restored Plot';
            s.position = struct('col', 1, 'row', 1, 'width', 6, 'height', 3);
            s.source = struct('type', 'data', 'x', 1:10, 'y', rand(1,10));

            w = FastPlotWidget.fromStruct(s);
            testCase.verifyEqual(w.Title, 'Restored Plot');
            testCase.verifyEqual(w.Position, [1 1 6 3]);
            testCase.verifyLength(w.XData, 10);
        end
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

```matlab
results = runtests('TestFastPlotWidget');
```
Expected: FAIL — `FastPlotWidget` not found

- [ ] **Step 3: Implement FastPlotWidget**

Create `libs/Dashboard/FastPlotWidget.m`:

```matlab
classdef FastPlotWidget < DashboardWidget
%FASTPLOTWIDGET Dashboard widget wrapping a FastPlot instance.
%
%   Supports three data binding modes:
%     Sensor:    w = FastPlotWidget('Sensor', sensorObj)
%     DataStore: w = FastPlotWidget('DataStore', dsObj)
%     Inline:    w = FastPlotWidget('XData', x, 'YData', y)
%     File:      w = FastPlotWidget('File', 'path.mat', 'XVar', 'x', 'YVar', 'y')
%
%   When bound to a Sensor, ThresholdRules apply automatically.

    properties (Access = public)
        SensorObj    = []       % Sensor object (optional)
        DataStoreObj = []       % FastPlotDataStore object (optional)
        XData        = []       % Inline X data (optional)
        YData        = []       % Inline Y data (optional)
        File         = ''       % .mat file path (optional)
        XVar         = ''       % Variable name for X in .mat file
        YVar         = ''       % Variable name for Y in .mat file
        Thresholds   = 'auto'   % 'auto' (from Sensor) or manual config
    end

    properties (SetAccess = private)
        FastPlotObj = []        % The FastPlot instance
    end

    methods
        function obj = FastPlotWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 6 3]; % default size for FastPlot

            % Parse name-value pairs
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end

            % Default title from Sensor name
            if ~isempty(obj.SensorObj) && isempty(obj.Title)
                if ~isempty(obj.SensorObj.Name)
                    obj.Title = obj.SensorObj.Name;
                else
                    obj.Title = obj.SensorObj.Key;
                end
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;

            % Create axes inside the panel
            ax = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.08 0.12 0.88 0.78]);

            % Create FastPlot on this axes
            fp = FastPlot('Parent', ax);
            obj.FastPlotObj = fp;

            % Bind data
            if ~isempty(obj.SensorObj)
                fp.addSensor(obj.SensorObj);
            elseif ~isempty(obj.DataStoreObj)
                fp.addLine([], [], 'DataStore', obj.DataStoreObj);
            elseif ~isempty(obj.File)
                data = load(obj.File);
                x = data.(obj.XVar);
                y = data.(obj.YVar);
                fp.addLine(x, y);
            elseif ~isempty(obj.XData) && ~isempty(obj.YData)
                fp.addLine(obj.XData, obj.YData);
            end

            % Set title
            if ~isempty(obj.Title)
                title(ax, obj.Title, 'Color', get(ax, 'XColor'));
            end

            fp.render();
        end

        function refresh(obj)
            if ~isempty(obj.FastPlotObj)
                obj.FastPlotObj.refresh();
            end
        end

        function configure(obj)
            % Placeholder for edit mode properties panel (Phase 4)
        end

        function t = getType(~)
            t = 'fastplot';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);

            if ~isempty(obj.SensorObj)
                s.source = struct('type', 'sensor', 'name', obj.SensorObj.Key);
                s.thresholds = obj.Thresholds;
            elseif ~isempty(obj.File)
                s.source = struct('type', 'file', 'path', obj.File, ...
                                  'xVar', obj.XVar, 'yVar', obj.YVar);
            elseif ~isempty(obj.XData)
                s.source = struct('type', 'data', 'x', obj.XData, 'y', obj.YData);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = FastPlotWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];

            if isfield(s, 'source')
                switch s.source.type
                    case 'sensor'
                        % Sensor must be resolved at runtime via SensorRegistry
                        if exist('SensorRegistry', 'class')
                            obj.SensorObj = SensorRegistry.get(s.source.name);
                        end
                    case 'file'
                        obj.File = s.source.path;
                        obj.XVar = s.source.xVar;
                        obj.YVar = s.source.yVar;
                    case 'data'
                        obj.XData = s.source.x;
                        obj.YData = s.source.y;
                end
            end

            if isfield(s, 'thresholds')
                obj.Thresholds = s.thresholds;
            end
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```matlab
results = runtests('TestFastPlotWidget');
```
Expected: All 9 tests PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/FastPlotWidget.m tests/suite/TestFastPlotWidget.m
git commit -m "feat: add FastPlotWidget with Sensor/DataStore/file binding"
```

---

### Task 6: DashboardSerializer — JSON Load/Save

**Files:**
- Create: `libs/Dashboard/DashboardSerializer.m`
- Create: `tests/suite/TestDashboardSerializer.m`

- [ ] **Step 1: Write the failing test**

Create `tests/suite/TestDashboardSerializer.m`:

```matlab
classdef TestDashboardSerializer < matlab.unittest.TestCase
    properties
        TempDir
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.addTeardown(@() rmdir(testCase.TempDir, 's'));
        end
    end

    methods (Test)
        function testSaveAndLoadRoundTrip(testCase)
            config = struct();
            config.name = 'Test Dashboard';
            config.theme = 'dark';
            config.liveInterval = 5;
            config.grid = struct('columns', 12);
            config.widgets = {};
            config.widgets{1} = struct('type', 'fastplot', ...
                'title', 'Temperature', ...
                'position', struct('col', 1, 'row', 1, 'width', 6, 'height', 3), ...
                'source', struct('type', 'data', 'x', 1:10, 'y', rand(1,10)));

            filepath = fullfile(testCase.TempDir, 'test_dashboard.json');
            DashboardSerializer.save(config, filepath);

            testCase.verifyTrue(exist(filepath, 'file') == 2, ...
                'JSON file should exist');

            loaded = DashboardSerializer.load(filepath);
            testCase.verifyEqual(loaded.name, 'Test Dashboard');
            testCase.verifyEqual(loaded.theme, 'dark');
            testCase.verifyEqual(loaded.liveInterval, 5);
            testCase.verifyEqual(numel(loaded.widgets), 1);
        end

        function testWidgetsToConfig(testCase)
            w1 = FastPlotWidget('Title', 'Plot 1', 'Position', [1 1 6 3]);
            w1.XData = 1:10;
            w1.YData = rand(1,10);
            w2 = FastPlotWidget('Title', 'Plot 2', 'Position', [7 1 6 3]);
            w2.XData = 1:10;
            w2.YData = rand(1,10);

            config = DashboardSerializer.widgetsToConfig('My Dashboard', 'dark', 5, {w1, w2});
            testCase.verifyEqual(config.name, 'My Dashboard');
            testCase.verifyEqual(numel(config.widgets), 2);
            testCase.verifyEqual(config.widgets{1}.title, 'Plot 1');
            testCase.verifyEqual(config.widgets{2}.title, 'Plot 2');
        end

        function testConfigToWidgets(testCase)
            config = struct();
            config.name = 'Test';
            config.theme = 'default';
            config.liveInterval = 1;
            config.grid = struct('columns', 12);

            ws = struct();
            ws.type = 'fastplot';
            ws.title = 'Temp';
            ws.position = struct('col', 1, 'row', 1, 'width', 6, 'height', 3);
            ws.source = struct('type', 'data', 'x', 1:5, 'y', [1 2 3 4 5]);
            config.widgets = {ws};

            widgets = DashboardSerializer.configToWidgets(config);
            testCase.verifyEqual(numel(widgets), 1);
            testCase.verifyTrue(isa(widgets{1}, 'FastPlotWidget'));
            testCase.verifyEqual(widgets{1}.Title, 'Temp');
        end

        function testExportScript(testCase)
            config = struct();
            config.name = 'Export Test';
            config.theme = 'dark';
            config.liveInterval = 5;
            config.grid = struct('columns', 12);

            ws = struct();
            ws.type = 'fastplot';
            ws.title = 'Temperature';
            ws.position = struct('col', 1, 'row', 1, 'width', 6, 'height', 3);
            ws.source = struct('type', 'data', 'x', 1:10, 'y', rand(1,10));
            config.widgets = {ws};

            filepath = fullfile(testCase.TempDir, 'test_export.m');
            DashboardSerializer.exportScript(config, filepath);

            testCase.verifyTrue(exist(filepath, 'file') == 2);
            content = fileread(filepath);
            testCase.verifyTrue(contains(content, 'DashboardEngine'));
            testCase.verifyTrue(contains(content, 'addWidget'));
            testCase.verifyTrue(contains(content, 'Temperature'));
        end
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

```matlab
results = runtests('TestDashboardSerializer');
```
Expected: FAIL — `DashboardSerializer` not found

- [ ] **Step 3: Implement DashboardSerializer**

Create `libs/Dashboard/DashboardSerializer.m`:

```matlab
classdef DashboardSerializer
%DASHBOARDSERIALIZER JSON load/save and .m export for dashboard configs.
%
%   DashboardSerializer.save(config, filepath)   — save struct to JSON
%   config = DashboardSerializer.load(filepath)   — load struct from JSON
%   DashboardSerializer.exportScript(config, filepath) — generate .m script
%
%   config = DashboardSerializer.widgetsToConfig(name, theme, interval, widgets)
%   widgets = DashboardSerializer.configToWidgets(config)

    methods (Static)
        function save(config, filepath)
            %SAVE Write dashboard config struct to JSON file.
            %  Widgets may have heterogeneous fields, so encode each
            %  widget individually and assemble the JSON array by hand.
            parts = cell(1, numel(config.widgets));
            for i = 1:numel(config.widgets)
                parts{i} = jsonencode(config.widgets{i});
            end
            widgetsJson = ['[', strjoin(parts, ','), ']'];

            % Build top-level JSON without the widgets field
            topLevel = rmfield(config, 'widgets');
            topJson = jsonencode(topLevel);
            % Insert widgets array before the closing brace
            topJson = [topJson(1:end-1), ',"widgets":', widgetsJson, '}'];

            fid = fopen(filepath, 'w');
            if fid == -1
                error('DashboardSerializer:fileError', 'Cannot open file: %s', filepath);
            end
            fwrite(fid, topJson);
            fclose(fid);
        end

        function config = load(filepath)
            %LOAD Read dashboard config from JSON file.
            if ~exist(filepath, 'file')
                error('DashboardSerializer:fileNotFound', 'File not found: %s', filepath);
            end

            fid = fopen(filepath, 'r');
            jsonStr = fread(fid, '*char')';
            fclose(fid);

            config = jsondecode(jsonStr);

            % Ensure widgets is a cell array
            if isstruct(config.widgets)
                wa = config.widgets;
                config.widgets = cell(1, numel(wa));
                for i = 1:numel(wa)
                    config.widgets{i} = wa(i);
                end
            end
        end

        function config = widgetsToConfig(name, theme, liveInterval, widgets)
            %WIDGETSTOCONFIG Build a config struct from widget objects.
            config.name = name;
            config.theme = theme;
            config.liveInterval = liveInterval;
            config.grid = struct('columns', 12);
            config.widgets = cell(1, numel(widgets));
            for i = 1:numel(widgets)
                config.widgets{i} = widgets{i}.toStruct();
            end
        end

        function widgets = configToWidgets(config)
            %CONFIGTOWIDGETS Create widget objects from config struct.
            widgets = cell(1, numel(config.widgets));
            for i = 1:numel(config.widgets)
                ws = config.widgets{i};
                switch ws.type
                    case 'fastplot'
                        widgets{i} = FastPlotWidget.fromStruct(ws);
                    otherwise
                        error('DashboardSerializer:unknownType', ...
                            'Unknown widget type: %s', ws.type);
                end
            end
        end

        function exportScript(config, filepath)
            %EXPORTSCRIPT Generate a readable .m script from config.
            lines = {};
            lines{end+1} = sprintf('%% Dashboard: %s', config.name);
            lines{end+1} = sprintf('%% Auto-generated by DashboardSerializer.exportScript');
            lines{end+1} = sprintf('%% %s', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
            lines{end+1} = '';
            lines{end+1} = sprintf('d = DashboardEngine(''%s'');', config.name);
            lines{end+1} = sprintf('d.Theme = ''%s'';', config.theme);
            lines{end+1} = sprintf('d.LiveInterval = %g;', config.liveInterval);
            lines{end+1} = '';

            for i = 1:numel(config.widgets)
                ws = config.widgets{i};
                pos = sprintf('[%d %d %d %d]', ws.position.col, ws.position.row, ...
                    ws.position.width, ws.position.height);

                switch ws.type
                    case 'fastplot'
                        if isfield(ws, 'source')
                            switch ws.source.type
                                case 'sensor'
                                    lines{end+1} = sprintf('d.addWidget(''fastplot'', ''Title'', ''%s'', ...', ws.title);
                                    lines{end+1} = sprintf('    ''Position'', %s, ...', pos);
                                    lines{end+1} = sprintf('    ''Sensor'', SensorRegistry.get(''%s''));', ws.source.name);
                                case 'file'
                                    lines{end+1} = sprintf('d.addWidget(''fastplot'', ''Title'', ''%s'', ...', ws.title);
                                    lines{end+1} = sprintf('    ''Position'', %s, ...', pos);
                                    lines{end+1} = sprintf('    ''File'', ''%s'', ''XVar'', ''%s'', ''YVar'', ''%s'');', ...
                                        ws.source.path, ws.source.xVar, ws.source.yVar);
                                case 'data'
                                    lines{end+1} = sprintf('d.addWidget(''fastplot'', ''Title'', ''%s'', ...', ws.title);
                                    lines{end+1} = sprintf('    ''Position'', %s, ...', pos);
                                    lines{end+1} = sprintf('    ''XData'', %s, ''YData'', %s);', ...
                                        mat2str(ws.source.x), mat2str(ws.source.y));
                                otherwise
                                    lines{end+1} = sprintf('d.addWidget(''fastplot'', ''Title'', ''%s'', ''Position'', %s);', ws.title, pos);
                            end
                        else
                            lines{end+1} = sprintf('d.addWidget(''fastplot'', ''Title'', ''%s'', ''Position'', %s);', ws.title, pos);
                        end
                    otherwise
                        lines{end+1} = sprintf('d.addWidget(''%s'', ''Title'', ''%s'', ''Position'', %s);', ws.type, ws.title, pos);
                end
                lines{end+1} = '';
            end

            lines{end+1} = 'd.render();';

            fid = fopen(filepath, 'w');
            if fid == -1
                error('DashboardSerializer:fileError', 'Cannot open file: %s', filepath);
            end
            fprintf(fid, '%s\n', lines{:});
            fclose(fid);
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```matlab
results = runtests('TestDashboardSerializer');
```
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardSerializer.m tests/suite/TestDashboardSerializer.m
git commit -m "feat: add DashboardSerializer for JSON load/save and .m export"
```

---

## Chunk 3: DashboardEngine Orchestrator

### Task 7: DashboardToolbar — Global Controls

**Files:**
- Create: `libs/Dashboard/DashboardToolbar.m`

- [ ] **Step 1: Implement DashboardToolbar**

This is a simple UI component; test it through DashboardEngine integration tests rather than in isolation (toolbar requires a live figure context).

Create `libs/Dashboard/DashboardToolbar.m`:

```matlab
classdef DashboardToolbar < handle
%DASHBOARDTOOLBAR Global toolbar for dashboard controls.
%
%   Provides buttons for: Live mode toggle, Edit mode, Save, Export.
%   Sits at the top of the dashboard figure.

    properties (Access = public)
        Height = 0.04   % Normalized height of toolbar
    end

    properties (SetAccess = private)
        hPanel       = []
        hLiveBtn     = []
        hEditBtn     = []
        hSaveBtn     = []
        hExportBtn   = []
        hTitleText   = []
        Engine       = []   % Reference back to DashboardEngine
    end

    methods
        function obj = DashboardToolbar(engine, hFigure, theme)
            obj.Engine = engine;

            obj.hPanel = uipanel('Parent', hFigure, ...
                'Units', 'normalized', ...
                'Position', [0, 1 - obj.Height, 1, obj.Height], ...
                'BorderType', 'none', ...
                'BackgroundColor', theme.ToolbarBackground);

            % Dashboard title
            obj.hTitleText = uicontrol('Parent', obj.hPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.01 0.1 0.3 0.8], ...
                'String', engine.Name, ...
                'FontSize', theme.HeaderFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left');

            btnW = 0.06;
            btnH = 0.7;
            btnY = 0.15;
            rightEdge = 0.99;

            % Export button
            rightEdge = rightEdge - btnW - 0.005;
            obj.hExportBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Export', ...
                'Callback', @(~,~) obj.onExport());

            % Save button
            rightEdge = rightEdge - btnW - 0.005;
            obj.hSaveBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Save', ...
                'Callback', @(~,~) obj.onSave());

            % Edit button
            rightEdge = rightEdge - btnW - 0.005;
            obj.hEditBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Edit', ...
                'Callback', @(~,~) obj.onEdit());

            % Live button
            rightEdge = rightEdge - btnW - 0.005;
            obj.hLiveBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'togglebutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Live', ...
                'Value', 0, ...
                'Callback', @(src,~) obj.onLiveToggle(src));
        end

        function onLiveToggle(obj, src)
            if get(src, 'Value')
                obj.Engine.startLive();
            else
                obj.Engine.stopLive();
            end
        end

        function onSave(obj)
            [file, path] = uiputfile('*.json', 'Save Dashboard');
            if file ~= 0
                obj.Engine.save(fullfile(path, file));
            end
        end

        function onExport(obj)
            [file, path] = uiputfile('*.m', 'Export as Script');
            if file ~= 0
                obj.Engine.exportScript(fullfile(path, file));
            end
        end

        function onEdit(obj)
            % Placeholder for Phase 4: GUI builder
            disp('Edit mode not yet implemented (Phase 4)');
        end

        function contentArea = getContentArea(obj)
            %GETCONTENTAREA Returns [x y w h] for the area below the toolbar.
            contentArea = [0, 0, 1, 1 - obj.Height];
        end
    end
end
```

- [ ] **Step 2: Commit**

```bash
git add libs/Dashboard/DashboardToolbar.m
git commit -m "feat: add DashboardToolbar with live/save/export buttons"
```

---

### Task 8: DashboardEngine — Top-Level Orchestrator

**Files:**
- Create: `libs/Dashboard/DashboardEngine.m`
- Create: `tests/suite/TestDashboardEngine.m`

- [ ] **Step 1: Write the failing test**

Create `tests/suite/TestDashboardEngine.m`:

```matlab
classdef TestDashboardEngine < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            d = DashboardEngine('Test Dashboard');
            testCase.verifyEqual(d.Name, 'Test Dashboard');
            testCase.verifyEqual(d.Theme, 'default');
            testCase.verifyEqual(d.LiveInterval, 5);
        end

        function testSetTheme(testCase)
            d = DashboardEngine('Test');
            d.Theme = 'dark';
            testCase.verifyEqual(d.Theme, 'dark');
        end

        function testAddWidget(testCase)
            d = DashboardEngine('Test');
            d.addWidget('fastplot', 'Title', 'Plot 1', ...
                'Position', [1 1 6 3], ...
                'XData', 1:10, 'YData', rand(1,10));
            testCase.verifyEqual(numel(d.Widgets), 1);
            testCase.verifyTrue(isa(d.Widgets{1}, 'FastPlotWidget'));
        end

        function testAddMultipleWidgets(testCase)
            d = DashboardEngine('Test');
            d.addWidget('fastplot', 'Title', 'Plot 1', ...
                'Position', [1 1 6 3], 'XData', 1:10, 'YData', rand(1,10));
            d.addWidget('fastplot', 'Title', 'Plot 2', ...
                'Position', [7 1 6 3], 'XData', 1:10, 'YData', rand(1,10));
            testCase.verifyEqual(numel(d.Widgets), 2);
        end

        function testOverlapResolution(testCase)
            d = DashboardEngine('Test');
            d.addWidget('fastplot', 'Title', 'Plot 1', ...
                'Position', [1 1 6 3], 'XData', 1:10, 'YData', rand(1,10));
            % This overlaps with Plot 1 (cols 3-8 overlap with cols 1-6)
            d.addWidget('fastplot', 'Title', 'Plot 2', ...
                'Position', [3 1 6 3], 'XData', 1:10, 'YData', rand(1,10));
            % Plot 2 should have been pushed to row 4
            testCase.verifyEqual(d.Widgets{2}.Position(2), 4);
        end

        function testRender(testCase)
            d = DashboardEngine('Render Test');
            d.addWidget('fastplot', 'Title', 'Plot 1', ...
                'Position', [1 1 12 3], 'XData', 1:100, 'YData', rand(1,100));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            testCase.verifyNotEmpty(d.hFigure);
            testCase.verifyTrue(ishandle(d.hFigure));
        end

        function testSaveAndLoad(testCase)
            d = DashboardEngine('Save Test');
            d.Theme = 'dark';
            d.LiveInterval = 3;
            d.addWidget('fastplot', 'Title', 'Temp', ...
                'Position', [1 1 6 3], 'XData', 1:10, 'YData', [1:10]);

            filepath = fullfile(tempdir, 'test_save_dashboard.json');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(d2.Name, 'Save Test');
            testCase.verifyEqual(d2.Theme, 'dark');
            testCase.verifyEqual(d2.LiveInterval, 3);
            testCase.verifyEqual(numel(d2.Widgets), 1);
            testCase.verifyEqual(d2.Widgets{1}.Title, 'Temp');
        end

        function testExportScript(testCase)
            d = DashboardEngine('Export Test');
            d.addWidget('fastplot', 'Title', 'Pressure', ...
                'Position', [1 1 6 3], 'XData', 1:5, 'YData', [5 4 3 2 1]);

            filepath = fullfile(tempdir, 'test_export_dashboard.m');
            testCase.addTeardown(@() delete(filepath));
            d.exportScript(filepath);

            content = fileread(filepath);
            testCase.verifyTrue(contains(content, 'DashboardEngine'));
            testCase.verifyTrue(contains(content, 'Pressure'));
        end

        function testLiveStartStop(testCase)
            d = DashboardEngine('Live Test');
            d.LiveInterval = 1;
            d.addWidget('fastplot', 'Title', 'Plot', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', rand(1,10));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            d.startLive();
            testCase.verifyTrue(d.IsLive);
            testCase.verifyNotEmpty(d.LiveTimer);

            d.stopLive();
            testCase.verifyFalse(d.IsLive);
        end

        function testAddWidgetWithSensor(testCase)
            s = Sensor('T-401', 'Name', 'Temperature');
            s.X = 1:100;
            s.Y = rand(1,100);
            s.addThresholdRule(struct(), 80, 'Direction', 'upper', 'Label', 'Hi');
            s.resolve();

            d = DashboardEngine('Sensor Test');
            d.addWidget('fastplot', 'Sensor', s, 'Position', [1 1 8 3]);
            testCase.verifyEqual(d.Widgets{1}.Title, 'Temperature');
            testCase.verifyEqual(d.Widgets{1}.SensorObj, s);
        end

        function testCloseDeletesTimer(testCase)
            d = DashboardEngine('Timer Cleanup');
            d.LiveInterval = 1;
            d.addWidget('fastplot', 'Title', 'P', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', rand(1,10));
            d.render();
            d.startLive();

            % Close the figure — should clean up the timer
            close(d.hFigure);
            testCase.verifyFalse(d.IsLive);
        end
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

```matlab
results = runtests('TestDashboardEngine');
```
Expected: FAIL — `DashboardEngine` not found

- [ ] **Step 3: Implement DashboardEngine**

Create `libs/Dashboard/DashboardEngine.m`:

```matlab
classdef DashboardEngine < handle
%DASHBOARDENGINE Top-level dashboard orchestrator.
%
%   Usage:
%     d = DashboardEngine('My Dashboard');
%     d.Theme = 'dark';
%     d.LiveInterval = 5;
%     d.addWidget('fastplot', 'Title', 'Temp', 'Position', [1 1 6 3], ...
%                 'Sensor', SensorRegistry.get('T-401'));
%     d.render();
%
%   Loading from JSON:
%     d = DashboardEngine.load('path/to/dashboard.json');
%     d.render();

    properties (Access = public)
        Name         = ''          % Dashboard display name
        Theme        = 'default'   % Theme preset name or struct
        LiveInterval = 5           % Live refresh interval in seconds
    end

    properties (SetAccess = private)
        Widgets    = {}            % Cell array of DashboardWidget objects
        hFigure    = []            % Figure handle
        Layout     = []            % DashboardLayout instance
        Toolbar    = []            % DashboardToolbar instance
        LiveTimer  = []            % Timer object for live mode
        IsLive     = false         % Whether live mode is active
        FilePath   = ''            % Last save/load path
    end

    methods (Access = public)
        function obj = DashboardEngine(name, varargin)
            if nargin >= 1
                obj.Name = name;
            end
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
            obj.Layout = DashboardLayout();
        end

        function addWidget(obj, type, varargin)
            %ADDWIDGET Add a widget to the dashboard.
            %
            %   d.addWidget('fastplot', 'Title', 'Temp', 'Position', [1 1 6 3], ...)

            switch type
                case 'fastplot'
                    w = FastPlotWidget(varargin{:});
                otherwise
                    error('DashboardEngine:unknownType', ...
                        'Unknown widget type: %s (Phase 2+ types not yet implemented)', type);
            end

            % Resolve overlaps
            existingPositions = cell(1, numel(obj.Widgets));
            for i = 1:numel(obj.Widgets)
                existingPositions{i} = obj.Widgets{i}.Position;
            end
            w.Position = obj.Layout.resolveOverlap(w.Position, existingPositions);

            obj.Widgets{end+1} = w;
        end

        function render(obj)
            %RENDER Create the dashboard figure and render all widgets.
            themeStruct = DashboardTheme(obj.Theme);

            % Create figure
            obj.hFigure = figure('Name', obj.Name, ...
                'NumberTitle', 'off', ...
                'Color', themeStruct.DashboardBackground, ...
                'Units', 'normalized', ...
                'OuterPosition', [0.05 0.05 0.9 0.9], ...
                'CloseRequestFcn', @(~,~) obj.onClose());

            % Create toolbar
            obj.Toolbar = DashboardToolbar(obj, obj.hFigure, themeStruct);

            % Set layout content area (below toolbar)
            obj.Layout.ContentArea = obj.Toolbar.getContentArea();

            % Create panels and render widgets
            obj.Layout.createPanels(obj.hFigure, obj.Widgets, themeStruct);
        end

        function startLive(obj)
            %STARTLIVE Start the global live refresh timer.
            if obj.IsLive
                return;
            end
            obj.IsLive = true;
            obj.LiveTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', obj.LiveInterval, ...
                'TimerFcn', @(~,~) obj.onLiveTick());
            start(obj.LiveTimer);
        end

        function stopLive(obj)
            %STOPLIVE Stop the global live refresh timer.
            if ~isempty(obj.LiveTimer)
                stop(obj.LiveTimer);
                delete(obj.LiveTimer);
                obj.LiveTimer = [];
            end
            obj.IsLive = false;
        end

        function save(obj, filepath)
            %SAVE Save dashboard configuration to JSON file.
            config = DashboardSerializer.widgetsToConfig( ...
                obj.Name, obj.Theme, obj.LiveInterval, obj.Widgets);
            DashboardSerializer.save(config, filepath);
            obj.FilePath = filepath;
        end

        function exportScript(obj, filepath)
            %EXPORTSCRIPT Export dashboard as a .m script.
            config = DashboardSerializer.widgetsToConfig( ...
                obj.Name, obj.Theme, obj.LiveInterval, obj.Widgets);
            DashboardSerializer.exportScript(config, filepath);
        end

        function delete(obj)
            obj.stopLive();
        end
    end

    methods (Access = private)
        function onClose(obj)
            obj.stopLive();
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                delete(obj.hFigure);
            end
        end

        function onLiveTick(obj)
            for i = 1:numel(obj.Widgets)
                try
                    obj.Widgets{i}.refresh();
                catch ME
                    warning('DashboardEngine:refreshError', ...
                        'Widget "%s" refresh failed: %s', ...
                        obj.Widgets{i}.Title, ME.message);
                end
            end
        end
    end

    methods (Static)
        function obj = load(filepath)
            %LOAD Create a DashboardEngine from a JSON file.
            config = DashboardSerializer.load(filepath);
            obj = DashboardEngine(config.name);
            obj.Theme = config.theme;
            obj.LiveInterval = config.liveInterval;
            obj.FilePath = filepath;

            widgets = DashboardSerializer.configToWidgets(config);
            for i = 1:numel(widgets)
                obj.Widgets{end+1} = widgets{i};
            end
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```matlab
results = runtests('TestDashboardEngine');
```
Expected: All 11 tests PASS

- [ ] **Step 5: Run the full dashboard test suite**

```matlab
results = runtests('TestDashboardTheme', 'TestDashboardWidget', 'TestDashboardLayout', ...
    'TestFastPlotWidget', 'TestDashboardSerializer', 'TestDashboardEngine');
```
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add libs/Dashboard/DashboardEngine.m tests/suite/TestDashboardEngine.m
git commit -m "feat: add DashboardEngine orchestrator with live mode and serialization"
```

---

### Task 9: Integration Smoke Test Example

**Files:**
- Create: `examples/example_dashboard.m` (update existing if it exists)

- [ ] **Step 1: Check if example_dashboard.m exists and read it**

Check `examples/example_dashboard.m`. If it exists, read it to understand the current content. The new example should demonstrate the Phase 1 API with inline data.

- [ ] **Step 2: Create/update the example**

Create `examples/example_dashboard_engine.m`:

```matlab
%% Dashboard Engine Example — Phase 1 Core API
% Demonstrates: DashboardEngine with FastPlotWidgets, Sensor binding,
% JSON save/load, and live mode.

setup();

%% 1. Create dashboard with inline data
d = DashboardEngine('Process Monitoring — Line 4');
d.Theme = 'dark';
d.LiveInterval = 5;

% Generate sample data
t = linspace(0, 86400, 10000); % 24 hours in seconds
temp = 70 + 5*sin(2*pi*t/3600) + randn(1,10000)*0.5;
pressure = 50 + 20*sin(2*pi*t/7200) + randn(1,10000)*1.0;

% Add FastPlot widgets
d.addWidget('fastplot', 'Title', 'Temperature', ...
    'Position', [1 1 8 3], ...
    'XData', t, 'YData', temp);

d.addWidget('fastplot', 'Title', 'Pressure', ...
    'Position', [9 1 4 3], ...
    'XData', t, 'YData', pressure);

d.addWidget('fastplot', 'Title', 'Temp vs Pressure Overlay', ...
    'Position', [1 4 12 3], ...
    'XData', t, 'YData', temp);

d.render();

%% 2. Save to JSON
d.save(fullfile(tempdir, 'example_dashboard.json'));
fprintf('Dashboard saved to: %s\n', fullfile(tempdir, 'example_dashboard.json'));

%% 3. Demonstrate Sensor binding (if SensorRegistry available)
% s = Sensor('T-401', 'Name', 'Temperature Sensor');
% s.X = t;
% s.Y = temp;
% s.addThresholdRule(struct(), 78, 'Direction', 'upper', 'Label', 'Hi Warn');
% s.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'Hi Alarm');
% s.resolve();
%
% d2 = DashboardEngine('Sensor Dashboard');
% d2.Theme = 'industrial';
% d2.addWidget('fastplot', 'Sensor', s, 'Position', [1 1 12 4]);
% d2.render();
```

- [ ] **Step 3: Run the example to verify it works**

```matlab
example_dashboard_engine;
```
Expected: Dashboard window opens with 3 FastPlot widgets in a dark theme, arranged on a 12-column grid.

- [ ] **Step 4: Commit**

```bash
git add examples/example_dashboard_engine.m
git commit -m "feat: add dashboard engine example with inline data and JSON save"
```

---

### Task 10: Final Validation

- [ ] **Step 1: Run the full test suite**

```matlab
results = run_all_tests();
```
Expected: All existing tests PASS + all new dashboard tests PASS. No regressions.

- [ ] **Step 2: Verify JSON round-trip end-to-end**

```matlab
% Create, save, load, render
d1 = DashboardEngine('Round Trip');
d1.Theme = 'dark';
d1.addWidget('fastplot', 'Title', 'Test', 'Position', [1 1 12 3], ...
    'XData', 1:100, 'YData', rand(1,100));
d1.save(fullfile(tempdir, 'roundtrip.json'));

d2 = DashboardEngine.load(fullfile(tempdir, 'roundtrip.json'));
d2.render();
% Verify: should open a dashboard identical to d1
close(d2.hFigure);
```

- [ ] **Step 3: Commit final state**

```bash
git add libs/Dashboard/ tests/suite/TestDashboard*.m tests/suite/TestFastPlotWidget.m tests/suite/MockDashboardWidget.m examples/example_dashboard_engine.m setup.m
git commit -m "feat: complete Dashboard Engine Phase 1 — core API with tests and example"
```
