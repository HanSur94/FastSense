function test_threshold()
%TEST_THRESHOLD Octave function-based tests for the Threshold class.

    add_threshold_path();

    % Test 1: Constructor defaults
    t = Threshold('k');
    assert(strcmp(t.Key, 'k'), 'test1: Key set');
    assert(strcmp(t.Direction, 'upper'), 'test1: Direction default upper');
    assert(t.IsUpper == true, 'test1: IsUpper true for upper');
    assert(strcmp(t.LineStyle, '--'), 'test1: LineStyle default --');
    assert(isempty(t.Name), 'test1: Name empty');
    assert(isempty(t.Color), 'test1: Color empty');
    assert(isempty(t.Units), 'test1: Units empty');
    assert(isempty(t.Description), 'test1: Description empty');
    assert(isempty(t.Tags), 'test1: Tags empty');

    % Test 2: Constructor all options
    t = Threshold('k2', 'Name', 'X', 'Direction', 'lower', ...
        'Color', [1 0 0], 'LineStyle', ':', 'Units', 'degC', ...
        'Description', 'desc', 'Tags', {'temp'});
    assert(strcmp(t.Name, 'X'), 'test2: Name set');
    assert(strcmp(t.Direction, 'lower'), 'test2: Direction lower');
    assert(t.IsUpper == false, 'test2: IsUpper false for lower');
    assert(isequal(t.Color, [1 0 0]), 'test2: Color set');
    assert(strcmp(t.LineStyle, ':'), 'test2: LineStyle set');
    assert(strcmp(t.Units, 'degC'), 'test2: Units set');
    assert(strcmp(t.Description, 'desc'), 'test2: Description set');
    assert(isequal(t.Tags, {'temp'}), 'test2: Tags set');

    % Test 3: IsUpper false for lower direction
    t = Threshold('k3', 'Direction', 'lower');
    assert(t.IsUpper == false, 'test3: IsUpper false for lower');

    % Test 4: Unknown option throws Threshold:unknownOption
    threw = false;
    try
        Threshold('k4', 'BadOpt', 1);
    catch e
        threw = true;
        assert(strcmp(e.identifier, 'Threshold:unknownOption'), 'test4: correct error id');
    end
    assert(threw, 'test4: should throw for unknown option');

    % Test 5: addCondition single
    t = Threshold('k5');
    t.addCondition(struct('machine', 1), 80);
    assert(numel(t.conditions_) == 1, 'test5: one condition stored');

    % Test 6: addCondition multiple
    t = Threshold('k6');
    t.addCondition(struct('machine', 1), 80);
    t.addCondition(struct('machine', 2), 90);
    assert(numel(t.conditions_) == 2, 'test6: two conditions stored');

    % Test 7: allValues returns vector
    t = Threshold('k7');
    t.addCondition(struct('machine', 1), 80);
    t.addCondition(struct('machine', 2), 90);
    vals = t.allValues();
    assert(isequal(sort(vals), [80, 90]), 'test7: allValues returns [80, 90]');

    % Test 8: allValues returns empty when no conditions
    t = Threshold('k8');
    vals = t.allValues();
    assert(isempty(vals), 'test8: allValues empty with no conditions');

    % Test 9: getConditionFields single
    t = Threshold('k9');
    t.addCondition(struct('machine', 1), 80);
    fields = t.getConditionFields();
    assert(isequal(fields, {'machine'}), 'test9: getConditionFields returns {machine}');

    % Test 10: getConditionFields unique sorted across multiple conditions
    t = Threshold('k10');
    t.addCondition(struct('zone', 2, 'machine', 1), 80);
    t.addCondition(struct('machine', 2), 90);
    fields = t.getConditionFields();
    assert(any(strcmp(fields, 'machine')), 'test10: has machine field');

    % Test 11: handle class behaviour
    t = Threshold('k11', 'Name', 'Before');
    t2 = t;
    t2.Name = 'After';
    assert(strcmp(t.Name, 'After'), 'test11: handle class copy shares reference');

    % Test 12: Label dependent property returns Name
    t = Threshold('k12', 'Name', 'MyName');
    assert(strcmp(t.Label, 'MyName'), 'test12: Label returns Name');

    % Test 13: Label empty when Name is empty
    t = Threshold('k13');
    assert(isempty(t.Label), 'test13: Label empty when Name empty');

    fprintf('    All 13 threshold tests passed.\n');
end

function add_threshold_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
