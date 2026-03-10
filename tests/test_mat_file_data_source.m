function test_mat_file_data_source()
    add_event_path();
    test_constructor();
    test_first_fetch_reads_all();
    test_incremental_fetch();
    test_unchanged_file();
    test_state_data();
    test_missing_file();
    fprintf('test_mat_file_data_source: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    setup();
end

function test_constructor()
    ds = MatFileDataSource('/tmp/test.mat', 'XVar', 't', 'YVar', 'y');
    assert(strcmp(ds.FilePath, '/tmp/test.mat'), 'filepath');
    assert(strcmp(ds.XVar, 't'), 'xvar');
    assert(strcmp(ds.YVar, 'y'), 'yvar');
    fprintf('  PASS: test_constructor\n');
end

function test_first_fetch_reads_all()
    f = [tempname '.mat'];
    x = [1 2 3 4 5]; y = [10 20 30 40 50];
    save(f, 'x', 'y');
    ds = MatFileDataSource(f, 'XVar', 'x', 'YVar', 'y');
    result = ds.fetchNew();
    assert(result.changed, 'changed');
    assert(isequal(result.X, x), 'all_x');
    assert(isequal(result.Y, y), 'all_y');
    delete(f);
    fprintf('  PASS: test_first_fetch_reads_all\n');
end

function test_incremental_fetch()
    f = [tempname '.mat'];
    x = [1 2 3]; y = [10 20 30];
    save(f, 'x', 'y');
    ds = MatFileDataSource(f, 'XVar', 'x', 'YVar', 'y');
    ds.fetchNew();  % read initial
    pause(1.1);  % ensure file modtime changes
    % Append new data
    x = [1 2 3 4 5]; y = [10 20 30 40 50];
    save(f, 'x', 'y');
    result = ds.fetchNew();
    assert(result.changed, 'changed');
    assert(isequal(result.X, [4 5]), 'only_new_x');
    assert(isequal(result.Y, [40 50]), 'only_new_y');
    delete(f);
    fprintf('  PASS: test_incremental_fetch\n');
end

function test_unchanged_file()
    f = [tempname '.mat'];
    x = [1 2 3]; y = [10 20 30];
    save(f, 'x', 'y');
    ds = MatFileDataSource(f, 'XVar', 'x', 'YVar', 'y');
    ds.fetchNew();
    result = ds.fetchNew();
    assert(~result.changed, 'not_changed');
    assert(isempty(result.X), 'empty_x');
    delete(f);
    fprintf('  PASS: test_unchanged_file\n');
end

function test_state_data()
    f = [tempname '.mat'];
    x = [1 2 3]; y = [10 20 30];
    stateX = [1 2.5]; stateY = {'idle', 'running'};
    save(f, 'x', 'y', 'stateX', 'stateY');
    ds = MatFileDataSource(f, 'XVar', 'x', 'YVar', 'y', ...
        'StateXVar', 'stateX', 'StateYVar', 'stateY');
    result = ds.fetchNew();
    assert(isequal(result.stateX, stateX), 'state_x');
    assert(isequal(result.stateY, stateY), 'state_y');
    delete(f);
    fprintf('  PASS: test_state_data\n');
end

function test_missing_file()
    ds = MatFileDataSource('/tmp/nonexistent_abc123.mat', 'XVar', 'x', 'YVar', 'y');
    result = ds.fetchNew();
    assert(~result.changed, 'missing_not_changed');
    assert(isempty(result.X), 'missing_empty');
    fprintf('  PASS: test_missing_file\n');
end
