function test_gauge_widget()
%TEST_GAUGE_WIDGET Tests for GaugeWidget with Thresholds API.
%   Verifies that GaugeWidget derives range from Sensor.Thresholds.allValues().

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (known Octave classdef limitation)\n');
        return;
    end

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    nPassed = 0;

    % --- Test 1: default Range is [0 100] with no sensor ---
    w1 = GaugeWidget('Title', 'Pressure', 'ValueFcn', @() 50, 'Units', 'bar');
    assert(isequal(w1.Range, [0 100]), 'Default Range should be [0 100]');
    assert(strcmp(w1.Style, 'arc'), 'Default Style should be arc');
    assert(strcmp(w1.Units, 'bar'), 'Units should be set');
    nPassed = nPassed + 1;

    % --- Test 2: Range auto-derives from Threshold.allValues() ---
    s2 = SensorTag('P-201', 'Name', 'Pressure');
    s2.updateData([1 2 3], [40 50 60]);
    tLo = Threshold('P201_lo', 'Name', 'Lo', 'Direction', 'lower');
    tLo.addCondition(struct(), 30);
    s2.addThreshold(tLo);
    tHi = Threshold('P201_hi', 'Name', 'Hi', 'Direction', 'upper');
    tHi.addCondition(struct(), 80);
    s2.addThreshold(tHi);
    w2 = GaugeWidget('Sensor', s2);
    assert(isequal(w2.Range, [30 80]), ...
        sprintf('Range should auto-derive from Threshold values, got [%g %g]', w2.Range(1), w2.Range(2)));
    nPassed = nPassed + 1;

    % --- Test 3: Units derive from Sensor ---
    s3 = SensorTag('T-101', 'Name', 'Temperature', 'Units', 'degC');
    s3.updateData([1 2 3], [20 25 30]);
    w3 = GaugeWidget('Sensor', s3);
    assert(strcmp(w3.Units, 'degC'), 'Units should auto-derive from Sensor.Units');
    nPassed = nPassed + 1;

    % --- Test 4: getType ---
    w4 = GaugeWidget('Title', 'Test');
    assert(strcmp(w4.getType(), 'gauge'), 'getType should return gauge');
    nPassed = nPassed + 1;

    % --- Test 5: toStruct round-trip ---
    w5 = GaugeWidget('Title', 'RPM', 'StaticValue', 3000, ...
        'Range', [0 6000], 'Units', 'rpm', 'Style', 'donut');
    st = w5.toStruct();
    assert(strcmp(st.type, 'gauge'), 'type should be gauge');
    assert(isequal(st.range, [0 6000]), 'range should be serialized');
    assert(strcmp(st.units, 'rpm'), 'units should be serialized');
    assert(strcmp(st.style, 'donut'), 'style should be serialized');
    nPassed = nPassed + 1;

    % --- Test 6: Range fallback to Y data when no thresholds ---
    s6 = SensorTag('S-001', 'Name', 'Speed');
    s6.updateData([1 2 3], [10 50 90]);
    w6 = GaugeWidget('Sensor', s6);
    assert(isequal(w6.Range, [10 90]), ...
        sprintf('Range should fall back to Y data range, got [%g %g]', w6.Range(1), w6.Range(2)));
    nPassed = nPassed + 1;

    fprintf('    All %d tests passed.\n', nPassed);
end
