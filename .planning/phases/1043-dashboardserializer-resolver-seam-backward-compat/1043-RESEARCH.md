# Phase 1043: DashboardSerializer Resolver Seam + Backward Compat - Research

**Researched:** 2026-06-07
**Domain:** MATLAB Dashboard load/serialize pipeline — optional resolver injection
**Confidence:** HIGH (all claims from direct code audit at current HEAD)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Thread optional `tagResolver` (`@(localKey) machine.get(localKey)`) through `DashboardEngine.load(..., 'TagResolver', r)` → `DashboardSerializer.configToWidgets(config, resolver)` → `createWidgetFromStruct(ws, resolver)` → `FastSenseWidget.fromStruct(s, tagResolver)`. The existing resolver hook at `configToWidgets:388` covers only `source.type='sensor'` at `:402`; extend it so `source.type='tag'` path in `fromStruct:1516` uses the resolver.
- **D-02:** Close the multi-page resolver drop at `DashboardEngine.m:4384` — the per-page `createWidgetFromStruct` call must receive the same resolver the single-page path already passes at `:4412`.
- **D-03:** `fromStruct(s, tagResolver)`: resolver present → use it. Absent → `TagRegistry.get` in try/catch; hit = legacy (no warning); miss → `warning('FastSenseWidget:tagResolverMissing', ...)` + `obj.Tag = []` (loud, non-crashing).
- **D-04:** Default no-resolver = `TagRegistry.get` (backward compat). Warning fires ONLY on registry-miss path.
- **D-05:** Optional machine-variable-name arg in `.m` export path. Supplied (fleet) → emit `<machineVar>.get('key')`; absent (legacy) → `TagRegistry.get('key')` as today. No machineId in widget structs. Shared `linesForWidget` helper is the single emission choke-point.
- **D-06:** Class suite covering: (a) legacy load via `TagRegistry.get`, no warning; (b) multi-page fleet + injected resolver, page-2 widgets use resolver; (c) fleet + no resolver → warning, no crash, `Tag=[]`; (d) `.m` export with machineVar → machine-scoped form.
- **D-07:** Octave flat companion test for resolver-threading + warning logic (fromStruct/configToWidgets are Octave-safe — they build Tag objects without rendering).

### Claude's Discretion

Planner may refine exact arg form (`'TagResolver'` NV vs positional), warning-id spelling, and test-file naming as long as SC1-SC4 and backward-compat hold.

### Deferred Ideas (OUT OF SCOPE)

- Actual fleet-dashboard export wiring (which caller passes machineVar) — exercised in 1046 clone/remap.
- Resolver-inverse / auto-detecting a Tag's owning machine.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DASH-01 | A machine's tag-bound dashboards serialize and reload correctly, resolving `(machineId, localKey)` via the Fleet→Machine resolver — including multi-page dashboards (closes `FastSenseWidget.fromStruct:1516` + `DashboardEngine:4384` resolver gaps) | Seam audit in sections "Exact Code Seams" and "Threading Path"; fromStruct signature change + createWidgetFromStruct threading + DashboardEngine multi-page fix |
| DASH-02 | Pre-v5.0 single-machine dashboards (JSON and `.m`) continue to load unchanged via the global registry (resolver defaults to `TagRegistry.get`) | Verified: existing `fromStruct:1514-1521` try/catch pattern becomes the no-resolver default branch; zero new warnings on hit path; confirmed by "Backward-Compat Guarantee" section |
</phase_requirements>

---

## Summary

Phase 1043 is a precision seam-completion phase. The infrastructure is half-built: `DashboardEngine.load` already parses a `'SensorResolver'` varargin and passes it to `configToWidgets` on the single-page path; `configToWidgets` already accepts a resolver arg but only uses it for `source.type='sensor'` (legacy). Two gaps remain: (1) `FastSenseWidget.fromStruct:1516` calls `TagRegistry.get` directly for `source.type='tag'` — the current v2.0 path — bypassing the resolver entirely; (2) the multi-page load branch at `DashboardEngine.m:4384` calls `createWidgetFromStruct(pgWidgets{j})` with no resolver arg, silently dropping it even when supplied.

The fix is three minimal surgical edits touching three files, plus a fourth edit to `linesForWidget` for SC4 (`.m` export). All changes default to the existing behavior when no resolver is supplied — making the no-resolver path byte-for-byte identical to current operation for legacy dashboards. The warning fires exactly once: when a fleet tag key misses in the global registry with no resolver present, signaling the user that a machine resolver is needed.

No new dependencies. No JSON schema changes. No changes to `toStruct` or any serialization path. The resolver context comes from the load site (the machine the user is loading), not from the stored JSON struct.

**Primary recommendation:** Implement in one wave (all three files + tests). The changes are independent — no sequencing hazard between them — but the test suite must be written first (RED) to lock the observable behavior.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Tag resolution at load time | Dashboard/Serializer | Fleet/Machine (resolver target) | Resolution happens during deserialization, not during render; the resolver is injected from outside |
| Resolver injection point | DashboardEngine.load | DashboardSerializer.configToWidgets | Entry point for machine context; threads inward |
| Tag binding (source.type='tag') | FastSenseWidget.fromStruct | TagRegistry (fallback) | Widget owns its own binding; resolver is optional override |
| `.m` export machine-scoping | DashboardSerializer.linesForWidget | exportScript / exportScriptPages (callers) | linesForWidget is the single choke-point; callers pass machineVar |
| Warning emission | FastSenseWidget.fromStruct | — | Fleet-tag-without-resolver is a widget-level concern |
| Backward compat | FastSenseWidget.fromStruct (default) | DashboardEngine.load (default) | `nargin < 2` guards preserve existing behavior exactly |

---

## Standard Stack

No new packages. Pure MATLAB/Octave. [VERIFIED: direct codebase audit]

| Component | Current State | Phase 1043 Change |
|-----------|--------------|-------------------|
| `FastSenseWidget.fromStruct` | `fromStruct(s)` — 1 arg | `fromStruct(s, tagResolver)` — 2nd arg optional via `nargin < 2` |
| `DashboardSerializer.createWidgetFromStruct` | `createWidgetFromStruct(ws)` — 1 arg | `createWidgetFromStruct(ws, tagResolver)` — 2nd arg optional |
| `DashboardSerializer.configToWidgets` | Already has `resolver` arg (`:388`); sensor-only | Thread resolver into `createWidgetFromStruct` call; tag path inside fromStruct |
| `DashboardEngine.load` | Parses `'SensorResolver'` NV (`:4346`); single-page only | Parse `'TagResolver'` NV (or rename); propagate into multi-page loop at `:4384` |
| `DashboardSerializer.linesForWidget` | No `'tag'` case in switch; falls through to `otherwise` | Add `'tag'` case with machineVar conditional |
| `DashboardSerializer.exportScript` | Passes no machineVar to linesForWidget | Add optional `machineVar` arg; thread to linesForWidget |
| `DashboardSerializer.exportScriptPages` | Passes no machineVar to linesForWidget | Add optional `machineVar` arg; thread to linesForWidget |

**Package Legitimacy Audit:** Not applicable — no external packages installed.

---

## Architecture Patterns

### System Architecture Diagram

```
[Caller: machine resolver]
    @(localKey) machine.get(localKey)
         |
         v
DashboardEngine.load(filepath, 'TagResolver', r)
         |
         +-----> [multi-page path: :4377-4409]
         |           for each page:
         |               createWidgetFromStruct(pgWidgets{j}, r)  <-- GAP D-02 fix
         |
         +-----> [single-page path: :4412]
                     configToWidgets(config, resolver)  <-- already works
                         |
                         v
                 createWidgetFromStruct(ws, tagResolver)  <-- GAP: today takes 1 arg
                         |
                         v
                 FastSenseWidget.fromStruct(ws, tagResolver)  <-- GAP D-01 fix
                         |
                         +--> tagResolver present? --> tagResolver(key)
                         |
                         +--> absent? --> TagRegistry.get(key) try/catch
                                              hit  --> use tag (no warning)
                                              miss --> warning('FastSenseWidget:tagResolverMissing') + Tag=[]
```

```
[.m Export path]
DashboardSerializer.exportScript(config, filepath, machineVar)
DashboardSerializer.exportScriptPages(config, filepath, machineVar)
         |
         v
linesForWidget(ws, pos, indent, machineVar)  <-- add 4th optional arg
         |
         case 'tag':
             machineVar supplied? --> sprintf('%s.get(''%s'')', machineVar, ws.source.key)
             absent?              --> sprintf('TagRegistry.get(''%s'')', ws.source.key)
```

### Recommended Project Structure

No new files required (except tests). Edits touch:

```
libs/Dashboard/
├── FastSenseWidget.m        -- fromStruct: add optional tagResolver arg
├── DashboardSerializer.m    -- createWidgetFromStruct: add tagResolver arg
│                               configToWidgets: thread to createWidgetFromStruct
│                               linesForWidget: add machineVar arg, add 'tag' case
│                               exportScript: add optional machineVar arg
│                               exportScriptPages: add optional machineVar arg
└── DashboardEngine.m        -- load: propagate resolver into multi-page loop

tests/suite/
└── TestFleetDashboardResolver.m   -- new class suite (D-06)

tests/
└── test_dashboard_resolver.m      -- new Octave flat test (D-07)
```

---

## Exact Code Seams (VERIFIED by direct audit)

### Seam 1: FastSenseWidget.fromStruct (the tag-path gap)

**Current code at :1501-1521:** [VERIFIED: direct read 2026-06-07]

```matlab
function obj = fromStruct(s)          % <-- 1 arg
    obj = FastSenseWidget();
    ...
    case 'tag'
        if exist('TagRegistry', 'class')
            try
                obj.Tag = TagRegistry.get(s.source.key);  % :1516 -- the gap
            catch
                warning('FastSenseWidget:tagNotFound', ...
                    'TagRegistry key ''%s'' not found.', s.source.key);
            end
        end
```

**Required change:**

```matlab
function obj = fromStruct(s, tagResolver)
    if nargin < 2, tagResolver = []; end
    obj = FastSenseWidget();
    ...
    case 'tag'
        if ~isempty(tagResolver)
            obj.Tag = tagResolver(s.source.key);   % machine path
        elseif exist('TagRegistry', 'class')
            try
                obj.Tag = TagRegistry.get(s.source.key);   % legacy path
            catch
                warning('FastSenseWidget:tagResolverMissing', ...
                    ['Tag ''%s'' not found in TagRegistry and no machine resolver ' ...
                     'supplied — pass a TagResolver to DashboardEngine.load to ' ...
                     'load a fleet dashboard.'], s.source.key);
            end
        end
```

Key points:
- The warning ID changes from `FastSenseWidget:tagNotFound` to `FastSenseWidget:tagResolverMissing` on the miss path (D-03 requirement: "loud, non-crashing").
- The resolver path does NOT have its own try/catch — if `machine.get(key)` throws `Machine:unknownKey`, the error propagates. This is intentional: a resolver that can't find its key is a programming error (wrong resolver injected), not a fleet-tag-missing-from-global-registry situation.
- The `exist('TagRegistry', 'class')` guard is preserved on the legacy path for Octave safety.

### Seam 2: DashboardSerializer.createWidgetFromStruct (threading)

**Current code at :413-418:** [VERIFIED: direct read 2026-06-07]

```matlab
function w = createWidgetFromStruct(ws)    % <-- 1 arg
    w = [];
    switch ws.type
        case 'fastsense'
            w = FastSenseWidget.fromStruct(ws);    % <-- no resolver
```

**Required change:**

```matlab
function w = createWidgetFromStruct(ws, tagResolver)
    if nargin < 2, tagResolver = []; end
    w = [];
    switch ws.type
        case 'fastsense'
            w = FastSenseWidget.fromStruct(ws, tagResolver);
        % all other cases unchanged — they don't use tagResolver
```

Only `FastSenseWidget.fromStruct` receives the resolver — other widget types (`NumberWidget`, `StatusWidget`, etc.) do not have tag bindings and do not need it.

### Seam 3: DashboardSerializer.configToWidgets (thread to createWidgetFromStruct)

**Current code at :388-411:** [VERIFIED: direct read 2026-06-07]

```matlab
function widgets = configToWidgets(config, resolver)
    if nargin < 2, resolver = []; end
    widgets = cell(1, numel(config.widgets));
    for i = 1:numel(config.widgets)
        ws = config.widgets{i};
        widgets{i} = DashboardSerializer.createWidgetFromStruct(ws);  % <-- no resolver
        % Resolve sensor binding using resolver
        if ~isempty(resolver) && ~isempty(widgets{i}) && ...
                isfield(ws, 'source') && strcmp(ws.source.type, 'sensor')
            try
                widgets{i}.Sensor = resolver(ws.source.name);
```

**Required change:** Pass the resolver into `createWidgetFromStruct`. The `source.type='sensor'` post-hoc block can stay for backward-compat (it was the original hook, used when callers wanted to inject a sensor resolver after fromStruct). The new tag-resolver path now lives inside `fromStruct` and is applied during construction.

```matlab
widgets{i} = DashboardSerializer.createWidgetFromStruct(ws, resolver);
```

Note: This means the resolver arg serves dual purpose in this function — as a tag resolver (threaded into fromStruct) and as a sensor resolver (the existing post-hoc block). This is acceptable since `D-01` specifies the resolver signature as `@(localKey) machine.get(localKey)` — which for the sensor case (old JSON) would not be called anyway (`source.type='sensor'` is legacy and fleet tags use `source.type='tag'`).

If the planner prefers cleaner separation, an alternative is to add a separate `tagResolver` arg to `configToWidgets` so the sensor resolver and tag resolver are distinct. The simpler approach (reuse the single resolver arg) is correct for the fleet use case where the resolver IS `machine.get`.

### Seam 4: DashboardEngine.load — multi-page gap

**Current code at :4345-4412:** [VERIFIED: direct read 2026-06-07]

```matlab
function obj = load(filepath, varargin)
    resolver = [];
    for k = 1:2:numel(varargin)
        if strcmp(varargin{k}, 'SensorResolver')   % <-- current NV key name
            resolver = varargin{k+1};
        end
    end
    ...
    if isfield(config, 'pages') && ~isempty(config.pages)
        % Multi-page: resolver is NOT passed
        for i = 1:numel(config.pages)
            pg = DashboardPage(config.pages{i}.name);
            for j = 1:numel(pgWidgets)
                w = DashboardSerializer.createWidgetFromStruct(pgWidgets{j});  % :4384 -- gap
```

**Required change:**

1. Add `'TagResolver'` to the varargin parse loop (alongside or replacing `'SensorResolver'` — the planner should decide on naming consistency; `'TagResolver'` matches D-01 exactly). Keep `'SensorResolver'` for backward compat if any existing callers use it.
2. Propagate resolver into the multi-page loop:

```matlab
w = DashboardSerializer.createWidgetFromStruct(pgWidgets{j}, resolver);
```

### Seam 5: DashboardSerializer.linesForWidget — 'tag' case (SC4)

**Current state:** The `switch ws.source.type` in `linesForWidget` at :788 has cases for `'sensor'`, `'file'`, `'data'`, and `otherwise`. There is NO `'tag'` case. Tag-bound widgets fall through to `otherwise` which emits a bare `d.addWidget('fastsense', 'Title', '%s', 'Position', %s)` with no Tag binding — the exported `.m` would produce an unbound widget. [VERIFIED: direct read 2026-06-07]

**Required change:**

Add a `'tag'` case before `otherwise`:

```matlab
case 'tag'
    wLines{end+1} = sprintf('%sd.addWidget(''fastsense'', ''Title'', ''%s'', ...', indent, ws.title);
    wLines{end+1} = sprintf('%s    ''Position'', %s, ...', indent, pos);
    if ~isempty(machineVar)
        tagExpr = sprintf('%s.get(''%s'')', machineVar, ws.source.key);
    else
        tagExpr = sprintf('TagRegistry.get(''%s'')', ws.source.key);
    end
    if showPl
        wLines{end+1} = sprintf('%s    ''Tag'', %s, ...', indent, tagExpr);
        wLines{end+1} = sprintf('%s    ''ShowPlantLog'', true);', indent);
    else
        wLines{end+1} = sprintf('%s    ''Tag'', %s);', indent, tagExpr);
    end
```

The `machineVar` arg is added as an optional 4th arg to `linesForWidget(ws, pos, indent)` → `linesForWidget(ws, pos, indent, machineVar)` with `if nargin < 4, machineVar = ''; end`.

The same optional `machineVar` arg flows from `exportScript(config, filepath)` → `exportScript(config, filepath, machineVar)` and `exportScriptPages(config, filepath)` → `exportScriptPages(config, filepath, machineVar)`, defaulting to `''` (empty = legacy form, `TagRegistry.get`).

The `.m` export calls in `DashboardSerializer.save` (the function-form export at :1-120) also call `linesForWidget` via its own inline loop at :30-35 — that path also needs the machineVar arg threaded through.

**Note:** The existing `'sensor'` case in `linesForWidget` also emits `TagRegistry.get(...)` but using `ws.source.name` (the legacy field name, not `ws.source.key`). Legacy sensor-type widgets are not fleet widgets; the machineVar conditional only needs to be in the new `'tag'` case.

---

## TagRegistry.get Miss Behavior (VERIFIED)

**Critical for D-03 try/catch design.** [VERIFIED: direct read of `libs/SensorThreshold/TagRegistry.m:47-65`]

```matlab
function t = get(key)
    map = TagRegistry.catalog();
    if ~map.isKey(key)
        error('TagRegistry:unknownKey', ...
            'No tag registered with key ''%s''. Use TagRegistry.list() to see available keys.', ...
            key);
    end
    t = map(key);
end
```

`TagRegistry.get` throws `error('TagRegistry:unknownKey', ...)` on miss — it does NOT return `[]`. The try/catch in D-03 is therefore correct: the miss path throws, the catch block fires, the warning is emitted, `obj.Tag` stays `[]`.

**Machine.get miss behavior:** [VERIFIED: direct read of `libs/Fleet/Machine.m:157-168`]

```matlab
function t = get(obj, localKey)
    if ~obj.Tags_.isKey(localKey)
        error('Machine:unknownKey', ...
            'No tag with key ''%s'' in machine ''%s''.', localKey, obj.Id);
    end
    t = obj.Tags_(localKey);
end
```

Machine.get also throws on miss. If the injected resolver calls `machine.get(key)` and the key is absent from the machine's catalog, the error propagates from `fromStruct`. The planner should decide whether to wrap the resolver call in a try/catch as well — reasonable options:

- **No try/catch on resolver path** (simpler): programming error surfaces immediately. Useful during development.
- **Try/catch on resolver path** with a different warning ID: `'FastSenseWidget:resolverMiss'` — allows loading a partially-bound fleet dashboard. Aligned with DASH-04 spirit (failed remaps surfaced, not crashes) but DASH-04 is 1046 scope. D-03 is silent on this; leaving the resolver path unwrapped (let it throw) is the safer interpretation for 1043 — 1046 can wrap it when it needs graceful partial binding.

**Recommendation:** Leave resolver path unwrapped in 1043. Document in test that a resolver throwing for an unknown key propagates as an error (different from the no-resolver warning path). This preserves the distinction between "fleet tag missing from global registry" (warning) and "resolver itself can't find the key" (error — wrong resolver for this dashboard).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Optional arg handling in MATLAB | Conditional logic before `nargin` check | `if nargin < N, arg = default; end` | Standard MATLAB pattern; Octave-compatible |
| Warning emission | Custom logging class | `warning('ID:camelCase', 'message %s', args)` | Built-in; suppressible via `warning('off', 'ID:camelCase')` |
| Error on registry miss | Return sentinel | `error(...)` / catch in caller | TagRegistry contract is already established; don't change it |
| machineVar conditional | Complex emission logic | Simple `if ~isempty(machineVar)` branch in sprintf | The two forms are just different strings |

---

## Common Pitfalls

### Pitfall 1: Resolver NV Key Name Mismatch
**What goes wrong:** The current varargin parse at `DashboardEngine.load:4348` checks for `'SensorResolver'`, not `'TagResolver'`. If 1043 adds a new `'TagResolver'` key without also removing or aliasing `'SensorResolver'`, existing callers that happen to use `'SensorResolver'` will still work but new callers using `'TagResolver'` will silently get `resolver=[]` if the key spelling doesn't match exactly.
**How to avoid:** Either (a) rename `'SensorResolver'` to `'TagResolver'` throughout (check for any existing callers of `DashboardEngine.load` with `'SensorResolver'`) or (b) accept both keys in the parse loop. [VERIFIED: no callers in tests/suite/TestDashboardSerializer.m use 'SensorResolver' directly — the parse exists but is unused in current tests]

### Pitfall 2: Warning ID Convention
**What goes wrong:** Warning ID must follow `ClassName:camelCaseProblem` (from CLAUDE.md). The locked decision specifies `'FastSenseWidget:tagResolverMissing'` — this is correct format.
**How to avoid:** Don't use underscores or spaces in the camelCase part. The existing `'FastSenseWidget:tagNotFound'` at :1518 uses correct format; the new ID replaces it on the miss path only.

### Pitfall 3: createWidgetFromStruct Called From Unexpected Sites
**What goes wrong:** `createWidgetFromStruct` is a public static method. Callers outside `DashboardEngine.load` (e.g., `testSerializerRoundTrip` in `TestDashboardSerializer.m:88`) call `DashboardSerializer.createWidgetFromStruct(s)` with 1 arg. The `nargin < 2` guard must handle this cleanly.
**How to avoid:** Add `if nargin < 2, tagResolver = []; end` as the first line of `createWidgetFromStruct`. All 1-arg callers remain byte-for-byte unchanged.

### Pitfall 4: linesForWidget Called From save() Private Path
**What goes wrong:** `DashboardSerializer.save()` (the function-format `.m` export at :1-120) has its own inline widget-loop (`:30-35`) that also calls `linesForWidget`. If `linesForWidget` gains a new 4th arg `machineVar` but `save()` doesn't pass it, a tag-type widget exported via `save()` will use the 3-arg form → falls through `nargin < 4` guard → `machineVar=''` → emits `TagRegistry.get(...)`. This is correct for the single-machine path (save() is always legacy). No change needed to save() — the default is correct.
**Confirm:** Read `save()` at :1-120 — it calls `linesForWidget(ws, pos, wLines)` style or similar. Actually it has its own inline switch at :35-88 (NOT calling linesForWidget). Only `exportScript` and `exportScriptPages` call `linesForWidget`. The `save()` method has a separate inline switch block — this path also needs a `'tag'` case added if it's to emit correct tag bindings. [NOTE TO PLANNER: Verify whether `save()` inline block needs a `'tag'` case or whether `save()` is only used for non-tag dashboards. If save() can be called with a tag-type widget, it also emits the `otherwise` fallback (no binding). This may need a parallel fix.]

### Pitfall 5: Multi-Page configToWidgets Is Not Used
**What goes wrong:** In the multi-page load path, `configToWidgets` is NOT called — the code directly calls `createWidgetFromStruct` per widget in a loop at :4384. So threading the resolver into `configToWidgets` alone does NOT fix the multi-page path. Both seams must be fixed independently.
**How to avoid:** Fix D-02 (`:4384` loop) AND D-01 (fromStruct tag path) as separate edits. The SC1 test (page-2 resolver) verifies both are in place. [VERIFIED: direct read of DashboardEngine.load:4377-4409]

### Pitfall 6: Octave isa() in fromStruct Not Needed
**What goes wrong:** The existing `exist('TagRegistry', 'class')` guard in fromStruct is an Octave compatibility check. It should remain on the legacy (no-resolver) path. The resolver path does not need this guard — if a resolver is supplied, it's a function handle and TagRegistry is irrelevant.
**How to avoid:** Structure as: `if ~isempty(tagResolver)` ... `elseif exist('TagRegistry', 'class')` ... — the `exist` check only wraps the fallback branch.

---

## Backward-Compat Guarantee

**No-resolver path must be byte-for-byte equivalent to current behavior.**

Current `fromStruct` behavior for `source.type='tag'`:
1. Check `exist('TagRegistry', 'class')` — always true in a normal MATLAB session
2. Try `TagRegistry.get(key)` — hit: bind tag; miss: `warning('FastSenseWidget:tagNotFound', ...)`, `obj.Tag` stays `[]`

After 1043, with no resolver supplied:
1. `nargin < 2` → `tagResolver = []`
2. `isempty(tagResolver)` → true → take legacy path
3. Same `exist` check, same try/catch, same behavior on hit
4. On miss: new warning ID `'FastSenseWidget:tagResolverMissing'` instead of `'FastSenseWidget:tagNotFound'`

**The warning ID changes on the miss path.** This is intentional (D-03 — the new warning is more informative) but means the miss-path is not byte-for-byte identical at the warning ID level. Any existing tests that assert `'FastSenseWidget:tagNotFound'` will need updating. [VERIFIED: `TestDashboardSerializer.m` does not test for a specific warning ID on tag miss — no test updates needed for existing suite]

**The hit path (legacy load with tags in registry) is byte-for-byte identical:** same code executes, no new warning, `obj.Tag` bound correctly.

---

## Fixture Strategy for Tests (D-06, D-07)

### Synthetic in-test JSON fixture (primary — determinism)

All tests use synthetic structs built inline. No dependency on a real `examples/` file. This is the correct approach because:
- No real `examples/` JSON files use `source.type='tag'` (existing examples use `source.type='data'` or `source.type='file'`) — confirmed by `grep -rn "source.*tag" examples/` returning nothing meaningful
- Synthetic fixtures are deterministic and version-stable

**Fixture pattern (from TestDashboardSerializer.m style):**

```matlab
% Build a 2-page fleet dashboard config struct inline
config = struct();
config.name = 'Fleet Dash';
config.theme = 'dark';
config.liveInterval = 5;
config.grid = struct('columns', 24);

ws1.type = 'fastsense';
ws1.title = 'Page1 Widget';
ws1.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
ws1.source = struct('type', 'tag', 'key', 'temperature');  % fleet tag key

pg1.name = 'Page 1';
pg1.widgets = {ws1};

ws2.type = 'fastsense';
ws2.title = 'Page2 Widget';
ws2.position = struct('col', 1, 'row', 1, 'width', 12, 'height', 3);
ws2.source = struct('type', 'tag', 'key', 'pressure');  % page-2 fleet tag key

pg2.name = 'Page 2';
pg2.widgets = {ws2};

config.pages = {pg1, pg2};
```

### Multi-page test for SC1 (resolver used on page 2)

To assert page-2 widgets resolve via the resolver (not TagRegistry), set up:
1. A `Machine` (from 1042) with `temperature` and `pressure` tags in its catalog
2. TagRegistry empty (call `TagRegistry.clear()` in setup)
3. Save the config to a temp JSON file via `DashboardSerializer.saveJSON`
4. Load with `DashboardEngine.load(filepath, 'TagResolver', @(k) machine.get(k))`
5. Assert page-2 widget `obj.Tag` is non-empty and is the machine's tag

This is Octave-safe at the model level but uses `DashboardEngine.load` (which creates a `DashboardEngine` object). `DashboardEngine` itself is Octave-safe as a data model without rendering — the `render()` call is what requires uifigure. The test should NOT call `render()`.

### Octave flat test (D-07) — fromStruct + warning

The Octave flat test avoids DashboardEngine entirely and tests fromStruct directly:

```matlab
function test_dashboard_resolver()
    install();
    TagRegistry.clear();

    % Set up a machine with one tag
    m = Machine('Id', 'M01', 'DataRoot', '');
    m.addTag(SensorTag('pressure'));

    % SC1: resolver path
    ws.type = 'fastsense';
    ws.title = 'Test';
    ws.position = struct('col', 1, 'row', 1, 'width', 6, 'height', 2);
    ws.source = struct('type', 'tag', 'key', 'pressure');
    w = FastSenseWidget.fromStruct(ws, @(k) m.get(k));
    assert(~isempty(w.Tag), 'resolver path: Tag must be bound');

    % SC3: no-resolver, fleet tag not in TagRegistry → warning
    % (TagRegistry.clear() called above, so 'pressure' is not registered)
    warnState = warning('query', 'FastSenseWidget:tagResolverMissing');
    warning('error', 'FastSenseWidget:tagResolverMissing');  % turn to error for capture
    errored = false;
    try
        FastSenseWidget.fromStruct(ws);  % no resolver, miss
    catch me
        errored = ~isempty(strfind(me.identifier, 'FastSenseWidget:tagResolverMissing'));
    end
    warning(warnState.state, 'FastSenseWidget:tagResolverMissing');
    assert(errored, 'SC3: tagResolverMissing warning must fire on no-resolver miss');

    % SC2: legacy tag in TagRegistry → no warning
    t = SensorTag('legacy_temp');
    TagRegistry.register('legacy_temp', t);
    ws2.type = 'fastsense'; ws2.title = 'T2'; ws2.position = ws.position;
    ws2.source = struct('type', 'tag', 'key', 'legacy_temp');
    w2 = FastSenseWidget.fromStruct(ws2);  % no resolver, hit
    assert(~isempty(w2.Tag), 'SC2: legacy registry hit must bind Tag');

    TagRegistry.clear();
    fprintf('    All 3 tests passed.\n');
end
```

**Note on Octave warning-as-error pattern:** The `warning('error', ...)` / `try-catch` pattern is the Octave-compatible way to assert a warning fires. It's used in `tests/test_machine.m:27-32` for error assertion.

---

## .m Export: linesForWidget Threading Path

The `machineVar` arg must reach `linesForWidget` via two paths:

**Path A — exportScript:**
```
exportScript(config, filepath)              [today]
exportScript(config, filepath, machineVar)  [1043]
    calls linesForWidget(ws, pos, '', machineVar)
```

**Path B — exportScriptPages:**
```
exportScriptPages(config, filepath)              [today]
exportScriptPages(config, filepath, machineVar)  [1043]
    calls linesForWidget(ws, pos, '    ', machineVar)
```

**Path C — save() inline block:**
The `save()` method at :1-120 has its own inline switch, NOT calling `linesForWidget`. Its inline switch also lacks a `'tag'` case. However, `save()` is the function-form export (returns a `DashboardEngine` from a MATLAB function file) used for all exports today. It needs a `'tag'` case added to its inline switch too, with the same machineVar conditional. However since `save()` is not called by any fleet workflow in 1043 (fleet export uses `exportScript`/`exportScriptPages`), adding the tag case to save() can be a cleanup task. The planner should decide: add to save() now for consistency, or defer to 1046.

**The SC4 test asserts on the string content of the exported `.m` file.** Specifically:
- With machineVar: `fileread(filepath)` must contain `machine.get('pressure')` and must NOT contain `TagRegistry.get('pressure')`
- Without machineVar: `fileread(filepath)` must contain `TagRegistry.get('pressure')`

---

## Validation Architecture

`workflow.nyquist_validation = true` in `.planning/config.json` — section required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `matlab.unittest.TestCase` (class suite) + function-based (Octave flat) |
| Config file | None — tests call `install()` via `TestClassSetup.addPaths` |
| Quick run command | `mcp__matlab__run_matlab_test_file` on `tests/suite/TestFleetDashboardResolver.m` |
| Full suite command | `mcp__matlab__run_matlab_file` on `tests/run_all_tests.m` |
| Octave flat run | `mcp__matlab__evaluate_matlab_code`: `install(); test_dashboard_resolver()` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DASH-01 SC1 | Page-2 tag widgets resolve via injected resolver, not TagRegistry | unit | `run_matlab_test_file('tests/suite/TestFleetDashboardResolver.m')` | Wave 0 |
| DASH-01 SC1 | Multi-page `createWidgetFromStruct` at :4384 receives resolver | unit | same suite | Wave 0 |
| DASH-01 SC4 | `.m` export with machineVar emits `<machineVar>.get('key')` | unit | same suite | Wave 0 |
| DASH-02 SC2 | Legacy JSON loads unchanged — tags in registry, no warning | unit | same suite | Wave 0 |
| DASH-02 SC3 | No-resolver fleet tag miss → `FastSenseWidget:tagResolverMissing`, no crash | unit | same suite | Wave 0 |
| DASH-01 SC1 | fromStruct + warning logic, Octave-safe | unit | `evaluate_matlab_code('install(); test_dashboard_resolver()')` | Wave 0 |

### Observable Signals Per Requirement

**SC1 (fleet resolver used, not TagRegistry):**
- `TagRegistry.clear()` before load (ensures TagRegistry cannot provide the tag)
- Machine with the tag key in its catalog
- After load: `w.Tag` is non-empty AND `isa(w.Tag, 'SensorTag')` AND `w.Tag.Key == 'pressure'`
- Negative: `TagRegistry.find(@(t) true)` returns empty (machine tag did not leak into registry)

**SC2 (legacy backward compat):**
- TagRegistry populated with legacy tags
- No machine resolver supplied
- After load: `w.Tag` is non-empty
- No `FastSenseWidget:tagResolverMissing` warning emitted (use `warning('query', ...)` capture or `verifyWarningFree`)

**SC3 (fleet tag without resolver → warning, no crash):**
- TagRegistry empty
- No resolver supplied
- Load succeeds (no error thrown)
- `w.Tag` is empty (`[]`)
- Warning `'FastSenseWidget:tagResolverMissing'` was emitted — captured via `verifyWarning` or `warning('error', ...)` / try-catch

**SC4 (.m export machine-scoped form):**
- Call `exportScript(config, filepath, 'machine')` with a config containing `source.type='tag'`
- `fileread(filepath)` contains `machine.get('pressure')`
- `fileread(filepath)` does NOT contain `TagRegistry.get('pressure')`
- Negative: call `exportScript(config, filepath)` (no machineVar) — output contains `TagRegistry.get('pressure')`

### Sampling Rate

- **Per task commit:** Run `TestFleetDashboardResolver` only
- **Per wave merge:** Full `tests/run_all_tests.m` including Octave flat `test_dashboard_resolver`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `tests/suite/TestFleetDashboardResolver.m` — covers SC1/SC2/SC3/SC4 (RED before implementation)
- [ ] `tests/test_dashboard_resolver.m` — Octave flat companion for SC1/SC3 (RED before implementation)

---

## State of the Art

No external tooling change. The resolver pattern mirrors the established DI seam from Phase 1042 (pipeline `tagSource_`). [VERIFIED: ARCHITECTURE.md and codebase audit]

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No resolver; only `TagRegistry.get` in fromStruct | Optional resolver arg; falls back to `TagRegistry.get` | Phase 1043 | Fleet dashboards can load with machine-scoped tags |
| `linesForWidget` has no `'tag'` case | `'tag'` case with machineVar conditional | Phase 1043 | Fleet dashboards can be exported to `.m` with correct tag references |

**Deprecated/outdated:**
- Warning ID `'FastSenseWidget:tagNotFound'` on the tag-miss path — replaced by `'FastSenseWidget:tagResolverMissing'` which is more actionable. The old ID fired for any miss; the new ID fires only on the no-resolver miss path, which is the fleet-dashboard-without-resolver signal.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is code/config changes only. No external CLIs, databases, or services required beyond the existing MATLAB session already running.

---

## Security Domain

Step: SKIPPED — no authentication, session management, cryptography, or user-facing input validation introduced. The resolver is a function handle injected by trusted caller code (not user input). No ASVS categories applicable.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `DashboardSerializer.save()` inline switch (`:30-88`) is distinct from `linesForWidget` and not called by fleet workflows in 1043 — deferring `'tag'` case addition to save() to 1046 is safe | Seam 5 / Pitfall 4 | If save() IS called by a 1043 test scenario, tag widgets would export without binding; easily caught by a test |
| A2 | No existing tests assert `'FastSenseWidget:tagNotFound'` warning ID specifically | Backward-Compat Guarantee | If a test asserts the old ID, it would fail after 1043 changes the ID on the miss path; mitigated by grep before implementing |
| A3 | Leaving the resolver-call unwrapped (no try/catch when `tagResolver(key)` throws) is correct for 1043 scope | Exact Code Seams / Seam 1 | If 1046 needs graceful partial binding on resolver miss, it will add the try/catch then; no regression risk now since Machine.get throwing on unknown key is the correct signal |

**If this table is empty:** Not empty — A1/A2/A3 are the three assumptions needing verification before implementation.

---

## Open Questions

1. **NV key naming in DashboardEngine.load**
   - What we know: current key is `'SensorResolver'` (`:4348`); D-01 specifies `'TagResolver'`
   - What's unclear: whether any existing code (examples, user scripts, companion) calls `DashboardEngine.load` with `'SensorResolver'` and expects the sensor-resolver behavior
   - Recommendation: Add `'TagResolver'` as a new accepted key; keep `'SensorResolver'` for backward compat; document that `'TagResolver'` is the v5.0 key

2. **Resolver call try/catch policy**
   - What we know: D-03 specifies the no-resolver miss path gets try/catch; the resolver path is unspecified
   - What's unclear: whether a resolver that throws for an unknown key should crash the load or emit a different warning
   - Recommendation: Leave resolver path unwrapped in 1043 (throw = programming error); 1046 adds graceful partial binding if DASH-04 requires it

3. **linesForWidget machineVar arg position (4th vs named)**
   - What we know: current signature is `linesForWidget(ws, pos, indent)` — positional
   - What's unclear: whether adding a 4th positional arg is cleanest or whether the function should accept a struct of options
   - Recommendation: 4th positional with `nargin < 4` guard is consistent with the existing 3-arg pattern in this file; no need for a named-arg complexity

---

## Sources

### Primary (HIGH confidence — direct code audit 2026-06-07)

- `libs/Dashboard/FastSenseWidget.m:1500-1540` — fromStruct current implementation; `:1516` TagRegistry.get call [VERIFIED]
- `libs/Dashboard/DashboardSerializer.m:388-411` — configToWidgets resolver hook (sensor-only) [VERIFIED]
- `libs/Dashboard/DashboardSerializer.m:413-460` — createWidgetFromStruct current 1-arg signature [VERIFIED]
- `libs/Dashboard/DashboardSerializer.m:470-510` — exportScript (no machineVar) [VERIFIED]
- `libs/Dashboard/DashboardSerializer.m:510-570` — exportScriptPages (no machineVar) [VERIFIED]
- `libs/Dashboard/DashboardSerializer.m:775-830` — linesForWidget switch (no 'tag' case) [VERIFIED]
- `libs/Dashboard/DashboardEngine.m:4345-4412` — load() varargin parse + multi-page loop gap at :4384 [VERIFIED]
- `libs/SensorThreshold/TagRegistry.m:47-65` — get() throws `TagRegistry:unknownKey` on miss [VERIFIED]
- `libs/Fleet/Machine.m:157-168` — get() throws `Machine:unknownKey` on miss [VERIFIED]
- `tests/suite/TestDashboardSerializer.m` — existing test structure; no warning-ID assertions [VERIFIED]
- `tests/test_machine.m` — Octave flat test pattern for 1042 [VERIFIED]
- `.planning/config.json` — `nyquist_validation: true` [VERIFIED]

### Secondary (HIGH confidence — milestone research)

- `.planning/research/ARCHITECTURE.md:111-202` — Q2 resolver seam design [CITED]
- `.planning/research/ARCHITECTURE.md:457-461` — Anti-Pattern 2 (no machineId in structs) [CITED]
- `.planning/research/SUMMARY.md:141-151` — Phase 3 scope and exit gates [CITED]
- `.planning/phases/1043-dashboardserializer-resolver-seam-backward-compat/1043-CONTEXT.md` — locked decisions D-01..D-07 [CITED]

---

## Metadata

**Confidence breakdown:**
- Exact code seams: HIGH — read every file:line directly at current HEAD
- TagRegistry/Machine miss behavior: HIGH — read source, confirmed throw semantics
- Test structure and fixture strategy: HIGH — existing test patterns confirmed
- linesForWidget 'tag' gap: HIGH — confirmed by grep + direct read (no 'tag' case exists)
- Warning ID convention: HIGH — confirmed in CLAUDE.md and existing code

**Research date:** 2026-06-07
**Valid until:** Stable — pure MATLAB, no external versioning; valid until DashboardSerializer or DashboardEngine changes
