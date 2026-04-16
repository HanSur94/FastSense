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

    fprintf('    All 11 test_tag_registry tests passed.\n');
end

function add_tag_registry_path()
    %ADD_TAG_REGISTRY_PATH Ensure libs/SensorThreshold and tests/suite are on the path.
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    addpath(fullfile(test_dir, 'suite'));  % so MockTag + MockTagThrowingResolve are found
    install();
end
