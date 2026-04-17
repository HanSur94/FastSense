classdef TestTagRegistry < matlab.unittest.TestCase
    %TESTTAGREGISTRY Unit tests for the TagRegistry singleton.
    %   Covers CRUD (TAG-03), query (TAG-04, META-02), introspection
    %   (TAG-05), and two-phase deserialization (TAG-06, TAG-07) with
    %   Pitfall 7 (duplicate-key hard error) and Pitfall 8 (order-
    %   insensitive loadFromStructs plus unresolvedRef wrap) gates.
    %
    %   See also TagRegistry, MockTag, MockTagThrowingResolve.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function clearBefore(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function clearAfter(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)

        % ---- CRUD (TAG-03) ----

        function testRegisterAndGet(testCase)
            t = MockTag('t1', 'Name', 'Tag One');
            TagRegistry.register('t1', t);
            got = TagRegistry.get('t1');
            testCase.verifyEqual(got.Key, 't1');
            testCase.verifyEqual(got.Name, 'Tag One');
        end

        function testRegisterRejectsNonTag(testCase)
            testCase.verifyError(@() TagRegistry.register('k', struct('x', 1)), ...
                'TagRegistry:invalidType');
        end

        function testGetUnknownKeyErrors(testCase)
            testCase.verifyError(@() TagRegistry.get('missing'), ...
                'TagRegistry:unknownKey');
        end

        function testUnregisterRemoves(testCase)
            TagRegistry.register('t1', MockTag('t1'));
            TagRegistry.unregister('t1');
            testCase.verifyError(@() TagRegistry.get('t1'), 'TagRegistry:unknownKey');
        end

        function testUnregisterMissingIsNoOp(testCase) %#ok<MANU>
            TagRegistry.unregister('never_registered');  % must not throw
        end

        function testClearEmptiesAll(testCase)
            TagRegistry.register('a', MockTag('a'));
            TagRegistry.register('b', MockTag('b'));
            TagRegistry.register('c', MockTag('c'));
            TagRegistry.clear();
            testCase.verifyEmpty(TagRegistry.find(@(t) true));
        end

        function testDuplicateRegisterErrors(testCase)
            TagRegistry.register('k', MockTag('k'));
            testCase.verifyError(@() TagRegistry.register('k', MockTag('k')), ...
                'TagRegistry:duplicateKey');
        end

        function testDuplicateRegisterPreservesOriginal(testCase)
            original = MockTag('k', 'Name', 'Original');
            TagRegistry.register('k', original);
            replacement = MockTag('k', 'Name', 'Replacement');
            try
                TagRegistry.register('k', replacement); %#ok<NASGU>
            catch
                % expected
            end
            got = TagRegistry.get('k');
            testCase.verifyEqual(got.Name, 'Original');
        end

        % ---- Query (TAG-04, META-02) ----

        function testFindAll(testCase)
            TagRegistry.register('a', MockTag('a'));
            TagRegistry.register('b', MockTag('b'));
            TagRegistry.register('c', MockTag('c'));
            ts = TagRegistry.find(@(t) true);
            testCase.verifyEqual(numel(ts), 3);
        end

        function testFindWithPredicate(testCase)
            TagRegistry.register('a', MockTag('a', 'Criticality', 'safety'));
            TagRegistry.register('b', MockTag('b', 'Criticality', 'medium'));
            TagRegistry.register('c', MockTag('c', 'Criticality', 'safety'));
            ts = TagRegistry.find(@(t) strcmp(t.Criticality, 'safety'));
            testCase.verifyEqual(numel(ts), 2);
        end

        function testFindByLabel(testCase)
            TagRegistry.register('a', MockTag('a', 'Labels', {'pressure', 'critical'}));
            TagRegistry.register('b', MockTag('b', 'Labels', {'temperature', 'critical'}));
            TagRegistry.register('c', MockTag('c', 'Labels', {'flow'}));
            cr = TagRegistry.findByLabel('critical');
            pr = TagRegistry.findByLabel('pressure');
            testCase.verifyEqual(numel(cr), 2);
            testCase.verifyEqual(numel(pr), 1);
        end

        function testFindByLabelEmpty(testCase)
            TagRegistry.register('a', MockTag('a'));
            testCase.verifyEmpty(TagRegistry.findByLabel('nonexistent'));
        end

        function testFindByKind(testCase)
            TagRegistry.register('a', MockTag('a'));
            TagRegistry.register('b', MockTag('b'));
            ts = TagRegistry.findByKind('mock');
            testCase.verifyEqual(numel(ts), 2);
            ts2 = TagRegistry.findByKind('sensor');
            testCase.verifyEmpty(ts2);
        end

        % ---- Introspection (TAG-05) ----

        function testListPrintsKeys(testCase)
            TagRegistry.register('alpha', MockTag('alpha', 'Name', 'Alpha One'));
            TagRegistry.register('beta',  MockTag('beta',  'Name', 'Beta Two'));
            out = evalc('TagRegistry.list()');
            testCase.verifyTrue(~isempty(strfind(out, 'alpha')));
            testCase.verifyTrue(~isempty(strfind(out, 'beta')));
        end

        function testPrintTableHeader(testCase)
            TagRegistry.register('a', MockTag('a', 'Name', 'A'));
            out = evalc('TagRegistry.printTable()');
            testCase.verifyTrue(~isempty(strfind(out, 'Key')));
            testCase.verifyTrue(~isempty(strfind(out, 'Kind')));
            testCase.verifyTrue(~isempty(strfind(out, 'Criticality')));
        end

        function testPrintTableEmpty(testCase)
            out = evalc('TagRegistry.printTable()');
            testCase.verifyTrue(~isempty(strfind(out, 'No tags')));
        end

        % ---- Two-phase deserialization (TAG-06, TAG-07, Pitfall 8) ----

        function testLoadFromStructsSingleTag(testCase)
            t = MockTag('t1', 'Name', 'Tag One');
            s = t.toStruct();
            TagRegistry.clear();
            TagRegistry.loadFromStructs({s});
            got = TagRegistry.get('t1');
            testCase.verifyEqual(got.Key, 't1');
        end

        function testLoadFromStructsMultipleTags(testCase)
            t1 = MockTag('t1', 'Labels', {'a'});
            t2 = MockTag('t2', 'Labels', {'b'});
            t3 = MockTag('t3', 'Labels', {'c'});
            structs = {t1.toStruct(), t2.toStruct(), t3.toStruct()};
            TagRegistry.clear();
            TagRegistry.loadFromStructs(structs);
            testCase.verifyEqual(TagRegistry.get('t1').Labels{1}, 'a');
            testCase.verifyEqual(TagRegistry.get('t2').Labels{1}, 'b');
            testCase.verifyEqual(TagRegistry.get('t3').Labels{1}, 'c');
        end

        function testLoadFromStructsOrderInsensitive(testCase)
            % Pitfall 8 gate — two-phase loader must be order-insensitive.
            t1 = MockTag('t1');
            t2 = MockTag('t2');
            structsForward = {t1.toStruct(), t2.toStruct()};
            structsReverse = {t2.toStruct(), t1.toStruct()};

            TagRegistry.clear();
            TagRegistry.loadFromStructs(structsForward);
            testCase.verifyEqual(TagRegistry.get('t1').Key, 't1');
            testCase.verifyEqual(TagRegistry.get('t2').Key, 't2');

            TagRegistry.clear();
            TagRegistry.loadFromStructs(structsReverse);
            testCase.verifyEqual(TagRegistry.get('t1').Key, 't1');
            testCase.verifyEqual(TagRegistry.get('t2').Key, 't2');
        end

        function testLoadFromStructsUnknownKindErrors(testCase)
            badStruct = struct('kind', 'unknowntype', 'key', 'k');
            testCase.verifyError(@() TagRegistry.loadFromStructs({badStruct}), ...
                'TagRegistry:unknownKind');
        end

        function testLoadFromStructsDuplicateKeyInInputErrors(testCase)
            s = MockTag('dup').toStruct();
            testCase.verifyError(@() TagRegistry.loadFromStructs({s, s}), ...
                'TagRegistry:duplicateKey');
        end

        function testLoadFromStructsUnresolvedRefErrors(testCase)
            % Pitfall 8 gate — a resolveRefs error must surface as
            % TagRegistry:unresolvedRef (the registry wraps the error).
            t = MockTagThrowingResolve('t1');
            s = t.toStruct();
            TagRegistry.clear();
            testCase.verifyError(@() TagRegistry.loadFromStructs({s}), ...
                'TagRegistry:unresolvedRef');
        end

        % ---- Round-trip (TAG-07) ----

        function testRoundTripPreservesProperties(testCase)
            t1 = MockTag('t1', 'Name', 'Pump', ...
                'Labels', {'a', 'b'}, 'Criticality', 'safety');
            structs = {t1.toStruct()};
            TagRegistry.clear();
            TagRegistry.loadFromStructs(structs);
            got = TagRegistry.get('t1');
            testCase.verifyEqual(got.Name, 'Pump');
            testCase.verifyEqual(numel(got.Labels), 2);
            testCase.verifyEqual(got.Labels{1}, 'a');
            testCase.verifyEqual(got.Criticality, 'safety');
        end

        % ---- Phase 1005-03: SensorTag + StateTag round-trip via loadFromStructs ----

        function testRoundTripSensorTag(testCase)
            % Phase 1005-03: TagRegistry.instantiateByKind must dispatch
            % 'sensor' to SensorTag.fromStruct.
            t = SensorTag('p', 'Name', 'Pump');
            s = t.toStruct();
            TagRegistry.clear();
            TagRegistry.loadFromStructs({s});
            got = TagRegistry.get('p');
            testCase.verifyEqual(got.Key, 'p');
            testCase.verifyEqual(got.Name, 'Pump');
            testCase.verifyEqual(got.getKind(), 'sensor');
        end

        function testRoundTripStateTag(testCase)
            % Phase 1005-03: TagRegistry.instantiateByKind must dispatch
            % 'state' to StateTag.fromStruct.
            t = StateTag('m', 'X', [1 5 10], 'Y', [0 1 2]);
            s = t.toStruct();
            TagRegistry.clear();
            TagRegistry.loadFromStructs({s});
            got = TagRegistry.get('m');
            testCase.verifyEqual(got.Key, 'm');
            testCase.verifyEqual(got.getKind(), 'state');
            [X, Y] = got.getXY();
            testCase.verifyEqual(X, [1 5 10]);
            testCase.verifyEqual(Y, [0 1 2]);
        end

        % ---- Phase 1006-03: MonitorTag round-trip via loadFromStructs ----

        function testRoundTripMonitorTag(testCase)
            %TESTROUNDTRIPMONITORTAG MonitorTag round-trip via loadFromStructs (forward + reverse order).
            %   Pass-1 instantiates both tags; Pass-2 resolveRefs wires the Parent handle.
            %   Reverse order (monitor first, parent second) re-exercises Pitfall 8
            %   order-insensitivity for the 'monitor' kind.
            %
            %   Handle identity is proven via Key equality + observable listener
            %   wiring (Octave isequal on user-defined handles with listener
            %   cycles hits SIGILL — see Plan 01 SUMMARY deviation #3).

            % --- Forward order: parent struct first, monitor struct second ---
            TagRegistry.clear();
            parent = SensorTag('pkey', 'Name', 'Pump', 'X', 1:5, 'Y', [1 2 3 4 5]);
            monitor = MonitorTag('mkey', parent, @(x,y) y > 2, 'Name', 'Overheat');
            parentStruct  = parent.toStruct();
            monitorStruct = monitor.toStruct();

            TagRegistry.clear();
            TagRegistry.loadFromStructs({parentStruct, monitorStruct});

            loadedParent  = TagRegistry.get('pkey');
            loadedMonitor = TagRegistry.get('mkey');
            testCase.verifyEqual(loadedMonitor.getKind(), 'monitor');
            testCase.verifyEqual(loadedMonitor.Parent.Key, loadedParent.Key, ...
                'Forward order: loadedMonitor.Parent.Key must equal loadedParent.Key.');
            testCase.verifyEqual(loadedMonitor.Name, 'Overheat');

            % --- Reverse order: monitor struct first, parent struct second ---
            %   Pitfall 8 re-verification: two-phase loader must be order-insensitive
            %   for the 'monitor' kind. Pass-1 instantiates MonitorTag with a
            %   dummy parent; Pass-2 resolveRefs(registry) wires the real parent
            %   regardless of input order.
            TagRegistry.clear();
            TagRegistry.loadFromStructs({monitorStruct, parentStruct});

            loadedParent2  = TagRegistry.get('pkey');
            loadedMonitor2 = TagRegistry.get('mkey');
            testCase.verifyEqual(loadedMonitor2.getKind(), 'monitor');
            testCase.verifyEqual(loadedMonitor2.Parent.Key, loadedParent2.Key, ...
                'Reverse order: loadedMonitor.Parent.Key must equal loadedParent.Key (Pitfall 8).');

            TagRegistry.clear();
        end
    end
end
