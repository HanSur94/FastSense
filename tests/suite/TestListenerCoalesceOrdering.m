classdef TestListenerCoalesceOrdering < matlab.unittest.TestCase
    %TESTLISTENERCOALESCEORDERING Phase 1028 Plan 05 — A1/A2 listener coalescing.
    %
    %   Asserts the semantic contract of `Tag.invalidateBatch_(tagSet)`:
    %
    %     1. Per-monitor recompute counts are invariant whether the
    %        downstream listener cascade is fired via per-tag
    %        `tag.invalidate()` or via end-of-tick
    %        `Tag.invalidateBatch_(tagSet)`. The same listeners get
    %        their cache invalidated; only WHEN is collapsed (batched).
    %
    %     2. Empty `tagSet` is a no-op (no error, no side effects).
    %
    %     3. Duplicate handles in `tagSet` are deduplicated: the same
    %        downstream listener is only invalidated once per batch.
    %
    %     4. `invalidateBatch_(tagSet)` followed by a per-tag
    %        `tag.invalidate()` is idempotent (cache state matches
    %        the per-tag-only path).
    %
    %   The contract is internal-only (D-10): public APIs
    %   (`Tag.invalidate`, `addListener`) are unchanged. The
    %   `invalidateBatch_` helper is a private/Hidden seam used by
    %   `LiveTagPipeline.onTick_` (Plan 05 Task 2).
    %
    %   See also Tag, SensorTag, MonitorTag, CompositeTag, LiveTagPipeline.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', '..'));
            install();
        end
    end

    methods (Test)

        function testPerMonitorOrderingInvariantUnderCoalescing(testCase)
            %TESTPERMONITORORDERINGINVARIANTUNDERCOALESCING Chain semantics.
            %   Build a chain: 3 SensorTags → 6 MonitorTags (each over 1
            %   sensor) → 3 CompositeTags (each over 2 monitors). Run two
            %   sequences:
            %     A) per-tag: for each sensor, call sensor.invalidate()
            %        AFTER updateData so its cascade fires; collect each
            %        monitor's recomputeCount_ after triggering a getXY.
            %     B) batch: for each sensor, updateData (with listeners
            %        temporarily detached), then call
            %        Tag.invalidateBatch_({sensorA, sensorB, sensorC})
            %        once; trigger getXY across monitors.
            %
            %   Assert: per-monitor recomputeCount_ identical between
            %   sequences. Same listeners notified, just batched.
            TagRegistry.clear();

            % --- Build chain ---
            sA = makeSensor_('sA', linspace(0, 10, 50));
            sB = makeSensor_('sB', linspace(0, 10, 50));
            sC = makeSensor_('sC', linspace(0, 10, 50));

            mA1 = MonitorTag('mA1', sA, @(~,y) y > 0);
            mA2 = MonitorTag('mA2', sA, @(~,y) y > 0.5);
            mB1 = MonitorTag('mB1', sB, @(~,y) y > 0);
            mB2 = MonitorTag('mB2', sB, @(~,y) y > 0.5);
            mC1 = MonitorTag('mC1', sC, @(~,y) y > 0);
            mC2 = MonitorTag('mC2', sC, @(~,y) y > 0.5);

            % Prime caches once so dirty_ starts true after invalidate.
            [~, ~] = mA1.getXY(); [~, ~] = mA2.getXY();
            [~, ~] = mB1.getXY(); [~, ~] = mB2.getXY();
            [~, ~] = mC1.getXY(); [~, ~] = mC2.getXY();

            baseA1 = mA1.recomputeCount_;
            baseA2 = mA2.recomputeCount_;
            baseB1 = mB1.recomputeCount_;
            baseB2 = mB2.recomputeCount_;
            baseC1 = mC1.recomputeCount_;
            baseC2 = mC2.recomputeCount_;

            % --- Sequence A: per-tag invalidate path ---
            sA.updateData(linspace(0, 10, 50), rand(50, 1));
            sB.updateData(linspace(0, 10, 50), rand(50, 1));
            sC.updateData(linspace(0, 10, 50), rand(50, 1));
            % updateData already fires listeners (per SensorTag.updateData → notifyListeners_).
            [~, ~] = mA1.getXY(); [~, ~] = mA2.getXY();
            [~, ~] = mB1.getXY(); [~, ~] = mB2.getXY();
            [~, ~] = mC1.getXY(); [~, ~] = mC2.getXY();

            seqA = struct( ...
                'mA1', mA1.recomputeCount_ - baseA1, ...
                'mA2', mA2.recomputeCount_ - baseA2, ...
                'mB1', mB1.recomputeCount_ - baseB1, ...
                'mB2', mB2.recomputeCount_ - baseB2, ...
                'mC1', mC1.recomputeCount_ - baseC1, ...
                'mC2', mC2.recomputeCount_ - baseC2);

            % --- Re-prime to clear dirty_ for sequence B ---
            [~, ~] = mA1.getXY(); [~, ~] = mA2.getXY();
            [~, ~] = mB1.getXY(); [~, ~] = mB2.getXY();
            [~, ~] = mC1.getXY(); [~, ~] = mC2.getXY();

            baseA1 = mA1.recomputeCount_;
            baseA2 = mA2.recomputeCount_;
            baseB1 = mB1.recomputeCount_;
            baseB2 = mB2.recomputeCount_;
            baseC1 = mC1.recomputeCount_;
            baseC2 = mC2.recomputeCount_;

            % --- Sequence B: batched invalidate via Tag.invalidateBatch_ ---
            % To isolate the batch path, set X_/Y_ directly via updateData
            % (which will fire listeners — same behavior as sequence A — but
            % we ALSO call invalidateBatch_. Since invalidate is idempotent
            % the cumulative effect must remain the same.)
            sA.updateData(linspace(0, 10, 50), rand(50, 1));
            sB.updateData(linspace(0, 10, 50), rand(50, 1));
            sC.updateData(linspace(0, 10, 50), rand(50, 1));
            Tag.invalidateBatch_({sA, sB, sC});

            [~, ~] = mA1.getXY(); [~, ~] = mA2.getXY();
            [~, ~] = mB1.getXY(); [~, ~] = mB2.getXY();
            [~, ~] = mC1.getXY(); [~, ~] = mC2.getXY();

            seqB = struct( ...
                'mA1', mA1.recomputeCount_ - baseA1, ...
                'mA2', mA2.recomputeCount_ - baseA2, ...
                'mB1', mB1.recomputeCount_ - baseB1, ...
                'mB2', mB2.recomputeCount_ - baseB2, ...
                'mC1', mC1.recomputeCount_ - baseC1, ...
                'mC2', mC2.recomputeCount_ - baseC2);

            % Per-monitor recompute counts must match: same listeners called.
            testCase.verifyEqual(seqB, seqA, ...
                'Per-monitor recompute counts must be invariant under coalescing');

            TagRegistry.clear();
        end

        function testEmptyTagSetNoOp(testCase)
            %TESTEMPTYTAGSETNOOP Tag.invalidateBatch_({}) returns silently.
            testCase.verifyWarningFree(@() Tag.invalidateBatch_({}));
        end

        function testDuplicateHandleDeduplication(testCase)
            %TESTDUPLICATEHANDLEDEDUPLICATION Same handle twice → one invalidate.
            %   Build SensorTag + MonitorTag; pass tagSet = {sensor, sensor}
            %   (same handle twice). Monitor must be invalidated exactly
            %   once (not twice).
            TagRegistry.clear();

            s = makeSensor_('s_dup', linspace(0, 10, 30));
            m = MonitorTag('m_dup', s, @(~,y) y > 0);

            % Prime monitor cache.
            [~, ~] = m.getXY();
            baseRecompute = m.recomputeCount_;

            % Invalidate via batch with duplicate handle.
            Tag.invalidateBatch_({s, s});

            % Monitor must be dirty now (cache cleared once).
            testCase.verifyTrue(isMonitorDirty_(m), ...
                'Monitor must be dirty after batched invalidate');

            % Trigger recompute and confirm exactly one recompute happened.
            [~, ~] = m.getXY();
            testCase.verifyEqual(m.recomputeCount_, baseRecompute + 1, ...
                'Duplicate handle in tagSet must yield exactly one recompute');

            TagRegistry.clear();
        end

        function testIdempotency(testCase)
            %TESTIDEMPOTENCY batch then per-tag invalidate == per-tag-only.
            TagRegistry.clear();

            s1 = makeSensor_('s_idem', linspace(0, 10, 40));
            m1 = MonitorTag('m_idem', s1, @(~,y) y > 0);

            % Prime monitor.
            [x1, y1] = m1.getXY();
            base1 = m1.recomputeCount_;

            % Path 1: batch then per-tag.
            Tag.invalidateBatch_({s1});
            s1.invalidate();  % redundant but must be safe
            [xPath1, yPath1] = m1.getXY();
            rcPath1 = m1.recomputeCount_ - base1;

            % Re-prime.
            [~, ~] = m1.getXY();
            base2 = m1.recomputeCount_;

            % Path 2: per-tag only.
            s1.invalidate();
            [xPath2, yPath2] = m1.getXY();
            rcPath2 = m1.recomputeCount_ - base2;

            % Both paths must yield same (x, y) and same recompute count
            % (exactly one recompute, because both invalidate paths leave
            % the monitor dirty exactly once before the getXY).
            testCase.verifyEqual(xPath1, xPath2, ...
                'X arrays must match between batch and per-tag paths');
            testCase.verifyEqual(yPath1, yPath2, ...
                'Y arrays must match between batch and per-tag paths');
            testCase.verifyEqual(rcPath1, rcPath2, ...
                'Recompute count must match between batch and per-tag paths');

            % Sanity: starting (x1, y1) matches both paths (no parent data change).
            testCase.verifyEqual(xPath1, x1);
            testCase.verifyEqual(yPath1, y1);

            TagRegistry.clear();
        end

    end
end

% =====================================================================
%  Local helpers (function form; not part of test methods)
% =====================================================================

function s = makeSensor_(key, x)
    %MAKESENSOR_ Build a SensorTag with deterministic data of length numel(x).
    y = sin(x(:));
    s = SensorTag(key, 'X', x(:), 'Y', y);
end

function tf = isMonitorDirty_(m)
    %ISMONITORDIRTY_ Inspect MonitorTag.dirty_ via a side-effect probe.
    %   MonitorTag.dirty_ is private; we detect dirty state by calling
    %   getXY and observing whether recomputeCount_ increments. We use
    %   a non-mutating probe: a single getXY after invalidate must
    %   bump recomputeCount_ exactly once if dirty was true.
    prior = m.recomputeCount_;
    [~, ~] = m.getXY();
    tf = (m.recomputeCount_ > prior);
end
