classdef TestSparklineCardWidget < matlab.unittest.TestCase
%TESTSPARKLINECARDWIDGET Unit tests for SparklineCardWidget.
%
%   Tests cover: construction, rendering, sparkline axes, delta display
%   (positive and negative), flat data edge case, refresh guard, and
%   serialization round-trip.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            w = SparklineCardWidget();
            testCase.verifyEqual(w.getType(), 'sparkline');
        end

        function testRenderNoError(testCase)
            w = SparklineCardWidget('Title', 'Temp', 'StaticValue', 23.5, ...
                'SparkData', randn(1, 50) + 23);
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyNotEmpty(w.hPanel);
        end

        function testSparklineAxesExists(testCase)
            w = SparklineCardWidget('Title', 'Temp', 'StaticValue', 23.5, ...
                'SparkData', randn(1, 50) + 23);
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            testCase.verifyGreaterThanOrEqual( ...
                numel(findobj(hp, 'Type', 'axes')), 1);
        end

        function testDeltaPositive(testCase)
            % SparkData rising: last > first => positive delta
            sparkData = [1 2 3 4 5 6 7 8 9 10];
            w = SparklineCardWidget('StaticValue', 5, 'SparkData', sparkData);
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            w.refresh();
            deltaStr = get(w.hDeltaText, 'String');
            testCase.verifySubstring(deltaStr, '+');
            testCase.verifySubstring(deltaStr, char(9650));
        end

        function testDeltaNegative(testCase)
            % SparkData falling: last < first => negative delta
            sparkData = [10 9 8 7 6 5 4 3 2 1];
            w = SparklineCardWidget('StaticValue', 5, 'SparkData', sparkData);
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            w.render(hp);
            w.refresh();
            deltaStr = get(w.hDeltaText, 'String');
            testCase.verifySubstring(deltaStr, '-');
            testCase.verifySubstring(deltaStr, char(9660));
        end

        function testFlatData(testCase)
            % Flat sparkline (zero y-range) must not error
            w = SparklineCardWidget('StaticValue', 5, 'SparkData', ones(1, 50));
            fig = figure('Visible', 'off');
            cleanup = onCleanup(@() close(fig));
            hp = uipanel(fig, 'Position', [0 0 1 1]);
            w.ParentTheme = DashboardTheme('dark');
            testCase.verifyWarningFree(@() w.render(hp));
        end

        function testRefreshBeforeRender(testCase)
            % refresh() before render() must not error
            w = SparklineCardWidget();
            testCase.verifyWarningFree(@() w.refresh());
        end

        function testToStruct(testCase)
            w = SparklineCardWidget('Title', 'CPU', 'StaticValue', 42.0, ...
                'Units', '%', 'NSparkPoints', 30);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'sparkline');
            testCase.verifyEqual(s.units, '%');
            testCase.verifyEqual(s.nSparkPoints, 30);
        end

        function testFromStruct(testCase)
            s.type         = 'sparkline';
            s.title        = 'Load';
            s.description  = 'CPU load';
            s.position     = struct('col', 1, 'row', 2, 'width', 6, 'height', 2);
            s.units        = '%';
            s.format       = '%.2f';
            s.nSparkPoints = 40;
            s.showDelta    = false;
            s.deltaFormat  = '%+.2f';
            s.source.type  = 'static';
            s.source.value = 75.5;

            w = SparklineCardWidget.fromStruct(s);
            testCase.verifyEqual(w.Title, 'Load');
            testCase.verifyEqual(w.Units, '%');
            testCase.verifyEqual(w.NSparkPoints, 40);
            testCase.verifyEqual(w.ShowDelta, false);
            testCase.verifyEqual(w.StaticValue, 75.5);
        end
    end
end
