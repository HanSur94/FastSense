# runLive() Design — Octave Timer Alternative

**Goal:** Add `runLive()` blocking poll loop so live mode auto-polling works on Octave (which lacks MATLAB's `timer` object).

**Approach:** Explicit `runLive()` method that blocks in a `while` loop with `pause(interval)` + `drawnow` (keeps GUI responsive). MATLAB users don't need it — their timer fires automatically.

## API

```matlab
% Both platforms: configure live mode
fp.startLive('data.mat', @updateFcn, 'Interval', 2);

% Octave only: start blocking poll loop
fp.runLive();  % blocks until figure closed or Ctrl+C
```

On MATLAB, `runLive()` detects the timer is running and returns immediately (no-op).

## Behavior

- `runLive()` requires `LiveIsActive == true` (i.e., `startLive()` was called)
- Enters `while ishandle(hFigure) && obj.LiveIsActive` loop
- Each iteration: check `dir(LiveFile).datenum`, load + call `LiveUpdateFcn` if changed, `drawnow`, `pause(interval)`
- Uses `onCleanup` for Ctrl+C → calls `stopLive()`
- Exit conditions: figure closed, Ctrl+C, toolbar Live button toggled off

## Changes

- `FastPlot.m`: add `runLive()` public method, clean up `startLive` Octave fallback (remove struct placeholder, just skip timer)
- `FastPlotFigure.m`: add `runLive()` public method, same cleanup
- `tests/test_live.m`: add test for `runLive()` with `LiveIsActive = false` (returns immediately)
- `examples/example_live.m`: add `runLive()` call for Octave compatibility
- `README.md`: document `runLive()` in the Live Mode section
