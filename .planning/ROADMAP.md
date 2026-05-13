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
- 🚧 **v3.1 Plant Log Integration** — Phases 1029-1033 (started 2026-05-13)

## Phases

<details open>
<summary>🚧 v3.1 Plant Log Integration (Phases 1029-1033) — started 2026-05-13</summary>

- [x] **Phase 1029: Plant Log Storage Foundation** — `PlantLogStore` class with time-range queries and timestamp+row-hash dedup (3/3 plans complete, 2026-05-13)
- [ ] **Phase 1030: CSV/XLSX Import + Mapping Dialog** — File reader with auto-detected timestamp/message columns and a uifigure override dialog
- [ ] **Phase 1031: Live Tail + Slider Preview Overlay** — Periodic re-read timer plus black plant-log lines on the dashboard slider with hover tooltips
- [ ] **Phase 1032: Per-Widget Plant Log Overlay** — Opt-in `ShowPlantLog` toggle that draws black plant-log lines on FastSenseWidget axes with full-metadata tooltips
- [ ] **Phase 1033: Dashboard + Companion Integration & Serialization** — `attachPlantLog`/`detachPlantLog` API, JSON/.m persistence of source path and mapping, and Companion "Open Plant Log…" toolbar entry

</details>

<details>
<summary>🚧 Pending milestone (Phases 1025-1028) — promoted from backlog 2026-05-08</summary>

- [x] Phase 1024: Fix companion app dark mode — closed via quick task [260508-d7k](./quick/260508-d7k-fix-companion-app-dark-mode-switching-th/) (2026-05-08)
- [ ] Phase 1025: FastSense hover crosshair + datatip
- [ ] Phase 1026: Dashboard time slider preview
- [x] Phase 1027: Companion detachable log window — completed 2026-05-08
- [ ] Phase 1027.1: Independent events/live log detach (gap closure)
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
| 1027. Companion detachable log window | pending | 5/5 | Complete    | 2026-05-08 |
| 1027.1. Independent events/live log detach | pending | 8/8 | Complete    | 2026-05-08 |
| 1028. Tag update perf — MEX + SIMD | pending | 0/? | Not started | — |
| 1029. Plant Log Storage Foundation | v3.1 | 3/3 | Complete    | 2026-05-13 |
| 1030. CSV/XLSX Import + Mapping Dialog | v3.1 | 2/3 | In Progress|  |
| 1031. Live Tail + Slider Preview Overlay | v3.1 | 0/? | Not started | — |
| 1032. Per-Widget Plant Log Overlay | v3.1 | 0/? | Not started | — |
| 1033. Dashboard + Companion Integration & Serialization | v3.1 | 0/? | Not started | — |

## Phase Details (v3.1 Plant Log Integration)

### Phase 1029: Plant Log Storage Foundation

**Goal:** Establish a separate `PlantLogStore` data model — parallel to `EventStore` but never merged into it — that holds imported plant-log entries, dedupes by timestamp + row-content hash, and exposes time-range queries plus a count API.

**Depends on:** Nothing (foundation phase for v3.1)
**Requirements:** PLOG-ST-01, PLOG-ST-02, PLOG-ST-03, PLOG-ST-04, PLOG-ST-05
**Success Criteria** (what must be TRUE):
  1. User can construct an empty `PlantLogStore` and add entries that carry a timestamp, message text, and an arbitrary map of metadata column values; every stored entry returns its message and full metadata map on read.
  2. User can query the store by `[t0, t1]` and receive every entry whose timestamp lies in that range, and can query the total entry count independently.
  3. Re-adding rows with identical timestamp + row-content hash produces zero duplicate entries; the store's count stays stable across repeated identical adds.
  4. No code path causes a plant-log entry to appear in `EventStore.getEvents()` — `PlantLogStore` and `EventStore` are confirmed as fully independent stores in tests.
  5. `PlantLogStore:*` namespaced errors fire on invalid inputs, and pure-logic helpers (hashing, dedup, range filter) ship with unit tests that pass on both MATLAB and Octave.
**Plans:** 3/3 plans complete
- [x] 1029-01-entry-and-hash-PLAN.md — PlantLogEntry value class + djb2/computeRowHash private helpers + tests
- [x] 1029-02-store-PLAN.md — PlantLogStore handle class (reuses FastSense binary_search for ordered insert) + tests
- [x] 1029-03-install-and-smoke-PLAN.md — install.m wiring + end-to-end integration smoke test

### Phase 1030: CSV/XLSX Import + Mapping Dialog

**Goal:** Build the one-shot import pipeline — a CSV/XLSX reader that auto-detects timestamp and message columns, preserves remaining columns as metadata, and surfaces a uifigure mapping dialog with a 10-row preview so the user can override auto-detection before confirming.

**Depends on:** Phase 1029 (writes into `PlantLogStore`)
**Requirements:** PLOG-IM-01, PLOG-IM-02, PLOG-IM-03, PLOG-IM-04, PLOG-IM-05, PLOG-IM-06, PLOG-IM-07, PLOG-IM-08
**Success Criteria** (what must be TRUE):
  1. User can point the importer at a `.csv` file and have every row become a plant-log entry; on MATLAB R2020b+, user can also import a `.xlsx` file (Octave XLSX support is gated on `usejava('jvm')` + `which xlsread` and tests skip cleanly when unavailable).
  2. On import, the system auto-selects the timestamp column as the first column whose values parse cleanly as dates/times, and auto-selects the message column as the first non-timestamp text column; every other column is preserved as metadata on each entry.
  3. After auto-detection, the user sees a modal uifigure mapping dialog listing the detected timestamp column, message column, metadata columns, and a 10-row preview of the parsed result — and can override the timestamp column, message column, or explicit timestamp format string before confirming.
  4. If no parseable timestamp column is detected, the user sees a non-blocking `uialert` and the dialog blocks confirmation until they pick a valid column manually.
  5. `PlantLogReader:*` / `PlantLogImportDialog:*` namespaced errors fire on malformed inputs, all dialog callbacks are wrapped in try/catch with non-blocking `uialert`, and unit tests for the pure auto-detect helper pass on both MATLAB and Octave.
**Plans:** 2/3 plans executed
- [x] 1030-01-reader-and-helpers-PLAN.md — Private parsing/scoring helpers + PlantLogReader.readFile/autoDetect static methods + headless tests
- [x] 1030-02-import-dialog-PLAN.md — PlantLogImportDialog handle class (modal uifigure with dropdowns, format edit, preview, error label) + dialog tests
- [ ] 1030-03-open-interactive-and-smoke-PLAN.md — PlantLogReader.openInteractive wiring + integration smoke (headless + interactive + XLSX runtime check)
**UI hint**: yes

### Phase 1031: Live Tail + Slider Preview Overlay

**Goal:** Add a periodic re-read live-tail timer that appends only newly-discovered rows to the store, and render every entry in the dashboard's bottom slider preview track as a black vertical line — visually distinct from existing sev1/2/3 markers — with a hover tooltip showing timestamp + message and a `MarkerPlantLog` theme token sourcing the color.

**Depends on:** Phase 1029 (store), Phase 1030 (re-uses reader for re-reads)
**Requirements:** PLOG-LT-01, PLOG-LT-02, PLOG-LT-03, PLOG-LT-04, PLOG-LT-05, PLOG-VIZ-01, PLOG-VIZ-02, PLOG-VIZ-06, PLOG-VIZ-08, PLOG-VIZ-09
**Success Criteria** (what must be TRUE):
  1. User can enable live tail on a `PlantLogStore`, choose a re-read interval (default 5 s), and watch the slider preview gain black vertical lines as new rows appear in the source file without any duplicate entries across re-reads.
  2. When the user stops live tail (or closes the dashboard), the timer is stopped + deleted via the existing `Listeners_` + `stop(t); delete(t);` cleanup pattern; `timerfindall` shows no orphan timers and the cleanup path is exercised by tests.
  3. Whenever a `PlantLogStore` is attached to a dashboard, the bottom slider preview track shows a 1px, full-opacity black vertical line for every entry within the slider's visible range — the existing sev1/2/3 colored markers remain unchanged and the black plant-log lines are visually distinguishable from them.
  4. Hovering a plant-log line on the slider preview pops a small tooltip showing the entry's timestamp and message; new live-tail rows appear on the slider preview without a full dashboard re-render.
  5. The line color is sourced from a new theme token `MarkerPlantLog` (default black on both light and dark themes), parse errors during live-tail re-read surface via non-blocking `uialert`/`warning` without crashing the dashboard or stopping the timer, and the slider-overlay insertion path reuses the existing event-marker hook in `TimeRangeSelector` (verified against the sev1/2/3 marker code path).
**Plans:** TBD
**UI hint**: yes

### Phase 1032: Per-Widget Plant Log Overlay

**Goal:** Give every `FastSenseWidget` a `ShowPlantLog` toggle (default off) that, when enabled, draws black plant-log vertical lines on the widget's axes for entries within its current x-axis range, with a hover tooltip exposing timestamp + message + every metadata column value, and a button-bar icon to toggle the overlay per widget.

**Depends on:** Phase 1029 (store), Phase 1031 (live-refresh contract + theme token)
**Requirements:** PLOG-VIZ-03, PLOG-VIZ-04, PLOG-VIZ-05, PLOG-VIZ-07
**Success Criteria** (what must be TRUE):
  1. Every `FastSenseWidget` exposes a `ShowPlantLog` boolean property that defaults to `false`; existing dashboards continue to render with no plant-log lines on any widget unless the user opts in.
  2. When a `PlantLogStore` is attached to the dashboard and a widget's `ShowPlantLog` is `true`, the widget's axes show a black vertical line at each entry timestamp within the widget's current x-axis range — color is sourced from the same `MarkerPlantLog` theme token introduced in Phase 1031.
  3. User can toggle `ShowPlantLog` per widget via an icon button in the widget button bar; the overlay appears or disappears immediately on toggle.
  4. Hovering a plant-log line on a widget pops a small tooltip showing the entry's timestamp, message, and every metadata column value; new live-tail rows appear on every `ShowPlantLog=true` widget without a full re-render (extending the Phase 1031 refresh contract to widget overlays).
  5. The widget-overlay insertion path reuses the existing tag-bound event-marker hook in `FastSenseWidget` (verified against the existing event-marker draw path) and the icon-button callback is wrapped in try/catch with non-blocking `uialert`.
**Plans:** TBD
**UI hint**: yes

### Phase 1033: Dashboard + Companion Integration & Serialization

**Goal:** Wire plant logs into the dashboard and Companion as a first-class feature — `DashboardEngine.attachPlantLog(path, opts)` / `detachPlantLog()`, JSON and `.m` serialization of source path + column mapping + live-tail interval + per-widget `ShowPlantLog`, re-import on load, and a `FastSenseCompanion` toolbar "Open Plant Log…" entry that attaches to every managed dashboard.

**Depends on:** Phase 1029 (store), Phase 1030 (importer), Phase 1031 (slider overlay + live tail), Phase 1032 (widget overlay)
**Requirements:** PLOG-INT-01, PLOG-INT-02, PLOG-INT-03, PLOG-INT-04, PLOG-INT-05
**Success Criteria** (what must be TRUE):
  1. User can call `engine.attachPlantLog(filePath, opts)` and immediately see the slider preview black-line overlay activate on that dashboard; `engine.detachPlantLog()` removes all slider and widget overlays and cleanly stops any active live tail (timer stopped + deleted, no orphans in `timerfindall`).
  2. User can click `FastSenseCompanion`'s toolbar "Open Plant Log…" entry, pick a file in the resulting dialog, and have the resulting `PlantLogStore` attach to every open `DashboardEngine` instance the Companion is managing.
  3. Saving a dashboard via `DashboardSerializer` (both JSON and `.m` export) writes the plant-log source path, the column mapping (timestamp/message/metadata + explicit format if overridden), the live-tail interval, and each widget's `ShowPlantLog` flag — but does NOT serialize the imported entries themselves.
  4. Loading a serialized dashboard re-imports the plant log from the saved source path using the saved column mapping, restores each widget's `ShowPlantLog` state, and the slider overlay reappears with the freshly-imported entries; existing v1.0–v3.0 serialized dashboards (with no plant-log section) continue to load without error.
  5. All new public APIs raise `PlantLogStore:*` / `PlantLogReader:*` namespaced errors on invalid inputs, every Companion toolbar callback is wrapped in try/catch with non-blocking `uialert`, and the round-trip "attach → save → load → re-attach" path is covered by tests that pass on both MATLAB and Octave (with XLSX gated where necessary).
**Plans:** TBD
**UI hint**: yes

## Backlog

(empty — last 5 items promoted to phases 1024-1028 on 2026-05-08)
