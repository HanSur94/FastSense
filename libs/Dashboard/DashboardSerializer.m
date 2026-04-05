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
                    case 'divider'
                        lines{end+1} = sprintf('    d.addWidget(''divider'', ''Position'', %s);', pos);
                    case 'iconcard'
                        lines{end+1} = sprintf('    d.addWidget(''iconcard'', ''Title'', ''%s'', ...', ws.title);
                        lines{end+1} = sprintf('        ''Position'', %s);', pos);
                    case 'chipbar'
                        lines{end+1} = sprintf('    d.addWidget(''chipbar'', ''Title'', ''%s'', ...', ws.title);
                        lines{end+1} = sprintf('        ''Position'', %s);', pos);
                    case 'sparkline'
                        lines{end+1} = sprintf('    d.addWidget(''sparkline'', ''Title'', ''%s'', ...', ws.title);
                        lines{end+1} = sprintf('        ''Position'', %s);', pos);
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
            %SAVEJSON Write dashboard config struct to JSON file.
            %  Handles both single-page (widgets field) and multi-page (pages field).
            %  Widgets/pages may have heterogeneous fields, so encode each entry
            %  individually and assemble the JSON array by hand.
            if isfield(config, 'pages')
                % Multi-page path: encode each page individually
                pageParts = cell(1, numel(config.pages));
                for i = 1:numel(config.pages)
                    pg = config.pages{i};
                    % Encode each widget within the page individually
                    wParts = cell(1, numel(pg.widgets));
                    for j = 1:numel(pg.widgets)
                        wParts{j} = jsonencode(pg.widgets{j});
                    end
                    widgetsJson = ['[', strjoin(wParts, ','), ']'];
                    pgNoWidgets = rmfield(pg, 'widgets');
                    pgJson = jsonencode(pgNoWidgets);
                    pageParts{i} = [pgJson(1:end-1), ',"widgets":', widgetsJson, '}'];
                end
                pagesJson = ['[', strjoin(pageParts, ','), ']'];
                topLevel = rmfield(config, 'pages');
                topJson = jsonencode(topLevel);
                topJson = [topJson(1:end-1), ',"pages":', pagesJson, '}'];
            else
                % Single-page path: encode each widget individually
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
            end

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
            if fid == -1
                error('DashboardSerializer:fileNotFound', ...
                    'Cannot open JSON file: %s', filepath);
            end
            jsonStr = fread(fid, '*char')';
            fclose(fid);
            config = jsondecode(jsonStr);
            if isfield(config, 'pages') && ~isempty(config.pages)
                config.pages = normalizeToCell(config.pages);
                for i = 1:numel(config.pages)
                    if isfield(config.pages{i}, 'widgets') && ~isempty(config.pages{i}.widgets)
                        config.pages{i}.widgets = normalizeToCell(config.pages{i}.widgets);
                    else
                        config.pages{i}.widgets = {};
                    end
                end
            else
                % Legacy single-page
                if isfield(config, 'widgets')
                    config.widgets = normalizeToCell(config.widgets);
                else
                    config.widgets = {};
                end
            end
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

        function config = widgetsPagesToConfig(name, theme, liveInterval, pages, activePage, infoFile)
            %WIDGETSPAGESTOCONFIG Build a multi-page config struct from page objects.
            %   pages is a cell array of DashboardPage objects.
            %   activePage is the Name string of the active page.
            if nargin < 6
                infoFile = '';
            end
            config.name = name;
            config.theme = theme;
            config.liveInterval = liveInterval;
            if nargin >= 6 && ~isempty(infoFile)
                config.infoFile = infoFile;
            end
            config.grid = struct('columns', 24);
            config.activePage = activePage;
            config.pages = cell(1, numel(pages));
            for i = 1:numel(pages)
                config.pages{i} = pages{i}.toStruct();
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
                case 'divider'
                    w = DividerWidget.fromStruct(ws);
                case 'iconcard'
                    w = IconCardWidget.fromStruct(ws);
                case 'chipbar'
                    w = ChipBarWidget.fromStruct(ws);
                case 'sparkline'
                    w = SparklineCardWidget.fromStruct(ws);
                case 'mock'
                    % MockDashboardWidget used in tests — load via fromStruct if available
                    try
                        w = MockDashboardWidget.fromStruct(ws);
                    catch
                        w = [];
                    end
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
                wLines = DashboardSerializer.linesForWidget(ws, pos, '');
                lines = [lines, wLines];
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

        function exportScriptPages(config, filepath)
            %EXPORTSCRIPTPAGES Generate a MATLAB function file from a multi-page config.
            %   The output is a function returning a DashboardEngine so that
            %   DashboardEngine.load() can use feval(funcname) to reconstruct it.
            %   Emits d.addPage('Name') + d.switchPage(N) before each page's widget block
            %   so that addWidget routes to the correct page.
            [~, funcname] = fileparts(filepath);

            lines = {};
            lines{end+1} = sprintf('function d = %s()', funcname);
            lines{end+1} = sprintf('%%%s Recreate multi-page dashboard.', upper(funcname));
            lines{end+1} = sprintf('%%   d = %s() returns a DashboardEngine.', funcname);
            lines{end+1} = sprintf('%% Dashboard: %s', config.name);
            lines{end+1} = sprintf('%% Auto-generated by DashboardSerializer.exportScriptPages');
            lines{end+1} = sprintf('%% %s', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
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

            % First pass: emit all addPage() calls so pages exist before switchPage
            for pi = 1:numel(config.pages)
                pg = config.pages{pi};
                lines{end+1} = sprintf('    d.addPage(''%s'');', strrep(pg.name, '''', ''''''));
            end
            lines{end+1} = '';

            % Second pass: for each page switch to it, then emit its widgets
            for pi = 1:numel(config.pages)
                pg = config.pages{pi};
                lines{end+1} = sprintf('    d.switchPage(%d);', pi);
                pgWidgets = pg.widgets;
                if ~iscell(pgWidgets), pgWidgets = {}; end
                for i = 1:numel(pgWidgets)
                    ws = pgWidgets{i};
                    pos = sprintf('[%d %d %d %d]', ws.position.col, ws.position.row, ...
                        ws.position.width, ws.position.height);
                    wLines = DashboardSerializer.linesForWidget(ws, pos, '    ');
                    lines = [lines, wLines];
                end
                lines{end+1} = '';
            end

            lines{end+1} = '    d.render();';
            lines{end+1} = 'end';

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
                case 'divider'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = DividerWidget(''Position'', %s);', varName, cpos);
                case 'iconcard'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = IconCardWidget(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, ctitle, cpos);
                case 'chipbar'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = ChipBarWidget(''Title'', ''%s'', ''Position'', %s);', ...
                        varName, ctitle, cpos);
                case 'sparkline'
                    varName = sprintf('c%d', groupCount);
                    groupCount = groupCount + 1;
                    childLines{end+1} = sprintf('    %s = SparklineCardWidget(''Title'', ''%s'', ''Position'', %s);', ...
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

    methods (Static, Access = private)
        function wLines = linesForWidget(ws, pos, indent)
        %LINESFORWIDGET Generate addWidget code lines for a single widget struct.
        %   ws     - widget config struct
        %   pos    - position string, e.g. '[1 1 6 2]'
        %   indent - indentation prefix string, e.g. '' or '    '
        %   Returns wLines, a cell array of code lines (no trailing blank line).
            wLines = {};
            switch ws.type
                case 'fastsense'
                    if isfield(ws, 'source')
                        switch ws.source.type
                            case 'sensor'
                                wLines{end+1} = sprintf('%sd.addWidget(''fastsense'', ''Title'', ''%s'', ...', indent, ws.title);
                                wLines{end+1} = sprintf('%s    ''Position'', %s, ...', indent, pos);
                                wLines{end+1} = sprintf('%s    ''Sensor'', SensorRegistry.get(''%s''));', indent, ws.source.name);
                            case 'file'
                                wLines{end+1} = sprintf('%sd.addWidget(''fastsense'', ''Title'', ''%s'', ...', indent, ws.title);
                                wLines{end+1} = sprintf('%s    ''Position'', %s, ...', indent, pos);
                                wLines{end+1} = sprintf('%s    ''File'', ''%s'', ''XVar'', ''%s'', ''YVar'', ''%s'');', ...
                                    indent, ws.source.path, ws.source.xVar, ws.source.yVar);
                            case 'data'
                                wLines{end+1} = sprintf('%sd.addWidget(''fastsense'', ''Title'', ''%s'', ...', indent, ws.title);
                                wLines{end+1} = sprintf('%s    ''Position'', %s, ...', indent, pos);
                                wLines{end+1} = sprintf('%s    ''XData'', %s, ''YData'', %s);', ...
                                    indent, mat2str(ws.source.x), mat2str(ws.source.y));
                            otherwise
                                wLines{end+1} = sprintf('%sd.addWidget(''fastsense'', ''Title'', ''%s'', ''Position'', %s);', indent, ws.title, pos);
                        end
                    else
                        wLines{end+1} = sprintf('%sd.addWidget(''fastsense'', ''Title'', ''%s'', ''Position'', %s);', indent, ws.title, pos);
                    end
                case 'number'
                    line = sprintf('%sd.addWidget(''number'', ''Title'', ''%s'', ''Position'', %s', indent, ws.title, pos);
                    if isfield(ws, 'units') && ~isempty(ws.units)
                        line = [line, sprintf(', ...\n%s    ''Units'', ''%s''', indent, ws.units)];
                    end
                    if isfield(ws, 'source') && isfield(ws.source, 'type')
                        if strcmp(ws.source.type, 'callback')
                            line = [line, sprintf(', ...\n%s    ''ValueFcn'', @%s', indent, ws.source.function)];
                        elseif strcmp(ws.source.type, 'static')
                            line = [line, sprintf(', ...\n%s    ''StaticValue'', %g', indent, ws.source.value)];
                        end
                    end
                    wLines{end+1} = [line, ');'];
                case 'kpi'
                    line = sprintf('%sd.addWidget(''kpi'', ''Title'', ''%s'', ''Position'', %s', indent, ws.title, pos);
                    if isfield(ws, 'units') && ~isempty(ws.units)
                        line = [line, sprintf(', ...\n%s    ''Units'', ''%s''', indent, ws.units)];
                    end
                    if isfield(ws, 'source') && isfield(ws.source, 'type')
                        if strcmp(ws.source.type, 'callback')
                            line = [line, sprintf(', ...\n%s    ''ValueFcn'', @%s', indent, ws.source.function)];
                        elseif strcmp(ws.source.type, 'static')
                            line = [line, sprintf(', ...\n%s    ''StaticValue'', %g', indent, ws.source.value)];
                        end
                    end
                    wLines{end+1} = [line, ');'];
                case 'status'
                    line = sprintf('%sd.addWidget(''status'', ''Title'', ''%s'', ''Position'', %s', indent, ws.title, pos);
                    if isfield(ws, 'source') && isfield(ws.source, 'type')
                        if strcmp(ws.source.type, 'callback')
                            line = [line, sprintf(', ...\n%s    ''StatusFcn'', @%s', indent, ws.source.function)];
                        elseif strcmp(ws.source.type, 'static')
                            line = [line, sprintf(', ...\n%s    ''StaticStatus'', ''%s''', indent, ws.source.value)];
                        end
                    end
                    wLines{end+1} = [line, ');'];
                case 'text'
                    line = sprintf('%sd.addWidget(''text'', ''Title'', ''%s'', ''Position'', %s', indent, ws.title, pos);
                    if isfield(ws, 'content') && ~isempty(ws.content)
                        line = [line, sprintf(', ...\n%s    ''Content'', ''%s''', indent, ws.content)];
                    end
                    wLines{end+1} = [line, ');'];
                case 'gauge'
                    line = sprintf('%sd.addWidget(''gauge'', ''Title'', ''%s'', ''Position'', %s', indent, ws.title, pos);
                    if isfield(ws, 'range')
                        line = [line, sprintf(', ...\n%s    ''Range'', [%g %g]', indent, ws.range(1), ws.range(2))];
                    end
                    if isfield(ws, 'units') && ~isempty(ws.units)
                        line = [line, sprintf(', ...\n%s    ''Units'', ''%s''', indent, ws.units)];
                    end
                    if isfield(ws, 'source') && isfield(ws.source, 'type')
                        if strcmp(ws.source.type, 'callback')
                            line = [line, sprintf(', ...\n%s    ''ValueFcn'', @%s', indent, ws.source.function)];
                        elseif strcmp(ws.source.type, 'static')
                            line = [line, sprintf(', ...\n%s    ''StaticValue'', %g', indent, ws.source.value)];
                        end
                    end
                    wLines{end+1} = [line, ');'];
                case 'group'
                    line = sprintf('%sd.addWidget(''group'', ''Label'', ''%s'', ''Position'', %s', indent, ws.label, pos);
                    if isfield(ws, 'mode') && ~isempty(ws.mode)
                        line = [line, sprintf(', ...\n%s    ''Mode'', ''%s''', indent, ws.mode)];
                    end
                    wLines{end+1} = [line, ');'];
                case 'heatmap'
                    wLines{end+1} = sprintf('%sd.addWidget(''heatmap'', ''Title'', ''%s'', ''Position'', %s);', indent, ws.title, pos);
                case 'barchart'
                    wLines{end+1} = sprintf('%sd.addWidget(''barchart'', ''Title'', ''%s'', ''Position'', %s);', indent, ws.title, pos);
                case 'histogram'
                    wLines{end+1} = sprintf('%sd.addWidget(''histogram'', ''Title'', ''%s'', ''Position'', %s);', indent, ws.title, pos);
                case 'scatter'
                    wLines{end+1} = sprintf('%sd.addWidget(''scatter'', ''Title'', ''%s'', ''Position'', %s);', indent, ws.title, pos);
                case 'image'
                    line = sprintf('%sd.addWidget(''image'', ''Title'', ''%s'', ''Position'', %s', indent, ws.title, pos);
                    if isfield(ws, 'file') && ~isempty(ws.file)
                        line = [line, sprintf(', ...\n%s    ''File'', ''%s''', indent, ws.file)];
                    end
                    wLines{end+1} = [line, ');'];
                case 'multistatus'
                    wLines{end+1} = sprintf('%sd.addWidget(''multistatus'', ''Title'', ''%s'', ''Position'', %s);', indent, ws.title, pos);
                case 'divider'
                    wLines{end+1} = sprintf('%sd.addWidget(''divider'', ''Position'', %s);', indent, pos);
                case 'iconcard'
                    line = sprintf('%sd.addWidget(''iconcard'', ''Title'', ''%s'', ''Position'', %s', indent, ws.title, pos);
                    if isfield(ws, 'units') && ~isempty(ws.units)
                        line = [line, sprintf(', ...\n%s    ''Units'', ''%s''', indent, ws.units)];
                    end
                    if isfield(ws, 'source') && isfield(ws.source, 'type')
                        if strcmp(ws.source.type, 'static')
                            line = [line, sprintf(', ...\n%s    ''StaticValue'', %g', indent, ws.source.value)];
                        end
                    end
                    if isfield(ws, 'staticState') && ~isempty(ws.staticState)
                        line = [line, sprintf(', ...\n%s    ''StaticState'', ''%s''', indent, ws.staticState)];
                    end
                    wLines{end+1} = [line, ');'];
                case 'chipbar'
                    wLines{end+1} = sprintf('%sd.addWidget(''chipbar'', ''Title'', ''%s'', ''Position'', %s);', indent, ws.title, pos);
                case 'sparkline'
                    line = sprintf('%sd.addWidget(''sparkline'', ''Title'', ''%s'', ''Position'', %s', indent, ws.title, pos);
                    if isfield(ws, 'units') && ~isempty(ws.units)
                        line = [line, sprintf(', ...\n%s    ''Units'', ''%s''', indent, ws.units)];
                    end
                    if isfield(ws, 'source') && isfield(ws.source, 'type')
                        if strcmp(ws.source.type, 'static')
                            line = [line, sprintf(', ...\n%s    ''StaticValue'', %g', indent, ws.source.value)];
                        end
                    end
                    wLines{end+1} = [line, ');'];
                otherwise
                    if isfield(ws, 'title')
                        wLines{end+1} = sprintf('%sd.addWidget(''%s'', ''Title'', ''%s'', ''Position'', %s);', indent, ws.type, ws.title, pos);
                    end
            end
        end
    end
end
