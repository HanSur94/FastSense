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
    %   FastPlotFigure Properties:
    %     Grid             — [rows, cols] grid dimensions
    %     Theme            — FastPlotTheme struct for all tiles
    %     hFigure          — figure handle
    %     ParentFigure     — external figure handle (skip figure creation)
    %     ContentOffset    — [left bottom width height] normalized content area
    %     LiveViewMode     — 'preserve' | 'follow' | 'reset' for live updates
    %     LiveFile         — path to .mat file for live polling
    %     LiveUpdateFcn    — @(fig, data) callback on live data change
    %     LiveIsActive     — whether live polling is running
    %     LiveInterval     — poll interval in seconds (default 2.0)
    %     MetadataFile     — path to metadata .mat file
    %     MetadataVars     — variable names to extract from metadata
    %     MetadataLineIndex — line index within the tile for metadata
    %     MetadataTileIndex — which tile to attach metadata to
    %     ShowProgress     — show console progress bar during renderAll
    %     Padding          — [left bottom right top] normalized padding
    %     GapH             — horizontal gap between tiles (normalized)
    %     GapV             — vertical gap between tiles (normalized)
    %
    %   FastPlotFigure Methods:
    %     FastPlotFigure    — construct a tiled dashboard
    %     tile              — get or create the FastPlot instance for tile n
    %     axes              — get or create a raw MATLAB axes for tile n
    %     setTileSpan       — set the row/column span for tile n
    %     setTileTheme      — set per-tile theme overrides
    %     tileTitle         — set title for tile n
    %     tileXLabel        — set xlabel for tile n
    %     tileYLabel        — set ylabel for tile n
    %     renderAll         — render all tiles that haven't been rendered yet
    %     render            — alias for renderAll
    %     reapplyTheme      — re-apply theme to figure and all rendered tiles
    %     startLive         — start live mode on the dashboard
    %     stopLive          — stop live polling
    %     refresh           — manual one-shot reload
    %     setViewMode       — set view mode on all tiles
    %     runLive           — blocking poll loop for Octave compatibility
    %     computeTilePosition — calculate normalized [x y w h] for tile n
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
    %   Example — mixed tile types:
    %     fig = FastPlotFigure(2, 2, 'Theme', 'dark');
    %     fig.tile(1).addLine(t, y1);           % FastPlot (optimized)
    %     ax = fig.axes(2); bar(ax, x, y2);     % raw axes (bar chart)
    %     ax = fig.axes(3); scatter(ax, x, y3); % raw axes (scatter)
    %     fig.tile(4).addLine(t, y4);           % FastPlot (optimized)
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
        ShowProgress     = true      % show console progress bar during renderAll
    end

    % ====================== INTERNAL STATE ===============================
    properties (SetAccess = private)
        Tiles      = {}         % cell array of FastPlot instances
        TileAxes   = {}         % cell array of axes handles
        TileSpans  = {}         % cell array of [rowSpan, colSpan]
        TileThemes = {}         % cell array of theme override structs
        TileTitles = {}         % cell array of buffered title strings
        TileXLabels = {}        % cell array of buffered xlabel strings
        TileYLabels = {}        % cell array of buffered ylabel strings
        RawAxesTiles = []     % logical array: true = raw axes, false = FastPlot
        IsRendered = false
        LiveTimer      = []        % timer object
        LiveFileDate   = 0         % last known file datenum
        MetadataFileDate  = 0         % last known metadata file datenum
    end

    % ====================== LAYOUT SETTINGS ==============================
    % Normalized spacing for the tile grid. Override before render().
    properties (Access = public)
        Padding = [0.06 0.04 0.01 0.02]  % [left bottom right top] normalized
        GapH    = 0.03    % horizontal gap between tiles
        GapV    = 0.06    % vertical gap between tiles
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
            obj.Tiles      = cell(1, nTiles);
            obj.TileAxes   = cell(1, nTiles);
            obj.TileSpans  = cell(1, nTiles);
            obj.TileThemes = cell(1, nTiles);
            obj.TileTitles = cell(1, nTiles);
            obj.TileXLabels = cell(1, nTiles);
            obj.TileYLabels = cell(1, nTiles);
            obj.RawAxesTiles = false(1, nTiles);

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
            %   fp = fig.tile(n) returns the FastPlot for tile n, creating
            %   it (and its axes) on first access. Tile themes are merged
            %   from the figure theme and any per-tile overrides.
            %
            %   Input:
            %     n — tile index (1 to rows*cols, row-major order)
            %
            %   Output:
            %     fp — FastPlot instance for the requested tile
            %
            %   See also setTileSpan, setTileTheme.
            nTiles = obj.Grid(1) * obj.Grid(2);
            if n < 1 || n > nTiles
                error('FastPlotFigure:outOfBounds', ...
                    'Tile %d is out of range (1-%d).', n, nTiles);
            end

            if obj.RawAxesTiles(n)
                error('FastPlotFigure:tileConflict', ...
                    'Tile %d is a raw axes tile. Use axes(%d) to access it.', n, n);
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

        function ax = axes(obj, n)
            %AXES Get or create a raw MATLAB axes for tile n.
            %   ax = fig.axes(n) returns a themed MATLAB axes handle at the
            %   position for tile n. Use for non-FastPlot plot types (bar,
            %   scatter, histogram, stem, etc.). The axes gets theme colors
            %   applied but no FastPlot optimization.
            %
            %   Mutually exclusive with tile(n) — a tile cannot be both a
            %   FastPlot and a raw axes.
            %
            %   Input:
            %     n — tile index (1 to rows*cols, row-major order)
            %
            %   Output:
            %     ax — MATLAB axes handle
            %
            %   Example:
            %     ax = fig.axes(2);
            %     bar(ax, [1 2 3], [10 20 15]);
            %
            %   See also tile, setTileSpan.
            nTiles = obj.Grid(1) * obj.Grid(2);
            if n < 1 || n > nTiles
                error('FastPlotFigure:outOfBounds', ...
                    'Tile %d is out of range (1-%d).', n, nTiles);
            end

            if ~isempty(obj.Tiles{n})
                error('FastPlotFigure:tileConflict', ...
                    'Tile %d is a FastPlot tile. Use tile(%d) to access it.', n, n);
            end

            if isempty(obj.TileAxes{n})
                ax = obj.createTileAxes(n);
                obj.TileAxes{n} = ax;
                obj.RawAxesTiles(n) = true;
                obj.applyThemeToAxes(ax);
            else
                ax = obj.TileAxes{n};
            end
        end

        function hp = tilePanel(obj, n)
            %TILEPANEL  Get or create a uipanel for tile n.
            %   hp = fig.tilePanel(n) returns a uipanel handle at the
            %   computed grid position for tile n. Use this to embed
            %   composite widgets (e.g. SensorDetailPlot) into a tile.
            %
            %   Throws an error if tile n is already occupied by a
            %   FastPlot (via tile()) or raw axes (via axes()).

            nTiles = obj.Grid(1) * obj.Grid(2);
            if n < 1 || n > nTiles
                error('FastPlotFigure:invalidTile', ...
                    'Tile index %d is out of range [1, %d].', n, nTiles);
            end

            % Idempotency: return cached panel if already created
            if ~isempty(obj.TileAxes{n}) && isa(obj.TileAxes{n}, 'matlab.ui.container.Panel')
                hp = obj.TileAxes{n};
                return;
            end

            % Conflict check: occupied by FastPlot?
            if ~isempty(obj.Tiles{n})
                error('FastPlotFigure:tileConflict', ...
                    'Tile %d is a FastPlot tile. Use tile(%d) to access it.', n, n);
            end

            % Conflict check: occupied by raw axes?
            if obj.RawAxesTiles(n)
                error('FastPlotFigure:tileConflict', ...
                    'Tile %d is a raw axes tile. Use axes(%d) to access it.', n, n);
            end

            % Create panel at tile position with theme background
            pos = obj.computeTilePosition(n);
            hp = uipanel('Parent', obj.hFigure, ...
                'Units', 'normalized', 'Position', pos, ...
                'BorderType', 'none', ...
                'BackgroundColor', obj.Theme.Background);

            % Attach theme so embedded widgets (e.g. SensorDetailPlot) can
            % auto-inherit the figure's theme without explicit Theme arg.
            hp.UserData = struct('FastPlotTheme', obj.Theme);

            % Store panel handle (reuses TileAxes cell for storage)
            obj.TileAxes{n} = hp;
            % Mark as occupied to prevent future tile()/axes() conflicts
            obj.RawAxesTiles(n) = true;
        end

        function setTileSpan(obj, n, span)
            %SETTILESPAN Set the row/column span for tile n.
            %   fig.setTileSpan(n, span) configures tile n to occupy
            %   multiple rows and/or columns in the grid layout.
            %
            %   Inputs:
            %     n    — tile index (1 to rows*cols)
            %     span — [rowSpan, colSpan], e.g. [2 1] for 2 rows, 1 col
            %
            %   If the tile's axes already exist, their position is
            %   immediately recomputed to reflect the new span.
            %
            %   Example:
            %     fig.setTileSpan(1, [2 1]);  % tile 1 spans 2 rows, 1 col
            %
            %   See also tile, computeTilePosition.
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
            %   fig.setTileTheme(n, themeOverrides) stores a partial theme
            %   struct for tile n. When the tile is created or re-themed,
            %   these overrides are merged on top of the figure-level theme.
            %
            %   Inputs:
            %     n              — tile index (1 to rows*cols)
            %     themeOverrides — struct with theme fields to override
            %
            %   Example:
            %     fig.setTileTheme(2, struct('Background', [0 0 0]));
            %
            %   See also tile, reapplyTheme.
            nTiles = obj.Grid(1) * obj.Grid(2);
            if n < 1 || n > nTiles
                error('FastPlotFigure:outOfBounds', ...
                    'Tile %d is out of range (1-%d).', n, nTiles);
            end
            obj.TileThemes{n} = themeOverrides;
        end

        function tileTitle(obj, n, str)
            %TILETITLE Set title for tile n.
            %   fig.tileTitle(n, str) sets the axes title on tile n using
            %   the figure theme's TitleFontSize and ForegroundColor.
            %   Can be called before or after render().
            %
            %   Inputs:
            %     n   — tile index (1 to rows*cols)
            %     str — title string
            %
            %   See also tileXLabel, tileYLabel.
            obj.TileTitles{n} = str;
            ax = obj.getTileAxesHandle(n);
            if ~isempty(ax)
                title(ax, str, 'FontSize', obj.Theme.TitleFontSize, ...
                    'Color', obj.Theme.ForegroundColor);
            end
        end

        function tileXLabel(obj, n, str)
            %TILEXLABEL Set xlabel for tile n.
            %   fig.tileXLabel(n, str) sets the X-axis label on tile n
            %   using the figure theme's ForegroundColor.
            %   Can be called before or after render().
            %
            %   Inputs:
            %     n   — tile index (1 to rows*cols)
            %     str — label string
            %
            %   See also tileTitle, tileYLabel.
            obj.TileXLabels{n} = str;
            ax = obj.getTileAxesHandle(n);
            if ~isempty(ax)
                xlabel(ax, str, 'Color', obj.Theme.ForegroundColor);
            end
        end

        function tileYLabel(obj, n, str)
            %TILEYLABEL Set ylabel for tile n.
            %   fig.tileYLabel(n, str) sets the Y-axis label on tile n
            %   using the figure theme's ForegroundColor.
            %   Can be called before or after render().
            %
            %   Inputs:
            %     n   — tile index (1 to rows*cols)
            %     str — label string
            %
            %   See also tileTitle, tileXLabel.
            obj.TileYLabels{n} = str;
            ax = obj.getTileAxesHandle(n);
            if ~isempty(ax)
                ylabel(ax, str, 'Color', obj.Theme.ForegroundColor);
            end
        end

        function renderAll(obj, parentProgressBar)
            %RENDERALL Render all tiles that haven't been rendered yet.
            %   fig.renderAll() renders all tiles and makes the figure visible.
            %   fig.renderAll(parentProgressBar) renders as a child of a
            %   dock or parent progress context (skips figure show/drawnow).
            %
            %   Each tile is rendered with DeferDraw=true and a per-tile
            %   ConsoleProgressBar. Tiles that are already rendered are skipped.
            %
            %   Input:
            %     parentProgressBar — (optional) truthy value indicating nested
            %                         render context; suppresses figure visibility
            %
            %   See also render, tile.
            if nargin < 2; parentProgressBar = []; end

            % Collect FastPlot tiles that need rendering (skip raw axes tiles)
            tilesToRender = [];
            for i = 1:numel(obj.Tiles)
                if obj.RawAxesTiles(i)
                    continue;
                end
                if ~isempty(obj.Tiles{i}) && ~obj.Tiles{i}.IsRendered
                    tilesToRender(end+1) = i; %#ok<AGROW>
                end
            end
            nTiles = numel(tilesToRender);

            % Determine indent level (0 standalone, 2 from dock)
            if ~isempty(parentProgressBar)
                tileIndent = 2;
            else
                tileIndent = 0;
            end

            showProg = obj.ShowProgress && nTiles > 0;

            try
                for k = 1:nTiles
                    i = tilesToRender(k);
                    nLines = numel(obj.Tiles{i}.Lines);

                    % Create per-tile progress bar
                    if showProg
                        cpb = ConsoleProgressBar(tileIndent);
                        cpb.update(0, max(nLines, 1), sprintf('Tile %d/%d', k, nTiles));
                        cpb.start();
                    else
                        cpb = [];
                    end

                    obj.Tiles{i}.DeferDraw = true;
                    obj.Tiles{i}.ShowProgress = false;
                    obj.Tiles{i}.render(cpb);
                    obj.Tiles{i}.DeferDraw = false;
                end
            catch err
                if showProg && ~isempty(cpb); cpb.finish(); end
                rethrow(err);
            end

            % Apply buffered titles and labels now that axes exist
            for i = 1:numel(obj.Tiles)
                % Determine the axes handle for this tile
                if obj.RawAxesTiles(i)
                    if isempty(obj.TileAxes{i}); continue; end
                    % Skip uipanel tiles (from tilePanel) — they manage their own content
                    if isa(obj.TileAxes{i}, 'matlab.ui.container.Panel'); continue; end
                    ax = obj.TileAxes{i};
                else
                    if isempty(obj.Tiles{i}) || ~obj.Tiles{i}.IsRendered
                        continue;
                    end
                    ax = obj.Tiles{i}.hAxes;
                end
                if ~isempty(obj.TileTitles{i})
                    title(ax, obj.TileTitles{i}, 'FontSize', obj.Theme.TitleFontSize, ...
                        'Color', obj.Theme.ForegroundColor);
                end
                if ~isempty(obj.TileXLabels{i})
                    xlabel(ax, obj.TileXLabels{i}, 'Color', obj.Theme.ForegroundColor);
                end
                if ~isempty(obj.TileYLabels{i})
                    ylabel(ax, obj.TileYLabels{i}, 'Color', obj.Theme.ForegroundColor);
                end
            end

            % Skip figure show + drawnow when nested (dock manages visibility)
            if isempty(parentProgressBar)
                set(obj.hFigure, 'Visible', 'on');
                drawnow;
            end
        end

        function render(obj)
            %RENDER Alias for renderAll.
            %   fig.render() is a convenience alias for fig.renderAll().
            %
            %   See also renderAll.
            obj.renderAll();
        end

        function reapplyTheme(obj)
            %REAPPLYTHEME Re-apply theme to figure and all rendered tiles.
            %   fig.reapplyTheme() updates the figure background and
            %   propagates the current Theme to every rendered tile.
            %   Per-tile theme overrides (from setTileTheme) are merged
            %   on top of the figure-level theme before propagation.
            %
            %   Use after changing fig.Theme to update all visuals.
            %
            %   See also setTileTheme, FastPlot.reapplyTheme.
            set(obj.hFigure, 'Color', obj.Theme.Background);
            for i = 1:numel(obj.Tiles)
                if obj.RawAxesTiles(i)
                    % Raw axes: apply theme colors directly (skip uipanel tiles)
                    if ~isempty(obj.TileAxes{i}) && ishandle(obj.TileAxes{i}) && ...
                       ~isa(obj.TileAxes{i}, 'matlab.ui.container.Panel')
                        obj.applyThemeToAxes(obj.TileAxes{i});
                    end
                elseif ~isempty(obj.Tiles{i}) && obj.Tiles{i}.IsRendered
                    if ~isempty(obj.TileThemes) && i <= numel(obj.TileThemes) && ~isempty(obj.TileThemes{i})
                        obj.Tiles{i}.Theme = mergeTheme(obj.Theme, obj.TileThemes{i});
                    else
                        obj.Tiles{i}.Theme = obj.Theme;
                    end
                    obj.Tiles{i}.reapplyTheme();
                end
            end
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

            % Set view mode on FastPlot tiles only (raw axes tiles are unmanaged)
            for i = 1:numel(obj.Tiles)
                if ~obj.RawAxesTiles(i) && ~isempty(obj.Tiles{i})
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
            %   fig.stopLive() stops and deletes the internal timer, then
            %   sets LiveIsActive to false. Safe to call when not active.
            %
            %   See also startLive, runLive.
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
            %   fig.refresh() loads the LiveFile, calls LiveUpdateFcn,
            %   and reloads the metadata file if configured. Errors if
            %   no live source has been configured via startLive().
            %
            %   See also startLive, stopLive.
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
            %   fig.setViewMode(mode) sets LiveViewMode on the figure and
            %   propagates it to every non-empty tile.
            %
            %   Input:
            %     mode — 'preserve' | 'follow' | 'reset'
            %
            %   See also startLive.
            obj.LiveViewMode = mode;
            for i = 1:numel(obj.Tiles)
                if ~obj.RawAxesTiles(i) && ~isempty(obj.Tiles{i})
                    obj.Tiles{i}.LiveViewMode = mode;
                end
            end
        end

        function runLive(obj)
            %RUNLIVE Blocking poll loop for live mode (Octave compatibility).
            %   fig.runLive() enters a blocking while-loop that polls
            %   LiveFile at LiveInterval. On MATLAB, this is a no-op if
            %   the timer is already running. On Octave (which lacks the
            %   timer object), this provides equivalent functionality.
            %   The loop exits when LiveIsActive becomes false or the
            %   figure is closed. An onCleanup guard calls stopLive().
            %
            %   See also startLive, stopLive.
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
            %ONLIVETIMER Timer callback: check for data and metadata changes.
            %   Compares the file's datenum against LiveFileDate. If the file
            %   has been modified, loads it and calls LiveUpdateFcn. Also
            %   checks the MetadataFile for changes and reloads if needed.
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
            %LOADMETADATAFILE Load metadata from file and attach to target tile/line.
            %   Uses loadMetaStruct() to extract MetadataVars from
            %   MetadataFile, then calls setLineMetadata on the tile and
            %   line specified by MetadataTileIndex and MetadataLineIndex.
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
            %ONFIGURECLOSELIVE Figure close handler during live mode.
            %   Stops live polling, then chains to the previously installed
            %   DeleteFcn (if any) so that other cleanup still runs.
            %
            %   Inputs:
            %     existingDeleteFcn — previous DeleteFcn (function_handle or [])
            %     src               — source figure handle
            %     evt               — event data
            obj.stopLive();
            if ~isempty(existingDeleteFcn) && isa(existingDeleteFcn, 'function_handle')
                existingDeleteFcn(src, evt);
            end
        end

        function ax = createTileAxes(obj, n)
            %CREATETILEAXES Create an axes at the computed position for tile n.
            %   ax = createTileAxes(obj, n) computes the normalized position
            %   for tile n and creates an axes parented to hFigure. Locks
            %   the axes to its assigned position to prevent MATLAB's
            %   automatic layout padding adjustments.
            %
            %   Input:
            %     n — tile index (1 to rows*cols)
            %
            %   Output:
            %     ax — newly created axes handle
            pos = obj.computeTilePosition(n);
            ax = axes('Parent', obj.hFigure, 'Position', pos);
            % Lock axes to its assigned position (prevent MATLAB padding)
            try
                set(ax, 'PositionConstraint', 'innerposition');
            catch
                set(ax, 'ActivePositionProperty', 'position');
            end
        end

        function ax = getTileAxesHandle(obj, n)
            %GETTILEAXESHANDLE Get the axes handle for tile n (FastPlot or raw).
            if obj.RawAxesTiles(n)
                ax = obj.TileAxes{n};
                if ~isempty(ax) && ~ishandle(ax); ax = []; end
                % tilePanel tiles store a uipanel, not axes — return empty
                if ~isempty(ax) && isa(ax, 'matlab.ui.container.Panel'); ax = []; end
            else
                fp = obj.Tiles{n};
                if ~isempty(fp) && ~isempty(fp.hAxes) && ishandle(fp.hAxes)
                    ax = fp.hAxes;
                else
                    % Tile exists but not rendered yet — call tile() to create axes
                    if ~isempty(fp)
                        ax = [];
                    else
                        fp = obj.tile(n);
                        if ~isempty(fp.hAxes) && ishandle(fp.hAxes)
                            ax = fp.hAxes;
                        else
                            ax = [];
                        end
                    end
                end
            end
        end

        function applyThemeToAxes(obj, ax)
            %APPLYTHEMETOAXES Apply figure theme colors to a raw axes.
            set(ax, 'Color', obj.Theme.AxesColor, ...
                    'XColor', obj.Theme.ForegroundColor, ...
                    'YColor', obj.Theme.ForegroundColor, ...
                    'GridColor', obj.Theme.GridColor);
            if ~isempty(obj.Theme.GridAlpha)
                set(ax, 'GridAlpha', obj.Theme.GridAlpha);
            end
            set(ax, 'FontSize', obj.Theme.FontSize);
        end

    end

    methods (Access = public, Hidden = true)
        function pos = computeTilePosition(obj, n)
            %COMPUTETILEPOSITION Calculate normalized [x y w h] for tile n.
            %   pos = computeTilePosition(obj, n) computes the normalized
            %   position vector for tile n, accounting for grid position,
            %   Padding, GapH, GapV, tile spanning (TileSpans), and
            %   ContentOffset. Tiles are numbered in row-major order with
            %   top-left origin, then converted to MATLAB's bottom-left
            %   coordinate system.
            %
            %   Input:
            %     n — tile index (1 to rows*cols)
            %
            %   Output:
            %     pos — [x, y, w, h] in normalized figure coordinates
            %
            %   See also setTileSpan, createTileAxes.
            rows = obj.Grid(1);
            cols = obj.Grid(2);
            span = obj.TileSpans{n};
            rowSpan = span(1);
            colSpan = span(2);

            % Convert tile index to row, col (1-based, top-left origin)
            row = ceil(n / cols);
            col = mod(n - 1, cols) + 1;

            % Padding: scalar or [left bottom right top]
            p = obj.Padding;
            if isscalar(p)
                padL = p; padB = p; padR = p; padT = p;
            else
                padL = p(1); padB = p(2); padR = p(3); padT = p(4);
            end
            gapH = obj.GapH;
            gapV = obj.GapV;

            % Content area
            co = obj.ContentOffset;
            coLeft = co(1); coBottom = co(2); coWidth = co(3); coHeight = co(4);

            % Available space after padding (within content area)
            totalW = coWidth - padL - padR;
            totalH = coHeight - padT - padB;

            % Cell dimensions
            cellW = (totalW - (cols-1)*gapH) / cols;
            cellH = (totalH - (rows-1)*gapV) / rows;

            % Position (bottom-left origin for MATLAB), offset by content area
            x = coLeft + padL + (col-1) * (cellW + gapH);
            y = coBottom + padB + (rows - row) * (cellH + gapV);

            % Apply span
            w = colSpan * cellW + (colSpan-1) * gapH;
            h = rowSpan * cellH + (rowSpan-1) * gapV;

            pos = [x, y, w, h];
        end
    end
end
