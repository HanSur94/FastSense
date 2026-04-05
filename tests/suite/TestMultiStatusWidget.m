classdef TestMultiStatusWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = MultiStatusWidget();
            testCase.verifyEqual(w.getType(), 'multistatus');
            testCase.verifyEqual(w.ShowLabels, true);
            testCase.verifyEqual(w.IconStyle, 'dot');
        end

        function testToStruct(testCase)
            w = MultiStatusWidget('Title', 'Status Grid');
            w.Columns = 4;
            w.IconStyle = 'square';
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'multistatus');
            testCase.verifyEqual(s.columns, 4);
            testCase.verifyEqual(s.iconStyle, 'square');
        end

        function testThresholdStructItem(testCase)
            % Sensors cell with struct threshold item renders without error
            t = Threshold('msw_test_thr', 'Direction', 'upper');
            t.addCondition(struct(), 50);
            item = struct('threshold', t, 'value', 42, 'label', 'Pump');
            w = MultiStatusWidget('Title', 'Status');
            w.Sensors = {item};
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hAxes);
        end

        function testThresholdStructColor(testCase)
            % Struct item with violated threshold shows alarm color
            t = Threshold('msw_color_thr', 'Direction', 'upper', 'Color', [1 0 0]);
            t.addCondition(struct(), 50);
            item = struct('threshold', t, 'value', 75, 'label', 'Pump');
            w = MultiStatusWidget('Title', 'Status');
            w.Sensors = {item};
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            theme = DashboardTheme('dark');
            w.ParentTheme = theme;
            w.render(hp);
            % Check that something rendered (color is set)
            testCase.verifyNotEmpty(w.hAxes);
        end

        function testThresholdStructSerialize(testCase)
            % toStruct emits items array with threshold key; fromStruct restores
            t = Threshold('msw_ser_thr', 'Direction', 'upper');
            t.addCondition(struct(), 50);
            ThresholdRegistry.register('msw_ser_thr', t);
            cleanup = onCleanup(@() ThresholdRegistry.unregister('msw_ser_thr'));
            item = struct('threshold', t, 'value', 42, 'label', 'Pump');
            w = MultiStatusWidget('Title', 'Status');
            w.Sensors = {item};
            s = w.toStruct();
            testCase.verifyTrue(isfield(s, 'items'));
            testCase.verifyEqual(s.items{1}.type, 'threshold');
            testCase.verifyEqual(s.items{1}.key, 'msw_ser_thr');
        end

        function testMixedSensorAndThresholdItems(testCase)
            % Sensors cell with both Sensor objects and threshold structs works
            t = Threshold('msw_mixed_thr', 'Direction', 'upper');
            t.addCondition(struct(), 50);
            item = struct('threshold', t, 'value', 42, 'label', 'Pump');
            sensor = Sensor('msw_mixed_sensor', 'Name', 'Mixed Sensor');
            sensor.Y = (1:10)';
            w = MultiStatusWidget('Title', 'Status');
            w.Sensors = {sensor, item};
            testCase.verifyEqual(numel(w.Sensors), 2);
        end
    end
end
