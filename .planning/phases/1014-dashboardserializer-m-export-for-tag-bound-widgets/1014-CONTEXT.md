# Phase 1014: DashboardSerializer `.m` export for Tag-bound widgets - Context

**Gathered:** 2026-04-28
**Status:** Reconstructed retroactively (original CONTEXT.md lost in worktree turbulence)
**Mode:** Recovered from commit messages (b0c4bfc, ee04f4e, ac44490) and ROADMAP entry

<domain>
## Phase Boundary

User saving a Tag-bound dashboard via `DashboardSerializer.save(d, 'out.m')` or `exportScriptPages(d, 'out.m')` gets a `.m` script that round-trips the Tag binding via `TagRegistry.get('key')` lookups — no silent omission, with a clear error if the user forgets to register the tag before running.

</domain>

<decisions>
## Implementation Decisions

### Switch-case Strategy
- `case 'tag'` added in BOTH the inline switch in `save()` AND the `linesForWidget` helper (both code paths must emit the same Tag lookup pattern).
- `case 'sensor'` deleted from both — one-direction migration (in-memory widgets only emit `source.type='tag'` post-v2.0). FastSenseWidget.fromStruct keeps the legacy 'sensor' reader for on-disk JSON backward compat (out of scope here).

### Lookup Strategy
- `TagRegistry.has(key)` does not exist on the public API — verified during plan-checker iteration 2.
- Use try/catch around `TagRegistry.get('key')` and rethrow with serializer-namespaced error ID `DashboardSerializer:tagNotRegistered` for clear user-facing diagnostics.
- Capture into `tag_<key>` local var so emitted `d.addWidget(...)` stays readable.

### Field Name
- Read `ws.source.key` (the field FastSenseWidget.toStruct emits), not `ws.source.name`.

### Test Coverage
- Add `TestDashboardSerializerTagExport` suite covering 4 scenarios: single-page via save(), single-page via exportScript directly (helper-path coverage gap), multi-page via save→exportScriptPages, unregistered tag fails with `DashboardSerializer:tagNotRegistered`.
- Suite-only (MATLAB unittest), no Octave-flat sidecar — TEST-DEFER-01 per Phase 1013.

### Claude's Discretion
All implementation choices at Claude's discretion — infrastructure phase (single-file edit + test).

</decisions>

<code_context>
## Existing Code Insights

### Touched files
- `libs/Dashboard/DashboardSerializer.m` — `save()` inline switch (~line 36) + `linesForWidget` helper (~line 596).
- `tests/suite/TestDashboardSerializerTagExport.m` — new suite (174 LOC, 4 methods).

### Established Patterns
- TagRegistry.get(key) throws `TagRegistry:unknownKey` on miss — wrapped here.
- FastSenseWidget.toStruct emits `source.type='tag'` and `source.key=<tag-key>`.

### Integration Points
- Auto-discovered via `tests/run_all_tests.m` `TestSuite.fromFolder` (no manual wiring).

</code_context>

<specifics>
## Specific Ideas

- macOS Octave `tempname()` inserts hyphens — invalid MATLAB function names. Test helper `iMakeTempMPath()` uses `fullfile(tempdir, 'tag_export_<ts>_<n>.m')` for deterministic alphanumeric+underscore names.

</specifics>

<deferred>
## Deferred Ideas

- FastSenseWidget.fromStruct legacy 'sensor' reader removal — kept for on-disk JSON backward compat. Out of scope for v2.1.
- Wider DashboardSerializer test coverage (other widget source types) — out of scope.

</deferred>
