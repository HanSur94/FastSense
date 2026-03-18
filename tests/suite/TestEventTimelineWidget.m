classdef TestEventTimelineWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = EventTimelineWidget('Title', 'Timeline');
            testCase.verifyEqual(w.Title, 'Timeline');
            testCase.verifyEmpty(w.Events);
            testCase.verifyEmpty(w.EventFcn);
            testCase.verifyEmpty(w.EventStoreObj);
            testCase.verifyEmpty(w.FilterSensors);
            testCase.verifyEqual(w.ColorSource, 'event');
        end

        function testDefaultPosition(testCase)
            w = EventTimelineWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 24 2], ...
                'EventTimelineWidget default position should be [1 1 24 2]');
        end

        function testRender(testCase)
            evts = struct('startTime', {100, 200}, ...
                          'endTime',   {150, 250}, ...
                          'label',     {'Alarm', 'Warning'}, ...
                          'color',     {[1 0 0], [1 1 0]});
            w = EventTimelineWidget('Title', 'Render Test', 'Events', evts);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyNotEmpty(w.hAxes, ...
                'Axes handle should be created after render');
        end

        function testRefreshStaticEvents(testCase)
            evts = struct('startTime', {10, 20, 30}, ...
                          'endTime',   {15, 25, 35}, ...
                          'label',     {'A', 'B', 'A'}, ...
                          'color',     {[1 0 0], [0 1 0], [0 0 1]});
            w = EventTimelineWidget('Title', 'Static', 'Events', evts);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyNotEmpty(w.hBars, ...
                'hBars should contain bar handles after rendering events');
            testCase.verifyEqual(numel(w.hBars), 3, ...
                'Should have one bar per event');
        end

        function testGetTimeRange(testCase)
            evts = struct('startTime', {100, 200, 50}, ...
                          'endTime',   {150, 300, 80}, ...
                          'label',     {'A', 'B', 'C'}, ...
                          'color',     {[1 0 0], [0 1 0], [0 0 1]});
            w = EventTimelineWidget('Title', 'Range', 'Events', evts);
            [tMin, tMax] = w.getTimeRange();
            testCase.verifyEqual(tMin, 50, ...
                'tMin should be the earliest startTime');
            testCase.verifyEqual(tMax, 300, ...
                'tMax should be the latest endTime');
        end

        function testFilterSensors(testCase)
            evts = struct('startTime', {10, 20, 30}, ...
                          'endTime',   {15, 25, 35}, ...
                          'label',     {'Pump-101', 'Valve-202', 'Pump-101'}, ...
                          'color',     {[1 0 0], [0 1 0], [0 0 1]});
            w = EventTimelineWidget('Title', 'Filtered', ...
                'Events', evts, 'FilterSensors', {{'Pump-101'}});
            % getTimeRange calls resolveEvents which applies the filter
            [tMin, tMax] = w.getTimeRange();
            testCase.verifyEqual(tMin, 10, ...
                'Filtered tMin should come from Pump-101 events only');
            testCase.verifyEqual(tMax, 35, ...
                'Filtered tMax should come from Pump-101 events only');
        end

        function testToStruct(testCase)
            evts = struct('startTime', {1, 2}, ...
                          'endTime',   {3, 4}, ...
                          'label',     {'X', 'Y'}, ...
                          'color',     {[1 0 0], [0 1 0]});
            w = EventTimelineWidget('Title', 'Serialise', ...
                'Events', evts, 'Position', [1 1 24 3], ...
                'FilterSensors', {{'Sensor-A'}}, 'ColorSource', 'theme');
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'timeline');
            testCase.verifyEqual(s.title, 'Serialise');
            testCase.verifyEqual(s.filterSensors, {'Sensor-A'});
            testCase.verifyEqual(s.colorSource, 'theme');
            testCase.verifyEqual(s.source.type, 'static');
            testCase.verifyEqual(s.position, ...
                struct('col', 1, 'row', 1, 'width', 24, 'height', 3));
        end

        function testFromStruct(testCase)
            evts = struct('startTime', {5, 10}, ...
                          'endTime',   {8, 15}, ...
                          'label',     {'A', 'B'}, ...
                          'color',     {[1 0 0], [0 0 1]});
            w = EventTimelineWidget('Title', 'Round Trip', ...
                'Events', evts, 'Position', [2 3 20 4], ...
                'FilterSensors', {{'S1'}}, 'ColorSource', 'theme');
            s = w.toStruct();
            w2 = EventTimelineWidget.fromStruct(s);
            testCase.verifyEqual(w2.Title, 'Round Trip');
            testCase.verifyEqual(w2.Position, [2 3 20 4]);
            testCase.verifyEqual(w2.FilterSensors, {'S1'});
            testCase.verifyEqual(w2.ColorSource, 'theme');
        end

        function testGetType(testCase)
            w = EventTimelineWidget();
            testCase.verifyEqual(w.getType(), 'timeline');
        end
    end
end
