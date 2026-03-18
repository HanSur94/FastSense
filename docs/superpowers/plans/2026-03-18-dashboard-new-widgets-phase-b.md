# Dashboard New Widgets (Phase B) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 6 new widget types to the dashboard: HeatmapWidget, BarChartWidget, HistogramWidget, ScatterWidget, ImageWidget, and MultiStatusWidget.

**Architecture:** Each widget extends DashboardWidget, follows the Sensor-first data binding pattern (Sensor → DataFcn/ValueFcn → static fallback), implements render/refresh/getType/toStruct/fromStruct, and uses base MATLAB/Octave graphics (axes, bar, imagesc, patch, text). All 6 are registered in DashboardEngine/DashboardSerializer/bridge in a single final task.

**Tech Stack:** MATLAB/Octave, pure figure-based UI, R2020b compatible, no App Designer.

**Spec:** `docs/superpowers/specs/2026-03-18-dashboard-grouping-and-widgets-design.md` (Phase B section)

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `libs/Dashboard/HeatmapWidget.m` | 2D color grid visualization |
| Create | `libs/Dashboard/BarChartWidget.m` | Categorical bar charts |
| Create | `libs/Dashboard/HistogramWidget.m` | Value distribution bins |
| Create | `libs/Dashboard/ScatterWidget.m` | X vs Y correlation plot |
| Create | `libs/Dashboard/ImageWidget.m` | Static image display |
| Create | `libs/Dashboard/MultiStatusWidget.m` | Multi-sensor status grid |
| Create | `tests/suite/TestHeatmapWidget.m` | Heatmap tests |
| Create | `tests/suite/TestBarChartWidget.m` | BarChart tests |
| Create | `tests/suite/TestHistogramWidget.m` | Histogram tests |
| Create | `tests/suite/TestScatterWidget.m` | Scatter tests |
| Create | `tests/suite/TestImageWidget.m` | Image tests |
| Create | `tests/suite/TestMultiStatusWidget.m` | MultiStatus tests |
| Modify | `libs/Dashboard/DashboardEngine.m` | Add 6 new cases to addWidget + widgetTypes |
| Modify | `libs/Dashboard/DashboardSerializer.m` | Add 6 new cases to createWidgetFromStruct + exportScript |
| Modify | `bridge/web/js/widgets.js` | Add 6 new render functions |

---

## Widget Implementation Template

Every widget task follows this exact pattern. The task text below specifies **only the differences** from this template.

**Constructor:**
```matlab
function obj = MyWidget(varargin)
    obj = obj@DashboardWidget(varargin{:});
    % Override default position if needed
    if isequal(obj.Position, [1 1 6 2])
        obj.Position = [1 1 6 3];  % widget-specific default
    end
end
```

**getType:** Returns lowercase type string (e.g., `'heatmap'`).

**toStruct:** Calls `s = toStruct@DashboardWidget(obj)` then adds widget-specific fields in lowercase. For DataFcn/ValueFcn sources, serializes as `s.source = struct('type', 'callback', 'function', func2str(obj.DataFcn))`.

**fromStruct:** Static. Creates widget, sets Position from `s.position.{col,row,width,height}`, Title from `s.title`, and widget-specific properties. Resolves Sensor via SensorRegistry if available.

**Test pattern:** Each test file has TestClassSetup calling `install()`, then tests for: construction with defaults, construction with Sensor, getType, toStruct round-trip, and render into offscreen figure.

---

## Chunk 1: Chart Widgets (Heatmap, BarChart, Histogram, Scatter)

### Task 1: HeatmapWidget

**Files:** Create `libs/Dashboard/HeatmapWidget.m`, Create `tests/suite/TestHeatmapWidget.m`

- [ ] **Step 1: Write test file**

```matlab
classdef TestHeatmapWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = HeatmapWidget();
            testCase.verifyEqual(w.getType(), 'heatmap');
            testCase.verifyEqual(w.Colormap, 'parula');
            testCase.verifyEqual(w.ShowColorbar, true);
        end

        function testRender(testCase)
            w = HeatmapWidget('Title', 'Test Heatmap');
            w.DataFcn = @() magic(5);

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hPanel);
        end

        function testToStructRoundTrip(testCase)
            w = HeatmapWidget('Title', 'Heat');
            w.Colormap = 'jet';
            w.ShowColorbar = false;
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'heatmap');
            testCase.verifyEqual(s.colormap, 'jet');
            testCase.verifyEqual(s.showColorbar, false);
        end
    end
end
```

- [ ] **Step 2: Write HeatmapWidget.m**

```matlab
classdef HeatmapWidget < DashboardWidget
    properties (Access = public)
        DataFcn     = []           % function_handle returning matrix
        Colormap    = 'parula'     % colormap name or Nx3 matrix
        ShowColorbar = true
        XLabels     = {}           % cell array of axis labels
        YLabels     = {}           % cell array of axis labels
    end

    properties (SetAccess = private)
        hAxes       = []
        hImage      = []
        hColorbar   = []
    end

    methods
        function obj = HeatmapWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 8 4];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();
            bg = theme.WidgetBackground;

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.1 0.1 0.8 0.8], ...
                'Color', bg, ...
                'XColor', theme.AxisColor, ...
                'YColor', theme.AxisColor);

            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            data = [];
            if ~isempty(obj.Sensor)
                if isempty(obj.Sensor.Y), return; end
                data = obj.Sensor.Y;
            elseif ~isempty(obj.DataFcn)
                data = obj.DataFcn();
            end
            if isempty(data), return; end

            % Ensure data is 2D matrix
            if isvector(data)
                data = data(:)';
            end

            obj.hImage = imagesc(obj.hAxes, data);
            colormap(obj.hAxes, obj.Colormap);
            if obj.ShowColorbar
                obj.hColorbar = colorbar(obj.hAxes);
            end
            if ~isempty(obj.XLabels)
                set(obj.hAxes, 'XTick', 1:numel(obj.XLabels), ...
                    'XTickLabel', obj.XLabels);
            end
            if ~isempty(obj.YLabels)
                set(obj.hAxes, 'YTick', 1:numel(obj.YLabels), ...
                    'YTickLabel', obj.YLabels);
            end
        end

        function t = getType(~)
            t = 'heatmap';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.colormap = obj.Colormap;
            s.showColorbar = obj.ShowColorbar;
            if ~isempty(obj.XLabels), s.xLabels = obj.XLabels; end
            if ~isempty(obj.YLabels), s.yLabels = obj.YLabels; end
            if ~isempty(obj.DataFcn) && isempty(obj.Sensor)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.DataFcn));
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = HeatmapWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'colormap'), obj.Colormap = s.colormap; end
            if isfield(s, 'showColorbar'), obj.ShowColorbar = s.showColorbar; end
            if isfield(s, 'xLabels'), obj.XLabels = s.xLabels; end
            if isfield(s, 'yLabels'), obj.YLabels = s.yLabels; end
        end
    end
end
```

- [ ] **Step 3: Verify tests pass, commit**

```bash
git add libs/Dashboard/HeatmapWidget.m tests/suite/TestHeatmapWidget.m
git commit -m "feat(dashboard): add HeatmapWidget for 2D color grid visualization"
```

---

### Task 2: BarChartWidget

**Files:** Create `libs/Dashboard/BarChartWidget.m`, Create `tests/suite/TestBarChartWidget.m`

- [ ] **Step 1: Write test file**

```matlab
classdef TestBarChartWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = BarChartWidget();
            testCase.verifyEqual(w.getType(), 'barchart');
            testCase.verifyEqual(w.Orientation, 'vertical');
            testCase.verifyEqual(w.Stacked, false);
        end

        function testRender(testCase)
            w = BarChartWidget('Title', 'Test Bar');
            w.DataFcn = @() struct('categories', {{'A','B','C'}}, 'values', [10 20 30]);

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hPanel);
        end

        function testToStruct(testCase)
            w = BarChartWidget('Title', 'Bar');
            w.Orientation = 'horizontal';
            w.Stacked = true;
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'barchart');
            testCase.verifyEqual(s.orientation, 'horizontal');
            testCase.verifyEqual(s.stacked, true);
        end
    end
end
```

- [ ] **Step 2: Write BarChartWidget.m**

```matlab
classdef BarChartWidget < DashboardWidget
    properties (Access = public)
        DataFcn      = []           % @() struct('categories',{},'values',[])
        Orientation  = 'vertical'   % 'vertical' or 'horizontal'
        Stacked      = false
    end

    properties (SetAccess = private)
        hAxes = []
        hBars = []
    end

    methods
        function obj = BarChartWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 8 4];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.12 0.15 0.82 0.75], ...
                'Color', theme.WidgetBackground, ...
                'XColor', theme.AxisColor, ...
                'YColor', theme.AxisColor);
            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            data = [];
            cats = {};
            if ~isempty(obj.Sensor)
                if isempty(obj.Sensor.Y), return; end
                data = obj.Sensor.Y;
            elseif ~isempty(obj.DataFcn)
                result = obj.DataFcn();
                if isstruct(result)
                    cats = result.categories;
                    data = result.values;
                else
                    data = result;
                end
            end
            if isempty(data), return; end

            cla(obj.hAxes);
            if strcmp(obj.Orientation, 'horizontal')
                obj.hBars = barh(obj.hAxes, data);
            else
                obj.hBars = bar(obj.hAxes, data);
            end
            if ~isempty(cats)
                if strcmp(obj.Orientation, 'horizontal')
                    set(obj.hAxes, 'YTick', 1:numel(cats), 'YTickLabel', cats);
                else
                    set(obj.hAxes, 'XTick', 1:numel(cats), 'XTickLabel', cats);
                end
            end
        end

        function t = getType(~)
            t = 'barchart';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.orientation = obj.Orientation;
            s.stacked = obj.Stacked;
            if ~isempty(obj.DataFcn) && isempty(obj.Sensor)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.DataFcn));
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = BarChartWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'orientation'), obj.Orientation = s.orientation; end
            if isfield(s, 'stacked'), obj.Stacked = s.stacked; end
        end
    end
end
```

- [ ] **Step 3: Verify tests pass, commit**

```bash
git add libs/Dashboard/BarChartWidget.m tests/suite/TestBarChartWidget.m
git commit -m "feat(dashboard): add BarChartWidget for categorical bar charts"
```

---

### Task 3: HistogramWidget

**Files:** Create `libs/Dashboard/HistogramWidget.m`, Create `tests/suite/TestHistogramWidget.m`

- [ ] **Step 1: Write test file**

```matlab
classdef TestHistogramWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = HistogramWidget();
            testCase.verifyEqual(w.getType(), 'histogram');
            testCase.verifyEqual(w.ShowNormalFit, false);
            testCase.verifyEmpty(w.NumBins);
        end

        function testRender(testCase)
            w = HistogramWidget('Title', 'Test Hist');
            w.DataFcn = @() randn(1, 100);

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hPanel);
        end

        function testToStruct(testCase)
            w = HistogramWidget('Title', 'Hist');
            w.NumBins = 20;
            w.ShowNormalFit = true;
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'histogram');
            testCase.verifyEqual(s.numBins, 20);
            testCase.verifyEqual(s.showNormalFit, true);
        end
    end
end
```

- [ ] **Step 2: Write HistogramWidget.m**

Uses `bar` on computed bin edges (not `histogram()`) for Octave compatibility:

```matlab
classdef HistogramWidget < DashboardWidget
    properties (Access = public)
        DataFcn       = []
        NumBins       = []       % empty = auto
        ShowNormalFit = false
        EdgeColor     = []       % RGB or empty for default
    end

    properties (SetAccess = private)
        hAxes = []
    end

    methods
        function obj = HistogramWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 8 4];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.12 0.15 0.82 0.75], ...
                'Color', theme.WidgetBackground, ...
                'XColor', theme.AxisColor, ...
                'YColor', theme.AxisColor);
            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            data = [];
            if ~isempty(obj.Sensor)
                if isempty(obj.Sensor.Y), return; end
                data = obj.Sensor.Y(:)';
            elseif ~isempty(obj.DataFcn)
                data = obj.DataFcn();
                data = data(:)';
            end
            if isempty(data), return; end

            nBins = obj.NumBins;
            if isempty(nBins)
                nBins = max(10, round(sqrt(numel(data))));
            end

            [counts, edges] = histcounts(data, nBins);
            centers = (edges(1:end-1) + edges(2:end)) / 2;

            cla(obj.hAxes);
            bar(obj.hAxes, centers, counts, 1);

            if obj.ShowNormalFit && numel(data) > 2
                hold(obj.hAxes, 'on');
                mu = mean(data);
                sigma = std(data);
                xFit = linspace(min(data), max(data), 100);
                binWidth = edges(2) - edges(1);
                yFit = numel(data) * binWidth * ...
                    (1 / (sigma * sqrt(2*pi))) * exp(-0.5 * ((xFit - mu) / sigma).^2);
                plot(obj.hAxes, xFit, yFit, 'r-', 'LineWidth', 1.5);
                hold(obj.hAxes, 'off');
            end
        end

        function t = getType(~)
            t = 'histogram';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.NumBins), s.numBins = obj.NumBins; end
            s.showNormalFit = obj.ShowNormalFit;
            if ~isempty(obj.EdgeColor), s.edgeColor = obj.EdgeColor; end
            if ~isempty(obj.DataFcn) && isempty(obj.Sensor)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.DataFcn));
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = HistogramWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'numBins'), obj.NumBins = s.numBins; end
            if isfield(s, 'showNormalFit'), obj.ShowNormalFit = s.showNormalFit; end
            if isfield(s, 'edgeColor'), obj.EdgeColor = s.edgeColor; end
        end
    end
end
```

- [ ] **Step 3: Verify tests pass, commit**

```bash
git add libs/Dashboard/HistogramWidget.m tests/suite/TestHistogramWidget.m
git commit -m "feat(dashboard): add HistogramWidget for value distributions"
```

---

### Task 4: ScatterWidget

**Files:** Create `libs/Dashboard/ScatterWidget.m`, Create `tests/suite/TestScatterWidget.m`

- [ ] **Step 1: Write test file**

```matlab
classdef TestScatterWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = ScatterWidget();
            testCase.verifyEqual(w.getType(), 'scatter');
            testCase.verifyEqual(w.MarkerSize, 6);
            testCase.verifyEqual(w.Colormap, 'parula');
        end

        function testToStruct(testCase)
            w = ScatterWidget('Title', 'Scatter');
            w.MarkerSize = 10;
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'scatter');
            testCase.verifyEqual(s.markerSize, 10);
        end
    end
end
```

- [ ] **Step 2: Write ScatterWidget.m**

Uses two Sensor properties (SensorX, SensorY) instead of the base Sensor:

```matlab
classdef ScatterWidget < DashboardWidget
    properties (Access = public)
        SensorX     = []       % Sensor for X axis
        SensorY     = []       % Sensor for Y axis
        SensorColor = []       % Optional: color-code by third sensor
        MarkerSize  = 6
        Colormap    = 'parula'
    end

    properties (SetAccess = private)
        hAxes = []
        hScatter = []
    end

    methods
        function obj = ScatterWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 8 4];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.12 0.15 0.82 0.75], ...
                'Color', theme.WidgetBackground, ...
                'XColor', theme.AxisColor, ...
                'YColor', theme.AxisColor);
            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            xData = [];
            yData = [];
            if ~isempty(obj.SensorX) && ~isempty(obj.SensorY)
                if isempty(obj.SensorX.Y) || isempty(obj.SensorY.Y), return; end
                n = min(numel(obj.SensorX.Y), numel(obj.SensorY.Y));
                xData = obj.SensorX.Y(1:n);
                yData = obj.SensorY.Y(1:n);
            end
            if isempty(xData), return; end

            cla(obj.hAxes);
            if ~isempty(obj.SensorColor) && ~isempty(obj.SensorColor.Y)
                cData = obj.SensorColor.Y(1:min(numel(obj.SensorColor.Y), numel(xData)));
                % Use line with markers for Octave compatibility
                obj.hScatter = scatter(obj.hAxes, xData, yData, obj.MarkerSize, cData, 'filled');
                colormap(obj.hAxes, obj.Colormap);
                colorbar(obj.hAxes);
            else
                obj.hScatter = line(xData, yData, ...
                    'Parent', obj.hAxes, ...
                    'LineStyle', 'none', ...
                    'Marker', '.', ...
                    'MarkerSize', obj.MarkerSize);
            end
        end

        function t = getType(~)
            t = 'scatter';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.markerSize = obj.MarkerSize;
            s.colormap = obj.Colormap;
            % Override source with dual-sensor info
            if ~isempty(obj.SensorX)
                s.sensorX = obj.SensorX.Key;
            end
            if ~isempty(obj.SensorY)
                s.sensorY = obj.SensorY.Key;
            end
            if ~isempty(obj.SensorColor)
                s.sensorColor = obj.SensorColor.Key;
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = ScatterWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'markerSize'), obj.MarkerSize = s.markerSize; end
            if isfield(s, 'colormap'), obj.Colormap = s.colormap; end
        end
    end
end
```

- [ ] **Step 3: Verify tests pass, commit**

```bash
git add libs/Dashboard/ScatterWidget.m tests/suite/TestScatterWidget.m
git commit -m "feat(dashboard): add ScatterWidget for sensor correlation plots"
```

---

## Chunk 2: Content Widgets (Image, MultiStatus) + Registration

### Task 5: ImageWidget

**Files:** Create `libs/Dashboard/ImageWidget.m`, Create `tests/suite/TestImageWidget.m`

- [ ] **Step 1: Write test file**

```matlab
classdef TestImageWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = ImageWidget();
            testCase.verifyEqual(w.getType(), 'image');
            testCase.verifyEqual(w.Scaling, 'fit');
        end

        function testRenderWithImageFcn(testCase)
            w = ImageWidget('Title', 'Test Image');
            w.ImageFcn = @() uint8(randi(255, 50, 50, 3));

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hPanel);
        end

        function testToStruct(testCase)
            w = ImageWidget('Title', 'Img');
            w.File = '/tmp/test.png';
            w.Caption = 'A test image';
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'image');
            testCase.verifyEqual(s.file, '/tmp/test.png');
            testCase.verifyEqual(s.caption, 'A test image');
        end
    end
end
```

- [ ] **Step 2: Write ImageWidget.m**

```matlab
classdef ImageWidget < DashboardWidget
    properties (Access = public)
        File      = ''          % Path to image file (PNG, JPG)
        ImageFcn  = []          % function_handle returning image matrix
        Scaling   = 'fit'       % 'fit', 'fill', 'stretch'
        Caption   = ''
    end

    properties (SetAccess = private)
        hAxes     = []
        hImage    = []
        hCaption  = []
    end

    methods
        function obj = ImageWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 6 4];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            captionH = 0;
            if ~isempty(obj.Caption)
                captionH = 0.08;
            end

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.02 captionH+0.02 0.96 0.96-captionH], ...
                'Visible', 'off');

            if ~isempty(obj.Caption)
                obj.hCaption = uicontrol(parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Caption, ...
                    'Units', 'normalized', ...
                    'Position', [0.02 0 0.96 captionH], ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 9, ...
                    'ForegroundColor', theme.AxisColor, ...
                    'BackgroundColor', theme.WidgetBackground);
            end

            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            imgData = [];
            if ~isempty(obj.File) && exist(obj.File, 'file')
                imgData = imread(obj.File);
            elseif ~isempty(obj.ImageFcn)
                imgData = obj.ImageFcn();
            end
            if isempty(imgData), return; end

            obj.hImage = image(obj.hAxes, imgData);
            axis(obj.hAxes, 'image');
            set(obj.hAxes, 'Visible', 'off');
        end

        function t = getType(~)
            t = 'image';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.File), s.file = obj.File; end
            if ~isempty(obj.Caption), s.caption = obj.Caption; end
            s.scaling = obj.Scaling;
            if ~isempty(obj.ImageFcn) && isempty(obj.File)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.ImageFcn));
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = ImageWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'file'), obj.File = s.file; end
            if isfield(s, 'caption'), obj.Caption = s.caption; end
            if isfield(s, 'scaling'), obj.Scaling = s.scaling; end
        end
    end
end
```

- [ ] **Step 3: Verify tests pass, commit**

```bash
git add libs/Dashboard/ImageWidget.m tests/suite/TestImageWidget.m
git commit -m "feat(dashboard): add ImageWidget for static image display"
```

---

### Task 6: MultiStatusWidget

**Files:** Create `libs/Dashboard/MultiStatusWidget.m`, Create `tests/suite/TestMultiStatusWidget.m`

- [ ] **Step 1: Write test file**

```matlab
classdef TestMultiStatusWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = MultiStatusWidget();
            testCase.verifyEqual(w.getType(), 'multistatus');
            testCase.verifyEqual(w.ShowLabels, true);
            testCase.verifyEqual(w.IconStyle, 'dot');
        end

        function testToStruct(testCase)
            w = MultiStatusWidget('Title', 'Status Grid');
            w.Columns = 4;
            w.IconStyle = 'square';
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'multistatus');
            testCase.verifyEqual(s.columns, 4);
            testCase.verifyEqual(s.iconStyle, 'square');
        end
    end
end
```

- [ ] **Step 2: Write MultiStatusWidget.m**

Note: Uses `Sensors` (plural) array instead of inherited `Sensor` (singular). Fully overrides `toStruct`.

```matlab
classdef MultiStatusWidget < DashboardWidget
    properties (Access = public)
        Sensors    = {}         % Cell array of Sensor objects
        Columns    = []         % Grid columns (empty = auto)
        ShowLabels = true
        IconStyle  = 'dot'      % 'dot', 'square', 'icon'
    end

    properties (SetAccess = private)
        hAxes = []
    end

    methods
        function obj = MultiStatusWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 8 3];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.96 0.96], ...
                'Visible', 'off', ...
                'XLim', [0 1], 'YLim', [0 1]);
            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            n = numel(obj.Sensors);
            if n == 0, return; end

            cols = obj.Columns;
            if isempty(cols)
                cols = ceil(sqrt(n));
            end
            rows = ceil(n / cols);

            cla(obj.hAxes);
            hold(obj.hAxes, 'on');

            theme = obj.getTheme();
            okColor = theme.StatusOkColor;
            warnColor = theme.StatusWarnColor;
            alarmColor = theme.StatusAlarmColor;

            for i = 1:n
                col = mod(i-1, cols);
                row = floor((i-1) / cols);

                cx = (col + 0.5) / cols;
                cy = 1 - (row + 0.5) / rows;

                % Determine color from sensor thresholds
                sensor = obj.Sensors{i};
                color = okColor;
                if ~isempty(sensor) && ~isempty(sensor.Y)
                    val = sensor.Y(end);
                    if ~isempty(sensor.ThresholdRules)
                        for k = 1:numel(sensor.ThresholdRules)
                            rule = sensor.ThresholdRules{k};
                            if ~isempty(rule.Color)
                                if rule.IsUpper && val >= rule.Value
                                    color = rule.Color;
                                elseif ~rule.IsUpper && val <= rule.Value
                                    color = rule.Color;
                                end
                            end
                        end
                    end
                end

                % Draw indicator
                r = 0.3 / max(cols, rows);
                if strcmp(obj.IconStyle, 'square')
                    rectangle(obj.hAxes, 'Position', [cx-r cy-r 2*r 2*r], ...
                        'FaceColor', color, 'EdgeColor', 'none');
                else
                    theta = linspace(0, 2*pi, 30);
                    fill(obj.hAxes, cx + r*cos(theta), cy + r*sin(theta), ...
                        color, 'EdgeColor', 'none');
                end

                % Label
                if obj.ShowLabels && ~isempty(sensor)
                    name = sensor.Name;
                    if isempty(name), name = sensor.Key; end
                    text(obj.hAxes, cx, cy - r - 0.02, name, ...
                        'HorizontalAlignment', 'center', ...
                        'FontSize', 8, ...
                        'Color', theme.AxisColor);
                end
            end
            hold(obj.hAxes, 'off');
        end

        function t = getType(~)
            t = 'multistatus';
        end

        function s = toStruct(obj)
            % Fully override — does not use base Sensor property
            s = struct();
            s.type = 'multistatus';
            s.title = obj.Title;
            s.description = obj.Description;
            s.position = struct('col', obj.Position(1), 'row', obj.Position(2), ...
                'width', obj.Position(3), 'height', obj.Position(4));
            if ~isempty(fieldnames(obj.ThemeOverride))
                s.themeOverride = obj.ThemeOverride;
            end
            s.columns = obj.Columns;
            s.showLabels = obj.ShowLabels;
            s.iconStyle = obj.IconStyle;
            % Serialize sensor keys
            keys = cell(1, numel(obj.Sensors));
            for i = 1:numel(obj.Sensors)
                keys{i} = obj.Sensors{i}.Key;
            end
            s.sensors = keys;
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = MultiStatusWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'columns'), obj.Columns = s.columns; end
            if isfield(s, 'showLabels'), obj.ShowLabels = s.showLabels; end
            if isfield(s, 'iconStyle'), obj.IconStyle = s.iconStyle; end
            % Sensor resolution happens via resolver in configToWidgets
        end
    end
end
```

- [ ] **Step 3: Verify tests pass, commit**

```bash
git add libs/Dashboard/MultiStatusWidget.m tests/suite/TestMultiStatusWidget.m
git commit -m "feat(dashboard): add MultiStatusWidget for multi-sensor status grid"
```

---

### Task 7: Register all 6 widgets in Engine, Serializer, and Bridge

**Files:**
- Modify: `libs/Dashboard/DashboardEngine.m`
- Modify: `libs/Dashboard/DashboardSerializer.m`
- Modify: `bridge/web/js/widgets.js`

- [ ] **Step 1: Add 6 cases to DashboardEngine.addWidget**

In the `addWidget` switch block, add before `otherwise`:

```matlab
case 'heatmap'
    w = HeatmapWidget(varargin{:});
case 'barchart'
    w = BarChartWidget(varargin{:});
case 'histogram'
    w = HistogramWidget(varargin{:});
case 'scatter'
    w = ScatterWidget(varargin{:});
case 'image'
    w = ImageWidget(varargin{:});
case 'multistatus'
    w = MultiStatusWidget(varargin{:});
```

Add to `widgetTypes()`:

```matlab
'heatmap',      'Heatmap color grid (HeatmapWidget)'
'barchart',     'Bar chart for categories (BarChartWidget)'
'histogram',    'Value distribution histogram (HistogramWidget)'
'scatter',      'X vs Y scatter plot (ScatterWidget)'
'image',        'Static image display (ImageWidget)'
'multistatus',  'Multi-sensor status grid (MultiStatusWidget)'
```

- [ ] **Step 2: Add 6 cases to DashboardSerializer.createWidgetFromStruct**

```matlab
case 'heatmap'
    w = HeatmapWidget.fromStruct(ws);
case 'barchart'
    w = BarChartWidget.fromStruct(ws);
case 'histogram'
    w = HistogramWidget.fromStruct(ws);
case 'scatter'
    w = ScatterWidget.fromStruct(ws);
case 'image'
    w = ImageWidget.fromStruct(ws);
case 'multistatus'
    w = MultiStatusWidget.fromStruct(ws);
```

Also add cases to `exportScript`.

- [ ] **Step 3: Add 6 render functions to widgets.js**

Add dispatch cases and simple render functions for web export. Each function creates a placeholder or basic HTML representation.

- [ ] **Step 4: Commit**

```bash
git add libs/Dashboard/DashboardEngine.m libs/Dashboard/DashboardSerializer.m bridge/web/js/widgets.js
git commit -m "feat(dashboard): register all 6 new widget types in engine, serializer, and bridge"
```

---

## Summary

| Task | Widget | Key Feature |
|------|--------|-------------|
| 1 | HeatmapWidget | imagesc + colorbar, DataFcn or Sensor |
| 2 | BarChartWidget | bar/barh, orientation, stacked |
| 3 | HistogramWidget | bar on histcounts, optional normal fit |
| 4 | ScatterWidget | Dual SensorX/SensorY, optional color sensor |
| 5 | ImageWidget | imread from file or ImageFcn |
| 6 | MultiStatusWidget | Sensor array, colored dots/squares grid |
| 7 | Registration | Engine + Serializer + Bridge for all 6 |

**Parallelization:** Tasks 1-6 are fully independent — all 6 widgets can be implemented in parallel. Task 7 depends on all 6 being complete.
