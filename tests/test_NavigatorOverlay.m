function tests = test_NavigatorOverlay
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (MATLAB-only test)\n');
        tests = [];
        return;
    end
    tests = functiontests(localfunctions);
end

function setup(testCase)
    addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'libs', 'FastPlot'));
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
