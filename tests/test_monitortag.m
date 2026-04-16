function test_monitortag()
%TEST_MONITORTAG Octave flat-style port of TestMonitorTag.m (Phase 1006-01).
%   Mirrors the key assertions of tests/suite/TestMonitorTag.m:
%     - Construction succeeds, isa(Tag), getKind()=='monitor'
%     - Invalid parent   -> MonitorTag:invalidParent
%     - Invalid condition -> MonitorTag:invalidCondition
%     - Unknown option   -> MonitorTag:unknownOption
%     - getXY returns 0/1 binary aligned to parent's grid (ALIGN-02)
%     - Lazy memoize via recomputeCount_ probe
%     - Parent updateData triggers invalidation (MONITOR-04)
%     - Recursive MonitorTag invalidation
%     - Property-setter invalidation (MinDuration / ConditionFn)
%     - NaN-in-parent-Y yields 0 (ALIGN-04)
%     - toStruct kind=='monitor', parentkey set
%     - Five grep gates: Pitfall 2 code, Pitfall 2 header, MONITOR-10,
%       ALIGN-01, Octave-safety (methods (Abstract))
%
%   See also test_sensortag, test_statetag, TestMonitorTag.

    add_monitortag_path();
    TagRegistry.clear();

    % --- Construction ---
    st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
    m  = MonitorTag('m', st, @(x, y) y > 5);
    assert(isa(m, 'Tag'),            'test_monitortag: isa(Tag)');
    assert(isa(m, 'handle'),         'test_monitortag: isa(handle)');
    assert(strcmp(m.getKind(), 'monitor'), 'test_monitortag: getKind');
    assert(m.Parent == st,           'test_monitortag: Parent handle identity');
    assert(m.MinDuration == 0,       'test_monitortag: MinDuration default');
    assert(isempty(m.AlarmOffConditionFn), 'test_monitortag: AlarmOffConditionFn default');
    assert(isempty(m.EventStore),    'test_monitortag: EventStore default');
    assert(m.recomputeCount_ == 0,   'test_monitortag: recomputeCount_ == 0 before getXY');
    TagRegistry.clear();

    % --- Invalid parent ---
    threw = false;
    try
        MonitorTag('bad', struct('Key', 'x'), @(x, y) true);
    catch me
        threw = strcmp(me.identifier, 'MonitorTag:invalidParent');
    end
    assert(threw, 'test_monitortag: invalidParent error');
    TagRegistry.clear();

    % --- Invalid condition ---
    st = SensorTag('stg', 'X', 1:5, 'Y', 1:5);
    threw = false;
    try
        MonitorTag('bad', st, 'not-a-fn');
    catch me
        threw = strcmp(me.identifier, 'MonitorTag:invalidCondition');
    end
    assert(threw, 'test_monitortag: invalidCondition error');
    TagRegistry.clear();

    % --- Unknown option ---
    st = SensorTag('stg', 'X', 1:5, 'Y', 1:5);
    threw = false;
    try
        MonitorTag('m', st, @(x, y) y > 0, 'NotARealKey', 5);
    catch me
        threw = strcmp(me.identifier, 'MonitorTag:unknownOption');
    end
    assert(threw, 'test_monitortag: unknownOption error');
    TagRegistry.clear();

    % --- getXY binary output aligned to parent grid ---
    st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
    m  = MonitorTag('m', st, @(x, y) y > 5);
    [mx, my] = m.getXY();
    assert(isequal(mx(:).', 1:10), 'test_monitortag: getXY X aligned');
    assert(isequal(my(:).', double([0 0 0 0 0 1 1 1 1 1])), ...
        'test_monitortag: getXY binary Y');
    TagRegistry.clear();

    % --- Lazy memoize ---
    st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
    m  = MonitorTag('m', st, @(x, y) y > 5);
    [~, ~] = m.getXY();
    assert(m.recomputeCount_ == 1, 'test_monitortag: first getXY triggers one recompute');
    [~, ~] = m.getXY();
    assert(m.recomputeCount_ == 1, 'test_monitortag: second getXY is a cache hit');
    TagRegistry.clear();

    % --- invalidate() clears cache ---
    st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
    m  = MonitorTag('m', st, @(x, y) y > 5);
    [~, ~] = m.getXY();
    m.invalidate();
    [~, ~] = m.getXY();
    assert(m.recomputeCount_ == 2, 'test_monitortag: invalidate then getXY recomputes');
    TagRegistry.clear();

    % --- Parent updateData invalidates (MONITOR-04) ---
    st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
    m  = MonitorTag('m', st, @(x, y) y > 5);
    [~, ~] = m.getXY();
    c_before = m.recomputeCount_;
    st.updateData(11:20, 11:20);
    [mx, my] = m.getXY();
    assert(m.recomputeCount_ > c_before, ...
        'test_monitortag: parent updateData must invalidate monitor');
    assert(isequal(mx(:).', 11:20),                      'test_monitortag: updateData X');
    assert(isequal(my(:).', double([1 1 1 1 1 1 1 1 1 1])), ...
        'test_monitortag: updateData Y');
    TagRegistry.clear();

    % --- Recursive MonitorTag invalidation ---
    st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
    m1 = MonitorTag('m1', st, @(x, y) y > 5);
    m2 = MonitorTag('m2', m1, @(x, y) y > 0);
    [~, ~] = m1.getXY();
    [~, ~] = m2.getXY();
    c1_before = m1.recomputeCount_;
    c2_before = m2.recomputeCount_;
    st.updateData(1:10, 10:-1:1);
    [~, ~] = m2.getXY();
    assert(m1.recomputeCount_ > c1_before, 'test_monitortag: inner m1 must recompute');
    assert(m2.recomputeCount_ > c2_before, 'test_monitortag: outer m2 must recompute');
    TagRegistry.clear();

    % --- Setter invalidation: MinDuration ---
    st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
    m  = MonitorTag('m', st, @(x, y) y > 5);
    [~, ~] = m.getXY();
    c1 = m.recomputeCount_;
    m.MinDuration = 5;
    [~, ~] = m.getXY();
    assert(m.recomputeCount_ > c1, 'test_monitortag: MinDuration setter must invalidate');
    TagRegistry.clear();

    % --- Setter invalidation: ConditionFn ---
    st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
    m  = MonitorTag('m', st, @(x, y) y > 5);
    [~, ~] = m.getXY();
    c1 = m.recomputeCount_;
    m.ConditionFn = @(x, y) y > 100;
    [~, ~] = m.getXY();
    assert(m.recomputeCount_ > c1, 'test_monitortag: ConditionFn setter must invalidate');
    TagRegistry.clear();

    % --- NaN-in-parent-Y yields 0 (ALIGN-04) ---
    st = SensorTag('stg', 'X', 1:5, 'Y', [1 NaN 3 4 5]);
    m  = MonitorTag('m', st, @(x, y) y > 2);
    [~, my] = m.getXY();
    assert(my(2) == 0, 'test_monitortag: NaN > 2 must yield 0 (IEEE 754)');
    assert(my(1) == 0 && my(3) == 1 && my(4) == 1 && my(5) == 1, ...
        'test_monitortag: non-NaN samples compute correctly');
    TagRegistry.clear();

    % --- valueAt ---
    st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
    m  = MonitorTag('m', st, @(x, y) y > 5);
    assert(m.valueAt(3) == 0,   'test_monitortag: valueAt(3) == 0');
    assert(m.valueAt(7) == 1,   'test_monitortag: valueAt(7) == 1');
    assert(m.valueAt(100) == 1, 'test_monitortag: valueAt clamp right');
    TagRegistry.clear();

    % --- toStruct ---
    st = SensorTag('stg', 'X', 1:5, 'Y', 1:5);
    m  = MonitorTag('m', st, @(x, y) y > 0);
    s  = m.toStruct();
    assert(strcmp(s.kind, 'monitor'),    'test_monitortag: toStruct.kind');
    assert(strcmp(s.key, m.Key),         'test_monitortag: toStruct.key');
    assert(strcmp(s.parentkey, st.Key),  'test_monitortag: toStruct.parentkey');
    assert(~isfield(s, 'conditionfn'),   'test_monitortag: no conditionfn in toStruct');
    TagRegistry.clear();

    % --- resolveRefs wires parent ---
    st = SensorTag('pkey', 'X', 1:3, 'Y', [1 2 3]);
    m  = MonitorTag('mkey', st, @(x, y) y > 1);
    s  = m.toStruct();
    m2 = MonitorTag.fromStruct(s);
    map = containers.Map({st.Key}, {st});
    m2.resolveRefs(map);
    assert(m2.Parent == st, 'test_monitortag: resolveRefs wires real parent');
    TagRegistry.clear();

    % --- StateTag parent path ---
    stt = StateTag('mode', 'X', [1 5 10 20], 'Y', [0 1 2 3]);
    m   = MonitorTag('m', stt, @(x, y) y >= 2);
    [mx, my] = m.getXY();
    assert(isequal(mx(:).', [1 5 10 20]),           'test_monitortag: StateTag X grid');
    assert(isequal(my(:).', double([0 0 1 1])),     'test_monitortag: StateTag Y binary');
    c1 = m.recomputeCount_;
    stt.updateData([1 10], [0 3]);
    [~, ~] = m.getXY();
    assert(m.recomputeCount_ > c1, 'test_monitortag: StateTag updateData invalidates');
    TagRegistry.clear();

    % --- Grep gates on MonitorTag.m source ---
    src = fileread(monitortag_source_path_());
    assert(isempty(regexp(src, 'FastSenseDataStore|storeMonitor|storeResolved', 'match')), ...
        'Pitfall 2: MonitorTag.m contains forbidden persistence reference');
    assert(~isempty(regexp(src, 'lazy-by-default, no persistence', 'once')), ...
        'Pitfall 2: MonitorTag.m class header missing "lazy-by-default, no persistence"');
    assert(isempty(regexp(src, 'PerSample|OnSample|onEachSample', 'match')), ...
        'MONITOR-10: MonitorTag.m contains a per-sample callback keyword');
    assert(isempty(regexp(src, 'interp1.*''linear''', 'match')), ...
        'ALIGN-01: MonitorTag.m contains interp1 linear');
    assert(isempty(regexp(src, 'methods \(Abstract\)', 'match')), ...
        'Octave safety: MonitorTag.m must not use methods (Abstract) block');
    assert(~isempty(regexp(src, 'classdef MonitorTag < Tag', 'once')), ...
        'MonitorTag.m must extend Tag');

    fprintf('    All test_monitortag tests passed.\n');
end

function add_monitortag_path()
    %ADD_MONITORTAG_PATH Ensure repo root + tests/suite are on the path.
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    addpath(fullfile(here, 'suite'));  % for MockTag (future)
    install();
end

function p = monitortag_source_path_()
    %MONITORTAG_SOURCE_PATH_ Absolute path to MonitorTag.m for grep gates.
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    p    = fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m');
end
