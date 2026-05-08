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
- [ ] Phase 1027: Companion detachable log window
- [ ] Phase 1028: Tag update perf — MEX + SIMD

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
| 1027. Companion detachable log window | pending | 0/? | Not started | — |
| 1028. Tag update perf — MEX + SIMD | pending | 2/6 | In Progress|  |

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

**Goal:** In the FastSense Companion app, make the log panel detachable into its own draggable, resizable window — same pop-out pattern as detachable widgets in the main dashboard.

**Promoted from:** Backlog 999.4 (2026-05-08)
**Requirements:** TBD
**Plans:** 0 plans

### Phase 1028: Tag update perf — MEX + SIMD

**Goal:** Profile and accelerate the tag update path at the 1000-tag × N-source × 1-session workload anchor (CONTEXT.md D-01). Land MEX kernels (K1 delimited_parse, K2 monitor_fsm, K3 composite_merge, K4 aggregate_matrix) behind transparent .m fallback dispatch (D-09), and conditionally land Stage 2 architectural seams (A1+A2 listener coalescing) gated on Stage-1 measurement (D-05). All 5 existing benchmark gates remain green throughout (D-08); no public API changes (D-10); DerivedTag.UserFn untouched (D-11); .mat write cadence unchanged (D-12).

**Promoted from:** Backlog 999.5 (2026-05-08)
**Decisions:** D-01..D-12 from .planning/phases/1028-tag-update-perf-mex-simd/1028-CONTEXT.md (no formal REQ-IDs for v3.x)
**Plans:** 2/6 plans executed

Plans:
- [x] 1028-01-PLAN.md — Wave 0: 1000-tag harness + parity scaffolds + regression suite + CI wiring + baseline measurement
- [x] 1028-02-PLAN.md — Wave 1: K1 delimited_parse_mex + .m fallback dispatch
- [ ] 1028-03-PLAN.md — Wave 2: K2 monitor_fsm_mex (fused hysteresis+debounce+findRuns) + .m fallback
- [ ] 1028-04-PLAN.md — Wave 3: K3 composite_merge_mex + K4 aggregate_matrix_mex (6 structural modes) + fallbacks
- [ ] 1028-05-PLAN.md — Wave 4 (CONDITIONAL): Stage 2 architectural — A1 listener coalescing + A2 batch invalidate, gated on Stage-1 measurement
- [ ] 1028-06-PLAN.md — Wave 5: Phase wrap — finalize VERIFICATION.md, update ROADMAP.md + STATE.md

> Plans 02-06 are serialized: each Wave-N plan extends the SensorThreshold MEX block in `libs/FastSense/build_mex.m`, appends measurements to `bench_tag_pipeline_1k.m`, and writes a new subsection to `1028-VERIFICATION.md`. The serial chain prevents shared-file conflicts and naturally flows each plan's `tickMin` into the next plan's Δ-vs-previous table.

## Backlog

(empty — last 5 items promoted to phases 1024-1028 on 2026-05-08)
