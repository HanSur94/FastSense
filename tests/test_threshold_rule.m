function test_threshold_rule()
%TEST_THRESHOLD_RULE Tests for ThresholdRule class.

    add_sensor_path();

    % testConstructorDefaults
    rule = ThresholdRule(struct('x', 1), 50);
    assert(rule.Value == 50, 'testConstructorDefaults: Value');
    assert(strcmp(rule.Direction, 'upper'), 'testConstructorDefaults: Direction default');
    assert(isempty(rule.Label), 'testConstructorDefaults: Label default');
    assert(isempty(rule.Color), 'testConstructorDefaults: Color default');
    assert(strcmp(rule.LineStyle, '--'), 'testConstructorDefaults: LineStyle default');

    % testConstructorWithOptions
    rule = ThresholdRule(struct('x', 2), 100, ...
        'Direction', 'lower', 'Label', 'Low Alarm', ...
        'Color', [1 0 0], 'LineStyle', ':');
    assert(rule.Value == 100, 'testConstructorWithOptions: Value');
    assert(strcmp(rule.Direction, 'lower'), 'testConstructorWithOptions: Direction');
    assert(strcmp(rule.Label, 'Low Alarm'), 'testConstructorWithOptions: Label');
    assert(isequal(rule.Color, [1 0 0]), 'testConstructorWithOptions: Color');
    assert(strcmp(rule.LineStyle, ':'), 'testConstructorWithOptions: LineStyle');

    % testConditionEvaluation (via matchesState)
    rule = ThresholdRule(struct('machine', 1, 'zone', 0), 50);
    assert(rule.matchesState(struct('machine', 1, 'zone', 0)) == true, 'testConditionEval: true case');
    assert(rule.matchesState(struct('machine', 2, 'zone', 0)) == false, 'testConditionEval: false case');

    % testInvalidDirection
    threw = false;
    try
        ThresholdRule(struct(), 50, 'Direction', 'sideways');
    catch
        threw = true;
    end
    assert(threw, 'testInvalidDirection: should throw');

    fprintf('    All 4 threshold_rule tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
