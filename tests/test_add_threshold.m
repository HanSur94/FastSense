function test_add_threshold()
%TEST_ADD_THRESHOLD Tests for FastPlot.addThreshold method.

    run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));

    % testAddUpperThreshold
    fp = FastPlot();
    fp.addThreshold(4.5, 'Direction', 'upper');
    assert(numel(fp.Thresholds) == 1, 'testAddUpperThreshold: count');
    assert(fp.Thresholds(1).Value == 4.5, 'testAddUpperThreshold: value');
    assert(strcmp(fp.Thresholds(1).Direction, 'upper'), 'testAddUpperThreshold: direction');

    % testAddLowerThreshold
    fp = FastPlot();
    fp.addThreshold(-2.0, 'Direction', 'lower');
    assert(strcmp(fp.Thresholds(1).Direction, 'lower'), 'testAddLowerThreshold');

    % testDefaults
    fp = FastPlot();
    fp.addThreshold(5.0);
    assert(strcmp(fp.Thresholds(1).Direction, 'upper'), 'testDefaults: direction');
    assert(fp.Thresholds(1).ShowViolations == false, 'testDefaults: ShowViolations');
    assert(strcmp(fp.Thresholds(1).LineStyle, '--'), 'testDefaults: LineStyle');
    assert(strcmp(fp.Thresholds(1).Label, ''), 'testDefaults: Label');

    % testCustomOptions
    fp = FastPlot();
    fp.addThreshold(3.0, 'Direction', 'lower', ...
        'ShowViolations', true, 'Color', [1 0 0], ...
        'LineStyle', ':', 'Label', 'LowerBound');
    t = fp.Thresholds(1);
    assert(t.ShowViolations == true, 'testCustomOptions: ShowViolations');
    assert(isequal(t.Color, [1 0 0]), 'testCustomOptions: Color');
    assert(strcmp(t.LineStyle, ':'), 'testCustomOptions: LineStyle');
    assert(strcmp(t.Label, 'LowerBound'), 'testCustomOptions: Label');

    % testMultipleThresholds
    fp = FastPlot();
    fp.addThreshold(1.0);
    fp.addThreshold(2.0);
    fp.addThreshold(3.0);
    assert(numel(fp.Thresholds) == 3, 'testMultipleThresholds');

    fprintf('    All 5 addThreshold tests passed.\n');
end
