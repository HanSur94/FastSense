classdef TableWidget < DashboardWidget
%TABLEWIDGET Tabular data display using uitable.
%
%   w = TableWidget('Title', 'Sensor Data', 'DataFcn', @() getData());
%   w = TableWidget('Title', 'Static', 'Data', {{'A',1;'B',2}}, ...
%                   'ColumnNames', {'Name','Value'});
%   w = TableWidget('Sensor', sensorObj);                 % last N data rows
%   w = TableWidget('Sensor', sensorObj, 'Mode', 'events', 'EventStoreObj', store);

    properties (Access = public)
        DataFcn     = []
        Data        = {}
        ColumnNames = {}
        Mode        = 'data'     % 'data' or 'events'
        N           = 10         % number of rows to display
        EventStoreObj = []       % EventStore for event mode
    end

    properties (SetAccess = private)
        hTable      = []
        hTitleText  = []
    end

    methods
        function obj = TableWidget(varargin)
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'Sensor')
                    varargin{k} = 'SensorObj';
                end
            end
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 8 2];
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
            colNames = obj.ColumnNames;

            if ~isempty(obj.SensorObj)
                if strcmp(obj.Mode, 'data')
                    n = min(obj.N, numel(obj.SensorObj.X));
                    x = obj.SensorObj.X(end-n+1:end);
                    y = obj.SensorObj.Y(end-n+1:end);
                    data = cell(n, 2);
                    for i = 1:n
                        data{i,1} = datestr(x(i), 'HH:MM:SS');
                        data{i,2} = y(i);
                    end
                    if isempty(colNames)
                        colNames = {'Time', obj.SensorObj.Name};
                    end
                elseif strcmp(obj.Mode, 'events') && ~isempty(obj.EventStoreObj)
                    evts = obj.EventStoreObj.getEvents();
                    if ~isempty(evts)
                        sName = obj.SensorObj.Name;
                        mask = arrayfun(@(e) contains(e.SensorName, sName), evts);
                        evts = evts(mask);
                        n = min(obj.N, numel(evts));
                        if n > 0
                            evts = evts(end-n+1:end);
                            data = cell(n, 4);
                            for i = 1:n
                                data{i,1} = datestr(evts(i).StartTime, 'HH:MM:SS');
                                data{i,2} = datestr(evts(i).EndTime, 'HH:MM:SS');
                                data{i,3} = evts(i).ThresholdLabel;
                                data{i,4} = sprintf('%.1fs', (evts(i).EndTime - evts(i).StartTime)*86400);
                            end
                        end
                    end
                    if isempty(colNames)
                        colNames = {'Start', 'End', 'Label', 'Duration'};
                    end
                end
            elseif ~isempty(obj.DataFcn)
                data = obj.DataFcn();
            elseif ~isempty(obj.Data)
                data = obj.Data;
            end

            if ~isempty(data) && ~isempty(obj.hTable) && ishandle(obj.hTable)
                set(obj.hTable, 'Data', data);
                if ~isempty(colNames)
                    set(obj.hTable, 'ColumnName', colNames);
                end
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
            s.mode = obj.Mode;
            s.n = obj.N;
            if ~isempty(obj.SensorObj)
                s.source = struct('type', 'sensor', 'name', obj.SensorObj.Key, ...
                    'mode', obj.Mode);
            elseif ~isempty(obj.DataFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.DataFcn));
            elseif ~isempty(obj.Data)
                s.source = struct('type', 'static', 'data', {obj.Data});
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = TableWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'description')
                obj.Description = s.description;
            end
            if isfield(s, 'columnNames')
                obj.ColumnNames = s.columnNames;
            end
            if isfield(s, 'mode')
                obj.Mode = s.mode;
            end
            if isfield(s, 'n')
                obj.N = s.n;
            end
            if isfield(s, 'source')
                switch s.source.type
                    case 'sensor'
                        if exist('SensorRegistry', 'class')
                            obj.SensorObj = SensorRegistry.get(s.source.name);
                        end
                        if isfield(s.source, 'mode')
                            obj.Mode = s.source.mode;
                        end
                    case 'callback'
                        obj.DataFcn = str2func(s.source.function);
                end
            end
        end
    end

end
