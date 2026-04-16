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
    test_legacy_sensor_still_works();

    TagRegistry.clear();
    fprintf('    All 4 sensor_detail_plot_tag tests passed.\n');
end

function test_sensor_tag_construct()
    TagRegistry.clear();
    st = makePhase1009Fixtures.makeSensorTag('sdp_press_a', 'Units', 'bar');
    sdp = SensorDetailPlot(st);
    assert(~isempty(sdp.TagRef), ...
        'test_sensor_detail_plot_tag: SensorTag construct -> TagRef set');
    assert(isempty(sdp.Sensor), ...
        'test_sensor_detail_plot_tag: SensorTag construct -> Sensor empty');
    assert(sdp.TagRef == st, ...
        'test_sensor_detail_plot_tag: TagRef same handle');
end

function test_monitor_tag_construct()
    TagRegistry.clear();
    st = makePhase1009Fixtures.makeSensorTag('sdp_press_b');
    m  = makePhase1009Fixtures.makeMonitorTag('sdp_press_hi', st);
    sdp = SensorDetailPlot(m);
    assert(~isempty(sdp.TagRef), ...
        'test_sensor_detail_plot_tag: MonitorTag construct -> TagRef set');
    assert(isempty(sdp.Sensor), ...
        'test_sensor_detail_plot_tag: MonitorTag construct -> Sensor empty');
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

function test_legacy_sensor_still_works()
    s = Sensor('sdp_legacy', 'Name', 'LegacySensor');
    s.X = 1:30;
    s.Y = (1:30) * 0.1;
    sdp = SensorDetailPlot(s);
    assert(~isempty(sdp.Sensor), ...
        'test_sensor_detail_plot_tag: legacy Sensor construct -> Sensor set');
    assert(isempty(sdp.TagRef), ...
        'test_sensor_detail_plot_tag: legacy Sensor construct -> TagRef empty');
end

function add_sensor_detail_plot_tag_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();
    addpath(fullfile(repo_root, 'tests', 'suite'));
end
