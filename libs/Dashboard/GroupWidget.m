classdef GroupWidget < DashboardWidget
    properties (Access = public)
        Mode            = 'panel'  % 'panel', 'collapsible', 'tabbed'
        Label           = ''       % Title shown in header bar
        Collapsed       = false    % Collapsed state (collapsible mode only)
        Children        = {}       % Cell array of DashboardWidget (panel/collapsible)
        Tabs            = {}       % Cell array of struct('name','...','widgets',{{}})
        ActiveTab       = ''       % Current tab name (tabbed mode)
        ChildColumns    = 24       % Sub-grid column count
        ChildAutoFlow   = true     % Auto-arrange children
        ReflowCallback  = []       % Callback invoked after collapse/expand (injected by DashboardEngine)
    end

    properties (SetAccess = protected)
        ExpandedHeight = []        % Stores original Position(4) when collapsed
        ParentGroup   = []         % Reference to parent GroupWidget (if nested)
    end

    properties (SetAccess = protected)
        hHeader       = []         % Header bar uipanel
        hChildPanel   = []         % Child content area uipanel
        hTabButtons   = {}         % Tab button handles (tabbed mode)
        hChildPanels  = {}         % Per-child uipanel handles
    end

    methods
        function obj = GroupWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            % Default position: wide, medium height (override base default)
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 12 4];
            end
        end

        function addChild(obj, widget, tabName)
            % Check nesting depth for GroupWidget children
            if isa(widget, 'GroupWidget')
                myDepth = obj.ancestorDepth() + 1;
                if myDepth + 1 > 2
                    error('GroupWidget:maxDepth', ...
                        'Maximum nesting depth of 2 exceeded');
                end
                widget.ParentGroup = obj;
            end

            if nargin >= 3 && ~isempty(tabName)
                % Tabbed mode: add to named tab
                idx = obj.findTab(tabName);
                if idx == 0
                    obj.Tabs{end+1} = struct('name', tabName, ...
                        'widgets', {{widget}});
                    if isempty(obj.ActiveTab)
                        obj.ActiveTab = tabName;
                    end
                else
                    obj.Tabs{idx}.widgets{end+1} = widget;
                end
            else
                obj.Children{end+1} = widget;
            end
        end

        function removeChild(obj, idx)
            if idx < 1 || idx > numel(obj.Children)
                error('GroupWidget:invalidIndex', ...
                    'Child index %d out of range [1, %d]', idx, numel(obj.Children));
            end
            obj.Children(idx) = [];
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            headerFrac = 0.12;
            if isempty(obj.Label) && ~strcmp(obj.Mode, 'tabbed')
                % Tabbed mode always needs a header for tab buttons
                headerFrac = 0;
            end

            headerBg = obj.getThemeField(theme, ...
                'GroupHeaderBg', [0.20 0.20 0.25]);
            headerFg = obj.getThemeField(theme, ...
                'GroupHeaderFg', [0.92 0.92 0.92]);

            if headerFrac > 0
                obj.hHeader = uipanel(parentPanel, ...
                    'Units', 'normalized', ...
                    'Position', [0 1-headerFrac 1 headerFrac], ...
                    'BackgroundColor', headerBg, ...
                    'BorderType', 'none');
                uicontrol(obj.hHeader, ...
                    'Style', 'text', ...
                    'String', obj.Label, ...
                    'Units', 'normalized', ...
                    'Position', [0.02 0 0.96 1], ...
                    'HorizontalAlignment', 'left', ...
                    'FontWeight', 'bold', ...
                    'FontSize', 11, ...
                    'ForegroundColor', headerFg, ...
                    'BackgroundColor', headerBg);

                if strcmp(obj.Mode, 'collapsible')
                    if obj.Collapsed
                        btnStr = '>';
                    else
                        btnStr = 'v';
                    end
                    uicontrol(obj.hHeader, ...
                        'Style', 'pushbutton', ...
                        'String', btnStr, ...
                        'Units', 'normalized', ...
                        'Position', [0.92 0.1 0.06 0.8], ...
                        'Callback', @(~,~) obj.toggleCollapse(), ...
                        'FontSize', 10, ...
                        'ForegroundColor', headerFg, ...
                        'BackgroundColor', headerBg);
                end
            end

            contentBg = obj.getThemeField(theme, ...
                'WidgetBackground', [0.15 0.15 0.20]);
            obj.hChildPanel = uipanel(parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1-headerFrac], ...
                'BorderType', 'none', ...
                'BackgroundColor', contentBg);

            if obj.Collapsed
                set(obj.hChildPanel, 'Visible', 'off');
            end

            obj.renderChildren();
        end

        function refresh(obj)
            if strcmp(obj.Mode, 'tabbed')
                idx = obj.findTab(obj.ActiveTab);
                if idx > 0
                    for i = 1:numel(obj.Tabs{idx}.widgets)
                        obj.Tabs{idx}.widgets{i}.refresh();
                    end
                end
            else
                for i = 1:numel(obj.Children)
                    obj.Children{i}.refresh();
                end
            end
        end

        function t = getType(obj) %#ok<MANU>
            t = 'group';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if isempty(ttl), ttl = obj.Label; end
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                if strcmp(obj.Mode, 'tabbed') && ~isempty(obj.Tabs)
                    info = sprintf('[group: %d tabs]', numel(obj.Tabs));
                elseif ~isempty(obj.Children)
                    info = sprintf('[group: %d children]', numel(obj.Children));
                else
                    info = '[-- group --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end

        function setTimeRange(obj, tStart, tEnd)
            for i = 1:numel(obj.Children)
                obj.Children{i}.setTimeRange(tStart, tEnd);
            end
            for i = 1:numel(obj.Tabs)
                for j = 1:numel(obj.Tabs{i}.widgets)
                    obj.Tabs{i}.widgets{j}.setTimeRange(tStart, tEnd);
                end
            end
        end

        function s = toStruct(obj)
            s = struct();
            s.type = 'group';
            s.title = obj.Title;
            s.label = obj.Label;
            s.description = obj.Description;
            s.mode = obj.Mode;
            s.position = struct('col', obj.Position(1), 'row', obj.Position(2), ...
                'width', obj.Position(3), 'height', obj.Position(4));
            s.childAutoFlow = obj.ChildAutoFlow;
            s.childColumns = obj.ChildColumns;

            if ~isempty(fieldnames(obj.ThemeOverride))
                s.themeOverride = obj.ThemeOverride;
            end

            if strcmp(obj.Mode, 'tabbed')
                s.tabs = cell(1, numel(obj.Tabs));
                for i = 1:numel(obj.Tabs)
                    tab = struct();
                    tab.name = obj.Tabs{i}.name;
                    tab.widgets = cell(1, numel(obj.Tabs{i}.widgets));
                    for j = 1:numel(obj.Tabs{i}.widgets)
                        tab.widgets{j} = obj.Tabs{i}.widgets{j}.toStruct();
                    end
                    s.tabs{i} = tab;
                end
                s.activeTab = obj.ActiveTab;
                s.children = {};
            else
                s.collapsed = obj.Collapsed;
                s.children = cell(1, numel(obj.Children));
                for i = 1:numel(obj.Children)
                    s.children{i} = obj.Children{i}.toStruct();
                end
                s.tabs = {};
            end
        end

        function collapse(obj)
            if ~strcmp(obj.Mode, 'collapsible')
                return;
            end
            if obj.Collapsed
                return;
            end
            obj.ExpandedHeight = obj.Position(4);
            obj.Position(4) = 1;
            obj.Collapsed = true;
            if ~isempty(obj.hChildPanel) && ishandle(obj.hChildPanel)
                set(obj.hChildPanel, 'Visible', 'off');
            end
            if ~isempty(obj.ReflowCallback)
                obj.ReflowCallback();
            end
        end

        function expand(obj)
            if ~strcmp(obj.Mode, 'collapsible')
                return;
            end
            if ~obj.Collapsed
                return;
            end
            if ~isempty(obj.ExpandedHeight)
                obj.Position(4) = obj.ExpandedHeight;
            end
            obj.Collapsed = false;
            if ~isempty(obj.hChildPanel) && ishandle(obj.hChildPanel)
                set(obj.hChildPanel, 'Visible', 'on');
            end
            if ~isempty(obj.ReflowCallback)
                obj.ReflowCallback();
            end
        end

        function switchTab(obj, tabName)
            if ~strcmp(obj.Mode, 'tabbed')
                return;
            end
            idx = obj.findTab(tabName);
            if idx == 0
                return;
            end
            obj.ActiveTab = tabName;

            % Update visibility of tab content panels
            if ~isempty(obj.hChildPanels)
                for i = 1:numel(obj.hChildPanels)
                    if i == idx
                        set(obj.hChildPanels{i}, 'Visible', 'on');
                    else
                        set(obj.hChildPanels{i}, 'Visible', 'off');
                    end
                end
            end

            % Update tab button appearance
            if ~isempty(obj.hTabButtons)
                theme = obj.getTheme();
                activeBg = obj.getThemeField(theme, 'TabActiveBg', [0.20 0.20 0.25]);
                inactiveBg = obj.getThemeField(theme, 'TabInactiveBg', [0.12 0.12 0.16]);
                for i = 1:numel(obj.hTabButtons)
                    if i == idx
                        set(obj.hTabButtons{i}, 'BackgroundColor', activeBg);
                    else
                        set(obj.hTabButtons{i}, 'BackgroundColor', inactiveBg);
                    end
                end
            end
        end
    end

    methods (Access = protected)
        function d = ancestorDepth(obj)
            d = 0;
            p = obj.ParentGroup;
            while ~isempty(p)
                d = d + 1;
                p = p.ParentGroup;
            end
        end

        function idx = findTab(obj, name)
            idx = 0;
            for i = 1:numel(obj.Tabs)
                if strcmp(obj.Tabs{i}.name, name)
                    idx = i;
                    return;
                end
            end
        end

        function val = getThemeField(~, theme, field, default)
            if isfield(theme, field)
                val = theme.(field);
            else
                val = default;
            end
        end

        function renderChildren(obj)
            if strcmp(obj.Mode, 'tabbed')
                obj.renderTabbedChildren();
                return;
            end

            children = obj.Children;
            positions = obj.computeChildPositions(children);
            obj.hChildPanels = cell(1, numel(children));

            for i = 1:numel(children)
                pos = positions{i};
                hp = uipanel(obj.hChildPanel, ...
                    'Units', 'normalized', ...
                    'Position', pos, ...
                    'BorderType', 'none');
                children{i}.ParentTheme = obj.getTheme();
                children{i}.render(hp);
                obj.hChildPanels{i} = hp;
            end
        end

        function positions = computeChildPositions(obj, children)
            n = numel(children);
            positions = cell(1, n);
            if n == 0
                return;
            end

            if obj.ChildAutoFlow
                maxPerRow = min(n, 4);
                colWidth = 1.0 / maxPerRow;
                gap = 0.01;
                for i = 1:n
                    col = mod(i-1, maxPerRow);
                    row = floor((i-1) / maxPerRow);
                    totalRows = ceil(n / maxPerRow);
                    rowHeight = 1.0 / totalRows;
                    x = col * colWidth + gap/2;
                    y = 1 - (row+1) * rowHeight + gap/2;
                    w = colWidth - gap;
                    h = rowHeight - gap;
                    positions{i} = [x y w h];
                end
            else
                maxRow = max(cellfun(@(c) c.Position(2) + c.Position(4) - 1, ...
                    children));
                for i = 1:n
                    cp = children{i}.Position;
                    x = (cp(1) - 1) / obj.ChildColumns;
                    y = 1 - (cp(2) + cp(4) - 1) / maxRow;
                    w = cp(3) / obj.ChildColumns;
                    h = cp(4) / maxRow;
                    positions{i} = [x y w h];
                end
            end
        end

        function renderTabbedChildren(obj)
            theme = obj.getTheme();
            activeBg = obj.getThemeField(theme, 'TabActiveBg', [0.20 0.20 0.25]);
            inactiveBg = obj.getThemeField(theme, 'TabInactiveBg', [0.12 0.12 0.16]);
            headerFg = obj.getThemeField(theme, 'GroupHeaderFg', [0.92 0.92 0.92]);

            nTabs = numel(obj.Tabs);

            if nTabs == 0
                uicontrol(obj.hChildPanel, ...
                    'Style', 'text', ...
                    'String', '(no tabs)', ...
                    'Units', 'normalized', ...
                    'Position', [0.3 0.4 0.4 0.2], ...
                    'HorizontalAlignment', 'center', ...
                    'ForegroundColor', [0.5 0.5 0.5], ...
                    'BackgroundColor', get(obj.hChildPanel, 'BackgroundColor'));
                return;
            end

            % Create tab buttons in header
            obj.hTabButtons = cell(1, nTabs);
            tabWidth = min(0.15, 0.9 / nTabs);
            for i = 1:nTabs
                isActive = strcmp(obj.Tabs{i}.name, obj.ActiveTab);
                if isActive
                    bg = activeBg;
                else
                    bg = inactiveBg;
                end
                tabName = obj.Tabs{i}.name;
                obj.hTabButtons{i} = uicontrol(obj.hHeader, ...
                    'Style', 'pushbutton', ...
                    'String', tabName, ...
                    'Units', 'normalized', ...
                    'Position', [0.02 + (i-1)*tabWidth 0 tabWidth 0.5], ...
                    'FontSize', 9, ...
                    'ForegroundColor', headerFg, ...
                    'BackgroundColor', bg, ...
                    'Callback', @(~,~) obj.switchTab(tabName));
            end

            % Create content panel per tab
            obj.hChildPanels = cell(1, nTabs);
            for i = 1:nTabs
                isActive = strcmp(obj.Tabs{i}.name, obj.ActiveTab);
                if isActive
                    vis = 'on';
                else
                    vis = 'off';
                end
                tabPanel = uipanel(obj.hChildPanel, ...
                    'Units', 'normalized', ...
                    'Position', [0 0 1 1], ...
                    'BorderType', 'none', ...
                    'Visible', vis, ...
                    'BackgroundColor', get(obj.hChildPanel, 'BackgroundColor'));
                obj.hChildPanels{i} = tabPanel;

                % Render tab's widgets
                widgets = obj.Tabs{i}.widgets;
                positions = obj.computeChildPositions(widgets);
                for j = 1:numel(widgets)
                    wp = uipanel(tabPanel, ...
                        'Units', 'normalized', ...
                        'Position', positions{j}, ...
                        'BorderType', 'none');
                    widgets{j}.ParentTheme = obj.getTheme();
                    widgets{j}.render(wp);
                end
            end
        end

        function toggleCollapse(obj)
            if obj.Collapsed
                obj.expand();
            else
                obj.collapse();
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = GroupWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'label'), obj.Label = s.label; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'mode'), obj.Mode = s.mode; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                                s.position.width, s.position.height];
            end
            if isfield(s, 'childAutoFlow'), obj.ChildAutoFlow = s.childAutoFlow; end
            if isfield(s, 'childColumns'), obj.ChildColumns = s.childColumns; end
            if isfield(s, 'collapsed'), obj.Collapsed = s.collapsed; end
            if isfield(s, 'activeTab'), obj.ActiveTab = s.activeTab; end

            if isfield(s, 'themeOverride')
                obj.ThemeOverride = s.themeOverride;
            end

            % Deserialize children (panel/collapsible mode)
            % jsondecode converts cell arrays of structs to struct arrays;
            % normalize back to cell arrays for consistent indexing.
            if isfield(s, 'children') && ~isempty(s.children)
                ch = normalizeToCell(s.children);
                for i = 1:numel(ch)
                    cs = ch{i};
                    child = DashboardSerializer.createWidgetFromStruct(cs);
                    if ~isempty(child)
                        obj.Children{end+1} = child;
                    end
                end
            end

            % Deserialize tabs (tabbed mode)
            if isfield(s, 'tabs') && ~isempty(s.tabs)
                tb = normalizeToCell(s.tabs);
                for i = 1:numel(tb)
                    ts = tb{i};
                    tabEntry = struct('name', ts.name, 'widgets', {{}});
                    wlist = normalizeToCell(ts.widgets);
                    for j = 1:numel(wlist)
                        ws = wlist{j};
                        w = DashboardSerializer.createWidgetFromStruct(ws);
                        if ~isempty(w)
                            tabEntry.widgets{end+1} = w;
                        end
                    end
                    obj.Tabs{end+1} = tabEntry;
                end
                if isempty(obj.ActiveTab) && ~isempty(obj.Tabs)
                    obj.ActiveTab = obj.Tabs{1}.name;
                end
            end
        end
    end
end
