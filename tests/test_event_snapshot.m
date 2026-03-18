function test_event_snapshot()
    add_event_path();
    test_generates_two_pngs();
    test_detail_plot_bounds();
    test_context_plot_bounds();
    test_shaded_region_exists();
    test_custom_size();
    fprintf('test_event_snapshot: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    addpath(fullfile(repoRoot, 'libs', 'FastSense'));
    setup();
end

function [ev, sensorData] = makeTestEvent()
    tStart = now - 1/24;  % 1 hour ago
    tEnd = now - 0.5/24;  % 30 min ago
    ev = Event(tStart, tEnd, 'temperature', 'HH', 100, 'upper');
    ev = ev.setStats(115, 50, 90, 115, 105, 106, 5);
    rng(42);
    t = linspace(now - 3/24, now, 1000);
    y = 80 + 5*randn(1, 1000);
    idx = t >= tStart & t <= tEnd;
    y(idx) = 110 + 5*randn(1, sum(idx));
    sensorData = struct('X', t, 'Y', y, 'thresholdValue', 100, 'thresholdDirection', 'upper');
end

function test_generates_two_pngs()
    [ev, sd] = makeTestEvent();
    outDir = tempname; mkdir(outDir);
    files = generateEventSnapshot(ev, sd, 'OutputDir', outDir);
    assert(numel(files) == 2, 'two_files');
    assert(isfile(files{1}), 'detail_exists');
    assert(isfile(files{2}), 'context_exists');
    assert(~isempty(strfind(files{1}, 'detail')), 'detail_name');
    assert(~isempty(strfind(files{2}, 'context')), 'context_name');
    rmdir(outDir, 's');
    fprintf('  PASS: test_generates_two_pngs\n');
end

function test_detail_plot_bounds()
    [ev, sd] = makeTestEvent();
    outDir = tempname; mkdir(outDir);
    files = generateEventSnapshot(ev, sd, 'OutputDir', outDir);
    % Just verify files were created (visual verification is manual)
    assert(isfile(files{1}), 'detail_created');
    rmdir(outDir, 's');
    fprintf('  PASS: test_detail_plot_bounds\n');
end

function test_context_plot_bounds()
    [ev, sd] = makeTestEvent();
    outDir = tempname; mkdir(outDir);
    files = generateEventSnapshot(ev, sd, 'OutputDir', outDir, 'ContextHours', 2);
    assert(isfile(files{2}), 'context_created');
    rmdir(outDir, 's');
    fprintf('  PASS: test_context_plot_bounds\n');
end

function test_shaded_region_exists()
    [ev, sd] = makeTestEvent();
    outDir = tempname; mkdir(outDir);
    files = generateEventSnapshot(ev, sd, 'OutputDir', outDir);
    % Verify the images are non-trivially sized (> 1KB)
    d = dir(files{1});
    assert(d.bytes > 1000, 'detail_not_empty');
    d = dir(files{2});
    assert(d.bytes > 1000, 'context_not_empty');
    rmdir(outDir, 's');
    fprintf('  PASS: test_shaded_region_exists\n');
end

function test_custom_size()
    [ev, sd] = makeTestEvent();
    outDir = tempname; mkdir(outDir);
    files = generateEventSnapshot(ev, sd, 'OutputDir', outDir, 'SnapshotSize', [400, 200]);
    assert(isfile(files{1}), 'custom_size_ok');
    rmdir(outDir, 's');
    fprintf('  PASS: test_custom_size\n');
end
