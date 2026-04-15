# Roadmap: FastSense Advanced Dashboard

## Milestones

- ✅ **v1.0 FastSense Advanced Dashboard** — Phases 1-9 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Engine Code Review Fixes** — Phase 1 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Performance Optimization** — Phase 1 (shipped 2026-04-04)

## Phases

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
<summary>✅ v1.0 Dashboard Engine Code Review Fixes (Phase 1) — SHIPPED 2026-04-03</summary>

- [x] Phase 1: Dashboard Engine Code Review Fixes (4/4 plans) — completed 2026-04-03

</details>

<details>
<summary>✅ v1.0 Dashboard Performance Optimization (Phase 1) — SHIPPED 2026-04-04</summary>

- [x] Phase 1: Dashboard Performance Optimization (3/3 plans) — completed 2026-04-04

Full details: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-9 | v1.0 Advanced Dashboard | 24/24 | Complete | 2026-04-03 |
| 01. Code Review Fixes | v1.0 Code Review | 4/4 | Complete | 2026-04-03 |
| 01. Performance Optimization | v1.0 Performance | 3/3 | Complete | 2026-04-04 |

## Backlog

### Phase 999.1: Mushroom Cards for Dashboard Engine (BACKLOG)

**Goal:** Add Home Assistant-style Mushroom Card widgets to the dashboard engine — minimal, icon-driven cards with clean visual design for sensor status, controls, and quick glance data. Three new widget classes: IconCardWidget, ChipBarWidget, SparklineCardWidget, plus theme additions and full serializer/builder/detach integration.
**Requirements:** [MUSH-01: DashboardTheme InfoColor, MUSH-02: IconCardWidget, MUSH-03: ChipBarWidget, MUSH-04: SparklineCardWidget, MUSH-05: DashboardEngine type registration, MUSH-06: DashboardSerializer integration, MUSH-07: DetachedMirror + DashboardBuilder integration]
**Plans:** 4/4 plans complete

Plans:
- [ ] 999.1-01-PLAN.md — DashboardTheme InfoColor + IconCardWidget implementation
- [ ] 999.1-02-PLAN.md — ChipBarWidget implementation
- [ ] 999.1-03-PLAN.md — SparklineCardWidget implementation
- [x] 999.1-04-PLAN.md — Infrastructure wiring (Engine, Serializer, DetachedMirror, Builder)

### Phase 999.3: Graph Data Export (.mat / .csv) (BACKLOG)

**Goal:** Enable exporting any graph's underlying data as .mat or .csv files, so users can easily extract plotted data for further analysis in MATLAB or external tools.
**Requirements:** [EXPORT-01: CSV export with time + Y columns, EXPORT-02: MAT export with lines + thresholds structs, EXPORT-03: NaN-filled union for mismatched X arrays, EXPORT-04: Datetime ISO 8601 + datenum columns, EXPORT-05: Toolbar Export Data button, EXPORT-06: Empty plot error guard]
**Plans:** 2/2 plans complete

Plans:
- [x] 999.3-01-PLAN.md — Core exportData method + private helpers + tests
- [x] 999.3-02-PLAN.md — Toolbar button, icon, callbacks + test updates

### Phase 1000: Dashboard Engine Performance Optimization Phase 2

**Goal:** Fix 6 identified performance bottlenecks in DashboardEngine: (1) FastSenseWidget.refresh() full teardown → incremental update reusing axes/FastSense, (2) broadcastTimeRange synchronous slider → debounced/coalesced updates, (3) All-page panel creation at startup → lazy page realization on first switchPage(), (4) getTimeRange full-array scan per widget per tick → cached min/max with incremental update, (5) switchPage synchronous realize → batched with drawnow, (6) Resize marks all dirty → debounced resize without dirty marking. Goal: 10-50x faster live ticks, 2-5x faster startup, smooth slider interactivity.
**Requirements**: [PERF2-01: Incremental FastSenseWidget refresh, PERF2-02: Debounced time slider broadcast, PERF2-03: Lazy page panel realization, PERF2-04: Cached widget time ranges, PERF2-05: Batched switchPage realize, PERF2-06: Debounced resize without dirty]
**Depends on:** None
**Plans:** 3/3 plans complete

Plans:
- [x] 1000-01-PLAN.md — Incremental FastSenseWidget refresh + cached time ranges
- [x] 1000-02-PLAN.md — Debounced slider broadcast + resize without dirty marking
- [ ] 1000-03-PLAN.md — Lazy page panel realization + batched switchPage realize

### Phase 1001: First-Class Threshold Entities

**Goal:** Make thresholds independent, reusable entities with ThresholdRegistry and shared-reference semantics (TrendMiner-style). Breaking change: replace ThresholdRules/addThresholdRule with Threshold handle class + addThreshold across all libraries.
**Requirements**: [THR-01: Threshold handle class, THR-02: ThresholdRegistry singleton, THR-03: Sensor integration (addThreshold/removeThreshold), THR-04: Resolve adaptation, THR-05: Downstream consumer migration, THR-06: Test migration]
**Depends on:** Phase 1000
**Plans:** 6/6 plans complete

Plans:
- [x] 1001-01-PLAN.md — Threshold handle class + ThresholdRegistry singleton + tests
- [x] 1001-02-PLAN.md — Sensor.m refactor (Thresholds property, addThreshold, resolve adaptation) + sensor test migration
- [x] 1001-03-PLAN.md — Dashboard widgets, SensorRegistry display, loadModuleMetadata migration + widget tests
- [x] 1001-04-PLAN.md — EventDetection migration (IncrementalEventDetector, LiveEventPipeline, EventViewer) + EventDetection tests
- [x] 1001-05-PLAN.md — Gap closure: migrate 10 core sensor + consumer widget test files from addThresholdRule
- [x] 1001-06-PLAN.md — Gap closure: migrate 5 EventDetection test files from addThresholdRule

### Phase 1002: Direct Widget-Threshold Binding — StatusWidget, GaugeWidget, and other widgets can reference Threshold objects directly without requiring a Sensor. Enables standalone threshold-driven status indicators.

**Goal:** Add Threshold + Value/ValueFcn properties to StatusWidget, GaugeWidget, IconCardWidget, MultiStatusWidget, and ChipBarWidget so they can display threshold-driven status without requiring a Sensor object. Purely additive — existing Sensor-bound behavior unchanged.
**Requirements**: [THRBIND-01: StatusWidget + GaugeWidget threshold binding, THRBIND-02: IconCardWidget + MultiStatusWidget + ChipBarWidget threshold binding, THRBIND-03: Serialization round-trip for threshold-bound widgets, THRBIND-04: Backward compatibility, THRBIND-05: ValueFcn live tick support]
**Depends on:** Phase 1001
**Plans:** 2/2 plans complete

Plans:
- [x] 1002-01-PLAN.md — StatusWidget + GaugeWidget threshold binding + serialization + tests
- [ ] 1002-02-PLAN.md — IconCardWidget + MultiStatusWidget + ChipBarWidget threshold binding + serialization + tests

### Phase 1003: Composite Thresholds — CompositeThreshold class that aggregates child Threshold objects for hierarchical status. Component A is green only if children A.A and A.B are both green. Enables system health trees and nested status monitoring.

**Goal:** Create CompositeThreshold class that aggregates child Threshold objects with AND/OR/MAJORITY logic for hierarchical system health monitoring. Wire into all dashboard widgets (StatusWidget, GaugeWidget, IconCardWidget, MultiStatusWidget) with isa-guards and auto-expansion. Add serialization for save/load persistence.
**Requirements**: [COMP-01: CompositeThreshold inherits Threshold, COMP-02: AND/OR/MAJORITY aggregation, COMP-03: Nested composites, COMP-04: computeStatus method, COMP-05: addChild dual-input, COMP-06: Per-child ValueFcn/Value, COMP-07: Shared handle references, COMP-08: MultiStatusWidget expansion, COMP-09: ThresholdRegistry + serialization]
**Depends on:** Phase 1002
**Plans:** 3/3 plans complete

Plans:
- [x] 1003-01-PLAN.md — CompositeThreshold class + TDD test suite (AND/OR/MAJORITY, addChild, computeStatus, nesting)
- [x] 1003-02-PLAN.md — Widget isa-guards (StatusWidget, GaugeWidget, IconCardWidget) + MultiStatusWidget composite expansion
- [x] 1003-03-PLAN.md — CompositeThreshold toStruct/fromStruct serialization + round-trip tests

### Phase 1004: Dashboard Image Export Button

**Goal:** Add an image export button to the dashboard toolbar that captures the entire dashboard layout as a single image (PNG/JPEG), enabling users to share or document their dashboard state with one click.
**Requirements**: TBD
**Depends on:** Phase 1003
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd:discuss-phase 1004 to scope requirements, then /gsd:plan-phase 1004 to break down)
