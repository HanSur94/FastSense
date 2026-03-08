function cfg = FastPlotDefaults()
%FASTPLOTDEFAULTS User-editable default settings for FastPlot.
%   Edit this file to change global defaults for all FastPlot instances.
%   These values are loaded once per MATLAB session and cached.
%   Call clearDefaultsCache() to force a reload after editing.
%
%   Example: change default theme to dark and increase font size:
%       cfg.Theme = 'dark';
%       cfg.FontSize = 14;   (set in the theme, not here)

    % --- Theme ---
    cfg.Theme = 'default';              % preset name or struct
    cfg.Verbose = false;                % print diagnostics

    % --- Performance Tuning ---
    cfg.MinPointsForDownsample = 5000;  % below this, plot raw data
    cfg.DownsampleFactor = 2;           % points per pixel (min + max)
    cfg.PyramidReduction = 100;         % compression factor per pyramid level

    % --- Line Defaults ---
    cfg.DefaultDownsampleMethod = 'minmax';  % 'minmax' or 'lttb'

    % --- Dashboard Layout (normalized units) ---
    cfg.DashboardPadding = 0.06;        % padding around figure edges
    cfg.DashboardGapH = 0.05;           % horizontal gap between tiles
    cfg.DashboardGapV = 0.07;           % vertical gap between tiles

    % --- Dock Layout ---
    cfg.TabBarHeight = 0.03;            % normalized height of tab bar
end
