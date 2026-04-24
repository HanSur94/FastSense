# Phase 1002: Direct Widget-Threshold Binding - Research

**Researched:** 2026-04-06
**Domain:** MATLAB Dashboard widget extension — standalone Threshold binding without Sensor
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** New `Threshold` property on each supported widget alongside existing `Sensor` property
- **D-02:** Widget checks Threshold first, falls back to Sensor path (additive, not replacing)
- **D-03:** Current value comes from new `Value` property (manual) or `ValueFcn` callback (live)
- **D-04:** Supported widgets: StatusWidget, GaugeWidget, MultiStatusWidget, ChipBarWidget, IconCardWidget
- **D-05:** StatusWidget derives ok/warning/alarm from Value + Threshold conditions using the same logic as the Sensor path but with a different value source
- **D-06:** Constructor syntax: `StatusWidget('Threshold', t, 'Value', 42)` or `StatusWidget('Threshold', 'temp_hh', 'ValueFcn', @() readTemp())`
- **D-07:** Threshold property accepts both Threshold objects and registry key strings (like Sensor.addThreshold)
- **D-08:** Sensor and standalone Threshold are mutually exclusive on a widget — setting one clears the other
- **D-09:** ValueFcn is called on each DashboardEngine live tick via widget.refresh()
- **D-10:** Threshold-only widgets serialize threshold key in JSON: `"threshold": "temp_hh"`
- **D-11:** On load, threshold resolved from ThresholdRegistry
- **D-12:** Zero changes to existing Sensor-bound widget behavior — Threshold binding is purely additive

### Claude's Discretion
- Internal implementation of the dual Sensor/Threshold path in each widget
- How ValueFcn integrates with existing refresh() lifecycle
- Error handling for missing ThresholdRegistry keys on load
- DashboardBuilder convenience methods (if any)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

## Summary

Phase 1002 adds a `Threshold` property to five dashboard widgets (StatusWidget, GaugeWidget,
MultiStatusWidget, ChipBarWidget, IconCardWidget) so they can display threshold-driven status
without requiring a `Sensor` object. A companion `Value`/`ValueFcn` property provides the
current reading. The Threshold system (Phase 1001) already provides `Threshold.allValues()`,
`Threshold.IsUpper`, and `ThresholdRegistry.get(key)` — the full violation-check logic needed
by widgets is already present and in use on the Sensor path.

The implementation is purely additive: existing Sensor-path code is untouched in every widget.
The new Threshold path mirrors it with a different value source. Serialization follows a new
`source.type = 'threshold'` convention (or a top-level `threshold` key) consistent with how
Sensor binding serializes today. On load, `ThresholdRegistry.get(key)` resolves the key — the
same one-liner already used by `Sensor.addThreshold`.

**Primary recommendation:** Follow the existing Sensor-path structure as the template for
every widget change; copy `deriveStatusFromSensor` / `getValueColor` logic to a parallel
`deriveStatusFromThreshold` / `getValueColorFromThreshold` private helper, then wire the new
path in `refresh()` after the Sensor check.

---

## Project Constraints (from CLAUDE.md)

- Pure MATLAB — no external dependencies
- Backward compatibility is mandatory — existing Sensor-bound widgets must not change behavior
- Widget contract: changes must work through `DashboardWidget` base class interface
- MISS_HIT style: PascalCase properties, camelCase methods, 160-char line limit, cyclomatic complexity ≤ 80
- Error IDs: `'WidgetName:problemName'` format
- All public properties with inline defaults on declaration
- `properties (Access = public)` for user config, `properties (SetAccess = private)` for state

---

## Standard Stack

### Core (all already present — no new dependencies)

| Component | Location | Purpose | Notes |
|-----------|----------|---------|-------|
| `Threshold` | `libs/SensorThreshold/Threshold.m` | Threshold entity with `allValues()`, `IsUpper`, `Color` | Handle class — Phase 1001 |
| `ThresholdRegistry` | `libs/SensorThreshold/ThresholdRegistry.m` | Singleton key-based catalog | `get(key)` throws `ThresholdRegistry:unknownKey` if missing |
| `DashboardWidget` | `libs/Dashboard/DashboardWidget.m` | Abstract base; `Sensor` property lives here | Constructor parses all varargin via `obj.(key) = val` |
| `DashboardSerializer` | `libs/Dashboard/DashboardSerializer.m` | JSON save/load, widget dispatch | `createWidgetFromStruct`, `configToWidgets`, `loadJSON` |

### Target Widgets

| Widget | File | Current Value Source | Status Derivation |
|--------|------|---------------------|-------------------|
| `StatusWidget` | `libs/Dashboard/StatusWidget.m` | `obj.Sensor.Y(end)` | `deriveStatusFromSensor` (private) |
| `GaugeWidget` | `libs/Dashboard/GaugeWidget.m` | `obj.Sensor.Y(end)` or `ValueFcn` | `getValueColor` (private) |
| `MultiStatusWidget` | `libs/Dashboard/MultiStatusWidget.m` | per-chip `sensor.Y(end)` | `deriveColor` (private) |
| `ChipBarWidget` | `libs/Dashboard/ChipBarWidget.m` | per-chip `sensor` or `statusFcn` | `resolveChipColor` (private) |
| `IconCardWidget` | `libs/Dashboard/IconCardWidget.m` | `obj.Sensor.Y(end)` or `ValueFcn` | `deriveStateFromSensor` (private) |

---

## Architecture Patterns

### Pattern 1: Sensor/Threshold Mutual Exclusivity via Property Set

**What:** D-08 requires that setting Threshold clears Sensor and vice versa.

**Implementation approach:** Override property setter using `set.Threshold` and `set.Sensor`
in each widget. However, MATLAB does not allow property setters on properties inherited from
a superclass (DashboardWidget.Sensor) without redeclaring them.

**Recommended approach (Claude's discretion):** Handle mutual exclusivity inside the
constructor (where varargin is parsed) and at the start of `refresh()`. Do not rely on
MATLAB property setters. The constructor already calls `obj.(key) = val` for all varargin
pairs; after parsing, add a guard:

```matlab
% In constructor, after super varargin parse:
if ~isempty(obj.Threshold_) && ~isempty(obj.Sensor)
    obj.Sensor = [];  % Threshold wins when both given
end
```

Since `DashboardWidget` parses varargin generically, any new public property declared in the
subclass is automatically settable via constructor name-value pairs — no override needed.

**Source:** Verified by reading `DashboardWidget.m` line 36-41; constructor loop
`obj.(varargin{k}) = varargin{k+1}` works on all `isprop` properties.

**Confidence:** HIGH

### Pattern 2: Threshold Property — String-or-Object Resolution

The exact pattern is already established in `Sensor.addThreshold` (lines 207-211):

```matlab
% Source: libs/SensorThreshold/Sensor.m addThreshold()
if ischar(thresholdOrKey) || isstring(thresholdOrKey)
    t = ThresholdRegistry.get(thresholdOrKey);
else
    t = thresholdOrKey;
end
```

Each widget's `Threshold` property should store the **resolved Threshold object** (not the
key string). Resolution happens at assignment time in the constructor or in a
`resolveThreshold_` private helper called from `refresh()` if `Threshold_` holds a string.
Storing the resolved object avoids repeated registry lookups on every tick.

**Recommended approach (Claude's discretion):**
- Store raw input in a private `Threshold_` property (can be char or Threshold object)
- Expose a public `Threshold` dependent property that calls `resolveThreshold_()` — or,
  simpler: resolve to Threshold object at constructor time when input is char, store in
  a public `Threshold` property with `Access = public` directly

The simpler design: store the resolved handle directly in a public `Threshold` property.
Resolve at constructor time via the same `ischar` check.

**Confidence:** HIGH

### Pattern 3: refresh() Dispatch — Check Threshold Before Sensor

Per D-02, widget refresh priority is: Threshold-path first, then Sensor-path fallback.
Current `refresh()` in StatusWidget:

```matlab
if ~isempty(obj.Sensor)
    ...deriveStatusFromSensor...
elseif ~isempty(obj.StatusFcn)
    ...
```

New order:

```matlab
if ~isempty(obj.Threshold)
    % Threshold-only path: Value/ValueFcn provides the reading
    val = obj.resolveCurrentValue_();
    if isempty(val), return; end
    [obj.CurrentStatus, obj.CurrentColor] = obj.deriveStatusFromThreshold(val, theme);
elseif ~isempty(obj.Sensor)
    ...existing Sensor path, untouched...
elseif ~isempty(obj.StatusFcn)
    ...existing legacy path...
```

**Note on ValueFcn naming:** GaugeWidget already has a `ValueFcn` property. StatusWidget and
IconCardWidget do not. The new `Value` and `ValueFcn` properties on StatusWidget/IconCardWidget
must not conflict with GaugeWidget's existing `ValueFcn`. Since each widget is a separate
class, there is no conflict — each widget owns its own property namespace.

**Confidence:** HIGH

### Pattern 4: GaugeWidget Range Auto-Derivation from Standalone Threshold

`GaugeWidget.deriveRange()` currently calls `obj.Sensor.Thresholds{i}.allValues()`. With
a standalone Threshold, range can be derived directly from `obj.Threshold.allValues()`.
This is the only place where GaugeWidget needs a new code path in its constructor:

```matlab
% In GaugeWidget constructor, after handling Sensor path:
if ~isempty(obj.Threshold) && isempty(obj.Range)
    tVals = obj.Threshold.allValues();
    if ~isempty(tVals)
        obj.Range = [min(tVals), max(tVals)];
    end
end
if isempty(obj.Range)
    obj.Range = [0 100]; % ultimate fallback
end
```

**Confidence:** HIGH

### Pattern 5: MultiStatusWidget — Parallel Item List for Thresholds

MultiStatusWidget uses `obj.Sensors` (cell array). For standalone Threshold binding, the
natural extension is a parallel `Thresholds` cell array (or mixed `Items` array). However,
per D-04, the decision is to add a `Threshold` property (singular), not a `Thresholds` list.

**Implication:** For MultiStatusWidget, standalone threshold support is per-item (inside the
chip structs), not a top-level multi-Threshold list. The cleanest approach:
- Add a `Threshold` property at the widget level for widgets that display one threshold
- For MultiStatusWidget, individual items (Sensors entries) can be extended to accept
  `{threshold, value, label}` structs as an alternative to Sensor objects

**Recommended approach (Claude's discretion):** Keep MultiStatusWidget's `Sensors` cell
array as-is but allow entries to be either Sensor objects or `struct('threshold', t,
'value', val, 'label', name)`. The `deriveColor` private method already receives the entry
— it can branch on `isstruct(sensor)` vs `isa(sensor, 'Sensor')`.

**Confidence:** HIGH (design is straightforward; risk is minimal complexity increase)

### Pattern 6: ChipBarWidget — Extend Chip Struct

ChipBarWidget chip structs already have `sensor`, `statusFcn`, `iconColor` fields.
Adding `threshold` and `value`/`valueFcn` fields to chip structs is backward compatible
since `resolveChipColor` already uses `isfield` checks. No breaking changes.

**Confidence:** HIGH

### Pattern 7: Serialization — `source.type = 'threshold'` Convention

Existing `source` field pattern in `toStruct` (from DashboardWidget base):
```matlab
% When Sensor is bound:
s.source = struct('type', 'sensor', 'name', obj.Sensor.Key);
```

New Threshold binding serializes as:
```matlab
% When Threshold is bound (widget-level Threshold, not per-chip):
s.source = struct('type', 'threshold', 'key', obj.Threshold.Key);
```

In `fromStruct`, add a `'threshold'` case alongside `'sensor'` and `'callback'`:
```matlab
case 'threshold'
    if exist('ThresholdRegistry', 'class')
        try
            obj.Threshold = ThresholdRegistry.get(s.source.key);
        catch
            warning('WidgetClass:thresholdNotFound', ...
                'Could not resolve threshold key ''%s''.', s.source.key);
        end
    end
```

For `Value` (scalar number), serialize as:
```matlab
if ~isempty(obj.Value)
    s.value = obj.Value;
end
```

`ValueFcn` function handles cannot be serialized (same limitation as existing `StatusFcn`
and `ValueFcn` on GaugeWidget — they are silently dropped, documented in comments).

**Confidence:** HIGH

### Recommended Project Structure (new properties / no new files)

No new files are required. All changes are additions within existing widget `.m` files
and `DashboardSerializer.m`. The five widget files each get:
1. Two new `properties (Access = public)` — `Threshold` and `Value` (plus `ValueFcn`
   where not already present)
2. One new private helper — `resolveCurrentValue_()` (or inlined if simple)
3. Updated `refresh()` — new first branch for Threshold path
4. Updated `toStruct()` — emit `source.type = 'threshold'` when Threshold is bound
5. Updated `fromStruct()` — handle `source.type = 'threshold'`

`DashboardSerializer.createWidgetFromStruct` needs no changes — dispatch is per `ws.type`
and each widget's `fromStruct` handles the new `source.type`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Threshold violation check | Custom value-vs-limit comparison | `Threshold.allValues()` + `Threshold.IsUpper` | Already handles multi-condition per Threshold; exact same logic in `deriveStatusFromSensor` |
| Threshold key resolution | String-to-object lookup | `ThresholdRegistry.get(key)` | Throws `ThresholdRegistry:unknownKey` with helpful message |
| Color from violation state | Manual RGB assignment | Copy `getValueColor` / `deriveStatusFromSensor` private helper pattern | Consistent with theme; handles `t.Color`, upper/lower, theme fallback |
| Name-value constructor parsing | Custom parser | `obj.(varargin{k}) = varargin{k+1}` loop (already in DashboardWidget base) | All subclass properties are automatically settable |

**Key insight:** The violation logic needed by all five widgets is already written in those
widgets for the Sensor path. The Threshold path needs the same loop over `t.allValues()` —
it's a 10-line private helper, not a new algorithm.

---

## Common Pitfalls

### Pitfall 1: Redeclaring Inherited `Sensor` Property
**What goes wrong:** MATLAB error if a subclass declares a property already defined in
a superclass.
**Why it happens:** `DashboardWidget` declares `Sensor`; subclasses cannot redeclare it.
**How to avoid:** Add only NEW properties (`Threshold`, `Value`, `ValueFcn`) in the
subclass `properties` block. Never redeclare `Sensor`.
**Warning signs:** MATLAB class-loading error `property 'Sensor' is already defined`.

### Pitfall 2: GaugeWidget ValueFcn Already Exists
**What goes wrong:** GaugeWidget already has `ValueFcn` declared. Adding it again causes
a duplicate-property error.
**Why it happens:** GaugeWidget owns `ValueFcn` from its original design.
**How to avoid:** Only add `Threshold` and `Value` to GaugeWidget; `ValueFcn` is already
available for the live-tick path. The `Value` property maps to GaugeWidget's `StaticValue`
— check whether using `StaticValue` directly is preferable to a new `Value` alias.
**Recommended approach:** Use `StaticValue` on GaugeWidget for consistency; add only
`Threshold` as the new property. This avoids a naming conflict and `StaticValue` is
already serialized. For StatusWidget/IconCardWidget/MultiStatusWidget/ChipBarWidget,
add `Value` (scalar) and `ValueFcn` (function handle) where not already present.

### Pitfall 3: IconCardWidget ValueFcn Already Exists
**What goes wrong:** IconCardWidget already has `ValueFcn` declared.
**How to avoid:** Same as GaugeWidget — only add `Threshold` (and `Value` if needed).
`ValueFcn` is already settable on IconCardWidget from constructor varargin.

### Pitfall 4: Mutual Exclusivity Not Enforced at Assignment Time
**What goes wrong:** User passes both `Sensor` and `Threshold` in constructor; widget
silently uses Sensor and ignores Threshold (or vice versa) without warning.
**How to avoid:** After the varargin loop in the subclass constructor, add an explicit
mutual-exclusivity guard. Issue a `warning('Widget:conflictingInput', ...)` if both are
set and clear `obj.Sensor`.

### Pitfall 5: ThresholdRegistry.get Throws on Load
**What goes wrong:** `fromStruct` calls `ThresholdRegistry.get(key)` but the registry
has not been populated yet (user forgot to register thresholds before calling
`DashboardEngine.load()`).
**Why it happens:** ThresholdRegistry starts empty; no lazy-loading mechanism exists.
**How to avoid:** Wrap `ThresholdRegistry.get(key)` in try/catch inside `fromStruct`.
Issue a `warning('WidgetClass:thresholdNotFound', ...)` and leave `Threshold = []`.
Widget renders in grey/inactive state until the threshold is registered.

### Pitfall 6: Empty allValues() on Threshold with No Conditions
**What goes wrong:** Violation loop over `t.allValues()` receives `[]`; widget stays
at default color even though a Threshold is bound.
**Why it happens:** `Threshold.allValues()` returns `[]` when `conditions_` is empty.
**How to avoid:** Guard the violation loop: `if isempty(tVals), continue; end` before
iterating conditions. Document that a bound Threshold with no conditions shows "ok" state.

### Pitfall 7: MultiStatusWidget toStruct Fully Overrides Base
**What goes wrong:** `MultiStatusWidget.toStruct()` fully overrides the base (comment
in source: "Fully override — does not use base Sensor property"). New threshold fields
must be added to this manual struct construction, not via super call.
**How to avoid:** Planner must be aware that MultiStatusWidget.toStruct starts from
`struct()` not `toStruct@DashboardWidget(obj)`. Add threshold entries in the full
override, not as an augmentation.

---

## Code Examples

### Violation Check (copy from Sensor path, reuse as Threshold path)

The existing `deriveStatusFromSensor` in StatusWidget (lines 199-239) is the template:

```matlab
% Source: libs/Dashboard/StatusWidget.m deriveStatusFromSensor (template for new path)
function [status, color] = deriveStatusFromThreshold(obj, val, theme)
    status = 'ok';
    color = theme.StatusOkColor;
    if isempty(obj.Threshold), return; end
    tVals = obj.Threshold.allValues();
    if isempty(tVals), return; end
    t = obj.Threshold;
    for v = 1:numel(tVals)
        isViolated = (t.IsUpper && val > tVals(v)) || ...
                     (~t.IsUpper && val < tVals(v));
        if isViolated
            status = 'violation';
            if ~isempty(t.Color)
                color = t.Color;
            elseif t.IsUpper
                color = theme.StatusAlarmColor;
            else
                color = theme.StatusWarnColor;
            end
        end
    end
end
```

### Value Resolution (new private helper)

```matlab
% Private helper: resolve current scalar value from Value or ValueFcn
function val = resolveCurrentValue_(obj)
    val = [];
    if ~isempty(obj.ValueFcn)
        try
            val = obj.ValueFcn();
        catch
            return;
        end
    elseif ~isempty(obj.Value)
        val = obj.Value;
    end
end
```

### Threshold Property Resolution (string-to-object)

```matlab
% Source pattern: libs/SensorThreshold/Sensor.m addThreshold()
% In widget constructor, after super varargin parse:
if ischar(obj.Threshold) || isstring(obj.Threshold)
    try
        obj.Threshold = ThresholdRegistry.get(obj.Threshold);
    catch
        warning('StatusWidget:thresholdNotFound', ...
            'ThresholdRegistry key ''%s'' not found.', obj.Threshold);
        obj.Threshold = [];
    end
end
```

### Serialization (toStruct)

```matlab
% In toStruct, replace Sensor-based source with Threshold source when applicable
if ~isempty(obj.Threshold)
    s.source = struct('type', 'threshold', 'key', obj.Threshold.Key);
elseif ~isempty(obj.Value)
    s.value = obj.Value;
end
% ValueFcn is a function handle — cannot serialize, silently omitted
```

### fromStruct Threshold Case

```matlab
% In fromStruct, extend switch on s.source.type:
case 'threshold'
    if exist('ThresholdRegistry', 'class')
        try
            obj.Threshold = ThresholdRegistry.get(s.source.key);
        catch
            warning('StatusWidget:thresholdNotFound', ...
                'Could not resolve threshold key ''%s'' on load.', s.source.key);
        end
    end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ThresholdRule` per sensor | `Threshold` first-class entity with `ThresholdRegistry` | Phase 1001 | Widgets can now bind Threshold handles directly |
| Sensor required for threshold status | Threshold-only binding (this phase) | Phase 1002 | Standalone threshold indicators |

**Phase 1001 established:**
- `Threshold.allValues()` — all condition values as numeric vector
- `Threshold.IsUpper` — cached direction flag
- `ThresholdRegistry.get(key)` — singleton key lookup with error on miss
- `addThreshold(charOrObject)` — dual-input pattern on Sensor

All of these are directly reusable in widget code without modification.

---

## Open Questions

1. **`Value` vs `StaticValue` naming for GaugeWidget**
   - What we know: GaugeWidget already has `StaticValue`; adding `Value` would be a synonym.
   - What's unclear: D-03 says "new `Value` property" — does this apply to GaugeWidget as well?
   - Recommendation: For GaugeWidget, treat `StaticValue` as the `Value` equivalent (already
     serialized, already in `refresh()`). Only add `Threshold`. This avoids a new property
     that duplicates existing behavior. Document in plan.

2. **ChipBarWidget per-chip vs widget-level Threshold**
   - What we know: ChipBarWidget uses per-chip structs; there is no single "the value".
   - What's unclear: D-04 says "ChipBarWidget" is supported — does "Threshold + Value"
     apply at the chip level (chip struct fields) or widget level?
   - Recommendation: Per-chip level. Extend chip struct with optional `threshold` and
     `value`/`valueFcn` fields, resolved in `resolveChipColor`. No widget-level `Threshold`
     property needed for ChipBarWidget.

3. **MultiStatusWidget per-item Threshold**
   - What we know: `Sensors` cell array entries drive per-item status.
   - Recommendation: Allow `Sensors` entries to be Sensor objects OR threshold-binding
     structs `struct('threshold', t, 'value', v, 'label', 'name')`.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is pure MATLAB code changes within existing project files;
no external CLI tools, services, or runtimes beyond the project baseline are required.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `matlab.unittest.TestCase` (MATLAB) + Octave function tests |
| Config file | `tests/run_all_tests.m` |
| Quick run command | `cd /Users/hannessuhr/FastPlot && octave --no-gui tests/suite/TestStatusWidget.m` (single file) |
| Full suite command | `cd /Users/hannessuhr/FastPlot && octave --no-gui tests/run_all_tests.m` |

### Phase Requirements to Test Map

| ID | Behavior | Test Type | Automated Command | File Exists? |
|----|----------|-----------|-------------------|-------------|
| D-01 | `Threshold` property settable on StatusWidget/GaugeWidget/MultiStatusWidget/ChipBarWidget/IconCardWidget | unit | `TestStatusWidget`, `TestGaugeWidget`, `TestIconCardWidget`, `TestChipBarWidget`, `TestMultiStatusWidget` | Existing — extend |
| D-02 | Threshold-path executes before Sensor-path in refresh() | unit | `TestStatusWidget.testThresholdPathPriority` | Wave 0 |
| D-03 | `Value` sets CurrentValue; `ValueFcn` called on refresh() | unit | `TestStatusWidget.testValueAndValueFcn` | Wave 0 |
| D-05 | StatusWidget derives ok/violation from Value+Threshold | unit | `TestStatusWidget.testDeriveStatusFromThreshold` | Wave 0 |
| D-06 | Constructor accepts `'Threshold', t, 'Value', 42` syntax | unit | `TestStatusWidget.testConstructorThresholdBinding` | Wave 0 |
| D-07 | Threshold property accepts char key string | unit | `TestStatusWidget.testThresholdKeyResolution` | Wave 0 |
| D-08 | Setting Threshold clears Sensor; setting Sensor clears Threshold | unit | `TestStatusWidget.testMutualExclusivity` | Wave 0 |
| D-09 | ValueFcn called on each refresh() tick | unit | `TestStatusWidget.testValueFcnLiveTick` | Wave 0 |
| D-10/D-11 | Round-trip serialization: toStruct/fromStruct with threshold key | unit | `TestStatusWidget.testSerializeThresholdKey` | Wave 0 |
| D-12 | Existing Sensor-bound tests still pass unchanged | regression | All existing TestStatusWidget/TestGaugeWidget tests | Existing — verify |

### Sampling Rate
- **Per task commit:** Run the test file for the widget(s) modified in that task
- **Per wave merge:** Full suite `tests/run_all_tests.m`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/suite/TestStatusWidget.m` — add 7 new test methods (D-02 through D-11)
- [ ] `tests/suite/TestGaugeWidget.m` — add threshold range derivation + threshold color tests
- [ ] `tests/suite/TestIconCardWidget.m` — add threshold state derivation tests
- [ ] `tests/suite/TestChipBarWidget.m` — add per-chip threshold field tests
- [ ] `tests/suite/TestMultiStatusWidget.m` — add threshold-struct item tests

*(Existing test infrastructure and class setup patterns are in place — only new test methods needed)*

---

## Sources

### Primary (HIGH confidence)
- `libs/Dashboard/StatusWidget.m` — Full source read; Sensor-path `deriveStatusFromSensor`, `refresh()` dispatch, `toStruct`/`fromStruct` structure
- `libs/Dashboard/GaugeWidget.m` — Full source read; existing `ValueFcn`, `StaticValue`, `deriveRange()`, `getValueColor()`
- `libs/Dashboard/MultiStatusWidget.m` — Full source read; `Sensors` cell array, `toStruct` full override, `deriveColor`
- `libs/Dashboard/ChipBarWidget.m` — Full source read; chip struct pattern, `resolveChipColor`, `isfield` guards
- `libs/Dashboard/IconCardWidget.m` — Full source read; existing `ValueFcn`, `StaticValue`, `deriveStateFromSensor`
- `libs/SensorThreshold/Threshold.m` — Full source read; `allValues()`, `IsUpper`, `conditions_`
- `libs/SensorThreshold/ThresholdRegistry.m` — Full source read; `get(key)`, error on miss, singleton `catalog()`
- `libs/Dashboard/DashboardWidget.m` — Full source read; base `Sensor` property, constructor varargin loop, `toStruct`
- `libs/SensorThreshold/Sensor.m` — `addThreshold()` dual-input pattern (lines 190-226)
- `libs/Dashboard/DashboardSerializer.m` — `createWidgetFromStruct` dispatch, `configToWidgets`, `loadJSON` structure
- `tests/suite/TestStatusWidget.m` — Test structure and setup patterns
- `tests/suite/TestGaugeWidget.m` — Test structure for gauge

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components read from source, no external dependencies
- Architecture: HIGH — all integration points verified from live code
- Pitfalls: HIGH — identified from direct code inspection (existing property declarations, full override toStruct, etc.)

**Research date:** 2026-04-06
**Valid until:** Stable for this milestone; Threshold/ThresholdRegistry APIs (Phase 1001) are complete
