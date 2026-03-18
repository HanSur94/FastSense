classdef TestTheme < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultPreset(testCase)
            t = FastSenseTheme('default');
            testCase.verifyTrue(isstruct(t), 'testDefaultPreset: must return struct');
            testCase.verifyEqual(t.Background, [1 1 1], 'testDefaultPreset: Background');
            testCase.verifyTrue(isfield(t, 'AxesColor'), 'testDefaultPreset: AxesColor field');
            testCase.verifyTrue(isfield(t, 'ForegroundColor'), 'testDefaultPreset: ForegroundColor field');
            testCase.verifyTrue(isfield(t, 'GridColor'), 'testDefaultPreset: GridColor field');
            testCase.verifyTrue(isfield(t, 'GridAlpha'), 'testDefaultPreset: GridAlpha field');
            testCase.verifyTrue(isfield(t, 'GridStyle'), 'testDefaultPreset: GridStyle field');
            testCase.verifyTrue(isfield(t, 'FontName'), 'testDefaultPreset: FontName field');
            testCase.verifyTrue(isfield(t, 'FontSize'), 'testDefaultPreset: FontSize field');
            testCase.verifyTrue(isfield(t, 'TitleFontSize'), 'testDefaultPreset: TitleFontSize field');
            testCase.verifyTrue(isfield(t, 'LineWidth'), 'testDefaultPreset: LineWidth field');
            testCase.verifyTrue(isfield(t, 'LineColorOrder'), 'testDefaultPreset: LineColorOrder field');
            testCase.verifyTrue(isfield(t, 'ThresholdColor'), 'testDefaultPreset: ThresholdColor field');
            testCase.verifyTrue(isfield(t, 'ThresholdStyle'), 'testDefaultPreset: ThresholdStyle field');
            testCase.verifyTrue(isfield(t, 'ViolationMarker'), 'testDefaultPreset: ViolationMarker field');
            testCase.verifyTrue(isfield(t, 'ViolationSize'), 'testDefaultPreset: ViolationSize field');
            testCase.verifyTrue(isfield(t, 'BandAlpha'), 'testDefaultPreset: BandAlpha field');
            testCase.verifyEqual(size(t.LineColorOrder, 2), 3, 'testDefaultPreset: LineColorOrder must be Nx3');
        end

        function testNoArgsReturnsDefault(testCase)
            t0 = FastSenseTheme();
            t1 = FastSenseTheme('default');
            testCase.verifyEqual(t0, t1, 'testNoArgsReturnsDefault');
        end

        function testMergeOverrides(testCase)
            t = FastSenseTheme('default', 'FontSize', 14, 'LineWidth', 2.0);
            testCase.verifyEqual(t.FontSize, 14, 'testMergeOverrides: FontSize');
            testCase.verifyEqual(t.LineWidth, 2.0, 'testMergeOverrides: LineWidth');
            testCase.verifyEqual(t.Background, [1 1 1], 'testMergeOverrides: Background unchanged');
        end

        function testInvalidPresetErrors(testCase)
            threw = false;
            try
                FastSenseTheme('nonexistent');
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'testInvalidPresetErrors');
        end

        function testDarkPreset(testCase)
            t = FastSenseTheme('dark');
            testCase.verifyTrue(all(t.Background < [0.2 0.2 0.2]), 'testDarkPreset: Background should be dark');
            testCase.verifyTrue(all(t.ForegroundColor > [0.7 0.7 0.7]), 'testDarkPreset: ForegroundColor should be light');
            testCase.verifyEqual(size(t.LineColorOrder, 2), 3, 'testDarkPreset: LineColorOrder Nx3');
        end

        function testLightPreset(testCase)
            t = FastSenseTheme('light');
            testCase.verifyTrue(all(t.Background > [0.9 0.9 0.9]), 'testLightPreset: Background');
            testCase.verifyEqual(size(t.LineColorOrder, 2), 3, 'testLightPreset: LineColorOrder Nx3');
        end

        function testIndustrialPreset(testCase)
            t = FastSenseTheme('industrial');
            testCase.verifyTrue(t.LineWidth >= 1.0, 'testIndustrialPreset: LineWidth');
            testCase.verifyEqual(size(t.LineColorOrder, 2), 3, 'testIndustrialPreset: LineColorOrder Nx3');
        end

        function testScientificPreset(testCase)
            t = FastSenseTheme('scientific');
            testCase.verifyEqual(t.FontName, 'Times New Roman', 'testScientificPreset: FontName');
            testCase.verifyEqual(t.GridAlpha, 0, 'testScientificPreset: no grid');
            testCase.verifyTrue(t.LineWidth < 1.0, 'testScientificPreset: thin lines');
            testCase.verifyEqual(size(t.LineColorOrder, 2), 3, 'testScientificPreset: LineColorOrder Nx3');
        end

        function testOceanPreset(testCase)
            t = FastSenseTheme('ocean');
            testCase.verifyEqual(t.Background, [1 1 1], 'testOceanPreset: Background should be white');
            testCase.verifyEqual(t.AxesColor, [1 1 1], 'testOceanPreset: AxesColor should be white');
            testCase.verifyEqual(size(t.LineColorOrder, 2), 3, 'testOceanPreset: LineColorOrder Nx3');
            testCase.verifyEqual(size(t.LineColorOrder, 1), 8, 'testOceanPreset: 8 colors');
        end

        function testStructAsPreset(testCase)
            custom = struct('Background', [0 0 0], 'FontSize', 16);
            t = FastSenseTheme(custom);
            testCase.verifyEqual(t.Background, [0 0 0], 'testStructAsPreset: Background');
            testCase.verifyEqual(t.FontSize, 16, 'testStructAsPreset: FontSize');
            testCase.verifyTrue(isfield(t, 'GridColor'), 'testStructAsPreset: inherits defaults');
        end

        function testPaletteResolution(testCase)
            t = FastSenseTheme('default');
            testCase.verifyTrue(size(t.LineColorOrder, 1) >= 6, 'testPaletteResolution: at least 6 colors');
        end

        function testCustomPaletteMatrix(testCase)
            customColors = [1 0 0; 0 1 0; 0 0 1];
            t = FastSenseTheme('default', 'LineColorOrder', customColors);
            testCase.verifyEqual(t.LineColorOrder, customColors, 'testCustomPaletteMatrix');
        end
    end
end
