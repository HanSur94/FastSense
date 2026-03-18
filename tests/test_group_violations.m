function test_group_violations()
%TEST_GROUP_VIOLATIONS Tests for groupViolations private helper.

    add_event_path();
    add_event_private_path();

    % testSingleGroup — continuous violation
    t      = [1 2 3 4 5 6 7 8 9 10];
    values = [5 5 12 14 11 13 5 5 5 5];
    groups = groupViolations(t, values, 10, 'upper');
    assert(numel(groups) == 1, 'singleGroup: count');
    assert(groups(1).startIdx == 3, 'singleGroup: startIdx');
    assert(groups(1).endIdx == 6, 'singleGroup: endIdx');

    % testTwoGroups — gap splits into two events
    t      = [1 2 3 4 5 6 7 8 9 10];
    values = [12 13 5 5 5 14 15 5 5 5];
    groups = groupViolations(t, values, 10, 'upper');
    assert(numel(groups) == 2, 'twoGroups: count');
    assert(groups(1).startIdx == 1, 'twoGroups: g1 start');
    assert(groups(1).endIdx == 2, 'twoGroups: g1 end');
    assert(groups(2).startIdx == 6, 'twoGroups: g2 start');
    assert(groups(2).endIdx == 7, 'twoGroups: g2 end');

    % testLowDirection
    t      = [1 2 3 4 5];
    values = [50 3 2 4 50];
    groups = groupViolations(t, values, 10, 'lower');
    assert(numel(groups) == 1, 'lowDir: count');
    assert(groups(1).startIdx == 2, 'lowDir: start');
    assert(groups(1).endIdx == 4, 'lowDir: end');

    % testNoViolations
    t      = [1 2 3 4 5];
    values = [5 6 7 8 9];
    groups = groupViolations(t, values, 10, 'upper');
    assert(isempty(groups), 'noViolations: empty');

    % testAllViolations
    t      = [1 2 3];
    values = [20 30 40];
    groups = groupViolations(t, values, 10, 'upper');
    assert(numel(groups) == 1, 'allViolations: count');
    assert(groups(1).startIdx == 1, 'allViolations: start');
    assert(groups(1).endIdx == 3, 'allViolations: end');

    fprintf('    All 5 group_violations tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end

function add_event_private_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    privDir = fullfile(repo_root, 'libs', 'EventDetection', 'private');

    w = warning('off', 'all');
    addpath(privDir);
    warning(w);

    % Check if it actually landed on the path (R2025b rejects private/)
    dirs = strsplit(path, pathsep);
    if ~any(strcmp(dirs, privDir))
        tmpDir = fullfile(tempdir, 'event_detection_private_proxy');
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
