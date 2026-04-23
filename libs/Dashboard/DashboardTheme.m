function theme = DashboardTheme(preset, varargin)
%DASHBOARDTHEME Returns a theme struct with FastSenseTheme + dashboard fields.
%
%   theme = DashboardTheme()              % 'light' preset (default)
%   theme = DashboardTheme('dark')        % named preset ('light' or 'dark')
%   theme = DashboardTheme('dark', 'DashboardBackground', [0.1 0.1 0.2])
%
%   Legacy preset names ('default', 'industrial', 'scientific', 'ocean')
%   are accepted and aliased to 'light' for backward compatibility.
%
%   Returns a struct containing all FastSenseTheme fields plus dashboard-specific
%   fields.
%
%   Inherited from FastSenseTheme (guaranteed on all presets):
%     ForegroundColor, AxesColor, AxisColor, FontName, Background,
%     LineColors, GridColor, GridAlpha, MinorGridColor, MinorGridAlpha
%
%   Dashboard-specific fields:
%     DashboardBackground, WidgetBackground, WidgetBorderColor,
%     WidgetBorderWidth, DragHandleColor, DropZoneColor, GridLineColor,
%     ToolbarBackground, ToolbarFontColor, HeaderFontSize,
%     WidgetTitleFontSize, StatusOkColor, StatusWarnColor, StatusAlarmColor,
%     GaugeArcWidth, KpiFontSize.

    if nargin == 0
        preset = 'light';
    end

    % Alias legacy preset names to 'light' so existing configs, tests,
    % and examples keep working after the theme catalog was trimmed to
    % 'light' and 'dark'.
    if ischar(preset) && any(strcmpi(preset, {'default', 'industrial', 'scientific', 'ocean'}))
        preset = 'light';
    end

    % Get base FastSenseTheme
    base = FastSenseTheme(preset);

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
    switch lower(preset)
        case 'dark'
            d.DashboardBackground = [0.10 0.10 0.18];
            d.WidgetBackground    = [0.09 0.13 0.24];
            d.WidgetBorderColor   = [0.16 0.23 0.37];
            d.ToolbarBackground   = [0.09 0.13 0.24];
            d.ToolbarFontColor    = [0.66 0.73 0.78];
            d.DragHandleColor     = [0.31 0.80 0.64];
            d.DropZoneColor       = [0.16 0.23 0.37];
            d.GridLineColor       = [0.20 0.28 0.42];
            d.GroupHeaderBg       = [0.16 0.22 0.34];
            d.GroupHeaderFg       = [0.95 0.95 0.95];
            d.GroupBorderColor    = [0.25 0.30 0.40];
            d.TabActiveBg         = [0.16 0.22 0.34];
            d.TabInactiveBg       = [0.10 0.12 0.18];
        otherwise % 'light' (also: legacy aliases default/industrial/scientific/ocean)
            d.DashboardBackground = [0.96 0.96 0.97];
            d.WidgetBackground    = [1.00 1.00 1.00];
            d.WidgetBorderColor   = [0.85 0.85 0.87];
            d.ToolbarBackground   = [0.94 0.94 0.95];
            d.ToolbarFontColor    = [0.20 0.20 0.25];
            d.DragHandleColor     = [0.20 0.60 0.86];
            d.DropZoneColor       = [0.85 0.85 0.87];
            d.GridLineColor       = [0.82 0.82 0.85];
            d.GroupHeaderBg       = [0.90 0.92 0.95];
            d.GroupHeaderFg       = [0.15 0.15 0.15];
            d.GroupBorderColor    = [0.80 0.82 0.85];
            d.TabActiveBg         = [0.90 0.92 0.95];
            d.TabInactiveBg       = [0.82 0.84 0.88];
    end

    % Axis label/tick color — derive from toolbar font (readable on widget bg)
    if ~isfield(d, 'AxisColor')
        d.AxisColor = d.ToolbarFontColor;
    end

    % Shared defaults across all presets
    d.WidgetBorderWidth    = 1;
    d.HeaderFontSize       = 14;
    d.WidgetTitleFontSize  = 11;
    d.StatusOkColor        = [0.31 0.80 0.64];
    d.StatusWarnColor      = [0.91 0.63 0.27];
    d.StatusAlarmColor     = [0.91 0.27 0.38];
    d.InfoColor            = [0.27 0.52 0.85];
    d.GaugeArcWidth        = 8;
    d.KpiFontSize          = 28;

    % Group widget shared defaults (overridden per preset above where applicable)
    if ~isfield(d, 'GroupHeaderBg')
        d.GroupHeaderBg    = [0.20 0.20 0.25];
    end
    if ~isfield(d, 'GroupHeaderFg')
        d.GroupHeaderFg    = [0.92 0.92 0.92];
    end
    if ~isfield(d, 'GroupBorderColor')
        d.GroupBorderColor = [0.30 0.30 0.35];
    end
    if ~isfield(d, 'TabActiveBg')
        d.TabActiveBg      = [0.20 0.20 0.25];
    end
    if ~isfield(d, 'TabInactiveBg')
        d.TabInactiveBg    = [0.12 0.12 0.16];
    end
end
