function test_threshold_registry()
%TEST_THRESHOLD_REGISTRY Octave function-based tests for ThresholdRegistry.

    add_threshold_registry_path();

    % Keys used in this test — unregistered in teardown
    testKeys = {'thr_reg_oct1', 'thr_reg_oct2', 'thr_reg_oct3', ...
                'thr_reg_oct4', 'thr_reg_oct5', 'thr_reg_oct6', ...
                'thr_reg_oct7', 'thr_reg_oct8', 'thr_reg_oct9'};

    % Ensure clean state before tests
    for i = 1:numel(testKeys)
        ThresholdRegistry.unregister(testKeys{i});
    end

    % Test 1: register + get returns same handle
    t = Threshold('thr_reg_oct1', 'Name', 'Oct1');
    ThresholdRegistry.register('thr_reg_oct1', t);
    got = ThresholdRegistry.get('thr_reg_oct1');
    % Verify same handle: mutating one should change both
    t.Name = 'Mutated';
    assert(strcmp(got.Name, 'Mutated'), 'test1: get returns same handle (handle semantics)');

    % Test 2: get unknown key throws ThresholdRegistry:unknownKey
    threw = false;
    try
        ThresholdRegistry.get('nonexistent_thr_oct_xyz_9999');
    catch e
        threw = true;
        assert(strcmp(e.identifier, 'ThresholdRegistry:unknownKey'), ...
            'test2: correct error id');
    end
    assert(threw, 'test2: should throw for unknown key');

    % Test 3: unregister removes key; get throws after
    t = Threshold('thr_reg_oct2', 'Name', 'ToRemove');
    ThresholdRegistry.register('thr_reg_oct2', t);
    ThresholdRegistry.unregister('thr_reg_oct2');
    threw = false;
    try
        ThresholdRegistry.get('thr_reg_oct2');
    catch
        threw = true;
    end
    assert(threw, 'test3: get throws after unregister');

    % Test 4: list() runs without error
    t = Threshold('thr_reg_oct3', 'Name', 'ForList');
    ThresholdRegistry.register('thr_reg_oct3', t);
    ThresholdRegistry.list();  % should not error

    % Test 5: printTable() runs without error
    t = Threshold('thr_reg_oct4', 'Name', 'ForTable', 'Tags', {'test'});
    t.addCondition(struct('machine', 1), 80);
    ThresholdRegistry.register('thr_reg_oct4', t);
    ThresholdRegistry.printTable();  % should not error

    % Test 6: getMultiple returns cell array of Threshold handles
    t1 = Threshold('thr_reg_oct5', 'Name', 'Multi1');
    t2 = Threshold('thr_reg_oct6', 'Name', 'Multi2');
    ThresholdRegistry.register('thr_reg_oct5', t1);
    ThresholdRegistry.register('thr_reg_oct6', t2);
    result = ThresholdRegistry.getMultiple({'thr_reg_oct5', 'thr_reg_oct6'});
    assert(numel(result) == 2, 'test6: getMultiple returns 2');
    assert(isa(result{1}, 'Threshold'), 'test6: first is Threshold');
    assert(isa(result{2}, 'Threshold'), 'test6: second is Threshold');

    % Test 7: findByTag returns matching threshold
    t = Threshold('thr_reg_oct7', 'Name', 'Tagged', 'Tags', {'pressure', 'alarm'});
    ThresholdRegistry.register('thr_reg_oct7', t);
    results = ThresholdRegistry.findByTag('pressure');
    assert(numel(results) >= 1, 'test7: findByTag returns >= 1');
    keys = cellfun(@(r) r.Key, results, 'UniformOutput', false);
    assert(any(strcmp(keys, 'thr_reg_oct7')), 'test7: result contains registered key');

    % Test 8: findByTag unknown tag returns empty
    results = ThresholdRegistry.findByTag('nonexistent_tag_oct_xyz_9999');
    assert(isempty(results), 'test8: findByTag returns empty for unknown tag');

    % Test 9: findByDirection upper returns only upper thresholds
    t = Threshold('thr_reg_oct8', 'Name', 'UpperThr', 'Direction', 'upper');
    ThresholdRegistry.register('thr_reg_oct8', t);
    results = ThresholdRegistry.findByDirection('upper');
    assert(numel(results) >= 1, 'test9: findByDirection upper returns >= 1');
    for i = 1:numel(results)
        assert(strcmp(results{i}.Direction, 'upper'), 'test9: all results are upper');
    end

    % Test 10: findByDirection lower returns only lower thresholds
    t = Threshold('thr_reg_oct9', 'Name', 'LowerThr', 'Direction', 'lower');
    ThresholdRegistry.register('thr_reg_oct9', t);
    results = ThresholdRegistry.findByDirection('lower');
    assert(numel(results) >= 1, 'test10: findByDirection lower returns >= 1');
    for i = 1:numel(results)
        assert(strcmp(results{i}.Direction, 'lower'), 'test10: all results are lower');
    end

    % Cleanup
    for i = 1:numel(testKeys)
        ThresholdRegistry.unregister(testKeys{i});
    end

    fprintf('    All 10 threshold_registry tests passed.\n');
end

function add_threshold_registry_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
