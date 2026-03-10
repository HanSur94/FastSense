function test_data_source_map()
    add_event_path();
    test_add_and_get();
    test_keys();
    test_has();
    test_unknown_key_errors();
    test_remove();
    fprintf('test_data_source_map: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    setup();
end

function test_add_and_get()
    m = DataSourceMap();
    ds = MockDataSource('BaseValue', 50);
    m.add('pressure', ds);
    out = m.get('pressure');
    assert(out.BaseValue == 50, 'get_returns_source');
    fprintf('  PASS: test_add_and_get\n');
end

function test_keys()
    m = DataSourceMap();
    m.add('a', MockDataSource());
    m.add('b', MockDataSource());
    k = m.keys();
    assert(numel(k) == 2, 'two_keys');
    assert(ismember('a', k) && ismember('b', k), 'correct_keys');
    fprintf('  PASS: test_keys\n');
end

function test_has()
    m = DataSourceMap();
    m.add('x', MockDataSource());
    assert(m.has('x'), 'has_true');
    assert(~m.has('y'), 'has_false');
    fprintf('  PASS: test_has\n');
end

function test_unknown_key_errors()
    m = DataSourceMap();
    try
        m.get('nope');
        error('Should not reach here');
    catch ex
        assert(contains(ex.identifier, 'unknownKey'), 'error_id');
    end
    fprintf('  PASS: test_unknown_key_errors\n');
end

function test_remove()
    m = DataSourceMap();
    m.add('x', MockDataSource());
    m.remove('x');
    assert(~m.has('x'), 'removed');
    fprintf('  PASS: test_remove\n');
end
