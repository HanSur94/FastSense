function test_data_source()
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (known Octave classdef limitation)\n');
        return;
    end
    add_event_path();
    test_cannot_instantiate();
    test_subclass_must_implement_fetchNew();
    fprintf('test_data_source: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    setup();
end

function test_cannot_instantiate()
    try
        ds = DataSource();
        error('Should not reach here');
    catch ex
        assert(~isempty(strfind(ex.message, 'Abstract')), 'cannot_instantiate');
    end
    fprintf('  PASS: test_cannot_instantiate\n');
end

function test_subclass_must_implement_fetchNew()
    % A minimal concrete subclass that does implement fetchNew
    % is tested in test_mock_data_source.m
    % Here we just verify the class file loads without error
    mc = meta.class.fromName('DataSource');
    assert(~isempty(mc), 'class_exists');
    methods = {mc.MethodList.Name};
    assert(ismember('fetchNew', methods), 'has_fetchNew');
    fprintf('  PASS: test_subclass_must_implement_fetchNew\n');
end
