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
            % Default position: wide, medium height
            if nargin == 0 || ~any(strcmp(varargin(1:2:end), 'Position'))
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
            if idx >= 1 && idx <= numel(obj.Children)
                obj.Children(idx) = [];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            % Stub - will be replaced in Task 2
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
    end

    methods (Static)
        function obj = fromStruct(s) %#ok<INUSD>
            obj = GroupWidget();
            % Stub - will be implemented in serialization task
        end
    end
end
