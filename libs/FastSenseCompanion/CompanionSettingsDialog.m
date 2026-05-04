classdef CompanionSettingsDialog < handle
%COMPANIONSETTINGSDIALOG Non-modal settings popup for FastSenseCompanion.
%
%   Owns its own uifigure with a Theme dropdown, Live-period spinner,
%   Reset and Close buttons. Every control change applies live via the
%   parent FastSenseCompanion's public setters (applyTheme,
%   setLivePeriod). Persistence is handled by those setters; the dialog
%   itself does not write to prefdir.
%
%   Lifecycle is independent: closing this dialog does not close the
%   Companion; closing the Companion deletes this dialog if still open.
%
%   Note: this class deliberately writes `app.SettingsDlg_ = []` on
%   close. FastSenseCompanion declares that property with
%   `SetAccess = ?CompanionSettingsDialog` precisely to allow this.
%
%   Usage:
%     dlg = CompanionSettingsDialog(app)
%     dlg.close()
%
%   Properties (read-only):
%     App   — the FastSenseCompanion handle
%     hFig_ — the owned uifigure handle (or [] after close)
%
%   See also FastSenseCompanion, CompanionTheme.

    properties (SetAccess = private)
        App   = []   % FastSenseCompanion handle (parent)
        hFig_ = []   % owned uifigure
    end

    properties (Access = private)
        hThemeDD_       = []
        hPeriodSpinner_ = []
        hResetBtn_      = []
        hCloseBtn_      = []
    end

    methods (Access = public)

        function obj = CompanionSettingsDialog(app)
        %COMPANIONSETTINGSDIALOG Construct the dialog and bind it to app.
            if ~isa(app, 'FastSenseCompanion')
                error('CompanionSettingsDialog:invalidApp', ...
                    'CompanionSettingsDialog requires a FastSenseCompanion handle.');
            end
            obj.App = app;
            t = app.Theme_;

            obj.hFig_ = uifigure( ...
                'Name',                'Companion Settings', ...
                'Position',            [200 200 360 200], ...
                'Resize',              'off', ...
                'AutoResizeChildren',  'off', ...
                'Color',               t.DashboardBackground);
            % Non-modal — explicitly do NOT set WindowStyle='modal'.

            g = uigridlayout(obj.hFig_, [3 2]);
            g.RowHeight     = {32, 32, 40};
            g.ColumnWidth   = {120, '1x'};
            g.Padding       = [16 16 16 16];
            g.RowSpacing    = 12;
            g.ColumnSpacing = 12;
            g.BackgroundColor = t.DashboardBackground;

            uilabel(g, 'Text', 'Theme');
            obj.hThemeDD_ = uidropdown(g, ...
                'Items',           {'dark','light'}, ...
                'Value',           app.Theme, ...
                'ValueChangedFcn', @(s,e) obj.onThemeChanged_(s,e));

            uilabel(g, 'Text', 'Live period (s)');
            obj.hPeriodSpinner_ = uispinner(g, ...
                'Limits',              [0.1 60], ...
                'Step',                0.1, ...
                'ValueDisplayFormat',  '%.1f', ...
                'Value',               app.LivePeriod, ...
                'ValueChangedFcn',     @(s,e) obj.onPeriodChanged_(s,e));

            gBtns = uigridlayout(g, [1 2]);
            gBtns.Layout.Row    = 3;
            gBtns.Layout.Column = [1 2];
            gBtns.RowHeight     = {'1x'};
            gBtns.ColumnWidth   = {'1x', '1x'};
            gBtns.Padding       = [0 0 0 0];
            gBtns.ColumnSpacing = 8;
            gBtns.BackgroundColor = t.DashboardBackground;

            obj.hResetBtn_ = uibutton(gBtns, 'push', ...
                'Text',            'Reset to defaults', ...
                'ButtonPushedFcn', @(~,~) obj.onReset_());
            obj.hCloseBtn_ = uibutton(gBtns, 'push', ...
                'Text',            'Close', ...
                'ButtonPushedFcn', @(~,~) obj.close());

            % Style every child via the recursive walker, then restore the
            % dropdown/spinner Values the walker may have ignored (it only
            % paints color properties).
            applyThemeToChildren_(obj.hFig_, t);

            obj.hFig_.CloseRequestFcn = @(~,~) obj.close();
        end

        function close(obj)
        %CLOSE Tear down the dialog. Idempotent.
        %   Notifies the parent app (via the friend-class SettingsDlg_
        %   setter) so the singleton check sees a clean slate next time.
            if isempty(obj.hFig_) || ~isvalid(obj.hFig_)
                obj.hFig_ = [];
                return;
            end
            try
                if ~isempty(obj.App) && isvalid(obj.App)
                    obj.App.SettingsDlg_ = [];
                end
            catch
            end
            try
                delete(obj.hFig_);
            catch
            end
            obj.hFig_ = [];
        end

        function delete(obj)
        %DELETE Handle-class destructor — calls close() for safety.
            obj.close();
        end

    end

    methods (Access = private)

        function onThemeChanged_(obj, ~, evt)
        %ONTHEMECHANGED_ Theme dropdown ValueChangedFcn.
            try
                obj.App.applyTheme(evt.Value);
                % Repaint the dialog itself with the new theme.
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    obj.hFig_.Color = obj.App.Theme_.DashboardBackground;
                    applyThemeToChildren_(obj.hFig_, obj.App.Theme_);
                end
            catch err
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    uialert(obj.hFig_, err.message, 'Companion Settings');
                end
            end
        end

        function onPeriodChanged_(obj, ~, evt)
        %ONPERIODCHANGED_ Live-period spinner ValueChangedFcn.
            try
                obj.App.setLivePeriod(evt.Value);
            catch err
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    uialert(obj.hFig_, err.message, 'Companion Settings');
                end
            end
        end

        function onReset_(obj)
        %ONRESET_ Reset-to-defaults ButtonPushedFcn.
            try
                obj.App.applyTheme('dark');
                obj.App.setLivePeriod(1.0);
                if ~isempty(obj.hThemeDD_) && isvalid(obj.hThemeDD_)
                    obj.hThemeDD_.Value = 'dark';
                end
                if ~isempty(obj.hPeriodSpinner_) && isvalid(obj.hPeriodSpinner_)
                    obj.hPeriodSpinner_.Value = 1.0;
                end
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    obj.hFig_.Color = obj.App.Theme_.DashboardBackground;
                    applyThemeToChildren_(obj.hFig_, obj.App.Theme_);
                end
            catch err
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    uialert(obj.hFig_, err.message, 'Companion Settings');
                end
            end
        end

    end
end
