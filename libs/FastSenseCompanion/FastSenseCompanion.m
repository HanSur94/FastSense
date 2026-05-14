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
%     LivePeriod — seconds between live refreshes (default: 1.0)
%     EventStore — EventStore handle or [] (default: auto-discover from registry)
%     SharedRoot — (cluster mode) path to shared filesystem root; default '' (single-user).
%
%   Public methods:
%     setProject(dashboards, registry) — rebuild against new project
%     addDashboard(d)                  - append a DashboardEngine; refresh browser
%     removeDashboard(key)             - remove by Name; reset inspector if it was selected
%     refreshCatalog()                 — re-snapshot tags and rebuild catalog
%     getEventStore()                  — resolved EventStore handle or []
%     close()                          — idempotent teardown
%
%   Events fired:
%     InspectorStateChanged    payload: InspectorStateEventData(state, payload)
%     OpenAdHocPlotRequested   payload: AdHocPlotEventData(tagKeys, mode) — fired by InspectorPane
%     LiveModeChanged          no payload — fires on startLiveMode/stopLiveMode after IsLive is updated
%
%   See also DashboardEngine, TagRegistry, CompanionTheme.

    events
        InspectorStateChanged
        OpenAdHocPlotRequested
        LiveModeChanged
    end

    properties (Access = public)
        % (intentionally empty — all user-observable state is SetAccess=private)
    end

    properties (SetAccess = private)
        Dashboards    = {}       % cell array of DashboardEngine passed by user
        Registry      = []       % TagRegistry reference
        Theme         = 'dark'   % preset string ('dark' | 'light')
        LivePeriod    = 1.0      % seconds; user-readable mirror of LivePeriod_
        IsOpen        = false    % true while uifigure is valid
        IsLive        = false    % true while LiveTimer_ is running (refreshes inspector)
        SharedRoot    = ''       % cluster shared filesystem root ('' in single-user mode)
        IsClusterMode = false    % logical; true iff SharedRoot is non-empty
    end

    properties (GetAccess = public, SetAccess = ?CompanionSettingsDialog)
        SettingsDlg_ = []     % CompanionSettingsDialog handle (or empty)
    end

    properties (Access = private)
        hFig_          = []   % uifigure handle
        hLayout_       = []   % root uigridlayout handle
        hToolbarPanel_ = []   % top toolbar uipanel (row 1, spans cols [1 3])
        hSettingsBtn_  = []   % gear button inside hToolbarPanel_ (right-aligned)
        hEventsBtn_    = []   % toolbar uibutton: Events viewer launch
        hLeftPanel_    = []   % left pane uipanel
        hMidPanel_     = []   % middle pane uipanel
        hRightPanel_   = []   % right pane uipanel
        hLogPanel_     = []   % bottom log uipanel (full-width); hosts hLogStripGrid_ with EventsLogPane and LiveLogPane sub-panels
        LiveSampleCount_ = []  % containers.Map(tagKey -> last seen sample count); pipeline state used by scanLiveTagUpdates_, initialised in constructor
        hLiveBtn_      = []   % Live mode toggle button (parented to top toolbar in Phase 1027)
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
        % Phase 1027.1 — independent EventsLogPane + LiveLogPane integration
        EventsLogPane_        = []     % EventsLogPane instance
        LiveLogPane_          = []     % LiveLogPane instance
        hDetachedEventsFig_   = []     % uifigure when events state == 'Detached', else []
        hDetachedLiveFig_     = []     % uifigure when live state   == 'Detached', else []
        hLogStripGrid_        = []     % inner uigridlayout([2 1]) hosting both sub-panels in row 3
        hEventsLogPanel_      = []     % sub-panel (LogPaneRoot-tagged) for events pane
        hLiveLogPanel_        = []     % sub-panel (LogPaneRoot-tagged) for live pane
        OriginalLogRowHeight_ = 360    % captured at construction; restored when at least one pane is Inline
        EventStore_  = []   % EventStore handle resolved via constructor option or auto-discovery
        EventViewer_ = []   % CompanionEventViewer handle (single-instance) or [] (Task 13 wires it)
        % Phase 1033 Plan 01 — cluster mode internal state
        SharedRoot_               = ''    % internal mirror of public SharedRoot
        IsClusterMode_            = false % internal cluster-mode gate
        LastContentionNoticeText_ = ''    % most recent contention notice (Plan 04 surfaces in UI)
    end

    methods (Access = public)

        function obj = FastSenseCompanion(varargin)
        %FASTSENSECOMPANION Constructor. Opens a themed three-pane uifigure immediately.
        %   Name-value pairs: 'Dashboards', 'Registry', 'Name', 'Theme', 'LivePeriod', 'EventStore'.

            % Step 1 — Octave guard (FIRST, before any other work)
            if exist('OCTAVE_VERSION', 'builtin') ~= 0
                error('FastSenseCompanion:notSupported', ...
                    'FastSenseCompanion requires MATLAB R2020b or later. Octave is not supported.');
            end

            % Step 2 — Built-in defaults
            userDashboards = {};
            userRegistry   = [];
            userName       = 'FastSense Companion';
            userTheme      = 'dark';
            userLivePeriod = 1.0;
            userEventStore = [];
            userSharedRoot = '';

            % Step 2b — Override with stored prefdir values (if present and well-formed).
            % Priority: built-in default < prefdir < explicit Name-Value (Step 3).
            stored = companionPrefs('load');
            if isstruct(stored)
                if isfield(stored, 'theme') && (ischar(stored.theme) || ...
                        (isstring(stored.theme) && isscalar(stored.theme)))
                    cand = char(stored.theme);
                    if any(strcmp(cand, {'dark','light'}))
                        userTheme = cand;
                    end
                end
                if isfield(stored, 'livePeriod') && ...
                        isnumeric(stored.livePeriod) && ...
                        isscalar(stored.livePeriod) && ...
                        isfinite(stored.livePeriod) && ...
                        stored.livePeriod > 0
                    userLivePeriod = double(stored.livePeriod);
                end
            end

            % Step 3 — Parse varargin (explicit Name-Value wins over prefdir).
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
                    case 'LivePeriod'
                        v = varargin{k+1};
                        if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v) || v <= 0
                            error('FastSenseCompanion:invalidLivePeriod', ...
                                'LivePeriod must be a positive finite scalar (seconds).');
                        end
                        userLivePeriod = double(v);
                    case 'EventStore'
                        v = varargin{k+1};
                        if ~isempty(v) && ~isa(v, 'EventStore')
                            error('FastSenseCompanion:invalidEventStore', ...
                                'EventStore must be an EventStore handle or [] (got %s).', class(v));
                        end
                        userEventStore = v;
                    case 'SharedRoot'
                        v = varargin{k+1};
                        if ~isempty(v) && ~(ischar(v) || (isstring(v) && isscalar(v)))
                            error('FastSenseCompanion:invalidSharedRoot', ...
                                'SharedRoot must be a non-empty char/string or empty (got %s).', class(v));
                        end
                        userSharedRoot = char(v);
                    otherwise
                        error('FastSenseCompanion:unknownOption', ...
                            ['Unknown option ''%s''. Valid options: ', ...
                             'Dashboards, Registry, Name, Theme, LivePeriod, EventStore, SharedRoot.'], key);
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
            obj.Engines_    = userDashboards;
            obj.Dashboards  = userDashboards;
            obj.Registry_   = userRegistry;
            obj.Registry    = userRegistry;
            obj.Theme       = userTheme;
            obj.Theme_      = CompanionTheme.get(userTheme);
            obj.LivePeriod_ = userLivePeriod;
            obj.LivePeriod  = userLivePeriod;

            % --- Cluster mode resolution (Phase 1033 Plan 01; OPS-01 partial) ---
            obj.SharedRoot_     = userSharedRoot;
            obj.SharedRoot      = userSharedRoot;
            obj.IsClusterMode_  = ~isempty(userSharedRoot);
            obj.IsClusterMode   = obj.IsClusterMode_;
            if obj.IsClusterMode_
                % Validate the shared root via ClusterConfig — throws
                % Concurrency:sharedRootUnreachable on a non-existent folder.
                ClusterConfig.resolve(struct('SharedRoot', userSharedRoot));
                % IDENT-01 fail-fast guard — throws Concurrency:identityResolutionFailed
                % when the OS cannot resolve a usable username/hostname (mirrors
                % EventStore cluster-mode init and LiveTagPipeline pattern).
                ClusterIdentity.resolve('Strict', true);
                % Best-effort oplock smoke test — never throws; one-time warning
                % via warning('Concurrency:smbOplockDetected', ...) on mismatch.
                try
                    ClusterConfig.checkSharedConfig(userSharedRoot);
                catch
                    % checkSharedConfig is documented to be best-effort and never
                    % throw, but guard anyway so a stray error from a future
                    % refactor cannot prevent the companion from opening.
                end
            end

            % Step 6b — Resolve EventStore: explicit override wins; otherwise
            % auto-discover from the registry, with cluster-mode upgrade when SharedRoot is set.
            obj.EventStore_ = companionDiscoverEventStore(obj.SharedRoot_, userEventStore);

            % Step 7 — Build uifigure (Visible='off' while building)
            obj.hFig_ = uifigure( ...
                'Name',               userName, ...
                'Position',           [100 100 1320 800], ...
                'Resize',             'on', ...
                'AutoResizeChildren', 'off', ...
                'Visible',            'off');
            obj.hFig_.Color = obj.Theme_.DashboardBackground;

            % Step 8 — Root grid (3 rows: top toolbar = 32 px, panes = 1x, log strip = 360 px)
            obj.hLayout_ = uigridlayout(obj.hFig_, [3 3]);
            obj.hLayout_.ColumnWidth   = {220, '1x', 360};
            obj.hLayout_.RowHeight     = {32, '1x', 360};
            obj.hLayout_.Padding       = [24 24 24 24];
            obj.hLayout_.ColumnSpacing = 16;
            obj.hLayout_.RowSpacing    = 12;
            obj.hLayout_.BackgroundColor = obj.Theme_.DashboardBackground;

            % Step 9a — Top toolbar panel (row 1, spans all 3 columns).
            obj.hToolbarPanel_ = uipanel(obj.hLayout_);
            obj.hToolbarPanel_.Layout.Row    = 1;
            obj.hToolbarPanel_.Layout.Column = [1 3];
            obj.hToolbarPanel_.BorderType      = 'none';
            obj.hToolbarPanel_.BackgroundColor = obj.Theme_.WidgetBackground;
            % Inner 1x4 grid — col 1 = Events viewer button (Task 13);
            % col 2 = Live: ON/OFF button; col 3 = flex spacer;
            % col 4 = gear button.
            hToolbarGrid = uigridlayout(obj.hToolbarPanel_, [1 4]);
            hToolbarGrid.ColumnWidth     = {110, 110, '1x', 36};
            hToolbarGrid.RowHeight       = {'1x'};
            hToolbarGrid.Padding         = [4 0 4 0];
            hToolbarGrid.ColumnSpacing   = 8;
            hToolbarGrid.BackgroundColor = obj.Theme_.WidgetBackground;

            % Col 1 — Events viewer launch (Task 13).
            obj.hEventsBtn_ = uibutton(hToolbarGrid, 'push');
            obj.hEventsBtn_.Layout.Row    = 1;
            obj.hEventsBtn_.Layout.Column = 1;
            obj.hEventsBtn_.Text          = ['Events ', char(8599)];   % ↗
            obj.hEventsBtn_.FontSize      = 11;
            obj.hEventsBtn_.FontWeight    = 'bold';
            obj.hEventsBtn_.Tag           = 'CompanionEventsBtn';
            obj.hEventsBtn_.Tooltip       = 'Open the event viewer';
            obj.hEventsBtn_.ButtonPushedFcn = @(~,~) obj.openEventViewer_();
            if isempty(obj.EventStore_)
                obj.hEventsBtn_.Enable  = 'off';
                obj.hEventsBtn_.Tooltip = 'No EventStore registered';
            end

            % Col 2 — Live: ON/OFF button (Phase 1027: moved from log header).
            obj.hLiveBtn_ = uibutton(hToolbarGrid, 'push');
            obj.hLiveBtn_.Layout.Row    = 1;
            obj.hLiveBtn_.Layout.Column = 2;
            obj.hLiveBtn_.Text          = 'Live: OFF';
            obj.hLiveBtn_.FontSize      = 11;
            obj.hLiveBtn_.FontWeight    = 'bold';
            obj.hLiveBtn_.Tooltip       = 'Toggle live refresh of the inspector';
            obj.hLiveBtn_.ButtonPushedFcn = @(~,~) obj.toggleLiveMode();

            % Col 4 — Settings gear.
            obj.hSettingsBtn_ = uibutton(hToolbarGrid, 'push');
            obj.hSettingsBtn_.Layout.Row    = 1;
            obj.hSettingsBtn_.Layout.Column = 4;
            obj.hSettingsBtn_.Text          = char(9881);   % gear glyph
            obj.hSettingsBtn_.FontSize      = 14;
            obj.hSettingsBtn_.Tooltip       = 'Companion settings';
            obj.hSettingsBtn_.BackgroundColor = obj.Theme_.WidgetBorderColor;
            obj.hSettingsBtn_.FontColor       = obj.Theme_.ForegroundColor;
            obj.hSettingsBtn_.ButtonPushedFcn = @(~,~) obj.openSettings();

            % Step 9b — Three uipanels in row 2 + log panel spanning row 3.
            obj.hLeftPanel_  = uipanel(obj.hLayout_);
            obj.hLeftPanel_.Layout.Row = 2; obj.hLeftPanel_.Layout.Column = 1;
            obj.hMidPanel_   = uipanel(obj.hLayout_);
            obj.hMidPanel_.Layout.Row = 2; obj.hMidPanel_.Layout.Column = 2;
            obj.hRightPanel_ = uipanel(obj.hLayout_);
            obj.hRightPanel_.Layout.Row = 2; obj.hRightPanel_.Layout.Column = 3;
            obj.hLogPanel_ = uipanel(obj.hLayout_);
            obj.hLogPanel_.Layout.Row = 3; obj.hLogPanel_.Layout.Column = [1 3];
            % Phase 1027.1 -- LogPaneRoot tag moves to the two sub-panels below.

            % Apply panel styling from theme. uifigure-uipanel border
            % properties (BorderColor, BorderWidth) are R2021a+; on R2020b
            % they error with UnsupportedAppDesignerFunctionality even
            % though isprop() reports them as present. Tolerate failure
            % per-property — BackgroundColor works on all versions.
            for hp = {obj.hLeftPanel_, obj.hMidPanel_, obj.hRightPanel_, obj.hLogPanel_}
                hp{1}.BackgroundColor = obj.Theme_.WidgetBackground;
                try, hp{1}.BorderColor = obj.Theme_.WidgetBorderColor; catch, end
                try, hp{1}.BorderType  = 'line';                      catch, end
                try, hp{1}.BorderWidth = 1;                           catch, end
            end

            % Phase 1027.1 -- inner [2 1] grid hosting two LogPaneRoot-tagged sub-panels.
            obj.hLogStripGrid_ = uigridlayout(obj.hLogPanel_, [2 1]);
            obj.hLogStripGrid_.RowHeight     = {180, '1x'};   % default Inline+Inline
            obj.hLogStripGrid_.ColumnWidth   = {'1x'};
            obj.hLogStripGrid_.Padding       = [0 0 0 0];
            obj.hLogStripGrid_.RowSpacing    = 4;
            obj.hLogStripGrid_.BackgroundColor = obj.Theme_.WidgetBackground;

            obj.hEventsLogPanel_ = uipanel(obj.hLogStripGrid_);
            obj.hEventsLogPanel_.Layout.Row    = 1;
            obj.hEventsLogPanel_.Layout.Column = 1;
            obj.hEventsLogPanel_.BorderType    = 'none';
            obj.hEventsLogPanel_.BackgroundColor = obj.Theme_.WidgetBackground;
            obj.hEventsLogPanel_.Tag = 'LogPaneRoot';   % theme walker skip rule

            obj.hLiveLogPanel_ = uipanel(obj.hLogStripGrid_);
            obj.hLiveLogPanel_.Layout.Row    = 2;
            obj.hLiveLogPanel_.Layout.Column = 1;
            obj.hLiveLogPanel_.BorderType    = 'none';
            obj.hLiveLogPanel_.BackgroundColor = obj.Theme_.WidgetBackground;
            obj.hLiveLogPanel_.Tag = 'LogPaneRoot';   % theme walker skip rule

            % Phase 1027 — capture the row-3 height once for restore on Inline.
            rh3 = obj.hLayout_.RowHeight{3};
            if isnumeric(rh3) && isscalar(rh3) && isfinite(rh3) && rh3 > 0
                obj.OriginalLogRowHeight_ = rh3;
            end

            % Phase 1027.1 -- instantiate both panes; wire DetachRequested listeners.
            obj.EventsLogPane_ = EventsLogPane(obj.Theme_);
            obj.LiveLogPane_   = LiveLogPane(obj.Theme_);
            obj.Listeners_{end+1} = addlistener(obj.EventsLogPane_, 'DetachRequested', ...
                @(~,~) obj.setLogState_('events', 'Detached'));
            obj.Listeners_{end+1} = addlistener(obj.LiveLogPane_, 'DetachRequested', ...
                @(~,~) obj.setLogState_('live', 'Detached'));
            % LiveSampleCount_ is companion-owned per Phase 1027 boundary --
            % NEITHER pane tracks per-tag pipeline cursors.
            obj.LiveSampleCount_ = containers.Map( ...
                'KeyType', 'char', 'ValueType', 'double');
            % Attach both panes inline by default.
            obj.setLogState_('events', 'Inline');
            obj.setLogState_('live',   'Inline');
            % Seed the events log with the ready line.
            obj.addLogEntry('info', 'Companion ready.');

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
            % Tear down the event viewer first so its listener doesn't fire
            % into a half-deleted companion. Independent try/catch — viewer
            % failure must not block the rest of teardown.
            try
                if ~isempty(obj.EventViewer_) && isvalid(obj.EventViewer_)
                    obj.EventViewer_.close();
                end
            catch err
                fprintf(2, '[FastSenseCompanion] EventViewer cleanup failed: %s\n', err.message);
            end
            obj.EventViewer_ = [];
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
            % Phase 1027.1 -- close any open detached uifigures FIRST (clear
            % CloseRequestFcn so it can't fire mid-teardown), then destroy
            % both panes. Order between events/live doesn't matter.
            try
                if ~isempty(obj.hDetachedEventsFig_) && isvalid(obj.hDetachedEventsFig_)
                    obj.hDetachedEventsFig_.CloseRequestFcn = '';
                    delete(obj.hDetachedEventsFig_);
                end
            catch err
                fprintf(2, '[FastSenseCompanion] hDetachedEventsFig cleanup failed: %s\n', err.message);
            end
            obj.hDetachedEventsFig_ = [];
            try
                if ~isempty(obj.hDetachedLiveFig_) && isvalid(obj.hDetachedLiveFig_)
                    obj.hDetachedLiveFig_.CloseRequestFcn = '';
                    delete(obj.hDetachedLiveFig_);
                end
            catch err
                fprintf(2, '[FastSenseCompanion] hDetachedLiveFig cleanup failed: %s\n', err.message);
            end
            obj.hDetachedLiveFig_ = [];
            try
                if ~isempty(obj.EventsLogPane_) && isvalid(obj.EventsLogPane_)
                    obj.EventsLogPane_.detach();
                    delete(obj.EventsLogPane_);
                end
            catch err
                fprintf(2, '[FastSenseCompanion] EventsLogPane cleanup failed: %s\n', err.message);
            end
            obj.EventsLogPane_ = [];
            try
                if ~isempty(obj.LiveLogPane_) && isvalid(obj.LiveLogPane_)
                    obj.LiveLogPane_.detach();
                    delete(obj.LiveLogPane_);
                end
            catch err
                fprintf(2, '[FastSenseCompanion] LiveLogPane cleanup failed: %s\n', err.message);
            end
            obj.LiveLogPane_ = [];
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
            % Tear down a still-open settings dialog, if any.
            try
                if ~isempty(obj.SettingsDlg_) && isvalid(obj.SettingsDlg_)
                    delete(obj.SettingsDlg_);
                end
            catch err
                fprintf(2, '[FastSenseCompanion] SettingsDlg cleanup failed: %s\n', err.message);
            end
            obj.SettingsDlg_ = [];
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
            % Phase 1027.1 -- re-register both panes' DetachRequested listeners.
            if ~isempty(obj.EventsLogPane_) && isvalid(obj.EventsLogPane_)
                obj.Listeners_{end+1} = addlistener(obj.EventsLogPane_, 'DetachRequested', ...
                    @(~,~) obj.setLogState_('events', 'Detached'));
            end
            if ~isempty(obj.LiveLogPane_) && isvalid(obj.LiveLogPane_)
                obj.Listeners_{end+1} = addlistener(obj.LiveLogPane_, 'DetachRequested', ...
                    @(~,~) obj.setLogState_('live', 'Detached'));
            end
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
                notify(obj, 'LiveModeChanged');
            catch err
                obj.addLogEntry('error', sprintf('Live start failed: %s', err.message));
            end
        end

        function stopLiveMode(obj)
        %STOPLIVEMODE Stop the inspector refresh timer (timer object kept for reuse).
            if ~obj.IsLive; return; end
            try
                if ~isempty(obj.LiveTimer_) && isvalid(obj.LiveTimer_) && ...
                        strcmp(obj.LiveTimer_.Running, 'on')
                    stop(obj.LiveTimer_);
                end
            catch
            end
            obj.IsLive = false;
            obj.updateLiveButton_();
            obj.addLogEntry('info', 'Live mode OFF');
            notify(obj, 'LiveModeChanged');
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
        %ADDLOGENTRY Append a timestamped log line. Forwards to EventsLogPane_.
        %   Phase 1027.1: actual buffering + filter + render lives in
        %   EventsLogPane. This method survives as the public API for code
        %   that calls `obj.addLogEntry(...)` directly (existing callers are
        %   unchanged).
            if isempty(obj.EventsLogPane_) || ~isvalid(obj.EventsLogPane_); return; end
            obj.EventsLogPane_.addLogEntry(level, msg);
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

        function applyTheme(obj, theme)
        %APPLYTHEME Live theme switch — repaints all panes + log strip + toolbar; persists.
        %   theme — 'dark' | 'light'.
        %   On invalid input throws FastSenseCompanion:invalidTheme.
        %   On propagation failure rolls back Theme/Theme_ to their previous
        %   values and rethrows. After successful apply, persists via
        %   companionPrefs('save', ...).
            if ~ischar(theme) && ~(isstring(theme) && isscalar(theme))
                error('FastSenseCompanion:invalidTheme', ...
                    'Theme must be a char ''dark'' or ''light''.');
            end
            theme = char(theme);
            if ~any(strcmp(theme, {'dark','light'}))
                error('FastSenseCompanion:invalidTheme', ...
                    'Theme must be ''dark'' or ''light'' (got ''%s'').', theme);
            end
            prevTheme  = obj.Theme;
            prevTheme_ = obj.Theme_;
            try
                obj.Theme  = theme;
                obj.Theme_ = CompanionTheme.get(theme);
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    obj.hFig_.Color = obj.Theme_.DashboardBackground;
                end
                if ~isempty(obj.hLayout_) && isvalid(obj.hLayout_)
                    obj.hLayout_.BackgroundColor = obj.Theme_.DashboardBackground;
                end
                % Repaint every panel + log strip + toolbar via the recursive walker.
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    applyThemeToChildren_(obj.hFig_, obj.Theme_);
                end
                % Per-pane setTheme — in-place where safe; setState for inspector.
                if ~isempty(obj.CatalogPane_) && isvalid(obj.CatalogPane_)
                    obj.CatalogPane_.setTheme(obj.Theme_);
                end
                if ~isempty(obj.ListPane_) && isvalid(obj.ListPane_)
                    obj.ListPane_.setTheme(obj.Theme_);
                end
                if ~isempty(obj.InspectorPane_) && isvalid(obj.InspectorPane_)
                    obj.InspectorPane_.setTheme(obj.Theme_);
                end
                % Phase 1027.1 -- both panes manage their own theming (walker
                % skips both LogPaneRoot-tagged sub-panels). Companion calls
                % applyTheme on each pane and updates each detached uifigure's
                % background.
                if ~isempty(obj.EventsLogPane_) && isvalid(obj.EventsLogPane_)
                    obj.EventsLogPane_.applyTheme(obj.Theme_);
                end
                if ~isempty(obj.LiveLogPane_) && isvalid(obj.LiveLogPane_)
                    obj.LiveLogPane_.applyTheme(obj.Theme_);
                end
                if ~isempty(obj.hDetachedEventsFig_) && isvalid(obj.hDetachedEventsFig_)
                    obj.hDetachedEventsFig_.Color = obj.Theme_.DashboardBackground;
                end
                if ~isempty(obj.hDetachedLiveFig_) && isvalid(obj.hDetachedLiveFig_)
                    obj.hDetachedLiveFig_.Color = obj.Theme_.DashboardBackground;
                end
                obj.updateLiveButton_();
                drawnow;
            catch err
                obj.Theme  = prevTheme;
                obj.Theme_ = prevTheme_;
                rethrow(err);
            end
            obj.savePrefs_();
        end

        function setLivePeriod(obj, seconds)
        %SETLIVEPERIOD Change the live-mode timer Period and persist.
        %   seconds — positive finite scalar (seconds, > 0).
        %   On invalid input throws FastSenseCompanion:invalidLivePeriod.
        %   Stops the LiveTimer_ if running, sets the new Period, restarts
        %   only if it was running before. Persists to prefdir.
            if ~isnumeric(seconds) || ~isscalar(seconds) || ...
                    ~isfinite(seconds) || seconds <= 0
                error('FastSenseCompanion:invalidLivePeriod', ...
                    'LivePeriod must be a positive finite scalar (seconds).');
            end
            seconds = double(seconds);
            obj.LivePeriod_ = seconds;
            obj.LivePeriod  = seconds;
            wasLive = obj.IsLive;
            if ~isempty(obj.LiveTimer_) && isvalid(obj.LiveTimer_)
                try
                    if strcmp(obj.LiveTimer_.Running, 'on')
                        stop(obj.LiveTimer_);
                    end
                    obj.LiveTimer_.Period = seconds;
                    if wasLive
                        start(obj.LiveTimer_);
                    end
                catch err
                    obj.addLogEntry('error', ...
                        sprintf('Live period change failed: %s', err.message));
                end
            end
            obj.savePrefs_();
        end

        function openSettings(obj)
        %OPENSETTINGS Open or focus the singleton CompanionSettingsDialog.
        %   Idempotent: a second call brings the existing dialog forward
        %   instead of constructing a new one.
            if ~isempty(obj.SettingsDlg_) && isvalid(obj.SettingsDlg_) && ...
                    ~isempty(obj.SettingsDlg_.hFig_) && ...
                    isvalid(obj.SettingsDlg_.hFig_)
                figure(obj.SettingsDlg_.hFig_);
                return;
            end
            obj.SettingsDlg_ = CompanionSettingsDialog(obj);
        end

        % --- Test helpers (Phase 1027.1) -- do not call from production ---
        % These accessors expose private state to TestFastSenseCompanion only.
        % They are intentionally public (MATLAB has no friend-class scope), but
        % production code paths must continue to use the private members
        % directly (EventsLogPane_, LiveLogPane_, etc.) -- these wrappers exist
        % solely so the test suite can verify state machine behavior without
        % relaxing access on the real properties.

        function p = getEventsLogPane(obj)
        %GETEVENTSLOGPANE Test helper: return the EventsLogPane instance.
            p = obj.EventsLogPane_;
        end

        function p = getLiveLogPane(obj)
        %GETLIVELOGPANE Test helper: return the LiveLogPane instance.
            p = obj.LiveLogPane_;
        end

        function v = getEventsLogStateValue(obj)
        %GETEVENTSLOGSTATEVALUE Test helper: return current events log state ('Inline'|'Detached'|'Hidden'|'').
        %   Derives state from pane attachment + detached-figure validity (dropdowns removed).
            v = obj.deriveLogState_('events');
        end

        function v = getLiveLogStateValue(obj)
        %GETLIVELOGSTATEVALUE Test helper: return current live log state ('Inline'|'Detached'|'Hidden'|'').
        %   Derives state from pane attachment + detached-figure validity (dropdowns removed).
            v = obj.deriveLogState_('live');
        end

        function hf = getDetachedEventsFig(obj)
        %GETDETACHEDEVENTSFIG Test helper: return the events detached uifigure handle or [].
            hf = obj.hDetachedEventsFig_;
        end

        function hf = getDetachedLiveFig(obj)
        %GETDETACHEDLIVEFIG Test helper: return the live detached uifigure handle or [].
            hf = obj.hDetachedLiveFig_;
        end

        function rh = getRow3Height(obj)
        %GETROW3HEIGHT Test helper: return numeric row 3 height of hLayout_.
            rh = obj.hLayout_.RowHeight{3};
        end

        function applyLogState(obj, which, newState)
        %APPLYLOGSTATE Test helper: public wrapper for the private setLogState_.
            obj.setLogState_(which, newState);
        end

        function par = getLiveButtonParent(obj)
        %GETLIVEBUTTONPARENT Test helper: return the parent handle of hLiveBtn_.
            if isempty(obj.hLiveBtn_) || ~isvalid(obj.hLiveBtn_)
                par = [];
            else
                par = obj.hLiveBtn_.Parent;
            end
        end

        function s = getEventStore(obj)
        %GETEVENTSTORE Return the resolved EventStore handle (or [] if none).
        %   Returns whatever was passed via the 'EventStore' constructor
        %   option, OR the auto-discovered store from the registry, OR []
        %   if neither resolved.
            s = obj.EventStore_;
        end

        function r = getSharedRoot(obj)
        %GETSHAREDROOT Return the resolved SharedRoot (or '' if single-user).
            r = obj.SharedRoot_;
        end

        function tf = getIsClusterMode(obj)
        %GETISCLUSTERMODE Return the cluster-mode gate.
            tf = obj.IsClusterMode_;
        end

        function s = getLastContentionNoticeText(obj)
        %GETLASTCONTENTIONNOTICETEXT Return the cluster contention banner text
        %   (or '' when no contention has been observed since startup).
        %   Plan 04 wires the live polling that populates this property.
            s = obj.LastContentionNoticeText_;
        end

        function openEventViewer(obj)
        %OPENEVENTVIEWER Public alias for the toolbar callback (used by tests / scripting).
            obj.openEventViewer_();
        end

        function openEventViewer_internalForTest(obj)
        %OPENEVENTVIEWER_INTERNALFORTEST Test shim: call openEventViewer_ directly.
            obj.openEventViewer_();
        end

        function v = getEventViewerForTest_(obj)
        %GETEVENTVIEWERFORTEST_ Test helper: return the EventViewer_ handle or [].
            v = obj.EventViewer_;
        end

        function f = getFigForTest_(obj)
        %GETFIGFORTEST_ Test helper: return the companion uifigure handle.
            f = obj.hFig_;
        end

    end

    methods (Access = private)

        function savePrefs_(obj)
        %SAVEPREFS_ Persist current Theme + LivePeriod to prefdir.
        %   Companion-side wrapper around companionPrefs('save', prefs).
        %   Never throws — companionPrefs is the safety net.
            prefs = struct('theme', obj.Theme, 'livePeriod', obj.LivePeriod_);
            companionPrefs('save', prefs);
        end

        function v = deriveLogState_(obj, which)
        %DERIVELOGSTATE_ Return the actual state of a log pane as a char.
        %   which — 'events' | 'live'
        %   Returns 'Inline' | 'Detached' | 'Hidden' | '' (if pane invalid).
            if strcmp(which, 'events')
                pane    = obj.EventsLogPane_;
                detFig  = obj.hDetachedEventsFig_;
            else
                pane    = obj.LiveLogPane_;
                detFig  = obj.hDetachedLiveFig_;
            end
            if isempty(pane) || ~isvalid(pane)
                v = '';
                return;
            end
            attached    = pane.IsAttached;
            hasDetached = ~isempty(detFig) && isvalid(detFig);
            if attached && ~hasDetached
                v = 'Inline';
            elseif hasDetached
                v = 'Detached';
            else
                v = 'Hidden';
            end
        end

        function setLogState_(obj, which, newState)
        %SETLOGSTATE_ Transition one log pane between Inline / Detached / Hidden.
        %   Single transition function called from:
        %     - EventsLogPane_/LiveLogPane_.DetachRequested listeners
        %     - hDetachedEventsFig_/hDetachedLiveFig_.CloseRequestFcn
        %   Idempotent: derives current state from the pane's own attachment
        %   plus the corresponding hDetached*Fig_ validity. Same lesson as
        %   Phase 1027 fix-commit 3e6c155.
        %
        %   which    -- char: 'events' | 'live'
        %   newState -- char: 'Inline' | 'Detached' | 'Hidden'
            if ~ischar(which) && ~(isstring(which) && isscalar(which))
                error('FastSenseCompanion:invalidLogWhich', ...
                    'which must be ''events'' or ''live''.');
            end
            which = lower(char(which));
            if ~any(strcmp(which, {'events', 'live'}))
                error('FastSenseCompanion:invalidLogWhich', ...
                    'which must be ''events'' or ''live'' (got ''%s'').', which);
            end
            if ~ischar(newState) && ~(isstring(newState) && isscalar(newState))
                error('FastSenseCompanion:invalidLogState', ...
                    'newState must be ''Inline'', ''Detached'', or ''Hidden''.');
            end
            newState = char(newState);
            if ~any(strcmp(newState, {'Inline', 'Detached', 'Hidden'}))
                error('FastSenseCompanion:invalidLogState', ...
                    'newState must be ''Inline'', ''Detached'', or ''Hidden'' (got ''%s'').', ...
                    newState);
            end

            % Resolve which pane / parent / detached handle to use.
            if strcmp(which, 'events')
                pane     = obj.EventsLogPane_;
                panel    = obj.hEventsLogPanel_;
                detName  = 'hDetachedEventsFig_';
                figTitle = sprintf('FastSense Companion %s Events Log', char(8212));
                figSize  = [720 480];
            else
                pane     = obj.LiveLogPane_;
                panel    = obj.hLiveLogPanel_;
                detName  = 'hDetachedLiveFig_';
                figTitle = sprintf('FastSense Companion %s Live Log', char(8212));
                figSize  = [480 360];
            end

            if isempty(pane) || ~isvalid(pane); return; end

            % Idempotency: derive actual state from pane attachment + detFig validity.
            detFig = obj.(detName);
            hasDetached = ~isempty(detFig) && isvalid(detFig);
            attached    = pane.IsAttached;
            inState = '';
            if attached && ~hasDetached
                inState = 'Inline';
            elseif attached && hasDetached
                inState = 'Detached';
            elseif ~attached && ~hasDetached
                inState = 'Hidden';
            end
            if strcmp(inState, newState)
                return;
            end

            try
                switch newState
                    case 'Inline'
                        if ~isempty(detFig) && isvalid(detFig)
                            detFig.CloseRequestFcn = '';
                            delete(detFig);
                        end
                        obj.(detName) = [];
                        if pane.IsAttached
                            pane.detach();
                        end
                        pane.attach(panel, obj.Theme_);

                    case 'Detached'
                        if pane.IsAttached
                            pane.detach();
                        end
                        newFig = uifigure( ...
                            'Name',     figTitle, ...
                            'Position', [0 0 figSize(1) figSize(2)], ...
                            'Color',    obj.Theme_.DashboardBackground);
                        movegui(newFig, 'center');
                        % CloseRequestFcn drives state back to Inline. The
                        % cleared-handler dance in 'Inline' above prevents
                        % recursion when WE delete it programmatically.
                        newFig.CloseRequestFcn = ...
                            @(~,~) obj.setLogState_(which, 'Inline');
                        obj.(detName) = newFig;
                        pane.attach(newFig, obj.Theme_);

                    case 'Hidden'
                        if ~isempty(detFig) && isvalid(detFig)
                            detFig.CloseRequestFcn = '';
                            delete(detFig);
                        end
                        obj.(detName) = [];
                        if pane.IsAttached
                            pane.detach();
                        end
                end
                obj.rebalanceLogStrip_();
            catch err
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    uialert(obj.hFig_, err.message, 'FastSense Companion');
                end
            end
        end

        function rebalanceLogStrip_(obj)
        %REBALANCELOGSTRIP_ Recompute inner hLogStripGrid_.RowHeight + outer hLayout_.RowHeight{3}
        %   from BOTH panes' actual attachment state (pane.IsAttached AND
        %   the corresponding hDetached*Fig_ validity -- a pane "Inline"
        %   means attached AND no detached uifigure).
        %   Single-source of truth so callers (setLogState_ and tests) never
        %   touch row heights directly.
            if isempty(obj.hLogStripGrid_) || ~isvalid(obj.hLogStripGrid_); return; end
            evtInline  = false;
            liveInline = false;
            if ~isempty(obj.EventsLogPane_) && isvalid(obj.EventsLogPane_) && ...
                    obj.EventsLogPane_.IsAttached && ...
                    (isempty(obj.hDetachedEventsFig_) || ~isvalid(obj.hDetachedEventsFig_))
                evtInline = true;
            end
            if ~isempty(obj.LiveLogPane_) && isvalid(obj.LiveLogPane_) && ...
                    obj.LiveLogPane_.IsAttached && ...
                    (isempty(obj.hDetachedLiveFig_) || ~isvalid(obj.hDetachedLiveFig_))
                liveInline = true;
            end
            % Inner sub-grid row heights (events row 1, live row 2).
            if evtInline && liveInline
                obj.hLogStripGrid_.RowHeight = {180, '1x'};
            elseif evtInline && ~liveInline
                obj.hLogStripGrid_.RowHeight = {'1x', 0};
            elseif ~evtInline && liveInline
                obj.hLogStripGrid_.RowHeight = {0, '1x'};
            else
                obj.hLogStripGrid_.RowHeight = {0, 0};
            end
            % Outer row 3: collapse to 0 only when neither pane is inline.
            if evtInline || liveInline
                obj.hLayout_.RowHeight{3} = obj.OriginalLogRowHeight_;
            else
                obj.hLayout_.RowHeight{3} = 0;
            end
        end

        function scanLiveTagUpdates_(obj)
        %SCANLIVETAGUPDATES_ Walk SensorTag/StateTag in TagRegistry; log size deltas.
            % Guard for the truly-uninitialized state (property default is []).
            % Do NOT use isempty() here — isempty(containers.Map) returns true
            % whenever the map has 0 entries, and the map only acquires keys
            % from inside this function (chicken-and-egg). The constructor
            % initialises the map before startLiveMode() runs, so by the
            % time the timer fires, LiveSampleCount_ is always a
            % containers.Map handle.
            if ~isa(obj.LiveSampleCount_, 'containers.Map'); return; end
            if isempty(obj.LiveLogPane_) || ~isvalid(obj.LiveLogPane_); return; end
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
                            obj.LiveLogPane_.addLiveLogEntry(key, delta, latestY);
                        end
                        obj.LiveSampleCount_(key) = n;
                    end
                catch
                end
            end
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
                if ~isempty(obj.InspectorPane_) && isvalid(obj.InspectorPane_) && ...
                        ismethod(obj.InspectorPane_, 'refreshLive')
                    obj.InspectorPane_.refreshLive();
                end
                obj.scanLiveTagUpdates_();
                if ~isempty(obj.EventsLogPane_) && isvalid(obj.EventsLogPane_)
                    obj.EventsLogPane_.setLastUpdated(datetime('now'));
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
                elseif strcmp(obj.LastInteraction_, 'dashboard') && ...
                        isnumeric(obj.SelectedDashboardIdx_) && ...
                        isscalar(obj.SelectedDashboardIdx_) && ...
                        obj.SelectedDashboardIdx_ > 0 && ...
                        obj.SelectedDashboardIdx_ <= numel(obj.Engines_)
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

        function openEventViewer_(obj)
        %OPENEVENTVIEWER_ Open the singleton CompanionEventViewer.
        %   No-op when EventStore_ is empty. While the viewer is open, the
        %   toolbar Events button is disabled — closing the viewer re-enables it.
            if isempty(obj.EventStore_); return; end
            if ~isempty(obj.EventViewer_) && isvalid(obj.EventViewer_) && ...
                    ~isempty(obj.EventViewer_.hFigure) && isgraphics(obj.EventViewer_.hFigure)
                obj.EventViewer_.bringToFront();
                return;
            end
            obj.EventViewer_ = CompanionEventViewer(obj.EventStore_, obj.Registry_, obj);
            % Listen on BOTH the viewer's figure AND the viewer object:
            %   - Figure listener (commit 18906f7): fires when the user
            %     closes the window or anyone calls viewer.close() — the
            %     viewer object survives in EventViewer_ so its own
            %     ObjectBeingDestroyed never fires that way.
            %   - Object listener: fires on programmatic delete(v) without
            %     a prior close() — keeps the existing
            %     testViewerObjectBeingDestroyedClearsHandle contract.
            % Either path clears EventViewer_ and re-enables the toolbar button.
            obj.Listeners_{end+1} = addlistener(obj.EventViewer_.hFigure, 'ObjectBeingDestroyed', ...
                @(~,~) obj.clearEventViewerHandle_());
            obj.Listeners_{end+1} = addlistener(obj.EventViewer_, 'ObjectBeingDestroyed', ...
                @(~,~) obj.clearEventViewerHandle_());
            % Disable the launch button so it visually reflects that the viewer
            % is currently open. The destruction listener re-enables it.
            if ~isempty(obj.hEventsBtn_) && isvalid(obj.hEventsBtn_)
                obj.hEventsBtn_.Enable  = 'off';
                obj.hEventsBtn_.Tooltip = 'Event viewer is open';
            end
        end

        function clearEventViewerHandle_(obj)
        %CLEAREVENTVIEWERHANDLE_ ObjectBeingDestroyed callback: clear the stale
        %   handle and re-enable the launch button. Guarded against being fired
        %   after the companion itself has been destroyed (which can happen
        %   during shutdown when both objects' destructors race).
            if ~isvalid(obj); return; end
            try
                obj.EventViewer_ = [];
            catch
            end
            if ~isempty(obj.hEventsBtn_) && isvalid(obj.hEventsBtn_)
                obj.hEventsBtn_.Enable  = 'on';
                obj.hEventsBtn_.Tooltip = 'Open the event viewer';
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
