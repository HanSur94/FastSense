---
phase: 1042-machine-fleet-pipeline-di-seam
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/SensorThreshold/BatchTagPipeline.m
  - libs/SensorThreshold/LiveTagPipeline.m
autonomous: true
requirements: [FLEET-03]
must_haves:
  truths:
    - "A caller can scope a pipeline to a custom tag source via the 'TagSource' NV-pair"
    - "A caller that supplies no 'TagSource' gets the exact pre-existing single-machine behavior (default @TagRegistry.find)"
    - "Both pipelines' eligibleTags_ predicate bodies stay byte-semantically identical to each other"
  artifacts:
    - path: "libs/SensorThreshold/BatchTagPipeline.m"
      provides: "tagSource_ DI seam + 'TagSource' NV-pair; eligibleTags_ calls obj.tagSource_(pred)"
      contains: "tagSource_"
    - path: "libs/SensorThreshold/LiveTagPipeline.m"
      provides: "identical tagSource_ DI seam; SharedRoot/cluster path untouched"
      contains: "tagSource_"
  key_links:
    - from: "libs/SensorThreshold/BatchTagPipeline.m"
      to: "obj.tagSource_"
      via: "eligibleTags_ predicate enumeration"
      pattern: "tags = obj\\.tagSource_\\("
    - from: "libs/SensorThreshold/LiveTagPipeline.m"
      to: "obj.tagSource_"
      via: "eligibleTags_ predicate enumeration"
      pattern: "tags = obj\\.tagSource_\\("
---

<objective>
Add the `tagSource_` dependency-injection seam to `BatchTagPipeline` and `LiveTagPipeline` per D-12 so a Machine can scope ingestion to its own isolated catalog while every existing single-machine caller is byte-for-byte unchanged. The seam is a private fn-handle property defaulting to `@TagRegistry.find`, exposed via a new `'TagSource'` constructor NV-pair, with `eligibleTags_` calling `obj.tagSource_(pred)` instead of the static `TagRegistry.find`.

Purpose: FLEET-03 requires a machine to ingest into its own DataRoot via the existing pipelines without touching the global registry, with single-machine usage preserved exactly. This is the minimal additive edit that makes Machine.ingestBatch/startLive (Plan 03) possible.
Output: Two modified pipeline files; default behavior unchanged; new opt-in NV-pair.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/1042-machine-fleet-pipeline-di-seam/1042-CONTEXT.md
@.planning/phases/1042-machine-fleet-pipeline-di-seam/1042-RESEARCH.md
@.planning/phases/1042-machine-fleet-pipeline-di-seam/1042-PATTERNS.md
</context>

<artifacts_this_phase_produces>
See `1042-01-...-PLAN.md` <artifacts_this_phase_produces> for the full phase symbol list. This plan introduces: the `'TagSource'` constructor NV-pair and the `tagSource_` private property on both `BatchTagPipeline.m` and `LiveTagPipeline.m`.
</artifacts_this_phase_produces>

<tasks>

<task type="auto">
  <name>Task 1: Add tagSource_ DI seam to BatchTagPipeline.m</name>
  <files>libs/SensorThreshold/BatchTagPipeline.m</files>
  <read_first>
    - libs/SensorThreshold/BatchTagPipeline.m lines 41-74 (private properties block), 85-117 (constructor: opts struct line 85, switch with `otherwise` at line 97, prop assignments lines 114-115), 251-261 (eligibleTags_ at line 251, `TagRegistry.find` at line 256)
    - libs/SensorThreshold/BatchTagPipeline.m around line 43 for the existing `writeFn_`/`setWriteFnForTesting_` DI idiom to mirror
    - 1042-PATTERNS.md "BatchTagPipeline.m (modify — DI seam only)" section (the three additive changes, verbatim)
  </read_first>
  <action>
    Make exactly three additive changes to `BatchTagPipeline.m`, no other edits:
    (1) Add a private property `tagSource_ = @TagRegistry.find` to the private properties block (the seam default; comment it as FLEET-03/D-12 single-machine default).
    (2) Add `'TagSource', @TagRegistry.find` to the `opts = struct(...)` initializer at line 85, and add a `case 'TagSource'` that sets `opts.TagSource = varargin{k+1};` to the constructor switch BEFORE the `otherwise` guard at line 97 (the `otherwise` hard-errors `TagPipeline:invalidOutputDir` on unknown keys, so the case must precede it). After the switch loop, alongside the existing `obj.Verbose = opts.Verbose;` (line 115), add `obj.tagSource_ = opts.TagSource;`.
    (3) Change `eligibleTags_` signature from `function tags = eligibleTags_(~)` to `function tags = eligibleTags_(obj)` and change the `TagRegistry.find(@(t) ...)` call at line 256 to `obj.tagSource_(@(t) ...)`. Keep the predicate body byte-identical (`(isa(t,'SensorTag')||isa(t,'StateTag')) && isstruct(t.RawSource) && isfield(t.RawSource,'file') && ~isempty(t.RawSource.file)`).
    Do NOT touch `run()`, the disk-write path, or any other method.
  </action>
  <verify>
    <automated>mcp__matlab__run_matlab_test_file 'tests/suite/TestBatchTagPipeline.m' (existing suite must stay green if present); plus mcp__matlab__check_matlab_code on BatchTagPipeline.m</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "tagSource_ = @TagRegistry.find" libs/SensorThreshold/BatchTagPipeline.m` >= 1 (property default present).
    - `grep -nE "case 'TagSource'" libs/SensorThreshold/BatchTagPipeline.m` appears and is on a line number LESS THAN the `otherwise` line in the constructor switch.
    - `grep -c "tags = obj.tagSource_(" libs/SensorThreshold/BatchTagPipeline.m` == 1 and `grep -v '^[[:space:]]*%' libs/SensorThreshold/BatchTagPipeline.m | grep -c "TagRegistry.find"` == 0 (no live static call remains in eligibleTags_; the only `TagRegistry.find` tokens left are the property default + opts default, which are `@TagRegistry.find` handles, not calls).
    - `eligibleTags_` signature is `function tags = eligibleTags_(obj)` (not `(~)`).
    - MATLAB MCP smoke: `p = BatchTagPipeline('OutputDir', tempname);` constructs with no 'TagSource' arg and `isequal(func2str(p_default_tagsource), 'TagRegistry.find')`-equivalent default holds (verify by running an existing single-machine batch ingest test and confirming it still passes unchanged).
    - `p = BatchTagPipeline('OutputDir', tempname, 'TagSource', @(pred) {});` constructs without raising `TagPipeline:invalidOutputDir`.
    - `mcp__matlab__check_matlab_code` clean.
  </acceptance_criteria>
  <done>BatchTagPipeline exposes a `'TagSource'` NV-pair backed by `tagSource_` (default `@TagRegistry.find`); `eligibleTags_` enumerates via `obj.tagSource_`; existing single-machine batch tests pass unchanged; unknown-option guard still rejects truly unknown keys.</done>
</task>

<task type="auto">
  <name>Task 2: Add identical tagSource_ DI seam to LiveTagPipeline.m</name>
  <files>libs/SensorThreshold/LiveTagPipeline.m</files>
  <read_first>
    - libs/SensorThreshold/LiveTagPipeline.m lines 155-164 (private properties incl. IsClusterMode_ at 159, SharedRoot_ at 161), 178-228 (constructor: opts struct lines 178-180, switch cases incl. SharedRoot at 196, `otherwise` at 200, prop assignments lines 217-227, IsClusterMode_ gate at 227), 786-806 (eligibleTags_ at 786, `TagRegistry.find` at 801)
    - libs/SensorThreshold/BatchTagPipeline.m (the just-modified sibling — both eligibleTags_ predicates must stay byte-semantically identical)
    - 1042-PATTERNS.md "LiveTagPipeline.m (modify — DI seam only)" section
  </read_first>
  <action>
    Apply the same three additive changes as BatchTagPipeline, at the LiveTagPipeline seam locations:
    (1) Add `tagSource_ = @TagRegistry.find` to the private properties block (near line 164), commented FLEET-03/D-12, mirrors BatchTagPipeline.
    (2) Add `'TagSource', @TagRegistry.find` to the `opts = struct(...)` initializer (lines 178-180; append the field), and add a `case 'TagSource'` setting `opts.TagSource = varargin{k+1};` to the switch BEFORE the `otherwise` at line 200. After the switch, alongside `obj.Verbose = opts.Verbose;` (line 220), add `obj.tagSource_ = opts.TagSource;`. Place the assignment so it runs regardless of the `IsClusterMode_` branch (it is independent of cluster mode).
    (3) Change `eligibleTags_(~)` (line 786) to `eligibleTags_(obj)` and the `TagRegistry.find(@(t) ...)` at line 801 to `obj.tagSource_(@(t) ...)`, keeping the predicate body byte-identical to BatchTagPipeline's. Preserve the existing comment that the body must stay in lockstep with BatchTagPipeline.
    Do NOT touch the SharedRoot/cluster path (`IsClusterMode_`, `Coordinator_`, `SharedPaths`), the timer, or any tick logic. The cluster gate at line 227 (`~isempty(opts.SharedRoot)`) is unchanged — omitting SharedRoot still runs zero cluster-path code.
  </action>
  <verify>
    <automated>mcp__matlab__run_matlab_test_file 'tests/suite/TestLiveTagPipeline.m' (existing suite must stay green if present); plus mcp__matlab__check_matlab_code on LiveTagPipeline.m</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "tagSource_ = @TagRegistry.find" libs/SensorThreshold/LiveTagPipeline.m` >= 1.
    - `grep -nE "case 'TagSource'" libs/SensorThreshold/LiveTagPipeline.m` appears at a line number LESS THAN the constructor `otherwise` line.
    - `grep -c "tags = obj.tagSource_(" libs/SensorThreshold/LiveTagPipeline.m` == 1 and `grep -v '^[[:space:]]*%' libs/SensorThreshold/LiveTagPipeline.m | grep -c "TagRegistry.find"` counts only the two `@TagRegistry.find` default handles (property + opts), zero live static calls inside eligibleTags_.
    - The two `eligibleTags_` predicate bodies in BatchTagPipeline.m and LiveTagPipeline.m are character-identical between the `tagSource_(@(t)` and the closing `~isempty(t.RawSource.file))` (diff the predicate region; must match).
    - SharedRoot/cluster lines unchanged: `grep -c "IsClusterMode_" libs/SensorThreshold/LiveTagPipeline.m` equals its pre-edit count (no cluster lines added/removed).
    - MATLAB MCP smoke: `LiveTagPipeline('OutputDir', tempname)` constructs (single-user default) AND `LiveTagPipeline('OutputDir', tempname, 'TagSource', @(pred) {})` constructs without `TagPipeline:invalidOutputDir`; an existing single-user live-pipeline test still passes.
    - `mcp__matlab__check_matlab_code` clean.
  </acceptance_criteria>
  <done>LiveTagPipeline exposes the same `'TagSource'` NV-pair / `tagSource_` seam; `eligibleTags_` enumerates via `obj.tagSource_`; the predicate body is byte-identical to BatchTagPipeline's; the SharedRoot/cluster path is untouched; single-user live tests pass unchanged.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| caller -> pipeline constructor | `'TagSource'` is a caller-supplied fn-handle; pipeline invokes it as the tag enumerator |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1042-02 | Tampering | `'TagSource'` fn-handle injected into pipeline enumeration | accept | Script-only local API; the handle is supplied by the same trusting user script that runs the pipeline. No network/untrusted source. Default `@TagRegistry.find` preserves existing behavior; unknown keys still hard-error via the unchanged `otherwise` guard |
| T-1042-03 | Elevation of Privilege | DI seam bypasses TagRegistry | accept | By design: Machine scoping is the goal. Machine tags never enter the global registry (verified by Plan 03 grep gate `TagRegistry.register == 0`). No privilege boundary crossed |
| T-1042-SC | Tampering | npm/pip/cargo installs | n/a | No package installs — pure MATLAB, toolbox-free |
</threat_model>

<verification>
- Both pipelines construct with and without `'TagSource'`; default path unchanged.
- Existing single-machine pipeline test suites (Batch + Live) stay green — FLEET-03 "byte-for-byte unchanged" gate.
- `eligibleTags_` predicate bodies remain byte-identical between the two files.
- No live `TagRegistry.find(...)` call remains in either `eligibleTags_`.
- SharedRoot/cluster code untouched in LiveTagPipeline.
</verification>

<success_criteria>
- `tagSource_` DI seam present in both pipelines, default `@TagRegistry.find`, opt-in via `'TagSource'` NV-pair (case before `otherwise`).
- Single-machine callers run identically (existing Batch + Live suites green).
- Machine-scoped override works (`'TagSource', @(pred) machine.find(pred)` accepted) — consumed by Plan 03.
- Cluster mode (LiveTagPipeline SharedRoot path) unchanged.
</success_criteria>

<output>
Create `.planning/phases/1042-machine-fleet-pipeline-di-seam/1042-02-SUMMARY.md` when done.
</output>
