classdef MockDashboardWidget < DashboardWidget
    methods
        function obj = MockDashboardWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
        end

        function refresh(obj)
        end

        function t = getType(obj)
            t = 'mock';
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = MockDashboardWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
        end

        function invokeClearPanelControls(hPanel)
            %INVOKECLEARPANELCONTROLS Test-visible wrapper around the
            %   protected DashboardWidget.clearPanelControls helper.
            %   Subclasses can call protected static methods on the
            %   parent class; ordinary test code cannot.
            DashboardWidget.clearPanelControls(hPanel);
        end
    end
end
