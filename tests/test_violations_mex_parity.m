function test_violations_mex_parity()
    add_sensor_path();

    if exist('compute_violations_mex', 'file') ~= 3
        fprintf('    SKIPPED: compute_violations_mex not compiled.\n');
        return;
    end

    % Test 1: single threshold, upper direction
    rng(42);
    N = 100000;
    sensorY = randn(1, N) * 20 + 50;
    segLo = [1, 50001];
    segHi = [50000, N];
    thresholdValues = 60;
    directions = true;  % upper

    result_mex = compute_violations_mex(sensorY, double(segLo), double(segHi), double(thresholdValues), double(directions));
    result_mat = compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions);
    assert(isequal(result_mex{1}, result_mat{1}), 'parity: single upper');

    % Test 2: multiple thresholds, mixed directions (batched)
    thresholdValues = [60, 40, 70, 30];
    directions = [true, false, true, false];  % upper, lower, upper, lower

    result_mex = compute_violations_mex(sensorY, double(segLo), double(segHi), double(thresholdValues), double(directions));
    result_mat = compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions);
    for t = 1:4
        assert(isequal(result_mex{t}, result_mat{t}), sprintf('parity: batch threshold %d', t));
    end

    % Test 3: edge case — single element segments
    sensorY = [1 2 3 4 5];
    segLo = [1 3 5];
    segHi = [1 3 5];
    thresholdValues = 3;
    directions = true;

    result_mex = compute_violations_mex(double(sensorY), double(segLo), double(segHi), double(thresholdValues), double(directions));
    result_mat = compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions);
    assert(isequal(result_mex{1}, result_mat{1}), 'parity: single element');

    % Test 4: no violations
    sensorY = ones(1, 100);
    segLo = [1];
    segHi = [100];
    thresholdValues = 5;
    directions = true;

    result_mex = compute_violations_mex(double(sensorY), double(segLo), double(segHi), double(thresholdValues), double(directions));
    assert(isempty(result_mex{1}), 'parity: no violations');

    % Test 5: large dataset (1M)
    N = 1000000;
    sensorY = randn(1, N) * 20 + 50;
    segLo = [1, 250001, 500001, 750001];
    segHi = [250000, 500000, 750000, N];
    thresholdValues = [60, 40];
    directions = [true, false];

    result_mex = compute_violations_mex(double(sensorY), double(segLo), double(segHi), double(thresholdValues), double(directions));
    result_mat = compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions);
    assert(isequal(result_mex{1}, result_mat{1}), 'parity: 1M upper');
    assert(isequal(result_mex{2}, result_mat{2}), 'parity: 1M lower');

    fprintf('    All 5 violations_mex_parity tests passed.\n');
end

function batchViolIdx = compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions)
    %Reference MATLAB implementation for parity checking
    nThresholds = numel(thresholdValues);
    nSegs = numel(segLo);
    batchViolIdx = cell(1, nThresholds);
    totalPoints = sum(segHi - segLo + 1);
    for t = 1:nThresholds
        thVal = thresholdValues(t);
        isUpper = directions(t);
        idx = zeros(1, totalPoints);
        count = 0;
        for s = 1:nSegs
            lo = segLo(s);
            hi = segHi(s);
            chunk = sensorY(lo:hi);
            if isUpper
                mask = chunk > thVal;
            else
                mask = chunk < thVal;
            end
            hits = find(mask) + lo - 1;
            nHits = numel(hits);
            idx(count+1:count+nHits) = hits;
            count = count + nHits;
        end
        batchViolIdx{t} = idx(1:count);
    end
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
    % Add private dirs so MEX is directly accessible for parity testing
    addpath(fullfile(repo_root, 'libs', 'FastPlot', 'private'));
end
