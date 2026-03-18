function test_add_threshold()
%TEST_ADD_THRESHOLD Tests for FastSense.addThreshold method.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();

    % testAddUpperThreshold
    fp = FastSense();
    fp.addThreshold(4.5, 'Direction', 'upper');
    assert(numel(fp.Thresholds) == 1, 'testAddUpperThreshold: count');
    assert(fp.Thresholds(1).Value == 4.5, 'testAddUpperThreshold: value');
    assert(strcmp(fp.Thresholds(1).Direction, 'upper'), 'testAddUpperThreshold: direction');

    % testAddLowerThreshold
    fp = FastSense();
    fp.addThreshold(-2.0, 'Direction', 'lower');
    assert(strcmp(fp.Thresholds(1).Direction, 'lower'), 'testAddLowerThreshold');

    % testDefaults
    fp = FastSense();
    fp.addThreshold(5.0);
    assert(strcmp(fp.Thresholds(1).Direction, 'upper'), 'testDefaults: direction');
    assert(fp.Thresholds(1).ShowViolations == false, 'testDefaults: ShowViolations');
    assert(strcmp(fp.Thresholds(1).LineStyle, '--'), 'testDefaults: LineStyle');
    assert(strcmp(fp.Thresholds(1).Label, ''), 'testDefaults: Label');

    % testCustomOptions
    fp = FastSense();
    fp.addThreshold(3.0, 'Direction', 'lower', ...
        'ShowViolations', true, 'Color', [1 0 0], ...
        'LineStyle', ':', 'Label', 'LowerBound');
    t = fp.Thresholds(1);
    assert(t.ShowViolations == true, 'testCustomOptions: ShowViolations');
    assert(isequal(t.Color, [1 0 0]), 'testCustomOptions: Color');
    assert(strcmp(t.LineStyle, ':'), 'testCustomOptions: LineStyle');
    assert(strcmp(t.Label, 'LowerBound'), 'testCustomOptions: Label');

    % testMultipleThresholds
    fp = FastSense();
    fp.addThreshold(1.0);
    fp.addThreshold(2.0);
    fp.addThreshold(3.0);
    assert(numel(fp.Thresholds) == 3, 'testMultipleThresholds');

    % testTimeVaryingThreshold
    fp = FastSense();
    thX = [0 10 20 30];
    thY = [5.0 5.0 7.0 7.0];
    fp.addThreshold(thX, thY, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'StepTh');
    assert(numel(fp.Thresholds) == 1, 'testTimeVarying: count');
    assert(isempty(fp.Thresholds(1).Value), 'testTimeVarying: Value should be empty');
    assert(isequal(fp.Thresholds(1).X, thX), 'testTimeVarying: X');
    assert(isequal(fp.Thresholds(1).Y, thY), 'testTimeVarying: Y');
    assert(strcmp(fp.Thresholds(1).Direction, 'upper'), 'testTimeVarying: direction');
    assert(fp.Thresholds(1).ShowViolations == true, 'testTimeVarying: ShowViolations');

    % testMixedThresholds — scalar and time-varying coexist
    fp = FastSense();
    fp.addThreshold(4.5);
    fp.addThreshold([0 10], [3.0 5.0], 'Direction', 'lower');
    assert(numel(fp.Thresholds) == 2, 'testMixed: count');
    assert(fp.Thresholds(1).Value == 4.5, 'testMixed: scalar Value');
    assert(isempty(fp.Thresholds(2).Value), 'testMixed: tv Value empty');

    fprintf('    All 7 addThreshold tests passed.\n');
end
