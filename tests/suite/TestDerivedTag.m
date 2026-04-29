classdef TestDerivedTag < matlab.unittest.TestCase
    %TESTDERIVEDTAG Unit tests for the DerivedTag class (Phase 1008-r2b).
    %   Covers:
    %     - Construction (function-handle compute, object compute, NV pairs,
    %       error paths, cycle detection — direct + transitive)
    %     - Computation (lazy, cached, recompute on parent update,
    %       valueAt scalar + vector ZOH, getTimeRange)
    %     - Compute validation (non-numeric / shape mismatch errors)
    %     - Listener / observer (invalidate cascade, downstream wiring,
    %       addListener type guard)
    %     - Serialization (function-handle vs. object compute, Pass-1
    %       sentinel, Pass-2 resolveRefs round-trip, dataMismatch errors)
    %     - Integration (TagRegistry findByKind, MonitorTag accepts as
    %       parent, CompositeTag rejects as child, loadFromStructs round-trip)
    %     - Grep gates (no methods (Abstract) block, classdef DerivedTag < Tag,
    %       error IDs match SPEC §4)
    %
    %   Mirrors TestMonitorTag.m structure (TestClassSetup/addPaths,
    %   TestMethodSetup/Teardown calling TagRegistry.clear()).
    %
    %   See also DerivedTag, ComputeAddStub, Tag, MonitorTag, CompositeTag.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'tests', 'suite'));  % MockTag, ComputeAddStub
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

        % ====== Construction ======

        function testConstructorBasic(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
            d = DerivedTag('d', {a, b}, ...
                @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            testCase.verifyEqual(d.Key, 'd');
            testCase.verifyEqual(d.getKind(), 'derived');
            testCase.verifyTrue(isa(d, 'Tag'));
            testCase.verifyTrue(isa(d, 'handle'));
            testCase.verifyEqual(numel(d.Parents), 2);
            testCase.verifyEqual(d.Parents{1}.Key, 'a');
            testCase.verifyEqual(d.Parents{2}.Key, 'b');
            [x, y] = d.getXY();
            testCase.verifyEqual(x(:).', 1:5);
            testCase.verifyEqual(y(:).', double([3 5 7 9 11]));
        end

        function testConstructorObjectCompute(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
            stub = ComputeAddStub(2);
            d = DerivedTag('d', {a, b}, stub);
            [~, y] = d.getXY();
            testCase.verifyEqual(y(:).', double([3 5 7 9 11]) * 2);
        end

        function testConstructorRejectsEmptyParents(testCase)
            testCase.verifyError( ...
                @() DerivedTag('d', {}, @(p) deal([], [])), ...
                'DerivedTag:invalidParents');
        end

        function testConstructorRejectsNonTagParent(testCase)
            testCase.verifyError( ...
                @() DerivedTag('d', {'string'}, @(p) deal([], [])), ...
                'DerivedTag:invalidParents');
        end

        function testConstructorRejectsEmptyCompute(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            testCase.verifyError( ...
                @() DerivedTag('d', {a}, []), ...
                'DerivedTag:invalidCompute');
        end

        function testConstructorRejectsBadCompute(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            testCase.verifyError( ...
                @() DerivedTag('d', {a}, 42), ...
                'DerivedTag:invalidCompute');
        end

        function testConstructorTagUniversals(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y), ...
                'Name', 'Derived A', ...
                'Units', 'bar', ...
                'Labels', {'derived', 'pressure'}, ...
                'Criticality', 'high', ...
                'Description', 'desc', ...
                'SourceRef', 'doc.md');
            testCase.verifyEqual(d.Name, 'Derived A');
            testCase.verifyEqual(d.Units, 'bar');
            testCase.verifyEqual(d.Labels, {'derived', 'pressure'});
            testCase.verifyEqual(d.Criticality, 'high');
            testCase.verifyEqual(d.Description, 'desc');
            testCase.verifyEqual(d.SourceRef, 'doc.md');
        end

        function testConstructorUnknownOption(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            testCase.verifyError( ...
                @() DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y), ...
                    'Bogus', 1), ...
                'DerivedTag:unknownOption');
        end

        function testConstructorRejectsDirectCycle(testCase)
            % A DerivedTag named 'd1' cannot list a parent whose Key is also 'd1'.
            a  = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            d1 = DerivedTag('d1', {a}, @(p) deal(p{1}.X, p{1}.Y));
            testCase.verifyError( ...
                @() DerivedTag('d1', {d1}, @(p) deal(p{1}.X, p{1}.Y)), ...
                'DerivedTag:cycleDetected');
        end

        function testConstructorRejectsTransitiveCycle(testCase)
            % Build d_a -> d_b -> d_c, then attempt DerivedTag('d_a', {d_c}, ...).
            a   = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            d_a = DerivedTag('d_a', {a},   @(p) deal(p{1}.X, p{1}.Y));
            d_b = DerivedTag('d_b', {d_a}, @(p) deal(p{1}.X, p{1}.Y));
            d_c = DerivedTag('d_c', {d_b}, @(p) deal(p{1}.X, p{1}.Y));
            testCase.verifyError( ...
                @() DerivedTag('d_a', {d_c}, @(p) deal(p{1}.X, p{1}.Y)), ...
                'DerivedTag:cycleDetected');
        end

        % ====== Computation ======

        function testGetXYBasicSum(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
            d = DerivedTag('d', {a, b}, ...
                @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            [x, y] = d.getXY();
            testCase.verifyEqual(x(:).', 1:5);
            testCase.verifyEqual(y(:).', double([3 5 7 9 11]));
        end

        function testGetXYLazyEvaluation(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
            d = DerivedTag('d', {a, b}, ...
                @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            % No getXY call yet — recomputeCount_ must still be 0.
            testCase.verifyEqual(d.recomputeCount_, 0, ...
                'recomputeCount_ must be 0 before any getXY call');
        end

        function testGetXYCachesResult(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
            d = DerivedTag('d', {a, b}, ...
                @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            [~, ~] = d.getXY();
            testCase.verifyEqual(d.recomputeCount_, 1, ...
                'First getXY must trigger exactly one recompute');
            [~, ~] = d.getXY();
            testCase.verifyEqual(d.recomputeCount_, 1, ...
                'Second getXY must be a cache hit — no recompute');
        end

        function testGetXYRecomputesAfterParentUpdate(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
            d = DerivedTag('d', {a, b}, ...
                @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            [~, ~] = d.getXY();
            cBefore = d.recomputeCount_;
            a.updateData(1:5, 10*(1:5));
            % Force getXY again — must recompute against new parent data.
            [x, y] = d.getXY();
            testCase.verifyGreaterThan(d.recomputeCount_, cBefore, ...
                'Parent updateData must invalidate dependent DerivedTag');
            testCase.verifyEqual(x(:).', 1:5);
            testCase.verifyEqual(y(:).', double((10*(1:5)) + (2:6)));
        end

        function testValueAtZOHLookup(testCase)
            a = SensorTag('a', 'X', [1 3 5 7 9], 'Y', [10 30 50 70 90]);
            b = SensorTag('b', 'X', [1 3 5 7 9], 'Y', [0 0 0 0 0]);
            d = DerivedTag('d', {a, b}, ...
                @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            % Scalar t — right-biased ZOH
            testCase.verifyEqual(d.valueAt(4), 30);   % X=3 last <= 4
            testCase.verifyEqual(d.valueAt(5), 50);
            testCase.verifyEqual(d.valueAt(0), 10);   % below lowest -> clamped to idx 1
            % Vector t
            v = d.valueAt([0 4 5 6 8 100]);
            testCase.verifyEqual(v, [10 30 50 50 70 90]);
        end

        function testGetTimeRange(testCase)
            a = SensorTag('a', 'X', [3 7 11], 'Y', [1 2 3]);
            b = SensorTag('b', 'X', [3 7 11], 'Y', [4 5 6]);
            d = DerivedTag('d', {a, b}, ...
                @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            [tMin, tMax] = d.getTimeRange();
            testCase.verifyEqual(tMin, 3);
            testCase.verifyEqual(tMax, 11);
            % Empty compute -> [NaN NaN]
            d2 = DerivedTag('d2', {a, b}, @(p) deal([], []));
            [tMin2, tMax2] = d2.getTimeRange();
            testCase.verifyTrue(isnan(tMin2));
            testCase.verifyTrue(isnan(tMax2));
        end

        % ====== Compute validation ======

        function testRecomputeRejectsNonNumeric(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            d = DerivedTag('d', {a}, @(p) deal('abc', 'abc'));
            testCase.verifyError(@() d.getXY(), ...
                'DerivedTag:computeReturnedNonNumeric');
        end

        function testRecomputeRejectsShapeMismatch(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            d = DerivedTag('d', {a}, @(p) deal(1:10, 1:11));
            testCase.verifyError(@() d.getXY(), ...
                'DerivedTag:computeShapeMismatch');
        end

        % ====== Listener / observer ======

        function testInvalidateClearsCache(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y));
            [~, ~] = d.getXY();
            testCase.verifyEqual(d.recomputeCount_, 1);
            d.invalidate();
            [~, ~] = d.getXY();
            testCase.verifyEqual(d.recomputeCount_, 2, ...
                'invalidate() then getXY must recompute');
        end

        function testParentDataChangeInvalidates(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y * 2));
            [~, y0] = d.getXY();
            testCase.verifyEqual(y0(:).', double((1:5) * 2));
            cBefore = d.recomputeCount_;
            a.updateData(1:5, [10 20 30 40 50]);
            [~, y1] = d.getXY();
            testCase.verifyGreaterThan(d.recomputeCount_, cBefore);
            testCase.verifyEqual(y1(:).', double([10 20 30 40 50]) * 2);
        end

        function testAddListenerDownstream(testCase)
            % Chain a MonitorTag onto a DerivedTag — root parent update must
            % cascade through DerivedTag.invalidate to the MonitorTag.
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y * 10));
            m = MonitorTag('m', d, @(x, y) y > 25);
            [~, my] = m.getXY();
            testCase.verifyEqual(my(:).', double([0 0 1 1 1]));
            cBefore = m.recomputeCount_;
            a.updateData(1:5, [1 1 1 1 1]);
            [~, my2] = m.getXY();
            testCase.verifyGreaterThan(m.recomputeCount_, cBefore, ...
                'Root SensorTag update must cascade through DerivedTag to MonitorTag');
            testCase.verifyEqual(my2(:).', double([0 0 0 0 0]));
        end

        function testAddListenerRejectsNoInvalidate(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y));
            testCase.verifyError(@() d.addListener(struct()), ...
                'DerivedTag:invalidListener');
        end

        % ====== Serialization ======

        function testToStructFunctionHandle(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
            d = DerivedTag('d', {a, b}, ...
                @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            s = d.toStruct();
            testCase.verifyEqual(s.kind, 'derived');
            testCase.verifyEqual(s.key, 'd');
            testCase.verifyEqual(s.computekind, 'function_handle');
            testCase.verifyTrue(ischar(s.computestr) && ~isempty(s.computestr));
            testCase.verifyTrue(iscell(s.parentkeys));
            testCase.verifyEqual(numel(s.parentkeys), 2);
            testCase.verifyEqual(s.parentkeys{1}, 'a');
            testCase.verifyEqual(s.parentkeys{2}, 'b');
        end

        function testToStructObject(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
            stub = ComputeAddStub(3);
            d = DerivedTag('d', {a, b}, stub);
            s = d.toStruct();
            testCase.verifyEqual(s.computekind, 'object');
            testCase.verifyEqual(s.computeclass, 'ComputeAddStub');
            testCase.verifyTrue(isstruct(s.computestate));
            testCase.verifyTrue(isfield(s.computestate, 'Scale'));
            testCase.verifyEqual(s.computestate.Scale, 3);
        end

        function testFromStructPass1(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
            d = DerivedTag('d', {a, b}, ...
                @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            s  = d.toStruct();
            d2 = DerivedTag.fromStruct(s);
            testCase.verifyEqual(d2.Key, 'd');
            % Parents should be empty post-Pass-1; parentkeys stashed internally.
            testCase.verifyEqual(numel(d2.Parents), 0);
            % Function-handle case: ComputeFn is the rehydration sentinel —
            % invocation must raise computeNotRehydrated.
            testCase.verifyError(@() d2.getXY(), ...
                'DerivedTag:computeNotRehydrated');
        end

        function testFromStructResolveRefs(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
            d = DerivedTag('d', {a, b}, ...
                @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
            s  = d.toStruct();
            d2 = DerivedTag.fromStruct(s);
            % Reattach the real handle BEFORE resolveRefs (function-handle path).
            d2.ComputeFn = @(p) deal(p{1}.X, p{1}.Y + p{2}.Y);
            registry = containers.Map({'a', 'b'}, {a, b});
            d2.resolveRefs(registry);
            testCase.verifyEqual(numel(d2.Parents), 2);
            testCase.verifyEqual(d2.Parents{1}.Key, 'a');
            testCase.verifyEqual(d2.Parents{2}.Key, 'b');
            [x, y] = d2.getXY();
            testCase.verifyEqual(x(:).', 1:5);
            testCase.verifyEqual(y(:).', double([3 5 7 9 11]));
            % Listener wiring observable: parent update must invalidate d2.
            cBefore = d2.recomputeCount_;
            a.updateData(1:5, 100*(1:5));
            [~, ~] = d2.getXY();
            testCase.verifyGreaterThan(d2.recomputeCount_, cBefore, ...
                'resolveRefs must register listener on real parent');
        end

        function testFromStructRejectsMissingKey(testCase)
            testCase.verifyError(@() DerivedTag.fromStruct(struct()), ...
                'DerivedTag:dataMismatch');
        end

        function testFromStructObjectRoundTrip(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
            stub = ComputeAddStub(2);
            d = DerivedTag('d', {a, b}, stub);
            [~, yOriginal] = d.getXY();

            s  = d.toStruct();
            d2 = DerivedTag.fromStruct(s);
            % Object-compute case: fromStruct rehydrates via ComputeAddStub.fromStruct.
            testCase.verifyTrue(isa(d2.ComputeFn, 'ComputeAddStub'));
            testCase.verifyEqual(d2.ComputeFn.Scale, 2);
            registry = containers.Map({'a', 'b'}, {a, b});
            d2.resolveRefs(registry);
            [~, yReloaded] = d2.getXY();
            testCase.verifyEqual(yReloaded, yOriginal);
        end

        % ====== Integration ======

        function testFindByKindReturnsDerived(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y));
            TagRegistry.register('a', a);
            TagRegistry.register('d', d);
            tags = TagRegistry.findByKind('derived');
            testCase.verifyEqual(numel(tags), 1);
            testCase.verifyEqual(tags{1}.Key, 'd');
        end

        function testMonitorTagAcceptsDerivedAsParent(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y * 10));
            m = MonitorTag('m', d, @(x, y) y > 25);
            testCase.verifyEqual(m.Parent.Key, 'd');
            [~, my] = m.getXY();
            testCase.verifyEqual(my(:).', double([0 0 1 1 1]));
        end

        function testCompositeTagRejectsDerivedAsChild(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            d = DerivedTag('d', {a}, @(p) deal(p{1}.X, p{1}.Y));
            comp = CompositeTag('c', 'and');
            testCase.verifyError(@() comp.addChild(d), ...
                'CompositeTag:invalidChildType');
        end

        function testTagRegistryLoadFromStructsRoundTrip(testCase)
            a = SensorTag('a', 'X', 1:5, 'Y', 1:5);
            b = SensorTag('b', 'X', 1:5, 'Y', 2:6);
            stub = ComputeAddStub(2);
            d = DerivedTag('d', {a, b}, stub);
            [~, yOriginal] = d.getXY();

            sa = a.toStruct();
            sb = b.toStruct();
            sd = d.toStruct();

            TagRegistry.clear();
            TagRegistry.loadFromStructs({sa, sb, sd});

            % Loaded SensorTags lack inline X/Y (toStruct intentionally
            % omits raw data — see SensorTag.toStruct comments). Re-attach
            % data via the real handles so the compute can run end-to-end.
            % This validates that the wiring is correct, not the data
            % round-trip (which is SensorTag's responsibility).
            aReg = TagRegistry.get('a');
            bReg = TagRegistry.get('b');
            aReg.updateData(1:5, 1:5);
            bReg.updateData(1:5, 2:6);

            dReg = TagRegistry.get('d');
            testCase.verifyEqual(dReg.getKind(), 'derived');
            testCase.verifyEqual(numel(dReg.Parents), 2);
            [~, yReloaded] = dReg.getXY();
            testCase.verifyEqual(yReloaded, yOriginal);
        end

        % ====== Grep gates ======

        function testNoAbstractMethodsBlock(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'DerivedTag.m'));
            matches = regexp(src, 'methods \(Abstract\)', 'match');
            testCase.verifyEmpty(matches, ...
                'Octave safety: DerivedTag.m must not use methods (Abstract) block.');
        end

        function testClassdefExtendsTag(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'DerivedTag.m'));
            matches = regexp(src, 'classdef DerivedTag < Tag', 'match');
            testCase.verifyEqual(numel(matches), 1, ...
                'DerivedTag.m must declare `classdef DerivedTag < Tag` exactly once.');
        end

        function testErrorIdsAreNamespaced(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'DerivedTag.m'));
            % Extract every error('DerivedTag:XYZ', ...) call.
            ids = regexp(src, 'error\(''DerivedTag:(\w+)''', 'tokens');
            ids = unique(cellfun(@(c) c{1}, ids, 'UniformOutput', false));
            % Locked error IDs from SPEC §4.
            valid = {'invalidParents', 'invalidCompute', 'unknownOption', ...
                'invalidListener', 'computeReturnedNonNumeric', ...
                'computeShapeMismatch', 'dataMismatch', 'unresolvedParent', ...
                'cycleDetected', 'nonSerializableCompute', 'computeNotRehydrated'};
            for i = 1:numel(ids)
                testCase.verifyTrue(any(strcmp(ids{i}, valid)), ...
                    sprintf('Error ID DerivedTag:%s not in SPEC §4 locked list.', ids{i}));
            end
        end

    end
end
