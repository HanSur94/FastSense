function test_dashboard_range_selector_integration()
%TEST_DASHBOARD_RANGE_SELECTOR_INTEGRATION End-to-end: selector -> broadcast -> widget xlim.
%
%   Drives the engine's synchronous Hidden accessor broadcastTimeRangeNow
%   (plan 1016-03) and asserts that the active-page FastSenseWidget's axes
%   XLim reflects the new range. Stock Octave 7 has no MATLAB `timer`, so
%   Case 1 bypasses SliderDebounceTimer entirely.
%
%   Case 2 exercises the legacy triggerTimeSlidersChangedForTest shim (the
%   debounced path). The debounce relies on MATLAB's `timer`; under Octave
%   it fails silently (wrapped in TimeRangeSelector's try/catch), so Case 2
%   is gated to MATLAB only.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    x = linspace(0, 100, 500);
    y = sin(x * 0.1);
    d = DashboardEngine('integration-test');
    d.addWidget('fastsense', 'Title', 'sig', 'XData', x, 'YData', y);
    d.render();

    cleanup = onCleanup(@() safeDelete(d));

    % Engine's render path runs updateGlobalTimeRange, which sets
    % DataTimeRange from widget min/max and resets the selector to the full
    % data span.
    assert(~isempty(d.TimeRangeSelector_), 'selector not constructed');
    assert(isa(d.TimeRangeSelector_, 'TimeRangeSelector'), ...
        sprintf('selector type=%s expected TimeRangeSelector', class(d.TimeRangeSelector_)));

    span  = d.DataTimeRange(2) - d.DataTimeRange(1);
    tStart = d.DataTimeRange(1) + 0.25 * span;
    tEnd   = d.DataTimeRange(1) + 0.75 * span;

    % --- Case 1: synchronous path (Octave-safe) ------------------------------
    d.TimeRangeSelector_.setSelection(tStart, tEnd);
    d.broadcastTimeRangeNow(tStart, tEnd);

    w = d.Widgets{1};
    ax = w.FastSenseObj.hAxes;
    xl = get(ax, 'XLim');
    assert(abs(xl(1) - tStart) < 0.01, ...
        sprintf('Case 1 xl(1)=%.4f expected %.4f', xl(1), tStart));
    assert(abs(xl(2) - tEnd) < 0.01, ...
        sprintf('Case 1 xl(2)=%.4f expected %.4f', xl(2), tEnd));

    % --- Case 2: debounced path (MATLAB only) --------------------------------
    % The SliderDebounceTimer uses MATLAB's `timer`, which is not implemented
    % in stock Octave; under Octave TimeRangeSelector's OnRangeChanged catches
    % the failure, so we cannot reliably verify the debounced broadcast.
    if ~exist('OCTAVE_VERSION', 'builtin')
        d.TimeRangeSelector_.setSelection(d.DataTimeRange(1), tEnd);
        d.triggerTimeSlidersChangedForTest();
        pause(0.25);  % let the 100 ms debounce timer fire
        xl2 = get(ax, 'XLim');
        assert(abs(xl2(1) - d.DataTimeRange(1)) < 0.01, ...
            sprintf('Case 2 debounced xl2(1)=%.4f expected %.4f', ...
                    xl2(1), d.DataTimeRange(1)));
    else
        fprintf('    Case 2 debounce-timer assertion skipped on Octave.\n');
    end

    fprintf('    All 2 tests passed.\n');
end

function safeDelete(d)
%SAFEDELETE Cleanup helper tolerated if the engine is already gone.
    try
        if ~isempty(d) && isvalid(d)
            delete(d);
        end
    catch
    end
    try close(findall(0, 'Type', 'figure')); catch, end
end
