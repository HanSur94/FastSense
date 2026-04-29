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
%     refreshCatalog()                 — re-snapshot tags and rebuild catalog
%     close()                          — idempotent teardown
%
%   See also DashboardEngine, TagRegistry, CompanionTheme.

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
            obj.ListPane_.attach(obj.hMidPanel_);
            obj.InspectorPane_.attach(obj.hRightPanel_);
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
            % Rebuild pane placeholders (detach + reattach clears children and re-creates labels)
            obj.CatalogPane_.detach();
            obj.ListPane_.detach();
            obj.InspectorPane_.detach();
            obj.CatalogPane_.attach(obj.hLeftPanel_, obj.hFig_, obj.Registry_, obj.Theme_);
            obj.ListPane_.attach(obj.hMidPanel_);
            obj.InspectorPane_.attach(obj.hRightPanel_);
            obj.applyPlaceholderColors_();
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

    end

end
