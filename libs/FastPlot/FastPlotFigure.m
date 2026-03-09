classdef FastPlotFigure < handle
    %FASTPLOTFIGURE Tiled layout manager for FastPlot dashboards.
    %   fig = FastPlotFigure(rows, cols)
    %   fig = FastPlotFigure(rows, cols, 'Theme', 'dark')

    properties (Access = public)
        Grid       = [1 1]      % [rows, cols]
        Theme      = []         % FastPlotTheme struct
        hFigure    = []         % figure handle
    end

    properties (SetAccess = private)
        Tiles      = {}         % cell array of FastPlot instances
        TileAxes   = {}         % cell array of axes handles
        TileSpans  = {}         % cell array of [rowSpan, colSpan]
        TileThemes = {}         % cell array of theme override structs
        IsRendered = false
    end

    properties (Constant, Access = private)
        PADDING = 0.06          % normalized padding around edges
        GAP_H   = 0.05          % horizontal gap between tiles
        GAP_V   = 0.07          % vertical gap between tiles
    end

    methods (Access = public)
        function obj = FastPlotFigure(rows, cols, varargin)
            obj.Grid = [rows, cols];
            nTiles = rows * cols;
            obj.Tiles     = cell(1, nTiles);
            obj.TileAxes  = cell(1, nTiles);
            obj.TileSpans = cell(1, nTiles);
            obj.TileThemes = cell(1, nTiles);

            % Default spans: each tile is 1x1
            for i = 1:nTiles
                obj.TileSpans{i} = [1 1];
            end

            % Parse options
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
        end

        function fp = tile(obj, n)
            %TILE Get or create the FastPlot instance for tile n.
            nTiles = obj.Grid(1) * obj.Grid(2);
            if n < 1 || n > nTiles
                error('FastPlotFigure:outOfBounds', ...
                    'Tile %d is out of range (1-%d).', n, nTiles);
            end

            if isempty(obj.Tiles{n})
                ax = obj.createTileAxes(n);
                obj.TileAxes{n} = ax;

                % Merge figure theme with tile-level overrides
                tileTheme = obj.Theme;
                if ~isempty(obj.TileThemes{n})
                    fnames = fieldnames(obj.TileThemes{n});
                    for i = 1:numel(fnames)
                        tileTheme.(fnames{i}) = obj.TileThemes{n}.(fnames{i});
                    end
                end

                fp = FastPlot('Parent', ax, 'Theme', tileTheme);
                obj.Tiles{n} = fp;
            else
                fp = obj.Tiles{n};
            end
        end

        function setTileSpan(obj, n, span)
            %SETTILESPAN Set the row/column span for tile n.
            %   fig.setTileSpan(1, [2 1])  — tile 1 spans 2 rows, 1 col
            nTiles = obj.Grid(1) * obj.Grid(2);
            if n < 1 || n > nTiles
                error('FastPlotFigure:outOfBounds', ...
                    'Tile %d is out of range (1-%d).', n, nTiles);
            end
            obj.TileSpans{n} = span;

            % Recompute axes position if already created
            if ~isempty(obj.TileAxes{n})
                pos = obj.computeTilePosition(n);
                set(obj.TileAxes{n}, 'Position', pos);
            end
        end

        function setTileTheme(obj, n, themeOverrides)
            %SETTILETHEME Set per-tile theme overrides.
            nTiles = obj.Grid(1) * obj.Grid(2);
            if n < 1 || n > nTiles
                error('FastPlotFigure:outOfBounds', ...
                    'Tile %d is out of range (1-%d).', n, nTiles);
            end
            obj.TileThemes{n} = themeOverrides;
        end

        function tileTitle(obj, n, str)
            %TILETITLE Set title for tile n.
            fp = obj.tile(n);
            if ~isempty(fp.hAxes) && ishandle(fp.hAxes)
                title(fp.hAxes, str, 'FontSize', obj.Theme.TitleFontSize, ...
                    'Color', obj.Theme.ForegroundColor);
            end
        end

        function tileXLabel(obj, n, str)
            %TILEXLABEL Set xlabel for tile n.
            fp = obj.tile(n);
            if ~isempty(fp.hAxes) && ishandle(fp.hAxes)
                xlabel(fp.hAxes, str, 'Color', obj.Theme.ForegroundColor);
            end
        end

        function tileYLabel(obj, n, str)
            %TILEYLABEL Set ylabel for tile n.
            fp = obj.tile(n);
            if ~isempty(fp.hAxes) && ishandle(fp.hAxes)
                ylabel(fp.hAxes, str, 'Color', obj.Theme.ForegroundColor);
            end
        end

        function renderAll(obj)
            %RENDERALL Render all tiles that haven't been rendered yet.
            for i = 1:numel(obj.Tiles)
                if ~isempty(obj.Tiles{i}) && ~obj.Tiles{i}.IsRendered
                    obj.Tiles{i}.render();
                end
            end
            set(obj.hFigure, 'Visible', 'on');
            drawnow;
        end

        function render(obj)
            %RENDER Alias for renderAll.
            obj.renderAll();
        end
    end

    methods (Access = private)
        function ax = createTileAxes(obj, n)
            pos = obj.computeTilePosition(n);
            ax = axes('Parent', obj.hFigure, 'Position', pos);
        end

        function pos = computeTilePosition(obj, n)
            rows = obj.Grid(1);
            cols = obj.Grid(2);
            span = obj.TileSpans{n};
            rowSpan = span(1);
            colSpan = span(2);

            % Convert tile index to row, col (1-based, top-left origin)
            row = ceil(n / cols);
            col = mod(n - 1, cols) + 1;

            pad = obj.PADDING;
            gapH = obj.GAP_H;
            gapV = obj.GAP_V;

            % Available space after padding
            totalW = 1 - 2*pad;
            totalH = 1 - 2*pad;

            % Cell dimensions
            cellW = (totalW - (cols-1)*gapH) / cols;
            cellH = (totalH - (rows-1)*gapV) / rows;

            % Position (bottom-left origin for MATLAB)
            x = pad + (col-1) * (cellW + gapH);
            y = 1 - pad - row * cellH - (row-1) * gapV;

            % Apply span
            w = colSpan * cellW + (colSpan-1) * gapH;
            h = rowSpan * cellH + (rowSpan-1) * gapV;

            pos = [x, y, w, h];
        end
    end
end
