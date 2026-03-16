classdef TestEventTimelineWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            events = struct('startTime', {0, 100}, ...
                'endTime', {50, 200}, ...
                'label', {'High', 'Low'});
            w = EventTimelineWidget('Title', 'Alarms', 'Events', events);
            testCase.verifyEqual(w.Title, 'Alarms');
            testCase.verifyEqual(numel(w.Events), 2);
        end

        function testDefaultPosition(testCase)
            w = EventTimelineWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 24 2]);
        end

        function testGetType(testCase)
            w = EventTimelineWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'timeline');
        end

        function testToStructFromStruct(testCase)
            w = EventTimelineWidget('Title', 'Events', ...
                'Position', [1 1 12 2]);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'timeline');

            w2 = EventTimelineWidget.fromStruct(s);
            testCase.verifyEqual(w2.Title, 'Events');
        end

        function testRender(testCase)
            events = struct('startTime', {0, 100, 300}, ...
                'endTime', {50, 200, 400}, ...
                'label', {'High', 'Low', 'High'});
            w = EventTimelineWidget('Title', 'Timeline', 'Events', events);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyNotEmpty(w.hAxes);
            testCase.verifyEqual(numel(w.hBars), 3);
        end
    end
end
