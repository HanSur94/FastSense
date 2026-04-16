# Phase 1001: First-Class Threshold Entities - Research

**Researched:** 2026-04-05
**Domain:** MATLAB OOP refactoring — SensorThreshold library, registry pattern, handle class lifecycle
**Confidence:** HIGH

## Summary

Phase 1001 is a breaking API refactor of the SensorThreshold library. The current `ThresholdRule` value class is subordinate to `Sensor` (owned per-sensor, no identity, no sharing). The new `Threshold` handle class becomes a first-class entity with its own registry (`ThresholdRegistry`), analogous to how `Sensor` is managed by `SensorRegistry`. A `Threshold` owns its Name, Key, Direction, Color, LineStyle, Units, Description, Tags and carries a list of state-condition/value pairs (analogous to what `ThresholdRule` today calls Condition+Value). Multiple sensors reference the same `Threshold` handle, so a change propagates everywhere.

The refactor has a well-understood blast radius: 34 test files contain 147 references to `ThresholdRule`/`ThresholdRules`/`addThresholdRule`. Nine downstream consumer files in Dashboard and EventDetection iterate `sensor.ThresholdRules` and call `rule.Value`, `rule.IsUpper`, `rule.Direction`, `rule.Color`, `rule.LineStyle`, `rule.Label`. The private helpers (`buildThresholdEntry`, `conditionKey`) and `Sensor.resolve()` are the core evaluation machinery that must be adapted.

The key architectural insight is that `Threshold` is a new class (not an upgrade of `ThresholdRule`) and `ThresholdRule` can be retained as an internal implementation detail inside `Threshold` for condition storage if that makes `resolve()` cleanest — or replaced with a plain struct array. The public contract changes completely; the resolve algorithm structure stays the same.

**Primary recommendation:** Keep `ThresholdRule` as an internal condition-storage struct (renamed or left as private) inside `Threshold`. Each `Threshold` owns a `cell` of condition/value pairs. `Sensor.resolve()` is adapted to iterate `obj.Thresholds` and extract the same `CachedConditionKey`/`Value`/`IsUpper`/`Direction` data that it currently reads from `ThresholdRule`. This minimises churn in the batch-violation MEX pathway.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** New `Threshold` class (handle class, like Sensor) — NOT an upgrade of ThresholdRule
- **D-02:** TrendMiner-style: a Threshold is a named limit concept that owns state-dependent condition-value pairs. Direction, Color, LineStyle live on the Threshold, not per-condition
- **D-03:** Threshold properties: Key, Name, Direction, Color, LineStyle, Units, Description, Tags (cell array of strings for filtering/grouping)
- **D-04:** Conditions use the existing StateChannel struct-matching mechanism: `t.addCondition(struct('machine', 1), 80)`
- **D-05:** Handle class — changes to a Threshold propagate to all sensors referencing it
- **D-06:** `ThresholdRegistry` mirrors `SensorRegistry` exactly — static methods, persistent `containers.Map`, singleton pattern
- **D-07:** API: `get(key)`, `register(key, t)`, `unregister(key)`, `list()`, `printTable()`, `viewer()`
- **D-08:** Query methods: `findByTag(tag)`, `findByDirection('upper'/'lower')` for discovery
- **D-09:** No predefined catalog — registry starts empty, users populate at runtime
- **D-10:** `getMultiple(keys)` for batch retrieval (mirrors SensorRegistry)
- **D-11:** Breaking change: `addThresholdRule` removed entirely, `ThresholdRules` property replaced with `Thresholds`
- **D-12:** `Sensor.addThreshold()` accepts both Threshold objects and registry key strings (dual input, key auto-resolves via ThresholdRegistry)
- **D-13:** Duplicate rejection by Key — addThreshold skips/warns if same Key already attached
- **D-14:** `Sensor.removeThreshold(key)` detaches threshold from sensor (Threshold stays in registry)
- **D-15:** `Sensor.Thresholds` is a cell array of Threshold handle references
- **D-16:** Conditions use existing StateChannel mechanism (struct-based condition matching) — no changes to condition evaluation logic
- **D-17:** Existing `Sensor.resolve()` internals adapted to iterate `Thresholds` instead of `ThresholdRules`

### Claude's Discretion
- Internal representation of conditions within Threshold (keep ThresholdRule as internal class, replace with struct array, or other — whatever makes resolve() cleanest)
- Resolve architecture: whether results stay on Sensor (current pattern) or move — Claude picks based on integration with FastSense, EventDetection, and Dashboard consumers
- Migration of existing code: SensorRegistry.catalog() predefined sensors, EventDetection, Dashboard widgets — all reference points that use ThresholdRule need updating

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MATLAB handle class | R2020b+ | `Threshold` identity and shared-reference semantics | Required by D-05; same pattern as `Sensor`, `StateChannel`, `DashboardWidget` |
| `containers.Map` | R2020b+ | ThresholdRegistry singleton backing store | Exact pattern used by `SensorRegistry.catalog()` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `conditionKey.m` (private) | existing | Canonical string key for condition structs | Used in `Threshold.addCondition()` to pre-compute `CachedConditionKey` per condition |
| `buildThresholdEntry.m` (private) | existing | Build resolved threshold struct for plotting | Needs signature update: accept `Threshold` instead of `ThresholdRule` |
| MEX kernels (`compute_violations_batch`, `violation_cull_mex`) | existing | Batch violation detection | No changes needed — called with same numeric arrays |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Keep `ThresholdRule` as internal condition struct inside `Threshold` | Replace with plain `struct` array | Struct array avoids extra class file, but `ThresholdRule.matchesState()` is already tested and correct — reuse it as internal impl for zero-cost migration of condition eval logic |
| Results stay on Sensor (`ResolvedThresholds`, `ResolvedViolations`) | Move resolve results to Threshold | Keeping on Sensor is correct: results depend on sensor data × threshold × state channels — not threshold alone. FastSense.addSensor(), EventDetection all read from sensor. No move needed. |

**Installation:** No new packages. Pure MATLAB.

---

## Architecture Patterns

### Recommended Project Structure

New files:
```
libs/SensorThreshold/
├── Threshold.m              (new — first-class threshold entity)
└── ThresholdRegistry.m      (new — mirrors SensorRegistry exactly)
```

Modified files:
```
libs/SensorThreshold/
└── Sensor.m                 (replace ThresholdRules -> Thresholds, addThresholdRule -> addThreshold, adapt resolve())
libs/SensorThreshold/private/
└── buildThresholdEntry.m    (signature: accept Threshold instead of ThresholdRule)
libs/Dashboard/
├── FastSenseWidget.m        (comment update only — no code reads ThresholdRules directly)
├── StatusWidget.m           (replace sensor.ThresholdRules -> sensor.Thresholds)
├── GaugeWidget.m            (replace sensor.ThresholdRules -> sensor.Thresholds; rule.IsUpper -> t.IsUpper or strcmp(t.Direction,'upper'))
├── MultiStatusWidget.m      (replace sensor.ThresholdRules -> sensor.Thresholds)
├── ChipBarWidget.m          (replace sensor.ThresholdRules -> sensor.Thresholds)
└── IconCardWidget.m         (replace sensor.ThresholdRules -> sensor.Thresholds)
libs/EventDetection/
├── IncrementalEventDetector.m  (replace ThresholdRules iteration + addThresholdRule calls)
├── LiveEventPipeline.m         (replace ThresholdRules -> Thresholds)
└── EventViewer.m               (replace addThresholdRule -> addThreshold)
libs/SensorThreshold/
├── SensorRegistry.m         (update printTable() / viewer() #Rules column)
├── ExternalSensorRegistry.m (update #Rules column)
└── loadModuleMetadata.m     (replace ThresholdRules -> Thresholds; adapt condition field extraction)
```

Test files requiring update (34 files, 147 references — see Test Migration section below).

### Pattern 1: Threshold Handle Class

**What:** `Threshold` is a `handle` class with entity identity (`Key`), visual properties (Direction, Color, LineStyle, Units, Description, Tags), and a cell array of condition/value pairs. Each condition pair is internally stored using the existing `ThresholdRule` value class (or a plain struct — Claude's discretion).

**When to use:** Whenever a threshold limit concept must be shared across sensors or referenced by key from a registry.

**Example:**
```matlab
% Source: modelled on Sensor.m and ThresholdRule.m patterns
t = Threshold('temp-hh', 'Name', 'Temperature High-High', ...
    'Direction', 'upper', 'Color', [1 0 0], ...
    'Tags', {'temperature', 'alarm'});
t.addCondition(struct('machine', 1), 85);
t.addCondition(struct('machine', 2), 90);
ThresholdRegistry.register('temp-hh', t);

s = SensorRegistry.get('temperature');
s.addThreshold('temp-hh');   % key string -> auto-resolve via ThresholdRegistry
s.resolve();
```

### Pattern 2: ThresholdRegistry — Static Singleton

**What:** Mirrors `SensorRegistry` exactly. `persistent cache` in private `catalog()` method holds a `containers.Map`. No predefined entries (D-09).

**When to use:** All lookup, registration, query operations.

**Example:**
```matlab
% Source: modelled on SensorRegistry.m
classdef ThresholdRegistry
    methods (Static)
        function t = get(key)
            map = ThresholdRegistry.catalog();
            if ~map.isKey(key)
                error('ThresholdRegistry:unknownKey', ...
                    'No threshold defined with key ''%s''.', key);
            end
            t = map(key);
        end

        function ts = findByTag(tag)
            map = ThresholdRegistry.catalog();
            keys = map.keys();
            ts = {};
            for i = 1:numel(keys)
                t = map(keys{i});
                if any(strcmp(t.Tags, tag))
                    ts{end+1} = t;
                end
            end
        end

        function ts = findByDirection(dir)
            map = ThresholdRegistry.catalog();
            keys = map.keys();
            ts = {};
            for i = 1:numel(keys)
                t = map(keys{i});
                if strcmp(t.Direction, dir)
                    ts{end+1} = t;
                end
            end
        end
    end
    methods (Static, Access = private)
        function map = catalog()
            persistent cache;
            if isempty(cache)
                cache = containers.Map();
            end
            map = cache;
        end
    end
end
```

### Pattern 3: Sensor.addThreshold() Dual Input

**What:** Accepts either a `Threshold` object directly, or a char key string which is resolved via `ThresholdRegistry.get()`. Rejects duplicates by Key (D-13).

**Example:**
```matlab
function addThreshold(obj, thresholdOrKey)
    if ischar(thresholdOrKey)
        t = ThresholdRegistry.get(thresholdOrKey);
    else
        t = thresholdOrKey;
    end
    % Reject duplicates by Key
    for i = 1:numel(obj.Thresholds)
        if strcmp(obj.Thresholds{i}.Key, t.Key)
            warning('Sensor:duplicateThreshold', ...
                'Threshold ''%s'' already attached, skipping.', t.Key);
            return;
        end
    end
    obj.Thresholds{end+1} = t;
    if obj.isOnDisk()
        obj.DataStore.clearResolved();
    end
end
```

### Pattern 4: Sensor.resolve() Adaptation

**What:** The existing `resolve()` algorithm iterates `obj.ThresholdRules` and reads `.CachedConditionKey`, `.Value`, `.IsUpper`, `.Direction`, `.Label`, `.Color`, `.LineStyle`. After migration, it iterates `obj.Thresholds` and for each Threshold expands its conditions into the same per-condition-group processing. The batch MEX pathway is unchanged.

**Key insight:** `Threshold` owns `Direction`, `Color`, `LineStyle` (D-02). The condition storage inside `Threshold` only holds the condition struct and numeric value. The resolve loop must synthesise `ThresholdRule`-shaped objects (or equivalent structs) per condition per Threshold to feed the existing batch infrastructure — OR directly refactor the group loop to work from Threshold conditions natively.

**Recommended approach (Claude's discretion):** Keep `ThresholdRule` as private internal class unchanged. `Threshold.conditions_` is a cell array of `ThresholdRule` objects where each `ThresholdRule` inherits Direction/Color/LineStyle from its parent `Threshold` at construction time. `Sensor.resolve()` flattens `obj.Thresholds` into a single `allRules` cell array before the existing grouping logic — zero changes to the batch algorithm.

```matlab
% Inside Threshold.addCondition():
function addCondition(obj, conditionStruct, value)
    rule = ThresholdRule(conditionStruct, value, ...
        'Direction', obj.Direction, ...
        'Label', obj.Name, ...
        'Color', obj.Color, ...
        'LineStyle', obj.LineStyle);
    obj.conditions_{end+1} = rule;
end

% Inside Sensor.resolve() — replace nRules / obj.ThresholdRules loop:
allRules = {};
for i = 1:numel(obj.Thresholds)
    t = obj.Thresholds{i};
    for j = 1:numel(t.conditions_)
        allRules{end+1} = t.conditions_{j};
    end
end
nRules = numel(allRules);
% ... rest of algorithm unchanged, using allRules instead of obj.ThresholdRules
```

This is the safest approach: the entire MEX-backed batch pipeline, `conditionKey`, `buildThresholdEntry`, `appendResults`, `mergeResolvedByLabel` all work without any modification.

**Caveat:** If a `Threshold`'s Direction/Color/LineStyle changes after `addCondition()` was called, the internal `ThresholdRule` copies will be stale. Since `Threshold` is a handle class, updates are infrequent and callers must call `resolve()` after any Threshold property change. Document this in the class header.

### Pattern 5: Downstream Consumer Update

**What:** All consumer code that currently reads `sensor.ThresholdRules{k}` needs `sensor.Thresholds{k}` instead. The property names on each `Threshold` are the same as on `ThresholdRule` for the fields that consumers read (`Value`, `Direction`, `IsUpper`, `Color`, `LineStyle`, `Label` = `Name`).

**Breaking point:** `ThresholdRule.Label` becomes `Threshold.Name`. Consumers checking `.Label` need `.Name`. This is the only semantic rename. `IsUpper` is a cached logical; add it as a `(SetAccess = private)` computed property on `Threshold`.

**Consumer-by-consumer update:**

| File | Current code | New code |
|------|-------------|----------|
| `StatusWidget.asciiRender` | `sensor.ThresholdRules{k}` | `sensor.Thresholds{k}` |
| `GaugeWidget.deriveRange` | `cellfun(@(r) r.Value, sensor.ThresholdRules)` | `cellfun(@(t) t.Value, sensor.Thresholds)` |
| `GaugeWidget.getValueColor` | `rule.IsUpper`, `rule.Value`, `rule.Color` | `t.IsUpper`, `t.Value`, `t.Color` |
| `MultiStatusWidget` | `sensor.ThresholdRules{k}` | `sensor.Thresholds{k}` |
| `ChipBarWidget` | `sensor.ThresholdRules{k}` | `sensor.Thresholds{k}` |
| `IconCardWidget` | `sensor.ThresholdRules{k}` | `sensor.Thresholds{k}` |
| `StatusWidget.deriveStatusFromSensor` | `rule.IsUpper`, `rule.Value` | `t.IsUpper`, `t.Value` |
| `IncrementalEventDetector.process` (line 65-69) | copies ThresholdRules via addThresholdRule | copies Thresholds via addThreshold |
| `IncrementalEventDetector` (line 237-238) | reads ThresholdRules | reads Thresholds |
| `LiveEventPipeline` (lines 177-201) | reads ThresholdRules | reads Thresholds |
| `EventViewer` (line 733) | sensor.addThresholdRule(struct(), r.Value, ...) | sensor.addThreshold(t) — reconstruct from stored threshold data |
| `loadModuleMetadata` (lines 62-72) | iterates ThresholdRules, reads rule.Condition | iterates Thresholds, expands conditions from Threshold |
| `SensorRegistry.printTable` / `viewer` | `numel(s.ThresholdRules)` | `numel(s.Thresholds)` |
| `ExternalSensorRegistry` | `numel(s.ThresholdRules)` | `numel(s.Thresholds)` |

**loadModuleMetadata special case:** Currently extracts `condFields = fieldnames(rule.Condition)` from each ThresholdRule. After migration, `Threshold` exposes conditions as internal `ThresholdRule` objects, or as a public method `getConditionFields()` returning all unique condition field names. Recommend adding `Threshold.getConditionFields()` as a convenience method that iterates `obj.conditions_` and unions fieldnames.

**IncrementalEventDetector special case:** Currently reconstructs a temp sensor by calling `tmpSensor.addThresholdRule(rule.Condition, rule.Value, ...)`. After migration it calls `tmpSensor.addThreshold(t)` for each `t` in `sensor.Thresholds`. The temp sensor receives Threshold handles directly — same handle, no copy needed, because the values are read-only during detection.

### Anti-Patterns to Avoid
- **Adding `Value` as a top-level Threshold property:** `Threshold` does not have a single `Value` — it has per-condition values. Only `Direction`, `Color`, `LineStyle` are Threshold-level. Downstream code reading `t.Value` must call `t.getValueAt(conditionStruct)` or flatten conditions first. EXCEPTION: `GaugeWidget.deriveRange` needs all values; expose a `Threshold.allValues()` method returning all numeric values across all conditions.
- **Modifying ThresholdRule internal class:** Leave `ThresholdRule` unchanged as internal class. Its public API is not user-facing after this phase. Removing it from the MATLAB path is out of scope.
- **Storing Threshold as value class:** Must be handle (D-05). Using `classdef Threshold` without `< handle` would break the sharing contract.
- **Breaking SensorRegistry.catalog():** The catalog currently adds ThresholdRules to example sensors. After migration, update catalog entries to use `addThreshold` with fresh Threshold objects. This is a small change to the static catalog method.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Condition key generation | Custom serializer | `conditionKey()` private helper | Already tested, handles empty struct, field ordering, string/numeric |
| Batch violation detection | Custom loop | `compute_violations_batch` / `compute_violations_disk` | MEX-accelerated; threshold data passed as numeric arrays unchanged |
| Registry singleton | Custom global | `containers.Map` in `persistent` var | Exact SensorRegistry pattern; Octave-compatible; no toolbox needed |
| State condition matching | Custom comparison | `ThresholdRule.matchesState()` | Already handles string/numeric types, field-order independence |

**Key insight:** The entire MEX-backed evaluation pipeline (`compute_violations_batch`, `compute_violations_disk`, `violation_cull_mex`) works on flat numeric arrays (`thresholdValues`, `directions`). These arrays are assembled in `Sensor.resolve()` from whatever rule objects are available. Adapting `resolve()` to flatten `Thresholds -> conditions -> ThresholdRules` means zero changes to the MEX kernels.

---

## Common Pitfalls

### Pitfall 1: Value property ambiguity on Threshold
**What goes wrong:** Consumer code (GaugeWidget, StatusWidget, IconCardWidget, ChipBarWidget) reads `rule.Value` from ThresholdRule objects to get the numeric limit. After migration, `Threshold` has no single `Value` — it has per-condition values. If consumers blindly read `threshold.Value` the code will error.
**Why it happens:** The old ThresholdRule was a value=condition pair. The new Threshold owns conditions separately. The distinction is fundamental to the TrendMiner model.
**How to avoid:** Add `Threshold.allValues()` returning `cellfun(@(r) r.Value, obj.conditions_)` for range derivation. For point-in-time evaluation, add `Threshold.getValueAt(conditionStruct)` returning the value of the first matching condition, or NaN. Update all consumer sites to use appropriate method.
**Warning signs:** `struct has no field 'Value'` errors at runtime in GaugeWidget.deriveRange, ChipBarWidget status derivation.

### Pitfall 2: IsUpper not on Threshold
**What goes wrong:** `GaugeWidget.getValueColor`, `IconCardWidget.deriveStateFromSensor`, `StatusWidget.asciiRender` all read `rule.IsUpper`. `Threshold` does not have `IsUpper` unless explicitly added.
**Why it happens:** `IsUpper` was a `SetAccess = private` cached property on `ThresholdRule`, computed from `Direction` in constructor.
**How to avoid:** Add `IsUpper` as a `Dependent` property on `Threshold`: `get.IsUpper(obj) = strcmp(obj.Direction, 'upper')`. Or add it as a `(SetAccess = private)` property set in constructor. Both approaches are Octave-compatible.
**Warning signs:** `struct has no field 'IsUpper'` errors in widget refresh methods.

### Pitfall 3: stale ThresholdRule condition copies when Threshold properties change
**What goes wrong:** If the recommended approach (conditions stored as ThresholdRule objects) is used, and a user changes `threshold.Color` after calling `addCondition()`, the internal ThresholdRule copies retain the old color. Resolved thresholds will render with stale colors.
**Why it happens:** ThresholdRule is a value class; copying Direction/Color/LineStyle into it at addCondition time means those properties are no longer live-linked to the parent Threshold.
**How to avoid:** Document clearly in `Threshold.m` header: "Call `addCondition()` after setting Direction, Color, LineStyle. Call `sensor.resolve()` after any Threshold property change." Optionally, `buildThresholdEntry` could override color/style from the Threshold rather than from the embedded ThresholdRule — but that adds complexity.
**Warning signs:** Colors or line styles not updating after user modifies a Threshold property.

### Pitfall 4: IncrementalEventDetector copies ThresholdRules to temp sensor
**What goes wrong:** Lines 65-69 of `IncrementalEventDetector.process` copy each ThresholdRule to a temp sensor via `addThresholdRule`. After migration this code will break (no `addThresholdRule` method).
**Why it happens:** The incremental detector builds a slice-scoped temp Sensor for evaluation. With the new API it must call `tmpSensor.addThreshold(t)` for each t in `sensor.Thresholds`.
**How to avoid:** The temp sensor gets the same `Threshold` handle references as the original. This is safe because the temp sensor exists only for the duration of the process() call and does not modify any Threshold state.
**Warning signs:** `Undefined function 'addThresholdRule'` error in IncrementalEventDetector.process.

### Pitfall 5: loadModuleMetadata condition field extraction
**What goes wrong:** Lines 68-72 of `loadModuleMetadata` iterate `ThresholdRules` and read `rule.Condition` to find state channel keys. After migration, Threshold does not expose `.Condition` directly.
**Why it happens:** loadModuleMetadata discovers which state channels are needed by inspecting rule conditions.
**How to avoid:** Add `Threshold.getConditionFields()` public method that returns a cell array of unique fieldnames across all conditions. `loadModuleMetadata` calls `t.getConditionFields()` instead of iterating `rule.Condition`.
**Warning signs:** Empty StateChannels attached to sensors — thresholds appear unconditional when they should not be.

### Pitfall 6: SensorRegistry.catalog() still uses addThresholdRule
**What goes wrong:** The catalog() private method in SensorRegistry.m currently has commented examples using `addThresholdRule`. After migration the example becomes invalid.
**Why it happens:** Catalog shows usage patterns.
**How to avoid:** Update catalog comment examples to show `addThreshold` usage. Active sensors in catalog (currently `pressure` and `temperature`) have no threshold rules in the default catalog — safe, no code change needed beyond comment.
**Warning signs:** Linter warning or confusion for new users; not a runtime failure.

---

## Code Examples

Verified patterns from project source:

### Threshold class skeleton (based on Sensor.m pattern)
```matlab
% Source: modelled on libs/SensorThreshold/Sensor.m and ThresholdRule.m
classdef Threshold < handle
    properties
        Key         % char: unique identifier
        Name        % char: human-readable display name
        Direction   % char: 'upper' or 'lower'
        Color       % 1x3 double: RGB (empty = theme default)
        LineStyle   % char: e.g., '--'
        Units       % char: measurement unit
        Description % char: extended description
        Tags        % cell array of char: for findByTag()
    end
    properties (SetAccess = private)
        IsUpper     % logical: cached from Direction
        conditions_ % cell array of ThresholdRule (private internal)
    end
    methods
        function obj = Threshold(key, varargin)
            obj.Key = key;
            obj.Name = '';
            obj.Direction = 'upper';
            obj.Color = [];
            obj.LineStyle = '--';
            obj.Units = '';
            obj.Description = '';
            obj.Tags = {};
            obj.conditions_ = {};
            obj.IsUpper = true;
            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Name',        obj.Name = varargin{i+1};
                    case 'Direction'
                        obj.Direction = varargin{i+1};
                        obj.IsUpper = strcmp(obj.Direction, 'upper');
                    case 'Color',       obj.Color = varargin{i+1};
                    case 'LineStyle',   obj.LineStyle = varargin{i+1};
                    case 'Units',       obj.Units = varargin{i+1};
                    case 'Description', obj.Description = varargin{i+1};
                    case 'Tags',        obj.Tags = varargin{i+1};
                    otherwise
                        error('Threshold:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end
        function addCondition(obj, conditionStruct, value)
            % Build internal ThresholdRule inheriting visual props from Threshold
            rule = ThresholdRule(conditionStruct, value, ...
                'Direction', obj.Direction, ...
                'Label', obj.Name, ...
                'Color', obj.Color, ...
                'LineStyle', obj.LineStyle);
            obj.conditions_{end+1} = rule;
        end
        function vals = allValues(obj)
            % Return all condition values as numeric vector
            if isempty(obj.conditions_)
                vals = [];
            else
                vals = cellfun(@(r) r.Value, obj.conditions_);
            end
        end
        function fields = getConditionFields(obj)
            % Return unique state channel keys across all conditions
            fields = {};
            for i = 1:numel(obj.conditions_)
                f = fieldnames(obj.conditions_{i}.Condition);
                fields = [fields; f]; %#ok<AGROW>
            end
            fields = unique(fields);
        end
    end
end
```

### Sensor.resolve() adaptation (key lines)
```matlab
% Source: libs/SensorThreshold/Sensor.m resolve() — replace ThresholdRules section
% Flatten Thresholds -> conditions (ThresholdRule objects) for batch processing
allRules = {};
for i = 1:numel(obj.Thresholds)
    t = obj.Thresholds{i};
    for j = 1:numel(t.conditions_)
        allRules{end+1} = t.conditions_{j};
    end
end
nRules = numel(allRules);
if nRules == 0
    obj.ResolvedThresholds = [];
    obj.ResolvedViolations = [];
    obj.ResolvedStateBands = [];
    return;
end
% ... remainder unchanged, replace obj.ThresholdRules{r} with allRules{r}
```

### Sensor.currentStatus() adaptation
```matlab
% Source: libs/SensorThreshold/Sensor.m currentStatus()
% Replace check: isempty(obj.ThresholdRules) -> isempty(obj.Thresholds)
% getThresholdsAt() similarly flattens to allRules before loop
```

---

## Test Migration Map

34 test files contain 147 references. The table below maps each file to required change type.

| File | References | Change Required |
|------|-----------|----------------|
| `TestThresholdRule.m` | 5 | Keep as-is OR repurpose as `TestThreshold.m` |
| `TestSensor.m` | 9 | `testAddThresholdRule` → `testAddThreshold`; property name |
| `TestSensorResolve.m` | 7 | Replace addThresholdRule → addThreshold, Threshold objects |
| `TestResolveSegments.m` | 5 | Same as TestSensorResolve |
| `TestDeclarativeCondition.m` | 6 | Replace addThresholdRule → addThreshold |
| `TestIncrementalDetector.m` | 3 | Test passes via sensor with Thresholds |
| `TestLivePipeline.m` | 3 | Sensor setup via addThreshold |
| `TestStatusWidget.m` | 8 | Sensor setup via addThreshold |
| `TestGaugeWidget.m` | 4 | Sensor setup via addThreshold |
| `TestLoadModuleMetadata.m` | 5 | Replace addThresholdRule in fixtures |
| `TestDetectEventsFromSensor.m` | 4 | Sensor fixture via addThreshold |
| `TestEventIntegration.m` | (suite) | Update sensor fixtures |
| `TestAddSensor.m` | 2 | Update sensor fixture if threshold-bearing |
| `test_sensor.m` (flat) | 9 | Mirror changes from TestSensor.m |
| `test_sensor_resolve.m` (flat) | 7 | Mirror TestSensorResolve.m changes |
| `test_resolve_segments.m` (flat) | 5 | Mirror |
| `test_declarative_condition.m` (flat) | 6 | Mirror |
| `test_incremental_detector.m` (flat) | 3 | Mirror |
| `test_live_pipeline.m` (flat) | 3 | Mirror |
| `test_detect_events_from_sensor.m` (flat) | 3 | Mirror |
| (remaining flat tests) | varies | Update sensor construction |

**New test files to create:**
- `tests/suite/TestThreshold.m` — constructor, addCondition, allValues, getConditionFields, IsUpper
- `tests/suite/TestThresholdRegistry.m` — get, register, unregister, list, findByTag, findByDirection, getMultiple, unknownKey error
- `tests/test_threshold.m` + `tests/test_threshold_registry.m` — Octave function-based mirrors

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | MATLAB unittest (matlab.unittest.TestCase) + Octave function-based |
| Config file | `tests/run_all_tests.m` |
| Quick run command | `cd /Users/hannessuhr/FastPlot && octave --no-gui tests/test_threshold.m` |
| Full suite command | `cd /Users/hannessuhr/FastPlot && matlab -batch "run_all_tests"` or Octave equivalent |

### Phase Requirements → Test Map
| ID | Behavior | Test Type | Automated Command | File Exists? |
|----|----------|-----------|-------------------|-------------|
| — | Threshold constructor + properties | unit | `tests/suite/TestThreshold.m` | ❌ Wave 0 |
| — | ThresholdRegistry get/register/unregister/list | unit | `tests/suite/TestThresholdRegistry.m` | ❌ Wave 0 |
| — | ThresholdRegistry findByTag/findByDirection | unit | `tests/suite/TestThresholdRegistry.m` | ❌ Wave 0 |
| — | Sensor.addThreshold (object path) | unit | `TestSensor.m` (modified) | update existing |
| — | Sensor.addThreshold (key string path) | unit | `TestSensor.m` (modified) | update existing |
| — | Sensor.addThreshold duplicate rejection | unit | `TestSensor.m` (modified) | update existing |
| — | Sensor.removeThreshold | unit | `TestSensor.m` (modified) | update existing |
| — | Sensor.resolve() with Threshold (unconditional) | unit | `TestSensorResolve.m` (modified) | update existing |
| — | Sensor.resolve() with Threshold + StateChannel | unit | `TestResolveSegments.m` (modified) | update existing |
| — | Sensor.currentStatus() with Thresholds | unit | `TestSensor.m` (modified) | update existing |
| — | IncrementalEventDetector with Thresholds | integration | `TestIncrementalDetector.m` (modified) | update existing |
| — | Dashboard widgets render with Thresholds | integration | `TestStatusWidget.m`, `TestGaugeWidget.m` (modified) | update existing |

### Sampling Rate
- **Per task commit:** Run modified suite file relevant to that task
- **Per wave merge:** `run_all_tests` full suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/suite/TestThreshold.m` — covers Threshold constructor, addCondition, allValues, getConditionFields, IsUpper
- [ ] `tests/suite/TestThresholdRegistry.m` — covers full registry API
- [ ] `tests/test_threshold.m` — Octave-compatible function-based mirror
- [ ] `tests/test_threshold_registry.m` — Octave-compatible function-based mirror

---

## Open Questions

1. **Value property on Threshold for single-condition case**
   - What we know: Consumers like GaugeWidget.deriveRange use `cellfun(@(r) r.Value, sensor.ThresholdRules)`. After migration all values live inside conditions.
   - What's unclear: Should `Threshold` expose a `Value` property as syntactic sugar when only one condition exists, or always require `allValues()`?
   - Recommendation: Add `allValues()` method. Do NOT add a `Value` shortcut — it breaks the model for multi-condition thresholds and the ambiguity will cause bugs.

2. **Threshold.Label vs Threshold.Name**
   - What we know: ThresholdRule has `.Label`. Downstream consumers (EventViewer, buildThresholdEntry) read `.Label`. Threshold uses `.Name` (D-03).
   - What's unclear: Should Threshold also expose `.Label` as an alias for `.Name`?
   - Recommendation: Expose `Label` as a `Dependent` property returning `obj.Name`. This minimises changes in `buildThresholdEntry` and plotting code that already reads `.Label` from resolved threshold structs. The resolved struct format (`buildThresholdEntry` output) uses `.Label` — that stays unchanged.

3. **EventViewer rebuild of sensor for click-to-plot**
   - What we know: EventViewer line 733 calls `sensor.addThresholdRule(struct(), r.Value, args{:})` to reconstruct a sensor for display. After migration it has access to the original Threshold objects via `sensor.Thresholds`.
   - What's unclear: EventViewer stores `sd.thresholdRules` (a local struct array, not ThresholdRule objects) — see line 725. It rebuilds from stored display data, not from live sensor.
   - Recommendation: Investigate EventViewer's `sd` struct construction (around line 700-735) before writing the plan. The fix may be to store Threshold keys in `sd` and re-fetch from ThresholdRegistry, or to store the Threshold handles directly.

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — pure MATLAB code refactor, all tools already verified operational in Phase 1000).

---

## Sources

### Primary (HIGH confidence)
- Direct source read: `libs/SensorThreshold/Sensor.m` — full resolve() algorithm, ThresholdRules property, addThresholdRule method
- Direct source read: `libs/SensorThreshold/ThresholdRule.m` — value class structure, CachedConditionKey, IsUpper, matchesState
- Direct source read: `libs/SensorThreshold/SensorRegistry.m` — exact pattern to mirror for ThresholdRegistry
- Direct source read: `libs/SensorThreshold/StateChannel.m` — condition evaluation reused unchanged
- Direct source read: `libs/SensorThreshold/private/buildThresholdEntry.m` — reads rule.Direction/Label/Color/LineStyle/Value
- Direct source read: `libs/SensorThreshold/private/conditionKey.m` — canonical key generation reused unchanged
- Direct source grep: all ThresholdRule/ThresholdRules/addThresholdRule references across Dashboard, EventDetection, SensorThreshold (147 occurrences, 34 files)
- Direct source read: `libs/Dashboard/GaugeWidget.m` lines 170-203 — uses ThresholdRules for range derivation and color
- Direct source read: `libs/EventDetection/IncrementalEventDetector.m` lines 60-88 — copies ThresholdRules to temp sensor

### Secondary (MEDIUM confidence)
- CONTEXT.md decisions D-01 through D-17 — locked decisions verified against source code for feasibility
- STATE.md accumulated context — confirms ThresholdRegistry architecture fits established registry pattern

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all patterns read directly from source, no external dependencies
- Architecture: HIGH — resolve() algorithm fully understood, migration path is clear
- Downstream consumers: HIGH — exhaustive grep found all 34 files with 147 references
- Test migration: HIGH — all affected test files identified by name with change type
- Pitfalls: HIGH — each pitfall derived from direct code inspection of affected files

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (stable codebase, no fast-moving external dependencies)
