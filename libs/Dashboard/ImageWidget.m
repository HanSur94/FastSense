classdef ImageWidget < DashboardWidget
    properties (Access = public)
        File      = ''          % Path to image file (PNG, JPG)
        ImageFcn  = []          % function_handle returning image matrix
        Scaling   = 'fit'       % 'fit', 'fill', 'stretch'
        Caption   = ''
    end

    properties (SetAccess = private)
        hAxes     = []
        hImage    = []
        hCaption  = []
    end

    methods
        function obj = ImageWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 6 4];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            captionH = 0;
            if ~isempty(obj.Caption)
                captionH = 0.08;
            end

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.02 captionH+0.02 0.96 0.96-captionH], ...
                'Visible', 'off');

            if ~isempty(obj.Title)
                title(obj.hAxes, obj.Title, ...
                    'Color', theme.ForegroundColor, ...
                    'FontSize', theme.WidgetTitleFontSize);
                try set(get(obj.hAxes, 'Title'), 'Visible', 'on'); catch, end
            end

            if ~isempty(obj.Caption)
                obj.hCaption = uicontrol(parentPanel, ...
                    'Style', 'text', ...
                    'String', obj.Caption, ...
                    'Units', 'normalized', ...
                    'Position', [0.02 0 0.96 captionH], ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 9, ...
                    'ForegroundColor', theme.AxisColor, ...
                    'BackgroundColor', theme.WidgetBackground);
            end

            obj.refresh();
        end

        function refresh(obj)
            if isempty(obj.hAxes) || ~ishandle(obj.hAxes)
                return;
            end

            imgData = [];
            if ~isempty(obj.File) && exist(obj.File, 'file')
                imgData = imread(obj.File);
            elseif ~isempty(obj.ImageFcn)
                imgData = obj.ImageFcn();
            end
            if isempty(imgData), return; end

            obj.hImage = image(obj.hAxes, imgData);
            axis(obj.hAxes, 'image');
            set(obj.hAxes, 'Visible', 'off');
        end

        function t = getType(~)
            t = 'image';
        end

        function lines = asciiRender(obj, width, height)
            if height <= 0, lines = {}; return; end
            blank = repmat(' ', 1, width);
            lines = cell(1, height);
            for i = 1:height, lines{i} = blank; end

            ttl = obj.Title;
            if isempty(ttl), ttl = obj.Caption; end
            if numel(ttl) > width, ttl = ttl(1:width); end
            if ~isempty(ttl)
                lines{1} = [ttl, repmat(' ', 1, width - numel(ttl))];
            end

            if height >= 2
                if ~isempty(obj.File)
                    [~, fname, ext] = fileparts(obj.File);
                    info = sprintf('[img: %s%s]', fname, ext);
                else
                    info = '[-- image --]';
                end
                if numel(info) > width, info = info(1:width); end
                lines{2} = [info, repmat(' ', 1, width - numel(info))];
            end
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.File), s.file = obj.File; end
            if ~isempty(obj.Caption), s.caption = obj.Caption; end
            s.scaling = obj.Scaling;
            if ~isempty(obj.ImageFcn) && isempty(obj.File)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.ImageFcn));
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = ImageWidget();
            if isfield(s, 'title'), obj.Title = s.title; end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                    s.position.width, s.position.height];
            end
            if isfield(s, 'file'), obj.File = s.file; end
            if isfield(s, 'caption'), obj.Caption = s.caption; end
            if isfield(s, 'scaling'), obj.Scaling = s.scaling; end
        end
    end
end
