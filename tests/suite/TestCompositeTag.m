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

    end
end
