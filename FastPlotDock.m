classdef FastPlotDock < handle
    %FASTPLOTDOCK Tabbed container for multiple FastPlotFigure dashboards.
    %   dock = FastPlotDock()
    %   dock = FastPlotDock('Theme', 'dark', 'Name', 'My Dock')

    properties (Access = public)
        Theme     = []         % FastPlotTheme struct
        hFigure   = []         % shared figure handle
    end

    properties (SetAccess = private)
        Tabs      = struct('Name', {}, 'Figure', {}, 'Toolbar', {}, 'Panel', {})
        ActiveTab = 0          % index of currently visible tab
        hTabButtons = {}       % cell array of uicontrol handles
        hCloseButtons = {}     % cell array of close button handles
    end

    properties (Constant, Access = private)
        TAB_BAR_HEIGHT = 0.03  % normalized height for tab bar
    end

    methods (Access = public)
        function obj = FastPlotDock(varargin)
            figOpts = {};
            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'theme'
                        val = varargin{k+1};
                        if ischar(val) || isstruct(val)
                            obj.Theme = FastPlotTheme(val);
                        else
                            obj.Theme = val;
                        end
                    otherwise
                        figOpts{end+1} = varargin{k};   %#ok<AGROW>
                        figOpts{end+1} = varargin{k+1};  %#ok<AGROW>
                end
            end

            if isempty(obj.Theme)
                obj.Theme = FastPlotTheme('default');
            end

            obj.hFigure = figure('Visible', 'off', ...
                'Color', obj.Theme.Background, figOpts{:});
            set(obj.hFigure, 'SizeChangedFcn', @(s,e) obj.recomputeLayout());
            set(obj.hFigure, 'CloseRequestFcn', @(s,e) obj.onClose());
        end

        function addTab(obj, fig, name)
            %ADDTAB Register a FastPlotFigure as a tab.
            %   dock.addTab(fig, 'Tab Name')

            % Ensure the figure renders into our window
            if isempty(fig.ParentFigure) || fig.ParentFigure ~= obj.hFigure
                fig.ParentFigure = obj.hFigure;
                fig.hFigure = obj.hFigure;
            end

            % Tiles fill the full panel (panel handles the tab bar offset)
            fig.ContentOffset = [0, 0, 1, 1];

            % Create a panel for this tab's content
            tabH = obj.TAB_BAR_HEIGHT;
            panel = uipanel(obj.hFigure, 'Units', 'normalized', ...
                'Position', [0, 0, 1, 1 - tabH], ...
                'BorderType', 'none', ...
                'BackgroundColor', obj.Theme.Background);

            % Append to tabs
            idx = numel(obj.Tabs) + 1;
            obj.Tabs(idx).Name = name;
            obj.Tabs(idx).Figure = fig;
            obj.Tabs(idx).Toolbar = [];
            obj.Tabs(idx).Panel = panel;

            % If already rendered, render this tab immediately
            if obj.ActiveTab >= 1
                fig.renderAll();
                obj.reparentAxes(idx);
                obj.Tabs(idx).Toolbar = FastPlotToolbar(fig);
                obj.setTabVisible(idx, false);
                obj.addTabButton(idx);
            end
        end

        function render(obj)
            %RENDER Render all tabs, create tab bar, show first tab.
            if isempty(obj.Tabs)
                set(obj.hFigure, 'Visible', 'on');
                return;
            end

            % Render all figures, reparent axes into panels,
            % create toolbars but immediately hide non-active ones
            for i = 1:numel(obj.Tabs)
                obj.Tabs(i).Figure.renderAll();
                obj.reparentAxes(i);
                obj.Tabs(i).Toolbar = FastPlotToolbar(obj.Tabs(i).Figure);
                obj.setTabVisible(i, false);
            end

            % Create the tab bar buttons
            obj.createTabBar();

            % Show the first tab
            obj.selectTab(1);

            set(obj.hFigure, 'Visible', 'on');
            drawnow;
        end

        function selectTab(obj, n)
            %SELECTTAB Switch to tab n.
            if n < 1 || n > numel(obj.Tabs)
                error('FastPlotDock:outOfBounds', ...
                    'Tab %d is out of range (1-%d).', n, numel(obj.Tabs));
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

            % Delete toolbar
            tb = obj.Tabs(n).Toolbar;
            if ~isempty(tb) && ~isempty(tb.hToolbar) && ishandle(tb.hToolbar)
                delete(tb.hToolbar);
            end

            % Delete tab button and close button
            if n <= numel(obj.hTabButtons) && ishandle(obj.hTabButtons{n})
                delete(obj.hTabButtons{n});
            end
            if n <= numel(obj.hCloseButtons) && ishandle(obj.hCloseButtons{n})
                delete(obj.hCloseButtons{n});
            end

            % Remove from arrays
            obj.Tabs(n) = [];
            obj.hTabButtons(n) = [];
            obj.hCloseButtons(n) = [];

            if isempty(obj.Tabs)
                obj.ActiveTab = 0;
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

        function recomputeLayout(obj)
            %RECOMPUTELAYOUT Reposition tab and close buttons on resize.
            if ~isempty(obj.hTabButtons)
                nTabs = numel(obj.hTabButtons);
                tabH = obj.TAB_BAR_HEIGHT;
                closeW = 0.02;
                btnWidth = 1 / nTabs;
                for i = 1:nTabs
                    if ishandle(obj.hTabButtons{i})
                        set(obj.hTabButtons{i}, 'Position', ...
                            [(i-1)*btnWidth, 1 - tabH, btnWidth - closeW, tabH]);
                    end
                    if i <= numel(obj.hCloseButtons) && ishandle(obj.hCloseButtons{i})
                        set(obj.hCloseButtons{i}, 'Position', ...
                            [i*btnWidth - closeW, 1 - tabH, closeW, tabH]);
                    end
                end
            end
        end

        function delete(obj)
            % Stop all live timers before closing
            for i = 1:numel(obj.Tabs)
                if ~isempty(obj.Tabs(i).Figure)
                    try obj.Tabs(i).Figure.stopLive(); catch; end
                end
            end
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                delete(obj.hFigure);
            end
        end
    end

    methods (Access = private)
        function reparentAxes(obj, idx)
            %REPARENTAXES Move all tile axes into the tab's panel.
            fig = obj.Tabs(idx).Figure;
            panel = obj.Tabs(idx).Panel;
            for j = 1:numel(fig.TileAxes)
                if ~isempty(fig.TileAxes{j}) && ishandle(fig.TileAxes{j})
                    set(fig.TileAxes{j}, 'Parent', panel);
                end
            end
        end

        function createTabBar(obj)
            obj.hTabButtons = {};
            obj.hCloseButtons = {};
            for i = 1:numel(obj.Tabs)
                obj.addTabButton(i);
            end
        end

        function addTabButton(obj, idx)
            tabH = obj.TAB_BAR_HEIGHT;
            nTabs = numel(obj.Tabs);
            btnWidth = 1 / nTabs;
            closeW = 0.02;

            btn = uicontrol(obj.hFigure, ...
                'Style', 'togglebutton', ...
                'String', obj.Tabs(idx).Name, ...
                'Units', 'normalized', ...
                'Position', [(idx-1)*btnWidth, 1 - tabH, btnWidth - closeW, tabH], ...
                'FontSize', 9, ...
                'Callback', @(s,e) obj.onTabClick(idx));
            obj.hTabButtons{idx} = btn;

            cbtn = uicontrol(obj.hFigure, ...
                'Style', 'pushbutton', ...
                'String', 'x', ...
                'Units', 'normalized', ...
                'Position', [idx*btnWidth - closeW, 1 - tabH, closeW, tabH], ...
                'FontSize', 8, ...
                'BackgroundColor', [0.94 0.94 0.94], ...
                'ForegroundColor', [0.5 0.5 0.5], ...
                'Callback', @(s,e) obj.removeTab(idx));
            obj.hCloseButtons{idx} = cbtn;

            % Reposition all buttons to account for new count
            obj.recomputeLayout();

            % Style active/inactive
            obj.styleTabButton(idx, idx == obj.ActiveTab);
        end

        function rebuildTabBar(obj)
            %REBUILDTABBAR Delete and recreate all tab/close buttons.
            %   Needed after removeTab to fix callback indices.
            for i = 1:numel(obj.hTabButtons)
                if ishandle(obj.hTabButtons{i}); delete(obj.hTabButtons{i}); end
            end
            for i = 1:numel(obj.hCloseButtons)
                if ishandle(obj.hCloseButtons{i}); delete(obj.hCloseButtons{i}); end
            end
            obj.hTabButtons = {};
            obj.hCloseButtons = {};
            for i = 1:numel(obj.Tabs)
                obj.addTabButton(i);
            end
            % Re-style active tab
            if obj.ActiveTab >= 1 && obj.ActiveTab <= numel(obj.Tabs)
                obj.styleTabButton(obj.ActiveTab, true);
            end
        end

        function onTabClick(obj, idx)
            obj.selectTab(idx);
        end

        function onClose(obj)
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
            %   Panel visibility cleanly hides all child axes without
            %   touching individual axes properties or MATLAB's zoom state.
            panel = obj.Tabs(idx).Panel;
            if ~isempty(panel) && ishandle(panel)
                if visible
                    set(panel, 'Visible', 'on');
                else
                    set(panel, 'Visible', 'off');
                end
            end

            % Toggle toolbar (parented to figure, not panel)
            tb = obj.Tabs(idx).Toolbar;
            if ~isempty(tb) && ~isempty(tb.hToolbar) && ishandle(tb.hToolbar)
                if visible
                    set(tb.hToolbar, 'Visible', 'on');
                else
                    set(tb.hToolbar, 'Visible', 'off');
                end
            end
        end

        function styleTabButton(obj, idx, active)
            if idx < 1 || idx > numel(obj.hTabButtons); return; end
            btn = obj.hTabButtons{idx};
            if ~ishandle(btn); return; end
            if active
                set(btn, 'Value', 1, ...
                    'BackgroundColor', [1 1 1], ...
                    'ForegroundColor', [0 0 0], ...
                    'FontWeight', 'bold');
            else
                set(btn, 'Value', 0, ...
                    'BackgroundColor', [0.94 0.94 0.94], ...
                    'ForegroundColor', [0.4 0.4 0.4], ...
                    'FontWeight', 'normal');
            end
        end
    end
end
