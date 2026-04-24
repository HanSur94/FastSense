classdef TestDashboardEngineEventMarkers < matlab.unittest.TestCase
%TESTDASHBOARDENGINEEVENTMARKERS Integration tests for
%   DashboardEngine.computeEventMarkers + the 4 hook-site wire-up.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath'))));
            install();
        end
    end

    methods (Test)
        function testEventMarkersDrawnOnRender(testCase)
            evts = struct('startTime', {10, 20, 30}, ...
                          'endTime',   {15, 25, 35}, ...
                          'label',     {'A', 'B', 'A'}, ...
                          'color',     {[1 0 0], [0 1 0], [0 0 1]});
            d = DashboardEngine('EvtMarkRender');
            d.addWidget(EventTimelineWidget('Title', 'T', 'Events', evts));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            x = markerXData(d.TimeRangeSelector_);
            testCase.verifyEqual(x, [10 20 30]);
        end

        function testEventMarkersUpdateOnSwitchPage(testCase)
            e1 = struct('startTime', {5, 15}, 'endTime', {6, 16}, ...
                        'label', {'A','B'}, 'color', {[1 0 0],[0 1 0]});
            e2 = struct('startTime', {100, 200, 300}, ...
                        'endTime',   {110, 210, 310}, ...
                        'label',     {'X','Y','Z'}, ...
                        'color',     {[1 0 0],[0 1 0],[0 0 1]});
            d = DashboardEngine('EvtMarkSwitch');
            d.addPage('P1');
            d.addWidget(EventTimelineWidget('Title', 'T1', 'Events', e1));
            d.addPage('P2');
            d.switchPage(2);
            d.addWidget(EventTimelineWidget('Title', 'T2', 'Events', e2));
            d.switchPage(1);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            testCase.verifyEqual(markerXData(d.TimeRangeSelector_), [5 15]);
            d.switchPage(2);
            testCase.verifyEqual(markerXData(d.TimeRangeSelector_), [100 200 300]);
        end

        function testEventMarkersUpdateOnUpdateGlobalTimeRange(testCase)
            evts = struct('startTime', {10, 20}, 'endTime', {11, 21}, ...
                          'label', {'A','B'}, 'color', {[1 0 0],[0 1 0]});
            d = DashboardEngine('EvtMarkUpdate');
            w = EventTimelineWidget('Title', 'T', 'Events', evts);
            d.addWidget(w);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            testCase.verifyEqual(markerXData(d.TimeRangeSelector_), [10 20]);
            % Mutate the widget's static events.
            w.Events = struct('startTime', {10, 20, 30}, ...
                              'endTime',   {11, 21, 31}, ...
                              'label',     {'A','B','C'}, ...
                              'color',     {[1 0 0],[0 1 0],[0 0 1]});
            d.updateGlobalTimeRange();
            testCase.verifyEqual(markerXData(d.TimeRangeSelector_), [10 20 30]);
        end

        function testEventMarkersUpdateOnLiveTick(testCase)
            evts = struct('startTime', {10, 20}, 'endTime', {11, 21}, ...
                          'label', {'A','B'}, 'color', {[1 0 0],[0 1 0]});
            d = DashboardEngine('EvtMarkTick');
            w = EventTimelineWidget('Title', 'T', 'Events', evts);
            d.addWidget(w);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            testCase.verifyEqual(markerXData(d.TimeRangeSelector_), [10 20]);
            w.Events = struct('startTime', {10, 20, 30}, ...
                              'endTime',   {11, 21, 31}, ...
                              'label',     {'A','B','C'}, ...
                              'color',     {[1 0 0],[0 1 0],[0 0 1]});
            d.onLiveTick();
            testCase.verifyEqual(markerXData(d.TimeRangeSelector_), [10 20 30]);
        end

        function testEventMarkersDedupAndSort(testCase)
            e1 = struct('startTime', {50, 10, 30}, ...
                        'endTime',   {51, 11, 31}, ...
                        'label',     {'A','B','C'}, ...
                        'color',     {[1 0 0],[0 1 0],[0 0 1]});
            e2 = struct('startTime', {30, 20}, 'endTime', {31, 21}, ...
                        'label', {'X','Y'}, 'color', {[1 0 0],[0 1 0]});
            d = DashboardEngine('EvtMarkDedup');
            d.addWidget(EventTimelineWidget('Title', 'T1', 'Events', e1));
            d.addWidget(EventTimelineWidget('Title', 'T2', 'Events', e2));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            testCase.verifyEqual(markerXData(d.TimeRangeSelector_), ...
                [10 20 30 50], ...
                'Marker X positions must be unique & ascending across widgets.');
        end

        function testEventMarkersNonFiniteFiltered(testCase)
            evts = struct('startTime', {10, NaN, 20, Inf, 30}, ...
                          'endTime',   {11, 12, 21, 22, 31}, ...
                          'label',     {'A','B','C','D','E'}, ...
                          'color',     {[1 0 0],[0 1 0],[0 0 1],[1 1 0],[0 1 1]});
            d = DashboardEngine('EvtMarkNaN');
            d.addWidget(EventTimelineWidget('Title', 'T', 'Events', evts));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            testCase.verifyEqual(markerXData(d.TimeRangeSelector_), [10 20 30], ...
                'Non-finite startTimes must be dropped before marker draw.');
        end

        function testEventMarkersEmptyWidgetsNoCrash(testCase)
            d = DashboardEngine('EvtMarkEmpty');
            d.addWidget('number', 'Title', 'N', 'ValueFcn', @() 1, ...
                'Position', [1 1 6 1]);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            testCase.verifyEmpty(d.TimeRangeSelector_.hEventMarkers, ...
                'Dashboards with no event-bearing widgets must draw no markers.');
        end

        function testEventMarkersWidgetGetEventTimesThrows(testCase)
            evts = struct('startTime', {10, 20}, 'endTime', {11, 21}, ...
                          'label', {'A','B'}, 'color', {[1 0 0],[0 1 0]});
            d = DashboardEngine('EvtMarkThrow');
            % Bad widget first — engine must swallow its error and still
            % render markers for the well-behaved EventTimelineWidget.
            bad = ThrowingEventWidget('Title', 'Bad', 'ValueFcn', @() 1, ...
                'Position', [1 1 6 1]);
            d.addWidget(bad);
            d.addWidget(EventTimelineWidget('Title', 'Good', 'Events', evts));
            ws = warning('off', 'DashboardEngine:getEventTimesFailed');
            testCase.addTeardown(@() warning(ws));
            d.render();
            testCase.addTeardown(@() close(d.hFigure));
            testCase.verifyEqual(markerXData(d.TimeRangeSelector_), [10 20], ...
                'Throwing widget must not prevent markers from well-behaved siblings.');
        end
    end
end

function x = markerXData(sel)
    x = zeros(1, numel(sel.hEventMarkers));
    for k = 1:numel(sel.hEventMarkers)
        xd = get(sel.hEventMarkers(k), 'XData');
        x(k) = xd(1);
    end
    x = sort(x);
end
