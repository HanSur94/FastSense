function test_declarative_condition()
    add_sensor_path();

    % testStructCondition — single field
    rule = ThresholdRule(struct('machine', 1), 50, 'Direction', 'upper');
    assert(isstruct(rule.Condition), 'struct condition stored');
    assert(rule.Condition.machine == 1, 'field value stored');
    assert(rule.Value == 50, 'threshold value');
    assert(strcmp(rule.Direction, 'upper'), 'direction');

    % testMultiFieldCondition — two state channels
    rule = ThresholdRule(struct('machine', 1, 'vacuum', 2), 80);
    assert(rule.Condition.machine == 1, 'multi: machine');
    assert(rule.Condition.vacuum == 2, 'multi: vacuum');

    % testMatchesState — single field match
    rule = ThresholdRule(struct('machine', 1), 50);
    assert(rule.matchesState(struct('machine', 1)) == true, 'match true');
    assert(rule.matchesState(struct('machine', 0)) == false, 'match false');
    assert(rule.matchesState(struct('machine', 1, 'zone', 2)) == true, 'match ignores extra');

    % testMatchesStateMultiField — AND logic
    rule = ThresholdRule(struct('machine', 1, 'vacuum', 2), 50);
    assert(rule.matchesState(struct('machine', 1, 'vacuum', 2)) == true, 'multi match');
    assert(rule.matchesState(struct('machine', 1, 'vacuum', 0)) == false, 'multi partial');
    assert(rule.matchesState(struct('machine', 0, 'vacuum', 2)) == false, 'multi other partial');

    % testEmptyCondition — always active (replaces @(st) true)
    rule = ThresholdRule(struct(), 50, 'Direction', 'upper');
    assert(rule.matchesState(struct('machine', 1)) == true, 'empty always true');
    assert(rule.matchesState(struct()) == true, 'empty vs empty');

    % testDefaults
    rule = ThresholdRule(struct('m', 1), 50);
    assert(strcmp(rule.Direction, 'upper'), 'default direction');
    assert(strcmp(rule.LineStyle, '--'), 'default line style');
    assert(isempty(rule.Label), 'default label');
    assert(isempty(rule.Color), 'default color');

    fprintf('    All 6 declarative_condition tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end
