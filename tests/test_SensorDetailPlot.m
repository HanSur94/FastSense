function tests = test_SensorDetailPlot
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

%% Render creates two FastPlot instances
function test_render_creates_main_and_navigator(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    sdp.render();
    verifyClass(testCase, sdp.MainPlot, ?FastPlot);
    verifyClass(testCase, sdp.NavigatorPlot, ?FastPlot);
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
    s.addThresholdRule(struct('mode', 1), 65, ...
        'Direction', 'upper', 'Label', 'H Warning');
    s.resolve();
end

%% Event shading
function test_event_shading_in_main_plot(testCase)
    s = testCase.TestData.sensor;

    % Create mock events
    ev1 = Event(20, 25, 'test_pressure', 'H Warning', 65, 'upper');
    ev2 = Event(50, 55, 'test_pressure', 'HH Alarm', 70, 'upper');

    sdp = SensorDetailPlot(s, 'Events', [ev1, ev2]);
    sdp.render();

    % Check that patches exist in the main axes with UserData
    % Use findall to include HandleVisibility='off' patches
    patches = findall(sdp.MainPlot.hAxes, 'Type', 'patch');
    patchCount = 0;
    for i = 1:numel(patches)
        ud = get(patches(i), 'UserData');
        if isstruct(ud) && isfield(ud, 'ThresholdLabel')
            patchCount = patchCount + 1;
        end
    end
    verifyGreaterThanOrEqual(testCase, patchCount, 2);
    delete(sdp);
end

%% Event vertical lines in navigator
function test_event_lines_in_navigator(testCase)
    s = testCase.TestData.sensor;

    ev1 = Event(20, 25, 'test_pressure', 'H Warning', 65, 'upper');

    sdp = SensorDetailPlot(s, 'Events', [ev1]);
    sdp.render();

    % Check that a line exists at StartTime in navigator axes
    % Use findall to include HandleVisibility='off' lines
    lines = findall(sdp.NavigatorPlot.hAxes, 'Type', 'line');
    lineFound = false;
    for i = 1:numel(lines)
        xd = get(lines(i), 'XData');
        if numel(xd) == 2 && abs(xd(1) - 20) < 0.1
            lineFound = true;
            break;
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
    ev1 = Event(20, 25, 'test_pressure', 'H Warning', 65, 'upper');
    ev2 = Event(30, 35, 'other_sensor', 'H Warning', 65, 'upper');
    store.append([ev1, ev2]);

    sdp = SensorDetailPlot(s, 'Events', store);
    sdp.render();

    % Only ev1 should appear (filtered by sensor key)
    % Use findall to include HandleVisibility='off' patches
    patches = findall(sdp.MainPlot.hAxes, 'Type', 'patch');
    patchCount = 0;
    for i = 1:numel(patches)
        ud = get(patches(i), 'UserData');
        if isstruct(ud) && isfield(ud, 'ThresholdLabel')
            patchCount = patchCount + 1;
        end
    end
    verifyEqual(testCase, patchCount, 1);

    delete(sdp);
    if exist(tmpFile, 'file'); delete(tmpFile); end
end

%% Event color mapping
function test_event_color_high(testCase)
    s = testCase.TestData.sensor;
    ev = Event(20, 25, 'test_pressure', 'H Warning', 65, 'upper');
    sdp = SensorDetailPlot(s, 'Events', [ev]);
    sdp.render();

    patches = findall(sdp.MainPlot.hAxes, 'Type', 'patch');
    foundPatch = false;
    for i = 1:numel(patches)
        ud = get(patches(i), 'UserData');
        if isstruct(ud) && isfield(ud, 'Direction') && strcmp(ud.Direction, 'upper')
            fc = get(patches(i), 'FaceColor');
            % Should be orange-ish [1 0.6 0.2]
            verifyGreaterThan(testCase, fc(1), 0.5);  % red channel high
            foundPatch = true;
            break;
        end
    end
    verifyTrue(testCase, foundPatch, 'No event patch found with Direction=upper');
    delete(sdp);
end

function test_event_color_escalated(testCase)
    s = testCase.TestData.sensor;
    ev = Event(20, 25, 'test_pressure', 'HH Alarm', 70, 'upper');
    sdp = SensorDetailPlot(s, 'Events', [ev]);
    sdp.render();

    patches = findall(sdp.MainPlot.hAxes, 'Type', 'patch');
    foundPatch = false;
    for i = 1:numel(patches)
        ud = get(patches(i), 'UserData');
        if isstruct(ud) && isfield(ud, 'ThresholdLabel') && ...
           ~isempty(regexpi(ud.ThresholdLabel, 'HH'))
            fc = get(patches(i), 'FaceColor');
            % Should be red-ish [0.9 0.1 0.1]
            verifyGreaterThan(testCase, fc(1), 0.7);
            verifyLessThan(testCase, fc(2), 0.3);
            foundPatch = true;
            break;
        end
    end
    verifyTrue(testCase, foundPatch, 'No event patch found with HH label');
    delete(sdp);
end

%% UserData completeness
function test_event_patch_userdata_fields(testCase)
    s = testCase.TestData.sensor;
    ev = Event(20, 25, 'test_pressure', 'H Warning', 65, 'upper');
    % Event is a handle class with private setters — use setStats()
    % setStats(peak, numPoints, min, max, mean, rms, std)
    ev.setStats(67, 50, 64, 67, 66, 66.1, 0.8);

    sdp = SensorDetailPlot(s, 'Events', [ev]);
    sdp.render();

    patches = findall(sdp.MainPlot.hAxes, 'Type', 'patch');
    foundPatch = false;
    for i = 1:numel(patches)
        ud = get(patches(i), 'UserData');
        if isstruct(ud) && isfield(ud, 'ThresholdLabel')
            expectedFields = {'ThresholdLabel', 'Direction', 'Duration', ...
                'PeakValue', 'MeanValue', 'MinValue', 'MaxValue', ...
                'RmsValue', 'StdValue', 'NumPoints'};
            for f = expectedFields
                verifyTrue(testCase, isfield(ud, f{1}), ...
                    sprintf('Missing UserData field: %s', f{1}));
            end
            foundPatch = true;
            break;
        end
    end
    verifyTrue(testCase, foundPatch, 'No event patch found with ThresholdLabel');
    delete(sdp);
end

%% FastPlotGrid tilePanel integration
function test_tilePanel_returns_uipanel(testCase)
    fig = FastPlotGrid(2, 1);
    hp = fig.tilePanel(1);
    verifyTrue(testCase, isa(hp, 'matlab.ui.container.Panel'));
    delete(fig);
end

function test_tilePanel_conflict_with_tile(testCase)
    fig = FastPlotGrid(2, 1);
    fig.tile(1);  % Occupy tile 1 as FastPlot
    verifyError(testCase, @() fig.tilePanel(1), 'FastPlotGrid:tileConflict');
    delete(fig);
end

%% Embedded in FastPlotGrid
function test_embedded_in_figure_tile(testCase)
    s = testCase.TestData.sensor;
    fig = FastPlotGrid(1, 1);
    hp = fig.tilePanel(1);
    sdp = SensorDetailPlot(s, 'Parent', hp);
    sdp.render();
    verifyTrue(testCase, sdp.IsRendered);
    verifyClass(testCase, sdp.MainPlot, ?FastPlot);
    delete(sdp);
    delete(fig);
end
