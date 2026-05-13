---
gsd_state_version: 1.0
milestone: v3.1
milestone_name: Plant Log Integration
status: executing
stopped_at: Completed 1030-01-reader-and-helpers-PLAN.md
last_updated: "2026-05-13T22:13:36.070Z"
last_activity: 2026-05-13
progress:
  total_phases: 5
  completed_phases: 1
  total_plans: 6
  completed_plans: 4
---

# State

## Project Reference

See: .planning/PROJECT.md (created 2026-05-13)

**Core value:** Engineers can render millions of sensor points smoothly, organize
them into navigable dashboards, and surface anomalies — all in pure MATLAB with no
toolbox dependencies.
**Current focus:** Phase 1030 — CSV/XLSX Import + Mapping Dialog

## Current Position

Phase: 1030 (CSV/XLSX Import + Mapping Dialog) — EXECUTING
Plan: 2 of 3
Milestone: v3.1 Plant Log Integration
Status: Ready to execute
Last activity: 2026-05-14 -- Plan 1030-01 (reader + helpers) shipped; PlantLogReader headless API live; 25/25 tests PASS on MATLAB

## Progress Bar

v3.1 Plant Log Integration:

- [x] Phase 1029: Plant Log Storage Foundation — 3/3 plans
- [ ] Phase 1030: CSV/XLSX Import + Mapping Dialog — 1/3 plans
- [ ] Phase 1031: Live Tail + Slider Preview Overlay — 0/? plans
- [ ] Phase 1032: Per-Widget Plant Log Overlay — 0/? plans
- [ ] Phase 1033: Dashboard + Companion Integration & Serialization — 0/? plans

Phases complete: 1/5
Plans complete: 1/3 (33%) in Phase 1030

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

- **Resume point:** Phase 1029 is **closed**. Next step: run `/gsd:verify-phase 1029`
  to confirm every PLOG-ST-* requirement has matching test evidence, then
  `/gsd:start-phase 1030` to begin the CSV/XLSX importer (which will consume
  `PlantLogStore.computeEntryHash` and `PlantLogStore.addEntries` directly).

- **Order of phases:** 1029 ✅ → 1030 → 1031 → 1032 → 1033 (each phase depends on
  prior phases; no parallel execution paths).

- **Coverage:** 32/32 active PLOG-* requirements mapped to phases — verified
  during roadmap creation. PLOG-ST-01..05 (5/32) have unit + integration
  proof (Phase 1029); PLOG-IM-01..05 (10/32) have headless-reader proof
  (Phase 1030 Plan 01). 22 requirements remaining across Phases 1030
  Plans 02 + 03, 1031, 1032, 1033.

- **Stopped at:** Completed 1030-01-reader-and-helpers-PLAN.md.
  PlantLogReader headless API now ships (static `readFile` +
  `autoDetect`); 5 private helpers under `libs/PlantLog/private/` cover
  the 7-format timestamp ladder, scoring, sanitization, and portable
  readtable. 15/15 function-style + 10/10 class-based tests PASS on
  MATLAB; checkcode clean on all 8 new files. Plan 1030-02 (import
  dialog) is now unblocked; the dialog will consume `autoDetect` output
  to pre-fill its dropdowns and produce a mapping struct that
  `PlantLogReader.readFile` parses on Confirm.

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

- **Plan 03 (install + smoke, 2026-05-13)** — Wired `libs/PlantLog/` into
  `install.m` with a two-line edit: one documentation entry under the
  "Directories added" comment block (line 25), one `addpath(fullfile(root,
  'libs', 'PlantLog'))` in the libs-block (line 59), both directly after the
  FastSenseCompanion entries. `verify_installation` was deliberately NOT
  expanded with PlantLogStore (locked decision) — the integration smoke owns
  the `which('PlantLogStore')` verification, which is hard-failure semantics
  vs. the warning-only semantics of `verify_installation`'s `core_classes`.
  Shipped `tests/test_plant_log_integration_smoke.m` (9 assertions in one
  flow) and `tests/suite/TestPlantLogIntegrationSmoke.m` (7 Test methods) —
  both deliberately omit any manual `addpath(fullfile(..., 'libs', 'PlantLog'))`
  so a regression to the install.m edit fails fast at the very first `which()`
  assertion. Phase 1029 closure: 44/44 class-based tests + 47/47
  function-style assertions green on MATLAB; 47/47 function-style assertions
  green on Octave. All 5 PLOG-ST-* requirements integration-proven (multiple
  distinct test paths each). See
  `.planning/phases/1029-plant-log-storage-foundation/1029-03-install-and-smoke-SUMMARY.md`.

### Phase 1030 — CSV/XLSX Import + Mapping Dialog

- **Plan 01 (reader + helpers, 2026-05-14)** — Shipped `PlantLogReader`
  handle class (`libs/PlantLog/PlantLogReader.m`) with static `readFile`
  (headless CSV/XLSX -> `PlantLogEntry[]`) and `autoDetect` (column scoring
  -> mapping struct) methods. Five private helpers under
  `libs/PlantLog/private/`: `parseTimestampLadder.m` (7-format ladder
  handling cell/char/string/numeric/datetime inputs), `scoreColumnAsTimestamp.m`,
  `scoreColumnAsMessage.m`, `sanitizeFieldName.m` (cross-runtime
  `matlab.lang.makeValidName` wrapper), and `readtablePortable.m` (CSV+XLSX
  dispatcher with Octave xlsx gating). Auto-detect thresholds locked at
  parse-ratio >= 0.9 (timestamp) and text-ness >= 0.7 (message); the
  scorers expose raw ratios so callers can re-use them. Error namespace
  `PlantLogReader:fileNotFound / unsupportedFormat / xlsxUnavailable /
  invalidInput / unknownColumn / readError`. Auto-fixed during execution:
  (1) added `datetime` input branch to parser because MATLAB readtable
  auto-promotes ISO timestamps; (2) tightened numeric-datenum sanity gate
  to values > 1e5 so integer count columns aren't misclassified as
  timestamps; (3) quoted timestamp values in `yyyy/MM/dd` test fixture
  because readtable was auto-splitting on '/'; (4) stripped no-longer-emitted
  `%#ok<NASGU>` suppressions. 15/15 function-style + 10/10 class-based
  tests PASS on MATLAB; checkcode reports clean on all 8 new files; zero
  edits to existing files. PLOG-IM-01..05 completed. See
  `.planning/phases/1030-csv-xlsx-import-mapping-dialog/1030-01-reader-and-helpers-SUMMARY.md`.
