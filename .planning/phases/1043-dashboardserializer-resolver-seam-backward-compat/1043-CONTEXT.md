# Phase 1043: DashboardSerializer Resolver Seam + Backward Compat - Context

**Gathered:** 2026-06-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Thread an optional machine-scoped tag resolver through the **full** Dashboard load path so machine-bound tag widgets resolve via the injected resolver instead of the global `TagRegistry` — closing the `FastSenseWidget.fromStruct:1516` gap (the `source.type='tag'` path calls `TagRegistry.get` directly, bypassing the resolver) and the `DashboardEngine.m:4384` gap (the multi-page load path drops the resolver) — while pre-v5.0 single-machine dashboards (JSON **and** `.m`) load byte-for-byte unchanged.

Covers **DASH-01, DASH-02**.

Out of this phase: Fleet clone/remap (1046), comparison (1045), companion machine wiring (1044), the Machine/Fleet model (1042 — shipped + verified).
</domain>

<decisions>
## Implementation Decisions

User selected "[No preference]" — all decisions locked at Claude's discretion.

### Resolver threading (DASH-01, SC1)
- **D-01:** Add an optional `tagResolver` (fn handle `@(localKey) machine.get(localKey)`) threaded `DashboardEngine.load(..., 'TagResolver', r)` → `DashboardSerializer.configToWidgets(config, resolver)` → `createWidgetFromStruct(ws, resolver)` → `FastSenseWidget.fromStruct(s, tagResolver)`. The `configToWidgets` resolver hook (`DashboardSerializer.m:388`) currently only resolves the legacy `source.type='sensor'` path (`:402`); extend it to pass the resolver into `createWidgetFromStruct` so the `source.type='tag'` path (`fromStruct:1516`) uses it.
- **D-02:** Close the multi-page gap at `DashboardEngine.m:4384` — the per-page `createWidgetFromStruct` call must receive the same resolver the single-page path already passes at `:4412`.

### Missing-tag / no-resolver behavior (DASH-02, SC2 + SC3)
- **D-03:** `fromStruct(s, tagResolver)`: if `tagResolver` supplied → `obj.Tag = tagResolver(s.source.key)`. Else try `TagRegistry.get(s.source.key)` in try/catch; on success use it (legacy backward-compat, no warning); on miss → `warning('FastSenseWidget:tagResolverMissing', 'tag ''%s'' not in TagRegistry and no machine resolver supplied — pass a machine resolver to load a fleet dashboard', key)` and leave `obj.Tag = []` (loud, non-crashing).
- **D-04:** Default behavior with no resolver = `TagRegistry.get` (SC2 backward-compat). The warning fires ONLY on the registry-miss path (the fleet-tag-without-resolver case, SC3). Pure legacy dashboards (keys present in the global registry) warn never.

### .m export machine-scoping (DASH-01, SC4)
- **D-05:** Add an optional machine-variable-name argument to the `.m` export path (`linesForWidget` / `exportScript` / `exportScriptPages`). When supplied (fleet export) → tag widgets emit `<machineVar>.get('key')`; when absent (legacy export) → `TagRegistry.get('key')` as today. `machineId` is NOT stored in widget structs (research Anti-Pattern 2); the machine context comes from the export caller. Apply uniformly via the shared `linesForWidget` helper (covers single-page + multi-page emission at `:44/47/793/796`).

### Backward-compat + tests (DASH-02)
- **D-06:** Add a class suite (extend `TestDashboardSerializer` or new `TestFleetDashboardResolver`) covering: (a) legacy single-machine JSON loads with no resolver → tags via `TagRegistry.get`, bound, no warning; (b) multi-page fleet JSON + injected resolver → page-2 tag widgets resolve via the resolver, not `TagRegistry.get`; (c) fleet JSON, no resolver → `FastSenseWidget:tagResolverMissing` warning, no crash, `Tag` empty; (d) `.m` export with a machineVar → emits the machine-scoped form, no bare `TagRegistry.get` for fleet widgets. Prefer a synthetic in-test JSON fixture for determinism; assert against ≥1 real legacy `examples/` dashboard if a stable one exists.
- **D-07:** Add an Octave flat companion test for the resolver-threading + warning logic (`fromStruct`/`configToWidgets` build Tag objects without rendering, so they are Octave-safe), per the project's class-suite-MATLAB-only / flat-`test_*`-Octave split.

### Claude's Discretion
The planner may refine exact arg form (`'TagResolver'` NV vs positional), warning-id spelling, and test-file naming as long as SC1–SC4 and backward-compat hold.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Specs
- `.planning/REQUIREMENTS.md` §"Per-Machine Dashboards & Clone/Remap (DASH)" — DASH-01, DASH-02
- `.planning/ROADMAP.md` §"Phase 1043" — goal + 4 success criteria; depends on 1042
- `.planning/research/SUMMARY.md` §"Phase 3: DashboardSerializer Resolver Seam + Backward-Compat Tests" + Pitfall 2 (resolver propagation gap) + Pitfall 10 (backward-compat break)
- `.planning/research/ARCHITECTURE.md` §"Question 2: DashboardSerializer Resolver Seam" (lines 111-202) + §"Anti-Pattern 2: Storing machineId in Widget Structs"
- `.planning/phases/1042-machine-fleet-pipeline-di-seam/1042-CONTEXT.md` (the `Machine.get(localKey)` resolver target) + `1042-VERIFICATION.md` (Machine shipped/verified)

### Exact code seams
- `libs/Dashboard/FastSenseWidget.m:1501-1516` — `fromStruct`; `:1516` `obj.Tag = TagRegistry.get(s.source.key)` (the tag-path seam needing `tagResolver`)
- `libs/Dashboard/DashboardSerializer.m:388-411` — `configToWidgets(config, resolver)` hook (sensor-only today, `:402`); `:44/47/793/796` — `linesForWidget` `TagRegistry.get('%s')` emission
- `libs/Dashboard/DashboardEngine.m:4346-4412` — `load` resolver varargin (`:4346/4349`); multi-page path `:4384` drops it; single-page `:4412` passes it
- `libs/SensorThreshold/TagRegistry.m` — `get` (the default resolver; its miss/duplicate error behavior)
- `CLAUDE.md` — conventions, error-id `ClassName:camelCaseProblem`, Octave parity, class-suite/flat-test split

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `configToWidgets` already accepts a `resolver` arg (`:388`); `DashboardEngine.load` already parses a resolver varargin (`:4346/4349`) and passes it single-page (`:4412`) — the threading is **half-built**. 1043 completes it (tag path + multi-page).
- `linesForWidget` is the shared `.m` emission helper (eliminates `exportScript`/`exportScriptPages` drift) — the single choke-point for the machineVar emission switch.
- `Machine.get(localKey)` (1042) is the resolver target.

### Established Patterns
- Optional-arg-with-backward-compatible-default (`resolver=[]` → `TagRegistry.get`) mirrors 1042's `tagSource_` DI seam.
- try/catch-around-`TagRegistry.get` to distinguish legacy (hit) from fleet (miss) without storing fleet-ness in the struct.

### Integration Points
- 1044 companion passes `@(k) machine.get(k)` as the resolver when loading a machine's dashboards.
- 1046 clone/remap uses the `.m` export machineVar form.

</code_context>

<specifics>
## Specific Ideas
- Warning must be loud + non-crashing + non-silent (SC3); trigger = a fleet tag missing from the global registry with no resolver.
- Legacy dashboards byte-for-byte unchanged (SC2) — default path = `TagRegistry.get`, zero new warnings on the hit path.

</specifics>

<deferred>
## Deferred Ideas
- Actual fleet-dashboard export wiring (which caller passes the machineVar) — exercised in 1046 clone/remap; 1043 only makes the export CAPABLE + tested.
- Resolver-inverse / auto-detecting a Tag's owning machine — not needed; machine context comes from the caller.

None are scope creep.

</deferred>

---

*Phase: 1043-dashboardserializer-resolver-seam-backward-compat*
*Context gathered: 2026-06-07*
