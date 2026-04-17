classdef TestCompositeTagAlign < matlab.unittest.TestCase
    %TESTCOMPOSITETAGALIGN Merge-sort + ALIGN + invalidation tests (Plan 02).
    %   Asserts behavior that Plan 01's throw-from-base stubs will fail:
    %     A. Merge-sort correctness (COMPOSITE-05, ALIGN-02)
    %     B. ALIGN-03 pre-history drop
    %     C. ALIGN-01 ZOH-only (no interp1)
    %     D. ALIGN-04 NaN handling end-to-end (joint with ALIGN-03)
    %     E. COMPOSITE-06 valueAt fast-path (no materialization)
    %     F. Invalidation cascade (observer end-to-end)
    %     G. Diamond invalidation (no double-fire issue)
    %
    %   ALIGN-04 NaN aggregation cases are covered exhaustively by
    %   TestCompositeTag.testTruthTableAllModes (Plan 01, 29 rows).
    %   This file covers STRUCTURAL NaN propagation via empty-start segments
    %   (joint ALIGN-03 + ALIGN-04 test).
    %
    %   See also TestCompositeTag, CompositeTag, MonitorTag.

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

        % ---- A. Merge-sort correctness (COMPOSITE-05, ALIGN-02) ----

        function testMergeSortTwoChildrenAlignedX(testCase)
            % Two MonitorTags with IDENTICAL X arrays (X=1:10).
            % m1 fires at indices 3-5; m2 fires at indices 4-7.
            % Composite AND over them.
            s1 = SensorTag('s1', 'X', 1:10, ...
                'Y', [0 0 10 10 10 0 0 0 0 0]);
            s2 = SensorTag('s2', 'X', 1:10, ...
                'Y', [0 0 0 10 10 10 10 0 0 0]);
            m1 = MonitorTag('m1', s1, @(x, y) y > 5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 5);
            c = CompositeTag('c', 'and');
            c.addChild(m1);
            c.addChild(m2);
            [X, Y] = c.getXY();
            % ALIGN-02: all 10 timestamps present (identical X).
            testCase.verifyEqual(numel(X), 10, ...
                'A1: union size must equal 10 (both children share X).');
            testCase.verifyEqual(X(1), 1, 'A1: first X == 1');
            testCase.verifyEqual(X(end), 10, 'A1: last X == 10');
            % AND truth:
            testCase.verifyEqual(Y(1), 0, 'A1: idx 1 both 0 -> AND 0');
            testCase.verifyEqual(Y(3), 0, 'A1: idx 3 m1=1 m2=0 -> AND 0');
            testCase.verifyEqual(Y(4), 1, 'A1: idx 4 both 1 -> AND 1');
            testCase.verifyEqual(Y(5), 1, 'A1: idx 5 both 1 -> AND 1');
            testCase.verifyEqual(Y(6), 0, 'A1: idx 6 m1=0 m2=1 -> AND 0');
            testCase.verifyEqual(Y(10), 0, 'A1: idx 10 both 0 -> AND 0');
        end

        function testMergeSortTwoChildrenStaggeredX(testCase)
            % m1.X = [1 2 3 4 5], m2.X = [1.5 2.5 3.5 4.5].
            % Union size = 9; after ALIGN-03 drop (first_x = max(1,1.5) = 1.5)
            % drop t=1 -> result grid = [1.5 2 2.5 3 3.5 4 4.5 5] (8 pts).
            s1 = SensorTag('s1', 'X', [1 2 3 4 5],   'Y', [0 10 0 0 0]);
            s2 = SensorTag('s2', 'X', [1.5 2.5 3.5 4.5], 'Y', [0 10 0 0]);
            m1 = MonitorTag('m1', s1, @(x, y) y > 5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 5);
            c = CompositeTag('c', 'or');
            c.addChild(m1);
            c.addChild(m2);
            [X, Y] = c.getXY();
            testCase.verifyEqual(numel(X), 8, ...
                'A2: staggered union after ALIGN-03 drop = 8.');
            testCase.verifyEqual(X(1), 1.5, ...
                'A2: first X == 1.5 (max child first_x).');
            testCase.verifyEqual(X(end), 5, 'A2: last X == 5');
            % Y binary only — no fractional (ZOH, no interp1).
            unique_y = unique(Y(~isnan(Y)));
            testCase.verifyTrue(all(ismember(unique_y, [0 1])), ...
                'A2: Y must be binary 0/1 (no interp).');
        end

        function testMergeSortSameTimestampCoalesce(testCase)
            % Both children have x=5 — aggregator must run ONCE at t=5 with
            % BOTH children's y(t=5) — not twice.
            % m1.X=[1 5 10], m2.X=[2 5 8]; both Y=[0 1 0] at idx 2 (which
            % is x=5). Composite OR. Expected output at t=5 is 1.
            s1 = SensorTag('s1', 'X', [1 5 10], 'Y', [0 10 0]);
            s2 = SensorTag('s2', 'X', [2 5 8],  'Y', [0 10 0]);
            m1 = MonitorTag('m1', s1, @(x, y) y > 5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 5);
            c = CompositeTag('c', 'or');
            c.addChild(m1);
            c.addChild(m2);
            [X, Y] = c.getXY();
            % first_x = max(1, 2) = 2, so union before drop = {1,2,5,8,10}
            % after drop => {2, 5, 8, 10} = 4 pts.
            testCase.verifyEqual(numel(X), 4, ...
                'A3: coalesced union after drop = 4.');
            idx5 = find(X == 5, 1, 'first');
            testCase.verifyNotEmpty(idx5, 'A3: t=5 must appear exactly once.');
            testCase.verifyEqual(sum(X == 5), 1, ...
                'A3: t=5 coalesced to single emission.');
            testCase.verifyEqual(Y(idx5), 1, 'A3: OR at t=5 = 1');
        end

        % ---- B. ALIGN-03 pre-history drop ----

        function testPreHistoryDropStaggeredStart(testCase)
            % m1.X = 1:10, m2.X = 5:15. first_x = max(1,5) = 5.
            s1 = SensorTag('s1', 'X', 1:10,  'Y', ones(1, 10));
            s2 = SensorTag('s2', 'X', 5:15,  'Y', ones(1, 11));
            m1 = MonitorTag('m1', s1, @(x, y) y > 0.5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 0.5);
            c = CompositeTag('c', 'or');
            c.addChild(m1);
            c.addChild(m2);
            [X, ~] = c.getXY();
            testCase.verifyEqual(X(1), 5, ...
                'B4: first X must equal max(child_first_x) = 5.');
        end

        function testPreHistoryAllStartAtSame(testCase)
            % Both children start at t=1 -> X(1) should equal 1.
            s1 = SensorTag('s1', 'X', 1:10, 'Y', ones(1, 10));
            s2 = SensorTag('s2', 'X', 1:10, 'Y', ones(1, 10));
            m1 = MonitorTag('m1', s1, @(x, y) y > 0.5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 0.5);
            c = CompositeTag('c', 'or');
            c.addChild(m1);
            c.addChild(m2);
            [X, ~] = c.getXY();
            testCase.verifyEqual(X(1), 1, ...
                'B5: first X == 1 when both children start at t=1.');
        end

        function testPreHistoryThreeChildrenStaggered(testCase)
            % m1 starts t=1, m2 starts t=5, m3 starts t=10 -> X(1) == 10.
            s1 = SensorTag('s1', 'X', 1:20,   'Y', ones(1, 20));
            s2 = SensorTag('s2', 'X', 5:20,   'Y', ones(1, 16));
            s3 = SensorTag('s3', 'X', 10:20,  'Y', ones(1, 11));
            m1 = MonitorTag('m1', s1, @(x, y) y > 0.5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 0.5);
            m3 = MonitorTag('m3', s3, @(x, y) y > 0.5);
            c = CompositeTag('c', 'and');
            c.addChild(m1);
            c.addChild(m2);
            c.addChild(m3);
            [X, ~] = c.getXY();
            testCase.verifyEqual(X(1), 10, ...
                'B6: first X == 10 (max of three staggered starts).');
        end

        % ---- C. ALIGN-01 ZOH-only (no interp1) ----

        function testNoInterp1InSource(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, ...
                'libs', 'SensorThreshold', 'CompositeTag.m'));
            testCase.verifyTrue(isempty(regexp(src, 'interp1', 'once')), ...
                'C7: CompositeTag.m must not contain interp1 (ALIGN-01).');
        end

        function testNoLinearInterpolationInAggregation(testCase)
            % m1.X=[1 3 5], Y=[0 0 10]; m2.X=[2 4 6], Y=[0 10 0]
            % Composite AND. At any staggered t, ZOH-aggregation should
            % produce only {0, 1} — never 0.5 or any non-binary value.
            s1 = SensorTag('s1', 'X', [1 3 5], 'Y', [0 0 10]);
            s2 = SensorTag('s2', 'X', [2 4 6], 'Y', [0 10 0]);
            m1 = MonitorTag('m1', s1, @(x, y) y > 5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 5);
            c = CompositeTag('c', 'and');
            c.addChild(m1);
            c.addChild(m2);
            [~, Y] = c.getXY();
            unique_y = unique(Y(~isnan(Y)));
            testCase.verifyTrue(all(ismember(unique_y, [0 1])), ...
                'C8: AND output Y must be binary (no interpolation).');
        end

        % ---- D. ALIGN-03 + ALIGN-04 joint test ----

        function testAlignNaNPropagationViaEmptyStartSegment(testCase)
            % m1.X=[10 20 30] (starts t=10); m2.X=[5 15 25] (starts t=5).
            % Composite AND. ALIGN-03: first_x = max(10,5) = 10 -> drop t=5.
            % At t=10: m1.Y[1] (first sample), m2 lastY = 0 (from t=5 ZOH).
            % At t=15: m2.Y[2], m1 lastY = m1.Y[1] (ZOH).
            % Output must NOT contain NaN — ZOH fills lastY for m2 before
            % any emitted timestamp.
            s1 = SensorTag('s1', 'X', [10 20 30], 'Y', [0 0 0]);
            s2 = SensorTag('s2', 'X', [5 15 25],  'Y', [0 0 0]);
            m1 = MonitorTag('m1', s1, @(x, y) y > 0.5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 0.5);
            c = CompositeTag('c', 'and');
            c.addChild(m1);
            c.addChild(m2);
            [X, Y] = c.getXY();
            testCase.verifyEqual(X(1), 10, ...
                'D9: ALIGN-03 drops pre-history samples before t=10.');
            testCase.verifyEqual(sum(isnan(Y)), 0, ...
                'D9: No NaN in Y — ZOH seeds lastY before first emission.');
        end

        % ---- E. COMPOSITE-06 valueAt fast-path ----

        function testValueAtDoesNotMaterialize(testCase)
            % Build composite with 2 children, compute v = composite.valueAt(7).
            % composite.recomputeCount_ must stay 0 (no mergeStream_ fired).
            s1 = SensorTag('s1', 'X', 1:10, 'Y', 1:10);
            s2 = SensorTag('s2', 'X', 1:10, 'Y', 1:10);
            m1 = MonitorTag('m1', s1, @(x, y) y > 5);
            m2 = MonitorTag('m2', s2, @(x, y) y > 5);
            c = CompositeTag('c', 'and');
            c.addChild(m1);
            c.addChild(m2);
            v = c.valueAt(7);
            testCase.verifyEqual(v, 1, ...
                'E10: valueAt at t=7 in both children -> AND 1.');
            testCase.verifyEqual(c.recomputeCount_, 0, ...
                'E10: valueAt must NOT trigger mergeStream_.');
            testCase.verifyTrue(c.isDirty(), ...
                'E10: cache still dirty (valueAt did not populate).');
        end

        function testValueAtMatchesGetXYSample(testCase)
            % After getXY() (recomputeCount_ == 1), valueAt(t) at X(k) must
            % equal Y(k) of the materialized series.
            s1 = SensorTag('s1', 'X', 1:10, 'Y', 1:10);
            m1 = MonitorTag('m1', s1, @(x, y) y > 5);
            c = CompositeTag('c', 'and');
            c.addChild(m1);
            [X, Y] = c.getXY();
            testCase.verifyEqual(c.recomputeCount_, 1, ...
                'E11: getXY must increment recomputeCount_.');
            for k = 1:numel(X)
                v = c.valueAt(X(k));
                if isnan(Y(k))
                    testCase.verifyTrue(isnan(v), sprintf( ...
                        'E11: valueAt(%.3f) must be NaN (matches Y(%d)).', ...
                        X(k), k));
                else
                    testCase.verifyEqual(v, Y(k), sprintf( ...
                        'E11: valueAt(%.3f) must equal Y(%d) = %g.', ...
                        X(k), k, Y(k)));
                end
            end
        end

        % ---- F. Invalidation cascade (observer end-to-end) ----

        function testChildUpdateInvalidatesComposite(testCase)
            % Build composite with 1 MonitorTag child. getXY populates cache
            % (isDirty == false). Update child's parent; monitor invalidates,
            % cascades through listeners to composite.invalidate().
            s1 = SensorTag('s1', 'X', 1:10, 'Y', 1:10);
            m1 = MonitorTag('m1', s1, @(x, y) y > 5);
            c = CompositeTag('c', 'and');
            c.addChild(m1);
            c.getXY();   % warm cache
            testCase.verifyFalse(c.isDirty(), ...
                'F12 pre: cache populated after getXY.');
            s1.updateData(11:20, 11:20);
            testCase.verifyTrue(c.isDirty(), ...
                'F12: child-update cascades to composite.invalidate.');
        end

        % ---- G. Diamond invalidation (no double-fire issue) ----

        function testDiamondSameLeafBothPathsInvalidate(testCase)
            % leaf -> {midA, midB} -> top. Update leaf parent; both mids
            % invalidate; both notify top (top.invalidate called twice).
            % No errors; top.isDirty() == true. Idempotent invalidate.
            s = SensorTag('s', 'X', 1:10, 'Y', 1:10);
            leaf = MonitorTag('leaf', s, @(x, y) y > 5);
            midA = CompositeTag('midA', 'and');
            midB = CompositeTag('midB', 'or');
            midA.addChild(leaf);
            midB.addChild(leaf);
            top = CompositeTag('top', 'and');
            top.addChild(midA);
            top.addChild(midB);
            top.getXY();
            testCase.verifyFalse(top.isDirty(), ...
                'G13 pre: top cache populated.');
            s.updateData(11:20, 11:20);
            testCase.verifyTrue(top.isDirty(), ...
                'G13: diamond invalidation reaches top.');
        end

    end
end
