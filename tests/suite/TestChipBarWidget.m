classdef TestChipBarWidget < matlab.unittest.TestCase
%TESTCHIPBARWIDGET Unit tests for ChipBarWidget.
%
%   Tests cover: construction, multi-chip render, single-axes constraint,
%   refresh guard, serialization round-trip, and color update.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = ChipBarWidget();
            testCase.verifyEqual(w.getType(), 'chipbar');
            testCase.verifyEmpty(w.Chips);
        end

        function testRenderThreeChips(testCase)
            w = ChipBarWidget();
            w.Chips = { ...
                struct('label', 'Pump',  'statusFcn', @() 'ok'), ...
                struct('label', 'Tank',  'statusFcn', @() 'warn'), ...
                struct('label', 'Fan',   'statusFcn', @() 'alarm') ...
            };

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);

            testCase.verifyEqual(numel(w.hChipCircles), 3);
        end

        function testSingleAxes(testCase)
            w = ChipBarWidget();
            w.Chips = { ...
                struct('label', 'A', 'statusFcn', @() 'ok'), ...
                struct('label', 'B', 'statusFcn', @() 'warn'), ...
                struct('label', 'C', 'statusFcn', @() 'alarm') ...
            };

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);

            nAxes = numel(findobj(w.hPanel, 'Type', 'axes'));
            testCase.verifyEqual(nAxes, 1);
        end

        function testRefreshBeforeRender(testCase)
            w = ChipBarWidget();
            % Should not error when called before render
            testCase.verifyWarningFree(@() w.refresh());
        end

        function testToStruct(testCase)
            w = ChipBarWidget();
            w.Chips = { ...
                struct('label', 'X', 'statusFcn', @() 'ok'), ...
                struct('label', 'Y', 'statusFcn', @() 'alarm') ...
            };
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'chipbar');
            testCase.verifyEqual(numel(s.chips), 2);
        end

        function testFromStruct(testCase)
            s = struct();
            s.type = 'chipbar';
            s.title = 'Health';
            s.description = '';
            s.position = struct('col', 1, 'row', 1, 'width', 6, 'height', 1);
            s.chips = { ...
                struct('label', 'Motor'), ...
                struct('label', 'Pump') ...
            };
            w2 = ChipBarWidget.fromStruct(s);
            testCase.verifyEqual(numel(w2.Chips), 2);
        end

        function testChipColorUpdate(testCase)
            % Use containers.Map (handle class) so statusFcn closure sees mutation
            stateMap = containers.Map({'s'}, {'ok'});
            w = ChipBarWidget();
            w.Chips = { struct('label', 'Sensor1', 'statusFcn', @() stateMap('s')) };

            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);

            theme = DashboardTheme('dark');
            okColor = theme.StatusOkColor;
            c = get(w.hChipCircles{1}, 'FaceColor');
            testCase.verifyEqual(c, okColor, 'AbsTol', 1e-9);

            % Change state to alarm and refresh
            stateMap('s') = 'alarm';
            w.refresh();
            alarmColor = theme.StatusAlarmColor;
            c2 = get(w.hChipCircles{1}, 'FaceColor');
            testCase.verifyEqual(c2, alarmColor, 'AbsTol', 1e-9);
        end

        function testChipThreshold(testCase)
            % chip struct with threshold + value fields resolves alarm color
            t = Threshold('cbw_thr_test', 'Direction', 'upper');
            t.addCondition(struct(), 50);
            chip = struct('label', 'Pump', 'threshold', t, 'value', 75);
            w = ChipBarWidget();
            w.Chips = {chip};
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            theme = DashboardTheme('dark');
            w.ParentTheme = theme;
            w.render(hp);
            % value 75 > threshold 50 -> alarm
            c = get(w.hChipCircles{1}, 'FaceColor');
            testCase.verifyEqual(c, theme.StatusAlarmColor, 'AbsTol', 0.01);
        end

        function testChipThresholdWithValueFcn(testCase)
            % chip with threshold + valueFcn resolves dynamically
            t = Threshold('cbw_valfcn_test', 'Direction', 'upper');
            t.addCondition(struct(), 50);
            val = 30;  % below threshold -> ok
            chip = struct('label', 'Tank', 'threshold', t, 'valueFcn', @() val);
            w = ChipBarWidget();
            w.Chips = {chip};
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            theme = DashboardTheme('dark');
            w.ParentTheme = theme;
            w.render(hp);
            % value 30 < threshold 50 -> ok
            c = get(w.hChipCircles{1}, 'FaceColor');
            testCase.verifyEqual(c, theme.StatusOkColor, 'AbsTol', 0.01);
        end

        function testChipThresholdSerialize(testCase)
            % toStruct emits chip threshold key; fromStruct restores
            t = Threshold('cbw_ser_test', 'Direction', 'upper');
            t.addCondition(struct(), 50);
            TagRegistry.register('cbw_ser_test', t);
            cleanup = onCleanup(@() TagRegistry.unregister('cbw_ser_test'));
            chip = struct('label', 'Fan', 'threshold', t, 'value', 40);
            w = ChipBarWidget('Title', 'Health');
            w.Chips = {chip};
            s = w.toStruct();
            testCase.verifyEqual(s.chips{1}.threshold, 'cbw_ser_test');
            testCase.verifyEqual(s.chips{1}.value, 40);
        end
    end
end
