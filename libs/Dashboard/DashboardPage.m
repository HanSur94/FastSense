classdef DashboardPage < handle
%DASHBOARDPAGE Named page container within a multi-page dashboard.
%
%   Each DashboardPage holds a list of widgets to be rendered when the
%   page is active. DashboardEngine maintains a Pages cell array of
%   DashboardPage objects and routes addWidget() to the active page.
%
%   Usage:
%     pg = DashboardPage('Overview');
%     pg.addWidget(myWidget);
%     s = pg.toStruct();    % serialize for JSON save
%
%   Properties:
%     Name    (char)  - Display name of the page; default ''
%     Widgets (cell)  - Cell array of DashboardWidget instances
%
%   Methods:
%     addWidget(w)  - Append w to the Widgets list
%     toStruct()    - Return serializable struct {name, widgets}

    properties (Access = public)
        Name    = ''
        Widgets = {}
    end

    methods

        function obj = DashboardPage(name)
        %DASHBOARDPAGE Construct a named page container.
        %   pg = DashboardPage()        creates page with Name = ''
        %   pg = DashboardPage('Name')  creates page with given Name
            if nargin >= 1
                obj.Name = name;
            end
        end

        function w = addWidget(obj, w)
        %ADDWIDGET Append widget w to the Widgets list.
        %   pg.addWidget(w) appends w to obj.Widgets.
            obj.Widgets{end+1} = w;
        end

        function s = toStruct(obj)
        %TOSTRUCT Serialize the page to a struct with name and widgets fields.
        %   s = pg.toStruct() returns s.name (char) and s.widgets (cell).
            s.name = obj.Name;
            s.widgets = cell(1, numel(obj.Widgets));
            for i = 1:numel(obj.Widgets)
                s.widgets{i} = obj.Widgets{i}.toStruct();
            end
        end

    end

end
