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

        function xs = extractMarkerTimes(~, sel)
            %extractMarkerTimes  Collect all finite event times from
            %   hEventMarkers handles. setEventMarkers now uses
            %   NaN-separated polylines (one handle per unique color group),
            %   so XData is [t t NaN t t NaN ...]. We extract the first
            %   value of each [t t NaN] triplet across all handles.
            %   (260508-slider-stuck: NaN-separator reduces O(N) handles to
            %   O(N_colors), so numel(hEventMarkers) is not equal to the
            %   event count — use this helper instead.)
            xs = [];
            for k = 1:numel(sel.hEventMarkers)
                h = sel.hEventMarkers(k);
                if ~ishandle(h), continue; end
                xd = get(h, 'XData');
                % Every NaN-separated segment is [t t NaN]; take index 1,4,7,...
                for idx = 1:3:numel(xd)
                    v = xd(idx);
                    if isfinite(v)
                        xs(end + 1) = v; %#ok<AGROW>
                    end
                end
            end
        end
    end

    methods (Test)
        function testSetEventMarkersDrawsLines(testCase)
            % setEventMarkers now uses NaN-separated polylines grouped by
            % color: uniform color → 1 handle for all events, not 1 per event.
            % Verify all 4 times appear in the combined XData. (260508-slider-stuck)
            sel = testCase.makeSelector();
            sel.setEventMarkers([10 25 60 90]);
            testCase.verifyGreaterThan(numel(sel.hEventMarkers), 0, ...
                'Expected at least one line handle after setEventMarkers.');
            for k = 1:numel(sel.hEventMarkers)
                testCase.verifyTrue(ishandle(sel.hEventMarkers(k)), ...
                    'Each marker handle must be a valid graphics handle.');
            end
            % For NaN-separator polylines: XData = [t t NaN t t NaN ...].
            % The pair (xd(1),xd(2)) within each segment are equal → vertical.
            for k = 1:numel(sel.hEventMarkers)
                xd = get(sel.hEventMarkers(k), 'XData');
                testCase.verifyEqual(xd(1), xd(2), ...
                    'First segment of each marker handle must be vertical.');
            end
            xs = testCase.extractMarkerTimes(sel);
            testCase.verifyEqual(sort(xs), [10 25 60 90], ...
                'All requested finite event times must appear in marker XData.');
        end

        function testSetEventMarkersEmptyClears(testCase)
            sel = testCase.makeSelector();
            sel.setEventMarkers([10 20 30]);
            testCase.verifyGreaterThan(numel(sel.hEventMarkers), 0, ...
                'setEventMarkers with 3 times must create at least one handle.');
            sel.setEventMarkers([]);
            testCase.verifyEmpty(sel.hEventMarkers, ...
                'Empty input must clear previously-drawn markers.');
        end

        function testSetEventMarkersNaNFiltered(testCase)
            % Non-finite times must be excluded from the marker polylines.
            sel = testCase.makeSelector();
            sel.setEventMarkers([10 NaN 20 Inf -Inf 30]);
            testCase.verifyGreaterThan(numel(sel.hEventMarkers), 0, ...
                'Non-finite filtering must leave at least one handle for the 3 finite times.');
            xs = testCase.extractMarkerTimes(sel);
            testCase.verifyEqual(sort(xs), [10 20 30], ...
                'Only finite times (10, 20, 30) must appear after NaN/Inf filtering.');
        end

        function testSetEventMarkersReplacesPrevious(testCase)
            % Old handles must be deleted on the next setEventMarkers call.
            sel = testCase.makeSelector();
            sel.setEventMarkers([10 20]);
            oldHandles = sel.hEventMarkers;
            testCase.verifyGreaterThan(numel(oldHandles), 0, ...
                'First call must create at least one handle.');
            sel.setEventMarkers([40 50 60]);
            testCase.verifyGreaterThan(numel(sel.hEventMarkers), 0, ...
                'Second call must produce at least one handle for 3 new times.');
            for k = 1:numel(oldHandles)
                testCase.verifyFalse(ishandle(oldHandles(k)), ...
                    'Old marker handles must be deleted when replaced.');
            end
            xs = testCase.extractMarkerTimes(sel);
            testCase.verifyEqual(sort(xs), [40 50 60], ...
                'New call must draw only the new event times.');
        end

        function testEventMarkersNotClickable(testCase)
            sel = testCase.makeSelector();
            sel.setEventMarkers(50);
            testCase.verifyEqual(numel(sel.hEventMarkers), 1);
            h = sel.hEventMarkers(1);
            % MATLAB R2020b+ returns matlab.lang.OnOffSwitchState enum from
            % get(...,'HitTest'); Octave returns char. Normalize via char().
            testCase.verifyEqual(char(get(h, 'HitTest')), 'off', ...
                'Event markers must not intercept mouse clicks.');
            testCase.verifyEqual(char(get(h, 'PickableParts')), 'none', ...
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

        function testFastSenseWidgetGetEventTimesWithEventStore(testCase)
        %TESTFASTSENSEWIDGETGETEVENTTIMESWITHEVENTSTORE Live round-trip:
        %   bind a real EventStore to the rendered FastSense and confirm
        %   getEventTimes() returns the StartTime values (PascalCase path).
            w = FastSenseWidget('Title', 'WithStore', ...
                'XData', 1:10, 'YData', rand(1, 10));
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            % EventStore is in-memory until save() — pure RAM test, no I/O.
            store = EventStore('');
            store.append(struct( ...
                'StartTime',      {10, 25, 40}, ...
                'EndTime',        {12, 27, 42}, ...
                'SensorName',     {'s1', 's1', 's2'}, ...
                'ThresholdLabel', {'high', 'high', 'low'}, ...
                'Severity',       {'warn', 'warn', 'crit'}));
            % Extract local handle: Octave forbids dot-chain assignment
            % through a SetAccess=private parent property, but mutating
            % through a local handle still updates the same FastSense.
            fp = w.FastSenseObj;
            fp.EventStore = store;
            t = w.getEventTimes();
            testCase.verifyEqual(sort(t), [10 25 40], ...
                'FastSenseWidget must read StartTime (PascalCase) from EventStore.getEvents.');
            testCase.verifySize(t, [1 3], ...
                'getEventTimes must return a row vector.');
            % Live append: a new event between ticks must surface on the
            % next getEventTimes() call without re-rendering the widget.
            store.append(struct( ...
                'StartTime',      55, ...
                'EndTime',        57, ...
                'SensorName',     's1', ...
                'ThresholdLabel', 'high', ...
                'Severity',       'warn'));
            t2 = w.getEventTimes();
            testCase.verifyEqual(sort(t2), [10 25 40 55], ...
                'Live append must surface in the next getEventTimes call.');
        end
    end
end
