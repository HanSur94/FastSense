# Phase 1004: Tag Foundation + Golden Test — Research

**Researched:** 2026-04-16
**Domain:** MATLAB/Octave classdef design, registry singleton pattern, two-phase JSON deserialization, integration-test fixture design
**Confidence:** HIGH on all areas (every decision has a direct, verified precedent already shipping in this codebase)

## Summary

Phase 1004 is near-zero greenfield research: every primitive needed (`containers.Map` registry, throw-from-base abstract class, name-value constructor, handle-class inheritance, JSON round-trip via structs, test dual-style infrastructure) is already shipping and battle-tested in this repo. The planner's job is combinatorial assembly, not invention.

The single highest-risk decision is the abstract-enforcement pattern: the repo has **two competing precedents** — `DashboardWidget` uses the MATLAB `methods (Abstract)` block, while `DataSource` uses throw-from-base. Only the throw-from-base pattern is verified Octave-safe per the strangler-fig research (`.planning/research/STACK.md`, `SUMMARY.md §6.1`). CONTEXT.md locks throw-from-base — research confirms this is correct; `methods (Abstract)` should **not** be used.

Second priority is the two-phase deserializer: `CompositeThreshold.fromStruct` currently has a documented ordering bug (silent `try/warning/skip` when children aren't yet registered — visible in `CompositeThreshold.m:327-333`). The fix is a static `TagRegistry.loadFromStructs(structs)` that iterates twice — first to instantiate empty, second to resolve cross-references via a per-instance `resolveRefs(registry)` hook that is a no-op on `Tag` base (CompositeTag will override in Phase 1008).

**Primary recommendation:** Follow `Threshold.m` + `ThresholdRegistry.m` verbatim for structure. Differ only where the research explicitly justifies (throw-from-base instead of Abstract block; hard-error on `register` instead of silent overwrite; two-phase loader instead of single-pass `fromStruct`). Enumerate ≤6 abstract method stubs on `Tag`, no more. Golden test lives in both `tests/suite/TestGoldenIntegration.m` AND `tests/test_golden_integration.m` (dual-runner convention).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**File Organization**
- Tag classes live alongside legacy in `libs/SensorThreshold/` during the strangler-fig window. Makes Phase 1011 deletion a pure delete, no move.
- New files: `libs/SensorThreshold/Tag.m`, `libs/SensorThreshold/TagRegistry.m`
- Golden integration test: `tests/suite/TestGoldenIntegration.m` + `tests/test_golden_integration.m` (both entry points, matching existing dual-style convention)

**Patterns Carried Forward (from Phase 1001-1003)**
- Handle class inheritance (`classdef Tag < handle`)
- Name-value constructor pattern (`Tag('key', 'Name', n, 'Labels', {...}, 'Criticality', 'safety', ...)`)
- Persistent containers.Map singleton for `TagRegistry` (identical shape to `ThresholdRegistry`)
- Error identifier pattern `TagRegistry:problemName`, `Tag:problemName`
- TDD — write `TestTag.m` + `TestTagRegistry.m` + `test_tag.m` + `test_tag_registry.m` suites first, then implement

**Abstract Method Enforcement**
- MATLAB "throw-from-base" pattern: base class methods raise `error('Tag:notImplemented', 'Subclasses must implement %s', 'methodName')`
- Subclasses override by providing concrete implementation
- **NO `abstract` keyword** (avoids Octave quirks per DataSource precedent)

**Tag Properties**
- `Key` (char, required) — validated non-empty
- `Name` (char, optional, defaults to Key)
- `Units` (char, optional, defaults to '')
- `Description` (char, optional, defaults to '')
- `Labels` (cellstr, optional, defaults to `{}`)
- `Metadata` (struct, optional, defaults to `struct()`)
- `Criticality` (enum char: `'low'|'medium'|'high'|'safety'`, defaults to `'medium'`)
- `SourceRef` (char, optional, defaults to '')

**TagRegistry API**
- `TagRegistry.register(key, tag)` — **hard error** on collision (`TagRegistry:duplicateKey`)
- `TagRegistry.get(key)` — throws `TagRegistry:unknownKey` if missing
- `TagRegistry.unregister(key)` — silent no-op on missing (matches ThresholdRegistry pattern)
- `TagRegistry.clear()` — wipe catalog
- `TagRegistry.find(predicateFn)` — cell array of matching tags
- `TagRegistry.findByLabel(label)` — label-driven lookup (port of `findByTag`)
- `TagRegistry.findByKind(kindStr)` — e.g., `'sensor'`, `'state'`, `'monitor'`, `'composite'`
- `TagRegistry.list()` — print sorted keys+names to cmd window
- `TagRegistry.printTable()` — detailed table (Key, Name, Kind, Labels, Criticality, Units)
- `TagRegistry.viewer()` — uitable GUI (Octave-safe)
- `TagRegistry.loadFromStructs(structs)` — two-phase: Pass 1 instantiate with empty children, Pass 2 wire cross-refs via `resolveRefs(registry)` hook on each tag; throws `TagRegistry:unresolvedRef` on Pass 2 failure

**Golden Integration Test**
- File: `tests/suite/TestGoldenIntegration.m` + `tests/test_golden_integration.m` wrapper
- Fixture: one `Sensor` (synthetic sinusoid), one `Threshold` (upper bound), one `CompositeThreshold` (2 children), one `EventDetector` run → assert violation count, event times, composite status
- Header comment: `% GOLDEN INTEGRATION TEST — regression guard for v2.0 Tag migration.` + `% DO NOT REWRITE without architectural review.  Modifying this test before Phase 1011 invalidates the safety net.`
- Written against legacy API only — rewritten to Tag API in Phase 1011 cleanup
- No `addpath` to Tag code in this test (legacy-only)
- Registered in both `tests/run_all_tests.m` and suite runner

### Claude's Discretion
- Exact test assertion counts and tolerances — pick representative values, keep test <200 lines
- Private helper organization within `libs/SensorThreshold/private/` if needed
- Format of `printTable`/`viewer` — follow `ThresholdRegistry.printTable` layout with a Kind column added
- Exact wording of header comments — idiomatic MATLAB docstrings matching existing classes

### Deferred Ideas (OUT OF SCOPE)
- None — discuss skipped; requirements fully specified in REQUIREMENTS.md
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TAG-01 | `Tag` abstract base (`< handle`) with ≤6 abstract-by-convention methods (`getXY()`, `valueAt(t)`, `getTimeRange()`, `getKind()`, `toStruct()`, static `fromStruct(s)`) via throw-from-base | §1 Octave-safe abstract pattern; `DataSource.m` precedent (proven Octave-safe) |
| TAG-02 | Universal properties: Key, Name, Units, Description, Labels, Metadata, Criticality, SourceRef | §7 META implementation; `Threshold.m` property/default declaration + varargin parse pattern |
| TAG-03 | `TagRegistry` singleton CRUD (`register/get/unregister/clear`) with hard-error on collision | §2 Registry singleton; `ThresholdRegistry.m` static methods + persistent `containers.Map` |
| TAG-04 | Query API (`find/findByLabel/findByKind`) | §2; `ThresholdRegistry.findByTag` + `findByDirection` as direct templates |
| TAG-05 | Introspection (`list/printTable/viewer`) — Octave-safe uitable | §2; `ThresholdRegistry.list/printTable/viewer` as direct templates |
| TAG-06 | `loadFromStructs(structs)` — **two-phase** (Pass 1 instantiate empty, Pass 2 resolve refs) | §3 Two-phase deserialization; solves documented `CompositeThreshold.fromStruct` ordering trap |
| TAG-07 | Every Tag subclass implements `toStruct()`+`fromStruct(s)`; any-depth round-trip works | §3; composite-of-composite 3-deep test required; cellstr/struct json-encode semantics verified |
| META-01 | `Tag.Labels` (cell of strings) — flat cross-cutting classification | §7; mirrors existing `Threshold.Tags` (which is cellstr); renamed to avoid class-name collision |
| META-02 | `TagRegistry.findByLabel(label)` — port of `ThresholdRegistry.findByTag` | §2, §7; identical iteration pattern on `containers.Map` |
| META-03 | `Tag.Metadata` (struct) — open key-value bag | §7; plain struct, no validation needed (future-proof for Asset milestone) |
| META-04 | `Tag.Criticality` enum (`low|medium|high|safety`) — drives widget/event color downstream | §7; `CompositeThreshold.set.AggregateMode` as enum-validation template |
| MIGRATE-01 | Golden integration test written against current Sensor/Threshold API; stays green through all phases | §4 Golden integration test design; `test_event_integration.m` precedent |
| MIGRATE-02 | Strangler-fig ≤20-file budget; no legacy-class edits | §8 File-touch inventory; 17-file budget holds with margin |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Directly applicable to Phase 1004:

- **Tech stack**: Pure MATLAB (no external dependencies) — no new toolboxes allowed
- **Backward compatibility**: Existing dashboard scripts and serialized dashboards must continue to work — legacy `Sensor`/`Threshold`/`CompositeThreshold` untouched
- **Widget contract**: New features must work through existing `DashboardWidget` base class interface — not relevant this phase; no widget changes
- **Performance**: Detached live-mirrored widgets must not degrade dashboard refresh rate — not relevant this phase; Tag foundation has no hot-path consumers yet
- **Runtime**: MATLAB R2020b+ AND GNU Octave 7+ both must work — **enforces throw-from-base over `methods (Abstract)`**
- **Forbidden**: `arguments` blocks, `enumeration`, `events`/listeners, `matlab.mixin.*`, `dictionary` (per `SUMMARY.md §4` stack exclusions)
- **Naming**: PascalCase classes, camelCase methods, PascalCase public properties, trailing-underscore private, `ClassName:camelCaseProblem` error IDs
- **Line length**: 160 chars max (MISS_HIT enforced)
- **Error handling**: Every `error()` call uses namespaced `ClassName:problemName` IDs
- **Testing**: Dual-style — `tests/suite/TestX.m` (MATLAB) + `tests/test_x.m` (Octave function-based)
- **GSD workflow**: All edits go through `/gsd:plan-phase` then `/gsd:execute-phase` — this research will feed the planner

## Section 1 — Octave-Safe Abstract Class Pattern

### The precedent conflict

The codebase has two competing abstract-class patterns:

| Pattern | File | Octave status | Used in v2.0? |
|---------|------|----------------|---------------|
| `methods (Abstract)` block | `libs/Dashboard/DashboardWidget.m:144-148` | **Partial** — parsed on Octave but enforcement semantics differ from MATLAB | NO |
| Throw-from-base | `libs/EventDetection/DataSource.m:12-15` | **Full** — works identically on both | YES |

**Why the discrepancy:** DashboardWidget's Abstract block only works on Octave because `MockDashboardWidget` (the only concrete subclass in tests) overrides all three methods. An inheritance chain that instantiates the base directly would diverge between interpreters — MATLAB throws at class-definition time, Octave throws at call time. `DataSource` sidesteps this entirely by instantiating freely and failing only when the unimplemented method is actually called.

**Research decision (already locked in CONTEXT.md):** Use throw-from-base. This is the pattern endorsed by `PITFALLS.md §"Octave compatibility"` and `SUMMARY.md §6.1`, both HIGH confidence.

### Canonical pattern

```matlab
classdef Tag < handle
    %TAG Abstract base for the unified Tag domain model.
    %   Subclasses must implement: getXY(), valueAt(t), getTimeRange(),
    %   getKind(), toStruct().  Subclasses must also provide a static
    %   fromStruct(s) method.
    %
    %   Serialization:
    %     Subclasses MAY override resolveRefs(registry) when they hold
    %     references to other tags (e.g., CompositeTag children).  The
    %     default is a no-op and is safe for leaf tags.
    %
    %   See also TagRegistry.

    properties
        Key = ''           % char: unique identifier
        Name = ''          % char: human-readable name (defaults to Key if empty)
        Units = ''         % char: measurement unit
        Description = ''   % char: free-text description
        Labels = {}        % cellstr: cross-cutting classification
        Metadata = struct()% struct: open key-value bag
        Criticality = 'medium' % char: 'low'|'medium'|'high'|'safety'
        SourceRef = ''     % char: optional provenance string
    end

    methods
        function obj = Tag(key, varargin)
            if nargin < 1 || isempty(key) || ~ischar(key)
                error('Tag:invalidKey', 'Key must be a non-empty char.');
            end
            obj.Key = key;
            obj.Name = key;  % Default Name = Key

            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Name',        obj.Name = varargin{i+1};
                    case 'Units',       obj.Units = varargin{i+1};
                    case 'Description', obj.Description = varargin{i+1};
                    case 'Labels',      obj.Labels = varargin{i+1};
                    case 'Metadata',    obj.Metadata = varargin{i+1};
                    case 'Criticality', obj.Criticality = varargin{i+1};
                    case 'SourceRef',   obj.SourceRef = varargin{i+1};
                    otherwise
                        error('Tag:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end

        function set.Criticality(obj, v)
            %SET.CRITICALITY Validate enum before assigning.
            valid = {'low', 'medium', 'high', 'safety'};
            if ~any(strcmp(v, valid))
                error('Tag:invalidCriticality', ...
                    'Criticality must be one of: %s. Got: ''%s''.', ...
                    strjoin(valid, ', '), v);
            end
            obj.Criticality = v;
        end

        % ---- Abstract-by-convention (throw-from-base) ----

        function [X, Y] = getXY(obj) %#ok<STOUT,MANU>
            error('Tag:notImplemented', 'Subclass must implement getXY().');
        end

        function v = valueAt(obj, t) %#ok<STOUT,INUSD>
            error('Tag:notImplemented', 'Subclass must implement valueAt(t).');
        end

        function [tMin, tMax] = getTimeRange(obj) %#ok<STOUT,MANU>
            error('Tag:notImplemented', 'Subclass must implement getTimeRange().');
        end

        function k = getKind(obj) %#ok<STOUT,MANU>
            error('Tag:notImplemented', 'Subclass must implement getKind().');
        end

        function s = toStruct(obj) %#ok<STOUT,MANU>
            error('Tag:notImplemented', 'Subclass must implement toStruct().');
        end

        % ---- Default serialization hooks ----

        function resolveRefs(obj, registry) %#ok<INUSD>
            %RESOLVEREFS Pass-2 hook for two-phase deserialization.
            %   Default: no-op.  CompositeTag will override to wire up
            %   children by key.  Leaf tags (Sensor/State/Monitor) do
            %   not need references resolved.
        end
    end

    methods (Static)
        function obj = fromStruct(s) %#ok<STOUT,INUSD>
            error('Tag:notImplemented', ...
                'fromStruct must be provided by a concrete Tag subclass.');
        end
    end
end
```

**Method count check: 5 instance-abstract (`getXY`, `valueAt`, `getTimeRange`, `getKind`, `toStruct`) + 1 static-abstract (`fromStruct`) = 6 abstract-by-convention methods. Exactly meets the Pitfall 1 budget.**

`resolveRefs` is **not** abstract-by-convention — it has a meaningful default (no-op) that works for every leaf tag. Counting it toward the budget would force every subclass to stub it.

### Gotchas

- **`%#ok<STOUT>`** is required when a function has a declared output but throws before assignment, otherwise MISS_HIT flags an "output never assigned" warning. `%#ok<MANU>` for methods that do not use `obj`; `%#ok<INUSD>` for unused arguments.
- **Do not put `methods (Abstract)` anywhere in Tag.m.** Even as a parallel declaration, it changes Octave's class-definition-time semantics.
- **`error()` in a static method must be fully qualified** with an ID; otherwise Octave emits a different error class than MATLAB and `verifyError('Tag:notImplemented')` tests fail asymmetrically.

**Confidence:** HIGH. Verified against `DataSource.m` (shipping Octave-safe pattern) and `SUMMARY.md §6.1`.

## Section 2 — Registry Singleton Pattern

### Canonical template: `ThresholdRegistry.m` line-by-line

`TagRegistry` is a near-verbatim copy of `ThresholdRegistry` with three deltas:

| Delta | Reason |
|-------|--------|
| `register` hard-errors on collision | META-01 decision; Pitfall 7 (prevents silent overwrite) |
| `loadFromStructs(structs)` added as new static method | TAG-06 (two-phase deserialization) |
| `findByKind` replaces `findByDirection` | Tag is multi-kind (sensor/state/monitor/composite), not binary |

### Persistent map singleton

The pattern is proven Octave-safe (`ThresholdRegistry.catalog()` lines 301-318, `SensorRegistry.catalog()` lines 226-259, plus 9 other `containers.Map` usage sites in the codebase — grep confirms full ecosystem support):

```matlab
function map = catalog()
    persistent cache;
    if isempty(cache)
        cache = containers.Map();  % Octave-safe; no KeyType needed for char keys
        % Catalog starts EMPTY — users populate via register()
    end
    map = cache;
end
```

**Octave compatibility note:** `containers.Map()` (no args) defaults to `KeyType='char', ValueType='any'` and is supported Octave 7+. `ExternalSensorRegistry.m:25` uses explicit KeyType — both forms work. Prefer the no-args form to match `ThresholdRegistry` exactly.

### Hard-error on duplicate register

CONTEXT.md locks this — the codebase's `ThresholdRegistry.register` actually silently overwrites (line 89: `m(key) = t;`). That is the historical behavior but Pitfall 7 explicitly flags it as a latent bug. TagRegistry fixes this:

```matlab
function register(key, tag)
    %REGISTER Add a Tag to the catalog; hard error on collision.
    if ~isa(tag, 'Tag')
        error('TagRegistry:invalidType', ...
            'Value must be a Tag object, got %s.', class(tag));
    end
    m = TagRegistry.catalog();
    if m.isKey(key)
        existing = m(key);
        error('TagRegistry:duplicateKey', ...
            'Key ''%s'' already registered (existing kind=''%s'', new kind=''%s''). Call unregister(key) first to replace.', ...
            key, existing.getKind(), tag.getKind());
    end
    m(key) = tag;
end
```

### findByLabel / findByKind

`findByLabel` is a 1:1 port of `ThresholdRegistry.findByTag` (lines 240-263). `findByKind` is identical except it calls `tag.getKind()` instead of inspecting `t.Tags`:

```matlab
function ts = findByKind(kind)
    map = TagRegistry.catalog();
    keys = map.keys();
    ts = {};
    for i = 1:numel(keys)
        t = map(keys{i});
        if strcmp(t.getKind(), kind)
            ts{end+1} = t; %#ok<AGROW>
        end
    end
end
```

**Note:** `getKind()` is a virtual method — in Phase 1004 no concrete subclass exists so `findByKind` can only be called if the registry is empty OR if user code creates ad-hoc Tag subclasses in tests. This is fine; the method is tested by registering a Mock subclass (see Section 5).

### viewer() — Octave-safe uitable

`ThresholdRegistry.viewer()` (lines 182-238) is already Octave-safe — `uitable` with `'Parent'`, `'Data'`, `'ColumnName'`, `'ColumnWidth'` is supported Octave 5+. Copy the structure verbatim; adjust column list to `{Key, Name, Kind, Criticality, Units, Labels}` (swap `Direction`→`Kind`, `#Conditions`→`Criticality`).

**Confidence:** HIGH. Direct codebase read; 11 `containers.Map` call sites all working on both runtimes; `uitable` usage shipping in `SensorRegistry.viewer` and `ThresholdRegistry.viewer` today.

## Section 3 — Two-Phase Deserialization

### The trap in `CompositeThreshold.fromStruct`

Read `libs/SensorThreshold/CompositeThreshold.m:276-334`. The function calls `ThresholdRegistry.get(key)` for each child inside `addChild`. If the parent composite is deserialized before its children, `addChild` catches the missing-key error and emits a silent warning:

```matlab
try
    obj.addChild(c.key, childArgs{:});
catch me
    warning('CompositeThreshold:loadChildFailed', ...
        'Could not resolve child key ''%s'': %s', c.key, me.message);
end
```

`TestCompositeThreshold.testFromStructMissingChildKeyWarns` (line 297-308) exercises this warning path — confirming the bug is currently accepted behavior. **Pitfall 8 requires TagRegistry to not repeat this mistake.**

### The two-phase algorithm

```
loadFromStructs(structs):
  Pass 1 — Instantiate:
    For each struct s in structs:
      tag = dispatchByKind(s).fromStruct(s)   % creates tag with EMPTY children
      catalog.register(tag.Key, tag)

  Pass 2 — Resolve refs:
    For each key in catalog.keys():
      tag = catalog.get(key)
      tag.resolveRefs(registry)  % CompositeTag overrides; others no-op

    If any resolveRefs throws, bubble up as TagRegistry:unresolvedRef with
    the original exception chained as cause.
```

### `dispatchByKind` strategy

Phase 1004 ships only `Tag` + `TagRegistry`. `loadFromStructs` still needs to know how to instantiate — the dispatcher is a static helper that reads `s.kind` (or `s.type` for pre-existing shapes) and calls the right `fromStruct`:

```matlab
function tag = instantiateByKind(s)
    kind = lower(s.kind);
    switch kind
        case 'sensor',    tag = SensorTag.fromStruct(s);      % Phase 1005
        case 'state',     tag = StateTag.fromStruct(s);       % Phase 1005
        case 'monitor',   tag = MonitorTag.fromStruct(s);     % Phase 1006/1007
        case 'composite', tag = CompositeTag.fromStruct(s);   % Phase 1008
        otherwise
            error('TagRegistry:unknownKind', ...
                'Unknown tag kind ''%s''.  Valid: sensor|state|monitor|composite.', kind);
    end
end
```

**Phase 1004 reality:** None of these subclasses exist yet. `loadFromStructs` in Phase 1004 is **testable with a MockTag** — the researcher recommends adding `tests/suite/MockTag.m` (pattern: `tests/suite/MockDashboardWidget.m`) so `TestTagRegistry` can exercise both `register` and `loadFromStructs` without waiting on Phase 1005.

### `resolveRefs(registry)` contract

- **Default (on `Tag` base):** no-op, no error. Safe for any leaf.
- **CompositeTag (Phase 1008)** will override: iterate `children_` structs (stored as `{key, weight}` pairs, not handles), look up each key in `registry`, replace the struct with a handle reference. If a key is missing, throw `CompositeTag:unresolvedChild`.
- **Phase 1004 verification:** `TestTagRegistry.testLoadFromStructs` uses two MockTags and asserts that `resolveRefs` is called on each (via a test-side spy flag). No CompositeTag needed.

### JSON encode/decode semantics

`jsonencode`/`jsondecode` are Octave-safe from Octave 7.0 onwards (they are builtin; no package required). Gotchas:

- `jsondecode` returns a **struct array** (not cell-of-structs) when the JSON is a homogeneous array. `CompositeThreshold.fromStruct` already normalizes this (lines 308-316). `TagRegistry.loadFromStructs` must do the same.
- `cellstr` round-trips to a JSON array of strings fine. On decode, it becomes a cell array of char (MATLAB) or cell of char (Octave) — identical for this use case.
- `struct()` with no fields round-trips as `{}` (empty JSON object). On decode, it becomes `struct()` with `isempty(fieldnames(...))` true.
- Empty cellstr `{}` encodes as `[]` in JSON and decodes back as `{}` (in MATLAB) or `[]` (in Octave). **Guard this on decode** — normalize any `[]` received on `Labels` back to `{}`.

**Confidence:** HIGH for encode/decode semantics (direct codebase use in `DashboardSerializer`); MEDIUM on `jsondecode` empty-cell edge case (minor normalization required — documented above).

## Section 4 — Golden Integration Test Design

### Minimum viable fixture

The golden test exercises the **full live-pipeline path** from raw data through composite status:

```
Synthetic sinusoid Sensor (X = 1:N, Y = sin-like)
  └─ Threshold (upper bound, value crosses threshold 3x)
  └─ CompositeThreshold (AND of 2 children: press_hi + temp_hi)
  └─ EventDetector (MinDuration=0 for simplicity)
  └─ detectEventsFromSensor(s) → asserts
```

**Assertion menu** (all against legacy APIs — unchanged by Phase 1004):

| Assertion | Target |
|-----------|--------|
| `numel(fp.Lines) == 1` after `fp.addSensor(s)` | FastSense data-binding |
| `numel(fp.Thresholds) >= 1` after resolve | Threshold rendering |
| `s.countViolations() == <expected>` | resolve() correctness |
| `events(1).StartTime == <expected>` | EventDetector correctness |
| `events(1).PeakValue == <expected>` | Stat extraction |
| `composite.computeStatus() == 'alarm'` | CompositeThreshold AND mode |
| `sensor.currentStatus() == 'warning'` or `'alarm'` | Status derivation |

### Exemplar (based on existing `test_event_integration.m`)

```matlab
function test_golden_integration()
% GOLDEN INTEGRATION TEST — regression guard for v2.0 Tag migration.
% DO NOT REWRITE without architectural review.  Modifying this test
% before Phase 1011 invalidates the safety net across the entire
% Tag-based domain model migration.
%
% Written against the legacy Sensor/Threshold/CompositeThreshold/
% EventDetector API as of Phase 1003.  Will be rewritten to the Tag
% API exactly once, in Phase 1011 cleanup.

    add_golden_path();
    ThresholdRegistry.clear();

    % --- Fixture: one sensor with a sinusoid that crosses threshold twice ---
    s = Sensor('press_a', 'Name', 'Pressure A', 'Units', 'bar');
    s.X = 1:20;
    s.Y = [5 5 5 12 14 16 14 5 5 5 5 5 18 20 22 5 5 5 5 5];

    sc = StateChannel('machine');
    sc.X = 1; sc.Y = 1;
    s.addStateChannel(sc);

    tHi = Threshold('press_hi', 'Name', 'Pressure High', 'Direction', 'upper');
    tHi.addCondition(struct('machine', 1), 10);
    s.addThreshold(tHi);
    s.resolve();

    % --- Golden assertion 1: resolve correctness ---
    assert(s.countViolations() > 0, 'golden: violations detected');

    % --- Golden assertion 2: event detection ---
    events = detectEventsFromSensor(s);
    assert(numel(events) == 2, 'golden: two events detected');
    assert(events(1).StartTime == 4, 'golden: first event start');
    assert(events(1).PeakValue == 16, 'golden: first event peak');
    assert(events(2).PeakValue == 22, 'golden: second event peak');

    % --- Golden assertion 3: composite status (AND mode) ---
    tLo = Threshold('temp_hi', 'Direction', 'upper');
    tLo.addCondition(struct(), 80);
    comp = CompositeThreshold('pump_a_health', 'AggregateMode', 'and');
    comp.addChild(tHi, 'Value', 15);   % above 10 -> alarm leg
    comp.addChild(tLo, 'Value', 50);   % below 80 -> ok leg
    assert(strcmp(comp.computeStatus(), 'alarm'), 'golden: AND with one leg alarm -> alarm');

    % --- Golden assertion 4: FastSense rendering ---
    fp = FastSense();
    fp.addSensor(s);
    assert(numel(fp.Lines) == 1, 'golden: one line after addSensor');

    ThresholdRegistry.clear();
    fprintf('    All 7 golden_integration tests passed.\n');
end

function add_golden_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
```

### Dual-runner wiring

- **Suite version** (`tests/suite/TestGoldenIntegration.m`): single `classdef TestGoldenIntegration < matlab.unittest.TestCase` with one `methods (Test)` function `testGoldenIntegration` that performs the same assertions via `testCase.verifyEqual`. `TestClassSetup.addPaths` calls `install()` as always.
- **Flat version** (`tests/test_golden_integration.m`): function-style, one `function test_golden_integration()` (shown above). Octave subprocess runner picks it up automatically from `dir(test_dir, 'test_*.m')` in `run_all_tests.m:77`.
- **Registration in `run_all_tests.m`:** zero code changes required — both runners auto-discover.

**Header comment wording** (exact; lock to prevent drift):

```
% GOLDEN INTEGRATION TEST — regression guard for v2.0 Tag migration.
% DO NOT REWRITE without architectural review.  Modifying this test
% before Phase 1011 invalidates the safety net across the entire
% Tag-based domain model migration.
%
% Written against the legacy Sensor/Threshold/CompositeThreshold/
% EventDetector API as of Phase 1003.  Will be rewritten to the Tag
% API exactly once, in Phase 1011 cleanup.
```

**Confidence:** HIGH. Template follows `test_event_integration.m:1-53` + `TestAddSensor.m:1-67` directly.

## Section 5 — Existing Test Infrastructure

### Dual-style pattern

Per `TESTING.md:59-84`:
- MATLAB primary: class-based in `tests/suite/Test*.m`, auto-discovered by `TestSuite.fromFolder(suite_dir)` (line `run_all_tests.m:34`)
- Octave primary: function-based in `tests/test_*.m`, auto-discovered by `dir(test_dir, 'test_*.m')` (line `run_all_tests.m:77`)
- Octave runs each test in a subprocess (line 102) to survive `break_closure_cycles` crashes in Octave 8.x
- Tests are NOT registered anywhere — auto-discovery alone

### Phase 1004 needs 4 new test files

1. `tests/suite/TestTag.m` — unit tests for `Tag` base class (constructor validation, property defaults, enum validation, throw-from-base on abstract methods)
2. `tests/suite/TestTagRegistry.m` — unit tests for `TagRegistry` (register/get/unregister/clear; collision; findByLabel; findByKind; loadFromStructs; two-phase ref resolution)
3. `tests/test_tag.m` — Octave port of TestTag
4. `tests/test_tag_registry.m` — Octave port of TestTagRegistry

Plus one shared test helper:

5. `tests/suite/MockTag.m` — minimal concrete Tag subclass for testing. Mirrors `MockDashboardWidget.m`. Implements all 6 abstract methods minimally (e.g., `getKind()` returns `'mock'`; `toStruct()` returns `struct('kind','mock','key',obj.Key)`; static `fromStruct(s)` returns `MockTag(s.key)`).

Plus the golden test files (already counted in CONTEXT):

6. `tests/suite/TestGoldenIntegration.m`
7. `tests/test_golden_integration.m`

### Existing test-class patterns to copy

- **TestClassSetup pattern** (every test file): `addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..')); install();` (`TestCompositeThreshold.m:5-9`)
- **Registry-clear teardown** (critical for test isolation): `methods (TestMethodTeardown) function clearRegistry(testCase); ThresholdRegistry.clear(); end end` (`TestCompositeThreshold.m:11-15`). TestTagRegistry **must** do `TagRegistry.clear()` to avoid cross-test pollution.
- **Error testing**: `testCase.verifyError(@() fn(), 'ErrorID:subid')` (`TestCompositeThreshold.m:216`, `TESTING.md:289-299`)
- **Warning testing**: `testCase.verifyWarning(@() fn(), 'WarningID:subid')` (`TestCompositeThreshold.m:51`, `TESTING.md:298`)
- **Octave function-style wrapper**: each test file has a local `add_*_path()` helper that reproduces `addpath + install()` (see `test_composite_threshold.m`, `test_event_integration.m`)

### MockTag placement

`MockTag.m` lives in `tests/suite/` (matches `MockDashboardWidget.m`). **It is already on the path after `install()` runs** because `install.m:54-58` recursively addpaths `tests/` (`genpath(d)`). Octave function-style tests will see it automatically in the subprocess.

**Confidence:** HIGH. Verified against `run_all_tests.m:30-34`, `run_all_tests.m:77`, `install.m:54-58`, and `MockDashboardWidget.m`.

## Section 6 — MATLAB/Octave `classdef` Edge Cases

### Static methods + persistent variables

Fully supported Octave 7+; proven via `ThresholdRegistry.catalog`, `SensorRegistry.catalog`, `DataSourceMap`, `IncrementalEventDetector.sensorState_`, etc. (11 call sites total). No gotchas.

### Handle vs value class semantics

- `Tag < handle` — pass-by-reference. Edits to properties via method calls persist. Required for registry semantics (`reg.get('k').Name = 'new'` must persist).
- **Octave `isequal` on handles differs** from MATLAB. MATLAB compares identity by default; Octave walks property contents (reference-deep). `CompositeThreshold.m:155` uses `isequal(t, obj)` specifically to get Octave-safe self-reference detection. Phase 1004 **does not** need this (no composite children yet), but the comment and pattern remain valuable for Phase 1008.
- **`==` operator on handles** works differently: MATLAB returns identity bool, Octave may not overload it. Prefer `isequal(a, b)` for cross-runtime handle comparison in Phase 1008+.

### Name-value arg parsing

Three patterns in codebase; use **Pattern 1 (switch/case over varargin)** to match `Threshold.m:106-126` exactly:

```matlab
for i = 1:2:numel(varargin)
    switch varargin{i}
        case 'Name',        obj.Name = varargin{i+1};
        ...
        otherwise
            error('Tag:unknownOption', 'Unknown option ''%s''.', varargin{i});
    end
end
```

**Do not use** `inputParser` (pattern 2 — slower, verbose, partial-match surprises) or `parseOpts` (pattern 3 — internal FastSense private, not re-exposed).

### Struct round-trip via `jsonencode/jsondecode`

- `jsonencode(struct)` → char of JSON; requires no recursive special handling for scalar primitives, cells of char, and nested struct
- `jsondecode(jsonChar)` → struct (may need normalization for struct-array vs cell-of-struct; see `CompositeThreshold.m:308-316`)
- **Avoid** `loadjson/savejson` (JSONLab) — third-party, not a dependency

### Empty struct field quirks

`isfield(s, 'labels') && ~isempty(s.labels)` is the portable idiom. MATLAB R2024a+ added `isfield` multi-field query; don't use that (R2020b floor). Octave supports single-field `isfield` identically.

### `%#ok<...>` MISS_HIT pragmas used in Tag.m

- `%#ok<STOUT>` — declared output not assigned (throw-from-base methods)
- `%#ok<MANU>` — `obj` not used in method body
- `%#ok<INUSD>` — input argument unused (e.g., `t` in default `valueAt(obj, t)`)
- `%#ok<AGROW>` — iteratively growing cell array (findByLabel)

### Property defaults

`Threshold.m:51-60` declares properties WITHOUT inline defaults (defaults set in constructor). `DashboardWidget.m:11-20` declares properties WITH inline defaults (e.g., `Title = ''`). **Either works on both runtimes.** Prefer inline defaults for Tag (matches newer DashboardWidget style, less constructor noise):

```matlab
properties
    Key = ''
    Name = ''
    ...
end
```

**Confidence:** HIGH. Every edge case has a shipping precedent in the codebase.

## Section 7 — META Implementation

### Labels (cellstr)

Direct port of `Threshold.Tags` (property `Tags` in `Threshold.m:59`, rendered in `ThresholdRegistry.findByTag:240-263`). Only difference: rename `Tags` → `Labels` to avoid collision with the class name `Tag`.

- Type: `cell` of `char`
- Default: `{}`
- Validation: minimal — trust caller (matches `Threshold.Tags`)
- `findByLabel(label)`: `any(strcmp(t.Labels, label))` (line 259 of ThresholdRegistry)

### Metadata (struct)

Open key-value bag. No validation, no type coercion. Default: `struct()` (an "empty" struct with no fields). Tests:

```matlab
t = Tag('k');
t.Metadata.asset = 'pump-3';
t.Metadata.vendor = 'Acme';
assert(strcmp(t.Metadata.asset, 'pump-3'));
assert(isempty(fieldnames(Tag('other').Metadata)));  % default empty
```

### Criticality (enum-like char)

MATLAB/Octave have no native enum support compatible with Octave. The codebase pattern (see `CompositeThreshold.set.AggregateMode:108-115`) is:

```matlab
function set.Criticality(obj, v)
    valid = {'low', 'medium', 'high', 'safety'};
    if ~any(strcmp(v, valid))
        error('Tag:invalidCriticality', ...
            'Criticality must be one of: %s. Got: ''%s''.', ...
            strjoin(valid, ', '), v);
    end
    obj.Criticality = v;
end
```

This validates on every assignment including constructor via the varargin loop. **Default is `'medium'`** per CONTEXT.md.

### `findByKind` (META-adjacent — used in Phase 1005+)

Queries `tag.getKind()` which must return one of `'sensor' | 'state' | 'monitor' | 'composite'` (extensible). Phase 1004 tests it via `MockTag` (returns `'mock'`).

**Confidence:** HIGH. Every META pattern ports directly from existing classes.

## Section 8 — File-Touch Inventory (≤20 budget)

### New files (Phase 1004 creates)

| # | Path | Type | SLOC estimate | Justification |
|---|------|------|---------------|---------------|
| 1 | `libs/SensorThreshold/Tag.m` | Production | 180 | TAG-01, TAG-02, META-01..04, TAG-07 (base `toStruct`) |
| 2 | `libs/SensorThreshold/TagRegistry.m` | Production | 280 | TAG-03, TAG-04, TAG-05, TAG-06 |
| 3 | `tests/suite/TestTag.m` | Test | 180 | Unit tests for Tag base (constructor, validators, abstract enforcement) |
| 4 | `tests/suite/TestTagRegistry.m` | Test | 260 | Unit tests for TagRegistry (CRUD, collision, query, loadFromStructs) |
| 5 | `tests/suite/TestGoldenIntegration.m` | Test | 120 | MIGRATE-01 (class-based wrapper) |
| 6 | `tests/suite/MockTag.m` | Test helper | 40 | Enables TestTagRegistry without waiting on SensorTag/StateTag |
| 7 | `tests/test_tag.m` | Test (Octave) | 160 | Octave function-style port of TestTag |
| 8 | `tests/test_tag_registry.m` | Test (Octave) | 240 | Octave function-style port of TestTagRegistry |
| 9 | `tests/test_golden_integration.m` | Test (Octave) | 100 | MIGRATE-01 (Octave function-style) |

**Subtotal: 9 files created. Budget margin: 11 files unused.**

### Files NOT touched (verify during review)

- `libs/SensorThreshold/Sensor.m` — **untouched** (Pitfall 5)
- `libs/SensorThreshold/Threshold.m` — **untouched**
- `libs/SensorThreshold/StateChannel.m` — **untouched**
- `libs/SensorThreshold/CompositeThreshold.m` — **untouched**
- `libs/SensorThreshold/SensorRegistry.m` — **untouched**
- `libs/SensorThreshold/ThresholdRegistry.m` — **untouched**
- `libs/SensorThreshold/ThresholdRule.m` — **untouched**
- `libs/SensorThreshold/ExternalSensorRegistry.m` — **untouched**
- `libs/FastSense/FastSense.m` — **untouched** (no `addTag` yet)
- `libs/Dashboard/*.m` — **untouched** (no widget migration)
- `libs/EventDetection/*.m` — **untouched**
- `install.m` — **untouched** (no path changes; `libs/SensorThreshold` already on path)
- `tests/run_all_tests.m` — **untouched** (auto-discovery handles everything)

### Files that MIGHT need a small touch (counted in budget if hit)

| Candidate | Likely? | If touched, why |
|-----------|---------|------------------|
| `.planning/phases/1004-.../1004-RESEARCH.md` | YES (this file) | Research output — not production |
| `.planning/phases/1004-.../1004-PLAN-*.md` | YES (created by planner) | Not production |
| `.planning/STATE.md` | YES (auto-updated) | Not production |
| `libs/SensorThreshold/private/<new helper>.m` | MAYBE | Any private helper for registry internals; keep in main classes if possible |

**Realistic upper bound: 9 production/test files + 3 planning files = 12 total files. Well under 20.**

### Hard "do not touch" list (enforced by MIGRATE-02)

The planner MUST reject any plan that edits:

```
libs/SensorThreshold/Sensor.m
libs/SensorThreshold/Threshold.m
libs/SensorThreshold/StateChannel.m
libs/SensorThreshold/CompositeThreshold.m
libs/SensorThreshold/SensorRegistry.m
libs/SensorThreshold/ThresholdRegistry.m
libs/SensorThreshold/ThresholdRule.m
libs/SensorThreshold/ExternalSensorRegistry.m
libs/SensorThreshold/loadModuleData.m
libs/SensorThreshold/loadModuleMetadata.m
libs/SensorThreshold/private/*.m
libs/FastSense/*.m
libs/EventDetection/*.m
libs/Dashboard/*.m
libs/WebBridge/*.m
install.m
tests/run_all_tests.m
tests/add_fastsense_private_path.m
```

**Confidence:** HIGH. File-touch inventory is directly enumerable; ≤20 gate holds with >40% margin.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MATLAB OOP (`classdef < handle`) | R2020b+ | Base class + registry | Shipping in this codebase since v1.0 |
| `containers.Map` (no args) | MATLAB all, Octave 7+ | Registry singleton | 11 in-codebase usages; proven both runtimes |
| `jsonencode` / `jsondecode` | Octave 7+ | Struct ↔ JSON | Used by `DashboardSerializer` today |
| Name-value varargin + switch/case | N/A | Constructor options | `Threshold.m:106-126` pattern |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `uitable` | All | `TagRegistry.viewer()` | Only inside `viewer()`; Octave-safe |
| `matlab.unittest.TestCase` | MATLAB only | Class-based test suite | All `tests/suite/Test*.m` |
| `assert()` + `fprintf()` | All | Octave function-style tests | All `tests/test_*.m` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `containers.Map` | `dictionary` (R2022b+) | **Forbidden** — not on Octave 11; strict stack-ban in `SUMMARY.md §4` |
| Throw-from-base | `methods (Abstract)` block | **Forbidden** — Octave enforcement diverges from MATLAB; `SUMMARY.md §6.1` |
| Varargin switch | `inputParser` / `arguments` block | Slower; `arguments` blocks patchy on Octave |
| Two-phase `loadFromStructs` | Single-pass with try/warn | **Forbidden** — silent lossy load; Pitfall 8 |
| Hard-error register | Silent overwrite (current `ThresholdRegistry`) | **Locked** per CONTEXT + Pitfall 7 |

**Installation:** None. All primitives are MATLAB/Octave built-ins. `install()` already adds `libs/SensorThreshold` to path.

**Version verification:** N/A. No external packages to version-check.

## Architecture Patterns

### Recommended File Layout

```
libs/SensorThreshold/
├── Tag.m                     ← NEW: abstract base, 6 abstract methods, 8 properties
├── TagRegistry.m             ← NEW: singleton + two-phase loader
├── Sensor.m                  ← untouched (legacy)
├── Threshold.m               ← untouched (legacy)
├── StateChannel.m            ← untouched (legacy)
├── CompositeThreshold.m      ← untouched (legacy)
├── SensorRegistry.m          ← untouched (legacy)
├── ThresholdRegistry.m       ← untouched (legacy) ← template for TagRegistry
├── ThresholdRule.m           ← untouched (legacy)
├── ExternalSensorRegistry.m  ← untouched (legacy)
├── loadModuleData.m          ← untouched
├── loadModuleMetadata.m      ← untouched
└── private/                  ← no new additions

tests/suite/
├── TestTag.m                 ← NEW
├── TestTagRegistry.m         ← NEW
├── TestGoldenIntegration.m   ← NEW
├── MockTag.m                 ← NEW (test helper; mirrors MockDashboardWidget.m)
├── TestCompositeThreshold.m  ← untouched ← template for TestTagRegistry
└── <81 other untouched suites>

tests/
├── test_tag.m                ← NEW (Octave wrapper)
├── test_tag_registry.m       ← NEW (Octave wrapper)
├── test_golden_integration.m ← NEW (Octave wrapper)
├── test_composite_threshold.m← untouched ← template
└── <64 other untouched flat tests>
```

### Pattern 1: Throw-from-base abstract class

See Section 1 for canonical Tag.m. Confidence HIGH.

```matlab
function [X, Y] = getXY(obj) %#ok<STOUT,MANU>
    error('Tag:notImplemented', 'Subclass must implement getXY().');
end
```

### Pattern 2: Persistent-Map singleton

```matlab
methods (Static, Access = private)
    function map = catalog()
        persistent cache;
        if isempty(cache)
            cache = containers.Map();
        end
        map = cache;
    end
end
```

### Pattern 3: Enum-validated setter

```matlab
function set.Criticality(obj, v)
    valid = {'low', 'medium', 'high', 'safety'};
    if ~any(strcmp(v, valid))
        error('Tag:invalidCriticality', ...
            'Criticality must be one of: %s. Got: ''%s''.', ...
            strjoin(valid, ', '), v);
    end
    obj.Criticality = v;
end
```

### Pattern 4: Two-phase deserializer

```matlab
function loadFromStructs(structs)
    % Pass 1 — Instantiate all empty
    if isstruct(structs); structs = num2cell(structs); end  % normalize
    for i = 1:numel(structs)
        s = structs{i};
        tag = TagRegistry.instantiateByKind(s);
        TagRegistry.register(tag.Key, tag);  % hard-errors on collision
    end
    % Pass 2 — Resolve refs
    map = TagRegistry.catalog();
    keys = map.keys();
    for i = 1:numel(keys)
        tag = map(keys{i});
        try
            tag.resolveRefs(map);
        catch me
            error('TagRegistry:unresolvedRef', ...
                'Tag ''%s'' failed to resolve refs: %s', keys{i}, me.message);
        end
    end
end
```

### Anti-patterns to avoid

- **`methods (Abstract)` block** in `Tag.m` — diverges Octave vs MATLAB (see Section 1)
- **Silent `try/warning/skip` on missing registry ref during load** — current `CompositeThreshold.fromStruct` bug; Pitfall 8
- **Silent overwrite on `register`** — current `ThresholdRegistry.register` bug; Pitfall 7
- **`isa(tag, 'SensorTag')` switches inside generic code** — Pitfall 1; use `tag.getKind()` dispatch
- **Embedding `resolveRefs` logic inside `fromStruct`** — must be a separate pass so Pass 1 can finish across all tags first
- **Validating `Labels` element types** — trust caller; matches `Threshold.Tags` permissiveness
- **Using `dictionary` / `arguments` / `enumeration`** — forbidden stack additions

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Key-value catalog | Custom hash map with `struct.dynamicField` | `containers.Map()` | Shipping + Octave-safe; 11 call sites in codebase |
| JSON serialize | Write your own `jsonencode` | `jsonencode`/`jsondecode` builtins | Octave 7+ built-in; used in `DashboardSerializer` |
| Enum validation | Check at every call site | `set.Property` setter method | Validates on assignment; `CompositeThreshold.set.AggregateMode` pattern |
| Abstract enforcement | `methods (Abstract)` block | Throw-from-base stubs | Octave-safe; `DataSource.m` precedent |
| uitable viewer | Custom figure + uicontrol | `uitable` with Data/ColumnName | Works on both runtimes; `ThresholdRegistry.viewer` precedent |
| Duplicate detection | Extra lookup tables | `map.isKey(key)` before `map(key) = v` | Single source of truth |
| Test isolation | Custom teardown scripts | `methods (TestMethodTeardown)` on class-based tests + explicit `Registry.clear()` in function-style tests | Runs after every test method |

**Key insight:** Phase 1004 is pure composition of existing proven patterns. Any line of code that isn't a direct port of a `Threshold` / `ThresholdRegistry` / `DataSource` / `DashboardWidget` pattern should be flagged for review.

## Runtime State Inventory

**This is not a rename/refactor phase** — it is a greenfield parallel-hierarchy introduction. No runtime state is modified, migrated, or renamed. **Section omitted per template rules** (no rename/refactor/migration trigger applies).

For completeness:

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None — `TagRegistry` is a fresh empty persistent Map on first session | None |
| Live service config | None — no external services involved | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None — no MEX compilation, no new scripts in `install()` | None |

## Common Pitfalls

### Pitfall 1: Fat Tag base class

**What goes wrong:** `Tag` accumulates abstract methods to satisfy every consumer.

**How to avoid:** Hard-cap at **6 abstract methods** (`getXY`, `valueAt`, `getTimeRange`, `getKind`, `toStruct`, static `fromStruct`). `resolveRefs` is not abstract — it is a defaulted hook. Any future abstract method addition requires justification that ALL subtypes implement it meaningfully.

**Warning signs:** Any `error('Tag:notApplicable')` in a subclass; consumer doing `isa(t, 'SensorTag')` instead of `t.getKind()` switches.

**Gate (verification):** Grep `Tag.m` for `error\('Tag:notImplemented'` → count must be ≤6.

### Pitfall 7: Registry collisions

**What goes wrong:** `register('press_a', sensorTag)` followed by `register('press_a', monitorTag)` silently overwrites.

**How to avoid:** **Hard error** on `isKey(key)` before insertion. Message names both kinds: `Key 'press_a' already registered (existing kind='sensor', new kind='monitor'). Call unregister(key) first to replace.`

**Gate (verification):** Explicit test `TestTagRegistry.testDuplicateRegisterErrors` with `verifyError(@() ..., 'TagRegistry:duplicateKey')`.

### Pitfall 8: Load-order-sensitive deserialization

**What goes wrong:** Parent CompositeTag deserialized before its children → silent warning + missing children.

**How to avoid:** `loadFromStructs(structs)` runs Pass 1 (instantiate all empty) then Pass 2 (resolve refs via `tag.resolveRefs(map)` override). Loud error `TagRegistry:unresolvedRef` on Pass 2 failure — not a silent warning.

**Gate (verification):** Explicit tests `TestTagRegistry.testLoadFromStructsOrderInsensitive` (shuffle structs, assert round-trip equivalent) and `testLoadFromStructsMissingRefErrors` (assert `verifyError`).

### Pitfall 11: Golden test rewriting

**What goes wrong:** Phase-N developer rewrites the golden test "while they're updating tests" → regression guard broken.

**How to avoid:** Header comment (exact wording locked in Section 4) marks the test as untouchable. PR review reflex: "Does this PR rewrite the golden integration test?" If yes, block.

**Gate (verification):** Phase 1011 is the **only** phase allowed to edit `tests/suite/TestGoldenIntegration.m` or `tests/test_golden_integration.m`.

### Pitfall 5: File-touch creep

**What goes wrong:** Plan 03 "while we're here" touches `FastSense.m` or `Sensor.m` → strangler-fig broken.

**How to avoid:** File-touch budget ≤20 enforced at plan-write. Forbidden-list grep (Section 8) runs as a CI check before merge.

**Gate (verification):** `git diff --name-only main...HEAD -- libs/` post-execution reports no hits in the forbidden list.

### Minor: MISS_HIT pragma hygiene

**What goes wrong:** `Tag.m` abstract stubs trigger "output never assigned" MISS_HIT warnings.

**How to avoid:** `%#ok<STOUT,MANU>` on every abstract stub. `%#ok<STOUT,INUSD>` when argument `t` is declared but unused.

**Gate (verification):** `mh_lint libs/SensorThreshold/Tag.m` → zero warnings.

## Code Examples

### Example 1: Constructing a Tag subclass instance (post-Phase-1005 preview)

```matlab
% Phase 1005+ will ship SensorTag extending Tag:
t = SensorTag('press_a', ...
    'Name', 'Pressure A', ...
    'Units', 'bar', ...
    'Labels', {'pressure', 'pump-3', 'critical'}, ...
    'Criticality', 'safety', ...
    'Metadata', struct('asset', 'pump-3', 'vendor', 'Acme'));
```

**In Phase 1004 testing**, MockTag serves the same role:

```matlab
t = MockTag('mock_a', 'Labels', {'alpha', 'beta'}, 'Criticality', 'high');
TagRegistry.register('mock_a', t);
assert(strcmp(TagRegistry.get('mock_a').Criticality, 'high'));
```

### Example 2: Two-phase round-trip

```matlab
% Given two MockTags:
t1 = MockTag('t1', 'Labels', {'a'});
t2 = MockTag('t2', 'Labels', {'b'});

% Round-trip via structs:
structs = {t1.toStruct(), t2.toStruct()};
TagRegistry.clear();
TagRegistry.loadFromStructs(structs);
assert(TagRegistry.get('t1').Labels{1} == 'a');

% Order-insensitive:
TagRegistry.clear();
TagRegistry.loadFromStructs({t2.toStruct(), t1.toStruct()});  % reverse order
assert(~isempty(TagRegistry.get('t1')) && ~isempty(TagRegistry.get('t2')));
```

### Example 3: Introspection

```matlab
TagRegistry.register('sensor_a', SensorTag('sensor_a'));
TagRegistry.register('state_m', StateTag('state_m'));
TagRegistry.list();        % prints sorted keys + names
TagRegistry.printTable();  % prints Key | Name | Kind | Criticality | Units | Labels
TagRegistry.findByKind('sensor');  % returns {sensor_a handle}
TagRegistry.findByLabel('critical'); % returns tags carrying 'critical' label
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `SensorRegistry` + `ThresholdRegistry` separate | `TagRegistry` single flat keyspace | Phase 1004 | Parallel hierarchy; legacy registries keep working |
| `CompositeThreshold.fromStruct` single-pass with silent skip | `TagRegistry.loadFromStructs` two-phase with hard error | Phase 1004 | Fixes latent correctness bug for composite-of-composite |
| `Threshold.Tags` cellstr | `Tag.Labels` cellstr | Phase 1004 | Rename to avoid class-name collision |
| Threshold-scoped "tags" semantics | Tag-scoped "labels" semantics with criticality + metadata | Phase 1004 | More expressive; mirrors Trendminer/PI AF |

**Deprecated/outdated:** None at this phase. `Sensor` / `Threshold` / `CompositeThreshold` are still fully operational through Phase 1011.

## Open Questions

**None.** Every decision is either locked in CONTEXT.md or has a verified precedent in the codebase.

Minor discretionary questions (flagged to planner, not blockers):

1. **Dispatch in `instantiateByKind`** — Phase 1004 has no subclasses. The dispatcher can either (a) only handle `'mock'` (tested only via `MockTag`) or (b) include the full `sensor|state|monitor|composite` cases that all throw `TagRegistry:kindNotYetImplemented` until their respective phases.

   **Recommendation:** Option (a). Ship `instantiateByKind` with `'mock'` + clear extension point. Each Phase 1005-1008 adds its case alongside its subclass. Avoids dead-code warnings in Phase 1004.

2. **`Labels` JSON-decode empty-cell normalization** — On Octave, `jsondecode('[]')` may yield `[]` (double) rather than `{}` (cell). Normalize inside `Tag.fromStruct` via `if isempty(Labels); Labels = {}; end`. Trivial but worth including a test case.

3. **`printTable` column widths** — `ThresholdRegistry.printTable` uses `%-22s %-25s %-8s`. For Tag, add a Kind column (8 chars) and Criticality (8 chars). Target 120-character terminal width to match existing.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| MATLAB R2020b+ | All Tag code | Assumed (project constraint) | — | — |
| GNU Octave 7+ | All Tag code on non-MATLAB CI | Assumed (project constraint) | — | — |
| `containers.Map` | TagRegistry | Built-in both runtimes | — | — |
| `jsonencode`/`jsondecode` | `loadFromStructs` round-trip tests | Built-in Octave 7+, MATLAB R2016b+ | — | — |
| `matlab.unittest` | Class-based tests | MATLAB only | — | Function-style tests cover Octave |
| `uitable` | `TagRegistry.viewer()` | Both runtimes | — | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None required for Phase 1004 (no external services, no MEX, no new runtimes, no build steps).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `matlab.unittest` (MATLAB) + function-style `test_*.m` (Octave) |
| Config file | None — auto-discovery in `tests/run_all_tests.m` |
| Quick run command | `matlab -batch "cd tests; run_all_tests()"` |
| Full suite command | Same as quick run (suite is only 115 files; completes in <2 min) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TAG-01 | Tag base class with throw-from-base stubs | unit | `matlab -batch "install; runtests('tests/suite/TestTag.m')"` | ❌ Wave 0 |
| TAG-02 | Universal properties with defaults | unit | Same as TAG-01 (`TestTag.testConstructorDefaults`) | ❌ Wave 0 |
| TAG-03 | Registry CRUD + collision | unit | `matlab -batch "install; runtests('tests/suite/TestTagRegistry.m')"` | ❌ Wave 0 |
| TAG-04 | Query API | unit | Same as TAG-03 (`TestTagRegistry.testFindByLabel/Kind`) | ❌ Wave 0 |
| TAG-05 | Introspection — list/printTable | unit | `TestTagRegistry.testList`, `testPrintTable` | ❌ Wave 0 |
| TAG-06 | Two-phase loadFromStructs | unit | `TestTagRegistry.testLoadFromStructs*` | ❌ Wave 0 |
| TAG-07 | Round-trip for any composition | unit | `TestTagRegistry.testRoundTripMultipleTags` | ❌ Wave 0 |
| META-01 | Labels cellstr property | unit | `TestTag.testLabelsDefault/Assign` | ❌ Wave 0 |
| META-02 | findByLabel | unit | `TestTagRegistry.testFindByLabel` | ❌ Wave 0 |
| META-03 | Metadata struct | unit | `TestTag.testMetadataOpenStruct` | ❌ Wave 0 |
| META-04 | Criticality enum validation | unit | `TestTag.testCriticalityValidation` | ❌ Wave 0 |
| MIGRATE-01 | Golden integration test passes against legacy API | integration | `matlab -batch "install; runtests('tests/suite/TestGoldenIntegration.m')"` | ❌ Wave 0 |
| MIGRATE-02 | Strangler-fig file budget | static | `git diff --name-only main...HEAD -- libs/SensorThreshold/ | grep -v 'Tag.m\|TagRegistry.m' | wc -l` → must be 0 | ❌ Wave 0 (Bash-runnable, no test file) |

### Pitfall gate → verification map

| Gate | Verification Command |
|------|----------------------|
| Pitfall 1 (≤6 abstract methods) | `grep -c "notImplemented" libs/SensorThreshold/Tag.m` → ≤6 |
| Pitfall 5 (≤20 files, no legacy edits) | `git diff --name-only main...HEAD | wc -l` ≤20 AND forbidden-path grep returns 0 |
| Pitfall 7 (hard-error collision) | `TestTagRegistry.testDuplicateRegisterErrors` green |
| Pitfall 8 (two-pass + 3-deep round trip) | `TestTagRegistry.testLoadFromStructsOrderInsensitive` + `testLoadFromStructsMissingRefErrors` green |
| Pitfall 11 (golden test marked "do not rewrite") | `grep -c "DO NOT REWRITE" tests/suite/TestGoldenIntegration.m tests/test_golden_integration.m` → 2 |

### Sampling Rate

- **Per task commit:** `matlab -batch "install; runtests('tests/suite/TestTag.m'); runtests('tests/suite/TestTagRegistry.m')"` — scoped to Phase 1004 tests
- **Per wave merge:** `matlab -batch "cd tests; run_all_tests()"` — full suite including legacy (Success Criterion 4 gate)
- **Phase gate:** Full suite green on both MATLAB and Octave before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/suite/TestTag.m` — covers TAG-01, TAG-02, META-01, META-03, META-04
- [ ] `tests/suite/TestTagRegistry.m` — covers TAG-03, TAG-04, TAG-05, TAG-06, TAG-07, META-02
- [ ] `tests/suite/MockTag.m` — test helper; needed before TestTagRegistry runs
- [ ] `tests/suite/TestGoldenIntegration.m` — covers MIGRATE-01
- [ ] `tests/test_tag.m` — Octave port of TestTag
- [ ] `tests/test_tag_registry.m` — Octave port of TestTagRegistry
- [ ] `tests/test_golden_integration.m` — Octave port of golden test

**No framework install needed** — `matlab.unittest` ships with MATLAB; Octave uses function-style `assert`; both are battle-tested in this repo (115 suite files + 68 flat files).

## Sources

### Primary (HIGH confidence)

- `libs/SensorThreshold/ThresholdRegistry.m` — canonical template for TagRegistry static methods + persistent containers.Map
- `libs/SensorThreshold/Threshold.m` — canonical template for Tag base class property defaults + name-value varargin loop
- `libs/SensorThreshold/CompositeThreshold.m` — serialization trap documented at lines 326-333; enum-validating setter at lines 108-115
- `libs/EventDetection/DataSource.m` — proven Octave-safe throw-from-base abstract pattern (lines 11-15)
- `libs/Dashboard/DashboardWidget.m` — cautionary counterexample using `methods (Abstract)` (line 144); only works because all concrete subclasses override everything
- `tests/suite/TestCompositeThreshold.m` — test suite template including `TestMethodTeardown` registry-clear pattern
- `tests/test_composite_threshold.m` — Octave function-style template
- `tests/test_event_integration.m` — minimum-viable integration test fixture pattern
- `tests/run_all_tests.m` — auto-discovery wiring; no registration changes needed
- `install.m` (lines 54-58) — `genpath('tests')` confirms test helpers on path automatically
- `.planning/research/SUMMARY.md §6.1` — locked decision: throw-from-base over `methods (Abstract)`
- `.planning/research/PITFALLS.md §1, §5, §7, §8, §11` — verification gates for this phase
- `.planning/REQUIREMENTS.md` — TAG-01..07, META-01..04, MIGRATE-01..02 verbatim requirements

### Secondary (MEDIUM confidence)

- `.planning/research/STACK.md` (referenced via SUMMARY.md) — stack bans (no `dictionary`, no `matlab.mixin.*`, no `arguments`, no `enumeration`)
- `.planning/research/ARCHITECTURE.md` (referenced via SUMMARY.md) — Tag interface contract motivation

### Tertiary (LOW confidence)

- None. Every Phase 1004 claim is verified against in-repo code or in-repo prior research.

## Metadata

**Confidence breakdown:**

- **Standard stack:** HIGH — every primitive has a shipping precedent in the codebase
- **Architecture (throw-from-base, two-phase loader, persistent-Map singleton):** HIGH — verified against `DataSource.m`, `CompositeThreshold.m`, `ThresholdRegistry.m`
- **Test infrastructure (dual-style, auto-discovery):** HIGH — direct read of `run_all_tests.m` + 115 existing suite files + 68 flat files
- **Pitfalls (1/5/7/8/11):** HIGH — each pitfall has a documented precedent or counterexample in the existing code
- **File-touch inventory (≤20 budget):** HIGH — exact enumeration (9-12 files), >40% margin to budget
- **Octave empty-cell JSON decode edge case:** MEDIUM — known quirk; trivial normalization in `fromStruct`

**Research date:** 2026-04-16
**Valid until:** 2026-06-16 (stable — all codebase references, no fast-moving external docs)

## RESEARCH COMPLETE
