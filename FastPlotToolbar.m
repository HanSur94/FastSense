classdef FastPlotToolbar < handle
    %FASTPLOTTOOLBAR Custom toolbar for FastPlot figures.
    %   tb = FastPlotToolbar(fp)        — attach to a FastPlot
    %   tb = FastPlotToolbar(fig)       — attach to a FastPlotFigure

    properties (SetAccess = private)
        Target        = []    % FastPlot or FastPlotFigure
        hFigure       = []    % figure handle
        hToolbar      = []    % uitoolbar handle
        FastPlots     = {}    % cell array of all FastPlot instances
        Mode          = 'none'  % 'none' | 'cursor' | 'crosshair'
        hCursorBtn    = []    % uitoggletool handle
        hCrosshairBtn = []    % uitoggletool handle
        hCrosshairH   = []    % horizontal crosshair line
        hCrosshairV   = []    % vertical crosshair line
        hCrosshairTxt = []    % crosshair text annotation
        hCursorDot    = []    % data cursor marker
        hCursorTxt    = []    % data cursor text box
        SavedCallbacks = struct() % saved figure callbacks to restore
    end

    methods (Access = public)
        function obj = FastPlotToolbar(target)
            obj.Target = target;

            % Resolve figure handle and FastPlot instances
            if isa(target, 'FastPlotFigure')
                obj.hFigure = target.hFigure;
                obj.FastPlots = {};
                for i = 1:numel(target.Tiles)
                    if ~isempty(target.Tiles{i})
                        obj.FastPlots{end+1} = target.Tiles{i};
                    end
                end
            elseif isa(target, 'FastPlot')
                obj.hFigure = target.hFigure;
                obj.FastPlots = {target};
            else
                error('FastPlotToolbar:invalidTarget', ...
                    'Target must be a FastPlot or FastPlotFigure instance.');
            end

            obj.createToolbar();
        end
    end

    methods (Access = private)
        function createToolbar(obj)
            obj.hToolbar = uitoolbar(obj.hFigure);

            % Buttons: cursor, crosshair, grid, legend, autoscale, export
            obj.hCursorBtn = uitoggletool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('cursor'), ...
                'TooltipString', 'Data Cursor', ...
                'OnCallback',  @(s,e) obj.onCursorOn(), ...
                'OffCallback', @(s,e) obj.onCursorOff());

            obj.hCrosshairBtn = uitoggletool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('crosshair'), ...
                'TooltipString', 'Crosshair', ...
                'OnCallback',  @(s,e) obj.onCrosshairOn(), ...
                'OffCallback', @(s,e) obj.onCrosshairOff());

            uipushtool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('grid'), ...
                'TooltipString', 'Toggle Grid', ...
                'ClickedCallback', @(s,e) obj.onToggleGrid());

            uipushtool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('legend'), ...
                'TooltipString', 'Toggle Legend', ...
                'ClickedCallback', @(s,e) obj.onToggleLegend());

            uipushtool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('autoscale'), ...
                'TooltipString', 'Autoscale Y', ...
                'ClickedCallback', @(s,e) obj.onAutoscaleY());

            uipushtool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('export'), ...
                'TooltipString', 'Export PNG', ...
                'ClickedCallback', @(s,e) obj.onExportPNG());
        end

        % --- Placeholder callbacks (implemented in subsequent tasks) ---
        function onCursorOn(obj)
            obj.Mode = 'cursor';
        end

        function onCursorOff(obj)
            obj.Mode = 'none';
        end

        function onCrosshairOn(obj)
            obj.Mode = 'crosshair';
        end

        function onCrosshairOff(obj)
            obj.Mode = 'none';
        end

        function onToggleGrid(obj)
        end

        function onToggleLegend(obj)
        end

        function onAutoscaleY(obj)
        end

        function onExportPNG(obj)
        end

        function [fp, ax] = getActiveTarget(obj)
            %GETACTIVETARGET Find the FastPlot instance under the mouse.
            fp = [];
            ax = [];
            cp = get(obj.hFigure, 'CurrentPoint');
            for i = 1:numel(obj.FastPlots)
                a = obj.FastPlots{i}.hAxes;
                if ~ishandle(a); continue; end
                oldUnits = get(a, 'Units');
                set(a, 'Units', 'pixels');
                pos = get(a, 'Position');
                set(a, 'Units', oldUnits);
                if cp(1) >= pos(1) && cp(1) <= pos(1)+pos(3) && ...
                   cp(2) >= pos(2) && cp(2) <= pos(2)+pos(4)
                    fp = obj.FastPlots{i};
                    ax = a;
                    return;
                end
            end
        end
    end

    methods (Static)
        function icon = makeIcon(name)
            %MAKEICON Generate a 16x16x3 RGB icon for toolbar buttons.
            icon = ones(16, 16, 3) * 0.94;  % light gray background
            fg = [0.2 0.2 0.2];  % dark foreground

            switch name
                case 'cursor'
                    % Crosshair with center dot
                    icon(8, 3:13, :) = repmat(reshape(fg,1,1,3), 1, 11, 1);
                    icon(3:13, 8, :) = repmat(reshape(fg,1,1,3), 11, 1, 1);
                    for dr = -1:1
                        for dc = -1:1
                            icon(8+dr, 8+dc, :) = reshape(fg,1,1,3);
                        end
                    end

                case 'crosshair'
                    % Thin + cross
                    icon(8, 2:14, :) = repmat(reshape(fg,1,1,3), 1, 13, 1);
                    icon(2:14, 8, :) = repmat(reshape(fg,1,1,3), 13, 1, 1);

                case 'grid'
                    % Grid lines
                    icon(4, 2:14, :)  = repmat(reshape(fg,1,1,3), 1, 13, 1);
                    icon(8, 2:14, :)  = repmat(reshape(fg,1,1,3), 1, 13, 1);
                    icon(12, 2:14, :) = repmat(reshape(fg,1,1,3), 1, 13, 1);
                    icon(2:14, 4, :)  = repmat(reshape(fg,1,1,3), 13, 1, 1);
                    icon(2:14, 8, :)  = repmat(reshape(fg,1,1,3), 13, 1, 1);
                    icon(2:14, 12, :) = repmat(reshape(fg,1,1,3), 13, 1, 1);

                case 'legend'
                    % Box with lines
                    icon(3, 3:13, :)  = repmat(reshape(fg,1,1,3), 1, 11, 1);
                    icon(13, 3:13, :) = repmat(reshape(fg,1,1,3), 1, 11, 1);
                    icon(3:13, 3, :)  = repmat(reshape(fg,1,1,3), 11, 1, 1);
                    icon(3:13, 13, :) = repmat(reshape(fg,1,1,3), 11, 1, 1);
                    icon(6, 5:7, :)   = repmat(reshape([0.8 0.2 0.2],1,1,3), 1, 3, 1);
                    icon(6, 9:11, :)  = repmat(reshape(fg,1,1,3), 1, 3, 1);
                    icon(10, 5:7, :)  = repmat(reshape([0.2 0.2 0.8],1,1,3), 1, 3, 1);
                    icon(10, 9:11, :) = repmat(reshape(fg,1,1,3), 1, 3, 1);

                case 'autoscale'
                    % Vertical double arrow
                    icon(2:14, 8, :) = repmat(reshape(fg,1,1,3), 13, 1, 1);
                    % Up arrow
                    icon(3, 7:9, :) = repmat(reshape(fg,1,1,3), 1, 3, 1);
                    icon(4, 6:10, :) = repmat(reshape(fg,1,1,3), 1, 5, 1);
                    % Down arrow
                    icon(13, 7:9, :) = repmat(reshape(fg,1,1,3), 1, 3, 1);
                    icon(12, 6:10, :) = repmat(reshape(fg,1,1,3), 1, 5, 1);

                case 'export'
                    % Camera shape
                    icon(5, 5:11, :)  = repmat(reshape(fg,1,1,3), 1, 7, 1);
                    icon(12, 4:12, :) = repmat(reshape(fg,1,1,3), 1, 9, 1);
                    icon(5:12, 4, :)  = repmat(reshape(fg,1,1,3), 8, 1, 1);
                    icon(5:12, 12, :) = repmat(reshape(fg,1,1,3), 8, 1, 1);
                    icon(4, 6:8, :)   = repmat(reshape(fg,1,1,3), 1, 3, 1);
                    % Lens circle (approximate)
                    for r = [7 8 9]
                        for c = [7 8 9]
                            if (r-8)^2 + (c-8)^2 <= 2
                                icon(r, c, :) = reshape(fg,1,1,3);
                            end
                        end
                    end
            end
        end
    end
end
