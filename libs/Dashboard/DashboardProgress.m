classdef DashboardProgress < handle
%DASHBOARDPROGRESS Progress-bar helper for DashboardEngine render passes.
%   Emits a self-updating progress line to stdout as widgets are realized
%   during DashboardEngine.render() / rerenderWidgets(), and a final
%   summary line on completion.
%
%   Silent outside interactive sessions so test / CI output stays clean.
%
%   Usage:
%       p = DashboardProgress(name, totalWidgets, totalPages);
%       p.tick(widget, pageIdx, pageName);    % call once per realized widget
%       p.finish();                            % call after the last widget
%
%   Construction:
%       DashboardProgress(name, total, totalPages)        % mode = 'auto'
%       DashboardProgress(name, total, totalPages, mode)  % mode in 'auto'|'on'|'off'
%
%   See also DashboardEngine.

    properties (SetAccess = private)
        DashboardName      = ''
        TotalWidgets       = 0
        TotalPages         = 0
        Current            = 0
        StartTime          = 0
        Silent             = true
        LastLineLen        = 0
    end

    properties (Constant, Access = private)
        BarWidth = 30
    end

    methods
        function obj = DashboardProgress(name, totalWidgets, totalPages, mode)
            if nargin < 4 || isempty(mode), mode = 'auto'; end
            obj.DashboardName = name;
            obj.TotalWidgets  = max(0, totalWidgets);
            obj.TotalPages    = max(0, totalPages);
            obj.StartTime     = tic();
            obj.Silent        = ~DashboardProgress.shouldShow(mode);
        end

        function tick(obj, widget, pageIdx, pageName)
            if obj.Silent, return; end
            obj.Current = min(obj.Current + 1, obj.TotalWidgets);

            bar = obj.renderBar();
            pageLabel = obj.formatPageLabel(pageIdx, pageName);
            widgetLabel = obj.formatWidgetLabel(widget);
            elapsed = toc(obj.StartTime);

            line = sprintf('[Dashboard ''%s''] [%s] %d/%d%s %s %.1fs', ...
                obj.DashboardName, bar, obj.Current, obj.TotalWidgets, ...
                pageLabel, widgetLabel, elapsed);

            obj.writeLine(line);
        end

        function finish(obj)
            if obj.Silent, return; end
            elapsed = toc(obj.StartTime);
            if obj.TotalPages > 1
                summary = sprintf('[Dashboard ''%s''] rendered %d widgets across %d pages in %.2fs', ...
                    obj.DashboardName, obj.TotalWidgets, obj.TotalPages, elapsed);
            else
                summary = sprintf('[Dashboard ''%s''] rendered %d widgets in %.2fs', ...
                    obj.DashboardName, obj.TotalWidgets, elapsed);
            end
            obj.clearLine();
            fprintf('%s\n', summary);
            obj.LastLineLen = 0;
        end
    end

    methods (Access = private)
        function bar = renderBar(obj)
            if obj.TotalWidgets <= 0
                bar = repmat('-', 1, obj.BarWidth);
                return;
            end
            filled = round(obj.BarWidth * obj.Current / obj.TotalWidgets);
            filled = max(0, min(obj.BarWidth, filled));
            bar = [repmat('#', 1, filled), repmat('-', 1, obj.BarWidth - filled)];
        end

        function label = formatPageLabel(obj, pageIdx, pageName)
            if obj.TotalPages <= 1
                label = '';
                return;
            end
            if isempty(pageName)
                label = sprintf(' (page %d/%d)', pageIdx, obj.TotalPages);
            else
                label = sprintf(' (page %d/%d ''%s'')', pageIdx, obj.TotalPages, pageName);
            end
        end

        function label = formatWidgetLabel(obj, widget)
            if isstruct(widget) && isfield(widget, 'ClassName')
                typeName = widget.ClassName;
            else
                typeName = class(widget);
            end
            title = '';
            if isstruct(widget) && isfield(widget, 'Title')
                title = widget.Title;
            elseif isobject(widget)
                try
                    title = widget.Title;
                catch
                    title = '';
                end
            end
            if isempty(title)
                label = sprintf('%s #%d', typeName, obj.Current);
            else
                label = sprintf('%s ''%s''', typeName, title);
            end
        end

        function writeLine(obj, line)
            pad = '';
            if obj.LastLineLen > numel(line)
                pad = repmat(' ', 1, obj.LastLineLen - numel(line));
            end
            fprintf('\r%s%s', line, pad);
            obj.LastLineLen = numel(line);
        end

        function clearLine(obj)
            if obj.LastLineLen > 0
                fprintf('\r%s\r', repmat(' ', 1, obj.LastLineLen));
            end
        end
    end

    methods (Static, Access = private)
        function tf = shouldShow(mode)
            switch mode
                case 'on',  tf = true;
                case 'off', tf = false;
                otherwise
                    tf = DashboardProgress.isInteractiveSession();
            end
        end

        function tf = isInteractiveSession()
            if exist('OCTAVE_VERSION', 'builtin')
                tf = exist('isguirunning', 'builtin') && isguirunning();
                return;
            end
            tf = usejava('desktop');
            if tf && exist('batchStartupOptionUsed', 'builtin') && ...
                    batchStartupOptionUsed()
                tf = false;
            end
        end
    end
end
