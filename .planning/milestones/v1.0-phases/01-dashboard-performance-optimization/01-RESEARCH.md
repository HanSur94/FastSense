# Phase 01: Dashboard Performance Optimization - Research

**Researched:** 2026-04-03
**Domain:** MATLAB Dashboard Engine performance — widget lifecycle, theme caching, render pipeline
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Profiling & Measurement Strategy**
- Use `tic/toc` wall-clock benchmarks on dashboard creation, render, and refresh cycles
- Benchmark scenario: 20-widget mixed dashboard (FastSense, Number, Status, Group widgets)
- Add `benchmarks/bench_dashboard.m` as a reusable performance tracking script
- Target: 2x faster creation+render, <50ms per live tick refresh

**Creation & Instantiation Optimizations**
- Replace 17-case switch in `addWidget` with `containers.Map` type→constructor lookup, built once at construction
- Cache `DashboardTheme()` struct on engine instance, invalidate only when `Theme` property changes — currently reconstructed on every `switchPage`, `rerenderWidgets`, `render`
- Keep eager `DashboardLayout` creation (current behavior) — layout object is lightweight
- Profile widget constructors first, optimize only if they show up as bottleneck

**Render & Interactivity Optimizations**
- Optimize `rerenderWidgets` to reposition existing panels instead of destroy+recreate — only recreate when widget list actually changes
- Optimize `onLiveTick`: cache `activePageWidgets()` result, skip non-dirty widgets early, consolidate to single pass instead of multiple loops
- Verify `realizeBatch` visibility-first ordering works correctly, tune batch size from profiling
- `switchPage` should hide/show panels instead of full rerender — keep panels alive across page switches

### Claude's Discretion
- Widget constructor optimization approach (if profiling reveals bottleneck)
- Exact batch size tuning for `realizeBatch`
- Any additional micro-optimizations discovered during profiling

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

## Summary

This phase optimizes the MATLAB Dashboard Engine (`DashboardEngine.m`) through four independent, well-scoped improvements: theme caching, `addWidget` dispatch table, `onLiveTick` consolidation, and `switchPage`/`rerenderWidgets` panel reuse. All optimization targets are directly identifiable in the codebase — no speculative work required.

The code is already well-structured with clean lifecycle flags (`Dirty`, `Realized`, `markRealized`/`markUnrealized`), so the optimizations are incremental refinements rather than architecture changes. The existing `TestDashboardPerformance` suite provides a test foundation. A new `benchmarks/bench_dashboard.m` script will establish quantitative baselines.

**Primary recommendation:** Implement optimizations in order of impact — theme cache first (highest call frequency), then `onLiveTick` consolidation (every live tick), then `addWidget` dispatch (construction time), then panel reuse in `switchPage`/`rerenderWidgets` (interaction path).

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MATLAB `containers.Map` | R2009a+ | O(1) string→function dispatch | Built-in handle class, no allocation overhead per call |
| MATLAB `tic/toc` | All versions | Wall-clock benchmarking | Standard MATLAB profiling tool, Octave-compatible |
| MATLAB `profile` (optional) | R2006a+ | Line-level profiling | Built-in, identifies hotspots not visible to tic/toc |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Octave `tic/toc` | Octave 7+ | Same API as MATLAB | CI uses Octave — benchmarks must run on both |
| `drawnow` | All versions | Force graphics flush | Use sparingly in realizeBatch; each call is expensive |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `containers.Map` dispatch | `feval(typeMap(type), varargin{:})` | Same O(1) — either works; Map→constructor function handle is cleaner |
| Wall-clock `tic/toc` | `profile on/off` | Profile gives line-level detail but 10-30x overhead; tic/toc is production-safe |

**Installation:** No external dependencies. All tools are built into MATLAB/Octave.

## Architecture Patterns

### Recommended Project Structure

No new files added to `libs/Dashboard/`. Modifications are in-place:
```
libs/Dashboard/
├── DashboardEngine.m        # Primary target — 4 optimization sites
benchmarks/
├── bench_dashboard.m        # NEW — 20-widget mixed dashboard benchmark
tests/suite/
├── TestDashboardPerformance.m  # EXTEND — add theme cache + dispatch tests
```

### Pattern 1: Theme Struct Caching with Property-Change Invalidation

**What:** Store the `DashboardTheme()` result in a private property (`ThemeCache_`). Recompute only when the public `Theme` property is assigned.

**When to use:** Wherever `DashboardTheme(obj.Theme)` currently appears — `render()`, `rerenderWidgets()`, `switchPage()`, `detachWidget()`, and `DashboardLayout.createPanels` callers.

**Current call sites in `DashboardEngine.m` (verified by grep):**
- Line 98: `switchPage()` → `DashboardTheme(obj.Theme)` for button colors
- Line 213: `render()` → `DashboardTheme(obj.Theme)` for figure setup
- Line 602: `detachWidget()` → `DashboardTheme(obj.Theme)` for mirror
- Line 639: `rerenderWidgets()` → `DashboardTheme(obj.Theme)` passed to `createPanels`

**Example:**
```matlab
% In DashboardEngine properties (Access = private):
ThemeCache_ = []   % Cached DashboardTheme struct; invalidated on Theme change

% New private helper:
function t = getCachedTheme(obj)
    if isempty(obj.ThemeCache_)
        obj.ThemeCache_ = DashboardTheme(obj.Theme);
    end
    t = obj.ThemeCache_;
end

% Theme property setter (requires property setter pattern):
% Or: invalidate cache in any method that modifies obj.Theme
% Simplest approach — check in getCachedTheme() via string comparison:
function t = getCachedTheme(obj)
    if isempty(obj.ThemeCache_) || ~strcmp(obj.ThemeCache_.preset_, obj.Theme)
        obj.ThemeCache_ = DashboardTheme(obj.Theme);
        obj.ThemeCache_.preset_ = obj.Theme;  % tag for invalidation check
    end
    t = obj.ThemeCache_;
end
```

**Note on invalidation:** `DashboardTheme` returns a plain struct (not a handle class). MATLAB structs are copied on assignment, so the cache is always a safe snapshot. Invalidating by comparing the preset string is O(1) and correct.

### Pattern 2: containers.Map Widget Dispatch Table

**What:** Replace the 17-case switch statement in `addWidget` with a `containers.Map` of type→constructor function handles, built once in `DashboardEngine` constructor.

**When to use:** Replaces the switch at lines 124–169 of `DashboardEngine.m`.

**Current state (verified):**
- 17 explicit cases: `fastsense`, `number`, `kpi` (deprecated), `status`, `text`, `gauge`, `table`, `rawaxes`, `timeline`, `group`, `heatmap`, `barchart`, `histogram`, `scatter`, `image`, `multistatus`, `divider`
- Sequential evaluation — worst case is 17 comparisons for `'divider'`

**Example:**
```matlab
% In DashboardEngine constructor, after obj.Layout = DashboardLayout():
obj.WidgetTypeMap_ = containers.Map({ ...
    'fastsense',    'number',      'status',       'text', ...
    'gauge',        'table',       'rawaxes',      'timeline', ...
    'group',        'heatmap',     'barchart',     'histogram', ...
    'scatter',      'image',       'multistatus',  'divider'}, ...
    {@FastSenseWidget, @NumberWidget, @StatusWidget, @TextWidget, ...
     @GaugeWidget, @TableWidget, @RawAxesWidget, @EventTimelineWidget, ...
     @GroupWidget, @HeatmapWidget, @BarChartWidget, @HistogramWidget, ...
     @ScatterWidget, @ImageWidget, @MultiStatusWidget, @DividerWidget});

% In addWidget(), replace switch with:
if isKey(obj.WidgetTypeMap_, type)
    ctor = obj.WidgetTypeMap_(type);
    w = ctor(varargin{:});
else
    error('DashboardEngine:unknownType', 'Unknown widget type: %s', type);
end
```

**Note:** The `kpi` deprecated warning case must remain as a special pre-check before the map lookup (translate `'kpi'` → `'number'` with warning).

### Pattern 3: onLiveTick Single-Pass Consolidation

**What:** Fetch `activePageWidgets()` once at the top of `onLiveTick` and reuse the result across all loops. Merge the mark-dirty loop and the refresh loop into a single pass.

**Current state (verified from lines 752–816):**
- `updateLiveTimeRange()` (line 758) calls `activePageWidgets()` internally — that's 1 internal call
- Line 763: `ws = obj.activePageWidgets()` — explicit fetch
- Lines 763–768: Loop 1 — mark sensor-bound widgets dirty
- Lines 771–786: Loop 2 — refresh dirty/realized/visible widgets
- Lines 813–815: Loop 3 — clear dirty flags

**Consolidated structure:**
```matlab
function onLiveTick(obj)
    if isempty(obj.hFigure) || ~ishandle(obj.hFigure), return; end

    ws = obj.activePageWidgets();  % fetch once

    % Pass time range update the widget list directly (avoid re-fetch inside)
    obj.updateLiveTimeRangeFrom(ws);  % refactored overload that accepts ws

    % Single pass: mark dirty, refresh if dirty+realized+visible, collect stale
    for i = 1:numel(ws)
        w = ws{i};
        if ~isempty(w.Sensor)
            w.markDirty();
        end
        if w.Dirty && w.Realized && obj.Layout.isWidgetVisible(w.Position)
            try
                if isa(w, 'FastSenseWidget')
                    w.update();
                else
                    w.refresh();
                end
            catch ME
                warning('DashboardEngine:refreshError', ...
                    'Widget "%s" refresh failed: %s', w.Title, ME.message);
            end
        end
    end

    % ... detached mirrors loop unchanged ...

    % Clear dirty flags
    for i = 1:numel(ws)
        ws{i}.Dirty = false;
    end
end
```

**Alternative approach:** Keep separate loops but pass `ws` to avoid re-fetching. Either achieves the stated goal; single-pass is cleaner but requires verifying sensor-bind + refresh ordering is safe (it is — marking dirty then checking dirty in same iteration works correctly since we mark then check in order).

### Pattern 4: Panel Reuse in rerenderWidgets and switchPage

**What:** Instead of destroying all panels on every resize or page switch, reposition existing panels in-place when only the layout changes (not the widget list).

**Current state (verified, lines 637–651):**
```matlab
function rerenderWidgets(obj)
    theme = DashboardTheme(obj.Theme);
    ws = obj.activePageWidgets();
    for i = 1:numel(ws)
        w = ws{i};
        w.markUnrealized();
        if ~isempty(w.hPanel) && ishandle(w.hPanel)
            delete(w.hPanel);  % <-- destroys panel and all children
        end
    end
    obj.Layout.createPanels(obj.hFigure, ws, theme);
    obj.Layout.DetachCallback = @(w) obj.detachWidget(w);
end
```

**Optimization approach:** Add a private `repositionPanels(ws, theme)` method that only calls `set(w.hPanel, 'Position', newPos)` when panels are alive. Call this from resize handler. Only fall back to full destroy+recreate when the widget list actually changes.

**For `switchPage`:** Keep all page panels allocated but set `Visible` to `'off'` for inactive-page panels and `'on'` for active-page panels, instead of calling `rerenderWidgets()`. This is the highest-impact change since switching pages currently triggers full destroy+recreate.

**Key constraint:** `DashboardLayout.allocatePanels` creates the viewport/canvas structure. Panel reuse must work within the existing canvas panel, and panels are children of `obj.Layout.hCanvas`, not `obj.hFigure` directly. The reposition path must preserve the canvas hierarchy.

### Anti-Patterns to Avoid

- **Calling `drawnow` too frequently:** Each `drawnow` is expensive (forces a graphics flush). The current `realizeBatch` pattern of calling `drawnow` once per batch is correct. Do not add `drawnow` in `onLiveTick`.
- **Using `containers.Map` with dynamic string keys in hot loops:** `isKey` on `containers.Map` is fast for static keys but adds overhead compared to direct struct field access. The dispatch map is for construction time (not per-tick), so this is acceptable.
- **Rebuilding the dispatch map on every addWidget call:** The map must be built once in the constructor and reused. Building it per call would be slower than the switch.
- **Merging `markUnrealized` + `repositionPanels` incorrectly:** When repositioning in-place, panels must NOT be marked unrealized unless the widget content needs to be re-rendered. Resizing changes panel position, not widget state.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| String dispatch table | Custom hash map or strcmp chain | `containers.Map` with function handles | Built-in, O(1), handle class (safe to store in properties) |
| Struct caching with invalidation | External cache manager | Simple private property + comparison in getter | MATLAB structs are value-copied; no reference aliasing risk |
| Panel visibility management | Custom show/hide tracker | MATLAB `set(h, 'Visible', 'off/on')` | Built-in uipanel visibility; panels retain children when hidden |
| Batch rendering progress | Custom progress tracker | Existing `realizeBatch` with `drawnow` | Already implemented with visibility-first ordering |

**Key insight:** MATLAB's built-in graphics handles already support in-place repositioning via `set(hPanel, 'Position', newPos)` — no destruction required. The current destroy+recreate pattern is an unnecessary conservatism.

## Common Pitfalls

### Pitfall 1: Octave `containers.Map` Compatibility

**What goes wrong:** `containers.Map` with function handles as values may behave differently in Octave 7+ vs MATLAB. Specifically, calling `ctor(varargin{:})` where `ctor` is a function handle retrieved from a Map may fail with unexpected argument errors in edge cases.

**Why it happens:** Octave's `containers.Map` implementation is compatible but the behavior of `feval`-like calls with cell-unpacked varargin can differ.

**How to avoid:** Test the dispatch map with a 0-argument construction call (`ctor()`) and a non-empty varargin call during `TestDashboardPerformance`. The existing CI runs Octave 9.2.0 (Windows) and Octave 7+ (Linux).

**Warning signs:** Test failures only on Octave CI but not MATLAB.

### Pitfall 2: Theme Cache Stale After Theme Property Assignment

**What goes wrong:** If the `Theme` property is assigned after construction (e.g., `d.Theme = 'dark'`), the cache must be invalidated. Without invalidation, the cached light theme is used for a dark dashboard.

**Why it happens:** MATLAB doesn't support automatic property set observers in value classes. `DashboardEngine` uses a simple public property with no setter hook.

**How to avoid:** The invalidation strategy using `ThemeCache_.preset_` string comparison in `getCachedTheme()` handles this automatically — the preset tag won't match the new `Theme` value. This is the recommended approach since it requires no property setter change and is Octave-compatible.

**Warning signs:** Wrong theme colors appear after `d.Theme = 'dark'; d.render()`.

### Pitfall 3: rerenderWidgets Called from Both Resize and switchPage

**What goes wrong:** If `rerenderWidgets` is refactored to reuse panels, but `switchPage` still calls the full destroy+recreate path, the panel reuse benefit is lost for the most interactive case.

**Why it happens:** `rerenderWidgets` serves dual purpose: resize (layout change, same widgets) and page switch (different widget set). These need different strategies.

**How to avoid:** Split into two methods:
- `repositionPanels(ws, theme)` — in-place reposition for resize
- `switchPagePanels(oldPage, newPage)` — hide/show for page navigation
Keep `rerenderWidgets` as the full rebuild path for widget-list changes (addWidget, removeWidget).

**Warning signs:** After page switch, old page widgets are still visible (show/hide bug) or new page widgets overlap (position bug).

### Pitfall 4: Panel Hierarchy — Panels Are Children of hCanvas, Not hFigure

**What goes wrong:** When repositioning panels in-place, code that assumes panels are children of `hFigure` will fail because panels are actually children of `obj.Layout.hCanvas` (a uipanel inside `obj.Layout.hViewport`).

**Why it happens:** `DashboardLayout.allocatePanels` creates a viewport+canvas hierarchy for scroll support. Widget panels are created with `'Parent', obj.hCanvas`.

**How to avoid:** Any panel repositioning must use `set(w.hPanel, 'Position', newPos)` directly — this works regardless of parent. Do not attempt to reparent panels during reposition.

**Warning signs:** Panels disappear after resize, or layout errors about invalid parent.

### Pitfall 5: `onLiveTick` Ordering — Dirty Flag Must Clear AFTER Refresh

**What goes wrong:** If dirty flags are cleared before the refresh loop (or mid-loop), widgets that need refresh will be skipped in the same tick.

**Why it happens:** In the single-pass consolidation, marking dirty and checking dirty happen in the same loop iteration. The order matters: mark dirty → check dirty → refresh → (clear at end).

**How to avoid:** Keep the clear-dirty loop as a separate final pass after all refreshes. Do not inline the `Dirty = false` assignment into the refresh block (that would clear the flag before the time slider broadcast at line 808 re-broadcasts, potentially skipping widgets).

**Warning signs:** Widgets stop refreshing after the first tick, or refresh only every other tick.

## Code Examples

Verified patterns from the existing codebase:

### DashboardTheme — Current Function Signature
```matlab
% Source: libs/Dashboard/DashboardTheme.m lines 1-42
function theme = DashboardTheme(preset, varargin)
% Returns a plain struct (value class, safe to cache)
% Called at: DashboardEngine.m lines 98, 213, 602, 639
```

### containers.Map with Function Handles (MATLAB/Octave pattern)
```matlab
% Pattern: build once, look up by string key
m = containers.Map({'a', 'b'}, {@ClassA, @ClassB});
ctor = m('a');
obj = ctor('Title', 'T1');  % equivalent to ClassA('Title', 'T1')
```

### Panel In-Place Repositioning
```matlab
% MATLAB built-in: repositions panel without destroying children
set(hPanel, 'Position', [x y w h]);  % normalized coords
% Equivalent to creating a new panel at that position, but faster
```

### Visibility Toggle for Page Switching
```matlab
% Hide page 1 panels, show page 2 panels
for i = 1:numel(page1Widgets)
    set(page1Widgets{i}.hPanel, 'Visible', 'off');
end
for i = 1:numel(page2Widgets)
    set(page2Widgets{i}.hPanel, 'Visible', 'on');
end
```

### Benchmark Script Structure (matches existing benchmarks/ style)
```matlab
% Source: benchmarks/benchmark.m — pattern to follow
addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
install();

fprintf('=== Dashboard Performance Benchmark ===\n');
% Baseline measurement
t_create = tic;
d = DashboardEngine('BenchDash');
% ... add 20 mixed widgets ...
t_create_elapsed = toc(t_create);

t_render = tic;
d.render();
drawnow;
t_render_elapsed = toc(t_render);

fprintf('Create: %.3f s  Render: %.3f s  Total: %.3f s\n', ...
    t_create_elapsed, t_render_elapsed, ...
    t_create_elapsed + t_render_elapsed);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 17-case switch | containers.Map dispatch | This phase | O(1) vs O(N) lookup; cleaner extensibility |
| DashboardTheme() per call | Cached struct | This phase | Eliminates 4+ redundant struct constructions per render/switch |
| Destroy+recreate on resize | Reposition in-place | This phase | Avoids widget re-render on every window resize |
| Full rerenderWidgets on page switch | Hide/show panels | This phase | O(1) visibility toggle vs O(N) destroy+create |
| 3-loop onLiveTick | Single-pass + cached ws | This phase | 3x fewer `activePageWidgets()` calls per tick |

**Deprecated/outdated:**
- `rerenderWidgets` as the path for page switching: will be replaced by panel visibility toggle (but kept for widget-list changes)

## Open Questions

1. **Should `updateLiveTimeRange` accept a pre-fetched widget list?**
   - What we know: It currently calls `activePageWidgets()` internally (line 680), adding an extra fetch inside `onLiveTick`
   - What's unclear: Refactoring to accept `ws` argument requires changing the function signature, which may affect any callers outside `onLiveTick`
   - Recommendation: Add an overload `updateLiveTimeRangeFrom(ws)` that accepts the list; keep the zero-argument version for external callers. This avoids breaking the public interface.

2. **Panel reuse across page switches: how to handle panels from different pages sharing the same canvas?**
   - What we know: `allocatePanels` creates a fresh canvas each time; widget panels are children of `hCanvas`
   - What's unclear: If each page has its own set of panels under one canvas, hiding/showing requires tracking which panels belong to which page
   - Recommendation: At `render()` time, allocate panels for all pages (not just the active page). Store page-to-panels association. `switchPage` toggles visibility. This is a larger change — scope carefully in the plan.

3. **Batch size for `realizeBatch`: is 5 optimal?**
   - What we know: Current default is 5 (line 717); CONTEXT.md says "tune from profiling"
   - What's unclear: Optimal batch size depends on widget complexity and hardware
   - Recommendation: Start at 5, expose as a tunable constant. Benchmark script should test sizes [3, 5, 8, 10] and report results.

## Environment Availability

Step 2.6: SKIPPED — this phase is purely code/logic changes within MATLAB. No external tools, services, or CLIs beyond the project's own MATLAB codebase are required.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | MATLAB `matlab.unittest.TestCase` (class-based suite) |
| Config file | `tests/run_all_tests.m` |
| Quick run command | `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); run(TestSuite.fromClass('TestDashboardPerformance'))"` |
| Full suite command | `cd /Users/hannessuhr/FastPlot && matlab -batch "run_all_tests"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERF-01 | Theme cache returns same struct for same preset | unit | `TestDashboardPerformance.testThemeCacheReturnsSameStruct` | ❌ Wave 0 |
| PERF-02 | Theme cache invalidates on Theme property change | unit | `TestDashboardPerformance.testThemeCacheInvalidatesOnChange` | ❌ Wave 0 |
| PERF-03 | addWidget dispatch map covers all 17+ types | unit | `TestDashboardPerformance.testDispatchMapCoversAllTypes` | ❌ Wave 0 |
| PERF-04 | onLiveTick completes in <50ms for 20-widget dashboard | smoke | `TestDashboardPerformance.testLiveTickUnder50ms` | ❌ Wave 0 |
| PERF-05 | rerenderWidgets repositions panels without destroying them | unit | `TestDashboardPerformance.testRerenderWidgetsRepositions` | ❌ Wave 0 |
| PERF-06 | switchPage hides/shows panels instead of full rerender | unit | `TestDashboardPerformance.testSwitchPageTogglesVisibility` | ❌ Wave 0 |
| PERF-07 | benchmarks/bench_dashboard.m runs without error | smoke | manual run | ❌ Wave 0 |
| EXISTING | onLiveTick only refreshes dirty widgets | unit | existing `testLiveTickOnlyRefreshesDirtyWidgets` | ✅ |
| EXISTING | Widgets realized after render | unit | existing `testWidgetsRealizedAfterRender` | ✅ |

### Sampling Rate
- **Per task commit:** `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); run(TestSuite.fromClass('TestDashboardPerformance'))"`
- **Per wave merge:** Full test suite via `run_all_tests`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/suite/TestDashboardPerformance.m` — extend with PERF-01 through PERF-06 test methods
- [ ] `benchmarks/bench_dashboard.m` — new benchmark script (PERF-07)

*(Existing `TestDashboardPerformance.m` has 4 tests; 6 new methods must be added for this phase)*

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `libs/Dashboard/DashboardEngine.m` — all 4 optimization sites verified by line numbers
- Direct code inspection: `libs/Dashboard/DashboardLayout.m` — panel creation hierarchy (`hViewport → hCanvas → widget panels`)
- Direct code inspection: `libs/Dashboard/DashboardTheme.m` — confirmed plain struct return (safe to cache)
- Direct code inspection: `tests/suite/TestDashboardPerformance.m` — confirmed existing 4 tests, wave 0 gaps identified

### Secondary (MEDIUM confidence)
- MATLAB documentation pattern: `containers.Map` with function handle values — standard MATLAB dispatch table pattern, well-established
- MATLAB graphics: `set(hPanel, 'Position', ...)` for in-place repositioning — documented MATLAB graphics behavior

### Tertiary (LOW confidence)
- None — all findings are from direct code inspection of the target repository

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no external dependencies, all built-in MATLAB
- Architecture: HIGH — all patterns verified from existing code, no speculation
- Pitfalls: HIGH — all pitfalls derived from direct code analysis (panel hierarchy, dirty flag ordering)

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (stable codebase, no fast-moving dependencies)
