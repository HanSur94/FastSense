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

        function testRefreshWithSensor(testCase)
            %% Sensor-bound widget derives status from sensor data
            s = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degC');
            s.X = [1 2 3];
            s.Y = [70 71 72];
            s.ThresholdRules = {};

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
            s = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degC');
            s.X = [1 2 3];
            s.Y = [70 71 85];
            rule = ThresholdRule(struct(), 80, ...
                'Direction', 'upper', ...
                'Label', 'Hi Alarm', ...
                'Color', [0.9 0.2 0.2]);
            s.ThresholdRules = {rule};

            w = StatusWidget('Sensor', s);
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);

            testCase.verifyEqual(w.CurrentStatus, 'violation', ...
                'Status should be violation when threshold is exceeded');
            testCase.verifyEqual(w.CurrentColor, [0.9 0.2 0.2], ...
                'Color should come from the ThresholdRule.Color');

            % Upper threshold NOT violated: latest Y (75) < limit (80)
            s2 = Sensor('T-402', 'Name', 'Temp Safe');
            s2.X = [1 2 3];
            s2.Y = [70 71 75];
            rule2 = ThresholdRule(struct(), 80, ...
                'Direction', 'upper', 'Label', 'Hi');
            s2.ThresholdRules = {rule2};

            w2 = StatusWidget('Sensor', s2);
            hp2 = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w2.render(hp2);

            testCase.verifyEqual(w2.CurrentStatus, 'ok', ...
                'Status should be ok when value is within threshold');
            testCase.verifyEqual(w2.CurrentColor, theme.StatusOkColor, ...
                'Color should be StatusOkColor when ok');

            % Lower threshold violated: latest Y (5) < limit (10)
            s3 = Sensor('P-100', 'Name', 'Pressure');
            s3.X = [1 2 3];
            s3.Y = [20 15 5];
            ruleLo = ThresholdRule(struct(), 10, ...
                'Direction', 'lower', 'Label', 'Lo Warn');
            s3.ThresholdRules = {ruleLo};

            w3 = StatusWidget('Sensor', s3);
            hp3 = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w3.render(hp3);

            testCase.verifyEqual(w3.CurrentStatus, 'violation', ...
                'Lower threshold violation should also be detected');
            % No Color on rule + IsUpper=false => StatusWarnColor
            testCase.verifyEqual(w3.CurrentColor, theme.StatusWarnColor, ...
                'Lower violation without Color should use StatusWarnColor');
        end

        function testToStruct(testCase)
            %% Serialization includes type, title, position, and source
            s = Sensor('V-100', 'Name', 'Valve');
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
    end
end
