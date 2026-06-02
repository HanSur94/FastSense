classdef CompanionTimeBar < handle
%COMPANIONTIMEBAR Toolbar range button + singleton picker popup for FastSenseCompanion.
%
%   Owns the 'CompanionTimeRangeBtn' uibutton in the companion toolbar's
%   col-9 flex spacer, and a singleton 400x280 uifigure picker with three
%   modes: Quick presets, Relative builder, Absolute date pickers.
%
%   All edits flow through the shared CompanionTimeRange handle passed at
%   construction — this class calls setRelative/setAbsolute/setAll on it;
%   the CompanionTimeRange fires RangeChanged; the companion listens.
%   CompanionTimeBar NEVER fires RangeChanged directly.
%
%   Usage:
%     bar = CompanionTimeBar(hToolbarGrid, 9, timeRange, theme, app)
%     bar.refreshButton()
%     bar.openPicker()
%     bar.setTheme(newTheme)
%     bar.close()     % close popup only
%     delete(bar)     % full teardown
%
%   Constructor:
%     bar = CompanionTimeBar(parentGrid, col, timeRange, theme, app)
%       parentGrid  — companion hToolbarGrid (uigridlayout)
%       col         — 9 (the '1x' flex spacer column)
%       timeRange   — CompanionTimeRange handle (shared source of truth)
%       theme       — resolved CompanionTheme struct
%       app         — FastSenseCompanion handle (for uialert + applyThemeToChildren_)
%
%   Public methods:
%     openPicker()            — open or focus the picker popup
%     refreshButton()         — sync button Text + BackgroundColor from TimeRange_
%     setTheme(theme)         — restyle button (and open popup) to new theme
%     close()                 — delete popup; no-op on button
%     delete()                — full teardown
%
%   See also CompanionTimeRange, FastSenseCompanion, CompanionSettingsDialog.

    properties (Access = private)
        hBtn_             = []    % toolbar uibutton (Tag 'CompanionTimeRangeBtn')
        hPopup_           = []    % picker uifigure ([] when closed)
        TimeRange_        = []    % CompanionTimeRange handle (shared; NOT owned)
        Theme_            = []    % resolved CompanionTheme struct
        App_              = []    % FastSenseCompanion handle
        Listeners_        = {}    % all addlistener returns; deleted in delete()
        ActiveMode_       = 'Quick'   % 'Quick' | 'Relative' | 'Absolute'
        % Tab strip handles
        hTabQuick_        = []
        hTabRelative_     = []
        hTabAbsolute_     = []
        % Mode panel handles (parented into the mode-host row of the popup grid)
        hPanelQuick_      = []
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
        %COMPANIONTIMEBAR Build the range button into parentGrid at col.
            obj.TimeRange_ = timeRange;
            obj.Theme_     = theme;
            obj.App_       = app;

            t = theme;

            % Build the toolbar range button.
            obj.hBtn_ = uibutton(parentGrid, 'push');
            obj.hBtn_.Layout.Row    = 1;
            obj.hBtn_.Layout.Column = col;
            obj.hBtn_.FontSize      = 11;
            obj.hBtn_.FontWeight    = 'bold';
            obj.hBtn_.FontColor     = t.ForegroundColor;
            obj.hBtn_.Tag           = 'CompanionTimeRangeBtn';
            obj.hBtn_.Tooltip       = 'Set the global time range for all companion-opened views';
            obj.hBtn_.ButtonPushedFcn = @(~,~) obj.openPicker();

            obj.refreshButton();
        end

        function openPicker(obj)
        %OPENPICKER Open the singleton picker popup, or bring the existing one to front.
            if ~isempty(obj.hPopup_) && isvalid(obj.hPopup_)
                figure(obj.hPopup_);
                return;
            end
            try
                obj.buildPopup_();
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
        %REFRESHBUTTON Sync button Text + BackgroundColor from TimeRange_.
            if isempty(obj.hBtn_) || ~isvalid(obj.hBtn_); return; end
            try
                obj.hBtn_.Text = obj.TimeRange_.label();
                if obj.TimeRange_.isDefault()
                    obj.hBtn_.BackgroundColor = obj.Theme_.WidgetBorderColor;
                else
                    obj.hBtn_.BackgroundColor = obj.Theme_.Accent;
                end
            catch
            end
        end

        function setTheme(obj, theme)
        %SETTHEME Restyle the button (and open popup if valid) to a new theme.
            obj.Theme_ = theme;
            t = theme;
            if ~isempty(obj.hBtn_) && isvalid(obj.hBtn_)
                try
                    obj.hBtn_.FontColor = t.ForegroundColor;
                    obj.refreshButton();
                catch
                end
            end
            if ~isempty(obj.hPopup_) && isvalid(obj.hPopup_)
                try
                    obj.hPopup_.Color = t.DashboardBackground;
                    applyThemeToChildren_(obj.hPopup_, t);
                    % Re-assert Accent on the active mode tab and Apply.
                    obj.switchMode_(obj.ActiveMode_);
                catch
                end
            end
        end

        function close(obj)
        %CLOSE Delete the popup uifigure if open. Does NOT delete the button.
            if ~isempty(obj.hPopup_) && isvalid(obj.hPopup_)
                try
                    delete(obj.hPopup_);
                catch
                end
            end
            obj.hPopup_ = [];
        end

        function delete(obj)
        %DELETE Handle-class destructor — deletes listeners, closes popup, deletes button.
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
            if ~isempty(obj.hBtn_) && isvalid(obj.hBtn_)
                try
                    delete(obj.hBtn_);
                catch
                end
            end
            obj.hBtn_ = [];
        end

    end

    methods (Access = private)

        function buildPopup_(obj)
        %BUILDPOPUP_ Build the 400x280 singleton picker uifigure.
            t = obj.Theme_;

            % Position near the companion figure.
            popW = 400;
            popH = 280;
            px = 200;
            py = 200;
            try
                if ~isempty(obj.App_) && isvalid(obj.App_) && ...
                        ~isempty(obj.App_.hFig_) && isvalid(obj.App_.hFig_)
                    fp = obj.App_.hFig_.Position;   % [x y w h]
                    px = fp(1) + floor(fp(3)/2) - floor(popW/2);
                    py = fp(2) + floor(fp(4)/2) - floor(popH/2);
                    % Clamp to screen.
                    mons = get(groot, 'MonitorPositions');
                    sr = mons(1, :);
                    px = max(sr(1), min(sr(1)+sr(3)-popW, px));
                    py = max(sr(2), min(sr(2)+sr(4)-popH, py));
                end
            catch
            end

            % Popup: 400 280 px (width x height per UI-SPEC locked values).
            obj.hPopup_ = uifigure( ...
                'Name',               'Time Range', ...
                'Position',           [px py popW popH], ...
                'Resize',             'off', ...
                'AutoResizeChildren', 'off', ...
                'Color',              t.DashboardBackground);

            % Root [4 1] grid.
            gRoot = uigridlayout(obj.hPopup_, [4 1]);
            gRoot.RowHeight     = {32, '1x', 1, 40};
            gRoot.ColumnWidth   = {'1x'};
            gRoot.Padding       = [16 16 16 16];
            gRoot.RowSpacing    = 12;
            gRoot.ColumnSpacing = 0;
            gRoot.BackgroundColor = t.DashboardBackground;

            % Row 1: Mode tab strip [1 3].
            gTabs = uigridlayout(gRoot, [1 3]);
            gTabs.Layout.Row    = 1;
            gTabs.Layout.Column = 1;
            gTabs.RowHeight     = {'1x'};
            gTabs.ColumnWidth   = {'1x', '1x', '1x'};
            gTabs.Padding       = [0 0 0 0];
            gTabs.ColumnSpacing = 4;
            gTabs.BackgroundColor = t.DashboardBackground;

            obj.hTabQuick_ = uibutton(gTabs, 'push');
            obj.hTabQuick_.Layout.Row    = 1;
            obj.hTabQuick_.Layout.Column = 1;
            obj.hTabQuick_.Text          = 'Quick';
            obj.hTabQuick_.FontSize      = 11;
            obj.hTabQuick_.FontWeight    = 'bold';
            obj.hTabQuick_.ButtonPushedFcn = @(~,~) obj.onTabQuick_();

            obj.hTabRelative_ = uibutton(gTabs, 'push');
            obj.hTabRelative_.Layout.Row    = 1;
            obj.hTabRelative_.Layout.Column = 2;
            obj.hTabRelative_.Text          = 'Relative';
            obj.hTabRelative_.FontSize      = 11;
            obj.hTabRelative_.FontWeight    = 'bold';
            obj.hTabRelative_.ButtonPushedFcn = @(~,~) obj.onTabRelative_();

            obj.hTabAbsolute_ = uibutton(gTabs, 'push');
            obj.hTabAbsolute_.Layout.Row    = 1;
            obj.hTabAbsolute_.Layout.Column = 3;
            obj.hTabAbsolute_.Text          = 'Absolute';
            obj.hTabAbsolute_.FontSize      = 11;
            obj.hTabAbsolute_.FontWeight    = 'bold';
            obj.hTabAbsolute_.ButtonPushedFcn = @(~,~) obj.onTabAbsolute_();

            % Row 2: Mode-panel host (each mode panel placed here with Visible toggling).
            gPanelHost = uigridlayout(gRoot, [1 1]);
            gPanelHost.Layout.Row    = 2;
            gPanelHost.Layout.Column = 1;
            gPanelHost.RowHeight     = {'1x'};
            gPanelHost.ColumnWidth   = {'1x'};
            gPanelHost.Padding       = [0 0 0 0];
            gPanelHost.RowSpacing    = 0;
            gPanelHost.BackgroundColor = t.DashboardBackground;

            % Build three mode panels inside the host (Visible toggled by switchMode_).
            obj.buildQuickPanel_(gPanelHost);
            obj.buildRelativePanel_(gPanelHost);
            obj.buildAbsolutePanel_(gPanelHost);

            % Row 3: Visual separator (1px thin panel).
            hSep = uipanel(gRoot);
            hSep.Layout.Row    = 3;
            hSep.Layout.Column = 1;
            hSep.BackgroundColor = t.WidgetBorderColor;
            hSep.BorderType      = 'none';

            % Row 4: Action row [1 2].
            gAction = uigridlayout(gRoot, [1 2]);
            gAction.Layout.Row    = 4;
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
            obj.hCancelBtn_.ButtonPushedFcn = @(~,~) obj.close();

            % Theme + re-assert Accent.
            applyThemeToChildren_(obj.hPopup_, t);
            obj.switchMode_('Quick');

            obj.hPopup_.CloseRequestFcn = @(~,~) obj.close();
        end

        function buildQuickPanel_(obj, parent)
        %BUILDQUICKPANEL_ Build the Quick-presets mode panel with 6 one-click preset buttons.
            t = obj.Theme_;

            obj.hPanelQuick_ = uigridlayout(parent, [6 1]);
            obj.hPanelQuick_.RowHeight   = {32, 32, 32, 32, 32, 32};
            obj.hPanelQuick_.ColumnWidth = {'1x'};
            obj.hPanelQuick_.Padding     = [0 0 0 0];
            obj.hPanelQuick_.RowSpacing  = 4;
            obj.hPanelQuick_.BackgroundColor = t.DashboardBackground;
            obj.hPanelQuick_.Visible         = 'on';

            presets = { ...
                'Last 24 hours', 24, 'hours'; ...
                'Last 7 days',    7, 'days'; ...
                'Last 30 days',  30, 'days'; ...
                'Last 90 days',  90, 'days'; ...
                'Last 1 year',    1, 'years'; ...
                'All data',       0, 'all'};

            for k = 1:6
                lbl  = presets{k, 1};
                N    = presets{k, 2};
                unit = presets{k, 3};

                % Highlight the active preset.
                isActive = obj.isPresetActive_(N, unit);
                if isActive
                    bgColor = t.Accent;
                else
                    bgColor = t.WidgetBorderColor;
                end

                btn = uibutton(obj.hPanelQuick_, 'push');
                btn.Layout.Row    = k;
                btn.Layout.Column = 1;
                btn.Text          = lbl;
                btn.FontSize      = 11;
                btn.FontWeight    = 'bold';
                btn.HorizontalAlignment = 'left';
                btn.BackgroundColor     = bgColor;
                btn.FontColor           = t.ForegroundColor;

                % One-click: commit + close.
                if strcmp(unit, 'all')
                    btn.ButtonPushedFcn = @(~,~) obj.applyPresetAll_();
                else
                    btn.ButtonPushedFcn = @(~,~) obj.applyPresetRelative_(N, unit);
                end
            end
        end

        function buildRelativePanel_(obj, parent)
        %BUILDRELATIVEPANEL_ Build the Relative builder panel (stub; completed in Task 1b).
            % TODO(1b): populate with uispinner + uidropdown + preview label.
            t = obj.Theme_;
            obj.hPanelRelative_ = uigridlayout(parent, [3 3]);
            obj.hPanelRelative_.RowHeight   = {32, 32, 32};
            obj.hPanelRelative_.ColumnWidth = {60, '1x', 120};
            obj.hPanelRelative_.Padding     = [0 0 0 0];
            obj.hPanelRelative_.RowSpacing  = 8;
            obj.hPanelRelative_.ColumnSpacing = 8;
            obj.hPanelRelative_.BackgroundColor = t.DashboardBackground;
            obj.hPanelRelative_.Visible         = 'off';

            % Row 1: labels
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

            % Row 2: controls
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

            % Row 3: preview label
            obj.hRelPreview_ = uilabel(obj.hPanelRelative_);
            obj.hRelPreview_.Layout.Row    = 3;
            obj.hRelPreview_.Layout.Column = [1 3];
            obj.hRelPreview_.FontSize      = 11;
            obj.hRelPreview_.FontColor     = t.PlaceholderTextColor;
            obj.hRelPreview_.Text          = '';

            % Seed preview.
            obj.updateRelPreview_();
        end

        function buildAbsolutePanel_(obj, parent)
        %BUILDABSOLUTEPANEL_ Build the Absolute date-picker panel (stub; completed in Task 1b).
            % TODO(1b): populate with uidatepicker + validation + preview label.
            t = obj.Theme_;
            obj.hPanelAbsolute_ = uigridlayout(parent, [3 2]);
            obj.hPanelAbsolute_.RowHeight   = {32, 32, 32};
            obj.hPanelAbsolute_.ColumnWidth = {80, '1x'};
            obj.hPanelAbsolute_.Padding     = [0 0 0 0];
            obj.hPanelAbsolute_.RowSpacing  = 8;
            obj.hPanelAbsolute_.ColumnSpacing = 8;
            obj.hPanelAbsolute_.BackgroundColor = t.DashboardBackground;
            obj.hPanelAbsolute_.Visible         = 'off';

            % Row 1: Start
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

            % Row 2: End
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

            % Row 3: Preview label
            obj.hAbsPreview_ = uilabel(obj.hPanelAbsolute_);
            obj.hAbsPreview_.Layout.Row    = 3;
            obj.hAbsPreview_.Layout.Column = [1 2];
            obj.hAbsPreview_.FontSize      = 11;
            obj.hAbsPreview_.FontColor     = t.PlaceholderTextColor;
            obj.hAbsPreview_.Text          = '';

            obj.updateAbsPreview_();
        end

        function switchMode_(obj, mode)
        %SWITCHMODE_ Show the active mode panel; repaint tab + Apply visibility.
            obj.ActiveMode_ = mode;
            t = obj.Theme_;

            % Toggle panels.
            if ~isempty(obj.hPanelQuick_) && isvalid(obj.hPanelQuick_)
                obj.hPanelQuick_.Visible = 'off';
            end
            if ~isempty(obj.hPanelRelative_) && isvalid(obj.hPanelRelative_)
                obj.hPanelRelative_.Visible = 'off';
            end
            if ~isempty(obj.hPanelAbsolute_) && isvalid(obj.hPanelAbsolute_)
                obj.hPanelAbsolute_.Visible = 'off';
            end

            switch mode
                case 'Quick'
                    if ~isempty(obj.hPanelQuick_) && isvalid(obj.hPanelQuick_)
                        obj.hPanelQuick_.Visible = 'on';
                    end
                case 'Relative'
                    if ~isempty(obj.hPanelRelative_) && isvalid(obj.hPanelRelative_)
                        obj.hPanelRelative_.Visible = 'on';
                    end
                case 'Absolute'
                    if ~isempty(obj.hPanelAbsolute_) && isvalid(obj.hPanelAbsolute_)
                        obj.hPanelAbsolute_.Visible = 'on';
                    end
            end

            % Repaint tab backgrounds (Accent for active, WidgetBorderColor for inactive).
            tabs  = {obj.hTabQuick_, obj.hTabRelative_, obj.hTabAbsolute_};
            names = {'Quick', 'Relative', 'Absolute'};
            for k = 1:3
                if ~isempty(tabs{k}) && isvalid(tabs{k})
                    if strcmp(names{k}, mode)
                        tabs{k}.BackgroundColor = t.Accent;
                    else
                        tabs{k}.BackgroundColor = t.WidgetBorderColor;
                    end
                end
            end

            % Apply button hidden in Quick mode; visible in Relative/Absolute.
            if ~isempty(obj.hApplyBtn_) && isvalid(obj.hApplyBtn_)
                if strcmp(mode, 'Quick')
                    obj.hApplyBtn_.Visible = 'off';
                else
                    obj.hApplyBtn_.Visible = 'on';
                    obj.hApplyBtn_.BackgroundColor = t.Accent;
                end
            end
        end

        % ----------------------------------------------------------------
        %  Quick preset helpers
        % ----------------------------------------------------------------

        function applyPresetRelative_(obj, N, unit)
        %APPLYPRESETRELATIVE_ One-click relative preset commit + close.
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
        %APPLYPRESETALL_ One-click All data preset commit + close.
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

        function tf = isPresetActive_(obj, N, unit)
        %ISPRESETACTIVE_ Check whether a preset matches the current TimeRange_ spec.
            try
                s = obj.TimeRange_.toStruct();
                if strcmp(unit, 'all')
                    tf = strcmp(s.type, 'all');
                else
                    tf = strcmp(s.type, 'relative') && s.N == N && strcmp(s.unit, unit);
                end
            catch
                tf = false;
            end
        end

        % ----------------------------------------------------------------
        %  Tab callbacks
        % ----------------------------------------------------------------

        function onTabQuick_(obj)
        %ONTABQUICK_ Mode tab callback.
            try
                obj.switchMode_('Quick');
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
                        % Quick mode hides Apply; defensive no-op.
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
        %COMMITRELATIVE_ Commit the Relative panel state and close.
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
