function test_compositetag()
%TEST_COMPOSITETAG Octave flat-style port of TestCompositeTag.m (Phase 1008-01).
%   Mirrors the 22 assertions of tests/suite/TestCompositeTag.m:
%     A. Constructor / kind / Tag identity                (1..8)
%     B. addChild path (handle + string + weight + guards)(9..15)
%     C. Cycle detection DFS (self + 2-deep + 3-deep + diamond) (16..19)
%     D. Truth-table aggregator (7 modes × NaN rows)      (20..21)
%     E. Pitfall 6 class-header truth-table doc gate      (22a)
%     F. Pitfall 5 strangler-fig legacy-unchanged gate    (22b)
%
%   RED expectation: before Task 2 ships CompositeTag.m, this whole
%   function aborts with "undefined class 'CompositeTag'" or similar.
%
%   See also TestCompositeTag, test_monitortag.

    add_compositetag_paths_();
    TagRegistry.clear();

    %% A. Constructor / kind / Tag identity

    % A1: isa(Tag) + handle
    c = CompositeTag('c', 'and');
    assert(isa(c, 'Tag'),    'A1: not a Tag');
    assert(isa(c, 'handle'), 'A1: not a handle');

    % A2: getKind() == 'composite'
    assert(strcmp(c.getKind(), 'composite'), 'A2: getKind must be composite');

    % A3: default AggregateMode == 'and'
    cDef = CompositeTag('cdef');
    assert(strcmp(cDef.AggregateMode, 'and'), 'A3: default mode');

    % A4: Tag NV pairs flow through
    c2 = CompositeTag('c2', 'or', ...
        'Name', 'display', ...
        'Labels', {'a', 'b'}, ...
        'Criticality', 'high');
    assert(strcmp(c2.Name, 'display'),      'A4: Name');
    assert(isequal(c2.Labels, {'a', 'b'}),  'A4: Labels');
    assert(strcmp(c2.Criticality, 'high'),  'A4: Criticality');

    % A5: user_fn without UserFn -> userFnRequired
    threw = false;
    try
        CompositeTag('c3', 'user_fn');
    catch me
        threw = strcmp(me.identifier, 'CompositeTag:userFnRequired');
    end
    assert(threw, 'A5: userFnRequired');

    % A6: user_fn with UserFn works
    c4 = CompositeTag('c4', 'user_fn', 'UserFn', @(v) max(v));
    assert(c4.UserFn(1:3) == 3, 'A6: UserFn stored');

    % A7: unknown mode
    threw = false;
    try
        CompositeTag('c5', 'xor');
    catch me
        threw = strcmp(me.identifier, 'CompositeTag:invalidAggregateMode');
    end
    assert(threw, 'A7: invalidAggregateMode');

    % A8: unknown NV option
    threw = false;
    try
        CompositeTag('c6', 'and', 'BadKey', 1);
    catch me
        threw = strcmp(me.identifier, 'CompositeTag:unknownOption');
    end
    assert(threw, 'A8: unknownOption');

    TagRegistry.clear();

    %% B. addChild path

    % B9: addChild by handle
    s = SensorTag('s', 'X', 1:10, 'Y', 1:10);
    m = MonitorTag('m', s, @(x, y) y > 5);
    c = CompositeTag('cb', 'and');
    c.addChild(m);
    assert(c.getChildCount() == 1, 'B9: child count');
    keys = c.getChildKeys();
    assert(strcmp(keys{1}, 'm'), 'B9: child key stored');

    % B10: addChild by string key (resolve via TagRegistry)
    TagRegistry.clear();
    s2 = SensorTag('s2', 'X', 1:10, 'Y', 1:10);
    m2 = MonitorTag('m2', s2, @(x, y) y > 5);
    TagRegistry.register('m2', m2);
    c10 = CompositeTag('c10', 'and');
    c10.addChild('m2');
    assert(c10.getChildCount() == 1, 'B10: string-key addChild count');
    k10 = c10.getChildKeys();
    assert(strcmp(k10{1}, 'm2'), 'B10: string-key resolved to registry handle');

    % B11: Weight NV stored
    TagRegistry.clear();
    s3 = SensorTag('s3', 'X', 1:10, 'Y', 1:10);
    m3 = MonitorTag('m3', s3, @(x, y) y > 5);
    c11 = CompositeTag('c11', 'severity');
    c11.addChild(m3, 'Weight', 0.7);
    w = c11.getChildWeights();
    assert(abs(w(1) - 0.7) < 1e-12, 'B11: Weight stored');

    % B12: reject SensorTag
    TagRegistry.clear();
    sRaw = SensorTag('sRaw', 'X', 1:5, 'Y', 1:5);
    c12 = CompositeTag('c12', 'and');
    threw = false;
    try
        c12.addChild(sRaw);
    catch me
        threw = strcmp(me.identifier, 'CompositeTag:invalidChildType');
    end
    assert(threw, 'B12: SensorTag rejected');

    % B13: reject StateTag
    TagRegistry.clear();
    stRaw = StateTag('stRaw', 'X', 1:5, 'Y', [1 2 1 2 1]);
    c13 = CompositeTag('c13', 'and');
    threw = false;
    try
        c13.addChild(stRaw);
    catch me
        threw = strcmp(me.identifier, 'CompositeTag:invalidChildType');
    end
    assert(threw, 'B13: StateTag rejected');

    % B14: accept CompositeTag child
    TagRegistry.clear();
    cOuter = CompositeTag('cOuter', 'and');
    cInner = CompositeTag('cInner', 'or');
    cOuter.addChild(cInner);
    assert(cOuter.getChildCount() == 1, 'B14: CompositeTag child accepted');

    % B15: listener cascade -- child.invalidate() makes composite dirty
    TagRegistry.clear();
    sL = SensorTag('sL', 'X', 1:10, 'Y', 1:10);
    mL = MonitorTag('mL', sL, @(x, y) y > 5);
    cL = CompositeTag('cL', 'and');
    cL.addChild(mL);
    mL.invalidate();  % should cascade into cL.invalidate()
    assert(cL.isDirty(), 'B15: composite must be dirty after child invalidate');

    TagRegistry.clear();

    %% C. Cycle detection DFS (Key-equality per RESEARCH §7)

    % C16: self-reference
    cSelf = CompositeTag('cSelf', 'and');
    threw = false;
    try
        cSelf.addChild(cSelf);
    catch me
        threw = strcmp(me.identifier, 'CompositeTag:cycleDetected');
    end
    assert(threw, 'C16: self cycle detected');

    % C17: 2-deep a -> b -> a
    TagRegistry.clear();
    aC = CompositeTag('aC', 'and');
    bC = CompositeTag('bC', 'and');
    aC.addChild(bC);
    threw = false;
    try
        bC.addChild(aC);
    catch me
        threw = strcmp(me.identifier, 'CompositeTag:cycleDetected');
    end
    assert(threw, 'C17: 2-deep cycle detected');

    % C18: 3-deep a -> b -> c -> a
    TagRegistry.clear();
    a3 = CompositeTag('a3', 'and');
    b3 = CompositeTag('b3', 'and');
    c3 = CompositeTag('c3', 'and');
    a3.addChild(b3);
    b3.addChild(c3);
    threw = false;
    try
        c3.addChild(a3);
    catch me
        threw = strcmp(me.identifier, 'CompositeTag:cycleDetected');
    end
    assert(threw, 'C18: 3-deep cycle detected');

    % C19: diamond is NOT a cycle (2 parents share 1 leaf)
    TagRegistry.clear();
    sD   = SensorTag('sD', 'X', 1:10, 'Y', 1:10);
    leafD = MonitorTag('leafD', sD, @(x, y) y > 5);
    aD   = CompositeTag('aD', 'and');
    bD   = CompositeTag('bD', 'and');
    aD.addChild(leafD);
    bD.addChild(leafD);
    top  = CompositeTag('topD', 'and');
    top.addChild(aD);
    top.addChild(bD);
    assert(top.getChildCount() == 2, 'C19: diamond accepted (not a cycle)');

    TagRegistry.clear();

    %% D. Truth table (RESEARCH §4 verbatim)

    cases = { ...
        'and',      [0 0],       [1 1],    0.5, 0; ...
        'and',      [0 1],       [1 1],    0.5, 0; ...
        'and',      [1 1],       [1 1],    0.5, 1; ...
        'and',      [0 NaN],     [1 1],    0.5, NaN; ...
        'and',      [1 NaN],     [1 1],    0.5, NaN; ...
        'and',      [NaN NaN],   [1 1],    0.5, NaN; ...
        'or',       [0 0],       [1 1],    0.5, 0; ...
        'or',       [0 1],       [1 1],    0.5, 1; ...
        'or',       [1 1],       [1 1],    0.5, 1; ...
        'or',       [0 NaN],     [1 1],    0.5, 0; ...
        'or',       [1 NaN],     [1 1],    0.5, 1; ...
        'or',       [NaN NaN],   [1 1],    0.5, NaN; ...
        'majority', [1 1 0],     [1 1 1],  0.5, 1; ...
        'majority', [1 0 0],     [1 1 1],  0.5, 0; ...
        'majority', [1 1 NaN],   [1 1 1],  0.5, 1; ...
        'majority', [1 0 NaN],   [1 1 1],  0.5, 0; ...
        'majority', [NaN NaN NaN], [1 1 1], 0.5, NaN; ...
        'count',    [1 1 0],     [1 1 1],  2,   1; ...
        'count',    [1 0 0],     [1 1 1],  2,   0; ...
        'count',    [1 1 NaN],   [1 1 1],  2,   1; ...
        'count',    [1 0 NaN],   [1 1 1],  2,   0; ...
        'worst',    [0 0],       [1 1],    0.5, 0; ...
        'worst',    [0 1],       [1 1],    0.5, 1; ...
        'worst',    [1 NaN],     [1 1],    0.5, 1; ...
        'worst',    [NaN NaN],   [1 1],    0.5, NaN; ...
        'severity', [1 0],       [1 1],    0.5, 1; ...
        'severity', [1 0],       [1 3],    0.5, 0; ...
        'severity', [1 NaN],     [1 1],    0.5, 1; ...
        'severity', [NaN NaN],   [1 1],    0.5, NaN; ...
    };
    for i = 1:size(cases, 1)
        mode     = cases{i, 1};
        vals     = cases{i, 2};
        weights  = cases{i, 3};
        thr      = cases{i, 4};
        expected = cases{i, 5};
        got = CompositeTag.aggregateForTesting(vals, weights, mode, [], thr);
        if isnan(expected)
            assert(isnan(got), sprintf( ...
                'D20 row %d mode=%s vals=[%s] expected NaN got %g', ...
                i, mode, num2str(vals), got));
        else
            assert(got == expected, sprintf( ...
                'D20 row %d mode=%s vals=[%s] expected %g got %g', ...
                i, mode, num2str(vals), expected, got));
        end
    end

    % D21: USER_FN
    userFn = @(v) mean(v(~isnan(v)));
    out = CompositeTag.aggregateForTesting( ...
        [0.2 0.4 0.6], [1 1 1], 'user_fn', userFn, 0.5);
    assert(abs(out - 0.4) < 1e-12, 'D21: user_fn mean');

    %% E. Pitfall 6 doc gate (class-header truth tables)
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    src  = fileread(fullfile(repo, ...
        'libs', 'SensorThreshold', 'CompositeTag.m'));
    assert(~isempty(regexp(src, 'Truth [Tt]able', 'once')), ...
        'E22a: Truth Table text missing from class header (Pitfall 6)');

    %% F. Pitfall 5 strangler-fig -- legacy unchanged
    legacy = { ...
        'Sensor', 'Threshold', 'ThresholdRule', ...
        'CompositeThreshold', 'StateChannel', ...
        'SensorRegistry', 'ThresholdRegistry', ...
        'ExternalSensorRegistry'};
    for i = 1:numel(legacy)
        fn = fullfile(repo, 'libs', 'SensorThreshold', [legacy{i} '.m']);
        if exist(fn, 'file')
            txt = fileread(fn);
            assert(isempty(regexp(txt, 'CompositeTag', 'once')), ...
                sprintf('F22b: legacy %s.m must not reference CompositeTag', ...
                    legacy{i}));
        end
    end

    fprintf('    All 22 CompositeTag tests passed.\n');
end

function add_compositetag_paths_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
end
