classdef FastPlotFigure < handle
    %FASTPLOTFIGURE Tiled layout manager for FastPlot dashboards.
    %   fig = FastPlotFigure(rows, cols)
    %   fig = FastPlotFigure(rows, cols, 'Theme', 'dark')

    properties (Access = public)
        Grid       = [1 1]      % [rows, cols]
        Theme      = []         % FastPlotTheme struct
        hFigure    = []         % figure handle
        ParentFigure = []      % external figure handle (skip figure creation)
        LiveViewMode = ''          % 'preserve' | 'follow' | 'reset'
        LiveFile       = ''        % path to .mat file
        LiveUpdateFcn  = []        % @(fig, data) callback
        LiveIsActive   = false     % whether polling is running
        LiveInterval   = 2.0       % poll interval in seconds
        MetadataFile      = ''        % path to metadata .mat file
        MetadataVars      = {}        % variable names to extract
        MetadataLineIndex = 1         % line index within the tile
        MetadataTileIndex = 1         % which tile to attach metadata to
    end

    properties (SetAccess = private)
        Tiles      = {}         % cell array of FastPlot instances
        TileAxes   = {}         % cell array of axes handles
        TileSpans  = {}         % cell array of [rowSpan, colSpan]
        TileThemes = {}         % cell array of theme override structs
        IsRendered = false
        LiveTimer      = []        % timer object
        LiveFileDate   = 0         % last known file datenum
        MetadataFileDate  = 0         % last known metadata file datenum
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
                    case 'parentfigure'
                        obj.ParentFigure = varargin{k+1};
                    otherwise
                        figOpts{end+1} = varargin{k};   %#ok<AGROW>
                        figOpts{end+1} = varargin{k+1};  %#ok<AGROW>
                end
            end

            if isempty(obj.Theme)
                obj.Theme = FastPlotTheme('default');
            end

            if ~isempty(obj.ParentFigure)
                obj.hFigure = obj.ParentFigure;
            else
                obj.hFigure = figure('Visible', 'off', ...
                    'Color', obj.Theme.Background, figOpts{:});
            end
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
                    obj.Tiles{i}.DeferDraw = true;
                    obj.Tiles{i}.render();
                    obj.Tiles{i}.DeferDraw = false;
                end
            end
            set(obj.hFigure, 'Visible', 'on');
            drawnow;
        end

        function render(obj)
            %RENDER Alias for renderAll.
            obj.renderAll();
        end

        function startLive(obj, filepath, updateFcn, varargin)
            %STARTLIVE Start live mode on the dashboard.
            if obj.LiveIsActive
                obj.stopLive();
            end

            obj.LiveFile = filepath;
            obj.LiveUpdateFcn = updateFcn;

            for k = 1:2:numel(varargin)
                switch lower(varargin{k})
                    case 'interval'
                        obj.LiveInterval = varargin{k+1};
                    case 'viewmode'
                        obj.LiveViewMode = varargin{k+1};
                    case 'metadatafile'
                        obj.MetadataFile = varargin{k+1};
                    case 'metadatavars'
                        obj.MetadataVars = varargin{k+1};
                    case 'metadatalineindex'
                        obj.MetadataLineIndex = varargin{k+1};
                    case 'metadatatileindex'
                        obj.MetadataTileIndex = varargin{k+1};
                end
            end

            if isempty(obj.LiveViewMode)
                obj.LiveViewMode = 'preserve';
            end

            % Set view mode on all tiles
            for i = 1:numel(obj.Tiles)
                if ~isempty(obj.Tiles{i})
                    obj.Tiles{i}.LiveViewMode = obj.LiveViewMode;
                end
            end

            if exist(obj.LiveFile, 'file')
                d = dir(obj.LiveFile);
                obj.LiveFileDate = d.datenum;
            end

            if ~isempty(obj.MetadataFile) && exist(obj.MetadataFile, 'file')
                d = dir(obj.MetadataFile);
                obj.MetadataFileDate = d.datenum;
                obj.loadMetadataFile();
            end

            % Create and start timer (MATLAB only; Octave lacks timer)
            try
                obj.LiveTimer = timer( ...
                    'ExecutionMode', 'fixedSpacing', ...
                    'Period', obj.LiveInterval, ...
                    'TimerFcn', @(~,~) obj.onLiveTimer(), ...
                    'ErrorFcn', @(~,~) []);
                start(obj.LiveTimer);
            catch
                % Octave: no timer — use runLive() for blocking poll loop
            end

            obj.LiveIsActive = true;

            existingDeleteFcn = get(obj.hFigure, 'DeleteFcn');
            set(obj.hFigure, 'DeleteFcn', @(s,e) obj.onFigureCloseLive(existingDeleteFcn, s, e));
        end

        function stopLive(obj)
            %STOPLIVE Stop live polling.
            if ~isempty(obj.LiveTimer)
                try
                    stop(obj.LiveTimer);
                    delete(obj.LiveTimer);
                catch
                end
            end
            obj.LiveTimer = [];
            obj.LiveIsActive = false;
        end

        function refresh(obj)
            %REFRESH Manual one-shot reload.
            if isempty(obj.LiveFile) || isempty(obj.LiveUpdateFcn)
                error('FastPlotFigure:noLiveSource', ...
                    'No live source configured.');
            end
            if ~exist(obj.LiveFile, 'file')
                warning('FastPlotFigure:fileNotFound', 'File not found: %s', obj.LiveFile);
                return;
            end
            try
                data = load(obj.LiveFile);
                obj.LiveUpdateFcn(obj, data);
            catch
            end
            d = dir(obj.LiveFile);
            obj.LiveFileDate = d.datenum;

            % Load metadata file if configured
            obj.loadMetadataFile();
            if ~isempty(obj.MetadataFile) && exist(obj.MetadataFile, 'file')
                dm = dir(obj.MetadataFile);
                obj.MetadataFileDate = dm.datenum;
            end
        end

        function setViewMode(obj, mode)
            %SETVIEWMODE Set view mode on all tiles.
            obj.LiveViewMode = mode;
            for i = 1:numel(obj.Tiles)
                if ~isempty(obj.Tiles{i})
                    obj.Tiles{i}.LiveViewMode = mode;
                end
            end
        end

        function runLive(obj)
            %RUNLIVE Blocking poll loop for live mode (Octave compatibility).
            if ~obj.LiveIsActive
                return;
            end

            % On MATLAB, the timer is already running
            if ~isempty(obj.LiveTimer) && ~isstruct(obj.LiveTimer)
                return;
            end

            cleanupObj = onCleanup(@() obj.stopLive());

            while obj.LiveIsActive && ishandle(obj.hFigure)
                try
                    if exist(obj.LiveFile, 'file')
                        d = dir(obj.LiveFile);
                        if d.datenum > obj.LiveFileDate
                            obj.LiveFileDate = d.datenum;
                            data = load(obj.LiveFile);
                            obj.LiveUpdateFcn(obj, data);
                        end
                    end
                catch
                end
                drawnow;
                pause(obj.LiveInterval);
            end
        end
    end

    methods (Access = private)
        function onLiveTimer(obj)
            if ~exist(obj.LiveFile, 'file'); return; end
            try
                d = dir(obj.LiveFile);
                if d.datenum > obj.LiveFileDate
                    obj.LiveFileDate = d.datenum;
                    data = load(obj.LiveFile);
                    obj.LiveUpdateFcn(obj, data);
                    drawnow;
                end
            catch
            end

            % Check metadata file
            if ~isempty(obj.MetadataFile) && exist(obj.MetadataFile, 'file')
                try
                    dm = dir(obj.MetadataFile);
                    if dm.datenum > obj.MetadataFileDate
                        obj.MetadataFileDate = dm.datenum;
                        obj.loadMetadataFile();
                    end
                catch
                end
            end
        end

        function loadMetadataFile(obj)
            if isempty(obj.MetadataFile) || isempty(obj.MetadataVars)
                return;
            end
            if ~exist(obj.MetadataFile, 'file')
                return;
            end
            try
                data = load(obj.MetadataFile);
                meta = struct();
                if isfield(data, 'datenum')
                    meta.datenum = data.datenum;
                elseif isfield(data, 'datetime')
                    meta.datenum = data.datetime;
                else
                    return;
                end
                for i = 1:numel(obj.MetadataVars)
                    varName = obj.MetadataVars{i};
                    if isfield(data, varName)
                        meta.(varName) = data.(varName);
                    end
                end
                tileIdx = obj.MetadataTileIndex;
                lineIdx = obj.MetadataLineIndex;
                if tileIdx >= 1 && tileIdx <= numel(obj.Tiles) && ~isempty(obj.Tiles{tileIdx})
                    fp = obj.Tiles{tileIdx};
                    fp.setLineMetadata(lineIdx, meta);
                end
            catch
            end
        end

        function onFigureCloseLive(obj, existingDeleteFcn, src, evt)
            obj.stopLive();
            if ~isempty(existingDeleteFcn) && isa(existingDeleteFcn, 'function_handle')
                existingDeleteFcn(src, evt);
            end
        end

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
