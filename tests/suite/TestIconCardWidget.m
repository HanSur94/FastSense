classdef TestIconCardWidget < matlab.unittest.TestCase
%TESTICONWIDGET Unit tests for IconCardWidget.
%
%   Tests cover construction, render, refresh guard, serialization
%   round-trip, and state-to-color mapping.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = IconCardWidget();
            testCase.verifyEqual(w.getType(), 'iconcard');
        end

        function testRenderNoError(testCase)
            w = IconCardWidget('Title', 'Test', 'StaticValue', 42);
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hPanel);
        end

        function testRefreshBeforeRender(testCase)
            w = IconCardWidget();
            % Should not error when called before render
            w.refresh();
            testCase.verifyTrue(true);
        end

        function testToStruct(testCase)
            w = IconCardWidget('Title', 'MyCard', 'StaticValue', 99);
            w.Position = [1 1 6 2];
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'iconcard');
            testCase.verifyEqual(s.title, 'MyCard');
        end

        function testFromStruct(testCase)
            s = struct();
            s.type = 'iconcard';
            s.title = 'FromStructTest';
            s.description = '';
            s.position = struct('col', 1, 'row', 1, 'width', 6, 'height', 2);
            s.source = struct('type', 'static', 'value', 55);
            w = IconCardWidget.fromStruct(s);
            testCase.verifyEqual(w.Title, 'FromStructTest');
            testCase.verifyEqual(w.StaticValue, 55);
        end

        function testStateColorOk(testCase)
            w = IconCardWidget('Title', 'Test', 'StaticValue', 42, 'StaticState', 'ok');
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            theme = DashboardTheme('dark');
            w.ParentTheme = theme;
            w.render(hp);
            faceColor = get(w.hIconShape, 'FaceColor');
            testCase.verifyEqual(faceColor, theme.StatusOkColor, 'AbsTol', 0.01);
        end

        function testStateColorWarn(testCase)
            w = IconCardWidget('Title', 'Test', 'StaticValue', 42, 'StaticState', 'warn');
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            theme = DashboardTheme('dark');
            w.ParentTheme = theme;
            w.render(hp);
            faceColor = get(w.hIconShape, 'FaceColor');
            testCase.verifyEqual(faceColor, theme.StatusWarnColor, 'AbsTol', 0.01);
        end

        function testStateColorAlarm(testCase)
            w = IconCardWidget('Title', 'Test', 'StaticValue', 42, 'StaticState', 'alarm');
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            theme = DashboardTheme('dark');
            w.ParentTheme = theme;
            w.render(hp);
            faceColor = get(w.hIconShape, 'FaceColor');
            testCase.verifyEqual(faceColor, theme.StatusAlarmColor, 'AbsTol', 0.01);
        end

        function testInfoColorInTheme(testCase)
            theme = DashboardTheme('dark');
            testCase.verifyTrue(isfield(theme, 'InfoColor'));
        end

        function testInfoColorAllPresets(testCase)
            presets = {'dark', 'light', 'industrial', 'scientific', 'ocean', 'default'};
            expected = [0.27 0.52 0.85];
            for i = 1:numel(presets)
                theme = DashboardTheme(presets{i});
                testCase.verifyTrue(isfield(theme, 'InfoColor'), ...
                    sprintf('InfoColor missing from preset: %s', presets{i}));
                testCase.verifyEqual(theme.InfoColor, expected, 'AbsTol', 0.01, ...
                    sprintf('InfoColor wrong value on preset: %s', presets{i}));
            end
        end

        function testStateColorInfo(testCase)
            w = IconCardWidget('Title', 'Test', 'StaticValue', 42, 'StaticState', 'info');
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            theme = DashboardTheme('dark');
            w.ParentTheme = theme;
            w.render(hp);
            faceColor = get(w.hIconShape, 'FaceColor');
            testCase.verifyEqual(faceColor, theme.InfoColor, 'AbsTol', 0.01);
        end

        function testStateColorInactive(testCase)
            w = IconCardWidget('Title', 'Test', 'StaticValue', 42, 'StaticState', 'inactive');
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            theme = DashboardTheme('dark');
            w.ParentTheme = theme;
            w.render(hp);
            faceColor = get(w.hIconShape, 'FaceColor');
            testCase.verifyEqual(faceColor, [0.5 0.5 0.5], 'AbsTol', 0.01);
        end
    end
end
