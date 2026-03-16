classdef TestGaugeWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = GaugeWidget('Title', 'Pressure', ...
                'ValueFcn', @() 50, 'Range', [0 100], 'Units', 'bar');
            testCase.verifyEqual(w.Title, 'Pressure');
            testCase.verifyEqual(w.Range, [0 100]);
            testCase.verifyEqual(w.Units, 'bar');
        end

        function testDefaultPosition(testCase)
            w = GaugeWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 6 2]);
        end

        function testGetType(testCase)
            w = GaugeWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'gauge');
        end

        function testToStructFromStruct(testCase)
            w = GaugeWidget('Title', 'RPM', ...
                'ValueFcn', @() 3000, 'Range', [0 6000], 'Units', 'rpm');
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'gauge');
            testCase.verifyEqual(s.range, [0 6000]);
            testCase.verifyEqual(s.units, 'rpm');

            w2 = GaugeWidget.fromStruct(s);
            testCase.verifyEqual(w2.Range, [0 6000]);
            testCase.verifyEqual(w2.Units, 'rpm');
        end

        function testRender(testCase)
            w = GaugeWidget('Title', 'Temp', ...
                'ValueFcn', @() 72, 'Range', [0 100], 'Units', char(176) + "C");
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 72);
        end

        function testRefreshUpdatesValue(testCase)
            w = GaugeWidget('Title', 'Gauge', ...
                'StaticValue', 25, 'Range', [0 100]);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 25);
            % Update static value and refresh
            w.StaticValue = 75;
            w.refresh();
            testCase.verifyEqual(w.CurrentValue, 75);
        end

        function testStaticValue(testCase)
            w = GaugeWidget('Title', 'Static', ...
                'StaticValue', 42, 'Range', [0 100]);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 42);
        end

        function testSensorBinding(testCase)
            s = Sensor('P-201', 'Name', 'Pressure', 'Units', 'bar');
            s.X = [1 2 3]; s.Y = [40 50 60];
            rule1 = ThresholdRule(struct(), 30, 'Direction', 'lower', 'Label', 'Lo', 'Color', [1 0.6 0]);
            rule2 = ThresholdRule(struct(), 80, 'Direction', 'upper', 'Label', 'Hi', 'Color', [1 0 0]);
            s.ThresholdRules = {rule1, rule2};
            w = GaugeWidget('SensorObj', s);
            testCase.verifyEqual(w.Title, 'Pressure');
            testCase.verifyEqual(w.Units, 'bar');
            testCase.verifyEqual(w.Range, [30 80]);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 60);
        end

        function testDonutStyle(testCase)
            w = GaugeWidget('Title', 'CPU', 'StaticValue', 65, ...
                'Range', [0 100], 'Units', '%', 'Style', 'donut');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 65);
            testCase.verifyEqual(w.Style, 'donut');
        end

        function testBarStyle(testCase)
            w = GaugeWidget('Title', 'Load', 'StaticValue', 42, ...
                'Range', [0 100], 'Style', 'bar');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 42);
        end

        function testThermometerStyle(testCase)
            w = GaugeWidget('Title', 'Temp', 'StaticValue', 72, ...
                'Range', [0 100], 'Units', 'degC', 'Style', 'thermometer');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 72);
        end

        function testStyleSerializationRoundTrip(testCase)
            w = GaugeWidget('Title', 'G', 'StaticValue', 50, ...
                'Range', [0 100], 'Style', 'donut');
            s = w.toStruct();
            testCase.verifyEqual(s.style, 'donut');
            w2 = GaugeWidget.fromStruct(s);
            testCase.verifyEqual(w2.Style, 'donut');
        end
    end
end
