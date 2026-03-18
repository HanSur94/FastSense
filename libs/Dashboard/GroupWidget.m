classdef GroupWidget < DashboardWidget
    properties (Access = public)
        Mode          = 'panel'    % 'panel', 'collapsible', 'tabbed'
        Label         = ''         % Title shown in header bar
        Collapsed     = false      % Collapsed state (collapsible mode only)
        Children      = {}         % Cell array of DashboardWidget (panel/collapsible)
        Tabs          = {}         % Cell array of struct('name','...','widgets',{{}})
        ActiveTab     = ''         % Current tab name (tabbed mode)
        ChildColumns  = 24         % Sub-grid column count
        ChildAutoFlow = true       % Auto-arrange children
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
            if isempty(obj.Label)
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

        function s = toStruct(obj) %#ok<MANU>
            % Stub - will be fully implemented in serialization task
            s = struct();
            s.type = 'group';
            s.title = obj.Title;
            s.label = obj.Label;
            s.mode = obj.Mode;
            s.position = struct('col', obj.Position(1), 'row', obj.Position(2), ...
                'width', obj.Position(3), 'height', obj.Position(4));
        end

        function collapse(obj) %#ok<MANU>
            % Stub - will be implemented in collapsible mode task
        end

        function expand(obj) %#ok<MANU>
            % Stub - will be implemented in collapsible mode task
        end

        function switchTab(obj, tabName) %#ok<INUSD>
            % Stub - will be implemented in tabbed mode task
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

        function renderTabbedChildren(obj) %#ok<MANU>
            % Stub - will be implemented in tabbed mode task
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
        function obj = fromStruct(s) %#ok<INUSD>
            obj = GroupWidget();
            % Stub - will be implemented in serialization task
        end
    end
end
