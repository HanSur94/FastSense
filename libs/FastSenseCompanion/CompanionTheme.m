classdef CompanionTheme
%COMPANIONTHEME Static theme helper for the FastSense Companion.
%
%   Usage:
%     theme = CompanionTheme.get('dark')   % default
%     theme = CompanionTheme.get('light')
%
%   Returns the full DashboardTheme struct for the given preset plus the
%   following companion-specific fields:
%     PanePadding          — 16 px — inner padding for each pane uipanel
%     GridOuterPadding     — 24 px — uigridlayout outer Padding (all sides)
%     GridColumnSpacing    — 16 px — uigridlayout ColumnSpacing
%     PlaceholderTextColor — RGB   — uilabel FontColor in placeholder panes
%     SearchFieldHeight    — 28 px — reserved for Phase 1019 search field
%     FilterPillHeight     — 24 px — reserved for Phase 1019 filter pills
%     Accent               — RGB   — companion accent color (active pills,
%                                    Plot CTA bg, mode toggle selected, status dot)
%     LineColors           — cell  — row-vector cell of plot line colors
%                                    (cell-of-row-vector form derived from
%                                    DashboardTheme.LineColorOrder)
%
%   See also DashboardTheme.

    methods (Static)
        function theme = get(preset)
        %GET Return augmented DashboardTheme struct with companion-specific fields.
        %   preset — char: 'dark' (default) or 'light'
        %
        %   Returns struct with all DashboardTheme fields plus:
        %     PanePadding, GridOuterPadding, GridColumnSpacing,
        %     PlaceholderTextColor, SearchFieldHeight, FilterPillHeight
            if nargin == 0
                preset = 'dark';
            end

            theme = DashboardTheme(preset);

            % Companion layout constants (same for both presets)
            theme.PanePadding       = 16;
            theme.GridOuterPadding  = 24;
            theme.GridColumnSpacing = 16;
            theme.SearchFieldHeight = 28;
            theme.FilterPillHeight  = 24;

            % PlaceholderTextColor mirrors ToolbarFontColor — already in struct.
            % Declared as a named field so Phases 1019–1021 don't re-derive it.
            % dark:  [0.66 0.73 0.78]
            % light: [0.20 0.20 0.25]
            theme.PlaceholderTextColor = theme.ToolbarFontColor;

            % Phase 1023.1 cross-phase fix: companion-side aliases for fields
            % the panes expected but DashboardTheme exposes under different
            % names. theme.Accent backs active filter pills (1019), live
            % status dot (1020), mode-toggle selected state + Plot CTA (1021).
            % theme.LineColors backs the InspectorPane sparkline color (1021).
            % dark:  Accent = [0.31 0.80 0.64]; light: [0.20 0.60 0.86]
            theme.Accent = theme.DragHandleColor;
            % Convert FastSenseTheme's Nx3 LineColorOrder matrix to a
            % cell of 1x3 row vectors so callers can write theme.LineColors{1}.
            theme.LineColors = num2cell(theme.LineColorOrder, 2)';
        end
    end
end
