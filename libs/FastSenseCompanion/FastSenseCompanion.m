classdef FastSenseCompanion < handle
%FASTSENSECOMPANION Companion navigator for FastSense dashboards and tags.
%
%   Usage:
%     app = FastSenseCompanion('Dashboards', {d1, d2}, 'Registry', reg, ...
%                              'Name', 'Line 4 Demo', 'Theme', 'dark');
%     app.setProject({d3}, reg2);
%     app.close();
%
%   Opens a single themed uifigure with a three-column layout immediately.
%   No separate render() call is required.
%
%   Constructor name-value options:
%     Dashboards — cell array of DashboardEngine (default: {})
%     Registry   — TagRegistry instance (default: TagRegistry singleton)
%     Name       — window title string (default: 'FastSense Companion')
%     Theme      — 'dark' | 'light' (default: 'dark')
%
%   Public methods:
%     setProject(dashboards, registry) — rebuild against new project
%     addDashboard(d)                  - append a DashboardEngine; refresh browser
%     removeDashboard(key)             - remove by Name; reset inspector if it was selected
%     refreshCatalog()                 — re-snapshot tags and rebuild catalog
%     close()                          — idempotent teardown
%
%   Events fired:
%     InspectorStateChanged    payload: InspectorStateEventData(state, payload)
%     OpenAdHocPlotRequested   payload: AdHocPlotEventData(tagKeys, mode) — fired by InspectorPane
%
%   See also DashboardEngine, TagRegistry, CompanionTheme.

    events
        InspectorStateChanged
        OpenAdHocPlotRequested
    end

    properties (Access = public)
        % (intentionally empty — all user-observable state is SetAccess=private)
    end

    properties (SetAccess = private)
        Dashboards = {}       % cell array of DashboardEngine passed by user
        Registry   = []       % TagRegistry reference
        Theme      = 'dark'   % preset string ('dark' | 'light')
        IsOpen     = false    % true while uifigure is valid
        IsLive     = false    % true while LiveTimer_ is running (refreshes inspector)
    end

    properties (Access = private)
        hFig_          = []   % uifigure handle
        hLayout_       = []   % root uigridlayout handle
        hLeftPanel_    = []   % left pane uipanel
        hMidPanel_     = []   % middle pane uipanel
        hRightPanel_   = []   % right pane uipanel
        hLogPanel_     = []   % bottom log uipanel (full-width)
        hLogTable_     = []   % uitable inside hLogPanel_ (alternating row colors)
        hLogSearch_    = []   % uieditfield ('text') search box for the log
        hLogLevelDD_   = []   % uidropdown level filter ('All' | 'INFO' | 'WARN' | 'ERROR')
        LogBuffer_     = cell(0, 3)  % full {Time, Level, Message} buffer (newest first)
        hLiveLogTable_ = []   % uitable for the live data-update log (below the events log)
        LiveLogBuffer_ = cell(0, 4)  % {Time, Tag, +Samples, Latest} buffer (newest first)
        LiveSampleCount_ = []  % containers.Map(tagKey -> last seen sample count)
        hLiveBtn_      = []   % Live mode toggle button (in log strip header)
        hLastUpdateLbl_ = []  % "Updated 12:34:56" label next to live button
        LiveTimer_     = []   % MATLAB timer driving inspector refresh
        LivePeriod_    = 1.0  % seconds between live refreshes
        Theme_         = []   % resolved CompanionTheme struct
        Listeners_     = {}   % all addlistener return values; deleted on close
        CatalogPane_   = []   % TagCatalogPane instance
        ListPane_      = []   % DashboardListPane instance
        InspectorPane_ = []   % InspectorPane instance
        Engines_       = {}   % internal copy of Dashboards cell (DashboardEngine handles)
        Registry_      = []   % internal Registry_ reference
        SelectedDashboardIdx_ = 0    % 1-based; 0 = nothing selected (Phase 1020)
        LastInteraction_      = ''   % '' | 'tags' | 'dashboard' (Phase 1020 sets 'dashboard'; Phase 1021 sets 'tags')
        SelectedTagKeys_      = {}   % cellstr cache mirrored from CatalogPane.getSelectedKeys() (Phase 1021)
    end

    methods (Access = public)

        function obj = FastSenseCompanion(varargin)
        %FASTSENSECOMPANION Constructor. Opens a themed three-pane uifigure immediately.
        %   Name-value pairs: 'Dashboards', 'Registry', 'Name', 'Theme'.

            % Step 1 — Octave guard (FIRST, before any other work)
            if exist('OCTAVE_VERSION', 'builtin') ~= 0
                error('FastSenseCompanion:notSupported', ...
                    'FastSenseCompanion requires MATLAB R2020b or later. Octave is not supported.');
            end

            % Step 2 — Default options
            userDashboards = {};
            userRegistry   = [];
            userName       = 'FastSense Companion';
            userTheme      = 'dark';

            % Step 3 — Parse varargin (explicit switch, match project convention)
            for k = 1:2:numel(varargin)
                key = varargin{k};
                switch key
                    case 'Dashboards'
                        userDashboards = varargin{k+1};
                    case 'Registry'
                        userRegistry = varargin{k+1};
                    case 'Name'
                        userName = varargin{k+1};
                    case 'Theme'
                        userTheme = varargin{k+1};
                    otherwise
                        error('FastSenseCompanion:unknownOption', ...
                            'Unknown option ''%s''. Valid options: Dashboards, Registry, Name, Theme.', key);
                end
            end

            % Step 4 — Validate Dashboards cell
            if ~iscell(userDashboards)
                userDashboards = {userDashboards};
            end
            for i = 1:numel(userDashboards)
                if ~isa(userDashboards{i}, 'DashboardEngine')
                    error('FastSenseCompanion:invalidDashboard', ...
                        'Dashboards{%d} must be a DashboardEngine instance.', i);
                end
            end

            % Step 5 — Default Registry to TagRegistry singleton if not supplied
            if isempty(userRegistry)
                userRegistry = TagRegistry;
            end

            % Step 6 — Store on object
            obj.Engines_   = userDashboards;
            obj.Dashboards = userDashboards;
            obj.Registry_  = userRegistry;
            obj.Registry   = userRegistry;
            obj.Theme      = userTheme;
            obj.Theme_     = CompanionTheme.get(userTheme);

            % Step 7 — Build uifigure (Visible='off' while building)
            obj.hFig_ = uifigure( ...
                'Name',               userName, ...
                'Position',           [100 100 1320 800], ...
                'Resize',             'on', ...
                'AutoResizeChildren', 'off', ...
                'Visible',            'off');
            obj.hFig_.Color = obj.Theme_.DashboardBackground;

            % Step 8 — Root grid (2 rows: top = 3 panes, bottom = log strip)
            obj.hLayout_ = uigridlayout(obj.hFig_, [2 3]);
            obj.hLayout_.ColumnWidth   = {220, '1x', 360};
            obj.hLayout_.RowHeight     = {'1x', 360};
            obj.hLayout_.Padding       = [24 24 24 24];
            obj.hLayout_.ColumnSpacing = 16;
            obj.hLayout_.RowSpacing    = 12;
            obj.hLayout_.BackgroundColor = obj.Theme_.DashboardBackground;

            % Step 9 — Three uipanels in row 1 + log panel spanning row 2.
            obj.hLeftPanel_  = uipanel(obj.hLayout_);
            obj.hLeftPanel_.Layout.Row = 1; obj.hLeftPanel_.Layout.Column = 1;
            obj.hMidPanel_   = uipanel(obj.hLayout_);
            obj.hMidPanel_.Layout.Row = 1; obj.hMidPanel_.Layout.Column = 2;
            obj.hRightPanel_ = uipanel(obj.hLayout_);
            obj.hRightPanel_.Layout.Row = 1; obj.hRightPanel_.Layout.Column = 3;
            obj.hLogPanel_ = uipanel(obj.hLayout_);
            obj.hLogPanel_.Layout.Row = 2; obj.hLogPanel_.Layout.Column = [1 3];

            % Apply panel styling from theme
            for hp = {obj.hLeftPanel_, obj.hMidPanel_, obj.hRightPanel_, obj.hLogPanel_}
                hp{1}.BackgroundColor = obj.Theme_.WidgetBackground;
                hp{1}.BorderColor     = obj.Theme_.WidgetBorderColor;
                hp{1}.BorderType      = 'line';
                hp{1}.BorderWidth     = 1;
            end

            % Build log strip (Header + uitextarea in a 2-row inner grid)
            obj.buildLogStrip_();

            % Step 10 — Instantiate pane objects and attach
            obj.CatalogPane_   = TagCatalogPane();
            obj.ListPane_      = DashboardListPane();
            obj.InspectorPane_ = InspectorPane();
            obj.CatalogPane_.attach(obj.hLeftPanel_, obj.hFig_, obj.Registry_, obj.Theme_);
            obj.ListPane_.attach(obj.hMidPanel_, obj.hFig_, obj.Engines_, obj.Theme_);
            obj.InspectorPane_.attach(obj.hRightPanel_, obj.hFig_, obj.CatalogPane_, obj, obj.Theme_);
            % Wire pane event listeners (append to Listeners_)
            obj.Listeners_{end+1} = addlistener(obj.ListPane_, 'DashboardSelected', ...
                @(s, e) obj.onDashboardSelected_(s, e));
            obj.Listeners_{end+1} = addlistener(obj.ListPane_, 'OpenDashboardRequested', ...
                @(s, e) obj.onOpenDashboardRequested_(s, e));
            obj.Listeners_{end+1} = addlistener(obj.CatalogPane_, 'TagSelectionChanged', ...
                @(s, e) obj.onTagSelectionChanged_(s, e));
            obj.Listeners_{end+1} = addlistener(obj, 'InspectorStateChanged', ...
                @(s, e) obj.InspectorPane_.setState(e.State, e.Payload));
            obj.Listeners_{end+1} = addlistener(obj, 'OpenAdHocPlotRequested', ...
                @(s, e) obj.onOpenAdHocPlotRequested_(s, e));
            obj.applyPlaceholderColors_();

            % Step 11 — Wire CloseRequestFcn
            obj.hFig_.CloseRequestFcn = @(~,~) obj.close();

            % Step 12 — Center and show
            movegui(obj.hFig_, 'center');
            obj.hFig_.Visible = 'on';
            obj.IsOpen = true;

            % Step 13 — Default to Live mode ON (refreshes inspector at LivePeriod_).
            obj.startLiveMode();
        end

        function close(obj)
        %CLOSE Idempotent teardown — deletes listeners, owned timers, and the uifigure.
        %   Does NOT affect any DashboardEngine figure or ad-hoc plot figures.
        %
        %   Bulletproof: every cleanup step is wrapped in try/catch so a
        %   single failure (e.g. a stale listener handle, a pane already
        %   half-deleted) cannot prevent the uifigure itself from being
        %   deleted. The X-button must always close the window.
            if ~isvalid(obj)
                return;
            end
            if isempty(obj.hFig_) || ~isvalid(obj.hFig_)
                obj.hFig_  = [];
                obj.IsOpen = false;
                return;
            end
            % Diagnostic — confirms the X click reached close().
            fprintf('[FastSenseCompanion] close() invoked, tearing down...\n');
            % Stop and delete live timer first so no tick fires mid-teardown.
            try
                if ~isempty(obj.LiveTimer_) && isvalid(obj.LiveTimer_)
                    if strcmp(obj.LiveTimer_.Running, 'on')
                        stop(obj.LiveTimer_);
                    end
                    delete(obj.LiveTimer_);
                end
            catch err
                fprintf(2, '[FastSenseCompanion] LiveTimer cleanup failed: %s\n', err.message);
            end
            obj.LiveTimer_ = [];
            obj.IsLive = false;
            % Detach panes (releases their listeners + debounce timers).
            try
                if ~isempty(obj.CatalogPane_) && isvalid(obj.CatalogPane_)
                    obj.CatalogPane_.detach();
                end
            catch err
                fprintf(2, '[FastSenseCompanion] CatalogPane.detach failed: %s\n', err.message);
            end
            try
                if ~isempty(obj.ListPane_) && isvalid(obj.ListPane_)
                    obj.ListPane_.detach();
                end
            catch err
                fprintf(2, '[FastSenseCompanion] ListPane.detach failed: %s\n', err.message);
            end
            try
                if ~isempty(obj.InspectorPane_) && isvalid(obj.InspectorPane_)
                    obj.InspectorPane_.detach();
                end
            catch err
                fprintf(2, '[FastSenseCompanion] InspectorPane.detach failed: %s\n', err.message);
            end
            % Release orchestrator-level listeners. delete(cellArray) is
            % interpreted as filename-delete by MATLAB ("Name must be a
            % text scalar"). Iterate explicitly.
            for ii = 1:numel(obj.Listeners_)
                try
                    lh = obj.Listeners_{ii};
                    if isobject(lh) && isvalid(lh)
                        delete(lh);
                    end
                catch err
                    fprintf(2, '[FastSenseCompanion] Listener[%d] delete failed: %s\n', ii, err.message);
                end
            end
            obj.Listeners_ = {};
            % Always delete the uifigure last and unconditionally — this is
            % what makes the X click actually close the window.
            try
                delete(obj.hFig_);
            catch err
                fprintf(2, '[FastSenseCompanion] hFig delete failed: %s\n', err.message);
            end
            obj.hFig_  = [];
            obj.IsOpen = false;
            fprintf('[FastSenseCompanion] close() complete.\n');
        end

        function delete(obj)
        %DELETE Handle class destructor — calls close() for safety.
            obj.close();
        end

        function setProject(obj, dashboards, registry)
        %SETPROJECT Replace the project (dashboards + registry) and rebuild pane placeholders.
        %   The uifigure is NOT recreated. Inspector returns to welcome state (placeholder).
        %   Previously opened dashboard or ad-hoc plot figures are not affected.
        %
        %   dashboards — cell array of DashboardEngine (same validation as constructor)
        %   registry   — TagRegistry instance
            if ~iscell(dashboards)
                dashboards = {dashboards};
            end
            for i = 1:numel(dashboards)
                if ~isa(dashboards{i}, 'DashboardEngine')
                    error('FastSenseCompanion:invalidDashboard', ...
                        'Dashboards{%d} must be a DashboardEngine instance.', i);
                end
            end
            obj.Engines_   = dashboards;
            obj.Dashboards = dashboards;
            obj.Registry_  = registry;
            obj.Registry   = registry;
            % Reset selection tracking on project switch
            obj.SelectedDashboardIdx_ = 0;
            obj.LastInteraction_      = '';
            obj.SelectedTagKeys_      = {};
            % Rebuild pane placeholders (detach + reattach clears children and re-creates labels)
            obj.CatalogPane_.detach();
            obj.ListPane_.detach();
            obj.InspectorPane_.detach();
            obj.CatalogPane_.attach(obj.hLeftPanel_, obj.hFig_, obj.Registry_, obj.Theme_);
            obj.ListPane_.attach(obj.hMidPanel_, obj.hFig_, obj.Engines_, obj.Theme_);
            obj.InspectorPane_.attach(obj.hRightPanel_, obj.hFig_, obj.CatalogPane_, obj, obj.Theme_);
            % Phase 1023.1 cross-phase fix: clear orchestrator-owned listeners
            % before re-registering. Without this, every setProject() call
            % doubles the handler count for InspectorStateChanged,
            % OpenAdHocPlotRequested, and the three pane event listeners
            % (COMPSHELL-05). Iterate cell explicitly because
            % delete(cellArray) is interpreted as filename-delete by MATLAB.
            for ii = 1:numel(obj.Listeners_)
                lh = obj.Listeners_{ii};
                if isobject(lh) && isvalid(lh)
                    delete(lh);
                end
            end
            obj.Listeners_ = {};
            % Re-wire pane event listeners (detach cleared them)
            obj.Listeners_{end+1} = addlistener(obj.ListPane_, 'DashboardSelected', ...
                @(s, e) obj.onDashboardSelected_(s, e));
            obj.Listeners_{end+1} = addlistener(obj.ListPane_, 'OpenDashboardRequested', ...
                @(s, e) obj.onOpenDashboardRequested_(s, e));
            obj.Listeners_{end+1} = addlistener(obj.CatalogPane_, 'TagSelectionChanged', ...
                @(s, e) obj.onTagSelectionChanged_(s, e));
            obj.Listeners_{end+1} = addlistener(obj, 'InspectorStateChanged', ...
                @(s, e) obj.InspectorPane_.setState(e.State, e.Payload));
            obj.Listeners_{end+1} = addlistener(obj, 'OpenAdHocPlotRequested', ...
                @(s, e) obj.onOpenAdHocPlotRequested_(s, e));
            obj.applyPlaceholderColors_();
        end

        function addDashboard(obj, d)
        %ADDDASHBOARD Append a DashboardEngine to the browser; refresh the list.
        %   Throws FastSenseCompanion:invalidDashboard if d is not a DashboardEngine.
        %   Throws FastSenseCompanion:duplicateDashboard if d (by handle identity)
        %   already exists in Engines_.
            if ~isa(d, 'DashboardEngine')
                error('FastSenseCompanion:invalidDashboard', ...
                    'addDashboard requires a DashboardEngine instance.');
            end
            % Duplicate detection by handle identity (== compares handles)
            for i = 1:numel(obj.Engines_)
                if obj.Engines_{i} == d
                    error('FastSenseCompanion:duplicateDashboard', ...
                        'Dashboard already present in browser.');
                end
            end
            obj.Engines_{end+1} = d;
            obj.Dashboards       = obj.Engines_;
            if ~isempty(obj.ListPane_) && isvalid(obj.ListPane_)
                obj.ListPane_.refresh(obj.Engines_);
            end
        end

        function removeDashboard(obj, key)
        %REMOVEDASHBOARD Remove a dashboard by Name match.
        %   key — char; matches DashboardEngine.Name (case-sensitive).
        %   Throws FastSenseCompanion:dashboardNotFound if no engine has Name == key.
        %   If the removed dashboard was the currently inspected one, the inspector
        %   is reset to its placeholder/welcome state.
            if ~ischar(key)
                error('FastSenseCompanion:dashboardNotFound', ...
                    'removeDashboard requires a char Name key.');
            end
            idx = 0;
            for i = 1:numel(obj.Engines_)
                if strcmp(obj.Engines_{i}.Name, key)
                    idx = i;
                    break;
                end
            end
            if idx == 0
                error('FastSenseCompanion:dashboardNotFound', ...
                    'No dashboard with Name "%s".', key);
            end
            wasSelected = (obj.SelectedDashboardIdx_ == idx);
            obj.Engines_(idx) = [];
            obj.Dashboards    = obj.Engines_;
            if wasSelected
                obj.SelectedDashboardIdx_ = 0;
                obj.LastInteraction_      = '';
                obj.resolveInspectorState_();
                % Note: we no longer detach + reattach the inspector; the listener on
                % InspectorStateChanged drives the inspector content. This avoids tearing
                % down listeners mid-flow. (Phase 1018 detach-and-reattach was correct
                % when the inspector was a placeholder; Phase 1021 makes it event-driven.)
            elseif obj.SelectedDashboardIdx_ > idx
                % Shift index down since the removed entry was earlier in the cell
                obj.SelectedDashboardIdx_ = obj.SelectedDashboardIdx_ - 1;
            end
            if ~isempty(obj.ListPane_) && isvalid(obj.ListPane_)
                obj.ListPane_.refresh(obj.Engines_);
            end
        end

        function startLiveMode(obj)
        %STARTLIVEMODE Start (or resume) the inspector refresh timer.
        %   Idempotent. Companion launches with live mode already ON.
            if obj.IsLive; return; end
            try
                if isempty(obj.LiveTimer_) || ~isvalid(obj.LiveTimer_)
                    obj.LiveTimer_ = timer( ...
                        'ExecutionMode', 'fixedRate', ...
                        'Period',        obj.LivePeriod_, ...
                        'BusyMode',      'drop', ...
                        'TimerFcn',      @(~,~) obj.onLiveTick_(), ...
                        'ErrorFcn',      @(~,~) []);
                end
                if strcmp(obj.LiveTimer_.Running, 'off')
                    start(obj.LiveTimer_);
                end
                obj.IsLive = true;
                obj.updateLiveButton_();
                obj.addLogEntry('info', sprintf('Live mode ON (period %gs)', obj.LivePeriod_));
            catch err
                obj.addLogEntry('error', sprintf('Live start failed: %s', err.message));
            end
        end

        function stopLiveMode(obj)
        %STOPLIVEMODE Stop the inspector refresh timer (timer object kept for reuse).
            if ~obj.IsLive; return; end
            try
                if ~isempty(obj.LiveTimer_) && isvalid(obj.LiveTimer_) ...
                        && strcmp(obj.LiveTimer_.Running, 'on')
                    stop(obj.LiveTimer_);
                end
            catch
            end
            obj.IsLive = false;
            obj.updateLiveButton_();
            obj.addLogEntry('info', 'Live mode OFF');
        end

        function toggleLiveMode(obj)
        %TOGGLELIVEMODE Flip live mode on/off — bound to the toolbar button.
            if obj.IsLive
                obj.stopLiveMode();
            else
                obj.startLiveMode();
            end
        end

        function addLogEntry(obj, level, msg)
        %ADDLOGENTRY Append a timestamped log line.
        %   level — 'info' | 'warn' | 'error' (any short tag accepted)
        %   msg   — char/string. Anything else is sprintf'd through %s.
        %   Pushes onto LogBuffer_ (full history, newest first, capped at
        %   500), then re-applies the level + text filter to update the
        %   visible uitable rows.
            if isempty(obj.hLogTable_) || ~isvalid(obj.hLogTable_); return; end
            try
                ts = char(datetime('now', 'Format', 'HH:mm:ss'));
                if isstring(msg) && isscalar(msg); msg = char(msg); end
                if ~ischar(msg); msg = sprintf('%s', msg); end
                row = {ts, upper(char(level)), msg};
                obj.LogBuffer_ = [row; obj.LogBuffer_];
                if size(obj.LogBuffer_, 1) > 500
                    obj.LogBuffer_ = obj.LogBuffer_(1:500, :);
                end
                obj.applyLogFilter_();
            catch
                % Logging must never crash the UI.
            end
        end

        function refreshCatalog(obj)
        %REFRESHCATALOG Re-snapshot tags from registry and rebuild the tag catalog.
        %   Call after externally mutating TagRegistry to update the visible catalog.
        %   Prior to this call, the catalog shows the snapshot taken at construction
        %   or last setProject() call (no listener-leak risk on the static registry).
            if isempty(obj.CatalogPane_) || ~isvalid(obj.CatalogPane_)
                return;
            end
            obj.CatalogPane_.refresh();
        end

    end

    methods (Access = private)

        function buildLogStrip_(obj)
        %BUILDLOGSTRIP_ Construct two stacked logs: events (top) + live updates (bottom).
        %   Events: search + level filter + updated label + live toggle in
        %   the header, table below.
        %   Live updates: 'Live updates' label + Clear button in header,
        %   table {Time, Tag, +Samples, Latest} below.
            t = obj.Theme_;
            g = uigridlayout(obj.hLogPanel_, [4 1]);
            g.RowHeight   = {28, 150, 28, '1x'};
            g.ColumnWidth = {'1x'};
            g.Padding = [8 4 8 4];
            g.RowSpacing = 4;
            g.BackgroundColor = t.WidgetBackground;

            % Header: Log label | search | level dropdown | last-update | Live toggle.
            gHdr = uigridlayout(g, [1 5]);
            gHdr.Layout.Row = 1; gHdr.Layout.Column = 1;
            gHdr.ColumnWidth = {40, '1x', 100, 150, 110};
            gHdr.RowHeight = {'1x'};
            gHdr.Padding = [0 0 0 0];
            gHdr.ColumnSpacing = 8;
            gHdr.BackgroundColor = t.WidgetBackground;

            hLbl = uilabel(gHdr);
            hLbl.Layout.Row = 1; hLbl.Layout.Column = 1;
            hLbl.Text = 'Log'; hLbl.FontWeight = 'bold'; hLbl.FontSize = 11;
            hLbl.FontColor = t.ForegroundColor;
            hLbl.HorizontalAlignment = 'left'; hLbl.VerticalAlignment = 'center';

            obj.hLogSearch_ = uieditfield(gHdr, 'text');
            obj.hLogSearch_.Layout.Row = 1; obj.hLogSearch_.Layout.Column = 2;
            obj.hLogSearch_.Placeholder = 'Search log…';
            obj.hLogSearch_.FontSize = 11;
            obj.hLogSearch_.ValueChangedFcn = @(~,~) obj.applyLogFilter_();

            obj.hLogLevelDD_ = uidropdown(gHdr);
            obj.hLogLevelDD_.Layout.Row = 1; obj.hLogLevelDD_.Layout.Column = 3;
            obj.hLogLevelDD_.Items = {'All', 'INFO', 'WARN', 'ERROR'};
            obj.hLogLevelDD_.Value = 'All';
            obj.hLogLevelDD_.FontSize = 11;
            obj.hLogLevelDD_.Tooltip = 'Filter by log level';
            obj.hLogLevelDD_.ValueChangedFcn = @(~,~) obj.applyLogFilter_();

            obj.hLastUpdateLbl_ = uilabel(gHdr);
            obj.hLastUpdateLbl_.Layout.Row = 1; obj.hLastUpdateLbl_.Layout.Column = 4;
            obj.hLastUpdateLbl_.Text = 'Updated: --:--:--';
            obj.hLastUpdateLbl_.FontSize = 11; obj.hLastUpdateLbl_.FontName = 'Menlo';
            obj.hLastUpdateLbl_.FontColor = t.PlaceholderTextColor;
            obj.hLastUpdateLbl_.HorizontalAlignment = 'right';
            obj.hLastUpdateLbl_.VerticalAlignment = 'center';
            obj.hLastUpdateLbl_.Tooltip = 'Time of the last successful live refresh';

            obj.hLiveBtn_ = uibutton(gHdr, 'push');
            obj.hLiveBtn_.Layout.Row = 1; obj.hLiveBtn_.Layout.Column = 5;
            obj.hLiveBtn_.Text = 'Live: OFF';
            obj.hLiveBtn_.FontSize = 11; obj.hLiveBtn_.FontWeight = 'bold';
            obj.hLiveBtn_.Tooltip = 'Toggle live refresh of the inspector';
            obj.hLiveBtn_.ButtonPushedFcn = @(~,~) obj.toggleLiveMode();
            obj.updateLiveButton_();

            obj.hLogTable_ = uitable(g);
            obj.hLogTable_.Layout.Row = 2; obj.hLogTable_.Layout.Column = 1;
            obj.hLogTable_.ColumnName     = {'Time', 'Level', 'Message'};
            obj.hLogTable_.ColumnWidth    = {65, 55, 'auto'};
            obj.hLogTable_.ColumnEditable = [false false false];
            obj.hLogTable_.RowName        = {};
            obj.hLogTable_.FontSize       = 10;
            obj.hLogTable_.FontName       = 'Menlo';
            obj.hLogTable_.ForegroundColor = t.ForegroundColor;
            if strcmp(obj.Theme, 'dark')
                obj.hLogTable_.BackgroundColor = [0.13 0.13 0.13; 0.20 0.20 0.20];
            else
                obj.hLogTable_.BackgroundColor = [1.00 1.00 1.00; 0.94 0.94 0.94];
            end

            % Seed buffer with one ready line and apply filter.
            obj.LogBuffer_ = { ...
                char(datetime('now', 'Format', 'HH:mm:ss')), 'INFO', 'Companion ready.'};
            obj.applyLogFilter_();

            % --- Live updates header (label + Clear button) ---
            gLive = uigridlayout(g, [1 2]);
            gLive.Layout.Row = 3; gLive.Layout.Column = 1;
            gLive.ColumnWidth = {'1x', 80};
            gLive.RowHeight = {'1x'};
            gLive.Padding = [0 0 0 0]; gLive.ColumnSpacing = 8;
            gLive.BackgroundColor = t.WidgetBackground;

            hLiveLbl = uilabel(gLive);
            hLiveLbl.Layout.Row = 1; hLiveLbl.Layout.Column = 1;
            hLiveLbl.Text = 'Live updates'; hLiveLbl.FontWeight = 'bold'; hLiveLbl.FontSize = 11;
            hLiveLbl.FontColor = t.ForegroundColor;
            hLiveLbl.HorizontalAlignment = 'left'; hLiveLbl.VerticalAlignment = 'center';

            hLiveClear = uibutton(gLive, 'push');
            hLiveClear.Layout.Row = 1; hLiveClear.Layout.Column = 2;
            hLiveClear.Text = 'Clear'; hLiveClear.FontSize = 11;
            hLiveClear.Tooltip = 'Clear the live updates log';
            hLiveClear.ButtonPushedFcn = @(~,~) obj.clearLiveLog_();

            % --- Live updates table ---
            obj.hLiveLogTable_ = uitable(g);
            obj.hLiveLogTable_.Layout.Row = 4; obj.hLiveLogTable_.Layout.Column = 1;
            obj.hLiveLogTable_.ColumnName     = {'Time', 'Tag', char([8710, ' samples']), 'Latest'};
            obj.hLiveLogTable_.ColumnWidth    = {65, 'auto', 90, 90};
            obj.hLiveLogTable_.ColumnEditable = [false false false false];
            obj.hLiveLogTable_.RowName        = {};
            obj.hLiveLogTable_.FontSize       = 10;
            obj.hLiveLogTable_.FontName       = 'Menlo';
            obj.hLiveLogTable_.ForegroundColor = t.ForegroundColor;
            if strcmp(obj.Theme, 'dark')
                obj.hLiveLogTable_.BackgroundColor = [0.13 0.13 0.13; 0.20 0.20 0.20];
            else
                obj.hLiveLogTable_.BackgroundColor = [1.00 1.00 1.00; 0.94 0.94 0.94];
            end
            obj.hLiveLogTable_.Data = cell(0, 4);

            % Per-tag last-seen sample count map (for delta detection).
            obj.LiveSampleCount_ = containers.Map( ...
                'KeyType', 'char', 'ValueType', 'double');
        end

        function clearLiveLog_(obj)
        %CLEARLIVELOG_ Wipe the live-updates buffer + table.
            obj.LiveLogBuffer_ = cell(0, 4);
            if ~isempty(obj.hLiveLogTable_) && isvalid(obj.hLiveLogTable_)
                obj.hLiveLogTable_.Data = cell(0, 4);
            end
        end

        function addLiveLogEntry_(obj, tagKey, deltaSamples, latestY)
        %ADDLIVELOGENTRY_ Push a row into the live-updates log.
            if isempty(obj.hLiveLogTable_) || ~isvalid(obj.hLiveLogTable_); return; end
            try
                ts = char(datetime('now', 'Format', 'HH:mm:ss'));
                latestTxt = '—';
                if ~isempty(latestY) && isnumeric(latestY) && isfinite(latestY)
                    a = abs(latestY);
                    if a == 0;       latestTxt = '0';
                    elseif a >= 1000 || a < 0.01; latestTxt = sprintf('%.3g', latestY);
                    elseif a >= 100;  latestTxt = sprintf('%.0f', latestY);
                    elseif a >= 10;   latestTxt = sprintf('%.2f', latestY);
                    else;             latestTxt = sprintf('%.3f', latestY);
                    end
                elseif ischar(latestY) || (isstring(latestY) && isscalar(latestY))
                    latestTxt = char(latestY);
                end
                row = {ts, char(tagKey), sprintf('+%d', deltaSamples), latestTxt};
                obj.LiveLogBuffer_ = [row; obj.LiveLogBuffer_];
                if size(obj.LiveLogBuffer_, 1) > 500
                    obj.LiveLogBuffer_ = obj.LiveLogBuffer_(1:500, :);
                end
                obj.hLiveLogTable_.Data = obj.LiveLogBuffer_;
            catch
            end
        end

        function scanLiveTagUpdates_(obj)
        %SCANLIVETAGUPDATES_ Walk SensorTag/StateTag in TagRegistry; log size deltas.
            % Guard for the truly-uninitialized state (property default is []).
            % Do NOT use isempty() here — isempty(containers.Map) returns true
            % whenever the map has 0 entries, and the map only acquires keys
            % from inside this function (chicken-and-egg). buildLogStrip_()
            % constructs the map in the constructor before startLiveMode() runs,
            % so by the time the timer fires, LiveSampleCount_ is always a
            % containers.Map handle.
            if ~isa(obj.LiveSampleCount_, 'containers.Map'); return; end
            try
                tags = TagRegistry.find(@(t) isa(t, 'SensorTag') || isa(t, 'StateTag'));
            catch
                return;
            end
            for k = 1:numel(tags)
                tg = tags{k};
                try
                    if ~isobject(tg) || ~isvalid(tg); continue; end
                    key = char(tg.Key);
                    [tv, y] = tg.getXY();
                    n = numel(tv);
                    last = 0;
                    if obj.LiveSampleCount_.isKey(key)
                        last = obj.LiveSampleCount_(key);
                    end
                    if n > last
                        delta = n - last;
                        % Pull latest Y; for cellstr Y, use the label.
                        latestY = [];
                        if ~isempty(y)
                            if iscell(y); latestY = y{end}; else; latestY = y(end); end
                        end
                        if last > 0  % skip the first-seen baseline log
                            obj.addLiveLogEntry_(key, delta, latestY);
                        end
                        obj.LiveSampleCount_(key) = n;
                    end
                catch
                end
            end
        end

        function applyLogFilter_(obj)
        %APPLYLOGFILTER_ Re-apply level + text filter to LogBuffer_ → uitable.Data.
            if isempty(obj.hLogTable_) || ~isvalid(obj.hLogTable_); return; end
            rows = obj.LogBuffer_;
            if isempty(rows)
                obj.hLogTable_.Data = cell(0, 3); return;
            end
            % Level filter
            lvl = 'All';
            if ~isempty(obj.hLogLevelDD_) && isvalid(obj.hLogLevelDD_)
                lvl = obj.hLogLevelDD_.Value;
            end
            if ~strcmpi(lvl, 'All')
                keep = false(size(rows, 1), 1);
                for i = 1:size(rows, 1)
                    keep(i) = strcmpi(rows{i, 2}, lvl);
                end
                rows = rows(keep, :);
            end
            % Text filter — case-insensitive substring across all 3 columns.
            qry = '';
            if ~isempty(obj.hLogSearch_) && isvalid(obj.hLogSearch_)
                qry = strtrim(obj.hLogSearch_.Value);
            end
            if ~isempty(qry)
                qLow = lower(qry);
                keep = false(size(rows, 1), 1);
                for i = 1:size(rows, 1)
                    line = lower([rows{i, 1}, ' ', rows{i, 2}, ' ', rows{i, 3}]);
                    keep(i) = ~isempty(strfind(line, qLow)); %#ok<STREMP>
                end
                rows = rows(keep, :);
            end
            obj.hLogTable_.Data = rows;
        end

        function updateLiveButton_(obj)
        %UPDATELIVEBUTTON_ Reflect IsLive in the toolbar button text/colors.
            if isempty(obj.hLiveBtn_) || ~isvalid(obj.hLiveBtn_); return; end
            t = obj.Theme_;
            if obj.IsLive
                obj.hLiveBtn_.Text            = [char(9679) ' Live: ON'];
                obj.hLiveBtn_.BackgroundColor = t.Accent;
                obj.hLiveBtn_.FontColor       = t.DashboardBackground;
            else
                obj.hLiveBtn_.Text            = 'Live: OFF';
                obj.hLiveBtn_.BackgroundColor = t.WidgetBorderColor;
                obj.hLiveBtn_.FontColor       = t.ForegroundColor;
            end
        end

        function onLiveTick_(obj)
        %ONLIVETICK_ Periodic in-place refresh: tag sample count + X range +
        %   sparkline; or dashboard status. Uses InspectorPane.refreshLive
        %   (updates Data/XData/YData on existing widgets) to avoid layout
        %   teardown/rebuild flicker. The catalog and dashboard list are
        %   intentionally NOT refreshed (they would lose selection/scroll).
            if ~obj.IsLive || isempty(obj.hFig_) || ~isvalid(obj.hFig_); return; end
            try
                if ~isempty(obj.InspectorPane_) && isvalid(obj.InspectorPane_) ...
                        && ismethod(obj.InspectorPane_, 'refreshLive')
                    obj.InspectorPane_.refreshLive();
                end
                obj.scanLiveTagUpdates_();
                if ~isempty(obj.hLastUpdateLbl_) && isvalid(obj.hLastUpdateLbl_)
                    obj.hLastUpdateLbl_.Text = sprintf('Updated: %s', ...
                        char(datetime('now', 'Format', 'HH:mm:ss')));
                end
            catch
                % Live ticks must never crash the timer.
            end
        end

        function applyPlaceholderColors_(obj)
        %APPLYPLACEHOLDERCOLORS_ Set FontColor on all placeholder uilabels.
        %   Called after attach() on each pane so the theme color is applied.
            color  = obj.Theme_.PlaceholderTextColor;
            panels = {obj.hLeftPanel_, obj.hMidPanel_, obj.hRightPanel_};
            for i = 1:numel(panels)
                kids = panels{i}.Children;
                for j = 1:numel(kids)
                    if isa(kids(j), 'matlab.ui.control.Label')
                        kids(j).FontColor = color;
                    end
                end
            end
        end

        function onDashboardSelected_(obj, ~, ed)
        %ONDASHBOARDSELECTED_ Listener for DashboardListPane.DashboardSelected.
        %   ed — DashboardEventData with Engine + Index. Records selection state
        %   and asks the resolver to fire InspectorStateChanged.
            try
                obj.SelectedDashboardIdx_ = ed.Index;
                obj.LastInteraction_      = 'dashboard';
                obj.resolveInspectorState_();
                obj.addLogEntry('info', sprintf('Selected dashboard: %s', ...
                    char(ed.Engine.Name)));
            catch err
                obj.addLogEntry('error', sprintf('Dashboard select failed: %s', err.message));
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onOpenDashboardRequested_(obj, ~, ed)
        %ONOPENDASHBOARDREQUESTED_ Listener for DashboardListPane.OpenDashboardRequested.
        %   The pane already calls engine.render() with try/catch + uialert. The
        %   orchestrator records most-recent interaction and refreshes the inspector
        %   so the dashboard state shows for the just-opened engine.
            try
                obj.SelectedDashboardIdx_ = ed.Index;
                obj.LastInteraction_      = 'dashboard';
                obj.resolveInspectorState_();
                obj.addLogEntry('info', sprintf('Opened dashboard: %s', ...
                    char(ed.Engine.Name)));
            catch err
                obj.addLogEntry('error', sprintf('Open dashboard failed: %s', err.message));
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onTagSelectionChanged_(obj, ~, ~)
        %ONTAGSELECTIONCHANGED_ Listener for TagCatalogPane.TagSelectionChanged.
        %   Pulls the current selection cellstr from the pane (event payload-less,
        %   per Phase 1019 contract) and asks the resolver to fire InspectorStateChanged.
            try
                obj.SelectedTagKeys_ = obj.CatalogPane_.getSelectedKeys();
                obj.LastInteraction_ = 'tags';
                obj.resolveInspectorState_();
                if isempty(obj.SelectedTagKeys_)
                    obj.addLogEntry('info', 'Tag selection cleared');
                elseif numel(obj.SelectedTagKeys_) == 1
                    obj.addLogEntry('info', sprintf('Selected tag: %s', ...
                        char(obj.SelectedTagKeys_{1})));
                else
                    obj.addLogEntry('info', sprintf('Selected %d tags: %s', ...
                        numel(obj.SelectedTagKeys_), ...
                        strjoin(obj.SelectedTagKeys_, ', ')));
                end
            catch err
                obj.addLogEntry('error', sprintf('Tag select failed: %s', err.message));
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function resolveInspectorState_(obj)
        %RESOLVEINSPECTORSTATE_ Compute (state, payload) and fire InspectorStateChanged.
        %   Single notify point for the inspector. Inspector subscribes via the
        %   InspectorStateChanged listener wired in the constructor / setProject.
        %
        %   Resolution strategy: prefer tag HANDLES from the catalog snapshot
        %   (CatalogPane_.getSelectedTags()) over a TagRegistry.get() round
        %   trip. The catalog already has resolved Tag handles; using them
        %   directly bypasses any drift between the catalog snapshot and
        %   the TagRegistry singleton's current state (e.g. cooling.health
        %   visible in catalog but missing from get() — a real bug seen in
        %   the industrial plant demo). Keys without a matching handle in
        %   the catalog snapshot are silently dropped.
            try
                state   = '';
                payload = struct();
                tags = obj.CatalogPane_.getSelectedTags();
                nTags = numel(tags);

                if nTags == 1
                    state   = 'tag';
                    payload = struct('tag', tags{1}, ...
                                     'tagKeys', {obj.SelectedTagKeys_});
                elseif nTags >= 2
                    state   = 'multitag';
                    payload = struct('tags', {tags}, ...
                                     'tagKeys', {obj.SelectedTagKeys_});
                elseif strcmp(obj.LastInteraction_, 'dashboard') ...
                        && isnumeric(obj.SelectedDashboardIdx_) ...
                        && isscalar(obj.SelectedDashboardIdx_) ...
                        && obj.SelectedDashboardIdx_ > 0 ...
                        && obj.SelectedDashboardIdx_ <= numel(obj.Engines_)
                    state   = 'dashboard';
                    payload = struct('dashboard', ...
                                     obj.Engines_{obj.SelectedDashboardIdx_});
                else
                    state   = 'welcome';
                    payload = struct('nTags', nTags, ...
                                     'nDashboards', numel(obj.Engines_));
                end

                ed = InspectorStateEventData(state, payload);
                notify(obj, 'InspectorStateChanged', ed);
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onOpenAdHocPlotRequested_(obj, ~, evt)
        %ONOPENADHOCPLOTREQUESTED_ Listener for OpenAdHocPlotRequested event.
        %   Resolves AdHocPlotEventData.TagKeys to Tag handles via Registry_,
        %   delegates to openAdHocPlot for actual figure spawn. The companion
        %   does NOT track the spawned figure — closing it does not affect the
        %   companion (ADHOC-04 lifecycle independence is structural).
        %
        %   Partial-success (some tags failed): figure spawns AND uialert lists
        %   the skipped tag names. All-fail and resolution errors raise uialert
        %   without a spawned figure; companion stays alive.
            try
                keys = evt.TagKeys;
                mode = evt.Mode;
                % Prefer the catalog snapshot's already-resolved Tag handles
                % over a TagRegistry.get() round-trip (catalog/registry can
                % drift; see resolveInspectorState_).
                allTags  = obj.CatalogPane_.getSelectedTags();
                allKeys  = obj.SelectedTagKeys_;
                tags     = {};
                for k = 1:numel(keys)
                    matched = false;
                    for j = 1:numel(allTags)
                        if strcmp(allKeys{j}, keys{k})
                            tags{end+1} = allTags{j}; %#ok<AGROW>
                            matched = true;
                            break;
                        end
                    end
                    if ~matched
                        % Last-resort registry fallback (still wrapped in
                        % the outer try/catch so a missing key surfaces as
                        % uialert instead of crashing the figure callback).
                        tags{end+1} = obj.Registry_.get(keys{k}); %#ok<AGROW>
                    end
                end
                [~, skipped] = openAdHocPlot(tags, mode, obj.Theme);
                obj.addLogEntry('info', sprintf( ...
                    'Opened ad-hoc plot: %d tag(s) [%s]', ...
                    numel(tags), char(mode)));
                if ~isempty(skipped)
                    obj.addLogEntry('warn', sprintf( ...
                        'Ad-hoc plot skipped %d tag(s): %s', ...
                        numel(skipped), strjoin(skipped, ', ')));
                    msg = sprintf( ...
                        'Plot opened, but some tags were skipped:\n  - %s', ...
                        strjoin(skipped, sprintf('\n  - ')));
                    uialert(obj.hFig_, msg, 'FastSense Companion', ...
                        'Icon', 'warning');
                end
            catch ME
                obj.addLogEntry('error', sprintf('Ad-hoc plot failed: %s', ME.message));
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    uialert(obj.hFig_, ...
                        sprintf('Failed to open plot: %s', ME.message), ...
                        'FastSense Companion', 'Icon', 'error');
                end
            end
        end

    end

end
