function cfg = FastSenseDefaults()
%FASTSENSEDEFAULTS User-editable default settings for FastSense.
%   cfg = FASTSENSEDEFAULTS() returns a struct of global defaults used by
%   FastSense, FastSenseGrid, and FastSenseDock. Edit this file to
%   customize behavior project-wide.
%
%   Values are loaded once per MATLAB session via getDefaults() and cached
%   in a persistent variable. Call clearDefaultsCache() to force a reload
%   after editing this file.
%
%   Output:
%     cfg — struct with the following fields:
%
%   Theme Settings:
%     cfg.Theme                    — preset name ('light' or 'dark';
%                                    legacy names 'default',
%                                    'industrial', 'scientific', 'ocean'
%                                    are accepted and aliased to 'light')
%                                    or a struct of theme overrides
%                                    (default: 'light')
%     cfg.ThemeDir                 — folder containing custom theme .m
%                                    files, relative to this file
%                                    (default: 'themes')
%     cfg.Verbose                  — logical; print diagnostics to the
%                                    console during plotting operations
%                                    (default: false)
%
%   Performance Tuning:
%     cfg.MinPointsForDownsample   — integer; series with fewer points
%                                    than this are plotted raw without
%                                    downsampling (default: 5000)
%     cfg.DownsampleFactor         — integer; target points per pixel
%                                    for downsampled display; higher
%                                    values produce denser traces
%                                    (default: 2)
%     cfg.PyramidReduction         — integer; compression factor per
%                                    level of the data pyramid; controls
%                                    the ratio between successive LOD
%                                    levels (default: 100)
%
%   Line Defaults:
%     cfg.DefaultDownsampleMethod  — char; downsampling algorithm:
%                                    'minmax' preserves extremes,
%                                    'lttb' (Largest-Triangle-Three-
%                                    Buckets) preserves visual shape
%                                    (default: 'minmax')
%
%   Axis Scale:
%     cfg.XScale                   — char; 'linear' or 'log'
%                                    (default: 'linear')
%     cfg.YScale                   — char; 'linear' or 'log'
%                                    (default: 'linear')
%
%   Live Mode:
%     cfg.LiveInterval             — double; polling interval in seconds
%                                    for live-updating data sources
%                                    (default: 2.0)
%
%   Dashboard Layout (normalized figure units 0..1):
%     cfg.DashboardPadding         — 1x4 double [left bottom right top];
%                                    padding between figure edges and the
%                                    tile grid (default: [0.06 0.04 0.01 0.02])
%     cfg.DashboardGapH            — double; horizontal gap between
%                                    adjacent tiles (default: 0.03)
%     cfg.DashboardGapV            — double; vertical gap between
%                                    adjacent tiles (default: 0.06)
%
%   Dock Layout:
%     cfg.TabBarHeight             — double; normalized height of the tab
%                                    bar in docked figure mode
%                                    (default: 0.03)
%     cfg.MinTabWidth              — double; minimum normalized width per
%                                    tab button; when tabs would be smaller,
%                                    scroll arrows appear (default: 0.10)
%
%   SensorDetailPlot Layout:
%     cfg.NavigatorHeight          — double; fraction of total height
%                                    allocated to the navigator strip in
%                                    SensorDetailPlot (default: 0.20)
%
%   Example — switch to dark theme with LTTB downsampling:
%     cfg = FastSenseDefaults();
%     cfg.Theme = 'dark';
%     cfg.DefaultDownsampleMethod = 'lttb';
%
%   Example — widen tile gaps for a spacious dashboard:
%     cfg = FastSenseDefaults();
%     cfg.DashboardGapH = 0.06;
%     cfg.DashboardGapV = 0.10;
%
%   See also getDefaults, clearDefaultsCache, FastSenseTheme.

    % --- Theme ---
    cfg.Theme = 'default';              % preset name or struct
    cfg.ThemeDir = 'themes';          % folder of custom theme .m files
    cfg.Verbose = false;                % print diagnostics

    % --- Performance Tuning ---
    cfg.MinPointsForDownsample = 5000;  % below this, plot raw data
    cfg.DownsampleFactor = 2;           % points per pixel (min + max)
    cfg.PyramidReduction = 100;         % compression factor per pyramid level

    % --- Memory Management ---
    cfg.StorageMode = 'auto';           % 'auto', 'memory', or 'disk'
    cfg.MemoryLimit = 500e6;            % bytes; lines above this use disk (auto mode)

    % --- Line Defaults ---
    cfg.DefaultDownsampleMethod = 'minmax';  % 'minmax' or 'lttb'

    % --- Axis Scale ---
    cfg.XScale = 'linear';                   % 'linear' or 'log'
    cfg.YScale = 'linear';                   % 'linear' or 'log'

    % --- Live Mode ---
    cfg.LiveInterval = 2.0;                  % poll interval in seconds

    % --- Dashboard Layout (normalized units) ---
    cfg.DashboardPadding = [0.06 0.04 0.01 0.02];  % [left bottom right top]
    cfg.DashboardGapH = 0.03;           % horizontal gap between tiles
    cfg.DashboardGapV = 0.06;           % vertical gap between tiles

    % --- Dock Layout ---
    cfg.TabBarHeight = 0.03;            % normalized height of tab bar
    cfg.MinTabWidth  = 0.10;            % minimum normalized width per tab

    % --- SensorDetailPlot Layout ---
    cfg.NavigatorHeight = 0.20;         % fraction of total height for navigator
end
