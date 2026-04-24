classdef TestDashboardEventsToggle < matlab.unittest.TestCase
    %TESTDASHBOARDEVENTSTOGGLE Coverage for quick 260424-jf5 (global Events
    %   toolbar toggle). Mirrors the Octave function-based test so both
    %   runners exercise the new code paths.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testEngineDefaultTrue(testCase)
            d = DashboardEngine('ToggleDefault');
            testCase.verifyTrue(isprop(d, 'EventMarkersVisible'));
            testCase.verifyTrue(d.EventMarkersVisible);
        end

        function testEngineFlagFlip(testCase)
            d = DashboardEngine('ToggleFlagFlip');
            d.setEventMarkersVisible(false);
            testCase.verifyFalse(d.EventMarkersVisible);
            d.setEventMarkersVisible(true);
            testCase.verifyTrue(d.EventMarkersVisible);
        end

        function testToolbarButtonExists(testCase)
            d = DashboardEngine('EventsBtnExists');
            d.addWidget('number', 'Title', 'T', ...
                'Position', [1 1 6 2], 'StaticValue', 1);
            d.render();
            hFig = d.hFigure;
            testCase.addTeardown(@() closeFigSafe(hFig));
            set(hFig, 'Visible', 'off');

            testCase.verifyNotEmpty(d.Toolbar.hEventsBtn);
            testCase.verifyTrue(ishandle(d.Toolbar.hEventsBtn));
            testCase.verifyNotEmpty(d.Toolbar.hEventsPanel);
            testCase.verifyTrue(ishandle(d.Toolbar.hEventsPanel));
            tip = get(d.Toolbar.hEventsBtn, 'TooltipString');
            testCase.verifyNotEmpty(tip, ...
                'Events button must have a tooltip');
        end

        function testIndicatorBorderSwap(testCase)
            d = DashboardEngine('EventsBorder');
            d.addWidget('number', 'Title', 'T', ...
                'Position', [1 1 6 2], 'StaticValue', 1);
            d.render();
            hFig = d.hFigure;
            testCase.addTeardown(@() closeFigSafe(hFig));
            set(hFig, 'Visible', 'off');

            theme = d.getCachedTheme();

            d.Toolbar.setEventsActiveIndicator(true);
            onColor = get(d.Toolbar.hEventsPanel, 'HighlightColor');
            testCase.verifyLessThan(max(abs(onColor - theme.InfoColor)), 1e-6);

            d.Toolbar.setEventsActiveIndicator(false);
            offColor = get(d.Toolbar.hEventsPanel, 'HighlightColor');
            testCase.verifyLessThan(max(abs(offColor - theme.ToolbarBackground)), 1e-6);
        end

        function testFastSenseToggleClearsAndRepopulates(testCase)
            EventBinding.clear();
            f = figure('Visible', 'off');
            testCase.addTeardown(@() closeFigSafe(f));
            ax = axes('Parent', f);
            es = EventStore('');
            tag = SensorTag('tgl_fs', 'X', 1:100, 'Y', sin((1:100)/10)*30 + 40);
            tag.EventStore = es;
            tag.addManualEvent(20, 25, 'ev_a', '');
            tag.addManualEvent(60, 65, 'ev_b', '');

            fp = FastSense('Parent', ax);
            fp.EventStore = es;
            fp.addTag(tag);
            fp.render();

            fp.setShowEventMarkers(false);
            testCase.verifyFalse(fp.ShowEventMarkers);
            testCase.verifyEqual(countRoundMarkers(ax), 0, ...
                'round markers should be gone after toggle off');

            fp.setShowEventMarkers(true);
            testCase.verifyTrue(fp.ShowEventMarkers);
            testCase.verifyGreaterThanOrEqual(countRoundMarkers(ax), 1, ...
                'round markers should repopulate after toggle on');
        end

        function testFastSenseWidgetPreRenderNoOp(testCase)
            w = FastSenseWidget('Title', 'PreRender', 'Position', [1 1 6 2]);
            % No FastSenseObj yet — must not error.
            w.setEventMarkersVisible(false);
            w.setEventMarkersVisible(true);
            testCase.verifyTrue(true);  % reaching here = success
        end

        function testEventTimelineWidgetIsExempt(testCase)
            tw = EventTimelineWidget('Title', 'Tml', 'Position', [1 1 6 2]);
            testCase.verifyFalse(ismethod(tw, 'setEventMarkersVisible'), ...
                ['EventTimelineWidget must NOT implement setEventMarkersVisible ' ...
                 '— it exists solely to display events, so the engine fan-out ' ...
                 'skips it via ismethod().']);
        end

        function testFanoutUpdatesToolbarIndicator(testCase)
            d = DashboardEngine('FanoutIndicator');
            d.addWidget('number', 'Title', 'T', ...
                'Position', [1 1 6 2], 'StaticValue', 1);
            d.render();
            hFig = d.hFigure;
            testCase.addTeardown(@() closeFigSafe(hFig));
            set(hFig, 'Visible', 'off');

            theme = d.getCachedTheme();

            d.setEventMarkersVisible(false);
            borderOff = get(d.Toolbar.hEventsPanel, 'HighlightColor');
            testCase.verifyLessThan(max(abs(borderOff - theme.ToolbarBackground)), 1e-6);
            testCase.verifyFalse(d.EventMarkersVisible);

            d.setEventMarkersVisible(true);
            borderOn = get(d.Toolbar.hEventsPanel, 'HighlightColor');
            testCase.verifyLessThan(max(abs(borderOn - theme.InfoColor)), 1e-6);
        end
    end
end

function n = countRoundMarkers(ax)
    children = allchild(ax);
    n = 0;
    for i = 1:numel(children)
        try
            mk = get(children(i), 'Marker');
            ls = get(children(i), 'LineStyle');
            if strcmp(mk, 'o') && strcmp(ls, 'none')
                n = n + 1;
            end
        catch
            % non-line children — ignore
        end
    end
end

function closeFigSafe(h)
    try
        if ~isempty(h) && ishandle(h)
            close(h);
        end
    catch
        % teardown best-effort
    end
end
