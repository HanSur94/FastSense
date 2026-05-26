classdef TestTagInvalidateBatch < matlab.unittest.TestCase
    %TESTTAGINVALIDATEBATCH Phase 1028 post-merge — direct unit coverage of Tag.invalidateBatch_.
    %
    %   Plan 05 introduced `Tag.invalidateBatch_(tagSet)` (libs/SensorThreshold/Tag.m
    %   lines 190-314) as the internal seam used by `LiveTagPipeline.onTick_` to
    %   coalesce per-tag invalidation cascades at end-of-tick. The PR #114
    %   codecov report (deferred-items.md) flagged the method at 63.6% patch
    %   coverage; the existing `TestListenerCoalesceOrdering` exercised the
    %   cascade end-to-end (chain of Sensor → Monitor → Composite tags) but
    %   did not target the dispatch logic directly.
    %
    %   This suite adds direct unit coverage of the dispatch contract:
    %
    %     1. Empty cell input — `invalidateBatch_({})` is a no-op.
    %     2. Empty numeric input — `invalidateBatch_([])` is a no-op
    %        via the same isempty guard.
    %     3. Single-tag dispatch — one tag with one listener →
    %        listener.invalidate() called exactly once.
    %     4. Multi-tag dispatch — three tags each with its own listener →
    %        each listener invalidated exactly once.
    %     5. Shared-listener deduplication — two tags share one listener
    %        handle; listener invalidated exactly once (not twice).
    %     6. Mixed Tag-kind batch — SensorTag + StateTag in the same
    %        tagSet; each kind's listener cell is walked correctly.
    %     7. Invalid input — non-cell `tagSet` raises `Tag:invalidBatchInput`.
    %     8. Listener-error propagation — a listener that throws
    %        surfaces its error (no swallow); earlier listeners were
    %        processed; later listeners are skipped (documented
    %        non-fault-tolerance per the source-level walker contract).
    %
    %   The mock listener types `CountingListener` and `ThrowingListener`
    %   implement the minimal observer contract (ismethod(m, 'invalidate'))
    %   required by SensorTag.addListener.
    %
    %   See also Tag.invalidateBatch_, TestListenerCoalesceOrdering,
    %            CountingListener, ThrowingListener.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function clearRegistry(testCase) %#ok<MANU>
            %CLEARREGISTRY Reset TagRegistry singleton before each test.
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function clearRegistryAfter(testCase) %#ok<MANU>
            %CLEARREGISTRYAFTER Reset TagRegistry singleton after each test.
            TagRegistry.clear();
        end
    end

    methods (Test)

        function testEmptyTagSetIsNoOp(testCase)
            %TESTEMPTYTAGSETISNOOP Verify `invalidateBatch_({})` returns silently.
            testCase.verifyWarningFree(@() Tag.invalidateBatch_({}));
        end

        function testEmptyNumericInputIsNoOp(testCase)
            %TESTEMPTYNUMERICINPUTISNOOP `invalidateBatch_([])` is tolerated.
            %   The empty-input guard (line 231) short-circuits before
            %   the ~iscell check (line 234) so any empty value is a
            %   safe no-op regardless of type. This protects callers
            %   from accidental empty-numeric arrays in dynamic paths.
            testCase.verifyWarningFree(@() Tag.invalidateBatch_([]));
        end

        function testSingleTagSingleListenerDispatchedOnce(testCase)
            %TESTSINGLETAGSINGLELISTENERDISPATCHEDONCE One tag, one listener → 1 call.
            s = SensorTag('s_single', 'X', 1:10, 'Y', sin(1:10));
            l = CountingListener();
            s.addListener(l);

            Tag.invalidateBatch_({s});

            testCase.verifyEqual(l.Count, 1, ...
                'Listener.invalidate must be called exactly once for single-tag batch.');
        end

        function testMultiTagEachListenerDispatchedOnce(testCase)
            %TESTMULTITAGEACHLISTENERDISPATCHEDONCE Three tags, three listeners → 1 call each.
            %   Each tag has its own distinct listener handle. The batch
            %   walker must visit each (tag, listener) pair exactly once.
            sA = SensorTag('s_multi_A', 'X', 1:5, 'Y', sin(1:5));
            sB = SensorTag('s_multi_B', 'X', 1:5, 'Y', sin(1:5));
            sC = SensorTag('s_multi_C', 'X', 1:5, 'Y', sin(1:5));

            lA = CountingListener();
            lB = CountingListener();
            lC = CountingListener();

            sA.addListener(lA);
            sB.addListener(lB);
            sC.addListener(lC);

            Tag.invalidateBatch_({sA, sB, sC});

            testCase.verifyEqual(lA.Count, 1, 'lA must be invalidated exactly once.');
            testCase.verifyEqual(lB.Count, 1, 'lB must be invalidated exactly once.');
            testCase.verifyEqual(lC.Count, 1, 'lC must be invalidated exactly once.');
        end

        function testSharedListenerAcrossTagsDedupedToOneCall(testCase)
            %TESTSHAREDLISTENERACROSSTAGSDEDUPEDTOONECALL Listener shared by two tags → 1 call.
            %   When a single listener handle is registered with two
            %   different tags AND both tags are in the batch, the
            %   walker must dedupe by handle identity and invoke
            %   invalidate() exactly once. This is the core coalescing
            %   guarantee.
            %
            %   This is the MonitorTag-with-multiple-Sensor-parents
            %   pattern (e.g., a monitor that observes two sensors).
            sA = SensorTag('s_shared_A', 'X', 1:5, 'Y', sin(1:5));
            sB = SensorTag('s_shared_B', 'X', 1:5, 'Y', sin(1:5));

            shared = CountingListener();
            sA.addListener(shared);
            sB.addListener(shared);

            Tag.invalidateBatch_({sA, sB});

            testCase.verifyEqual(shared.Count, 1, ...
                'Shared listener handle must be invalidated exactly once across the batch.');
        end

        function testMixedTagKindsBatch(testCase)
            %TESTMIXEDTAGKINDSBATCH SensorTag + StateTag in same batch — both walked.
            %   Tag.invalidateBatch_ must call getListeners_ on every
            %   Tag subclass. Verify it works for at least two distinct
            %   concrete kinds in the same call.
            s = SensorTag('s_mixed', 'X', 1:5, 'Y', sin(1:5));
            st = StateTag('st_mixed', 'X', 1:5, 'Y', ones(1, 5));

            lSensor = CountingListener();
            lState  = CountingListener();
            s.addListener(lSensor);
            st.addListener(lState);

            Tag.invalidateBatch_({s, st});

            testCase.verifyEqual(lSensor.Count, 1, 'SensorTag listener invalidated once.');
            testCase.verifyEqual(lState.Count,  1, 'StateTag listener invalidated once.');
        end

        function testNonCellInputRaisesInvalidBatchInput(testCase)
            %TESTNONCELLINPUTRAISESINVALIDBATCHINPUT Wrong-type input is rejected.
            %   The walker validates `iscell(tagSet)` after the
            %   empty-input early-return. A non-empty non-cell input
            %   must raise `Tag:invalidBatchInput`. We pass a numeric
            %   array (non-empty) to bypass the isempty short-circuit.
            testCase.verifyError(@() Tag.invalidateBatch_([1, 2, 3]), ...
                'Tag:invalidBatchInput');
        end

        function testListenerErrorPropagatesAndAborts(testCase)
            %TESTLISTENERERRORPROPAGATESANDABORTS Documented non-fault-tolerance.
            %   The walker (Tag.m lines 304-313) does NOT wrap each
            %   listener invalidate() in try/catch — it iterates and
            %   calls. The documented contract is therefore:
            %     - If a listener throws, the error propagates out.
            %     - Listeners that appeared earlier in the unique-list
            %       have already been processed.
            %     - Listeners later in the unique-list are SKIPPED.
            %
            %   This test pins that contract. If a future refactor adds
            %   fault-tolerance (try/catch around each invalidate), this
            %   test will fail and force a deliberate update to the
            %   contract documentation.
            %
            %   Order strategy: SensorTag stores listeners_ as a cell
            %   (append-on-addListener). The walker preserves
            %   listeners_ order while deduping. Listener registration
            %   order: [counting, throwing, never] — so we expect
            %   counting to be invalidated, throwing to fire the error,
            %   and `never` to NOT be invoked.
            s = SensorTag('s_err', 'X', 1:5, 'Y', sin(1:5));
            counting = CountingListener();
            throwing = ThrowingListener();
            never    = CountingListener();

            s.addListener(counting);
            s.addListener(throwing);
            s.addListener(never);

            % The throwing listener's error must surface.
            testCase.verifyError(@() Tag.invalidateBatch_({s}), ...
                'ThrowingListener:intentional');

            % Pre-throw listener was processed; post-throw listener was not.
            testCase.verifyEqual(counting.Count, 1, ...
                'Listener BEFORE the throwing one must have been invalidated.');
            testCase.verifyEqual(never.Count, 0, ...
                'Listener AFTER the throwing one must NOT have been invalidated (loop aborts).');
        end

    end
end
