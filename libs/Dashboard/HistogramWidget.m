classdef HistogramWidget < DashboardWidget
    properties (Access = public)
        DataFcn       = []
        NumBins       = []       % empty = auto
        ShowNormalFit = false
        EdgeColor     = []       % RGB or empty for default
    end

    properties (SetAccess = private)
        hAxes = []
    end

    methods
        function obj = HistogramWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 8 4];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.12 0.13 0.82 0.65], ...
                'Color', theme.WidgetBackground, ...
                'XColor', theme.AxisColor, ...
                'YColor', theme.AxisColor);
            % Phase 3 — title as a header band above the axes (no in-axes overlap).
            obj.drawPanelTitle_(parentPanel, theme);
            % A freshly created axes is always empty, so force a repopulate.
            % Without this, a re-render (resize / theme toggle / page switch)
            % recreates the axes but refresh() early-returns on ~Dirty (it was
            % cleared by the previous plot) — leaving the histogram blank.
            obj.Dirty = true;
            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end
            if ~obj.Dirty
                return;
            end

            data = [];
            if ~isempty(obj.Tag)
                % Read via the Tag.getXY() contract (Derived/Composite tags have no .Y).
                [~, y] = obj.Tag.getXY();
                if isempty(y), return; end
                data = y(:)';
            elseif ~isempty(obj.DataFcn)
                data = obj.DataFcn();
                data = data(:)';
            end
            if isempty(data), return; end

            nBins = obj.NumBins;
            if isempty(nBins)
                nBins = max(10, round(sqrt(numel(data))));
            end

            [counts, edges] = histcounts(data, nBins);
            centers = (edges(1:end-1) + edges(2:end)) / 2;

            cla(obj.hAxes);
            bar(obj.hAxes, centers, counts, 1);

            if obj.ShowNormalFit && numel(data) > 2
                hold(obj.hAxes, 'on');
                mu = mean(data);
                sigma = std(data);
                xFit = linspace(min(data), max(data), 100);
                binWidth = edges(2) - edges(1);
                yFit = numel(data) * binWidth * ...
                    (1 / (sigma * sqrt(2*pi))) * exp(-0.5 * ((xFit - mu) / sigma).^2);
                plot(obj.hAxes, xFit, yFit, 'r-', 'LineWidth', 1.5);
                hold(obj.hAxes, 'off');
            end
            % Re-apply theme after plot commands. bar/plot run newplot, which
            % resets the axes Color (background) and XColor/YColor to their
            % light-mode defaults — a glaring white box in dark mode. Restore
            % the themed colors every refresh. The title lives in a sibling
            % header band (drawPanelTitle_, immune to newplot), so no in-axes
            % title re-apply is needed.
            theme = obj.getTheme();
            set(obj.hAxes, 'Color', theme.WidgetBackground, ...
                'XColor', theme.AxisColor, ...
                'YColor', theme.AxisColor);
            obj.Dirty = false;
        end

        function t = getType(~)
            t = 'histogram';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if numel(ttl) > width, ttl = ttl(1:width); end
            lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];

            if height >= 2
                if ~isempty(obj.Tag)
                    [~, yProbe] = obj.Tag.getXY();
                else
                    yProbe = [];
                end
                hasData = ~isempty(yProbe) || ~isempty(obj.DataFcn);
                if hasData && ~isempty(obj.Tag)
                    info = sprintf('%d data points', numel(yProbe));
                else
                    info = '[-- histogram --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.NumBins), s.numBins = obj.NumBins; end
            s.showNormalFit = obj.ShowNormalFit;
            if ~isempty(obj.EdgeColor), s.edgeColor = obj.EdgeColor; end
            if ~isempty(obj.DataFcn) && isempty(obj.Sensor)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.DataFcn));
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = HistogramWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'numBins'), obj.NumBins = s.numBins; end
            if isfield(s, 'showNormalFit'), obj.ShowNormalFit = s.showNormalFit; end
            if isfield(s, 'edgeColor'), obj.EdgeColor = s.edgeColor; end
            % Restore the data binding (callback) — dropped before P0-3.
            if isfield(s, 'source') && isfield(s.source, 'type')
                switch s.source.type
                    case 'callback'
                        obj.DataFcn = str2func(s.source.function);
                    otherwise
                        warning('HistogramWidget:sourceUnresolved', ...
                            'Unresolved source type ''%s'' for Histogram ''%s''.', ...
                            s.source.type, obj.Title);
                end
            end
        end
    end
end
