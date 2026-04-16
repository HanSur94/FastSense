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

        function testRefreshWithSensor(testCase)
            s = Sensor('P-201', 'Name', 'Pressure', 'Units', 'bar');
            s.X = [1 2 3];
            s.Y = [40 50 60];
            w = GaugeWidget('Sensor', s);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentValue, 60, ...
                'Sensor-driven gauge should read Y(end)');
            % Append new data and refresh
            s.Y = [40 50 60 85];
            s.X = [1 2 3 4];
            w.refresh();
            testCase.verifyEqual(w.CurrentValue, 85);
        end

        function testRangeDeriveFromSensor(testCase)
            s = Sensor('P-201', 'Name', 'Pressure');
            s.X = [1 2 3];
            s.Y = [40 50 60];
            t1 = Threshold('P201_lo', 'Name', 'Lo', ...
                'Direction', 'lower', 'Color', [1 0.6 0]);
            t1.addCondition(struct(), 30);
            s.addThreshold(t1);
            t2 = Threshold('P201_hi', 'Name', 'Hi', ...
                'Direction', 'upper', 'Color', [1 0 0]);
            t2.addCondition(struct(), 80);
            s.addThreshold(t2);
            w = GaugeWidget('Sensor', s);
            testCase.verifyEqual(w.Range, [30 80], ...
                'Range should auto-derive from Threshold values');
        end

        function testUnitsDeriveFromSensor(testCase)
            s = Sensor('T-101', 'Name', 'Temperature', 'Units', 'degC');
            s.X = [1 2 3];
            s.Y = [20 25 30];
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

        % --- NEW TESTS FOR THRESHOLD BINDING ---

        function testConstructorThresholdBinding(testCase)
            %% GaugeWidget stores Threshold when passed via constructor
            t = Threshold('press_hi', 'Name', 'Hi', 'Direction', 'upper');
            t.addCondition(struct(), 80);
            w = GaugeWidget('Threshold', t, 'StaticValue', 50);
            testCase.verifyEqual(w.Threshold, t, ...
                'Threshold property should store the Threshold object');
            testCase.verifyEqual(w.StaticValue, 50, ...
                'StaticValue should be set');
        end

        function testThresholdRangeDerivation(testCase)
            %% Threshold with conditions at 30 and 80 -> Range auto-derives to [30, 80]
            t = Threshold('press_rng', 'Name', 'Range', 'Direction', 'upper');
            t.addCondition(struct(), 30);
            t.addCondition(struct(), 80);
            w = GaugeWidget('Threshold', t, 'StaticValue', 50);
            testCase.verifyEqual(w.Range, [30 80], ...
                'Range should auto-derive from Threshold condition values');
        end

        function testThresholdColorPath(testCase)
            %% Value above upper threshold -> alarm color in getValueColor
            theme = DashboardTheme();
            t = Threshold('press_hi', 'Name', 'Hi Alarm', ...
                'Direction', 'upper');
            t.addCondition(struct(), 80);

            % Violation: value 90 > threshold 80
            w = GaugeWidget('Threshold', t, 'StaticValue', 90, 'Range', [0 100]);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);

            % The gauge arc foreground color should be alarm color
            % We verify indirectly by checking the arc fill color
            arcFg = w.hArcFg;
            testCase.verifyTrue(ishandle(arcFg), ...
                'Arc foreground handle should be valid after render');
            arcColor = get(arcFg, 'FaceColor');
            testCase.verifyEqual(arcColor, theme.StatusAlarmColor, ...
                'Upper violation without Color should use StatusAlarmColor');
        end

        function testMutualExclusivity(testCase)
            %% Setting Threshold clears Sensor
            s = Sensor('P-201', 'Name', 'Pressure');
            s.X = [1]; s.Y = [50];
            t = Threshold('press_hi', 'Name', 'Hi', 'Direction', 'upper');
            t.addCondition(struct(), 80);

            w = GaugeWidget('Sensor', s, 'Threshold', t, 'StaticValue', 50);
            testCase.verifyEmpty(w.Sensor, ...
                'Sensor should be cleared when Threshold is set');
            testCase.verifyEqual(w.Threshold, t, ...
                'Threshold should be set');
        end

        function testSerializeThresholdRoundTrip(testCase)
            %% toStruct/fromStruct preserves threshold key
            ThresholdRegistry.clear();
            t = Threshold('press_hi', 'Name', 'Hi', 'Direction', 'upper');
            t.addCondition(struct(), 90);
            ThresholdRegistry.register('press_hi', t);
            testCase.addTeardown(@() ThresholdRegistry.clear());

            w = GaugeWidget('Title', 'Pressure', ...
                'Threshold', t, 'StaticValue', 70, 'Range', [0 100]);
            st = w.toStruct();

            testCase.verifyTrue(isfield(st, 'source'), ...
                'toStruct should include source field');
            testCase.verifyEqual(st.source.type, 'threshold', ...
                'source.type should be ''threshold''');
            testCase.verifyEqual(st.source.key, 'press_hi', ...
                'source.key should match threshold key');

            % Round-trip via fromStruct
            w2 = GaugeWidget.fromStruct(st);
            testCase.verifyEqual(w2.Threshold, t, ...
                'fromStruct should restore Threshold from registry');
        end

        function testThresholdWithValueFcn(testCase)
            %% ValueFcn + Threshold -> refresh uses ValueFcn value and Threshold color
            theme = DashboardTheme();
            t = Threshold('press_hi', 'Name', 'Hi', 'Direction', 'upper');
            t.addCondition(struct(), 80);

            val = containers.Map('KeyType', 'char', 'ValueType', 'double');
            val('v') = 90; % above threshold

            w = GaugeWidget('Title', 'Pressure', ...
                'Threshold', t, 'ValueFcn', @() val('v'), 'Range', [0 100]);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);

            testCase.verifyEqual(w.CurrentValue, 90, ...
                'CurrentValue should be set from ValueFcn');

            % Arc color should indicate violation
            arcColor = get(w.hArcFg, 'FaceColor');
            testCase.verifyEqual(arcColor, theme.StatusAlarmColor, ...
                'Alarm color should be used when value > threshold');

            % Now change value to below threshold and refresh
            val('v') = 60;
            w.refresh();
            testCase.verifyEqual(w.CurrentValue, 60, ...
                'CurrentValue should update after refresh');
            arcColor2 = get(w.hArcFg, 'FaceColor');
            testCase.verifyEqual(arcColor2, theme.StatusOkColor, ...
                'OK color should be used when value < threshold');
        end
    end
end
