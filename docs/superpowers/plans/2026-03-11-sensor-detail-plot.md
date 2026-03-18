# SensorDetailPlot Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a two-panel sensor overview+detail plot with interactive navigator, threshold bands, and optional event overlay.

**Architecture:** Two new classes (`SensorDetailPlot`, `NavigatorOverlay`) in `libs/FastSense/`, one new method (`tilePanel`) on `FastSenseFigure`. `SensorDetailPlot` coordinates two `FastSense` instances; `NavigatorOverlay` handles the zoom rectangle, dimming, and drag interaction on the navigator axes.

**Tech Stack:** MATLAB (handle classes, uipanel layout, axes listeners, WindowButton callbacks)

**Spec:** `docs/superpowers/specs/2026-03-11-sensor-detail-plot-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `libs/FastSense/NavigatorOverlay.m` | Create | Zoom rectangle, dimming patches, drag interaction |
| `libs/FastSense/SensorDetailPlot.m` | Create | Coordinator: two-panel layout, sensor rendering, event overlay, sync |
| `libs/FastSense/FastSenseFigure.m` | Modify | Add `tilePanel(n)` method |
| `tests/test_NavigatorOverlay.m` | Create | Unit tests for NavigatorOverlay |
| `tests/test_SensorDetailPlot.m` | Create | Unit tests for SensorDetailPlot |
| `examples/example_sensor_detail.m` | Create | Demo script showing standalone + events usage |

---

## Chunk 1: NavigatorOverlay

### Task 1: NavigatorOverlay — Class Skeleton + Visual Elements

**Files:**
- Create: `libs/FastSense/NavigatorOverlay.m`
- Create: `tests/test_NavigatorOverlay.m`

- [ ] **Step 1: Write failing tests for NavigatorOverlay construction and visual elements**

Create `tests/test_NavigatorOverlay.m`:

```matlab
function tests = test_NavigatorOverlay
    tests = functiontests(localfunctions);
end

function setup(testCase)
    addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'libs', 'FastSense'));
    addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'libs', 'SensorThreshold'));
    testCase.TestData.hFig = figure('Visible', 'off');
    testCase.TestData.hAxes = axes('Parent', testCase.TestData.hFig);
    % Draw a dummy line so axes has data range
    plot(testCase.TestData.hAxes, [0 100], [0 10]);
    xlim(testCase.TestData.hAxes, [0 100]);
    ylim(testCase.TestData.hAxes, [0 10]);
end

function teardown(testCase)
    if ishandle(testCase.TestData.hFig)
        delete(testCase.TestData.hFig);
    end
end

%% Construction
function test_constructor_creates_overlay(testCase)
    ov = NavigatorOverlay(testCase.TestData.hAxes);
    verifyClass(testCase, ov, ?NavigatorOverlay);
    verifyTrue(testCase, ishandle(ov.hRegion));
    verifyTrue(testCase, ishandle(ov.hDimLeft));
    verifyTrue(testCase, ishandle(ov.hDimRight));
    verifyTrue(testCase, ishandle(ov.hEdgeLeft));
    verifyTrue(testCase, ishandle(ov.hEdgeRight));
    delete(ov);
end

%% setRange
function test_setRange_updates_patches(testCase)
    ov = NavigatorOverlay(testCase.TestData.hAxes);
    ov.setRange(20, 60);

    % Region patch X vertices should span [20, 60]
    regionX = get(ov.hRegion, 'XData');
    verifyEqual(testCase, min(regionX), 20, 'AbsTol', 1e-10);
    verifyEqual(testCase, max(regionX), 60, 'AbsTol', 1e-10);

    % DimLeft should cover [0, 20]
    dimLX = get(ov.hDimLeft, 'XData');
    verifyEqual(testCase, min(dimLX), 0, 'AbsTol', 1e-10);
    verifyEqual(testCase, max(dimLX), 20, 'AbsTol', 1e-10);

    % DimRight should cover [60, 100]
    dimRX = get(ov.hDimRight, 'XData');
    verifyEqual(testCase, min(dimRX), 60, 'AbsTol', 1e-10);
    verifyEqual(testCase, max(dimRX), 100, 'AbsTol', 1e-10);

    % Edge lines at boundaries
    edgeLX = get(ov.hEdgeLeft, 'XData');
    verifyEqual(testCase, edgeLX(1), 20, 'AbsTol', 1e-10);
    edgeRX = get(ov.hEdgeRight, 'XData');
    verifyEqual(testCase, edgeRX(1), 60, 'AbsTol', 1e-10);

    delete(ov);
end

%% Boundary clamping
function test_setRange_clamps_to_axes_limits(testCase)
    ov = NavigatorOverlay(testCase.TestData.hAxes);
    ov.setRange(-10, 120);

    regionX = get(ov.hRegion, 'XData');
    verifyEqual(testCase, min(regionX), 0, 'AbsTol', 1e-10);
    verifyEqual(testCase, max(regionX), 100, 'AbsTol', 1e-10);
    delete(ov);
end

%% Minimum width
function test_setRange_enforces_minimum_width(testCase)
    ov = NavigatorOverlay(testCase.TestData.hAxes);
    % 0.5% of range [0,100] = 0.5
    ov.setRange(50, 50.1);

    regionX = get(ov.hRegion, 'XData');
    actualWidth = max(regionX) - min(regionX);
    verifyGreaterThanOrEqual(testCase, actualWidth, 0.5);
    delete(ov);
end

%% OnRangeChanged callback
function test_callback_fires_on_setRange(testCase)
    ov = NavigatorOverlay(testCase.TestData.hAxes);
    callbackFired = false;
    capturedRange = [0 0];
    ov.OnRangeChanged = @(xMin, xMax) deal_callback(xMin, xMax);
    ov.setRange(30, 70);

    verifyTrue(testCase, callbackFired);
    verifyEqual(testCase, capturedRange, [30 70], 'AbsTol', 1e-10);
    delete(ov);

    function deal_callback(xMin, xMax)
        callbackFired = true;
        capturedRange = [xMin xMax];
    end
end

%% Cleanup
function test_delete_removes_graphics(testCase)
    ov = NavigatorOverlay(testCase.TestData.hAxes);
    hReg = ov.hRegion;
    delete(ov);
    verifyFalse(testCase, ishandle(hReg));
end

function test_delete_restores_figure_callbacks(testCase)
    hFig = testCase.TestData.hFig;
    oldDown = get(hFig, 'WindowButtonDownFcn');
    ov = NavigatorOverlay(testCase.TestData.hAxes);
    delete(ov);
    restoredDown = get(hFig, 'WindowButtonDownFcn');
    verifyEqual(testCase, restoredDown, oldDown);
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); results = runtests('test_NavigatorOverlay'); disp(results)"`
Expected: FAIL — NavigatorOverlay class not found

- [ ] **Step 3: Implement NavigatorOverlay class — visual elements + setRange**

Create `libs/FastSense/NavigatorOverlay.m`:

```matlab
classdef NavigatorOverlay < handle
    % NavigatorOverlay  Zoom rectangle, dimming, and drag interaction on navigator axes.
    %
    %   ov = NavigatorOverlay(hAxes)
    %
    %   Properties (read-only):
    %     hRegion, hDimLeft, hDimRight, hEdgeLeft, hEdgeRight — graphics handles
    %
    %   Methods:
    %     setRange(xMin, xMax) — update the visible region rectangle
    %     delete()             — clean up all handles and callbacks

    properties (SetAccess = private)
        hAxes           % Navigator axes handle
        hRegion         % Patch: semi-transparent rectangle over visible range
        hDimLeft        % Patch: gray overlay left of region
        hDimRight       % Patch: gray overlay right of region
        hEdgeLeft       % Line: left boundary grab handle
        hEdgeRight      % Line: right boundary grab handle
    end

    properties
        OnRangeChanged  % Callback: @(xMin, xMax)
    end

    properties (Access = private)
        hFig            % Parent figure handle
        DragState       % 'idle', 'panning', 'resizeLeft', 'resizeRight'
        DragStartX      % X position at drag start (data units)
        DragStartRange  % [xMin, xMax] at drag start
        CurrentRange    % [xMin, xMax] current visible range
        DataXLim        % [xMin, xMax] full data range (axes XLim at construction)
        MinWidthFrac    % Minimum region width as fraction of full range
        EdgeTolPx       % Edge hit tolerance in pixels
        EdgeTolData     % Edge hit tolerance in data units (recomputed on resize)
        RegionColor     % RGB for region patch
        DimColor        % RGB for dim patches
        DimAlpha        % Alpha for dim patches
        RegionAlpha     % Alpha for region patch
        OldWindowButtonDownFcn
        OldWindowButtonMotionFcn
        OldWindowButtonUpFcn
        OldResizeFcn
    end

    methods
        function obj = NavigatorOverlay(hAxes, varargin)
            obj.hAxes = hAxes;
            obj.hFig = ancestor(hAxes, 'figure');
            obj.DragState = 'idle';
            obj.MinWidthFrac = 0.005;  % 0.5% of range
            obj.EdgeTolPx = 5;
            obj.RegionColor = [0.2 0.4 0.8];
            obj.DimColor = [0.5 0.5 0.5];
            obj.DimAlpha = 0.4;
            obj.RegionAlpha = 0.15;
            obj.OnRangeChanged = [];

            obj.DataXLim = get(hAxes, 'XLim');
            yLim = get(hAxes, 'YLim');

            % Initialize patches — all start at zero width
            xL = obj.DataXLim(1);
            xR = obj.DataXLim(2);
            yB = yLim(1);
            yT = yLim(2);

            wasHeld = ishold(hAxes);
            hold(hAxes, 'on');

            % Dim left
            obj.hDimLeft = patch(hAxes, ...
                [xL xL xL xL], [yB yT yT yB], obj.DimColor, ...
                'FaceAlpha', obj.DimAlpha, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off', 'HitTest', 'off', 'PickableParts', 'none');

            % Dim right
            obj.hDimRight = patch(hAxes, ...
                [xR xR xR xR], [yB yT yT yB], obj.DimColor, ...
                'FaceAlpha', obj.DimAlpha, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off', 'HitTest', 'off', 'PickableParts', 'none');

            % Region highlight
            obj.hRegion = patch(hAxes, ...
                [xL xL xR xR], [yB yT yT yB], obj.RegionColor, ...
                'FaceAlpha', obj.RegionAlpha, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off', 'HitTest', 'off', 'PickableParts', 'none');

            % Edge lines
            obj.hEdgeLeft = line(hAxes, [xL xL], [yB yT], ...
                'Color', obj.RegionColor, 'LineWidth', 1.5, ...
                'HandleVisibility', 'off', 'HitTest', 'off', 'PickableParts', 'none');
            obj.hEdgeRight = line(hAxes, [xR xR], [yB yT], ...
                'Color', obj.RegionColor, 'LineWidth', 1.5, ...
                'HandleVisibility', 'off', 'HitTest', 'off', 'PickableParts', 'none');

            obj.CurrentRange = [xL xR];

            % Restore hold state
            if ~wasHeld; hold(hAxes, 'off'); end

            % Compute initial edge tolerance
            obj.recomputeEdgeTolerance();

            % Install mouse callbacks
            obj.installCallbacks();

            % Listen for figure resize to recompute edge tolerance
            obj.OldResizeFcn = get(obj.hFig, 'ResizeFcn');
            set(obj.hFig, 'ResizeFcn', @(s,e) obj.onFigureResize(s,e));
        end

        function setRange(obj, xMin, xMax)
            % Clamp to data limits
            xMin = max(xMin, obj.DataXLim(1));
            xMax = min(xMax, obj.DataXLim(2));

            % Enforce minimum width
            fullRange = obj.DataXLim(2) - obj.DataXLim(1);
            minWidth = fullRange * obj.MinWidthFrac;
            if (xMax - xMin) < minWidth
                mid = (xMin + xMax) / 2;
                xMin = mid - minWidth / 2;
                xMax = mid + minWidth / 2;
                % Re-clamp after expansion
                if xMin < obj.DataXLim(1)
                    xMin = obj.DataXLim(1);
                    xMax = xMin + minWidth;
                end
                if xMax > obj.DataXLim(2)
                    xMax = obj.DataXLim(2);
                    xMin = xMax - minWidth;
                end
            end

            obj.CurrentRange = [xMin xMax];
            obj.updatePatches();

            % Fire callback
            if ~isempty(obj.OnRangeChanged)
                obj.OnRangeChanged(xMin, xMax);
            end
        end

        function delete(obj)
            % Restore original figure callbacks
            if ~isempty(obj.hFig) && ishandle(obj.hFig)
                if ~isempty(obj.OldWindowButtonDownFcn)
                    set(obj.hFig, 'WindowButtonDownFcn', obj.OldWindowButtonDownFcn);
                end
                if ~isempty(obj.OldWindowButtonMotionFcn)
                    set(obj.hFig, 'WindowButtonMotionFcn', obj.OldWindowButtonMotionFcn);
                end
                if ~isempty(obj.OldWindowButtonUpFcn)
                    set(obj.hFig, 'WindowButtonUpFcn', obj.OldWindowButtonUpFcn);
                end
                if ~isempty(obj.OldResizeFcn)
                    set(obj.hFig, 'ResizeFcn', obj.OldResizeFcn);
                else
                    set(obj.hFig, 'ResizeFcn', '');
                end
            end

            % Delete graphics
            handles = [obj.hRegion, obj.hDimLeft, obj.hDimRight, obj.hEdgeLeft, obj.hEdgeRight];
            for h = handles
                if ~isempty(h) && ishandle(h)
                    delete(h);
                end
            end
        end
    end

    methods (Access = private)
        function updatePatches(obj)
            if ~ishandle(obj.hAxes); return; end

            yLim = get(obj.hAxes, 'YLim');
            yB = yLim(1);
            yT = yLim(2);
            xMin = obj.CurrentRange(1);
            xMax = obj.CurrentRange(2);
            xL = obj.DataXLim(1);
            xR = obj.DataXLim(2);

            % Update region
            set(obj.hRegion, 'XData', [xMin xMin xMax xMax], ...
                             'YData', [yB yT yT yB]);

            % Update dim left
            set(obj.hDimLeft, 'XData', [xL xL xMin xMin], ...
                              'YData', [yB yT yT yB]);

            % Update dim right
            set(obj.hDimRight, 'XData', [xMax xMax xR xR], ...
                               'YData', [yB yT yT yB]);

            % Update edge lines
            set(obj.hEdgeLeft, 'XData', [xMin xMin], 'YData', [yB yT]);
            set(obj.hEdgeRight, 'XData', [xMax xMax], 'YData', [yB yT]);
        end

        function recomputeEdgeTolerance(obj)
            if ~ishandle(obj.hAxes); return; end
            % Convert pixel tolerance to data units
            pos = getpixelposition(obj.hAxes);
            axesWidthPx = pos(3);
            dataRange = obj.DataXLim(2) - obj.DataXLim(1);
            if axesWidthPx > 0
                obj.EdgeTolData = obj.EdgeTolPx * (dataRange / axesWidthPx);
            else
                obj.EdgeTolData = dataRange * 0.01;
            end
        end

        function installCallbacks(obj)
            % Save existing callbacks to chain them
            obj.OldWindowButtonDownFcn = get(obj.hFig, 'WindowButtonDownFcn');
            obj.OldWindowButtonMotionFcn = get(obj.hFig, 'WindowButtonMotionFcn');
            obj.OldWindowButtonUpFcn = get(obj.hFig, 'WindowButtonUpFcn');

            set(obj.hFig, 'WindowButtonDownFcn', @(s,e) obj.onMouseDown(s,e));
            set(obj.hFig, 'WindowButtonMotionFcn', @(s,e) obj.onMouseMove(s,e));
            set(obj.hFig, 'WindowButtonUpFcn', @(s,e) obj.onMouseUp(s,e));
        end

        function onMouseDown(obj, src, evt)
            % Get click position in navigator axes data coordinates
            cp = get(obj.hAxes, 'CurrentPoint');
            clickX = cp(1,1);
            clickY = cp(1,2);

            % Check if click is within navigator axes bounds
            xLim = get(obj.hAxes, 'XLim');
            yLim = get(obj.hAxes, 'YLim');
            if clickX < xLim(1) || clickX > xLim(2) || ...
               clickY < yLim(1) || clickY > yLim(2)
                % Click outside navigator — chain to old callback
                if ~isempty(obj.OldWindowButtonDownFcn)
                    obj.OldWindowButtonDownFcn(src, evt);
                end
                return;
            end

            xMin = obj.CurrentRange(1);
            xMax = obj.CurrentRange(2);
            tol = obj.EdgeTolData;

            if abs(clickX - xMin) <= tol
                % Left edge
                obj.DragState = 'resizeLeft';
                obj.DragStartX = clickX;
                obj.DragStartRange = obj.CurrentRange;
            elseif abs(clickX - xMax) <= tol
                % Right edge
                obj.DragState = 'resizeRight';
                obj.DragStartX = clickX;
                obj.DragStartRange = obj.CurrentRange;
            elseif clickX > xMin && clickX < xMax
                % Inside region — pan
                obj.DragState = 'panning';
                obj.DragStartX = clickX;
                obj.DragStartRange = obj.CurrentRange;
            else
                % Outside region — click to center
                width = xMax - xMin;
                newMin = clickX - width / 2;
                newMax = clickX + width / 2;
                obj.setRange(newMin, newMax);
                % Start panning from new position
                obj.DragState = 'panning';
                obj.DragStartX = clickX;
                obj.DragStartRange = obj.CurrentRange;
            end
        end

        function onMouseMove(obj, ~, ~)
            if strcmp(obj.DragState, 'idle'); return; end
            if ~ishandle(obj.hAxes); return; end

            cp = get(obj.hAxes, 'CurrentPoint');
            currentX = cp(1,1);
            deltaX = currentX - obj.DragStartX;

            switch obj.DragState
                case 'panning'
                    newMin = obj.DragStartRange(1) + deltaX;
                    newMax = obj.DragStartRange(2) + deltaX;
                    obj.setRange(newMin, newMax);

                case 'resizeLeft'
                    newMin = obj.DragStartRange(1) + deltaX;
                    obj.setRange(newMin, obj.DragStartRange(2));

                case 'resizeRight'
                    newMax = obj.DragStartRange(2) + deltaX;
                    obj.setRange(obj.DragStartRange(1), newMax);
            end
        end

        function onMouseUp(obj, ~, ~)
            obj.DragState = 'idle';
        end

        function onFigureResize(obj, src, evt)
            obj.recomputeEdgeTolerance();
            % Chain to old callback
            if ~isempty(obj.OldResizeFcn)
                if isa(obj.OldResizeFcn, 'function_handle')
                    obj.OldResizeFcn(src, evt);
                end
            end
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); results = runtests('test_NavigatorOverlay'); disp(results)"`
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add libs/FastSense/NavigatorOverlay.m tests/test_NavigatorOverlay.m
git commit -m "feat: add NavigatorOverlay with visual elements and drag interaction"
```

---

### Task 2: NavigatorOverlay — Mouse Interaction Tests

**Files:**
- Modify: `tests/test_NavigatorOverlay.m`

- [ ] **Step 1: Add mouse interaction tests**

Append to `tests/test_NavigatorOverlay.m` (before the final `end` — note: there is no final `end` in function-based tests):

```matlab
%% Panning preserves region width at boundary
function test_pan_preserves_width_at_left_boundary(testCase)
    ov = NavigatorOverlay(testCase.TestData.hAxes);
    ov.setRange(5, 25);  % width = 20
    ov.setRange(-10, 10);  % pan past left edge
    regionX = get(ov.hRegion, 'XData');
    verifyGreaterThanOrEqual(testCase, min(regionX), 0);
    % Width should be clamped but not shrunk
    actualWidth = max(regionX) - min(regionX);
    verifyGreaterThanOrEqual(testCase, actualWidth, 0.5);  % at least min width
    delete(ov);
end

function test_pan_preserves_width_at_right_boundary(testCase)
    ov = NavigatorOverlay(testCase.TestData.hAxes);
    ov.setRange(80, 95);  % width = 15
    ov.setRange(90, 110);  % pan past right edge
    regionX = get(ov.hRegion, 'XData');
    verifyLessThanOrEqual(testCase, max(regionX), 100);
    delete(ov);
end

%% Hold state is preserved
function test_hold_state_preserved(testCase)
    hold(testCase.TestData.hAxes, 'off');
    ov = NavigatorOverlay(testCase.TestData.hAxes);
    verifyFalse(testCase, ishold(testCase.TestData.hAxes));
    delete(ov);
end
```

- [ ] **Step 2: Run tests**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); results = runtests('test_NavigatorOverlay'); disp(results)"`
Expected: All 10 tests PASS

- [ ] **Step 3: Commit**

```bash
git add tests/test_NavigatorOverlay.m
git commit -m "test: add NavigatorOverlay boundary clamping tests"
```

---

## Chunk 2: SensorDetailPlot Core

### Task 3: SensorDetailPlot — Constructor + Layout

**Files:**
- Create: `libs/FastSense/SensorDetailPlot.m`
- Create: `tests/test_SensorDetailPlot.m`

- [ ] **Step 1: Write failing tests for constructor and layout**

Create `tests/test_SensorDetailPlot.m`:

```matlab
function tests = test_SensorDetailPlot
    tests = functiontests(localfunctions);
end

function setup(testCase)
    addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'libs', 'FastSense'));
    addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'libs', 'SensorThreshold'));
    addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'libs', 'EventDetection'));

    % Create a simple sensor
    s = Sensor('test_pressure', 'Name', 'Test Pressure');
    t = linspace(0, 100, 10000);
    s.X = t;
    s.Y = 50 + 10*sin(2*pi*t/20) + randn(1, numel(t));
    testCase.TestData.sensor = s;
end

function teardown(testCase)
    % Close any figures opened during tests
    close all force;
end

%% Construction
function test_constructor_stores_sensor(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    verifyEqual(testCase, sdp.Sensor.Key, 'test_pressure');
    delete(sdp);
end

function test_constructor_default_options(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    verifyEqual(testCase, sdp.NavigatorHeight, 0.20, 'AbsTol', 1e-10);
    verifyTrue(testCase, sdp.ShowThresholds);
    verifyTrue(testCase, sdp.ShowThresholdBands);
    verifyTrue(testCase, isempty(sdp.Events));
    delete(sdp);
end

function test_constructor_custom_options(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor, ...
        'NavigatorHeight', 0.30, ...
        'ShowThresholds', false, ...
        'Theme', 'dark', ...
        'Title', 'Custom Title');
    verifyEqual(testCase, sdp.NavigatorHeight, 0.30, 'AbsTol', 1e-10);
    verifyFalse(testCase, sdp.ShowThresholds);
    delete(sdp);
end

%% Render creates two FastSense instances
function test_render_creates_main_and_navigator(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    sdp.render();
    verifyClass(testCase, sdp.MainPlot, ?FastSense);
    verifyClass(testCase, sdp.NavigatorPlot, ?FastSense);
    delete(sdp);
end

%% Render guard
function test_render_twice_throws(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    sdp.render();
    verifyError(testCase, @() sdp.render(), 'SensorDetailPlot:alreadyRendered');
    delete(sdp);
end

%% MainPlot has sensor data
function test_main_plot_has_sensor_line(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    sdp.render();
    verifyGreaterThanOrEqual(testCase, numel(sdp.MainPlot.Lines), 1);
    delete(sdp);
end

%% NavigatorPlot has data line
function test_navigator_has_data_line(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    sdp.render();
    verifyGreaterThanOrEqual(testCase, numel(sdp.NavigatorPlot.Lines), 1);
    delete(sdp);
end

%% Zoom range methods
function test_set_get_zoom_range(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    sdp.render();
    sdp.setZoomRange(20, 60);
    [xMin, xMax] = sdp.getZoomRange();
    verifyEqual(testCase, xMin, 20, 'AbsTol', 1);
    verifyEqual(testCase, xMax, 60, 'AbsTol', 1);
    delete(sdp);
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); results = runtests('test_SensorDetailPlot'); disp(results)"`
Expected: FAIL — SensorDetailPlot class not found

- [ ] **Step 3: Implement SensorDetailPlot — constructor + render + layout**

Create `libs/FastSense/SensorDetailPlot.m`:

```matlab
classdef SensorDetailPlot < handle
    % SensorDetailPlot  Two-panel sensor overview+detail plot with interactive navigator.
    %
    %   sdp = SensorDetailPlot(sensor)
    %   sdp = SensorDetailPlot(sensor, Name, Value, ...)
    %
    %   Name-Value Options:
    %     'Theme'              - FastSense theme (default: 'default')
    %     'NavigatorHeight'    - Fraction 0-1 for navigator (default: 0.20)
    %     'ShowThresholds'     - Show thresholds in main plot (default: true)
    %     'ShowThresholdBands' - Show threshold bands in navigator (default: true)
    %     'Events'             - EventStore or Event array (default: [])
    %     'ShowEventLabels'    - Reserved, no effect (default: false)
    %     'Parent'             - uipanel handle for embedding (default: [])
    %     'Title'              - Plot title (default: sensor.Name)

    properties (SetAccess = private)
        Sensor              % Sensor object
        MainPlot            % FastSense instance for upper panel
        NavigatorPlot       % FastSense instance for lower panel
        NavigatorOverlayObj % NavigatorOverlay instance
    end

    properties (SetAccess = private, GetAccess = public)
        NavigatorHeight     % Fraction of total height for navigator
        ShowThresholds      % Show thresholds in main plot
        ShowThresholdBands  % Show threshold bands in navigator
        Events              % Event array (resolved from EventStore or direct)
        ShowEventLabels     % Reserved, no effect
        Theme               % Theme string or struct
        Title               % Plot title
    end

    properties (Access = private)
        ParentPanel         % External uipanel (if embedded)
        hFig                % Figure handle (if standalone)
        hMainPanel          % uipanel for main plot
        hNavPanel           % uipanel for navigator
        hMainAxes           % Axes in main panel
        hNavAxes            % Axes in navigator panel
        IsRendered          % Guard flag
        IsPropagating       % Guard against infinite sync loops
        XLimListener        % Listener for main axes XLim changes
        OwnsFigure          % True if we created the figure
    end

    methods
        function obj = SensorDetailPlot(sensor, varargin)
            % Validate sensor
            assert(isa(sensor, 'Sensor'), 'SensorDetailPlot:invalidInput', ...
                'First argument must be a Sensor object.');

            obj.Sensor = sensor;
            obj.IsRendered = false;
            obj.IsPropagating = false;
            obj.OwnsFigure = false;

            % Parse options
            p = inputParser;
            p.addParameter('Theme', 'default');
            p.addParameter('NavigatorHeight', 0.20);
            p.addParameter('ShowThresholds', true);
            p.addParameter('ShowThresholdBands', true);
            p.addParameter('Events', []);
            p.addParameter('ShowEventLabels', false);
            p.addParameter('Parent', []);
            p.addParameter('Title', sensor.Name);
            p.parse(varargin{:});
            opts = p.Results;

            obj.Theme = opts.Theme;
            obj.NavigatorHeight = opts.NavigatorHeight;
            obj.ShowThresholds = opts.ShowThresholds;
            obj.ShowThresholdBands = opts.ShowThresholdBands;
            obj.ShowEventLabels = opts.ShowEventLabels;
            obj.ParentPanel = opts.Parent;
            obj.Title = opts.Title;

            % Resolve events
            obj.Events = obj.resolveEvents(opts.Events);
        end

        function render(obj)
            if obj.IsRendered
                error('SensorDetailPlot:alreadyRendered', ...
                    'SensorDetailPlot has already been rendered.');
            end

            % Create layout
            obj.createLayout();

            % Create main FastSense
            obj.MainPlot = FastSense('Parent', obj.hMainAxes, 'Theme', obj.Theme);
            obj.MainPlot.addSensor(obj.Sensor, 'ShowThresholds', obj.ShowThresholds);

            % Render main plot
            obj.MainPlot.render();

            % Set title
            if ~isempty(obj.Title)
                title(obj.hMainAxes, obj.Title);
            end

            % Create navigator FastSense
            obj.NavigatorPlot = FastSense('Parent', obj.hNavAxes, 'Theme', obj.Theme);
            obj.NavigatorPlot.addLine(obj.Sensor.X, obj.Sensor.Y, ...
                'DisplayName', obj.Sensor.Name);

            % Add threshold bands to navigator
            if obj.ShowThresholdBands
                obj.addNavigatorThresholdBands();
            end

            % Render navigator
            obj.NavigatorPlot.render();

            % Fix navigator axes limits
            xFull = [min(obj.Sensor.X), max(obj.Sensor.X)];
            yRange = [min(obj.Sensor.Y), max(obj.Sensor.Y)];
            yPad = (yRange(2) - yRange(1)) * 0.05;
            if yPad == 0; yPad = 1; end
            set(obj.hNavAxes, 'XLim', xFull, 'YLim', [yRange(1)-yPad, yRange(2)+yPad]);
            set(obj.hNavAxes, 'XLimMode', 'manual', 'YLimMode', 'manual');

            % Disable zoom/pan on navigator
            zoom(obj.hNavAxes, 'off');
            pan(obj.hNavAxes, 'off');

            % Add event overlays
            if ~isempty(obj.Events)
                obj.addEventShading();
                obj.addEventVerticalLines();
            end

            % Create navigator overlay
            obj.NavigatorOverlayObj = NavigatorOverlay(obj.hNavAxes);
            initRange = get(obj.hMainAxes, 'XLim');
            obj.NavigatorOverlayObj.setRange(initRange(1), initRange(2));

            % Wire bidirectional sync
            obj.NavigatorOverlayObj.OnRangeChanged = @(xMin, xMax) obj.onNavigatorRangeChanged(xMin, xMax);

            try
                obj.XLimListener = addlistener(obj.hMainAxes, 'XLim', 'PostSet', ...
                    @(s,e) obj.onMainXLimChanged());
            catch
                % Fallback for older MATLAB
            end

            % Set figure visible if standalone
            if obj.OwnsFigure
                set(obj.hFig, 'Visible', 'on');
                set(obj.hFig, 'CloseRequestFcn', @(~,~) obj.onFigureClose());
            end

            obj.IsRendered = true;
        end

        function setZoomRange(obj, xMin, xMax)
            if ~obj.IsRendered; return; end
            obj.IsPropagating = true;
            set(obj.hMainAxes, 'XLim', [xMin, xMax]);
            obj.NavigatorOverlayObj.setRange(xMin, xMax);
            obj.IsPropagating = false;
        end

        function [xMin, xMax] = getZoomRange(obj)
            if ~obj.IsRendered
                xMin = []; xMax = [];
                return;
            end
            lim = get(obj.hMainAxes, 'XLim');
            xMin = lim(1);
            xMax = lim(2);
        end

        function delete(obj)
            % Remove XLim listener
            if ~isempty(obj.XLimListener) && isvalid(obj.XLimListener)
                delete(obj.XLimListener);
            end

            % Delete navigator overlay
            if ~isempty(obj.NavigatorOverlayObj) && isvalid(obj.NavigatorOverlayObj)
                delete(obj.NavigatorOverlayObj);
            end

            % Close figure if we own it (guard against double-delete
            % when triggered from CloseRequestFcn)
            if obj.OwnsFigure && ~isempty(obj.hFig) && ishandle(obj.hFig)
                set(obj.hFig, 'CloseRequestFcn', 'closereq');
                delete(obj.hFig);
                obj.hFig = [];
            end
        end
    end

    methods (Access = private)
        function createLayout(obj)
            mainHeight = 1 - obj.NavigatorHeight;

            if ~isempty(obj.ParentPanel)
                % Embedded mode: create sub-panels inside parent
                container = obj.ParentPanel;
                obj.OwnsFigure = false;
            else
                % Standalone mode: create figure
                obj.hFig = figure('Visible', 'off', 'Name', obj.Title, ...
                    'NumberTitle', 'off', 'Position', [100 100 900 600]);
                container = obj.hFig;
                obj.OwnsFigure = true;
            end

            % Main panel (upper)
            obj.hMainPanel = uipanel('Parent', container, ...
                'Units', 'normalized', ...
                'Position', [0, obj.NavigatorHeight, 1, mainHeight], ...
                'BorderType', 'none');

            % Navigator panel (lower)
            obj.hNavPanel = uipanel('Parent', container, ...
                'Units', 'normalized', ...
                'Position', [0, 0, 1, obj.NavigatorHeight], ...
                'BorderType', 'none');

            % Create axes in each panel
            obj.hMainAxes = axes('Parent', obj.hMainPanel, ...
                'Units', 'normalized', 'Position', [0.08 0.12 0.88 0.82]);
            obj.hNavAxes = axes('Parent', obj.hNavPanel, ...
                'Units', 'normalized', 'Position', [0.08 0.15 0.88 0.75]);
        end

        function events = resolveEvents(~, eventsInput)
            if isempty(eventsInput)
                events = [];
                return;
            end

            if isa(eventsInput, 'EventStore')
                events = eventsInput.getEvents();
            elseif isa(eventsInput, 'Event')
                events = eventsInput;
            else
                error('SensorDetailPlot:invalidEvents', ...
                    'Events must be an EventStore or Event array.');
            end
        end

        function addNavigatorThresholdBands(obj)
            if isempty(obj.Sensor.ResolvedThresholds)
                return;
            end

            for i = 1:numel(obj.Sensor.ResolvedThresholds)
                th = obj.Sensor.ResolvedThresholds(i);

                % Determine color
                if ~isempty(th.Color)
                    bandColor = th.Color;
                elseif strcmp(th.Direction, 'upper')
                    bandColor = [1 0.2 0.2]; % red
                else
                    bandColor = [0.2 0.2 1]; % blue
                end

                % For bands: upper goes from threshold to YMax,
                % lower goes from YMin to threshold
                % Use mean of non-NaN threshold values for band level.
                % Note: time-varying step-function bands (direct patch)
                % are not yet implemented — this uses a constant band
                % at the mean active threshold value.
                thVal = mean(th.Y, 'omitnan');
                if isnan(thVal); continue; end

                if strcmp(th.Direction, 'upper')
                    yHigh = max(obj.Sensor.Y) + (max(obj.Sensor.Y) - min(obj.Sensor.Y)) * 0.05;
                    obj.NavigatorPlot.addBand(thVal, yHigh, ...
                        'FaceColor', bandColor, 'FaceAlpha', 0.10, ...
                        'EdgeColor', 'none', 'Label', th.Label);
                else
                    yLow = min(obj.Sensor.Y) - (max(obj.Sensor.Y) - min(obj.Sensor.Y)) * 0.05;
                    obj.NavigatorPlot.addBand(yLow, thVal, ...
                        'FaceColor', bandColor, 'FaceAlpha', 0.10, ...
                        'EdgeColor', 'none', 'Label', th.Label);
                end
            end
        end

        function addEventShading(obj)
            % Add event shaded regions to main plot
            if isempty(obj.Events); return; end

            % Filter events for this sensor
            sensorEvents = obj.filterEventsForSensor(obj.Events);
            if isempty(sensorEvents); return; end

            yLim = get(obj.hMainAxes, 'YLim');

            for i = 1:numel(sensorEvents)
                ev = sensorEvents(i);
                [color, alpha] = obj.eventColor(ev);

                % Create shaded patch
                xVerts = [ev.StartTime ev.StartTime ev.EndTime ev.EndTime];
                yVerts = [yLim(1) yLim(2) yLim(2) yLim(1)];

                hPatch = patch(obj.hMainAxes, xVerts, yVerts, color, ...
                    'FaceAlpha', alpha, 'EdgeColor', 'none', ...
                    'HandleVisibility', 'off');

                % Attach metadata to UserData
                ud = struct();
                ud.ThresholdLabel = ev.ThresholdLabel;
                ud.Direction = ev.Direction;
                ud.Duration = ev.Duration;
                ud.PeakValue = ev.PeakValue;
                ud.MeanValue = ev.MeanValue;
                ud.MinValue = ev.MinValue;
                ud.MaxValue = ev.MaxValue;
                ud.RmsValue = ev.RmsValue;
                ud.StdValue = ev.StdValue;
                ud.NumPoints = ev.NumPoints;
                set(hPatch, 'UserData', ud);
            end
        end

        function addEventVerticalLines(obj)
            % Add event vertical lines to navigator
            if isempty(obj.Events); return; end

            sensorEvents = obj.filterEventsForSensor(obj.Events);
            if isempty(sensorEvents); return; end

            yLim = get(obj.hNavAxes, 'YLim');
            hold(obj.hNavAxes, 'on');

            for i = 1:numel(sensorEvents)
                ev = sensorEvents(i);
                [color, ~] = obj.eventColor(ev);

                line(obj.hNavAxes, [ev.StartTime ev.StartTime], yLim, ...
                    'Color', color, 'LineWidth', 1, ...
                    'HandleVisibility', 'off');
            end

            hold(obj.hNavAxes, 'off');
        end

        function filtered = filterEventsForSensor(obj, events)
            if isempty(events)
                filtered = events;
                return;
            end
            mask = strcmp({events.SensorName}, obj.Sensor.Key);
            filtered = events(mask);
        end

        function [color, alpha] = eventColor(~, ev)
            label = ev.ThresholdLabel;
            isEscalated = ~isempty(regexpi(label, '(HH|LL)', 'once'));

            if strcmp(ev.Direction, 'high')
                if isEscalated
                    color = [0.9 0.1 0.1];   % red
                    alpha = 0.15;
                else
                    color = [1 0.6 0.2];     % orange
                    alpha = 0.12;
                end
            elseif strcmp(ev.Direction, 'low')
                if isEscalated
                    color = [0.1 0.1 0.7];   % dark blue
                    alpha = 0.15;
                else
                    color = [0.4 0.6 1];     % light blue
                    alpha = 0.12;
                end
            else
                color = [0.5 0.5 0.5];       % fallback gray
                alpha = 0.10;
            end
        end

        function onNavigatorRangeChanged(obj, xMin, xMax)
            if obj.IsPropagating; return; end
            obj.IsPropagating = true;
            if ishandle(obj.hMainAxes)
                set(obj.hMainAxes, 'XLim', [xMin, xMax]);
            end
            obj.IsPropagating = false;
        end

        function onMainXLimChanged(obj)
            if obj.IsPropagating; return; end
            if ~ishandle(obj.hMainAxes); return; end
            obj.IsPropagating = true;
            lim = get(obj.hMainAxes, 'XLim');
            if ~isempty(obj.NavigatorOverlayObj) && isvalid(obj.NavigatorOverlayObj)
                obj.NavigatorOverlayObj.setRange(lim(1), lim(2));
            end
            obj.IsPropagating = false;
        end

        function onFigureClose(obj)
            delete(obj);
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); results = runtests('test_SensorDetailPlot'); disp(results)"`
Expected: All 8 tests PASS

- [ ] **Step 5: Commit**

```bash
git add libs/FastSense/SensorDetailPlot.m tests/test_SensorDetailPlot.m
git commit -m "feat: add SensorDetailPlot with two-panel layout and navigator sync"
```

---

### Task 4: SensorDetailPlot — Threshold Tests

**Files:**
- Modify: `tests/test_SensorDetailPlot.m`

- [ ] **Step 1: Add threshold-specific tests**

Append to `tests/test_SensorDetailPlot.m`:

```matlab
%% Thresholds in main plot
function test_thresholds_shown_when_enabled(testCase)
    s = createSensorWithThreshold();
    sdp = SensorDetailPlot(s, 'ShowThresholds', true);
    sdp.render();
    verifyGreaterThanOrEqual(testCase, numel(sdp.MainPlot.Thresholds), 1);
    delete(sdp);
end

function test_thresholds_hidden_when_disabled(testCase)
    s = createSensorWithThreshold();
    sdp = SensorDetailPlot(s, 'ShowThresholds', false);
    sdp.render();
    verifyEqual(testCase, numel(sdp.MainPlot.Thresholds), 0);
    delete(sdp);
end

%% Threshold bands in navigator
function test_navigator_has_threshold_bands(testCase)
    s = createSensorWithThreshold();
    sdp = SensorDetailPlot(s, 'ShowThresholdBands', true);
    sdp.render();
    verifyGreaterThanOrEqual(testCase, numel(sdp.NavigatorPlot.Bands), 1);
    delete(sdp);
end

function test_navigator_no_bands_when_disabled(testCase)
    s = createSensorWithThreshold();
    sdp = SensorDetailPlot(s, 'ShowThresholdBands', false);
    sdp.render();
    verifyEqual(testCase, numel(sdp.NavigatorPlot.Bands), 0);
    delete(sdp);
end

%% Helper: create fresh sensor with threshold (avoids shared handle mutation)
function s = createSensorWithThreshold()
    s = Sensor('test_th', 'Name', 'Threshold Test');
    t = linspace(0, 100, 1000);
    s.X = t;
    s.Y = 50 + 10*sin(2*pi*t/20) + randn(1, numel(t));
    sc = StateChannel('mode');
    sc.X = [0 100];
    sc.Y = [1 1];
    s.addStateChannel(sc);
    s.addThresholdRule(ThresholdRule(struct('mode', 1), 65, ...
        'Direction', 'upper', 'Label', 'H Warning'));
    s.resolve();
end
```

- [ ] **Step 2: Run tests**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); results = runtests('test_SensorDetailPlot'); disp(results)"`
Expected: All 12 tests PASS

- [ ] **Step 3: Commit**

```bash
git add tests/test_SensorDetailPlot.m
git commit -m "test: add threshold display tests for SensorDetailPlot"
```

---

## Chunk 3: Events, FastSenseFigure Integration, and Example

### Task 5: SensorDetailPlot — Event Overlay Tests

**Files:**
- Modify: `tests/test_SensorDetailPlot.m`

- [ ] **Step 1: Add event overlay tests**

Append to `tests/test_SensorDetailPlot.m`:

```matlab
%% Event shading
function test_event_shading_in_main_plot(testCase)
    s = testCase.TestData.sensor;

    % Create mock events
    ev1 = Event(20, 25, 'test_pressure', 'H Warning', 65, 'high');
    ev2 = Event(50, 55, 'test_pressure', 'HH Alarm', 70, 'high');

    sdp = SensorDetailPlot(s, 'Events', [ev1, ev2]);
    sdp.render();

    % Check that patches exist in the main axes with UserData
    children = get(sdp.MainPlot.hAxes, 'Children');
    patchCount = 0;
    for c = children'
        if isa(c, 'matlab.graphics.primitive.Patch')
            ud = get(c, 'UserData');
            if isstruct(ud) && isfield(ud, 'ThresholdLabel')
                patchCount = patchCount + 1;
            end
        end
    end
    verifyGreaterThanOrEqual(testCase, patchCount, 2);
    delete(sdp);
end

%% Event vertical lines in navigator
function test_event_lines_in_navigator(testCase)
    s = testCase.TestData.sensor;

    ev1 = Event(20, 25, 'test_pressure', 'H Warning', 65, 'high');

    sdp = SensorDetailPlot(s, 'Events', [ev1]);
    sdp.render();

    % Check that a line exists at StartTime in navigator axes
    children = get(sdp.NavigatorPlot.hAxes, 'Children');
    lineFound = false;
    for c = children'
        if isa(c, 'matlab.graphics.chart.primitive.Line') || ...
           isa(c, 'matlab.graphics.primitive.Line')
            xd = get(c, 'XData');
            if numel(xd) == 2 && abs(xd(1) - 20) < 0.1
                lineFound = true;
                break;
            end
        end
    end
    verifyTrue(testCase, lineFound);
    delete(sdp);
end

%% Events from EventStore
function test_events_from_eventstore(testCase)
    s = testCase.TestData.sensor;

    % Create EventStore and append events
    tmpFile = [tempname, '.mat'];
    store = EventStore(tmpFile);
    ev1 = Event(20, 25, 'test_pressure', 'H Warning', 65, 'high');
    ev2 = Event(30, 35, 'other_sensor', 'H Warning', 65, 'high');
    store.append([ev1, ev2]);

    sdp = SensorDetailPlot(s, 'Events', store);
    sdp.render();

    % Only ev1 should appear (filtered by sensor key)
    children = get(sdp.MainPlot.hAxes, 'Children');
    patchCount = 0;
    for c = children'
        if isa(c, 'matlab.graphics.primitive.Patch')
            ud = get(c, 'UserData');
            if isstruct(ud) && isfield(ud, 'ThresholdLabel')
                patchCount = patchCount + 1;
            end
        end
    end
    verifyEqual(testCase, patchCount, 1);

    delete(sdp);
    if exist(tmpFile, 'file'); delete(tmpFile); end
end

%% Event color mapping
function test_event_color_high(testCase)
    s = testCase.TestData.sensor;
    ev = Event(20, 25, 'test_pressure', 'H Warning', 65, 'high');
    sdp = SensorDetailPlot(s, 'Events', [ev]);
    sdp.render();

    children = get(sdp.MainPlot.hAxes, 'Children');
    for c = children'
        if isa(c, 'matlab.graphics.primitive.Patch')
            ud = get(c, 'UserData');
            if isstruct(ud) && isfield(ud, 'Direction') && strcmp(ud.Direction, 'high')
                fc = get(c, 'FaceColor');
                % Should be orange-ish [1 0.6 0.2]
                verifyGreaterThan(testCase, fc(1), 0.5);  % red channel high
                break;
            end
        end
    end
    delete(sdp);
end

function test_event_color_escalated(testCase)
    s = testCase.TestData.sensor;
    ev = Event(20, 25, 'test_pressure', 'HH Alarm', 70, 'high');
    sdp = SensorDetailPlot(s, 'Events', [ev]);
    sdp.render();

    children = get(sdp.MainPlot.hAxes, 'Children');
    for c = children'
        if isa(c, 'matlab.graphics.primitive.Patch')
            ud = get(c, 'UserData');
            if isstruct(ud) && isfield(ud, 'ThresholdLabel') && ...
               ~isempty(regexpi(ud.ThresholdLabel, 'HH'))
                fc = get(c, 'FaceColor');
                % Should be red-ish [0.9 0.1 0.1]
                verifyGreaterThan(testCase, fc(1), 0.7);
                verifyLessThan(testCase, fc(2), 0.3);
                break;
            end
        end
    end
    delete(sdp);
end

%% UserData completeness
function test_event_patch_userdata_fields(testCase)
    s = testCase.TestData.sensor;
    ev = Event(20, 25, 'test_pressure', 'H Warning', 65, 'high');
    % Event is a value class with private setters — use setStats()
    % setStats(peak, numPoints, min, max, mean, rms, std)
    ev = ev.setStats(67, 50, 64, 67, 66, 66.1, 0.8);

    sdp = SensorDetailPlot(s, 'Events', [ev]);
    sdp.render();

    children = get(sdp.MainPlot.hAxes, 'Children');
    for c = children'
        if isa(c, 'matlab.graphics.primitive.Patch')
            ud = get(c, 'UserData');
            if isstruct(ud) && isfield(ud, 'ThresholdLabel')
                expectedFields = {'ThresholdLabel', 'Direction', 'Duration', ...
                    'PeakValue', 'MeanValue', 'MinValue', 'MaxValue', ...
                    'RmsValue', 'StdValue', 'NumPoints'};
                for f = expectedFields
                    verifyTrue(testCase, isfield(ud, f{1}), ...
                        sprintf('Missing UserData field: %s', f{1}));
                end
                break;
            end
        end
    end
    delete(sdp);
end
```

- [ ] **Step 2: Run tests**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); results = runtests('test_SensorDetailPlot'); disp(results)"`
Expected: All 19 tests PASS

- [ ] **Step 3: Commit**

```bash
git add tests/test_SensorDetailPlot.m
git commit -m "test: add event overlay tests for SensorDetailPlot"
```

---

### Task 6: FastSenseFigure — tilePanel Method

**Files:**
- Modify: `libs/FastSense/FastSenseFigure.m:211-251` (add after `axes(n)` method)
- Modify: `tests/test_SensorDetailPlot.m` (add integration test)

- [ ] **Step 1: Write failing test for tilePanel**

Append to `tests/test_SensorDetailPlot.m`:

```matlab
%% FastSenseFigure tilePanel integration
function test_tilePanel_returns_uipanel(testCase)
    fig = FastSenseFigure(2, 1);
    hp = fig.tilePanel(1);
    verifyTrue(testCase, isa(hp, 'matlab.ui.container.Panel'));
    delete(fig);
end

function test_tilePanel_conflict_with_tile(testCase)
    fig = FastSenseFigure(2, 1);
    fig.tile(1);  % Occupy tile 1 as FastSense
    verifyError(testCase, @() fig.tilePanel(1), 'FastSenseFigure:tileConflict');
    delete(fig);
end

%% Embedded in FastSenseFigure
function test_embedded_in_figure_tile(testCase)
    s = testCase.TestData.sensor;
    fig = FastSenseFigure(1, 1);
    hp = fig.tilePanel(1);
    sdp = SensorDetailPlot(s, 'Parent', hp);
    sdp.render();
    verifyTrue(testCase, sdp.IsRendered);
    verifyClass(testCase, sdp.MainPlot, ?FastSense);
    delete(sdp);
    delete(fig);
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); results = runtests('test_SensorDetailPlot', 'ProcedureName', 'test_tilePanel*'); disp(results)"`
Expected: FAIL — tilePanel method not found

- [ ] **Step 3: Read FastSenseFigure.m to find insertion point**

Read: `libs/FastSense/FastSenseFigure.m:211-260` to see the `axes(n)` method and find where to add `tilePanel(n)`.

- [ ] **Step 4: Add tilePanel method to FastSenseFigure**

Add after the `axes(n)` method (around line 251) in `libs/FastSense/FastSenseFigure.m`. The method follows the same pattern as `axes(n)`:

```matlab
        function hp = tilePanel(obj, n)
            %TILEPANEL  Get or create a uipanel for tile n.
            %   hp = fig.tilePanel(n) returns a uipanel handle at the
            %   computed grid position for tile n. Use this to embed
            %   composite widgets (e.g. SensorDetailPlot) into a tile.
            %
            %   Throws an error if tile n is already occupied by a
            %   FastSense (via tile()) or raw axes (via axes()).

            nTiles = obj.Grid(1) * obj.Grid(2);
            if n < 1 || n > nTiles
                error('FastSenseFigure:invalidTile', ...
                    'Tile index %d is out of range [1, %d].', n, nTiles);
            end

            % Idempotency: return cached panel if already created
            if ~isempty(obj.TileAxes{n}) && isa(obj.TileAxes{n}, 'matlab.ui.container.Panel')
                hp = obj.TileAxes{n};
                return;
            end

            % Conflict check: occupied by FastSense?
            if ~isempty(obj.Tiles{n})
                error('FastSenseFigure:tileConflict', ...
                    'Tile %d is a FastSense tile. Use tile(%d) to access it.', n, n);
            end

            % Conflict check: occupied by raw axes?
            if obj.RawAxesTiles(n)
                error('FastSenseFigure:tileConflict', ...
                    'Tile %d is a raw axes tile. Use axes(%d) to access it.', n, n);
            end

            % Create panel at tile position
            pos = obj.computeTilePosition(n);
            hp = uipanel('Parent', obj.hFigure, ...
                'Units', 'normalized', 'Position', pos, ...
                'BorderType', 'none');

            % Store panel handle (reuses TileAxes cell for storage)
            obj.TileAxes{n} = hp;
            % Mark as occupied to prevent future tile()/axes() conflicts
            obj.RawAxesTiles(n) = true;
        end
```

- [ ] **Step 5: Run tests**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); results = runtests('test_SensorDetailPlot'); disp(results)"`
Expected: All 22 tests PASS

- [ ] **Step 6: Also make `IsRendered` accessible for test**

In `libs/FastSense/SensorDetailPlot.m`, change `IsRendered` access from `(Access = private)` to `(SetAccess = private, GetAccess = ?matlab.unittest.TestCase)` or simply move it to the `(SetAccess = private, GetAccess = public)` block since it's a useful read-only property:

Move `IsRendered` from the private properties block to the public-readable block:

```matlab
    properties (SetAccess = private, GetAccess = public)
        NavigatorHeight
        ShowThresholds
        ShowThresholdBands
        Events
        ShowEventLabels
        Theme
        Title
        IsRendered          % Whether render() has been called
    end
```

- [ ] **Step 7: Run all tests**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); results = runtests('test_SensorDetailPlot'); disp(results)"`
Expected: All 22 tests PASS

- [ ] **Step 8: Commit**

```bash
git add libs/FastSense/FastSenseFigure.m libs/FastSense/SensorDetailPlot.m tests/test_SensorDetailPlot.m
git commit -m "feat: add tilePanel method to FastSenseFigure for composite widget embedding"
```

---

### Task 7: Example Script

**Files:**
- Create: `examples/example_sensor_detail.m`

- [ ] **Step 1: Create the example script**

Create `examples/example_sensor_detail.m`:

```matlab
%% example_sensor_detail.m — SensorDetailPlot demo
%
% Demonstrates:
%   1. Standalone sensor detail plot with thresholds
%   2. Adding events from EventStore
%   3. Embedding in a FastSenseFigure tile

%% Setup path
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'libs', 'FastSense'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'libs', 'SensorThreshold'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'libs', 'EventDetection'));

%% 1. Create sensor with realistic data
t = linspace(0, 300, 100000);  % 5 minutes at ~333 Hz
data = 50 + 8*sin(2*pi*t/60) + 3*randn(1, numel(t));

% Add a few spikes to trigger events
data(30000:30200) = data(30000:30200) + 20;  % spike at t~90
data(70000:70300) = data(70000:70300) + 25;  % bigger spike at t~210
data(50000:50100) = data(50000:50100) - 18;  % dip at t~150

s = Sensor('temperature', 'Name', 'Chamber Temperature');
s.X = t;
s.Y = data;

% Add state channel (constant state for simplicity)
sc = StateChannel('mode');
sc.X = [0 300];
sc.Y = [1 1];
s.addStateChannel(sc);

% Add threshold rules
s.addThresholdRule(ThresholdRule(struct('mode', 1), 62, ...
    'Direction', 'upper', 'Label', 'H Warning', ...
    'Color', [1 0.75 0], 'LineStyle', '--'));
s.addThresholdRule(ThresholdRule(struct('mode', 1), 70, ...
    'Direction', 'upper', 'Label', 'HH Alarm', ...
    'Color', [1 0 0], 'LineStyle', '-'));
s.addThresholdRule(ThresholdRule(struct('mode', 1), 38, ...
    'Direction', 'lower', 'Label', 'L Warning', ...
    'Color', [0.3 0.6 1], 'LineStyle', '--'));

s.resolve();

%% 2. Create events matching the spikes
% Event is a value class — use setStats(peak, numPoints, min, max, mean, rms, std)
d1 = data(30000:30200);
ev1 = Event(t(30000), t(30200), 'temperature', 'H Warning', 62, 'high');
ev1 = ev1.setStats(max(d1), numel(d1), min(d1), max(d1), mean(d1), rms(d1), std(d1));

d2 = data(70000:70300);
ev2 = Event(t(70000), t(70300), 'temperature', 'HH Alarm', 70, 'high');
ev2 = ev2.setStats(max(d2), numel(d2), min(d2), max(d2), mean(d2), rms(d2), std(d2));

d3 = data(50000:50100);
ev3 = Event(t(50000), t(50100), 'temperature', 'L Warning', 38, 'low');
ev3 = ev3.setStats(min(d3), numel(d3), min(d3), max(d3), mean(d3), rms(d3), std(d3));

events = [ev1, ev2, ev3];

%% 3. Standalone with events
fprintf('=== SensorDetailPlot: Standalone with events ===\n');
sdp = SensorDetailPlot(s, ...
    'Theme', 'dark', ...
    'Events', events, ...
    'Title', 'Chamber Temperature — Detail View');
sdp.render();

% Programmatic zoom to the first event
sdp.setZoomRange(t(29000), t(31500));

fprintf('  Try: zoom/pan in the main plot, or drag the navigator highlight.\n');
fprintf('  Press any key to continue...\n');
pause;

%% 4. Standalone without events (thresholds only)
fprintf('=== SensorDetailPlot: Thresholds only ===\n');
sdp2 = SensorDetailPlot(s, ...
    'Theme', 'light', ...
    'NavigatorHeight', 0.25, ...
    'Title', 'Chamber Temperature — Thresholds Only');
sdp2.render();

fprintf('  Press any key to continue...\n');
pause;

%% 5. Embedded in FastSenseFigure
fprintf('=== SensorDetailPlot: Embedded in FastSenseFigure ===\n');
fig = FastSenseFigure(1, 2, 'Theme', 'dark', 'Name', 'Sensor Dashboard');
sdp3 = SensorDetailPlot(s, 'Parent', fig.tilePanel(1), ...
    'Events', events, 'Title', 'Temperature');
sdp3.render();

% Second tile: plain FastSense for comparison
fp = fig.tile(2);
fp.addLine(t, data, 'DisplayName', 'Raw Data');
fig.tileTitle(2, 'Raw Data');
fig.renderAll();

fprintf('  Two tiles: SensorDetailPlot + plain FastSense\n');
fprintf('  Press any key to exit...\n');
pause;

fprintf('Done.\n');
```

- [ ] **Step 2: Run example to verify it works**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "run('examples/example_sensor_detail.m')"`
Expected: Two figure windows open showing the sensor detail plots. No errors.

- [ ] **Step 3: Commit**

```bash
git add examples/example_sensor_detail.m
git commit -m "feat: add example_sensor_detail demo script"
```

---

### Task 8: Run Full Test Suite

- [ ] **Step 1: Run all tests to ensure nothing is broken**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "addpath('tests'); results = runtests('tests'); disp(table(results))"`
Expected: All tests PASS (existing tests + new tests)

- [ ] **Step 2: Fix any failures**

If any existing tests fail, investigate and fix. The new classes should not affect existing behavior since they are additive (new files) with only one modification to `FastSenseFigure.m` (adding a new method, no changes to existing methods).

- [ ] **Step 3: Final commit if fixes were needed**

```bash
git add -A
git commit -m "fix: resolve any test issues from SensorDetailPlot integration"
```
