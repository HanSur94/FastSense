# Phase 1012: Tag Pipeline — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-22
**Phase:** 1012-tag-pipeline-raw-files-to-per-tag-mat-via-registry-batch-and-live
**Areas discussed:** Raw formats + parser model, Tag↔file binding, Per-tag .mat payload schema, Batch vs live orchestration, Monitor materialization, Output dir, Error policy

---

## Area selection

**Question:** Which gray areas do you want to discuss for the Tag Pipeline?

| Option | Description | Selected |
|--------|-------------|----------|
| Raw formats + parser model | Which file types + pluggable vs fixed parser set | ✓ (no preference → all) |
| Tag↔file binding mechanism | Config file vs filename convention vs header auto-match vs programmatic | ✓ (no preference → all) |
| Per-tag .mat payload schema | Existing contract vs extended with metadata | ✓ (no preference → all) |
| Batch vs live orchestration | One class vs two; reuse LiveEventPipeline or not | ✓ (no preference → all) |

**User's choice:** `[No preference]` — interpreted as "discuss all four".

---

## Raw formats + parser model

### Q1: What raw file formats must the pipeline handle out of the box?

| Option | Description | Selected |
|--------|-------------|----------|
| CSV only (Recommended) | `.csv`/`.txt` with delimiter detection; readtable + textscan fallback | |
| CSV + binary .dat | CSV plus documented binary .dat | |
| Wide: CSV + TXT + DAT + user-extensible | Pluggable parser registry by extension | ✓ |
| Minimal + pluggable hook | CSV only + `registerParser(ext, fn)` API | |

**User's choice:** Wide: CSV + TXT + DAT + user-extensible.

### Q2: Is the parser set fixed for this phase, or extensible by users today?

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed built-ins this phase (Recommended) | Ship built-ins; no public registerParser API yet | ✓ |
| Extensible now | Public `registerParser(ext, fn)` from day one | |

**User's choice:** Fixed built-ins this phase.

### Q3 (clarifier): What is the .dat layout?

| Option | Description | Selected |
|--------|-------------|----------|
| Delimited text (like CSV) (Recommended) | .dat = text; extension is a hint; one parser for all three | ✓ |
| Binary with documented header | fread-based parser, big-risk area | |
| Both — sniff by magic bytes | Ship both parsers | |

**User's choice:** Delimited text.

### Q4 (clarifier): Do we have a sample file / format spec, or design fresh?

| Option | Description | Selected |
|--------|-------------|----------|
| Design fresh, use synthetic fixtures (Recommended) | No real sample; tests generate in-suite | ✓ |
| There's a real sample file | Design parsers to match a concrete file | |

**User's choice:** Design fresh, synthetic fixtures.

**Notes:** Confirms `.csv` / `.txt` / `.dat` share one delimited-text parser with auto-detected delimiter. No public plugin API this phase (architect for extensibility later).

---

## Tag↔file binding mechanism

### Q5: What's the dominant raw-file shape?

| Option | Description | Selected |
|--------|-------------|----------|
| One raw file = many tags (wide) (Recommended) | CSV has time col + N value cols → N per-tag .mat | |
| One raw file = one tag (tall) | 2-col per file; filename = tag | |
| Both — must support wide AND tall | Pipeline auto-detects by column count | ✓ |

**User's choice:** Both.

### Q6: How should the pipeline know which raw column/file maps to which TagRegistry key?

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit mapping file (.m or .json) (Recommended) | Separate `{rawFile, column} -> tagKey` spec | |
| CSV header auto-match against TagRegistry | Column headers must equal tag keys | |
| Filename convention + header auto-match | Filename stem = tag key; header fallback | |
| Programmatic registration | `pipeline.bind(rawFile, column, tagKey)` | |

**User's choice:** Free text — "we have an matlab tag registry where all tags or certain tags are defined... .m file... there we specify the paths".

**Notes:** User clarified that the existing tag-registry `.m` script is where tag definitions AND their raw source paths live. No separate mapping file — the registry *is* the mapping.

### Q7 (Claude's recommendation, user-confirmed): Where does the path live on a tag?

| Option | Description | Selected |
|--------|-------------|----------|
| (a) On existing `Tag.SourceRef` | Free-text provenance string; overload for pipeline config | |
| (b) On `Tag.Metadata` (open struct) | Typed by convention only; no validation | |
| (c) New `Tag.RawSource` on base class | Touches Tag.m; dead weight on Monitor/Composite | |
| (d) Per-subclass `SensorTag.RawSource` / `StateTag.RawSource` (Recommended) | Matches existing SensorTag sensor-extras pattern; Tag base untouched | ✓ |

### Q8 (paired): Wide-file case — multiple tags pointing at same file?

| Option | Description | Selected |
|--------|-------------|----------|
| Multiple tags independently point at same file, pipeline de-dups internally (Recommended) | Flat schema; internal `parsedFile[path]` cache | ✓ |
| Normalized RawFile table indexes wide CSV once + fans out to tags | Second registry | |

**User's choice:** "ok do that" — confirmed (d) + internal de-dup.

**Notes:** `RawSource = struct('file', ..., 'column', ..., 'format', '')`. Pipeline opens each unique file once per run.

---

## Per-tag .mat payload schema

### Q9: What should each per-tag .mat file contain?

| Option | Description | Selected |
|--------|-------------|----------|
| Data only (keep existing SensorTag.load) (Recommended) | `data.<key> = struct('x', X, 'y', Y)` | ✓ |
| Data + metadata snapshot | Add `meta = struct(name, units, labels, criticality, sourceref)` | |
| Data + metadata + ingest provenance | Above plus rawFile/rawColumn/parsedAt/pipelineVersion | |

**User's choice:** Data only.

### Q10: One tag per .mat or multi-tag .mat?

| Option | Description | Selected |
|--------|-------------|----------|
| Strict one-tag-per-.mat (Recommended) | `<OutputDir>/<tagKey>.mat` | ✓ |
| Multi-tag .mat allowed | Multiple tags share one .mat; live writes conflict across tags | |

**User's choice:** Strict one-tag-per-.mat.

---

## Batch vs live orchestration

### Q11: How should batch and live mode be structured?

| Option | Description | Selected |
|--------|-------------|----------|
| Two classes: BatchTagPipeline + LiveTagPipeline (Recommended) | Shared private helper; clean blast radius | ✓ |
| One class with Mode='batch'/'live' flag | Smaller public surface but bigger cognitive load per method | |
| Batch only this phase, defer live | Ship batch, live in follow-up | |

**User's choice:** Two classes.

### Q12: How does live mode detect and append new raw data?

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse MatFileDataSource pattern on raw files (Recommended) | modTime + lastIndex polling | ✓ |
| Tail-read raw file incrementally | Byte-offset fseek + textscan; more edge cases | |
| Reuse LiveEventPipeline timer directly | LiveTagPipeline subclasses LiveEventPipeline | |

**User's choice:** Reuse MatFileDataSource pattern.

---

## Final gaps

### Q13: What does the pipeline do with MonitorTag (and CompositeTag) outputs?

| Option | Description | Selected |
|--------|-------------|----------|
| Raw-only pipeline; monitors stay lazy at load (Recommended) | Respects MONITOR-03 lazy-by-default | ✓ |
| Raw + optional monitor persist | Honor `MonitorTag.Persist = true` via existing storeMonitor | |
| Raw + monitors always materialized | Break MONITOR-03; not recommended | |

**User's choice:** Raw-only, monitors stay lazy.

### Q14: Where do per-tag .mat files land?

| Option | Description | Selected |
|--------|-------------|----------|
| Constructor parameter: OutputDir (Recommended) | `BatchTagPipeline(OutputDir='data/processed')` | ✓ |
| Per-tag override on RawSource | Optional `outputDir` field on RawSource | |
| Colocate next to raw files | Output .mat in same dir as raw source | |

**User's choice:** Constructor parameter.

### Q15: What happens on corrupt file / missing column / tag lacks RawSource?

| Option | Description | Selected |
|--------|-------------|----------|
| Hard-fail on per-tag errors, report summary at end (Recommended) | Per-tag try/catch; throw `TagPipeline:ingestFailed` at end with report | ✓ |
| Skip silently with warning | Return struct of successes/failures, no throw | |
| Fail-fast on first error | Stop on first failure | |

**User's choice:** Hard-fail with summary.

---

## Readiness check

### Q16: Ready to write CONTEXT.md?

| Option | Description | Selected |
|--------|-------------|----------|
| I'm ready for context | Write CONTEXT.md and advance to planning | ✓ |
| Explore more gray areas | Surface load-side API / huge ingest / Octave parity / fixture strategy | |

**User's choice:** I'm ready for context.

---

## Claude's Discretion

- Exact delimiter-sniffing algorithm (try `,` → `\t` → `;` → whitespace).
- Internal parser dispatch shape (switch vs. private containers.Map).
- Directory-creation semantics (`mkdir -p`-like, error only on permission failures).
- Error-ID taxonomy under `TagPipeline:*`.
- Private helper location (`private/` folder vs static class vs plain function file).
- File-count budget (likely ≤12 files following v2.0 discipline).
- Whether to add a `.pipelineVersion` getter for forward-compat.

---

## Deferred Ideas

Captured in CONTEXT.md `<deferred>` section:
- Public `registerParser(ext, fn)` plugin API.
- Binary `.dat` layout support.
- Metadata snapshot inside `.mat` files (self-describing).
- Multi-tag `.mat` layouts.
- Monitor / composite pre-materialization.
- FastSenseDataStore handoff for huge ingests.
- Load-side API rework / `TagLoader` class.
- GUI / builder for tag-definition `.m` file.
- Ingest provenance fields inside `.mat` outputs.
- Byte-offset tail-reading for huge append-only CSVs.
