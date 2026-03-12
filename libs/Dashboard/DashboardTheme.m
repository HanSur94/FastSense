function theme = DashboardTheme(preset, varargin)
%DASHBOARDTHEME Returns a theme struct with FastPlotTheme + dashboard fields.
%
%   theme = DashboardTheme()              % default preset
%   theme = DashboardTheme('dark')        % named preset
%   theme = DashboardTheme('dark', 'DashboardBackground', [0.1 0.1 0.2])
%
%   Returns a struct containing all FastPlotTheme fields plus dashboard-specific
%   fields: DashboardBackground, WidgetBackground, WidgetBorderColor,
%   WidgetBorderWidth, DragHandleColor, DropZoneColor, ToolbarBackground,
%   ToolbarFontColor, HeaderFontSize, WidgetTitleFontSize, StatusOkColor,
%   StatusWarnColor, StatusAlarmColor, GaugeArcWidth, KpiFontSize.

    if nargin == 0
        preset = 'default';
    end

    % Get base FastPlotTheme
    base = FastPlotTheme(preset);

    % Append dashboard-specific fields
    dash = getDashboardDefaults(preset);
    fnames = fieldnames(dash);
    for i = 1:numel(fnames)
        base.(fnames{i}) = dash.(fnames{i});
    end

    theme = base;

    % Apply name-value overrides
    for k = 1:2:numel(varargin)
        theme.(varargin{k}) = varargin{k+1};
    end
end

function d = getDashboardDefaults(preset)
    switch preset
        case 'dark'
            d.DashboardBackground = [0.10 0.10 0.18];
            d.WidgetBackground    = [0.09 0.13 0.24];
            d.WidgetBorderColor   = [0.16 0.23 0.37];
            d.ToolbarBackground   = [0.09 0.13 0.24];
            d.ToolbarFontColor    = [0.66 0.73 0.78];
            d.DragHandleColor     = [0.31 0.80 0.64];
            d.DropZoneColor       = [0.16 0.23 0.37];
        case 'light'
            d.DashboardBackground = [0.96 0.96 0.97];
            d.WidgetBackground    = [1.00 1.00 1.00];
            d.WidgetBorderColor   = [0.85 0.85 0.87];
            d.ToolbarBackground   = [0.94 0.94 0.95];
            d.ToolbarFontColor    = [0.20 0.20 0.25];
            d.DragHandleColor     = [0.20 0.60 0.86];
            d.DropZoneColor       = [0.85 0.85 0.87];
        case 'industrial'
            d.DashboardBackground = [0.15 0.15 0.16];
            d.WidgetBackground    = [0.20 0.20 0.21];
            d.WidgetBorderColor   = [0.30 0.30 0.31];
            d.ToolbarBackground   = [0.20 0.20 0.21];
            d.ToolbarFontColor    = [0.78 0.78 0.78];
            d.DragHandleColor     = [0.90 0.60 0.10];
            d.DropZoneColor       = [0.30 0.30 0.31];
        case 'scientific'
            d.DashboardBackground = [0.98 0.98 0.96];
            d.WidgetBackground    = [1.00 1.00 1.00];
            d.WidgetBorderColor   = [0.80 0.80 0.78];
            d.ToolbarBackground   = [0.94 0.94 0.92];
            d.ToolbarFontColor    = [0.15 0.15 0.20];
            d.DragHandleColor     = [0.00 0.45 0.74];
            d.DropZoneColor       = [0.80 0.80 0.78];
        case 'ocean'
            d.DashboardBackground = [0.05 0.12 0.18];
            d.WidgetBackground    = [0.07 0.16 0.24];
            d.WidgetBorderColor   = [0.12 0.25 0.35];
            d.ToolbarBackground   = [0.07 0.16 0.24];
            d.ToolbarFontColor    = [0.60 0.78 0.85];
            d.DragHandleColor     = [0.00 0.75 0.85];
            d.DropZoneColor       = [0.12 0.25 0.35];
        otherwise % 'default'
            d.DashboardBackground = [0.94 0.94 0.94];
            d.WidgetBackground    = [1.00 1.00 1.00];
            d.WidgetBorderColor   = [0.80 0.80 0.80];
            d.ToolbarBackground   = [0.90 0.90 0.90];
            d.ToolbarFontColor    = [0.20 0.20 0.20];
            d.DragHandleColor     = [0.20 0.60 0.40];
            d.DropZoneColor       = [0.80 0.80 0.80];
    end

    % Shared defaults across all presets
    d.WidgetBorderWidth    = 1;
    d.HeaderFontSize       = 14;
    d.WidgetTitleFontSize  = 11;
    d.StatusOkColor        = [0.31 0.80 0.64];
    d.StatusWarnColor      = [0.91 0.63 0.27];
    d.StatusAlarmColor     = [0.91 0.27 0.38];
    d.GaugeArcWidth        = 8;
    d.KpiFontSize          = 28;
end
