function test_statetag()
%TEST_STATETAG Octave flat-style port of TestStateTag.m (Phase 1005-02).
%   Mirrors the key assertions of tests/suite/TestStateTag.m:
%     - isa(Tag) subtype relationship
%     - getKind() returns 'state'
%     - ZOH numeric 7-point golden fixture (byte-for-byte StateChannel match)
%     - ZOH numeric vector form
%     - ZOH cellstr scalar form
%     - Empty-state guard (StateTag:emptyState)
%     - toStruct emits kind='state'
%     - fromStruct round-trip for numeric AND cellstr Y
%
%   See also test_state_channel, test_tag, TestStateTag.

    add_statetag_path();
    try
        TagRegistry.clear();
    catch
        % TagRegistry may not be on path in isolated runs; ignore.
    end

    % isa + kind
    t = StateTag('mode');
    assert(isa(t, 'Tag'), 'test_statetag: isa(Tag)');
    assert(strcmp(t.getKind(), 'state'), 'test_statetag: getKind');

    % Numeric ZOH golden points (copied verbatim from test_state_channel.m)
    t = StateTag('s', 'X', [1 5 10 20], 'Y', [0 1 2 3]);
    assert(t.valueAt(0)   == 0, 'zoh @ 0');
    assert(t.valueAt(1)   == 0, 'zoh @ 1');
    assert(t.valueAt(3)   == 0, 'zoh @ 3');
    assert(t.valueAt(5)   == 1, 'zoh @ 5');
    assert(t.valueAt(7)   == 1, 'zoh @ 7');
    assert(t.valueAt(15)  == 2, 'zoh @ 15');
    assert(t.valueAt(100) == 3, 'zoh @ 100');

    % Numeric vector form
    assert(isequal(t.valueAt([0 3 5 7 15]), [0 0 1 1 2]), 'zoh vector');

    % Cellstr ZOH
    t2 = StateTag('m', 'X', [1 5 10], 'Y', {'off', 'running', 'evacuated'});
    assert(strcmp(t2.valueAt(3),  'off'),       'cellstr @ 3');
    assert(strcmp(t2.valueAt(7),  'running'),   'cellstr @ 7');
    assert(strcmp(t2.valueAt(15), 'evacuated'), 'cellstr @ 15');

    % getTimeRange
    [tMin, tMax] = t.getTimeRange();
    assert(tMin == 1 && tMax == 20, 'test_statetag: getTimeRange non-empty');
    [nMin, nMax] = StateTag('e').getTimeRange();
    assert(isnan(nMin) && isnan(nMax), 'test_statetag: getTimeRange empty -> NaN');

    % Empty-state guard
    ok = false;
    try
        StateTag('e').valueAt(0);
    catch me
        ok = ~isempty(strfind(me.identifier, 'StateTag:emptyState'));
    end
    assert(ok, 'test_statetag: emptyState error');

    % Unknown option
    ok = false;
    try
        StateTag('k', 'NoSuch', 1);
    catch me
        ok = ~isempty(strfind(me.identifier, 'StateTag:unknownOption'));
    end
    assert(ok, 'test_statetag: unknownOption error');

    % toStruct / fromStruct numeric round-trip
    t3 = StateTag('mm', 'X', [1 5 10], 'Y', [0 1 2], ...
                  'Name', 'Mode', 'Labels', {'state', 'machine'}, 'Criticality', 'high');
    s = t3.toStruct();
    assert(strcmp(s.kind, 'state'), 'test_statetag: toStruct kind');
    t4 = StateTag.fromStruct(s);
    assert(strcmp(t4.Key, 'mm'),       'test_statetag: fromStruct Key');
    assert(strcmp(t4.Name, 'Mode'),    'test_statetag: fromStruct Name');
    assert(isequal(t4.X, [1 5 10]),    'test_statetag: fromStruct X');
    assert(isequal(t4.Y, [0 1 2]),     'test_statetag: fromStruct Y');
    assert(numel(t4.Labels) == 2,      'test_statetag: fromStruct Labels');
    assert(strcmp(t4.Criticality, 'high'), 'test_statetag: fromStruct Criticality');

    % toStruct / fromStruct cellstr round-trip
    t5 = StateTag('cc', 'X', [1 5 10], 'Y', {'off', 'running', 'idle'});
    s2 = t5.toStruct();
    t6 = StateTag.fromStruct(s2);
    assert(iscell(t6.Y),            'test_statetag: fromStruct cellstr Y type');
    assert(numel(t6.Y) == 3,        'test_statetag: fromStruct cellstr Y count');
    assert(strcmp(t6.Y{1}, 'off'),  'test_statetag: fromStruct cellstr Y{1}');
    assert(strcmp(t6.Y{2}, 'running'), 'test_statetag: fromStruct cellstr Y{2}');
    assert(strcmp(t6.Y{3}, 'idle'), 'test_statetag: fromStruct cellstr Y{3}');

    fprintf('    All test_statetag tests passed.\n');
end

function add_statetag_path()
    %ADD_STATETAG_PATH Ensure libs/SensorThreshold and tests/suite are on the path.
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    addpath(fullfile(test_dir, 'suite'));
    install();
end
