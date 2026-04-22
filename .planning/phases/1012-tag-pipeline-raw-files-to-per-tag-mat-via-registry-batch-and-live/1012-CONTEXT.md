# Phase 1012: Tag Pipeline — raw files to per-tag MAT via registry, batch and live — Context

**Gathered:** 2026-04-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a MATLAB pipeline that ingests arbitrary raw data files (`.csv` / `.txt` / `.dat`) and emits per-tag `.mat` files keyed off `TagRegistry`, in two modes:

- **Batch** — synchronous one-shot ingest of all tags' raw sources.
- **Live** — timer-driven incremental append as raw files grow.

Outputs are loadable by the existing `SensorTag.load()` contract so the usual plotting / dashboard path just works. Only `SensorTag` and `StateTag` (raw data carriers) are written; `MonitorTag` / `CompositeTag` remain lazy at load time per MONITOR-03.

**In scope:**
- New property `RawSource` on `SensorTag` + `StateTag` (struct: `file`, `column`, `format`).
- One shared private delimited-text parser covering `.csv` / `.txt` / `.dat`, auto-detecting delimiter (comma / tab / semicolon / whitespace).
- `BatchTagPipeline` class — iterates `TagRegistry`, de-dups file reads, writes `<OutputDir>/<tagKey>.mat`.
- `LiveTagPipeline` class — timer-driven, polling raw files via `MatFileDataSource`-style `modTime + lastIndex` pattern.
- Per-tag isolated error handling; end-of-run summary + `TagPipeline:ingestFailed`.
- Synthetic in-test fixtures (wide + tall CSV/TXT/DAT).

**Out of scope (explicitly deferred):**
- Public `registerParser(ext, fn)` plugin API.
- Binary `.dat` layouts (all three extensions are delimited text this phase).
- Metadata-snapshot blocks inside `.mat` files (Tag universals stay on the Tag definition in the `.m` registry script).
- Multi-tag `.mat` layouts (strict one-tag-per-file).
- Monitor/composite materialization to disk (lazy-only — MONITOR-03 discipline preserved).
- Huge-dataset handoff to `FastSenseDataStore` (pipeline writes plain `.mat`; disk-backed stores are the caller's choice via `SensorTag.toDisk()`).
- Load-side API rework — `SensorTag.load()` already handles the output shape unchanged.
- GUI / builder for the tag definition `.m` file.

</domain>

<decisions>
## Implementation Decisions

### Raw input surface
- **D-01:** Ship **one shared delimited-text parser** used for `.csv`, `.txt`, and `.dat`. Extension is a hint only; the parser sniffs the delimiter (comma / tab / semicolon / whitespace).
- **D-02:** **No public parser-registration API this phase.** Built-ins are fixed. Architect the internal dispatch so a future phase can add `registerParser(ext, fn)` without rewrite, but do not expose it now.
- **D-03:** **Synthetic in-test fixtures only** — no real sample files to target. Tests generate CSV/TXT/DAT variants in-suite.
- **D-04:** Pipeline supports **both wide** (time column + N value columns) **and tall** (2 cols: time + value) raw shapes. Dispatch by column count vs. the `RawSource.column` field.

### Tag ↔ file binding
- **D-05:** Binding lives on the **tag itself** via a new `RawSource` struct property on `SensorTag` and `StateTag`. `Tag` base is **not** touched (preserves Pitfall-1/5 discipline from v2.0).
  ```matlab
  SensorTag('pump_a_pressure', 'Units', 'bar', ...
      'RawSource', struct('file',   'data/raw/loggerA.csv', ...
                          'column', 'pressure_a', ...
                          'format', ''));   % optional; default = infer from extension
  ```
  `MonitorTag` / `CompositeTag` deliberately do **not** get this property (they are derived).
- **D-06:** For tall files, `column` may be omitted (2-col file has no ambiguity). For wide files, `column` is required; missing-column at ingest → per-tag error.
- **D-07:** **Pipeline de-dups file reads internally**: when N tags share the same `RawSource.file`, the file is opened/parsed once per pipeline run and fanned out to each tag's column. User-facing schema stays flat (every tag declares its own `RawSource`); de-dup is an internal optimization.
- **D-08:** Tags without a `RawSource` (or `MonitorTag` / `CompositeTag`) are **skipped silently** — pipeline only ingests tags whose `RawSource` is non-empty.

### Per-tag `.mat` output schema
- **D-09:** Each output file contains exactly `data.<KeyName> = struct('x', X, 'y', Y)` — **data only**, matching the current `SensorTag.load()` expectation at [libs/SensorThreshold/SensorTag.m:176](libs/SensorThreshold/SensorTag.m:176). No metadata/provenance block in the `.mat`; tag universals (`Name`, `Units`, `Labels`, `Criticality`, `SourceRef`, `Metadata`) stay on the Tag definition in the registry `.m` script.
- **D-10:** **Strict one-tag-per-`.mat`** — output file is `<OutputDir>/<tagKey>.mat`. No multi-tag `.mat` layouts, so live-mode per-tag writes never conflict across tags.
- **D-11:** `StateTag` output reuses the same `{x, y}` shape (`y` may be numeric or cellstr — existing `StateTag` contract).

### Batch vs live orchestration
- **D-12:** **Two classes, not one**: `BatchTagPipeline` (synchronous, returns on completion) and `LiveTagPipeline` (timer-driven `start`/`stop`/`Status`/`Interval`/`ErrorFcn` ergonomics mirroring `LiveEventPipeline`). Shared private helper module handles the parse-and-write logic so both classes call the same code path per tag.
- **D-13:** `LiveTagPipeline` detects new rows by **mirroring `MatFileDataSource`'s pattern** on raw files — stat `modTime` + remember `lastIndex` per raw file; on each tick re-parse and diff, append-write the output `.mat`. Bytewise tail-reading rejected as over-optimized for this phase.
- **D-14:** `LiveTagPipeline` does **not** subclass `LiveEventPipeline`. It borrows the pattern (timer, start/stop, Status) but lives in its own module to avoid cross-library coupling (`EventDetection` stays about events, not ingestion).

### Output location
- **D-15:** `OutputDir` is a **constructor parameter** on both pipeline classes. Pipeline creates the directory if missing. No per-tag `outputDir` override; no colocation with raw sources.

### Monitor / composite policy
- **D-16:** **Raw-only pipeline.** `MonitorTag` and `CompositeTag` are *never* materialized to disk by this pipeline. Their `getXY()` remains lazy at plot / dashboard load time — parent `SensorTag`/`StateTag` `.mat` loads, then derived tags compute on demand. Preserves MONITOR-03 lazy-by-default contract.
- **D-17:** Users who want monitor persistence continue to use the already-shipped `MonitorTag.Persist = true` + `FastSenseDataStore.storeMonitor` path (Phase 1007 MONITOR-09). That lever is orthogonal to this pipeline.

### Error policy
- **D-18:** **Per-tag isolated error handling.** Each tag's ingest is a try/catch boundary. On failure: log the tag + error + raw-file path, continue with remaining tags. At end of run, if any tag failed, throw `TagPipeline:ingestFailed` with a report listing failed tags. Matches TagRegistry's Pitfall-7 hard-error discipline but scales to batch operations.
- **D-19:** Specific expected errors surfaced by the per-tag try/catch: corrupt file, unreadable file, missing column (wide case), delimiter-detect failure, empty / header-only file. Each produces a namespaced error ID under `TagPipeline:*` for assertable tests.

### Claude's Discretion
- Exact delimiter-sniffing algorithm (likely: try in order `,` → `\t` → `;` → whitespace and pick the one producing consistent column counts).
- Internal parser dispatch shape (switch-by-extension inside the shared helper vs. a private `containers.Map` keyed by extension — pick whichever matches existing code style; no user-visible difference).
- Directory-create behavior (likely `mkdir -p` semantics; error only on permission failures).
- Error-ID naming taxonomy under `TagPipeline:*` (e.g., `TagPipeline:corruptFile`, `:missingColumn`, `:delimiterAmbiguous`, `:rawSourceMissing`).
- Whether the shared private helper is a `+private` folder, a static class, or a plain function file — pick whichever matches existing private-helper patterns in `libs/`.
- File-count budget for the phase (likely ≤12 files following v2.0 discipline).
- Whether to add a `.pipelineVersion` getter or similar for future forward-compat — not required, decide at plan time.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Tag contract (load-side interface the pipeline must round-trip through)
- [libs/SensorThreshold/SensorTag.m:176](libs/SensorThreshold/SensorTag.m:176) — `load(matFile)` contract: expects `data.<KeyName>` as struct `{x, y}` or bare vector. Pipeline output MUST satisfy this.
- [libs/SensorThreshold/SensorTag.m:27](libs/SensorThreshold/SensorTag.m:27) — existing sensor-extras block (`ID_`, `Source_`, `MatFile_`, `KeyName_`); the new `RawSource_` property sits alongside these.
- [libs/SensorThreshold/StateTag.m](libs/SensorThreshold/StateTag.m) — StateTag subclass; parallel `RawSource` property needed here too.
- [libs/SensorThreshold/Tag.m](libs/SensorThreshold/Tag.m) — **do not touch**. `RawSource` is per-subclass (D-05).
- [libs/SensorThreshold/TagRegistry.m](libs/SensorThreshold/TagRegistry.m) — pipeline iterates this to discover tags with `RawSource`.

### Live-mode reference pattern
- [libs/EventDetection/MatFileDataSource.m](libs/EventDetection/MatFileDataSource.m) — canonical `modTime + lastIndex` incremental-read pattern. `LiveTagPipeline` mirrors this on raw files.
- [libs/EventDetection/LiveEventPipeline.m](libs/EventDetection/LiveEventPipeline.m) — timer ergonomics (start / stop / Status / Interval / ErrorFcn). `LiveTagPipeline` borrows the shape, does **not** subclass.
- [libs/EventDetection/DataSource.m](libs/EventDetection/DataSource.m) — abstract `fetchNew()` contract; not required but useful prior art.

### Project discipline
- [.planning/milestones/v2.0-REQUIREMENTS.md](.planning/milestones/v2.0-REQUIREMENTS.md) §TAG-08, §TAG-09 (SensorTag / StateTag data contract), §MONITOR-03 (lazy-by-default — **binds D-16**).
- [.planning/research/PITFALLS.md](.planning/research/PITFALLS.md) — Pitfall 1 (don't over-abstract Tag base), Pitfall 5 (file-touch budgets), Pitfall 7 (hard-error registry discipline — shape for D-18's end-of-run throw).
- [CLAUDE.md](CLAUDE.md) — project constraints: pure MATLAB, no external deps, backward compatibility, MATLAB R2020b+ AND Octave 7+ (delimiter detection must work on both).

### Not applicable
- No external design doc / ADR has been written for this phase; requirements are captured in this CONTEXT.md (D-01 … D-19).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`SensorTag` sensor-extras pattern** ([libs/SensorThreshold/SensorTag.m:27-31](libs/SensorThreshold/SensorTag.m:27)) — `RawSource_` drops into this block cleanly; construction goes through the existing `splitArgs_` name-value machinery.
- **`MatFileDataSource`** ([libs/EventDetection/MatFileDataSource.m](libs/EventDetection/MatFileDataSource.m)) — copy-and-adapt for `LiveTagPipeline`'s polling loop. Proven pattern (used by `LiveEventPipeline` since v1).
- **`LiveEventPipeline` timer shape** ([libs/EventDetection/LiveEventPipeline.m:73-99](libs/EventDetection/LiveEventPipeline.m:73)) — `start()` / `stop()` / timer with `ErrorFcn` and `ExecutionMode='fixedSpacing'`. `LiveTagPipeline` borrows this skeleton without subclassing.
- **`TagRegistry.find(predicate)`** — natural query for `findall(t -> ~isempty(t.RawSource))`; pipeline uses this to enumerate ingest targets.
- **`parseOpts.m`** private helper under `libs/FastSense/private/` — matches existing NV-pair parsing convention; pipeline constructor should reuse this style.

### Established Patterns
- **Strangler-fig discipline** from v2.0 — add new classes / properties additively; do not edit `Tag.m`, `Monitor*.m`, `Composite*.m`.
- **Hard-error registries** (`TagRegistry:duplicateKey`) — end-of-run `TagPipeline:ingestFailed` follows the same philosophy at batch scale.
- **Private helpers under `libs/<Module>/private/`** — shared parse+write helper lives here.
- **Dual-test style** — suite classes (`Test*.m`) + flat function tests (`test_*.m`) as established throughout `tests/`.
- **MATLAB + Octave parity** — project policy; any `readtable`-style MATLAB API needs an Octave fallback (manual `textscan`). Tests gate for this explicitly.

### Integration Points
- `SensorTag` constructor `splitArgs_` — new `RawSource` NV key.
- `StateTag` constructor — parallel `RawSource` handling.
- `TagRegistry` — pipeline's discovery surface (no API change).
- No changes to `FastSense`, `DashboardEngine`, or `LiveEventPipeline` — pipeline is orthogonal.

</code_context>

<specifics>
## Specific Ideas

- The user's existing workflow is: a `.m` script defines tags and registers them with `TagRegistry`. The same script will now also declare each tag's `RawSource`. The pipeline is invoked after that script runs, iterating the registry. This means **no separate mapping file** — the registry IS the mapping.
- Live mode should feel like `LiveEventPipeline` to users who know that class (start/stop/Status/Interval/ErrorFcn) — cognitive re-use matters.
- "Fail one tag, keep going, yell at the end" is the UX — users want a full report, not fail-fast, but they do want a hard error if anything failed so CI catches it.

</specifics>

<deferred>
## Deferred Ideas

- **Public `registerParser(ext, fn)` plugin API** — land in a follow-up phase once a real custom format shows up. Architect internal dispatch to support this without rewrite.
- **Binary `.dat` layout support** — if a real binary format is needed, new phase with a documented header spec.
- **Metadata snapshot inside `.mat` files** — self-describing files with `Name`/`Units`/`Labels` co-persisted. Would need a backward-compatible extension to `SensorTag.load` (read `.meta` if present). Deferred until a user workflow actually needs standalone `.mat` inspection.
- **Multi-tag `.mat` layouts** — if disk-file-count becomes a problem. Trivially supported by the shape `SensorTag.load()` already handles; gated on real pain, not speculation.
- **Monitor / composite pre-materialization** — on-by-default disk persistence for derived tags. Already expressible via `MonitorTag.Persist = true` (Phase 1007) if users want it; pipeline-driven materialization is a separate feature.
- **FastSenseDataStore handoff for huge ingests** — direct-to-disk streaming instead of `.mat`. New phase if raw files exceed RAM.
- **Load-side API rework / new `TagLoader` class** — unnecessary; `SensorTag.load()` already satisfies the contract.
- **GUI / builder for the tag-definition `.m` file** — UI concern, not pipeline; candidate for a separate UX phase.
- **Ingest provenance fields** (`rawFile`, `rawColumn`, `parsedAt`, `pipelineVersion`) inside `.mat` outputs — would ship with the metadata-snapshot deferral above.
- **Byte-offset tail-reading for huge append-only CSVs** — `modTime + lastIndex` is sufficient for this phase; revisit if live-mode throughput regresses.

</deferred>

---

*Phase: 1012-tag-pipeline-raw-files-to-per-tag-mat-via-registry-batch-and-live*
*Context gathered: 2026-04-22*
