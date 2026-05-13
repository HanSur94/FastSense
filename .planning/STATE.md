---
gsd_state_version: 1.0
milestone: v3.1
milestone_name: Plant Log Integration
status: executing
last_updated: "2026-05-13T21:08:27.874Z"
last_activity: 2026-05-13
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 3
  completed_plans: 2
---

# State

## Project Reference

See: .planning/PROJECT.md (created 2026-05-13)

**Core value:** Engineers can render millions of sensor points smoothly, organize
them into navigable dashboards, and surface anomalies — all in pure MATLAB with no
toolbox dependencies.
**Current focus:** Phase 1029 — Plant Log Storage Foundation

## Current Position

Phase: 1029 (Plant Log Storage Foundation) — EXECUTING
Plan: 3 of 3
Milestone: v3.1 Plant Log Integration
Status: Plan 02 complete, ready for Plan 03 (install.m wiring + integration smoke)
Last activity: 2026-05-13 -- Plan 1029-02 (store) complete

## Progress Bar

v3.1 Plant Log Integration:

- [ ] Phase 1029: Plant Log Storage Foundation — 2/3 plans
- [ ] Phase 1030: CSV/XLSX Import + Mapping Dialog — 0/? plans
- [ ] Phase 1031: Live Tail + Slider Preview Overlay — 0/? plans
- [ ] Phase 1032: Per-Widget Plant Log Overlay — 0/? plans
- [ ] Phase 1033: Dashboard + Companion Integration & Serialization — 0/? plans

Phases complete: 0/5
Plans complete: 2/3 (67%) in Phase 1029

## Accumulated Context

### Roadmap Evolution

- 2026-04-29 — Milestone v3.0 FastSense Companion started (programmatic MATLAB
  uifigure companion app)

- 2026-04-30 — v3.0 SHIPPED at phase 1023.1
- 2026-05-08 — Five floating phases (1024–1028) promoted from backlog into a
  "Pending milestone" bucket; most closed via quick tasks over the following days

- 2026-05-13 — Milestone v3.1 Plant Log Integration started; phases start at 1029
  to avoid collision with floating phase 1028 (Tag update perf, still open)

- 2026-05-13 — v3.1 roadmap defined: 5 phases (1029–1033), 32 PLOG-* requirements
  mapped to phases, no orphans

### Brainstorm Outcomes (v3.1)

Design decisions locked during the v3.1 milestone scoping conversation (2026-05-13):

- **File formats:** CSV and Excel (XLSX). Other formats deferred.
- **Visual style:** Plant-log entries always render as **black vertical lines** on
  the slider preview and on opt-in FastSenseWidgets. Visually distinct from the
  existing sev1/2/3 colored event markers (green/orange/red).

- **Storage:** Separate `PlantLogStore` class, parallel to `EventStore`. **Not**
  merged into `EventStore` — preserves clean separation from auto-detected events.

- **Ingest:** One-shot import + live tail. Live tail re-reads the source file on a
  timer and appends only new rows.

- **Dedup:** Timestamp + row-hash. Safe under append, prepend, file rotation.
- **Column mapping:** Auto-detect timestamp column (parses dates) + message column
  (first non-timestamp text column); remaining columns become metadata. User can
  override via a uifigure mapping dialog at import time.

- **Slider preview:** Always shows plant-log lines (black) when a `PlantLogStore`
  is attached to the dashboard.

- **Widget overlay:** Per-`FastSenseWidget` `ShowPlantLog` boolean property,
  default `false`. When `true`, the widget draws black vertical lines on its axes
  for every entry in its current time range.

- **Hover tooltip:** Hovering a plant-log line shows a small datatip with
  timestamp + message + metadata columns. Works on both slider and widget overlays.

- **Dashboard integration:** `DashboardEngine.attachPlantLog(path, opts)` /
  `detachPlantLog()` / `PlantLogStore` property. Serialization saves source path

  + column mapping (NOT the imported data — re-imported from source on load).
- **Companion integration:** `FastSenseCompanion` toolbar gains an "Open Plant
  Log…" entry that imports a file and attaches to all open dashboards.

### Cross-Cutting Engineering Constraints (v3.1)

These apply to every phase and are reflected in phase success criteria rather than
separate REQ-IDs:

- Live-tail timer follows the existing pattern: `Listeners_` cell + `stop(t); delete(t);` in
  cleanup; never `kill(t)`. CloseRequestFcn safe.

- Errors namespaced `PlantLogStore:*` / `PlantLogReader:*` / `PlantLogImportDialog:*`
- Every callback wrapped in try/catch + non-blocking `uialert` (or `warning` for
  non-uifigure contexts)

- MATLAB + Octave compatibility — Octave's `readtable` reads CSV but not XLSX;
  XLSX path may be MATLAB-only and tests gated on `usejava('jvm')` + `which xlsread`

- Theme-aware: black line color comes from the theme's `MarkerPlantLog` token
  (added in v3.1) so dark theme can override if needed — default black on both
  themes

- Pure-logic helpers (`parsePlantLog_`, `dedupEntries_`, column auto-detect) ship
  with unit tests

### Research Flags for Planning

- **Phase 1029 planning:** Read `libs/EventDetection/EventStore.m` and
  `libs/EventDetection/Event.m` to mirror the `EventStore` shape (constructor,
  add/query/count API) into `PlantLogStore` without coupling them.

- **Phase 1030 planning:** Run a 20-line scratch test of `readtable` against an
  XLSX file in headless MATLAB + Octave to confirm XLSX availability per
  platform/runtime. Determines whether XLSX support is MATLAB-only (then Octave
  tests gated) or fully cross-runtime.

- **Phase 1031 planning:** Read `libs/Dashboard/TimeRangeSelector.m` to confirm
  the exact hook point used by the existing event-marker overlay (sev1/2/3) —
  reuse the same insertion path to avoid disturbing the slider preview pipeline.
  Also read `libs/EventDetection/LiveEventPipeline.m` for the timer + cleanup
  precedent (`Listeners_` + `stop(t); delete(t);`).

- **Phase 1032 planning:** Read `libs/Dashboard/FastSenseWidget.m` to confirm
  where the existing tag-bound event markers are drawn on the widget axes;
  plant-log overlay should integrate at the same point with a different color +
  hover behavior. Read `libs/FastSense/FastSenseToolbar.m` for the widget
  button-bar icon-button precedent.

- **Phase 1033 planning:** Read `libs/Dashboard/DashboardSerializer.m` for the
  JSON + `.m` export hook points, and `libs/FastSenseCompanion/FastSenseCompanion.m`
  for the toolbar entry + multi-dashboard fan-out pattern.

### Carry-Forward (independent of v3.1)

- **v2.1 Tag-API Tech Debt Cleanup** — phases 1012–1017 (in flight, not blocking)
- **Floating phase 1028** — Tag update perf (MEX + SIMD); not started, not part of v3.1

## Session Continuity

- **Resume point:** Phase 1029 — Plan 03 `install.m wiring + integration smoke`.
  `PlantLogEntry`, the private hash helpers (`djb2Hash`, `computeRowHash`), and
  `PlantLogStore` are all available under `libs/PlantLog/`. Run
  `/gsd:execute-phase 1029` (or directly execute `1029-03-install-and-smoke-PLAN.md`)
  to wire the library directory into the global `install.m` path loop and to
  add the end-to-end integration smoke test that exercises the full pipeline
  without explicit `addpath` helpers.

- **Order of phases:** 1029 → 1030 → 1031 → 1032 → 1033 (each phase depends on
  prior phases; no parallel execution paths).

- **Coverage:** 32/32 active PLOG-* requirements mapped to phases — verified
  during roadmap creation.

- **Stopped at:** 2026-05-13 -- Completed 1029-02-store-PLAN.md (PlantLogStore
  handle class + cross-runtime tests; 21/21 PASS on both MATLAB and Octave).
  Plan 03 (install.m wiring + integration smoke) next.

## Decisions Log

### Phase 1029 — Plant Log Storage Foundation

- **Plan 01 (entry + hash, 2026-05-13)** — djb2 hash uses `lo32/hi32` split + double-precision
  intermediates so MATLAB (saturating uint64) and Octave (wrapping uint64) produce
  bit-identical 16-char lowercase hex. `PlantLogEntry` is a value class (no `< handle`)
  with `SetAccess = private` on every property; ID assignment uses `withId(newId)` which
  returns a copy. Metadata fields are sorted by fieldname and joined by `char(31)`
  before hashing — field-order-independent dedup contract that downstream phases
  (1030 import, 1031 live tail, 1033 serializer) rely on. Private hash helpers are
  tested indirectly via `PlantLogEntry.RowHash` because functions under `libs/PlantLog/private/`
  cannot be called from `tests/`. See `.planning/phases/1029-plant-log-storage-foundation/1029-01-entry-and-hash-SUMMARY.md`.

- **Plan 02 (store, 2026-05-13)** — `PlantLogStore` handle class reuses
  `libs/FastSense/binary_search.m` for the ordered-insert position lookup
  (`'left'` direction) and for the inclusive range-query bounds in
  `getEntriesInRange` (`'left'` for lo, `'right'` for hi); no new
  `binarySearchInsert.m` helper was added. Silent dedup on the composite key
  `(Timestamp, RowHash)` via a Timestamp-pre-filtered linear scan (O(k)
  effective for plant-log volumes); `nextId_` is `uint64` and advances only
  after the dedup check passes so re-adding identical sets does not burn ids.
  Static `PlantLogStore.computeEntryHash(message, metadata)` exposes the
  hash entry point for tests and the Phase 1030 reader. Cross-runtime fix:
  switched private `entries_` default from `PlantLogEntry.empty` to `[]`
  because Octave does not implement classdef `.empty`; every `[obj.entries_.Timestamp]`
  expression is already guarded by `isempty(obj.entries_)`. Independence from
  EventStore is enforced at the file level — zero code-level constructor calls
  or method invocations to `Event*`, only doc-comment mentions; verified by
  three relaxed-regex grep acceptance checks plus an explicit runtime test
  (`test_independence_from_event_store` / `testIndependenceFromEventStore`).
  21/21 function-style + 21/21 class-based tests PASS on MATLAB; 21/21
  function-style PASS on Octave. See
  `.planning/phases/1029-plant-log-storage-foundation/1029-02-store-SUMMARY.md`.
