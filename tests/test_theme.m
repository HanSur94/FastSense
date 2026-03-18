function test_theme()
%TEST_THEME Tests for FastSenseTheme function.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();

    % testDefaultPreset
    t = FastSenseTheme('default');
    assert(isstruct(t), 'testDefaultPreset: must return struct');
    assert(isequal(t.Background, [1 1 1]), 'testDefaultPreset: Background');
    assert(isfield(t, 'AxesColor'), 'testDefaultPreset: AxesColor field');
    assert(isfield(t, 'ForegroundColor'), 'testDefaultPreset: ForegroundColor field');
    assert(isfield(t, 'GridColor'), 'testDefaultPreset: GridColor field');
    assert(isfield(t, 'GridAlpha'), 'testDefaultPreset: GridAlpha field');
    assert(isfield(t, 'GridStyle'), 'testDefaultPreset: GridStyle field');
    assert(isfield(t, 'FontName'), 'testDefaultPreset: FontName field');
    assert(isfield(t, 'FontSize'), 'testDefaultPreset: FontSize field');
    assert(isfield(t, 'TitleFontSize'), 'testDefaultPreset: TitleFontSize field');
    assert(isfield(t, 'LineWidth'), 'testDefaultPreset: LineWidth field');
    assert(isfield(t, 'LineColorOrder'), 'testDefaultPreset: LineColorOrder field');
    assert(isfield(t, 'ThresholdColor'), 'testDefaultPreset: ThresholdColor field');
    assert(isfield(t, 'ThresholdStyle'), 'testDefaultPreset: ThresholdStyle field');
    assert(isfield(t, 'ViolationMarker'), 'testDefaultPreset: ViolationMarker field');
    assert(isfield(t, 'ViolationSize'), 'testDefaultPreset: ViolationSize field');
    assert(isfield(t, 'BandAlpha'), 'testDefaultPreset: BandAlpha field');
    assert(size(t.LineColorOrder, 2) == 3, 'testDefaultPreset: LineColorOrder must be Nx3');

    % testNoArgsReturnsDefault
    t0 = FastSenseTheme();
    t1 = FastSenseTheme('default');
    assert(isequal(t0, t1), 'testNoArgsReturnsDefault');

    % testMergeOverrides
    t = FastSenseTheme('default', 'FontSize', 14, 'LineWidth', 2.0);
    assert(t.FontSize == 14, 'testMergeOverrides: FontSize');
    assert(t.LineWidth == 2.0, 'testMergeOverrides: LineWidth');
    assert(isequal(t.Background, [1 1 1]), 'testMergeOverrides: Background unchanged');

    % testInvalidPresetErrors
    threw = false;
    try
        FastSenseTheme('nonexistent');
    catch
        threw = true;
    end
    assert(threw, 'testInvalidPresetErrors');

    % testDarkPreset
    t = FastSenseTheme('dark');
    assert(all(t.Background < [0.2 0.2 0.2]), 'testDarkPreset: Background should be dark');
    assert(all(t.ForegroundColor > [0.7 0.7 0.7]), 'testDarkPreset: ForegroundColor should be light');
    assert(size(t.LineColorOrder, 2) == 3, 'testDarkPreset: LineColorOrder Nx3');

    % testLightPreset
    t = FastSenseTheme('light');
    assert(all(t.Background > [0.9 0.9 0.9]), 'testLightPreset: Background');
    assert(size(t.LineColorOrder, 2) == 3, 'testLightPreset: LineColorOrder Nx3');

    % testIndustrialPreset
    t = FastSenseTheme('industrial');
    assert(t.LineWidth >= 1.0, 'testIndustrialPreset: LineWidth');
    assert(size(t.LineColorOrder, 2) == 3, 'testIndustrialPreset: LineColorOrder Nx3');

    % testScientificPreset
    t = FastSenseTheme('scientific');
    assert(strcmp(t.FontName, 'Times New Roman'), 'testScientificPreset: FontName');
    assert(t.GridAlpha == 0, 'testScientificPreset: no grid');
    assert(t.LineWidth < 1.0, 'testScientificPreset: thin lines');
    assert(size(t.LineColorOrder, 2) == 3, 'testScientificPreset: LineColorOrder Nx3');

    % testOceanPreset
    t = FastSenseTheme('ocean');
    assert(isequal(t.Background, [1 1 1]), 'testOceanPreset: Background should be white');
    assert(isequal(t.AxesColor, [1 1 1]), 'testOceanPreset: AxesColor should be white');
    assert(size(t.LineColorOrder, 2) == 3, 'testOceanPreset: LineColorOrder Nx3');
    assert(size(t.LineColorOrder, 1) == 8, 'testOceanPreset: 8 colors');

    % testStructAsPreset
    custom = struct('Background', [0 0 0], 'FontSize', 16);
    t = FastSenseTheme(custom);
    assert(isequal(t.Background, [0 0 0]), 'testStructAsPreset: Background');
    assert(t.FontSize == 16, 'testStructAsPreset: FontSize');
    assert(isfield(t, 'GridColor'), 'testStructAsPreset: inherits defaults');

    % testPaletteResolution
    t = FastSenseTheme('default');
    assert(size(t.LineColorOrder, 1) >= 6, 'testPaletteResolution: at least 6 colors');

    % testCustomPaletteMatrix
    customColors = [1 0 0; 0 1 0; 0 0 1];
    t = FastSenseTheme('default', 'LineColorOrder', customColors);
    assert(isequal(t.LineColorOrder, customColors), 'testCustomPaletteMatrix');

    fprintf('    All 12 theme tests passed.\n');
end
