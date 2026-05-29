classdef TestDashboardCurrentViewIndicator < matlab.unittest.TestCase
%TESTDASHBOARDCURRENTVIEWINDICATOR End-to-end integration suite for the Phase 1039 current-view box.
%   Goal-backward verification: builds a real DashboardEngine with multiple
%   FastSenseWidgets, zooms ONE (or more) widget(s) out of sync, drives the
%   engine indicator via the public test seam updateCurrentViewIndicatorForTest_,
%   and asserts the slider's hCurrentViewBox becomes visible at the zoomed
%   widget's XLim union; re-syncing (broadcastTimeRange) hides it; an all-synced
%   dashboard never shows it.
%
%   This asserts the observable truths of the phase goal against the INTEGRATED
%   stack from Plans 01-03:
%     - Plan 01: TimeRangeSelector.hCurrentViewBox + setCurrentView/hideCurrentView
%     - Plan 02: FastSenseWidget.getCurrentXLim + UseGlobalTime out-of-sync signal
%     - Plan 03: DashboardEngine.updateCurrentViewIndicator_ + the test seam
%
%   Determinism note: the indicator decision is driven through the PUBLIC seam
%   updateCurrentViewIndicatorForTest_ rather than the XLim PostSet listener,
%   which Octave skips. zoomWidget_ additionally forces UseGlobalTime=false so
%   the out-of-sync state is robust on Octave (on MATLAB the listener already
%   flipped it, so the explicit set is a no-op).
%
%   Coverage:
%     testBoxHiddenWhenAllSynced        -> all-synced -> box hidden, CurrentView empty
%     testBoxAppearsWhenWidgetZoomed    -> one zoomed -> box visible at that window
%     testBoxHidesAfterResync           -> broadcastTimeRange re-sync -> box hidden
%     testUnionOfTwoOutOfSyncWidgets    -> two zoomed -> box spans the union
%     testSubEpsilonDifferenceStaysHidden -> sub-epsilon delta from Selection -> hidden
%     testNoSelectorGuardNoThrow        -> engine without a slider -> seam no-throw

    properties
        Engines = {}
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            thisDir  = fileparts(mfilename('fullpath'));
            repoRoot = fileparts(fileparts(thisDir));
            addpath(repoRoot);
            install();
        end
    end

    methods (TestMethodTeardown)
        function cleanup(testCase)
            for k = 1:numel(testCase.Engines)
                try
                    if ~isempty(testCase.Engines{k}) && isvalid(testCase.Engines{k})
                        delete(testCase.Engines{k});
                    end
                catch
                end
            end
            testCase.Engines = {};
            try close all force; catch, end
            try drawnow; catch, end
        end
    end

    methods (Access = private)
        function [d, x] = makeDashboard_(testCase, nWidgets)
            %makeDashboard_  Build + render an nWidgets FastSense dashboard over X in [0 100].
            %   Inline XData/YData so the rendered axes carry a real data range
            %   (DataTimeRange == [0 100]) the indicator can reason about. The
            %   figure is made invisible after render so the suite runs headless
            %   without flicker; the slider (TimeRangeSelector_) still builds.
            x = linspace(0, 100, 300);
            d = DashboardEngine('CurrentView Test');
            for k = 1:nWidgets
                d.addWidget('fastsense', ...
                    'Position', [1, 1 + (k - 1) * 4, 24, 4], ...
                    'XData', x, 'YData', sin(x / 5) + k);
            end
            d.render();
            try set(d.hFigure, 'Visible', 'off'); catch, end
            drawnow;
            testCase.Engines{end + 1} = d;
        end

        function zoomWidget_(~, w, a, b)
            %zoomWidget_  Simulate a widget showing the sub-window [a b], out of sync.
            %   Drives the deterministic test seam CurrentXLimOverrideForTest_ rather
            %   than poking the live axes: FastSense rebuilds its axes during the
            %   zoom-re-resolve, so a raw xlim() set is not durable under the
            %   unittest runner's event flushing (it can snap back to the data
            %   extent before the seam reads it). The real axes<->getCurrentXLim
            %   path is verified deterministically by TestFastSenseWidgetCurrentXLim.
            %   We also set the live axes (realistic) and force UseGlobalTime=false
            %   (on Octave the XLim PostSet listener that flips it may not fire).
            try
                ax = w.FastSenseObj.hAxes;
                if ishandle(ax); xlim(ax, [a b]); end
            catch
            end
            w.CurrentXLimOverrideForTest_ = [a b];
            w.UseGlobalTime = false;
            drawnow;
        end
    end

    methods (Test)
        function testBoxHiddenWhenAllSynced(testCase)
            % All widgets in sync (none UseGlobalTime==false): the box stays
            % hidden and CurrentView is empty even after the seam runs.
            [d, ~] = testCase.makeDashboard_(2);
            sel = d.TimeRangeSelector_;
            testCase.assumeNotEmpty(sel, ...
                'No TimeRangeSelector built (slider-less environment) — skip.');

            d.updateCurrentViewIndicatorForTest_();

            testCase.verifyEqual(char(get(sel.hCurrentViewBox, 'Visible')), 'off', ...
                'All-synced dashboard must keep the current-view box hidden.');
            testCase.verifyEmpty(sel.CurrentView, ...
                'CurrentView must be empty when nothing is out of sync.');
        end

        function testBoxAppearsWhenWidgetZoomed(testCase)
            % Zoom widget 1 to an interior sub-window distinct from the Selection,
            % drive the seam, and assert the box surfaces at exactly that window.
            [d, ~] = testCase.makeDashboard_(2);
            sel = d.TimeRangeSelector_;
            testCase.assumeNotEmpty(sel, ...
                'No TimeRangeSelector built (slider-less environment) — skip.');

            w1 = d.Widgets{1};
            testCase.zoomWidget_(w1, 20, 40);
            d.updateCurrentViewIndicatorForTest_();

            testCase.verifyEqual(char(get(sel.hCurrentViewBox, 'Visible')), 'on', ...
                'Zooming a widget out of sync must surface the current-view box.');
            testCase.verifyEqual(sel.CurrentView, [20 40], 'AbsTol', 0.1, ...
                'CurrentView must match the zoomed widget''s XLim window.');
            boxX = reshape(get(sel.hCurrentViewBox, 'XData'), 1, []);
            testCase.verifyEqual(boxX, [20 20 40 40], 'AbsTol', 0.1, ...
                'Box XData must follow the [xL xL xR xR] patch shape at the zoomed window.');
        end

        function testBoxHidesAfterResync(testCase)
            % From a zoomed/showing state, re-sync via the PUBLIC broadcastTimeRange
            % path (exercises Plan 03 SITE 2: broadcastTimeRange calls the indicator).
            % With no widget out of sync, the box hides.
            [d, ~] = testCase.makeDashboard_(2);
            sel = d.TimeRangeSelector_;
            testCase.assumeNotEmpty(sel, ...
                'No TimeRangeSelector built (slider-less environment) — skip.');

            w1 = d.Widgets{1};
            testCase.zoomWidget_(w1, 20, 40);
            d.updateCurrentViewIndicatorForTest_();
            testCase.verifyEqual(char(get(sel.hCurrentViewBox, 'Visible')), 'on', ...
                'Precondition: box must be visible before re-sync.');

            % Re-sync: clear the out-of-sync flag, then broadcast a window.
            % broadcastTimeRange itself re-runs updateCurrentViewIndicator_;
            % with the widget back in sync the box must hide.
            w1.UseGlobalTime = true;
            d.broadcastTimeRange(20, 40);
            drawnow;

            testCase.verifyEqual(char(get(sel.hCurrentViewBox, 'Visible')), 'off', ...
                'Re-syncing via broadcastTimeRange must hide the current-view box.');
            testCase.verifyEmpty(sel.CurrentView, ...
                'CurrentView must be empty after re-sync.');
        end

        function testUnionOfTwoOutOfSyncWidgets(testCase)
            % Two widgets zoomed to disjoint windows: the box spans their UNION
            % (min start, max end).
            [d, ~] = testCase.makeDashboard_(2);
            sel = d.TimeRangeSelector_;
            testCase.assumeNotEmpty(sel, ...
                'No TimeRangeSelector built (slider-less environment) — skip.');

            w1 = d.Widgets{1};
            w2 = d.Widgets{2};
            testCase.zoomWidget_(w1, 10, 30);
            testCase.zoomWidget_(w2, 50, 80);
            d.updateCurrentViewIndicatorForTest_();

            testCase.verifyEqual(char(get(sel.hCurrentViewBox, 'Visible')), 'on', ...
                'Two out-of-sync widgets must surface the current-view box.');
            testCase.verifyEqual(sel.CurrentView, [10 80], 'AbsTol', 0.1, ...
                'CurrentView must be the union [min(starts) max(ends)] of both windows.');
        end

        function testSubEpsilonDifferenceStaysHidden(testCase)
            % A widget whose live XLim differs from the Selection by less than the
            % epsilon (0.005 * span = 0.5 over span 100) must NOT show the box —
            % this guards against float-noise flicker. The widget IS flagged
            % out-of-sync, but the union ~ Selection within epsilon -> hidden.
            [d, ~] = testCase.makeDashboard_(1);
            sel = d.TimeRangeSelector_;
            testCase.assumeNotEmpty(sel, ...
                'No TimeRangeSelector built (slider-less environment) — skip.');

            [selStart, selEnd] = sel.getSelection();
            % Nudge by 0.1 each side: well under epsilon (0.5) for span 100.
            w1 = d.Widgets{1};
            testCase.zoomWidget_(w1, selStart + 0.1, selEnd - 0.1);
            d.updateCurrentViewIndicatorForTest_();

            testCase.verifyEqual(char(get(sel.hCurrentViewBox, 'Visible')), 'off', ...
                'A sub-epsilon difference from the Selection must NOT show the box.');
            testCase.verifyEmpty(sel.CurrentView, ...
                'CurrentView must stay empty for a sub-epsilon difference.');
        end

        function testNoSelectorGuardNoThrow(testCase)
            % Guard: an engine with no TimeRangeSelector_ (never rendered) must
            % no-op cleanly when the seam is called — never throw.
            d = DashboardEngine('NoSelector');
            testCase.Engines{end + 1} = d;
            d.addWidget('fastsense', 'Position', [1 1 24 4], ...
                'XData', linspace(0, 100, 50), 'YData', linspace(0, 1, 50));
            testCase.verifyEmpty(d.TimeRangeSelector_, ...
                'Precondition: no slider before render.');
            try
                d.updateCurrentViewIndicatorForTest_();
                testCase.verifyTrue(true, ...
                    'Seam must no-op (not throw) when no TimeRangeSelector_ exists.');
            catch err
                testCase.verifyFail(sprintf( ...
                    'Seam must not throw without a slider, but threw: %s', err.message));
            end
        end
    end
end
