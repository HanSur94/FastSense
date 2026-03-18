function test_compute_violations()
%TEST_COMPUTE_VIOLATIONS Tests for compute_violations private function.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); setup();
    add_fastsense_private_path();

    % testUpperViolation
    x = 1:10;
    y = [1 2 3 4 5 6 5 4 3 2];
    [xV, yV] = compute_violations(x, y, 4.5, 'upper');
    assert(isequal(xV, [5 6 7]), 'testUpperViolation xV');
    assert(isequal(yV, [5 6 5]), 'testUpperViolation yV');

    % testLowerViolation
    x = 1:10;
    y = [5 4 3 2 1 0 1 2 3 4];
    [xV, yV] = compute_violations(x, y, 2.5, 'lower');
    assert(isequal(xV, [4 5 6 7 8]), 'testLowerViolation xV');
    assert(isequal(yV, [2 1 0 1 2]), 'testLowerViolation yV');

    % testNoViolations
    x = 1:5;
    y = [1 2 3 2 1];
    [xV, yV] = compute_violations(x, y, 10, 'upper');
    assert(isempty(xV), 'testNoViolations xV');
    assert(isempty(yV), 'testNoViolations yV');

    % testWithNaN
    x = 1:10;
    y = [1 2 NaN 8 9 10 NaN 3 2 1];
    [xV, yV] = compute_violations(x, y, 5, 'upper');
    assert(isequal(xV, [4 5 6]), 'testWithNaN xV');
    assert(isequal(yV, [8 9 10]), 'testWithNaN yV');

    % testExactThreshold: exact match is NOT a violation
    x = 1:5;
    y = [1 5 5 5 1];
    [xV, ~] = compute_violations(x, y, 5, 'upper');
    assert(isempty(xV), 'testExactThreshold: exact match should not violate');

    fprintf('    All 5 compute_violations tests passed.\n');
end
