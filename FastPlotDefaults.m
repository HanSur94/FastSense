function cfg = FastPlotDefaults()
%FASTPLOTDEFAULTS User-editable default settings for FastPlot.
%   cfg = FastPlotDefaults()
%
%   Returns a struct of global defaults used by FastPlot, FastPlotFigure,
%   and FastPlotDock. Edit this file to customize behavior project-wide.
%
%   Values are loaded once per MATLAB session via getDefaults() and cached
%   in a persistent variable. Call clearDefaultsCache() to force a reload
%   after editing this file.
%
%   Settings:
%     Theme                    — preset name or struct (default: 'default')
%     Verbose                  — print diagnostics (default: false)
%     MinPointsForDownsample   — raw plot threshold (default: 5000)
%     DownsampleFactor         — points per pixel (default: 2)
%     PyramidReduction         — compression per level (default: 100)
%     DefaultDownsampleMethod  — 'minmax' or 'lttb' (default: 'minmax')
%     LiveInterval             — poll interval in seconds (default: 2.0)
%     DashboardPadding         — figure edge padding (default: 0.06)
%     DashboardGapH            — horizontal tile gap (default: 0.05)
%     DashboardGapV            — vertical tile gap (default: 0.07)
%     TabBarHeight             — dock tab bar height (default: 0.03)
%
%   Example — switch to dark theme with LTTB downsampling:
%     cfg.Theme = 'dark';
%     cfg.DefaultDownsampleMethod = 'lttb';
%
%   See also getDefaults, clearDefaultsCache, FastPlotTheme.

    % --- Theme ---
    cfg.Theme = 'default';              % preset name or struct
    cfg.Verbose = false;                % print diagnostics

    % --- Performance Tuning ---
    cfg.MinPointsForDownsample = 5000;  % below this, plot raw data
    cfg.DownsampleFactor = 2;           % points per pixel (min + max)
    cfg.PyramidReduction = 100;         % compression factor per pyramid level

    % --- Line Defaults ---
    cfg.DefaultDownsampleMethod = 'minmax';  % 'minmax' or 'lttb'

    % --- Axis Scale ---
    cfg.XScale = 'linear';                   % 'linear' or 'log'
    cfg.YScale = 'linear';                   % 'linear' or 'log'

    % --- Live Mode ---
    cfg.LiveInterval = 2.0;                  % poll interval in seconds

    % --- Dashboard Layout (normalized units) ---
    cfg.DashboardPadding = 0.06;        % padding around figure edges
    cfg.DashboardGapH = 0.05;           % horizontal gap between tiles
    cfg.DashboardGapV = 0.07;           % vertical gap between tiles

    % --- Dock Layout ---
    cfg.TabBarHeight = 0.03;            % normalized height of tab bar
end
