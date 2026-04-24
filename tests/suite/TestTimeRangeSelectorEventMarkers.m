classdef TestTimeRangeSelectorEventMarkers < matlab.unittest.TestCase
%TESTTIMERANGESELECTOREVENTMARKERS Unit tests for TimeRangeSelector.setEventMarkers
%   and the related DashboardWidget/EventTimelineWidget/FastSenseWidget
%   getEventTimes overrides.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Access = private)
        function sel = makeSelector(testCase)
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            sel = TimeRangeSelector(hp);
            testCase.addTeardown(@() delete(sel));
            sel.setDataRange(0, 100);
        end
    end

    methods (Test)
        function testSetEventMarkersDrawsLines(testCase)
            sel = testCase.makeSelector();
            sel.setEventMarkers([10 25 60 90]);
            testCase.verifyEqual(numel(sel.hEventMarkers), 4, ...
                'Expected one line handle per finite event time.');
            for k = 1:numel(sel.hEventMarkers)
                h = sel.hEventMarkers(k);
                testCase.verifyTrue(ishandle(h), ...
                    'Each marker handle must be a valid graphics handle.');
                xd = get(h, 'XData');
                testCase.verifyEqual(xd(1), xd(2), ...
                    'Marker line must be vertical (XData(1) == XData(2)).');
            end
            xs = zeros(1, numel(sel.hEventMarkers));
            for k = 1:numel(sel.hEventMarkers)
                xd = get(sel.hEventMarkers(k), 'XData');
                xs(k) = xd(1);
            end
            testCase.verifyEqual(sort(xs), [10 25 60 90], ...
                'Marker X positions should match the requested event times.');
        end

        function testSetEventMarkersEmptyClears(testCase)
            sel = testCase.makeSelector();
            sel.setEventMarkers([10 20 30]);
            testCase.verifyEqual(numel(sel.hEventMarkers), 3);
            sel.setEventMarkers([]);
            testCase.verifyEmpty(sel.hEventMarkers, ...
                'Empty input must clear previously-drawn markers.');
        end

        function testSetEventMarkersNaNFiltered(testCase)
            sel = testCase.makeSelector();
            sel.setEventMarkers([10 NaN 20 Inf -Inf 30]);
            testCase.verifyEqual(numel(sel.hEventMarkers), 3, ...
                'Non-finite values (NaN, Inf, -Inf) must be dropped.');
            xs = zeros(1, numel(sel.hEventMarkers));
            for k = 1:numel(sel.hEventMarkers)
                xd = get(sel.hEventMarkers(k), 'XData');
                xs(k) = xd(1);
            end
            testCase.verifyEqual(sort(xs), [10 20 30]);
        end

        function testSetEventMarkersReplacesPrevious(testCase)
            sel = testCase.makeSelector();
            sel.setEventMarkers([10 20]);
            oldHandles = sel.hEventMarkers;
            testCase.verifyEqual(numel(oldHandles), 2);
            sel.setEventMarkers([40 50 60]);
            testCase.verifyEqual(numel(sel.hEventMarkers), 3, ...
                'New call must produce one handle per new finite time.');
            for k = 1:numel(oldHandles)
                testCase.verifyFalse(ishandle(oldHandles(k)), ...
                    'Old marker handles must be deleted when replaced.');
            end
            xs = zeros(1, numel(sel.hEventMarkers));
            for k = 1:numel(sel.hEventMarkers)
                xd = get(sel.hEventMarkers(k), 'XData');
                xs(k) = xd(1);
            end
            testCase.verifyEqual(sort(xs), [40 50 60]);
        end

        function testEventMarkersNotClickable(testCase)
            sel = testCase.makeSelector();
            sel.setEventMarkers(50);
            testCase.verifyEqual(numel(sel.hEventMarkers), 1);
            h = sel.hEventMarkers(1);
            testCase.verifyEqual(get(h, 'HitTest'), 'off', ...
                'Event markers must not intercept mouse clicks.');
            testCase.verifyEqual(get(h, 'PickableParts'), 'none', ...
                'Event markers must be non-pickable.');
        end

        function testEventMarkersBehindSelection(testCase)
            sel = testCase.makeSelector();
            sel.setEventMarkers(50);
            testCase.verifyEqual(numel(sel.hEventMarkers), 1);
            h = sel.hEventMarkers(1);
            ch = get(sel.hAxes, 'Children');
            idxSelection = find(ch == sel.hSelection, 1);
            idxMarker    = find(ch == h, 1);
            testCase.verifyNotEmpty(idxSelection);
            testCase.verifyNotEmpty(idxMarker);
            % Lower index in Children = drawn on top in MATLAB axes order.
            testCase.verifyLessThan(idxSelection, idxMarker, ...
                'Selection patch must sit above event markers in axes child order.');
        end

        function testDashboardWidgetBaseReturnsEmpty(testCase)
            w = NumberWidget('Title', 'BaseNoOverride', 'ValueFcn', @() 1);
            testCase.verifyEmpty(w.getEventTimes(), ...
                'DashboardWidget.getEventTimes must default to [] for non-overriding subclasses.');
        end

        function testEventTimelineWidgetGetEventTimesStatic(testCase)
            evts = struct('startTime', {10, 20, 30}, ...
                          'endTime',   {15, 25, 35}, ...
                          'label',     {'A', 'B', 'A'}, ...
                          'color',     {[1 0 0], [0 1 0], [0 0 1]});
            w = EventTimelineWidget('Title', 'Static', 'Events', evts);
            t = w.getEventTimes();
            testCase.verifyEqual(sort(t), [10 20 30], ...
                'getEventTimes must return the startTime row vector.');
            testCase.verifySize(t, [1 3], ...
                'getEventTimes must return a row vector.');
        end

        function testEventTimelineWidgetGetEventTimesFilter(testCase)
            evts = struct('startTime', {10, 20, 30}, ...
                          'endTime',   {15, 25, 35}, ...
                          'label',     {'Pump-101', 'Valve-202', 'Pump-101'}, ...
                          'color',     {[1 0 0], [0 1 0], [0 0 1]});
            w = EventTimelineWidget('Title', 'Filtered', ...
                'Events', evts, 'FilterSensors', {'Pump-101'});
            t = w.getEventTimes();
            testCase.verifyEqual(sort(t), [10 30], ...
                'Filter must only yield events whose label matches Pump-101.');
        end

        function testFastSenseWidgetGetEventTimesNoStore(testCase)
            w = FastSenseWidget('Title', 'NoStore', ...
                'XData', 1:10, 'YData', rand(1, 10));
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            t = w.getEventTimes();
            testCase.verifyEmpty(t, ...
                'FastSenseWidget without an EventStore must return [].');
        end

        function testFastSenseWidgetGetEventTimesNeverThrows(testCase)
            w = FastSenseWidget('Title', 'Unrendered', ...
                'XData', 1:5, 'YData', 1:5);
            % No render -> FastSenseObj is []. Must not throw.
            t = w.getEventTimes();
            testCase.verifyEmpty(t, ...
                'FastSenseWidget.getEventTimes must return [] without throwing when unrendered.');
        end
    end
end
