# Project Research Summary — v2.1 Tag-API Tech Debt Cleanup

**Project:** FastSense Advanced Dashboard
**Milestone:** v2.1 — Tag-API Tech Debt Cleanup
**Domain:** Post-migration cleanup on a shipped v2.0 Tag-based MATLAB/Octave dashboard codebase
**Researched:** 2026-04-22
**Confidence:** HIGH

---

## TL;DR

v2.1 is a **pure tech-debt cleanup** closing the 4 non-blocking items from the v2.0 milestone audit — NOT new feature work. Every replacement API (`MonitorTag`, `EventStore`, `EventBinding`, `LiveEventPipeline`, `TagRegistry`, `FastSense.addTag`, `DashboardSerializer.linesForWidget`) already ships in v2.0. There are **zero new dependencies** and **zero new abstractions**; every fix is a mechanical migration, deletion, or copy-paste-with-minor-edit against existing patterns. The work is "small on paper" but sits in the highest-risk cleanup category: the incentive to scope-creep ("while I'm in here…") is maximal, and several silent-skip mechanisms (Octave subprocess runner, `test_examples_smoke` skip list) could hide regressions introduced by the cleanup itself.

**We are NOT building:** new classes, new APIs, asset hierarchy, custom event GUI, calc tags, tri-state severity, WebBridge tag parity, a parametric test framework, a codegen library, a mocking layer, or any Python/web changes. This is discipline, not invention.

---

## Scope

Four items from `.planning/milestones/v2.0-MILESTONE-AUDIT.md`. Count numbers below reflect direct grep verification against the live codebase (audit figures were slightly stale).

| # | Item | Surface | Complexity | Net LOC |
|---|------|---------|------------|---------|
| 1 | Stub/delete `EventDetector.detect(tag, threshold)` dead code (also `IncrementalEventDetector.process`, `EventConfig.addSensor`, possibly full-class deletions) | `libs/EventDetection/EventDetector.m` + zombie test files | **Simple** (Medium if full-class chain delete) | -300 to -500 |
| 2 | `DashboardSerializer` `.m` export — add `case 'tag'` branch (currently silently drops Tag binding; JSON path already works) | `libs/Dashboard/DashboardSerializer.m` (two switch blocks at line 38 `save()` and line 598 `linesForWidget`) + round-trip test | **Simple** | +40 to +80 |
| 3 | Clean up ~73–98 `Threshold(`/`CompositeThreshold(`/`StateChannel(`/`ThresholdRule(` constructor refs across ~16–22 MATLAB-only suite test files (plus ~6 Octave-flat siblings) | `tests/suite/Test*.m` + `tests/test_*.m`; some DELETE, some MIGRATE, leave `fp.addThreshold()` surviving API alone | **Medium** (volume-driven, not complexity-driven) | -500 to -1500 |
| 4 | Rewrite `examples/05-events/example_event_detection_live.m` + `example_event_viewer_from_file.m` as fully-migrated `MonitorTag + EventStore + EventBinding` pipelines; fix any strays in `example_live_pipeline.m` | `examples/05-events/*.m` + skip-list parity updates | **Medium** (~150–200 LOC each, templates exist) | +300 to +450 |

**Audit figure note:** the audit said "93 refs in 42 files." Direct grep at v2.1 kickoff found **73 `Threshold(` constructor refs in 16 suite files** — the audit's 42 counted Octave-flat sidecars that don't actually reference `Threshold` (it's MATLAB-only / deleted). PITFALLS.md uses 98 when counting `CompositeThreshold`/`StateChannel`/`ThresholdRule` patterns together; both figures are correct depending on regex precision. Plan in terms of **~16–22 files, ~73–98 refs**, and classify per-file before editing.

---

## Stack Decision

**No new dependencies. Zero new libraries. One CI gate.**

Everything v2.1 needs already ships in v2.0:

- **MATLAB R2020b+ / Octave 11.1.0** — CI pinned; R2025b drift is explicitly **out of scope** for v2.1 (catalogued in `.planning/debug/matlab-tests-failures-investigation.md`).
- **matlab.unittest** with `testCase.assumeTrue(false, 'reason')` — already the project idiom for skip-with-reason (43 usages across 17 suite files). No new test framework.
- **Custom Octave subprocess runner** in `tests/run_all_tests.m` — no change.
- **MISS_HIT lint/style/metrics** — no rule changes (`miss_hit.cfg` limits at cyc=85, function_length=550, line_length=160 all hold).
- **Tag API surface** (`SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `TagRegistry`, `EventBinding`, `EventStore`, `LiveEventPipeline`, `MockDataSource`, `MatFileDataSource`, `EventViewer.fromFile`, `FastSense.addTag`) — fully covers every demand of every item.
- **Fixture factories** (`tests/suite/makePhase1009Fixtures.m`, `MockTag.m`) — reuse for all test rewrites.

**ONE recommended addition — grep regression gate in `.github/workflows/tests.yml` `lint` job.** Fails CI on any new reference to the 8 classes deleted in Phase 1011 (`Threshold`, `CompositeThreshold`, `StateChannel`, `ThresholdRule`, `Sensor`, `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry`). Phase 1012 Plan 10 already ran this grep manually during the v2.0 regression sweep; v2.1 promotes it to CI. 15 lines of YAML, 0 dependencies, <5 s per run. The grep filter must preserve `fp.addThreshold()` / `obj.addThreshold()` — those are the **surviving** FastSense plot-annotation API, not the deleted class. See STACK.md §"New Tooling" for the exact YAML snippet.

**Rejected alternatives:** matlab.mock (deletion beats mocking for dead code), codegen library for `.m` export (copy-paste the existing `case 'sensor'` pattern), parametric test framework (no leverage over heterogeneous test setups), `dictionary` R2022b type (Octave lacks it, MATLAB CI pins to R2020b), re-introducing `Threshold` as a deprecation shim (explicit Phase 1011 Pitfall 12 violation).

Full rationale: `.planning/research/STACK.md`.

---

## Feature Priorities

Collapsed across all 4 items.

### Table stakes (must-do)

- **Item 1:** Hard-error stub matching the established `EventConfig.addSensor` / `IncrementalEventDetector.process` pattern — `error('EventDetector:legacyRemoved', 'detect(tag, threshold) depended on the deleted Threshold class. Use MonitorTag + EventStore for event detection.')` — OR full deletion of `EventDetector.m` + `IncrementalEventDetector.m` + `EventConfig.m` + their test zombies.
- **Item 2:** `case 'tag'` branch added to BOTH `DashboardSerializer.save()` (line 38) AND `DashboardSerializer.linesForWidget()` (line 598); emit `TagRegistry.get('KEY')` mirroring the existing `'sensor'` case; round-trip test covering save-to-`.m` → `feval` → assert widget `Tag` handle resolves.
- **Item 3:** Per-file classification (DELETE / MIGRATE / LEAVE); per-file commit for MIGRATE bucket (bisect discipline); delete `TestEventConfig.m` + `TestIncrementalDetector.m` outright (zombie tests for stubbed code); rewrite `TestStatusWidget`/`TestGaugeWidget`/`TestIconCardWidget`/`TestMultiStatusWidget`/etc. using `MonitorTag` + `makePhase1009Fixtures`; trim `TestEventDetectorTag.m` to the 6-arg legacy signature + error-path methods only.
- **Item 4:** Drop the `return;` deprecation-banner stubs; rewrite as `SensorTag` + `MonitorTag` + `EventStore` + `LiveEventPipeline` + `MockDataSource`/`MatFileDataSource` compositions; `TagRegistry.clear()` + `EventBinding.clear()` at top of each file; remove from `test_examples_smoke.m` AND `examples/run_all_examples.m` skip lists (parity-maintained).

### Differentiators (should-do; low-cost value)

- **Promote Phase 1012's manual grep regression sweep to a CI lint step** (one-time, protects every future milestone).
- **Add a file-header `% DO NOT REWRITE` banner** to `TestGoldenIntegration.m` + `test_golden_integration.m` (Pitfall 3 prevention — currently only documented in v2.0 STATE.md, not the file itself).
- **Consolidate legacy-deprecation contract tests** into a single `TestLegacyEventDetectionRemoved.m` that asserts the `EventDetector:legacyRemoved` / `EventConfig:legacyRemoved` / `IncrementalEventDetector:legacyRemoved` error IDs fire — replaces 3 deleted suite files with one focused deprecation-contract test.
- **Update skip-list parity from comment-enforced to script-enforced** (`scripts/check_skip_list_parity.sh` callable from CI).
- **Wire `NotificationService(DryRun=true)`** into at least one rewritten demo for pedagogical parity with `example_live_pipeline.m`.

### Anti-features (explicitly DO NOT)

- Re-introduce `Threshold` as a thin deprecation shim (Phase 1011 Pitfall 12 violation).
- Bulk `sed -i 's/Threshold(/Tag(/g'` — breaks `fp.addThreshold()` surviving API + loses assertion semantics.
- Add warning-then-delegate shim for `EventDetector.detect(tag, threshold)` — codebase has "no users"; hard-error is the decision.
- Emit `SensorTag('k', 'X', [...], 'Y', [...])` inline in `.m` export — creates 10k-line scripts; use `TagRegistry.get('k')` + register-before-run contract (matches existing `'sensor'` case).
- Keep `source.type='sensor'` emitter branch alongside new `'tag'` branch — two-path drift; delete legacy emitter, keep reader only if compat policy says so (decide in PLAN.md).
- Use `datetime` / `table` / `categorical` in rewritten examples (Octave smoke breaks; not needed — canonical demos use `linspace`).
- Leave `persistent` variables or unbounded MATLAB `timer` objects in rewritten demos (cross-example contamination in smoke runner).
- Scope-creep into refactor of `linesForWidget` or any unrelated file while in the neighborhood.

Full rationale: `.planning/research/FEATURES.md`.

---

## Architecture Picture

**Integration story.** Every fix lives **inside an existing file** (or deletes files that already exist). No new classes. Items are largely independent; Item 3 has a minor ordering dependency on Item 1 (DELETE test file for `EventDetectorTag` only makes sense once the `detect(tag,threshold)` stub semantics are locked in). The dependency graph is shallow:

```
[Item 1: EventDetector dead code]
      └── informs ──> [Item 3: test cleanup]
                            ├── DELETE TestEventConfig / TestIncrementalDetector (independent)
                            ├── DELETE TestEventDetectorTag (depends on Item 1 stub shape)
                            ├── REWRITE TestStatusWidget / TestGaugeWidget / TestMultiStatusWidget / etc. (independent)
                            └── TRIM TestLiveEventPipelineTag (independent)

[Item 2: .m export case 'tag']
      └── independent of Items 1/3/4

[Item 4: examples/05-events rewrites]
      └── independent of Items 1/2/3 (Tag API ships; templates ship)
      └── MUST coordinate skip-list parity in tests/test_examples_smoke.m + examples/run_all_examples.m
```

**Build order (recommended): Item 1 → Item 3, with Items 2 and 4 in parallel.** Item 1 first because it settles the delete-vs-stub decision that Item 3's DELETE bucket depends on. Items 2 and 4 are independent and can run in any order relative to Items 1/3.

**Files untouched.** FastSense render core (downsampling, MEX kernels, `FastSenseDataStore` core, `DashboardEngine`, `DashboardLayout`, `DashboardTheme`, `DashboardBuilder`, all widgets except their test files, WebBridge end-to-end) all remain as-shipped. This is cleanup around the edges, not a core touch.

Full integration map + per-item new/modified/deleted file tables: `.planning/research/ARCHITECTURE.md`.

---

## Pitfall Watch List

Top 5 of 12+6+2 cataloged. Each has a falsifiable CI-style gate in PITFALLS.md.

1. **Scope creep ("while I'm in here…")** — declare `affected_files` + net-line budget in each PLAN.md; reject commits that edit files outside the list. Gate: `git diff --name-only` vs PLAN `affected_files` intersection must be empty.

2. **Golden test creep** — `TestGoldenIntegration.m` + `test_golden_integration.m` must have **zero diff** across every v2.1 phase (comments included). Gate: `git diff HEAD~..HEAD -- tests/**/*olden*` → 0 lines. Add a `% DO NOT REWRITE` file-header if not present.

3. **Bulk test migration drift (sed breaks assertion semantics)** — per-file review only. `fp.addThreshold()` is a surviving API and must not be replaced. `MonitorTag` emits events with different timing semantics than the deleted `EventDetector.detect()`; assertion values must be **re-derived from the fixture**, not copy-pasted from the pre-migration test. Gate: post-migration grep for `(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule)\(` in `tests/` — 0 non-surviving-API hits.

4. **Silently-skipped tests stay silently skipped** — the Octave subprocess runner's `is_cleanup_crash` passthrough was correct for Octave 8.4.0 but bug #67749 is fixed in 11.1.0; it now masks real crashes. `test_examples_smoke.m` skip list is comment-enforced-parity with `examples/run_all_examples.m`. Gate: convert `is_cleanup_crash` branch to warn-and-count; script-enforce skip-list parity via `scripts/check_skip_list_parity.sh`.

5. **Live-demo timer & singleton leaks across smoke runs** — MATLAB timers are process-global; `persistent` variables survive function calls; `TagRegistry.clear()` mid-timer-tick crashes the next example. Gate: zero `persistent` in rewrites; bounded `TasksToExecute` or `onCleanup` on any timer; smoke runner asserts `timerfindall()` empty between examples.

Honorable mentions (see PITFALLS.md for full treatment):

- **Dead code that isn't actually dead** (Pitfall 2) — greps must cover `libs/`, `tests/`, `examples/`, `benchmarks/`, `docs/`, `wiki/`.
- **R2025b drift is NOT v2.1's job** (Pitfall 6) — explicit out-of-scope forbidden-files list in PLAN.md, drawn from `.planning/debug/matlab-tests-failures-investigation.md`.
- **Per-widget commit bisect discipline** (Pitfall 7) — no commit touches > 3 test files unless it's pure deletion.
- **`.m` export emits unregistered Tag references** (Pitfall 8) — choose strategy A/B/C explicitly in PLAN.md before editing.
- **`source.type='sensor'` vs `'tag'` ambiguity** (Pitfall 9) — decide backward-compat policy in PLAN.md; delete legacy emitter.
- **Demo duplicates `example_sensor_threshold.m`** (Pitfall 11) — each of the 3 demos must have a distinct pedagogical purpose written in its file header.
- **MATLAB-only APIs break Octave smoke** (Pitfall 12) — no `datetime`/`table`/`categorical`/`duration`; match `example_sensor_threshold.m`'s `linspace` pattern.

Full list (12 critical + 6 moderate + 2 minor) with recovery strategies: `.planning/research/PITFALLS.md`.

---

## Proposed Phase Shape

**4 phases, dependency-driven, 1 plan per phase** (item=phase mapping, matching the natural granularity of the cleanup).

| Phase | Item | Depends on | Complexity | Expected net LOC |
|-------|------|------------|------------|------------------|
| **v2.1-Phase-1** — Dead-code deletion | Item 1 | none | Simple | -300 to -500 |
| **v2.1-Phase-2** — `.m` export `case 'tag'` | Item 2 | none (Tag API stable) | Simple | +40 to +80 |
| **v2.1-Phase-3** — Test cleanup | Item 3 | Phase 1 (DELETE bucket informed by stub/delete decision) | Medium (volume) | -500 to -1500 |
| **v2.1-Phase-4** — `05-events` rewrites | Item 4 | none in v2.1 | Medium | +300 to +450 |

**Parallelism:** Phases 2 and 4 are independent of 1 and 3 and of each other. The user may parallelize them or run strictly sequentially; both work. The linear ordering **1 → 2 → 3 → 4** is the simplest and recommended.

**Per-phase exit gate (reuse Phase 1012 Plan 10 six-gate pattern):**

- **Gate A:** `affected_files` respected — `git diff --name-only` ⊆ PLAN `affected_files` (Pitfall 1).
- **Gate B:** Golden test untouched — `git diff -- tests/**/*olden*` → 0 lines (Pitfall 3).
- **Gate C:** No surviving dead-code stubs or legacy-class refs — grep gates from Pitfalls 2, 16, and STACK.md §"New Tooling" (Pitfalls 2, 16).
- **Gate D:** Octave smoke green — `tests/test_examples_smoke.m` passes; `timerfindall()` empty between examples (Pitfalls 10, 12).
- **Gate E:** MATLAB R2020b CI green — `run_all_tests.m` count doesn't regress (with documented drops for deleted test files) (Pitfalls 4, 7).
- **Gate F:** Skip-list parity — `test_examples_smoke.m` / `run_all_examples.m` diff empty (Pitfall 18).

**Research flags.** None of the 4 phases need `/gsd:research-phase` — v2.0 research + this synthesis already cover the ground. Every API exists; every pattern has a precedent file; every pitfall has a prior-phase gate. Recommend **skip phase research for all 4 phases** and jump straight to planning.

**Alternative shape: 1 phase / 4 plans.** Defensible if the user prefers a single milestone-shaped surface, but loses some parallelism and bisect granularity. Not recommended for v2.1's per-item-distinct cleanup work.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | No new deps proposed; every cited API verified against live codebase; matlab.unittest + MISS_HIT + Tag API all in production v2.0 |
| Features | **HIGH** | All 4 items grounded in direct grep + read of affected files; audit counts re-verified |
| Architecture | **HIGH** | Integration points are localized; no new components; existing patterns (`linesForWidget` switch, `assumeTrue` skip, `makePhase1009Fixtures`) apply directly |
| Pitfalls | **HIGH** | 20 pitfalls with falsifiable gates; precedent set by Phase 1004 Pitfall 5, Phase 1008 Pitfall 1, Phase 1011 Pitfall 12, Phase 1012 six-gate sweep |

**Overall confidence: HIGH.**

### Open Questions (decide before REQUIREMENTS.md)

1. **Item 1 — stub vs delete.** Stub preserves method signature + matches `EventConfig.addSensor` precedent; delete is cleaner (Pitfall 16) and cascades to removing `EventDetector.m` / `IncrementalEventDetector.m` / `EventConfig.m` entirely (≈-250 LOC extra). **Recommendation:** delete (no users, no external callers).

2. **Item 2 — `.m` export missing-Tag strategy.** Three options from Pitfall 8:
   - (A) Emit `% TODO: register tag 'foo'` comment + `TagRegistry.get(...)` — fails at run if not pre-registered.
   - (B) Emit `TagRegistry.register('foo', SensorTag(...))` with inline data — self-contained but can produce huge files.
   - (C) Guarded lookup: `if ~TagRegistry.has('foo'); error(...); end; TagRegistry.get('foo')`.
   **Recommendation:** (C) — mirrors existing `'sensor'` case semantics, never emits broken widgets silently, clean error message if user forgets to register.

3. **Item 2 — keep or delete legacy `case 'sensor'` emitter branch?** No users means no in-the-wild JSON fixtures; keeping it creates drift (Pitfall 9). **Recommendation:** delete the emitter; keep the reader if compat-policy-kept (decide in PLAN.md).

4. **Item 3 — scope of DELETE bucket.** Confirm whether `TestEventConfig.m` + `TestIncrementalDetector.m` + `TestCompositeThreshold.m` should be fully deleted (recommended if Item 1 goes full-class-delete route) or just trimmed. Affects net-LOC budget and test-count baseline.

5. **Item 4 — timer strategy.** Bounded (`TasksToExecute=5`) vs `onCleanup`-wrapped vs no-timer-at-all for `example_event_viewer_from_file.m`. **Recommendation:** `example_event_viewer_from_file.m` has no need for a timer (persistence-narrative); `example_event_detection_live.m` uses bounded `TasksToExecute` with `onCleanup` for safety (mirrors `example_live_pipeline.m`).

6. **Differentiators in/out?** The 5 should-do items (CI grep gate, golden-test banner, consolidated deprecation-contract test, script-enforced skip parity, NotificationService in a demo) are all LOW complexity but add surface. **Recommendation:** include all 5 — each directly prevents a future rebound of the very debt v2.1 is closing.

All six are **policy decisions with clear defaults**, not research gaps. Ready for user decision during REQUIREMENTS.md authoring.

---

## Sources

Research files (this directory):
- `.planning/research/STACK.md` — no-new-deps rationale + grep-gate YAML
- `.planning/research/FEATURES.md` — per-item table-stakes / differentiators / anti-features + MATLAB code sketches
- `.planning/research/ARCHITECTURE.md` — per-item integration map, dependency graph, new/modified/deleted file tables
- `.planning/research/PITFALLS.md` — 12 critical + 6 moderate + 2 minor pitfalls with falsifiable gates and phase mapping

---
*Research completed: 2026-04-22*
*Ready for REQUIREMENTS.md: yes — 6 open questions are policy decisions with clear defaults, not research gaps*
