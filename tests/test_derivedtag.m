function test_derivedtag()
%TEST_DERIVEDTAG Octave flat-style port of TestDerivedTag.m (5th Tag class).
%   Mirrors the key assertions of tests/suite/TestDerivedTag.m:
%     - Construction succeeds, isa(Tag), getKind()=='derived', N parents
%     - Invalid parents (empty / non-Tag) -> DerivedTag:invalidParents
%     - Invalid compute (empty / non-fn / non-object) -> DerivedTag:invalidCompute
%     - Unknown option -> DerivedTag:unknownOption
%     - Direct + transitive cycle detection -> DerivedTag:cycleDetected
%     - getXY computes via fn handle; lazy via recomputeCount_; cached on hit
%     - Parent updateData triggers automatic invalidation (listener cascade)
%     - valueAt scalar + vector ZOH semantics; getTimeRange
%     - recompute_ rejects non-numeric / shape-mismatch returns
%     - Listener observer: invalidate cascade + invalid listener rejection
%     - Object-form compute path
%     - toStruct/fromStruct/resolveRefs round-trip (function-handle sentinel)
%     - findByKind('derived') returns the registered tag
%     - MonitorTag accepts DerivedTag as parent
%     - CompositeTag rejects DerivedTag as child
%     - TagRegistry.instantiateByKind dispatches 'derived'
%
%   See also test_monitortag, test_compositetag, TestDerivedTag.

    add_derivedtag_path();
    TagRegistry.clear();

    % --- Construction (basic) ---
    a = SensorTag('a', 'X', 1:10, 'Y', 1:10);
    b = SensorTag('b', 'X', 1:10, 'Y', 2:11);
    d = DerivedTag('d', {a, b}, @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
    assert(isa(d, 'Tag'),                  'isa(Tag)');
    assert(isa(d, 'handle'),               'isa(handle)');
    assert(strcmp(d.getKind(), 'derived'), 'getKind == derived');
    assert(strcmp(d.Key, 'd'),             'Key preserved');
    assert(numel(d.Parents) == 2,          'Parents count');
    assert(strcmp(d.Parents{1}.Key, 'a'),  'Parent[1] key');
    assert(strcmp(d.Parents{2}.Key, 'b'),  'Parent[2] key');
    assert(d.MinDuration == 0,             'MinDuration default');
    assert(d.recomputeCount_ == 0,         'recomputeCount_ == 0 pre-getXY');
    TagRegistry.clear();

    % --- Invalid parents ---
    threw = false;
    try
        DerivedTag('d', {}, @(p) deal([], []));
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:invalidParents');
    end
    assert(threw, 'invalidParents (empty)');

    threw = false;
    try
        DerivedTag('d', {struct('Key', 'fake')}, @(p) deal([], []));
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:invalidParents');
    end
    assert(threw, 'invalidParents (non-Tag)');

    % --- Invalid compute ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    threw = false;
    try
        DerivedTag('d', {a}, []);
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:invalidCompute');
    end
    assert(threw, 'invalidCompute (empty)');

    threw = false;
    try
        DerivedTag('d', {a}, 42);
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:invalidCompute');
    end
    assert(threw, 'invalidCompute (numeric)');

    % --- Unknown option ---
    threw = false;
    try
        DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y), 'BogusKey', 1);
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:unknownOption');
    end
    assert(threw, 'unknownOption');
    TagRegistry.clear();

    % --- Tag universals ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y), ...
        'Name', 'Pretty', 'Units', 'mbar', 'Description', 'doc', ...
        'Labels', {'l1', 'l2'}, 'Criticality', 'high');
    assert(strcmp(d.Name, 'Pretty'),     'Name set');
    assert(strcmp(d.Units, 'mbar'),      'Units set');
    assert(strcmp(d.Description, 'doc'), 'Description set');
    assert(isequal(d.Labels, {'l1','l2'}), 'Labels set');
    assert(strcmp(d.Criticality, 'high'),'Criticality set');
    TagRegistry.clear();

    % --- Direct cycle ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    d1 = DerivedTag('cyc', {a}, @(p) deal(p{1}.X, p{1}.Y));
    threw = false;
    try
        DerivedTag('cyc', {d1}, @(p) deal(p{1}.X, p{1}.Y));
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:cycleDetected');
    end
    assert(threw, 'cycleDetected (direct)');
    TagRegistry.clear();

    % --- Transitive cycle ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    bd = DerivedTag('b', {a}, @(p) deal(p{1}.X, p{1}.Y));
    c  = DerivedTag('c', {bd}, @(p) deal(p{1}.X, p{1}.Y));
    threw = false;
    try
        DerivedTag('b', {c}, @(p) deal(p{1}.X, p{1}.Y));
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:cycleDetected');
    end
    assert(threw, 'cycleDetected (transitive)');
    TagRegistry.clear();

    % --- getXY basic + lazy + cache ---
    a = SensorTag('a', 'X', 1:10, 'Y', 1:10);
    b = SensorTag('b', 'X', 1:10, 'Y', 2:11);
    d = DerivedTag('d', {a, b}, @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
    assert(d.recomputeCount_ == 0, 'recompute pre-getXY');
    [x, y] = d.getXY();
    assert(d.recomputeCount_ == 1, 'recompute after 1st getXY');
    assert(isequal(x, 1:10), 'X correct');
    assert(isequal(y, [3 5 7 9 11 13 15 17 19 21]), 'Y sum correct');
    [x, y] = d.getXY();
    assert(d.recomputeCount_ == 1, 'cache hit on 2nd getXY');
    TagRegistry.clear();

    % --- Parent updateData triggers invalidation ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y * 2));
    [~, y1] = d.getXY();
    assert(isequal(y1, 2:2:10), 'Y x2');
    a.updateData(1:5, 100*(1:5));
    [~, y2] = d.getXY();
    assert(isequal(y2, 200:200:1000), 'Y after parent update');
    assert(d.recomputeCount_ == 2, 'recompute after parent update');
    TagRegistry.clear();

    % --- valueAt scalar + vector ZOH ---
    a = SensorTag('a', 'X', [0 1 2 3 4], 'Y', [10 20 30 40 50]);
    d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y));
    assert(d.valueAt(2)   == 30, 'valueAt scalar exact');
    assert(d.valueAt(2.5) == 30, 'valueAt scalar ZOH');
    assert(d.valueAt(0)   == 10, 'valueAt at start');
    assert(d.valueAt(100) == 50, 'valueAt beyond end -> last');
    v = d.valueAt([0 1.5 2.5 3.5]);
    assert(isequal(v, [10 20 30 40]), 'valueAt vector');
    TagRegistry.clear();

    % --- getTimeRange ---
    a = SensorTag('a', 'X', 1:10, 'Y', (1:10).^2);
    d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y));
    [tMin, tMax] = d.getTimeRange();
    assert(tMin == 1 && tMax == 10, 'getTimeRange');
    TagRegistry.clear();

    % --- recompute rejects non-numeric / shape mismatch ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    d = DerivedTag('d', {a}, @(p) deal(p{1}.X, 'not-numeric'));
    threw = false;
    try
        d.getXY();
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:computeReturnedNonNumeric');
    end
    assert(threw, 'computeReturnedNonNumeric');
    TagRegistry.clear();

    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    d = DerivedTag('d', {a}, @(p) deal(p{1}.X, 1:10));
    threw = false;
    try
        d.getXY();
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:computeShapeMismatch');
    end
    assert(threw, 'computeShapeMismatch');
    TagRegistry.clear();

    % --- invalidate clears cache ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y * 3));
    d.getXY();
    assert(d.recomputeCount_ == 1, 'recompute after first getXY');
    d.invalidate();
    d.getXY();
    assert(d.recomputeCount_ == 2, 'recompute after invalidate');
    TagRegistry.clear();

    % --- addListener rejects no-invalidate target ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y));
    threw = false;
    try
        d.addListener(struct());
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:invalidListener');
    end
    assert(threw, 'invalidListener');
    TagRegistry.clear();

    % --- MonitorTag accepts DerivedTag as parent (downstream chaining) ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y * 10));
    m = MonitorTag('m', d, @(x, y) y > 25);
    [~, my] = m.getXY();
    assert(isequal(my, [0 0 1 1 1]), 'MonitorTag over DerivedTag');
    % Cascade through parent update
    a.updateData(1:5, 100*(1:5));
    [~, my2] = m.getXY();
    assert(isequal(my2, [1 1 1 1 1]), 'MonitorTag re-fires after root update');
    TagRegistry.clear();

    % --- CompositeTag rejects DerivedTag as child ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y));
    c = CompositeTag('c', 'and');
    threw = false;
    try
        c.addChild(d);
    catch me
        threw = strcmp(me.identifier, 'CompositeTag:invalidChildType');
    end
    assert(threw, 'CompositeTag rejects DerivedTag');
    TagRegistry.clear();

    % --- toStruct (function-handle compute) ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
    d = DerivedTag('d', {a, b}, @(p) deal(p{1}.X, p{1}.Y + p{2}.Y), ...
        'Name', 'Sum', 'Units', 'V');
    s = d.toStruct();
    assert(strcmp(s.kind, 'derived'),                   'kind serialized');
    assert(strcmp(s.key,  'd'),                         'key serialized');
    assert(strcmp(s.name, 'Sum'),                       'name serialized');
    assert(strcmp(s.units, 'V'),                        'units serialized');
    assert(strcmp(s.computekind, 'function_handle'),    'computekind=fh');
    assert(ischar(s.computestr),                        'computestr is char');
    pk = s.parentkeys;
    if iscell(pk) && numel(pk) == 1 && iscell(pk{1})
        pk = pk{1};
    end
    assert(isequal(pk, {'a', 'b'}),                     'parentkeys serialized');
    TagRegistry.clear();

    % --- fromStruct (Pass-1) + sentinel ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
    d  = DerivedTag('d', {a, b}, @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
    s  = d.toStruct();
    d2 = DerivedTag.fromStruct(s);
    assert(strcmp(d2.Key, 'd'),                       'fromStruct key');
    assert(strcmp(d2.getKind(), 'derived'),           'fromStruct kind');
    assert(numel(d2.Parents) == 0,                    'Pass-1 Parents empty');
    threw = false;
    try
        d2.getXY();
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:computeNotRehydrated');
    end
    assert(threw, 'computeNotRehydrated sentinel');
    TagRegistry.clear();

    % --- resolveRefs (Pass-2) + ComputeFn rebind ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
    d  = DerivedTag('d', {a, b}, @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
    s  = d.toStruct();
    d2 = DerivedTag.fromStruct(s);
    registry = containers.Map();
    registry('a') = a;
    registry('b') = b;
    d2.resolveRefs(registry);
    assert(numel(d2.Parents) == 2,             'Pass-2 wired Parents');
    assert(strcmp(d2.Parents{1}.Key, 'a'),     'Pass-2 parent[1]');
    assert(strcmp(d2.Parents{2}.Key, 'b'),     'Pass-2 parent[2]');
    d2.ComputeFn = @(p) deal(p{1}.X, p{1}.Y + p{2}.Y);
    [~, y] = d2.getXY();
    assert(isequal(y, [3 5 7 9 11]), 'rebound ComputeFn computes');
    TagRegistry.clear();

    % --- fromStruct rejects missing fields ---
    threw = false;
    try
        DerivedTag.fromStruct(struct());
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:dataMismatch');
    end
    assert(threw, 'dataMismatch (no key)');

    threw = false;
    try
        DerivedTag.fromStruct(struct('key', 'd', 'kind', 'derived'));
    catch me
        threw = strcmp(me.identifier, 'DerivedTag:dataMismatch');
    end
    assert(threw, 'dataMismatch (no parentkeys)');
    TagRegistry.clear();

    % --- TagRegistry.instantiateByKind('derived') ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y * 5));
    s = d.toStruct();
    d2 = TagRegistry.instantiateByKind(s);
    assert(isa(d2, 'DerivedTag'),     'instantiateByKind returns DerivedTag');
    assert(strcmp(d2.Key, 'd'),       'instantiateByKind preserves Key');
    TagRegistry.clear();

    % --- findByKind('derived') ---
    a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
    d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y));
    TagRegistry.register('a', a);
    TagRegistry.register('d', d);
    ts = TagRegistry.findByKind('derived');
    assert(numel(ts) == 1,            'findByKind returns one derived');
    assert(strcmp(ts{1}.Key, 'd'),    'findByKind returns the right one');
    TagRegistry.clear();

    % --- Source guards ---
    src = fileread(derivedtag_source_path_());
    assert(~isempty(regexp(src, 'classdef DerivedTag < Tag', 'once')), ...
        'DerivedTag.m must extend Tag');
    assert(isempty(regexp(src, 'methods \(Abstract\)', 'match')), ...
        'Octave safety: DerivedTag.m must not use methods (Abstract) block');

    fprintf('    All test_derivedtag tests passed.\n');
end

function add_derivedtag_path()
    %ADD_DERIVEDTAG_PATH Ensure repo root + tests/suite are on the path.
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    addpath(fullfile(here, 'suite'));  % for MockTag (used by fromStruct)
    install();
end

function p = derivedtag_source_path_()
    %DERIVEDTAG_SOURCE_PATH_ Absolute path to DerivedTag.m for grep gates.
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    p    = fullfile(repo, 'libs', 'SensorThreshold', 'DerivedTag.m');
end
