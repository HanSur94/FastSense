function test_align_state()
%TEST_ALIGN_STATE Tests for alignStateToTime helper.

    add_sensor_path();
    add_sensor_private_path();

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
    addpath(repo_root); setup();
end

function add_sensor_private_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    privDir = fullfile(repo_root, 'libs', 'SensorThreshold', 'private');

    w = warning('off', 'all');
    addpath(privDir);
    warning(w);

    % Check if it actually landed on the path (R2025b rejects private/)
    dirs = strsplit(path, pathsep);
    if ~any(strcmp(dirs, privDir))
        tmpDir = fullfile(tempdir, 'sensor_threshold_private_proxy');
        if ~exist(tmpDir, 'dir')
            mkdir(tmpDir);
        end
        files = dir(fullfile(privDir, '*.m'));
        for i = 1:numel(files)
            src = fullfile(privDir, files(i).name);
            dst = fullfile(tmpDir, files(i).name);
            copyfile(src, dst);
        end
        addpath(tmpDir);
    end
end
