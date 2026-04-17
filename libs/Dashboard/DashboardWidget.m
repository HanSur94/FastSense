classdef DashboardWidget < handle
%DASHBOARDWIDGET Abstract base class for all dashboard widgets.
%
%   Subclasses must implement:
%     render(parentPanel) — create graphics objects inside the panel
%     refresh()           — update data/display (called by live timer)
%     getType()           — return widget type string (e.g. 'fastsense')
%
%   Subclasses must also provide a static fromStruct(s) method.

    properties (Access = public)
        Title       = ''           % Widget title displayed in header
        Position    = [1 1 6 2]    % [col, row, width, height] in grid units
        ThemeOverride = struct()   % Per-widget theme overrides (merged on top of dashboard theme)
        UseGlobalTime = true       % false when user manually zooms this widget
        Description = ''           % Optional tooltip text shown via info icon hover
        Tag         = []           % v2.0 Tag API — any Tag subclass
        ParentTheme = []           % Theme inherited from DashboardEngine
        Dirty       = true         % true when widget needs refresh (data changed)
    end

    properties (SetAccess = private)
        Realized    = false        % true after render() has been called (use markRealized/markUnrealized)
    end

    properties (SetAccess = public)
        hPanel = []             % Handle to the uipanel this widget renders into
    end

    properties (Dependent)
        Type                    % Widget type string (from getType)
    end

    methods
        function obj = DashboardWidget(varargin)
            % Map legacy 'Sensor' NV pair to 'Tag' for backward compat
            % of serialized dashboards.
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'Sensor')
                    varargin{k} = 'Tag';
                end
            end
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
            % Title cascade from Tag.
            if isempty(obj.Title) && ~isempty(obj.Tag)
                if ~isempty(obj.Tag.Name)
                    obj.Title = obj.Tag.Name;
                else
                    obj.Title = obj.Tag.Key;
                end
            end
        end

        function t = get.Type(obj)
            t = obj.getType();
        end

        function s = toStruct(obj)
            s.type = obj.Type;
            s.title = obj.Title;
            s.description = obj.Description;
            s.position = struct('col', obj.Position(1), ...
                                'row', obj.Position(2), ...
                                'width', obj.Position(3), ...
                                'height', obj.Position(4));
            if ~isempty(fieldnames(obj.ThemeOverride))
                s.themeOverride = obj.ThemeOverride;
            end
            % Source from Tag.
            if ~isempty(obj.Tag) && ~isempty(obj.Tag.Key)
                s.source = struct('type', 'tag', 'key', obj.Tag.Key);
            end
        end

        function delete(obj)
            if ~isempty(obj.hPanel) && ishandle(obj.hPanel)
                delete(obj.hPanel);
            end
        end

        function markDirty(obj)
        %MARKDIRTY Flag this widget as needing a refresh.
            obj.Dirty = true;
        end

        function markRealized(obj)
        %MARKREALIZED Mark this widget as having been rendered.
            obj.Realized = true;
        end

        function markUnrealized(obj)
        %MARKUNREALIZED Mark this widget as needing re-render.
            obj.Realized = false;
        end
    end

    methods
        function setTimeRange(~, ~, ~)
            % Override in subclasses to respond to global time changes.
        end

        function [tMin, tMax] = getTimeRange(~)
            % Override in subclasses to report data time range.
            tMin = inf; tMax = -inf;
        end

        function lines = asciiRender(obj, width, height)
        %ASCIIRENDER Return ASCII representation of this widget.
        %   lines = asciiRender(obj, width, height) returns a cell array
        %   of strings, each exactly WIDTH characters. HEIGHT is the
        %   available number of lines. Default implementation shows
        %   [type] Title; subclasses override for richer content.
            if height <= 0
                lines = {};
                return;
            end
            label = sprintf('[%s]', obj.getType());
            if ~isempty(obj.Title)
                label = sprintf('%s %s', label, obj.Title);
            end
            if numel(label) > width
                label = label(1:width);
            end
            label = [label, repmat(' ', 1, width - numel(label))];
            lines = cell(1, height);
            lines{1} = label;
            blank = repmat(' ', 1, width);
            for i = 2:height
                lines{i} = blank;
            end
        end
    end

    methods (Access = protected)
        function theme = getTheme(obj)
            if ~isempty(obj.ParentTheme) && isstruct(obj.ParentTheme)
                theme = obj.ParentTheme;
            else
                theme = DashboardTheme();
            end
            if ~isempty(fieldnames(obj.ThemeOverride))
                fns = fieldnames(obj.ThemeOverride);
                for i = 1:numel(fns)
                    theme.(fns{i}) = obj.ThemeOverride.(fns{i});
                end
            end
        end
    end

    methods (Abstract)
        render(obj, parentPanel)
        refresh(obj)
        t = getType(obj)
    end
end
