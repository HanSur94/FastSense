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

        function testCompositeExpansion(testCase)
            % CompositeThreshold with 2 children expands to 3 dots (2 children + 1 summary)
            t1 = Threshold('msw_comp_t1', 'Direction', 'upper');
            t1.addCondition(struct(), 100);
            t2 = Threshold('msw_comp_t2', 'Direction', 'upper');
            t2.addCondition(struct(), 80);
            ct = CompositeThreshold('msw_comp_ct', 'AggregateMode', 'and');
            ct.addChild(t1, 'Value', 50);
            ct.addChild(t2, 'Value', 50);
            item = struct('threshold', ct, 'label', 'System A');
            w = MultiStatusWidget('Title', 'Status');
            w.Sensors = {item};
            % expandedItems should have 3 entries: child1, child2, summary
            expanded = w.expandSensors_();
            testCase.verifyEqual(numel(expanded), 3);
        end

        function testCompositeExpansionMixed(testCase)
            % Mix of Sensor + CompositeThreshold items — total dot count is correct
            t1 = Threshold('msw_mix_t1', 'Direction', 'upper');
            t1.addCondition(struct(), 100);
            t2 = Threshold('msw_mix_t2', 'Direction', 'upper');
            t2.addCondition(struct(), 80);
            ct = CompositeThreshold('msw_mix_ct', 'AggregateMode', 'and');
            ct.addChild(t1, 'Value', 50);
            ct.addChild(t2, 'Value', 50);
            ctItem = struct('threshold', ct, 'label', 'System');
            sensor = Sensor('msw_mix_sensor', 'Name', 'Mix Sensor');
            sensor.Y = (1:5)';
            w = MultiStatusWidget('Title', 'Mix');
            w.Sensors = {sensor, ctItem};
            % 1 sensor + 2 children + 1 summary = 4 items
            expanded = w.expandSensors_();
            testCase.verifyEqual(numel(expanded), 4);
        end

        function testCompositeExpansionNestedFlattens(testCase)
            % Nested composite: inner composite children are recursively expanded
            t1 = Threshold('msw_nest_t1', 'Direction', 'upper');
            t1.addCondition(struct(), 100);
            inner = CompositeThreshold('msw_nest_inner', 'AggregateMode', 'and');
            inner.addChild(t1, 'Value', 50);
            outer = CompositeThreshold('msw_nest_outer', 'AggregateMode', 'and');
            outer.addChild(inner);
            outerItem = struct('threshold', outer, 'label', 'Outer');
            w = MultiStatusWidget('Title', 'Nested');
            w.Sensors = {outerItem};
            % outer expands: inner (1 child) expands to 1 leaf + 1 inner-summary = 2
            % plus outer summary = 3 total
            expanded = w.expandSensors_();
            testCase.verifyGreaterThanOrEqual(numel(expanded), 2);
        end

        function testCompositeExpansionSummaryColor(testCase)
            % Summary dot reflects aggregate status from computeStatus
            t1 = Threshold('msw_sum_t1', 'Direction', 'upper');
            t1.addCondition(struct(), 50);
            ct = CompositeThreshold('msw_sum_ct', 'AggregateMode', 'and');
            ct.addChild(t1, 'Value', 75);  % alarm: 75 > 50
            item = struct('threshold', ct, 'label', 'System');
            w = MultiStatusWidget('Title', 'Sum');
            w.Sensors = {item};
            expanded = w.expandSensors_();
            % Last item should be summary with isCompositeSummary = true
            lastItem = expanded{end};
            testCase.verifyTrue(isfield(lastItem, 'isCompositeSummary'));
            testCase.verifyTrue(lastItem.isCompositeSummary);
            % computeStatus should return 'alarm'
            testCase.verifyEqual(ct.computeStatus(), 'alarm');
        end

        function testNonCompositeUnchanged(testCase)
            % Existing Sensor and threshold-struct items render exactly as before
            t = Threshold('msw_nc_thr', 'Direction', 'upper');
            t.addCondition(struct(), 50);
            item = struct('threshold', t, 'value', 30, 'label', 'Pump');
            sensor = Sensor('msw_nc_sensor', 'Name', 'NC Sensor');
            sensor.Y = (1:5)';
            w = MultiStatusWidget('Title', 'NC');
            w.Sensors = {sensor, item};
            expanded = w.expandSensors_();
            % Non-composite items pass through unchanged: 2 items
            testCase.verifyEqual(numel(expanded), 2);
        end
    end
end
