# Roadmap: FastSense Advanced Dashboard

## Milestones

- ✅ **v1.0 FastSense Advanced Dashboard** — Phases 1-9 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Engine Code Review Fixes** — Phase 1 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Performance Optimization** — Phase 1 (shipped 2026-04-04)
- ✅ **v1.0 First-Class Thresholds & Composites** — Phases 1000-1003 (shipped 2026-04-15)
- ✅ **v2.0 Tag-Based Domain Model** — Phases 1004-1011 (shipped 2026-04-17)
- 📋 **v2.1 Tag-API Tech Debt Cleanup** — Phases 1012-1017 (carry-forward, parallel — not active)
- ✅ **v3.0 FastSense Companion** — Phases 1018-1023 + 1023.1 gap closure (shipped 2026-04-30)
- 🚧 **Pending milestone** — Phases 1025-1028 (promoted from backlog 2026-05-08, awaiting milestone scoping; 1024 closed via quick task 260508-d7k)

## Phases

<details open>
<summary>🚧 Pending milestone (Phases 1025-1028) — promoted from backlog 2026-05-08</summary>

- [x] Phase 1024: Fix companion app dark mode — closed via quick task [260508-d7k](./quick/260508-d7k-fix-companion-app-dark-mode-switching-th/) (2026-05-08)
- [ ] Phase 1025: FastSense hover crosshair + datatip
- [ ] Phase 1026: Dashboard time slider preview
- [x] Phase 1027: Companion detachable log window — completed 2026-05-08
- [ ] Phase 1027.1: Independent events/live log detach (gap closure)
- [x] Phase 1028: Tag update perf — MEX + SIMD — completed 2026-05-19

</details>

<details>
<summary>✅ v1.0 FastSense Advanced Dashboard (Phases 1-9) — SHIPPED 2026-04-03</summary>

- [x] Phase 1: Infrastructure Hardening (4/4 plans) — completed 2026-04-01
- [x] Phase 2: Collapsible Sections (2/2 plans) — completed 2026-04-01
- [x] Phase 3: Widget Info Tooltips (3/3 plans) — completed 2026-04-01
- [x] Phase 4: Multi-Page Navigation (3/3 plans) — completed 2026-04-01
- [x] Phase 5: Detachable Widgets (3/3 plans) — completed 2026-04-02
- [x] Phase 6: Serialization & Persistence (2/2 plans) — completed 2026-04-02
- [x] Phase 7: Tech Debt Cleanup (1/1 plan) — completed 2026-04-03
- [x] Phase 8: Widget Improvements (3/3 plans) — completed 2026-04-03
- [x] Phase 9: Threshold Mini-Labels (2/2 plans) — completed 2026-04-03

Full details: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v2.0 Tag-Based Domain Model (Phases 1004-1011) — SHIPPED 2026-04-17</summary>

- [x] Phase 1004: Tag Foundation + Golden Test
- [x] Phase 1005: SensorTag + StateTag (data carriers)
- [x] Phase 1006: MonitorTag (lazy, in-memory)
- [x] Phase 1007: MonitorTag streaming + persistence
- [x] Phase 1008: CompositeTag
- [x] Phase 1009: Consumer migration (one widget at a time)
- [x] Phase 1010: Event ↔ Tag binding + FastSense overlay
- [x] Phase 1011: Cleanup — collapse parallel hierarchy + delete legacy

Full details: [milestones/v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md)

</details>

<details>
<summary>🚧 v2.1 Tag-API Tech Debt Cleanup (Phases 1012-1017) — in flight</summary>

- [x] Phase 1012: Migrate examples to Tag API
- [x] Phase 1013: Dead code deletion — EventDetector, IncrementalEventDetector, EventConfig
- [x] Phase 1014: DashboardSerializer .m export for Tag-bound widgets
- 🚧 Phase 1017: Tag system event auto-wiring — registry default EventStore, dual-key emission

</details>

<details>
<summary>✅ v3.0 FastSense Companion (Phases 1018-1023 + 1023.1) — SHIPPED 2026-04-30</summary>

- [x] Phase 1018: Companion Shell + Project Handoff (3/3 plans) — completed 2026-04-29
- [x] Phase 1019: Tag Catalog (3/3 plans) — completed 2026-04-29
- [x] Phase 1020: Dashboard Browser (3/3 plans) — completed 2026-04-29
- [x] Phase 1021: Inspector (4/4 plans) — completed 2026-04-30
- [x] Phase 1022: Ad-Hoc Plot Composer (3/3 plans) — completed 2026-04-30
- [x] Phase 1023: Industrial Plant Demo Integration (2/2 plans) — completed 2026-04-30
- [x] Phase 1023.1: Cross-Phase Wiring Fixes (gap closure) — completed 2026-04-30

Full details: [milestones/v3.0-ROADMAP.md](milestones/v3.0-ROADMAP.md)

</details>

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-9 | v1.0 Advanced Dashboard | 24/24 | Complete | 2026-04-03 |
| 01. Code Review Fixes | v1.0 Code Review | 4/4 | Complete | 2026-04-03 |
| 01. Performance Optimization | v1.0 Performance | 3/3 | Complete | 2026-04-04 |
| 1000-1003 | v1.0 First-Class Thresholds | 14/14 | Complete | 2026-04-15 |
| 1004. Tag Foundation + Golden Test | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1005. SensorTag + StateTag | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1006. MonitorTag (lazy, in-memory) | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1007. MonitorTag streaming + persistence | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1008. CompositeTag | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1009. Consumer migration | v2.0 | 4/4 | Complete | 2026-04-17 |
| 1010. Event ↔ Tag binding + overlay | v2.0 | 3/3 | Complete | 2026-04-17 |
| 1011. Cleanup + delete legacy | v2.0 | 5/5 | Complete | 2026-04-17 |
| 1012. Migrate examples to Tag API | v2.1 | 10/10 | Complete | — |
| 1013. Dead code deletion | v2.1 | — | Complete | — |
| 1014. DashboardSerializer .m export | v2.1 | 1/1 | Complete | — |
| 1017. Tag system event auto-wiring | v2.1 | 0/? | In progress | — |
| 1018. Companion Shell + Project Handoff | v3.0 | 3/3 | Complete    | 2026-04-29 |
| 1019. Tag Catalog | v3.0 | 3/3 | Complete    | 2026-04-29 |
| 1020. Dashboard Browser | v3.0 | 3/3 | Complete   | 2026-04-29 |
| 1021. Inspector | v3.0 | 4/4 | Complete   | 2026-04-30 |
| 1022. Ad-Hoc Plot Composer | v3.0 | 3/3 | Complete   | 2026-04-30 |
| 1023. Industrial Plant Demo Integration | v3.0 | 2/2 | Complete | 2026-04-30 |
| 1023.1. Cross-Phase Wiring Fixes | v3.0 | gap-closure | Complete | 2026-04-30 |
| 1024. Fix companion app dark mode | pending | quick-task | Complete (via 260508-d7k) | 2026-05-08 |
| 1025. FastSense hover crosshair + datatip | pending | 0/? | Not started | — |
| 1026. Dashboard time slider preview | pending | 0/? | Not started | — |
| 1027. Companion detachable log window | pending | 5/5 | Complete    | 2026-05-08 |
| 1027.1. Independent events/live log detach | pending | 8/8 | Complete    | 2026-05-08 |
| 1028. Tag update perf — MEX + SIMD | pending | 6/6 | Complete | 2026-05-19 |

## Phase Details (Pending Milestone)

### Phase 1024: Fix companion app dark mode — CLOSED

**Status:** Closed 2026-05-08 via quick task [260508-d7k](./quick/260508-d7k-fix-companion-app-dark-mode-switching-th/).

**Root cause:** `applyThemeToChildren_` walker silently skipped widget classes without an explicit `case`. `uilistbox` (TagCatalogPane Row 7 — the tag list) was the visible casualty.

**Fix:** Added 8 widget cases to the walker (`ListBox`, `TextArea`, `CheckBox`, `NumericEditField`, `StateButton`, `ToggleButton`, `RadioButton`, `ButtonGroup`). Regression test asserts dark→light→dark flip across all classes.

**Promoted from:** Backlog 999.1 (2026-05-08)

### Phase 1025: FastSense hover crosshair + datatip

**Goal:** Add a vertical crosshair line that follows the mouse when hovering over a FastSense plot/widget, with a context datatip window showing the values of all lines at the hovered x position.

**Promoted from:** Backlog 999.2 (2026-05-08)
**Requirements:** TBD
**Plans:** 0 plans

### Phase 1026: Dashboard time slider preview

**Goal:** Fix the lower dashboard time slider so it shows a preview overlay of all graphed plot lines and detected events across the full time range. Currently the slider track is empty — investigate why the preview rendering isn't happening and restore it.

**Promoted from:** Backlog 999.3 (2026-05-08)
**Requirements:** TBD
**Plans:** 0 plans

### Phase 1027: Companion detachable log window

**Goal:** In the FastSense Companion app, make the log panel detachable into its own draggable, resizable window — same pop-out pattern as detachable widgets in the main dashboard. Implementation extracts the log strip into a `LogPane` class (mirrors existing pane pattern) with an `Inline`/`Detached`/`Hidden` state machine driven by a top-toolbar dropdown.

**Promoted from:** Backlog 999.4 (2026-05-08)
**Requirements:** TBD
**Plans:** 5/5 plans complete

Plans:
- [x] 1027-01-create-logpane-class-PLAN.md — extract self-contained `LogPane` class (UI + buffers + filter + theme + DetachRequested event)
- [x] 1027-02-test-logpane-PLAN.md — class-based unit suite covering attach/detach lifecycle, buffer preservation, theme switch, 500-row cap, event firing
- [x] 1027-03-integrate-logpane-companion-PLAN.md — wire `LogPane` into `FastSenseCompanion`, add toolbar `Live` button + `Log:` dropdown, implement `setLogState_` state machine, update theme walker to skip LogPaneRoot
- [x] 1027-04-extend-companion-tests-PLAN.md — add 10 state-machine + Live-button-relocation + theme-while-detached tests to `TestFastSenseCompanion`
- [x] 1027-05-update-walker-test-PLAN.md — add LogPaneRoot skip-rule assertions to `test_companion_apply_theme_walker`


### Phase 1027.1: Independent events/live log detach (gap closure)

**Goal:** Make the events log and the live updates log independently detachable. Phase 1027 detached them as one unit; this phase splits the contract so each log has its own `Inline`/`Detached`/`Hidden` state, its own pop-out icon, its own detached `uifigure`, and its own toolbar dropdown. Inline strip rebalances so the still-inline log fills the row.

**Source:** User feedback after Phase 1027 demo (2026-05-08) — "we have 2 logs right? I want both separately detachable."
**Spec:** [docs/superpowers/specs/2026-05-08-independent-log-detach-design.md](../../docs/superpowers/specs/2026-05-08-independent-log-detach-design.md)
**Requirements:** none — CONTEXT.md acceptance criteria are the contract
**Plans:** 8/8 plans complete

Plans:
- [x] 1027.1-01-create-events-log-pane-PLAN.md — port events-half of LogPane into self-contained `EventsLogPane` class (Wave 1, parallel-safe)
- [x] 1027.1-02-create-live-log-pane-PLAN.md — port live-half of LogPane into self-contained `LiveLogPane` class with own pop-out icon (Wave 1, parallel-safe)
- [x] 1027.1-03-test-events-log-pane-PLAN.md — class-based unit suite for EventsLogPane (Wave 2, depends on 01)
- [x] 1027.1-04-test-live-log-pane-PLAN.md — class-based unit suite for LiveLogPane (Wave 2, depends on 02)
- [x] 1027.1-05-companion-integration-PLAN.md — heavy: replace LogPane with two panes, two dropdowns, two detached uifigures, parameterized `setLogState_(which, newState)`, `rebalanceLogStrip_()` (Wave 3, depends on 01+02)
- [x] 1027.1-06-delete-old-logpane-PLAN.md — delete `libs/FastSenseCompanion/LogPane.m` and `tests/suite/TestLogPane.m` (Wave 4, depends on 05)
- [x] 1027.1-07-update-companion-tests-PLAN.md — migrate Phase 1027 accessors and add 5 independence tests to `TestFastSenseCompanion` (Wave 4, depends on 05)
- [x] 1027.1-08-update-walker-test-PLAN.md — assert two-panel LogPaneRoot skip-rule in walker test (Wave 4, depends on 05)


### Phase 1028: Tag update perf — MEX + SIMD — COMPLETE

**Status:** Complete 2026-05-19.

**Headline:** 1000-tag WithIO `tickMin` reduced from Wave 0 baseline 4497 ms to post-Plan-02d 3662 ms (−18.6% on Octave Linux x86_64 CI) — almost entirely from Plan 02d's in-memory prior-state cache eliminating the per-tick `load()` inside `writeTagMat_('append',...)`. Plan 06 adds a per-tick fs-stat coalescing seam that reduces `dir`/`exist` syscalls from ~2000/tick to 1/tick (−99.94%); wall-time delta on shared CI runners depends on per-syscall cost (post-CI numbers in 1028-VERIFICATION.md). All 4 active D-08 benchmark gates remain green throughout; the 5th (`bench_monitortag_tick`) remains assume-skipped per a documented pre-existing v2.0-migration bug (Plan 01 deferred-items.md).

**Plans shipped:** 6 — `01` Wave 0 harness + baseline; `02` K1 `delimited_parse_mex`; `02b` DI seam + clean NoIO measurement; `02d` in-memory prior-state cache (the big win); `05` A1+A2 listener-coalescing seam (forward-compat, null measured win — surfaced finding); `06` per-tick fs-stat coalescing + phase wrap. Plans `03` (K2 monitor_fsm_mex) and `04` (K3+K4 composite kernels) were DEFERRED per Plan 02d's tBreakdown data: their target regions bucket as 0 ms in the post-cache profile, so the kernel-swap ROI does not justify the parity-test maintenance cost.

**Kernels added:** `delimited_parse_mex` (K1; .m fallback parity per D-09 via `TestDelimitedParseParity`). K2/K3/K4 deferred per data.

**Architectural seams added:**
- `LiveTagPipeline.writeFn_` DI seam + `Hidden setWriteFnForTesting_` (Plan 02b)
- `LiveTagPipeline.priorState_` in-memory cache + `cachedWriteFn_` + `Hidden setCacheActiveForTesting_` (Plan 02d) — **the big win**
- `Tag.invalidateBatch_(tagSet)` Static helper + `getListeners_` Hidden accessor protocol + `LiveTagPipeline.onTick_` end-of-tick wiring + `Hidden setCoalesceActiveForTesting_` (Plan 05)
- `LiveTagPipeline.lookupFsEntry_` per-tick fs-stat cache + `LastFsStatCount` observability + `Hidden setFsCoalesceForTesting_` (Plan 06)

**Public API changes:** none (D-10 verified — every new property is `Access = private`; every new method is `Hidden`).

**Deferred to follow-up phase 1029:**
- In-memory propagation refactor (`processTag_` → `tag.updateData(newX,newY)`) — the BIG architectural win that makes Plan 05's A1+A2 seam *real*. Touches D-09 parity directly; significant scope.
- `containers.Map` → struct-array refactor for the per-tag state lookup. `containers.Map/subsref` + `isKey` + `subsasgn` together account for ~1 s/tick in Plan 02b's top-N profile of the NoIO `other` bucket. Pure internal change. Skipped in Plan 06 in favour of the smaller fs-stat lever.
- K2 `monitor_fsm_mex`, K3 `composite_merge_mex`, K4 `aggregate_matrix_mex` — currently bucket as 0 ms in the post-cache `tBreakdown`. If a future profile pass with direct `tic/toc` probes finds these regions >2% of the post-Plan-06 tick, they become candidates.
- `.mat` save-side optimization (periodic-checkpoint cadence, or `save -struct wrap` → direct binary writer). Plan 02d's cache eliminated the read-side; `save()` is now the dominant within-tick I/O cost at ~720 ms/tick. Separate phase (changes crash-recovery semantics).
- A3 (parallel raw-source polling via `parfeval`/threadpool) — `containers.Map` + fs-stat dominate the post-cache cost, NOT parallelism. Complexity unjustified.

**Promoted from:** Backlog 999.5 (2026-05-08)
**Decisions:** D-01..D-12 from .planning/phases/1028-tag-update-perf-mex-simd/1028-CONTEXT.md (no formal REQ-IDs for v3.x)
**Plans:** 6/6 plans executed (with 03/04 deferred per data)

Plans:
- [x] 1028-01-PLAN.md — Wave 0: 1000-tag harness + parity scaffolds + regression suite + CI wiring + baseline measurement
- [x] 1028-02-PLAN.md — Wave 1: K1 delimited_parse_mex + .m fallback dispatch
- [x] 1028-02b — Wave 1.5 (insertion, no formal PLAN.md): NoIO measurement-gap fix via DI seam (`writeFn_` private + Hidden `setWriteFnForTesting_`); clean tBreakdown shows 65% of WithIO tick is .mat I/O
- [x] 1028-02d — Wave 1.5 (insertion, no formal PLAN.md): in-memory prior-state cache eliminating per-tick `load()` inside `writeTagMat_('append',...)`; D-09 byte-equal parity (TestPriorStateCacheParity); D-10 / D-12 preserved
- [~] 1028-03-PLAN.md — DEFERRED per Plan 02d data: K2 `monitor_fsm_mex` target region bucketed as 0 ms in post-cache profile
- [~] 1028-04-PLAN.md — DEFERRED per Plan 02d data: K3 `composite_merge_mex` + K4 `aggregate_matrix_mex` target regions bucketed as 0 ms in post-cache profile
- [x] 1028-05-PLAN.md — Wave 4 (CONDITIONAL): Stage 2 architectural — A1 listener coalescing + A2 batch invalidate. Shipped as a forward-compatible seam (post-cache `other` bucket is dispatch overhead, not listener fan-out; null measured win surfaced in VERIFICATION.md)
- [x] 1028-06-PLAN.md — Wave 5: Per-tick fs-stat coalescing (1600 → 1 syscalls/tick) + phase wrap (VERIFICATION.md final, ROADMAP.md, STATE.md, SUMMARY.md)

> Note on the serial plan chain: Plans 02-06 each extend the SensorThreshold MEX block in `libs/FastSense/build_mex.m` (Plan 02 only — K2/K3/K4 deferred), append measurements to `bench_tag_pipeline_1k.m`, and write a new subsection to `1028-VERIFICATION.md`. The serial chain prevented shared-file conflicts and produced a continuous before/after data trail. Plans 03/04 are kept as `[~]` (deferred, not failed) in the list because their PLAN.md files exist on disk and remain available as a starting point for any future phase that finds direct `tic/toc` evidence of their target regions being non-trivial.

## Backlog

(empty — last 5 items promoted to phases 1024-1028 on 2026-05-08)
