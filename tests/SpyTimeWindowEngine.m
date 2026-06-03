classdef SpyTimeWindowEngine < DashboardEngine
%SPYTIMEWINDOWENGINE Lightweight DashboardEngine test double recording setTimeWindow calls.
%
%   Subclasses DashboardEngine (rather than plain handle) so it passes the
%   isa(d,'DashboardEngine') gate in FastSenseCompanion.addDashboard and can be
%   exercised through the *managed-engine* re-query path. The ad-hoc figure path
%   duck-types via getappdata + ismethod, so this double works there too.
%
%   The DashboardEngine constructor only sets up in-memory layout/state and does
%   NOT create a figure (rendering is deferred to render()), so constructing a
%   spy is cheap and headless-safe. setTimeWindow is overridden to record the
%   call arguments instead of fanning out to (non-existent) widget panels.
%
%   Used by the Phase 1041 TestFastSenseCompanion integration tests to assert
%   that onRangeChanged_ pushes the resolved [t0, t1] window to managed engines
%   and ad-hoc figures.
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
%     LastT0      — t0 passed to most recent setTimeWindow call (or [])
%     LastT1      — t1 passed to most recent setTimeWindow call (or [])
%     CallCount   — cumulative count of setTimeWindow calls
%
%   See also CompanionTimeRange, FastSenseCompanion, DashboardEngine.

    properties
        LastT0     = []   % t0 from the most recent setTimeWindow call
        LastT1     = []   % t1 from the most recent setTimeWindow call
        CallCount  = 0    % total number of setTimeWindow calls received
    end

    methods

        function obj = SpyTimeWindowEngine()
        %SPYTIMEWINDOWENGINE Construct a managed-engine spy (no figure created).
            obj@DashboardEngine('spy-time-window-engine');
        end

        function setTimeWindow(obj, t0, t1)
        %SETTIMEWINDOW Record the window arguments and increment the call counter.
        %
        %   setTimeWindow(obj, t0, t1) stores t0 and t1 and increments CallCount.
        %   Overrides DashboardEngine.setTimeWindow: records only, does NOT
        %   touch widget panels (the spy has none).
            obj.LastT0    = t0;
            obj.LastT1    = t1;
            obj.CallCount = obj.CallCount + 1;
        end

    end

end
