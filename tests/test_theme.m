function test_theme()
%TEST_THEME Tests for FastPlotTheme function.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

    % testDefaultPreset
    t = FastPlotTheme('default');
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
    t0 = FastPlotTheme();
    t1 = FastPlotTheme('default');
    assert(isequal(t0, t1), 'testNoArgsReturnsDefault');

    % testMergeOverrides
    t = FastPlotTheme('default', 'FontSize', 14, 'LineWidth', 2.0);
    assert(t.FontSize == 14, 'testMergeOverrides: FontSize');
    assert(t.LineWidth == 2.0, 'testMergeOverrides: LineWidth');
    assert(isequal(t.Background, [1 1 1]), 'testMergeOverrides: Background unchanged');

    % testInvalidPresetErrors
    threw = false;
    try
        FastPlotTheme('nonexistent');
    catch
        threw = true;
    end
    assert(threw, 'testInvalidPresetErrors');

    fprintf('    All 4 theme tests passed.\n');
end
