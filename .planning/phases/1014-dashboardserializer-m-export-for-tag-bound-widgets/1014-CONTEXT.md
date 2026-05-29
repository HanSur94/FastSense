# Phase 1014: DashboardSerializer .m export for Tag-bound widgets - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning
**Mode:** Smart-discuss decisions inherited from milestone-level SUMMARY.md (Open Questions §2 + §3)

<domain>
## Phase Boundary

Add `case 'tag'` branches to `DashboardSerializer.save()` (line 38) and `DashboardSerializer.linesForWidget()` (line 598) so Tag-bound widgets round-trip through `.m` export with `TagRegistry.get('key')` lookups. Add a new suite test `tests/suite/TestDashboardSerializerTagExport.m` covering single-page + multi-page round-trip on MATLAB R2020b. Delete the now-vestigial `case 'sensor'` emitter branch (no in-memory widget emits `source.type='sensor'` post-v2.0).

JSON save path is already correct (uses per-widget `toStruct` which emits `s.source.type='tag'`); only the `.m` export paths need the `case 'tag'` branch. `FastSenseWidget.fromStruct` legacy `'sensor'` reader stays for backward-compat with old JSON files.

</domain>

<decisions>
## Implementation Decisions

### Lookup Strategy — Guarded `TagRegistry.get` via try/catch (locked from SUMMARY.md Open Question #2 → option C, refined 2026-04-28 after plan-checker found TagRegistry.has does not exist)

The emitted `.m` file reconstructs Tag-bound widgets with a try/catch guard around `TagRegistry.get`:

```matlab
try
    tag_press_a = TagRegistry.get('press_a');
catch
    error('DashboardSerializer:tagNotRegistered', ...
          'Tag ''press_a'' must be registered in TagRegistry before running this script');
end
d.addWidget('fastsense', 'Tag', tag_press_a, 'Position', [...], 'Title', '...');
```

Rationale: `TagRegistry.has(key)` does NOT exist on the public API of `libs/SensorThreshold/TagRegistry.m`. Verified by grep: `TagRegistry.get` throws `TagRegistry:unknownKey` on missing key — the natural pattern is to catch it and rethrow with the serializer's own error ID. This is option (b) from the plan-checker's fix options.

**NOT** plain `TagRegistry.get('k')` (would surface raw `TagRegistry:unknownKey` instead of the documented `DashboardSerializer:tagNotRegistered`). **NOT** adding a `TagRegistry.has(key)` method (scope creep into a different file — Pitfall 1; v2.1 is cleanup, not API extension).

### Legacy `case 'sensor'` Emitter — Delete (locked from SUMMARY.md Open Question #3)

- Delete the `case 'sensor'` branch from `linesForWidget` switch and `save()` switch.
- Keep `FastSenseWidget.fromStruct` `'sensor'` reader branch — legacy JSON files loaded from disk must still parse.
- This is a one-direction asymmetry: in-memory widgets always serialize as `'tag'` (post-v2.0); old JSON files read as `'sensor'` and migrate at load time to Tag-bound state.

### Multi-page Coverage (MEXP-02)

`linesForWidget` is the shared helper used by BOTH `exportScript` (single-page) AND `exportScriptPages` (multi-page). Adding the `case 'tag'` branch to `linesForWidget` covers both single-page and multi-page paths via one edit.

`save()` also has its own inline switch (not refactored to use the helper). That switch needs the `case 'tag'` branch added too — two edits total in `DashboardSerializer.m`.

### New Suite Test (MEXP-04)

`tests/suite/TestDashboardSerializerTagExport.m` covers:
1. Single-page Tag-bound widget → `save → load → assert .Tag.Key`
2. Multi-page Tag-bound widgets across 2 pages → `save → load → assert .Tag.Key per page`
3. Guarded lookup error path: emit `.m`, clear `TagRegistry`, run `.m` → assert error contains the missing key
4. (Optional) JSON ↔ .m bidirectional round-trip parity

Pattern: matlab.unittest.TestCase with `TestClassSetup` calling `addPaths` (matches existing suite tests).

### Verification Gates

- **Gate A (scope):** `git diff --name-only` ⊆ `affected_files` (DashboardSerializer.m + new test file). Net LOC +40 to +80.
- **Gate B (golden untouched):** `git diff -- tests/suite/TestGoldenIntegration.m tests/test_golden_integration.m` → 0 lines.
- **Gate C (dead-code grep):** Phase 1013 gate still 0 hits (regression check).
- **Gate D (Octave smoke):** `tests/test_examples_smoke.m` passes.
- **Gate E (MATLAB CI):** `tests/run_all_tests.m` green; `TestDashboardSerializerTagExport` 3-4/3-4 PASS on R2020b.
- Gate F (skip-list parity) not in scope this phase (Phase 1015 owns DIFF-04).

### Anti-features (locked)

- Do NOT inline `SensorTag(... 'X', [...], 'Y', [...])` data into the emitted `.m` script. Rejected per SUMMARY.md anti-features.
- Do NOT delete `FastSenseWidget.fromStruct` `'sensor'` reader branch — legacy JSON dashboards on user disks still need to load.
- Do NOT touch `TestGoldenIntegration.m` / `test_golden_integration.m`. Pitfall 3.
- Do NOT refactor `linesForWidget` into a dispatch table while in the neighborhood. Pitfall 1 scope creep.
- Do NOT change the JSON save/load path — it already works correctly via `toStruct`.

### Claude's Discretion

- Exact wording of the guarded-lookup error message (must include the missing key for clear diagnostics).
- Whether to use `TagRegistry.has` or `~isempty(TagRegistry.get('k'))` if `has` doesn't exist on R2020b — verify during planning. (Expected: `has` exists — used in Phase 1009/1010 widget code.)
- Whether to consolidate the two switch blocks (`save` + `linesForWidget`) into a single helper — recommend NOT doing this in v2.1 (scope creep); add a tracking note for v2.2+ if useful.
- Order of edits within the single plan. Suggest: (a) add Tag branch to linesForWidget → (b) add Tag branch to save() → (c) delete `'sensor'` branch from both → (d) write new test → (e) run gates.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `DashboardSerializer.linesForWidget` — existing 30+-case switch for widget types; pattern to extend.
- `FastSenseWidget.toStruct` — emits `s.source = struct('type','tag','key',obj.Tag.Key)` — already correct (Phase 1009).
- `FastSenseWidget.fromStruct` — handles BOTH `'tag'` (current) and `'sensor'` (legacy backward-compat) — leave as-is.
- `TagRegistry.has(key)` / `TagRegistry.get(key)` — public static methods, R2020b-compatible.
- `tests/suite/Test*.m` pattern with `TestClassSetup.addPaths` for path management.
- `tests/suite/makePhase1009Fixtures.m` — canonical SensorTag/MonitorTag fixture factory; reuse for the new round-trip test.

### Established Patterns

- One-direction migration in serializers: emit new format, read both new + legacy. Used heavily in Phase 1009/1010/1011.
- Two-switch pattern in DashboardSerializer (`save()` line 38 inline + `linesForWidget()` line 598 helper) is a vestige — one inline path predates the shared-helper extraction. Both need the new `case` added.
- `TagRegistry` cleared in test setup via `TagRegistry.clear()`; tests should clear in `TestMethodSetup` to avoid cross-test pollution.

### Integration Points

- `DashboardSerializer.save(d, path)` → switches on path extension `.m`/`.json` → calls inline switch (.m) OR `saveJSON` (.json).
- `DashboardSerializer.exportScript(cfg, path)` → calls `linesForWidget` per widget.
- `DashboardSerializer.exportScriptPages(cfg, path)` → calls `linesForWidget` per widget per page.
- Generated `.m` script when `feval`d builds a fresh `DashboardEngine` and calls `addWidget('fastsense', 'Tag', TagRegistry.get(...), ...)` — so `TagRegistry` must be pre-populated by user code before `feval`.

</code_context>

<specifics>
## Specific Ideas

- Code shape for the new `case 'tag'` (linesForWidget):

```matlab
case 'tag'
    wLines{end+1} = sprintf('%sif ~TagRegistry.has(''%s''); error(''DashboardSerializer:tagNotRegistered'', ''Tag %%s must be registered before running this script'', ''%s''); end', indent, ws.source.key, ws.source.key);
    wLines{end+1} = sprintf('%sd.addWidget(''fastsense'', ''Title'', ''%s'', ''Position'', %s, ''Tag'', TagRegistry.get(''%s''));', indent, ws.title, pos, ws.source.key);
```

(Adjust line breaks / indentation to match existing style.)

- The new test file structure:

```matlab
classdef TestDashboardSerializerTagExport < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            run(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'install.m'));
        end
    end
    methods (TestMethodSetup)
        function clearRegistries(~)
            TagRegistry.clear();
        end
    end
    methods (Test)
        function singlePageTagWidgetRoundTripsViaM(testCase) ...
        function multiPageTagWidgetsRoundTripViaM(testCase) ...
        function unregisteredTagFailsLoudly(testCase) ...
    end
end
```

</specifics>

<deferred>
## Deferred Ideas

- Consolidating `save()` inline switch + `linesForWidget` helper → out of v2.1 scope (Pitfall 1 scope creep; tracked as a v2.2+ refactor candidate).
- GroupWidget children with Tag bindings in `.m` export → `emitChildWidget` doesn't currently handle Tag-bound children → MEXP-DEFER-01 (per REQUIREMENTS.md Future Requirements).
- Inline-data `.m` export option → rejected per SUMMARY.md anti-features.

</deferred>
