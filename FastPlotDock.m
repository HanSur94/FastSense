classdef FastPlotDock < handle
    %FASTPLOTDOCK Tabbed container for multiple FastPlotFigure dashboards.
    %   dock = FastPlotDock()
    %   dock = FastPlotDock('Theme', 'dark', 'Name', 'My Dock')

    properties (Access = public)
        Theme     = []         % FastPlotTheme struct
        hFigure   = []         % shared figure handle
    end

    properties (SetAccess = private)
        Tabs      = struct('Name', {}, 'Figure', {}, 'Toolbar', {})
        ActiveTab = 0          % index of currently visible tab
        hTabButtons = {}       % cell array of uicontrol handles
    end

    properties (Constant, Access = private)
        TAB_BAR_HEIGHT = 0.04  % normalized height for tab bar
    end

    methods (Access = public)
        function obj = FastPlotDock(varargin)
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
                    otherwise
                        figOpts{end+1} = varargin{k};   %#ok<AGROW>
                        figOpts{end+1} = varargin{k+1};  %#ok<AGROW>
                end
            end

            if isempty(obj.Theme)
                obj.Theme = FastPlotTheme('default');
            end

            obj.hFigure = figure('Visible', 'off', ...
                'Color', obj.Theme.Background, figOpts{:});
        end

        function addTab(obj, fig, name)
            %ADDTAB Register a FastPlotFigure as a tab.
            %   dock.addTab(fig, 'Tab Name')

            % Ensure the figure renders into our window
            if isempty(fig.ParentFigure) || fig.ParentFigure ~= obj.hFigure
                fig.ParentFigure = obj.hFigure;
                fig.hFigure = obj.hFigure;
            end

            % Set content offset to leave room for tab bar
            tabH = obj.TAB_BAR_HEIGHT;
            fig.ContentOffset = [0, 0, 1, 1 - tabH];

            % Append to tabs
            idx = numel(obj.Tabs) + 1;
            obj.Tabs(idx).Name = name;
            obj.Tabs(idx).Figure = fig;
            obj.Tabs(idx).Toolbar = [];
        end

        function delete(obj)
            % Stop all live timers before closing
            for i = 1:numel(obj.Tabs)
                if ~isempty(obj.Tabs(i).Figure)
                    try obj.Tabs(i).Figure.stopLive(); catch; end
                end
            end
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                delete(obj.hFigure);
            end
        end
    end
end
