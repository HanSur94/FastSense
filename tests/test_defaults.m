function test_defaults()
%TEST_DEFAULTS Tests for FastPlotDefaults and getDefaults caching.

    add_private_path();

    % testDefaultsReturnsStruct
    cfg = FastPlotDefaults();
    assert(isstruct(cfg), 'testDefaults: must return struct');

    % testDefaultsHasRequiredFields
    cfg = FastPlotDefaults();
    assert(isfield(cfg, 'Theme'), 'testDefaults: Theme field');
    assert(isfield(cfg, 'Verbose'), 'testDefaults: Verbose field');
    assert(isfield(cfg, 'MinPointsForDownsample'), 'testDefaults: MinPointsForDownsample');
    assert(isfield(cfg, 'DownsampleFactor'), 'testDefaults: DownsampleFactor');
    assert(isfield(cfg, 'PyramidReduction'), 'testDefaults: PyramidReduction');
    assert(isfield(cfg, 'DefaultDownsampleMethod'), 'testDefaults: DefaultDownsampleMethod');
    assert(isfield(cfg, 'DashboardPadding'), 'testDefaults: DashboardPadding');
    assert(isfield(cfg, 'DashboardGapH'), 'testDefaults: DashboardGapH');
    assert(isfield(cfg, 'DashboardGapV'), 'testDefaults: DashboardGapV');
    assert(isfield(cfg, 'TabBarHeight'), 'testDefaults: TabBarHeight');

    % testDefaultValues — verify shipped defaults match current hard-coded values
    cfg = FastPlotDefaults();
    assert(isequal(cfg.Theme, 'default'), 'testDefaultValues: Theme');
    assert(cfg.Verbose == false, 'testDefaultValues: Verbose');
    assert(cfg.MinPointsForDownsample == 5000, 'testDefaultValues: MinPointsForDownsample');
    assert(cfg.DownsampleFactor == 2, 'testDefaultValues: DownsampleFactor');
    assert(cfg.PyramidReduction == 100, 'testDefaultValues: PyramidReduction');
    assert(strcmp(cfg.DefaultDownsampleMethod, 'minmax'), 'testDefaultValues: DefaultDownsampleMethod');
    assert(cfg.DashboardPadding == 0.06, 'testDefaultValues: DashboardPadding');
    assert(cfg.DashboardGapH == 0.05, 'testDefaultValues: DashboardGapH');
    assert(cfg.DashboardGapV == 0.07, 'testDefaultValues: DashboardGapV');
    assert(cfg.TabBarHeight == 0.03, 'testDefaultValues: TabBarHeight');

    % testGetDefaultsReturnsSameStruct
    cfg1 = getDefaults();
    cfg2 = getDefaults();
    assert(isequal(cfg1, cfg2), 'testGetDefaults: cached values identical');

    % testClearDefaultsCache — after clearing, getDefaults still returns valid struct
    clearDefaultsCache();
    cfg3 = getDefaults();
    assert(isstruct(cfg3), 'testClearCache: still returns struct');
    assert(isfield(cfg3, 'Theme'), 'testClearCache: still has Theme');

    fprintf('    All 5 defaults tests passed.\n');
end
