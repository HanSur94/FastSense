classdef CompanionTimeBar < handle
%COMPANIONTIMEBAR Inline toolbar time-range control for FastSenseCompanion.
%
%   Owns the 'CompanionTimeRangeBtn' uidropdown in the companion toolbar's
%   col-9 flex slot. The dropdown lists quick presets (Last 24 hours …
%   All data) that apply immediately, plus a 'Custom…' item that reveals an
%   inline relative/absolute editor strip *inside the companion window* — an
%   overlay panel just under the toolbar, NOT a separate figure or modal.
%
%   The Custom strip opens on the Absolute tab by default so a date can be
%   typed/picked directly; a Relative tab (N + unit) is one click away.
%
%   All edits flow through the shared CompanionTimeRange handle passed at
%   construction — this class calls setRelative/setAbsolute/setAll on it;
%   the CompanionTimeRange fires RangeChanged; the companion listens.
%   CompanionTimeBar NEVER fires RangeChanged directly.
%
%   Usage:
%     bar = CompanionTimeBar(hToolbarGrid, 9, timeRange, theme, app)
%     bar.refreshButton()     % sync dropdown Value + accent from TimeRange_
%     bar.openPicker()        % reveal the inline Custom editor strip
%     bar.setTheme(newTheme)
%     bar.close()             % dismiss the Custom strip (no-op if closed)
%     delete(bar)             % full teardown
%
%   Constructor:
%     bar = CompanionTimeBar(parentGrid, col, timeRange, theme, app)
%       parentGrid  — companion hToolbarGrid (uigridlayout)
%       col         — 9 (the '1x' flex spacer column)
%       timeRange   — CompanionTimeRange handle (shared source of truth)
%       theme       — resolved CompanionTheme struct
%       app         — FastSenseCompanion handle (for hFig_ overlay + uialert)
%
%   Public methods:
%     openPicker()            — reveal the inline Custom relative/absolute strip
%     refreshButton()         — sync dropdown Value + BackgroundColor from TimeRange_
%     setTheme(theme)         — restyle dropdown (and open strip) to new theme
%     close()                 — delete the Custom strip; no-op on the dropdown
%     delete()                — full teardown
%
%   See also CompanionTimeRange, FastSenseCompanion, CompanionSettingsDialog.

    properties (Access = private)
        hDropdown_        = []    % toolbar uidropdown (Tag 'CompanionTimeRangeBtn') — inline preset selector
        TimeRange_        = []    % CompanionTimeRange handle (shared; NOT owned)
        Theme_            = []    % resolved CompanionTheme struct
        App_              = []    % FastSenseCompanion handle
        Listeners_        = {}    % all addlistener returns; deleted in delete()
        ActiveMode_       = 'Absolute'   % 'Relative' | 'Absolute' (active tab in the Custom strip)
        % Inline Custom strip (overlay uipanel on the companion figure; NOT a separate window)
        hStrip_           = []
        % Custom-strip Relative/Absolute toggle handles
        hTabRelative_     = []
        hTabAbsolute_     = []
        % Mode panel handles (parented into the Custom strip's panel host)
        hPanelRelative_   = []
        hPanelAbsolute_   = []
        % Action row
        hApplyBtn_        = []
        hCancelBtn_       = []
        % Relative-panel controls (populated by buildRelativePanel_)
        hRelSpinner_      = []
        hRelDropdown_     = []
        hRelPreview_      = []
        % Absolute-panel controls (populated by buildAbsolutePanel_)
        hAbsStartPicker_  = []
        hAbsEndPicker_    = []
        hAbsPreview_      = []
    end

    methods (Access = public)

        function obj = CompanionTimeBar(parentGrid, col, timeRange, theme, app)
        %COMPANIONTIMEBAR Build the range dropdown into parentGrid at col.
            obj.TimeRange_ = timeRange;
            obj.Theme_     = theme;
            obj.App_       = app;

            t = theme;

            % Build the inline toolbar range dropdown (no separate window).
            % Selecting a preset applies it immediately via the shared
            % CompanionTimeRange; the 'Custom…' item reveals an inline
            % relative/absolute editor strip under the bar.
            obj.hDropdown_ = uidropdown(parentGrid);
            obj.hDropdown_.Layout.Row    = 1;
            obj.hDropdown_.Layout.Column = col;
            obj.hDropdown_.Items         = [obj.presetLabels_(), {obj.customLabel_()}];
            obj.hDropdown_.FontSize      = 11;
            obj.hDropdown_.FontWeight    = 'bold';
            obj.hDropdown_.FontColor     = t.ForegroundColor;
            obj.hDropdown_.Tag           = 'CompanionTimeRangeBtn';
            obj.hDropdown_.Tooltip       = 'Set the global time range for all companion-opened views';
            obj.hDropdown_.ValueChangedFcn = @(s,~) obj.onDropdownChanged_(s.Value);

            obj.refreshButton();
        end

        function openPicker(obj)
        %OPENPICKER Reveal the inline Custom relative/absolute editor strip.
        %   The strip is an overlay panel inside the companion window (under the
        %   toolbar) — NOT a separate figure. Re-calling focuses the open strip.
            try
                obj.openCustomStrip_();
            catch ME
                try
                    if ~isempty(obj.App_) && isvalid(obj.App_) && ...
                            ~isempty(obj.App_.hFig_) && isvalid(obj.App_.hFig_)
                        uialert(obj.App_.hFig_, ME.message, 'Time Range Error');
                    end
                catch
                end
            end
        end

        function refreshButton(obj)
        %REFRESHBUTTON Sync dropdown selection + BackgroundColor from TimeRange_.
        %   A preset range selects the matching item; a non-preset (custom)
        %   range is shown as a transient first item so the label stays visible.
        %   The 'Custom…' editor item is always appended last.
            if isempty(obj.hDropdown_) || ~isvalid(obj.hDropdown_); return; end
            try
                lbl    = obj.TimeRange_.label();
                base   = obj.presetLabels_();
                custom = obj.customLabel_();
                if any(strcmp(lbl, base))
                    obj.hDropdown_.Items = [base, {custom}];
                else
                    % Non-preset (custom) range: show its label as a transient
                    % leading item so it stays visible alongside the presets.
                    obj.hDropdown_.Items = [{lbl}, base, {custom}];
                end
                obj.hDropdown_.Value = lbl;
                if obj.TimeRange_.isDefault()
                    obj.hDropdown_.BackgroundColor = obj.Theme_.WidgetBorderColor;
                else
                    obj.hDropdown_.BackgroundColor = obj.Theme_.Accent;
                end
            catch
            end
        end

        function setTheme(obj, theme)
        %SETTHEME Restyle the dropdown (and open Custom strip if valid) to a new theme.
            obj.Theme_ = theme;
            t = theme;
            if ~isempty(obj.hDropdown_) && isvalid(obj.hDropdown_)
                try
                    obj.hDropdown_.FontColor = t.ForegroundColor;
                    obj.refreshButton();
                catch
                end
            end
            if ~isempty(obj.hStrip_) && isvalid(obj.hStrip_)
                try
                    obj.hStrip_.BackgroundColor = t.DashboardBackground;
                    applyThemeToChildren_(obj.hStrip_, t);
                    % Re-assert Accent on the active mode tab and Apply.
                    obj.switchMode_(obj.ActiveMode_);
                catch
                end
            end
        end

        function close(obj)
        %CLOSE Delete the inline Custom strip if open. Does NOT delete the dropdown.
            if ~isempty(obj.hStrip_) && isvalid(obj.hStrip_)
                try
                    delete(obj.hStrip_);
                catch
                end
            end
            obj.hStrip_ = [];
        end

        function delete(obj)
        %DELETE Handle-class destructor — deletes listeners, closes strip, deletes dropdown.
            for ii = 1:numel(obj.Listeners_)
                try
                    lh = obj.Listeners_{ii};
                    if isobject(lh) && isvalid(lh)
                        delete(lh);
                    end
                catch
                end
            end
            obj.Listeners_ = {};
            obj.close();
            if ~isempty(obj.hDropdown_) && isvalid(obj.hDropdown_)
                try
                    delete(obj.hDropdown_);
                catch
                end
            end
            obj.hDropdown_ = [];
        end

    end

    methods (Access = private)

        function labels = presetLabels_(~)
        %PRESETLABELS_ Inline-dropdown preset item labels (order matters).
            labels = {'Last 24 hours', 'Last 7 days', 'Last 30 days', ...
                      'Last 90 days', 'Last 1 year', 'All data'};
        end

        function s = customLabel_(~)
        %CUSTOMLABEL_ Label of the dropdown item that opens the Custom editor strip.
            s = ['Custom', char(8230)];   % 'Custom…'
        end

        function onDropdownChanged_(obj, val)
        %ONDROPDOWNCHANGED_ Apply the chosen preset, or open the Custom strip.
        %   Presets map to a CompanionTimeRange edit (fires RangeChanged so the
        %   companion re-queries open views). 'Custom…' reveals the inline editor.
            try
                if strcmp(val, obj.customLabel_())
                    obj.openCustomStrip_();
                    return;
                end
                switch val
                    case 'Last 24 hours', obj.applyPresetRelative_(24, 'hours');
                    case 'Last 7 days',   obj.applyPresetRelative_(7,  'days');
                    case 'Last 30 days',  obj.applyPresetRelative_(30, 'days');
                    case 'Last 90 days',  obj.applyPresetRelative_(90, 'days');
                    case 'Last 1 year',   obj.applyPresetRelative_(1,  'years');
                    case 'All data',      obj.applyPresetAll_();
                    otherwise
                        % Transient custom-range label re-selected, or unknown: no-op.
                end
            catch ME
                try
                    if ~isempty(obj.App_) && isvalid(obj.App_) && ...
                            ~isempty(obj.App_.hFig_) && isvalid(obj.App_.hFig_)
                        uialert(obj.App_.hFig_, ME.message, 'Time Range Error');
                    end
                catch
                end
            end
        end

        % ----------------------------------------------------------------
        %  Inline Custom strip (overlay panel; no separate window)
        % ----------------------------------------------------------------

        function openCustomStrip_(obj)
        %OPENCUSTOMSTRIP_ Build the Custom strip, or focus it if already open.
            if ~isempty(obj.hStrip_) && isvalid(obj.hStrip_)
                try
                    uistack(obj.hStrip_, 'top');
                catch
                end
                return;
            end
            obj.buildCustomStrip_();
        end

        function buildCustomStrip_(obj)
        %BUILDCUSTOMSTRIP_ Build the inline Custom editor strip as an overlay panel.
        %   Parented to the companion figure (NOT a separate window), positioned
        %   just under the toolbar. Hosts a Relative/Absolute toggle, the matching
        %   builder panel, a live preview, and Apply/Cancel. Seeded from the
        %   current range; opens on the Absolute tab by default for direct date entry.
            hFig = obj.hostFigure_();
            if isempty(hFig) || ~isvalid(hFig)
                error('CompanionTimeBar:noFigure', ...
                    'Cannot open the time-range editor: host figure unavailable.');
            end
            t = obj.Theme_;

            stripW = 400;
            stripH = 220;
            pos = obj.customStripPosition_(hFig.Position, stripW, stripH);

            obj.hStrip_ = uipanel(hFig);
            obj.hStrip_.Units           = 'pixels';
            obj.hStrip_.Position        = pos;
            obj.hStrip_.BackgroundColor = t.DashboardBackground;
            obj.hStrip_.BorderType      = 'line';
            obj.hStrip_.Tag             = 'CompanionTimeRangeStrip';
            try
                obj.hStrip_.BorderColor = t.Accent;
                obj.hStrip_.BorderWidth = 1;
            catch
            end
            try
                uistack(obj.hStrip_, 'top');
            catch
            end

            % Root [3 1] grid: toggle row / panel host / action row.
            gRoot = uigridlayout(obj.hStrip_, [3 1]);
            gRoot.RowHeight     = {28, '1x', 32};
            gRoot.ColumnWidth   = {'1x'};
            gRoot.Padding       = [12 12 12 12];
            gRoot.RowSpacing    = 10;
            gRoot.ColumnSpacing = 0;
            gRoot.BackgroundColor = t.DashboardBackground;

            % Row 1: Relative / Absolute toggle.
            gTabs = uigridlayout(gRoot, [1 2]);
            gTabs.Layout.Row    = 1;
            gTabs.Layout.Column = 1;
            gTabs.RowHeight     = {'1x'};
            gTabs.ColumnWidth   = {'1x', '1x'};
            gTabs.Padding       = [0 0 0 0];
            gTabs.ColumnSpacing = 4;
            gTabs.BackgroundColor = t.DashboardBackground;

            obj.hTabRelative_ = uibutton(gTabs, 'push');
            obj.hTabRelative_.Layout.Row    = 1;
            obj.hTabRelative_.Layout.Column = 1;
            obj.hTabRelative_.Text          = 'Relative';
            obj.hTabRelative_.FontSize      = 11;
            obj.hTabRelative_.FontWeight    = 'bold';
            obj.hTabRelative_.FontColor     = t.ForegroundColor;
            obj.hTabRelative_.ButtonPushedFcn = @(~,~) obj.onTabRelative_();

            obj.hTabAbsolute_ = uibutton(gTabs, 'push');
            obj.hTabAbsolute_.Layout.Row    = 1;
            obj.hTabAbsolute_.Layout.Column = 2;
            obj.hTabAbsolute_.Text          = 'Absolute';
            obj.hTabAbsolute_.FontSize      = 11;
            obj.hTabAbsolute_.FontWeight    = 'bold';
            obj.hTabAbsolute_.FontColor     = t.ForegroundColor;
            obj.hTabAbsolute_.ButtonPushedFcn = @(~,~) obj.onTabAbsolute_();

            % Row 2: panel host (Relative + Absolute built in; Visible toggled).
            gPanelHost = uigridlayout(gRoot, [1 1]);
            gPanelHost.Layout.Row    = 2;
            gPanelHost.Layout.Column = 1;
            gPanelHost.RowHeight     = {'1x'};
            gPanelHost.ColumnWidth   = {'1x'};
            gPanelHost.Padding       = [0 0 0 0];
            gPanelHost.RowSpacing    = 0;
            gPanelHost.BackgroundColor = t.DashboardBackground;

            % Build both mode panels into the SAME host cell (1,1) so they
            % overlap (visibility-toggled) and each gets the full host height.
            % Without an explicit Layout, a [1 1] uigridlayout auto-expands to
            % [2 1] and stacks the two panels, squishing/clipping their controls.
            obj.buildRelativePanel_(gPanelHost);
            obj.hPanelRelative_.Layout.Row    = 1;
            obj.hPanelRelative_.Layout.Column = 1;
            obj.buildAbsolutePanel_(gPanelHost);
            obj.hPanelAbsolute_.Layout.Row    = 1;
            obj.hPanelAbsolute_.Layout.Column = 1;

            % Row 3: action row (Apply / Cancel).
            gAction = uigridlayout(gRoot, [1 2]);
            gAction.Layout.Row    = 3;
            gAction.Layout.Column = 1;
            gAction.RowHeight     = {'1x'};
            gAction.ColumnWidth   = {'1x', '1x'};
            gAction.Padding       = [0 0 0 0];
            gAction.ColumnSpacing = 8;
            gAction.BackgroundColor = t.DashboardBackground;

            obj.hApplyBtn_ = uibutton(gAction, 'push');
            obj.hApplyBtn_.Layout.Row    = 1;
            obj.hApplyBtn_.Layout.Column = 1;
            obj.hApplyBtn_.Text          = 'Apply';
            obj.hApplyBtn_.FontSize      = 11;
            obj.hApplyBtn_.FontWeight    = 'bold';
            obj.hApplyBtn_.BackgroundColor = t.Accent;
            obj.hApplyBtn_.FontColor       = t.ForegroundColor;
            obj.hApplyBtn_.ButtonPushedFcn = @(~,~) obj.onApply_();

            obj.hCancelBtn_ = uibutton(gAction, 'push');
            obj.hCancelBtn_.Layout.Row    = 1;
            obj.hCancelBtn_.Layout.Column = 2;
            obj.hCancelBtn_.Text          = 'Cancel';
            obj.hCancelBtn_.FontSize      = 11;
            obj.hCancelBtn_.FontWeight    = 'bold';
            obj.hCancelBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.hCancelBtn_.FontColor       = t.ForegroundColor;
            obj.hCancelBtn_.ButtonPushedFcn = @(~,~) obj.closeStrip_();

            % Apply theme to all controls, then seed from the current range and
            % reveal the chosen mode (switchMode_ re-asserts tab + Apply accents).
            try
                applyThemeToChildren_(obj.hStrip_, t);
            catch
            end
            obj.seedCustomFromRange_();
            obj.switchMode_(obj.initialCustomMode_());
        end

        function closeStrip_(obj)
        %CLOSESTRIP_ Cancel the Custom strip: delete it and restore the dropdown label.
            obj.close();
            obj.refreshButton();
        end

        function pos = customStripPosition_(~, figPos, stripW, stripH)
        %CUSTOMSTRIPPOSITION_ Pixel Position for the overlay strip under the toolbar.
        %   Right-aligned beneath the toolbar dropdown/gear; clamped to stay
        %   on-figure. figPos is the companion figure [x y w h]; the returned
        %   Position is relative to the figure's lower-left corner (Units 'pixels').
            w = figPos(3);
            h = figPos(4);
            % Right margin: hLayout right pad (24) + gear col (36) + spacing (8) = 68.
            left = w - 68 - stripW;
            % Top: hLayout top pad (24) + toolbar row (32) + small gap (2) = 58.
            bottom = h - 58 - stripH;
            left   = max(8, left);
            bottom = max(8, bottom);
            pos = [left, bottom, stripW, stripH];
        end

        function f = hostFigure_(obj)
        %HOSTFIGURE_ The uifigure that hosts the toolbar dropdown (and the strip).
        %   Derived from the dropdown's ancestor so the strip overlays whatever
        %   figure the toolbar lives in; falls back to the app's hFig_.
            f = [];
            try
                if ~isempty(obj.hDropdown_) && isvalid(obj.hDropdown_)
                    f = ancestor(obj.hDropdown_, 'figure');
                end
            catch
            end
            if isempty(f) || ~isvalid(f)
                try
                    if ~isempty(obj.App_) && isvalid(obj.App_)
                        f = obj.App_.hFig_;
                    end
                catch
                end
            end
        end

        function mode = initialCustomMode_(obj)
        %INITIALCUSTOMMODE_ Pick the Custom strip's opening tab.
        %   Absolute by default (direct date entry); Relative only when the
        %   current range is a *non-preset* relative window, so the user sees
        %   their own custom relative setting on reopen.
            mode = 'Absolute';
            try
                s = obj.TimeRange_.toStruct();
                if strcmp(s.type, 'relative') && ~obj.isPresetRelative_(s.N, s.unit)
                    mode = 'Relative';
                end
            catch
            end
        end

        function tf = isPresetRelative_(~, N, unit)
        %ISPRESETRELATIVE_ True if (N, unit) matches one of the quick relative presets.
            presets = {24, 'hours'; 7, 'days'; 30, 'days'; 90, 'days'; 1, 'years'};
            tf = false;
            for k = 1:size(presets, 1)
                if N == presets{k, 1} && strcmp(unit, presets{k, 2})
                    tf = true;
                    return;
                end
            end
        end

        function seedCustomFromRange_(obj)
        %SEEDCUSTOMFROMRANGE_ Pre-fill the Relative/Absolute controls from TimeRange_.
        %   Relative spec -> spinner N + unit dropdown; absolute spec -> date
        %   pickers. Non-matching specs keep the builder defaults. Best-effort.
            try
                s = obj.TimeRange_.toStruct();
                if strcmp(s.type, 'relative')
                    if ~isempty(obj.hRelSpinner_) && isvalid(obj.hRelSpinner_)
                        obj.hRelSpinner_.Value = max(1, round(s.N));
                    end
                    if ~isempty(obj.hRelDropdown_) && isvalid(obj.hRelDropdown_) && ...
                            any(strcmp(s.unit, obj.hRelDropdown_.Items))
                        obj.hRelDropdown_.Value = s.unit;
                    end
                elseif strcmp(s.type, 'absolute') && ~isempty(s.t0) && ~isempty(s.t1)
                    if ~isempty(obj.hAbsStartPicker_) && isvalid(obj.hAbsStartPicker_)
                        obj.hAbsStartPicker_.Value = datetime(s.t0, 'ConvertFrom', 'datenum');
                    end
                    if ~isempty(obj.hAbsEndPicker_) && isvalid(obj.hAbsEndPicker_)
                        obj.hAbsEndPicker_.Value = datetime(s.t1, 'ConvertFrom', 'datenum');
                    end
                end
                obj.updateRelPreview_();
                obj.updateAbsPreview_();
            catch
            end
        end

        function buildRelativePanel_(obj, parent)
        %BUILDRELATIVEPANEL_ Build the Relative builder panel.
        %   [1x3] control row: uispinner N, spacer, uidropdown unit.
        %   Below: a read-only preview uilabel showing resolved date range.
        %   Spinner/dropdown ValueChangedFcn -> update preview live (no commit).
            t = obj.Theme_;

            % Container grid: 3 rows x 3 columns.
            obj.hPanelRelative_ = uigridlayout(parent, [3 3]);
            obj.hPanelRelative_.RowHeight     = {32, 32, '1x'};
            obj.hPanelRelative_.ColumnWidth   = {60, '1x', 120};
            obj.hPanelRelative_.Padding       = [0 0 0 0];
            obj.hPanelRelative_.RowSpacing    = 8;
            obj.hPanelRelative_.ColumnSpacing = 8;
            obj.hPanelRelative_.BackgroundColor = t.DashboardBackground;
            obj.hPanelRelative_.Visible         = 'off';

            % Row 1: labels — "Last" (col 1) ... "until now" (col 3).
            lbLast = uilabel(obj.hPanelRelative_);
            lbLast.Layout.Row    = 1;
            lbLast.Layout.Column = 1;
            lbLast.Text          = 'Last';
            lbLast.FontSize      = 11;
            lbLast.FontColor     = t.ForegroundColor;

            lbUntil = uilabel(obj.hPanelRelative_);
            lbUntil.Layout.Row    = 1;
            lbUntil.Layout.Column = 3;
            lbUntil.Text          = 'until now';
            lbUntil.FontSize      = 11;
            lbUntil.FontColor     = t.ForegroundColor;

            % Row 2: controls — uispinner (col 1) + uidropdown (col 3).
            obj.hRelSpinner_ = uispinner(obj.hPanelRelative_);
            obj.hRelSpinner_.Layout.Row    = 2;
            obj.hRelSpinner_.Layout.Column = 1;
            obj.hRelSpinner_.Limits        = [1 9999];
            obj.hRelSpinner_.Step          = 1;
            obj.hRelSpinner_.Value         = 7;
            obj.hRelSpinner_.RoundFractionalValues = 'on';
            obj.hRelSpinner_.ValueChangedFcn = @(~,~) obj.updateRelPreview_();

            obj.hRelDropdown_ = uidropdown(obj.hPanelRelative_);
            obj.hRelDropdown_.Layout.Row    = 2;
            obj.hRelDropdown_.Layout.Column = 3;
            obj.hRelDropdown_.Items         = {'hours', 'days', 'weeks', 'months', 'years'};
            obj.hRelDropdown_.Value         = 'days';
            obj.hRelDropdown_.ValueChangedFcn = @(~,~) obj.updateRelPreview_();

            % Row 3: read-only preview label — "YYYY-MM-DD to YYYY-MM-DD".
            obj.hRelPreview_ = uilabel(obj.hPanelRelative_);
            obj.hRelPreview_.Layout.Row    = 3;
            obj.hRelPreview_.Layout.Column = [1 3];
            obj.hRelPreview_.FontSize      = 11;
            obj.hRelPreview_.FontColor     = t.PlaceholderTextColor;
            obj.hRelPreview_.Text          = '';

            % Seed the preview with the current spinner/dropdown values.
            obj.updateRelPreview_();
        end

        function buildAbsolutePanel_(obj, parent)
        %BUILDABSOLUTEPANEL_ Build the Absolute date-picker panel.
        %   [3x2] grid: Start label+uidatepicker, End label+uidatepicker,
        %   and a preview/validation uilabel.
        %   Picker ValueChangedFcn -> recompute day count + run validation live.
        %   Validation: start >= end -> disable Apply + show alarm text.
            t = obj.Theme_;

            obj.hPanelAbsolute_ = uigridlayout(parent, [3 2]);
            obj.hPanelAbsolute_.RowHeight     = {32, 32, '1x'};
            obj.hPanelAbsolute_.ColumnWidth   = {80, '1x'};
            obj.hPanelAbsolute_.Padding       = [0 0 0 0];
            obj.hPanelAbsolute_.RowSpacing    = 8;
            obj.hPanelAbsolute_.ColumnSpacing = 8;
            obj.hPanelAbsolute_.BackgroundColor = t.DashboardBackground;
            obj.hPanelAbsolute_.Visible         = 'off';

            % Row 1: Start label + uidatepicker.
            lbStart = uilabel(obj.hPanelAbsolute_);
            lbStart.Layout.Row    = 1;
            lbStart.Layout.Column = 1;
            lbStart.Text          = 'Start';
            lbStart.FontSize      = 11;
            lbStart.FontColor     = t.ForegroundColor;

            obj.hAbsStartPicker_ = uidatepicker(obj.hPanelAbsolute_);
            obj.hAbsStartPicker_.Layout.Row    = 1;
            obj.hAbsStartPicker_.Layout.Column = 2;
            obj.hAbsStartPicker_.Value         = datetime('today') - caldays(7);
            obj.hAbsStartPicker_.ValueChangedFcn = @(~,~) obj.updateAbsPreview_();

            % Row 2: End label + uidatepicker.
            lbEnd = uilabel(obj.hPanelAbsolute_);
            lbEnd.Layout.Row    = 2;
            lbEnd.Layout.Column = 1;
            lbEnd.Text          = 'End';
            lbEnd.FontSize      = 11;
            lbEnd.FontColor     = t.ForegroundColor;

            obj.hAbsEndPicker_ = uidatepicker(obj.hPanelAbsolute_);
            obj.hAbsEndPicker_.Layout.Row    = 2;
            obj.hAbsEndPicker_.Layout.Column = 2;
            obj.hAbsEndPicker_.Value         = datetime('today');
            obj.hAbsEndPicker_.ValueChangedFcn = @(~,~) obj.updateAbsPreview_();

            % Row 3: preview / validation label.
            % Normal: "N days" in PlaceholderTextColor.
            % Invalid: "Invalid: start must be before end" in StatusAlarmColor.
            obj.hAbsPreview_ = uilabel(obj.hPanelAbsolute_);
            obj.hAbsPreview_.Layout.Row    = 3;
            obj.hAbsPreview_.Layout.Column = [1 2];
            obj.hAbsPreview_.FontSize      = 11;
            obj.hAbsPreview_.FontColor     = t.PlaceholderTextColor;
            obj.hAbsPreview_.Text          = '';

            obj.updateAbsPreview_();
        end

        function switchMode_(obj, mode)
        %SWITCHMODE_ Show the active mode panel; repaint the Relative/Absolute toggle.
            obj.ActiveMode_ = mode;
            t = obj.Theme_;

            % Toggle panels.
            if ~isempty(obj.hPanelRelative_) && isvalid(obj.hPanelRelative_)
                obj.hPanelRelative_.Visible = 'off';
            end
            if ~isempty(obj.hPanelAbsolute_) && isvalid(obj.hPanelAbsolute_)
                obj.hPanelAbsolute_.Visible = 'off';
            end

            switch mode
                case 'Relative'
                    if ~isempty(obj.hPanelRelative_) && isvalid(obj.hPanelRelative_)
                        obj.hPanelRelative_.Visible = 'on';
                    end
                case 'Absolute'
                    if ~isempty(obj.hPanelAbsolute_) && isvalid(obj.hPanelAbsolute_)
                        obj.hPanelAbsolute_.Visible = 'on';
                    end
            end

            % Repaint toggle backgrounds (Accent for active, WidgetBorderColor for inactive).
            tabs  = {obj.hTabRelative_, obj.hTabAbsolute_};
            names = {'Relative', 'Absolute'};
            for k = 1:2
                if ~isempty(tabs{k}) && isvalid(tabs{k})
                    if strcmp(names{k}, mode)
                        tabs{k}.BackgroundColor = t.Accent;
                    else
                        tabs{k}.BackgroundColor = t.WidgetBorderColor;
                    end
                end
            end

            % Apply is always available in the Custom strip; re-assert accent.
            if ~isempty(obj.hApplyBtn_) && isvalid(obj.hApplyBtn_)
                obj.hApplyBtn_.Visible         = 'on';
                obj.hApplyBtn_.BackgroundColor = t.Accent;
            end

            % Re-run validation for the now-visible Absolute panel (toggles Apply.Enable).
            if strcmp(mode, 'Absolute')
                obj.updateAbsPreview_();
            elseif ~isempty(obj.hApplyBtn_) && isvalid(obj.hApplyBtn_)
                obj.hApplyBtn_.Enable = 'on';
            end
        end

        % ----------------------------------------------------------------
        %  Quick preset helpers
        % ----------------------------------------------------------------

        function applyPresetRelative_(obj, N, unit)
        %APPLYPRESETRELATIVE_ One-click relative preset commit + close strip.
            try
                obj.TimeRange_.setRelative(N, unit);
                obj.refreshButton();
                obj.close();
            catch ME
                try
                    if ~isempty(obj.App_) && isvalid(obj.App_) && ...
                            ~isempty(obj.App_.hFig_) && isvalid(obj.App_.hFig_)
                        uialert(obj.App_.hFig_, ME.message, 'Time Range Error');
                    end
                catch
                end
            end
        end

        function applyPresetAll_(obj)
        %APPLYPRESETALL_ One-click All data preset commit + close strip.
            try
                obj.TimeRange_.setAll();
                obj.refreshButton();
                obj.close();
            catch ME
                try
                    if ~isempty(obj.App_) && isvalid(obj.App_) && ...
                            ~isempty(obj.App_.hFig_) && isvalid(obj.App_.hFig_)
                        uialert(obj.App_.hFig_, ME.message, 'Time Range Error');
                    end
                catch
                end
            end
        end

        % ----------------------------------------------------------------
        %  Tab callbacks
        % ----------------------------------------------------------------

        function onTabRelative_(obj)
        %ONTABRELATIVE_ Mode tab callback.
            try
                obj.switchMode_('Relative');
            catch ME
                try
                    if ~isempty(obj.App_) && isvalid(obj.App_) && ...
                            ~isempty(obj.App_.hFig_) && isvalid(obj.App_.hFig_)
                        uialert(obj.App_.hFig_, ME.message, 'Time Range Error');
                    end
                catch
                end
            end
        end

        function onTabAbsolute_(obj)
        %ONTABABSOLUTE_ Mode tab callback.
            try
                obj.switchMode_('Absolute');
            catch ME
                try
                    if ~isempty(obj.App_) && isvalid(obj.App_) && ...
                            ~isempty(obj.App_.hFig_) && isvalid(obj.App_.hFig_)
                        uialert(obj.App_.hFig_, ME.message, 'Time Range Error');
                    end
                catch
                end
            end
        end

        % ----------------------------------------------------------------
        %  Apply dispatch
        % ----------------------------------------------------------------

        function onApply_(obj)
        %ONAPPLY_ Dispatch Apply to the active mode's commit path.
            try
                switch obj.ActiveMode_
                    case 'Relative'
                        obj.commitRelative_();
                    case 'Absolute'
                        obj.commitAbsolute_();
                    otherwise
                        % Defensive no-op.
                end
            catch ME
                try
                    if ~isempty(obj.App_) && isvalid(obj.App_) && ...
                            ~isempty(obj.App_.hFig_) && isvalid(obj.App_.hFig_)
                        uialert(obj.App_.hFig_, ME.message, 'Time Range Error');
                    end
                catch
                end
            end
        end

        function commitRelative_(obj)
        %COMMITRELATIVE_ Commit the Relative panel state and close the strip.
            N    = obj.hRelSpinner_.Value;
            unit = obj.hRelDropdown_.Value;
            obj.TimeRange_.setRelative(N, unit);
            obj.refreshButton();
            obj.close();
        end

        function commitAbsolute_(obj)
        %COMMITABSOLUTE_ Commit the Absolute panel state and close (if valid).
            t0 = datenum(obj.hAbsStartPicker_.Value);
            t1 = datenum(obj.hAbsEndPicker_.Value);
            if t0 >= t1
                % Validation failed — Apply was already disabled by updateAbsPreview_,
                % but guard here anyway.
                return;
            end
            obj.TimeRange_.setAbsolute(t0, t1);
            obj.refreshButton();
            obj.close();
        end

        % ----------------------------------------------------------------
        %  Live-preview updaters
        % ----------------------------------------------------------------

        function updateRelPreview_(obj)
        %UPDATERELPREVIEW_ Recompute and display the relative range preview label.
            try
                if isempty(obj.hRelPreview_) || ~isvalid(obj.hRelPreview_); return; end
                N    = obj.hRelSpinner_.Value;
                unit = obj.hRelDropdown_.Value;
                asDays = obj.relToDays_(N, unit);
                t1 = now();
                t0 = t1 - asDays;
                obj.hRelPreview_.Text = sprintf('%s to %s', ...
                    datestr(t0, 'yyyy-mm-dd'), datestr(t1, 'yyyy-mm-dd'));
            catch
            end
        end

        function updateAbsPreview_(obj)
        %UPDATEABSPREVIEW_ Recompute and display the absolute range preview label; validate.
            try
                if isempty(obj.hAbsPreview_) || ~isvalid(obj.hAbsPreview_); return; end
                t = obj.Theme_;
                t0 = datenum(obj.hAbsStartPicker_.Value);
                t1 = datenum(obj.hAbsEndPicker_.Value);
                if t0 >= t1
                    obj.hAbsPreview_.Text      = 'Invalid: start must be before end';
                    obj.hAbsPreview_.FontColor = t.StatusAlarmColor;
                    if ~isempty(obj.hApplyBtn_) && isvalid(obj.hApplyBtn_)
                        obj.hApplyBtn_.Enable = 'off';
                    end
                else
                    nDays = round(t1 - t0);
                    obj.hAbsPreview_.Text      = sprintf('%d days', nDays);
                    obj.hAbsPreview_.FontColor = t.PlaceholderTextColor;
                    if ~isempty(obj.hApplyBtn_) && isvalid(obj.hApplyBtn_)
                        obj.hApplyBtn_.Enable = 'on';
                    end
                end
            catch
            end
        end

        function d = relToDays_(~, N, unit)
        %RELTDAYS_ Convert relative N + unit to fractional days. Mirrors CompanionTimeRange.
            switch unit
                case 'hours',  d = N / 24;
                case 'days',   d = N;
                case 'weeks',  d = N * 7;
                case 'months', d = N * 30;
                case 'years',  d = N * 365;
                otherwise,     d = N;
            end
        end

    end

end
