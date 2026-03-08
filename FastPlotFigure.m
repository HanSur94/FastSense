classdef FastPlotFigure < handle
    %FASTPLOTFIGURE Tiled layout manager for FastPlot dashboards.
    %   Creates a grid of FastPlot tiles in a single figure window with
    %   configurable spacing, per-tile theme overrides, and tile spanning.
    %   Supports live mode that synchronizes file polling across all tiles.
    %
    %   fig = FastPlotFigure(rows, cols)
    %   fig = FastPlotFigure(rows, cols, 'Theme', 'dark')
    %   fig = FastPlotFigure(rows, cols, 'ParentFigure', hFig)
    %
    %   Constructor options (name-value):
    %     'Theme'        — theme preset name, struct, or FastPlotTheme
    %     'ParentFigure' — existing figure handle (skip figure creation)
    %     Any additional name-value pairs are passed to figure().
    %
    %   Example — 2x2 dashboard:
    %     fig = FastPlotFigure(2, 2, 'Theme', 'dark');
    %     fig.tile(1).addLine(x1, y1); fig.tile(2).addLine(x2, y2);
    %     fig.tile(3).addLine(x3, y3); fig.tile(4).addLine(x4, y4);
    %     fig.renderAll();
    %
    %   Example — tile spanning:
    %     fig = FastPlotFigure(2, 2);
    %     fig.setTileSpan(1, [1, 2]);  % tile 1 spans full width
    %     fig.tile(1).addLine(x, y);
    %     fig.renderAll();
    %
    %   See also FastPlot, FastPlotDock, FastPlotTheme, FastPlotToolbar.

    % ========================= PUBLIC PROPERTIES =========================
    properties (Access = public)
        Grid       = [1 1]      % [rows, cols]
        Theme      = []         % FastPlotTheme struct
        hFigure    = []         % figure handle
        ParentFigure = []      % external figure handle (skip figure creation)
        ContentOffset = [0 0 1 1]  % [left bottom width height] normalized content area
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

    % ====================== INTERNAL STATE ===============================
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

    % ====================== LAYOUT SETTINGS ==============================
    % Normalized spacing for the tile grid. Override before render().
    properties (Access = public)
        Padding = 0.06    % normalized padding around edges
        GapH    = 0.05    % horizontal gap between tiles
        GapV    = 0.07    % vertical gap between tiles
    end

    methods (Access = public)
        function obj = FastPlotFigure(rows, cols, varargin)
            %FASTPLOTFIGURE Construct a tiled dashboard.
            %   fig = FastPlotFigure(rows, cols)
            %   fig = FastPlotFigure(rows, cols, 'Theme', 'dark')
            %
            %   rows, cols — grid dimensions
            %   Remaining name-value pairs: 'Theme', 'ParentFigure', or
            %   any valid figure property (e.g. 'Name', 'Position').

            % Load cached defaults
            cfg = getDefaults();
            obj.Padding = cfg.DashboardPadding;
            obj.GapH = cfg.DashboardGapH;
            obj.GapV = cfg.DashboardGapV;
            obj.LiveInterval = cfg.LiveInterval;

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

            % Parse known constructor options
            conDefaults.Theme = [];
            conDefaults.ParentFigure = [];
            [conOpts, figOpts] = parseOpts(conDefaults, varargin);

            obj.Theme = resolveTheme(conOpts.Theme, cfg.Theme);
            obj.ParentFigure = conOpts.ParentFigure;

            if ~isempty(obj.ParentFigure)
                obj.hFigure = obj.ParentFigure;
            else
                figOptsCell = struct2nvpairs(figOpts);
                obj.hFigure = figure('Visible', 'off', ...
                    'Color', obj.Theme.Background, figOptsCell{:});
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
                    tileTheme = mergeTheme(tileTheme, obj.TileThemes{n});
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
            %   fig.startLive(filepath, updateFcn)
            %   fig.startLive(filepath, updateFcn, 'Interval', 1)
            %
            %   Starts a timer that polls filepath. On change, loads the
            %   .mat file and calls updateFcn(fig, data). Sets the view
            %   mode on all tiles.
            %
            %   Options (name-value):
            %     'Interval'          — poll period in seconds
            %     'ViewMode'          — 'preserve'|'follow'|'reset'
            %     'MetadataFile'      — path to metadata .mat file
            %     'MetadataVars'      — cell array of variable names
            %     'MetadataLineIndex' — line index for metadata
            %     'MetadataTileIndex' — tile index for metadata
            if obj.LiveIsActive
                obj.stopLive();
            end

            obj.LiveFile = filepath;
            obj.LiveUpdateFcn = updateFcn;

            liveDefaults.Interval = obj.LiveInterval;
            liveDefaults.ViewMode = '';
            liveDefaults.MetadataFile = obj.MetadataFile;
            liveDefaults.MetadataVars = obj.MetadataVars;
            liveDefaults.MetadataLineIndex = obj.MetadataLineIndex;
            liveDefaults.MetadataTileIndex = obj.MetadataTileIndex;
            [liveOpts, ~] = parseOpts(liveDefaults, varargin);
            obj.LiveInterval = liveOpts.Interval;
            obj.LiveViewMode = liveOpts.ViewMode;
            obj.MetadataFile = liveOpts.MetadataFile;
            obj.MetadataVars = liveOpts.MetadataVars;
            obj.MetadataLineIndex = liveOpts.MetadataLineIndex;
            obj.MetadataTileIndex = liveOpts.MetadataTileIndex;

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

    % ======================== PRIVATE METHODS ============================
    % Timer callbacks, metadata loading, axes creation, and layout math.
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
            meta = loadMetaStruct(obj.MetadataFile, obj.MetadataVars);
            if ~isempty(meta)
                tileIdx = obj.MetadataTileIndex;
                lineIdx = obj.MetadataLineIndex;
                if tileIdx >= 1 && tileIdx <= numel(obj.Tiles) && ~isempty(obj.Tiles{tileIdx})
                    obj.Tiles{tileIdx}.setLineMetadata(lineIdx, meta);
                end
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

    end

    methods (Access = public, Hidden = true)
        function pos = computeTilePosition(obj, n)
            %COMPUTETILEPOSITION Calculate normalized [x y w h] for tile n.
            %   Accounts for grid position, padding, gaps, tile spanning,
            %   and ContentOffset. Uses top-left origin row ordering
            %   converted to MATLAB's bottom-left coordinate system.
            rows = obj.Grid(1);
            cols = obj.Grid(2);
            span = obj.TileSpans{n};
            rowSpan = span(1);
            colSpan = span(2);

            % Convert tile index to row, col (1-based, top-left origin)
            row = ceil(n / cols);
            col = mod(n - 1, cols) + 1;

            pad = obj.Padding;
            gapH = obj.GapH;
            gapV = obj.GapV;

            % Content area
            co = obj.ContentOffset;
            coLeft = co(1); coBottom = co(2); coWidth = co(3); coHeight = co(4);

            % Available space after padding (within content area)
            totalW = coWidth - 2*pad;
            totalH = coHeight - 2*pad;

            % Cell dimensions
            cellW = (totalW - (cols-1)*gapH) / cols;
            cellH = (totalH - (rows-1)*gapV) / rows;

            % Position (bottom-left origin for MATLAB), offset by content area
            x = coLeft + pad + (col-1) * (cellW + gapH);
            y = coBottom + coHeight - pad - row * cellH - (row-1) * gapV;

            % Apply span
            w = colSpan * cellW + (colSpan-1) * gapH;
            h = rowSpan * cellH + (rowSpan-1) * gapV;

            pos = [x, y, w, h];
        end
    end
end
