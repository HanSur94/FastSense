classdef TestFastSenseTheme < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testThemeConstructorString(testCase)
            fp = FastSense('Theme', 'dark');
            testCase.verifyTrue(isstruct(fp.Theme), 'testThemeConstructorString: Theme must be struct');
            testCase.verifyTrue(all(fp.Theme.Background < [0.2 0.2 0.2]), 'testThemeConstructorString: dark bg');
        end

        function testThemeConstructorStruct(testCase)
            custom = struct('Background', [0.5 0.5 0.5]);
            fp = FastSense('Theme', custom);
            testCase.verifyEqual(fp.Theme.Background, [0.5 0.5 0.5], 'testThemeConstructorStruct');
            testCase.verifyTrue(isfield(fp.Theme, 'FontSize'), 'testThemeConstructorStruct: inherits defaults');
        end

        function testDefaultThemeWhenNoneSpecified(testCase)
            fp = FastSense();
            testCase.verifyTrue(isstruct(fp.Theme), 'testDefaultTheme: must have theme');
            testCase.verifyEqual(fp.Theme.Background, [1 1 1], 'testDefaultTheme: default bg');
        end

        function testThemeAppliedOnRender(testCase)
            fp = FastSense('Theme', 'dark');
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            bgColor = get(fp.hFigure, 'Color');
            testCase.verifyTrue(all(bgColor < [0.2 0.2 0.2]), 'testThemeAppliedOnRender: figure bg');
            axColor = get(fp.hAxes, 'Color');
            testCase.verifyTrue(all(axColor < [0.25 0.25 0.25]), 'testThemeAppliedOnRender: axes bg');
        end

        function testThemeFontApplied(testCase)
            fp = FastSense('Theme', 'scientific');
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyEqual(get(fp.hAxes, 'FontName'), 'Times New Roman', 'testThemeFontApplied');
        end

        function testThemeWithParentAxes(testCase)
            fig = figure('Visible', 'off');
            testCase.addTeardown(@close, fig);
            ax = axes('Parent', fig);
            fp = FastSense('Parent', ax, 'Theme', 'dark');
            fp.addLine(1:100, rand(1,100));
            fp.render();
            axColor = get(ax, 'Color');
            testCase.verifyTrue(all(axColor < [0.25 0.25 0.25]), 'testThemeWithParentAxes: axes bg');
        end

        function testBackwardCompatNoTheme(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyTrue(ishandle(fp.hAxes), 'testBackwardCompatNoTheme');
        end

        function testAutoColorCycling(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10));
            fp.addLine(1:10, rand(1,10));
            fp.addLine(1:10, rand(1,10));
            c1 = fp.Lines(1).Options.Color;
            c2 = fp.Lines(2).Options.Color;
            c3 = fp.Lines(3).Options.Color;
            testCase.verifyTrue(~isequal(c1, c2), 'testAutoColorCycling: colors 1 and 2 differ');
            testCase.verifyTrue(~isequal(c2, c3), 'testAutoColorCycling: colors 2 and 3 differ');
        end

        function testExplicitColorSkipsCycle(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10), 'Color', [1 0 0]);
            fp.addLine(1:10, rand(1,10));
            testCase.verifyEqual(fp.Lines(1).Options.Color, [1 0 0], 'testExplicitColorSkipsCycle: explicit');
            expected2 = fp.Theme.LineColorOrder(1, :);
            testCase.verifyEqual(fp.Lines(2).Options.Color, expected2, 'testExplicitColorSkipsCycle: auto gets first');
        end

        function testThresholdUsesThemeDefaults(testCase)
            fp = FastSense('Theme', struct('ThresholdColor', [0 1 0], 'ThresholdStyle', ':'));
            fp.addThreshold(5.0);
            testCase.verifyEqual(fp.Thresholds(1).Color, [0 1 0], 'testThresholdThemeDefaults: Color');
            testCase.verifyEqual(fp.Thresholds(1).LineStyle, ':', 'testThresholdThemeDefaults: Style');
        end

        function testThresholdExplicitOverridesTheme(testCase)
            fp = FastSense('Theme', struct('ThresholdColor', [0 1 0]));
            fp.addThreshold(5.0, 'Color', [1 0 0]);
            testCase.verifyEqual(fp.Thresholds(1).Color, [1 0 0], 'testThresholdOverride: Color');
        end
    end
end
