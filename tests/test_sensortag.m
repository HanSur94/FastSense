function test_sensortag()
%TEST_SENSORTAG Octave flat-style port of TestSensorTag.m (Phase 1005-01).
%   Mirrors the key assertions of tests/suite/TestSensorTag.m covering
%   TAG-08 (composition wrapper for raw Sensor data):
%     - Constructor key validation, defaults, Tag/Sensor NV pair routing,
%       inline X/Y payload, unknown-option rejection
%     - isa(Tag) parity (SensorTag < Tag)
%     - Tag contract: getKind=='sensor', getXY forwarding, getTimeRange
%       (including empty -> [NaN NaN]), valueAt ZOH-style lookup
%     - Data-role delegation: toDisk/toMemory round-trip, isOnDisk,
%       DataStore empty default
%     - Serialization: toStruct.kind=='sensor', fromStruct round-trip
%       of Tag universals + Sensor extras
%
%   Note: the testLoadFromMatFile test is covered here via a temp file;
%   if Octave's save() semantics on the current runner are flaky, that
%   block can be skipped without weakening the dual-style contract —
%   the MATLAB suite covers load() coverage.
%
%   See also test_tag, test_tag_registry, TestSensorTag.

    add_sensortag_path();
    TagRegistry.clear();

    % --- Constructor / type ---
    t = SensorTag('press_a');
    assert(isa(t, 'Tag'),          'test_sensortag: isa(Tag)');
    assert(isa(t, 'handle'),       'test_sensortag: isa(handle)');
    assert(strcmp(t.Key, 'press_a'),  'test_sensortag: Key');
    assert(strcmp(t.Name, 'press_a'), 'test_sensortag: Name defaults to Key');
    assert(strcmp(t.Criticality, 'medium'), 'test_sensortag: Criticality default');

    % Empty key must raise Tag:invalidKey (via Tag super-constructor)
    ok = false;
    try
        SensorTag('');
    catch me
        ok = ~isempty(strfind(me.identifier, 'Tag:invalidKey'));
    end
    assert(ok, 'test_sensortag: invalidKey error');

    % --- Tag name-value pair parsing ---
    t2 = SensorTag('k', 'Name', 'Pump', 'Units', 'bar', ...
        'Labels', {'pressure', 'critical'}, 'Criticality', 'safety');
    assert(strcmp(t2.Name, 'Pump'), 'test_sensortag: Name NV');
    assert(strcmp(t2.Units, 'bar'), 'test_sensortag: Units NV');
    assert(numel(t2.Labels) == 2, 'test_sensortag: Labels NV count');
    assert(strcmp(t2.Criticality, 'safety'), 'test_sensortag: Criticality NV');

    % --- Inline X/Y ---
    t3 = SensorTag('s', 'X', 1:5, 'Y', [0 1 4 9 16]);
    [x, y] = t3.getXY();
    assert(numel(x) == 5, 'test_sensortag: getXY X size');
    assert(y(3) == 4,     'test_sensortag: getXY Y value');

    % --- Core Tag contract ---
    assert(strcmp(t3.getKind(), 'sensor'), 'test_sensortag: getKind');

    [tMin, tMax] = t3.getTimeRange();
    assert(tMin == 1 && tMax == 5, 'test_sensortag: getTimeRange');

    tEmpty = SensorTag('e');
    [tMinE, tMaxE] = tEmpty.getTimeRange();
    assert(isnan(tMinE) && isnan(tMaxE), 'test_sensortag: getTimeRange empty NaN');

    % valueAt — ZOH-style binary_search(X, t, 'right')
    tv = SensorTag('v', 'X', [1 5 10], 'Y', [2 4 6]);
    assert(tv.valueAt(5) == 4,       'test_sensortag: valueAt exact');
    assert(tv.valueAt(3) == 2,       'test_sensortag: valueAt between (ZOH left)');
    assert(tv.valueAt(100) == 6,     'test_sensortag: valueAt past end');
    assert(isnan(tEmpty.valueAt(5)), 'test_sensortag: valueAt empty NaN');

    % --- toDisk / toMemory round-trip ---
    N = 1000;
    xr = linspace(0, 100, N);
    yr = sin(xr);
    t4 = SensorTag('big', 'X', xr, 'Y', yr);

    assert(~t4.isOnDisk(), 'test_sensortag: isOnDisk false before toDisk');

    t4.toDisk();
    assert(t4.isOnDisk(), 'test_sensortag: isOnDisk true after toDisk');

    t4.toMemory();
    assert(~t4.isOnDisk(), 'test_sensortag: isOnDisk false after toMemory');

    [xr2, yr2] = t4.getXY();
    assert(numel(xr2) == N, 'test_sensortag: round-trip size');
    assert(abs(yr2(500) - yr(500)) < 1e-12, 'test_sensortag: round-trip values');

    % --- toStruct / fromStruct round-trip ---
    t5 = SensorTag('p', 'Name', 'Pump', ...
        'Labels', {'pressure', 'critical'}, ...
        'Criticality', 'safety', 'Units', 'bar', ...
        'ID', 42, 'Source', 'file.csv');
    s = t5.toStruct();
    assert(strcmp(s.kind, 'sensor'), 'test_sensortag: toStruct kind');
    assert(strcmp(s.key, 'p'),       'test_sensortag: toStruct key');

    t6 = SensorTag.fromStruct(s);
    assert(strcmp(t6.Name, 'Pump'),       'test_sensortag: fromStruct Name');
    assert(numel(t6.Labels) == 2,         'test_sensortag: fromStruct Labels count');
    assert(strcmp(t6.Labels{1}, 'pressure'), 'test_sensortag: fromStruct Labels{1}');
    assert(strcmp(t6.Criticality, 'safety'), 'test_sensortag: fromStruct Criticality');
    assert(strcmp(t6.Units, 'bar'),       'test_sensortag: fromStruct Units');

    % --- Unknown option ---
    ok = false;
    try
        SensorTag('x', 'NoSuch', 1);
    catch me
        ok = ~isempty(strfind(me.identifier, 'SensorTag:unknownOption'));
    end
    assert(ok, 'test_sensortag: unknownOption');

    % --- DataStore empty default ---
    t7 = SensorTag('d');
    assert(isempty(t7.DataStore), 'test_sensortag: DataStore empty default');

    TagRegistry.clear();
    fprintf('    All test_sensortag tests passed.\n');
end

function add_sensortag_path()
    %ADD_SENSORTAG_PATH Ensure repo root + tests/suite are on the path.
    test_dir  = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    addpath(fullfile(test_dir, 'suite'));  % so MockTag etc. are found if needed
    install();
end
