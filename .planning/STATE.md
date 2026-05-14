---
gsd_state_version: 1.0
milestone: v3.1
milestone_name: Plant Log Integration
status: verifying
stopped_at: Completed 1031-03-hover-tooltip-and-smoke-PLAN.md
last_updated: "2026-05-14T13:09:20.069Z"
last_activity: 2026-05-14
progress:
  total_phases: 5
  completed_phases: 3
  total_plans: 9
  completed_plans: 9
---

# State

## Project Reference

See: .planning/PROJECT.md (created 2026-05-13)

**Core value:** Engineers can render millions of sensor points smoothly, organize
them into navigable dashboards, and surface anomalies — all in pure MATLAB with no
toolbox dependencies.
**Current focus:** Phase 1031 — Live Tail + Slider Preview Overlay

## Current Position

Phase: 1031 (Live Tail + Slider Preview Overlay) — EXECUTING
Plan: 3 of 3
Milestone: v3.1 Plant Log Integration
Status: Phase complete — ready for verification
Last activity: 2026-05-14

## Progress Bar

v3.1 Plant Log Integration:

- [x] Phase 1029: Plant Log Storage Foundation — 3/3 plans
- [x] Phase 1030: CSV/XLSX Import + Mapping Dialog — 3/3 plans (executing complete; verify pending)
- [ ] Phase 1031: Live Tail + Slider Preview Overlay — 0/? plans
- [ ] Phase 1032: Per-Widget Plant Log Overlay — 0/? plans
- [ ] Phase 1033: Dashboard + Companion Integration & Serialization — 0/? plans

Phases complete: 2/5 (executing); 1/5 verified
Plans complete: 6/6 (100%) across closed phases

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

- **Resume point:** Phase 1030 is **closed**. Next step: run `/gsd:verify-phase 1030`
  to confirm every PLOG-IM-* requirement has matching test evidence, then
  `/gsd:start-phase 1031` to begin the live-tail + slider preview overlay
  (which will consume `PlantLogReader.openInteractive('Headless', true, 'Mapping', savedMapping)`
  on every timer tick).

- **Order of phases:** 1029 ✅ → 1030 ✅ → 1031 → 1032 → 1033 (each phase depends on
  prior phases; no parallel execution paths).

- **Coverage:** 32/32 active PLOG-* requirements mapped to phases — verified
  during roadmap creation. PLOG-ST-01..05 (5/32) have unit + integration
  proof (Phase 1029); PLOG-IM-01..05 (5/32) have headless-reader proof
  (Phase 1030 Plan 01); PLOG-IM-06..08 (3/32) have modal-dialog proof
  (Phase 1030 Plan 02); PLOG-IM-01 + 02 + 06 + 08 have additional
  integration-level proof (Phase 1030 Plan 03 — openInteractive +
  integration smoke). All PLOG-IM-* (8/32) integration-proven at runtime.
  16 requirements remaining across Phases 1031, 1032, 1033.

- **Stopped at:** Completed 1031-03-hover-tooltip-and-smoke-PLAN.md
  (Phase 1030 closed; ready for /gsd:verify-phase 1030).
  `PlantLogReader.openInteractive(filePath, varargin)` ships as the third
  static method, wiring `readtablePortable` → `autoDetect` →
  `PlantLogImportDialog` → `readFile` into the v3.1 public entry point.
  Headless+Mapping mode is the live-tail / serialization-resume contract
  Phase 1031 + 1033 will both call. Empty-file path in interactive mode
  surfaces a non-blocking uialert via a transient uifigure with a
  CloseFcn routed through the named `safeDeleteDialog_` helper (anonymous
  functions cannot wrap try/catch — CHECKER REVISION applied). The
  helper is generalized to handle both `PlantLogImportDialog` and raw
  uigraphics handles. 8/8 function-style + 8/8 class-based PASS on MATLAB
  (incl. XLSX happy path via writetable round-trip — PLOG-IM-02 runtime
  proof). Full Phase 1030 surface 32+27 = 59/59 PASS; Phase 1029
  regression intact (47+44 = 91/91 PASS); checkcode clean on the modified
  PlantLogReader.m and both new test files. Both smoke files deliberately
  omit any manual `addpath(libs/PlantLog)` — relies on Phase 1029 Plan
  03's install.m libs-block edit (regression gate via
  `which('PlantLogReader')`).

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

- **Plan 02 (import dialog, 2026-05-14)** — Shipped `PlantLogImportDialog`
  handle class (`libs/PlantLog/PlantLogImportDialog.m`, ~370 LOC) — modal
  uifigure with two dropdowns (timestamp + message column), explicit
  format-override edit field, 10-row preview uitable, inline red error
  label, and Cancel + Confirm buttons. `runModal()` blocks via `uiwait`
  and returns the mapping struct on Confirm or `[]` on Cancel/CloseRequest.
  `refreshState_` re-validates on every dropdown / format change via
  `parseTimestampLadder` (private helper from Plan 01); Confirm gated on
  parse-success ratio >= 0.9 (matches the autoDetect threshold so the user
  never sees autoDetect-finds-it / dialog-rejects-it inconsistency).
  Same-column safeguard: when ts == msg dropdown values, Confirm is disabled
  with explicit error message (CHECKER REVISION). Theme via
  `CompanionTheme.get(preset)` with a hardcoded fallback inside
  `themeStruct_`. Every callback wraps work in try/catch + non-blocking
  `uialert` (`surfaceError_`); no callback can throw to the user.
  Auto-fixed during execution: (1) stripped four `%#ok<NASGU>` suppressions
  on the `assert(isvalid(localHandle))` lines that R2024b checkcode no
  longer flags; (2) switched `test_explicit_format_revalidates` fixture
  from `'2025/01/15'` (which `datenum` parses leniently via `'MM/dd/yyyy'`)
  to `'20250115'` (rejected by every ladder format yet parseable via the
  explicit `'yyyyMMdd'` hint). Tests are MATLAB-only by design: function-style
  file gates Octave with a clean SKIP + return; class-based suite is
  `matlab.unittest.TestCase`. 9/9 function-style + 9/9 class-based PASS on
  MATLAB; checkcode reports clean on all 3 new files; zero edits to existing
  files. PLOG-IM-06..08 completed. See
  `.planning/phases/1030-csv-xlsx-import-mapping-dialog/1030-02-import-dialog-SUMMARY.md`.

- **Plan 03 (openInteractive + smoke, 2026-05-14)** — Shipped
  `PlantLogReader.openInteractive(filePath, varargin)` as the third
  static method on the existing `PlantLogReader` handle class
  (`libs/PlantLog/PlantLogReader.m`, +151 lines). Default form runs the
  full pipeline: `readtablePortable(filePath)` → `autoDetect(T)` →
  `PlantLogImportDialog(filePath, T, autoMap, 'Theme', opts.Theme)` →
  `dlg.runModal()` → `readFile(filePath, confirmedMapping)`. Returns
  `PlantLogEntry[]` on Confirm or `[]` on Cancel/close.
  `'Headless', true, 'Mapping', struct(...)` short-circuits the dialog
  and delegates straight to `readFile` — this is the live-tail /
  serialization-resume contract Phase 1031 + 1033 will both call.
  `Headless=true` without `Mapping` throws `PlantLogReader:invalidInput`.
  Empty-file path in interactive mode surfaces a non-blocking uialert
  via a transient uifigure with a CloseFcn routed through the named
  `safeDeleteDialog_` helper (anonymous functions cannot wrap try/catch
  — CHECKER REVISION applied to plan); falls back to
  `warning('PlantLogReader:emptyFile', ...)` when uifigure is unavailable
  (Octave / older MATLAB). Headless mode SKIPS the alert. The
  `safeDeleteDialog_` local function (added after the classdef closing
  `end`) is generalized to handle both `PlantLogImportDialog` instances
  AND raw uigraphics handles via `isa(h, 'PlantLogImportDialog')` /
  `isgraphics(h)` dispatch — one helper, two cleanup call sites.
  Caller-supplied partial Mapping in interactive mode merges with
  `autoDetect` output to ensure shape (Phase 1033 may pass partially-
  remembered choices). Function-style smoke
  `tests/test_plant_log_import_smoke.m` ships 8 sub-tests (cross-runtime
  headless: path pickup × 2, end-to-end + store round-trip, no-mapping
  throws, missing-file throws, unsupported-format throws, empty CSV
  returns [], dedup-via-store). Class-based suite
  `tests/suite/TestPlantLogImportSmoke.m` ships 8 test methods mirroring
  the function-style coverage AND adding three MATLAB-only tests:
  programmatic Confirm via `confirmBtn.ButtonPushedFcn([], [])` direct
  invocation, programmatic Cancel via the same pattern, and the XLSX
  happy path via `writetable(T, '*.xlsx')` round-trip with
  `testCase.assumeFail` fallback (PLOG-IM-02 runtime proof on MATLAB
  R2024b's built-in Excel writer; clean skip on Octave / older MATLAB).
  Both smoke files deliberately omit any manual `addpath(libs/PlantLog)`
  — relies on Phase 1029 Plan 03's install.m libs-block edit (regression
  gate via `which('PlantLogReader')`). Class-based interactive tests
  bypass `runModal` to avoid hanging the test runner on `uiwait`.
  Auto-fixed during execution: stripped `%#ok<NASGU>` suppressions on
  `cleanup = onCleanup(...)` lines (R2024b checkcode no longer emits
  NASGU on those — same Rule 1 fix Plans 1030-01 and 1030-02 applied
  uniformly). 8/8 function-style + 8/8 class-based PASS on MATLAB;
  full Phase 1030 surface 32+27 = 59/59 PASS; Phase 1029 regression
  intact (47+44 = 91/91 PASS); checkcode clean on the modified
  PlantLogReader.m and both new test files. Octave 11.1.0 lacks
  `readtable` (no `io` package — same pre-existing env issue Plan 01
  documented); function-style smoke is otherwise Octave-compatible.
  PLOG-IM-01 + PLOG-IM-02 + PLOG-IM-06 + PLOG-IM-08 all have
  integration-level runtime proof beyond the unit-level coverage from
  Plans 01 + 02. **Phase 1030 closed; ready for /gsd:verify-phase 1030.**
  See
  `.planning/phases/1030-csv-xlsx-import-mapping-dialog/1030-03-open-interactive-and-smoke-SUMMARY.md`.
