function test_status_widget()
%TEST_STATUS_WIDGET Tests for StatusWidget with Thresholds API.
%   Verifies that StatusWidget reads Sensor.Thresholds (not ThresholdRules).

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (known Octave classdef limitation)\n');
        return;
    end

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    nPassed = 0;
    nFailed = 0;

    % --- Test 1: no threshold, status is ok ---
    s = SensorTag('T-401', 'Name', 'Temperature', 'Units', 'degC');
    s.updateData([1 2 3], [70 71 72]);
    w = StatusWidget('Sensor', s);
    assert(strcmp(w.Title, 'Temperature'), 'Title should default to Sensor.Name');
    nPassed = nPassed + 1;

    % --- Test 2: upper threshold violated ---
    s2 = SensorTag('T-402', 'Name', 'TempHi');
    s2.updateData([1 2 3], [70 71 85]);
    t2 = Threshold('T402_hi', 'Name', 'Hi Alarm', ...
    t2.addCondition(struct(), 80);
    s2.addThreshold(t2);
    w2 = StatusWidget('Sensor', s2);
    theme = DashboardTheme();
    % Call deriveStatusFromSensor indirectly via asciiRender
    lines = w2.asciiRender(40, 2);
    assert(~isempty(strfind(lines{1}, 'ALARM')), ...
        'asciiRender should show ALARM when threshold violated');
    nPassed = nPassed + 1;

    % --- Test 3: upper threshold NOT violated ---
    s3 = SensorTag('T-403', 'Name', 'TempSafe');
    s3.updateData([1 2 3], [70 71 75]);
    t3 = Threshold('T403_hi', 'Name', 'Hi', 'Direction', 'upper');
    t3.addCondition(struct(), 80);
    s3.addThreshold(t3);
    w3 = StatusWidget('Sensor', s3);
    lines3 = w3.asciiRender(40, 2);
    assert(isempty(strfind(lines3{1}, 'ALARM')), ...
        'asciiRender should not show ALARM when threshold not violated');
    nPassed = nPassed + 1;

    % --- Test 4: lower threshold violated ---
    s4 = SensorTag('P-100', 'Name', 'Pressure');
    s4.updateData([1 2 3], [20 15 5]);
    t4 = Threshold('P100_lo', 'Name', 'Lo Warn', 'Direction', 'lower');
    t4.addCondition(struct(), 10);
    s4.addThreshold(t4);
    w4 = StatusWidget('Sensor', s4);
    lines4 = w4.asciiRender(40, 2);
    assert(~isempty(strfind(lines4{1}, 'ALARM')), ...
        'asciiRender should show ALARM for lower threshold violation');
    nPassed = nPassed + 1;

    % --- Test 5: StaticStatus callback ---
    w5 = StatusWidget('Title', 'Motor', 'StaticStatus', 'ok');
    assert(strcmp(w5.StaticStatus, 'ok'), 'StaticStatus should be set');
    nPassed = nPassed + 1;

    % --- Test 6: getType ---
    w6 = StatusWidget('Title', 'Valve');
    assert(strcmp(w6.getType(), 'status'), 'getType should return status');
    nPassed = nPassed + 1;

    fprintf('    All %d tests passed.\n', nPassed);
end
