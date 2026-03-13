classdef TableWidget < DashboardWidget
%TABLEWIDGET Tabular data display using uitable.
%
%   w = TableWidget('Title', 'Sensor Data', 'DataFcn', @() getData());
%   w = TableWidget('Title', 'Static', 'Data', {{'A',1;'B',2}}, ...
%                   'ColumnNames', {'Name','Value'});

    properties (Access = public)
        DataFcn     = []       % function_handle returning cell array or table
        Data        = {}       % static data (cell array)
        ColumnNames = {}       % column header names
    end

    properties (SetAccess = private)
        hTable      = []
        hTitleText  = []
    end

    methods
        function obj = TableWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 4 2];
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            bgColor = theme.WidgetBackground;
            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;

            % Title
            obj.hTitleText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', obj.Title, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.88 0.96 0.1], ...
                'FontName', fontName, ...
                'FontSize', theme.WidgetTitleFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'left');

            % uitable
            obj.hTable = uitable('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.96 0.84], ...
                'FontName', fontName, ...
                'FontSize', theme.WidgetTitleFontSize - 1, ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor);

            if ~isempty(obj.ColumnNames)
                set(obj.hTable, 'ColumnName', obj.ColumnNames);
            end

            obj.refresh();
        end

        function refresh(obj)
            data = [];
            if ~isempty(obj.DataFcn)
                data = obj.DataFcn();
            elseif ~isempty(obj.Data)
                data = obj.Data;
            end

            if ~isempty(data) && ~isempty(obj.hTable) && ishandle(obj.hTable)
                set(obj.hTable, 'Data', data);
            end
        end

        function configure(~)
        end

        function t = getType(~)
            t = 'table';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.columnNames = obj.ColumnNames;
            if ~isempty(obj.DataFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.DataFcn));
            elseif ~isempty(obj.Data)
                s.source = struct('type', 'static');
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = TableWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'columnNames')
                obj.ColumnNames = s.columnNames;
            end
            if isfield(s, 'source') && strcmp(s.source.type, 'callback')
                obj.DataFcn = str2func(s.source.function);
            end
        end
    end

    methods (Access = private)
        function theme = getTheme(obj)
            theme = DashboardTheme();
            if ~isempty(fieldnames(obj.ThemeOverride))
                fns = fieldnames(obj.ThemeOverride);
                for i = 1:numel(fns)
                    theme.(fns{i}) = obj.ThemeOverride.(fns{i});
                end
            end
        end
    end
end
