# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v2.0 — Tag-Based Domain Model

**Shipped:** 2026-04-23
**Phases:** 18 | **Plans:** 46 | **Timeline:** 48 days (2026-03-06 → 2026-04-23) | **Commits:** ~396

### What Was Built

- **Unified Tag domain model** replacing 8 legacy classes (`Sensor`, `Threshold`, `ThresholdRule`, `CompositeThreshold`, `StateChannel`, `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry`) with 7 Tag-rooted classes (`Tag`, `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `TagRegistry`, `EventBinding`). Every consumer migrated one-widget-per-commit.
- **Dashboard Performance Phase 2** — 10–50× faster live ticks through incremental widget refresh, O(1) cached time ranges, debounced slider broadcast, lazy page realization, batched switchPage, debounced resize.
- **First-Class Thresholds + Composite Thresholds** with direct widget binding (StatusWidget/GaugeWidget/IconCardWidget/MultiStatusWidget/ChipBarWidget).
- **Event↔Tag binding with FastSense overlay** — many-to-many `EventBinding` registry, toggleable round-marker render layer theme-colored by severity, separate render path keeps line-render hot path clean.
- **Tag ingestion pipeline** — `BatchTagPipeline` (sync) + `LiveTagPipeline` (timer, modTime+lastIndex incremental) ingest raw delimited files → per-tag `.mat`.
- **Prebuilt MEX binaries** — macOS ARM64 shipped (27 files), `.mex-version` stamp gates rebuild, `refresh-mex-binaries.yml` 7-platform matrix workflow with auto-PR, 5 existing CI workflows rewired to reuse committed binaries.
- **Mushroom card widgets** (IconCardWidget, ChipBarWidget, SparklineCardWidget), **image/data export** (PNG/JPEG + .mat/.csv), **MATLAB CI** with R2025b drift fixes (137 tests).

### What Worked

- **12 explicit Pitfall gates in PITFALLS.md** kept the rewrite honest. Falsifiable file-touch budgets per phase (≤20 files Phase 1004, ≤12 Phase 1010, etc.), semantics-drift checks, render-path purity gates, and the golden-test sanctity rule prevented scope creep and architectural erosion across 18 phases.
- **Golden integration test from Phase 1004** untouched throughout the rewrite gave a stable safety net. Rewritten only in Phase 1011 (the cleanup phase) to call `addTag` instead of `addSensor` — same assertions, proving end-to-end behavior preserved.
- **One-widget-per-commit migration strategy** (Phase 1009) made the rewrite incrementally revertable. Each commit independently green.
- **Strangler-fig discipline** — legacy `addSensor()` and new `addTag()` coexisted until Phase 1011's deletion sweep, zero downtime in the migration.
- **TDD RED→GREEN on Phase 1013-07 gap closure** — rewriting `testNeedsBuildFalseWhenMatch` to fail on the Plan 03 subdir layout *before* moving `mex_stamp.m` caught the actual bug (private-dir scoping silently swallowed in `install.m`'s try/catch) that auto-SKIP had hidden from CI.
- **Audit-driven tech debt tracking** — 2026-04-17 milestone audit scored 45/45 requirements, 45/45 integration, 8/8 flows but surfaced 3 tech debt items (EventDetector dead code, `.m` export tag gap, 93 MATLAB-only test refs). All carried forward with explicit visibility.

### What Was Inefficient

- **Phase numbering collisions** — "Phase 1004" was used twice (Tag Foundation + Dashboard Image Export), "Phase 1005/1006" also collided between v2.0 original scope and post-audit additions. Made ROADMAP.md and progress tracking ambiguous. Future milestones should enforce monotonic phase numbers or namespace by milestone.
- **SUMMARY.md one-liner extraction** — many summaries produced `One-liner:` as a literal placeholder rather than actual content, so auto-generated MILESTONES.md entries from `summary-extract` required manual rewrite at milestone completion. Fix: enforce a structured one-liner field in the summary template with required content before commit.
- **Phase 1005 (CI coverage expansion)** was added to the roadmap but never planned or executed. Ambiguous "pending" status for 6+ days. Partially superseded by other phases. Cost: roadmap noise, unclear what remained.
- **Stale regression test on Phase 1013** — `testNeedsBuildFalseWhenMatch` used a sentinel path that Plan 03's subdir layout no longer produced, causing auto-SKIP and hiding the primary-gate failure until post-phase verification. The test was "green" but meaningless. Future: verify tests actually assert on the platform they target; refuse to ship with any `SKIP` in a critical-path gate test.
- **4 debug sessions accumulated unresolved** across the milestone (CI failures, MATLAB/Octave tests). Visible via `/gsd:progress` throughout but never blocked a phase. Risk of indefinite accumulation — needs a triage cadence.

### Patterns Established

- **PITFALLS.md as a phase-entry gate** — explicit, grep-verifiable, falsifiable pitfall list referenced by every phase plan's `<verification>` block. Turns "avoid over-abstraction" into "Tag base class has ≤6 abstract methods; no `error('NotApplicable')` stub anywhere in subclasses this phase."
- **Strangler-fig + Golden test + Audit trio** for any rewrite: (1) parallel hierarchy, (2) untouchable end-to-end regression, (3) milestone audit with requirement/integration/flow scoring. If you're deleting classes, you need all three.
- **`requirements: []` on gap-closure plans** — plans with `gap_closure: true` don't map to roadmap REQ-IDs. Gap coverage is derived from VERIFICATION.md.
- **Auto-approved human-verify checkpoints under `workflow.auto_advance: true`** — the orchestrator bypasses interactive gates on autonomous plans, but still persists items to HUMAN-UAT.md for human follow-up when re-verification genuinely needs a human (e.g., "no MATLAB on dev host").
- **Planning-document-drift prevention** — PROJECT.md evolves at every phase completion, not just milestones. Active→Validated moves, decisions logged inline.
- **Public scope for cross-boundary helpers** — MATLAB `private/` directories scope functions to the containing library; helpers called from repo root (`install.m`) must live in public scope. General rule: if `install.m` calls it, it doesn't live in `private/`.

### Key Lessons

1. **Tests that auto-SKIP are not tests.** If a test's assertions depend on a platform-specific artifact that may not exist, it must fail loudly when the artifact is missing — not silently skip. Otherwise CI reports green while the primary gate is broken.
2. **Gap closure should be TDD-first.** Writing the failing regression test before the fix is the only way to prove the gap was real and the fix addresses it. Plan 1013-07's RED→GREEN commit ordering caught what a single "fix + green test" commit would have missed.
3. **Numbering collisions between original scope and post-audit additions are real costs.** Future milestones should either (a) reserve a decimal sub-range (e.g., 1013.1, 1013.2) for post-audit phases or (b) renumber on audit. Don't reuse ints.
4. **Record tech debt at the audit, not at ship time.** v2.0 audit surfaced 3 items on 2026-04-17, giving 6 days' visibility before ship. Earlier awareness means conscious decisions (carry forward vs. close now vs. cut scope) instead of ship-day discoveries.
5. **"Also available" routing commands are worth the context cost.** Every major orchestrator output (progress, execute-phase complete, plan-phase complete) ended with a clearly-labeled next-action + 2–4 alternatives. Made multi-step orchestration legible and correctable.
6. **Belt-and-suspenders backstops are valuable but must be documented.** `build_mex.m`'s mtime guard saved the install fast-path when the stamp check was broken — but also hid the bug. Solution: keep the backstop, but mark it loudly as `BACKSTOP, not the primary gate`. Future debuggers read code before they read plans.

### Cost Observations

- **Model mix (inferred from config):** planner: `opus`, researcher/executor/checker/verifier: `sonnet`. Opus reserved for high-leverage planning; sonnet for the hot loop of execution.
- **Session count:** not tracked. Sessions are free-form; this retrospective written across at least 3 distinct sessions.
- **Token efficiency observation:** parallel wave execution (Wave 4 Phase 1013 ran Plans 05 & 06 concurrently in isolated worktrees) completed in ~10 min wall-clock; sequential would have been ~20. Parallelization via git worktrees has real, measurable wins when plans are file-disjoint.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v1.0 Advanced Dashboard | 9 | 24 | Initial release — widget dashboard engine with tabs, collapsible groups, multi-page, detachable widgets |
| v1.0 Code Review Fixes | 1 | 4 | Post-ship bug cleanup — 14 issues across DashboardEngine, widgets, serializer |
| v1.0 Performance Optimization | 1 | 3 | First performance pass — theme caching, O(1) widget dispatch, single-pass live tick |
| v1.0 First-Class Thresholds | 4 | 14 | Threshold handle class + registry + widget binding + composites (preserved under v2.0 as concepts) |
| v2.0 Tag-Based Domain Model | 18 | 46 | Full domain rewrite + performance phase 2 + CI + prebuilt MEX + ingestion pipeline |

### Cumulative Quality

| Milestone | MATLAB LOC | Tests | Zero-Dep Additions |
|-----------|-----------|-------|-------------------|
| v1.0 shipped | ~24,473 | (baseline) | 3 new widget classes |
| v2.0 shipped | 66,638 | 76 Octave tests green | 7 Tag classes, 2 pipeline classes, 3 card widgets, 27 prebuilt MEX artifacts |

### Top Lessons (Verified Across Milestones)

1. **Pure-MATLAB constraint is a feature, not a limit.** v1.0 + v2.0 shipped zero new external dependencies; MEX extensions are bundled source. Deployability to any MATLAB R2020b+ / Octave 7+ environment remained uncompromised across 46 plans.
2. **Plans are only as good as their acceptance criteria.** Plans with grep-verifiable `<acceptance_criteria>` and concrete `<action>` values produce complete execution; vague "align X with Y" plans produce shallow work. Enforced via `<deep_work_rules>` in every planner prompt.
3. **Golden tests + audit scoring + strangler-fig** is the complete rewrite toolkit. All three in combination; any one alone is insufficient.
