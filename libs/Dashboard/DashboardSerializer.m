classdef DashboardSerializer
%DASHBOARDSERIALIZER JSON load/save and .m export for dashboard configs.

    methods (Static)
        function save(config, filepath)
            %SAVE Write dashboard config as a MATLAB function file.
            %   The output is a function returning a DashboardEngine.
            [~, funcname] = fileparts(filepath);

            % Generate the script body (reuse exportScript logic)
            lines = {};
            lines{end+1} = sprintf('function d = %s()', funcname);
            lines{end+1} = sprintf('%%%s Recreate dashboard.', upper(funcname));
            lines{end+1} = sprintf('%%   d = %s() returns a DashboardEngine.', funcname);
            lines{end+1} = '';
            lines{end+1} = sprintf('    d = DashboardEngine(''%s'');', strrep(config.name, '''', ''''''));
            if isfield(config, 'theme')
                lines{end+1} = sprintf('    d.Theme = ''%s'';', config.theme);
            end
            if isfield(config, 'liveInterval')
                lines{end+1} = sprintf('    d.LiveInterval = %g;', config.liveInterval);
            end
            if isfield(config, 'infoFile') && ~isempty(config.infoFile)
                lines{end+1} = sprintf('    d.InfoFile = ''%s'';', strrep(config.infoFile, '''', ''''''));
            end
            lines{end+1} = '';

            % Write widget calls (indented, with return value)
            groupCount = 1;
            for i = 1:numel(config.widgets)
                ws = config.widgets{i};
                pos = sprintf('[%d %d %d %d]', ws.position.col, ws.position.row, ...
                    ws.position.width, ws.position.height);

                switch ws.type
                    case 'fastsense'
                        if isfield(ws, 'source')
                            switch ws.source.type
                                case 'sensor'
                                    lines{end+1} = sprintf('    w = d.addWidget(''fastsense'', ''Title'', ''%s'', ...', ws.title);
                                    lines{end+1} = sprintf('        ''Position'', %s, ...', pos);
                                    lines{end+1} = sprintf('        ''Sensor'', SensorRegistry.get(''%s''));', ws.source.name);
                                case 'file'
                                    lines{end+1} = sprintf('    w = d.addWidget(''fastsense'', ''Title'', ''%s'', ...', ws.title);
                                    lines{end+1} = sprintf('        ''Position'', %s, ...', pos);
                                    lines{end+1} = sprintf('        ''File'', ''%s'', ''XVar'', ''%s'', ''YVar'', ''%s'');', ...
                                        ws.source.path, ws.source.xVar, ws.source.yVar);
                                case 'data'
                                    lines{end+1} = sprintf('    w = d.addWidget(''fastsense'', ''Title'', ''%s'', ...', ws.title);
                                    lines{end+1} = sprintf('        ''Position'', %s, ...', pos);
                                    lines{end+1} = sprintf('        ''XData'', %s, ''YData'', %s);', ...
                                        mat2str(ws.source.x), mat2str(ws.source.y));
                                otherwise
                                    lines{end+1} = sprintf('    d.addWidget(''fastsense'', ''Title'', ''%s'', ''Position'', %s);', ws.title, pos);
                            end
                        else
                            lines{end+1} = sprintf('    d.addWidget(''fastsense'', ''Title'', ''%s'', ''Position'', %s);', ws.title, pos);
                        end
                    case 'number'
                        line = sprintf('    d.addWidget(''number'', ''Title'', ''%s'', ''Position'', %s', ws.title, pos);
                        if isfield(ws, 'units') && ~isempty(ws.units)
                            line = [line, sprintf(', ...\n        ''Units'', ''%s''', ws.units)];
                        end
                        lines{end+1} = [line, ');'];
                    case 'status'
                        line = sprintf('    d.addWidget(''status'', ''Title'', ''%s'', ''Position'', %s', ws.title, pos);
                        lines{end+1} = [line, ');'];
                    case 'text'
                        line = sprintf('    d.addWidget(''text'', ''Title'', ''%s'', ''Position'', %s', ws.title, pos);
                        if isfield(ws, 'content') && ~isempty(ws.content)
                            line = [line, sprintf(', ...\n        ''Content'', ''%s''', ws.content)];
                        end
                        lines{end+1} = [line, ');'];
                    case 'gauge'
                        line = sprintf('    d.addWidget(''gauge'', ''Title'', ''%s'', ''Position'', %s', ws.title, pos);
                        if isfield(ws, 'range')
                            line = [line, sprintf(', ...\n        ''Range'', [%g %g]', ws.range(1), ws.range(2))];
                        end
                        if isfield(ws, 'units') && ~isempty(ws.units)
                            line = [line, sprintf(', ...\n        ''Units'', ''%s''', ws.units)];
                        end
                        lines{end+1} = [line, ');'];
                    case 'group'
                        groupVarName = sprintf('g%d', groupCount);
                        groupCount = groupCount + 1;
                        line = sprintf('    %s = d.addWidget(''group'', ''Label'', ''%s'', ''Position'', %s', ...
                            groupVarName, ws.label, pos);
                        if isfield(ws, 'mode') && ~isempty(ws.mode)
                            line = [line, sprintf(', ...\n        ''Mode'', ''%s''', ws.mode)];
                        end
                        lines{end+1} = [line, ');'];
                        % Emit children
                        if isfield(ws, 'mode') && strcmp(ws.mode, 'tabbed') && isfield(ws, 'tabs') && ~isempty(ws.tabs)
                            tabs = normalizeToCell(ws.tabs);
                            for ti = 1:numel(tabs)
                                tab = tabs{ti};
                                tabWidgets = normalizeToCell(tab.widgets);
                                for ci = 1:numel(tabWidgets)
                                    [childLines, childVar, groupCount] = ...
                                        DashboardSerializer.emitChildWidget(tabWidgets{ci}, groupCount);
                                    lines = [lines, childLines];
                                    lines{end+1} = sprintf('    %s.addChild(%s, ''%s'');', ...
                                        groupVarName, childVar, tab.name);
                                end
                            end
                        elseif isfield(ws, 'children') && ~isempty(ws.children)
                            ch = normalizeToCell(ws.children);
                            for ci = 1:numel(ch)
                                [childLines, childVar, groupCount] = ...
                                    DashboardSerializer.emitChildWidget(ch{ci}, groupCount);
                                lines = [lines, childLines];
                                lines{end+1} = sprintf('    %s.addChild(%s);', groupVarName, childVar);
                            end
                        end
                    otherwise
                        lines{end+1} = sprintf('    d.addWidget(''%s'', ''Title'', ''%s'', ''Position'', %s);', ws.type, ws.title, pos);
                end
                lines{end+1} = '';
            end

            lines{end+1} = 'end';

            fid = fopen(filepath, 'w');
            if fid == -1
                error('DashboardSerializer:fileError', 'Cannot open file: %s', filepath);
            end
            fprintf(fid, '%s\n', lines{:});
            fclose(fid);
        end

        function saveJSON(config, filepath)
            %SAVEJSON Legacy: write dashboard config struct to JSON file.
            %  Widgets may have heterogeneous fields, so encode each
            %  widget individually and assemble the JSON array by hand.
            parts = cell(1, numel(config.widgets));
            for i = 1:numel(config.widgets)
                parts{i} = jsonencode(config.widgets{i});
            end
            widgetsJson = ['[', strjoin(parts, ','), ']'];

            % Build top-level JSON without the widgets field
            topLevel = rmfield(config, 'widgets');
            topJson = jsonencode(topLevel);
            % Insert widgets array before the closing brace
            topJson = [topJson(1:end-1), ',"widgets":', widgetsJson, '}'];

            fid = fopen(filepath, 'w');
            if fid == -1
                error('DashboardSerializer:fileError', 'Cannot open file: %s', filepath);
            end
            fwrite(fid, topJson);
            fclose(fid);
        end

        function result = load(filepath)
            %LOAD Load dashboard config from file.
            %   For .m files: uses feval to execute the function and return the engine.
            %   For .json files: uses legacy JSON parsing.
            if ~exist(filepath, 'file')
                error('DashboardSerializer:fileNotFound', 'File not found: %s', filepath);
            end

            [fdir, funcname, ext] = fileparts(filepath);

            if strcmp(ext, '.json')
                result = DashboardSerializer.loadJSON(filepath);
                return;
            end

            % .m function file
            addpath(fdir);
            cleanupPath = onCleanup(@() rmpath(fdir));
            result = feval(funcname);
        end

        function config = loadJSON(filepath)
            %LOADJSON Legacy: read dashboard config from JSON file.
            fid = fopen(filepath, 'r');
            jsonStr = fread(fid, '*char')';
            fclose(fid);
            config = jsondecode(jsonStr);
            config.widgets = normalizeToCell(config.widgets);
        end

        function config = widgetsToConfig(name, theme, liveInterval, widgets, infoFile)
            %WIDGETSTOCONFIG Build a config struct from widget objects.
            if nargin < 5
                infoFile = '';
            end
            config.name = name;
            config.theme = theme;
            config.liveInterval = liveInterval;
            if ~isempty(infoFile)
                config.infoFile = infoFile;
            end
            config.grid = struct('columns', 24);
            config.widgets = cell(1, numel(widgets));
            for i = 1:numel(widgets)
                config.widgets{i} = widgets{i}.toStruct();
            end
        end

        function widgets = configToWidgets(config, resolver)
            %CONFIGTOWIDGETS Create widget objects from config struct.
            %   configToWidgets(config) — no sensor resolution
            %   configToWidgets(config, resolver) — resolver is a function
            %     handle @(name) that returns a Sensor object by name.
            if nargin < 2, resolver = []; end
            widgets = cell(1, numel(config.widgets));
            for i = 1:numel(config.widgets)
                ws = config.widgets{i};
                widgets{i} = DashboardSerializer.createWidgetFromStruct(ws);
                % Resolve sensor binding using resolver
                if ~isempty(resolver) && ~isempty(widgets{i}) && ...
                        isfield(ws, 'source') && strcmp(ws.source.type, 'sensor')
                    try
                        widgets{i}.Sensor = resolver(ws.source.name);
                    catch
                        warning('DashboardSerializer:sensorNotFound', ...
                            'Could not resolve sensor: %s', ws.source.name);
                    end
                end
            end
            % Filter out empty cells from unknown/skipped widget types
            widgets = widgets(~cellfun('isempty', widgets));
        end

        function w = createWidgetFromStruct(ws)
            %CREATEWIDGETFROMSTRUCT Create a single widget from a struct.
            w = [];
            switch ws.type
                case 'fastsense'
                    w = FastSenseWidget.fromStruct(ws);
                case 'number'
                    w = NumberWidget.fromStruct(ws);
                case 'kpi'
                    w = NumberWidget.fromStruct(ws);
                case 'status'
                    w = StatusWidget.fromStruct(ws);
                case 'text'
                    w = TextWidget.fromStruct(ws);
                case 'gauge'
                    w = GaugeWidget.fromStruct(ws);
                case 'table'
                    w = TableWidget.fromStruct(ws);
                case 'rawaxes'
                    w = RawAxesWidget.fromStruct(ws);
                case 'timeline'
                    w = EventTimelineWidget.fromStruct(ws);
                case 'group'
                    w = GroupWidget.fromStruct(ws);
                case 'heatmap'
                    w = HeatmapWidget.fromStruct(ws);
                case 'barchart'
                    w = BarChartWidget.fromStruct(ws);
                case 'histogram'
                    w = HistogramWidget.fromStruct(ws);
                case 'scatter'
                    w = ScatterWidget.fromStruct(ws);
                case 'image'
                    w = ImageWidget.fromStruct(ws);
                case 'multistatus'
                    w = MultiStatusWidget.fromStruct(ws);
                otherwise
                    warning('DashboardSerializer:unknownType', ...
                        'Unknown widget type: %s — skipping', ws.type);
            end
        end

        function exportScript(config, filepath)
            %EXPORTSCRIPT Generate a readable .m script from config.
            lines = {};
            lines{end+1} = sprintf('%% Dashboard: %s', config.name);
            lines{end+1} = sprintf('%% Auto-generated by DashboardSerializer.exportScript');
            lines{end+1} = sprintf('%% %s', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
            lines{end+1} = '';
            lines{end+1} = sprintf('d = DashboardEngine(''%s'');', config.name);
            lines{end+1} = sprintf('d.Theme = ''%s'';', config.theme);
            lines{end+1} = sprintf('d.LiveInterval = %g;', config.liveInterval);
            lines{end+1} = '';

            if isfield(config, 'infoFile') && ~isempty(config.infoFile)
                lines{end+1} = sprintf('d.InfoFile = ''%s'';', config.infoFile);
                lines{end+1} = '';
            end

            for i = 1:numel(config.widgets)
                ws = config.widgets{i};
                pos = sprintf('[%d %d %d %d]', ws.position.col, ws.position.row, ...
                    ws.position.width, ws.position.height);

                switch ws.type
                    case 'fastsense'
                        if isfield(ws, 'source')
                            switch ws.source.type
                                case 'sensor'
                                    lines{end+1} = sprintf('d.addWidget(''fastsense'', ''Title'', ''%s'', ...', ws.title);
                                    lines{end+1} = sprintf('    ''Position'', %s, ...', pos);
                                    lines{end+1} = sprintf('    ''Sensor'', SensorRegistry.get(''%s''));', ws.source.name);
                                case 'file'
                                    lines{end+1} = sprintf('d.addWidget(''fastsense'', ''Title'', ''%s'', ...', ws.title);
                                    lines{end+1} = sprintf('    ''Position'', %s, ...', pos);
                                    lines{end+1} = sprintf('    ''File'', ''%s'', ''XVar'', ''%s'', ''YVar'', ''%s'');', ...
                                        ws.source.path, ws.source.xVar, ws.source.yVar);
                                case 'data'
                                    lines{end+1} = sprintf('d.addWidget(''fastsense'', ''Title'', ''%s'', ...', ws.title);
                                    lines{end+1} = sprintf('    ''Position'', %s, ...', pos);
                                    lines{end+1} = sprintf('    ''XData'', %s, ''YData'', %s);', ...
                                        mat2str(ws.source.x), mat2str(ws.source.y));
                                otherwise
                                    lines{end+1} = sprintf('d.addWidget(''fastsense'', ''Title'', ''%s'', ''Position'', %s);', ws.title, pos);
                            end
                        else
                            lines{end+1} = sprintf('d.addWidget(''fastsense'', ''Title'', ''%s'', ''Position'', %s);', ws.title, pos);
                        end
                    case 'number'
                        line = sprintf('d.addWidget(''number'', ''Title'', ''%s'', ''Position'', %s', ws.title, pos);
                        if isfield(ws, 'units') && ~isempty(ws.units)
                            line = [line, sprintf(', ...\n    ''Units'', ''%s''', ws.units)];
                        end
                        if isfield(ws, 'source') && isfield(ws.source, 'type')
                            if strcmp(ws.source.type, 'callback')
                                line = [line, sprintf(', ...\n    ''ValueFcn'', @%s', ws.source.function)];
                            elseif strcmp(ws.source.type, 'static')
                                line = [line, sprintf(', ...\n    ''StaticValue'', %g', ws.source.value)];
                            end
                        end
                        lines{end+1} = [line, ');'];
                    case 'kpi'
                        line = sprintf('d.addWidget(''kpi'', ''Title'', ''%s'', ''Position'', %s', ws.title, pos);
                        if isfield(ws, 'units') && ~isempty(ws.units)
                            line = [line, sprintf(', ...\n    ''Units'', ''%s''', ws.units)];
                        end
                        if isfield(ws, 'source') && isfield(ws.source, 'type')
                            if strcmp(ws.source.type, 'callback')
                                line = [line, sprintf(', ...\n    ''ValueFcn'', @%s', ws.source.function)];
                            elseif strcmp(ws.source.type, 'static')
                                line = [line, sprintf(', ...\n    ''StaticValue'', %g', ws.source.value)];
                            end
                        end
                        lines{end+1} = [line, ');'];
                    case 'status'
                        line = sprintf('d.addWidget(''status'', ''Title'', ''%s'', ''Position'', %s', ws.title, pos);
                        if isfield(ws, 'source') && isfield(ws.source, 'type')
                            if strcmp(ws.source.type, 'callback')
                                line = [line, sprintf(', ...\n    ''StatusFcn'', @%s', ws.source.function)];
                            elseif strcmp(ws.source.type, 'static')
                                line = [line, sprintf(', ...\n    ''StaticStatus'', ''%s''', ws.source.value)];
                            end
                        end
                        lines{end+1} = [line, ');'];
                    case 'text'
                        line = sprintf('d.addWidget(''text'', ''Title'', ''%s'', ''Position'', %s', ws.title, pos);
                        if isfield(ws, 'content') && ~isempty(ws.content)
                            line = [line, sprintf(', ...\n    ''Content'', ''%s''', ws.content)];
                        end
                        lines{end+1} = [line, ');'];
                    case 'gauge'
                        line = sprintf('d.addWidget(''gauge'', ''Title'', ''%s'', ''Position'', %s', ws.title, pos);
                        if isfield(ws, 'range')
                            line = [line, sprintf(', ...\n    ''Range'', [%g %g]', ws.range(1), ws.range(2))];
                        end
                        if isfield(ws, 'units') && ~isempty(ws.units)
                            line = [line, sprintf(', ...\n    ''Units'', ''%s''', ws.units)];
                        end
                        if isfield(ws, 'source') && isfield(ws.source, 'type')
                            if strcmp(ws.source.type, 'callback')
                                line = [line, sprintf(', ...\n    ''ValueFcn'', @%s', ws.source.function)];
                            elseif strcmp(ws.source.type, 'static')
                                line = [line, sprintf(', ...\n    ''StaticValue'', %g', ws.source.value)];
                            end
                        end
                        lines{end+1} = [line, ');'];
                    case 'group'
                        line = sprintf('d.addWidget(''group'', ''Label'', ''%s'', ''Position'', %s', ws.label, pos);
                        if isfield(ws, 'mode') && ~isempty(ws.mode)
                            line = [line, sprintf(', ...\n    ''Mode'', ''%s''', ws.mode)];
                        end
                        lines{end+1} = [line, ');'];
                    case 'heatmap'
                        lines{end+1} = sprintf('d.addWidget(''heatmap'', ''Title'', ''%s'', ''Position'', %s);', ws.title, pos);
                    case 'barchart'
                        lines{end+1} = sprintf('d.addWidget(''barchart'', ''Title'', ''%s'', ''Position'', %s);', ws.title, pos);
                    case 'histogram'
                        lines{end+1} = sprintf('d.addWidget(''histogram'', ''Title'', ''%s'', ''Position'', %s);', ws.title, pos);
                    case 'scatter'
                        lines{end+1} = sprintf('d.addWidget(''scatter'', ''Title'', ''%s'', ''Position'', %s);', ws.title, pos);
                    case 'image'
                        line = sprintf('d.addWidget(''image'', ''Title'', ''%s'', ''Position'', %s', ws.title, pos);
                        if isfield(ws, 'file') && ~isempty(ws.file)
                            line = [line, sprintf(', ...\n    ''File'', ''%s''', ws.file)];
                        end
                        lines{end+1} = [line, ');'];
                    case 'multistatus'
                        lines{end+1} = sprintf('d.addWidget(''multistatus'', ''Title'', ''%s'', ''Position'', %s);', ws.title, pos);
                    otherwise
                        lines{end+1} = sprintf('d.addWidget(''%s'', ''Title'', ''%s'', ''Position'', %s);', ws.type, ws.title, pos);
                end
                lines{end+1} = '';
            end

            lines{end+1} = 'd.render();';

            fid = fopen(filepath, 'w');
            if fid == -1
                error('DashboardSerializer:fileError', 'Cannot open file: %s', filepath);
            end
            fprintf(fid, '%s\n', lines{:});
            fclose(fid);
        end

        function [childLines, varName, groupCount] = emitChildWidget(cw, groupCount)
        %EMITCHILDWIDGET Emit .m constructor lines for a child widget.
        %   Used by DashboardSerializer.save() to emit child code for GroupWidget
        %   children. Children are created by constructor, not d.addWidget().
        %   Returns the generated code lines, the variable name assigned, and the
        %   updated groupCount (in case the child is itself a GroupWidget).
            childLines = {};
            cpos = sprintf('[%d %d %d %d]', cw.position.col, cw.position.row, ...
                cw.position.width, cw.position.height);
            ctitle = '';
            if isfield(cw, 'title'), ctitle = cw.title; end

            switch cw.type
                case 'number'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = NumberWidget(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, ctitle, cpos);
                case 'status'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = StatusWidget(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, ctitle, cpos);
                case 'text'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = TextWidget(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, ctitle, cpos);
                case 'gauge'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = GaugeWidget(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, ctitle, cpos);
                case 'table'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = TableWidget(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, ctitle, cpos);
                case 'heatmap'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = HeatmapWidget(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, ctitle, cpos);
                case 'barchart'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = BarChartWidget(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, ctitle, cpos);
                case 'histogram'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = HistogramWidget(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, ctitle, cpos);
                case 'scatter'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = ScatterWidget(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, ctitle, cpos);
                case 'multistatus'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = MultiStatusWidget(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, ctitle, cpos);
                case 'group'
                    % Nested GroupWidget (max depth 2 per codebase constraint)
                    varName = sprintf('g%d', groupCount);
                    groupCount = groupCount + 1;
                    nestedLabel = '';
                    if isfield(cw, 'label'), nestedLabel = cw.label; end
                    nestedMode = '';
                    if isfield(cw, 'mode'), nestedMode = cw.mode; end
                    nestedLine = sprintf('    %s = GroupWidget(''Label'', ''%s'', ''Position'', %s', ...
                        varName, nestedLabel, cpos);
                    if ~isempty(nestedMode)
                        nestedLine = [nestedLine, sprintf(', ''Mode'', ''%s''', nestedMode)];
                    end
                    childLines{end+1} = [nestedLine, ');'];
                    % Emit nested children recursively
                    if strcmp(nestedMode, 'tabbed') && isfield(cw, 'tabs') && ~isempty(cw.tabs)
                        tabs = normalizeToCell(cw.tabs);
                        for ti = 1:numel(tabs)
                            tab = tabs{ti};
                            tabWidgets = normalizeToCell(tab.widgets);
                            for ci = 1:numel(tabWidgets)
                                [cl, cv, groupCount] = DashboardSerializer.emitChildWidget(tabWidgets{ci}, groupCount);
                                childLines = [childLines, cl];
                                childLines{end+1} = sprintf('    %s.addChild(%s, ''%s'');', varName, cv, tab.name);
                            end
                        end
                    elseif isfield(cw, 'children') && ~isempty(cw.children)
                        ch = normalizeToCell(cw.children);
                        for ci = 1:numel(ch)
                            [cl, cv, groupCount] = DashboardSerializer.emitChildWidget(ch{ci}, groupCount);
                            childLines = [childLines, cl];
                            childLines{end+1} = sprintf('    %s.addChild(%s);', varName, cv);
                        end
                    end
                otherwise
                    % Generic fallback for unknown/unhandled types
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    typeName = cw.type;
                    if ~isempty(typeName)
                        typeName = [upper(typeName(1)), typeName(2:end), 'Widget'];
                    end
                    childLines{end+1} = sprintf('    %s = %s(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, typeName, ctitle, cpos);
            end
        end
    end
end
