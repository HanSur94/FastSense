function test_downsample_violations()
%TEST_DOWNSAMPLE_VIOLATIONS Tests for violation marker pixel-density culling.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); setup();
    add_fastsense_private_path();

    % testBasicDownsample: 10 violations in 3 pixel columns -> 3 points
    xV = [1.0, 1.1, 1.2, 2.0, 2.1, 2.2, 3.0, 3.1, 3.2, 3.3];
    yV = [5.0, 5.5, 5.2, 6.0, 6.3, 6.1, 7.0, 7.5, 7.2, 7.8];
    pixelWidth = 1.0;
    threshVal = 4.0;
    [xD, yD] = downsample_violations(xV, yV, pixelWidth, threshVal, 0.0);
    assert(numel(xD) == 3, 'testBasicDownsample: expected 3 points, got %d', numel(xD));
    assert(xD(1) == 1.1, 'testBasicDownsample: wrong x for col 1');
    assert(yD(1) == 5.5, 'testBasicDownsample: wrong y for col 1');
    assert(xD(2) == 2.1, 'testBasicDownsample: wrong x for col 2');
    assert(yD(2) == 6.3, 'testBasicDownsample: wrong y for col 2');
    assert(xD(3) == 3.3, 'testBasicDownsample: wrong x for col 3');
    assert(yD(3) == 7.8, 'testBasicDownsample: wrong y for col 3');

    % testLowerThreshold: keep point with max deviation below threshold
    xV = [1.0, 1.1, 2.0, 2.1];
    yV = [3.0, 2.5, 1.0, 1.5];
    pixelWidth = 1.0;
    threshVal = 4.0;
    [xD, yD] = downsample_violations(xV, yV, pixelWidth, threshVal, 0.0);
    assert(numel(xD) == 2, 'testLowerThreshold: expected 2 points');
    assert(yD(1) == 2.5, 'testLowerThreshold: wrong y for col 1');
    assert(yD(2) == 1.0, 'testLowerThreshold: wrong y for col 2');

    % testEmpty: no violations
    [xD, yD] = downsample_violations([], [], 1.0, 5.0, 0.0);
    assert(isempty(xD), 'testEmpty xD');
    assert(isempty(yD), 'testEmpty yD');

    % testSinglePoint: one violation passes through
    [xD, yD] = downsample_violations(5, 10, 1.0, 4.0, 0.0);
    assert(xD == 5, 'testSinglePoint xD');
    assert(yD == 10, 'testSinglePoint yD');

    % testAlreadySparse: each point in its own pixel column -> no culling
    xV = [1, 3, 5, 7, 9];
    yV = [6, 7, 8, 9, 10];
    [xD, yD] = downsample_violations(xV, yV, 1.0, 5.0, 0.0);
    assert(numel(xD) == 5, 'testAlreadySparse: expected 5 points');

    % testWithNaN: NaN values stripped before binning
    xV = [1.0, 1.1, NaN, 3.0, 3.1];
    yV = [5.0, 5.5, NaN, 7.0, 7.5];
    [xD, yD] = downsample_violations(xV, yV, 1.0, 4.0, 0.0);
    assert(numel(xD) == 2, 'testWithNaN: expected 2 points, got %d', numel(xD));

    % testLargeOffset: precision at large x values (timestamp-like)
    xV = [1e6 + 0.1, 1e6 + 0.2, 1e6 + 1.1, 1e6 + 1.2];
    yV = [5.0, 5.5, 6.0, 6.3];
    [xD, yD] = downsample_violations(xV, yV, 1.0, 4.0, 1e6);
    assert(numel(xD) == 2, 'testLargeOffset: expected 2 points, got %d', numel(xD));
    assert(yD(1) == 5.5, 'testLargeOffset: wrong y for col 1');
    assert(yD(2) == 6.3, 'testLargeOffset: wrong y for col 2');

    fprintf('    All 7 downsample_violations tests passed.\n');
end
