function test_align_state()
%TEST_ALIGN_STATE Tests for alignStateToTime helper.

    add_sensor_path();
    add_private_path();

    % testNumericAlignment
    stateX = [1 5 10 20];
    stateY = [0 1 2 3];
    sensorX = [0 2 5 7 10 15 25];
    result = alignStateToTime(stateX, stateY, sensorX);
    assert(isequal(result, [0 0 1 1 2 2 3]), 'testNumericAlignment');

    % testCellStringAlignment
    stateX = [1 5 10];
    stateY = {'off', 'running', 'idle'};
    sensorX = [0 3 5 8 12];
    result = alignStateToTime(stateX, stateY, sensorX);
    assert(isequal(result, {'off', 'off', 'running', 'running', 'idle'}), 'testCellStringAlignment');

    % testSingleStateValue
    stateX = [5];
    stateY = [1];
    sensorX = [1 3 5 7 9];
    result = alignStateToTime(stateX, stateY, sensorX);
    assert(isequal(result, [1 1 1 1 1]), 'testSingleStateValue');

    % testExactTimestampMatch
    stateX = [1 2 3];
    stateY = [10 20 30];
    sensorX = [1 2 3];
    result = alignStateToTime(stateX, stateY, sensorX);
    assert(isequal(result, [10 20 30]), 'testExactTimestampMatch');

    fprintf('    All 4 align_state tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end

function add_private_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(fullfile(repo_root, 'libs', 'SensorThreshold', 'private'));
end
