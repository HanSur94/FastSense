classdef TestGaugeWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = GaugeWidget('Title', 'Pressure', ...
                'ValueFcn', @() 50, 'Units', 'bar');
            testCase.verifyEqual(w.Title, 'Pressure');
            testCase.verifyEqual(w.Range, [0 100], ...
                'Default Range should be [0 100] when no Sensor is bound');
            testCase.verifyEqual(w.Style, 'arc', ...
                'Default Style should be ''arc''');
            testCase.verifyEqual(w.Units, 'bar');
            testCase.verifyTrue(isa(w.ValueFcn, 'function_handle'));
        end

        function testDefaultPosition(testCase)
            w = GaugeWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 6 4], ...
                'GaugeWidget should override base default to [1 1 6 4]');
        end

        function testFourStyles(testCase)
            styles = {'arc', 'donut', 'bar', 'thermometer'};
            for i = 1:numel(styles)
                w = GaugeWidget('Title', styles{i}, ...
                    'StaticValue', 50, 'Range', [0 100], ...
                    'Style', styles{i});
                hFig = figure('Visible', 'off');
                testCase.addTeardown(@() close(hFig));
                hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
                w.render(hp);
                testCase.verifyEqual(w.Style, styles{i});
                testCase.verifyEqual(w.CurrentValue, 50);
            end
        end

        function testRenderArc(testCase)
            w = GaugeWidget('Title', 'Arc', 'StaticValue', 60, ...
                'Range', [0 100], 'Style', 'arc');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 60);
            children = allchild(hp);
            testCase.verifyGreaterThanOrEqual(numel(children), 1, ...
                'Arc render should create at least one child in the panel');
        end

        function testRenderDonut(testCase)
            w = GaugeWidget('Title', 'Donut', 'StaticValue', 65, ...
                'Range', [0 100], 'Units', '%', 'Style', 'donut');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 65);
            testCase.verifyEqual(w.Style, 'donut');
        end

        function testRenderBar(testCase)
            w = GaugeWidget('Title', 'Bar', 'StaticValue', 42, ...
                'Range', [0 100], 'Style', 'bar');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 42);
            testCase.verifyEqual(w.Style, 'bar');
        end

        function testRenderThermometer(testCase)
            w = GaugeWidget('Title', 'Thermo', 'StaticValue', 72, ...
                'Range', [0 100], 'Units', 'degC', 'Style', 'thermometer');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 72);
            testCase.verifyEqual(w.Style, 'thermometer');
        end

        function testRefreshStaticValue(testCase)
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

        function testRefreshWithValueFcn(testCase)
            counter = containers.Map('KeyType', 'char', 'ValueType', 'double');
            counter('val') = 10;
            w = GaugeWidget('Title', 'Callback', ...
                'ValueFcn', @() counter('val'), 'Range', [0 100]);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 10);
            counter('val') = 90;
            w.refresh();
            testCase.verifyEqual(w.CurrentValue, 90);
        end

        function testRefreshWithTag(testCase)
            s = SensorTag('P-201', 'Name', 'Pressure', 'Units', 'bar');
            s.updateData([1 2 3], [40 50 60]);
            [s_x_, s_y_] = s.getXY();
            w = GaugeWidget('Sensor', s);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 60, ...
                'Sensor-driven gauge should read Y(end)');
            % Append new data and refresh
            s_y_ = [40 50 60 85];
            % TODO: s_x_ = [1 2 3 4]; (needs manual fix)
            w.refresh();
            testCase.verifyEqual(w.CurrentValue, 85);
        end

        function testUnitsDeriveFromTag(testCase)
            s = SensorTag('T-101', 'Name', 'Temperature', 'Units', 'degC');
            s.updateData([1 2 3], [20 25 30]);
            w = GaugeWidget('Sensor', s);
            testCase.verifyEqual(w.Units, 'degC', ...
                'Units should auto-derive from Sensor.Units');
        end

        function testToStruct(testCase)
            w = GaugeWidget('Title', 'RPM', ...
                'StaticValue', 3000, ...
                'Range', [0 6000], 'Units', 'rpm', 'Style', 'donut');
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'gauge');
            testCase.verifyEqual(s.title, 'RPM');
            testCase.verifyEqual(s.range, [0 6000]);
            testCase.verifyEqual(s.units, 'rpm');
            testCase.verifyEqual(s.style, 'donut');
            testCase.verifyTrue(isfield(s, 'source'), ...
                'toStruct should include source for StaticValue');
            testCase.verifyEqual(s.source.type, 'static');
            testCase.verifyEqual(s.source.value, 3000);
        end

        function testFromStruct(testCase)
            s = struct();
            s.type = 'gauge';
            s.title = 'RPM';
            s.description = '';
            s.position = struct('col', 2, 'row', 3, 'width', 4, 'height', 5);
            s.range = [0 6000];
            s.units = 'rpm';
            s.style = 'donut';
            s.source = struct('type', 'static', 'value', 3000);
            w = GaugeWidget.fromStruct(s);
            testCase.verifyEqual(w.Title, 'RPM');
            testCase.verifyEqual(w.Position, [2 3 4 5]);
            testCase.verifyEqual(w.Range, [0 6000]);
            testCase.verifyEqual(w.Units, 'rpm');
            testCase.verifyEqual(w.Style, 'donut');
            testCase.verifyEqual(w.StaticValue, 3000);
            % Round-trip: serialize back and compare
            s2 = w.toStruct();
            testCase.verifyEqual(s2.range, s.range);
            testCase.verifyEqual(s2.units, s.units);
            testCase.verifyEqual(s2.style, s.style);
        end

        function testGetType(testCase)
            w = GaugeWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'gauge');
            testCase.verifyEqual(w.Type, 'gauge');
        end
    end
end
