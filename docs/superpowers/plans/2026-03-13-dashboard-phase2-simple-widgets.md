# Dashboard Engine Phase 2: Simple Widgets

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add KpiWidget, StatusWidget, TextWidget, and GaugeWidget to the Dashboard Engine, then register them in Engine and Serializer.

**Architecture:** Each widget extends `DashboardWidget` (abstract base in `libs/Dashboard/DashboardWidget.m`) and implements `render(parentPanel)`, `refresh()`, `configure()`, `getType()`, `toStruct()`, and static `fromStruct(s)`. Simple widgets use R2020b-compatible `uicontrol` and `patch`/`line` graphics — no `uifigure` or App Designer. Data binding uses `ValueFcn`/`StatusFcn` callbacks called on `refresh()`.

**Tech Stack:** MATLAB R2020b, figure-based UI (`uicontrol`, `uipanel`, `axes`, `patch`, `line`, `text`)

---

## Existing Code Context

### DashboardWidget Base Class (`libs/Dashboard/DashboardWidget.m`)
```matlab
classdef DashboardWidget < handle  % ABSTRACT
    properties (Access = public)
        Title       = ''
        Position    = [1 1 3 2]  % [col, row, width, height] grid units
        ThemeOverride = []
    end
    properties (SetAccess = protected)
        hPanel = []              % uipanel handle after rendering
    end
    % Abstract methods to implement:
    %   render(parentPanel)   — create graphics inside panel
    %   refresh()             — update display (called by live timer)
    %   configure()           — open properties UI (Phase 4)
    %   t = getType()         — return type string
    % Concrete:
    %   s = toStruct()        — returns struct with type, title, position
    %   fromStruct(s)         — STATIC, must override in subclass
```

### DashboardEngine.addWidget (`libs/Dashboard/DashboardEngine.m:43-59`)
Currently only handles `'fastplot'` in the switch statement. Each new widget type needs a case added.

### DashboardSerializer.configToWidgets (`libs/Dashboard/DashboardSerializer.m`)
Currently only handles `'fastplot'` in its switch. Each new widget type needs a case for deserialization.

### DashboardSerializer.exportScript (`libs/Dashboard/DashboardSerializer.m`)
Generates `.m` script code per widget. Each new widget type needs export logic.

### DashboardTheme fields used by simple widgets
```matlab
theme.StatusOkColor     % [R G B] green
theme.StatusWarnColor   % [R G B] yellow/orange
theme.StatusAlarmColor  % [R G B] red
theme.KpiFontSize       % 28
theme.GaugeArcWidth     % 8
theme.WidgetTitleFontSize % 11
theme.WidgetBackground  % [R G B]
theme.ForegroundColor   % [R G B] text color (from FastPlotTheme)
theme.FontName          % 'Helvetica' etc (from FastPlotTheme)
```

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `libs/Dashboard/KpiWidget.m` | Create | Big number + label + optional trend arrow |
| `libs/Dashboard/StatusWidget.m` | Create | Colored circle indicator + label |
| `libs/Dashboard/TextWidget.m` | Create | Static text label / section header |
| `libs/Dashboard/GaugeWidget.m` | Create | Circular arc gauge with range |
| `libs/Dashboard/DashboardEngine.m` | Modify | Add cases for 4 new widget types in `addWidget()` |
| `libs/Dashboard/DashboardSerializer.m` | Modify | Add cases in `configToWidgets()` and `exportScript()` |
| `tests/suite/TestKpiWidget.m` | Create | Tests for KpiWidget |
| `tests/suite/TestStatusWidget.m` | Create | Tests for StatusWidget |
| `tests/suite/TestTextWidget.m` | Create | Tests for TextWidget |
| `tests/suite/TestGaugeWidget.m` | Create | Tests for GaugeWidget |
| `examples/example_dashboard_widgets.m` | Create | Demo with all widget types |

---

## Chunk 1: Simple Widgets

### Task 1: KpiWidget

**Files:**
- Create: `libs/Dashboard/KpiWidget.m`
- Test: `tests/suite/TestKpiWidget.m`

KpiWidget displays a big number with a label and optional trend arrow. Data comes from a `ValueFcn` callback that returns a scalar or struct `{value, unit, trend}`.

- [ ] **Step 1: Write failing tests**

Create `tests/suite/TestKpiWidget.m`:

```matlab
classdef TestKpiWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = KpiWidget('Title', 'Current Temp', ...
                'ValueFcn', @() 72.5);
            testCase.verifyEqual(w.Title, 'Current Temp');
            testCase.verifyTrue(isa(w.ValueFcn, 'function_handle'));
        end

        function testDefaultPosition(testCase)
            w = KpiWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 3 1]);
        end

        function testGetType(testCase)
            w = KpiWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'kpi');
        end

        function testToStruct(testCase)
            w = KpiWidget('Title', 'Pressure', ...
                'ValueFcn', @() 50, ...
                'Units', 'bar', ...
                'Position', [4 1 3 1]);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'kpi');
            testCase.verifyEqual(s.title, 'Pressure');
            testCase.verifyEqual(s.units, 'bar');
            testCase.verifyTrue(isfield(s, 'source'));
            testCase.verifyEqual(s.source.type, 'callback');
        end

        function testFromStruct(testCase)
            s = struct();
            s.type = 'kpi';
            s.title = 'RPM';
            s.position = struct('col', 1, 'row', 1, 'width', 3, 'height', 1);
            s.units = 'rpm';
            s.source = struct('type', 'static', 'value', 1500);
            w = KpiWidget.fromStruct(s);
            testCase.verifyEqual(w.Title, 'RPM');
            testCase.verifyEqual(w.Units, 'rpm');
            testCase.verifyEqual(w.Position, [1 1 3 1]);
        end

        function testRenderCreatesGraphics(testCase)
            w = KpiWidget('Title', 'Temp', 'ValueFcn', @() 72.5, 'Units', '°C');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            % Should have created text objects inside the panel
            children = allchild(hp);
            testCase.verifyGreaterThanOrEqual(numel(children), 1);
        end

        function testRefreshUpdatesValue(testCase)
            counter = struct('val', 0);
            w = KpiWidget('Title', 'Counter', ...
                'ValueFcn', @() counter.val);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            counter.val = 42;
            w.refresh();
            % Verify the value text was updated
            testCase.verifyEqual(w.CurrentValue, 42);
        end

        function testStructValueBinding(testCase)
            w = KpiWidget('Title', 'Temp', ...
                'ValueFcn', @() struct('value', 72.5, 'unit', 'F', 'trend', 'up'));
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 72.5);
        end
    end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run via MATLAB:
```matlab
cd('/Users/hannessuhr/FastPlot'); setup();
results = runtests('tests/suite/TestKpiWidget.m');
```
Expected: All fail — `KpiWidget` class does not exist.

- [ ] **Step 3: Implement KpiWidget**

Create `libs/Dashboard/KpiWidget.m`:

```matlab
classdef KpiWidget < DashboardWidget
%KPIWIDGET Dashboard widget showing a big number with label and trend.
%
%   w = KpiWidget('Title', 'Temp', 'ValueFcn', @() readTemp(), 'Units', '°C');
%
%   ValueFcn returns either:
%     - A scalar (displayed as-is)
%     - A struct with fields: value, unit, trend ('up'/'down'/'flat')

    properties (Access = public)
        ValueFcn     = []       % function_handle returning scalar or struct
        Units        = ''       % unit label string
        Format       = '%.1f'   % sprintf format for value
        StaticValue  = []       % fixed value (no callback needed)
    end

    properties (SetAccess = private)
        CurrentValue = []
        CurrentTrend = ''
        hValueText   = []
        hUnitText    = []
        hTrendText   = []
        hTitleText   = []
    end

    methods
        function obj = KpiWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 3 1]; % default KPI size
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            bgColor = theme.WidgetBackground;
            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;
            kpiFontSize = theme.KpiFontSize;
            titleFontSize = theme.WidgetTitleFontSize;

            % Title at top
            obj.hTitleText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', obj.Title, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.75 0.9 0.2], ...
                'FontName', fontName, ...
                'FontSize', titleFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor * 0.7 + bgColor * 0.3, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'center');

            % Big value number in center
            obj.hValueText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '--', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.25 0.7 0.5], ...
                'FontName', fontName, ...
                'FontSize', kpiFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'center');

            % Trend arrow (right of value)
            obj.hTrendText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '', ...
                'Units', 'normalized', ...
                'Position', [0.75 0.25 0.2 0.5], ...
                'FontName', fontName, ...
                'FontSize', round(kpiFontSize * 0.6), ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'center');

            % Units label at bottom
            obj.hUnitText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', obj.Units, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.05 0.9 0.2], ...
                'FontName', fontName, ...
                'FontSize', titleFontSize, ...
                'ForegroundColor', fgColor * 0.5 + bgColor * 0.5, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'center');

            obj.refresh();
        end

        function refresh(obj)
            if ~isempty(obj.ValueFcn)
                result = obj.ValueFcn();
            elseif ~isempty(obj.StaticValue)
                result = obj.StaticValue;
            else
                return;
            end

            if isstruct(result)
                obj.CurrentValue = result.value;
                if isfield(result, 'unit')
                    obj.Units = result.unit;
                end
                if isfield(result, 'trend')
                    obj.CurrentTrend = result.trend;
                end
            else
                obj.CurrentValue = result;
            end

            % Update display
            if ~isempty(obj.hValueText) && ishandle(obj.hValueText)
                set(obj.hValueText, 'String', sprintf(obj.Format, obj.CurrentValue));
            end

            if ~isempty(obj.hUnitText) && ishandle(obj.hUnitText)
                set(obj.hUnitText, 'String', obj.Units);
            end

            if ~isempty(obj.hTrendText) && ishandle(obj.hTrendText)
                switch obj.CurrentTrend
                    case 'up'
                        set(obj.hTrendText, 'String', char(9650));  % ▲
                    case 'down'
                        set(obj.hTrendText, 'String', char(9660));  % ▼
                    case 'flat'
                        set(obj.hTrendText, 'String', char(9654));  % ▶
                    otherwise
                        set(obj.hTrendText, 'String', '');
                end
            end
        end

        function configure(obj)
            % Placeholder for Phase 4 edit mode
        end

        function t = getType(~)
            t = 'kpi';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.units = obj.Units;
            s.format = obj.Format;
            if ~isempty(obj.ValueFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.ValueFcn));
            elseif ~isempty(obj.StaticValue)
                s.source = struct('type', 'static', 'value', obj.StaticValue);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = KpiWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'units')
                obj.Units = s.units;
            end
            if isfield(s, 'format')
                obj.Format = s.format;
            end
            if isfield(s, 'source')
                switch s.source.type
                    case 'callback'
                        obj.ValueFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticValue = s.source.value;
                end
            end
        end
    end

    methods (Access = private)
        function theme = getTheme(obj)
            if ~isempty(obj.ThemeOverride)
                theme = obj.ThemeOverride;
            else
                theme = DashboardTheme();
            end
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```matlab
results = runtests('tests/suite/TestKpiWidget.m');
```
Expected: All pass.

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/KpiWidget.m tests/suite/TestKpiWidget.m
git commit -m "feat: add KpiWidget with big number, trend arrow, and callback binding"
```

---

### Task 2: StatusWidget

**Files:**
- Create: `libs/Dashboard/StatusWidget.m`
- Test: `tests/suite/TestStatusWidget.m`

StatusWidget shows a colored circle (OK=green, Warning=yellow, Alarm=red) with a label. Data from `StatusFcn` callback returning `'ok'`, `'warning'`, or `'alarm'`.

- [ ] **Step 1: Write failing tests**

Create `tests/suite/TestStatusWidget.m`:

```matlab
classdef TestStatusWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = StatusWidget('Title', 'Pump 1', ...
                'StatusFcn', @() 'ok');
            testCase.verifyEqual(w.Title, 'Pump 1');
        end

        function testDefaultPosition(testCase)
            w = StatusWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 2 1]);
        end

        function testGetType(testCase)
            w = StatusWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'status');
        end

        function testToStruct(testCase)
            w = StatusWidget('Title', 'Valve', ...
                'StatusFcn', @() 'ok', ...
                'Position', [1 1 2 1]);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'status');
            testCase.verifyEqual(s.title, 'Valve');
        end

        function testFromStruct(testCase)
            s = struct();
            s.type = 'status';
            s.title = 'Pump';
            s.position = struct('col', 1, 'row', 1, 'width', 2, 'height', 1);
            s.source = struct('type', 'static', 'value', 'ok');
            w = StatusWidget.fromStruct(s);
            testCase.verifyEqual(w.Title, 'Pump');
        end

        function testRenderCreatesGraphics(testCase)
            w = StatusWidget('Title', 'Motor', 'StatusFcn', @() 'ok');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentStatus, 'ok');
        end

        function testRefreshUpdatesStatus(testCase)
            status = struct('val', 'ok');
            w = StatusWidget('Title', 'Motor', ...
                'StatusFcn', @() status.val);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            status.val = 'alarm';
            w.refresh();
            testCase.verifyEqual(w.CurrentStatus, 'alarm');
        end
    end
end
```

- [ ] **Step 2: Run tests — expected FAIL**

- [ ] **Step 3: Implement StatusWidget**

Create `libs/Dashboard/StatusWidget.m`:

```matlab
classdef StatusWidget < DashboardWidget
%STATUSWIDGET Colored circle indicator with label.
%
%   w = StatusWidget('Title', 'Pump 1', 'StatusFcn', @() getPumpStatus());
%
%   StatusFcn returns 'ok', 'warning', or 'alarm'.

    properties (Access = public)
        StatusFcn    = []       % function_handle returning 'ok'/'warning'/'alarm'
        StaticStatus = ''       % fixed status (no callback)
    end

    properties (SetAccess = private)
        CurrentStatus = ''
        hAxes        = []
        hCircle      = []
        hLabelText   = []
        hStatusText  = []
    end

    methods
        function obj = StatusWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 2 1]; % default compact size
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            bgColor = theme.WidgetBackground;
            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;

            % Create axes for the circle
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.1 0.3 0.35 0.6], ...
                'Visible', 'off', ...
                'XLim', [-1.2 1.2], 'YLim', [-1.2 1.2], ...
                'DataAspectRatio', [1 1 1]);
            hold(obj.hAxes, 'on');

            % Draw circle
            theta = linspace(0, 2*pi, 60);
            obj.hCircle = fill(obj.hAxes, cos(theta), sin(theta), ...
                [0.5 0.5 0.5], 'EdgeColor', 'none');

            % Title/label text
            obj.hLabelText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', obj.Title, ...
                'Units', 'normalized', ...
                'Position', [0.45 0.5 0.5 0.35], ...
                'FontName', fontName, ...
                'FontSize', theme.WidgetTitleFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'left');

            % Status text below label
            obj.hStatusText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '--', ...
                'Units', 'normalized', ...
                'Position', [0.45 0.15 0.5 0.3], ...
                'FontName', fontName, ...
                'FontSize', theme.WidgetTitleFontSize - 1, ...
                'ForegroundColor', fgColor * 0.6 + bgColor * 0.4, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'left');

            obj.refresh();
        end

        function refresh(obj)
            if ~isempty(obj.StatusFcn)
                obj.CurrentStatus = obj.StatusFcn();
            elseif ~isempty(obj.StaticStatus)
                obj.CurrentStatus = obj.StaticStatus;
            else
                return;
            end

            theme = obj.getTheme();
            switch obj.CurrentStatus
                case 'ok'
                    color = theme.StatusOkColor;
                    label = 'OK';
                case 'warning'
                    color = theme.StatusWarnColor;
                    label = 'WARNING';
                case 'alarm'
                    color = theme.StatusAlarmColor;
                    label = 'ALARM';
                otherwise
                    color = [0.5 0.5 0.5];
                    label = upper(obj.CurrentStatus);
            end

            if ~isempty(obj.hCircle) && ishandle(obj.hCircle)
                set(obj.hCircle, 'FaceColor', color);
            end
            if ~isempty(obj.hStatusText) && ishandle(obj.hStatusText)
                set(obj.hStatusText, 'String', label, 'ForegroundColor', color);
            end
        end

        function configure(obj)
        end

        function t = getType(~)
            t = 'status';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.StatusFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.StatusFcn));
            elseif ~isempty(obj.StaticStatus)
                s.source = struct('type', 'static', 'value', obj.StaticStatus);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = StatusWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'source')
                switch s.source.type
                    case 'callback'
                        obj.StatusFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticStatus = s.source.value;
                end
            end
        end
    end

    methods (Access = private)
        function theme = getTheme(obj)
            if ~isempty(obj.ThemeOverride)
                theme = obj.ThemeOverride;
            else
                theme = DashboardTheme();
            end
        end
    end
end
```

- [ ] **Step 4: Run tests — expected PASS**

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/StatusWidget.m tests/suite/TestStatusWidget.m
git commit -m "feat: add StatusWidget with colored circle indicator and callback binding"
```

---

### Task 3: TextWidget

**Files:**
- Create: `libs/Dashboard/TextWidget.m`
- Test: `tests/suite/TestTextWidget.m`

TextWidget displays static text — section headers, labels, descriptions. No live refresh needed.

- [ ] **Step 1: Write failing tests**

Create `tests/suite/TestTextWidget.m`:

```matlab
classdef TestTextWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = TextWidget('Title', 'Section A', 'Content', 'Overview of sensors');
            testCase.verifyEqual(w.Title, 'Section A');
            testCase.verifyEqual(w.Content, 'Overview of sensors');
        end

        function testDefaultPosition(testCase)
            w = TextWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 3 1]);
        end

        function testGetType(testCase)
            w = TextWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'text');
        end

        function testToStructFromStruct(testCase)
            w = TextWidget('Title', 'Header', 'Content', 'Body text', ...
                'Position', [1 1 6 1], 'FontSize', 16);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'text');
            testCase.verifyEqual(s.content, 'Body text');
            testCase.verifyEqual(s.fontSize, 16);

            w2 = TextWidget.fromStruct(s);
            testCase.verifyEqual(w2.Title, 'Header');
            testCase.verifyEqual(w2.Content, 'Body text');
            testCase.verifyEqual(w2.FontSize, 16);
        end

        function testRender(testCase)
            w = TextWidget('Title', 'Header', 'Content', 'Some text');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            children = allchild(hp);
            testCase.verifyGreaterThanOrEqual(numel(children), 1);
        end
    end
end
```

- [ ] **Step 2: Run tests — expected FAIL**

- [ ] **Step 3: Implement TextWidget**

Create `libs/Dashboard/TextWidget.m`:

```matlab
classdef TextWidget < DashboardWidget
%TEXTWIDGET Static text label or section header.
%
%   w = TextWidget('Title', 'Section A', 'Content', 'Sensor overview');

    properties (Access = public)
        Content   = ''       % body text
        FontSize  = 0        % 0 = use theme default
        Alignment = 'left'   % 'left', 'center', 'right'
    end

    properties (SetAccess = private)
        hTitleText   = []
        hContentText = []
    end

    methods
        function obj = TextWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 3 1];
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            bgColor = theme.WidgetBackground;
            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;
            fontSize = obj.FontSize;
            if fontSize == 0
                fontSize = theme.WidgetTitleFontSize;
            end

            hasTitle = ~isempty(obj.Title);
            hasContent = ~isempty(obj.Content);

            if hasTitle && hasContent
                obj.hTitleText = uicontrol('Parent', parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Title, ...
                    'Units', 'normalized', ...
                    'Position', [0.05 0.55 0.9 0.4], ...
                    'FontName', fontName, ...
                    'FontSize', fontSize + 2, ...
                    'FontWeight', 'bold', ...
                    'ForegroundColor', fgColor, ...
                    'BackgroundColor', bgColor, ...
                    'HorizontalAlignment', obj.Alignment);

                obj.hContentText = uicontrol('Parent', parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Content, ...
                    'Units', 'normalized', ...
                    'Position', [0.05 0.05 0.9 0.45], ...
                    'FontName', fontName, ...
                    'FontSize', fontSize, ...
                    'ForegroundColor', fgColor * 0.7 + bgColor * 0.3, ...
                    'BackgroundColor', bgColor, ...
                    'HorizontalAlignment', obj.Alignment);
            elseif hasTitle
                obj.hTitleText = uicontrol('Parent', parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Title, ...
                    'Units', 'normalized', ...
                    'Position', [0.05 0.1 0.9 0.8], ...
                    'FontName', fontName, ...
                    'FontSize', fontSize + 2, ...
                    'FontWeight', 'bold', ...
                    'ForegroundColor', fgColor, ...
                    'BackgroundColor', bgColor, ...
                    'HorizontalAlignment', obj.Alignment);
            elseif hasContent
                obj.hContentText = uicontrol('Parent', parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Content, ...
                    'Units', 'normalized', ...
                    'Position', [0.05 0.1 0.9 0.8], ...
                    'FontName', fontName, ...
                    'FontSize', fontSize, ...
                    'ForegroundColor', fgColor, ...
                    'BackgroundColor', bgColor, ...
                    'HorizontalAlignment', obj.Alignment);
            end
        end

        function refresh(~)
            % Static widget — nothing to refresh
        end

        function configure(obj)
        end

        function t = getType(~)
            t = 'text';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.content = obj.Content;
            s.fontSize = obj.FontSize;
            s.alignment = obj.Alignment;
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = TextWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'content')
                obj.Content = s.content;
            end
            if isfield(s, 'fontSize')
                obj.FontSize = s.fontSize;
            end
            if isfield(s, 'alignment')
                obj.Alignment = s.alignment;
            end
        end
    end

    methods (Access = private)
        function theme = getTheme(obj)
            if ~isempty(obj.ThemeOverride)
                theme = obj.ThemeOverride;
            else
                theme = DashboardTheme();
            end
        end
    end
end
```

- [ ] **Step 4: Run tests — expected PASS**

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/TextWidget.m tests/suite/TestTextWidget.m
git commit -m "feat: add TextWidget for static labels and section headers"
```

---

### Task 4: GaugeWidget

**Files:**
- Create: `libs/Dashboard/GaugeWidget.m`
- Test: `tests/suite/TestGaugeWidget.m`

GaugeWidget draws a circular arc gauge using `patch`/`line` on an axes. Data from `ValueFcn` callback.

- [ ] **Step 1: Write failing tests**

Create `tests/suite/TestGaugeWidget.m`:

```matlab
classdef TestGaugeWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = GaugeWidget('Title', 'Pressure', ...
                'ValueFcn', @() 50, 'Range', [0 100], 'Units', 'bar');
            testCase.verifyEqual(w.Title, 'Pressure');
            testCase.verifyEqual(w.Range, [0 100]);
            testCase.verifyEqual(w.Units, 'bar');
        end

        function testDefaultPosition(testCase)
            w = GaugeWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 4 2]);
        end

        function testGetType(testCase)
            w = GaugeWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'gauge');
        end

        function testToStructFromStruct(testCase)
            w = GaugeWidget('Title', 'RPM', ...
                'ValueFcn', @() 3000, 'Range', [0 6000], 'Units', 'rpm');
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'gauge');
            testCase.verifyEqual(s.range, [0 6000]);
            testCase.verifyEqual(s.units, 'rpm');

            w2 = GaugeWidget.fromStruct(s);
            testCase.verifyEqual(w2.Range, [0 6000]);
            testCase.verifyEqual(w2.Units, 'rpm');
        end

        function testRender(testCase)
            w = GaugeWidget('Title', 'Temp', ...
                'ValueFcn', @() 72, 'Range', [0 100], 'Units', '°C');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 72);
        end

        function testRefreshUpdatesValue(testCase)
            counter = struct('val', 25);
            w = GaugeWidget('Title', 'Gauge', ...
                'ValueFcn', @() counter.val, 'Range', [0 100]);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            counter.val = 75;
            w.refresh();
            testCase.verifyEqual(w.CurrentValue, 75);
        end

        function testClampToRange(testCase)
            w = GaugeWidget('Title', 'Gauge', ...
                'ValueFcn', @() 150, 'Range', [0 100]);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            % Value exceeds range — needle should clamp
            testCase.verifyEqual(w.CurrentValue, 150);
        end
    end
end
```

- [ ] **Step 2: Run tests — expected FAIL**

- [ ] **Step 3: Implement GaugeWidget**

Create `libs/Dashboard/GaugeWidget.m`:

```matlab
classdef GaugeWidget < DashboardWidget
%GAUGEWIDGET Circular arc gauge with range.
%
%   w = GaugeWidget('Title', 'Pressure', 'ValueFcn', @() getPressure(), ...
%                   'Range', [0 100], 'Units', 'bar');

    properties (Access = public)
        ValueFcn    = []
        Range       = [0 100]
        Units       = ''
        StaticValue = []
    end

    properties (SetAccess = private)
        CurrentValue = []
        hAxes       = []
        hArcBg      = []
        hArcFg      = []
        hNeedle     = []
        hValueText  = []
        hTitleText  = []
        hMinText    = []
        hMaxText    = []
    end

    methods
        function obj = GaugeWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 4 2]; % default gauge size
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            bgColor = theme.WidgetBackground;
            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;
            arcWidth = theme.GaugeArcWidth;

            % Axes for gauge arc
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.1 0.15 0.8 0.7], ...
                'Visible', 'off', ...
                'XLim', [-1.4 1.4], 'YLim', [-0.5 1.5], ...
                'DataAspectRatio', [1 1 1]);
            hold(obj.hAxes, 'on');

            % Draw background arc (gray, 240 degrees from -210 to 30)
            startAngle = deg2rad(210);
            endAngle = deg2rad(-30);
            nPts = 80;
            angles = linspace(startAngle, endAngle, nPts);
            rOuter = 1.0;
            rInner = 1.0 - arcWidth * 0.02;

            xOuter = rOuter * cos(angles);
            yOuter = rOuter * sin(angles);
            xInner = rInner * cos(fliplr(angles));
            yInner = rInner * sin(fliplr(angles));

            obj.hArcBg = fill(obj.hAxes, ...
                [xOuter, xInner], [yOuter, yInner], ...
                fgColor * 0.15 + bgColor * 0.85, 'EdgeColor', 'none');

            % Foreground arc (colored, will be updated by refresh)
            obj.hArcFg = fill(obj.hAxes, [0 0], [0 0], ...
                theme.StatusOkColor, 'EdgeColor', 'none');

            % Needle line
            obj.hNeedle = line(obj.hAxes, [0 0], [0 0.9], ...
                'Color', fgColor, 'LineWidth', 2);

            % Value text
            obj.hValueText = text(obj.hAxes, 0, -0.15, '--', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', theme.KpiFontSize * 0.7, ...
                'FontWeight', 'bold', ...
                'FontName', fontName, ...
                'Color', fgColor);

            % Title
            obj.hTitleText = text(obj.hAxes, 0, 1.35, obj.Title, ...
                'HorizontalAlignment', 'center', ...
                'FontSize', theme.WidgetTitleFontSize, ...
                'FontWeight', 'bold', ...
                'FontName', fontName, ...
                'Color', fgColor);

            % Min/max labels
            xMin = rOuter * cos(startAngle);
            yMin = rOuter * sin(startAngle);
            obj.hMinText = text(obj.hAxes, xMin - 0.15, yMin - 0.1, ...
                sprintf('%.0f', obj.Range(1)), ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 8, 'FontName', fontName, 'Color', fgColor * 0.6 + bgColor * 0.4);

            xMax = rOuter * cos(endAngle);
            yMax = rOuter * sin(endAngle);
            obj.hMaxText = text(obj.hAxes, xMax + 0.15, yMax - 0.1, ...
                sprintf('%.0f', obj.Range(2)), ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 8, 'FontName', fontName, 'Color', fgColor * 0.6 + bgColor * 0.4);

            obj.refresh();
        end

        function refresh(obj)
            if ~isempty(obj.ValueFcn)
                obj.CurrentValue = obj.ValueFcn();
            elseif ~isempty(obj.StaticValue)
                obj.CurrentValue = obj.StaticValue;
            else
                return;
            end

            theme = obj.getTheme();
            val = obj.CurrentValue;
            rng = obj.Range;
            frac = (val - rng(1)) / (rng(2) - rng(1));
            frac = max(0, min(1, frac));  % clamp 0–1

            % Update value text
            if ~isempty(obj.hValueText) && ishandle(obj.hValueText)
                if isempty(obj.Units)
                    set(obj.hValueText, 'String', sprintf('%.1f', val));
                else
                    set(obj.hValueText, 'String', sprintf('%.1f %s', val, obj.Units));
                end
            end

            % Update foreground arc
            startAngle = deg2rad(210);
            endAngle = deg2rad(-30);
            totalSweep = endAngle - startAngle; % negative (clockwise)
            currentEnd = startAngle + frac * totalSweep;

            nPts = max(3, round(80 * frac));
            angles = linspace(startAngle, currentEnd, nPts);
            arcWidth = theme.GaugeArcWidth;
            rOuter = 1.0;
            rInner = 1.0 - arcWidth * 0.02;

            xOuter = rOuter * cos(angles);
            yOuter = rOuter * sin(angles);
            xInner = rInner * cos(fliplr(angles));
            yInner = rInner * sin(fliplr(angles));

            if ~isempty(obj.hArcFg) && ishandle(obj.hArcFg)
                % Choose color based on fraction
                if frac < 0.6
                    arcColor = theme.StatusOkColor;
                elseif frac < 0.85
                    arcColor = theme.StatusWarnColor;
                else
                    arcColor = theme.StatusAlarmColor;
                end
                set(obj.hArcFg, ...
                    'XData', [xOuter, xInner], ...
                    'YData', [yOuter, yInner], ...
                    'FaceColor', arcColor);
            end

            % Update needle
            needleAngle = startAngle + frac * totalSweep;
            if ~isempty(obj.hNeedle) && ishandle(obj.hNeedle)
                set(obj.hNeedle, ...
                    'XData', [0, 0.85 * cos(needleAngle)], ...
                    'YData', [0, 0.85 * sin(needleAngle)]);
            end
        end

        function configure(obj)
        end

        function t = getType(~)
            t = 'gauge';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.range = obj.Range;
            s.units = obj.Units;
            if ~isempty(obj.ValueFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.ValueFcn));
            elseif ~isempty(obj.StaticValue)
                s.source = struct('type', 'static', 'value', obj.StaticValue);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = GaugeWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'range')
                obj.Range = s.range;
            end
            if isfield(s, 'units')
                obj.Units = s.units;
            end
            if isfield(s, 'source')
                switch s.source.type
                    case 'callback'
                        obj.ValueFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticValue = s.source.value;
                end
            end
        end
    end

    methods (Access = private)
        function theme = getTheme(obj)
            if ~isempty(obj.ThemeOverride)
                theme = obj.ThemeOverride;
            else
                theme = DashboardTheme();
            end
        end
    end
end
```

- [ ] **Step 4: Run tests — expected PASS**

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/GaugeWidget.m tests/suite/TestGaugeWidget.m
git commit -m "feat: add GaugeWidget with circular arc, needle, and color zones"
```

---

### Task 5: Register Phase 2 Widgets in Engine and Serializer

**Files:**
- Modify: `libs/Dashboard/DashboardEngine.m:43-50` — add cases to `addWidget()`
- Modify: `libs/Dashboard/DashboardSerializer.m` — add cases to `configToWidgets()` and `exportScript()`

- [ ] **Step 1: Write integration test**

Add to the bottom of `tests/suite/TestDashboardEngine.m`, a new test method:

```matlab
function testAddPhase2Widgets(testCase)
    d = DashboardEngine('Phase 2 Test');

    d.addWidget('kpi', 'Title', 'Current Temp', ...
        'ValueFcn', @() 72.5, 'Units', '°C', 'Position', [1 1 3 1]);
    testCase.verifyTrue(isa(d.Widgets{1}, 'KpiWidget'));

    d.addWidget('status', 'Title', 'Pump 1', ...
        'StatusFcn', @() 'ok', 'Position', [4 1 2 1]);
    testCase.verifyTrue(isa(d.Widgets{2}, 'StatusWidget'));

    d.addWidget('text', 'Title', 'Header', ...
        'Content', 'Overview', 'Position', [6 1 3 1]);
    testCase.verifyTrue(isa(d.Widgets{3}, 'TextWidget'));

    d.addWidget('gauge', 'Title', 'Pressure', ...
        'ValueFcn', @() 50, 'Range', [0 100], 'Position', [9 1 4 2]);
    testCase.verifyTrue(isa(d.Widgets{4}, 'GaugeWidget'));
end
```

- [ ] **Step 2: Run test — expected FAIL** (unknown type error)

- [ ] **Step 3: Update DashboardEngine.addWidget()**

In `libs/Dashboard/DashboardEngine.m`, replace the `switch type` block (lines 44-50):

```matlab
switch type
    case 'fastplot'
        w = FastPlotWidget(varargin{:});
    case 'kpi'
        w = KpiWidget(varargin{:});
    case 'status'
        w = StatusWidget(varargin{:});
    case 'text'
        w = TextWidget(varargin{:});
    case 'gauge'
        w = GaugeWidget(varargin{:});
    otherwise
        error('DashboardEngine:unknownType', ...
            'Unknown widget type: %s', type);
end
```

- [ ] **Step 4: Update DashboardSerializer.configToWidgets()**

In `libs/Dashboard/DashboardSerializer.m`, in the `configToWidgets` method, update the switch block:

```matlab
switch ws.type
    case 'fastplot'
        widgets{i} = FastPlotWidget.fromStruct(ws);
    case 'kpi'
        widgets{i} = KpiWidget.fromStruct(ws);
    case 'status'
        widgets{i} = StatusWidget.fromStruct(ws);
    case 'text'
        widgets{i} = TextWidget.fromStruct(ws);
    case 'gauge'
        widgets{i} = GaugeWidget.fromStruct(ws);
    otherwise
        warning('DashboardSerializer:unknownType', ...
            'Unknown widget type: %s — skipping', ws.type);
end
```

- [ ] **Step 5: Update DashboardSerializer.exportScript()**

Add export cases for new widget types. For callback-based widgets, emit `'ValueFcn', @functionName` or warn if anonymous. For static values, emit the value directly. Add after the existing fastplot case in exportScript:

```matlab
case 'kpi'
    fprintf(fid, "d.addWidget('kpi', 'Title', '%s', ...\n", ws.title);
    fprintf(fid, "    'Position', [%d %d %d %d]", ...
        ws.position.col, ws.position.row, ws.position.width, ws.position.height);
    if isfield(ws, 'units')
        fprintf(fid, ", ...\n    'Units', '%s'", ws.units);
    end
    if isfield(ws, 'source') && strcmp(ws.source.type, 'callback')
        fprintf(fid, ", ...\n    'ValueFcn', @%s", ws.source.function);
    elseif isfield(ws, 'source') && strcmp(ws.source.type, 'static')
        fprintf(fid, ", ...\n    'StaticValue', %g", ws.source.value);
    end
    fprintf(fid, ");\n\n");
case 'status'
    fprintf(fid, "d.addWidget('status', 'Title', '%s', ...\n", ws.title);
    fprintf(fid, "    'Position', [%d %d %d %d]", ...
        ws.position.col, ws.position.row, ws.position.width, ws.position.height);
    if isfield(ws, 'source') && strcmp(ws.source.type, 'callback')
        fprintf(fid, ", ...\n    'StatusFcn', @%s", ws.source.function);
    elseif isfield(ws, 'source') && strcmp(ws.source.type, 'static')
        fprintf(fid, ", ...\n    'StaticStatus', '%s'", ws.source.value);
    end
    fprintf(fid, ");\n\n");
case 'text'
    fprintf(fid, "d.addWidget('text', 'Title', '%s', ...\n", ws.title);
    fprintf(fid, "    'Position', [%d %d %d %d]", ...
        ws.position.col, ws.position.row, ws.position.width, ws.position.height);
    if isfield(ws, 'content') && ~isempty(ws.content)
        fprintf(fid, ", ...\n    'Content', '%s'", ws.content);
    end
    fprintf(fid, ");\n\n");
case 'gauge'
    fprintf(fid, "d.addWidget('gauge', 'Title', '%s', ...\n", ws.title);
    fprintf(fid, "    'Position', [%d %d %d %d]", ...
        ws.position.col, ws.position.row, ws.position.width, ws.position.height);
    if isfield(ws, 'range')
        fprintf(fid, ", ...\n    'Range', [%g %g]", ws.range(1), ws.range(2));
    end
    if isfield(ws, 'units')
        fprintf(fid, ", ...\n    'Units', '%s'", ws.units);
    end
    if isfield(ws, 'source') && strcmp(ws.source.type, 'callback')
        fprintf(fid, ", ...\n    'ValueFcn', @%s", ws.source.function);
    elseif isfield(ws, 'source') && strcmp(ws.source.type, 'static')
        fprintf(fid, ", ...\n    'StaticValue', %g", ws.source.value);
    end
    fprintf(fid, ");\n\n");
```

- [ ] **Step 6: Run all tests**

```matlab
results = runtests('tests/suite');
```
Expected: All pass including new `testAddPhase2Widgets`.

- [ ] **Step 7: Commit**

```bash
git add libs/Dashboard/DashboardEngine.m libs/Dashboard/DashboardSerializer.m tests/suite/TestDashboardEngine.m
git commit -m "feat: register KPI, Status, Text, Gauge widgets in Engine and Serializer"
```

---

### Task 6: Phase 2 Integration Example

**Files:**
- Create: `examples/example_dashboard_all_widgets.m`

- [ ] **Step 1: Create example**

```matlab
%% Dashboard with All Phase 2 Widget Types
% Demonstrates KPI, Status, Gauge, Text alongside FastPlot.

setup();

d = DashboardEngine('Process Monitoring — All Widgets');
d.Theme = 'dark';
d.LiveInterval = 3;

%% Row 1: KPIs and Status indicators
d.addWidget('text', 'Title', 'Process Overview', ...
    'Position', [1 1 12 1], 'FontSize', 16);

d.addWidget('kpi', 'Title', 'Temperature', ...
    'Position', [1 2 3 1], ...
    'StaticValue', 72.5, 'Units', '°C');

d.addWidget('kpi', 'Title', 'Flow Rate', ...
    'Position', [4 2 3 1], ...
    'StaticValue', 145.3, 'Units', 'L/min');

d.addWidget('status', 'Title', 'Pump 1', ...
    'Position', [7 2 2 1], ...
    'StaticStatus', 'ok');

d.addWidget('status', 'Title', 'Pump 2', ...
    'Position', [9 2 2 1], ...
    'StaticStatus', 'warning');

d.addWidget('status', 'Title', 'Valve', ...
    'Position', [11 2 2 1], ...
    'StaticStatus', 'alarm');

%% Row 3-4: Gauge and FastPlot
d.addWidget('gauge', 'Title', 'Pressure', ...
    'Position', [1 3 4 2], ...
    'StaticValue', 65, 'Range', [0 100], 'Units', 'bar');

t = linspace(0, 86400, 5000);
temp = 70 + 5*sin(2*pi*t/3600) + randn(1,5000)*0.5;

d.addWidget('fastplot', 'Title', 'Temperature Trend', ...
    'Position', [5 3 8 2], ...
    'XData', t, 'YData', temp);

d.render();
```

- [ ] **Step 2: Run example to verify**

```matlab
cd('/Users/hannessuhr/FastPlot'); setup(); addpath('examples');
example_dashboard_all_widgets;
```

- [ ] **Step 3: Commit**

```bash
git add examples/example_dashboard_all_widgets.m
git commit -m "feat: add example dashboard with all Phase 2 widget types"
```
