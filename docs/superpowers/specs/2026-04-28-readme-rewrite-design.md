# README Rewrite — Design

**Date:** 2026-04-28
**Scope:** Rewrite `README.md` end-to-end. No other surfaces (Wiki, GitHub Pages, About sidebar, social preview) are in scope.

## Goals

1. Make the README a compelling front-page that explains the project's purpose to a stranger in under a minute.
2. Reflect the v2.0 **Tag domain model** (`Tag` / `SensorTag` / `StateTag` / `MonitorTag` / `CompositeTag` / `TagRegistry`) — the current README's code samples still use the retired `Sensor` / `StateChannel` / `addThresholdRule` / `EventConfig.runDetection` API.
3. Drop all in-README screenshots — the existing ones in `docs/images/` are not good enough; regeneration is out of scope here.
4. Replace the long "Five Pillars" walk-through with a concise capability inventory.
5. Keep what already works: the perf table, the badges row, the install block, the wiki/examples links.

## Non-Goals

- No Wiki edits.
- No regeneration of screenshots.
- No new GitHub Pages site or `homepageUrl` setup.
- No changes to `LICENSE`, `CITATION.cff`, or repo metadata.
- No edits to `examples/` or library code.

## Constraints

- README must be self-contained — no broken cross-links to deleted sections.
- All code blocks must use the **current** Tag-based API; no references to `Sensor(...)` / `addThresholdRule` / `addStateChannel` / `EventConfig.runDetection`.
- Keep existing badge URLs and benchmark links unchanged.
- The author's personal name MUST NOT appear anywhere in the README body, including the BibTeX block and the license line. (`LICENSE` and `CITATION.cff` files themselves are not modified.)
- Tone: technical and confident, not marketing-speak. The audience is MATLAB engineers working with industrial sensor data.

## Final Structure

The new README has these top-level sections, in order:

1. **Title + tagline + badges** — H1, badges row, single-line benefit tagline, two short framing paragraphs that name *Tags* up front and identify the audience.
2. **30 seconds in** — a single self-contained code block (10M points, plot + threshold) using the rendering API (`addLine`/`addThreshold`), with one payoff sentence linking forward to the perf table.
3. **The core idea: Tags** — table of the four Tag flavours, then a code block showing `SensorTag` + a `MonitorTag` over a single parent (`MonitorTag(key, parent, conditionFn)`), then a closing line that says the same Tag drives plots, dashboards, events, notifications, and the web bridge.
4. **Build a dashboard** — a `DashboardEngine` block that reuses the `press` and `alarm` tags from Section 3 (continuity), 4 widget lines, plus 4 compact bullets covering widget count, layout features, live mode, and `WebBridge`.
5. **Performance** — the existing comparison table verbatim, the existing footnote (live charts link), and one new short paragraph naming the techniques (per-pixel MinMax/LTTB downsampling, SQLite-backed disk store, render pipeline).
6. **What's in the box** — 7 bullets: plotting engine, Tag domain model, event detection, dashboards, browser bridge, disk-backed storage, pure MATLAB/Octave. Replaces the old "Five Pillars" / "Features at a Glance" sections.
7. **Install** — `git clone` + `install;` block, MEX-is-optional note, requirements line.
8. **Examples & docs** — one paragraph linking `examples/` and the Wiki.
9. **Citation · License** — `bibtex` block (no `author` field), pointer to `CITATION.cff`, MIT line (no author attribution).

## Removed Sections

These existing sections do not appear in the new README:

- **Table of Contents** — redundant given the shorter length.
- **Why FastSense?** — its content is folded into the framing paragraphs at the top.
- **Features at a Glance** — replaced by "What's in the box".
- **The Five Pillars** — replaced by Sections 3, 4, and 6 collectively.
- **Contributing** — issue/wiki links are sufficient; the existing section was boilerplate.

## Section-Level Specifications

### Section 1 — Title + tagline + framing

```markdown
# FastSense

[Tests | Benchmark | codecov | License: MIT | MATLAB R2020b+ | GNU Octave 7+ | Platform badges]

> **Sensor data, at the scale you actually have it — in MATLAB.**

FastSense is a pure-MATLAB platform for working with massive sensor
time-series. Plot 100M+ points without crashing, model sensors as
**Tags** with state-aware behaviour, detect events as they happen, and
compose interactive dashboards — all without a single toolbox license.

Built for engineers who deal with real industrial data: long recordings,
condition-dependent alarm limits, dashboards that need to stay live for
hours, and the moment when MATLAB's own `plot()` falls over at 10M
points.
```

Badges row reuses the seven existing badges (Tests, Benchmark, codecov, License, MATLAB, Octave, Platform) with their current URLs.

### Section 2 — 30 seconds in

````markdown
## 30 seconds in

```matlab
install;   % run once: adds paths + builds MEX accelerators

x = linspace(0, 100, 1e7);              % 10 million points
y = sin(x) + 0.1 * randn(size(x));

fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true);
fp.render();
```

That renders in **a few milliseconds and stays at 200+ FPS while you
zoom and pan**. MATLAB's built-in `plot()` takes ~3 seconds on the
same data and crawls at ~2 FPS. ([benchmarks ↓](#performance))
````

Uses the rendering API only; Tags are introduced in the next section.

### Section 3 — The core idea: Tags

````markdown
## The core idea: Tags

Everything in FastSense — sensors, machine states, alarms, derived
signals — is a **Tag**. One unified type, four flavours:

| Tag           | What it is                                                  |
|---------------|-------------------------------------------------------------|
| `SensorTag`   | A measured time-series (pressure, temperature, …)           |
| `StateTag`    | A discrete system state (idle / running / fault, recipe)    |
| `MonitorTag`  | A derived 0/1 alarm signal — "is this sensor out of spec?"  |
| `CompositeTag`| An aggregation of other tags                                |

Tags carry their own metadata (units, criticality, labels) and live in
a shared **`TagRegistry`** so every part of the system — plots,
dashboards, event detection, the web bridge — speaks the same language.

```matlab
press = SensorTag('press_a', 'Name', 'Chamber Pressure', 'Units', 'bar');
press.updateData(t, pressure_data);

% Alarm whenever pressure > 55 bar
alarm = MonitorTag('press_high', press, @(x, y) y > 55);

TagRegistry.register(press);
TagRegistry.register(alarm);

fp = FastSense();
fp.addTag(press);
fp.addTag(alarm);     % overlaid as a 0/1 step trace
fp.render();
```

The same `alarm` tag drives event detection, lights up status widgets
in the dashboard, fires notifications, and shows up in the browser
bridge — without you re-declaring the rule four times. For monitors
that depend on multiple parents (e.g., a state-conditional alarm),
compose them via `CompositeTag`.
````

`MonitorTag` constructor signature confirmed against `libs/SensorThreshold/MonitorTag.m`: `MonitorTag(key, parentTag, conditionFn, varargin)` — single positional parent, function handle takes `(x, y)`.

### Section 4 — Build a dashboard

````markdown
## Build a dashboard

Compose monitoring dashboards from widgets on a 24-column grid. The
same Tags drive the data — no re-wiring.

```matlab
d = DashboardEngine('Process Monitor');
d.Theme = 'dark';
d.addWidget('fastsense', 'Position', [1 1 16 8],  'Tag', press);
d.addWidget('number',    'Position', [17 1 8 4],  'Tag', press, 'Label', 'Pressure');
d.addWidget('gauge',     'Position', [17 5 8 4],  'Tag', press, 'Label', 'Live');
d.addWidget('status',    'Position', [1 9 24 2],  'Tag', alarm, 'Label', 'Alarm');
d.render();

d.save('process.json');           % JSON-persist
% later:  d = DashboardEngine.load('process.json');
```

- **21 widget types** — plots, numbers, gauges, status lights, gantt
  timelines, heatmaps, tables, markdown, …
- **Multi-page tabs · collapsible groups · pop-out detached widgets**
- **Live mode** — synchronised refresh on a configurable timer
- **Browser bridge** — `WebBridge(d).serve()` exposes the dashboard
  over TCP to a FastAPI + uPlot frontend
````

Widget invocations use the `'Tag', ...` keyword — the v2.0 base property defined on `DashboardWidget` (with `'Sensor'` kept as a backward-compat alias).

### Section 5 — Performance

````markdown
## Performance

FastSense vs. MATLAB's built-in `plot()` on 10M data points:

|                  | `plot()`  | FastSense       |
|------------------|-----------|-----------------|
| Render time      | ~3.2 s    | **4.7 ms**      |
| Memory           | 153 MB    | **0.06 MB**     |
| Zoom/pan FPS     | ~2 FPS    | **212 FPS**     |
| Points displayed | 10 000 000| ~400 (visually identical) |

<sub>MacBook Pro M1 Pro · GNU Octave 11 · MEX + NEON. Tracked on every
commit; regressions trigger alerts.
<a href="https://hansur94.github.io/FastSense/dev/bench/">Live benchmark charts</a></sub>

The trick: per-pixel **MinMax** and **LTTB** downsampling (SIMD C
kernels with pure-MATLAB fallbacks), an SQLite-backed disk store for
datasets that don't fit in RAM, and a render pipeline that only
touches the points you can actually see.
````

Numbers preserved verbatim from the existing README (no new benchmarking).

### Section 6 — What's in the box

```markdown
## What's in the box

- **Plotting engine** — 100M+ point time-series, 6 themes, linked axes,
  datetime support, optional MEX SIMD kernels
- **Tag domain model** — `SensorTag`, `StateTag`, `MonitorTag`,
  `CompositeTag`, shared `TagRegistry`
- **Event detection** — group violations into events, statistics, live
  pipeline, interactive Gantt viewer, notifications
- **Dashboards** — 21 widget types, JSON persistence, multi-page,
  collapsible, detachable, live refresh
- **Browser bridge** — TCP → FastAPI → uPlot, bidirectional callbacks
- **Disk-backed storage** — SQLite chunks with WAL for live reads,
  pyramid-cached downsamples
- **Pure MATLAB / Octave** — no toolboxes, no internet, no licenses
```

### Section 7 — Install

````markdown
## Install

```bash
git clone https://github.com/HanSur94/FastSense.git
cd FastSense
```

Then in MATLAB or Octave:

```matlab
install;   % adds paths + compiles MEX accelerators
```

MEX is optional — pure-MATLAB fallbacks kick in if no C compiler is
available. Requires MATLAB R2020b+ or GNU Octave 7+ on Linux, macOS,
or Windows.
````

### Section 8 — Examples & docs

```markdown
## Examples & docs

40+ runnable scripts in [`examples/`](examples/), grouped by topic
(`01-basics` … `07-advanced`). Run them all with `run_all_examples`.

Full reference lives in the [Wiki](https://github.com/HanSur94/FastSense/wiki):
Getting Started · API Reference · Architecture · MEX details · Performance.
```

### Section 9 — Citation · License

````markdown
## Citation · License

```bibtex
@software{fastsense,
  title  = {FastSense: Sensor Monitoring and Dashboarding for MATLAB and GNU Octave},
  url    = {https://github.com/HanSur94/FastSense},
  license= {MIT}
}
```

See [`CITATION.cff`](CITATION.cff) for the full citation metadata.

Released under the [MIT License](LICENSE).
````

No `author` field in the BibTeX. No trailing personal-name attribution. The `CITATION.cff` and `LICENSE` files themselves are unchanged.

## Verification

Before declaring the rewrite complete:

1. **API correctness** — every code block is grep-checked against `libs/` to confirm classes, methods, and keyword arguments still exist with the spelling shown. Spot-check `MonitorTag` constructor and the `'Tag'` widget keyword (already verified during design).
2. **No old API references** — full-file grep for `Sensor(`, `StateChannel`, `addThresholdRule`, `addStateChannel`, `\.resolve\(\)`, `EventConfig`, `runDetection` returns zero hits in the new README body.
3. **No personal name** — full-file grep for the author's surname / first name returns zero hits in the new README. Note that the GitHub Pages URL in the perf footnote (`hansur94.github.io`) and the repo URL (`github.com/HanSur94/FastSense`) contain the GitHub handle — these are kept because they are functional URLs, not attribution lines. If the user wants the handle scrubbed, that is a separate decision affecting URLs and hosting.
4. **No image references** — full-file grep for `docs/images/` and `<img` returns zero hits.
5. **All links resolve** — badges, Wiki links, benchmark charts URL, `examples/` directory, `LICENSE`, `CITATION.cff` all resolve.
6. **Markdown renders cleanly** — preview on GitHub or local Markdown renderer; tables, fenced code, and the `<sub>` HTML render as expected.

## Open Questions / Decisions Deferred

None. All structural and content decisions are locked in.
