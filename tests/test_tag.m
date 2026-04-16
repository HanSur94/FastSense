function test_tag()
%TEST_TAG Octave flat-style port of TestTag.m
%   Mirrors the key assertions of tests/suite/TestTag.m (Phase 1004-01):
%     - Constructor defaults and name-value parsing
%     - Unknown option rejection (Tag:unknownOption)
%     - Labels and Metadata behavior (META-01, META-03)
%     - Criticality enum validation (META-04, Tag:invalidCriticality)
%     - Abstract-by-convention stubs (TAG-01): Tag:notImplemented
%     - Pitfall 1 gate: exactly 6 'Tag:notImplemented' occurrences in Tag.m
%
%   See also test_event_integration, TestTag.

    add_tag_path();

    % testConstructorDefaults
    t = MockTag('k');
    assert(strcmp(t.Key, 'k'), 'test_tag: Key');
    assert(strcmp(t.Name, 'k'), 'test_tag: Name defaults to Key');
    assert(strcmp(t.Units, ''), 'test_tag: Units default');
    assert(strcmp(t.Description, ''), 'test_tag: Description default');
    assert(iscell(t.Labels) && isempty(t.Labels), 'test_tag: Labels default');
    assert(isempty(fieldnames(t.Metadata)), 'test_tag: Metadata empty default');
    assert(strcmp(t.Criticality, 'medium'), 'test_tag: Criticality default');
    assert(strcmp(t.SourceRef, ''), 'test_tag: SourceRef default');

    % testConstructorNameValuePairs
    t = MockTag('k', 'Name', 'Pump A', 'Units', 'bar', ...
        'Description', 'main pump', ...
        'Labels', {'alpha', 'beta'}, ...
        'Metadata', struct('asset', 'p3'), ...
        'Criticality', 'safety', ...
        'SourceRef', 'file.mat');
    assert(strcmp(t.Name, 'Pump A'), 'test_tag: Name NV');
    assert(strcmp(t.Units, 'bar'), 'test_tag: Units NV');
    assert(numel(t.Labels) == 2, 'test_tag: Labels NV count');
    assert(strcmp(t.Labels{1}, 'alpha'), 'test_tag: Labels{1}');
    assert(strcmp(t.Metadata.asset, 'p3'), 'test_tag: Metadata NV');
    assert(strcmp(t.Criticality, 'safety'), 'test_tag: Criticality NV');
    assert(strcmp(t.SourceRef, 'file.mat'), 'test_tag: SourceRef NV');

    % testConstructorUnknownOptionErrors
    ok = false;
    try
        MockTag('k', 'Bogus', 1);
    catch me
        ok = ~isempty(strfind(me.identifier, 'Tag:unknownOption'));
    end
    assert(ok, 'test_tag: unknownOption error');

    % testConstructorRequiresKey (empty)
    ok = false;
    try
        MockTag('');
    catch me
        ok = ~isempty(strfind(me.identifier, 'Tag:invalidKey'));
    end
    assert(ok, 'test_tag: invalidKey error (empty)');

    % testCriticalityAllValidValues
    valid = {'low', 'medium', 'high', 'safety'};
    for i = 1:numel(valid)
        t = MockTag('k', 'Criticality', valid{i});
        assert(strcmp(t.Criticality, valid{i}), ...
            sprintf('test_tag: Criticality %s accepted', valid{i}));
    end

    % testCriticalityInvalidInConstructor
    ok = false;
    try
        MockTag('k', 'Criticality', 'emergency');
    catch me
        ok = ~isempty(strfind(me.identifier, 'Tag:invalidCriticality'));
    end
    assert(ok, 'test_tag: invalidCriticality error');

    % testLabelsAssign
    t = MockTag('k');
    t.Labels = {'x', 'y'};
    assert(numel(t.Labels) == 2, 'test_tag: labels assign');
    assert(strcmp(t.Labels{1}, 'x'), 'test_tag: labels{1}');

    % testMetadataOpenStruct
    t = MockTag('k');
    t.Metadata.asset = 'pump-3';
    t.Metadata.vendor = 'Acme';
    assert(strcmp(t.Metadata.asset, 'pump-3'), 'test_tag: metadata assign asset');
    assert(strcmp(t.Metadata.vendor, 'Acme'), 'test_tag: metadata assign vendor');

    % Abstract method stubs — call on a raw Tag instance.
    % Tag is abstract-by-convention (not declared Abstract), so it is
    % instantiable; calling any of the six stubs on it raises notImplemented.

    % testAbstractGetXYThrows
    ok = false;
    try
        [xx, yy] = Tag('k').getXY(); %#ok<NASGU>
    catch me
        ok = ~isempty(strfind(me.identifier, 'Tag:notImplemented'));
    end
    assert(ok, 'test_tag: abstract getXY throws');

    % testAbstractValueAtThrows
    ok = false;
    try
        vv = Tag('k').valueAt(0); %#ok<NASGU>
    catch me
        ok = ~isempty(strfind(me.identifier, 'Tag:notImplemented'));
    end
    assert(ok, 'test_tag: abstract valueAt throws');

    % testAbstractGetTimeRangeThrows
    ok = false;
    try
        [a, b] = Tag('k').getTimeRange(); %#ok<NASGU>
    catch me
        ok = ~isempty(strfind(me.identifier, 'Tag:notImplemented'));
    end
    assert(ok, 'test_tag: abstract getTimeRange throws');

    % testAbstractGetKindThrows
    ok = false;
    try
        kk = Tag('k').getKind(); %#ok<NASGU>
    catch me
        ok = ~isempty(strfind(me.identifier, 'Tag:notImplemented'));
    end
    assert(ok, 'test_tag: abstract getKind throws');

    % testAbstractToStructThrows
    ok = false;
    try
        ss = Tag('k').toStruct(); %#ok<NASGU>
    catch me
        ok = ~isempty(strfind(me.identifier, 'Tag:notImplemented'));
    end
    assert(ok, 'test_tag: abstract toStruct throws');

    % testAbstractFromStructThrows
    ok = false;
    try
        Tag.fromStruct(struct());
    catch me
        ok = ~isempty(strfind(me.identifier, 'Tag:notImplemented'));
    end
    assert(ok, 'test_tag: abstract fromStruct throws');

    % testResolveRefsDefaultIsNoOp (should not throw)
    t = MockTag('k');
    fakeRegistry = containers.Map();
    t.resolveRefs(fakeRegistry);  % no-op — passes if no error

    % testAbstractMethodCount — Pitfall 1 gate
    tagPath = which('Tag');
    assert(~isempty(tagPath), 'test_tag: Tag.m not on path');
    src = fileread(tagPath);
    count = numel(strfind(src, 'Tag:notImplemented'));
    assert(count == 6, ...
        sprintf('test_tag: expected 6 abstract stubs, got %d', count));

    fprintf('    All 18 test_tag tests passed.\n');
end

function add_tag_path()
    %ADD_TAG_PATH Ensure libs/SensorThreshold and tests/suite are on the path.
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    addpath(fullfile(test_dir, 'suite'));  % so MockTag is found
    install();
end
