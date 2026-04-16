# Phase 1003: Composite Thresholds - Research

**Researched:** 2026-04-06
**Domain:** MATLAB Threshold system extension — CompositeThreshold class and widget integration
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** CompositeThreshold inherits from Threshold — usable anywhere a Threshold is accepted (widgets, sensors, registry)
- **D-02:** Default aggregation logic is AND (all children must be ok). Configurable via `AggregateMode` property: 'and', 'or', 'majority'
- **D-03:** Composites can nest — tree structure where children can be Threshold or CompositeThreshold objects
- **D-04:** `computeStatus(values)` method evaluates each child's current value against its limits, returns aggregate ok/warning/alarm
- **D-05:** `addChild(thresholdOrKey)` method — accepts Threshold objects or registry key strings (same dual-input as Sensor.addThreshold)
- **D-06:** Each child carries its own current value via ValueFcn or static value (from Phase 1002 widget pattern). Composite evaluates all children's values.
- **D-07:** Same Threshold can be a child of multiple composites — handle class shared references
- **D-08:** MultiStatusWidget auto-expands CompositeThresholds — shows each child as a status dot in the grid plus a summary row for the composite
- **D-09:** CompositeThreshold registered in ThresholdRegistry like any Threshold (same registry, same API)

### Claude's Discretion
- Internal representation of child list (cell array, containers.Map, etc.)
- How computeStatus traverses the tree for nested composites
- removeChild API (if needed)
- StatusWidget/GaugeWidget behavior when bound to a CompositeThreshold
- Serialization format for composite structure in JSON

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

## Summary

Phase 1003 introduces `CompositeThreshold`, a subclass of `Threshold` that aggregates child
`Threshold` or `CompositeThreshold` objects into a single hierarchical status. The parent is "ok"
only when its configured aggregation rule (`AggregateMode`: 'and', 'or', or 'majority') over all
children's current status is satisfied. Children supply their own current values via `ValueFcn` or
a static `Value` field — the same per-child value pattern established in Phase 1002.

Because `CompositeThreshold < Threshold`, every Phase 1002 widget that already accepts a
`Threshold` in its `Threshold` property automatically accepts a composite — the existing
`deriveStatusFromThreshold` path in `StatusWidget` and the parallel helpers in other widgets can
call `computeStatus()` directly instead of `allValues()`. The `ThresholdRegistry` requires no
changes because it already stores any subclass of `Threshold` by key.

`MultiStatusWidget` needs targeted expansion logic: when one of its `Sensors` items is (or
wraps) a `CompositeThreshold`, `refresh()` should inline the children as individual dots in the
grid, plus optionally a summary row for the composite itself.

**Primary recommendation:** Build `CompositeThreshold` in `libs/SensorThreshold/` using a cell
array for children, recursive `computeStatus()` traversal, and a straightforward `toStruct()`
/ `fromStruct()` with a `children` array. Wire `MultiStatusWidget` expansion separately so the
composite class remains widget-agnostic.

---

## Project Constraints (from CLAUDE.md)

- Pure MATLAB — no external dependencies
- Backward compatibility mandatory — existing Threshold and Sensor behavior unchanged
- Widget contract: changes must work through `DashboardWidget` base class interface
- MISS_HIT style: PascalCase properties, camelCase methods, 160-char line limit, cyclomatic complexity <= 80
- Error IDs: `'ClassName:problemName'` format
- All public properties with inline defaults on declaration
- `properties (Access = public)` for user-configurable settings, `properties (SetAccess = private)` for internal state
- Handle class inheritance: `classdef X < handle`
- Tests: both suite `TestX.m` (MATLAB) and Octave function-based `test_x.m` where applicable
- No MATLAB toolbox dependencies

---

## Standard Stack

### Core (all already present — no new dependencies)

| Component | Location | Purpose | Notes |
|-----------|----------|---------|-------|
| `Threshold` | `libs/SensorThreshold/Threshold.m` | Base class with `Key`, `Name`, `allValues()`, `conditions_` | Handle class; `IsUpper`, `Direction`, `Label` |
| `ThresholdRegistry` | `libs/SensorThreshold/ThresholdRegistry.m` | Singleton key catalog | Accepts any `Threshold` subclass via `register(key, t)` — no changes needed |
| `DashboardWidget` | `libs/Dashboard/DashboardWidget.m` | Abstract base class | Constructor parses all varargin via property assignment |
| `StatusWidget` | `libs/Dashboard/StatusWidget.m` | Phase 1002 threshold binding | `deriveStatusFromThreshold()` private helper — reusable pattern |
| `MultiStatusWidget` | `libs/Dashboard/MultiStatusWidget.m` | Grid of status dots | `Sensors` cell holds Sensor objects or threshold-binding structs |

### No Installation Required

All dependencies are existing in-repo MATLAB files. No `npm install`, `pip install`, or MEX compilation needed for this phase.

---

## Architecture Patterns

### Recommended Project Structure

```
libs/SensorThreshold/
├── CompositeThreshold.m    # NEW: subclass of Threshold
├── Threshold.m             # UNCHANGED
├── ThresholdRegistry.m     # UNCHANGED
└── ThresholdRule.m         # UNCHANGED

libs/Dashboard/
├── MultiStatusWidget.m     # MODIFIED: composite expansion in refresh()
├── StatusWidget.m          # POSSIBLY MODIFIED: see Pattern 3
└── ...

tests/suite/
├── TestCompositeThreshold.m  # NEW: suite tests
└── TestMultiStatusWidget.m   # EXTENDED: composite expansion tests
```

### Pattern 1: CompositeThreshold class skeleton

`CompositeThreshold` must:
1. Inherit from `Threshold` so it is accepted everywhere a `Threshold` is
2. Override `allValues()` to return `[]` — composites have no direct conditions
3. Add `AggregateMode` ('and'|'or'|'majority') and `children_` cell array
4. Implement `addChild(thresholdOrKey)` with dual-input (object or registry key string)
5. Implement `computeStatus()` — recursive, calls each child's own `computeStatus()` or evaluates a leaf Threshold

```matlab
% Source: internal design — based on existing Threshold.m pattern
classdef CompositeThreshold < Threshold
    properties (Access = public)
        AggregateMode = 'and'   % 'and', 'or', 'majority'
    end

    properties (SetAccess = private)
        children_  = {}   % cell: Threshold or CompositeThreshold objects
    end

    methods
        function obj = CompositeThreshold(key, varargin)
            % Forward all unknown options to parent after extracting AggregateMode
            obj = obj@Threshold(key);  % or parse varargin for Name, AggregateMode, etc.
            ...
        end

        function addChild(obj, thresholdOrKey)
            % Dual-input: string -> ThresholdRegistry.get(), object -> use directly
            ...
        end

        function status = computeStatus(obj)
            % Recursively evaluate each child
            % Leaf Threshold: use child.ValueFcn / child.Value + allValues()
            % CompositeThreshold child: recurse
            % Apply AggregateMode logic over child statuses
        end

        function vals = allValues(obj)
            vals = [];  % No direct conditions on a composite
        end
    end
end
```

**Key insight on `addChild` dual-input:** `Sensor.addThreshold()` has exactly the same pattern —
accepts both an object and a string key, resolves the string via the registry. Follow that
exactly (try/catch with warning on missing key).

### Pattern 2: computeStatus tree traversal

Each child can be either a leaf `Threshold` (which has a `ValueFcn` / `Value` field for its
current reading) or a nested `CompositeThreshold`. The traversal strategy:

```
For each child in children_:
    if isa(child, 'CompositeThreshold'):
        childStatus = child.computeStatus()   % recursive
    else:
        childValue = resolve ValueFcn or Value from child
        childStatus = evaluate child.allValues() + child.IsUpper against childValue
Apply AggregateMode over all childStatus strings
Return 'ok' | 'warning' | 'alarm'
```

**Value storage on leaf children:** The CONTEXT.md (D-06) says each child carries its own
current value via `ValueFcn` or static value. `Threshold` does not currently have `ValueFcn`
or `Value` properties (those live on widgets in Phase 1002). Two implementation options:

- **Option A (recommended):** Add `ValueFcn` and `Value` properties to `CompositeThreshold`'s
  child management — store them alongside the child reference in a struct within `children_`.
  This keeps `Threshold` itself clean and is analogous to how `MultiStatusWidget.Sensors{i}` is
  a struct `{threshold, value, valueFcn, label}`.

- **Option B:** Add `ValueFcn` / `Value` directly to `Threshold.m`. This is simpler but
  changes the base class.

Option A is recommended because it avoids modifying the base `Threshold` class (backward
compatibility) and mirrors the MultiStatusWidget struct pattern already in the codebase.

### Pattern 3: StatusWidget / GaugeWidget with CompositeThreshold

`StatusWidget.deriveStatusFromThreshold()` calls `obj.Threshold.allValues()` and
`obj.Threshold.IsUpper`. When `obj.Threshold` is a `CompositeThreshold`, `allValues()` returns
`[]` — so the existing code would silently show "ok". The fix options:

- **Option A (recommended, Claude's discretion):** In `deriveStatusFromThreshold`, check
  `isa(t, 'CompositeThreshold')` and call `t.computeStatus()` directly. A single `if isa`
  branch before the existing `allValues()` path handles this transparently.

- **Option B:** Override `allValues()` in `CompositeThreshold` to aggregate all descendant
  leaf values. This would work with the existing `deriveStatusFromThreshold` logic but
  produces meaningless numeric values.

Option A is recommended — a clean branch keeps the two code paths explicit and testable.

### Pattern 4: MultiStatusWidget composite expansion

The current `MultiStatusWidget.refresh()` iterates `obj.Sensors` which holds either `Sensor`
objects or threshold-binding structs. For D-08 (auto-expansion):

When `obj.Sensors{i}` contains or is a `CompositeThreshold`, expansion inserts:
1. One dot per leaf child in the composite (plus any nested composites)
2. A summary dot/row for the composite itself

Implementation approach:
- In `refresh()`, before the grid-draw loop, flatten the `Sensors` list: for each item, if
  it is or wraps a `CompositeThreshold`, replace it with an expanded list of child items
  plus the composite summary item.
- Or: do the expansion inline in the draw loop.

The struct-based item format already in `MultiStatusWidget` (`struct('threshold', t, 'value',
v, 'label', lbl)`) naturally accommodates composite child entries.

### Pattern 5: Serialization format

`CompositeThreshold.toStruct()` should emit:

```json
{
  "type": "composite",
  "key": "system_a",
  "name": "System A",
  "aggregateMode": "and",
  "children": [
    { "key": "subsys_aa", "valueFcn": null, "value": null },
    { "key": "subsys_ab", "valueFcn": null, "value": null }
  ]
}
```

`fromStruct()` resolves child keys via `ThresholdRegistry.get()`. When children are also
composites, they should already be registered in the registry before the parent is loaded —
document this ordering requirement.

### Anti-Patterns to Avoid

- **Circular references:** A `CompositeThreshold` that contains itself (or a cycle). Guard in
  `addChild()` with a trivial identity check against `obj` itself; a full cycle-detection scan
  would add complexity. Document that deeper cycles are undefined behavior.
- **Modifying Threshold.m base class:** Avoid adding `ValueFcn` / `Value` to `Threshold`
  to maintain backward compatibility (use Option A in Pattern 2 above).
- **Calling `allValues()` on a composite without isa-guard:** The existing `StatusWidget`
  `deriveStatusFromThreshold` logic must be updated with an `isa` guard before `allValues()`.
- **Hard-coding child count logic in widgets:** The expansion logic in `MultiStatusWidget`
  should call a method on `CompositeThreshold` (e.g., `getChildEntries()`) rather than
  accessing `children_` directly from the widget — keeps encapsulation intact.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Registry lookup | Custom key->object map | `ThresholdRegistry.get(key)` | Singleton already exists; consistent error handling |
| Circular reference guard | Full graph cycle detection | Simple `obj == thresholdOrKey` identity check in `addChild` | Cycles via grandchildren are edge cases; document, don't over-engineer |
| Status color derivation | New color logic | Reuse `statusToColor()` from `StatusWidget` or `theme.StatusOkColor` / `theme.StatusAlarmColor` | All color-to-status mapping is centralized in widgets; composite just returns a status string |
| Child iteration | Recursive `for` outside the class | `computeStatus()` method on `CompositeThreshold` | Keeps traversal encapsulated; callers get a single string result |

---

## Common Pitfalls

### Pitfall 1: allValues() returning [] breaks existing widget paths silently
**What goes wrong:** `StatusWidget.deriveStatusFromThreshold()` calls `t.allValues()`. For a
`CompositeThreshold` this returns `[]`. The existing logic returns early with "ok" status —
the widget shows green even when children are violated.
**Why it happens:** `allValues()` is the current Threshold-to-status evaluation entry point
for widgets. Composites have no direct numeric conditions.
**How to avoid:** Add `isa(t, 'CompositeThreshold')` guard in `deriveStatusFromThreshold()`:
call `t.computeStatus()` and map its output to color via `statusToColor()` before falling
through to the `allValues()` path. Same guard needed in `GaugeWidget` and `IconCardWidget`.
**Warning signs:** Tests pass for `Threshold` but a `CompositeThreshold` bound to
`StatusWidget` always shows green regardless of child violations.

### Pitfall 2: Children value resolution — ValueFcn not stored
**What goes wrong:** `computeStatus()` needs each leaf child's current value, but `Threshold`
objects have no `ValueFcn` or `Value` property. Attempting `child.ValueFcn` will throw.
**Why it happens:** Those properties live on widgets (Phase 1002) not on `Threshold`.
**How to avoid:** Store child entries as structs `{threshold: t, valueFcn: @f, value: v}`
inside `children_` (Option A from Pattern 2). `computeStatus()` pulls the value from the
struct wrapper, not directly from the `Threshold` object.
**Warning signs:** `computeStatus()` errors with "no property ValueFcn on Threshold".

### Pitfall 3: ThresholdRegistry.printTable() / viewer() choke on CompositeThreshold
**What goes wrong:** `printTable()` accesses `t.Direction` and `numel(t.conditions_)` for
every registered threshold. `CompositeThreshold` inherits these from `Threshold` — `Direction`
defaults to 'upper', `conditions_` defaults to `{}` (numel=0). This should work without
modification, but the printout will be misleading (shows "upper", "#Conditions: 0").
**How to avoid:** Override nothing in `ThresholdRegistry` — the existing code will not error.
Optionally override `getType()` or add a `Type` property to `CompositeThreshold` that returns
'composite' so the viewer can show it differently. Not strictly needed for correctness.
**Warning signs:** `ThresholdRegistry.printTable()` errors or shows garbled output after
registering a `CompositeThreshold`.

### Pitfall 4: MultiStatusWidget expansion changes item count mid-render
**What goes wrong:** `refresh()` builds a grid based on `numel(obj.Sensors)`. If expansion
runs inline (replacing each composite with N children), the grid dimensions change on each
refresh and the axes is redrawn with different slot counts, potentially causing flicker.
**Why it happens:** The grid geometry (`cols`, `rows`) is computed from item count at the
start of `refresh()`.
**How to avoid:** Flatten the expanded item list once at the top of `refresh()` before
computing `cols` and `rows`. Keep `obj.Sensors` as the user-facing list (never modify it in
`refresh()`). Use a local `items` variable for the expanded drawing list.

### Pitfall 5: Serialization ordering — child keys must be registered before parent
**What goes wrong:** `CompositeThreshold.fromStruct()` calls `ThresholdRegistry.get(childKey)`
for each child. If `DashboardSerializer` loads the parent composite first and children have
not been registered yet, the load throws `ThresholdRegistry:unknownKey`.
**Why it happens:** JSON loading order is sequential; composites referencing other composites
or thresholds not yet in the registry will fail.
**How to avoid:** Document the registration order requirement. In `fromStruct()`, use a
try/catch with a warning (same pattern as `StatusWidget.fromStruct()`) so loading is robust.
Children can be `[]` until the user re-registers them.

---

## Code Examples

### addChild dual-input pattern (mirrors Sensor.addThreshold)

```matlab
% Source: pattern from libs/SensorThreshold/Sensor.m addThreshold() method
function addChild(obj, thresholdOrKey, varargin)
    %ADDCHILD Add a child Threshold or CompositeThreshold.
    if ischar(thresholdOrKey) || isstring(thresholdOrKey)
        try
            t = ThresholdRegistry.get(thresholdOrKey);
        catch
            warning('CompositeThreshold:unknownChild', ...
                'ThresholdRegistry key ''%s'' not found; child skipped.', thresholdOrKey);
            return;
        end
    else
        t = thresholdOrKey;
    end
    % Parse optional ValueFcn / Value for leaf children
    valueFcn = [];
    value    = [];
    for i = 1:2:numel(varargin)
        switch varargin{i}
            case 'ValueFcn', valueFcn = varargin{i+1};
            case 'Value',    value    = varargin{i+1};
        end
    end
    entry = struct('threshold', t, 'valueFcn', valueFcn, 'value', value);
    obj.children_{end+1} = entry;
end
```

### computeStatus AND logic

```matlab
% Source: internal design
function status = computeStatus(obj)
    %COMPUTESTATUS Evaluate aggregate status across all children.
    nChildren = numel(obj.children_);
    if nChildren == 0
        status = 'ok';
        return;
    end
    statuses = cell(1, nChildren);
    for i = 1:nChildren
        entry = obj.children_{i};
        t = entry.threshold;
        if isa(t, 'CompositeThreshold')
            statuses{i} = t.computeStatus();
        else
            % Resolve current value
            val = [];
            if ~isempty(entry.valueFcn)
                try val = entry.valueFcn(); catch, end
            elseif ~isempty(entry.value)
                val = entry.value;
            end
            statuses{i} = obj.evaluateLeaf_(t, val);
        end
    end
    status = obj.applyAggregateMode_(statuses);
end
```

### StatusWidget isa-guard in deriveStatusFromThreshold

```matlab
% Source: modification to libs/Dashboard/StatusWidget.m
function [status, color] = deriveStatusFromThreshold(obj, val, theme)
    t = obj.Threshold;
    % CompositeThreshold: delegate to computeStatus(), ignore val
    if isa(t, 'CompositeThreshold')
        status = t.computeStatus();
        color  = obj.statusToColor(status, theme);
        return;
    end
    % Existing leaf Threshold logic unchanged below ...
    status = 'ok';
    color  = theme.StatusOkColor;
    tVals  = t.allValues();
    if isempty(tVals), return; end
    ...
end
```

### ThresholdRegistry stores CompositeThreshold unchanged

```matlab
% Source: ThresholdRegistry.m — no change required
ct = CompositeThreshold('system_a', 'Name', 'System A', 'AggregateMode', 'and');
ct.addChild(t1, 'ValueFcn', @() readA());
ct.addChild(t2, 'ValueFcn', @() readB());
ThresholdRegistry.register('system_a', ct);
got = ThresholdRegistry.get('system_a');  % Returns CompositeThreshold handle
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Threshold = leaf only, numeric conditions | CompositeThreshold = aggregate of child Thresholds | Phase 1003 | Enables hierarchical system health trees |
| Widget binds one Threshold | Widget binds Threshold or CompositeThreshold (polymorphic) | Phase 1003 | Single isa-guard update to deriveStatusFromThreshold |
| MultiStatusWidget shows flat list | MultiStatusWidget auto-expands composites to show children | Phase 1003 | Richer grid; composite summary row |

---

## Open Questions

1. **removeChild API (Claude's discretion)**
   - What we know: `addChild` is required; remove is deferred to discretion
   - What's unclear: Whether any widget or test workflow needs removal
   - Recommendation: Implement a simple `removeChild(thresholdOrKey)` that matches by key
     string or handle identity; add only if a test demands it

2. **StatusWidget / GaugeWidget behavior when no ValueFcn on composite**
   - What we know: When `StatusWidget.Threshold` is a `CompositeThreshold`, `val` argument to
     `deriveStatusFromThreshold()` comes from the widget's own `ValueFcn`/`Value` — not from
     children. The composite evaluates children using their per-child value fields.
   - What's unclear: Should the composite's own `val` be ignored (recommended) or used as a
     fallback for children without their own value?
   - Recommendation: Ignore `val` from the widget when the threshold is a composite — always
     delegate to `computeStatus()` which uses per-child values. Document this clearly.

3. **'majority' mode definition**
   - What we know: 'majority' is listed in D-02 but not further specified
   - What's unclear: Is majority > 50%? Or > 50% of non-ok? What status does majority return?
   - Recommendation: Define majority as `nOk > nChildren/2` returns 'ok', otherwise 'alarm'.
     This is the simplest unambiguous interpretation.

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified — this phase is pure MATLAB class additions)

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | matlab.unittest.TestCase (suite) + Octave function tests |
| Config file | tests/run_all_tests.m |
| Quick run command | `cd /path/to/FastPlot && matlab -batch "addpath('.'); install(); results = run(TestCompositeThreshold); exit(~all([results.Passed]))"` |
| Full suite command | `matlab -batch "addpath('.'); install(); run_all_tests"` |

### Phase Requirements → Test Map

| ID | Behavior | Test Type | Automated Command | File Exists? |
|----|----------|-----------|-------------------|-------------|
| D-01 | `isa(ct, 'Threshold')` is true | unit | `TestCompositeThreshold.testIsThresholdSubclass` | Wave 0 |
| D-02 | AND/OR/MAJORITY modes compute correct aggregate | unit | `TestCompositeThreshold.testComputeStatusAnd`, `testComputeStatusOr`, `testComputeStatusMajority` | Wave 0 |
| D-03 | Children can be Threshold or CompositeThreshold (nesting) | unit | `TestCompositeThreshold.testNestedComposite` | Wave 0 |
| D-04 | `computeStatus()` returns 'ok'/'warning'/'alarm' string | unit | `TestCompositeThreshold.testComputeStatusReturnsString` | Wave 0 |
| D-05 | `addChild` accepts Threshold object | unit | `TestCompositeThreshold.testAddChildObject` | Wave 0 |
| D-05 | `addChild` accepts registry key string | unit | `TestCompositeThreshold.testAddChildByKey` | Wave 0 |
| D-06 | Per-child ValueFcn called in computeStatus | unit | `TestCompositeThreshold.testComputeStatusCallsValueFcn` | Wave 0 |
| D-07 | Same Threshold as child of two composites | unit | `TestCompositeThreshold.testSharedChildHandle` | Wave 0 |
| D-08 | MultiStatusWidget expands composite to child dots | unit | `TestMultiStatusWidget.testCompositeExpansion` | Wave 0 |
| D-09 | ThresholdRegistry accepts and returns CompositeThreshold | unit | `TestCompositeThreshold.testRegistryRoundtrip` | Wave 0 |

### Sampling Rate
- **Per task commit:** `TestCompositeThreshold` suite only
- **Per wave merge:** Full `run_all_tests`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/suite/TestCompositeThreshold.m` — covers all D-0x requirements above
- [ ] `tests/suite/TestMultiStatusWidget.m` composite expansion tests (extend existing file)

---

## Sources

### Primary (HIGH confidence)
- `libs/SensorThreshold/Threshold.m` — Base class API, property names, constructor pattern, `allValues()`, `conditions_`, `IsUpper`
- `libs/SensorThreshold/ThresholdRegistry.m` — Registry API; `register()`, `get()`, `catalog()` singleton pattern; accepts any subclass
- `libs/Dashboard/StatusWidget.m` — `deriveStatusFromThreshold()` private helper, `resolveCurrentValue_()`, `statusToColor()`, isa-guard location
- `libs/Dashboard/MultiStatusWidget.m` — `Sensors` cell structure, struct items with `{threshold, value, valueFcn, label}`, `refresh()` grid logic, `toStruct()`/`fromStruct()` items array
- `libs/Dashboard/DashboardWidget.m` — Base class constructor varargin parsing, properties layout
- `tests/suite/TestThreshold.m` — Handle class test patterns, teardown conventions
- `tests/suite/TestThresholdRegistry.m` — Registry cleanup teardown (`TestMethodTeardown`), key naming conventions

### Secondary (MEDIUM confidence)
- `libs/Dashboard/IconCardWidget.m` — `isa`-guard pattern for key resolution; mutual exclusivity pattern
- `libs/Dashboard/GaugeWidget.m` — Second widget needing `isa` guard for composite; same `Threshold` property pattern
- Phase 1002 RESEARCH.md — Established patterns for Threshold-binding, widget property layout

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all files read directly from repo
- Architecture: HIGH — directly derived from existing code patterns in Threshold.m and StatusWidget.m
- Pitfalls: HIGH — identified by reading actual code paths that composites will interact with

**Research date:** 2026-04-06
**Valid until:** 2026-06-01 (stable codebase, no external dependencies)
