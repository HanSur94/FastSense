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
            testCase.verifyEqual(st.source.type, 'tag');
            testCase.verifyEqual(st.source.key, 'V-100');
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
