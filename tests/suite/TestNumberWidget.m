classdef TestNumberWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = NumberWidget('Title', 'Current Temp', ...
                'ValueFcn', @() 72.5);
            testCase.verifyEqual(w.Title, 'Current Temp');
            testCase.verifyTrue(isa(w.ValueFcn, 'function_handle'));
        end

        function testDefaultPosition(testCase)
            w = NumberWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 6 1]);
        end

        function testGetType(testCase)
            w = NumberWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'number');
        end

        function testToStruct(testCase)
            w = NumberWidget('Title', 'Pressure', ...
                'ValueFcn', @() 50, ...
                'Units', 'bar', ...
                'Position', [7 1 6 1]);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'number');
            testCase.verifyEqual(s.title, 'Pressure');
            testCase.verifyEqual(s.units, 'bar');
            testCase.verifyTrue(isfield(s, 'source'));
            testCase.verifyEqual(s.source.type, 'callback');
        end

        function testFromStruct(testCase)
            s = struct();
            s.type = 'number';
            s.title = 'RPM';
            s.position = struct('col', 1, 'row', 1, 'width', 6, 'height', 1);
            s.units = 'rpm';
            s.source = struct('type', 'static', 'value', 1500);
            w = NumberWidget.fromStruct(s);
            testCase.verifyEqual(w.Title, 'RPM');
            testCase.verifyEqual(w.Units, 'rpm');
            testCase.verifyEqual(w.Position, [1 1 6 1]);
        end

        function testRenderCreatesGraphics(testCase)
            w = NumberWidget('Title', 'Temp', 'ValueFcn', @() 72.5, 'Units', 'degC');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            % Should have created text objects inside the panel
            children = allchild(hp);
            testCase.verifyGreaterThanOrEqual(numel(children), 1);
        end

        function testRefreshUpdatesValue(testCase)
            counter = containers.Map('KeyType','char','ValueType','double');
            counter('val') = 0;
            w = NumberWidget('Title', 'Counter', ...
                'ValueFcn', @() counter('val'));
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            counter('val') = 42;
            w.refresh();
            % Verify the value text was updated
            testCase.verifyEqual(w.CurrentValue, 42);
        end

        function testStructValueBinding(testCase)
            w = NumberWidget('Title', 'Temp', ...
                'ValueFcn', @() struct('value', 72.5, 'unit', 'F', 'trend', 'up'));
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 72.5);
        end

        function testSensorBinding(testCase)
            s = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degC');
            s.X = [1 2 3 4 5];
            s.Y = [70 71 72 73 74];
            w = NumberWidget('Sensor', s);
            testCase.verifyEqual(w.Title, 'Temperature');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 74);
            testCase.verifyEqual(w.Units, 'degC');
        end

        function testSensorTrend(testCase)
            s = Sensor('T-401', 'Name', 'Temperature');
            s.X = [1 2 3 4 5];
            s.Y = [70 71 72 73 74]; % rising
            w = NumberWidget('SensorObj', s);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentTrend, 'up');
        end
    end
end
