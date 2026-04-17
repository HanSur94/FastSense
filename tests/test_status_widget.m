function test_status_widget()
%TEST_STATUS_WIDGET Tests for StatusWidget basic API.
%   Tests 2-4 (threshold-based status) removed in Phase 1011 -- the
%   legacy Sensor.Thresholds/addThreshold pipeline was deleted.
%   StatusWidget threshold evaluation now uses Tag API (tested in
%   TestStatusWidget suite).

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (known Octave classdef limitation)\n');
        return;
    end

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    nPassed = 0;

    % --- Test 1: no threshold, status is ok ---
    s = SensorTag('T-401', 'Name', 'Temperature', 'Units', 'degC');
    s.updateData([1 2 3], [70 71 72]);
    w = StatusWidget('Tag', s);
    assert(strcmp(w.Title, 'Temperature'), 'Title should default to Tag.Name');
    nPassed = nPassed + 1;

    % --- Test 2: StaticStatus callback ---
    w5 = StatusWidget('Title', 'Motor', 'StaticStatus', 'ok');
    assert(strcmp(w5.StaticStatus, 'ok'), 'StaticStatus should be set');
    nPassed = nPassed + 1;

    % --- Test 3: getType ---
    w6 = StatusWidget('Title', 'Valve');
    assert(strcmp(w6.getType(), 'status'), 'getType should return status');
    nPassed = nPassed + 1;

    fprintf('    All %d status_widget tests passed.\n', nPassed);
end
