classdef ThrowingEventWidget < NumberWidget
%THROWINGEVENTWIDGET Test fixture: NumberWidget subclass whose getEventTimes
%   deliberately errors. Used by TestDashboardEngineEventMarkers to verify
%   DashboardEngine.computeEventMarkers swallows a faulty widget and still
%   renders markers for well-behaved siblings.

    methods
        function t = getEventTimes(~) %#ok<STOUT>
            error('ThrowingEventWidget:boom', 'deliberate failure for test');
        end
    end
end
