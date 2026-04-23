# Roadmap: FastSense Advanced Dashboard

## Milestones

- ✅ **v1.0 FastSense Advanced Dashboard** — Phases 1–9 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Engine Code Review Fixes** — Phase 1 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Performance Optimization** — Phase 1 (shipped 2026-04-04)
- ✅ **v1.0 First-Class Thresholds & Composites** — Phases 1000–1003 (shipped 2026-04-15)
- ✅ **v2.0 Tag-Based Domain Model** — Phases 1004–1011 + 999.1 / 999.3 / 1004 Image Export / 1006 MATLAB CI Fixes / 1012 Tag Pipeline / 1013 Prebuilt MEX (shipped 2026-04-23)

## Phases

<details>
<summary>✅ v1.0 FastSense Advanced Dashboard (Phases 1–9) — SHIPPED 2026-04-03</summary>

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

<details>
<summary>✅ v1.0 First-Class Thresholds & Composites (Phases 1000–1003) — SHIPPED 2026-04-15</summary>

- [x] Phase 1000: Dashboard Engine Performance Optimization Phase 2 (3/3 plans)
- [x] Phase 1001: First-Class Threshold Entities (6/6 plans)
- [x] Phase 1002: Direct Widget-Threshold Binding (2/2 plans)
- [x] Phase 1003: Composite Thresholds (3/3 plans)

</details>

<details>
<summary>✅ v2.0 Tag-Based Domain Model — SHIPPED 2026-04-23</summary>

**Original Tag rewrite (Phases 1004–1011, 2026-04-16 → 2026-04-17):**

- [x] Phase 1004: Tag Foundation + Golden Test (3/3 plans)
- [x] Phase 1005: SensorTag + StateTag (3/3 plans)
- [x] Phase 1006: MonitorTag (lazy, in-memory) (3/3 plans)
- [x] Phase 1007: MonitorTag streaming + persistence (3/3 plans)
- [x] Phase 1008: CompositeTag (3/3 plans)
- [x] Phase 1009: Consumer migration (4/4 plans)
- [x] Phase 1010: Event ↔ Tag binding + FastSense overlay (3/3 plans)
- [x] Phase 1011: Cleanup — delete legacy hierarchy (5/5 plans)

**Post-audit additions (2026-04-17 → 2026-04-23):**

- [x] Phase 999.1: Mushroom Cards for Dashboard Engine (4/4 plans)
- [x] Phase 999.3: Graph Data Export (.mat / .csv) (2/2 plans)
- [x] Phase 1004: Dashboard Image Export Button (3/3 plans) *(numbering collision with Tag Foundation — different phase)*
- [x] Phase 1006: Fix 137 MATLAB test failures from R2025b drift (4/4 plans) *(numbering collision with MonitorTag — different phase)*
- [x] Phase 1012: Tag Pipeline — raw files → per-tag .mat (5/5 plans)
- [x] Phase 1013: Ship prebuilt MEX binaries for macOS/Windows/Linux (7/7 plans, incl. gap closure 1013-07)

Full details: [milestones/v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md)

**Known gaps at ship time** (carried to next milestone as tech debt):

- Phase 1013 HUMAN-UAT: 3 items pending (MATLAB fresh-clone install, Windows/Linux install after `refresh-mex-binaries.yml` first run)
- v2.0 audit tech debt: `EventDetector.detect(tag, threshold)` dead code; `DashboardSerializer` `.m` export missing `source.type='tag'`; 93 `Threshold(` constructor refs in 42 MATLAB-only test files
- Phase 1005 (CI coverage expansion — MATLAB+Octave tests on macOS/Windows, MATLAB benchmark) was never planned; partially superseded by Phase 1006 (MATLAB R2020b pinning + 137 test fixes) and Phase 1013 (prebuilt MEX binaries). Remaining work: full test suite execution on non-Linux CI runners.
- 4 pre-existing unresolved debug sessions (CI / test investigations)

</details>

## Progress

| Milestone | Phases | Plans | Status | Completed |
|-----------|--------|-------|--------|-----------|
| v1.0 Advanced Dashboard | 1–9 | 24/24 | ✓ Shipped | 2026-04-03 |
| v1.0 Code Review Fixes | 1 | 4/4 | ✓ Shipped | 2026-04-03 |
| v1.0 Performance Optimization | 1 | 3/3 | ✓ Shipped | 2026-04-04 |
| v1.0 First-Class Thresholds | 1000–1003 | 14/14 | ✓ Shipped | 2026-04-15 |
| v2.0 Tag-Based Domain Model | 1004–1013 + 999.x | 46/46 | ✓ Shipped | 2026-04-23 |

## Next

Start the next milestone with `/gsd:new-milestone` — requirements gathering → research → roadmap.

Candidate directions surfaced during v2.0:
- Asset hierarchy (Asset tree, templates, tag-to-asset binding, browse rollups)
- Custom event GUI (click-drag region selection in FastSense → label dialog)
- Calc tags / formula evaluator for arbitrary derived tags
- Tri-state / continuous severity MonitorTag output
- WebBridge parity for Tag API features
- v2.0 tech debt cleanup (EventDetector dead code, `.m` export tag support, test-file modernization)
- CI coverage expansion (Phase 1005 carryover)
