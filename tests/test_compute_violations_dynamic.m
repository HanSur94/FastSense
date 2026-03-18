function test_compute_violations_dynamic()
%TEST_COMPUTE_VIOLATIONS_DYNAMIC Tests for time-varying threshold violations.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); setup();
    add_fastsense_private_path();

    % testUpperStepFunction: threshold steps from 5 to 8 at x=10
    thX = [0 10 20];
    thY = [5  8  8];
    x = 1:20;
    y = [3 4 6 7 4 5 6 7 8 9   3 4 5 6 7 8 9 10 7 6];
    %    1 2 3 4 5 6 7 8 9 10  11 ...
    % Threshold is 5 for x<10, 8 for x>=10
    % Upper violations: y>5 for x<10 -> x=3(6),4(7),7(6),8(7),9(8),10(9)
    %                   y>8 for x>=10 -> x=18(10),19(7 no),20(6 no) -> wait
    % x=3: y=6>5 yes; x=4: y=7>5 yes; x=5: y=4>5 no; x=6: y=5>5 no (strict)
    % x=7: y=6>5 yes; x=8: y=7>5 yes; x=9: y=8>5 yes; x=10: y=9>8 yes
    % x=11-17: y=3,4,5,6,7,8,9 vs 8 -> only x=17(9>8)
    % x=18: y=10>8 yes; x=19: y=7>8 no; x=20: y=6>8 no
    [xV, yV] = compute_violations_dynamic(x, y, thX, thY, 'upper');
    expectedX = [3 4 7 8 9 10 17 18];
    expectedY = [6 7 6 7 8  9  9 10];
    assert(isequal(xV, expectedX), 'testUpperStep: xV mismatch, got [%s]', num2str(xV));
    assert(isequal(yV, expectedY), 'testUpperStep: yV mismatch');

    % testLowerStepFunction
    thX = [0 10];
    thY = [3  6];
    x = 1:15;
    y = [1 2 3 4 5 1 2 3 4 5  4 5 6 7 8];
    % Lower violations: y<3 for x<10 -> x=1(1),2(2),6(1),7(2)
    %                   y<6 for x>=10 -> x=10(5),11(4),12(5)
    [xV, yV] = compute_violations_dynamic(x, y, thX, thY, 'lower');
    assert(isequal(xV, [1 2 6 7 10 11 12]), 'testLowerStep: xV');
    assert(isequal(yV, [1 2 1 2 5 4 5]), 'testLowerStep: yV');

    % testNoViolations
    thX = [0 10];
    thY = [100 100];
    x = 1:10;
    y = ones(1, 10);
    [xV, yV] = compute_violations_dynamic(x, y, thX, thY, 'upper');
    assert(isempty(xV), 'testNoViolations: xV');
    assert(isempty(yV), 'testNoViolations: yV');

    % testWithNaN: NaN data points never violate
    thX = [0 10];
    thY = [5 5];
    x = 1:5;
    y = [6 NaN 7 NaN 8];
    [xV, yV] = compute_violations_dynamic(x, y, thX, thY, 'upper');
    assert(isequal(xV, [1 3 5]), 'testWithNaN: xV');
    assert(isequal(yV, [6 7 8]), 'testWithNaN: yV');

    % testScalarEquivalence: single-segment threshold = scalar behavior
    thX = [0];
    thY = [5];
    x = 1:10;
    y = [1 2 3 4 5 6 7 8 9 10];
    [xV1, yV1] = compute_violations_dynamic(x, y, thX, thY, 'upper');
    [xV2, yV2] = compute_violations(x, y, 5, 'upper');
    assert(isequal(xV1, xV2), 'testScalarEquiv: xV');
    assert(isequal(yV1, yV2), 'testScalarEquiv: yV');

    % testDataOutsideThresholdRange: data before first threshold X
    thX = [5 10];
    thY = [3  6];
    x = 1:12;
    y = [4 4 4 4 4 4 4 4 4 4 7 7];
    % x=1-4 are before thX(1)=5, threshold is 3 (extrapolate left)
    % x=1-4: y=4>3 yes; x=5-9: y=4>3 yes; x=10-12: y vs 6
    % x=10: y=4>6 no; x=11: y=7>6 yes; x=12: y=7>6 yes
    [xV, ~] = compute_violations_dynamic(x, y, thX, thY, 'upper');
    assert(isequal(xV, [1 2 3 4 5 6 7 8 9 11 12]), 'testExtrapolate: xV');

    fprintf('    All 6 compute_violations_dynamic tests passed.\n');
end
