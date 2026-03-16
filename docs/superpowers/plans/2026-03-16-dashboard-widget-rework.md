# Dashboard Widget Rework Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework all dashboard widgets to use Sensor-first data binding, rename KpiWidget→NumberWidget, add 4 gauge styles, rework StatusWidget layout, and add Description tooltip to all widgets.

**Architecture:** Move `SensorObj` from FastPlotWidget to the `DashboardWidget` base class. Each widget derives its display (value, units, range, colors) from the bound Sensor and its ThresholdRules. Add `Description` property with info icon hover to base class. GaugeWidget gains 4 rendering styles. StatusWidget uses ThresholdRule.Color for dot color.

**Tech Stack:** MATLAB R2020b, figure-based UI (uipanel, uicontrol, axes), no uifigure.

**Spec:** `docs/superpowers/specs/2026-03-16-dashboard-widget-rework-design.md`

---

## Chunk 1: Prerequisites and Base Class

### Task 1: Add Units property to Sensor

**Files:**
- Modify: `libs/SensorThreshold/Sensor.m:54-69`
- Test: `tests/suite/TestSensor.m` (existing — add one test)

- [ ] **Step 1: Write the failing test**

Add to `tests/suite/TestSensor.m`:

```matlab
function testUnitsProperty(testCase)
    s = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degC');
    testCase.verifyEqual(s.Units, 'degC');
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestSensor', 'ProcedureName', 'testUnitsProperty')"`
Expected: FAIL — 'Units' is not a property

- [ ] **Step 3: Add Units property to Sensor.m**

In `libs/SensorThreshold/Sensor.m`, add after line 62 (`Y` property):

```matlab
        Units         % char: measurement unit (e.g., 'degC', 'bar', 'rpm')
```

And in the constructor, add support for the name-value pair (the existing loop `for k = 1:2:numel(varargin)` already handles this generically).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestSensor', 'ProcedureName', 'testUnitsProperty')"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add libs/SensorThreshold/Sensor.m tests/suite/TestSensor.m
git commit -m "feat: add Units property to Sensor"
```

---

### Task 2: Add Description and SensorObj to DashboardWidget base class

**Files:**
- Modify: `libs/Dashboard/DashboardWidget.m`
- Test: `tests/suite/TestDashboardWidget.m`
- Test helper: `tests/suite/MockDashboardWidget.m`

- [ ] **Step 1: Write the failing tests**

Add to `tests/suite/TestDashboardWidget.m`:

```matlab
function testDescriptionProperty(testCase)
    w = MockDashboardWidget('Description', 'Measures outlet temp');
    testCase.verifyEqual(w.Description, 'Measures outlet temp');
end

function testSensorObjProperty(testCase)
    s = Sensor('T-401', 'Name', 'Temperature');
    w = MockDashboardWidget('SensorObj', s);
    testCase.verifyEqual(w.SensorObj.Key, 'T-401');
end

function testTitleDefaultsToSensorName(testCase)
    s = Sensor('T-401', 'Name', 'Temperature');
    w = MockDashboardWidget('SensorObj', s);
    testCase.verifyEqual(w.Title, 'Temperature');
end

function testTitleOverrideBeatssSensorName(testCase)
    s = Sensor('T-401', 'Name', 'Temperature');
    w = MockDashboardWidget('Title', 'Custom', 'SensorObj', s);
    testCase.verifyEqual(w.Title, 'Custom');
end

function testToStructIncludesDescription(testCase)
    w = MockDashboardWidget('Title', 'Test', 'Description', 'Info text');
    s = w.toStruct();
    testCase.verifyEqual(s.description, 'Info text');
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestDashboardWidget')"`
Expected: FAIL — Description and SensorObj not recognized

- [ ] **Step 3: Implement base class changes**

Modify `libs/Dashboard/DashboardWidget.m`:

In the public properties block (lines 12-17), add:

```matlab
        Description = ''    % Optional tooltip text shown via info icon hover
        SensorObj   = []    % Sensor object for data binding (primary source)
```

Update the constructor (lines 28-32) to apply title cascade after property assignment:

```matlab
        function obj = DashboardWidget(varargin)
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
            % Title cascade: if empty and Sensor bound, use Sensor.Name
            if isempty(obj.Title) && ~isempty(obj.SensorObj)
                if ~isempty(obj.SensorObj.Name)
                    obj.Title = obj.SensorObj.Name;
                else
                    obj.Title = obj.SensorObj.Key;
                end
            end
        end
```

Update `toStruct()` (lines 38-48) to include Description and Sensor source:

```matlab
        function s = toStruct(obj)
            s.type = obj.Type;
            s.title = obj.Title;
            s.description = obj.Description;
            s.position = struct('col', obj.Position(1), ...
                                'row', obj.Position(2), ...
                                'width', obj.Position(3), ...
                                'height', obj.Position(4));
            if ~isempty(fieldnames(obj.ThemeOverride))
                s.themeOverride = obj.ThemeOverride;
            end
            if ~isempty(obj.SensorObj)
                s.source = struct('type', 'sensor', 'name', obj.SensorObj.Key);
            end
        end
```

Add a `getTheme` utility method (currently duplicated in every widget — centralize here):

```matlab
    methods (Access = protected)
        function theme = getTheme(obj)
            theme = DashboardTheme();
            if ~isempty(fieldnames(obj.ThemeOverride))
                fns = fieldnames(obj.ThemeOverride);
                for i = 1:numel(fns)
                    theme.(fns{i}) = obj.ThemeOverride.(fns{i});
                end
            end
        end
    end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestDashboardWidget')"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardWidget.m tests/suite/TestDashboardWidget.m
git commit -m "feat: add Description, SensorObj, getTheme to DashboardWidget base class"
```

---

### Task 3: Remove duplicate getTheme from all widgets

**Files:**
- Modify: `libs/Dashboard/KpiWidget.m` (lines 192-202 — remove getTheme)
- Modify: `libs/Dashboard/GaugeWidget.m` (lines 225-235 — remove getTheme)
- Modify: `libs/Dashboard/StatusWidget.m` (lines 158-168 — remove getTheme)
- Modify: `libs/Dashboard/TextWidget.m` (lines 136-146 — remove getTheme)
- Modify: `libs/Dashboard/TableWidget.m` (lines 112-122 — remove getTheme)
- Modify: `libs/Dashboard/RawAxesWidget.m` (lines 115-134 — remove getTheme)
- Modify: `libs/Dashboard/EventTimelineWidget.m` (lines 246-254 — remove getTheme)

- [ ] **Step 1: Remove the `methods (Access = private)` block containing `getTheme` from each of the 7 widget files**

Each file has a private method block at the end with only `getTheme` in it. Delete the entire block from each file. The base class `DashboardWidget.getTheme()` (protected) will be inherited.

- [ ] **Step 2: Run all existing widget tests to verify nothing breaks**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestKpiWidget'); runtests('tests/suite/TestGaugeWidget'); runtests('tests/suite/TestStatusWidget'); runtests('tests/suite/TestFastPlotWidget')"`
Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add libs/Dashboard/KpiWidget.m libs/Dashboard/GaugeWidget.m libs/Dashboard/StatusWidget.m libs/Dashboard/TextWidget.m libs/Dashboard/TableWidget.m libs/Dashboard/RawAxesWidget.m libs/Dashboard/EventTimelineWidget.m
git commit -m "refactor: remove duplicate getTheme from widgets, use base class"
```

---

## Chunk 2: NumberWidget (rename from KpiWidget) + Sensor Binding

### Task 4: Rename KpiWidget to NumberWidget

**Files:**
- Create: `libs/Dashboard/NumberWidget.m` (copy from KpiWidget.m, rename class)
- Delete: `libs/Dashboard/KpiWidget.m` (after all references updated)
- Create: `tests/suite/TestNumberWidget.m` (copy from TestKpiWidget.m, update)
- Modify: `libs/Dashboard/DashboardEngine.m:52-78` (add 'number' case, alias 'kpi')
- Modify: `libs/Dashboard/DashboardSerializer.m:63-90` (add 'number' case, alias 'kpi')

- [ ] **Step 1: Create NumberWidget.m from KpiWidget.m**

Copy `libs/Dashboard/KpiWidget.m` to `libs/Dashboard/NumberWidget.m`. In the new file:
- Change `classdef KpiWidget` → `classdef NumberWidget`
- Change class doc comment to `%NUMBERWIDGET Dashboard widget showing a big number with label and trend.`
- Change constructor: `function obj = KpiWidget(` → `function obj = NumberWidget(`
- Change `getType()` return: `t = 'kpi'` → `t = 'number'`
- Change `fromStruct`: `obj = KpiWidget()` → `obj = NumberWidget()`
- Remove the private `getTheme` method block (now inherited from base class)

- [ ] **Step 2: Create TestNumberWidget.m from TestKpiWidget.m**

Copy `tests/suite/TestKpiWidget.m` to `tests/suite/TestNumberWidget.m`. Update:
- `classdef TestKpiWidget` → `classdef TestNumberWidget`
- All `KpiWidget(` → `NumberWidget(`
- `testGetType`: verify `'number'` not `'kpi'`
- `testToStruct`: verify `s.type` is `'number'`
- `testFromStruct`: use `NumberWidget.fromStruct(s)` and set `s.type = 'number'`

- [ ] **Step 3: Update DashboardEngine.addWidget switch-case**

In `libs/Dashboard/DashboardEngine.m`, at the switch block (lines 53-78), add after the 'kpi' case:

```matlab
                case 'number'
                    w = NumberWidget(varargin{:});
                case 'kpi'
                    warning('DashboardEngine:deprecated', ...
                        '''kpi'' type is deprecated, use ''number'' instead.');
                    w = NumberWidget(varargin{:});
```

Replace the existing `case 'kpi'` line 56-57 with the above.

- [ ] **Step 4: Update DashboardSerializer.configToWidgets switch-case**

In `libs/Dashboard/DashboardSerializer.m`, at the switch block (lines 68-88), replace `case 'kpi'` with:

```matlab
                    case 'number'
                        widgets{i} = NumberWidget.fromStruct(ws);
                    case 'kpi'
                        widgets{i} = NumberWidget.fromStruct(ws);
```

- [ ] **Step 5: Run TestNumberWidget**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestNumberWidget')"`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add libs/Dashboard/NumberWidget.m tests/suite/TestNumberWidget.m libs/Dashboard/DashboardEngine.m libs/Dashboard/DashboardSerializer.m
git commit -m "feat: rename KpiWidget to NumberWidget, add backward-compat alias"
```

---

### Task 5: Add Sensor binding to NumberWidget

**Files:**
- Modify: `libs/Dashboard/NumberWidget.m`
- Modify: `tests/suite/TestNumberWidget.m`

- [ ] **Step 1: Write failing tests for Sensor binding**

Add to `tests/suite/TestNumberWidget.m`:

```matlab
function testSensorBinding(testCase)
    s = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degC');
    s.X = [1 2 3 4 5];
    s.Y = [70 71 72 73 74];
    w = NumberWidget('Sensor', s);
    testCase.verifyEqual(w.Title, 'Temperature');
    hFig = figure('Visible', 'off');
    testCase.addTeardown(@() close(hFig));
    hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
    w.render(hp);
    testCase.verifyEqual(w.CurrentValue, 74);
    testCase.verifyEqual(w.Units, 'degC');
end

function testSensorTrend(testCase)
    s = Sensor('T-401', 'Name', 'Temperature');
    s.X = [1 2 3 4 5];
    s.Y = [70 71 72 73 74]; % rising
    w = NumberWidget('SensorObj', s);
    hFig = figure('Visible', 'off');
    testCase.addTeardown(@() close(hFig));
    hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
    w.render(hp);
    testCase.verifyEqual(w.CurrentTrend, 'up');
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestNumberWidget', 'ProcedureName', 'testSensorBinding')"`
Expected: FAIL

- [ ] **Step 3: Implement Sensor binding in NumberWidget**

Modify `libs/Dashboard/NumberWidget.m`:

Update constructor — add Sensor name-value support. The `'Sensor'` shorthand should map to the base-class `SensorObj`:

```matlab
        function obj = NumberWidget(varargin)
            % Map 'Sensor' shorthand to 'SensorObj'
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'Sensor')
                    varargin{k} = 'SensorObj';
                end
            end
            obj = obj@DashboardWidget(varargin{:});
            if isempty(obj.Position) || isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 6 1]; % default NumberWidget size
            end
            % Derive Units from Sensor if not explicitly set
            if isempty(obj.Units) && ~isempty(obj.SensorObj) && ~isempty(obj.SensorObj.Units)
                obj.Units = obj.SensorObj.Units;
            end
        end
```

Update `refresh()` to read from Sensor when bound:

```matlab
        function refresh(obj)
            if ~isempty(obj.SensorObj)
                obj.CurrentValue = obj.SensorObj.Y(end);
                if isempty(obj.Units) && ~isempty(obj.SensorObj.Units)
                    obj.Units = obj.SensorObj.Units;
                end
                % Compute trend from recent Y slope
                obj.CurrentTrend = obj.computeTrend();
            elseif ~isempty(obj.ValueFcn)
                result = obj.ValueFcn();
                if isstruct(result)
                    obj.CurrentValue = result.value;
                    if isfield(result, 'unit'), obj.Units = result.unit; end
                    if isfield(result, 'trend'), obj.CurrentTrend = result.trend; end
                else
                    obj.CurrentValue = result;
                end
            elseif ~isempty(obj.StaticValue)
                obj.CurrentValue = obj.StaticValue;
            else
                return;
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
                    case 'up',    set(obj.hTrendText, 'String', char(9650));
                    case 'down',  set(obj.hTrendText, 'String', char(9660));
                    case 'flat',  set(obj.hTrendText, 'String', char(9654));
                    otherwise,    set(obj.hTrendText, 'String', '');
                end
            end
        end
```

Add private `computeTrend` method:

```matlab
        function trend = computeTrend(obj)
            trend = '';
            if isempty(obj.SensorObj) || numel(obj.SensorObj.Y) < 3
                return;
            end
            % Use last 10% of data or at least 3 points
            n = numel(obj.SensorObj.Y);
            nTrend = max(3, round(n * 0.1));
            yRecent = obj.SensorObj.Y(end-nTrend+1:end);
            slope = (yRecent(end) - yRecent(1)) / nTrend;
            % Threshold: 1% of data range
            yRange = max(obj.SensorObj.Y) - min(obj.SensorObj.Y);
            if yRange == 0, return; end
            threshold = yRange * 0.01;
            if slope > threshold
                trend = 'up';
            elseif slope < -threshold
                trend = 'down';
            else
                trend = 'flat';
            end
        end
```

Update `toStruct()` to serialize Sensor binding:

```matlab
        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.units = obj.Units;
            s.format = obj.Format;
            % Source: prefer Sensor (already serialized by base class), then callback, then static
            if ~isempty(obj.SensorObj)
                % base class already added s.source
            elseif ~isempty(obj.ValueFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.ValueFcn));
            elseif ~isempty(obj.StaticValue)
                s.source = struct('type', 'static', 'value', obj.StaticValue);
            end
        end
```

Update `fromStruct()` to handle sensor source:

```matlab
        function obj = fromStruct(s)
            obj = NumberWidget();
            obj.Title = s.title;
            if isfield(s, 'description'), obj.Description = s.description; end
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'units'), obj.Units = s.units; end
            if isfield(s, 'format'), obj.Format = s.format; end
            if isfield(s, 'source')
                switch s.source.type
                    case 'sensor'
                        if exist('SensorRegistry', 'class')
                            obj.SensorObj = SensorRegistry.get(s.source.name);
                        end
                    case 'callback'
                        obj.ValueFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticValue = s.source.value;
                end
            end
        end
```

- [ ] **Step 4: Run all NumberWidget tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestNumberWidget')"`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/NumberWidget.m tests/suite/TestNumberWidget.m
git commit -m "feat: add Sensor binding to NumberWidget with auto trend/units"
```

---

## Chunk 3: StatusWidget Rework

### Task 6: Rework StatusWidget with Sensor binding and dot+value layout

**Files:**
- Modify: `libs/Dashboard/StatusWidget.m`
- Modify: `tests/suite/TestStatusWidget.m`

- [ ] **Step 1: Write failing tests**

Add to `tests/suite/TestStatusWidget.m`:

```matlab
function testSensorBindingNoViolation(testCase)
    s = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degC');
    s.X = [1 2 3]; s.Y = [70 71 72];
    s.ThresholdRules = {};
    s.ResolvedViolations = [];
    w = StatusWidget('SensorObj', s);
    testCase.verifyEqual(w.Title, 'Temperature');
    hFig = figure('Visible', 'off');
    testCase.addTeardown(@() close(hFig));
    hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
    w.render(hp);
    % No violations → green (ok)
    testCase.verifyEqual(w.CurrentStatus, 'ok');
end

function testSensorBindingWithViolation(testCase)
    s = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degC');
    s.X = [1 2 3]; s.Y = [70 71 85];
    rule = ThresholdRule(struct(), 80, 'Direction', 'upper', ...
        'Label', 'Hi Alarm', 'Color', [0.9 0.2 0.2]);
    s.ThresholdRules = {rule};
    s.resolve();
    w = StatusWidget('SensorObj', s);
    hFig = figure('Visible', 'off');
    testCase.addTeardown(@() close(hFig));
    hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
    w.render(hp);
    testCase.verifyNotEqual(w.CurrentStatus, 'ok');
    testCase.verifyEqual(w.CurrentColor, [0.9 0.2 0.2]);
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestStatusWidget', 'ProcedureName', 'testSensorBindingNoViolation')"`
Expected: FAIL

- [ ] **Step 3: Implement Sensor-bound StatusWidget**

Rewrite `libs/Dashboard/StatusWidget.m`:

```matlab
classdef StatusWidget < DashboardWidget
%STATUSWIDGET Colored dot indicator with sensor value.
%
%   Sensor-first:
%     w = StatusWidget('Sensor', sensorObj);
%
%   Legacy (still supported):
%     w = StatusWidget('Title', 'Pump 1', 'StatusFcn', @() 'ok');

    properties (Access = public)
        StatusFcn    = []       % function_handle returning 'ok'/'warning'/'alarm' (legacy)
        StaticStatus = ''       % fixed status string (legacy)
    end

    properties (SetAccess = private)
        CurrentStatus = ''
        CurrentColor  = [0.5 0.5 0.5]
        hAxes        = []
        hCircle      = []
        hLabelText   = []
    end

    methods
        function obj = StatusWidget(varargin)
            % Map 'Sensor' shorthand to 'SensorObj'
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'Sensor')
                    varargin{k} = 'SensorObj';
                end
            end
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 4 1]; % default compact size
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            bgColor = theme.WidgetBackground;
            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;

            % Adaptive font size
            oldUnits = get(parentPanel, 'Units');
            set(parentPanel, 'Units', 'pixels');
            pxPos = get(parentPanel, 'Position');
            set(parentPanel, 'Units', oldUnits);
            pH = pxPos(4);
            fontSz = max(7, min(14, round(pH * 0.28)));

            % Layout: [● dot] [Name: value Units]
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.1 0.12 0.8], ...
                'Visible', 'off', ...
                'XLim', [-1.3 1.3], 'YLim', [-1.3 1.3], ...
                'DataAspectRatio', [1 1 1], ...
                'HitTest', 'off');
            try set(obj.hAxes, 'PickableParts', 'none'); catch, end
            try disableDefaultInteractivity(obj.hAxes); catch, end
            hold(obj.hAxes, 'on');

            theta = linspace(0, 2*pi, 60);
            obj.hCircle = fill(obj.hAxes, cos(theta), sin(theta), ...
                [0.5 0.5 0.5], 'EdgeColor', 'none', 'HitTest', 'off');

            obj.hLabelText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '', ...
                'Units', 'normalized', ...
                'Position', [0.16 0.02 0.82 0.96], ...
                'FontName', fontName, ...
                'FontSize', fontSz, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'left');

            obj.refresh();
        end

        function refresh(obj)
            theme = obj.getTheme();

            if ~isempty(obj.SensorObj)
                % Sensor-first: derive status from violations
                [obj.CurrentStatus, obj.CurrentColor] = obj.deriveStatusFromSensor(theme);
            elseif ~isempty(obj.StatusFcn)
                obj.CurrentStatus = obj.StatusFcn();
                obj.CurrentColor = obj.statusToColor(obj.CurrentStatus, theme);
            elseif ~isempty(obj.StaticStatus)
                obj.CurrentStatus = obj.StaticStatus;
                obj.CurrentColor = obj.statusToColor(obj.CurrentStatus, theme);
            else
                return;
            end

            % Update dot color
            if ~isempty(obj.hCircle) && ishandle(obj.hCircle)
                set(obj.hCircle, 'FaceColor', obj.CurrentColor);
            end

            % Update label: "SensorName: value Units" or just status text
            if ~isempty(obj.hLabelText) && ishandle(obj.hLabelText)
                if ~isempty(obj.SensorObj)
                    val = obj.SensorObj.Y(end);
                    units = '';
                    if ~isempty(obj.SensorObj.Units)
                        units = [' ' obj.SensorObj.Units];
                    end
                    lbl = sprintf('%s: %.1f%s', obj.Title, val, units);
                else
                    lbl = sprintf('%s: %s', obj.Title, upper(obj.CurrentStatus));
                end
                set(obj.hLabelText, 'String', lbl);
            end
        end

        function configure(~)
        end

        function t = getType(~)
            t = 'status';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.SensorObj)
                % base class already serialized source
            elseif ~isempty(obj.StatusFcn)
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
            if isfield(s, 'description'), obj.Description = s.description; end
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'source')
                switch s.source.type
                    case 'sensor'
                        if exist('SensorRegistry', 'class')
                            obj.SensorObj = SensorRegistry.get(s.source.name);
                        end
                    case 'callback'
                        obj.StatusFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticStatus = s.source.value;
                end
            end
        end
    end

    methods (Access = private)
        function [status, color] = deriveStatusFromSensor(obj, theme)
            % Check current violations against the latest Y value
            status = 'ok';
            color = theme.StatusOkColor;

            if isempty(obj.SensorObj.ResolvedViolations)
                return;
            end

            latestX = obj.SensorObj.X(end);
            latestY = obj.SensorObj.Y(end);

            % Find active violations at the latest time point
            % A violation is active if latestY crosses a threshold
            worstValue = -inf;
            for i = 1:numel(obj.SensorObj.ThresholdRules)
                rule = obj.SensorObj.ThresholdRules{i};
                isViolated = false;
                if rule.IsUpper && latestY > rule.Value
                    isViolated = true;
                elseif ~rule.IsUpper && latestY < rule.Value
                    isViolated = true;
                end

                if isViolated
                    % Pick the most extreme threshold
                    extremeness = abs(latestY - rule.Value);
                    if extremeness > worstValue
                        worstValue = extremeness;
                        status = 'violation';
                        if ~isempty(rule.Color)
                            color = rule.Color;
                        elseif rule.IsUpper
                            color = theme.StatusAlarmColor;
                        else
                            color = theme.StatusWarnColor;
                        end
                    end
                end
            end
        end

        function color = statusToColor(~, status, theme)
            switch status
                case 'ok',      color = theme.StatusOkColor;
                case 'warning', color = theme.StatusWarnColor;
                case 'alarm',   color = theme.StatusAlarmColor;
                otherwise,      color = [0.5 0.5 0.5];
            end
        end
    end
end
```

- [ ] **Step 4: Run all StatusWidget tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestStatusWidget')"`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/StatusWidget.m tests/suite/TestStatusWidget.m
git commit -m "feat: rework StatusWidget with Sensor binding and dot+value layout"
```

---

## Chunk 4: GaugeWidget — Sensor Binding + 4 Styles

### Task 7: Add Sensor binding to GaugeWidget

**Files:**
- Modify: `libs/Dashboard/GaugeWidget.m`
- Modify: `tests/suite/TestGaugeWidget.m`

- [ ] **Step 1: Write failing test for Sensor binding**

Add to `tests/suite/TestGaugeWidget.m`:

```matlab
function testSensorBinding(testCase)
    s = Sensor('P-201', 'Name', 'Pressure', 'Units', 'bar');
    s.X = [1 2 3]; s.Y = [40 50 60];
    rule1 = ThresholdRule(struct(), 30, 'Direction', 'lower', 'Label', 'Lo', 'Color', [1 0.6 0]);
    rule2 = ThresholdRule(struct(), 80, 'Direction', 'upper', 'Label', 'Hi', 'Color', [1 0 0]);
    s.ThresholdRules = {rule1, rule2};
    w = GaugeWidget('SensorObj', s);
    testCase.verifyEqual(w.Title, 'Pressure');
    testCase.verifyEqual(w.Units, 'bar');
    % Range derived from thresholds: [30, 80]
    testCase.verifyEqual(w.Range, [30 80]);
    hFig = figure('Visible', 'off');
    testCase.addTeardown(@() close(hFig));
    hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
    w.render(hp);
    testCase.verifyEqual(w.CurrentValue, 60);
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestGaugeWidget', 'ProcedureName', 'testSensorBinding')"`
Expected: FAIL

- [ ] **Step 3: Implement Sensor binding**

Modify `libs/Dashboard/GaugeWidget.m`:

Add `Style` property and `Sensor` shorthand. Update constructor:

```matlab
    properties (Access = public)
        ValueFcn    = []
        Range       = []         % Changed default from [0 100] to [] for auto-derivation
        Units       = ''
        StaticValue = []
        Style       = 'arc'      % 'arc', 'donut', 'bar', 'thermometer'
    end
```

Update constructor:

```matlab
        function obj = GaugeWidget(varargin)
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'Sensor')
                    varargin{k} = 'SensorObj';
                end
            end
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 6 2]; % default gauge size
            end
            % Derive from Sensor
            if ~isempty(obj.SensorObj)
                if isempty(obj.Units) && ~isempty(obj.SensorObj.Units)
                    obj.Units = obj.SensorObj.Units;
                end
                if isempty(obj.Range)
                    obj.Range = obj.deriveRange();
                end
            end
            if isempty(obj.Range)
                obj.Range = [0 100]; % ultimate fallback
            end
        end
```

Add `deriveRange` method:

```matlab
        function rng = deriveRange(obj)
            % Cascade: thresholds → data → [0 100]
            if ~isempty(obj.SensorObj.ThresholdRules)
                vals = cellfun(@(r) r.Value, obj.SensorObj.ThresholdRules);
                rng = [min(vals), max(vals)];
            elseif ~isempty(obj.SensorObj.Y)
                rng = [min(obj.SensorObj.Y), max(obj.SensorObj.Y)];
            else
                rng = [0 100];
            end
        end
```

Update `refresh()` to read from Sensor:

```matlab
        function refresh(obj)
            if ~isempty(obj.SensorObj)
                obj.CurrentValue = obj.SensorObj.Y(end);
                if isempty(obj.Units) && ~isempty(obj.SensorObj.Units)
                    obj.Units = obj.SensorObj.Units;
                end
            elseif ~isempty(obj.ValueFcn)
                obj.CurrentValue = obj.ValueFcn();
            elseif ~isempty(obj.StaticValue)
                obj.CurrentValue = obj.StaticValue;
            else
                return;
            end
            obj.updateDisplay();
        end
```

Extract the arc rendering into `updateDisplay()` (refactored from existing refresh code). Color coding uses ThresholdRule.Color when available:

```matlab
        function color = getValueColor(obj, frac, theme)
            % Use ThresholdRule colors if Sensor bound
            if ~isempty(obj.SensorObj) && ~isempty(obj.SensorObj.ThresholdRules)
                val = obj.CurrentValue;
                color = theme.StatusOkColor;  % default ok
                worstDist = -inf;
                for i = 1:numel(obj.SensorObj.ThresholdRules)
                    rule = obj.SensorObj.ThresholdRules{i};
                    violated = (rule.IsUpper && val > rule.Value) || ...
                               (~rule.IsUpper && val < rule.Value);
                    if violated
                        dist = abs(val - rule.Value);
                        if dist > worstDist
                            worstDist = dist;
                            if ~isempty(rule.Color)
                                color = rule.Color;
                            elseif rule.IsUpper
                                color = theme.StatusAlarmColor;
                            else
                                color = theme.StatusWarnColor;
                            end
                        end
                    end
                end
            else
                % Fallback: fraction-based
                if frac < 0.6
                    color = theme.StatusOkColor;
                elseif frac < 0.85
                    color = theme.StatusWarnColor;
                else
                    color = theme.StatusAlarmColor;
                end
            end
        end
```

- [ ] **Step 4: Run all GaugeWidget tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestGaugeWidget')"`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/GaugeWidget.m tests/suite/TestGaugeWidget.m
git commit -m "feat: add Sensor binding and range derivation to GaugeWidget"
```

---

### Task 8: Add donut, bar, and thermometer styles to GaugeWidget

**Files:**
- Modify: `libs/Dashboard/GaugeWidget.m`
- Modify: `tests/suite/TestGaugeWidget.m`

- [ ] **Step 1: Write failing tests for each style**

Add to `tests/suite/TestGaugeWidget.m`:

```matlab
function testDonutStyle(testCase)
    w = GaugeWidget('Title', 'CPU', 'StaticValue', 65, ...
        'Range', [0 100], 'Units', '%', 'Style', 'donut');
    hFig = figure('Visible', 'off');
    testCase.addTeardown(@() close(hFig));
    hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
    w.render(hp);
    testCase.verifyEqual(w.CurrentValue, 65);
    testCase.verifyEqual(w.Style, 'donut');
end

function testBarStyle(testCase)
    w = GaugeWidget('Title', 'Load', 'StaticValue', 42, ...
        'Range', [0 100], 'Style', 'bar');
    hFig = figure('Visible', 'off');
    testCase.addTeardown(@() close(hFig));
    hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
    w.render(hp);
    testCase.verifyEqual(w.CurrentValue, 42);
end

function testThermometerStyle(testCase)
    w = GaugeWidget('Title', 'Temp', 'StaticValue', 72, ...
        'Range', [0 100], 'Units', 'degC', 'Style', 'thermometer');
    hFig = figure('Visible', 'off');
    testCase.addTeardown(@() close(hFig));
    hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
    w.render(hp);
    testCase.verifyEqual(w.CurrentValue, 72);
end

function testStyleSerializationRoundTrip(testCase)
    w = GaugeWidget('Title', 'G', 'StaticValue', 50, ...
        'Range', [0 100], 'Style', 'donut');
    s = w.toStruct();
    testCase.verifyEqual(s.style, 'donut');
    w2 = GaugeWidget.fromStruct(s);
    testCase.verifyEqual(w2.Style, 'donut');
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestGaugeWidget', 'ProcedureName', 'testDonutStyle')"`
Expected: FAIL — Style property not recognized or donut rendering not implemented

- [ ] **Step 3: Implement the render dispatcher and three new styles**

In `libs/Dashboard/GaugeWidget.m`, modify `render()` to dispatch based on Style:

```matlab
        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            switch obj.Style
                case 'arc',          obj.renderArc(parentPanel);
                case 'donut',        obj.renderDonut(parentPanel);
                case 'bar',          obj.renderBar(parentPanel);
                case 'thermometer',  obj.renderThermometer(parentPanel);
                otherwise
                    error('GaugeWidget:unknownStyle', 'Unknown style: %s', obj.Style);
            end
            obj.refresh();
        end
```

Move current arc rendering into `renderArc()`. Then implement three new methods:

**`renderDonut(parentPanel)`** — Full 360deg ring:
```matlab
        function renderDonut(obj, parentPanel)
            theme = obj.getTheme();
            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;
            arcWidth = theme.GaugeArcWidth;

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', 'Position', [0.1 0.05 0.8 0.8], ...
                'Visible', 'off', 'XLim', [-1.5 1.5], 'YLim', [-1.5 1.5], ...
                'DataAspectRatio', [1 1 1], 'HitTest', 'off');
            try set(obj.hAxes, 'PickableParts', 'none'); catch, end
            try disableDefaultInteractivity(obj.hAxes); catch, end
            hold(obj.hAxes, 'on');

            % Full circle background
            nPts = 100;
            angles = linspace(0, 2*pi, nPts);
            rOuter = 1.0; rInner = 0.70;
            xO = rOuter*cos(angles); yO = rOuter*sin(angles);
            xI = rInner*cos(fliplr(angles)); yI = rInner*sin(fliplr(angles));
            obj.hArcBg = fill(obj.hAxes, [xO xI], [yO yI], ...
                fgColor*0.15 + theme.WidgetBackground*0.85, 'EdgeColor', 'none');

            % Foreground arc (updated by refresh)
            obj.hArcFg = fill(obj.hAxes, [0 0], [0 0], ...
                theme.StatusOkColor, 'EdgeColor', 'none');

            % Value text centered
            obj.hValueText = text(obj.hAxes, 0, 0.05, '--', ...
                'HorizontalAlignment', 'center', 'FontSize', theme.KpiFontSize*0.8, ...
                'FontWeight', 'bold', 'FontName', fontName, 'Color', fgColor);

            % Units below value
            if ~isempty(obj.Units)
                text(obj.hAxes, 0, -0.3, obj.Units, ...
                    'HorizontalAlignment', 'center', 'FontSize', 9, ...
                    'FontName', fontName, 'Color', fgColor*0.6 + theme.WidgetBackground*0.4);
            end

            % Title above ring
            obj.hTitleText = text(obj.hAxes, 0, 1.35, obj.Title, ...
                'HorizontalAlignment', 'center', 'FontSize', theme.WidgetTitleFontSize, ...
                'FontWeight', 'bold', 'FontName', fontName, 'Color', fgColor);
        end
```

**`renderBar(parentPanel)`** — Horizontal progress bar:
```matlab
        function renderBar(obj, parentPanel)
            theme = obj.getTheme();
            fgColor = theme.ForegroundColor;
            bgColor = theme.WidgetBackground;
            fontName = theme.FontName;

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', 'Position', [0.08 0.3 0.84 0.3], ...
                'Visible', 'off', 'XLim', [0 1], 'YLim', [0 1], ...
                'HitTest', 'off');
            try set(obj.hAxes, 'PickableParts', 'none'); catch, end
            try disableDefaultInteractivity(obj.hAxes); catch, end
            hold(obj.hAxes, 'on');

            % Background bar
            obj.hArcBg = fill(obj.hAxes, [0 1 1 0], [0 0 1 1], ...
                fgColor*0.15 + bgColor*0.85, 'EdgeColor', 'none');

            % Foreground fill (updated by refresh)
            obj.hArcFg = fill(obj.hAxes, [0 0 0 0], [0 0 1 1], ...
                theme.StatusOkColor, 'EdgeColor', 'none');

            % Value text
            obj.hValueText = uicontrol('Parent', parentPanel, 'Style', 'text', ...
                'String', '--', 'Units', 'normalized', ...
                'Position', [0.08 0.62 0.84 0.25], ...
                'FontName', fontName, 'FontSize', theme.KpiFontSize*0.5, ...
                'FontWeight', 'bold', 'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, 'HorizontalAlignment', 'center');

            % Min/max labels
            obj.hMinText = uicontrol('Parent', parentPanel, 'Style', 'text', ...
                'String', sprintf('%.0f', obj.Range(1)), 'Units', 'normalized', ...
                'Position', [0.08 0.08 0.15 0.2], 'FontSize', 8, ...
                'FontName', fontName, 'ForegroundColor', fgColor*0.6+bgColor*0.4, ...
                'BackgroundColor', bgColor, 'HorizontalAlignment', 'left');
            obj.hMaxText = uicontrol('Parent', parentPanel, 'Style', 'text', ...
                'String', sprintf('%.0f', obj.Range(2)), 'Units', 'normalized', ...
                'Position', [0.77 0.08 0.15 0.2], 'FontSize', 8, ...
                'FontName', fontName, 'ForegroundColor', fgColor*0.6+bgColor*0.4, ...
                'BackgroundColor', bgColor, 'HorizontalAlignment', 'right');

            % Title
            obj.hTitleText = uicontrol('Parent', parentPanel, 'Style', 'text', ...
                'String', obj.Title, 'Units', 'normalized', ...
                'Position', [0.08 0.88 0.84 0.1], ...
                'FontName', fontName, 'FontSize', theme.WidgetTitleFontSize, ...
                'FontWeight', 'bold', 'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, 'HorizontalAlignment', 'center');
        end
```

**`renderThermometer(parentPanel)`** — Vertical bar:
```matlab
        function renderThermometer(obj, parentPanel)
            theme = obj.getTheme();
            fgColor = theme.ForegroundColor;
            bgColor = theme.WidgetBackground;
            fontName = theme.FontName;

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', 'Position', [0.35 0.1 0.3 0.75], ...
                'Visible', 'off', 'XLim', [0 1], 'YLim', [0 1], ...
                'HitTest', 'off');
            try set(obj.hAxes, 'PickableParts', 'none'); catch, end
            try disableDefaultInteractivity(obj.hAxes); catch, end
            hold(obj.hAxes, 'on');

            % Background bar (vertical)
            obj.hArcBg = fill(obj.hAxes, [0.2 0.8 0.8 0.2], [0 0 1 1], ...
                fgColor*0.15 + bgColor*0.85, 'EdgeColor', 'none');

            % Foreground fill (updated by refresh)
            obj.hArcFg = fill(obj.hAxes, [0.2 0.8 0.8 0.2], [0 0 0 0], ...
                theme.StatusOkColor, 'EdgeColor', 'none');

            % Bulb at bottom (circle)
            theta = linspace(0, 2*pi, 40);
            fill(obj.hAxes, 0.5 + 0.2*cos(theta), -0.08 + 0.08*sin(theta), ...
                fgColor*0.15 + bgColor*0.85, 'EdgeColor', 'none');

            % Value text above thermometer
            obj.hValueText = uicontrol('Parent', parentPanel, 'Style', 'text', ...
                'String', '--', 'Units', 'normalized', ...
                'Position', [0.1 0.86 0.8 0.12], ...
                'FontName', fontName, 'FontSize', theme.KpiFontSize*0.5, ...
                'FontWeight', 'bold', 'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, 'HorizontalAlignment', 'center');

            % Title
            obj.hTitleText = uicontrol('Parent', parentPanel, 'Style', 'text', ...
                'String', obj.Title, 'Units', 'normalized', ...
                'Position', [0.68 0.4 0.3 0.2], ...
                'FontName', fontName, 'FontSize', theme.WidgetTitleFontSize, ...
                'FontWeight', 'bold', 'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, 'HorizontalAlignment', 'left');

            % Min/max labels on right
            obj.hMinText = uicontrol('Parent', parentPanel, 'Style', 'text', ...
                'String', sprintf('%.0f', obj.Range(1)), 'Units', 'normalized', ...
                'Position', [0.68 0.1 0.3 0.1], 'FontSize', 8, ...
                'FontName', fontName, 'ForegroundColor', fgColor*0.6+bgColor*0.4, ...
                'BackgroundColor', bgColor, 'HorizontalAlignment', 'left');
            obj.hMaxText = uicontrol('Parent', parentPanel, 'Style', 'text', ...
                'String', sprintf('%.0f', obj.Range(2)), 'Units', 'normalized', ...
                'Position', [0.68 0.75 0.3 0.1], 'FontSize', 8, ...
                'FontName', fontName, 'ForegroundColor', fgColor*0.6+bgColor*0.4, ...
                'BackgroundColor', bgColor, 'HorizontalAlignment', 'left');
        end
```

Update `updateDisplay()` to handle all 4 styles for the foreground fill update:

```matlab
        function updateDisplay(obj)
            theme = obj.getTheme();
            val = obj.CurrentValue;
            rng = obj.Range;
            frac = max(0, min(1, (val - rng(1)) / (rng(2) - rng(1))));

            arcColor = obj.getValueColor(frac, theme);

            % Update value text
            if ~isempty(obj.hValueText) && ishandle(obj.hValueText)
                if isempty(obj.Units)
                    valStr = sprintf('%.1f', val);
                else
                    valStr = sprintf('%.1f %s', val, obj.Units);
                end
                    set(obj.hValueText, 'String', valStr);
            end

            switch obj.Style
                case 'arc'
                    obj.updateArc(frac, arcColor, theme);
                case 'donut'
                    obj.updateDonut(frac, arcColor, theme);
                case 'bar'
                    obj.updateBar(frac, arcColor);
                case 'thermometer'
                    obj.updateThermometer(frac, arcColor);
            end
        end
```

Where each `updateXxx` method sets the foreground fill XData/YData for that style:

- `updateArc`: existing arc sweep logic (lines 143-179)
- `updateDonut`: sweep from 90deg (top) clockwise, proportional to frac
- `updateBar`: set fill XData to `[0 frac frac 0]`
- `updateThermometer`: set fill YData to `[0 0 frac frac]`

Update `toStruct()` and `fromStruct()` to serialize `style`:

```matlab
        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.range = obj.Range;
            s.units = obj.Units;
            s.style = obj.Style;
            if ~isempty(obj.SensorObj)
                % already in base
            elseif ~isempty(obj.ValueFcn)
                s.source = struct('type', 'callback', 'function', func2str(obj.ValueFcn));
            elseif ~isempty(obj.StaticValue)
                s.source = struct('type', 'static', 'value', obj.StaticValue);
            end
        end
```

```matlab
        function obj = fromStruct(s)
            obj = GaugeWidget();
            obj.Title = s.title;
            if isfield(s, 'description'), obj.Description = s.description; end
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'range'), obj.Range = s.range; end
            if isfield(s, 'units'), obj.Units = s.units; end
            if isfield(s, 'style'), obj.Style = s.style; end
            if isfield(s, 'source')
                switch s.source.type
                    case 'sensor'
                        if exist('SensorRegistry', 'class')
                            obj.SensorObj = SensorRegistry.get(s.source.name);
                        end
                    case 'callback'
                        obj.ValueFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticValue = s.source.value;
                end
            end
        end
```

- [ ] **Step 4: Run all GaugeWidget tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestGaugeWidget')"`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/GaugeWidget.m tests/suite/TestGaugeWidget.m
git commit -m "feat: add donut, bar, thermometer styles to GaugeWidget"
```

---

## Chunk 5: Remaining Widget Updates

### Task 9: Update FastPlotWidget to use base class SensorObj

**Files:**
- Modify: `libs/Dashboard/FastPlotWidget.m`
- Test: `tests/suite/TestFastPlotWidget.m`

- [ ] **Step 1: Remove SensorObj property from FastPlotWidget**

`SensorObj` is now on the base class. Remove it from `libs/Dashboard/FastPlotWidget.m` line 13. Add 'Sensor' shorthand mapping in the constructor. Update constructor to delegate to base class:

```matlab
        function obj = FastPlotWidget(varargin)
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'Sensor')
                    varargin{k} = 'SensorObj';
                end
            end
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 12 3];
            end
            % Default labels from Sensor
            if ~isempty(obj.SensorObj)
                if isempty(obj.XLabel), obj.XLabel = 'Time'; end
                if isempty(obj.YLabel)
                    if ~isempty(obj.SensorObj.Units)
                        obj.YLabel = obj.SensorObj.Units;
                    elseif ~isempty(obj.SensorObj.Name)
                        obj.YLabel = obj.SensorObj.Name;
                    else
                        obj.YLabel = obj.SensorObj.Key;
                    end
                end
            end
        end
```

Remove the `SensorObj = []` from the public properties block (line 13). The rest of the class already references `obj.SensorObj` which will now resolve to the base class property.

- [ ] **Step 2: Run existing FastPlotWidget tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestFastPlotWidget')"`
Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add libs/Dashboard/FastPlotWidget.m
git commit -m "refactor: FastPlotWidget uses base class SensorObj"
```

---

### Task 10: Add Sensor binding to TableWidget (data + event modes)

**Files:**
- Modify: `libs/Dashboard/TableWidget.m`
- Modify: `tests/suite/TestTableWidget.m` (create if not exists)

- [ ] **Step 1: Write failing tests**

Create/update `tests/suite/TestTableWidget.m`:

```matlab
function testSensorDataMode(testCase)
    s = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degC');
    s.X = [1 2 3 4 5]; s.Y = [70 71 72 73 74];
    w = TableWidget('SensorObj', s, 'Mode', 'data', 'N', 3);
    testCase.verifyEqual(w.Title, 'Temperature');
    testCase.verifyEqual(w.Mode, 'data');
    testCase.verifyEqual(w.N, 3);
end
```

- [ ] **Step 2: Implement Sensor binding with data/event modes**

Add new properties to `TableWidget.m`:

```matlab
    properties (Access = public)
        DataFcn     = []
        Data        = {}
        ColumnNames = {}
        Mode        = 'data'     % 'data' or 'events'
        N           = 10         % number of rows to display
        EventStoreObj = []       % EventStore for event mode
    end
```

Add `'Sensor'` shorthand in constructor. Update `refresh()`:

```matlab
        function refresh(obj)
            data = [];
            colNames = obj.ColumnNames;

            if ~isempty(obj.SensorObj)
                if strcmp(obj.Mode, 'data')
                    % Last N data points
                    n = min(obj.N, numel(obj.SensorObj.X));
                    x = obj.SensorObj.X(end-n+1:end);
                    y = obj.SensorObj.Y(end-n+1:end);
                    data = cell(n, 2);
                    for i = 1:n
                        data{i,1} = datestr(x(i), 'HH:MM:SS');
                        data{i,2} = y(i);
                    end
                    if isempty(colNames)
                        colNames = {'Time', obj.SensorObj.Name};
                    end
                elseif strcmp(obj.Mode, 'events') && ~isempty(obj.EventStoreObj)
                    evts = obj.EventStoreObj.getEvents();
                    % Filter to this Sensor
                    sName = obj.SensorObj.Name;
                    mask = arrayfun(@(e) contains(e.SensorName, sName), evts);
                    evts = evts(mask);
                    % Last N
                    n = min(obj.N, numel(evts));
                    evts = evts(end-n+1:end);
                    data = cell(n, 4);
                    for i = 1:n
                        data{i,1} = datestr(evts(i).StartTime, 'HH:MM:SS');
                        data{i,2} = datestr(evts(i).EndTime, 'HH:MM:SS');
                        data{i,3} = evts(i).ThresholdLabel;
                        data{i,4} = sprintf('%.1fs', (evts(i).EndTime - evts(i).StartTime)*86400);
                    end
                    if isempty(colNames)
                        colNames = {'Start', 'End', 'Label', 'Duration'};
                    end
                end
            elseif ~isempty(obj.DataFcn)
                data = obj.DataFcn();
            elseif ~isempty(obj.Data)
                data = obj.Data;
            end

            if ~isempty(data) && ~isempty(obj.hTable) && ishandle(obj.hTable)
                set(obj.hTable, 'Data', data);
                if ~isempty(colNames)
                    set(obj.hTable, 'ColumnName', colNames);
                end
            end
        end
```

- [ ] **Step 3: Run tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestTableWidget')"`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add libs/Dashboard/TableWidget.m tests/suite/TestTableWidget.m
git commit -m "feat: add Sensor binding with data/event modes to TableWidget"
```

---

### Task 11: Update RawAxesWidget with Sensor-aware PlotFcn dispatch

**Files:**
- Modify: `libs/Dashboard/RawAxesWidget.m`

- [ ] **Step 1: Update callPlotFcn dispatch logic**

In `libs/Dashboard/RawAxesWidget.m`, replace `callPlotFcn` (lines 116-123):

```matlab
        function callPlotFcn(obj)
            if isempty(obj.PlotFcn), return; end
            nArgs = nargin(obj.PlotFcn);

            if ~isempty(obj.SensorObj)
                % Sensor-bound: @(ax, sensor) or @(ax, sensor, tRange)
                if ~isempty(obj.TimeRange) && nArgs >= 3
                    obj.PlotFcn(obj.hAxes, obj.SensorObj, obj.TimeRange);
                elseif nArgs >= 2
                    obj.PlotFcn(obj.hAxes, obj.SensorObj);
                else
                    obj.PlotFcn(obj.hAxes);
                end
            else
                % No Sensor: @(ax) or @(ax, tRange) (legacy)
                if ~isempty(obj.TimeRange) && nArgs >= 2
                    obj.PlotFcn(obj.hAxes, obj.TimeRange);
                else
                    obj.PlotFcn(obj.hAxes);
                end
            end
        end
```

Also update `getTimeRange()` to use Sensor when available:

```matlab
        function [tMin, tMax] = getTimeRange(obj)
            tMin = inf; tMax = -inf;
            if ~isempty(obj.SensorObj) && ~isempty(obj.SensorObj.X)
                tMin = min(obj.SensorObj.X);
                tMax = max(obj.SensorObj.X);
            elseif ~isempty(obj.DataRangeFcn)
                r = obj.DataRangeFcn();
                tMin = r(1); tMax = r(2);
            end
        end
```

Add `'Sensor'` shorthand mapping in constructor.

- [ ] **Step 2: Run existing tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite')"`
Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add libs/Dashboard/RawAxesWidget.m
git commit -m "feat: update RawAxesWidget PlotFcn dispatch for Sensor binding"
```

---

### Task 12: Add Description tooltip and 'Sensor' shorthand to TextWidget and EventTimelineWidget

**Files:**
- Modify: `libs/Dashboard/TextWidget.m`
- Modify: `libs/Dashboard/EventTimelineWidget.m`

- [ ] **Step 1: Update TextWidget**

Add `'Sensor'` shorthand mapping in constructor (TextWidget doesn't use it but the base class handles it). Update `fromStruct` to read `description` field. No other changes needed — TextWidget is static.

- [ ] **Step 2: Update EventTimelineWidget**

Add `FilterSensors` and `ColorSource` properties. Update `fromStruct` to read `description` and `filterSensors`. Update `resolveEvents` to filter by `FilterSensors` when set:

```matlab
    properties (Access = public)
        EventStoreObj = []
        Events    = []
        EventFcn  = []
        FilterSensors = {}   % Cell array of Sensor names to filter
        ColorSource = 'event' % 'event' or 'theme'
    end
```

In `resolveEvents`, after getting events, filter by `FilterSensors` and apply `ColorSource`:

```matlab
            if ~isempty(obj.FilterSensors) && ~isempty(evts)
                mask = false(1, numel(evts));
                for i = 1:numel(evts)
                    for j = 1:numel(obj.FilterSensors)
                        if contains(evts(i).label, obj.FilterSensors{j})
                            mask(i) = true;
                            break;
                        end
                    end
                end
                evts = evts(mask);
            end
```

In the rendering loop (inside `refresh()`), apply `ColorSource` when determining bar color:

```matlab
                % Color
                if strcmp(obj.ColorSource, 'event') && isfield(ev, 'color') && ~isempty(ev.color)
                    c = ev.color;
                else
                    % theme palette cycling
                    c = defaultColors(mod(i-1, size(defaultColors,1)) + 1, :);
                end
```

This replaces the existing color selection block. When `ColorSource == 'theme'`, event colors are ignored and the theme palette cycles instead.

- [ ] **Step 3: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite')"`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add libs/Dashboard/TextWidget.m libs/Dashboard/EventTimelineWidget.m
git commit -m "feat: add FilterSensors to EventTimelineWidget, update fromStruct for Description"
```

---

## Chunk 6: DashboardEngine.load() and Integration

### Task 13: Update DashboardEngine.load() with SensorResolver parameter

**Files:**
- Modify: `libs/Dashboard/DashboardEngine.m:403-424`

- [ ] **Step 1: Add SensorResolver name-value parameter**

Replace the `load` method:

```matlab
        function obj = load(filepath, varargin)
            resolver = [];
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'SensorResolver')
                    resolver = varargin{k+1};
                end
            end

            config = DashboardSerializer.load(filepath);
            obj = DashboardEngine(config.name);
            if isfield(config, 'theme')
                obj.Theme = config.theme;
            end
            if isfield(config, 'liveInterval')
                obj.LiveInterval = config.liveInterval;
            end
            obj.FilePath = filepath;

            widgets = DashboardSerializer.configToWidgets(config, resolver);
            for i = 1:numel(widgets)
                w = widgets{i};
                existingPositions = cell(1, numel(obj.Widgets));
                for j = 1:numel(obj.Widgets)
                    existingPositions{j} = obj.Widgets{j}.Position;
                end
                w.Position = obj.Layout.resolveOverlap(w.Position, existingPositions);
                obj.Widgets{end+1} = w;
            end
        end
```

- [ ] **Step 2: Update DashboardSerializer.configToWidgets to accept resolver**

Update `configToWidgets` signature to accept an optional resolver function handle and pass it to each widget's `fromStruct` or use it to resolve sensor keys after creation:

```matlab
        function widgets = configToWidgets(config, resolver)
            if nargin < 2, resolver = []; end
            widgets = cell(1, numel(config.widgets));
            for i = 1:numel(config.widgets)
                ws = config.widgets{i};
                switch ws.type
                    case 'fastplot'
                        widgets{i} = FastPlotWidget.fromStruct(ws);
                    case {'number', 'kpi'}
                        widgets{i} = NumberWidget.fromStruct(ws);
                    case 'status'
                        widgets{i} = StatusWidget.fromStruct(ws);
                    case 'text'
                        widgets{i} = TextWidget.fromStruct(ws);
                    case 'gauge'
                        widgets{i} = GaugeWidget.fromStruct(ws);
                    case 'table'
                        widgets{i} = TableWidget.fromStruct(ws);
                    case 'rawaxes'
                        widgets{i} = RawAxesWidget.fromStruct(ws);
                    case 'timeline'
                        widgets{i} = EventTimelineWidget.fromStruct(ws);
                    otherwise
                        warning('DashboardSerializer:unknownType', ...
                            'Unknown widget type: %s — skipping', ws.type);
                end
                % Resolve sensor binding using resolver
                if ~isempty(resolver) && ~isempty(widgets{i}) && ...
                        isfield(ws, 'source') && strcmp(ws.source.type, 'sensor')
                    try
                        widgets{i}.SensorObj = resolver(ws.source.name);
                    catch
                        warning('DashboardSerializer:sensorNotFound', ...
                            'Could not resolve sensor: %s', ws.source.name);
                    end
                end
            end
        end
```

- [ ] **Step 3: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite')"`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add libs/Dashboard/DashboardEngine.m libs/Dashboard/DashboardSerializer.m
git commit -m "feat: add SensorResolver to DashboardEngine.load()"
```

---

### Task 14: Delete old KpiWidget.m and TestKpiWidget.m

**Files:**
- Delete: `libs/Dashboard/KpiWidget.m`
- Delete: `tests/suite/TestKpiWidget.m`

- [ ] **Step 1: Verify NumberWidget works as replacement**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestNumberWidget')"`
Expected: All PASS

- [ ] **Step 2: Delete old files**

```bash
git rm libs/Dashboard/KpiWidget.m tests/suite/TestKpiWidget.m
git commit -m "chore: remove old KpiWidget files (replaced by NumberWidget)"
```

---

### Task 15: Update example scripts and run full test suite

**Files:**
- Modify: `examples/example_dashboard_all_widgets.m` — update `'kpi'` → `'number'`
- Modify: `examples/example_dashboard_live.m` — update references
- Modify: any other examples using `'kpi'` or `KpiWidget`

- [ ] **Step 1: Find and update all references to 'kpi' in examples**

Run grep to find all usages, then update each file.

- [ ] **Step 2: Run full test suite**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite')"`
Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add examples/
git commit -m "chore: update examples for NumberWidget rename and Sensor binding"
```

---

### Task 16: Update DashboardBuilder palette for NumberWidget

**Files:**
- Modify: `libs/Dashboard/DashboardBuilder.m` — update 'kpi' references to 'number'

- [ ] **Step 1: Find and update all 'kpi' references in DashboardBuilder.m**

The palette sidebar creates buttons for each widget type. Update the 'kpi' button label and type string to 'number'.

- [ ] **Step 2: Run builder tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); runtests('tests/suite/TestDashboardBuilder')"`
Expected: All PASS

- [ ] **Step 3: Commit**

```bash
git add libs/Dashboard/DashboardBuilder.m
git commit -m "chore: update DashboardBuilder palette for NumberWidget"
```

---

### Task 17: Final integration test

- [ ] **Step 1: Run the full test suite**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "setup(); results = runtests('tests/suite'); disp(table(results))"`
Expected: All PASS, no warnings about deprecated 'kpi' in test code

- [ ] **Step 2: Verify all changes are committed**

```bash
git status
git log --oneline -15
```
