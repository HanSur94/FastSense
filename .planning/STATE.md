---
gsd_state_version: 1.0
milestone: v3.1
milestone_name: Plant Log Integration
status: verifying
stopped_at: Completed 1033-03-companion-toolbar-and-smoke-PLAN.md (Phase 1033 + milestone v3.1 EXECUTION COMPLETE)
last_updated: "2026-05-19T11:45:54.125Z"
last_activity: 2026-05-19
progress:
  total_phases: 5
  completed_phases: 5
  total_plans: 15
  completed_plans: 15
---

# State

## Project Reference

See: .planning/PROJECT.md (created 2026-05-13)

**Core value:** Engineers can render millions of sensor points smoothly, organize
them into navigable dashboards, and surface anomalies — all in pure MATLAB with no
toolbox dependencies.
**Current focus:** Phase 1033 — Dashboard + Companion Integration & Serialization

## Current Position

Phase: 1033 (Dashboard + Companion Integration & Serialization) — EXECUTION COMPLETE
Plan: 3 of 3 — SHIPPED
Milestone: v3.1 Plant Log Integration — EXECUTION COMPLETE, ready for verification
Status: All 3 plans of Phase 1033 closed; Phase 1033 ready for /gsd:verify-phase 1033; milestone v3.1 ready for /gsd:complete-milestone
Last activity: 2026-05-19

## Progress Bar

v3.1 Plant Log Integration:

- [x] Phase 1029: Plant Log Storage Foundation — 3/3 plans
- [x] Phase 1030: CSV/XLSX Import + Mapping Dialog — 3/3 plans
- [x] Phase 1031: Live Tail + Slider Preview Overlay — 3/3 plans
- [x] Phase 1032: Per-Widget Plant Log Overlay — 3/3 plans
- [x] Phase 1033: Dashboard + Companion Integration & Serialization — 3/3 plans

Phases complete: 5/5 (100%) — Plan 1033-03 closed 2026-05-19 — milestone v3.1 EXECUTION COMPLETE
Plans complete: 15/15 (100%)

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

- **Resume point:** Phase 1033 Plan 03 (Companion toolbar + integration
  smoke) is **shipped** (2026-05-19) — milestone v3.1 EXECUTION COMPLETE.
  `PlantLogReader.openInteractive` now supports `[entries, varargout] =
  openInteractive(...)` with the second optional output being the
  confirmed mapping struct (echoed for headless; from dialog for
  interactive; [] for cancel/empty-file). All four return sites guard
  with `if nargout >= 2; varargout{1} = ...; end` so existing Phase
  1030 + 1031 single-output callers continue to work unchanged.
  `FastSenseCompanion` toolbar grid expanded from `[1 4]` `{110, 110,
  '1x', 36}` to `[1 5]` `{110, 110, 130, '1x', 36}`. New `hPlantLogBtn_`
  private property + new uibutton at col 3 with Tag=CompanionPlantLogBtn,
  Text=`['Plant Log', char(8230)]` ("Plant Log…"), FontSize=11,
  FontWeight=bold, Tooltip="Attach a plant log to every open dashboard".
  Enable=on with >=1 engine + Enable=off with tooltip "No dashboards
  open" otherwise. `hSettingsBtn_.Layout.Column` moved 4 -> 5. New
  private `openPlantLogDialog_` method: outer try/catch +
  final-safety-net uialert + empty-Engines_ branch + cancel branch +
  empty-file branch + best-effort fan-out loop with per-engine try/catch
  raising `FastSenseCompanion:plantLogAttachFailed` + partial-failure
  uialert at loop end (success path silent). Public test shims
  `openPlantLogDialogInternalForTest` + `getPlantLogBtnForTest_` mirror
  the openEventViewer_internalForTest idiom. Four new test files: 9
  function-style + 11 class-based toolbar tests (MATLAB-only with
  Octave SKIP gate); 9 function-style + 13 class-based integration
  smoke tests (cross-runtime where possible, Companion-touching tests
  MATLAB-only). The v3.1 milestone capstone test
  `testEndToEndDashboardLifecycle` exercises the FULL surface: attach
  -> save JSON -> save .m -> load JSON -> load .m -> detach all ->
  timerfindall back to baseline (zero orphans). Auto-fixed during
  execution: (1) matlab.lang.OnOffSwitchState class mismatch in
  verifyEqual (Rule 1 -- R2025b's Enable is enum, switched to
  `verifyTrue(strcmp(char(btn.Enable), 'on'))`); (2) stale
  `%#ok<NASGU>` + `catch ME` cleanup (Rule 2 hygiene). 209/209 PASS
  across the full v3.1 plant-log surface (17 test classes); 64/64
  existing TestFastSenseCompanion unchanged. PLOG-INT-03 complete.
  Phase 1033 ready for `/gsd:verify-phase 1033`; milestone v3.1 ready
  for `/gsd:complete-milestone`.

- **Order of phases:** 1029 ✅ → 1030 ✅ → 1031 ✅ → 1032 ✅ → 1033 ✅ (all 3 plans complete). Each phase depended on prior phases; no parallel execution paths.

- **Coverage:** 32/32 active PLOG-* requirements integration-proven end-to-end.
  Phase 1029 (PLOG-ST-01..05) + Phase 1030 (PLOG-IM-01..08) + Phase 1031
  (PLOG-LT-* + PLOG-VIZ-01/02/06/08/09) + Phase 1032 (PLOG-VIZ-03/04/05/07) +
  Phase 1033 (PLOG-INT-01..05). Plan 03 closure adds PLOG-INT-03 (Companion
  toolbar fan-out) on top of Plan 01 (PLOG-INT-01/02 attach/detach API) and
  Plan 02 (PLOG-INT-04/05 serialization + load-time degrade-to-warning).
  v3.1 milestone EXECUTION COMPLETE.

- **Stopped at:** Completed 1033-03-companion-toolbar-and-smoke-PLAN.md
  (Phase 1033 Plan 03 of 3 closed; Phase 1033 + milestone v3.1
  EXECUTION COMPLETE). `PlantLogReader.openInteractive` extended with
  varargout second-output mapping; FastSenseCompanion toolbar gains
  1x5 grid with new "Plant Log…" button at col 3; new
  `openPlantLogDialog_` private callback wraps the file picker +
  best-effort fan-out across `obj.Engines_` with per-engine try/catch
  and namespaced warning routing. Phase 1033 end-to-end smoke
  (`testEndToEndDashboardLifecycle`) proves the v3.1 capstone:
  engine.attachPlantLog -> save JSON -> save .m -> load JSON -> load
  .m -> detach all -> zero orphan timers. 209/209 PASS across the
  full v3.1 plant-log test surface; PLOG-INT-03 + all 32/32 v3.1
  requirements integration-proven end-to-end. Auto-fixed during
  execution: (1) matlab.lang.OnOffSwitchState class mismatch on three
  class-based `verifyEqual(btn.Enable, 'on')` calls (Rule 1 — switched
  to `verifyTrue(strcmp(char(btn.Enable), 'on'))`); (2) checkcode
  hygiene cleanup on stale `%#ok<NASGU>` + `catch ME` lines (Rule 2).
  All four new test files checkcode-clean. Phase 1033 ready for
  `/gsd:verify-phase 1033`; milestone v3.1 ready for
  `/gsd:complete-milestone`.

- **Plan 02 surface preserved (Phase 1033 Plan 02 historic note):** `DashboardSerializer`

  + `DashboardEngine` extended to round-trip the engine's plant-log state
  through JSON and .m-script paths with byte-identical back-compat for
  every v1.0-v3.0 dashboard. Save side: new `stampPlantLogIntoConfig_`
  private helper on `DashboardEngine` writes the plantLog block onto cfg
  AFTER widgetsToConfig builds it (omit-when-empty when
  `PlantLogStoreInternal_` OR `PlantLogSourcePath_` is empty). New
  `encodePlantLogBlock_` static helper on `DashboardSerializer`
  hand-encodes the JSON object bypassing `jsonencode`'s cell-of-cells
  ambiguity for `metadataCols`. New `linesForPlantLog_` static private
  helper is shared by all three .m-script export paths
  (`DashboardSerializer.save` legacy, `exportScript` modern,
  `exportScriptPages` multi-page); uses double-brace
  `metadataCols, {{...}}` literal so `struct()` preserves the cell shape
  on feval reload. Per-widget `'ShowPlantLog', true` NV pair forks BOTH
  the legacy single-line writer AND the modern `linesForWidget` case
  'fastsense' across all four sub-cases (sensor/file/data/otherwise +
  no-source fallback). Load side: `DashboardEngine.attachPlantLog`
  accepts hidden `ContinueOnReadError` opt (default false). New
  `surfacePlantLogLoadFailure_` private helper routes
  `PlantLogReader:fileNotFound` to
  `warning('DashboardEngine:plantLogPathMissing', ...)`, other read
  failures to `warning('DashboardEngine:plantLogReadFailed', ...)`.
  `PlantLogReader:unknownColumn` triggers inline mapping-mismatch
  recovery: re-run `autoDetectFromFile`,
  `warning('DashboardEngine:plantLogMappingMismatch', ...)`, retry
  `openInteractive` with the new mapping; on second failure warn
  plantLogReadFailed. `DashboardEngine.load` JSON branch pre-flights
  `exist(sourcePath, 'file')` (covers the case where user supplied an
  explicit Mapping that bypasses the autoDetect path), validates schema
  (`error('DashboardSerializer:plantLogSchemaInvalid', ...)` on
  malformed plantLog block), and dispatches `attachPlantLog` with
  `ContinueOnReadError=true`. v1.0-v3.0 back-compat: missing plantLog
  key skips entirely with zero warnings. 14/14 function-style + 17/17
  class-based PASS on MATLAB R2025b (including 3 rendered round-trip
  tests:`testRoundTripWidgetShowPlantLog`,
  `testRoundTripPerWidgetShowPlantLogScriptPath`,
  `testReAttachAfterLoadIsIdempotent`); Phase 1029-1032 regression
  intact (TestPlantLogIntegrationSmoke 9/9 + TestPhase1031IntegrationSmoke
  7/7 + TestPhase1032IntegrationSmoke 9/9 + TestDashboardEngineAttachPlantLog
  18/18 + TestDashboardMSerializer 10/10); checkcode 4 advisory AGROW
  warnings on new `wLines{end+1}` lines matching existing `linesForWidget`
  style, zero NEW Error/Critical-level. Auto-fixed during execution:
  dashboard name "TestWidgetNoShowPlantLog" → "TestWidgetDefault" (Rule 1
  — substring match on dashboard name produced false-positive assertion
  failure); 6 stale `%#ok<AGROW>` suppressions stripped from
  `attachArgs{end+1}` lines (Rule 2 hygiene — R2025b no longer emits AGROW
  on these patterns, same pattern as Plans 1030-1032).

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

### Phase 1032 — Per-Widget Plant Log Overlay

- **Plan 01 (widget property + draw, 2026-05-19)** — FastSenseWidget gains
  a public `ShowPlantLog` boolean property (default false) anchored after
  ShowEventMarkers, mirroring the Phase 1012 precedent shape. A new
  `PlantLogXLimListener_` property lives in its own properties block with
  `SetAccess = {?DashboardEngine, ?FastSenseWidget, ?matlab.unittest.TestCase}`
  so the engine's `attachPlantLogXLimListener_` can write the handle while
  public READ stays available (Rule 3 deviation: plan put it in
  `SetAccess = private`, which made the engine's `addlistener`
  assignment fail). `setPlantLogMarkers(times, entries)` draws one
  `xline` per finite timestamp with `Tag='WidgetPlantLogMarker'`,
  `Color=theme.MarkerPlantLog` (default `[0 0 0]`), `LineWidth=1`,
  `HitTest='on'`, `PickableParts='all'`. Empty / no-arg input clears
  via tag-based delete. Non-finite timestamps silently dropped.
  uistack z-order: sensor trace -> plant-log -> event badges.
  `setShowPlantLog(tf, engine)` flips the property with prior-state
  revert + `FastSenseWidget:plantLogToggleFailed` namespaced warning
  on failure. `delete(widget)` releases the listener BEFORE FastSense
  teardown deletes the axes. `toStruct`/`fromStruct` round-trip the
  `showPlantLog` key (default omitted so older serialized dashboards
  stay byte-identical). DashboardEngine gains three friend-restricted
  methods in a new
  `methods (Access = {?FastSenseWidget, ?matlab.unittest.TestCase})`
  block: `refreshPlantLogOverlayForWidget_` (clear -> store range query
  -> sub-pixel coalesce `floor(double(times) * pixelsPerDataUnit)`
  unique-bucket reduction -> `widget.setPlantLogMarkers`),
  `clearPlantLogOverlaysOnAllWidgets_` (walks `allPageWidgets()` AND
  `DetachedMirrors`, wipes markers WITHOUT flipping ShowPlantLog),
  and `attachPlantLogXLimListener_` (XLim PostSet listener that fires
  refresh). Plan literal `Access = {?FastSenseWidget}` was extended to
  also include `?matlab.unittest.TestCase` so class-based suite tests
  can call these directly (Rule 3 deviation; substring intact for the
  grep acceptance criterion). New private `onPlantLogTailTick_`
  callback wraps `computePlantLogMarkers` (slider path) + fans out to
  every ShowPlantLog=true widget across pages + DetachedMirrors
  (decision G full parity). `setPlantLogLiveTailForTest_` rewired
  single-line to route the `PlantLogTickListener_` through
  `onPlantLogTailTick_` so every live-tail tick refreshes both slider
  AND per-widget overlays. Three new Hidden test seams
  (`refreshPlantLogOverlayForWidgetForTest_`,
  `clearPlantLogOverlaysOnAllWidgetsForTest_`,
  `attachPlantLogXLimListenerForTest_`) route function-style tests to
  the friend-restricted methods (Phase 1031 idiom). 20/20 function-style

  + 20/20 class-based on MATLAB; Phase 1031 regression intact (22/22
  class + 19/19 function-style); Phase 1029-1031 broader regression
  52/52. checkcode reports zero NEW Error- or Critical-level
  diagnostics on either modified production file (23 pre-existing
  DashboardEngine warnings unchanged). PLOG-VIZ-03 + PLOG-VIZ-04
  completed. See
  `.planning/phases/1032-per-widget-plant-log-overlay/1032-01-widget-property-and-draw-SUMMARY.md`.

- **Plan 02 (toggle button + hover tooltip, 2026-05-19)** — DashboardLayout
  gains a new public `EngineRef` back-reference property (set in
  DashboardEngine constructor `obj.Layout.EngineRef = obj`) + a public
  `addPlantLogToggle(widget, engine)` method (intentional access bump
  vs. the existing private addInfoIcon/addDetachButton — tests + future
  Companion paths need to invoke the rebuild directly). The L button is
  a 24×24 uicontrol pushbutton with `Tag='PlantLogToggleButton'`,
  `String='L'`, `FontWeight='bold'`, positioned as the LEFTMOST of the
  three button-bar buttons (x = barW - 84 from right edge). Idempotent:
  prior tags are deleted before create. Pressed-state colors derived
  from `theme.MarkerPlantLog` (ON: bg=[0 0 0], fg=[1 1 1]) vs theme
  defaults (OFF). Disabled with tooltip `'No plant log attached'` when
  no store is attached. Callback wrapper `onPlantLogTogglePressed_` calls
  `widget.setShowPlantLog(~ShowPlantLog, engine)` + rebuilds the button
  look; wraps in try/catch + namespaced warning
  `DashboardLayout:plantLogToggleParentMissing` + best-effort uialert.
  Software-level `Enable='off'` guard short-circuits force-call paths.
  `reflowChrome_` extended to re-anchor all THREE buttons on resize
  (Detach at barW-24-4, Info at barW-56, PlantLog at barW-84).
  `realizeWidget` invokes `addPlantLogToggle(widget, obj.EngineRef)` for
  every FastSenseWidget instance behind the existing `needsBar` chrome
  path. `DashboardWidget.clearPanelControls` protectedTags extended with
  `'PlantLogToggleButton'`. New `libs/PlantLog/PlantLogWidgetHover.m`
  class (~480 LOC) mirrors `PlantLogSliderHover`'s chained-WBM lifecycle
  exactly with: single-entry vs multi-entry tooltip layout branching;
  full-metadata rendering (insertion order, value truncated to 39 chars +
  `char(8230)` Unicode '…' when >40 chars, embedded newlines collapsed
  to single space); overlap stacking with `'-- ts --'` block headers
  sorted by Timestamp ASC; 10-entry cap with `'+N more entries near this
  point'` footer; `simulateHoverAt_` returns the FULL entry array within
  tolerance (not single nearest pick like the slider hover);
  `PlantLogWidgetHover:invalidInput` error namespace. DashboardEngine
  gains a public-read/friend-write `WidgetHovers_` cell of
  `{widget, PlantLogWidgetHover}` pairs (mirrors Plan 01's
  PlantLogXLimListener_ access pattern). New friend-restricted methods
  `attachPlantLogWidgetHover_(widget)` + `detachPlantLogWidgetHover_(widget)`
  added to the existing Plan 01 `methods (Access = {?FastSenseWidget,
  ?matlab.unittest.TestCase})` block. `attachPlantLogWidgetHover_` lazy-
  constructs a `PlantLogWidgetHover` parented to the figure ancestor of
  the widget axes, routing lookup through `obj.lookupPlantLogEntries_`.
  `detachPlantLogWidgetHover_` is idempotent (cell-of-pairs walk with
  logical-mask kept-subset reassignment) and also sweeps stale-widget
  pairs. `DashboardEngine.delete()` tears down `WidgetHovers_` BEFORE
  `TimeRangeSelector_` (mirrors Phase 1031's hover-before-selector
  ordering rule). `FastSenseWidget.setShowPlantLog` extended with two
  lines: ON branch calls `engine.attachPlantLogWidgetHover_(obj)` after
  the listener + refresh; OFF branch calls
  `engine.detachPlantLogWidgetHover_(obj)` BEFORE the marker clear.
  `char(10)` -> `newline` migration on the tooltip strjoin separator
  (R2024b CHARTEN advisory). 12/12 layout function-style + 12/12 class

  + 13/13 hover function-style + 13/13 class on MATLAB; Phase 1029-1031
  + Plan 01 regression intact (126/126 across the v3.1 plant-log suite).
  checkcode reports zero NEW Error- or Critical-level diagnostics on
  any modified or new production file. PLOG-VIZ-05 + PLOG-VIZ-07
  completed. See
  `.planning/phases/1032-per-widget-plant-log-overlay/1032-02-toggle-button-and-hover-SUMMARY.md`.

- **Plan 03 (detached mirror parity + end-to-end smoke, 2026-05-19)** —
  Closed Phase 1032 by shipping Decision G full parity and an end-to-end
  integration smoke. `DetachedMirror.restoreLiveRefs` extended with a
  triple-guarded copy `cloned.ShowPlantLog = original.ShowPlantLog` when
  both sides are FastSenseWidget (belt-and-suspenders alongside Plan 01's
  `toStruct`/`fromStruct` round-trip; protects against future
  serialization regressions silently breaking detach parity).
  `DashboardEngine.detachWidget` extended with a tail block that
  re-invokes `cw.setShowPlantLog(true, obj)` on the mirror's cloned
  widget when `cw.ShowPlantLog == true` — this is a no-op for the
  property itself but triggers `attachPlantLogXLimListener_` +
  `refreshPlantLogOverlayForWidget_` + `attachPlantLogWidgetHover_` on
  the mirror's standalone figure axes (Decision G full parity wire-up).
  Wrapped in try/catch + namespaced warning
  `DashboardEngine:plantLogOverlayFailed` so a failure surfaces but does
  not break the detach. `removeDetached` (explicit prune from tests +
  onLiveTick stale scan) extended with `obj.detachPlantLogWidgetHover_(m.Widget)`
  inside the stale-mirror sweep loop, BEFORE the keep-filter applies.
  `removeDetachedByRef` (CloseRequestFcn path) similarly extended with
  `obj.detachPlantLogWidgetHover_(target.Widget)` guarded by `isa(target,
  'DetachedMirror') && isa(target.Widget, 'FastSenseWidget')`, also
  BEFORE the keep-filter. The detach helper is idempotent so double-sweep
  is safe. End-to-end smoke ships in two files:
  `tests/test_phase_1032_integration_smoke.m` (8 sub-tests, cross-runtime
  for path-pickup + serialize, MATLAB-only with clean Octave SKIP for
  toggle / hover / fan-out / detach / cleanup) and
  `tests/suite/TestPhase1032IntegrationSmoke.m` (9 Test methods mirroring
  the function-style + adding `testRealTimerRoundTrip` which uses
  `PlantLogLiveTail` with `Interval=0.2s` + `StartImmediately=true` +
  `pause(0.6)` to drive the real timer + listener + fan-out chain
  end-to-end with a CSV containing parseable `yyyy-mm-dd HH:MM:SS`
  datenum timestamps). Both files deliberately omit any manual
  `addpath(libs/PlantLog)` — install.m libs-block is the regression
  gate (sub-test 1 / testPathPickup covers it). Smoke fixtures use
  `SensorTag`-backed FastSenseWidget (matching
  `TestDashboardDetach.makeFastSenseWidget`) because
  `DetachedMirror.stripSensorRefs` unconditionally drops the `source`
  field on the clone — `restoreLiveRefs`'s `cloned.Sensor =
  original.Sensor` copy is the live-data restoration path. Auto-fixed
  during execution: (1) SensorTag fixture replacement (Rule 1); (2)
  `e.addWidget(w)` added to fan-out-asserting tests (Rule 1 — fan-out
  walks `obj.Widgets`); (3) `flattenTooltipString_` helper covering 4
  uicontrol(text) String shapes (Rule 1 — `strfind` needs flat char);
  (4) real-timer CSV switched to ISO datetime format (Rule 1 —
  `parseTimestampLadder` rejects numeric < 1e5); (5) checkcode hygiene
  on both new test files (Rule 2 — ISCL → isscalar, NOCOMMA →
  multi-line, DATST suppression on call line). 8/8 function-style + 9/9
  class-based PASS on MATLAB R2025b; full Phase 1029-1032 regression
  143/143 PASS (TestPlantLogStore 21 + Entry 10 + Reader 10 + LiveTail
  11 + IntegrationSmoke 7 + SliderHover 12 + SliderOverlay 10 +
  Phase1031Integration 7 + FastSenseWidgetPlantLog 20 + WidgetHover 13

  + LayoutToggle 12 + DashboardDetach 10 + Phase1032Integration 9 =
  143). checkcode clean on `DetachedMirror.m` + both new test files;
  `DashboardEngine.m` pre-existing warnings unchanged. All 4 PLOG-VIZ-*
  requirements (03/04/05/07) integration-proven end-to-end. **Phase
  1032 closed; ready for /gsd:verify-phase 1032.** See
  `.planning/phases/1032-per-widget-plant-log-overlay/1032-03-detached-mirror-and-smoke-SUMMARY.md`.

### Phase 1033 — Dashboard + Companion Integration & Serialization

- **Plan 01 (engine public API, 2026-05-19)** — Shipped
  `DashboardEngine.attachPlantLog` + `detachPlantLog` public methods
  replacing the Phase 1031 test seam as the production code path. Four
  new private serialization-state properties
  (`PlantLogSourcePath_`/`PlantLogMapping_`/`PlantLogInterval_`/`PlantLogStartTail_`)
  populated by attach + cleared by detach, ready for Plan 02 serializer
  read-through via friend access (CONTEXT.md D-01). Idempotent re-attach:
  `attachPlantLog` calls `detachPlantLog` internally when a prior store
  exists (D-04). Two new private mapping translation helpers
  (`plantLogMappingToReaderShape_` + `readerMappingToJsonShape_`) bridge
  the CONTEXT.md JSON-schema names (`timestampCol`/`messageCol`/`format`)
  <-> PlantLogReader PascalCase shape with back-compat acceptance of
  either shape (D-05). Destructor extended with
  `try obj.detachPlantLog(); catch, end` as the final plant-log teardown
  step. Phase 1031 test seams `setPlantLogStoreForTest_` +
  `setPlantLogLiveTailForTest_` preserved on disk -- production
  `attachPlantLog` REUSES them internally so wire-up code stays
  single-source-of-truth. After-attach widget rewire (D-09): iterate
  Widgets and call `setShowPlantLog(true, engine)` on every
  `ShowPlantLog=true` `FastSenseWidget` so XLim listener + hover attach
  even when the property was set by `fromStruct`. Auto-fixed during
  execution: (1) `PlantLogStore` constructor requires `sourceFile` arg
  (Rule 3 -- plan example `PlantLogStore()` throws
  `PlantLogStore:invalidInput`; use `PlantLogStore(filePath)` so the
  store records the source path); (2) Added
  `PlantLogReader.autoDetectFromFile(filePath)` static helper because
  `DashboardEngine` cannot reach `libs/PlantLog/private/readtablePortable.m`
  (Rule 3 -- minimal additive helper, does not conflict with Plan 03's
  planned `openInteractive` extension); (3) `StartTail` scalar
  validation added (Rule 2 -- `[true true]` would have passed the
  type check). 15/15 function-style + 18/18 class-based PASS on MATLAB
  R2025b; Phase 1029-1032 regression intact (23/23 integration smoke +
  52/52 plant-log unit surface); checkcode clean on both new test
  files; `DashboardEngine.m` pre-existing 23 warnings unchanged (zero
  NEW Error/Critical-level diagnostics). PLOG-INT-01 + PLOG-INT-02
  unit + integration-proven. See
  `.planning/phases/1033-dashboard-companion-integration-serialization/1033-01-engine-public-api-SUMMARY.md`.

- **Plan 02 (serializer + load round-trip, 2026-05-19)** — Shipped the
  full save + load round-trip for the engine's plant-log state through
  both JSON and .m-script paths with byte-identical back-compat for
  every v1.0-v3.0 dashboard. Save side: `stampPlantLogIntoConfig_`
  private helper on `DashboardEngine` stamps the plantLog block onto
  cfg AFTER widgetsToConfig builds it (omit-when-empty when store OR
  sourcePath is empty -- test-seam-only attachments by design do NOT
  serialize); `encodePlantLogBlock_` static helper on
  `DashboardSerializer` hand-encodes the JSON object bypassing
  jsonencode's cell-of-cells ambiguity for metadataCols;
  `linesForPlantLog_` static private helper is shared by all three
  .m-script export paths (`save`, `exportScript`, `exportScriptPages`)
  with double-brace `metadataCols, {{...}}` literal so struct()
  preserves the cell shape on feval reload. Per-widget
  `'ShowPlantLog', true` NV pair forks BOTH the legacy single-line
  fastsense writer (`DashboardSerializer.save` ~line 50) AND the
  modern multi-line writer (`linesForWidget` case 'fastsense') across
  all four sub-cases (sensor/file/data/otherwise + no-source
  fallback). Load side: `DashboardEngine.attachPlantLog` accepts the
  new hidden opt `ContinueOnReadError` (default false). New
  `surfacePlantLogLoadFailure_` private helper routes
  `PlantLogReader:fileNotFound` → `warning('DashboardEngine:plantLogPathMissing', ...)`,
  other read failures → `warning('DashboardEngine:plantLogReadFailed', ...)`.
  `PlantLogReader:unknownColumn` triggers inline mapping-mismatch
  recovery: re-run `autoDetectFromFile`, warn
  `DashboardEngine:plantLogMappingMismatch` showing before/after
  columns, retry `openInteractive` with the new mapping; on second
  failure warn plantLogReadFailed and return store=[].
  `DashboardEngine.load` JSON branch pre-flights `exist(sourcePath,
  'file')` check (covers the explicit-Mapping case that bypasses
  autoDetect), validates schema via
  `error('DashboardSerializer:plantLogSchemaInvalid', ...)` on
  malformed plantLog block missing sourcePath, and dispatches
  `attachPlantLog` with `ContinueOnReadError=true`. After successful
  mapping-mismatch recovery, the `readerMappingToJsonShape_` tail of
  attachPlantLog overwrites `engine.PlantLogMapping_` so the next
  save round-trips the new auto-detected shape (CONTEXT.md D-12).
  Byte-identical back-compat verified via
  `testSaveJsonBackCompatByteIdentical` (two no-plant-log engines
  produce identical JSON). Auto-fixed during execution: (1) dashboard
  name "TestWidgetNoShowPlantLog" renamed to "TestWidgetDefault"
  (Rule 1 -- substring match on dashboard name produced
  false-positive assertion failure); (2) 6 stale `%#ok<AGROW>`
  suppressions stripped from new `attachArgs{end+1}` lines (Rule 2
  hygiene -- R2025b no longer emits AGROW on these patterns, same
  Rule 2 fix Plans 1030-1032 applied uniformly). 14/14 function-style

  + 17/17 class-based PASS on MATLAB R2025b; Phase 1029-1032
  regression intact (TestPlantLogIntegrationSmoke 9/9 +
  TestPhase1031IntegrationSmoke 7/7 + TestPhase1032IntegrationSmoke
  9/9 + TestDashboardEngineAttachPlantLog 18/18 +
  TestDashboardMSerializer 10/10); DashboardSerializer.m checkcode
  +4 advisory AGROW warnings matching existing linesForWidget style
  (zero NEW Error/Critical); DashboardEngine.m checkcode improvement
  via stale-suppression cleanup. PLOG-INT-04 + PLOG-INT-05
  unit + integration-proven (including 3 rendered round-trip tests:
  `testRoundTripWidgetShowPlantLog`,
  `testRoundTripPerWidgetShowPlantLogScriptPath`,
  `testReAttachAfterLoadIsIdempotent`). See
  `.planning/phases/1033-dashboard-companion-integration-serialization/1033-02-serializer-and-load-SUMMARY.md`.

- **Plan 03 (companion toolbar + integration smoke, 2026-05-19)** —
  Closed Phase 1033 + milestone v3.1 by shipping the Companion's
  one-click "Plant Log…" toolbar entry + the Phase 1033 end-to-end
  integration smoke. `PlantLogReader.openInteractive` extended with
  `[entries, varargout] = openInteractive(filePath, varargin)`
  signature; second optional output is the confirmed mapping struct
  (echoed for `Headless=true`, from the dialog for interactive paths,
  `[]` on cancel/empty-file). All four return sites guard with
  `if nargout >= 2; varargout{1} = ...; end` so single-output Phase
  1030 + 1031 callers continue to work unchanged (back-compat
  preserved). `FastSenseCompanion` toolbar grid expanded from `[1 4]`
  `{110, 110, '1x', 36}` to `[1 5]` `{110, 110, 130, '1x', 36}`. New
  `hPlantLogBtn_` private property + new uibutton at col 3 with
  `Tag='CompanionPlantLogBtn'`, `Text=['Plant Log', char(8230)]`
  ("Plant Log…"), `FontSize=11`, `FontWeight='bold'`,
  `Tooltip='Attach a plant log to every open dashboard'`. Enable=on
  with ≥1 engine + Enable=off with tooltip 'No dashboards open'
  otherwise. `hSettingsBtn_.Layout.Column` moved 4 → 5 (gear stays
  rightmost). New private `openPlantLogDialog_` method: outer
  try/catch + final-safety-net `uialert(obj.hFig_, ...)` so no
  exception ever reaches the console; empty-`Engines_` branch fires
  'No dashboards are open' uialert; calls
  `[entries, confirmedMapping] = PlantLogReader.openInteractive('')`
  (empty path triggers native uigetfile in the reader); cancel branch
  (entries + mapping both empty) returns silently; empty-file branch
  (entries empty, mapping non-empty) fires 'no parseable rows' uialert
  and returns; fan-out loop iterates `obj.Engines_` with `isvalid`
  check + per-engine try/catch around
  `eng.attachPlantLog(filePath, 'Mapping', m, 'Interval', 5, 'StartTail', true)`,
  records failures in a `failedNames` cell, fires
  `warning('FastSenseCompanion:plantLogAttachFailed', ...)` per
  failure, and reports a single partial-failure uialert at loop end.
  Success path is silent (no toast). Public test shims
  `openPlantLogDialogInternalForTest` + `getPlantLogBtnForTest_`
  mirror the openEventViewer_internalForTest idiom. Four new test
  files: 9 function-style + 11 class-based toolbar tests (MATLAB-only
  with clean Octave SKIP gate); 9 function-style + 13 class-based
  Phase 1033 end-to-end integration smoke tests (cross-runtime for
  the headless save/load + Octave-skipped for Companion-touching
  tests). The v3.1 milestone capstone test
  `testEndToEndDashboardLifecycle` exercises the FULL surface: build
  engine -> attach plant log -> save JSON -> save .m -> load JSON ->
  load .m -> verify both reloaded stores have equivalent counts ->
  detach all three -> `timerfindall` returns to baseline. The
  varargout back-compat regression gate
  (`testVarargoutBackCompatPreserved`) explicitly exercises both
  single-output and two-output forms of openInteractive. Auto-fixed
  during execution: (1) `matlab.lang.OnOffSwitchState` class
  mismatch on three class-based `verifyEqual(btn.Enable, 'on')` calls
  in R2025b (Rule 1 — Enable is enum, switched to
  `verifyTrue(strcmp(char(btn.Enable), 'on'))` idiom); (2) checkcode
  hygiene cleanup on stale `%#ok<NASGU>` + `catch ME` -> `catch` +
  one `numel(x) == 1` -> `isscalar(x)` per ISCL (Rule 2 hygiene). All
  four new test files checkcode-clean. 9/9 function-style + 11/11
  class-based toolbar PASS; 9/9 function-style + 13/13 class-based
  Phase 1033 smoke PASS; 209/209 PASS across the full v3.1 plant-log
  test surface (17 test classes including TestPlantLogStore 21 +
  Entry 10 + Reader 10 + LiveTail 11 + IntegrationSmoke 7 +
  SliderHover 12 + SliderOverlay 10 + Phase1031Integration 7 +
  FastSenseWidgetPlantLog 20 + WidgetHover 13 + LayoutToggle 12 +
  Phase1032Integration 9 + DashboardEngineAttachPlantLog 18 +
  DashboardSerializerPlantLog 17 + FastSenseCompanionPlantLogToolbar
  11 + Phase1033IntegrationSmoke 13 + PlantLogImportSmoke 8); 64/64
  existing TestFastSenseCompanion regression intact (toolbar
  expansion did not regress Events/Live/Settings button paths).
  PLOG-INT-03 + all 32/32 v3.1 PLOG-* requirements integration-proven
  end-to-end. **Phase 1033 closed; milestone v3.1 EXECUTION COMPLETE;
  ready for /gsd:verify-phase 1033 and /gsd:complete-milestone v3.1.**
  See `.planning/phases/1033-dashboard-companion-integration-serialization/1033-03-companion-toolbar-and-smoke-SUMMARY.md`.
