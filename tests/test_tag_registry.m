function test_tag_registry()
%TEST_TAG_REGISTRY Octave flat-style port of TestTagRegistry.m
%   Mirrors the key TagRegistry assertions:
%     - register + get round-trip (TAG-03)
%     - get(missing) throws TagRegistry:unknownKey
%     - duplicate register throws TagRegistry:duplicateKey (Pitfall 7)
%     - unregister(missing) is a silent no-op
%     - findByLabel returns expected subset (META-02)
%     - findByKind returns expected subset (TAG-04)
%     - loadFromStructs is order-insensitive — forward + reverse (Pitfall 8)
%     - loadFromStructs with unknown kind throws TagRegistry:unknownKind
%     - round-trip preserves Name/Labels/Criticality (TAG-07)
%
%   See also test_tag, TestTagRegistry.

    add_tag_registry_path();
    TagRegistry.clear();

    % testRegisterAndGet
    t = MockTag('t1', 'Name', 'Tag One');
    TagRegistry.register('t1', t);
    assert(strcmp(TagRegistry.get('t1').Key, 't1'), 'test_tag_registry: register+get');
    TagRegistry.clear();

    % testGetUnknownKeyErrors
    ok = false;
    try
        TagRegistry.get('missing');
    catch me
        ok = ~isempty(strfind(me.identifier, 'TagRegistry:unknownKey'));
    end
    assert(ok, 'test_tag_registry: unknownKey error');

    % testDuplicateRegisterErrors (Pitfall 7)
    TagRegistry.register('k', MockTag('k'));
    ok = false;
    try
        TagRegistry.register('k', MockTag('k'));
    catch me
        ok = ~isempty(strfind(me.identifier, 'TagRegistry:duplicateKey'));
    end
    assert(ok, 'test_tag_registry: duplicateKey error');
    TagRegistry.clear();

    % testUnregisterMissingIsNoOp
    TagRegistry.unregister('never_registered');  % must not throw
    assert(true, 'test_tag_registry: unregister missing noop');

    % testFindByLabel (META-02)
    TagRegistry.register('a', MockTag('a', 'Labels', {'pressure', 'critical'}));
    TagRegistry.register('b', MockTag('b', 'Labels', {'temperature', 'critical'}));
    TagRegistry.register('c', MockTag('c', 'Labels', {'flow'}));
    cr = TagRegistry.findByLabel('critical');
    assert(numel(cr) == 2, 'test_tag_registry: findByLabel critical');
    pr = TagRegistry.findByLabel('pressure');
    assert(numel(pr) == 1, 'test_tag_registry: findByLabel pressure');
    TagRegistry.clear();

    % testFindByKind
    TagRegistry.register('a', MockTag('a'));
    TagRegistry.register('b', MockTag('b'));
    m = TagRegistry.findByKind('mock');
    assert(numel(m) == 2, 'test_tag_registry: findByKind mock');
    s = TagRegistry.findByKind('sensor');
    assert(isempty(s), 'test_tag_registry: findByKind sensor empty');
    TagRegistry.clear();

    % testLoadFromStructsOrderInsensitive (Pitfall 8)
    t1 = MockTag('t1');
    t2 = MockTag('t2');
    structsForward = {t1.toStruct(), t2.toStruct()};
    structsReverse = {t2.toStruct(), t1.toStruct()};

    TagRegistry.clear();
    TagRegistry.loadFromStructs(structsForward);
    assert(strcmp(TagRegistry.get('t1').Key, 't1'), 'test_tag_registry: load forward t1');
    assert(strcmp(TagRegistry.get('t2').Key, 't2'), 'test_tag_registry: load forward t2');

    TagRegistry.clear();
    TagRegistry.loadFromStructs(structsReverse);
    assert(strcmp(TagRegistry.get('t1').Key, 't1'), 'test_tag_registry: load reverse t1');
    assert(strcmp(TagRegistry.get('t2').Key, 't2'), 'test_tag_registry: load reverse t2');
    TagRegistry.clear();

    % testLoadFromStructsUnknownKindErrors
    ok = false;
    try
        TagRegistry.loadFromStructs({struct('kind', 'unknowntype', 'key', 'k')});
    catch me
        ok = ~isempty(strfind(me.identifier, 'TagRegistry:unknownKind'));
    end
    assert(ok, 'test_tag_registry: unknownKind error');

    % testRoundTripPreservesProperties (TAG-07)
    TagRegistry.clear();
    t1 = MockTag('t1', 'Name', 'Pump', 'Labels', {'a', 'b'}, 'Criticality', 'safety');
    TagRegistry.loadFromStructs({t1.toStruct()});
    got = TagRegistry.get('t1');
    assert(strcmp(got.Name, 'Pump'), 'test_tag_registry: roundtrip Name');
    assert(numel(got.Labels) == 2, 'test_tag_registry: roundtrip Labels');
    assert(strcmp(got.Criticality, 'safety'), 'test_tag_registry: roundtrip Criticality');
    TagRegistry.clear();

    % --- Phase 1005-03: SensorTag + StateTag round-trip via loadFromStructs ---
    % testRoundTripSensorTag
    tS = SensorTag('p', 'Name', 'Pump');
    TagRegistry.loadFromStructs({tS.toStruct()});
    gotS = TagRegistry.get('p');
    assert(strcmp(gotS.Key, 'p'), 'test_tag_registry: SensorTag roundtrip Key');
    assert(strcmp(gotS.Name, 'Pump'), 'test_tag_registry: SensorTag roundtrip Name');
    assert(strcmp(gotS.getKind(), 'sensor'), 'test_tag_registry: SensorTag roundtrip kind');
    TagRegistry.clear();

    % testRoundTripStateTag
    tST = StateTag('m', 'X', [1 5 10], 'Y', [0 1 2]);
    TagRegistry.loadFromStructs({tST.toStruct()});
    gotST = TagRegistry.get('m');
    assert(strcmp(gotST.Key, 'm'), 'test_tag_registry: StateTag roundtrip Key');
    assert(strcmp(gotST.getKind(), 'state'), 'test_tag_registry: StateTag roundtrip kind');
    [Xr, Yr] = gotST.getXY();
    assert(isequal(Xr, [1 5 10]), 'test_tag_registry: StateTag roundtrip X');
    assert(isequal(Yr, [0 1 2]), 'test_tag_registry: StateTag roundtrip Y');
    TagRegistry.clear();

    % --- Phase 1006-03: MonitorTag round-trip via loadFromStructs (MONITOR-02) ---
    % Forward + reverse order; Pitfall 8 order-insensitivity re-verified for the
    % 'monitor' kind. Pass-1 builds both tags; Pass-2 resolveRefs wires Parent.
    % Handle identity is asserted via Key equality (Octave-safe; Plan 01
    % SUMMARY deviation #3 documents why == / isequal on handles with listener
    % cycles hits SIGILL).
    TagRegistry.clear();
    parent_m  = SensorTag('pkey_m', 'Name', 'Pump', 'X', 1:5, 'Y', [1 2 3 4 5]);
    monitor_m = MonitorTag('mkey_m', parent_m, @(x,y) y > 2, 'Name', 'Overheat');
    parentStruct_m  = parent_m.toStruct();
    monitorStruct_m = monitor_m.toStruct();

    % Forward order
    TagRegistry.clear();
    TagRegistry.loadFromStructs({parentStruct_m, monitorStruct_m});
    lp = TagRegistry.get('pkey_m');
    lm = TagRegistry.get('mkey_m');
    assert(strcmp(lm.getKind(), 'monitor'), 'test_tag_registry: MonitorTag forward kind');
    assert(strcmp(lm.Parent.Key, lp.Key), 'test_tag_registry: MonitorTag forward Parent.Key');
    assert(strcmp(lm.Name, 'Overheat'), 'test_tag_registry: MonitorTag forward Name');

    % Reverse order (Pitfall 8 re-verification)
    TagRegistry.clear();
    TagRegistry.loadFromStructs({monitorStruct_m, parentStruct_m});
    lp2 = TagRegistry.get('pkey_m');
    lm2 = TagRegistry.get('mkey_m');
    assert(strcmp(lm2.getKind(), 'monitor'), 'test_tag_registry: MonitorTag reverse kind (Pitfall 8)');
    assert(strcmp(lm2.Parent.Key, lp2.Key), 'test_tag_registry: MonitorTag reverse Parent.Key (Pitfall 8)');
    TagRegistry.clear();

    fprintf('    All 14 test_tag_registry tests passed.\n');
end

function add_tag_registry_path()
    %ADD_TAG_REGISTRY_PATH Ensure libs/SensorThreshold and tests/suite are on the path.
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    addpath(fullfile(test_dir, 'suite'));  % so MockTag + MockTagThrowingResolve are found
    install();
end
