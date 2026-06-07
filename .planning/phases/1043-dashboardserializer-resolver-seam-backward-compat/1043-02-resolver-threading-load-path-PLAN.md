---
phase: 1043-dashboardserializer-resolver-seam-backward-compat
plan: 02
type: execute
wave: 1
depends_on: ["1043-01"]
files_modified:
  - libs/Dashboard/FastSenseWidget.m
  - libs/Dashboard/DashboardSerializer.m
  - libs/Dashboard/DashboardEngine.m
autonomous: true
requirements: [DASH-01, DASH-02]
nyquist_compliant: true

must_haves:
  truths:
    - "A fleet dashboard with tags on page 2 loads correctly — widgets on ALL pages resolve their tags via the injected machine resolver, not TagRegistry.get (D-01, D-02, SC1)"
    - "Pre-v5.0 single-machine JSON dashboards load byte-for-byte unchanged with no fleet objects present — the resolver defaults to TagRegistry.get when none is supplied, and zero new warnings fire on the registry-hit path (D-03, D-04, SC2)"
    - "Loading a fleet dashboard with no resolver injected emits warning FastSenseWidget:tagResolverMissing (loud) and leaves Tag empty (non-crashing) — not silent empty tags, not a crash (D-03, SC3)"
    - "DashboardEngine.load accepts BOTH 'TagResolver' (v5.0) and 'SensorResolver' (legacy) NV keys so neither fleet callers nor any existing callers break (RESEARCH Open Question 1)"
  artifacts:
    - path: "libs/Dashboard/FastSenseWidget.m"
      provides: "fromStruct(s, tagResolver) — optional 2nd arg; resolver path, legacy try/catch fallback, tagResolverMissing warning"
      contains: "FastSenseWidget:tagResolverMissing"
    - path: "libs/Dashboard/DashboardSerializer.m"
      provides: "createWidgetFromStruct(ws, tagResolver) forwarding; configToWidgets threading resolver into createWidgetFromStruct"
      contains: "createWidgetFromStruct(ws, tagResolver)"
    - path: "libs/Dashboard/DashboardEngine.m"
      provides: "load varargin accepts TagResolver+SensorResolver; multi-page loop passes resolver to createWidgetFromStruct"
      contains: "'TagResolver'"
  key_links:
    - from: "libs/Dashboard/DashboardEngine.m (load multi-page loop)"
      to: "DashboardSerializer.createWidgetFromStruct(pgWidgets{j}, resolver)"
      via: "resolver propagated into per-page widget construction (closes :4384 gap)"
      pattern: "createWidgetFromStruct\\(pgWidgets\\{j\\}, resolver\\)"
    - from: "libs/Dashboard/DashboardSerializer.m (createWidgetFromStruct)"
      to: "FastSenseWidget.fromStruct(ws, tagResolver)"
      via: "resolver forwarded into fastsense widget construction"
      pattern: "FastSenseWidget\\.fromStruct\\(ws, tagResolver\\)"
    - from: "libs/Dashboard/FastSenseWidget.m (fromStruct tag case)"
      to: "tagResolver(s.source.key) | TagRegistry.get(s.source.key)"
      via: "resolver-present branch vs legacy try/catch fallback branch"
      pattern: "tagResolver\\(s\\.source\\.key\\)"
---

<objective>
Complete the half-built resolver threading so a machine-scoped tag resolver reaches EVERY widget on EVERY page during load, while pre-v5.0 dashboards remain byte-for-byte unchanged. Three surgical edits across three files:

1. `FastSenseWidget.fromStruct(s, tagResolver)` — add the optional 2nd arg (D-01). Resolver present → `obj.Tag = tagResolver(s.source.key)` (machine path, no try/catch — a throwing resolver is a programming error, RESEARCH Open Question 2). Resolver absent → legacy `TagRegistry.get` in try/catch: hit binds the tag with NO warning (D-04, backward-compat); miss emits `warning('FastSenseWidget:tagResolverMissing', ...)` and leaves `obj.Tag = []` (D-03, loud + non-crashing).
2. `DashboardSerializer.createWidgetFromStruct(ws, tagResolver)` + `configToWidgets` — forward the resolver into `fromStruct` (D-01). `nargin < 2` default keeps all 1-arg callers unchanged.
3. `DashboardEngine.load` — accept BOTH `'TagResolver'` and `'SensorResolver'` NV keys (RESEARCH Open Question 1, resolved: ACCEPT BOTH), and pass the resolver into the multi-page loop at the `:4384` seam (D-02), which the single-page `:4412` path already does.

This closes the DASH-01 multi-page resolver gap and the DASH-02 backward-compat requirement. Turns the SC1/SC2/SC3 assertions in `TestFleetDashboardResolver` and `test_dashboard_resolver` (Plan 01) from RED to GREEN.

RESEARCH Open Question 2 is resolved explicitly in scope: the resolver-PATH (resolver supplied but key missing) is left UNWRAPPED in 1043 — a throwing resolver propagates as an error (wrong resolver injected). Graceful partial binding when a resolver is supplied but a key is missing is DEFERRED to Phase 1046 (DASH-04 scope); this plan does not add a try/catch around the resolver call.

Purpose: Make fleet dashboards loadable via machine context on all pages without disturbing the legacy single-machine load path.
Output: Three edited library files; SC1/SC2/SC3 GREEN.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/1043-dashboardserializer-resolver-seam-backward-compat/1043-CONTEXT.md
@.planning/phases/1043-dashboardserializer-resolver-seam-backward-compat/1043-RESEARCH.md

# The exact seams (read the specific line ranges named per-task)
@libs/Dashboard/FastSenseWidget.m
@libs/Dashboard/DashboardSerializer.m
@libs/Dashboard/DashboardEngine.m
@libs/SensorThreshold/TagRegistry.m
@libs/Fleet/Machine.m
</context>

<artifacts_this_phase_produces>
This plan (02) produces:
- `FastSenseWidget.fromStruct(s, tagResolver)` — optional 2nd arg; resolver path + legacy try/catch fallback; `warning('FastSenseWidget:tagResolverMissing', ...)` replaces `FastSenseWidget:tagNotFound` on the tag-miss path.
- `DashboardSerializer.createWidgetFromStruct(ws, tagResolver)` — optional 2nd arg forwarding to fromStruct; all other widget cases unchanged.
- `DashboardSerializer.configToWidgets(config, resolver)` — resolver passed into createWidgetFromStruct; the existing post-hoc `source.type='sensor'` block retained for backward-compat.
- `DashboardEngine.load(..., 'TagResolver', r)` accepting BOTH `'TagResolver'` and `'SensorResolver'`; multi-page loop at the former :4384 passes the resolver.
- The `FastSenseWidget:tagResolverMissing` warning id.
(The `.m` export machine-scoping — `linesForWidget` `'tag'` case + machineVar — is Plan 03.)
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: fromStruct gains optional tagResolver arg with resolver/legacy/warning branches</name>
  <files>libs/Dashboard/FastSenseWidget.m</files>
  <read_first>
    - libs/Dashboard/FastSenseWidget.m:1500-1540 (fromStruct current 1-arg signature at :1501; tag case at :1513-1521 calling TagRegistry.get at :1516 with FastSenseWidget:tagNotFound warning at :1518; the existing `exist('TagRegistry','class')` Octave guard at :1514)
    - libs/SensorThreshold/TagRegistry.m:47-65 (get throws error('TagRegistry:unknownKey',...) on miss — confirms the try/catch fires on miss, does NOT return [])
    - libs/Fleet/Machine.m:157-168 (get throws Machine:unknownKey on miss — confirms an unwrapped resolver call propagates as an error, which is the intended 1043 behavior per RESEARCH Open Question 2)
    - .planning/phases/.../1043-RESEARCH.md §"Seam 1" (lines 155-199) and §"Common Pitfalls" 2 + 6 (warning-id convention; exist-guard only wraps the legacy branch)
  </read_first>
  <action>
    Per D-01/D-03/D-04: change the static method signature from `function obj = fromStruct(s)` to `function obj = fromStruct(s, tagResolver)` and add `if nargin < 2, tagResolver = []; end` as the first line. In the `case 'tag'` branch, replace the current TagRegistry-only logic with a three-way structure:
    - If `~isempty(tagResolver)`: set `obj.Tag = tagResolver(s.source.key)` directly. Do NOT wrap this in try/catch — a resolver that throws for an unknown key is a programming error (wrong resolver injected); let it propagate. This is the explicit 1043 decision (RESEARCH Open Question 2); graceful partial-binding on a supplied-resolver miss is deferred to 1046.
    - Else if `exist('TagRegistry', 'class')` (preserve the Octave guard on the legacy branch only): try `obj.Tag = TagRegistry.get(s.source.key)`. On the catch (registry miss — TagRegistry.get throws TagRegistry:unknownKey), emit `warning('FastSenseWidget:tagResolverMissing', 'Tag ''%s'' not found in TagRegistry and no machine resolver supplied — pass a TagResolver to DashboardEngine.load to load a fleet dashboard.', s.source.key)` and leave `obj.Tag` as its default `[]`. This replaces the old `FastSenseWidget:tagNotFound` warning id on the tag-miss path (D-03).

    Leave the `'sensor'`, `'file'`, `'data'` cases and the rest of fromStruct completely untouched. Keep the header comment accurate (note the optional tagResolver arg). Keep all lines <= 160 chars; do not exceed nesting depth 5. The hit path (legacy tag present in registry) must execute the same code and produce no warning — byte-for-byte behavioral equivalence except the warning id on the miss path (RESEARCH §"Backward-Compat Guarantee").
  </action>
  <verify>
    <automated>mcp__matlab__check_matlab_code on libs/Dashboard/FastSenseWidget.m returns no errors; then mcp__matlab__evaluate_matlab_code running `install(); test_dashboard_resolver()` — all 3 flat-test assertions (resolver / no-resolver-miss-warning / legacy-hit) now PASS (the file-level GREEN signal for this task; full multi-page suite is Task 3's gate).</automated>
  </verify>
  <acceptance_criteria>
    - Signature has 2 args: `grep -cE "function obj = fromStruct\(s, tagResolver\)" libs/Dashboard/FastSenseWidget.m` returns 1
    - nargin guard present: `grep -c "if nargin < 2, tagResolver = \[\]; end" libs/Dashboard/FastSenseWidget.m` >= 1
    - Resolver path present: `grep -c "tagResolver(s.source.key)" libs/Dashboard/FastSenseWidget.m` >= 1
    - New warning id present: `grep -c "FastSenseWidget:tagResolverMissing" libs/Dashboard/FastSenseWidget.m` >= 1
    - Old tag-miss warning id removed from the tag path: the only remaining `FastSenseWidget:tagNotFound` (if any) must NOT be in fromStruct's tag case — `grep -n "FastSenseWidget:tagNotFound" libs/Dashboard/FastSenseWidget.m` shows no occurrence inside fromStruct (verify by line range against the fromStruct method)
    - Legacy exist-guard retained on fallback: `grep -c "exist('TagRegistry', 'class')" libs/Dashboard/FastSenseWidget.m` >= 1
    - No `contains(` introduced: `grep -c "contains(" libs/Dashboard/FastSenseWidget.m` returns 0
    - check_matlab_code reports no errors
    - `install(); test_dashboard_resolver()` prints "All 3 tests passed."
  </acceptance_criteria>
  <done>fromStruct accepts an optional tagResolver; resolver-present binds via the resolver (unwrapped), resolver-absent falls back to TagRegistry.get in try/catch (hit = no warning, miss = FastSenseWidget:tagResolverMissing + Tag=[]); the Octave flat test passes all 3 assertions.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: createWidgetFromStruct + configToWidgets thread the resolver into fromStruct</name>
  <files>libs/Dashboard/DashboardSerializer.m</files>
  <read_first>
    - libs/Dashboard/DashboardSerializer.m:388-411 (configToWidgets(config, resolver): nargin guard at :393; calls createWidgetFromStruct(ws) WITHOUT resolver at :397; the post-hoc source.type='sensor' resolver block at :399-407)
    - libs/Dashboard/DashboardSerializer.m:413-460 (createWidgetFromStruct(ws): 1-arg signature at :413; case 'fastsense' calls FastSenseWidget.fromStruct(ws) at :418; all other widget cases below do NOT take a resolver)
    - .planning/phases/.../1043-RESEARCH.md §"Seam 2" + §"Seam 3" (lines 201-253) and §"Common Pitfalls" 3 (createWidgetFromStruct is a public static called 1-arg from TestDashboardSerializer round-trip tests — nargin guard must keep those byte-for-byte valid)
  </read_first>
  <action>
    Per D-01: change `function w = createWidgetFromStruct(ws)` to `function w = createWidgetFromStruct(ws, tagResolver)` and add `if nargin < 2, tagResolver = []; end` as the first line. In the `case 'fastsense'` branch, change `FastSenseWidget.fromStruct(ws)` to `FastSenseWidget.fromStruct(ws, tagResolver)`. Leave EVERY other widget case (`number`, `status`, `text`, `gauge`, `table`, `rawaxes`, `timeline`, `group`, `heatmap`, `barchart`, `histogram`, `scatter`, `image`, `multistatus`, `divider`, `iconcard`, `chipbar`, `sparkline`, `mock`, etc.) unchanged — they have no tag binding and must not receive the resolver.

    In `configToWidgets`, change the construction call from `DashboardSerializer.createWidgetFromStruct(ws)` to `DashboardSerializer.createWidgetFromStruct(ws, resolver)` so the tag resolver reaches fromStruct during construction. KEEP the existing post-hoc `source.type='sensor'` resolver block (lines :399-407) exactly as-is — it is the legacy sensor-resolution hook for old `type='sensor'` JSON and is harmless for fleet tags (which use `type='tag'`, resolved inside fromStruct). Keep the `nargin < 2, resolver = []` guard. The single resolver arg now serves both the tag path (threaded into fromStruct) and the legacy sensor post-hoc block — this is correct because the fleet resolver is `@(localKey) machine.get(localKey)` and the sensor block only fires for `type='sensor'` widgets (RESEARCH Seam 3 note).

    Keep all lines <= 160 chars. Do not touch save/exportScript/exportScriptPages/linesForWidget in this task — those are Plan 03. Verify no 1-arg caller breaks (the nargin guards guarantee this).
  </action>
  <verify>
    <automated>mcp__matlab__check_matlab_code on libs/Dashboard/DashboardSerializer.m returns no errors; then mcp__matlab__run_matlab_test_file on tests/suite/TestDashboardSerializerRoundTrip.m — the existing round-trip suite (1-arg configToWidgets/createWidgetFromStruct callers) stays GREEN, proving backward-compat of the nargin guards.</automated>
  </verify>
  <acceptance_criteria>
    - createWidgetFromStruct has 2 args: `grep -cE "function w = createWidgetFromStruct\(ws, tagResolver\)" libs/Dashboard/DashboardSerializer.m` returns 1
    - nargin guard present: `grep -c "if nargin < 2, tagResolver = \[\]; end" libs/Dashboard/DashboardSerializer.m` >= 1
    - fastsense case forwards resolver: `grep -c "FastSenseWidget.fromStruct(ws, tagResolver)" libs/Dashboard/DashboardSerializer.m` >= 1
    - configToWidgets threads resolver: `grep -c "createWidgetFromStruct(ws, resolver)" libs/Dashboard/DashboardSerializer.m` >= 1
    - Legacy sensor post-hoc block retained: `grep -c "DashboardSerializer:sensorNotFound" libs/Dashboard/DashboardSerializer.m` >= 1
    - No `contains(` introduced: `grep -c "contains(" libs/Dashboard/DashboardSerializer.m` returns 0
    - check_matlab_code reports no errors
    - TestDashboardSerializerRoundTrip runs GREEN (existing 1-arg callers unbroken)
  </acceptance_criteria>
  <done>createWidgetFromStruct accepts and forwards an optional tagResolver to FastSenseWidget.fromStruct; configToWidgets threads its resolver into createWidgetFromStruct; the legacy sensor post-hoc block and all non-fastsense cases are unchanged; the round-trip suite stays GREEN.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: DashboardEngine.load accepts TagResolver+SensorResolver and passes resolver into the multi-page loop</name>
  <files>libs/Dashboard/DashboardEngine.m</files>
  <read_first>
    - libs/Dashboard/DashboardEngine.m:4345-4414 (load(filepath, varargin): resolver varargin parse at :4346-4351 currently matching ONLY 'SensorResolver' at :4348; multi-page branch at :4377-4400 with the createWidgetFromStruct(pgWidgets{j}) call MISSING the resolver at :4384; single-page branch at :4410-4413 already passing resolver via configToWidgets(config, resolver) at :4412)
    - .planning/phases/.../1043-RESEARCH.md §"Seam 4" (lines 255-283) + §"Common Pitfalls" 1 (NV-key mismatch — accept both keys) + 5 (multi-page does NOT call configToWidgets, so the :4384 loop must be fixed independently)
    - libs/Fleet/Machine.m:157-168 (the resolver target @(k) machine.get(k))
  </read_first>
  <action>
    Per D-02 and RESEARCH Open Question 1 (resolved: ACCEPT BOTH keys): in the varargin parse loop, change the single `strcmp(varargin{k}, 'SensorResolver')` test to match EITHER `'TagResolver'` (the v5.0 key, D-01) OR `'SensorResolver'` (the existing key) — e.g. `if strcmp(varargin{k}, 'TagResolver') || strcmp(varargin{k}, 'SensorResolver')`. This means neither fleet callers (1044 passes `'TagResolver'`) nor any existing `'SensorResolver'` caller breaks. If both keys are supplied the last-wins behavior of the existing loop is acceptable; document that `'TagResolver'` is the canonical v5.0 key in the load() header comment.

    Per D-02: in the multi-page branch, change `w = DashboardSerializer.createWidgetFromStruct(pgWidgets{j});` to `w = DashboardSerializer.createWidgetFromStruct(pgWidgets{j}, resolver);` so the resolver reaches every page's widgets (closes the multi-page drop gap). The single-page path at the former :4412 already passes the resolver via `configToWidgets(config, resolver)` — leave it unchanged.

    Do NOT change any other behavior in load (ActivePage restore, ReflowCallback injection, GroupWidget handling, the `.m` feval branch). Update the load() doc comment to mention the `'TagResolver'`/`'SensorResolver'` NV pair. Keep all lines <= 160 chars; nesting depth <= 5.
  </action>
  <verify>
    <automated>mcp__matlab__check_matlab_code on libs/Dashboard/DashboardEngine.m returns no errors; then mcp__matlab__run_matlab_test_file on tests/suite/TestFleetDashboardResolver.m — SC1 (multi-page page-2 resolver), SC2 (legacy load no-resolver, no warning), and SC3 (no-resolver fleet miss → tagResolverMissing warning, no crash, Tag=[]) all turn GREEN. SC4 (.m export) remains RED until Plan 03.</automated>
  </verify>
  <acceptance_criteria>
    - Both NV keys accepted: `grep -c "'TagResolver'" libs/Dashboard/DashboardEngine.m` >= 1 AND `grep -c "'SensorResolver'" libs/Dashboard/DashboardEngine.m` >= 1
    - Multi-page loop passes resolver: `grep -c "createWidgetFromStruct(pgWidgets{j}, resolver)" libs/Dashboard/DashboardEngine.m` >= 1
    - Old resolver-less multi-page call gone: `grep -c "createWidgetFromStruct(pgWidgets{j});" libs/Dashboard/DashboardEngine.m` returns 0
    - Single-page path intact: `grep -c "configToWidgets(config, resolver)" libs/Dashboard/DashboardEngine.m` >= 1
    - No `contains(` introduced: `grep -c "contains(" libs/Dashboard/DashboardEngine.m` returns 0
    - check_matlab_code reports no errors
    - TestFleetDashboardResolver SC1/SC2/SC3 methods GREEN (SC4 may still be RED — Plan 03 closes it)
  </acceptance_criteria>
  <done>load accepts both 'TagResolver' and 'SensorResolver', the multi-page loop passes the resolver to createWidgetFromStruct, the single-page path is unchanged, and TestFleetDashboardResolver's SC1/SC2/SC3 tests are GREEN.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| dashboard JSON file → DashboardEngine.load | Loading a (potentially untrusted) dashboard JSON: malformed `source.key`, missing `source` field, oversized strings |
| caller → load (resolver fn handle) | The resolver `@(k) machine.get(k)` is an arbitrary function handle supplied by the caller — trusted-by-construction (caller is companion/clone code, not end-user input) |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1043-02-01 | Tampering | malformed `source.key` in loaded JSON | mitigate | fromStruct accesses `s.source.key` only inside `case 'tag'` (guarded by `isfield(s,'source')` + switch on `s.source.type`); a missing/garbage key flows to TagRegistry.get/resolver which throw a namespaced error or the documented tagResolverMissing warning — never a silent wrong binding |
| T-1043-02-02 | Denial of Service | oversized `source.key` string in JSON | accept | A long key only widens a warning/error message and a containers.Map lookup; no unbounded allocation or recursion; JSON parse limits are MATLAB's jsondecode, unchanged by this phase |
| T-1043-02-03 | Elevation of Privilege | resolver fn handle could execute arbitrary code | accept | The resolver is supplied by trusted caller code (companion/clone), not parsed from the dashboard file; it is trusted-by-construction. Documented, not over-engineered (per phase security note: no HIGH expected) |
| T-1043-02-04 | Spoofing | a fleet tag silently binding to a same-named global TagRegistry tag | mitigate | When a resolver IS supplied it takes precedence (resolver branch first); TagRegistry.get is only consulted on the no-resolver path — fleet load with a resolver can never silently fall through to a global tag |
| T-1043-02-SC | Tampering | npm/pip/cargo installs | accept | No package installs — pure MATLAB edits, no dependency additions |
</threat_model>

<verification>
- All three files parse clean (`check_matlab_code` no errors).
- `test_dashboard_resolver()` (Octave flat) passes all 3 assertions after Task 1.
- `TestDashboardSerializerRoundTrip` stays GREEN after Task 2 (backward-compat of nargin guards).
- `TestFleetDashboardResolver` SC1/SC2/SC3 GREEN after Task 3 (multi-page resolver, legacy no-warning, no-resolver miss warning).
- No `contains(` introduced in any of the three files (Octave parity invariant).
- Warning id is `FastSenseWidget:tagResolverMissing` on the tag-miss path; `FastSenseWidget:tagNotFound` no longer fires from fromStruct's tag case.
- After Task 3, run `tests/run_all_tests.m` (per-wave merge gate, VALIDATION.md) — full suite green except SC4 (Plan 03).
</verification>

<success_criteria>
- SC1 (DASH-01): page-2 tag widgets resolve via the injected resolver, not TagRegistry.get (multi-page :4384 gap closed).
- SC2 (DASH-02): legacy single-machine JSON loads unchanged, resolver defaults to TagRegistry.get, zero new warnings on the hit path.
- SC3 (DASH-02): no-resolver fleet-tag miss emits FastSenseWidget:tagResolverMissing, no crash, Tag empty.
- load accepts both 'TagResolver' and 'SensorResolver' (RESEARCH Open Question 1 resolved).
- Resolver-path try/catch deliberately OMITTED (RESEARCH Open Question 2 resolved: defer graceful partial-bind to 1046).
</success_criteria>

<output>
Create `.planning/phases/1043-dashboardserializer-resolver-seam-backward-compat/1043-02-SUMMARY.md` when done.
</output>
