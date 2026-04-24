# Roadmap: FastSense Advanced Dashboard

## Milestones

- ✅ **v1.0 FastSense Advanced Dashboard** — Phases 1-9 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Engine Code Review Fixes** — Phase 1 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Performance Optimization** — Phase 1 (shipped 2026-04-04)
- ✅ **v1.0 First-Class Thresholds & Composites** — Phases 1000-1003 (shipped 2026-04-15)
- ✅ **v2.0 Tag-Based Domain Model** — Phases 1004-1012 (shipped 2026-04-24)
- 📋 **v2.1 TBD** — run `/gsd:new-milestone` to plan

## Shipped Milestones

<details>
<summary>✅ v2.0 Tag-Based Domain Model (Phases 1004-1012) — SHIPPED 2026-04-24</summary>

- [x] Phase 1004: Tag Foundation + Golden Test (3/3 plans)
- [x] Phase 1005: SensorTag + StateTag (3/3 plans)
- [x] Phase 1006: MonitorTag lazy in-memory (3/3 plans)
- [x] Phase 1007: MonitorTag streaming + persistence (3/3 plans)
- [x] Phase 1008: CompositeTag (3/3 plans)
- [x] Phase 1009: Consumer migration (4/4 plans)
- [x] Phase 1010: Event ↔ Tag binding + FastSense overlay (3/3 plans)
- [x] Phase 1011: Cleanup — collapse parallel hierarchy + delete legacy (5/5 plans)
- [x] Phase 1012: Live event markers + click-to-details (3/3 plans)

Full details: [milestones/v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md) · Audit: [milestones/v2.0-MILESTONE-AUDIT.md](milestones/v2.0-MILESTONE-AUDIT.md)

</details>

<details>
<summary>✅ v1.0 First-Class Thresholds & Composites (Phases 1000-1003) — SHIPPED 2026-04-15</summary>

- [x] Phase 1000: Dashboard Engine Performance Optimization Phase 2 (3/3 plans)
- [x] Phase 1001: First-Class Threshold Entities (6/6 plans)
- [x] Phase 1002: Direct Widget-Threshold Binding (2/2 plans)
- [x] Phase 1003: Composite Thresholds (3/3 plans)

</details>

<details>
<summary>✅ v1.0 Dashboard Performance Optimization (Phase 1) — SHIPPED 2026-04-04</summary>

- [x] Phase 1: Dashboard Performance Optimization (3/3 plans)

Full details: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.0 Dashboard Engine Code Review Fixes (Phase 1) — SHIPPED 2026-04-03</summary>

- [x] Phase 1: Dashboard Engine Code Review Fixes (4/4 plans)

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

## Active Work

*None — v2.0 shipped. Run `/gsd:new-milestone` to plan v2.1.*

## Backlog

### Phase 999.1: Mushroom Cards for Dashboard Engine (BACKLOG)

**Goal:** Add Home Assistant-style Mushroom Card widgets to the dashboard engine — minimal, icon-driven cards with clean visual design for sensor status, controls, and quick glance data. Three new widget classes: IconCardWidget, ChipBarWidget, SparklineCardWidget, plus theme additions and full serializer/builder/detach integration.
**Plans:** 5/5 plans complete (in previous milestone; items tracked in backlog for reference)

### Phase 999.3: Graph Data Export (.mat / .csv) (BACKLOG)

**Goal:** Enable exporting any graph's underlying data as .mat or .csv files, so users can easily extract plotted data for further analysis in MATLAB or external tools.
**Plans:** 2/2 plans complete

### Carried-over tech debt from v2.0 (see [milestones/v2.0-MILESTONE-AUDIT.md](milestones/v2.0-MILESTONE-AUDIT.md))

- Phase 1011: dead `EventDetector.detect(tag, threshold)` API, DashboardSerializer `.m` export for Tag widgets, 93 `Threshold(` refs in MATLAB-only test files
- Phase 1012: dead private properties in FastSense (`PrevWBMFcn_` etc.), `formatEventFields_` back-compat footer, deferred UI surfaces (filter chips, toolbar button, animated open markers), `autoscaleY` → public widget method

Consider addressing these in v2.1 or a dedicated cleanup phase.
