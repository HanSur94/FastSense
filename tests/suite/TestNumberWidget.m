classdef TestNumberWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = NumberWidget('Title', 'Current Temp', ...
                'ValueFcn', @() 72.5, 'Units', 'degC', 'Format', '%.2f');
            testCase.verifyEqual(w.Title, 'Current Temp');
            testCase.verifyTrue(isa(w.ValueFcn, 'function_handle'));
            testCase.verifyEqual(w.Units, 'degC');
            testCase.verifyEqual(w.Format, '%.2f');
            testCase.verifyEmpty(w.StaticValue);
            testCase.verifyEmpty(w.Sensor);
        end

        function testConstructionWithSensor(testCase)
            s = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degC');
            s.X = [1 2 3];
            s.Y = [70 71 72];
            w = NumberWidget('Sensor', s);
            testCase.verifyEqual(w.Title, 'Temperature', ...
                'Title should auto-derive from Sensor.Name');
            testCase.verifyEqual(w.Units, 'degC', ...
                'Units should auto-derive from Sensor.Units');
        end

        function testDefaultPosition(testCase)
            w = NumberWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 6 1], ...
                'NumberWidget default position should be [1 1 6 1], not the base [1 1 6 2]');
        end

        function testRender(testCase)
            w = NumberWidget('Title', 'Temp', ...
                'ValueFcn', @() 72.5, 'Units', 'degC');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            testCase.verifyWarningFree(@() w.render(hp));
            children = allchild(hp);
            testCase.verifyGreaterThanOrEqual(numel(children), 4, ...
                'render should create at least 4 uicontrol children (title, value, trend, unit)');
        end

        function testRefreshStaticValue(testCase)
            w = NumberWidget('Title', 'Static', 'StaticValue', 99);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 99);
            % Update static value and refresh
            w.StaticValue = 123;
            w.refresh();
            testCase.verifyEqual(w.CurrentValue, 123);
        end

        function testRefreshWithValueFcn(testCase)
            counter = containers.Map('KeyType', 'char', 'ValueType', 'double');
            counter('val') = 10;
            w = NumberWidget('Title', 'Counter', ...
                'ValueFcn', @() counter('val'));
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 10);
            counter('val') = 42;
            w.refresh();
            testCase.verifyEqual(w.CurrentValue, 42);
        end

        function testRefreshWithSensor(testCase)
            s = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degC');
            s.X = [1 2 3 4 5];
            s.Y = [70 71 72 73 74];
            w = NumberWidget('Sensor', s);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 74, ...
                'refresh should set CurrentValue to Sensor.Y(end)');
            testCase.verifyEqual(w.Units, 'degC');
        end

        function testComputeTrend(testCase)
            % Rising data -> 'up'
            s1 = Sensor('rising', 'Name', 'Rising');
            s1.X = 1:20;
            s1.Y = linspace(10, 30, 20);
            w1 = NumberWidget('Sensor', s1);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp1 = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w1.render(hp1);
            testCase.verifyEqual(w1.CurrentTrend, 'up');

            % Falling data -> 'down'
            s2 = Sensor('falling', 'Name', 'Falling');
            s2.X = 1:20;
            s2.Y = linspace(30, 10, 20);
            w2 = NumberWidget('Sensor', s2);
            hp2 = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w2.render(hp2);
            testCase.verifyEqual(w2.CurrentTrend, 'down');

            % Flat data -> 'flat'
            s3 = Sensor('flat', 'Name', 'Flat');
            s3.X = 1:20;
            s3.Y = 50 * ones(1, 20);
            % Need some range for threshold calc; add tiny variance at edges
            s3.Y(1) = 49; s3.Y(end) = 51;
            w3 = NumberWidget('Sensor', s3);
            hp3 = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w3.render(hp3);
            testCase.verifyTrue(ismember(w3.CurrentTrend, {'flat', ''}), ...
                'Flat data should produce flat or empty trend');
        end

        function testToStruct(testCase)
            w = NumberWidget('Title', 'Pressure', ...
                'ValueFcn', @() 50, ...
                'Units', 'bar', ...
                'Format', '%.2f', ...
                'Position', [7 1 6 1]);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'number');
            testCase.verifyEqual(s.title, 'Pressure');
            testCase.verifyEqual(s.units, 'bar');
            testCase.verifyEqual(s.format, '%.2f');
            testCase.verifyTrue(isfield(s, 'source'));
            testCase.verifyEqual(s.source.type, 'callback');
        end

        function testToStructWithSensor(testCase)
            s = Sensor('P-201', 'Name', 'Pressure', 'Units', 'bar');
            s.X = [1 2 3];
            s.Y = [40 50 60];
            w = NumberWidget('Sensor', s);
            st = w.toStruct();
            testCase.verifyEqual(st.type, 'number');
            testCase.verifyTrue(isfield(st, 'source'));
            testCase.verifyEqual(st.source.type, 'sensor');
            testCase.verifyEqual(st.source.name, 'P-201');
            testCase.verifyEqual(st.units, 'bar');
        end

        function testFromStruct(testCase)
            s = struct();
            s.type = 'number';
            s.title = 'RPM';
            s.description = 'Engine speed';
            s.position = struct('col', 2, 'row', 3, 'width', 4, 'height', 1);
            s.units = 'rpm';
            s.format = '%.0f';
            s.source = struct('type', 'static', 'value', 1500);
            w = NumberWidget.fromStruct(s);
            testCase.verifyEqual(w.Title, 'RPM');
            testCase.verifyEqual(w.Description, 'Engine speed');
            testCase.verifyEqual(w.Position, [2 3 4 1]);
            testCase.verifyEqual(w.Units, 'rpm');
            testCase.verifyEqual(w.Format, '%.0f');
            testCase.verifyEqual(w.StaticValue, 1500);
            % Round-trip: toStruct then fromStruct
            s2 = w.toStruct();
            w2 = NumberWidget.fromStruct(s2);
            testCase.verifyEqual(w2.Title, w.Title);
            testCase.verifyEqual(w2.Units, w.Units);
            testCase.verifyEqual(w2.Format, w.Format);
            testCase.verifyEqual(w2.Position, w.Position);
        end

        function testGetType(testCase)
            w = NumberWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'number');
            testCase.verifyEqual(w.Type, 'number', ...
                'Dependent Type property should also return number');
        end
    end
end
