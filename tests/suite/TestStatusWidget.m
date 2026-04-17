classdef TestStatusWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            %% Default properties after construction with Title only
            w = StatusWidget('Title', 'Pump 1');
            testCase.verifyEqual(w.Title, 'Pump 1');
            testCase.verifyEmpty(w.StatusFcn, ...
                'StatusFcn should be empty by default');
            testCase.verifyEqual(w.StaticStatus, '', ...
                'StaticStatus should be empty string by default');
            testCase.verifyEmpty(w.Sensor, ...
                'Sensor should be empty by default');
            testCase.verifyEqual(w.CurrentStatus, '', ...
                'CurrentStatus should be empty string by default');
            testCase.verifyEqual(w.CurrentColor, [0.5 0.5 0.5], ...
                'CurrentColor should be grey by default');
        end

        function testDefaultPosition(testCase)
            %% StatusWidget overrides default position to [1 1 4 1]
            w = StatusWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 4 1], ...
                'StatusWidget should default to compact [1 1 4 1]');
        end

        function testRender(testCase)
            %% Renders inside an invisible figure without error
            w = StatusWidget('Title', 'Motor', 'StatusFcn', @() 'ok');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            testCase.verifyWarningFree(@() w.render(hp));
            testCase.verifyNotEmpty(w.hPanel, ...
                'hPanel should be set after render');
        end

        function testRefreshStaticStatus(testCase)
            %% StaticStatus drives CurrentStatus and color
            theme = DashboardTheme();

            w = StatusWidget('Title', 'Valve', 'StaticStatus', 'ok');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentStatus, 'ok');
            testCase.verifyEqual(w.CurrentColor, theme.StatusOkColor, ...
                'ok status should produce StatusOkColor');

            w2 = StatusWidget('Title', 'Valve', 'StaticStatus', 'warning');
            hp2 = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w2.render(hp2);
            testCase.verifyEqual(w2.CurrentStatus, 'warning');
            testCase.verifyEqual(w2.CurrentColor, theme.StatusWarnColor, ...
                'warning status should produce StatusWarnColor');

            w3 = StatusWidget('Title', 'Valve', 'StaticStatus', 'alarm');
            hp3 = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w3.render(hp3);
            testCase.verifyEqual(w3.CurrentStatus, 'alarm');
            testCase.verifyEqual(w3.CurrentColor, theme.StatusAlarmColor, ...
                'alarm status should produce StatusAlarmColor');
        end

        function testRefreshWithStatusFcn(testCase)
            %% StatusFcn callback drives status updates
            status = containers.Map('KeyType', 'char', 'ValueType', 'char');
            status('val') = 'ok';

            w = StatusWidget('Title', 'Motor', ...
                'StatusFcn', @() status('val'));
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentStatus, 'ok');

            % Change the callback return value and refresh
            status('val') = 'alarm';
            w.refresh();
            testCase.verifyEqual(w.CurrentStatus, 'alarm', ...
                'refresh should pick up new StatusFcn return value');
        end

        function testRefreshWithTag(testCase)
            %% Sensor-bound widget derives status from sensor data
            s = SensorTag('T-401', 'Name', 'Temperature', 'Units', 'degC');
            s.updateData([1 2 3], [70 71 72]);

            w = StatusWidget('Sensor', s);
            testCase.verifyEqual(w.Title, 'Temperature', ...
                'Title should default to Sensor.Name');

            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentStatus, 'ok', ...
                'No threshold rules means status should be ok');
        end

        function testDeriveStatusFromSensorWithThresholds(testCase)
            %% Threshold violation detection via sensor binding
            theme = DashboardTheme();

            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));

            % Upper threshold violated: latest Y (85) > limit (80)
            s = SensorTag('T-401', 'Name', 'Temperature', 'Units', 'degC');
            s.updateData([1 2 3], [70 71 85]);
            t1 = Threshold('T401_hi', 'Name', 'Hi Alarm', ...
                'Direction', 'upper', 'Color', [0.9 0.2 0.2]);
            t1.addCondition(struct(), 80);
            s.addThreshold(t1);

            w = StatusWidget('Sensor', s);
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);

            testCase.verifyEqual(w.CurrentStatus, 'violation', ...
                'Status should be violation when threshold is exceeded');
            testCase.verifyEqual(w.CurrentColor, [0.9 0.2 0.2], ...
                'Color should come from the Threshold.Color');

            % Upper threshold NOT violated: latest Y (75) < limit (80)
            s2 = SensorTag('T-402', 'Name', 'Temp Safe');
            s2.updateData([1 2 3], [70 71 75]);
            t2 = Threshold('T402_hi', 'Name', 'Hi', 'Direction', 'upper');
            t2.addCondition(struct(), 80);
            s2.addThreshold(t2);

            w2 = StatusWidget('Sensor', s2);
            hp2 = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w2.render(hp2);

            testCase.verifyEqual(w2.CurrentStatus, 'ok', ...
                'Status should be ok when value is within threshold');
            testCase.verifyEqual(w2.CurrentColor, theme.StatusOkColor, ...
                'Color should be StatusOkColor when ok');

            % Lower threshold violated: latest Y (5) < limit (10)
            s3 = SensorTag('P-100', 'Name', 'Pressure');
            s3.updateData([1 2 3], [20 15 5]);
            t3 = Threshold('P100_lo', 'Name', 'Lo Warn', 'Direction', 'lower');
            t3.addCondition(struct(), 10);
            s3.addThreshold(t3);

            w3 = StatusWidget('Sensor', s3);
            hp3 = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w3.render(hp3);

            testCase.verifyEqual(w3.CurrentStatus, 'violation', ...
                'Lower threshold violation should also be detected');
            % No Color on threshold + IsUpper=false => StatusWarnColor
            testCase.verifyEqual(w3.CurrentColor, theme.StatusWarnColor, ...
                'Lower violation without Color should use StatusWarnColor');
        end

        function testToStruct(testCase)
            %% Serialization includes type, title, position, and source
            s = SensorTag('V-100', 'Name', 'Valve');
            w = StatusWidget('Sensor', s, ...
                'Description', 'Main valve status');
            st = w.toStruct();

            testCase.verifyEqual(st.type, 'status');
            testCase.verifyEqual(st.title, 'Valve');
            testCase.verifyEqual(st.description, 'Main valve status');
            testCase.verifyEqual(st.position, ...
                struct('col', 1, 'row', 1, 'width', 4, 'height', 1));
            testCase.verifyEqual(st.source.type, 'sensor');
            testCase.verifyEqual(st.source.name, 'V-100');
        end

        function testToStructWithStaticStatus(testCase)
            %% Static status serializes as source.type='static'
            w = StatusWidget('Title', 'Beacon', 'StaticStatus', 'warning');
            st = w.toStruct();

            testCase.verifyEqual(st.type, 'status');
            testCase.verifyEqual(st.title, 'Beacon');
            testCase.verifyTrue(isfield(st, 'source'), ...
                'toStruct should include source for StaticStatus');
            testCase.verifyEqual(st.source.type, 'static');
            testCase.verifyEqual(st.source.value, 'warning');
        end

        function testFromStruct(testCase)
            %% Deserialization round-trip preserves key fields
            w1 = StatusWidget('Title', 'Pump', ...
                'StaticStatus', 'ok', ...
                'Description', 'Pump status', ...
                'Position', [2 3 5 2]);
            st = w1.toStruct();

            w2 = StatusWidget.fromStruct(st);
            testCase.verifyEqual(w2.Title, 'Pump');
            testCase.verifyEqual(w2.Description, 'Pump status');
            testCase.verifyEqual(w2.Position, [2 3 5 2]);
            testCase.verifyEqual(w2.StaticStatus, 'ok');

            % Verify toStruct on the reconstructed widget matches
            st2 = w2.toStruct();
            testCase.verifyEqual(st2.title, st.title);
            testCase.verifyEqual(st2.position, st.position);
            testCase.verifyEqual(st2.source, st.source);
        end

        function testGetType(testCase)
            %% getType returns 'status'
            w = StatusWidget();
            testCase.verifyEqual(w.getType(), 'status');
            testCase.verifyEqual(w.Type, 'status', ...
                'Dependent Type property should also return status');
        end

        % --- NEW TESTS FOR THRESHOLD BINDING ---

        function testConstructorThresholdBinding(testCase)
            %% StatusWidget stores Threshold and Value when passed via constructor
            t = Threshold('test_hi', 'Name', 'Hi', 'Direction', 'upper');
            t.addCondition(struct(), 80);
            w = StatusWidget('Title', 'T', 'Threshold', t, 'Value', 42);
            testCase.verifyEqual(w.Threshold, t, ...
                'Threshold property should store the Threshold object');
            testCase.verifyEqual(w.Value, 42, ...
                'Value property should store the scalar value');
        end

        function testThresholdKeyResolution(testCase)
            %% Threshold string key is resolved via ThresholdRegistry
            TagRegistry.clear();
            t = Threshold('temp_hh', 'Name', 'Hi Hi', 'Direction', 'upper');
            t.addCondition(struct(), 100);
            TagRegistry.register('temp_hh', t);
            testCase.addTeardown(@() TagRegistry.clear());

            w = StatusWidget('Title', 'T', 'Threshold', 'temp_hh', 'Value', 50);
            testCase.verifyEqual(w.Threshold, t, ...
                'String key should resolve to registered Threshold object');
        end

        function testMutualExclusivity(testCase)
            %% Setting Threshold clears Sensor; widget with both has Threshold, Sensor cleared
            s = SensorTag('T-401', 'Name', 'Temperature');
            % TODO: s.X = [1]; s.Y = [70]; (needs manual fix)
            t = Threshold('temp_hi', 'Name', 'Hi', 'Direction', 'upper');
            t.addCondition(struct(), 80);

            w = StatusWidget('Sensor', s, 'Threshold', t, 'Value', 85);
            testCase.verifyEmpty(w.Sensor, ...
                'Sensor should be cleared when Threshold is set');
            testCase.verifyEqual(w.Threshold, t, ...
                'Threshold should be set');
        end

        function testDeriveStatusFromThreshold(testCase)
            %% Value above upper threshold -> violation + alarm color; below -> ok
            theme = DashboardTheme();
            t = Threshold('test_hi', 'Name', 'Hi Alarm', 'Direction', 'upper');
            t.addCondition(struct(), 80);

            % Violation: value 85 > threshold 80
            w = StatusWidget('Title', 'T', 'Threshold', t, 'Value', 85);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentStatus, 'violation', ...
                'Value above upper threshold should give violation status');
            testCase.verifyEqual(w.CurrentColor, theme.StatusAlarmColor, ...
                'Upper violation without Color should give StatusAlarmColor');

            % OK: value 70 < threshold 80
            w2 = StatusWidget('Title', 'T', 'Threshold', t, 'Value', 70);
            hp2 = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w2.render(hp2);
            testCase.verifyEqual(w2.CurrentStatus, 'ok', ...
                'Value below upper threshold should give ok status');
            testCase.verifyEqual(w2.CurrentColor, theme.StatusOkColor, ...
                'OK status should give StatusOkColor');
        end

        function testThresholdPathPriority(testCase)
            %% When both Threshold and StatusFcn are set, Threshold path wins
            t = Threshold('test_hi', 'Name', 'Hi', 'Direction', 'upper');
            t.addCondition(struct(), 80);

            w = StatusWidget('Title', 'T', ...
                'Threshold', t, 'Value', 85, ...
                'StatusFcn', @() 'ok');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentStatus, 'violation', ...
                'Threshold path should take priority over StatusFcn');
        end

        function testValueFcnLiveTick(testCase)
            %% ValueFcn is called on each refresh() and CurrentStatus updates
            t = Threshold('test_hi', 'Name', 'Hi', 'Direction', 'upper');
            t.addCondition(struct(), 80);

            val = containers.Map('KeyType', 'char', 'ValueType', 'double');
            val('v') = 70;

            w = StatusWidget('Title', 'T', ...
                'Threshold', t, 'ValueFcn', @() val('v'));
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentStatus, 'ok', ...
                'Initial value 70 < 80 should be ok');

            % Simulate value going above threshold
            val('v') = 90;
            w.refresh();
            testCase.verifyEqual(w.CurrentStatus, 'violation', ...
                'After refresh with value 90 > 80 should be violation');
        end

        function testSerializeThresholdRoundTrip(testCase)
            %% toStruct produces source.type='threshold' + source.key; fromStruct restores
            TagRegistry.clear();
            t = Threshold('press_hi', 'Name', 'Hi', 'Direction', 'upper');
            t.addCondition(struct(), 90);
            TagRegistry.register('press_hi', t);
            testCase.addTeardown(@() TagRegistry.clear());

            w = StatusWidget('Title', 'Pressure', ...
                'Threshold', t, 'Value', 75);
            st = w.toStruct();

            testCase.verifyTrue(isfield(st, 'source'), ...
                'toStruct should include source field');
            testCase.verifyEqual(st.source.type, 'threshold', ...
                'source.type should be ''threshold''');
            testCase.verifyEqual(st.source.key, 'press_hi', ...
                'source.key should match threshold key');

            % Round-trip via fromStruct
            w2 = StatusWidget.fromStruct(st);
            testCase.verifyEqual(w2.Threshold, t, ...
                'fromStruct should restore Threshold from registry');
            testCase.verifyEqual(w2.Value, 75, ...
                'fromStruct should restore Value');
        end

        function testThresholdValueLabel(testCase)
            %% Label shows "Title: value" format when Threshold path is active
            t = Threshold('test_hi', 'Name', 'Hi', 'Direction', 'upper');
            t.addCondition(struct(), 80);

            w = StatusWidget('Title', 'Temp', 'Threshold', t, 'Value', 72.5);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);

            % Check that the label text includes the value
            labelStr = get(w.hLabelText, 'String');
            testCase.verifyTrue(~isempty(labelStr), ...
                'Label should not be empty');
            testCase.verifyTrue(~isempty(strfind(labelStr, '72.5')) || ...
                ~isempty(strfind(labelStr, '72')), ...
                'Label should contain numeric value');
        end

        function testLowerThresholdViolation(testCase)
            %% Value below lower threshold -> violation + warn color
            theme = DashboardTheme();
            t = Threshold('test_lo', 'Name', 'Lo Warn', 'Direction', 'lower');
            t.addCondition(struct(), 10);

            w = StatusWidget('Title', 'T', 'Threshold', t, 'Value', 5);
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentStatus, 'violation', ...
                'Value below lower threshold should give violation');
            testCase.verifyEqual(w.CurrentColor, theme.StatusWarnColor, ...
                'Lower violation without Color should use StatusWarnColor');
        end
    end
end
