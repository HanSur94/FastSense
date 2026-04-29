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
        end
    end
end
