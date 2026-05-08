function applyThemeToChildren_(rootHandle, theme)
%APPLYTHEMETOCHILDREN_ Recursive walker that recolors uifigure subtrees in place.
%   applyThemeToChildren_(rootHandle, theme) walks rootHandle.Children and
%   sets BackgroundColor / FontColor / ForegroundColor properties from the
%   given CompanionTheme struct. Recurses into uipanel, uigridlayout, and
%   uibuttongroup. Skips unknown widget classes silently.
%
%   theme must contain at least:
%     WidgetBackground, WidgetBorderColor, ForegroundColor,
%     PlaceholderTextColor, Accent, DashboardBackground.
%
%   Each property assignment is wrapped in try/catch so a single
%   incompatible widget cannot abort the rest of the repaint.
%
%   Covered widget classes (v260508-d7k):
%     Containers (recurse): Panel, GridLayout, ButtonGroup
%     Text/input:  Label, EditField, NumericEditField, TextArea, DropDown,
%                  Spinner
%     Buttons:     Button, StateButton, ToggleButton
%     Selection:   CheckBox, RadioButton, ListBox
%     Data:        Table
%
%   Out of scope: axes / uiaxes children (owned by FastSense widgets) and
%   anything inside them (line/threshold colors).
%
%   See also CompanionTheme, FastSenseCompanion.applyTheme.

    if isempty(rootHandle) || ~isvalid(rootHandle); return; end
    if ~isstruct(theme); return; end
    try
        kids = rootHandle.Children;
    catch
        return;
    end
    % Pick the table backdrop pair once based on theme darkness.
    isDark = mean(theme.DashboardBackground) < 0.5;
    if isDark
        tableBg = [0.13 0.13 0.13; 0.20 0.20 0.20];
    else
        tableBg = [1.00 1.00 1.00; 0.94 0.94 0.94];
    end
    for i = 1:numel(kids)
        ch = kids(i);
        if ~isvalid(ch); continue; end
        cls = class(ch);
        switch cls
            case 'matlab.ui.container.Panel'
                try; ch.BackgroundColor = theme.WidgetBackground; catch; end
                try; ch.BorderColor     = theme.WidgetBorderColor; catch; end
                applyThemeToChildren_(ch, theme);

            case 'matlab.ui.container.GridLayout'
                try; ch.BackgroundColor = theme.WidgetBackground; catch; end
                applyThemeToChildren_(ch, theme);

            case 'matlab.ui.container.ButtonGroup'
                try; ch.BackgroundColor = theme.WidgetBackground; catch; end
                try; ch.BorderColor     = theme.WidgetBorderColor; catch; end
                applyThemeToChildren_(ch, theme);

            case 'matlab.ui.control.Label'
                % Labels inherit BackgroundColor from their parent — only
                % update FontColor here.
                try; ch.FontColor = theme.ForegroundColor; catch; end

            case 'matlab.ui.control.EditField'
                try; ch.BackgroundColor = theme.WidgetBackground; catch; end
                try; ch.FontColor       = theme.ForegroundColor; catch; end

            case 'matlab.ui.control.DropDown'
                try; ch.BackgroundColor = theme.WidgetBackground; catch; end
                try; ch.FontColor       = theme.ForegroundColor; catch; end

            case 'matlab.ui.control.Spinner'
                try; ch.BackgroundColor = theme.WidgetBackground; catch; end
                try; ch.FontColor       = theme.ForegroundColor; catch; end

            case 'matlab.ui.control.Button'
                % Live: ON button is repainted by FastSenseCompanion.updateLiveButton_
                % so do NOT special-case it here. Default to neutral styling.
                try; ch.BackgroundColor = theme.WidgetBorderColor; catch; end
                try; ch.FontColor       = theme.ForegroundColor; catch; end

            case 'matlab.ui.control.ListBox'
                try; ch.BackgroundColor = theme.WidgetBackground; catch; end
                try; ch.FontColor       = theme.ForegroundColor; catch; end

            case 'matlab.ui.control.TextArea'
                try; ch.BackgroundColor = theme.WidgetBackground; catch; end
                try; ch.FontColor       = theme.ForegroundColor; catch; end

            case 'matlab.ui.control.CheckBox'
                % CheckBox has no BackgroundColor -- it inherits from parent.
                try; ch.FontColor = theme.ForegroundColor; catch; end

            case 'matlab.ui.control.NumericEditField'
                try; ch.BackgroundColor = theme.WidgetBackground; catch; end
                try; ch.FontColor       = theme.ForegroundColor; catch; end

            case 'matlab.ui.control.StateButton'
                try; ch.BackgroundColor = theme.WidgetBorderColor; catch; end
                try; ch.FontColor       = theme.ForegroundColor; catch; end

            case 'matlab.ui.control.ToggleButton'
                try; ch.BackgroundColor = theme.WidgetBorderColor; catch; end
                try; ch.FontColor       = theme.ForegroundColor; catch; end

            case 'matlab.ui.control.RadioButton'
                % RadioButton has no BackgroundColor -- it inherits from parent.
                try; ch.FontColor = theme.ForegroundColor; catch; end

            case 'matlab.ui.control.Table'
                try; ch.ForegroundColor = theme.ForegroundColor; catch; end
                try; ch.BackgroundColor = tableBg; catch; end

            otherwise
                % Unknown widget type → skip silently (do not throw).
        end
    end
end
