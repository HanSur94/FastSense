classdef DashboardToolbar < handle
%DASHBOARDTOOLBAR Global toolbar for dashboard controls.
%
%   Provides buttons for: Sync, Live (toggle with blue border when active),
%   Config (opens DashboardConfigDialog), Image, Export, and Info (always
%   present — shows a placeholder page when no InfoFile is configured).
%   Every button has a descriptive tooltip. Sits at the top of the
%   dashboard figure.

    properties (Access = public)
        Height = 0.04
    end

    properties (SetAccess = private)
        hPanel       = []
        hLiveBtn     = []
        hLivePanel   = []
        hFollowBtn   = []   % togglebutton: opt into per-tick XLim auto-pan to data tail (260512-hrn)
        hFollowPanel = []   % wrapper panel — blue highlight when Follow is active
        hConfigBtn     = []
        hExportBtn   = []
        hImageBtn    = []
        hSyncBtn     = []
        hResetBtn    = []
        hEventsBtn   = []
        hEventsPanel = []
        hTitleText   = []
        hLastUpdate  = []
        hInfoBtn     = []
        Engine       = []
        Theme_       = []
    end

    methods
        function obj = DashboardToolbar(engine, hFigure, theme)
            obj.Engine = engine;
            obj.Theme_ = theme;

            % Y accounts for the reserved banner strip at the figure top —
            % toolbar always sits directly below the banner strip
            % (260508-jyh).
            obj.hPanel = uipanel('Parent', hFigure, ...
                'Units', 'normalized', ...
                'Position', [0, 1 - engine.BannerHeight - obj.Height, 1, obj.Height], ...
                'BorderType', 'none', ...
                'BackgroundColor', theme.ToolbarBackground);

            % Title: always reserve room for the (now mandatory) Info button
            obj.hTitleText = uicontrol('Parent', obj.hPanel, ...
                'Style', 'edit', ...
                'Units', 'normalized', ...
                'Position', [0.01 0.1 0.27 0.8], ...
                'String', engine.Name, ...
                'FontSize', theme.HeaderFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Dashboard name (click to edit)', ...
                'Callback', @(src,~) obj.onNameEdit(src));

            btnW = 0.06;
            btnH = 0.7;
            btnY = 0.15;

            % Mandatory Info button — opens linked info file or a placeholder page.
            obj.hInfoBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [0.29 btnY 0.05 btnH], ...
                'String', 'Info', ...
                'TooltipString', 'Show dashboard info page', ...
                'Callback', @(~,~) obj.onInfo());

            rightEdge = 0.99;

            rightEdge = rightEdge - btnW - 0.005;
            obj.hExportBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Export', ...
                'TooltipString', 'Export dashboard as MATLAB script (.m)', ...
                'Callback', @(~,~) obj.onExport());

            rightEdge = rightEdge - btnW - 0.005;
            obj.hImageBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Image', ...
                'TooltipString', 'Save dashboard as image (PNG/JPEG)', ...
                'Callback', @(~,~) obj.onImage());

            rightEdge = rightEdge - btnW - 0.005;
            obj.hConfigBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Config', ...
                'TooltipString', 'Open dashboard config dialog', ...
                'Callback', @(~,~) obj.onConfig());

            rightEdge = rightEdge - btnW - 0.005;
            % Wrap Live toggle in a thin panel so we can show a blue border when active.
            obj.hLivePanel = uipanel('Parent', obj.hPanel, ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'BorderType', 'line', ...
                'HighlightColor', theme.ToolbarBackground, ...
                'BorderWidth', 2, ...
                'BackgroundColor', theme.ToolbarBackground);
            obj.hLiveBtn = uicontrol('Parent', obj.hLivePanel, ...
                'Style', 'togglebutton', ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1], ...
                'String', 'Live', ...
                'Value', 0, ...
                'TooltipString', 'Toggle live mode — auto-refresh widgets from data', ...
                'Callback', @(src,~) obj.onLiveToggle(src));

            % Follow toggle (260512-hrn) — when ON, every FastSense widget
            % in the dashboard auto-pans its XLim to track the live data
            % tail; clicking ON from a panned-away view snaps the view to
            % the tail immediately. Wrapped in a thin panel for the same
            % blue-border active highlight as Live.
            rightEdge = rightEdge - btnW - 0.005;
            obj.hFollowPanel = uipanel('Parent', obj.hPanel, ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'BorderType', 'line', ...
                'HighlightColor', theme.ToolbarBackground, ...
                'BorderWidth', 2, ...
                'BackgroundColor', theme.ToolbarBackground);
            obj.hFollowBtn = uicontrol('Parent', obj.hFollowPanel, ...
                'Style', 'togglebutton', ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1], ...
                'String', 'Follow', ...
                'Value', 0, ...
                'TooltipString', ['Auto-pan all charts to track the live tail. ' ...
                    'Click again to release the view (or pan/zoom manually).'], ...
                'Callback', @(src,~) obj.onFollowToggle(src));

            rightEdge = rightEdge - btnW - 0.005;
            obj.hSyncBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Sync', ...
                'TooltipString', 'Reset all widgets to global time range', ...
                'Callback', @(~,~) obj.Engine.resetGlobalTime());

            % Reset button — manual recovery; forces full re-render of every
            % widget on the active page. Placed next to Sync because both
            % are "fix the dashboard" actions, but their roles differ:
            % Sync resets the time range; Reset re-renders widget panels.
            rightEdge = rightEdge - btnW - 0.005;
            obj.hResetBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Reset', ...
                'TooltipString', ['Force re-render of all widgets on the active page ' ...
                    '(recovery action when widgets get stuck)'], ...
                'Callback', @(~,~) obj.onReset());

            % Events toggle — globally show/hide event markers across all
            % widgets. Wrapped in a thin panel so we can show a blue
            % border when active (matches the Live-button visual treatment).
            rightEdge = rightEdge - btnW - 0.005;
            obj.hEventsPanel = uipanel('Parent', obj.hPanel, ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'BorderType', 'line', ...
                'HighlightColor', theme.InfoColor, ...
                'BorderWidth', 2, ...
                'BackgroundColor', theme.ToolbarBackground);
            obj.hEventsBtn = uicontrol('Parent', obj.hEventsPanel, ...
                'Style', 'togglebutton', ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1], ...
                'String', 'Events', ...
                'Value', 1, ...
                'TooltipString', 'Toggle event markers across all widgets', ...
                'Callback', @(src,~) obj.onEventsToggle(src));

            % Last update timestamp label
            labelW = 0.12;
            obj.hLastUpdate = uicontrol('Parent', obj.hPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [rightEdge - labelW - 0.01, btnY, labelW, btnH], ...
                'String', 'Last update: —', ...
                'FontSize', 8, ...
                'ForegroundColor', theme.ToolbarFontColor * 0.6 + ...
                    theme.ToolbarBackground * 0.4, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'right');
        end

        function setLastUpdateTime(obj, t)
        %SETLASTUPDATETIME Update the last-update label with a timestamp.
        %   Hot-path note: called on every live tick. Uses datevec (no format
        %   string parsing) instead of datestr to avoid timefun/private overhead.
            if ~isempty(obj.hLastUpdate) && ishandle(obj.hLastUpdate)
                try
                    dv = datevec(t);
                    timeStr = sprintf('%02d:%02d:%02d', dv(4), dv(5), floor(dv(6)));
                catch
                    timeStr = datestr(t, 'HH:MM:SS');
                end
                set(obj.hLastUpdate, 'String', ['Last update: ' timeStr]);
            end
        end

        function onNameEdit(obj, src)
            newName = get(src, 'String');
            obj.Engine.Name = newName;
            set(obj.Engine.hFigure, 'Name', newName);
        end

        function onLiveToggle(obj, src)
            isOn = logical(get(src, 'Value'));
            if isOn
                obj.Engine.startLive();
            else
                obj.Engine.stopLive();
            end
            obj.setLiveActiveIndicator(isOn);
        end

        function setLiveActiveIndicator(obj, isActive)
        %SETLIVEACTIVEINDICATOR Show a blue surround when live mode is active.
            if isempty(obj.hLivePanel) || ~ishandle(obj.hLivePanel)
                return;
            end
            if isActive
                set(obj.hLivePanel, 'HighlightColor', obj.Theme_.InfoColor);
            else
                set(obj.hLivePanel, 'HighlightColor', obj.Theme_.ToolbarBackground);
            end
        end

        function onFollowToggle(obj, src)
        %ONFOLLOWTOGGLE Apply auto-pan to every FastSense widget in the dashboard.
        %   isOn=true:  LiveViewMode='follow' on every FastSenseWidget's
        %               FastSenseObj AND snap each chart to its current
        %               data tail (one-shot jump-to-now).
        %   isOn=false: LiveViewMode='preserve' on every FastSenseWidget's
        %               FastSenseObj (the chart stops following).
        %
        %   The per-FastSense state set by this method is also what the
        %   FastSense auto-disengage hook reads — if the user manually
        %   pans a chart while Follow is on, that chart's LiveViewMode
        %   reverts to 'preserve', but other charts in the dashboard
        %   keep following. The Follow button state on the toolbar does
        %   not auto-update in that case; clicking Follow again resyncs
        %   every widget.
        %   (260512-hrn)
            isOn = logical(get(src, 'Value'));
            if isOn
                mode = 'follow';
            else
                mode = 'preserve';
            end
            try
                % Use allPageWidgets() not .Widgets so Follow reaches
                % every FastSenseWidget on every page — in multi-page
                % dashboards .Widgets is empty (widgets live on
                % Pages{i}.Widgets). (260513-ovt)
                ws = obj.Engine.allPageWidgets();
                obj.applyFollowToWidgets_(ws, mode, isOn);
            catch err
                warning('DashboardToolbar:followToggleFailed', ...
                    'Follow toggle failed: %s', err.message);
            end
            obj.setFollowActiveIndicator(isOn);
        end

        function setFollowActiveIndicator(obj, isActive)
        %SETFOLLOWACTIVEINDICATOR Show a blue surround when Follow is active.
            if isempty(obj.hFollowPanel) || ~ishandle(obj.hFollowPanel)
                return;
            end
            if isActive
                set(obj.hFollowPanel, 'HighlightColor', obj.Theme_.InfoColor);
            else
                set(obj.hFollowPanel, 'HighlightColor', obj.Theme_.ToolbarBackground);
            end
        end

        function applyFollowToWidgets_(obj, widgets, mode, snap)
        %APPLYFOLLOWTOWIDGETS_ Recursively apply LiveViewMode + optional snap.
        %   Walks the widget tree (descends into GroupWidget children),
        %   sets LiveViewMode on every FastSenseWidget's FastSenseObj,
        %   and — when `snap` is true — calls snapToTail() on each to
        %   immediately jump the view to the current data tail.
        %
        %   No-op for non-FastSenseWidget widgets (NumberWidget, GaugeWidget,
        %   StatusWidget, etc.) — they don't have an XLim to follow.
        %
        %   (260512-hrn)
            if iscell(widgets)
                items = widgets;
            else
                items = {widgets};
            end
            for k = 1:numel(items)
                w = items{k};
                if isempty(w) || ~isvalid(w)
                    continue;
                end
                if isa(w, 'FastSenseWidget')
                    if ~isempty(w.FastSenseObj) && isvalid(w.FastSenseObj) ...
                            && w.FastSenseObj.IsRendered
                        try
                            w.FastSenseObj.setViewMode(mode);
                            if snap
                                w.FastSenseObj.snapToTail();
                            end
                        catch
                            % per-widget failure shouldn't break the sweep
                        end
                    end
                elseif isa(w, 'GroupWidget')
                    try
                        obj.applyFollowToWidgets_(w.Children, mode, snap);
                    catch
                    end
                end
            end
        end

        function onEventsToggle(obj, src)
        %ONEVENTSTOGGLE Fire engine-level event-marker toggle from button state.
        %   Engine.setEventMarkersVisible already calls back into
        %   setEventsActiveIndicator, but call it directly here too in
        %   case the engine's call path skips the toolbar (e.g. tests
        %   that temporarily reassign Engine.Toolbar).
            isOn = logical(get(src, 'Value'));
            obj.Engine.setEventMarkersVisible(isOn);
            obj.setEventsActiveIndicator(isOn);
        end

        function setEventsActiveIndicator(obj, isActive)
        %SETEVENTSACTIVEINDICATOR Blue border when event markers are visible.
        %   Matches the Live button's visual treatment so the toolbar
        %   reads consistently. Keeps the button label constant — the
        %   border colour is the active indicator; the tooltip explains
        %   the function.
            if isempty(obj.hEventsPanel) || ~ishandle(obj.hEventsPanel)
                return;
            end
            if isActive
                set(obj.hEventsPanel, 'HighlightColor', obj.Theme_.InfoColor);
            else
                set(obj.hEventsPanel, 'HighlightColor', obj.Theme_.ToolbarBackground);
            end
            if ~isempty(obj.hEventsBtn) && ishandle(obj.hEventsBtn)
                if isActive
                    set(obj.hEventsBtn, 'String', 'Events', 'Value', 1);
                else
                    set(obj.hEventsBtn, 'String', 'Events', 'Value', 0);
                end
            end
        end

        function onConfig(obj)
        %ONCONFIG Open the dashboard config dialog.
            DashboardConfigDialog(obj.Engine);
        end

        function onReset(obj)
        %ONRESET Manual recovery — re-render all widgets on the active page.
        %   Delegates to DashboardEngine.rerenderWidgets which deletes every
        %   widget panel, marks widgets unrealized, then re-allocates and
        %   re-realizes them. Use when widgets get stuck (stale axes, zombie
        %   state, transient render error). Safe to call while Live mode is
        %   active — rerenderWidgets does not touch the Live timer state.
            if isempty(obj.Engine)
                return;
            end
            try
                obj.Engine.rerenderWidgets();
            catch ME
                warning('DashboardToolbar:resetFailed', ...
                    'Reset failed: %s', ME.message);
            end
        end

        function onExport(obj)
            [file, path] = uiputfile('*.m', 'Export as Script');
            if file ~= 0
                obj.Engine.exportScript(fullfile(path, file));
            end
        end

        function onImage(obj)
        %ONIMAGE Open save dialog and export dashboard figure as PNG/JPEG.
        %   Pops a uiputfile with PNG+JPEG filters, defaults to the
        %   sanitized dashboard name plus timestamp. On cancel, returns
        %   silently. On engine error, surfaces message via warndlg.
            defName = obj.defaultImageFilename();
            [file, path, idx] = uiputfile( ...
                {'*.png', 'PNG image (*.png)'; ...
                 '*.jpg', 'JPEG image (*.jpg)'}, ...
                'Save Dashboard Image', ...
                defName);
            obj.dispatchImageExport(file, path, idx);
        end

        function dispatchImageExport(obj, file, path, idx)
        %DISPATCHIMAGEEXPORT Post-dialog dispatcher — testable without uiputfile.
        %   file  — filename string, or 0 on user-cancel
        %   path  — directory path from uiputfile
        %   idx   — filter index (1=PNG, 2=JPEG). Defaults to PNG.
            if isequal(file, 0) || isempty(file)
                return;  % user cancelled — silent no-op (IMG-07)
            end
            if nargin < 4 || isempty(idx) || idx == 1
                fmt = 'png';
            else
                fmt = 'jpeg';
            end
            try
                obj.Engine.exportImage(fullfile(path, file), fmt);
            catch ME
                warndlg(ME.message, 'Image Export');
            end
        end

        function fname = defaultImageFilename(obj)
        %DEFAULTIMAGEFILENAME Build sanitized default filename for the dialog.
        %   Pattern: {sanitized Engine.Name}_{yyyymmdd_HHMMSS}.png
        %   Sanitization: replace [/\:*?"<>|] and whitespace with '_'.
        %   NOTE: datestr format 'yyyymmdd_HHMMSS' (lowercase mm=month here,
        %   HHMMSS=seconds). This differs from datetime/ISO notation —
        %   see libs/EventDetection/generateEventSnapshot.m:28 for the
        %   in-codebase precedent.
            rawName = obj.Engine.Name;
            if isempty(rawName)
                rawName = 'Dashboard';
            end
            safeName = regexprep(rawName, '[/\\:*?"<>|\s]', '_');
            stamp = datestr(now, 'yyyymmdd_HHMMSS');
            fname = sprintf('%s_%s.png', safeName, stamp);
        end

        function onInfo(obj)
            obj.Engine.showInfo();
        end

        function contentArea = getContentArea(obj)
        %GETCONTENTAREA Compute the widget content area in normalized units.
        %   Subtracts the reserved banner strip at the top, the toolbar,
        %   and the time-panel height (260508-jyh). DashboardEngine
        %   computes ContentArea inline in render() and
        %   applyVisibilityAndRelayout(); this helper exists for
        %   consistency with consumers that read directly from the
        %   toolbar (e.g. DashboardBuilder canvas calc).
            timePanelH = obj.Engine.TimePanelHeight;
            contentArea = [0, timePanelH, ...
                1, 1 - obj.Engine.BannerHeight - obj.Height - timePanelH];
        end
    end
end
