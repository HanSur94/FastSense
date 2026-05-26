classdef MultiLineFastSenseWidget < DashboardWidget
%MULTILINEFASTSENSEWIDGET Test helper: dashboard widget hosting a multi-line FastSense.
%   Used by the hover-crosshair manual demos to verify the colored-bullet
%   datatip in a real DashboardEngine context. Not a shipped widget.

    properties (Access = public)
        Series = struct('X', {}, 'Y', {}, 'Name', {}, 'Color', {})
    end

    properties (SetAccess = private)
        FastSenseObj = []
    end

    methods
        function obj = MultiLineFastSenseWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 24 4];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            ax = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.08 0.12 0.88 0.78]);
            fp = FastSense('Parent', ax);
            for i = 1:numel(obj.Series)
                s = obj.Series(i);
                args = {'DisplayName', s.Name};
                if ~isempty(s.Color); args = [args, {'Color', s.Color}]; end %#ok<AGROW>
                fp.addLine(s.X, s.Y, args{:});
            end
            fp.render();
            obj.FastSenseObj = fp;
            if ~isempty(obj.Title)
                title(ax, obj.Title);
            end
        end

        function refresh(obj) %#ok<MANU>
        end

        function s = getType(~)
            s = 'MultiLineFastSenseWidget';
        end
    end
end
