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
    end

    properties (Access = private)
        hFig_          = []   % uifigure handle
        hLayout_       = []   % root uigridlayout handle
        hLeftPanel_    = []   % left pane uipanel
        hMidPanel_     = []   % middle pane uipanel
        hRightPanel_   = []   % right pane uipanel
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
                'Position',           [100 100 1200 800], ...
                'Resize',             'on', ...
                'AutoResizeChildren', 'off', ...
                'Visible',            'off');
            obj.hFig_.Color = obj.Theme_.DashboardBackground;

            % Step 8 — Root grid
            obj.hLayout_ = uigridlayout(obj.hFig_, [1 3]);
            obj.hLayout_.ColumnWidth   = {220, '1x', 280};
            obj.hLayout_.RowHeight     = {'1x'};
            obj.hLayout_.Padding       = [24 24 24 24];
            obj.hLayout_.ColumnSpacing = 16;
            obj.hLayout_.RowSpacing    = 0;
            obj.hLayout_.BackgroundColor = obj.Theme_.DashboardBackground;

            % Step 9 — Three uipanels (order matters: grid assigns col 1, 2, 3)
            obj.hLeftPanel_  = uipanel(obj.hLayout_);
            obj.hMidPanel_   = uipanel(obj.hLayout_);
            obj.hRightPanel_ = uipanel(obj.hLayout_);

            % Apply panel styling from theme
            for hp = {obj.hLeftPanel_, obj.hMidPanel_, obj.hRightPanel_}
                hp{1}.BackgroundColor = obj.Theme_.WidgetBackground;
                hp{1}.BorderColor     = obj.Theme_.WidgetBorderColor;
                hp{1}.BorderType      = 'line';
                hp{1}.BorderWidth     = 1;
            end

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
            if ~isvalid(obj)
                return;
            end
            if isempty(obj.hFig_) || ~isvalid(obj.hFig_)
                return;
            end
            % Detach panes (releases their listeners)
            if ~isempty(obj.CatalogPane_) && isvalid(obj.CatalogPane_)
                obj.CatalogPane_.detach();
            end
            if ~isempty(obj.ListPane_) && isvalid(obj.ListPane_)
                obj.ListPane_.detach();
            end
            if ~isempty(obj.InspectorPane_) && isvalid(obj.InspectorPane_)
                obj.InspectorPane_.detach();
            end
            % Release orchestrator-level listeners
            delete(obj.Listeners_);
            obj.Listeners_ = {};
            % No companion-owned timers in Phase 1018 — pattern established for Phases 1019+:
            %   stop(t); delete(t);  (always in this order)
            % Close the uifigure
            delete(obj.hFig_);
            obj.hFig_  = [];
            obj.IsOpen = false;
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
            catch err
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
            catch err
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
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function resolveInspectorState_(obj)
        %RESOLVEINSPECTORSTATE_ Compute (state, payload) and fire InspectorStateChanged.
        %   Single notify point for the inspector. Inspector subscribes via the
        %   InspectorStateChanged listener wired in the constructor / setProject.
            try
                [state, payload] = inspectorResolveState( ...
                    obj.LastInteraction_, ...
                    obj.SelectedTagKeys_, ...
                    obj.SelectedDashboardIdx_, ...
                    obj.Engines_, ...
                    obj.Registry_);
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
                tags = cell(1, numel(keys));
                for k = 1:numel(keys)
                    tags{k} = obj.Registry_.get(keys{k});
                end
                [~, skipped] = openAdHocPlot(tags, mode, obj.Theme);
                if ~isempty(skipped)
                    msg = sprintf( ...
                        'Plot opened, but some tags were skipped:\n  - %s', ...
                        strjoin(skipped, sprintf('\n  - ')));
                    uialert(obj.hFig_, msg, 'FastSense Companion', ...
                        'Icon', 'warning');
                end
            catch ME
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    uialert(obj.hFig_, ...
                        sprintf('Failed to open plot: %s', ME.message), ...
                        'FastSense Companion', 'Icon', 'error');
                end
            end
        end

    end

end
