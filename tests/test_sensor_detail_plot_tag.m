function test_sensor_detail_plot_tag()
%TEST_SENSOR_DETAIL_PLOT_TAG Octave flat tests for SensorDetailPlot Tag input.
%   Phase 1009 Plan 01 — verifies SensorDetailPlot accepts a Tag as its
%   first positional argument, stores it in TagRef, preserves the legacy
%   Sensor construction path, and errors on non-Tag/Sensor inputs.
%
%   See also TestSensorDetailPlotTag, makePhase1009Fixtures.

    add_sensor_detail_plot_tag_path();
    TagRegistry.clear();

    test_sensor_tag_construct();
    test_monitor_tag_construct();
    test_invalid_input_error();
    test_tag_construct_with_sensortag();

    TagRegistry.clear();
    fprintf('    All 4 sensor_detail_plot_tag tests passed.\n');
end

function test_sensor_tag_construct()
    TagRegistry.clear();
    st = makePhase1009Fixtures.makeSensorTag('sdp_press_a', 'Units', 'bar');
    sdp = SensorDetailPlot(st);
    assert(~isempty(sdp.TagRef), ...
        'test_sensor_detail_plot_tag: SensorTag construct -> TagRef set');
    assert(strcmp(sdp.TagRef.Key, 'sdp_press_a'), ...
        'test_sensor_detail_plot_tag: TagRef.Key matches input');
end

function test_monitor_tag_construct()
    TagRegistry.clear();
    st = makePhase1009Fixtures.makeSensorTag('sdp_press_b');
    m  = makePhase1009Fixtures.makeMonitorTag('sdp_press_hi', st);
    sdp = SensorDetailPlot(m);
    assert(~isempty(sdp.TagRef), ...
        'test_sensor_detail_plot_tag: MonitorTag construct -> TagRef set');
end

function test_invalid_input_error()
    ok = false;
    try
        SensorDetailPlot(42);
    catch ex
        ok = ~isempty(strfind(ex.identifier, 'SensorDetailPlot:invalidInput'));
    end
    assert(ok, ...
        'test_sensor_detail_plot_tag: invalid input raises SensorDetailPlot:invalidInput');
end

function test_tag_construct_with_sensortag()
    s = SensorTag('sdp_legacy', 'Name', 'LegacySensor');
    s.updateData(1:30, (1:30) * 0.1);
    sdp = SensorDetailPlot(s);
    assert(~isempty(sdp.TagRef), ...
        'test_sensor_detail_plot_tag: SensorTag construct -> TagRef set');
end

function add_sensor_detail_plot_tag_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();
    addpath(fullfile(repo_root, 'tests', 'suite'));
end
