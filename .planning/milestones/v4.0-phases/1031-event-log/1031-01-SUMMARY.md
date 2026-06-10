---
phase: 1031-event-log
plan: 01
subsystem: Concurrency
tags: [ndjson, decoder, corrupt-line-tolerance, EVTLOG-02]
requirements: [EVTLOG-02]
dependency_graph:
  requires:
    - ndjsonEncode (Phase 1029-04, libs/Concurrency/ndjsonEncode.m)
    - jsondecode (built-in MATLAB R2016b+ / Octave 5+)
  provides:
    - ndjsonDecode(text) — multi-line NDJSON decoder with corrupt-line tolerance
    - parseStats.SkippedLineCount — skip counter for EVTLOG-02 contract
    - parseStats.SkippedLines — {lineNumber, rawText, errMsg} triples for diagnostics
    - tests/test_ndjson_decode.m — 7 function-style Octave-compatible unit tests
  affects:
    - Plan 1031-02 (EventLog) — calls ndjsonDecode for tail reads
    - Plan 1031-03 (EventLogReader) — composes on top of ndjsonDecode skip semantics
tech_stack:
  added: []
  patterns:
    - try/catch around jsondecode with skip-on-error semantics (EVTLOG-02)
    - struct-array field-union merge for heterogeneous event/ack records
    - comment/header line detection (ln(1) == '#') for NDJSON log header format
key_files:
  created:
    - libs/Concurrency/ndjsonDecode.m
    - tests/test_ndjson_decode.m
  modified: []
decisions:
  - "ndjsonDecode placed at libs/Concurrency/ root (not private/) — mirrors Phase 1029-04 deviation #1 placing ndjsonEncode at the same public location. Plans 02 and 03 (EventLog, EventLogReader) at libs/Concurrency/ call it directly."
  - "ndjsonDecode_mergeStruct_ is a module-local sub-function (not nested, not private/) — required because MATLAB/Octave struct-array growth fails when field sets differ across records. Future heterogeneous event/ack lines (Phase 1032) work without caller changes."
  - "isempty(s) && ~isempty(errMsg) pattern used to distinguish jsondecode-threw case from jsondecode-returned-null case. jsondecode('null') returns [] without throwing — falls through to ~isstruct() check, which correctly counts it as skipped."
metrics:
  duration_seconds: 134
  completed_date: "2026-05-14"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
  test_pass_rate: "7/7 (test_ndjson_decode)"
  static_analysis: "clean (no errors)"
---

# Phase 1031 Plan 01: ndjsonDecode Summary

**One-liner:** Octave-safe NDJSON line decoder with defensive corrupt-line tolerance — `jsondecode`-backed, skip-and-count semantics for EVTLOG-02, public placement at `libs/Concurrency/` as sibling to `ndjsonEncode`.

## What landed

- **`libs/Concurrency/ndjsonDecode.m`** — Public function (sibling to `ndjsonEncode.m`, NOT `private/`). Decodes multi-line NDJSON char buffer via `strsplit` on `\n`/`\r\n`, skips blank lines and `#`-prefixed comment/header lines silently, wraps `jsondecode` per-line in try/catch. Non-struct JSON values (numbers, strings, arrays) also counted as skipped. Returns `[events, parseStats]` where `events` is a 1xN struct array and `parseStats.SkippedLineCount` + `parseStats.SkippedLines` provide diagnostics. Internal `ndjsonDecode_mergeStruct_` sub-function handles heterogeneous field sets across records (needed when Phase 1032 mixes `event` and `ack` line types).

- **`tests/test_ndjson_decode.m`** — 7 function-style Octave-compatible unit tests:
  1. Empty input → `[]`, zero skips
  2. Encode/decode round-trip on flat struct
  3. Corrupt line (`{not_json}`) counted in `SkippedLineCount`, adjacent valid lines returned
  4. `#FASTSENSE_EVENTLOG_V1` header silently skipped, NOT counted as corrupt
  5. Blank lines + trailing newlines silently skipped, zero `SkippedLineCount`
  6. 3-record heterogeneous round-trip (fields `val`, `note` differ across records)
  7. Number-only JSON (`42`) counted as skipped (events must be structs)

## Deviations from Plan

None — plan executed exactly as written.

## REQ coverage

- **EVTLOG-02 (partial):** The corrupt-line tolerance primitive is in place. Plans 02 (EventLog 50-process stress) and 03 (EventLogReader) compose on top of it. The reader-side `parseStats.SkippedLineCount` contract is established at the decoder layer — no special-case logic needed in EventLogReader beyond surfacing the counter.

## Known Stubs

None. Implementation is complete and fully wired.

## Next consumers

- **Plan 1031-02 (EventLog):** `EventLog.tail` calls `ndjsonDecode` on the raw file contents.
- **Plan 1031-03 (EventLogReader):** `EventLogReader` surfaces `parseStats.SkippedLineCount` to callers.

## Self-Check: PASSED

Files verified:
- `libs/Concurrency/ndjsonDecode.m` exists at public (non-private) path
- `tests/test_ndjson_decode.m` exists
- Task 1 commit `135e79f` exists in git log
- Task 2 commit `e97eb29` exists in git log
