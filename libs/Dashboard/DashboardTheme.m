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
            d.MarkerPlantLog      = [0 0 0];   % Phase 1031 PLOG-VIZ-09: black plant-log slider markers
            d.CurrentViewBoxColor = [0.95 0.62 0.20];   % Phase 1039: amber current-view box, contrasts with bluish-gray Selection
            % Status colors are set per-preset (guarded shared block below) so
            % the light preset can carry its own crisp trio without disturbing dark.
            d.StatusOkColor       = [0.31 0.80 0.64];
            d.StatusWarnColor     = [0.91 0.63 0.27];
            d.StatusAlarmColor    = [0.91 0.27 0.38];
        otherwise % 'light' (also: legacy aliases default/industrial/scientific/ocean)
            % Clean-modern light preset: white widget surfaces on a soft neutral
            % canvas, hairline cool borders, blue #2563EB drag/drop accent.
            d.DashboardBackground = [0.961 0.965 0.973];
            d.WidgetBackground    = [1.00 1.00 1.00];
            d.WidgetBorderColor   = [0.898 0.910 0.925];
            d.ToolbarBackground   = [0.976 0.980 0.984];
            d.ToolbarFontColor    = [0.392 0.455 0.545];
            d.DragHandleColor     = [0.145 0.388 0.922];
            d.DropZoneColor       = [0.918 0.945 0.996];
            d.GridLineColor       = [0.914 0.929 0.949];
            d.GroupHeaderBg       = [0.933 0.949 0.969];
            d.GroupHeaderFg       = [0.118 0.161 0.231];
            d.GroupBorderColor    = [0.898 0.910 0.925];
            d.TabActiveBg         = [0.918 0.945 0.996];
            d.TabInactiveBg       = [0.933 0.949 0.969];
            d.MarkerPlantLog      = [0 0 0];   % Phase 1031 PLOG-VIZ-09: black plant-log slider markers
            d.CurrentViewBoxColor = [0.85 0.45 0.05];    % Phase 1039: dark amber, contrasts with the dark-blue Selection on light bg
            % Crisp semantic status trio, tuned for readability on white.
            d.StatusOkColor       = [0.086 0.639 0.290];
            d.StatusWarnColor     = [0.961 0.620 0.043];
            d.StatusAlarmColor    = [0.937 0.267 0.267];
    end

    % Axis label/tick color — derive from toolbar font (readable on widget bg)
    if ~isfield(d, 'AxisColor')
        d.AxisColor = d.ToolbarFontColor;
    end

    % Shared defaults across all presets
    d.WidgetBorderWidth    = 1;
    % Grid breathing room (Phase 1 UI refresh): inter-widget gutters + outer
    % canvas padding, in normalized units. DashboardLayout.computePosition
    % consumes GapH/GapV/Padding; DashboardEngine wires these in before
    % allocatePanels so widgets read as separated cards. DashboardPad is
    % [left bottom right top].
    d.WidgetGapH           = 0.006;
    d.WidgetGapV           = 0.010;
    d.DashboardPad         = [0.008 0.010 0.008 0.010];
    d.HeaderFontSize       = 14;
    d.WidgetTitleFontSize  = 11;
    % Status colors are now set per-preset above; guard so this shared block
    % only supplies a fallback and never clobbers a preset's own values.
    if ~isfield(d, 'StatusOkColor')
        d.StatusOkColor    = [0.31 0.80 0.64];
    end
    if ~isfield(d, 'StatusWarnColor')
        d.StatusWarnColor  = [0.91 0.63 0.27];
    end
    if ~isfield(d, 'StatusAlarmColor')
        d.StatusAlarmColor = [0.91 0.27 0.38];
    end
    d.InfoColor            = [0.27 0.52 0.85];
    d.GaugeArcWidth        = 8;
    d.KpiFontSize          = 28;
    d.EventMarkerSize      = 8;        % Phase 1012 — FastSense event overlay marker size (pt)

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
