classdef TestFastSenseWidgetCurrentXLim < matlab.unittest.TestCase
%TESTFASTSENSEWIDGETCURRENTXLIM Unit suite for FastSenseWidget.getCurrentXLim (Phase 1039 Plan 02).
%   Proves the live-view-vs-data-cache semantics of getCurrentXLim():
%     - returns [] before render (no FastSenseObj / not IsRendered),
%     - returns the live wrapped-FastSense axes XLim (1x2) after render,
%     - tracks a programmatic xlim() change (reads the LIVE axes, not a cache),
%     - diverges from getTimeRange() (the data-extent cache) when zoomed.
%   Also covers the engine-owned CurrentViewXLimListener_ slot setter and
%   delete() cleanup (both must be no-throw).
%
%   Mirrors the off-screen-figure + addTeardown convention used by the other
%   FastSenseWidget suites (TestFastSenseWidgetTag, TestFastSenseWidgetPlantLog).
%
%   See also FastSenseWidget, FastSenseWidget.getCurrentXLim, FastSenseWidget.getTimeRange.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
        end
    end

    methods (Access = private)
        function w = makeRenderedWidget(testCase)
        %MAKERENDEREDWIDGET Build + render an inline-data FastSenseWidget off-screen.
        %   Inline-data binding (XData/YData) needs no Tag/registry. Returns the
        %   rendered widget; the host figure and widget are torn down via
        %   addTeardown so each test cleans up after itself.
            x = linspace(0, 10, 200);
            y = sin(x);
            w = FastSenseWidget('XData', x, 'YData', y);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.addTeardown(@() delete(w));
            drawnow;   % let the axes settle so XLim is populated
        end
    end

    methods (Test)

        function testEmptyBeforeRender(testCase)
            %TESTEMPTYBEFORERENDER getCurrentXLim() is [] before render.
            w = FastSenseWidget('XData', 0:10, 'YData', sin(0:10));
            testCase.addTeardown(@() delete(w));
            testCase.verifyEmpty(w.getCurrentXLim());
        end

        function testReturnsLiveXLimAfterRender(testCase)
            %TESTRETURNSLIVEXLIMAFTERRENDER 1x2 finite increasing == live axes XLim.
            w = testCase.makeRenderedWidget();
            xl = w.getCurrentXLim();
            testCase.verifySize(xl, [1 2]);
            testCase.verifyTrue(all(isfinite(xl)));
            testCase.verifyGreaterThan(xl(2), xl(1));
            axXl = get(w.FastSenseObj.hAxes, 'XLim');
            testCase.verifyEqual(xl, [axXl(1), axXl(2)], 'AbsTol', 1e-9);
        end

        function testReflectsZoom(testCase)
            %TESTREFLECTSZOOM Programmatic xlim() change is reflected (LIVE read).
            w = testCase.makeRenderedWidget();
            xlim(w.FastSenseObj.hAxes, [2 5]);
            drawnow;
            testCase.verifyEqual(w.getCurrentXLim(), [2 5], 'AbsTol', 1e-9);
        end

        function testNotEqualToDataExtentWhenZoomed(testCase)
            %TESTNOTEQUALTODATAEXTENTWHENZOOMED Live view differs from data cache.
            w = testCase.makeRenderedWidget();
            xlim(w.FastSenseObj.hAxes, [2 5]);
            drawnow;
            [dMin, dMax] = w.getTimeRange();
            testCase.verifyFalse(isequal(w.getCurrentXLim(), [dMin, dMax]));
        end

        function testListenerSlotSetterAndDeleteNoThrow(testCase)
            %TESTLISTENERSLOTSETTERANDDELETENOTHROW Engine slot setter + delete() are safe.
            x = linspace(0, 10, 200);
            y = sin(x);
            w = FastSenseWidget('XData', x, 'YData', y);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            drawnow;
            % The engine (Plan 03) hands a real addlistener handle here; storing
            % an empty placeholder must not throw, and delete() must release it.
            testCase.verifyWarningFree(@() w.setCurrentViewXLimListenerForEngine_([]));
            testCase.verifyWarningFree(@() delete(w));
        end

    end
end
