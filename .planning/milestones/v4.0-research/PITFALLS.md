# Pitfalls Research — v2.1 Tag-API Tech Debt Cleanup

**Domain:** Post-migration tech-debt cleanup on a 24k LOC MATLAB codebase with mixed MATLAB/Octave CI, a parallel MATLAB-suite / Octave-flat test pipeline, Tag-singleton registries, and a dedicated golden integration test.
**Researched:** 2026-04-22
**Confidence:** HIGH (all findings traced to concrete files in this repo; pitfall gate pattern borrowed from v2.0 Phase 1004/1008/1011/1012 precedents)

## Summary

v2.1 is a cleanup milestone — "easy" on paper, but the highest-risk milestone category on this codebase because the regression surface is everything that ships and the incentive to cut corners ("it's just a cleanup") is maximal.

Four concrete items are in scope:

1. **`EventDetector.detect(tag, threshold)` dead-code cleanup** (also `IncrementalEventDetector.process`, `EventConfig.addSensor`)
2. **`DashboardSerializer` `.m` export for `source.type='tag'`** (currently falls through to `otherwise` and silently emits Tag-less widgets)
3. **93 `Threshold(`-like legacy-constructor references across ~22 MATLAB-only suite test files + ~6 flat tests** (actual count: 98 across 22 files when `Threshold\(`/`CompositeThreshold\(`/`StateChannel\(`/`ThresholdRule\(` are counted — the "42 files / 93 refs" audit figure comes from a looser whole-word grep)
4. **`examples/05-events/example_event_detection_live.m` and `example_event_viewer_from_file.m`** — currently deprecation-banner stubs with early return; need full rewrite to `MonitorTag + EventStore + EventBinding` pipelines

The pitfall landscape splits into three layers:

- **Cross-cutting post-migration-cleanup traps** — scope creep, silent-skip pathology, golden-test creep, bulk-sed semantic drift, commit-granularity breaking bisect. These fire on every item.
- **Per-item landmines** — each of the 4 items has 3–4 specific traps that depend on THIS codebase's architecture (TagRegistry hard-error on duplicate keys, two-phase `loadFromStructs` serialization contract, `DashboardSerializer.linesForWidget` switch-fallthrough, subprocess-isolated Octave test harness, per-example singleton cleanup in the smoke runner).
- **Verification gate patterns** — falsifiable grep/test gates at phase exit (Phase 1004 Pitfall 5, Phase 1008 Pitfall 1, Phase 1011 Pitfall 12, Phase 1012 six-gate sweep) that v2.1 should reuse to keep "cleanup" honest.

The single biggest risk is **item 3**: mass test migration across 22+ files with bulk find-replace drifting assertion semantics, AND some of those tests exist precisely to test DELETED code (TestEventDetector, TestIncrementalDetector, TestEventConfig) where the right answer is DELETE not MIGRATE. Conflating "migrate all" with "keep all" burns the budget on dead tests and leaves the tests that matter undermigrated.

The second biggest risk is **silent skip pathology**: the Octave subprocess-isolated runner and the `test_examples_smoke` skip-list both have mechanisms to mark a test/example as "known-bad" that work by absence of signal. v2.1 touches exactly these files; a test can pass on Octave because it never runs, and "fix" on MATLAB can look fine because MATLAB CI pins to R2020b and the R2025b drift is invisible.

The third biggest risk is **examples as singletons**: `TagRegistry` hard-errors on duplicate keys (Phase 1004 Pitfall 7 locked-in decision), and the smoke runner clears it between examples. The v2.1 rewrites of `example_event_detection_live.m` and `example_event_viewer_from_file.m` own state that must survive across ticks of a live timer AND be wiped between examples — a contract that the current broken stubs never had to satisfy.

---

## Critical Pitfalls

### Pitfall 1: Cleanup Grows Into Refactor ("while I'm in here…")

**What goes wrong:** The v2.1 scope is 4 narrow items. While touching `DashboardSerializer` for `.m` export, a developer notices `linesForWidget` has 11 widget-type cases that each duplicate the `ws.source.type = 'callback'|'static'` block. "Obvious cleanup: extract a helper." Now the serializer surface changes; golden-test JSON round-trip is unaffected, but the `.m` export format changes character (indentation, newlines), and the pre-existing `TestDashboardSerializerRoundTrip` regression surfaces that the debug investigation already identified in MATLAB R2025b. Scope blow-up.

**Why it happens:** v2.0 was 9 phases of discipline; `-3995 net lines` was the explicit Pitfall-12 gate. v2.1's small size makes each "tiny refactor" feel cheap. The codebase literally rewards refactoring (MISS_HIT complexity limits at 85/550/6 and aspirational targets at 20/200/5). Developers conflate "touching this file" with "time to clean it up."

**How to avoid:**
- Reuse v2.0 Phase 1011 Pitfall 12 gate: per-phase `git diff --stat` verdict. Net line change must be **within a budget declared in PLAN.md** — for v2.1 a reasonable ceiling is approximately +50 for fixes and +400 for the two example rewrites (i.e. each example ≈200 LOC matching the v2.0 audit item-4 estimate).
- No file touched unless it's listed in `affected_files` in the plan. Plan `affected_files` for each v2.1 phase in writing before any Edit.
- Forbid "drive-by" refactors — commit discipline: if a commit changes a file outside `affected_files`, reviewer rejects.

**Warning signs:**
- Commit message mixes "fix .m export" with "extract helper"
- Diff on `DashboardSerializer.m` > ~30 lines when only Tag case is needed (the current switch has a clear shape — add one case beneath `'data'`)
- `git diff libs/` shows any file not in the plan

**Phase to address:** Planning (declare `affected_files` and net-line budget in each PLAN.md) + Verify (grep the per-phase diff against `affected_files`, reject off-path touches).

**Falsifiable gate (pattern from Phase 1011 Pitfall 12):**
```bash
# Pass: every edited file appears in PLAN.md affected_files
comm -23 <(git diff --name-only HEAD~N..HEAD | sort) <(awk '/^affected_files:/,/^[a-z]/' PLAN.md | sort) | wc -l
# Expected: 0
```

---

### Pitfall 2: "Dead" Code That Isn't Actually Dead (stub-throws-break-green)

**What goes wrong:** `EventDetector.detect(tag, threshold)` is flagged as dead because no production caller exists in `libs/` (verified via Phase 1011 grep). Developer stubs it to `error('EventDetector:deadCode', ...)`. On next MATLAB CI run, `tests/suite/TestEventDetectorTag.m:39-40` (`det = EventDetector(); events = det.detect(st, thr);`) now throws — but that test was **already failing** on R2025b (debug investigation) because `thr = Threshold(...)` refers to a deleted class. The stub doesn't make things worse, but it hides the fact that the test was useful at finding callers: it IS the caller.

Worse: `IncrementalEventDetector.process()` was stubbed in Phase 1011, and `TestIncrementalDetector.m` has 8 test methods still constructing `IncrementalEventDetector(…)` + calling `.process(…)`. Stubbing vs deleting changes error signature vs undefined-method, and both are used somewhere (including `EventConfig.buildDetector()` which still constructs `EventDetector(args{:})` for `cfg.runDetection()`).

**Why it happens:** "No callers in libs/" ≠ "no callers in tests/ or examples/." The Phase 1011 grep explicitly excluded tests/ for the MIGRATE-03 gate; that exclusion is now being treated as "these tests don't count." They count: they gate CI.

**How to avoid:**
- Before stubbing or deleting **any** method, run a repo-wide grep across `libs/`, `tests/`, `examples/`, `benchmarks/`, `docs/`, `scripts/`, and `wiki/`.
- Decide per-caller: (a) caller is testing this method's current behavior → test dies with method; (b) caller is incidental (test constructs helper) → migrate caller; (c) caller is in production → it isn't dead.
- `error('...:legacyRemoved', ...)` stubs are the WORST option for pure-dead code: they keep the method name in the symbol table, preserve a false-positive "callers exist" signal for future greps, and turn a compile-time failure into a runtime failure. Prefer **deletion** unless you have external callers you can't control (and v2.1 has none — the no-users constraint is still true).

**Warning signs:**
- `grep -rE "EventDetector\.detect\(|EventDetector\(|IncrementalEventDetector\(|EventConfig\.addSensor\(" libs tests examples` returns > 0 hits after the "cleanup" is staged
- A stub function's body is just `error(...)` — strong signal this should be deleted
- Test files named after the thing being deleted (`TestEventDetector.m`, `TestIncrementalDetector.m`, `TestEventConfig.m`) — these are zombie tests; they survive only because the thing they test stubs back a "legacyRemoved" error

**Phase to address:** Planning (decide delete-vs-stub per method upfront, not ad hoc) + Execute (delete tests alongside the methods they test — same commit).

**Falsifiable gate:**
```bash
# After item-1 lands, no remaining callers to removed methods:
grep -rE "EventDetector\.detect\(|IncrementalEventDetector\(|EventConfig\.addSensor\(" libs tests examples
# Expected: 0 lines
```

---

### Pitfall 3: Golden Test Creep (touching the untouchable)

**What goes wrong:** `tests/suite/TestGoldenIntegration.m` and `tests/test_golden_integration.m` were rewritten in Phase 1011 with preserved assertion semantics (same fixture Y, same event timing at t=4 peak 16 and t=13 peak 22). Phase 1004 RESEARCH embedded a "DO NOT REWRITE" grep-enforced header. In v2.1, while touching `EventDetector`, a developer notices the golden test comments reference the removed `EventDetector('MinDuration', 3)` constructor in comments (`was: det = EventDetector('MinDuration', 3); detectEventsFromSensor -> 1 event`). They "clean up the comment." Now the golden test has been touched — grep audit at phase exit flags it, requires rollback, loses 30 minutes of work, or worse, the comment "cleanup" is merged and the regression trail goes cold.

**Why it happens:** Golden tests look ordinary. The DO-NOT-REWRITE convention is documented in v2.0 RESEARCH/CONTEXT but not emblazoned in the file header. A grep for "EventDetector" returns hits in the golden test and it looks like fair game.

**How to avoid:**
- Add a file-header directive at the top of both golden files if one isn't there already: `% DO NOT REWRITE — v2.0 assertion semantics locked by Phase 1011.` (verified: the header text at `TestGoldenIntegration.m:1` says `% GOLDEN INTEGRATION TEST --` but not "DO NOT REWRITE"; v2.1 should make this explicit.)
- Phase exit gate: `git diff HEAD~..HEAD -- tests/suite/TestGoldenIntegration.m tests/test_golden_integration.m` must return empty for every v2.1 phase commit (comments included).
- If the golden test contains a reference to removed code (it does: `was: det = EventDetector('MinDuration', 3)`), that reference is **intentional historical context**, not debt. It is the only place the assertion-equivalence mapping is documented.

**Warning signs:**
- Any commit touching the golden test files
- Commit message mentioning "update comment" or "cleanup docstring" near a golden filename
- Test output drift: fixture Y array not byte-for-byte identical to `[5 5 5 12 14 16 14 5 5 5 5 5 18 20 22 5 5 5 5 5]`

**Phase to address:** Verify (per-phase grep gate, borrowed from Phase 1004 BUDGET-VERIFICATION pattern).

**Falsifiable gate:**
```bash
git diff HEAD~..HEAD -- \
    tests/suite/TestGoldenIntegration.m \
    tests/test_golden_integration.m | wc -l
# Expected: 0 for every v2.1 phase
```

---

### Pitfall 4: Test Migration Drift (bulk sed breaks assertion semantics)

**What goes wrong:** Item 3 is "clean up 93 Threshold refs in 42 files." Developer uses `sed -i 's/Threshold(/Tag(/g'` or similar bulk find-replace, relying on MATLAB CI to catch breakage. Problems:

1. `fp.addThreshold(4.5, 'Direction', 'upper')` is a **SURVIVING API** on FastSense.m (line 520, `function addThreshold(obj, varargin)`). Greps for `Threshold(` return 76 hits in tests/suite across 19 files that are **correct** current usage. A naive bulk replace breaks production tests.
2. `CompositeThreshold(`, `StateChannel(`, `ThresholdRule(` grep patterns must be handled separately — each needs different Tag-family replacement (`CompositeTag`, `StateTag`, ConditionFn closure).
3. `Threshold('warn', 'Name', 'warn', 'Direction', 'upper'); t_warn.addCondition(struct(), 10); s.addThreshold(t_warn);` (TestEventConfig.m:25-27) — legacy 3-line threshold builder — has **no direct one-line Tag equivalent**. The Tag API uses `MonitorTag(key, parentTag, conditionFn, ...)`. Mechanically replacing the constructor leaves broken code.

**Why it happens:** The audit figure "93 refs in 42 files" implies a simple find-replace job. The reality is that the legacy constructor pattern decomposed into multiple Tag-family patterns (Threshold→MonitorTag via ConditionFn, CompositeThreshold→CompositeTag, StateChannel→StateTag, `Sensor→SensorTag` sometimes, `sensor.addThreshold(t)`→`MonitorTag(..., 'Parent', sensor)`), and some legacy usages have no 1:1 replacement at all (e.g. `s.addThreshold` for state-dependent per-state limits).

**How to avoid:**
- No bulk sed. Per-file review is the only safe mode.
- For each file, classify first (delete vs migrate vs leave-alone) before editing. Three buckets:
  - **DELETE:** Test file's whole purpose is deleted code (`TestEventDetector.m:14` calls `det.detect(t, values, 10, 'upper', 'warn', 'temp')` — the legacy 6-arg detect signature that was removed in Phase 1011 — and this test method has no Tag equivalent because it was testing signature shape, not behavior). **`TestEventConfig.m`** is another candidate — it tests `cfg.runDetection()` which requires the now-stubbed `addSensor()`.
  - **MIGRATE:** Tests of still-alive behavior that happen to use legacy constructors as scaffolding (`TestStatusWidget.m` with 12 `Threshold(` hits — StatusWidget is a surviving widget; threshold setup in tests is scaffolding that needs Tag rewrite).
  - **LEAVE:** `fp.addThreshold()` is surviving FastSense API; the 76 hits in suite tests via `fp.addThreshold(...)` are fine and should NOT be touched.
- Regex precision: use `= Threshold\(|= CompositeThreshold\(|= StateChannel\(|= ThresholdRule\(` to isolate **constructor calls** from method calls.
- Assertion values change when behavior changes. `MonitorTag` with `MinDuration=3` emits a different number of events than `EventDetector('MinDuration', 3).detect(...)` on the same fixture because the event timing semantics differ (MonitorTag emits on rising edges into the EventStore; EventDetector returned a `groupViolations` array). Assertion values must be re-derived from the fixture, not copy-pasted.

**Warning signs:**
- A single commit touching > ~5 test files
- Assertion values in a migrated test match byte-for-byte what they were pre-migration (strong hint that the behavior equivalence was assumed, not verified)
- A test migration commit with no accompanying fixture walk-through in the message

**Phase to address:** Planning (classify every file as delete/migrate/leave before any edit) + Execute (per-file commits for migration, borrowed from Phase 1009 per-widget commit precedent).

**Falsifiable gate:**
```bash
# After item-3 lands:
grep -rE "(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule)\(" tests/ \
    | grep -v "fp\.addThreshold\|\.addThreshold("
# Expected: 0 lines (the fp.addThreshold surviving-API hits are filtered)
```

---

### Pitfall 5: Silently-Skipped Tests Stay Silently Skipped

**What goes wrong:** `tests/run_all_tests.m` runs each Octave test in a **subprocess**. Lines 127-135:
```matlab
is_cleanup_crash = ~isempty(strfind(output, 'break_closure_cycles'));
if test_ok || is_cleanup_crash
    if is_cleanup_crash && ~test_ok
        fprintf('  PASSED (cleanup crash — known Octave bug)\n');
```
This was correct during the Octave 8.4.0 era but Octave was upgraded to 11.1.0 (tests.yml line 101) where bug #67749 is fixed. The `is_cleanup_crash` check now **silently masks real Octave crashes** because there's no "this workaround should never fire" assertion. v2.1 adds new code to Octave tests (example rewrites) — a regression that crashes on Octave would show as "PASSED (cleanup crash — known Octave bug)."

Similarly in `test_examples_smoke.m`: the skip list (lines 73-87) has `example_event_detection_live` and `example_event_viewer_from_file` as Pitfall-8 ("live-timer / interactive / external-resource scripts"). After v2.1 item 4 rewrites them as proper pipelines, they're candidates for removal from the skip list — but if the skip stays and the rewrites have a bug, the bug is invisible in CI.

**Why it happens:**
- `is_cleanup_crash` is defensive code written for Octave 8.4.0 that survived the 11.1.0 upgrade. Nobody audited it post-upgrade. It silently passes tests.
- `test_examples_smoke` skip list is hand-maintained. Parity with `run_all_examples.m` is enforced by a comment only; drift is not automated.

**How to avoid:**
- For `run_all_tests.m`: the `is_cleanup_crash` branch now should WARN loudly. Actionable cleanup for v2.1: keep the code path (belt-and-suspenders) but change `'  PASSED (cleanup crash — known Octave bug)\n'` to a warning that increments a counter; if counter > 0 at end, `results.failed` is incremented with message "Investigate break_closure_cycles on Octave ≥ 11.1.0 — bug #67749 should be fixed."
- For `test_examples_smoke.m`: when item-4 is complete, REMOVE `example_event_detection_live` and `example_event_viewer_from_file` from BOTH `tests/test_examples_smoke.m` (lines 78-79) AND `examples/run_all_examples.m` (lines 58-59). **Both** — the comment on both files says "parity-checked byte-for-byte," and that is a manual comment, not an automated gate. Phase exit must verify both file diffs match.

**Warning signs:**
- A test marked "skipped" or "known-bad" that originates from a version of a runtime/library that's been upgraded
- A test runs green but never actually executes (happens when the subprocess hits a crash before reaching the test body)
- Skip-list lines referencing something that has been fixed

**Phase to address:** Plan (audit every silently-skip mechanism in `tests/` before v2.1 adds new code) + Verify (phase exit: assert the number of silently-skipped tests does not increase, and any skip removed is accompanied by a green test).

**Falsifiable gate (silent-skip accounting):**
```bash
# Count silent-skip sources; must not grow during v2.1
grep -c "is_cleanup_crash\|PASSED (cleanup crash" tests/run_all_tests.m
# Must match the count at v2.0 milestone-close.

# Skip-list parity gate (pattern from Phase 1012 Plan 01):
diff <(awk '/^    skip = {/,/^    };/' tests/test_examples_smoke.m) \
     <(awk '/^    skip = {/,/^    };/' examples/run_all_examples.m)
# Expected: empty diff
```

---

### Pitfall 6: MATLAB CI pins to R2020b; R2025b drift is not v2.1's job

**What goes wrong:** The debug investigation `matlab-tests-failures-investigation.md` catalogs 137 failing MATLAB tests when CI runs on R2025b. Categories: `mksqlite` not on path, `TestData` dynamic property, private-method access restrictions, `table()` char-argument rejection, `fread` negative-size behavior, `OnOffSwitchState` vs char, headless `exportImage`. All are **R2025b drift**, not legacy-Threshold debt.

Current CI (`.github/workflows/tests.yml:247-248`) pins MATLAB to R2020b. The 137 failures live only in a non-pinned run. A v2.1 developer running local MATLAB (potentially R2025b on a dev Mac) could chase test failures thinking they are v2.1 cleanup scope. "Fix one thing, break golden test" morphs into "touch test file unrelated to v2.1 scope because test fails on MY MATLAB."

**Why it happens:** No dev-machine matrix pin; R2025b runs are exposed but not consistent.

**How to avoid:**
- Explicit scope statement in v2.1 PLAN.md: "R2025b drift is out of scope; fixing any test whose only failure mode is R2025b-specific is forbidden in v2.1."
- Dev-runbook: "To verify a test migration, use R2020b (pin documented in tests.yml)."
- When a developer sees a test failing locally, **first check** if the failure is in the debug-investigation list (`.planning/debug/matlab-tests-failures-investigation.md`). If yes — skip, not v2.1.

**Warning signs:**
- A v2.1 commit touches `TestNavigatorOverlay.m`, `TestSensorDetailPlot.m`, `TestMksqlite*.m`, `TestDataStoreWAL.m`, `TestLoadModuleMetadata.m`, `TestDashboardToolbarImageExport.m`, `TestDashboardBuilder*.m`, `TestDataSource.m`, `TestDatastoreEdgeCases.m`, `TestNotification*.m`, `TestEventTimelineWidget.m`, `TestNumberWidget.m`, `TestCompositeThreshold.m`, `TestToolbar.m`, `TestDashboardSerializerRoundTrip.m`, `TestDashboardDirtyFlag.m` — any of the files in the R2025b failure catalog.
- Commit message mentions "R2025b" — escape-hatch to a separate tech-debt backlog.

**Phase to address:** Planning (explicit out-of-scope list in v2.1 PROJECT.md update) + Verify (phase-exit grep: any touched test file must not appear in the R2025b debug catalog).

**Falsifiable gate:**
```bash
# Files named in .planning/debug/matlab-tests-failures-investigation.md:
R2025B_FILES="TestNavigatorOverlay TestSensorDetailPlot TestMksqlite \
    TestDataStoreWAL TestLoadModuleMetadata TestDashboardToolbarImageExport \
    TestDashboardBuilder TestDataSource TestDatastoreEdgeCases \
    TestNotificationRule TestNotificationService TestEventTimelineWidget \
    TestNumberWidget TestCompositeThreshold TestToolbar \
    TestDashboardSerializerRoundTrip TestDashboardDirtyFlag"
for f in $R2025B_FILES; do
    git diff HEAD~..HEAD --name-only | grep -F "$f" && echo "DRIFT: $f touched by v2.1"
done
```

---

### Pitfall 7: Per-Widget Commit Bisect Discipline Broken

**What goes wrong:** Item 3 migrates 22+ test files. One "fix tests" commit touches all 22. When a regression surfaces in CI two weeks later, `git bisect` lands on that commit — useless, because "what broke" is one of 22 test migrations and bisect can't narrow further.

Phase 1009 established the per-widget commit precedent (STATE.md: "Per-widget consumer migration is many small commits, not one big PR"). Phase 1011 plan 04 had 100 files in one commit — explicitly allowed because it was a pure deletion, not a migration.

**Why it happens:** 22 tests × separate commits × per-commit CI run + review feels expensive. Batching is natural.

**How to avoid:**
- Per-file (or per-widget-family) commits for test migrations. Expected: ~15-20 commits for item 3.
- For item 1 (dead code): one commit per method deletion (e.g., `EventDetector.detect` one commit, `IncrementalEventDetector.process` another, `EventConfig.addSensor` third). Keeps bisect useful if any of the three has a hidden caller.
- For item 4 (example rewrites): each example its own commit.
- For item 2 (.m export): single commit OK — one narrow change to `DashboardSerializer.linesForWidget`.

**Warning signs:**
- Any commit touching > 3 test files (unless pure deletion)
- Commit message using "various" or "multiple" ("migrate various test files")
- `git log --stat HEAD~5..HEAD` shows one commit with > ~20 files changed that is not a pure delete

**Phase to address:** Execute (per-phase plan prescribes commit granularity; reviewer enforces).

**Falsifiable gate:**
```bash
# For v2.1 phase delivering item 3, assert no single commit edits > 3 test files
git log --oneline v2.1-start..HEAD | while read sha _; do
    count=$(git diff-tree --no-commit-id --name-only -r "$sha" -- 'tests/' | wc -l)
    if [ "$count" -gt 3 ]; then
        echo "COMMIT $sha touches $count test files — bisect-hostile"
    fi
done
```

---

### Pitfall 8: `.m` Export Generates Unregistered Tag References

**What goes wrong:** Item 2 — extend `DashboardSerializer.linesForWidget` to handle `source.type='tag'`. Easy add: `case 'tag': wLines{end+1} = sprintf(... 'Tag', TagRegistry.get(''%s''), ...);` (mirroring the existing `case 'sensor':` at line 599-602). But that emits MATLAB code that calls `TagRegistry.get('press_a')` — which **hard-errors on missing key** (Phase 1004 Pitfall 7 decision: TagRegistry hard-errors on duplicate OR unknown key; see TagRegistry.m line 109).

The generated script is meant to be self-contained — a user running `./exported_dashboard.m` will hit `TagRegistry:notFound` if the script doesn't first register the Tag. The JSON path doesn't have this problem because `DashboardSerializer.loadJSON` uses `loadFromStructs` (two-phase: instantiate-register THEN resolve-refs), and it serializes the Tag's struct representation inline. `.m` export can't do the same without serializing the Tag's fixture data into the script (potentially huge arrays).

**Why it happens:**
- The `case 'sensor'` code path emits `SensorRegistry.get('%s')` (line 602 actually emits `TagRegistry.get('%s')` per the current code — the v2.0 cleanup migrated the emitter but not the semantic assumption). The assumption was: "Sensor was in SensorRegistry, which allowed silent overwrite + lookup-on-missing-returns-empty." TagRegistry is stricter.
- Tag fixture data is larger than a value+label pair; serializing `X`, `Y` arrays into a generated script creates >10k-line scripts for a single SensorTag.

**How to avoid:**
- Choose one of three strategies explicitly:
  - **(A) Exported `.m` emits a `% TODO: register tag 'foo' before running this script` comment.** Surface the dependency; don't pretend it's resolved.
  - **(B) Exported `.m` emits `TagRegistry.register('foo', SensorTag('foo', ..., 'X', [...], 'Y', [...]));`.** Self-contained but potentially huge. Use only for small Tags (< N samples; N = ~100 or a configurable cap).
  - **(C) `.m` export embeds a guarded lookup:** `if ~TagRegistry.has('foo'); error('Register ''foo'' before running this script.'); end; d.addWidget(..., 'Tag', TagRegistry.get('foo'));`.
- Decision should be locked in v2.1 PLAN.md — don't make it at Edit time.
- The two-phase JSON loader (`loadFromStructs` Pass 1 instantiate+register, Pass 2 resolveRefs in try/catch, wraps failures as `TagRegistry:unresolvedRef`) is the **canonical pattern** (Phase 1004 STATE decision). For `.m` export to match, CompositeTag children must be emitted before parent, and MonitorTag parent Tags must be emitted before the MonitorTag.

**Warning signs:**
- Generated `.m` script runs `TagRegistry.get('foo')` before any `TagRegistry.register('foo', …)` line
- Generated `.m` script contains no `TagRegistry.register` lines at all (the chosen strategy (A) or (C) — acceptable if explicit)
- CompositeTag emitted before its children in the script body (child-before-parent is the invariant; Phase 1008 STATE "Two-phase loader" locked in)

**Phase to address:** Planning (pick strategy A/B/C and document) + Execute (add `case 'tag':` with that strategy) + Verify (round-trip test: save `.m`, spawn a MATLAB/Octave subprocess, run the `.m` file on a cleared TagRegistry, assert the resulting DashboardEngine matches the source).

**Falsifiable gate (pattern from Phase 1008 3-deep round-trip):**
```matlab
% Test: .m export round-trip with Tag binding
TagRegistry.clear();
% ... build dashboard with Tag-bound widgets ...
DashboardSerializer.exportScript(d.toStruct(), '/tmp/exported.m');
TagRegistry.clear();
% Execute the exported script; it must either (a) self-register the Tag
% or (b) error cleanly with guidance, NEVER silently emit a broken widget.
[status, out] = system('octave --eval "run(''/tmp/exported.m'')"');
% Assert either status==0 (self-contained) or status~=0 with clear message.
```

---

### Pitfall 9: `source.type='tag'` vs Legacy `source.type='sensor'` Ambiguity in JSON

**What goes wrong:** FastSenseWidget.m:258 emits `s.source = struct('type', 'tag', 'key', obj.Tag.Key)`. But DashboardSerializer.m:289 still has `strcmp(ws.source.type, 'sensor')` (legacy), and linesForWidget.m:598 switch cases `'sensor'|'file'|'data'` (no `'tag'` case). Adding `'tag'` handling without **removing** the `'sensor'` compat branch produces a serializer that emits new `'tag'` on save but still reads old `'sensor'` on load — fine in isolation, but the JSON format now has two interpretations. If the `.m` export adds `'tag'` handling and keeps the `'sensor'` case for backward compat, old-format `.m` files will still work, but the two code paths will drift.

Additionally: FastSenseWidget.m:388 has `obj.Tag = TagRegistry.get(s.source.name)` in the `'sensor'` legacy branch — it treats the legacy sensor field as a Tag key. If the old sensor key doesn't exist in the new TagRegistry, TagRegistry hard-errors. JSON backward compatibility silently breaks.

**Why it happens:** Backward compat is rarely removed cleanly. The Phase 1011 grep found 0 production callers but didn't assert zero dashboard JSON files in the wild claim `source.type='sensor'`. With "no users" constraint, there shouldn't be any, but dev machines might have stale JSON fixtures.

**How to avoid:**
- In v2.1 item 2, **decide** whether `source.type='sensor'` continues to be supported. Options:
  - Keep it as a read-only legacy path; document that writes never emit `'sensor'`; test the read path works.
  - Remove it entirely; any JSON with `'sensor'` now errors `unsupportedLegacyFormat`.
- `.m` export should NOT emit `'sensor'` — only `'tag'`, `'file'`, `'data'`. The `case 'sensor'` in linesForWidget (line 599) should be **deleted** when `case 'tag'` is added, unless legacy-read compat is explicitly kept.
- Round-trip tests for both paths. Specifically add a "save → load → save" regression test that locks the second save's `.source.type` character string.

**Warning signs:**
- Both `'sensor'` and `'tag'` cases appear in `linesForWidget` after item 2
- A widget saved post-v2.1 loads to a different struct than it was saved from (source.type should round-trip byte-for-byte)
- FastSenseWidget.m:388 — the `TagRegistry.get(s.source.name)` line — still executes in a v2.1 test

**Phase to address:** Planning (decide backward-compat policy) + Execute (delete legacy-emitter `case 'sensor'` if policy is "no back-emit"; preserve loader case only if "read-only legacy path").

**Falsifiable gate:**
```bash
# Assert no new-format save emits legacy 'sensor' type:
grep -rn "'type', 'sensor'" libs/Dashboard/
# Expected: 0 hits after v2.1 (writes should all use 'tag'|'file'|'data')
# The reader (loader) may still accept 'sensor' if backward-compat is chosen.
```

---

### Pitfall 10: Live-Demo Timer & Singleton Leaks Across Smoke Runs

**What goes wrong:** Item 4 — rewrite `example_event_detection_live.m` and `example_event_viewer_from_file.m`. Both currently start MATLAB `timer` objects (`dataTimer`, `bgTimer`) with `ExecutionMode='fixedRate'` and wait for a figure close. The rewrites must also manage timers (the whole point of "live" is a timer).

`test_examples_smoke.m` runs each example in the same Octave process and clears TagRegistry + EventBinding between examples. It does NOT clear MATLAB timers. If the rewritten live examples leave a running timer (the `stopAll()` callback is wired to `DeleteFcn` on the figure — only fires when the figure closes), subsequent example invocations share process state and may see:
- A stale timer emitting callbacks into a deleted figure
- `TagRegistry.clear()` wiping tags mid-tick of a still-running timer
- Memory held by persistent `dataTimer` variable

Worse: both existing stubs declare `persistent dataTimer liveViewer ...` variables. A bare `return;` at line 25 after the deprecation banner doesn't clear these — but in the current broken state they never get set. After the rewrite they will, and `clear functions` or a subprocess is the only way to truly reset.

The smoke list today has both files in the **skip list** (lines 78-79) so this isn't currently triggered. Removing from the skip list (to prove the rewrite is CI-covered) exposes every leak.

**Why it happens:**
- MATLAB timers are process-global. `delete(timer)` releases one; `delete(timerfindall)` releases all. Neither is in the smoke runner.
- `persistent` variables in a function live for the MATLAB session — the smoke runner can't clear them from outside. Only `clear all` or process restart drops them.
- `figure('DeleteFcn', @stopAll)` ties cleanup to the figure close event. In headless CI, the figure is never shown, but it's also never closed — close happens on process exit, which means timer runs during every subsequent example.

**How to avoid:**
- **Default to no timer** in the rewrites if the demo can be pipelined without one. `example_event_viewer_from_file.m` arguably doesn't need a background timer — it demonstrates save → reload, which is inherently synchronous. The "Part 4 simulated background updates" is nice-to-have, not core to the demo.
- If timers are kept: use a **MaxIterations** or a **bounded duration** (e.g., 5 ticks × 1s period) so the demo self-terminates. Don't wait for figure close.
- Wrap the demo in a `try/catch` + `onCleanup(@() stopAll())` at the top. `onCleanup` runs when the function returns, regardless of figure state.
- If the demo absolutely needs to outlive its function call (none of them do — they're demos), add to the smoke skip list with a rationale comment, not because they're broken but because they're interactive.
- The smoke runner should pre-clear timers: add `try, stop(timerfindall); delete(timerfindall); catch, end` to `test_examples_smoke.m` alongside `TagRegistry.clear()` — defense in depth.

**Warning signs:**
- After running `example_event_detection_live()`, `timerfindall` returns > 0 timers
- Running the two examples sequentially in one Octave session produces different output the second time than the first
- Smoke runner log shows timer tick output interleaved between examples

**Phase to address:** Planning (decide timer strategy — prefer none or bounded) + Execute (use `onCleanup`; if skipped, document why) + Verify (smoke runner with timerfindall assertion).

**Falsifiable gate:**
```matlab
% In test_examples_smoke.m after each example:
remaining = timerfindall();
if ~isempty(remaining)
    error('ExampleSmoke:timerLeak', ...
        'Example %s left %d timers running', name, numel(remaining));
end
```

---

### Pitfall 11: Demo Duplicating `example_sensor_threshold.m` (why have two?)

**What goes wrong:** Item 4 rewrites both `example_event_detection_live.m` and `example_event_viewer_from_file.m` as `MonitorTag + EventStore + EventBinding` pipelines. Meanwhile, `examples/02-sensors/example_sensor_threshold.m` is already the **canonical v2.0 pipeline** (PROJECT.md line 64 calls it out; `.planning/milestones/v2.0-MILESTONE-AUDIT.md:92` says the same). Naive rewrite: copy `example_sensor_threshold.m`, paste into both 05-events files, sprinkle in a live timer. Result: three nearly-identical files with slight divergence in fixture data and theme.

User confusion — which demo is canonical? Maintenance burden — three files to update when `MonitorTag.appendData` semantics change. Wiki surface — three files to link.

**Why it happens:** "Make this work like the canonical demo" gets read as "make this be the canonical demo."

**How to avoid:**
- Differentiate by purpose:
  - `example_sensor_threshold.m` — **pipeline narrative** (tag creation → threshold → events → overlay), static data, no timer.
  - `example_event_detection_live.m` — **live-refresh narrative** (appendData on rolling data, EventStore accumulates, dashboard auto-updates). Use `MonitorTag.appendData` (Phase 1007 MONITOR-08) — the appendData path is otherwise only exercised in `LiveEventPipeline`.
  - `example_event_viewer_from_file.m` — **persistence narrative** (EventStore save/load, reopen from file, demonstrate backup rotation). Focus on filesystem behavior, not live detection. No timer required.
- Each file should have a file-header comment explicitly stating what it teaches that the other two don't.
- PROJECT.md update after v2.1 closes: name the three canonical demos and their distinct roles.

**Warning signs:**
- Two or three files have > 70% content overlap
- A future "Canonical MonitorTag demo?" question in a PR review
- The wiki page for events links only one of the three

**Phase to address:** Planning (write a one-liner purpose statement for each of the three demos and check for overlap) + Execute (differentiate pedagogically).

**Falsifiable gate:**
```bash
# Shouldn't be > ~70% similar by naive line-count:
diff -y \
    examples/02-sensors/example_sensor_threshold.m \
    examples/05-events/example_event_detection_live.m | \
    awk 'BEGIN{s=0;d=0} /\|/{d++} /[<>]/{d++} /(^[^|<>])/{s++} END{print "similar", s, "different", d}'
# Expected: different > similar (clearly divergent narratives)
```

---

### Pitfall 12: MATLAB-Only Demo Breaks Octave Smoke

**What goes wrong:** `test_examples_smoke.m` runs on Octave 11.1.0 (examples.yml line 28). MATLAB-only APIs that seem innocuous:

- `datetime` (not in Octave — `example_dock`, `example_datetime` live examples show this pattern)
- `table` (Octave has limited support; the R2025b `table('Date', datetime, ...)` failure is one example)
- `categorical` (MATLAB-only; `example_mixed_tiles` is skipped because of this)
- `disableDefaultInteractivity` (MATLAB-only; already skipped)
- `saveas` with `-dpng` + headless (depends on xvfb availability)
- `uicontrol('style', 'listbox', 'Max', inf)` (different between Octave/MATLAB)
- `input()` without explicit prompt (behaves differently)

A v2.1 item-4 rewrite of the live examples might reach for `datetime` for timestamps or `table` for the event list and break Octave smoke even though the rewrite is "just using Tag API."

**Why it happens:** MATLAB examples are developed on MATLAB first. Octave compatibility is retro-fitted.

**How to avoid:**
- Before writing any new line in an example, check: is this function in the Octave compat list? Rule of thumb: **if it's not used anywhere else in `examples/` that passes Octave smoke, don't use it**.
- Use `numeric` time (seconds from epoch or `linspace(0, T, N)`) — the canonical `example_sensor_threshold.m` uses `t = linspace(0, 100, 10000)` (line 21). Follow suit.
- If MATLAB-specific features are essential (e.g., the demo genuinely requires `datetime` to teach the concept), add to the smoke skip list with a rationale AND add to `.github/workflows/examples.yml` lines 173-203 matlab-examples curated list so it's exercised on MATLAB CI.
- The parity-checked skip-list in `test_examples_smoke.m`/`run_all_examples.m` has rationale comments grouping "Pitfall 8" (timer/interactive/external) and "MATLAB-only widget" — v2.1 must not add a new unlabeled skip; categorize every new skip.

**Warning signs:**
- `datetime(`, `table(`, `categorical(`, `duration(`, `timetable(`, `milliseconds(` appear in an example file
- `disableDefaultInteractivity`, `copygraphics`, `exportgraphics` appear
- Demo file runs green on MATLAB local but fails on Octave smoke with "undefined function"

**Phase to address:** Execute (choose Octave-safe APIs at write-time) + Verify (smoke runs on both MATLAB and Octave CI paths).

**Falsifiable gate:**
```bash
# Per Phase 1012 Plan 01 MATLAB-only API detection:
for f in examples/05-events/example_event_detection_live.m \
         examples/05-events/example_event_viewer_from_file.m; do
    grep -nE '\b(datetime|table|categorical|duration|timetable|milliseconds|copygraphics|exportgraphics|disableDefaultInteractivity)\(' "$f" \
        && echo "WARNING: MATLAB-only API in $f"
done
# Expected: 0 hits unless explicitly added to MATLAB-only smoke skip list
```

---

## Moderate Pitfalls

### Pitfall 13: TagRegistry Duplicate-Key Cascade Across Examples

**What goes wrong:** `TagRegistry.register('press_a', sensorTag)` on second call with same key — HARD ERROR `TagRegistry:duplicateKey` (Phase 1004 STATE "hard-errors on duplicate key — departure from ThresholdRegistry's silent-overwrite"). The smoke runner's per-example `TagRegistry.clear()` covers this — as long as the rewrite calls `register()` with a fresh key or relies on the pre-example clear.

But: `example_event_detection_live.m` and `example_event_viewer_from_file.m` both historically used keys `'temperature'`, `'pressure'`, `'vibration'` — reuse between the two files. Within a single process (the Octave subprocess in CI), the smoke runner clears between each, so this is OK. But if a user runs both in the same MATLAB session without the smoke harness, they collide.

**Prevention:** Add `TagRegistry.clear()` + `EventBinding.clear()` at the top of each rewrite (mirror `example_sensor_threshold.m:17-18`). Namespace keys if reuse is structural (`'live_demo_temperature'`, `'viewer_demo_temperature'`).

**Phase:** Execute (include defensive clear in each example). **Gate:** `grep -L "TagRegistry.clear" examples/05-events/example_event_*.m` — expected: no files without the clear.

---

### Pitfall 14: EventStore File Path — `tempdir` vs Repo-Relative

**What goes wrong:** `example_event_viewer_from_file.m` currently uses `fullfile(tempdir, 'demo_event_store.mat')` — correct. The rewrite might "simplify" to `'events.mat'` or to `fullfile(pwd, ...)` — creates files in the CWD during smoke runs, which is the repo root in CI, potentially committing garbage. EventStore backup rotation (line 86: `cfg.MaxBackups = 3;`) then creates `demo_event_store_1.mat`, `_2.mat`, `_3.mat` alongside.

Also: `example_event_detection_live.m` writes `.mat` files (`tempFile = fullfile(liveDir, 'temperature.mat'); ...; save(tempFile, 'x', 'y');`) used by `FastSense.startLive`. The Tag API doesn't use the file-poll startLive pattern (it uses `MonitorTag.appendData` in-process). The rewrite should shed the .mat file dance entirely.

**Prevention:**
- All disk writes via `tempdir` or a path passed via argument.
- Clean up temp files on example exit (use `onCleanup(@() delete(eventFile))`).
- The live-demo rewrite shouldn't write .mat files at all — the Tag API is in-process.

**Phase:** Execute. **Gate:** `grep -nE "save\(|fopen\(" examples/05-events/example_event_*.m | grep -v tempdir` — expected: 0 hits.

---

### Pitfall 15: Per-Example Timer Cleanup Races TagRegistry.clear

**What goes wrong:** The smoke runner does:
```
try, TagRegistry.clear(); catch; end
try, EventBinding.clear(); catch; end
try
    feval(name);     % runs example
```
If a previous example left a running timer (Pitfall 10), and the NEW example's `feval(name)` kicks off before the prior timer fires, the prior timer's callback might execute AFTER `TagRegistry.clear()` wipes the catalog. The callback looks up `TagRegistry.get('oldkey')` — HARD ERROR. The example being smoked fails with a foreign error message.

**Prevention:** Augment the smoke runner to also stop all timers before each example:
```matlab
try, stop(timerfindall); delete(timerfindall); catch; end
```
Place this BEFORE `TagRegistry.clear()`. Defense-in-depth against Pitfall 10 leak sources.

**Phase:** Execute (add to test_examples_smoke.m) + Verify (assert zero cross-example timer contamination in smoke log).

---

### Pitfall 16: `EventDetector` Class Kept But Empty

**What goes wrong:** Item 1 says "stub or delete `EventDetector.detect(tag, threshold)` dead code." If the developer stubs the `detect` method but keeps the class, the class is now effectively empty (the `MinDuration/OnEventStart/MaxCallsPerEvent` properties + constructor + `buildDetector()` call in EventConfig is all that remains useful). An empty class is a code smell that invites future "let me refactor this" churn.

Meanwhile, `EventConfig.buildDetector()` returns an `EventDetector(args{:})` — but the only methods on a post-stub EventDetector are error stubs, so `buildDetector` returns a useless object.

**Prevention:** Delete `EventDetector.m` entirely along with `EventConfig.buildDetector()`. That forces the question: does `EventConfig` still have a reason to exist? EventConfig's `runDetection()` is already dead (calls the stubbed `addSensor`). EventConfig is effectively dead code entirely. If v2.1 deletes `EventDetector`, the chain deletion is: `EventConfig`, `EventDetector`, `IncrementalEventDetector`, `TestEventConfig.m`, `TestEventDetector.m`, `TestEventDetectorTag.m`, `TestIncrementalDetector.m`, plus Octave-flat siblings (`test_event_config.m`, `test_event_detector.m`, `test_event_detector_tag.m`, `test_incremental_detector.m`). Entire event-detection-legacy subgraph.

**Phase:** Plan (decide class-level delete vs method-level stub upfront) + Execute. **Gate:** either `ls libs/EventDetection/EventDetector.m` returns no file (full delete path) OR every method in `EventDetector.m` has a body that isn't `error('...:legacyRemoved', ...)` (keep path).

---

### Pitfall 17: Examples with `persistent` Variables Pollute Subsequent Smoke Runs

**What goes wrong:** Current `example_event_detection_live.m:27` declares `persistent dataTimer liveViewer liveCfg liveN fpTemp fpPres fpVib hPlotFig; persistent tempFile presFile vibFile;` — 11 persistent variables. `example_event_viewer_from_file.m:21` declares `persistent sensors`. These persist across calls in the same Octave/MATLAB session. The smoke runner can't reset them.

After a rewrite, if persistent variables are kept, a stale handle (e.g., a deleted timer) lingers and the next call hits `isvalid(dataTimer)` — returns false but non-empty — and behavior depends on which branches null-check.

**Prevention:** Don't use `persistent` in examples. State should be local to the function call. If a nested function needs closure state, use shared variables within the parent function, not persistent.

**Phase:** Execute. **Gate:** `grep -n "^\s*persistent" examples/05-events/example_event_*.m` — expected: 0 hits.

---

### Pitfall 18: Skip-List Parity Drift (comment-enforced, not gate-enforced)

**What goes wrong:** `test_examples_smoke.m:72-87` and `examples/run_all_examples.m:50-67` both carry a `skip = {...};` block. Both file headers say "parity-checked byte-for-byte." Today they match. v2.1 item 4 removes `example_event_detection_live` and `example_event_viewer_from_file` from the smoke list because the rewrites are CI-ready. Developer updates one file, forgets the other. CI passes because one is updated; the other grows stale.

**Prevention:** Convert the comment-enforced parity into a gate (Phase 1012 Plan 01 STATE: "Skip-list block in test_examples_smoke.m and run_all_examples.m is parity-checked byte-for-byte via awk-extracted diff; 0 lines required"). Make this a reusable script:
```bash
# scripts/check_skip_list_parity.sh
diff <(awk '/^    skip = {/,/^    };/' tests/test_examples_smoke.m) \
     <(awk '/^    skip = {/,/^    };/' examples/run_all_examples.m)
# exit 0 on match, 1 on drift
```
Call from CI (tests.yml) in a "style check" step.

**Phase:** Planning (add to tests.yml lint step) + Execute (maintain both files together). **Gate:** the script above.

---

## Minor Pitfalls

### Pitfall 19: "Fixed" `printf` output in demo obscures CI log noise

**What goes wrong:** The current stubs print `'[example_event_detection_live] DEPRECATED — pending v2.0 rewrite.\n ...'` — useful when running manually. Post-rewrite, the demos will print multi-line per-tick updates that clutter CI logs. On a failure, the last 40 lines of log (examples.yml line 121: `tail -40 /tmp/example_out.log`) might be all tick output, hiding the actual error.

**Prevention:** Guard verbose output behind `if ~batch()` in Octave, or `if interactive()` in MATLAB. Demo still shows output interactively; CI log stays terse.

**Phase:** Execute. **Gate:** manual review of CI log after the rewrite lands.

---

### Pitfall 20: Docstring Drift from Body

**What goes wrong:** After rewriting an example, the `%EXAMPLE_EVENT_DETECTION_LIVE Live event detection demo with industrial sensors.` header still lists "3 mock industrial sensors, threshold-based event detection, console logging, EventViewer UI, and a live FastSense dashboard using startLive for real-time plotting." The rewrite uses MonitorTag/EventStore, not startLive/EventViewer. Docstring lies to user.

**Prevention:** Rewrite the docstring **first**, then the body. Treat the docstring as spec.

**Phase:** Execute.

---

## Technical Debt Patterns

Shortcuts that seem reasonable during v2.1 but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Stub dead method with `error('...:legacyRemoved', ...)` | Preserves method signature; no caller breaks | Method name stays in symbol table; future greps show false-positive callers; runtime failure instead of compile-time | Only when an external caller (outside repo) is known to exist. v2.1: never — no external users. |
| Bulk `sed -i 's/Threshold(/Tag(/g'` across tests | One command fixes all | Breaks `fp.addThreshold()` surviving API; loses assertion semantics; undifferentiable `CompositeThreshold`/`StateChannel`/`ThresholdRule` | Never — per-file review required. |
| Keep `source.type='sensor'` legacy case in `linesForWidget` alongside new `'tag'` case | Backward-compat with old `.m` files | Two code paths drift; tests don't cover the legacy path; silent data loss | Only if explicit dashboard JSON file in the wild requires it. v2.1: no users, can delete. |
| Squash 22 test migrations into one commit | Fewer commits to review | `git bisect` useless; regression hunt painful | Never for test-migration work. |
| Re-use `TagRegistry` keys across examples | Short, meaningful key names | Duplicate-key hard error if two examples registered in same session | Only when paired with per-example `TagRegistry.clear()` at entry. |
| Use `datetime`/`table` in a demo because MATLAB supports it | Cleaner code | Octave smoke breaks; demo relegated to MATLAB-only curated list in examples.yml | Only when the demo pedagogically REQUIRES datetime (none of the 05-events rewrites do). |
| Leave `persistent` variables in rewritten demos | "Matches prior style" | Cross-example contamination in smoke runner | Never in examples. |
| Add new test file to tests/ and rely on auto-discovery | "Just works" | If the test depends on MATLAB-specific features, Octave suite silently regresses | Always add a smoke-check in a new test + document Octave-skip rationale inline. |

---

## Integration Gotchas

Common mistakes when wiring cleanup fixes into the existing mixed-runtime system.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `TagRegistry` from examples | Relying on registry state from previous example | `TagRegistry.clear(); EventBinding.clear();` at top of every example |
| `EventStore` persistence | Repo-relative path for `.mat` file | `fullfile(tempdir, 'name.mat')` with `onCleanup(@() delete(eventFile))` |
| `MATLAB timer` in demo | Indefinite timer awaiting figure close | Bounded `TasksToExecute` or `onCleanup(@() stop+delete)` on function return |
| `DashboardSerializer.exportScript` | Emit `TagRegistry.get('k')` with no prior `register` | Emit either (a) self-contained `TagRegistry.register('k', SensorTag(...))` OR (b) guarded `if ~TagRegistry.has('k'); error(...); end` |
| `FastSense.addThreshold` | Assume it's deleted because Threshold class is deleted | `addThreshold` is a SURVIVING API on FastSense — distinct from the deleted `Threshold` class |
| Octave subprocess test runner | Trust `is_cleanup_crash` passthrough | After Octave 11.1.0 upgrade, treat break_closure_cycles as a real failure; warn on the "passthrough" branch |
| `tests/suite` on Octave | Assume tests pass because run_all_tests.m reports 73/75 | Suite tests don't run on Octave at all (MATLAB-only classdef unittest) — the 73/75 figure is flat tests; suite tests are silent on Octave |

---

## Performance Traps

v2.1 is not a performance milestone, but one trap exists.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Serialize huge Tag data into `.m` export | 10k-sample SensorTag → 100k-line `.m` file | Strategy (C) in Pitfall 8 (emit `TagRegistry.get` with runtime error if unregistered); NEVER serialize `X`/`Y` arrays inline | If Pitfall 8 strategy (B) is chosen and a real SensorTag has > ~1000 samples |
| Re-register Tags on every live-demo tick | `TagRegistry:duplicateKey` error every tick | Register once at demo startup; call `TagRegistry.has()` before register if re-register needed | Any live demo with a per-tick register pattern |
| `EventStore` backup rotation in tight loop | Disk fills with `.mat_1`, `.mat_2`, ... | `MaxBackups` property is respected; don't set to large number | `MaxBackups > 10` in a live demo running for minutes |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces. v2.1 per-item verification.

### Item 1: EventDetector dead code

- [ ] `grep -rE "EventDetector\.detect\(|IncrementalEventDetector\(|EventConfig\.addSensor\(" libs tests examples` returns 0 hits
- [ ] If delete: `ls libs/EventDetection/EventDetector.m` — no such file
- [ ] If delete: `tests/suite/TestEventDetector.m`, `tests/test_event_detector.m`, `tests/suite/TestEventDetectorTag.m`, `tests/test_event_detector_tag.m`, `tests/suite/TestIncrementalDetector.m`, `tests/test_incremental_detector.m`, `tests/suite/TestEventConfig.m`, `tests/test_event_config.m` also deleted
- [ ] `EventConfig.m` — if EventDetector is kept, `buildDetector()` still returns a usable object; if EventDetector is deleted, `buildDetector()` must also be deleted
- [ ] `libs/EventDetection/eventLogger.m:4` docstring `%   det = EventDetector('OnEventStart', eventLogger());` — updated or removed
- [ ] Wiki pages `Event-Detection-Guide.md`, `API-Reference:-Event-Detection.md`, `Use-Case:-Multi-Sensor-Shared-Threshold.md` — updated
- [ ] Golden test comments referencing removed methods — **unchanged** (Pitfall 3)
- [ ] No `error('...:legacyRemoved', ...)` stubs remain in the touched area
- [ ] `tests/run_all_tests.m` Octave run — 73/75 (or higher if deletes remove pre-existing failures) pass
- [ ] MATLAB R2020b CI — TestGoldenIntegration green

### Item 2: DashboardSerializer .m export for Tag

- [ ] `linesForWidget` has a `case 'tag':` branch
- [ ] Strategy for missing-Tag resolution chosen (A/B/C from Pitfall 8) and documented inline
- [ ] `case 'sensor':` legacy branch — either deleted (clean v2.0) or documented as "read-only legacy path"
- [ ] `TestDashboardSerializer.m` / `TestDashboardMSerializer.m` has a new test case: export `.m` for a Tag-bound FastSenseWidget, execute it in a subprocess, assert the resulting DashboardEngine matches
- [ ] Round-trip tests for all 11 widget types that bind to Tags (FastSenseWidget, StatusWidget, NumberWidget, GaugeWidget, MultiStatusWidget, IconCardWidget, SparklineCardWidget, ChipBarWidget, TableWidget, RawAxesWidget, plus EventTimelineWidget which uses `FilterTagKey`)
- [ ] Multi-page round-trip: `exportScriptPages` must also handle Tag widgets
- [ ] CompositeTag children emitted before parent (if .m export handles CompositeTag-bound widgets)
- [ ] Generated `.m` file has valid MATLAB syntax (smoke test: parse it)

### Item 3: 93 Threshold refs cleanup

- [ ] Per-file classification table committed (DELETE / MIGRATE / LEAVE with reason)
- [ ] DELETE bucket: entire test files removed (likely: `TestEventDetector.m`, `TestIncrementalDetector.m`, `TestEventConfig.m` + Octave-flat siblings + possibly `TestCompositeThreshold.m`)
- [ ] MIGRATE bucket: per-file commits (not one big commit) — Phase 1009 precedent
- [ ] LEAVE bucket: grep audit proves every remaining `Threshold(` is `fp.addThreshold` or similar surviving-API usage
- [ ] Post-cleanup grep: `grep -rE "(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule)\(" tests/` returns 0 non-surviving-API hits
- [ ] Octave test count (run_all_tests.m) must not REGRESS — if tests are deleted, expected count drops; document the new baseline
- [ ] Each migrated test's assertion values re-derived from fixture, not copy-pasted
- [ ] Golden integration test unchanged (Pitfall 3 gate)
- [ ] MISS_HIT lint + complexity metrics still within `miss_hit.cfg` limits (cyc 85, function_length 550)

### Item 4: 05-events live-demo rewrites

- [ ] `example_event_detection_live.m` — no `return; %#ok<UNRCH>` guard; full body executes
- [ ] `example_event_viewer_from_file.m` — same
- [ ] Both files: `TagRegistry.clear(); EventBinding.clear();` at top
- [ ] Both files: zero `persistent` variables
- [ ] Both files: any timers bounded by `TasksToExecute` or cleaned via `onCleanup`
- [ ] Both files: no `datetime`, `table`, `categorical`, `duration`, or other MATLAB-only APIs (Pitfall 12)
- [ ] Both files: EventStore paths use `tempdir`, never repo-relative
- [ ] Both files: distinct pedagogical purpose from `example_sensor_threshold.m` (Pitfall 11)
- [ ] `test_examples_smoke.m` + `run_all_examples.m` skip lists — UPDATED in both (Pitfall 18 parity gate)
- [ ] Octave smoke green on both examples
- [ ] MATLAB examples.yml list — if these examples move from Octave-skip to Octave-ready, curated MATLAB-only list (lines 173-203) may need touch
- [ ] `timerfindall()` returns 0 after each example completes (Pitfall 10 gate)
- [ ] Docstrings updated to match new body (Pitfall 20)

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| 1 Scope creep into refactor | LOW | `git reset --hard` to last on-scope commit; redo just the scoped change |
| 2 Dead code isn't dead | MEDIUM | Re-run cross-repo grep; revert stub/delete; properly classify callers; repeat deletion |
| 3 Golden test touched | LOW | `git checkout HEAD~N -- tests/suite/TestGoldenIntegration.m tests/test_golden_integration.m` |
| 4 Test migration drift | MEDIUM-HIGH | Per-file: run the test against fixture data on a pre-migration checkout, compare output to post-migration; align assertion values to the NEW Tag semantics, not the old |
| 5 Silent-skip drift | LOW | Add the warning-on-passthrough edit to `run_all_tests.m`; re-run CI |
| 6 R2025b drift in v2.1 | LOW | Revert the R2025b-targeting change; log as separate tech-debt ticket for a future "R2025b compat" milestone |
| 7 Bisect-hostile commit | HIGH | Can't retroactively split after merge; use `git log -p -- tests/suite/<file>` per-file for future bisects |
| 8 Tag-export strategy mismatch | MEDIUM | Change strategy; add round-trip test; re-run |
| 9 Source-type ambiguity | LOW-MEDIUM | Delete legacy emitter branch; confirm no in-the-wild JSON exists; re-run serialization suite |
| 10 Timer leak | LOW | Add `timerfindall` assertion in smoke runner; fix the specific example |
| 11 Demo duplication | LOW | Diff and differentiate; keep canonical one canonical |
| 12 MATLAB-only API in Octave demo | LOW | Replace API or add to skip list with rationale |

---

## Pitfall-to-Phase Mapping

Suggested v2.1 phase structure and which pitfalls each phase must gate.

| Pitfall | Primary Phase | Secondary (Verify) | Gate Mechanism |
|---------|---------------|---------------------|----------------|
| 1 Scope creep | All phases | All phase-exit `affected_files` gate | `git diff --name-only` vs PLAN |
| 2 Dead code not dead | Phase delivering item 1 | All | Cross-repo grep gate |
| 3 Golden test untouched | All phases | All phase-exit | `git diff -- tests/**/TestGoldenIntegration* tests/**/test_golden_integration*` zero lines |
| 4 Test migration drift | Phase delivering item 3 | Per-file verify | Assertion-value walk-through in commit message |
| 5 Silent-skip pathology | Phase delivering item 4 (or earlier sweep phase) | All phase-exit | `is_cleanup_crash` branch warning + skip-list parity diff |
| 6 R2025b out of scope | Planning + all phases | Phase-exit | Forbidden-files grep (Pitfall 6 list) |
| 7 Bisect granularity | All phases | Pre-merge review | Commit-count-per-file gate |
| 8 .m export Tag strategy | Phase delivering item 2 | Round-trip test | Subprocess-execute generated .m |
| 9 Source-type ambiguity | Phase delivering item 2 | Round-trip tests | Grep for `'type', 'sensor'` in libs/Dashboard/ writes |
| 10 Timer leaks | Phase delivering item 4 | Smoke runner gate | `timerfindall` assertion |
| 11 Demo duplication | Phase delivering item 4 | Planning | One-liner purpose for each of 3 demos in PLAN |
| 12 MATLAB-only API | Phase delivering item 4 | Smoke runner | `grep -E 'datetime\|table\|categorical\('` gate |
| 13-20 Minor | Execute in the delivering phase | Phase-exit checklist | "Looks Done But Isn't" checklist above |

---

## Phase Structure Recommendations

Four items, four phases is the minimal discipline. Suggested ordering (dependency-driven):

1. **v2.1-Phase-1: Dead code deletion (item 1).** No dependencies. Smallest surface. De-risks every later phase by removing zombie callers. Expected net lines: -300 to -500 (method bodies + test files deleted).

2. **v2.1-Phase-2: DashboardSerializer .m export (item 2).** Depends on: nothing (Tag API already stable). Small focused addition + case-branch deletion. Expected net lines: +40 to +80.

3. **v2.1-Phase-3: Test cleanup (item 3).** Depends on: Phase 1 (deleted methods inform which tests are DELETE vs MIGRATE; doing Phase 1 first prevents migrating tests that should be deleted). Per-file commits. Expected net lines: -500 to -1500 (big delete surface; depends on how many test files land in DELETE bucket).

4. **v2.1-Phase-4: Live demo rewrites (item 4).** Depends on: nothing in v2.1 (Tag API already stable). Optional parallel with Phase 3, but sequential is simpler for reviewer. Expected net lines: +300 to +450 (two ~150-line rewrites, minus the ~50-line deprecation stub each).

Each phase ends with a 6-gate regression sweep (pattern from Phase 1012 Plan 10):

- Gate A: `affected_files` respected (Pitfall 1)
- Gate B: Golden test untouched (Pitfall 3)
- Gate C: No dead-code stubs remain (Pitfall 2, 16)
- Gate D: Octave smoke green (Pitfalls 10, 12)
- Gate E: MATLAB R2020b CI green (Pitfalls 4, 7)
- Gate F: Skip-list parity (Pitfall 18)

Milestone exit: re-run every gate from each phase, plus the "Looks Done But Isn't" checklist for every item.

---

## Sources

- `.planning/milestones/v2.0-MILESTONE-AUDIT.md` — tech debt item list, pitfall gate table (Pitfalls 1-12 v2.0)
- `.planning/milestones/v2.0-phases/1011-cleanup-collapse-parallel-hierarchy-delete-legacy/1011-VERIFICATION.md` — Phase 1011 pitfall-gate verdicts; `deferred-items.md` for EventConfig, EventViewer threshold display
- `.planning/milestones/v2.0-phases/1011-cleanup-collapse-parallel-hierarchy-delete-legacy/1011-RESEARCH.md` — Sensor delegate inlining rationale
- `.planning/phases/1012-migrate-examples-to-tag-api/1012-VERIFICATION.md` — six-gate regression sweep pattern, 05-events deferral note
- `.planning/debug/matlab-tests-failures-investigation.md` — R2025b failure catalog (Pitfall 6 scope-guard list)
- `.planning/debug/octave-cleanup-crash-investigation.md` — break_closure_cycles bug #67749 fix in Octave 11.1.0 (Pitfall 5)
- `.planning/STATE.md` — Phase 1004-1012 accumulated decisions (TagRegistry hard-error, two-phase loader, per-widget commits, skip-list parity)
- `tests/run_all_tests.m:127-135` — silent-skip passthrough for break_closure_cycles (Pitfall 5)
- `tests/test_examples_smoke.m:73-87`, `examples/run_all_examples.m:53-67` — skip-list parity (Pitfall 18)
- `tests/suite/TestGoldenIntegration.m`, `tests/test_golden_integration.m` — Phase 1011 rewrite, same-fixture-same-assertions (Pitfall 3)
- `libs/Dashboard/DashboardSerializer.m:588-718` — `linesForWidget` switch with `'sensor'|'file'|'data'` cases, no `'tag'` case (Pitfall 8, 9)
- `libs/Dashboard/FastSenseWidget.m:258,374-400` — `source.type='tag'` emission and loader (Pitfall 9)
- `libs/EventDetection/EventConfig.m:35-42`, `IncrementalEventDetector.m:31-41` — post-Phase-1011 error stubs (Pitfall 2, 16)
- `libs/EventDetection/EventDetector.m:39-75` — surviving 2-arg `detect(tag, threshold)` method (Pitfall 2)
- `libs/SensorThreshold/TagRegistry.m:109,375-379`, `libs/EventDetection/EventBinding.m:95,111,120` — singleton clear semantics (Pitfall 13, 15)
- `.github/workflows/tests.yml:101,247-248` — Octave 11.1.0, MATLAB R2020b pin (Pitfalls 5, 6)
- `.github/workflows/examples.yml:28,163,180-203` — Octave + MATLAB examples split (Pitfall 12)
- `examples/02-sensors/example_sensor_threshold.m` — canonical MonitorTag+EventStore+EventBinding pipeline (Pitfall 11)
- `examples/05-events/example_event_detection_live.m`, `example_event_viewer_from_file.m` — current stub state (Pitfalls 10, 11, 14, 17)
- `miss_hit.cfg:17-23` — complexity limits (Pitfall 1 budget context)

---
*Pitfalls research for: v2.1 Tag-API Tech Debt Cleanup*
*Researched: 2026-04-22*
