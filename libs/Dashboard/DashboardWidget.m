classdef (Abstract) DashboardWidget < handle
%DASHBOARDWIDGET Abstract base class for all dashboard widgets.
%
%   Subclasses must implement:
%     render(parentPanel) — create graphics objects inside the panel
%     refresh()           — update data/display (called by live timer)
%     configure()         — open properties UI for edit mode
%     getType()           — return widget type string (e.g. 'fastplot')
%
%   Subclasses must also provide a static fromStruct(s) method.

    properties (Access = public)
        Title    = ''           % Widget title displayed in header
        Position = [1 1 3 2]    % [col, row, width, height] in grid units
        ThemeOverride = struct() % Per-widget theme overrides (merged on top of dashboard theme)
        UseGlobalTime = true    % false when user manually zooms this widget
    end

    properties (SetAccess = protected)
        hPanel = []             % Handle to the uipanel this widget renders into
    end

    properties (Dependent)
        Type                    % Widget type string (from getType)
    end

    methods
        function obj = DashboardWidget(varargin)
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function t = get.Type(obj)
            t = obj.getType();
        end

        function s = toStruct(obj)
            s.type = obj.Type;
            s.title = obj.Title;
            s.position = struct('col', obj.Position(1), ...
                                'row', obj.Position(2), ...
                                'width', obj.Position(3), ...
                                'height', obj.Position(4));
            if ~isempty(fieldnames(obj.ThemeOverride))
                s.themeOverride = obj.ThemeOverride;
            end
        end

        function delete(obj)
            if ~isempty(obj.hPanel) && isvalid(obj.hPanel)
                delete(obj.hPanel);
            end
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
    end

    methods (Abstract)
        render(obj, parentPanel)
        refresh(obj)
        configure(obj)
        t = getType(obj)
    end
end
