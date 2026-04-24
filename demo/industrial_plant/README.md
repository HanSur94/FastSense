# FastSense Industrial Plant Demo

## What this is

A runnable, self-contained showcase of the FastSense dashboard system. A
synthetic industrial-plant data generator drives live `SensorTag`,
`StateTag`, `MonitorTag`, and `CompositeTag` instances through the
`LiveTagPipeline`, and a six-page `DashboardEngine` figure exercises
every widget type plus tabs, groups, info tooltips, detachable widgets,
a plant-health rollup, and event-driven alerts. Use it as both a smoke
test and a living reference.

## How to run

```matlab
install();        % add library paths + compile MEX (once per machine)
ctx = run_demo(); % starts the generator, pipeline, and dashboard
```

Closing the dashboard figure tears every timer down automatically
(`CloseRequestFcn` -> `teardownDemo(ctx)`).

## What to click

- **Switch tabs** at the top: *Overview / Feed Line / Reactor / Cooling /
  Events / Diagnostics*.
- **Hover the info icon** (the little `i`) on any widget to surface its
  description tooltip.
- **Collapse / expand** any `GroupWidget` or the *Advanced* collapsible
  on the Reactor page via the chevron in the group header.
- **Main reactor pressure plot detaches on startup.** It opens in a
  standalone figure window you can resize freely. Close that window (or
  press the re-attach button on its panel) to fold it back into the
  dashboard. Pop out any other widget the same way via the detach button
  on its title bar.
- **Watch the Events page.** A `MonitorTag` fires within ~15 seconds for
  reactor.pressure spikes (deterministic anomaly windows at t ~= 15 s and
  t ~= 45 s); events populate the `EventTimelineWidget` and round markers
  appear on the FastSense plot.

## Architecture

- **Plan 01** (`1015-01-SUMMARY.md`): wiring layer -- plant taxonomy,
  synthetic generator, TagRegistry population, `LiveTagPipeline`.
- **Plan 02** (`1015-02-SUMMARY.md`): dashboard composition -- six pages,
  all 20 widget kinds from the catalogue, `InfoText` tooltips, detach,
  plant-health rollup, event overlays.
- Upstream phases: tag model (1011), tag pipeline (1012), events
  (1009-1010), dashboard engine (01-1008).

## Shutdown

Close the figure. `teardownDemo` stops the writer timer, stops the
`LiveTagPipeline`, stops the dashboard `LiveTimer`, and clears the
`TagRegistry`.

## Limitations

- Data resets on every run (clean-start; no replay).
- Single `DashboardTheme` preset (dark).
- Local MATLAB figure only; no WebBridge browser mirror in this demo.
- Octave: the synthetic generator and `LiveTagPipeline` rely on MATLAB's
  `timer` primitive, so the end-to-end smoke path is MATLAB-only (Octave
  users can still read the source to learn the wiring patterns).
