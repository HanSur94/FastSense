classdef FastPlotDock < handle
    %FASTPLOTDOCK Tabbed container for multiple FastPlotFigure dashboards.
    %   dock = FastPlotDock()
    %   dock = FastPlotDock('Theme', 'dark', 'Name', 'My Dock')

    properties (Access = public)
        Theme     = []         % FastPlotTheme struct
        hFigure   = []         % shared figure handle
    end

    properties (SetAccess = private)
        Tabs      = struct('Name', {}, 'Figure', {}, 'Toolbar', {})
        ActiveTab = 0          % index of currently visible tab
        hTabButtons = {}       % cell array of uicontrol handles
    end

    properties (Constant, Access = private)
        TAB_BAR_HEIGHT = 0.04  % normalized height for tab bar
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

            % Set content offset to leave room for tab bar
            tabH = obj.TAB_BAR_HEIGHT;
            fig.ContentOffset = [0, 0, 1, 1 - tabH];

            % Append to tabs
            idx = numel(obj.Tabs) + 1;
            obj.Tabs(idx).Name = name;
            obj.Tabs(idx).Figure = fig;
            obj.Tabs(idx).Toolbar = [];

            % If already rendered, render this tab immediately
            if obj.ActiveTab >= 1
                fig.renderAll();
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

            % Render all figures (all axes created but deferred draw)
            for i = 1:numel(obj.Tabs)
                obj.Tabs(i).Figure.renderAll();
                obj.Tabs(i).Toolbar = FastPlotToolbar(obj.Tabs(i).Figure);
            end

            % Create the tab bar buttons
            obj.createTabBar();

            % Hide all tabs, then show the first one
            for i = 1:numel(obj.Tabs)
                obj.setTabVisible(i, false);
            end
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

        function recomputeLayout(obj)
            %RECOMPUTELAYOUT Recalculate all tile positions for all tabs.
            for i = 1:numel(obj.Tabs)
                fig = obj.Tabs(i).Figure;
                for j = 1:numel(fig.TileAxes)
                    if ~isempty(fig.TileAxes{j}) && ishandle(fig.TileAxes{j})
                        pos = fig.computeTilePosition(j);
                        set(fig.TileAxes{j}, 'Position', pos);
                    end
                end
            end

            % Reposition tab buttons
            if ~isempty(obj.hTabButtons)
                nTabs = numel(obj.hTabButtons);
                tabH = obj.TAB_BAR_HEIGHT;
                btnWidth = min(0.15, 0.95 / nTabs);
                startX = 0.025;
                for i = 1:nTabs
                    if ishandle(obj.hTabButtons{i})
                        set(obj.hTabButtons{i}, 'Position', ...
                            [startX + (i-1)*btnWidth, 1 - tabH, btnWidth, tabH]);
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
        function createTabBar(obj)
            obj.hTabButtons = {};
            for i = 1:numel(obj.Tabs)
                obj.addTabButton(i);
            end
        end

        function addTabButton(obj, idx)
            nTabs = numel(obj.Tabs);
            tabH = obj.TAB_BAR_HEIGHT;
            btnWidth = min(0.15, 0.95 / nTabs);
            startX = 0.025;

            btn = uicontrol(obj.hFigure, ...
                'Style', 'togglebutton', ...
                'String', obj.Tabs(idx).Name, ...
                'Units', 'normalized', ...
                'Position', [startX + (idx-1)*btnWidth, 1 - tabH, btnWidth, tabH], ...
                'FontSize', 9, ...
                'Callback', @(s,e) obj.onTabClick(idx));
            obj.hTabButtons{idx} = btn;

            % Reposition all buttons to account for new count
            for i = 1:numel(obj.hTabButtons)
                if ishandle(obj.hTabButtons{i})
                    set(obj.hTabButtons{i}, 'Position', ...
                        [startX + (i-1)*btnWidth, 1 - tabH, btnWidth, tabH]);
                end
            end

            % Style active/inactive
            obj.styleTabButton(idx, idx == obj.ActiveTab);
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
            fig = obj.Tabs(idx).Figure;

            % Move axes on/off-screen instead of toggling Visible.
            % MATLAB's interactive zoom tool has issues with Visible='off'
            % axes — it maintains internal state that corrupts hidden axes.
            % Moving off-screen keeps axes alive and avoids zoom conflicts.
            for i = 1:numel(fig.TileAxes)
                if ~isempty(fig.TileAxes{i}) && ishandle(fig.TileAxes{i})
                    if visible
                        pos = fig.computeTilePosition(i);
                        set(fig.TileAxes{i}, 'Position', pos, ...
                            'HitTest', 'on');
                    else
                        set(fig.TileAxes{i}, 'Position', [-2 -2 0.01 0.01], ...
                            'HitTest', 'off');
                    end
                end
            end

            % Toggle toolbar visibility (uitoolbar handles this fine)
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
                    'BackgroundColor', obj.Theme.Background * 0.8 + [0.05 0.1 0.2], ...
                    'ForegroundColor', obj.Theme.ForegroundColor, ...
                    'FontWeight', 'bold');
            else
                set(btn, 'Value', 0, ...
                    'BackgroundColor', obj.Theme.Background, ...
                    'ForegroundColor', obj.Theme.ForegroundColor * 0.7, ...
                    'FontWeight', 'normal');
            end
        end
    end
end
