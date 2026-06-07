---
phase: 1043-dashboardserializer-resolver-seam-backward-compat
plan: 03
type: execute
wave: 2
depends_on: ["1043-01", "1043-02"]
files_modified:
  - libs/Dashboard/DashboardSerializer.m
autonomous: true
requirements: [DASH-01, DASH-02]
nyquist_compliant: true

must_haves:
  truths:
    - "The .m export path (linesForWidget) emits the machine-scoped form <machineVar>.get('key') for tag widgets when a machineVar is supplied, and the legacy TagRegistry.get('key') form when it is absent — never a bare unbound widget for a tag-type widget (D-05, SC4)"
    - "linesForWidget gains a 'tag' case (it had none before — tag widgets fell through to the otherwise branch producing an unbound widget); the machineVar is threaded from exportScript and exportScriptPages through the shared helper (D-05)"
    - "The save() inline export switch also gains a 'tag' case with the same machineVar conditional so all .m export entry points emit correct tag bindings (RESEARCH Open Question 3 resolved: fix in 1043 for consistency, default machineVar='' keeps legacy save() output unchanged)"
  artifacts:
    - path: "libs/Dashboard/DashboardSerializer.m"
      provides: "linesForWidget(ws, pos, indent, machineVar) with a 'tag' case; exportScript/exportScriptPages threading machineVar; save() inline 'tag' case"
      contains: "function wLines = linesForWidget(ws, pos, indent, machineVar)"
  key_links:
    - from: "libs/Dashboard/DashboardSerializer.m (exportScript / exportScriptPages)"
      to: "linesForWidget(ws, pos, indent, machineVar)"
      via: "optional machineVar arg threaded into the shared emission helper"
      pattern: "linesForWidget\\(ws, pos, [^,]+, machineVar\\)"
    - from: "libs/Dashboard/DashboardSerializer.m (linesForWidget 'tag' case)"
      to: "emitted .m string"
      via: "machineVar-supplied → <machineVar>.get('key'); absent → TagRegistry.get('key')"
      pattern: "%s\\.get\\(''%s''\\)"
---

<objective>
Close the SC4 `.m`-export gap (D-05, DASH-01). Today `linesForWidget` has NO `'tag'` case — tag-bound fastsense widgets fall through to the `otherwise` branch and export as an UNBOUND widget (no Tag), so a fleet dashboard exported to `.m` and reloaded would lose its tag bindings. Three coordinated edits, all in `DashboardSerializer.m`:

1. `linesForWidget(ws, pos, indent)` → `linesForWidget(ws, pos, indent, machineVar)` (optional 4th arg, `if nargin < 4, machineVar = ''; end`). Add a `'tag'` case before `otherwise` that emits the fastsense `addWidget` with a Tag binding: machineVar supplied (fleet export) → `<machineVar>.get('key')`; machineVar absent (legacy export) → `TagRegistry.get('key')` as today. Honor the existing `showPlantLog` conditional (the `'tag'` case must emit `'ShowPlantLog', true` when set, mirroring the `'sensor'`/`'file'`/`'data'` cases).
2. `exportScript(config, filepath)` → `exportScript(config, filepath, machineVar)` and `exportScriptPages(config, filepath)` → `exportScriptPages(config, filepath, machineVar)` (optional, default `''`), threading machineVar into their `linesForWidget` calls.
3. `save()` inline export switch (the function-form `.m` export at the top of the file) has its OWN switch that ALSO lacks a `'tag'` case. RESEARCH Open Question 3 is resolved here: FIX it in 1043 for consistency (so no `.m` export entry point can silently drop a tag binding), with the same machineVar conditional and a default `machineVar=''` that keeps legacy save() output byte-for-byte unchanged.

machineId is NOT stored in widget structs (RESEARCH Anti-Pattern 2 / D-05) — the machine context comes from the export caller's machineVar arg, never from the JSON. This plan makes the export CAPABLE of machine-scoped emission and tests it; the actual fleet-export caller wiring (which caller passes the machineVar) is exercised in 1046 clone/remap (CONTEXT Deferred Ideas — not scope creep).

Turns the SC4 assertions in `TestFleetDashboardResolver` (Plan 01) from RED to GREEN.

Purpose: A fleet dashboard exported to `.m` carries machine-scoped tag references; a legacy dashboard exported to `.m` is unchanged.
Output: One edited library file; SC4 GREEN; full phase suite green.
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

@libs/Dashboard/DashboardSerializer.m
</context>

<artifacts_this_phase_produces>
This plan (03) produces:
- `DashboardSerializer.linesForWidget(ws, pos, indent, machineVar)` — optional 4th arg; new `'tag'` case emitting `<machineVar>.get('key')` (fleet) or `TagRegistry.get('key')` (legacy), honoring showPlantLog.
- `DashboardSerializer.exportScript(config, filepath, machineVar)` — optional machineVar threaded to linesForWidget.
- `DashboardSerializer.exportScriptPages(config, filepath, machineVar)` — optional machineVar threaded to linesForWidget.
- `DashboardSerializer.save()` inline switch `'tag'` case with the same machineVar conditional (default `''` = legacy form).
(Combined with Plan 02's resolver threading and Plan 01's tests, this completes Phase 1043: DASH-01 + DASH-02.)
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: linesForWidget gains machineVar arg and a 'tag' case; exportScript/exportScriptPages thread machineVar</name>
  <files>libs/Dashboard/DashboardSerializer.m</files>
  <read_first>
    - libs/Dashboard/DashboardSerializer.m:775-830 (linesForWidget(ws, pos, indent) signature at :775; the switch ws.source.type at :788 with cases 'sensor' :789, 'file' :798, 'data' :809, otherwise :820 — NO 'tag' case; the 'sensor' case shows the showPl conditional emission pattern at :792-797 and uses ws.source.name)
    - libs/Dashboard/DashboardSerializer.m:470-510 (exportScript(config, filepath) signature at :470; its linesForWidget call at :491 with indent '')
    - libs/Dashboard/DashboardSerializer.m:510-575 (exportScriptPages(config, filepath) signature at :510; its linesForWidget call at :555 with indent '    ')
    - .planning/phases/.../1043-RESEARCH.md §"Seam 5" (lines 285-316) + §".m Export: linesForWidget Threading Path" (lines 517-541 — Path A exportScript, Path B exportScriptPages, the SC4 string assertions)
  </read_first>
  <action>
    Per D-05: change `function wLines = linesForWidget(ws, pos, indent)` to `function wLines = linesForWidget(ws, pos, indent, machineVar)` and add `if nargin < 4, machineVar = ''; end` as the first line. Update the header comment to document the optional machineVar (empty = legacy TagRegistry.get form; non-empty = machine-scoped form).

    Inside the `case 'fastsense'` → `switch ws.source.type`, add a NEW `case 'tag'` BEFORE the `otherwise`. It must emit the fastsense addWidget header + Position lines (mirroring the 'sensor' case's two leading sprintf lines, with the same `indent` prefix), then build the tag expression conditionally:
    - if `~isempty(machineVar)`: `tagExpr = sprintf('%s.get(''%s'')', machineVar, ws.source.key)`
    - else: `tagExpr = sprintf('TagRegistry.get(''%s'')', ws.source.key)`
    Then emit the Tag NV pair honoring showPl exactly like the 'sensor' case: if showPl, emit `'Tag', <tagExpr>, ...` followed by `'ShowPlantLog', true);`; else emit `'Tag', <tagExpr>);`. Use `ws.source.key` (the tag-type field), NOT `ws.source.name` (that is the legacy sensor field). Leave the existing 'sensor'/'file'/'data'/otherwise cases UNCHANGED — the machineVar conditional belongs only in the new 'tag' case (RESEARCH Seam 5 note: legacy sensor widgets are not fleet widgets).

    Per D-05 Path A/B: add an optional `machineVar` arg to `exportScript` (`exportScript(config, filepath, machineVar)`, `if nargin < 3, machineVar = ''; end`) and to `exportScriptPages` (`exportScriptPages(config, filepath, machineVar)`, `if nargin < 3, machineVar = ''; end`). Thread it into their `linesForWidget` calls: `linesForWidget(ws, pos, '', machineVar)` in exportScript and `linesForWidget(ws, pos, '    ', machineVar)` in exportScriptPages. The defaults keep every existing 2-arg caller (e.g. `TestDashboardInfo` calls `d.exportScript(filepath)`) byte-for-byte unchanged.

    Keep all lines <= 160 chars; nesting depth <= 5. Do NOT touch save() in this task (Task 2). Do NOT touch the resolver-threading edits from Plan 02.
  </action>
  <verify>
    <automated>mcp__matlab__check_matlab_code on libs/Dashboard/DashboardSerializer.m returns no errors; then mcp__matlab__run_matlab_test_file on tests/suite/TestFleetDashboardResolver.m — the SC4 export tests (machineVar → machine.get('pressure'); no machineVar → TagRegistry.get('pressure')) turn GREEN. Also run tests/suite/TestDashboardInfo.m to confirm the 2-arg exportScript callers stay GREEN.</automated>
  </verify>
  <acceptance_criteria>
    - linesForWidget has 4 args: `grep -cE "function wLines = linesForWidget\(ws, pos, indent, machineVar\)" libs/Dashboard/DashboardSerializer.m` returns 1
    - machineVar nargin guard present: `grep -c "if nargin < 4, machineVar = ''; end" libs/Dashboard/DashboardSerializer.m` >= 1
    - 'tag' case emits BOTH forms: `grep -c "%s.get(''%s'')" libs/Dashboard/DashboardSerializer.m` >= 1 AND the new 'tag' case references `ws.source.key` (verify a `case 'tag'` exists inside linesForWidget by line range)
    - exportScript threads machineVar: `grep -cE "function exportScript\(config, filepath, machineVar\)" libs/Dashboard/DashboardSerializer.m` returns 1 AND `grep -c "linesForWidget(ws, pos, '', machineVar)" libs/Dashboard/DashboardSerializer.m` >= 1
    - exportScriptPages threads machineVar: `grep -cE "function exportScriptPages\(config, filepath, machineVar\)" libs/Dashboard/DashboardSerializer.m` returns 1 AND `grep -c "linesForWidget(ws, pos, '    ', machineVar)" libs/Dashboard/DashboardSerializer.m` >= 1
    - No `contains(` introduced: `grep -c "contains(" libs/Dashboard/DashboardSerializer.m` returns 0
    - check_matlab_code reports no errors
    - TestFleetDashboardResolver SC4 tests GREEN; TestDashboardInfo GREEN (2-arg exportScript callers unbroken)
  </acceptance_criteria>
  <done>linesForWidget accepts an optional machineVar and emits a machine-scoped or registry-scoped tag binding via a new 'tag' case; exportScript and exportScriptPages thread machineVar with backward-compatible defaults; SC4 export tests pass and existing 2-arg export callers stay green.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: save() inline export switch gains a 'tag' case with the same machineVar conditional</name>
  <files>libs/Dashboard/DashboardSerializer.m</files>
  <read_first>
    - libs/Dashboard/DashboardSerializer.m:5-120 (save(config, filepath): the inline widget loop at :30-88 with its OWN switch ws.source.type — cases 'sensor' :40-48, 'file' :49-59, 'data' :60-70, otherwise :71-78 — NO 'tag' case; the showPl conditional pattern at :43-48 emitting TagRegistry.get(ws.source.name))
    - .planning/phases/.../1043-RESEARCH.md §"Path C — save() inline block" (lines 535-541) + §"Assumptions Log" A1 (save() inline switch is distinct from linesForWidget) + §"Open Questions" 3 (the decision: fix in 1043 vs defer — this plan FIXES it)
  </read_first>
  <action>
    Per RESEARCH Open Question 3 (resolved: fix in 1043 for consistency so no `.m` export entry point silently drops a tag binding): add a `'tag'` case to the save() inline `switch ws.source.type` block, placed before its `otherwise`. save() does not have a machineVar parameter and is the legacy function-form export — so the simplest correct fix is to emit the legacy `TagRegistry.get('key')` form for the `'tag'` case (equivalent to machineVar='' default), using `ws.source.key`. Mirror the inline 'sensor' case's two-line header (addWidget Title + Position) and its showPl conditional (emit `'Tag', TagRegistry.get('key'), ...` + `'ShowPlantLog', true);` when showPl, else `'Tag', TagRegistry.get('key'));`). Use `ws.source.key` (tag field), NOT `ws.source.name`.

    Rationale to record in the SUMMARY: save() is the legacy function-form export with no machine context; emitting the registry form for tag widgets makes a tag-bound dashboard saved via save() reload as a registry-bound dashboard (correct for the single-machine legacy path). Fleet export uses exportScript/exportScriptPages with a machineVar (Task 1). Adding the 'tag' case to save() prevents the silent-unbound-widget bug (tag widget falling through to otherwise) for ALL export entry points. This is the consistency fix chosen over deferral to 1046.

    Leave the inline 'sensor'/'file'/'data'/otherwise cases UNCHANGED. Default save() output for non-tag dashboards is byte-for-byte unchanged. Keep all lines <= 160 chars.
  </action>
  <verify>
    <automated>mcp__matlab__check_matlab_code on libs/Dashboard/DashboardSerializer.m returns no errors; then mcp__matlab__run_matlab_file on tests/run_all_tests.m — the full suite is green (resolver threading from Plan 02 + .m export from Task 1 + save() tag case here), AND the Octave flat test_dashboard_resolver passes. This is the phase-gate full-suite run (VALIDATION.md per-wave-merge sampling).</automated>
  </verify>
  <acceptance_criteria>
    - save() inline switch has a 'tag' case: a `case 'tag'` exists within the save() method body (lines ~5-120) — verify by line range; `grep -c "case 'tag'" libs/Dashboard/DashboardSerializer.m` >= 2 (one in save(), one in linesForWidget from Task 1)
    - save() 'tag' case emits a registry-scoped binding using the key field: the save() 'tag' case references `ws.source.key` (verify by reading the save() block)
    - save() 'tag' case does NOT introduce a machineVar (save has no such param): `grep -c "function save(config, filepath)" libs/Dashboard/DashboardSerializer.m` returns 1 (signature unchanged)
    - No `contains(` introduced: `grep -c "contains(" libs/Dashboard/DashboardSerializer.m` returns 0
    - check_matlab_code reports no errors
    - tests/run_all_tests.m full suite GREEN; test_dashboard_resolver Octave flat test GREEN
  </acceptance_criteria>
  <done>save()'s inline export switch has a 'tag' case emitting a registry-scoped binding via ws.source.key (no silent unbound tag widget), save()'s signature is unchanged, legacy non-tag save output is byte-for-byte unchanged, and the full test suite is green.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| dashboard config struct → emitted .m source string | An exported `.m` file embeds `ws.source.key` / `ws.title` into MATLAB source via sprintf — a malicious key containing quotes could break out of the string literal |
| exported .m file → later feval at load time | The generated `.m` is feval'd by DashboardEngine.load (.m branch); injected code in an embedded key would execute |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1043-03-01 | Tampering | sprintf-embedded ws.source.key with embedded single-quotes could break the emitted '...' literal or inject code into the .m | mitigate | The new 'tag' case embeds keys exactly as the existing 'sensor' case embeds ws.source.name (same sprintf '...' pattern, same exposure) — this phase introduces no NEW escaping risk relative to the established pattern. The pre-existing project pattern (e.g. config.name strrep-escapes quotes at save():16) is the codebase norm; tag keys are machine-local sensor identifiers from trusted catalogs, not end-user free text. Documented; not escalated (no HIGH expected per phase security note). If keys ever become user-supplied, a strrep('''','''''') escape on the key in the 'tag' case is the follow-up. |
| T-1043-03-02 | Elevation of Privilege | feval of a tampered exported .m | accept | Exported `.m` files are developer artifacts produced from trusted catalogs and loaded by the same developer; this is unchanged from the existing export/load contract for all other widget types |
| T-1043-03-03 | Information Disclosure | machineVar name leaking into exported source | accept | machineVar is a MATLAB variable name supplied by the export caller (e.g. 'machine'); it is not a secret and appears as-is in generated code by design (D-05) |
| T-1043-03-SC | Tampering | npm/pip/cargo installs | accept | No package installs — pure MATLAB edits, no dependency additions |
</threat_model>

<verification>
- `DashboardSerializer.m` parses clean (`check_matlab_code` no errors).
- SC4: exportScript with machineVar='machine' emits `machine.get('pressure')` and NOT `TagRegistry.get('pressure')`; without machineVar emits `TagRegistry.get('pressure')` (TestFleetDashboardResolver SC4 GREEN).
- exportScriptPages threads machineVar identically (indent '    ').
- save() no longer drops tag bindings (tag case emits registry-scoped binding).
- 2-arg export callers (TestDashboardInfo) stay GREEN.
- Full `tests/run_all_tests.m` green; Octave flat `test_dashboard_resolver` green.
- No `contains(` introduced (Octave parity invariant).
</verification>

<success_criteria>
- SC4 (DASH-01): the `.m` export path emits the machine-scoped form `<machineVar>.get('key')` for fleet widgets when machineVar supplied; legacy `TagRegistry.get('key')` when absent — never a bare unbound tag widget.
- linesForWidget has a 'tag' case (it had none); machineVar threaded from exportScript + exportScriptPages.
- save() inline switch 'tag' case added (RESEARCH Open Question 3 resolved: fixed in 1043, not deferred), legacy save output unchanged.
- Full phase: DASH-01 + DASH-02 satisfied; full suite + Octave flat test green.
</success_criteria>

<output>
Create `.planning/phases/1043-dashboardserializer-resolver-seam-backward-compat/1043-03-SUMMARY.md` when done.
</output>
