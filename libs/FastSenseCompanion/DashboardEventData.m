classdef DashboardEventData < event.EventData
%DASHBOARDEVENTDATA Payload for DashboardSelected and OpenDashboardRequested events.
%
%   Usage (inside DashboardListPane):
%     ed = DashboardEventData(engine, idx);
%     notify(obj, 'DashboardSelected', ed);
%     notify(obj, 'OpenDashboardRequested', ed);
%
%   The orchestrator's listener receives ed as the second arg:
%     addlistener(pane, 'DashboardSelected', @(src, ed) onSel(src, ed));
%
%   Properties (read-only after construction):
%     Engine - DashboardEngine handle the row represents
%     Index  - 1-based index into the orchestrator's Engines_ cell
%
%   See also DashboardListPane, FastSenseCompanion, event.EventData.

    properties (SetAccess = immutable)
        Engine = []
        Index  = 0
    end

    methods
        function obj = DashboardEventData(engine, idx)
        %DASHBOARDEVENTDATA Construct payload with engine handle + 1-based index.
            if nargin < 2
                error('FastSenseCompanion:invalidEventData', ...
                    'DashboardEventData requires (engine, idx).');
            end
            if ~isa(engine, 'DashboardEngine')
                error('FastSenseCompanion:invalidEventData', ...
                    'DashboardEventData: engine must be a DashboardEngine handle.');
            end
            if ~isnumeric(idx) || ~isscalar(idx) || idx < 1 || idx ~= floor(idx)
                error('FastSenseCompanion:invalidEventData', ...
                    'DashboardEventData: idx must be a positive integer scalar.');
            end
            obj.Engine = engine;
            obj.Index  = double(idx);
        end
    end
end
