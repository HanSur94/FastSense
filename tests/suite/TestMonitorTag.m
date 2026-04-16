classdef TestMonitorTag < matlab.unittest.TestCase
    %TESTMONITORTAG Unit tests for the MonitorTag core (Phase 1006-01).
    %   Covers:
    %     - Constructor defaults, invalidParent/invalidCondition/unknownOption errors
    %     - isa(Tag) parity; getKind() -> 'monitor'
    %     - getXY binary 0/1 output aligned to parent's grid (ALIGN-02)
    %     - Lazy memoize: first getXY computes; second is a cache hit
    %     - invalidate() clears cache
    %     - Parent updateData triggers listener invalidation (MONITOR-04)
    %     - Recursive MonitorTag invalidation propagation
    %     - Property setters (MinDuration/ConditionFn/AlarmOffConditionFn) invalidate
    %     - valueAt ZOH semantics + empty-data NaN
    %     - getTimeRange
    %     - NaN in parent Y produces 0 (IEEE 754 default — ALIGN-04)
    %     - toStruct shape (kind='monitor', parentkey present, no conditionfn)
    %     - resolveRefs wiring (Pass-2 deserialization) and unresolvedParent error
    %     - Pitfall 2 grep gates (no persistence + class-header doc)
    %     - MONITOR-10 grep gate (no per-sample callbacks)
    %     - ALIGN-01 grep gate (no interp1 linear)
    %     - Octave-safety grep gate (no methods (Abstract) block)
    %     - classdef gate (classdef MonitorTag < Tag exactly once)
    %
    %   See also MonitorTag, Tag, SensorTag, StateTag, TagRegistry.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'tests', 'suite'));  % for MockTag
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

        % ---- Constructor / type ----

        function testConstructorDefaults(testCase)
            st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
            m  = MonitorTag('m', st, @(x, y) y > 0);
            testCase.verifyEqual(m.Key, 'm');
            testCase.verifyTrue(m.Parent == st, 'Parent handle identity preserved');
            testCase.verifyEqual(m.getKind(), 'monitor');
            testCase.verifyTrue(isa(m, 'Tag'));
            testCase.verifyTrue(isa(m, 'handle'));
            testCase.verifyEqual(m.MinDuration, 0);
            testCase.verifyEmpty(m.AlarmOffConditionFn);
            testCase.verifyEmpty(m.EventStore);
            testCase.verifyEqual(m.Criticality, 'medium');
            testCase.verifyEqual(m.recomputeCount_, 0, ...
                'recomputeCount_ must be 0 before any getXY call');
        end

        function testConstructorRejectsNonTagParent(testCase)
            testCase.verifyError( ...
                @() MonitorTag('m', struct('Key', 'fake'), @(x, y) true), ...
                'MonitorTag:invalidParent');
        end

        function testConstructorRejectsNonFunctionCondition(testCase)
            st = SensorTag('stg', 'X', 1:5, 'Y', 1:5);
            testCase.verifyError( ...
                @() MonitorTag('m', st, 'not-a-fn'), ...
                'MonitorTag:invalidCondition');
        end

        function testConstructorUnknownOption(testCase)
            st = SensorTag('stg', 'X', 1:5, 'Y', 1:5);
            testCase.verifyError( ...
                @() MonitorTag('m', st, @(x, y) y > 0, 'NotARealKey', 5), ...
                'MonitorTag:unknownOption');
        end

        function testIsATag(testCase)
            st = SensorTag('stg', 'X', 1:5, 'Y', 1:5);
            m  = MonitorTag('m', st, @(x, y) y > 0);
            testCase.verifyTrue(isa(m, 'Tag'));
            testCase.verifyTrue(isa(m, 'handle'));
        end

        % ---- Core Tag contract ----

        function testGetXYBinaryAlignedToParentGrid(testCase)
            st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
            m  = MonitorTag('m', st, @(x, y) y > 5);
            [mx, my] = m.getXY();
            testCase.verifyEqual(mx(:).', 1:10);
            testCase.verifyEqual(my(:).', double([0 0 0 0 0 1 1 1 1 1]));
        end

        function testLazyMemoize(testCase)
            st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
            m  = MonitorTag('m', st, @(x, y) y > 5);
            [~, ~] = m.getXY();
            testCase.verifyEqual(m.recomputeCount_, 1, ...
                'First getXY must trigger exactly one recompute');
            [~, ~] = m.getXY();
            testCase.verifyEqual(m.recomputeCount_, 1, ...
                'Second getXY must be a cache hit — no recompute');
        end

        function testInvalidateClearsCache(testCase)
            st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
            m  = MonitorTag('m', st, @(x, y) y > 5);
            [~, ~] = m.getXY();
            testCase.verifyEqual(m.recomputeCount_, 1);
            m.invalidate();
            [~, ~] = m.getXY();
            testCase.verifyEqual(m.recomputeCount_, 2, ...
                'invalidate() then getXY must recompute');
        end

        function testParentUpdateDataInvalidates(testCase)
            st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
            m  = MonitorTag('m', st, @(x, y) y > 5);
            [~, ~] = m.getXY();
            c_before = m.recomputeCount_;
            st.updateData(11:20, 11:20);
            [mx, my] = m.getXY();
            testCase.verifyGreaterThan(m.recomputeCount_, c_before, ...
                'Parent updateData must invalidate dependent monitor');
            testCase.verifyEqual(mx(:).', 11:20);
            testCase.verifyEqual(my(:).', double([1 1 1 1 1 1 1 1 1 1]));
        end

        function testRecursiveMonitorInvalidation(testCase)
            st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
            m1 = MonitorTag('m1', st, @(x, y) y > 5);
            m2 = MonitorTag('m2', m1, @(x, y) y > 0);
            [~, ~] = m1.getXY();
            [~, ~] = m2.getXY();
            c1_before = m1.recomputeCount_;
            c2_before = m2.recomputeCount_;
            st.updateData(1:10, 10:-1:1);
            [~, ~] = m2.getXY();
            testCase.verifyGreaterThan(m1.recomputeCount_, c1_before, ...
                'Inner m1 must recompute after root parent update');
            testCase.verifyGreaterThan(m2.recomputeCount_, c2_before, ...
                'Outer m2 must recompute after inner invalidates');
        end

        function testSetterMinDurationInvalidates(testCase)
            st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
            m  = MonitorTag('m', st, @(x, y) y > 5);
            [~, ~] = m.getXY();
            c1 = m.recomputeCount_;
            m.MinDuration = 5;
            [~, ~] = m.getXY();
            testCase.verifyGreaterThan(m.recomputeCount_, c1, ...
                'MinDuration setter must invalidate cache');
        end

        function testSetterConditionFnInvalidates(testCase)
            st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
            m  = MonitorTag('m', st, @(x, y) y > 5);
            [~, ~] = m.getXY();
            c1 = m.recomputeCount_;
            m.ConditionFn = @(x, y) y > 100;
            [~, ~] = m.getXY();
            testCase.verifyGreaterThan(m.recomputeCount_, c1, ...
                'ConditionFn setter must invalidate cache');
        end

        function testSetterAlarmOffConditionFnInvalidates(testCase)
            st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
            m  = MonitorTag('m', st, @(x, y) y > 5);
            [~, ~] = m.getXY();
            c1 = m.recomputeCount_;
            m.AlarmOffConditionFn = @(x, y) y < 0;
            [~, ~] = m.getXY();
            testCase.verifyGreaterThan(m.recomputeCount_, c1, ...
                'AlarmOffConditionFn setter must invalidate cache');
        end

        function testValueAtReturnsZOH(testCase)
            st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
            m  = MonitorTag('m', st, @(x, y) y > 5);
            testCase.verifyEqual(m.valueAt(3), 0);
            testCase.verifyEqual(m.valueAt(7), 1);
            testCase.verifyEqual(m.valueAt(0), 0);    % before-first clamps to left
            testCase.verifyEqual(m.valueAt(100), 1);  % after-last clamps to right
        end

        function testValueAtEmptyReturnsNaN(testCase)
            st = SensorTag('stg');                    % empty parent
            m  = MonitorTag('m', st, @(x, y) y > 0);
            testCase.verifyTrue(isnan(m.valueAt(0)));
        end

        function testGetTimeRange(testCase)
            st = SensorTag('stg', 'X', 1:10, 'Y', 1:10);
            m  = MonitorTag('m', st, @(x, y) y > 5);
            [tMin, tMax] = m.getTimeRange();
            testCase.verifyEqual([tMin, tMax], [1 10]);
        end

        function testGetTimeRangeEmpty(testCase)
            st = SensorTag('stg');
            m  = MonitorTag('m', st, @(x, y) y > 0);
            [tMin, tMax] = m.getTimeRange();
            testCase.verifyTrue(isnan(tMin));
            testCase.verifyTrue(isnan(tMax));
        end

        function testNaNInParentY(testCase)
            st = SensorTag('stg', 'X', 1:5, 'Y', [1 NaN 3 4 5]);
            m  = MonitorTag('m', st, @(x, y) y > 2);
            [~, my] = m.getXY();
            testCase.verifyEqual(my(2), 0, ...
                'ALIGN-04: NaN in parent Y must yield 0 via IEEE 754 default');
            testCase.verifyEqual(my(3), 1);
            testCase.verifyEqual(my(4), 1);
            testCase.verifyEqual(my(5), 1);
            testCase.verifyEqual(my(1), 0);
        end

        function testStateTagParent(testCase)
            % StateTag as parent — MonitorTag operates on parent's native grid.
            parent = StateTag('mode', 'X', [1 5 10 20], 'Y', [0 1 2 3]);
            m = MonitorTag('m', parent, @(x, y) y >= 2);
            [mx, my] = m.getXY();
            testCase.verifyEqual(mx(:).', [1 5 10 20]);
            testCase.verifyEqual(my(:).', double([0 0 1 1]));
            % StateTag updateData invalidates
            c1 = m.recomputeCount_;
            parent.updateData([1 10], [0 3]);
            [~, ~] = m.getXY();
            testCase.verifyGreaterThan(m.recomputeCount_, c1, ...
                'StateTag parent updateData must invalidate monitor');
        end

        % ---- Serialization ----

        function testToStructRoundTripKeyKind(testCase)
            st = SensorTag('stg', 'X', 1:5, 'Y', 1:5);
            m  = MonitorTag('m', st, @(x, y) y > 0);
            s  = m.toStruct();
            testCase.verifyEqual(s.kind, 'monitor');
            testCase.verifyEqual(s.key, m.Key);
            testCase.verifyEqual(s.parentkey, st.Key);
            testCase.verifyFalse(isfield(s, 'conditionfn'), ...
                'function handles must NOT be serialized');
        end

        function testResolveRefsWiresParent(testCase)
            st = SensorTag('pkey', 'X', 1:3, 'Y', [1 2 3]);
            m  = MonitorTag('mkey', st, @(x, y) y > 1);
            s  = m.toStruct();
            m2 = MonitorTag.fromStruct(s);
            map = containers.Map({st.Key}, {st});
            m2.resolveRefs(map);
            testCase.verifyTrue(m2.Parent == st, ...
                'resolveRefs must wire the real parent by key lookup');
        end

        function testResolveRefsMissingParent(testCase)
            st = SensorTag('pkey', 'X', 1:3, 'Y', [1 2 3]);
            m  = MonitorTag('mkey', st, @(x, y) y > 1);
            s  = m.toStruct();
            m2 = MonitorTag.fromStruct(s);
            map = containers.Map('UniformValues', false);  % empty map
            testCase.verifyError(@() m2.resolveRefs(map), ...
                'MonitorTag:unresolvedParent');
        end

        % ---- Grep gates ----

        function testPitfall2NoFastSenseDataStore(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m'));
            matches = regexp(src, 'FastSenseDataStore|storeMonitor|storeResolved', 'match');
            testCase.verifyEmpty(matches, ...
                'Pitfall 2: MonitorTag.m must not reference FastSenseDataStore/storeMonitor/storeResolved.');
        end

        function testPitfall2ClassHeaderDocumentsLazy(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m'));
            testCase.verifyNotEmpty(regexp(src, 'lazy-by-default, no persistence', 'once'), ...
                'Pitfall 2: MonitorTag.m class header must contain "lazy-by-default, no persistence".');
        end

        function testMONITOR10NoPerSampleCallbacks(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m'));
            matches = regexp(src, 'PerSample|OnSample|onEachSample', 'match');
            testCase.verifyEmpty(matches, ...
                'MONITOR-10: MonitorTag.m must not expose per-sample callback keywords.');
        end

        function testALIGN01NoLinearInterp(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m'));
            matches = regexp(src, 'interp1.*''linear''', 'match');
            testCase.verifyEmpty(matches, ...
                'ALIGN-01: MonitorTag.m must not use interp1 linear.');
        end

        function testNoAbstractMethodsBlock(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m'));
            matches = regexp(src, 'methods \(Abstract\)', 'match');
            testCase.verifyEmpty(matches, ...
                'Octave safety: MonitorTag.m must not use methods (Abstract) block.');
        end

        function testClassdefExtendsTag(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m'));
            matches = regexp(src, 'classdef MonitorTag < Tag', 'match');
            testCase.verifyEqual(numel(matches), 1, ...
                'MonitorTag.m must declare `classdef MonitorTag < Tag` exactly once.');
        end

    end
end
