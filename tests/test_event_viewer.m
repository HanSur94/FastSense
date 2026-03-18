function test_event_viewer()
%TEST_EVENT_VIEWER Tests for EventViewer figure UI.
%   Note: these tests run headless — they verify object creation and
%   data wiring, not visual rendering.

    add_event_path();

    % --- Setup events ---
    e1 = Event(10, 25, 'Temperature', 'warning high', 80, 'upper');
    e1.setStats(95.2, 150, 72, 95.2, 87.3, 88.1, 4.21);
    e2 = Event(50, 55, 'Pressure', 'low alarm', 5, 'lower');
    e2.setStats(2.1, 50, 2.1, 6.8, 4.5, 4.7, 1.2);
    e3 = Event(30, 40, 'Temperature', 'critical high', 100, 'upper');
    e3.setStats(110, 80, 95, 110, 103, 104, 3.5);
    events = [e1, e2, e3];

    sensorData(1).name = 'Temperature';
    sensorData(1).t = 1:100;
    sensorData(1).y = 50 + 30*sin((1:100)/10);
    sensorData(2).name = 'Pressure';
    sensorData(2).t = 1:100;
    sensorData(2).y = 10 + 5*sin((1:100)/8);

    colors = containers.Map();
    colors('warning high') = [1 0.8 0];
    colors('critical high') = [1 0 0];
    colors('low alarm') = [0 0.5 1];

    % testConstructorEventsOnly
    viewer = EventViewer(events);
    assert(~isempty(viewer.hFigure), 'eventsOnly: figure created');
    assert(ishandle(viewer.hFigure), 'eventsOnly: valid handle');
    close(viewer.hFigure);

    % testConstructorWithSensorData
    viewer = EventViewer(events, sensorData);
    assert(~isempty(viewer.SensorData), 'withData: SensorData stored');
    close(viewer.hFigure);

    % testConstructorWithColors
    viewer = EventViewer(events, sensorData, colors);
    assert(~isempty(viewer.ThresholdColors), 'withColors: colors stored');
    close(viewer.hFigure);

    % testUpdate — should not error
    viewer = EventViewer(events, sensorData);
    e4 = Event(70, 75, 'Temperature', 'warning high', 80, 'upper');
    e4.setStats(88, 50, 78, 88, 83, 84, 2.1);
    viewer.update([events, e4]);
    close(viewer.hFigure);

    % testFilterSensors — getSensorNames returns unique sensor names
    viewer = EventViewer(events);
    names = viewer.getSensorNames();
    assert(numel(names) == 2, 'filterSensors: 2 unique sensors');
    assert(any(strcmp(names, 'Temperature')), 'filterSensors: has Temperature');
    assert(any(strcmp(names, 'Pressure')), 'filterSensors: has Pressure');
    close(viewer.hFigure);

    % testFilterLabels — getThresholdLabels returns unique labels
    viewer = EventViewer(events);
    labels = viewer.getThresholdLabels();
    assert(numel(labels) == 3, 'filterLabels: 3 unique labels');
    close(viewer.hFigure);

    test_bar_positions_cached();

    fprintf('    All 7 event_viewer tests passed.\n');
end

function test_bar_positions_cached()
    e1 = Event(10, 25, 'Temperature', 'warning high', 80, 'upper');
    e1.setStats(95.2, 150, 72, 95.2, 87.3, 88.1, 4.21);
    e2 = Event(50, 55, 'Pressure', 'low alarm', 5, 'lower');
    e2.setStats(2.1, 50, 2.1, 6.8, 4.5, 4.7, 1.2);
    events = [e1, e2];

    viewer = EventViewer(events);
    assert(~isempty(viewer.BarPositions), 'bar_positions_not_empty');
    assert(size(viewer.BarPositions, 1) == numel(viewer.BarRects), 'bar_positions_count');
    assert(size(viewer.BarPositions, 2) == 4, 'bar_positions_cols');
    assert(all(viewer.BarPositions(:,3) > 0), 'bar_widths_positive');
    assert(all(viewer.BarPositions(:,4) > 0), 'bar_heights_positive');
    close(viewer.hFigure);
    fprintf('  PASS: test_bar_positions_cached\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); setup();
end
