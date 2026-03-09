classdef FastPlotDock < handle
    %FASTPLOTDOCK Tabbed container for multiple FastPlotFigure dashboards.
    %   Manages multiple FastPlotFigure instances as switchable tabs in a
    %   single window. Each tab has its own panel, toolbar, close button,
    %   and undock button. Tabs can be dynamically added, removed, or
    %   popped out into standalone figures.
    %
    %   dock = FastPlotDock()
    %   dock = FastPlotDock('Theme', 'dark')
    %   dock = FastPlotDock('Theme', 'dark', 'Name', 'My Dock')
    %
    %   Constructor options (name-value):
    %     'Theme' — theme preset name, struct, or FastPlotTheme
    %     Any additional name-value pairs are passed to figure().
    %
    %   FastPlotDock Properties:
    %     Theme        — FastPlotTheme struct applied to all tabs
    %     hFigure      — shared figure handle for the dock window
    %     ShowProgress — show console progress bar during renderAll
    %     TabBarHeight — normalized height of the tab bar (default 0.03)
    %
    %   FastPlotDock Methods:
    %     FastPlotDock    — construct a tabbed dock container
    %     addTab          — register a FastPlotFigure as a tab
    %     render          — render active tab, create tab bar, show first tab
    %     renderAll       — eagerly render all tabs with hierarchical progress
    %     selectTab       — switch to tab n, rendering lazily if needed
    %     removeTab       — close and remove tab n
    %     undockTab       — pop tab n out into its own standalone figure
    %     recomputeLayout — reposition tab/undock/close buttons on resize
    %     reapplyTheme    — re-apply theme to dock, tab bar, panels, and all tabs
    %     delete          — clean up dock: stop all live timers and close figure
    %
    %   Example:
    %     dock = FastPlotDock('Theme', 'dark', 'Name', 'Dashboard');
    %     fig1 = FastPlotFigure(2, 1, 'ParentFigure', dock.hFigure);
    %     fig1.tile(1).addLine(x, y1); fig1.tile(2).addLine(x, y2);
    %     dock.addTab(fig1, 'Temperature');
    %     fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    %     fig2.tile(1).addLine(x, y3);
    %     dock.addTab(fig2, 'Pressure');
    %     dock.render();
    %
    %   See also FastPlotFigure, FastPlot, FastPlotToolbar, FastPlotTheme.

    % ========================= PUBLIC PROPERTIES =========================
    properties (Access = public)
        Theme     = []         % FastPlotTheme struct
        hFigure   = []         % shared figure handle
        ShowProgress = true   % show console progress bar during renderAll
    end

    % ====================== INTERNAL STATE ===============================
    properties (SetAccess = private)
        Tabs      = struct('Name', {}, 'Figure', {}, 'Panel', {}, 'IsRendered', {})
        Toolbar   = []         % shared FastPlotToolbar instance
        ActiveTab = 0          % index of currently visible tab
        hTabButtons = {}       % cell array of uicontrol handles
        hCloseButtons = {}     % cell array of close button handles
        hUndockButtons = {}    % cell array of undock button handles
    end

    % ====================== LAYOUT SETTINGS ==============================
    properties (Access = public)
        TabBarHeight = 0.03   % normalized height of tab bar
    end

    methods (Access = public)
        function obj = FastPlotDock(varargin)
            %FASTPLOTDOCK Construct a tabbed dock container.
            %   dock = FastPlotDock()
            %   dock = FastPlotDock('Theme', 'dark', 'Name', 'My Dock')
            %
            %   Creates a figure with a tab bar. Use addTab() to register
            %   FastPlotFigure instances, then call render().
            cfg = getDefaults();
            obj.TabBarHeight = cfg.TabBarHeight;

            conDefaults.Theme = [];
            [conOpts, figOpts] = parseOpts(conDefaults, varargin);
            obj.Theme = resolveTheme(conOpts.Theme, cfg.Theme);

            figOptsCell = struct2nvpairs(figOpts);
            obj.hFigure = figure('Visible', 'off', ...
                'Color', obj.Theme.Background, figOptsCell{:});
            set(obj.hFigure, 'SizeChangedFcn', @(s,e) obj.recomputeLayout());
            set(obj.hFigure, 'CloseRequestFcn', @(s,e) obj.onClose());
            setappdata(obj.hFigure, 'FastPlotDock', obj);
        end

        function addTab(obj, fig, name)
            %ADDTAB Register a FastPlotFigure as a tab.
            %   dock.addTab(fig, name) adds a FastPlotFigure as a new tab
            %   in the dock. The figure's ParentFigure and hFigure are
            %   redirected to the dock's shared figure. A uipanel is created
            %   for the tab's content, offset below the tab bar.
            %
            %   If the dock has already been rendered (ActiveTab >= 1),
            %   the new tab is rendered immediately and its button is added.
            %
            %   Inputs:
            %     fig  — FastPlotFigure instance to dock
            %     name — display name for the tab button
            %
            %   See also removeTab, undockTab, selectTab.

            % Ensure the figure renders into our window
            if isempty(fig.ParentFigure) || fig.ParentFigure ~= obj.hFigure
                fig.ParentFigure = obj.hFigure;
                fig.hFigure = obj.hFigure;
            end

            % Tiles fill the full panel (panel handles the tab bar offset)
            fig.ContentOffset = [0, 0, 1, 1];

            % Create a panel for this tab's content
            tabH = obj.TabBarHeight;
            panel = uipanel(obj.hFigure, 'Units', 'normalized', ...
                'Position', [0, 0, 1, 1 - tabH], ...
                'BorderType', 'none', ...
                'BackgroundColor', obj.Theme.Background);

            % Append to tabs
            idx = numel(obj.Tabs) + 1;
            obj.Tabs(idx).Name = name;
            obj.Tabs(idx).Figure = fig;
            obj.Tabs(idx).Panel = panel;
            obj.Tabs(idx).IsRendered = false;

            % If already rendered, render this tab immediately
            if obj.ActiveTab >= 1
                obj.renderTab(idx);
                obj.setTabVisible(idx, false);
                obj.addTabButton(idx);
            end
        end

        function render(obj)
            %RENDER Render active tab, create tab bar, show first tab.
            %   dock.render() renders only the first tab (lazy rendering),
            %   creates tab bar buttons for all tabs, attaches a shared
            %   FastPlotToolbar, selects tab 1, and makes the figure visible.
            %   Subsequent tabs are rendered on-demand when selectTab is called.
            %
            %   See also renderAll, selectTab.
            if isempty(obj.Tabs)
                set(obj.hFigure, 'Visible', 'on');
                return;
            end

            % Mark all tabs as not yet rendered
            for i = 1:numel(obj.Tabs)
                obj.Tabs(i).IsRendered = false;
            end

            % Only render the first tab now
            obj.renderTab(1);

            % Hide all tabs (selectTab will show tab 1)
            for i = 1:numel(obj.Tabs)
                obj.setTabVisible(i, false);
            end

            % Create the tab bar buttons
            obj.createTabBar();

            % Create shared toolbar for first tab
            obj.Toolbar = FastPlotToolbar(obj.Tabs(1).Figure);

            % Show the first tab
            obj.selectTab(1);

            set(obj.hFigure, 'Visible', 'on');
            w = warning('off', 'MATLAB:callback:error');
            drawnow;
            warning(w);
        end

        function renderAll(obj)
            %RENDERALL Eagerly render all tabs with hierarchical progress.
            %   dock.renderAll() renders every tab upfront (not lazily).
            %   Shows hierarchical console progress: tab headers + per-tile
            %   progress bars. After all tabs are rendered, creates the tab
            %   bar, shared toolbar, and selects tab 1.
            %
            %   Unlike render(), which defers tab rendering until selection,
            %   renderAll() pays the full cost upfront for smoother tab
            %   switching at runtime.
            %
            %   See also render, selectTab.
            if isempty(obj.Tabs)
                set(obj.hFigure, 'Visible', 'on');
                return;
            end

            nTabs = numel(obj.Tabs);

            % Suppress MATLAB internal warnings during batch render
            wState = warning('off', 'all');
            restoreWarn = onCleanup(@() warning(wState));

            % Render all tabs (no toolbars, no drawnow yet)
            for t = 1:nTabs
                if obj.ShowProgress
                    fprintf('Tab %d/%d: %s\n', t, nTabs, obj.Tabs(t).Name);
                end
                obj.Tabs(t).Figure.ShowProgress = obj.ShowProgress;
                obj.Tabs(t).Figure.renderAll(true);
                obj.reparentAxes(t);
                obj.Tabs(t).IsRendered = true;
            end

            % Hide all tabs, create tab bar
            for i = 1:nTabs
                obj.setTabVisible(i, false);
            end
            obj.createTabBar();

            % Create shared toolbar, then show tab 1
            obj.Toolbar = FastPlotToolbar(obj.Tabs(1).Figure);
            obj.selectTab(1);

            set(obj.hFigure, 'Visible', 'on');
            drawnow;
        end

        function selectTab(obj, n)
            %SELECTTAB Switch to tab n, rendering it lazily if needed.
            %   dock.selectTab(n) hides the currently active tab, renders
            %   tab n if it hasn't been rendered yet, rebinds the shared
            %   toolbar to the new tab's FastPlotFigure, and shows tab n.
            %
            %   Input:
            %     n — tab index (1 to numel(Tabs))
            %
            %   See also addTab, removeTab, render.
            if n < 1 || n > numel(obj.Tabs)
                error('FastPlotDock:outOfBounds', ...
                    'Tab %d is out of range (1-%d).', n, numel(obj.Tabs));
            end

            % Guard against calling selectTab before render()
            if isempty(obj.hTabButtons)
                return;
            end

            % Lazy render on first switch
            if ~obj.Tabs(n).IsRendered
                obj.renderTab(n);
            end

            % Rebind shared toolbar to new tab
            if ~isempty(obj.Toolbar)
                obj.Toolbar.rebind(obj.Tabs(n).Figure);
            else
                obj.Toolbar = FastPlotToolbar(obj.Tabs(n).Figure);
            end

            % Hide current tab
            if obj.ActiveTab >= 1 && obj.ActiveTab <= numel(obj.Tabs)
                obj.setTabVisible(obj.ActiveTab, false);
                obj.styleTabButton(obj.ActiveTab, false);
            end

            % Show new tab
            obj.setTabVisible(n, true);
            obj.styleTabButton(n, true);
            obj.ActiveTab = n;
        end

        function removeTab(obj, n)
            %REMOVETAB Close and remove tab n.
            %   dock.removeTab(n) stops live mode on the tab, deletes its
            %   panel and UI buttons, removes it from all internal arrays,
            %   and rebuilds the tab bar. If the removed tab was active, the
            %   nearest remaining tab is selected. If no tabs remain, the
            %   toolbar is also deleted.
            %
            %   Input:
            %     n — tab index (1 to numel(Tabs))
            %
            %   See also addTab, undockTab.
            if n < 1 || n > numel(obj.Tabs)
                return;
            end

            % Stop live mode on the tab's figure
            if ~isempty(obj.Tabs(n).Figure)
                try obj.Tabs(n).Figure.stopLive(); catch; end
            end

            % Delete panel (and all child axes)
            if ~isempty(obj.Tabs(n).Panel) && ishandle(obj.Tabs(n).Panel)
                delete(obj.Tabs(n).Panel);
            end

            % Delete tab button, undock button, and close button
            if n <= numel(obj.hTabButtons) && ishandle(obj.hTabButtons{n})
                delete(obj.hTabButtons{n});
            end
            if n <= numel(obj.hUndockButtons) && ishandle(obj.hUndockButtons{n})
                delete(obj.hUndockButtons{n});
            end
            if n <= numel(obj.hCloseButtons) && ishandle(obj.hCloseButtons{n})
                delete(obj.hCloseButtons{n});
            end

            % Remove from arrays
            obj.Tabs(n) = [];
            obj.hTabButtons(n) = [];
            obj.hUndockButtons(n) = [];
            obj.hCloseButtons(n) = [];

            if isempty(obj.Tabs)
                obj.ActiveTab = 0;
                if ~isempty(obj.Toolbar) && ~isempty(obj.Toolbar.hToolbar) && ishandle(obj.Toolbar.hToolbar)
                    delete(obj.Toolbar.hToolbar);
                end
                obj.Toolbar = [];
                return;
            end

            % Adjust active tab index
            if obj.ActiveTab == n
                newActive = min(n, numel(obj.Tabs));
                obj.ActiveTab = 0;  % reset so selectTab shows it
                obj.selectTab(newActive);
            elseif obj.ActiveTab > n
                obj.ActiveTab = obj.ActiveTab - 1;
            end

            % Rebuild button layout and re-bind callbacks
            obj.rebuildTabBar();
        end

        function undockTab(obj, n)
            %UNDOCKTAB Pop tab n out into its own standalone figure.
            %   dock.undockTab(n) creates a new standalone figure, stops
            %   live mode, reparents all tile axes from the dock panel to
            %   the new figure, recomputes tile positions for standalone
            %   layout, creates a fresh FastPlotToolbar, and removes the
            %   tab from the dock. The remaining dock tabs are reindexed
            %   and the tab bar is rebuilt.
            %
            %   Input:
            %     n — tab index (1 to numel(Tabs))
            %
            %   See also removeTab, addTab.
            if n < 1 || n > numel(obj.Tabs)
                return;
            end

            % Render if not yet rendered (need axes to reparent)
            if ~obj.Tabs(n).IsRendered
                obj.renderTab(n);
            end

            fig = obj.Tabs(n).Figure;
            tabName = obj.Tabs(n).Name;
            panel = obj.Tabs(n).Panel;

            % Stop live mode before undocking
            if ~isempty(fig)
                try fig.stopLive(); catch; end
            end

            % Create a new standalone figure
            newFig = figure('Visible', 'off', ...
                'Color', obj.Theme.Background, ...
                'Name', tabName);

            % Reparent all tile axes from dock panel to new figure
            fig.hFigure = newFig;
            fig.ParentFigure = [];
            fig.ContentOffset = [0, 0, 1, 1];
            for j = 1:numel(fig.TileAxes)
                if ~isempty(fig.TileAxes{j}) && ishandle(fig.TileAxes{j})
                    set(fig.TileAxes{j}, 'Parent', newFig);
                    % Recompute position for standalone layout
                    pos = fig.computeTilePosition(j);
                    set(fig.TileAxes{j}, 'Position', pos);
                end
            end

            % Delete the now-empty panel (don't delete children — they moved)
            if ~isempty(panel) && ishandle(panel)
                delete(panel);
            end

            % Delete tab button, close button, undock button
            if n <= numel(obj.hTabButtons) && ishandle(obj.hTabButtons{n})
                delete(obj.hTabButtons{n});
            end
            if n <= numel(obj.hCloseButtons) && ishandle(obj.hCloseButtons{n})
                delete(obj.hCloseButtons{n});
            end
            if n <= numel(obj.hUndockButtons) && ishandle(obj.hUndockButtons{n})
                delete(obj.hUndockButtons{n});
            end

            % Remove from arrays
            obj.Tabs(n) = [];
            obj.hTabButtons(n) = [];
            obj.hCloseButtons(n) = [];
            obj.hUndockButtons(n) = [];

            % Create toolbar on the new standalone figure
            FastPlotToolbar(fig);

            % Show the new figure (suppress MATLAB R2025b reparenting warnings)
            set(newFig, 'Visible', 'on');
            w = warning('off', 'MATLAB:callback:error');
            drawnow;
            warning(w);

            % Handle remaining dock tabs
            if isempty(obj.Tabs)
                obj.ActiveTab = 0;
                if ~isempty(obj.Toolbar) && ~isempty(obj.Toolbar.hToolbar) && ishandle(obj.Toolbar.hToolbar)
                    delete(obj.Toolbar.hToolbar);
                end
                obj.Toolbar = [];
                return;
            end

            if obj.ActiveTab == n
                newActive = min(n, numel(obj.Tabs));
                obj.ActiveTab = 0;
                obj.selectTab(newActive);
            elseif obj.ActiveTab > n
                obj.ActiveTab = obj.ActiveTab - 1;
            end

            obj.rebuildTabBar();
        end

        function recomputeLayout(obj)
            %RECOMPUTELAYOUT Reposition tab, undock, and close buttons on resize.
            %   dock.recomputeLayout() recalculates the normalized positions
            %   of all tab, undock (^), and close (x) buttons based on the
            %   current number of tabs. Called automatically on
            %   SizeChangedFcn and after addTabButton/rebuildTabBar.
            if ~isempty(obj.hTabButtons)
                nTabs = numel(obj.hTabButtons);
                tabH = obj.TabBarHeight;
                smallW = 0.02;  % width for close and undock buttons
                btnWidth = 1 / nTabs;
                for i = 1:nTabs
                    if ishandle(obj.hTabButtons{i})
                        set(obj.hTabButtons{i}, 'Position', ...
                            [(i-1)*btnWidth, 1 - tabH, btnWidth - 2*smallW, tabH]);
                    end
                    if i <= numel(obj.hUndockButtons) && ishandle(obj.hUndockButtons{i})
                        set(obj.hUndockButtons{i}, 'Position', ...
                            [i*btnWidth - 2*smallW, 1 - tabH, smallW, tabH]);
                    end
                    if i <= numel(obj.hCloseButtons) && ishandle(obj.hCloseButtons{i})
                        set(obj.hCloseButtons{i}, 'Position', ...
                            [i*btnWidth - smallW, 1 - tabH, smallW, tabH]);
                    end
                end
            end
        end

        function reapplyTheme(obj)
            %REAPPLYTHEME Re-apply theme to dock, tab bar, panels, and all tabs.
            %   dock.reapplyTheme() updates the figure background, re-styles
            %   all tab/undock/close buttons, updates panel backgrounds, and
            %   propagates the theme to every tab's FastPlotFigure (calling
            %   reapplyTheme on rendered figures).
            %
            %   See also FastPlotFigure.reapplyTheme.
            set(obj.hFigure, 'Color', obj.Theme.Background);
            for i = 1:numel(obj.hTabButtons)
                if ishandle(obj.hTabButtons{i})
                    obj.styleTabButton(i, i == obj.ActiveTab);
                end
            end
            for i = 1:numel(obj.hUndockButtons)
                if ishandle(obj.hUndockButtons{i})
                    set(obj.hUndockButtons{i}, 'BackgroundColor', obj.Theme.Background, ...
                        'ForegroundColor', obj.Theme.ForegroundColor);
                end
            end
            for i = 1:numel(obj.hCloseButtons)
                if ishandle(obj.hCloseButtons{i})
                    set(obj.hCloseButtons{i}, 'BackgroundColor', obj.Theme.Background, ...
                        'ForegroundColor', obj.Theme.ForegroundColor);
                end
            end
            for i = 1:numel(obj.Tabs)
                if ~isempty(obj.Tabs(i).Panel) && ishandle(obj.Tabs(i).Panel)
                    set(obj.Tabs(i).Panel, 'BackgroundColor', obj.Theme.Background);
                end
                if ~isempty(obj.Tabs(i).Figure)
                    obj.Tabs(i).Figure.Theme = obj.Theme;
                    if obj.Tabs(i).IsRendered
                        obj.Tabs(i).Figure.reapplyTheme();
                    end
                end
            end
        end

        function delete(obj)
            %DELETE Clean up dock: stop all live timers and close figure.
            %   Called automatically when the object is destroyed. Stops
            %   live mode on every tab, deletes the shared toolbar, and
            %   closes the figure window.
            for i = 1:numel(obj.Tabs)
                if ~isempty(obj.Tabs(i).Figure)
                    try obj.Tabs(i).Figure.stopLive(); catch; end
                end
            end
            if ~isempty(obj.Toolbar) && ~isempty(obj.Toolbar.hToolbar) && ishandle(obj.Toolbar.hToolbar)
                delete(obj.Toolbar.hToolbar);
            end
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                delete(obj.hFigure);
            end
        end
    end

    % ======================== PRIVATE METHODS ============================
    % Tab bar UI creation, axes reparenting, visibility, and styling.
    methods (Access = private)
        function reparentAxes(obj, idx)
            %REPARENTAXES Move all tile axes into the tab's panel.
            %   reparentAxes(obj, idx) sets the Parent of every tile axes
            %   in tab idx's FastPlotFigure to the tab's uipanel. This
            %   ensures axes are clipped to the panel and hidden/shown
            %   with it during tab switching.
            %
            %   Input:
            %     idx — tab index (1 to numel(Tabs))
            fig = obj.Tabs(idx).Figure;
            panel = obj.Tabs(idx).Panel;
            for j = 1:numel(fig.TileAxes)
                if ~isempty(fig.TileAxes{j}) && ishandle(fig.TileAxes{j})
                    set(fig.TileAxes{j}, 'Parent', panel);
                end
            end
        end

        function renderTab(obj, idx)
            %RENDERTAB Render a single tab: figure and axes reparenting.
            %   renderTab(obj, idx) calls renderAll on the tab's
            %   FastPlotFigure, reparents the axes into the tab's panel,
            %   and marks the tab as rendered.
            %
            %   Input:
            %     idx — tab index (1 to numel(Tabs))
            obj.Tabs(idx).Figure.renderAll();
            obj.reparentAxes(idx);
            obj.Tabs(idx).IsRendered = true;
        end

        function createTabBar(obj)
            %CREATETABBAR Create tab/undock/close buttons for all tabs.
            %   Initializes the button arrays and calls addTabButton for
            %   each tab. Called once during render() or renderAll().
            obj.hTabButtons = {};
            obj.hCloseButtons = {};
            obj.hUndockButtons = {};
            for i = 1:numel(obj.Tabs)
                obj.addTabButton(i);
            end
        end

        function addTabButton(obj, idx)
            %ADDTABBUTTON Create tab, undock, and close buttons for one tab.
            %   addTabButton(obj, idx) creates three uicontrol widgets for
            %   tab idx: a togglebutton for selection, a '^' pushbutton for
            %   undocking, and an 'x' pushbutton for closing. Positions are
            %   computed proportionally across the tab bar, then all buttons
            %   are repositioned via recomputeLayout.
            %
            %   Input:
            %     idx — tab index (1 to numel(Tabs))
            tabH = obj.TabBarHeight;
            nTabs = numel(obj.Tabs);
            btnWidth = 1 / nTabs;
            smallW = 0.02;

            btn = uicontrol(obj.hFigure, ...
                'Style', 'togglebutton', ...
                'String', obj.Tabs(idx).Name, ...
                'Units', 'normalized', ...
                'Position', [(idx-1)*btnWidth, 1 - tabH, btnWidth - 2*smallW, tabH], ...
                'FontSize', 9, ...
                'Callback', @(s,e) obj.onTabClick(idx));
            obj.hTabButtons{idx} = btn;

            ubtn = uicontrol(obj.hFigure, ...
                'Style', 'pushbutton', ...
                'String', '^', ...
                'Units', 'normalized', ...
                'Position', [idx*btnWidth - 2*smallW, 1 - tabH, smallW, tabH], ...
                'FontSize', 8, ...
                'TooltipString', 'Undock tab', ...
                'BackgroundColor', obj.Theme.Background, ...
                'ForegroundColor', obj.Theme.ForegroundColor, ...
                'Callback', @(s,e) obj.undockTab(idx));
            obj.hUndockButtons{idx} = ubtn;

            cbtn = uicontrol(obj.hFigure, ...
                'Style', 'pushbutton', ...
                'String', 'x', ...
                'Units', 'normalized', ...
                'Position', [idx*btnWidth - smallW, 1 - tabH, smallW, tabH], ...
                'FontSize', 8, ...
                'BackgroundColor', obj.Theme.Background, ...
                'ForegroundColor', obj.Theme.ForegroundColor, ...
                'Callback', @(s,e) obj.removeTab(idx));
            obj.hCloseButtons{idx} = cbtn;

            % Reposition all buttons to account for new count
            obj.recomputeLayout();

            % Style active/inactive
            obj.styleTabButton(idx, idx == obj.ActiveTab);
        end

        function rebuildTabBar(obj)
            %REBUILDTABBAR Delete and recreate all tab/close/undock buttons.
            %   rebuildTabBar(obj) destroys all existing tab bar UI controls
            %   and recreates them from scratch. This is necessary after
            %   removeTab or undockTab because callback closures capture the
            %   tab index at creation time, so removed indices would be stale.
            %   Re-styles the active tab button after rebuilding.
            for i = 1:numel(obj.hTabButtons)
                if ishandle(obj.hTabButtons{i}); delete(obj.hTabButtons{i}); end
            end
            for i = 1:numel(obj.hCloseButtons)
                if ishandle(obj.hCloseButtons{i}); delete(obj.hCloseButtons{i}); end
            end
            for i = 1:numel(obj.hUndockButtons)
                if ishandle(obj.hUndockButtons{i}); delete(obj.hUndockButtons{i}); end
            end
            obj.hTabButtons = {};
            obj.hCloseButtons = {};
            obj.hUndockButtons = {};
            for i = 1:numel(obj.Tabs)
                obj.addTabButton(i);
            end
            % Re-style active tab
            if obj.ActiveTab >= 1 && obj.ActiveTab <= numel(obj.Tabs)
                obj.styleTabButton(obj.ActiveTab, true);
            end
        end

        function onTabClick(obj, idx)
            %ONTABCLICK Callback: select the clicked tab.
            %   Forwards the tab button click to selectTab(idx).
            obj.selectTab(idx);
        end

        function onClose(obj)
            %ONCLOSE CloseRequestFcn handler: stop all live timers and close.
            %   Iterates over all tabs, stops their live mode, then
            %   deletes the figure handle.
            for i = 1:numel(obj.Tabs)
                if ~isempty(obj.Tabs(i).Figure)
                    try obj.Tabs(i).Figure.stopLive(); catch; end
                end
            end
            if ishandle(obj.hFigure)
                delete(obj.hFigure);
            end
        end

        function setTabVisible(obj, idx, visible)
            %SETTABVISIBLE Show/hide a tab by toggling its panel.
            %   setTabVisible(obj, idx, visible) shows or hides the uipanel
            %   for tab idx. Panel visibility cleanly hides all child axes
            %   without touching individual axes properties or MATLAB's
            %   zoom state.
            %
            %   Inputs:
            %     idx     — tab index (1 to numel(Tabs))
            %     visible — logical, true to show, false to hide
            panel = obj.Tabs(idx).Panel;
            if ~isempty(panel) && ishandle(panel)
                if visible
                    set(panel, 'Visible', 'on');
                else
                    set(panel, 'Visible', 'off');
                end
            end
        end

        function styleTabButton(obj, idx, active)
            %STYLETABBUTTON Apply active or inactive styling to a tab button.
            %   styleTabButton(obj, idx, active) sets the background color,
            %   foreground color, font weight, and toggle value on the tab
            %   button at index idx. Active tabs use AxesColor background
            %   with bold text; inactive tabs use Background with normal text.
            %
            %   Inputs:
            %     idx    — tab index (1 to numel(hTabButtons))
            %     active — logical, true for active styling
            if idx < 1 || idx > numel(obj.hTabButtons); return; end
            btn = obj.hTabButtons{idx};
            if ~ishandle(btn); return; end
            if active
                set(btn, 'Value', 1, ...
                    'BackgroundColor', obj.Theme.AxesColor, ...
                    'ForegroundColor', obj.Theme.ForegroundColor, ...
                    'FontWeight', 'bold');
            else
                set(btn, 'Value', 0, ...
                    'BackgroundColor', obj.Theme.Background, ...
                    'ForegroundColor', obj.Theme.ForegroundColor, ...
                    'FontWeight', 'normal');
            end
        end
    end
end
