classdef SpyTimeWindowEngine < handle
%SPYTIMEWINDOWENGINE Lightweight test double recording setTimeWindow calls.
%
%   Models on tests/CaptureNotificationService.m. Used by the Phase 1041
%   TestFastSenseCompanion integration tests to assert that onRangeChanged_
%   pushes the resolved [t0, t1] window to managed engines and ad-hoc figures.
%
%   Usage:
%     spy = SpyTimeWindowEngine();
%     companion.addDashboard(spy);          % managed-engine path
%     -- or --
%     hf = figure('Visible','off');
%     setappdata(hf, 'DashboardEngine', spy);
%     companion.trackOpenedFigureForTest_(hf);
%
%     companion.TimeRange_.setRelative(30, 'days');   % triggers onRangeChanged_
%     assert(spy.CallCount >= 1);
%     assert(abs(spy.LastT1 - spy.LastT0 - 30) < 1/24);
%
%   Properties:
%     hFigure     — figure handle stub ([] by default; read by syncOpenedFigures_)
%     LastT0      — t0 passed to most recent setTimeWindow call (or [])
%     LastT1      — t1 passed to most recent setTimeWindow call (or [])
%     CallCount   — cumulative count of setTimeWindow calls
%
%   Methods:
%     setTimeWindow(obj, t0, t1)  — records t0, t1, increments CallCount
%
%   See also CompanionTimeRange, FastSenseCompanion.

    properties
        hFigure    = []   % figure handle ([] = not-yet-rendered; skipped by syncOpenedFigures_)
        LastT0     = []   % t0 from the most recent setTimeWindow call
        LastT1     = []   % t1 from the most recent setTimeWindow call
        CallCount  = 0    % total number of setTimeWindow calls received
    end

    methods

        function setTimeWindow(obj, t0, t1)
        %SETTIMEWINDOW Record the window arguments and increment the call counter.
        %
        %   setTimeWindow(obj, t0, t1) stores the t0 and t1 values and
        %   increments CallCount. Does NOT call a real DashboardEngine.
            obj.LastT0    = t0;
            obj.LastT1    = t1;
            obj.CallCount = obj.CallCount + 1;
        end

    end

end
