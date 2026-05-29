# Phase 1: Infrastructure Hardening - Research

**Researched:** 2026-04-01
**Domain:** MATLAB dashboard engine — timer error handling, widget serialization, jsondecode normalization
**Confidence:** HIGH

## Summary

This is a pure codebase hardening phase with no external dependencies and no new user-visible features. All three problems have been directly inspected in the source code and their root causes are unambiguous.

**INFRA-01 (timer ErrorFcn):** `DashboardEngine.startLive()` creates a MATLAB timer with `TimerFcn` but no `ErrorFcn`. When `onLiveTick()` throws an uncaught error the MATLAB timer framework stops the timer permanently and swallows the error silently. The fix is a one-liner: add `'ErrorFcn', @(timerObj, eventData) obj.onLiveTimerError(timerObj, eventData)` to the timer constructor and implement a private `onLiveTimerError` method that logs the error and restarts the timer. The exact same pattern is already used in `LiveEventPipeline.start()` and in `FastSense.m` / `FastSenseGrid.m`.

**INFRA-02 (GroupWidget .m export):** `DashboardSerializer.save()` (the `.m` function export) has a `case 'group'` branch that only emits the outer `addWidget('group', ...)` call. It never serializes `Children` or `Tabs`. The fix requires generating `addChild()` calls for each child widget, recursively, after the group widget is added. The JSON round-trip path via `toStruct()`/`fromStruct()` already works correctly (evidenced by `TestGroupWidget.testFullDashboardIntegration` which uses `d.save(tmpFile)` — but that currently saves as `.m` via the `save()` method, which is the broken path).

**INFRA-03 (jsondecode normalization):** `GroupWidget.fromStruct()` already implements the struct-array → cell normalization for both `children` and `tabs.widgets`. The requirement is that this same normalization must be applied at future nesting levels (pages array, detached registry) as they are added in later phases. The research finding is: document the normalization pattern and where it must be applied proactively so Phase 4 and Phase 5 do not introduce the bug.

**Primary recommendation:** Three small, surgical changes to existing files — no new files needed. Each change has a clear existing test class to extend.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None — all implementation choices are at Claude's discretion.

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

### Deferred Ideas (OUT OF SCOPE)
None — infrastructure phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFRA-01 | DashboardEngine.LiveTimer has an ErrorFcn that logs errors and keeps the timer running | Add `ErrorFcn` to timer constructor in `startLive()`; implement private `onLiveTimerError` that logs and restarts |
| INFRA-02 | DashboardSerializer .m export correctly serializes GroupWidget children (fix existing bug) | `case 'group'` in `DashboardSerializer.save()` emits only the outer widget; must emit `addChild()` calls for each child recursively |
| INFRA-03 | jsondecode struct-vs-cell normalization applied at all new nesting levels (pages, detached registry) | Document the normalization pattern; no new levels exist yet — guards must be written when pages/detached structures are introduced in Phases 4/5 |
| COMPAT-01 | Existing dashboard scripts run without modification | No API changes; `addWidget()`, `startLive()`, `save()`, `load()` signatures unchanged |
| COMPAT-02 | Previously serialized JSON dashboards load correctly | JSON path unchanged; `loadJSON()` and `fromStruct()` not modified structurally |
| COMPAT-03 | Previously serialized .m dashboards load correctly | Old `.m` exports had no children (bug was silently losing them); after fix, old files still load — they just reconstruct a group with no children (same behavior as before) |
| COMPAT-04 | DashboardBuilder API remains unchanged for single-page dashboards | No changes to `DashboardBuilder.m` in this phase |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MATLAB timer | built-in | Periodic callback execution | Only timer mechanism in toolbox-free MATLAB |
| matlab.unittest.TestCase | built-in | Class-based test suite | Already used for all suite tests in `tests/suite/` |

No new external dependencies. This phase is pure MATLAB, consistent with the project constraint: "Pure MATLAB (no external dependencies)."

### Installation
No installation required — all changes are to existing `.m` source files.

## Architecture Patterns

### Pattern 1: Timer ErrorFcn — Log and Restart
**What:** MATLAB timers stop permanently when their `TimerFcn` throws and no `ErrorFcn` is set. The `ErrorFcn` receives `(timerObj, eventData)` where `eventData.Data.message` contains the error message.

**When to use:** Any timer that must stay alive despite widget or data errors.

**Existing reference implementation (`LiveEventPipeline.m:62`):**
```matlab
obj.timer_ = timer('ExecutionMode', 'fixedSpacing', ...
    'Period', obj.Interval, ...
    'TimerFcn', @(~,~) obj.timerCallback(), ...
    'ErrorFcn', @(~,~) obj.timerError());
```
`timerError` sets a status flag and logs. For `DashboardEngine` the requirement is stronger: the timer must keep running (not just log). The correct approach is to restart the timer inside `ErrorFcn`:

```matlab
% In startLive():
obj.LiveTimer = timer('ExecutionMode', 'fixedRate', ...
    'Period', obj.LiveInterval, ...
    'TimerFcn', @(~,~) obj.onLiveTick(), ...
    'ErrorFcn', @(t, e) obj.onLiveTimerError(t, e));

% New private method:
function onLiveTimerError(obj, ~, eventData)
    msg = '';
    if isstruct(eventData) && isfield(eventData, 'Data') && ...
            isfield(eventData.Data, 'message')
        msg = eventData.Data.message;
    end
    warning('DashboardEngine:timerError', ...
        '[DashboardEngine] Timer error: %s', msg);
    % Restart if timer is still valid and engine is still live
    if obj.IsLive && ~isempty(obj.LiveTimer) && isvalid(obj.LiveTimer)
        try
            start(obj.LiveTimer);
        catch
        end
    end
end
```

**Key detail:** MATLAB `fixedRate` timer stops on error. The `ErrorFcn` fires after stop. Calling `start(obj.LiveTimer)` inside `ErrorFcn` is valid and restarts the timer from that moment.

**Octave note:** GNU Octave 7+ supports `ErrorFcn` on timer objects. Verified by the fact that `LiveEventPipeline` uses it and CI passes on Octave.

### Pattern 2: GroupWidget .m Export — Recursive Child Emission
**What:** The `case 'group'` branch in `DashboardSerializer.save()` must emit code to reconstruct children after the group widget is added. The generated code must call `g.addChild(...)` for each child widget.

**Complication:** `addWidget` in `DashboardEngine` returns the widget handle (already in codebase — `w = d.addWidget(...)`). The generated `.m` code must capture this handle and call `addChild` on it. Looking at `DashboardSerializer.save()`, the fastsense case already assigns to `w`:

```matlab
lines{end+1} = sprintf('    w = d.addWidget(''fastsense'', ''Title'', ''%s'', ...', ws.title);
```

The group case must follow the same pattern. After emitting the `addWidget('group', ...)` call captured in a variable (e.g., `g1`), emit child `addWidget` calls and `g1.addChild(...)` calls.

**Generated code shape for a group with two children:**
```matlab
    g1 = d.addWidget('group', 'Label', 'Motor Health', 'Position', [1 1 24 4], ...
        'Mode', 'panel');
    c1 = NumberWidget('Title', 'RPM', 'Position', [1 1 6 1]);
    g1.addChild(c1);
    c2 = TextWidget('Title', 'Notes', 'Position', [7 1 6 1]);
    g1.addChild(c2);
```

**For tabbed groups:**
```matlab
    g1 = d.addWidget('group', 'Label', 'Analysis', 'Position', [1 1 24 4], ...
        'Mode', 'tabbed');
    c1 = TextWidget('Title', 'Overview', 'Position', [1 1 12 2]);
    g1.addChild(c1, 'Tab1');
```

**Variable naming:** Use `g{i}` for the i-th group widget encountered, `c{i}_{j}` for j-th child of group i. A simpler approach: use a counter and emit `gN` / `cN` style names with a running index to avoid collisions.

**Nesting:** GroupWidget children can themselves be GroupWidgets (up to depth 2). The emission must recurse. The helper that emits a single widget struct as `addWidget` or constructor code can be extracted to a private static method to support recursion cleanly.

### Pattern 3: jsondecode Struct-vs-Cell Normalization
**What:** `jsondecode` in MATLAB converts a JSON array of objects with homogeneous field sets to a MATLAB struct array (not a cell array). Code expecting `{1}` indexing on the result will error. The fix is to check `isstruct(x)` and convert.

**Established pattern in `GroupWidget.fromStruct()` (line 491-497):**
```matlab
if isfield(s, 'children') && ~isempty(s.children)
    ch = s.children;
    if isstruct(ch)
        tmp = ch;
        ch = cell(1, numel(tmp));
        for k = 1:numel(tmp), ch{k} = tmp(k); end
    end
    % ... iterate ch{i}
end
```

The same three-line pattern applies identically at:
- `config.widgets` — already handled in `DashboardSerializer.loadJSON()` (line 155-160)
- `s.children` in `GroupWidget.fromStruct()` — already handled
- `s.tabs` in `GroupWidget.fromStruct()` — already handled
- `ts.widgets` inside tab loop — already handled

**INFRA-03 scope for Phase 1:** No new nesting levels exist yet. The requirement says "applied at all new nesting levels (pages, detached registry)." For Phase 1, the action is: write a shared private static helper `normalizeToCell(x)` in `GroupWidget` (or `DashboardSerializer`) so Phases 4 and 5 can call it without duplicating the normalization logic. This is a refactor to reduce future risk, not a bug fix.

**Proposed helper:**
```matlab
function c = normalizeToCell(x)
%NORMALIZETOCELL Convert struct array from jsondecode to cell array.
    if isempty(x)
        c = {};
    elseif isstruct(x)
        c = cell(1, numel(x));
        for k = 1:numel(x), c{k} = x(k); end
    else
        c = x;  % already a cell array
    end
end
```

This helper can live as a private static method in `DashboardSerializer` (accessible to `GroupWidget.fromStruct` via `DashboardSerializer.normalizeToCell`), or duplicated as a private function in `GroupWidget` — since MATLAB private static methods can be tricky with access from external classes, a standalone private function `normalizeToCell.m` in `libs/Dashboard/private/` is the cleanest approach consistent with project conventions (`private/` directory for private helpers).

### Anti-Patterns to Avoid
- **Silently swallowing timer errors with empty callback `@(~,~) []`:** Used in `FastSense.m` and `FastSenseGrid.m` but not appropriate for `DashboardEngine` where the requirement is logging. The dashboard timer must log and restart.
- **Modifying `TimerFcn` to add a try/catch:** Wrapping `onLiveTick` in try/catch is *not* the solution for INFRA-01. The try/catch inside `onLiveTick` already exists for per-widget `refresh()` errors (lines 585-594). The `ErrorFcn` handles errors that escape `onLiveTick` itself (e.g., errors in the preamble code before the widget loop, or errors in `updateLiveTimeRange`).
- **Generating deeply nested .m code without a recursive helper:** Attempting to handle group export inline in the flat widget loop will produce unmaintainable code. Extract a private static emitWidgetCode method.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Timer restart after error | Custom polling loop / watchdog timer | MATLAB `ErrorFcn` + `start(timer)` | Built-in; same pattern in LiveEventPipeline |
| Struct-array normalization | Custom `cellfun` approach | Simple `isstruct` + loop pattern | Already established in GroupWidget.fromStruct |
| Child variable naming in .m export | Complex dependency-graph variable naming | Simple running counter (g1, g2, c1, c2...) | Sufficient for depth-2 nesting limit |

## Common Pitfalls

### Pitfall 1: ErrorFcn Does Not Auto-Restart the Timer
**What goes wrong:** Developer adds `ErrorFcn` that only logs, but the timer remains stopped. The dashboard silently stops refreshing after the first error.
**Why it happens:** `ErrorFcn` is called after the timer has already stopped. It does not automatically resume execution.
**How to avoid:** Explicitly call `start(obj.LiveTimer)` inside `onLiveTimerError`. Guard with `isvalid(obj.LiveTimer)` to avoid errors if the engine was deleted.
**Warning signs:** After a simulated error in `onLiveTick`, `isrunning(obj.LiveTimer)` returns false.

### Pitfall 2: ErrorFcn Timer Object Identity
**What goes wrong:** The `ErrorFcn` callback uses `obj.LiveTimer` to restart, but `obj.LiveTimer` has been replaced (e.g., by a race with `stopLive()`).
**Why it happens:** The ErrorFcn fires asynchronously; `stopLive()` may have been called between the error and the ErrorFcn execution.
**How to avoid:** Check `obj.IsLive` before restarting — if `IsLive` is false, the timer was intentionally stopped, so do not restart.

### Pitfall 3: Circular Reference in .m Export Variable Names
**What goes wrong:** Two group widgets both emit a variable named `g1`, causing the second to overwrite the first.
**Why it happens:** Naive implementation resets the counter per-widget instead of per-export call.
**How to avoid:** Maintain a single running counter across the entire export loop. Pass it as a return value or use a persistent local counter variable in the recursive helper.

### Pitfall 4: .m Export of Children Creates Standalone Widgets Not Added to Engine
**What goes wrong:** Children are emitted as `d.addWidget(...)` calls, causing them to appear as top-level dashboard widgets instead of GroupWidget children.
**Why it happens:** Confusion between children (owned by GroupWidget) and top-level widgets (owned by DashboardEngine).
**How to avoid:** Children of a GroupWidget are created with their constructor directly (e.g., `NumberWidget(...)`) and passed to `g1.addChild(...)`. They are NOT added via `d.addWidget(...)`.

### Pitfall 5: normalizeToCell Applied Only to Top Level
**What goes wrong:** `s.tabs` is normalized but `ts.widgets` inside each tab is not, causing indexing errors on the second level.
**Why it happens:** Developer normalizes the outer array but forgets the nested array.
**How to avoid:** Apply normalization at every level where jsondecode may produce a struct array. The existing `GroupWidget.fromStruct` already does this correctly — use it as the reference.

### Pitfall 6: GroupWidget .m Export Missing Tab Name Argument
**What goes wrong:** Children of tabbed GroupWidgets are exported as `g1.addChild(c1)` without the tab name argument, causing all children to land in `Children` instead of `Tabs`.
**Why it happens:** Panel/collapsible mode and tabbed mode use different `addChild` signatures (`addChild(widget)` vs `addChild(widget, tabName)`).
**How to avoid:** Check `ws.mode` before emitting child code. For `'tabbed'` mode, read `ws.tabs` and emit per-tab groups with the tab name argument.

## Code Examples

### INFRA-01: startLive with ErrorFcn
```matlab
% In DashboardEngine.startLive():
function startLive(obj)
    if obj.IsLive
        return;
    end
    obj.IsLive = true;
    obj.LiveTimer = timer('ExecutionMode', 'fixedRate', ...
        'Period', obj.LiveInterval, ...
        'TimerFcn', @(~,~) obj.onLiveTick(), ...
        'ErrorFcn', @(t, e) obj.onLiveTimerError(t, e));
    start(obj.LiveTimer);
end

% New private method in DashboardEngine:
function onLiveTimerError(obj, ~, eventData)
    msg = '';
    if isstruct(eventData) && isfield(eventData, 'Data') && ...
            isfield(eventData.Data, 'message')
        msg = eventData.Data.message;
    end
    warning('DashboardEngine:timerError', ...
        '[DashboardEngine] Live timer error: %s', msg);
    if obj.IsLive && ~isempty(obj.LiveTimer) && isvalid(obj.LiveTimer)
        try
            start(obj.LiveTimer);
        catch restartErr
            warning('DashboardEngine:timerRestartFailed', ...
                '[DashboardEngine] Timer restart failed: %s', restartErr.message);
        end
    end
end
```

### INFRA-02: GroupWidget .m export (panel/collapsible mode)
```matlab
% In DashboardSerializer.save(), replace the 'group' case with:
case 'group'
    groupVarName = sprintf('g%d', groupCount);
    groupCount = groupCount + 1;
    line = sprintf('    %s = d.addWidget(''group'', ''Label'', ''%s'', ''Position'', %s', ...
        groupVarName, ws.label, pos);
    if isfield(ws, 'mode') && ~isempty(ws.mode)
        line = [line, sprintf(', ...\n        ''Mode'', ''%s''', ws.mode)];
    end
    lines{end+1} = [line, ');'];
    % Emit children
    if strcmp(ws.mode, 'tabbed') && isfield(ws, 'tabs')
        for ti = 1:numel(ws.tabs)
            tab = ws.tabs{ti};
            for ci = 1:numel(tab.widgets)
                cw = tab.widgets{ci};
                [childLines, childVar, groupCount] = ...
                    DashboardSerializer.emitChildWidget(cw, groupCount);
                lines = [lines, childLines];
                lines{end+1} = sprintf('    %s.addChild(%s, ''%s'');', ...
                    groupVarName, childVar, tab.name);
            end
        end
    elseif isfield(ws, 'children')
        for ci = 1:numel(ws.children)
            cw = ws.children{ci};
            [childLines, childVar, groupCount] = ...
                DashboardSerializer.emitChildWidget(cw, groupCount);
            lines = [lines, childLines];
            lines{end+1} = sprintf('    %s.addChild(%s);', groupVarName, childVar);
        end
    end
```

### INFRA-03: normalizeToCell private helper
```matlab
% libs/Dashboard/private/normalizeToCell.m
function c = normalizeToCell(x)
%NORMALIZETOCELL Normalize jsondecode output to cell array.
%   jsondecode converts homogeneous JSON arrays of objects to struct arrays.
%   This helper converts struct arrays back to cell arrays for consistent
%   {i} indexing.
    if isempty(x)
        c = {};
    elseif isstruct(x)
        c = cell(1, numel(x));
        for k = 1:numel(x)
            c{k} = x(k);
        end
    else
        c = x;
    end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No ErrorFcn (timer stops silently) | ErrorFcn logs + restarts | This phase | Dashboard refresh survives transient errors |
| GroupWidget children lost on .m export | Children serialized as addChild calls | This phase | .m round-trip fidelity for GroupWidget |
| Inline struct-array normalization | Shared normalizeToCell helper | This phase | Future phases (4, 5) can reuse without duplication |

## Open Questions

1. **How does the MATLAB timer ErrorFcn interact with Octave's timer?**
   - What we know: `LiveEventPipeline` uses `ErrorFcn` in production and passes CI on Octave 7+. The CI configuration runs tests on Octave via `tests/run_all_tests.m`.
   - What's unclear: Whether Octave fires `ErrorFcn` with the same `eventData` struct shape as MATLAB.
   - Recommendation: Guard `eventData.Data.message` access with `isstruct(eventData)` check (already shown in the code example above). If `eventData` is empty or differently shaped on Octave, the message defaults to empty string and the restart logic still executes.

2. **Should emitChildWidget support all 15+ widget types or just the types GroupWidget can contain?**
   - What we know: GroupWidget children are any `DashboardWidget` subclass. In practice, the most common children are `FastSenseWidget`, `NumberWidget`, `StatusWidget`, `TextWidget`, `GaugeWidget`, and nested `GroupWidget`.
   - What's unclear: Whether to handle all widget types or emit a generic constructor call for unknown types.
   - Recommendation: Implement handlers for the 6 common types and a generic fallback that emits `WidgetType('Title', ...)` constructor syntax for unknown types. This avoids an exhaustive 15-branch implementation while covering real use cases.

## Environment Availability

Step 2.6: SKIPPED — this phase is purely code/config changes to existing MATLAB source files. No external tools, services, or CLIs beyond MATLAB/Octave (already present) are needed.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | matlab.unittest.TestCase (built-in) |
| Config file | none — discovered via `TestSuite.fromFolder(tests/suite/)` |
| Quick run command | `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('.'); install(); import matlab.unittest.*; r = TestSuite.fromFolder('tests/suite/'); run(r);"` |
| Full suite command | `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('.'); install(); run_all_tests();"` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFRA-01 | Timer continues running after TimerFcn error | unit | `matlab -batch "... TestDashboardEngine"` | Partially — `testLiveStartStop` exists; new test method needed |
| INFRA-02 | GroupWidget .m export round-trip preserves children | unit | `matlab -batch "... TestDashboardMSerializer"` | Partially — `testSaveProducesMFile` exists; new group round-trip test needed |
| INFRA-02 | GroupWidget .m export preserves tabbed children | unit | `matlab -batch "... TestGroupWidget"` | Partially — `testRoundTripPanel` exists; tabbed .m export test needed |
| INFRA-03 | normalizeToCell handles struct array, cell array, empty | unit | `matlab -batch "... TestDashboardSerializer"` | New test method needed in TestDashboardSerializer |
| COMPAT-01 | DashboardEngine addWidget/startLive API unchanged | unit | `matlab -batch "... TestDashboardEngine"` | Yes — existing `testAddWidget`, `testLiveStartStop` |
| COMPAT-02 | JSON dashboards load correctly | unit | `matlab -batch "... TestDashboardSerializerRoundTrip"` | Yes — `testAllWidgetTypesRoundTrip` |
| COMPAT-03 | .m dashboards without children load correctly | unit | `matlab -batch "... TestDashboardMSerializer"` | Yes — `testLoadFromMFile` (no-children case) |
| COMPAT-04 | DashboardBuilder API unchanged | unit | `matlab -batch "... TestDashboardBuilder"` | Yes — existing suite |

### Sampling Rate
- **Per task commit:** Run targeted test class (`TestDashboardEngine`, `TestGroupWidget`, or `TestDashboardMSerializer` depending on which file was changed)
- **Per wave merge:** Full suite `run_all_tests()`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/suite/TestDashboardEngine.m` — add `testTimerContinuesAfterError` method (covers INFRA-01)
- [ ] `tests/suite/TestDashboardMSerializer.m` — add `testGroupWithChildrenRoundTrip` and `testGroupTabbedRoundTrip` methods (covers INFRA-02)
- [ ] `tests/suite/TestDashboardSerializer.m` — add `testNormalizeToCellHelper` method (covers INFRA-03)

No new test files are needed — all gaps are new test methods in existing test classes.

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `libs/Dashboard/DashboardEngine.m` — `startLive()` and `onLiveTick()` methods
- Direct code inspection: `libs/Dashboard/DashboardSerializer.m` — `save()` method `case 'group'` branch
- Direct code inspection: `libs/Dashboard/GroupWidget.m` — `fromStruct()` normalization pattern
- Direct code inspection: `libs/EventDetection/LiveEventPipeline.m` — reference `ErrorFcn` implementation
- Direct code inspection: `tests/suite/TestGroupWidget.m`, `TestDashboardMSerializer.m`, `TestDashboardEngine.m`

### Secondary (MEDIUM confidence)
- MATLAB documentation (training knowledge): `timer` object `ErrorFcn` property behavior — fires after timer stops on error, `start()` can be called from within `ErrorFcn` to restart

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure MATLAB, no external deps, stack confirmed from codebase inspection
- Architecture: HIGH — root causes directly observed in source code, not inferred
- Pitfalls: HIGH — derived from code structure and MATLAB timer semantics
- Test gaps: HIGH — existing test files inspected, missing methods identified precisely

**Research date:** 2026-04-01
**Valid until:** Stable indefinitely — pure MATLAB, no version-sensitive libraries
