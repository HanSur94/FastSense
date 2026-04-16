classdef TestCompositeTag < matlab.unittest.TestCase
    %TESTCOMPOSITETAG Unit tests for the CompositeTag core (Phase 1008-01).
    %   Covers the public API shape + Pitfall 6 doc gate BEFORE the
    %   merge-sort implementation ships (that is Plan 02).
    %
    %   Test groups (numbered 1..22):
    %     A. Constructor / kind / Tag identity                (tests 1..8)
    %     B. addChild path (handle + string + weight + guards)(tests 9..15)
    %     C. Cycle detection DFS (self + 2-deep + 3-deep + diamond) (16..19)
    %     D. Truth-table aggregator (7 modes × NaN rows)      (tests 20..21)
    %     E. Pitfall 6 class-header truth-table doc gate      (test 22a)
    %     F. Pitfall 5 strangler-fig legacy-unchanged gate    (test 22b)
    %
    %   See also CompositeTag, Tag, MonitorTag, TagRegistry.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'tests', 'suite'));
        end
    end

    methods (TestMethodSetup)
        function resetRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function teardownRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)

        % ---- A. Constructor / kind / Tag identity ----

        function testIsATag(testCase)
            c = CompositeTag('c', 'and');
            testCase.verifyTrue(isa(c, 'Tag'));
            testCase.verifyTrue(isa(c, 'handle'));
        end

        function testGetKindCompositeLiteral(testCase)
            c = CompositeTag('c', 'and');
            testCase.verifyEqual(c.getKind(), 'composite');
        end

        function testDefaultAggregateModeIsAnd(testCase)
            c = CompositeTag('c');
            testCase.verifyEqual(c.AggregateMode, 'and');
        end

        function testConstructorAcceptsTagNVPairs(testCase)
            c = CompositeTag('c', 'or', ...
                'Name', 'display', ...
                'Labels', {'a', 'b'}, ...
                'Criticality', 'high');
            testCase.verifyEqual(c.Name, 'display');
            testCase.verifyEqual(c.Labels, {'a', 'b'});
            testCase.verifyEqual(c.Criticality, 'high');
        end

        function testConstructorUserFnRequired(testCase)
            testCase.verifyError(@() CompositeTag('c', 'user_fn'), ...
                'CompositeTag:userFnRequired');
        end

        function testConstructorUserFnProvided(testCase)
            c = CompositeTag('c', 'user_fn', 'UserFn', @(v) max(v));
            testCase.verifyEqual(c.UserFn(1:3), 3);
        end

        function testConstructorUnknownMode(testCase)
            testCase.verifyError(@() CompositeTag('c', 'xor'), ...
                'CompositeTag:invalidAggregateMode');
        end

        function testConstructorUnknownOption(testCase)
            testCase.verifyError(@() CompositeTag('c', 'and', 'BadKey', 1), ...
                'CompositeTag:unknownOption');
        end

        % ---- B. addChild path ----

        function testAddChildHandle(testCase)
            s = SensorTag('s', 'X', 1:10, 'Y', 1:10);
            m = MonitorTag('m', s, @(x, y) y > 5);
            c = CompositeTag('c', 'and');
            c.addChild(m);
            testCase.verifyEqual(c.getChildCount(), 1);
            keys = c.getChildKeys();
            testCase.verifyEqual(keys{1}, 'm');
        end

        function testAddChildByStringKey(testCase)
            s = SensorTag('s', 'X', 1:10, 'Y', 1:10);
            m = MonitorTag('m', s, @(x, y) y > 5);
            TagRegistry.register('m', m);
            c = CompositeTag('c', 'and');
            c.addChild('m');
            testCase.verifyEqual(c.getChildCount(), 1);
            keys = c.getChildKeys();
            testCase.verifyEqual(keys{1}, 'm');
        end

        function testAddChildWeight(testCase)
            s = SensorTag('s', 'X', 1:10, 'Y', 1:10);
            m = MonitorTag('m', s, @(x, y) y > 5);
            c = CompositeTag('c', 'severity');
            c.addChild(m, 'Weight', 0.7);
            w = c.getChildWeights();
            testCase.verifyEqual(w(1), 0.7, 'AbsTol', 1e-12);
        end

        function testAddChildRejectSensorTag(testCase)
            s = SensorTag('s', 'X', 1:10, 'Y', 1:10);
            c = CompositeTag('c', 'and');
            testCase.verifyError(@() c.addChild(s), ...
                'CompositeTag:invalidChildType');
        end

        function testAddChildRejectStateTag(testCase)
            st = StateTag('st', 'X', 1:5, 'Y', [1 2 1 2 1]);
            c = CompositeTag('c', 'and');
            testCase.verifyError(@() c.addChild(st), ...
                'CompositeTag:invalidChildType');
        end

        function testAddChildAcceptsCompositeTag(testCase)
            c  = CompositeTag('c',  'and');
            c2 = CompositeTag('c2', 'or');
            c.addChild(c2);
            testCase.verifyEqual(c.getChildCount(), 1);
        end

        function testAddChildRegistersListener(testCase)
            s = SensorTag('s', 'X', 1:10, 'Y', 1:10);
            m = MonitorTag('m', s, @(x, y) y > 5);
            c = CompositeTag('c', 'and');
            c.addChild(m);
            % After addChild -> invalidate() is called so dirty_ is true.
            % Simulate cache-warm: force isDirty() path via invalidation
            % event from the child.
            m.invalidate();
            testCase.verifyTrue(c.isDirty(), ...
                'composite must receive invalidate cascade from child');
        end

        % ---- C. Cycle detection DFS (Key-equality per RESEARCH §7) ----

        function testCycleSelf(testCase)
            c = CompositeTag('c', 'and');
            testCase.verifyError(@() c.addChild(c), ...
                'CompositeTag:cycleDetected');
        end

        function testCycleTwoDeep(testCase)
            a = CompositeTag('a', 'and');
            b = CompositeTag('b', 'and');
            a.addChild(b);
            testCase.verifyError(@() b.addChild(a), ...
                'CompositeTag:cycleDetected');
        end

        function testCycleThreeDeep(testCase)
            a = CompositeTag('a', 'and');
            b = CompositeTag('b', 'and');
            c = CompositeTag('c', 'and');
            a.addChild(b);
            b.addChild(c);
            testCase.verifyError(@() c.addChild(a), ...
                'CompositeTag:cycleDetected');
        end

        function testDiamondIsNotCycle(testCase)
            s    = SensorTag('s', 'X', 1:10, 'Y', 1:10);
            leaf = MonitorTag('leaf', s, @(x, y) y > 5);
            a    = CompositeTag('a', 'and');
            b    = CompositeTag('b', 'and');
            a.addChild(leaf);
            b.addChild(leaf);
            top  = CompositeTag('top', 'and');
            top.addChild(a);
            top.addChild(b);
            testCase.verifyEqual(top.getChildCount(), 2);
        end

        % ---- D. Truth-table aggregator (ALIGN-04 foreshadow) ----

        function testTruthTableAllModes(testCase)
            % RESEARCH §4 table literal, verbatim.
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
                got = CompositeTag.aggregateForTesting( ...
                    vals, weights, mode, [], thr);
                if isnan(expected)
                    testCase.verifyTrue(isnan(got), sprintf( ...
                        'Row %d mode=%s vals=[%s] expected NaN got %g', ...
                        i, mode, num2str(vals), got));
                else
                    testCase.verifyEqual(got, expected, sprintf( ...
                        'Row %d mode=%s vals=[%s] expected %g got %g', ...
                        i, mode, num2str(vals), expected, got));
                end
            end
        end

        function testUserFnMode(testCase)
            c = CompositeTag('c', 'user_fn', ...
                'UserFn', @(v) mean(v(~isnan(v))));
            out = CompositeTag.aggregateForTesting( ...
                [0.2 0.4 0.6], [1 1 1], 'user_fn', c.UserFn, 0.5);
            testCase.verifyEqual(out, 0.4, 'AbsTol', 1e-12);
        end

        % ---- E. Pitfall 6 doc gate ----

        function testClassHeaderHasTruthTables(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src = fileread(fullfile(repo, ...
                'libs', 'SensorThreshold', 'CompositeTag.m'));
            testCase.verifyGreaterThanOrEqual( ...
                numel(regexp(src, 'Truth [Tt]able')), 1, ...
                'Class header must contain the truth-table doc (Pitfall 6).');
        end

        % ---- F. Pitfall 5 legacy-unchanged strangler-fig gate ----

        function testLegacyUnchanged(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            legacy = { ...
                'Sensor', 'Threshold', 'ThresholdRule', ...
                'CompositeThreshold', 'StateChannel', ...
                'SensorRegistry', 'ThresholdRegistry', ...
                'ExternalSensorRegistry'};
            for i = 1:numel(legacy)
                fn = fullfile(repo, 'libs', 'SensorThreshold', ...
                    [legacy{i} '.m']);
                if exist(fn, 'file')
                    s = fileread(fn);
                    testCase.verifyEqual( ...
                        numel(regexp(s, 'CompositeTag')), 0, ...
                        sprintf('Legacy file %s.m must not reference CompositeTag.', ...
                            legacy{i}));
                end
            end
        end

        % ---- H. Serialization round-trip (Plan 02 — COMPOSITE-05 via toStruct) ----

        function testToStructMinimalComposite(testCase)
            %TESTTOSTRUCTMINIMALCOMPOSITE Plan 02: toStruct shape with no children.
            c = CompositeTag('c', 'or');
            s = c.toStruct();
            testCase.verifyEqual(s.kind, 'composite');
            testCase.verifyEqual(s.key, 'c');
            testCase.verifyEqual(s.aggregatemode, 'or');
            testCase.verifyEqual(s.threshold, 0.5, 'AbsTol', 1e-12);
            testCase.verifyTrue(isfield(s, 'childkeys'), ...
                'toStruct must carry childkeys field');
            testCase.verifyTrue(isfield(s, 'childweights'), ...
                'toStruct must carry childweights field');
            % Empty children -> empty lists.
            ck = s.childkeys;
            if iscell(ck) && numel(ck) == 1 && iscell(ck{1})
                ck = ck{1};   % unwrap defensive double-wrap
            end
            testCase.verifyEqual(numel(ck), 0, 'No children -> empty childkeys');
            testCase.verifyEqual(numel(s.childweights), 0, ...
                'No children -> empty childweights');
        end

        function testFromStructEmptyChildren(testCase)
            %TESTFROMSTRUCTEMPTYCHILDREN Plan 02: fromStruct reconstructs empty composite.
            c = CompositeTag('c', 'majority', ...
                'Name', 'agg', 'Criticality', 'high');
            s = c.toStruct();
            c2 = CompositeTag.fromStruct(s);
            testCase.verifyEqual(c2.Key, 'c');
            testCase.verifyEqual(c2.AggregateMode, 'majority');
            testCase.verifyEqual(c2.Name, 'agg');
            testCase.verifyEqual(c2.Criticality, 'high');
            testCase.verifyEqual(c2.getChildCount(), 0);
        end

        function testRoundTripCompositeWith2Children(testCase)
            %TESTROUNDTRIPCOMPOSITEWITH2CHILDREN Plan 02: local two-pass loader wires children.
            s1 = SensorTag('s1', 'X', 1:10, 'Y', 1:10);
            s2 = SensorTag('s2', 'X', 1:10, 'Y', 1:10);
            m1 = MonitorTag('m1', s1, @(x, y) y > 5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 5);
            c  = CompositeTag('c', 'or');
            c.addChild(m1);
            c.addChild(m2);
            structs = { ...
                s1.toStruct(), s2.toStruct(), ...
                m1.toStruct(), m2.toStruct(), ...
                c.toStruct()};
            TestCompositeTag.helperLoadStructsLocal_(structs);
            loadedC = TagRegistry.get('c');
            testCase.verifyEqual(loadedC.getKind(), 'composite');
            testCase.verifyEqual(loadedC.AggregateMode, 'or');
            keys = loadedC.getChildKeys();
            testCase.verifyEqual(keys, {'m1', 'm2'}, ...
                'Loaded composite must carry both children in original order.');
        end

        function testRoundTrip3DeepComposite(testCase)
            %TESTROUNDTRIP3DEEPCOMPOSITE Plan 02: 3-deep composite-of-composite-of-composite.
            %   Pitfall 8 gate. Uses local two-pass loader (Plan 02 bypasses
            %   TagRegistry.instantiateByKind which gains 'composite' case in
            %   Plan 03). Plan 03 VALIDATION will re-run via the real
            %   TagRegistry.loadFromStructs.
            s1 = SensorTag('s1', 'X', 1:10, 'Y', 1:10);
            s2 = SensorTag('s2', 'X', 1:10, 'Y', 1:10);
            s3 = SensorTag('s3', 'X', 1:10, 'Y', 1:10);
            s4 = SensorTag('s4', 'X', 1:10, 'Y', 1:10);
            m1 = MonitorTag('m1', s1, @(x, y) y > 5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 5);
            m3 = MonitorTag('m3', s3, @(x, y) y > 5);
            m4 = MonitorTag('m4', s4, @(x, y) y > 5);
            mid_L = CompositeTag('mid_L', 'or');
            mid_L.addChild(m1);
            mid_L.addChild(m2);
            mid_R = CompositeTag('mid_R', 'majority');
            mid_R.addChild(m3);
            mid_R.addChild(m4);
            top = CompositeTag('top', 'and');
            top.addChild(mid_L);
            top.addChild(mid_R);

            structs = { ...
                s1.toStruct(), s2.toStruct(), s3.toStruct(), s4.toStruct(), ...
                m1.toStruct(), m2.toStruct(), m3.toStruct(), m4.toStruct(), ...
                mid_L.toStruct(), mid_R.toStruct(), top.toStruct()};
            TestCompositeTag.helperLoadStructsLocal_(structs);

            loadedTop = TagRegistry.get('top');
            testCase.verifyEqual(loadedTop.getKind(), 'composite');
            testCase.verifyEqual(loadedTop.AggregateMode, 'and');
            testCase.verifyEqual(loadedTop.getChildKeys(), {'mid_L', 'mid_R'}, ...
                '3-deep: top children by Key.');
            % Descend one level — mid_L's children
            loadedMidL = loadedTop.getChildAt(1);
            testCase.verifyEqual(loadedMidL.Key, 'mid_L');
            testCase.verifyEqual(loadedMidL.AggregateMode, 'or');
            testCase.verifyEqual(loadedMidL.getChildKeys(), {'m1', 'm2'});
            % 3-deep descent — Pitfall 8 proof.
            testCase.verifyEqual(loadedTop.getChildAt(1).getChildAt(1).Key, 'm1', ...
                '3-deep descent: top -> mid_L -> m1.');
            testCase.verifyEqual(loadedTop.getChildAt(2).getChildAt(2).Key, 'm4', ...
                '3-deep descent: top -> mid_R -> m4.');
        end

        function testRoundTrip3DeepReverseOrder(testCase)
            %TESTROUNDTRIP3DEEPREVERSEORDER Pitfall 8: order-insensitive two-phase loader.
            s1 = SensorTag('s1', 'X', 1:10, 'Y', 1:10);
            s2 = SensorTag('s2', 'X', 1:10, 'Y', 1:10);
            s3 = SensorTag('s3', 'X', 1:10, 'Y', 1:10);
            s4 = SensorTag('s4', 'X', 1:10, 'Y', 1:10);
            m1 = MonitorTag('m1', s1, @(x, y) y > 5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 5);
            m3 = MonitorTag('m3', s3, @(x, y) y > 5);
            m4 = MonitorTag('m4', s4, @(x, y) y > 5);
            mid_L = CompositeTag('mid_L', 'or');
            mid_L.addChild(m1); mid_L.addChild(m2);
            mid_R = CompositeTag('mid_R', 'majority');
            mid_R.addChild(m3); mid_R.addChild(m4);
            top = CompositeTag('top', 'and');
            top.addChild(mid_L); top.addChild(mid_R);

            structs = { ...
                s1.toStruct(), s2.toStruct(), s3.toStruct(), s4.toStruct(), ...
                m1.toStruct(), m2.toStruct(), m3.toStruct(), m4.toStruct(), ...
                mid_L.toStruct(), mid_R.toStruct(), top.toStruct()};
            % Reverse order — top struct first, monitors last.
            structsReversed = fliplr(structs);
            TestCompositeTag.helperLoadStructsLocal_(structsReversed);

            loadedTop = TagRegistry.get('top');
            testCase.verifyEqual(loadedTop.getChildKeys(), {'mid_L', 'mid_R'}, ...
                'Reverse order: two-phase loader remains order-insensitive (Pitfall 8).');
            testCase.verifyEqual(loadedTop.getChildAt(1).getChildAt(1).Key, 'm1');
        end

        % ---- I. File-budget discipline watermark ----

        function testFileBudgetWatermark(testCase)
            %TESTFILEBUDGETWATERMARK Pitfall 8 file-count discipline.
            %   3-deep round-trip test lives in TestCompositeTag.m, NOT in
            %   TestTagRegistry.m. Asserts TestTagRegistry.m stays clean.
            here = fileparts(mfilename('fullpath'));
            src = fileread(fullfile(here, 'TestTagRegistry.m'));
            testCase.verifyTrue(isempty(regexp(src, 'CompositeTag', 'once')), ...
                'TestTagRegistry.m must not reference CompositeTag (file-budget).');
        end

        % ---- J. Plan 03 production-path integration (Pitfall 8 end-to-end) ----

        function testRoundTrip3DeepViaProductionTagRegistry(testCase)
            %TESTROUNDTRIP3DEEPVIAPRODUCTIONTAGREGISTRY Plan 03 integration gate.
            %   Same 11-tag fixture as testRoundTrip3DeepComposite, but loaded
            %   via the REAL TagRegistry.loadFromStructs path (exercises the
            %   Plan 03 instantiateByKind 'composite' case, not the local
            %   helper). Order-insensitivity verified via forward order.
            TagRegistry.clear();
            s1 = SensorTag('s1','X',1:10,'Y',1:10);
            s2 = SensorTag('s2','X',1:10,'Y',1:10);
            s3 = SensorTag('s3','X',1:10,'Y',1:10);
            s4 = SensorTag('s4','X',1:10,'Y',1:10);
            m1 = MonitorTag('m1', s1, @(x, y) y > 5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 5);
            m3 = MonitorTag('m3', s3, @(x, y) y > 5);
            m4 = MonitorTag('m4', s4, @(x, y) y > 5);
            mid_L = CompositeTag('mid_L', 'or');
            mid_L.addChild(m1); mid_L.addChild(m2);
            mid_R = CompositeTag('mid_R', 'majority');
            mid_R.addChild(m3); mid_R.addChild(m4);
            top = CompositeTag('top', 'and');
            top.addChild(mid_L); top.addChild(mid_R);

            structs = {s1.toStruct(), s2.toStruct(), s3.toStruct(), s4.toStruct(), ...
                       m1.toStruct(), m2.toStruct(), m3.toStruct(), m4.toStruct(), ...
                       mid_L.toStruct(), mid_R.toStruct(), top.toStruct()};
            TagRegistry.clear();
            TagRegistry.loadFromStructs(structs);   % PRODUCTION PATH

            loadedTop = TagRegistry.get('top');
            testCase.verifyEqual(loadedTop.getKind(), 'composite');
            testCase.verifyEqual(loadedTop.AggregateMode, 'and');
            testCase.verifyEqual(loadedTop.getChildKeys(), {'mid_L', 'mid_R'});
            % 3-deep descent via Key equality (never isequal on handles).
            testCase.verifyEqual(loadedTop.getChildAt(1).getChildAt(1).Key, 'm1');
            testCase.verifyEqual(loadedTop.getChildAt(2).getChildAt(2).Key, 'm4');
            TagRegistry.clear();
        end

        function testPitfall1NoIsaInFastSenseAddTag(testCase)
            %TESTPITFALL1NOISAINFASTSENSEADDTAG Pitfall 1 grep gate.
            %   FastSense.addTag must dispatch by tag.getKind(), NOT by
            %   isa(tag, 'SensorTag'|'StateTag'|'MonitorTag'|'CompositeTag').
            %   (The invalidTag guard at the top uses isa(tag, 'Tag') for the
            %   base class — that is permitted. The prohibition is on
            %   SUBCLASS-specific isa branching inside the kind dispatch.)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src = fileread(fullfile(repo, 'libs', 'FastSense', 'FastSense.m'));
            matches = regexp(src, ...
                'isa\s*\(\s*tag\s*,\s*''(SensorTag|StateTag|MonitorTag|CompositeTag)''', ...
                'tokens');
            testCase.verifyEmpty(matches, ...
                'Pitfall 1: FastSense.addTag must dispatch by getKind(), NOT isa(tag, subclass).');
        end

    end

    methods (Static, Access = private)

        function helperLoadStructsLocal_(structs)
            %HELPERLOADSTRUCTSLOCAL_ Local two-pass loader (Plan 02 workaround).
            %   Plan 02 ships CompositeTag.fromStruct + resolveRefs but does
            %   NOT edit TagRegistry.instantiateByKind (that is Plan 03).
            %   This helper dispatches kinds inline so the 3-deep round-trip
            %   tests are runnable in Plan 02. Plan 03's VALIDATION re-runs
            %   the 3-deep scenario through the real TagRegistry.loadFromStructs.
            TagRegistry.clear();
            map = containers.Map();
            % Pass 1 — instantiate + register.
            for i = 1:numel(structs)
                s = structs{i};
                switch lower(s.kind)
                    case 'sensor'
                        tag = SensorTag.fromStruct(s);
                    case 'state'
                        tag = StateTag.fromStruct(s);
                    case 'monitor'
                        tag = MonitorTag.fromStruct(s);
                    case 'composite'
                        tag = CompositeTag.fromStruct(s);
                    case 'mock'
                        tag = MockTag.fromStruct(s);
                    otherwise
                        error('TestCompositeTag:helperUnknownKind', ...
                            'Unknown kind ''%s'' in local loader.', s.kind);
                end
                TagRegistry.register(tag.Key, tag);
                map(tag.Key) = tag;
            end
            % Pass 2 — resolve refs.
            keys = map.keys();
            for i = 1:numel(keys)
                tag = map(keys{i});
                if ismethod(tag, 'resolveRefs')
                    tag.resolveRefs(map);
                end
            end
        end

    end
end
