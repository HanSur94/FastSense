classdef ImageWidget < DashboardWidget
    properties (Access = public)
        File      = ''          % Path to image file (PNG, JPG)
        ImageFcn  = []          % function_handle returning image matrix
        Scaling   = 'fit'       % 'fit', 'fill', 'stretch'
        Caption   = ''
    end

    properties (SetAccess = private)
        hAxes          = []
        hImage         = []
        hCaption       = []
        CachedImgData_ = []    % cached imread result; invalidated when File_ or ImageFcn change
        CachedFile_    = ''    % the File path that produced CachedImgData_
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

            imgData = obj.getImgData_();
            if isempty(imgData), return; end

            % Only rebuild the image object when the data actually changed.
            % For file-backed widgets with a static file, CachedImgData_ stays
            % constant across ticks so the early-out fires immediately after the
            % first render, avoiding a full imagesc/image + axis call every tick.
            % ImageFcn-backed widgets always rebuild (callback may return new data).
            if ~isempty(obj.hImage) && ishandle(obj.hImage) && isempty(obj.ImageFcn)
                % In-place update: just swap CData — no axes re-layout needed.
                try
                    set(obj.hImage, 'CData', imgData);
                    return;
                catch
                    % Handle no longer valid; fall through to full rebuild.
                end
            end

            % For matrices (not RGB uint8), use imagesc so CData auto-scales to
            % the colormap range -- image() would clip to 1..64 and render a dark block.
            if ndims(imgData) == 2
                obj.hImage = imagesc(obj.hAxes, imgData);
                colormap(obj.hAxes, 'parula');
            else
                obj.hImage = image(obj.hAxes, imgData);
            end
            axis(obj.hAxes, 'image');
            set(obj.hAxes, 'Visible', 'off');
            % Keep title visible even though axes is invisible (set by render()).
            if ~isempty(obj.Title)
                try set(get(obj.hAxes, 'Title'), 'Visible', 'on'); catch, end
            end
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

    methods (Access = private)
        function imgData = getImgData_(obj)
        %GETIMGDATA_ Return image data, caching file reads across ticks.
        %   File-backed widgets: imread is called only when File changes or the
        %   cache is empty. The cached path (CachedFile_) is compared to the
        %   current File property; a mismatch forces a reload.
        %   ImageFcn-backed widgets: the callback is always invoked (its return
        %   value may change every tick, e.g. a live correlation image).
            imgData = [];
            if ~isempty(obj.File) && exist(obj.File, 'file')
                if isempty(obj.CachedImgData_) || ~strcmp(obj.CachedFile_, obj.File)
                    obj.CachedImgData_ = imread(obj.File);
                    obj.CachedFile_ = obj.File;
                end
                imgData = obj.CachedImgData_;
            elseif ~isempty(obj.ImageFcn)
                imgData = obj.ImageFcn();
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
